import XCTest
import SwiftUI
import CoreLocation
@testable import SafeOrbit

// Risk and alerts (task T38): elder auto-navigation, caregiver snapshot, settings sync, reference
// routes, notification routing and the risk event page.

@MainActor private final class ActionReporterSpy: ElderActionReporting {
    var reports: [(String, ActionResultBody)] = []
    var failure: Error?
    var log: (String) -> Void = { _ in }
    func report(_ actionID: String, _ body: ActionResultBody) async throws {
        if let failure { throw failure }
        reports.append((actionID, body)); log("report \(body.result)")
    }
}
@MainActor private final class ReminderSpy: ElderReminderSpeaking {
    var spoken: [String] = []
    var log: (String) -> Void = { _ in }
    func speak(_ text: String, volume: Float) async { spoken.append(text); log("speak") }
}
@MainActor private final class AudioStub: ElderAudioSessionControlling {
    var allows = true
    func activateForPrompts() -> Bool { allows }
}
@MainActor private final class NotifierSpy: ElderLocalNotifying {
    var posts = 0
    var log: (String) -> Void = { _ in }
    func postStartNavigationFallback() async { posts += 1; log("notify") }
}
@MainActor private final class RouteProviderStub: WalkingRouteProvider {
    var failure: NavigationIssue?
    func currentPoint() async throws -> GeoPoint {
        if let failure { throw failure }
        return LocationPreviewData.startingPoint
    }
    func route(from: GeoPoint, to: GeoPoint) async throws -> WalkingRoute {
        WalkingRoute(coordinates: [from.appleCoordinate, to.appleCoordinate], distanceMeters: 210, expectedSeconds: 180, steps: ["Continue straight"])
    }
}
@MainActor private final class PlannerSpy: ReferenceRoutePlanning {
    var calls: [(GeoPoint, GeoPoint)] = []
    var failure: Error?
    let points = [GeoPoint(latitude: 32.0621, longitude: 118.7613), GeoPoint(latitude: 32.0600, longitude: 118.7640),
                  GeoPoint(latitude: 32.0585, longitude: 118.7666)]
    func plan(from: GeoPoint, to: GeoPoint) async throws -> [GeoPoint] {
        calls.append((from, to))
        if let failure { throw failure }
        return points
    }
}
@MainActor private final class RiskClientSpy: RiskEventClient {
    var detailResult: RiskEventDetail
    var metResult: Result<RiskEventDetail, Error>
    var falseAlarmResult: Result<RiskEventDetail, Error>
    var calls: [String] = []
    init(detail: RiskEventDetail) {
        detailResult = detail; metResult = .success(detail); falseAlarmResult = .success(detail)
    }
    func detail(_ id: String) async throws -> RiskEventDetail { calls.append("detail \(id)"); return detailResult }
    func markMet(_ id: String) async throws -> RiskEventDetail { calls.append("met \(id)"); return try metResult.get() }
    func markFalseAlarm(_ id: String) async throws -> RiskEventDetail { calls.append("falseAlarm \(id)"); return try falseAlarmResult.get() }
    func recordCall(riskEventID: String?) async { calls.append("call \(riskEventID ?? "-")") }
}

final class RiskAlertsTests: XCTestCase {
    private var network: URLSession!
    private var defaults: UserDefaults!
    private var suite: String!

