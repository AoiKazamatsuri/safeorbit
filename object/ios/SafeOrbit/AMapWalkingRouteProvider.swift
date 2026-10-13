import Foundation
import CoreLocation
#if !targetEnvironment(simulator)
import AMapLocationKit
import AMapSearchKit

/// App-facing fixes are WGS-84; AMap route geometry stays GCJ-02 for map display.
@MainActor final class AMapWalkingRouteProvider: NSObject, WalkingRouteProvider, AMapLocationManagerDelegate, CLLocationManagerDelegate {
    private var locator: AMapLocationManager?
    private let headingManager = CLLocationManager()
    private var receive: ((Result<NavigationFix, NavigationIssue>) -> Void)?
    private var headingReceiver: ((NavigationHeading) -> Void)?
    private var locationContinuation: CheckedContinuation<GeoPoint, Error>?
    private var locationRequestID: UUID?
    private var locationTimeout: Task<Void, Never>?
    private var routeOperation: AMapSearchOperation?
    private var latestFix: NavigationFix?

    override init() {
        super.init()
        headingManager.delegate = self
    }
    private func prepareLocator() -> Bool {
        guard AMapRuntime.prepare() else { return false }
        if locator == nil {
            let manager = AMapLocationManager()
            manager.delegate = self
            manager.desiredAccuracy = kCLLocationAccuracyBest
            manager.distanceFilter = kCLDistanceFilterNone
            manager.pausesLocationUpdatesAutomatically = false
            manager.allowsBackgroundLocationUpdates = false
            locator = manager
        }
        return true
    }
    func currentPoint() async throws -> GeoPoint {
        try Task.checkCancellation()
        guard prepareLocator() else { throw NavigationIssue.sdkNotReady }
        guard CLLocationManager.locationServicesEnabled(), headingManager.authorizationStatus != .denied,
              headingManager.authorizationStatus != .restricted else { throw NavigationIssue.locationDenied }
        if let fix = latestFix, fix.isUsable(at: Date()) { return fix.point }
        guard locationContinuation == nil else { throw NavigationIssue.locationUnavailable }
        let id = UUID()
        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                locationRequestID = id; locationContinuation = continuation
                locationTimeout = Task { [weak self] in
                    do { try await Task.sleep(for: .seconds(15)) } catch { return }
                    guard self?.locationRequestID == id else { return }
                    self?.completeLocation(.failure(NavigationIssue.locationUnavailable))
                }
                handleAuthorization(headingManager.authorizationStatus)
            }
        } onCancel: {
            Task { @MainActor [weak self] in
                guard self?.locationRequestID == id else { return }
                self?.completeLocation(.failure(CancellationError()))
            }
        }
    }
    func startUpdates(_ receive: @escaping (Result<NavigationFix, NavigationIssue>) -> Void) {
        self.receive = receive
        guard prepareLocator() else { receive(.failure(.sdkNotReady)); return }
        guard CLLocationManager.locationServicesEnabled() else { receive(.failure(.locationDenied)); return }
        handleAuthorization(headingManager.authorizationStatus)
    }
    func startHeadingUpdates(_ receive: @escaping (NavigationHeading) -> Void) {
        headingReceiver = receive
        guard prepareLocator() else { return }
        handleAuthorization(headingManager.authorizationStatus)
    }
    func stopUpdates() {
        receive = nil; headingReceiver = nil; latestFix = nil
        headingManager.stopUpdatingHeading()
        locator?.stopUpdatingLocation()
        // Discard the manager so a callback queued by an older session cannot enter a new session.
        locator?.delegate = nil; locator = nil
        completeLocation(.failure(CancellationError()))
    }
    private func handleAuthorization(_ status: CLAuthorizationStatus) {
        switch status {
        case .notDetermined:
            if receive != nil || locationContinuation != nil || headingReceiver != nil {
                headingManager.requestWhenInUseAuthorization()
            }
        case .authorizedWhenInUse, .authorizedAlways:
            if receive != nil || locationContinuation != nil { locator?.startUpdatingLocation() }
            if headingReceiver != nil, CLLocationManager.headingAvailable() { headingManager.startUpdatingHeading() }
        case .denied, .restricted:
            locator?.stopUpdatingLocation(); headingManager.stopUpdatingHeading(); latestFix = nil
            receive?(.failure(.locationDenied))
            completeLocation(.failure(NavigationIssue.locationDenied))
        @unknown default: break
        }
    }
    private func completeLocation(_ result: Result<GeoPoint, Error>) {
        locationTimeout?.cancel(); locationTimeout = nil
        let continuation = locationContinuation
        locationContinuation = nil; locationRequestID = nil
        if receive == nil { locator?.stopUpdatingLocation() }
        continuation?.resume(with: result)
    }
    nonisolated func amapLocationManager(_ manager: AMapLocationManager!, didUpdate location: CLLocation!, reGeocode: AMapLocationReGeocode!) {
        guard let location else { return }
        let point = MainlandCoordinates.toWGS84(GeoPoint(latitude: location.coordinate.latitude, longitude: location.coordinate.longitude))
        let fix = NavigationFix(point: point, accuracy: location.horizontalAccuracy, timestamp: location.timestamp, course: location.course)
        Task { @MainActor [weak self] in
            guard let self, manager === self.locator else { return }
            guard self.receive != nil || self.locationContinuation != nil else { return }
            self.latestFix = fix
            self.receive?(.success(fix))
            if fix.isUsable(at: Date()) { self.completeLocation(.success(point)) }
        }
    }
    nonisolated func amapLocationManager(_ manager: AMapLocationManager!, didFailWithError error: Error!) {
        let denied = (error as NSError?)?.domain == kCLErrorDomain && (error as NSError?)?.code == CLError.denied.rawValue
        Task { @MainActor [weak self] in
            guard let self, manager === self.locator else { return }
            let issue: NavigationIssue = denied || self.headingManager.authorizationStatus == .denied || self.headingManager.authorizationStatus == .restricted ? .locationDenied : .locationUnavailable
            self.receive?(.failure(issue)); self.completeLocation(.failure(issue))
        }
    }
    nonisolated func amapLocationManager(_ manager: AMapLocationManager!, locationManagerDidChangeAuthorization locationManager: CLLocationManager!) {
        guard let locationManager else { return }
        let status = locationManager.authorizationStatus
        Task { @MainActor [weak self] in
            guard let self, manager === self.locator else { return }
            self.handleAuthorization(status)
        }
    }
    nonisolated func amapLocationManager(_ manager: AMapLocationManager!, doRequireLocationAuth locationManager: CLLocationManager!) {
        Task { @MainActor in locationManager?.requestWhenInUseAuthorization() }
    }
    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        Task { @MainActor [weak self] in self?.handleAuthorization(status) }
    }
    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateHeading newHeading: CLHeading) {
        let sample = NavigationHeading(degrees: newHeading.trueHeading >= 0 ? newHeading.trueHeading : newHeading.magneticHeading,
                                       accuracy: newHeading.headingAccuracy, timestamp: newHeading.timestamp)
        Task { @MainActor [weak self] in self?.headingReceiver?(sample) }
    }
    func cancelRoute() { routeOperation?.cancel(); routeOperation = nil }
    func route(from: GeoPoint, to: GeoPoint) async throws -> WalkingRoute {
        try Task.checkCancellation()
        guard AMapRuntime.prepare() else { throw NavigationIssue.sdkNotReady }
        guard from.isValid, to.isValid else { throw NavigationIssue.routeUnavailable }
        cancelRoute()
        let operation = AMapSearchOperation()
        routeOperation = operation
        defer { if routeOperation === operation { routeOperation = nil } }
        let request = AMapWalkingRouteSearchRequest()
        request.origin = Self.searchPoint(from); request.destination = Self.searchPoint(to)
        // Include duration, navigation instructions and per-step geometry.
        request.showFieldsType = AMapWalkingRouteShowFieldType(rawValue: 7)
        let value = try await operation.perform(request)
        guard case .route(let route) = value else { throw NavigationIssue.routeUnavailable }
        return route
    }
    fileprivate static func searchPoint(_ point: GeoPoint) -> AMapGeoPoint {
        let converted = MainlandCoordinates.toGCJ02(point)
        let value = AMapGeoPoint()
        value.latitude = converted.latitude; value.longitude = converted.longitude
        return value
    }
}

