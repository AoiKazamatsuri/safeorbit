import Foundation
import CoreLocation
import MapKit
import AVFoundation

enum NavigationIssue: Error, LocalizedError, Equatable {
    case missingDestination, missingHome, staleDestination, locationDenied, locationUnavailable, routeUnavailable, sdkNotReady
    var errorDescription: String? {
        switch self {
        case .missingHome: return "Set a home location before starting navigation."
        case .sdkNotReady: return "Map services are unavailable. Enable map services or use a physical iPhone."
        case .missingDestination: return "Senior location is unavailable."
        case .staleDestination: return "Senior location is out of date. Refresh and try again."
        case .locationDenied: return "Allow location access in Settings to plan a route."
        case .locationUnavailable: return "Waiting for an accurate, current location."
        case .routeUnavailable: return "A walking route is unavailable. Try again."
        }
    }
}

struct NavigationFix {
    let point: GeoPoint
    let accuracy: Double
    let timestamp: Date
    var course: Double = -1
    func isUsable(at now: Date) -> Bool {
        point.isValid && accuracy.isFinite && (0...50).contains(accuracy)
        && now.timeIntervalSince(timestamp) >= -5 && now.timeIntervalSince(timestamp) <= 15
    }
}
struct NavigationHeading {
    let degrees: Double
    let accuracy: Double
    let timestamp: Date
    func isUsable(at now: Date) -> Bool {
        degrees.isFinite && (0..<360).contains(degrees) && accuracy.isFinite && (0...45).contains(accuracy)
        && (-5...15).contains(now.timeIntervalSince(timestamp))
    }
}
struct WalkingStep {
    let instruction: String
    let coordinates: [CLLocationCoordinate2D]
    let distanceMeters: Double
}
struct WalkingRoute {
    let coordinates: [CLLocationCoordinate2D]
    let distanceMeters: Double
    let expectedSeconds: TimeInterval
    let steps: [String]
    var segments: [WalkingStep] = []
}

@MainActor protocol WalkingRouteProvider {
    func currentPoint() async throws -> GeoPoint
    func route(from: GeoPoint, to: GeoPoint) async throws -> WalkingRoute
    func startUpdates(_ receive: @escaping (Result<NavigationFix, NavigationIssue>) -> Void)
    func startHeadingUpdates(_ receive: @escaping (NavigationHeading) -> Void)
    func stopUpdates()
    func cancelRoute()
}
extension WalkingRouteProvider {
    func startUpdates(_ receive: @escaping (Result<NavigationFix, NavigationIssue>) -> Void) {}
    func startHeadingUpdates(_ receive: @escaping (NavigationHeading) -> Void) {}
    func stopUpdates() {}
    func cancelRoute() {}
}

@MainActor protocol NavigationSpeaking {
    func speak(_ text: String)
    func stop()
}
@MainActor final class NavigationVoice: NavigationSpeaking {
    private let synthesizer = AVSpeechSynthesizer()
    func speak(_ text: String) {
        let utterance = AVSpeechUtterance(string: text)
        // Route instructions follow the English language setting configured in AMapRuntime.
        synthesizer.speak(utterance)
    }
    func stop() { synthesizer.stopSpeaking(at: .immediate) }
}

/// Projection onto the actual route geometry, in the GCJ-02 display coordinates returned by AMap.
struct RouteProjection {
    let along: Double
    let offRoute: Double
    let length: Double
    static func project(_ coordinate: CLLocationCoordinate2D, onto coordinates: [CLLocationCoordinate2D]) -> Self? {
        guard coordinates.count > 1 else { return nil }
        let point = MKMapPoint(coordinate)
        var traversed = 0.0, bestDistance = Double.infinity, bestAlong = 0.0
        for index in 1..<coordinates.count {
            let a = MKMapPoint(coordinates[index - 1]), b = MKMapPoint(coordinates[index])
            let dx = b.x - a.x, dy = b.y - a.y, square = dx * dx + dy * dy
            let fraction = square > 0 ? min(1, max(0, ((point.x - a.x) * dx + (point.y - a.y) * dy) / square)) : 0
            let projected = MKMapPoint(x: a.x + fraction * dx, y: a.y + fraction * dy)
            let distance = point.distance(to: projected), segmentLength = a.distance(to: b)
            if distance < bestDistance { bestDistance = distance; bestAlong = traversed + fraction * segmentLength }
            traversed += segmentLength
        }
        return Self(along: bestAlong, offRoute: bestDistance, length: traversed)
    }
}