    override func setUp() {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [StubURLProtocol.self]
        network = URLSession(configuration: config)
        suite = "org.safeorbit.test.risk.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suite)
    }
    override func tearDown() {
        StubURLProtocol.handler = nil
        network.invalidateAndCancel()
        defaults.removePersistentDomain(forName: suite)
    }
    private var api: OnboardingAPI { OnboardingAPI(baseURL: URL(string: "http://localhost:3000")!, session: network) }
    private static let household = #"{"elder":{"name":"Li Lan","callName":"Grandma","phone":"+12025550100","timezone":"Asia/Shanghai"},"caregiver":{"name":"Wang Min","phone":"+12025550101"}}"#
    private static func registration(_ token: String, role: String) -> Data {
        Data(#"{"deviceToken":"\#(token)","role":"\#(role)","household":\#(household)}"#.utf8)
    }
    private static func decode<T: Decodable>(_ json: String, as type: T.Type = T.self) async throws -> T {
        StubURLProtocol.handler = { _ in (200, Data(json.utf8)) }
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [StubURLProtocol.self]
        let session = URLSession(configuration: config)
        defer { session.invalidateAndCancel() }
        return try await OnboardingAPI(baseURL: URL(string: "http://localhost:3000")!, session: session).request("x")
    }
    private static func body(of request: URLRequest) -> Data {
        if let body = request.httpBody { return body }
        guard let stream = request.httpBodyStream else { return Data() }
        stream.open(); defer { stream.close() }
        var data = Data()
        var buffer = [UInt8](repeating: 0, count: 4096)
        while stream.hasBytesAvailable {
            let read = stream.read(&buffer, maxLength: buffer.count)
            if read <= 0 { break }
            data.append(buffer, count: read)
        }
        return data
    }
    private static func json(_ data: Data) -> [String: Any] { (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] ?? [:] }
    @MainActor private func eventually(_ condition: () -> Bool) async {
        for _ in 0..<100 where !condition() { try? await Task.sleep(for: .milliseconds(20)) }
    }

    // MARK: Elder actions

    func testUploadReplyActionsDecodeAndOldRepliesStillDecode() async throws {
        let reply: LocationUploadReply = try await Self.decode(#"""
            {"results":[{"index":0,"status":"accepted"}],
             "actions":[{"id":"34","type":"startNavigation","riskEventId":"10","expiresAt":"2026-10-27T09:02:00.000Z"}]}
            """#)
        let action = try XCTUnwrap(reply.actions?.first)
        XCTAssertEqual(action.id, "34"); XCTAssertEqual(action.type, ElderAction.startNavigation)
        XCTAssertEqual(action.riskEventId, "10")
        XCTAssertEqual(action.expiresAt, ISO8601DateFormatter().date(from: "2026-10-27T09:02:00Z"))
        let old: LocationUploadReply = try await Self.decode(#"{"results":[{"index":0,"status":"accepted"}]}"#)
        XCTAssertNil(old.actions)
    }

    @MainActor func testElderReporterHandsUploadActionsToItsListener() async throws {
        let file = FileManager.default.temporaryDirectory.appendingPathComponent("fixes-\(UUID().uuidString).json")
        defer { try? FileManager.default.removeItem(at: file) }
        StubURLProtocol.handler = { request in
            switch request.url!.path {
            case "/v1/devices": return (200, Self.registration("elder", role: "elder"))
            case "/v1/safe-zones": return (200, Data(#"[{"id":"h","name":"Home","isHome":true,"center":{"latitude":32.0621,"longitude":118.7613},"radiusMeters":100}]"#.utf8))
            default: return (200, Data(#"{"results":[{"index":0,"status":"accepted"}],"actions":[{"id":"34","type":"startNavigation","riskEventId":"10","expiresAt":"2030-01-01T00:00:00Z"}]}"#.utf8))
            }
        }
        let queue = PendingFixQueue(file: file)
        queue.append([UploadPoint(sampledAt: Date(), latitude: 32.06, longitude: 118.76)])
        let reporter = ElderLocationReporter(device: DemoDevice(role: .elder, api: api, defaults: defaults), queue: queue)
        var received: [[ElderAction]] = []
        reporter.onActions = { received.append($0) }
        await reporter.flush()
        XCTAssertEqual(received.map { $0.map(\.id) }, [["34"]])
        XCTAssertEqual(reporter.household?.elder.callName, "Grandma")
        XCTAssertEqual(reporter.household?.caregiver.phone, "+12025550101")
    }

    @MainActor private func autoNavigation(start: String?, active: Bool = true, audible: Bool = true)
        -> (ElderAutoNavigation, ActionReporterSpy, ReminderSpy, NotifierSpy, () -> [String]) {
        var log: [String] = []
        let reporter = ActionReporterSpy(), voice = ReminderSpy(), notifier = NotifierSpy(), audio = AudioStub()
        audio.allows = audible
        reporter.log = { log.append($0) }; voice.log = { log.append($0) }; notifier.log = { log.append($0) }
        let auto = ElderAutoNavigation(reporter: reporter, voice: voice, audio: audio, notifier: notifier)
        auto.callName = "Grandma"
        auto.isAppActive = { active }
        auto.startNavigation = { log.append("start"); return start }
        return (auto, reporter, voice, notifier, { log })
    }
    // Computed: XCTest creates every test case object before the suite runs, long before some tests start.
    private var action: ElderAction {
        ElderAction(id: "34", type: ElderAction.startNavigation, riskEventId: "10", expiresAt: Date().addingTimeInterval(120))
    }

    @MainActor func testAutoNavigationSpeaksTheReminderStartsAndReportsEachActionOnce() async {
        let (auto, reporter, voice, notifier, log) = autoNavigation(start: nil)
        await auto.receive([action])
        await auto.receive([action])   // the same action repeats in the next upload reply
        XCTAssertEqual(voice.spoken, ["Grandma, let's go home."])
        XCTAssertEqual(log(), ["speak", "start", "report started"], "reminder first, then navigation, then the result")
        XCTAssertEqual(reporter.reports.map(\.0), ["34"])
        XCTAssertEqual(reporter.reports.first?.1, .started)
        XCTAssertEqual(notifier.posts, 0)
        XCTAssertEqual(auto.lastOutcome, .started)
        // A new id after expiry runs again.
        await auto.receive([ElderAction(id: "35", type: "startNavigation", riskEventId: "10", expiresAt: Date().addingTimeInterval(120))])
        XCTAssertEqual(reporter.reports.map(\.0), ["34", "35"])
        XCTAssertEqual(ElderAutoNavigation.reminder(callName: " "), "Let's go home.")
    }

    @MainActor func testAutoNavigationThatCannotPlanPostsTheFallbackAndReportsWhy() async {
        let reason = ElderAutoNavigation.reason(for: .sdkNotReady)
        let (auto, reporter, _, notifier, log) = autoNavigation(start: reason)
        await auto.receive([action])
        XCTAssertEqual(log(), ["speak", "start", "notify", "report failed"])
        XCTAssertEqual(notifier.posts, 1)
        XCTAssertEqual(reporter.reports.first?.1, .failed(reason))
        XCTAssertEqual(reporter.reports.first?.1.reason, "Route planning failed: map service unavailable on her phone")
        XCTAssertEqual(auto.lastOutcome, .failed(reason))
    }

    @MainActor func testInTheBackgroundWithoutAudioTheFallbackReplacesNavigation() async {
        let (auto, reporter, voice, notifier, log) = autoNavigation(start: nil, active: false, audible: false)
        await auto.receive([action])
        XCTAssertTrue(voice.spoken.isEmpty)
        XCTAssertFalse(log().contains("start"))
        XCTAssertEqual(notifier.posts, 1)
        XCTAssertEqual(reporter.reports.first?.1, .failed("App in the background could not speak"))

        let (background, backgroundReporter, backgroundVoice, _, _) = autoNavigation(start: nil, active: false, audible: true)
        await background.receive([action])
        XCTAssertEqual(backgroundVoice.spoken.count, 1, "background audio lets the reminder play")
        XCTAssertEqual(backgroundReporter.reports.first?.1, .started)
    }

    @MainActor func testExpiredOtherAndAlreadyRunningActions() async {
        let (auto, reporter, voice, _, _) = autoNavigation(start: nil)
        await auto.receive([ElderAction(id: "1", type: "startNavigation", riskEventId: nil, expiresAt: Date().addingTimeInterval(-1)),
                            ElderAction(id: "2", type: "somethingElse", riskEventId: nil, expiresAt: nil)])
        XCTAssertTrue(reporter.reports.isEmpty)
        auto.isNavigatingHome = { true }
        await auto.receive([action])
        XCTAssertTrue(voice.spoken.isEmpty, "already guiding her home")
        XCTAssertEqual(reporter.reports.first?.1, .started)
    }

    @MainActor func testResultsWaitWhileOfflineAndAreSentWhenTheActionRepeats() async {
        let (auto, reporter, voice, _, _) = autoNavigation(start: nil)
        reporter.failure = APIError(kind: .network)
        await auto.receive([action])
        XCTAssertEqual(auto.unreported["34"], .started)
        reporter.failure = nil
        await auto.receive([action])
        XCTAssertEqual(voice.spoken.count, 1, "not started a second time")
        XCTAssertEqual(reporter.reports.map(\.0), ["34"])
        XCTAssertNil(auto.unreported["34"])
        reporter.failure = APIError(kind: .invalidCode)   // withdrawn: nothing left to send
        await auto.receive([ElderAction(id: "36", type: "startNavigation", riskEventId: "10", expiresAt: Date().addingTimeInterval(60))])
        XCTAssertNil(auto.unreported["36"])
        XCTAssertEqual(ActionResultBody.failed(String(repeating: "x", count: 300)).reason?.count, 200)
    }

    @MainActor func testActionResultIsPostedToTheCareAPI() async throws {
        var posted: (String, [String: Any])?
        StubURLProtocol.handler = { request in
            if request.url?.path == "/v1/devices" { return (200, Self.registration("elder", role: "elder")) }
            posted = (request.url!.path, Self.json(Self.body(of: request)))
            return (200, Data(#"{"id":"34","status":"failed"}"#.utf8))
        }
        try await DeviceActionReporter(device: DemoDevice(role: .elder, api: api, defaults: defaults)).report("34", .failed("No route"))
        XCTAssertEqual(posted?.0, "/v1/actions/34/result")
        XCTAssertEqual(posted?.1["result"] as? String, "failed")
        XCTAssertEqual(posted?.1["reason"] as? String, "No route")
    }

    @MainActor func testHomeNavigationStartReportsRouteOrReason() async throws {
        let name = "risk-home-" + UUID().uuidString
        let homeDefaults = try XCTUnwrap(UserDefaults(suiteName: name))
        defer { homeDefaults.removePersistentDomain(forName: name) }
        let provider = RouteProviderStub()
        let live = ElderLiveNavigation(home: HomeLocationStore(defaults: homeDefaults), provider: provider, navigationProvider: provider)
        let session = ElderDemoSession(usesLiveNavigation: true)
        let missing = await ElderHomePage.startNavigationHome(live: live, session: session)
        XCTAssertEqual(missing, "No home location on her phone")
        XCTAssertFalse(live.showingHomeSetup, "an automatic start never opens the home setup")
        live.home.save(LocationPreviewData.campus)
        let started = await ElderHomePage.startNavigationHome(live: live, session: session)
        XCTAssertNil(started)
        XCTAssertTrue(session.navigating); XCTAssertNotNil(live.navigation.route)
        live.cancel()
        provider.failure = .sdkNotReady
        let failed = await ElderHomePage.startNavigationHome(live: live, session: session)
        XCTAssertEqual(failed, "Route planning failed: map service unavailable on her phone")
        XCTAssertTrue(live.navigation.isPresented, "the guidance card shows why it could not start")
        live.stop()
    }

    // MARK: Caregiver snapshot

    func testSnapshotDecodesRiskFieldsAndOlderShapes() async throws {
        let live: ElderLocationSnapshot = try await Self.decode(#"""
            {"coordinate":{"latitude":32.0585,"longitude":118.7666},"recordedAt":"2026-10-27T09:00:00.123Z","heading":null,
             "status":"Out","batteryPercent":64,"address":null,"phase":"trip","tripName":null,
             "trail":[{"latitude":32.0621,"longitude":118.7613}],
             "safeZones":[{"id":"6f1c0b0e-0000-4000-8000-000000000001","name":"Home","isHome":true,"center":{"latitude":32.0621,"longitude":118.7613},"radiusMeters":100}],
             "riskLevel":"warning","riskHeadline":"Wandering for 7 minutes","riskAnomaly":"wandering",
             "riskSince":"2026-10-27T08:53:00.000Z","riskEventId":"15","riskEventStatus":"active",
             "agentStatus":"Learning daily routes (2/5 trips)"}
            """#)
        XCTAssertEqual(live.riskState, .warning)
        XCTAssertEqual(live.riskHeadline, "Wandering for 7 minutes")
        XCTAssertEqual(live.riskEventId, "15"); XCTAssertEqual(live.riskEventStatus, "active")
        XCTAssertEqual(live.agentStatus, "Learning daily routes (2/5 trips)")
        XCTAssertNotNil(live.riskSince)
        XCTAssertEqual(live.safeZones.first?.isHomeZone, true)
        let resolved: ElderLocationSnapshot = try await Self.decode(#"""
            {"coordinate":{"latitude":32.0585,"longitude":118.7666},"recordedAt":"2026-10-27T09:00:00Z","heading":90,"status":"At Home",
             "batteryPercent":null,"address":null,"trail":[],"safeZones":[],"riskLevel":"normal","riskHeadline":null,"riskAnomaly":null,
             "riskSince":null,"riskEventId":"15","riskEventStatus":"resolved","agentStatus":"Monitoring"}
            """#)
        XCTAssertEqual(resolved.riskState, .normal)
        XCTAssertEqual(resolved.riskEventId, "15", "a recently resolved event stays reachable for Mark as False Alarm")
        // T37 replies and the fixed sample have no risk fields: normal, no event, no status line.
        let old: ElderLocationSnapshot = try await Self.decode(#"""
            {"coordinate":{"latitude":32.0585,"longitude":118.7666},"recordedAt":"2026-10-26T09:00:00.123Z","heading":180,
             "status":"At Market","batteryPercent":64,"address":null,"trail":[],
             "safeZones":[{"id":"z","name":"Home","center":{"latitude":32.0621,"longitude":118.7613},"radiusMeters":100}]}
            """#)
        XCTAssertEqual(old.riskState, .normal)
        XCTAssertNil(old.riskEventId); XCTAssertNil(old.agentStatus)
        XCTAssertEqual(old.safeZones.first?.isHomeZone, true)
        let sample = LocationPreviewData.snapshot()
        XCTAssertEqual(sample.riskState, .normal); XCTAssertNil(sample.riskEventId)
        XCTAssertEqual(ElderLocationSnapshot(coordinate: sample.coordinate, recordedAt: Date(), heading: nil, status: nil, batteryPercent: nil,
                                             address: nil, trail: [], safeZones: [], riskLevel: "high").riskState, .high)
    }

    // MARK: Settings sync

    @MainActor func testSettingsFollowTheServerAndSwitchChangesAreSent() async throws {
        var puts: [[String: Any]] = []
        var failPuts = false
        var server: [String: Bool] = ["autoNavigation": false, "lowRiskNotifications": true,
                                      "recoveryNotifications": false, "limitedMonitoringNotifications": true]
        StubURLProtocol.handler = { request in
            switch (request.httpMethod!, request.url!.path) {
            case ("POST", "/v1/devices"): return (200, Self.registration("cg", role: "caregiver"))
            case ("PUT", "/v1/caregiver-settings"):
                if failPuts { throw URLError(.notConnectedToInternet) }
                let change = Self.json(Self.body(of: request)); puts.append(change)
                for (key, value) in change { server[key] = value as? Bool }
                return (200, try JSONSerialization.data(withJSONObject: server))
            default: return (200, try JSONSerialization.data(withJSONObject: server))
            }
        }
        let settings = CaregiverSettingsStore(defaults: defaults)
        XCTAssertTrue(settings.data.autoNavigation)
        let sync = CaregiverSettingsSync(device: DemoDevice(role: .caregiver, api: api, defaults: defaults), settings: settings)
        await sync.sync()
        XCTAssertFalse(settings.data.autoNavigation, "launch takes the server's switches")
        XCTAssertFalse(settings.data.recoveryNotifications)
        XCTAssertTrue(puts.isEmpty)

        settings.set(\.autoNavigation, true)
        await eventually { puts.count == 1 }
        XCTAssertEqual(puts.first as? [String: Bool], ["autoNavigation": true], "one changed switch, partial update")
        settings.set(\.allowAITripHistory, false)
        try await Task.sleep(for: .milliseconds(100))
        XCTAssertEqual(puts.count, 1, "phone-only settings stay on the phone")

        failPuts = true
        settings.set(\.lowRiskNotifications, false)
        await eventually { sync.pendingUpload }
        XCTAssertTrue(sync.pendingUpload)
        failPuts = false
        await sync.sync()   // e.g. back in the foreground
        XCTAssertEqual(puts.last as? [String: Bool], ["autoNavigation": true, "lowRiskNotifications": false,
                                                      "recoveryNotifications": false, "limitedMonitoringNotifications": true])
        XCTAssertFalse(sync.pendingUpload)
        XCTAssertFalse(settings.data.lowRiskNotifications)
    }

    // MARK: Reference routes

    func testReferenceRouteConvertsMapCoordinatesBackToWGS84AndStaysWithinTheLimit() {
        let wgs = [GeoPoint(latitude: 32.0621, longitude: 118.7613), GeoPoint(latitude: 32.0585, longitude: 118.7666)]
        let converted = ReferenceRoute.wgs84(wgs.map(\.appleCoordinate))
        for (a, b) in zip(converted, wgs) {
            XCTAssertEqual(a.latitude, b.latitude, accuracy: 1e-6); XCTAssertEqual(a.longitude, b.longitude, accuracy: 1e-6)
        }
        XCTAssertNotEqual(wgs[0].appleCoordinate.latitude, wgs[0].latitude, "the map coordinate differs in mainland China")
        let long = (0..<12_000).map { CLLocationCoordinate2D(latitude: 32 + Double($0) * 1e-6, longitude: 118.7) }
        let thinned = ReferenceRoute.wgs84(long)
        XCTAssertEqual(thinned.count, ReferenceRoute.maxPoints)
        XCTAssertEqual(thinned.first, ReferenceRoute.wgs84([long[0]]).first)
        XCTAssertEqual(thinned.last, ReferenceRoute.wgs84([long[long.count - 1]]).first)
    }

    @MainActor func testNewAndMovedZonesUploadAPlannedRouteFromHome() async throws {
        let home = #"{"id":"h1","name":"Home","isHome":true,"center":{"latitude":32.0621,"longitude":118.7613},"radiusMeters":100}"#
        var market = #"{"id":"m1","name":"Market","isHome":false,"center":{"latitude":32.0585,"longitude":118.7666},"radiusMeters":200}"#
        var zones = [home]
        var routes: [(String, [String: Any])] = []
        StubURLProtocol.handler = { request in
            switch (request.httpMethod!, request.url!.path) {
            case ("POST", "/v1/devices"): return (200, Self.registration("cg", role: "caregiver"))
            case ("GET", "/v1/location"):
                return (200, Data(#"{"coordinate":{"latitude":32.0585,"longitude":118.7666},"recordedAt":"2026-10-27T09:00:00Z","heading":null,"status":"Out","batteryPercent":null,"address":null,"trail":[],"safeZones":[\#(zones.joined(separator: ","))]}"#.utf8))
            case ("PUT", let path) where path.hasSuffix("/route"):
                routes.append((path, Self.json(Self.body(of: request))))
                return (200, Data(#"{"zoneId":"m1","pointCount":3,"uploadedAt":"2026-10-27T09:00:00Z"}"#.utf8))
            case ("POST", "/v1/safe-zones"):
                zones = [home, market]; return (200, Data(market.utf8))
            case ("PUT", "/v1/safe-zones/h1"): return (200, Data(home.utf8))
            default:
                let body = Self.json(Self.body(of: request))
                let center = body["center"] as! [String: Double]
                market = #"{"id":"m1","name":"Market","isHome":false,"center":{"latitude":\#(center["latitude"]!),"longitude":\#(center["longitude"]!)},"radiusMeters":200}"#
                zones = [home, market]; return (200, Data(market.utf8))
            }
        }
        let planner = PlannerSpy()
        let store = OnboardingStore(api: api, device: DemoDevice(role: .caregiver, api: api, defaults: defaults), routePlanner: planner)
        await store.refreshLocation()
        let marketCenter = GeoPoint(latitude: 32.0585, longitude: 118.7666)
        try await store.persistZone(.save(SafeZone(id: "local-new", name: "Market", center: marketCenter, radiusMeters: 200)))
        XCTAssertEqual(planner.calls.first?.0, GeoPoint(latitude: 32.0621, longitude: 118.7613), "routes start at home")
        XCTAssertEqual(planner.calls.first?.1, marketCenter)
        XCTAssertEqual(routes.map(\.0), ["/v1/safe-zones/m1/route"])
        let uploaded = (routes.first?.1["points"] as? [[String: Double]])?.map { GeoPoint(latitude: $0["latitude"]!, longitude: $0["longitude"]!) }
        XCTAssertEqual(uploaded, planner.points)

        try await store.persistZone(.save(SafeZone(id: "m1", name: "Market Street", center: marketCenter, radiusMeters: 500)))
        XCTAssertEqual(routes.count, 1, "renaming or resizing keeps the route")
        let moved = GeoPoint(latitude: 32.0570, longitude: 118.7690)
        try await store.persistZone(.save(SafeZone(id: "m1", name: "Market", center: moved, radiusMeters: 200)))
        XCTAssertEqual(routes.count, 2, "a moved zone gets a new route")
        XCTAssertEqual(planner.calls.last?.1, moved)
        try await store.persistZone(.save(SafeZone(id: "h1", name: "Home", center: GeoPoint(latitude: 32.0622, longitude: 118.7614), radiusMeters: 100)))
        XCTAssertEqual(routes.count, 2, "Home has no route of its own")

        planner.failure = NavigationIssue.sdkNotReady   // the simulator has no AMap planning
        try await store.persistZone(.save(SafeZone(id: "m1", name: "Market", center: marketCenter, radiusMeters: 200)))
        XCTAssertEqual(routes.count, 2)
        XCTAssertNil(store.locationError, "nothing alarming is shown")
    }

    // MARK: Notifications

    @MainActor func testNotificationTapsOpenTheRightPage() {
        XCTAssertEqual(NotificationRoute.from(userInfo: ["kind": "riskLow", "riskEventId": "15"]), .location)
        XCTAssertEqual(NotificationRoute.from(userInfo: ["kind": "riskResolved", "riskEventId": "15"]), .location)
        XCTAssertEqual(NotificationRoute.from(userInfo: ["kind": "riskHigh", "riskEventId": "15"]), .riskEvent("15"))
        XCTAssertEqual(NotificationRoute.from(userInfo: ["kind": "riskHigh"]), .location)
        XCTAssertEqual(NotificationRoute.from(userInfo: ["kind": ElderFallbackNotification.kind]), .elderStartNavigation)
        XCTAssertNil(NotificationRoute.from(userInfo: ["aps": ["alert": "x"]]))
        XCTAssertEqual(NotificationRoute.riskEvent("1").role, .caregiver)
        XCTAssertEqual(NotificationRoute.elderStartNavigation.role, .elder)

        let router = NotificationRouter()
        router.open(.riskEvent("15"))
        XCTAssertNil(router.take(for: .elder), "an elder page leaves caregiver taps alone")
        XCTAssertEqual(router.take(for: .caregiver), .riskEvent("15"))
        XCTAssertNil(router.pending)
        router.receive(deviceToken: Data([0x0a, 0xff, 0x01]))
        XCTAssertEqual(router.pushToken, "0aff01")
    }

    /// Pages read the router on the next main-queue turn: @Published sends before it stores the value.
    @MainActor func testPagesTakeATappedRouteOnce() async {
        let router = NotificationRouter()
        var taken: [NotificationRoute] = []
        let subscription = router.$pending.receive(on: DispatchQueue.main).sink { _ in
            if let route = router.take(for: .caregiver) { taken.append(route) }
        }
        router.open(.riskEvent("15"))
        await eventually { !taken.isEmpty }
        try? await Task.sleep(for: .milliseconds(100))
        XCTAssertEqual(taken, [.riskEvent("15")])
        XCTAssertNil(router.pending)
        subscription.cancel()
    }

    func testPushLocalizationKeysShipWithTheApp() {
        let expected = ["PUSH_RISK_LOW_TITLE": "%@ may need help",
                        "PUSH_RISK_LOW_WANDERING_NAV": "Wandering for %@ minutes. Starting navigation home for her.",
                        "PUSH_RISK_LOW_WANDERING": "Wandering for %@ minutes.",
                        "PUSH_RISK_LOW_DEVIATION_NAV": "Off her usual route for %@ minutes. Starting navigation home for her.",
                        "PUSH_RISK_LOW_DEVIATION": "Off her usual route for %@ minutes.",
                        "PUSH_RISK_HIGH_TITLE": "High risk: %@ needs you",
                        "PUSH_RISK_HIGH_WANDERING": "Still wandering after %@ minutes. Open to call her.",
                        "PUSH_RISK_HIGH_DEVIATION": "Still off her route after %@ minutes. Open to call her.",
                        "PUSH_RISK_RESOLVED_TITLE": "%@ is safe",
                        "PUSH_RISK_RESOLVED_HOME": "She is back home. The risk is resolved.",
                        "PUSH_RISK_RESOLVED_MET": "You've met her. The risk is resolved."]
        for (key, text) in expected {
            XCTAssertEqual(Bundle.main.localizedString(forKey: key, value: "missing", table: nil), text, key)
        }
    }

    @MainActor func testPushTokenIsSentWithARegistration() async {
        var bodies: [[String: Any]] = []
        StubURLProtocol.handler = { request in
            bodies.append(Self.json(Self.body(of: request)))
            return (200, Self.registration("cg-\(bodies.count)", role: "caregiver"))
        }
        let device = DemoDevice(role: .caregiver, api: api, defaults: defaults)
        let store = OnboardingStore(api: api, device: device, routePlanner: PlannerSpy())
        await store.registerPushToken("0aff01" + String(repeating: "ab", count: 16))
        await store.registerPushToken("0aff01" + String(repeating: "ab", count: 16))
        XCTAssertEqual(bodies.count, 1, "the same token is sent once")
        XCTAssertEqual(bodies.first?["pushToken"] as? String, "0aff01" + String(repeating: "ab", count: 16))
        XCTAssertEqual(bodies.first?["role"] as? String, "caregiver")
        XCTAssertEqual(device.token, "cg-1")
    }

    // MARK: Risk event page

    private static let activeDetail = #"""
        {"id":"15","level":"high","status":"active","anomaly":"wandering","headline":"Wandering for 16 minutes","durationMinutes":16,
         "anomalyStartedAt":"2026-10-27T08:44:00.000Z","openedAt":"2026-10-27T08:51:00.000Z","escalatedAt":"2026-10-27T08:59:00.000Z",
         "resolvedAt":null,"resolution":null,"falseAlarm":false,"canMarkFalseAlarm":false,"explanation":null,
         "coordinate":{"latitude":32.0585,"longitude":118.7666},"recordedAt":"2026-10-27T09:00:00.000Z",
         "trail":[{"latitude":32.0621,"longitude":118.7613},{"latitude":32.0585,"longitude":118.7666}],
         "help":[{"kind":"navigation","status":"failed","text":"Navigation home could not start (Route planning failed)","at":"2026-10-27T08:51:05.000Z"},
                 {"kind":"highRiskAlert","status":"notConfigured","text":"Urgent alert not sent: push is not configured","at":"2026-10-27T08:59:00.000Z"}],
         "timeline":[{"at":"2026-10-27T08:44:00.000Z","kind":"anomalyStarted","text":"Started wandering"},
                     {"at":"2026-10-27T08:59:00.000Z","kind":"highRisk","text":"High risk: wandering for 15 minutes"}],
         "transitions":[{"seq":1,"kind":"opened","fromLevel":null,"toLevel":"warning","at":"2026-10-27T08:51:00.000Z"}],
         "actions":[{"id":"34","type":"startNavigation","status":"failed","reason":"Route planning failed","decidedAt":"2026-10-27T08:51:00.000Z",
                     "createdAt":"2026-10-27T08:51:00.000Z","expiresAt":"2026-10-27T08:53:00.000Z","deliveredAt":"2026-10-27T08:51:03.000Z",
                     "resultAt":"2026-10-27T08:51:05.000Z","deliveries":[{"channel":"uploadReply","result":"included","detail":null,"at":"2026-10-27T08:51:03.000Z"}]}],
         "observations":[{"kind":"wandering","startedAt":"2026-10-27T08:44:00.000Z","endedAt":null,"features":{"pathMeters":210}}]}
        """#

    func testRiskEventDetailDecodesAndDecidesWhichButtonsShow() async throws {
        let active: RiskEventDetail = try await Self.decode(Self.activeDetail)
        XCTAssertEqual(active.riskState, .high)
        XCTAssertEqual(active.help.map(\.text).first, "Navigation home could not start (Route planning failed)")
        XCTAssertEqual(active.timeline.count, 2)
        XCTAssertEqual(active.trail.count, 2)
        XCTAssertEqual(active.anomalyText, "Wandering"); XCTAssertEqual(active.durationText, "16 minutes")
        XCTAssertTrue(active.canMarkMet); XCTAssertFalse(active.canMarkFalseAlarm)
        XCTAssertEqual(active.statusText, "In progress")
        let resolvedJSON = Self.activeDetail.replacingOccurrences(of: #""status":"active""#, with: #""status":"resolved""#)
            .replacingOccurrences(of: #""resolvedAt":null,"resolution":null"#, with: #""resolvedAt":"2026-10-27T09:01:00.000Z","resolution":"met""#)
            .replacingOccurrences(of: #""canMarkFalseAlarm":false"#, with: #""canMarkFalseAlarm":true"#)
        let resolved: RiskEventDetail = try await Self.decode(resolvedJSON)
        XCTAssertFalse(resolved.canMarkMet); XCTAssertTrue(resolved.canMarkFalseAlarm)
        XCTAssertEqual(resolved.statusText, "Resolved · you met her")
        let marked: RiskEventDetail = try await Self.decode(resolvedJSON
            .replacingOccurrences(of: #""falseAlarm":false"#, with: #""falseAlarm":true"#)
            .replacingOccurrences(of: #""canMarkFalseAlarm":true"#, with: #""canMarkFalseAlarm":false"#))
        XCTAssertFalse(marked.canMarkMet); XCTAssertFalse(marked.canMarkFalseAlarm)
        XCTAssertEqual(marked.statusText, "Resolved · marked as false alarm")
        let deviation: RiskEventDetail = try await Self.decode(Self.activeDetail.replacingOccurrences(of: #""anomaly":"wandering""#, with: #""anomaly":"deviation""#)
            .replacingOccurrences(of: #""level":"high""#, with: #""level":"warning""#))
        XCTAssertEqual(deviation.anomalyText, "Off her usual route"); XCTAssertEqual(deviation.riskState, .warning)
    }

    @MainActor func testRiskEventActionsUseTheCareAPI() async throws {
        var requests: [(String, String, [String: Any])] = []
        let resolved = Self.activeDetail.replacingOccurrences(of: #""status":"active""#, with: #""status":"resolved""#)
            .replacingOccurrences(of: #""canMarkFalseAlarm":false"#, with: #""canMarkFalseAlarm":true"#)
        var metStatus = 200
        StubURLProtocol.handler = { request in
            let path = request.url!.path
            requests.append((request.httpMethod!, path, Self.json(Self.body(of: request))))
            switch path {
            case "/v1/devices": return (200, Self.registration("cg", role: "caregiver"))
            case "/v1/risk-events/15/met": return (metStatus, Data((metStatus == 200 ? resolved : "{}").utf8))
            case "/v1/calls": return (201, Data(#"{"id":"3","at":"2026-10-27T09:00:00Z","riskEventId":"15"}"#.utf8))
            default: return (200, Data(Self.activeDetail.utf8))
            }
        }
        let store = RiskEventStore(id: "15", client: DeviceRiskEventClient(device: DemoDevice(role: .caregiver, api: api, defaults: defaults)))
        await store.load()
        XCTAssertEqual(store.detail?.isActive, true)
        await store.recordCall()
        XCTAssertEqual(requests.last?.1, "/v1/calls")
        XCTAssertEqual(requests.last?.2["riskEventId"] as? String, "15")
        await store.markMet()
        XCTAssertEqual(requests.last.map { "\($0.0) \($0.1)" }, "POST /v1/risk-events/15/met")
        XCTAssertEqual(store.detail?.canMarkFalseAlarm, true)
        XCTAssertNil(store.error)

        metStatus = 409   // already resolved elsewhere: show the latest
        await store.markMet()
        XCTAssertEqual(requests.last.map { "\($0.0) \($0.1)" }, "GET /v1/risk-events/15")
        XCTAssertEqual(store.error, "This risk has already changed. Showing the latest.")
    }

    @MainActor func testRiskEventStoreWithDoubles() async {
        let client = RiskClientSpy(detail: RiskEventPreviewData.detail())
        client.falseAlarmResult = .failure(APIError(kind: .invalidCode))
        let store = RiskEventStore(id: "15", client: client)
        await store.markFalseAlarm()
        XCTAssertEqual(client.calls, ["falseAlarm 15", "detail 15"], "rejected before resolution, then reloaded")
        XCTAssertNotNil(store.error)
        let offline = RiskEventStore(id: "15", client: nil)
        await offline.load()
        XCTAssertEqual(offline.error, "Risk details are unavailable.")
    }

    /// Event page and live risk location page at the product design widths, default size and AX1:
    /// content on the 16 pt margins and buttons at least 44 pt tall (section 10).
    @MainActor func testRiskEventPageLayoutAndSnapshots() async throws {
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.first as? UIWindowScene)
        let previous = scene.windows.first(where: \.isKeyWindow)
        let folder = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent("FrontendSnapshots")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        var profile = ElderProfile(); profile.name = "Li Lan"; profile.phone = "+12025550100"
        let widths: [CGFloat] = [320, 375, 390, 393, 402, 430]
        for width in widths {
            for type in [DynamicTypeSize.large, .accessibility1] {
                for status in ["active", "resolved"] {
                    let detail = RiskEventPreviewData.detail(status: status, level: "high", canMarkFalseAlarm: status == "resolved")
                    let size = CGSize(width: width, height: width < 375 ? 568 : 852)
                    LayoutProbe.frames = [:]
                    let window = UIWindow(windowScene: scene)
                    window.frame = CGRect(origin: .zero, size: size)
                    window.rootViewController = UIHostingController(rootView:
                        RiskEventPage(store: RiskEventStore(id: "15", client: nil, detail: detail), profile: profile, navigate: {}, back: {})
                            .environment(\.dynamicTypeSize, type).environment(\.colorScheme, .light))
                    window.makeKeyAndVisible()
                    window.rootViewController?.view.frame = window.bounds
                    window.rootViewController?.view.layoutIfNeeded()
                    try await Task.sleep(for: .milliseconds(width == 402 || width == 320 ? 1500 : 300))
                    let name = "risk-event-\(status)-\(Int(width))-\(type == .large ? "default" : "ax1")"
                    let content = try XCTUnwrap(LayoutProbe.frames["settings-content"], name)
                    XCTAssertEqual(content.minX, OrbitLayout.pageMargin, accuracy: 1, name)
                    XCTAssertEqual(content.maxX, width - OrbitLayout.pageMargin, accuracy: 1, name)
                    var buttons = ["risk-event-call", "risk-event-navigate"]
                    buttons.append(status == "active" ? "risk-event-met" : "risk-event-false-alarm")
                    for button in buttons {
                        let frame = try XCTUnwrap(LayoutProbe.frames[button], "\(name) \(button)")
                        XCTAssertGreaterThanOrEqual(frame.height, OrbitLayout.minimumHitSize, "\(name) \(button)")
                        XCTAssertGreaterThanOrEqual(frame.minX, OrbitLayout.pageMargin - 0.5, "\(name) \(button)")
                        XCTAssertLessThanOrEqual(frame.maxX, width - OrbitLayout.pageMargin + 0.5, "\(name) \(button)")
                    }
                    XCTAssertNil(LayoutProbe.frames[status == "active" ? "risk-event-false-alarm" : "risk-event-met"], name)
                    if width == 402 || (width == 320 && type == .accessibility1) {
                        let image = UIGraphicsImageRenderer(size: size).image { _ in
                            window.rootViewController!.view.drawHierarchy(in: window.bounds, afterScreenUpdates: true)
                        }
                        let data = try XCTUnwrap(image.pngData())
                        try data.write(to: folder.appendingPathComponent("\(name).png"))
                        let attachment = XCTAttachment(data: data, uniformTypeIdentifier: "public.png")
                        attachment.name = name; attachment.lifetime = .keepAlways; add(attachment)
                    }
                    window.isHidden = true
                    previous?.makeKeyAndVisible()
                }
            }
        }
        // Location page with the care agent's level, reason and status line from a live snapshot.
        var live = LocationPreviewData.snapshot()
        live.riskLevel = "warning"; live.riskHeadline = "Off route for 7 minutes"; live.riskEventId = "15"
        live.agentStatus = "Learning daily routes (2/5 trips)"
        let window = UIWindow(windowScene: scene)
        window.frame = CGRect(x: 0, y: 0, width: 402, height: 874)
        window.rootViewController = UIHostingController(rootView: ZStack {
            LocationPage(profile: profile, snapshot: live, message: nil, agent: {}, navigate: {}, riskState: live.riskState,
                         openRiskEvent: {})
            VStack { Spacer(); CaregiverTabBar(selection: .constant(.location)) }
        }.environment(\.colorScheme, .light))
        window.makeKeyAndVisible()
        window.rootViewController?.view.frame = window.bounds
        window.rootViewController?.view.layoutIfNeeded()
        try await Task.sleep(for: .milliseconds(2500))
        let image = UIGraphicsImageRenderer(size: window.bounds.size).image { _ in
            window.rootViewController!.view.drawHierarchy(in: window.bounds, afterScreenUpdates: true)
        }
        let data = try XCTUnwrap(image.pngData())
        try data.write(to: folder.appendingPathComponent("location-live-warning.png"))
        let attachment = XCTAttachment(data: data, uniformTypeIdentifier: "public.png")
        attachment.name = "location-live-warning"; attachment.lifetime = .keepAlways; add(attachment)
        window.isHidden = true
        previous?.makeKeyAndVisible()
    }
}
