import Foundation
import CoreLocation
import MapKit

enum NavigationIssue: Error, LocalizedError, Equatable {
    case missingDestination, staleDestination, locationDenied, locationUnavailable, routeUnavailable
    var errorDescription: String? {
        switch self {
        case .missingDestination: return "Senior location is unavailable."
        case .staleDestination: return "Senior location is out of date. Refresh and try again."
        case .locationDenied: return "Allow location access in Settings to plan a route."
        case .locationUnavailable: return "Your current location is unavailable. Try again."
        case .routeUnavailable: return "A walking route is unavailable. Try again."
        }
    }
}

struct WalkingRoute {
    let coordinates: [CLLocationCoordinate2D]
    let distanceMeters: Double
    let expectedSeconds: TimeInterval
    let steps: [String]
}

@MainActor protocol WalkingRouteProvider {
    func currentPoint() async throws -> GeoPoint
    func route(from: GeoPoint, to: GeoPoint) async throws -> WalkingRoute
}

@MainActor final class AppleWalkingRouteProvider: NSObject, WalkingRouteProvider, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    private var locationContinuation: CheckedContinuation<GeoPoint, Error>?
    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
    }
    func currentPoint() async throws -> GeoPoint {
        guard CLLocationManager.locationServicesEnabled() else { throw NavigationIssue.locationDenied }
        guard locationContinuation == nil else { throw NavigationIssue.locationUnavailable }
        let status = manager.authorizationStatus
        guard status != .denied && status != .restricted else { throw NavigationIssue.locationDenied }
        return try await withCheckedThrowingContinuation { continuation in
            locationContinuation = continuation
            if status == .notDetermined { manager.requestWhenInUseAuthorization() }
            else { manager.requestLocation() }
        }
    }
    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        Task { @MainActor [weak self] in self?.handleAuthorization(status) }
    }
    private func handleAuthorization(_ status: CLAuthorizationStatus) {
        guard locationContinuation != nil else { return }
        switch status {
        case .authorizedAlways, .authorizedWhenInUse: manager.requestLocation()
        case .denied, .restricted: completeLocation(.failure(NavigationIssue.locationDenied))
        default: break
        }
    }
    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        let location = locations.last
        let valid = location.map { $0.horizontalAccuracy >= 0 } ?? false
        let latitude = location?.coordinate.latitude ?? 0
        let longitude = location?.coordinate.longitude ?? 0
        Task { @MainActor [weak self] in
            self?.completeLocation(valid ? .success(GeoPoint(latitude: latitude, longitude: longitude)) : .failure(NavigationIssue.locationUnavailable))
        }
    }
    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor [weak self] in self?.completeLocation(.failure(NavigationIssue.locationUnavailable)) }
    }
    private func completeLocation(_ result: Result<GeoPoint, Error>) {
        let continuation = locationContinuation
        locationContinuation = nil
        continuation?.resume(with: result)
    }
    func route(from: GeoPoint, to: GeoPoint) async throws -> WalkingRoute {
        let request = MKDirections.Request()
        request.source = MKMapItem(placemark: MKPlacemark(coordinate: from.appleCoordinate))
        request.destination = MKMapItem(placemark: MKPlacemark(coordinate: to.appleCoordinate))
        request.transportType = .walking
        request.requestsAlternateRoutes = false
        let result: MKDirections.Response
        do { result = try await MKDirections(request: request).calculate() }
        catch { throw NavigationIssue.routeUnavailable }
        guard let route = result.routes.first, route.polyline.pointCount > 1 else { throw NavigationIssue.routeUnavailable }
        let points = route.polyline.points()
        let coordinates = (0..<route.polyline.pointCount).map { points[$0].coordinate }
        let steps = route.steps.map(\.instructions).filter { !$0.isEmpty }
        return WalkingRoute(coordinates: coordinates, distanceMeters: route.distance,
                            expectedSeconds: route.expectedTravelTime, steps: steps)
    }
}

@MainActor final class WalkingNavigationModel: ObservableObject {
    @Published private(set) var route: WalkingRoute?
    @Published private(set) var issue: NavigationIssue?
    @Published private(set) var loading = false
    private let provider: WalkingRouteProvider
    init(provider: WalkingRouteProvider) { self.provider = provider }
    convenience init() { self.init(provider: AppleWalkingRouteProvider()) }
    func plan(to snapshot: ElderLocationSnapshot?) async {
        guard !loading else { return }
        route = nil; issue = nil
        guard let snapshot, snapshot.coordinate.isValid else { issue = .missingDestination; return }
        guard snapshot.isCurrent else { issue = .staleDestination; return }
        loading = true
        defer { loading = false }
        do {
            let source = try await provider.currentPoint()
            guard source.isValid else { throw NavigationIssue.locationUnavailable }
            route = try await provider.route(from: source, to: snapshot.coordinate)
        } catch let error as NavigationIssue { issue = error }
        catch { issue = .routeUnavailable }
    }
}