enum NavigationDestinationKind { case senior, home }

@MainActor final class WalkingNavigationModel: ObservableObject {
    @Published private(set) var route: WalkingRoute?
    @Published private(set) var issue: NavigationIssue?
    @Published private(set) var loading = false
    @Published private(set) var isPresented = false
    @Published private(set) var suspended = false
    @Published private(set) var arrived = false
    @Published private(set) var fix: NavigationFix?
    @Published private var heading: NavigationHeading?
    @Published private(set) var destination: ElderLocationSnapshot?
    @Published private(set) var remainingMeters = 0.0
    @Published private(set) var remainingSeconds = 0.0
    @Published private(set) var estimatedArrival: Date?
    @Published private(set) var stepIndex = 0
    @Published private(set) var turnMeters = 0.0
    @Published private(set) var muted = false
    let destinationKind: NavigationDestinationKind
    let isDemoRoute: Bool
    private let provider: WalkingRouteProvider
    private let voice: NavigationSpeaking
    private let now: () -> Date
    private var generation = 0
    @Published private(set) var routeVersion = 0
    private var lastPlanningAt: Date?
    private var plannedDestination: GeoPoint?
    private var offRouteCount = 0
    private var arrivalCount = 0
    private var spoken: Set<String> = []
    private var stepEnds: [Double] = []
    @Published private var needsReplan = false
    private var planningTask: Task<Void, Never>?
    init(provider: WalkingRouteProvider, voice: NavigationSpeaking? = nil, now: @escaping () -> Date = Date.init, destinationKind: NavigationDestinationKind = .senior, isDemoRoute: Bool = false) {
        self.isDemoRoute = isDemoRoute
        self.destinationKind = destinationKind
        self.provider = provider; self.voice = voice ?? NavigationVoice(); self.now = now
    }
    convenience init(destinationKind: NavigationDestinationKind = .senior) {
        self.init(provider: AMapWalkingRouteProvider(), destinationKind: destinationKind)
    }
    /// Use device facing direction when stationary; route tangent keeps unsupported devices useful.
    var markerHeading: Double? {
        if let heading, heading.isUsable(at: now()) { return heading.degrees }
        if let fix, fix.course.isFinite, (0..<360).contains(fix.course) { return fix.course }
        guard let fix, let coordinates = route?.coordinates, coordinates.count > 1 else { return nil }
        let point = fix.point.appleCoordinate
        var nearest = Double.infinity, bearing: Double?
        for index in 1..<coordinates.count {
            let a = coordinates[index - 1], b = coordinates[index]
            guard let projection = RouteProjection.project(point, onto: [a, b]),
                  projection.length > 1, projection.offRoute < nearest else { continue }
            nearest = projection.offRoute
            let latitude1 = a.latitude * .pi / 180, latitude2 = b.latitude * .pi / 180
            let longitude = (b.longitude - a.longitude) * .pi / 180
            let y = sin(longitude) * cos(latitude2)
            let x = cos(latitude1) * sin(latitude2) - sin(latitude1) * cos(latitude2) * cos(longitude)
            bearing = (atan2(y, x) * 180 / .pi + 360).truncatingRemainder(dividingBy: 360)
        }
        return bearing
    }
    var instruction: String {
        if arrived { return arrivalInstruction }
        if suspended { return "Navigation paused" }
        if let issue { return issue.localizedDescription }
        if loading { return "Finding a walking route…" }
        if needsReplan { return destinationKind == .home ? "Updating route home…" : "Updating route to the senior’s latest location…" }
        guard let route, route.steps.indices.contains(stepIndex) else { return "Follow the highlighted route" }
        return route.steps[stepIndex]
    }
    var directionSymbol: String {
        if arrived { return "checkmark.circle.fill" }
        if issue != nil || suspended { return "exclamationmark.circle" }
        let text = instruction.lowercased()
        if text.contains("left") || text.contains("左") { return "arrow.turn.up.left" }
        if text.contains("right") || text.contains("右") { return "arrow.turn.up.right" }
        return "arrow.up"
    }
    private var arrivalInstruction: String {
        destinationKind == .home ? "Arrived home" : "Arrived near the senior’s latest location"
    }
    private func validDestination(_ snapshot: ElderLocationSnapshot?) -> NavigationIssue? {
        guard let snapshot, snapshot.coordinate.isValid else { return destinationKind == .home ? .missingHome : .missingDestination }
        if destinationKind == .home { return nil }
        let age = now().timeIntervalSince(snapshot.recordedAt)
        return age > 300 || age < -60 ? .staleDestination : nil
    }
    func start(to snapshot: ElderLocationSnapshot?) async {
        end()
        isPresented = true; destination = snapshot; arrived = false; suspended = false; muted = false
        subscribe()
        await plan(to: snapshot)
    }
    private func subscribe() {
        let session = generation
        provider.startUpdates { [weak self] result in
            guard let self, self.generation == session, self.isPresented, !self.suspended, !self.arrived else { return }
            switch result {
            case .success(let fix): self.receive(fix)
            case .failure(let issue): self.issue = issue; self.resetEvidence(); self.voice.stop()
            }
        }
        provider.startHeadingUpdates { [weak self] sample in
            guard let self, self.generation == session, self.isPresented, !self.suspended, !self.arrived else { return }
            guard self.heading == nil || sample.timestamp > self.heading!.timestamp else { return }
            self.heading = sample.isUsable(at: self.now()) ? sample : nil
        }
    }
    func plan(to snapshot: ElderLocationSnapshot?) async {
        guard !loading else { return }
        destination = snapshot
        voice.stop()
        route = nil; estimatedArrival = nil; issue = validDestination(snapshot)
        guard issue == nil, let snapshot else { voice.stop(); return }
        let session = generation
        loading = true
        lastPlanningAt = now()
        defer { if generation == session { loading = false } }
        do {
            let source = try await provider.currentPoint()
            guard generation == session, !Task.isCancelled else { return }
            guard source.isValid else { throw NavigationIssue.locationUnavailable }
            let result = try await provider.route(from: source, to: snapshot.coordinate)
            guard generation == session, !Task.isCancelled else { return }
            if let failure = validDestination(destination) { issue = failure; return }
            guard result.coordinates.count > 1, result.distanceMeters.isFinite, result.distanceMeters > 0,
                  result.expectedSeconds.isFinite, result.expectedSeconds >= 0 else { throw NavigationIssue.routeUnavailable }
            issue = nil; route = result; plannedDestination = snapshot.coordinate
            routeVersion += 1; stepIndex = 0; spoken.removeAll(); resetEvidence()
            remainingMeters = result.distanceMeters; remainingSeconds = result.expectedSeconds
            estimatedArrival = now().addingTimeInterval(remainingSeconds)
            var fallbackEnd = 0.0
            stepEnds = result.segments.map { step in
                fallbackEnd += max(0, step.distanceMeters)
                return step.coordinates.last.flatMap { RouteProjection.project($0, onto: result.coordinates)?.along } ?? fallbackEnd
            }
            turnMeters = stepEnds.first ?? remainingMeters
            needsReplan = destination.map { Self.distance($0.coordinate, snapshot.coordinate) > 30 } ?? false
            if let fix, fix.isUsable(at: now()), !needsReplan { updateProgress(fix) }
        } catch is CancellationError {
        } catch let error as NavigationIssue {
            guard generation == session else { return }; issue = error; voice.stop()
        } catch {
            guard generation == session else { return }; issue = .routeUnavailable; voice.stop()
        }
    }
    func updateDestination(_ snapshot: ElderLocationSnapshot?) {
        guard isPresented, !arrived else { return }
        if destinationKind == .senior, let snapshot, let old = destination, snapshot.recordedAt <= old.recordedAt { return }
        let wasStale = validDestination(destination) != nil
        destination = snapshot
        if let failure = validDestination(snapshot) { issue = failure; resetEvidence(); voice.stop(); return }
        if wasStale || plannedDestination == nil || snapshot.map({ Self.distance($0.coordinate, plannedDestination!) > 30 }) == true {
            needsReplan = true
            voice.stop(); resetEvidence()
        }
        tick()
    }
    func receive(_ sample: NavigationFix) {
        guard isPresented, !suspended, !arrived else { return }
        if let fix, sample.timestamp <= fix.timestamp { return }
        fix = sample
        guard sample.isUsable(at: now()) else { issue = .locationUnavailable; resetEvidence(); voice.stop(); return }
        if issue == .locationUnavailable { issue = nil }
        tick()
        guard issue == nil, !loading, !needsReplan else { return }
        updateProgress(sample)
    }
    func tick() {
        guard isPresented, !suspended, !arrived else { return }
        if let failure = validDestination(destination) { issue = failure; resetEvidence(); voice.stop(); return }
        guard let fix, fix.isUsable(at: now()) else {
            if !loading {
                if issue == nil || issue == .locationUnavailable { issue = .locationUnavailable }
                resetEvidence(); voice.stop()
            }
            return
        }
        if issue == .staleDestination || issue == .missingDestination || issue == .missingHome { needsReplan = true }
        if needsReplan && !loading && now().timeIntervalSince(lastPlanningAt ?? .distantPast) >= 30 {
            scheduleReplan()
        }
    }
    private func scheduleReplan() {
        guard !loading, let destination else { return }
        needsReplan = false
        // Reserve the interval before scheduling to prevent multiple updates launching requests.
        lastPlanningAt = now()
        planningTask?.cancel()
        planningTask = Task { [weak self] in await self?.plan(to: destination) }
    }
    private func updateProgress(_ sample: NavigationFix) {
        guard let route, let destination,
              let projection = RouteProjection.project(sample.point.appleCoordinate, onto: route.coordinates) else { return }
        offRouteCount = projection.offRoute > 40 ? offRouteCount + 1 : 0
        if offRouteCount >= 3 { needsReplan = true; voice.stop(); tick(); return }
        guard projection.offRoute <= 40 else { arrivalCount = 0; return }
        arrivalCount = Self.distance(sample.point, destination.coordinate) <= 20 ? arrivalCount + 1 : 0
        if arrivalCount >= 3 {
            arrived = true; remainingMeters = 0; remainingSeconds = 0; estimatedArrival = now()
            provider.stopUpdates(); provider.cancelRoute(); voice.stop()
            if !muted { voice.speak(arrivalInstruction) }
            return
        }
        let ratio = projection.length > 0 ? min(1, max(0, projection.along / projection.length)) : 0
        remainingMeters = min(remainingMeters, route.distanceMeters * (1 - ratio))
        remainingSeconds = route.expectedSeconds * remainingMeters / route.distanceMeters
        estimatedArrival = now().addingTimeInterval(remainingSeconds)
        while stepEnds.indices.contains(stepIndex), stepIndex < route.steps.count - 1,
              projection.along >= stepEnds[stepIndex] - 5 { stepIndex += 1 }
        turnMeters = stepEnds.indices.contains(stepIndex) ? max(0, stepEnds[stepIndex] - projection.along) : remainingMeters
        announce(key: "\(routeVersion)-\(stepIndex)-start", text: instruction)
        if turnMeters <= 30 { announce(key: "\(routeVersion)-\(stepIndex)-near", text: "In \(Int(turnMeters.rounded())) meters. \(instruction)") }
    }
    private func announce(key: String, text: String) {
        guard !muted, !spoken.contains(key) else { return }
        spoken.insert(key); voice.speak(text)
    }
    func toggleMuted() { muted.toggle(); if muted { voice.stop() } }
    func pause() {
        guard isPresented else { return }
        voice.stop()
        guard !arrived else { return }
        generation += 1; heading = nil; suspended = true; loading = false; needsReplan = false
        planningTask?.cancel(); provider.stopUpdates(); provider.cancelRoute(); voice.stop(); resetEvidence()
    }
    func resume(to snapshot: ElderLocationSnapshot?) async {
        guard isPresented, suspended, !arrived else { return }
        suspended = false; fix = nil; subscribe(); await plan(to: snapshot)
    }
    func end() {
        generation += 1; isPresented = false; suspended = false; arrived = false
        planningTask?.cancel(); planningTask = nil; provider.stopUpdates(); provider.cancelRoute(); voice.stop()
        heading = nil; route = nil; estimatedArrival = nil; issue = nil; fix = nil; destination = nil; loading = false; needsReplan = false
        lastPlanningAt = nil; plannedDestination = nil; resetEvidence(); spoken.removeAll()
    }
    private func resetEvidence() { offRouteCount = 0; arrivalCount = 0 }
    private static func distance(_ a: GeoPoint, _ b: GeoPoint) -> Double {
        CLLocation(latitude: a.latitude, longitude: a.longitude).distance(from: CLLocation(latitude: b.latitude, longitude: b.longitude))
    }
    static func distanceText(_ meters: Double) -> String {
        meters >= 1000 ? String(format: "%.1f km", meters / 1000) : "\(Int(meters.rounded())) m"
    }
}