@MainActor enum AMapGeocoder {
    static func address(at point: GeoPoint) async -> String? {
        guard point.isValid, AMapRuntime.prepare(), !Task.isCancelled else { return nil }
        let operation = AMapSearchOperation()
        let request = AMapReGeocodeSearchRequest()
        request.location = AMapWalkingRouteProvider.searchPoint(point)
        request.radius = 100; request.requireExtension = false
        do {
            guard case .address(let address) = try await operation.perform(request) else { return nil }
            return address
        } catch { return nil }
    }
}

/// One SDK search instance per request makes cancellation and late delegates independent.
@MainActor private final class AMapSearchOperation: NSObject, AMapSearchDelegate {
    enum Value { case route(WalkingRoute), address(String?) }
    private var api: AMapSearchAPI?
    private var request: NSObject?
    private var continuation: CheckedContinuation<Value, Error>?
    private var timeout: Task<Void, Never>?
    private var finished = false
    func perform(_ request: NSObject) async throws -> Value {
        try Task.checkCancellation()
        guard !finished else { throw CancellationError() }
        guard let api = AMapSearchAPI() else { throw NavigationIssue.sdkNotReady }
        self.api = api; self.request = request; api.delegate = self
        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                self.continuation = continuation
                timeout = Task { [weak self] in
                    do { try await Task.sleep(for: .seconds(20)) } catch { return }
                    self?.finish(.failure(NavigationIssue.routeTimedOut))
                }
                if let walking = request as? AMapWalkingRouteSearchRequest { api.aMapWalkingRouteSearch(walking) }
                else if let address = request as? AMapReGeocodeSearchRequest { api.aMapReGoecodeSearch(address) }
                else { finish(.failure(NavigationIssue.routeUnavailable)) }
            }
        } onCancel: { Task { @MainActor [weak self] in self?.cancel() } }
    }
    func cancel() { finish(.failure(CancellationError())) }
    private func finish(_ result: Result<Value, Error>) {
        guard !finished else { return }
        finished = true
        timeout?.cancel(); timeout = nil
        let pending = continuation; continuation = nil; request = nil
        api?.delegate = nil; api?.cancelAllRequests(); api = nil
        pending?.resume(with: result)
    }
    nonisolated func aMapSearchRequest(_ request: Any!, didFailWithError error: Error!) {
        let code = (error as NSError?)?.code ?? -1
        Task { @MainActor [weak self] in
            guard let self, let request = request as? NSObject, request === self.request else { return }
            // Never surface SDK userInfo, which may include credentials.
            self.finish(.failure(NavigationIssue.amapSearchError(code: code)))
        }
    }
    nonisolated func onRouteSearchDone(_ request: AMapRouteSearchBaseRequest!, response: AMapRouteSearchResponse!) {
        Task { @MainActor [weak self] in
            guard let self, request === self.request, !self.finished else { return }
            guard let path = response?.route?.paths?.first else { self.finish(.failure(NavigationIssue.routeUnavailable)); return }
            var segments = (path.steps ?? []).compactMap { step -> WalkingStep? in
                let coordinates = Self.coordinates(step.polyline)
                guard coordinates.count > 1 else { return nil }
                let instruction = step.instruction?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                let distance = step.distance > 0 ? Double(step.distance) : Self.length(of: coordinates)
                return WalkingStep(instruction: instruction.isEmpty ? "Continue along the route" : instruction,
                                   coordinates: coordinates, distanceMeters: distance)
            }
            var geometry = Self.coordinates(path.polyline)
            if geometry.count < 2 { geometry = (path.steps ?? []).flatMap { Self.coordinates($0.polyline) } }
            if geometry.count < 2 { geometry = Self.coordinates(response?.route?.polyline) }
            guard geometry.count > 1 else {
                self.finish(.failure(NavigationIssue.routeUnavailable)); return
            }
            let distance = path.distance > 0 ? Double(path.distance) : Self.length(of: geometry)
            guard distance > 0 else { self.finish(.failure(NavigationIssue.routeUnavailable)); return }
            if segments.isEmpty {
                segments = [WalkingStep(instruction: "Continue along the route", coordinates: geometry,
                                        distanceMeters: distance)]
            }
            let duration = path.duration > 0 ? Double(path.duration) : distance / 1.25
            self.finish(.success(.route(WalkingRoute(coordinates: geometry, distanceMeters: distance,
                         expectedSeconds: duration, steps: segments.map(\.instruction), segments: segments))))
        }
    }
    nonisolated func onReGeocodeSearchDone(_ request: AMapReGeocodeSearchRequest!, response: AMapReGeocodeSearchResponse!) {
        Task { @MainActor [weak self] in
            guard let self, request === self.request, !self.finished else { return }
            let address = response?.regeocode?.formattedAddress?.trimmingCharacters(in: .whitespacesAndNewlines)
            self.finish(.success(.address(address?.isEmpty == false ? address : nil)))
        }
    }
    private static func coordinates(_ polyline: String?) -> [CLLocationCoordinate2D] {
        guard let polyline else { return [] }
        return polyline.split(separator: ";").compactMap { pair in
            let values = pair.split(separator: ",")
            guard values.count == 2, let longitude = Double(values[0]), let latitude = Double(values[1]),
                  GeoPoint(latitude: latitude, longitude: longitude).isValid else { return nil }
            return CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
        }
    }
    private static func length(of coordinates: [CLLocationCoordinate2D]) -> Double {
        guard coordinates.count > 1 else { return 0 }
        return zip(coordinates, coordinates.dropFirst()).reduce(0) { total, pair in
            total + CLLocation(latitude: pair.0.latitude, longitude: pair.0.longitude)
                .distance(from: CLLocation(latitude: pair.1.latitude, longitude: pair.1.longitude))
        }
    }
}

#else
@MainActor final class AMapWalkingRouteProvider: WalkingRouteProvider {
    func currentPoint() async throws -> GeoPoint { throw NavigationIssue.sdkNotReady }
    func route(from: GeoPoint, to: GeoPoint) async throws -> WalkingRoute { throw NavigationIssue.sdkNotReady }
    func startUpdates(_ receive: @escaping (Result<NavigationFix, NavigationIssue>) -> Void) { receive(.failure(.sdkNotReady)) }
}
@MainActor enum AMapGeocoder {
    static func address(at point: GeoPoint) async -> String? { nil }
}
#endif
