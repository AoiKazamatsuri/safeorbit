import Foundation
import CoreLocation
import UIKit

/// One fix as the care API stores it: WGS-84 straight from Core Location (also what Xcode GPX playback feeds).
struct UploadPoint: Codable, Equatable {
    let sampledAt: Date
    let latitude: Double
    let longitude: Double
    let accuracy: Double?
    let speed: Double?
    let course: Double?

    init(sampledAt: Date, latitude: Double, longitude: Double, accuracy: Double? = nil, speed: Double? = nil, course: Double? = nil) {
        self.sampledAt = sampledAt; self.latitude = latitude; self.longitude = longitude
        self.accuracy = accuracy; self.speed = speed; self.course = course
    }
    init?(_ location: CLLocation) {
        guard location.horizontalAccuracy >= 0, CLLocationCoordinate2DIsValid(location.coordinate) else { return nil }
        self.init(sampledAt: location.timestamp, latitude: location.coordinate.latitude, longitude: location.coordinate.longitude,
                  accuracy: location.horizontalAccuracy,
                  speed: location.speed >= 0 ? location.speed : nil,
                  course: location.course >= 0 ? location.course : nil)
    }
}
struct LocationUploadBatch: Encodable {
    let points: [UploadPoint]
    let batteryPercent: Int?
    let locationPermission: String
    let preciseLocation: Bool
}
struct LocationUploadReply: Decodable {
    struct Result: Decodable { let index: Int; let status: String }
    let results: [Result]
    /// Pending actions for this phone (task T38), e.g. startNavigation; missing in older replies.
    let actions: [ElderAction]?
}

/// Fixes waiting for upload, kept on disk so a dropped connection or a restart only delays them.
final class PendingFixQueue {
    static let limit = 20_000
    private let file: URL
    private(set) var points: [UploadPoint]

    init(file: URL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        .appendingPathComponent("pending-location-fixes.json")) {
        self.file = file
        points = (try? Data(contentsOf: file)).flatMap { try? JSONDecoder().decode([UploadPoint].self, from: $0) } ?? []
    }
    func append(_ new: [UploadPoint]) {
        guard !new.isEmpty else { return }
        points.append(contentsOf: new)
        if points.count > Self.limit { points.removeFirst(points.count - Self.limit) }
        save()
    }
    func drop(first count: Int) {
        points.removeFirst(min(count, points.count))
        save()
    }
    private func save() {
        try? FileManager.default.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
        try? JSONEncoder().encode(points).write(to: file, options: .atomic)
    }
}

/// Elder phone (task T37): follows location in the background and uploads a batch every 5 s
/// (engineering architecture section 8, upload interval); also fetches the home zone for "Go Home".
@MainActor final class ElderLocationReporter: NSObject, ObservableObject, CLLocationManagerDelegate {
    static let uploadInterval: TimeInterval = 5
    static let batchLimit = 500
    @Published private(set) var home: GeoPoint?
    @Published private(set) var lastUpload: Date?
    @Published private(set) var problem: String?
    /// Preset household from registration: her call name and the caregiver's phone.
    @Published private(set) var household: DeviceHousehold?
    /// Receives the actions of every upload reply; the same action repeats until its result is posted.
    var onActions: (([ElderAction]) -> Void)?
    let device: DemoDevice
    let queue: PendingFixQueue
    private let manager: CLLocationManager
    private var timer: Timer?
    private var uploading = false
    private var started = false
    private var homeCheckedAt: Date?

    init(device: DemoDevice? = nil, queue: PendingFixQueue? = nil, manager: CLLocationManager? = nil) {
        self.device = device ?? DemoDevice(role: .elder)
        self.queue = queue ?? PendingFixQueue(); self.manager = manager ?? CLLocationManager()
        super.init()
    }

    func start() {
        guard !started else { return }
        started = true
        UIDevice.current.isBatteryMonitoringEnabled = true
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
        manager.distanceFilter = kCLDistanceFilterNone
        manager.activityType = .fitness
        manager.pausesLocationUpdatesAutomatically = false
        manager.allowsBackgroundLocationUpdates = true
        manager.showsBackgroundLocationIndicator = true
        manager.requestAlwaysAuthorization()
        manager.startUpdatingLocation()
        timer = Timer.scheduledTimer(withTimeInterval: Self.uploadInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in await self?.flush() }
        }
        Task { await flush() }
    }

    func stop() {
        timer?.invalidate(); timer = nil
        manager.stopUpdatingLocation()
        started = false
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        let points = locations.compactMap(UploadPoint.init)
        Task { @MainActor in self.queue.append(points) }
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor in self.problem = Self.permissionProblem(self.permission, precise: self.precise) }
    }

    var permission: String {
        switch manager.authorizationStatus {
        case .authorizedAlways: return "always"
        case .authorizedWhenInUse: return "whenInUse"
        case .denied: return "denied"
        case .restricted: return "restricted"
        default: return "notDetermined"
        }
    }
    var precise: Bool { manager.accuracyAuthorization == .fullAccuracy }

    nonisolated static func permissionProblem(_ permission: String, precise: Bool) -> String? {
        if permission == "denied" || permission == "restricted" { return "Location is off. Turn it on in Settings so your family can help." }
        if permission == "whenInUse" { return "Set Location to Always in Settings so your family can help when the app is closed." }
        if !precise && permission == "always" { return "Turn on Precise Location in Settings." }
        return nil
    }

    /// Sends waiting fixes in order; anything the server answered for (stored, duplicate or invalid) leaves the queue.
    func flush() async {
        guard !uploading else { return }
        uploading = true
        defer { uploading = false }
        do {
            // The home zone can be edited on the caregiver phone; look again once a minute.
            if device.token == nil || home == nil || homeCheckedAt.map({ Date().timeIntervalSince($0) > 60 }) ?? true {
                try await refreshHome()
            }
            while !queue.points.isEmpty {
                let points = Array(queue.points.prefix(Self.batchLimit))
                let battery = UIDevice.current.batteryLevel
                let batch = LocationUploadBatch(points: points, batteryPercent: battery >= 0 ? Int((battery * 100).rounded()) : nil,
                                                locationPermission: permission, preciseLocation: precise)
                let reply: LocationUploadReply = try await device.request("locations", method: "POST", body: OnboardingAPI.json(batch))
                queue.drop(first: reply.results.count)
                lastUpload = Date()
                if let actions = reply.actions, !actions.isEmpty { onActions?(actions) }
            }
            problem = Self.permissionProblem(permission, precise: precise)
        } catch is CancellationError {
        } catch {
            problem = (error as? APIError)?.kind == .network ? "Not connected. Your location will be sent when the connection returns." : nil
        }
    }

    private func refreshHome() async throws {
        let zones: [RemoteSafeZone] = try await device.request("safe-zones")
        homeCheckedAt = Date()
        if let latest = device.household, latest != household { household = latest }
        if let zone = zones.first(where: \.isHome), zone.center != home { home = zone.center }
    }
}