#if targetEnvironment(simulator)
/// Fixed road geometry for the simulator preview; never provides device GPS or an SDK route.
@MainActor final class PreviewWalkingRouteProvider: WalkingRouteProvider {
    private var updates: Task<Void, Never>?
    func currentPoint() async throws -> GeoPoint { LocationPreviewData.startingPoint }
    func route(from: GeoPoint, to: GeoPoint) async throws -> WalkingRoute {
        guard from == LocationPreviewData.startingPoint, to == LocationPreviewData.campus else {
            throw NavigationIssue.routeUnavailable
        }
        let points = LocationPreviewData.trail.map(\.appleCoordinate)
        let first = Array(points.prefix(4)), second = Array(points.dropFirst(3))
        func length(_ points: [CLLocationCoordinate2D]) -> Double {
            zip(points, points.dropFirst()).reduce(0) { sum, pair in
                sum + CLLocation(latitude: pair.0.latitude, longitude: pair.0.longitude)
                    .distance(from: CLLocation(latitude: pair.1.latitude, longitude: pair.1.longitude))
            }
        }
        let distance = length(points)
        let instructions = ["Turn right onto Ninghai Road", "Continue to the senior’s location"]
        return WalkingRoute(coordinates: points, distanceMeters: distance,
            expectedSeconds: distance / 1.2, steps: instructions,
            segments: [WalkingStep(instruction: instructions[0], coordinates: first, distanceMeters: length(first)),
                       WalkingStep(instruction: instructions[1], coordinates: second, distanceMeters: length(second))])
    }
    func startUpdates(_ receive: @escaping (Result<NavigationFix, NavigationIssue>) -> Void) {
        updates?.cancel()
        updates = Task { @MainActor in
            while !Task.isCancelled {
                receive(.success(NavigationFix(point: LocationPreviewData.startingPoint,
                    accuracy: 5, timestamp: Date(), course: 100)))
                do { try await Task.sleep(for: .seconds(1)) } catch { return }
            }
        }
    }
    func startHeadingUpdates(_ receive: @escaping (NavigationHeading) -> Void) {
        receive(NavigationHeading(degrees: 100, accuracy: 5, timestamp: Date()))
    }
    func stopUpdates() { updates?.cancel(); updates = nil }
    func cancelRoute() {}
}
#endif
