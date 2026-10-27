import XCTest
@testable import SafeOrbit

/// Live Demo backend wiring (task T37): device registration, caregiver refresh, safe zone sync, elder uploads.
final class DemoBackendTests: XCTestCase {
    private var network: URLSession!
    private var defaults: UserDefaults!
    private var suite: String!

    override func setUp() {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [StubURLProtocol.self]
        network = URLSession(configuration: config)
        suite = "org.safeorbit.test.\(UUID().uuidString)"
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
    private static let snapshot = Data(#"""
        {"coordinate":{"latitude":32.0585,"longitude":118.7666},"recordedAt":"2026-10-26T09:00:00.123Z","heading":180,
         "status":"At Market","batteryPercent":64,"address":null,"phase":"trip","tripName":"Home–Market",
         "trail":[{"latitude":32.0621,"longitude":118.7613},{"latitude":32.0585,"longitude":118.7666}],
         "safeZones":[{"id":"6f1c0b0e-0000-4000-8000-000000000001","name":"Home","isHome":true,"center":{"latitude":32.0621,"longitude":118.7613},"radiusMeters":100}]}
        """#.utf8)

    @MainActor func testPhoneRegistersItsRoleWithAStableInstallationAndRegistersAgainAfterRejection() async throws {
        var registrations: [[String: String]] = []
        var calls = 0
        StubURLProtocol.handler = { request in
            if request.url?.path == "/v1/devices" {
                registrations.append(try JSONDecoder().decode([String: String].self, from: Self.body(of: request)))
                return (200, Self.registration("token-\(registrations.count)", role: "elder"))
            }
            calls += 1
            XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer token-\(registrations.count)")
            return calls == 1 ? (401, Data()) : (200, Data("[]".utf8))
        }
        let device = DemoDevice(role: .elder, api: api, defaults: defaults)
        do { let _: [RemoteSafeZone] = try await device.request("safe-zones"); XCTFail("Expected rejection") }
        catch let error as APIError { XCTAssertEqual(error.kind, .unauthorized) }
        XCTAssertNil(device.token)
        let zones: [RemoteSafeZone] = try await device.request("safe-zones")
        XCTAssertEqual(zones, [])
        XCTAssertEqual(registrations.count, 2)
        XCTAssertEqual(registrations.map { $0["role"] }, ["elder", "elder"])
        XCTAssertEqual(Set(registrations.map { $0["installationId"] }).count, 1)
        XCTAssertEqual(device.installationID, registrations[0]["installationId"])
    }

    @MainActor func testCaregiverPageLoadsTheHouseholdAndLiveLocation() async throws {
        var paths: [String] = []
        StubURLProtocol.handler = { request in
            paths.append(request.url!.path)
            return request.url?.path == "/v1/devices" ? (200, Self.registration("cg", role: "caregiver")) : (200, Self.snapshot)
        }
        let store = OnboardingStore(api: api, device: DemoDevice(role: .caregiver, api: api, defaults: defaults))
        XCTAssertEqual(store.screen, .caregiverHome)
        XCTAssertFalse(store.previewSession)
        await store.refreshLocation()
        XCTAssertEqual(paths, ["/v1/devices", "/v1/location"])
        XCTAssertEqual(store.elder.callName, "Grandma")
        XCTAssertEqual(store.elder.phone, "+12025550100")
        XCTAssertEqual(store.location?.status, "At Market")
        XCTAssertEqual(store.location?.trail.count, 2)
        XCTAssertNil(store.locationError)
        await store.refreshLocation()
        XCTAssertEqual(paths.filter { $0 == "/v1/devices" }.count, 1, "registered once, then reuses the token")
    }

    @MainActor func testCaregiverExplainsAWaitingPhoneAndAMissingServer() async {
        StubURLProtocol.handler = { request in
            request.url?.path == "/v1/devices" ? (200, Self.registration("cg", role: "caregiver")) : (404, Data())
        }
        let store = OnboardingStore(api: api, device: DemoDevice(role: .caregiver, api: api, defaults: defaults))
        await store.refreshLocation()
        XCTAssertNil(store.location)
        XCTAssertEqual(store.locationError, "Waiting for the senior's phone to share its location.")
        StubURLProtocol.handler = { _ in throw URLError(.cannotConnectToHost) }
        await store.refreshLocation()
        XCTAssertEqual(store.locationError, "Can't reach the SafeOrbit server. Check that this phone is on the same Wi-Fi as the computer.")
    }

    @MainActor func testSafeZoneEditsAreStoredOnTheServerAndConflictsExplained() async throws {
        var requests: [(String, String, Data)] = []
        StubURLProtocol.handler = { request in
            requests.append((request.httpMethod!, request.url!.path, Self.body(of: request)))
            switch (request.httpMethod!, request.url!.path) {
            case ("POST", "/v1/devices"): return (200, Self.registration("cg", role: "caregiver"))
            case ("GET", "/v1/location"): return (200, Self.snapshot)
            case ("DELETE", _): return (204, Data())
            case ("POST", "/v1/safe-zones") where requests.filter({ $0.0 == "POST" && $0.1 == "/v1/safe-zones" }).count > 1: return (409, Data())
            default: return (200, Data(#"{"id":"z","name":"Market","isHome":false,"center":{"latitude":32.0585,"longitude":118.7666},"radiusMeters":200}"#.utf8))
            }
        }
        let store = OnboardingStore(api: api, device: DemoDevice(role: .caregiver, api: api, defaults: defaults))
        await store.refreshLocation()
        let home = try XCTUnwrap(store.location?.safeZones.first)
        let market = SafeZone(id: UUID().uuidString, name: "Market", center: GeoPoint(latitude: 32.0585, longitude: 118.7666), radiusMeters: 200)
        try await store.persistZone(.save(market))
        try await store.persistZone(.save(SafeZone(id: home.id, name: "Home", center: home.center, radiusMeters: 200)))
        try await store.persistZone(.delete(market))
        let writes = requests.filter { $0.1.hasPrefix("/v1/safe-zones") }
        XCTAssertEqual(writes.map { "\($0.0) \($0.1)" }, ["POST /v1/safe-zones", "PUT /v1/safe-zones/\(home.id)", "DELETE /v1/safe-zones/\(market.id)"])
        let body = try JSONSerialization.jsonObject(with: writes[0].2) as? [String: Any]
        XCTAssertEqual(body?["radiusMeters"] as? Int, 200)
        XCTAssertEqual(body?["name"] as? String, "Market")

        let zones = SafeZoneSessionStore()
        zones.persist = { change in try await store.persistZone(change) }
        zones.save(SafeZone(id: UUID().uuidString, name: "Home", center: home.center, radiusMeters: 100))
        for _ in 0..<50 where zones.syncMessage == nil { try await Task.sleep(for: .milliseconds(20)) }
        XCTAssertEqual(zones.syncMessage, "Only one Home is allowed, and Home can't be removed.")
        XCTAssertTrue(zones.edits.isEmpty, "a rejected edit is taken back")
    }

    func testPendingFixesSurviveARestartUntilTheServerHasThem() throws {
        let file = FileManager.default.temporaryDirectory.appendingPathComponent("fixes-\(UUID().uuidString).json")
        defer { try? FileManager.default.removeItem(at: file) }
        let first = PendingFixQueue(file: file)
        first.append([UploadPoint(sampledAt: Date(timeIntervalSince1970: 1), latitude: 32, longitude: 118),
                      UploadPoint(sampledAt: Date(timeIntervalSince1970: 2), latitude: 32.1, longitude: 118.1)])
        let reopened = PendingFixQueue(file: file)
        XCTAssertEqual(reopened.points, first.points)
        reopened.drop(first: 1)
        XCTAssertEqual(PendingFixQueue(file: file).points.map(\.latitude), [32.1])
    }

    func testUploadsKeepMillisecondsAndReportPermission() throws {
        let batch = LocationUploadBatch(points: [UploadPoint(sampledAt: Date(timeIntervalSince1970: 1_790_935_200.123), latitude: 32, longitude: 118, accuracy: 5)],
                                        batteryPercent: 64, locationPermission: "always", preciseLocation: true)
        let json = String(decoding: try OnboardingAPI.json(batch), as: UTF8.self)
        XCTAssertTrue(json.contains(#""sampledAt":"2026-10-02T10:00:00.123Z""#), json)
        XCTAssertTrue(json.contains(#""locationPermission":"always""#))
        XCTAssertNil(ElderLocationReporter.permissionProblem("always", precise: true))
        XCTAssertNotNil(ElderLocationReporter.permissionProblem("whenInUse", precise: true))
        XCTAssertNotNil(ElderLocationReporter.permissionProblem("denied", precise: false))
        XCTAssertNotNil(ElderLocationReporter.permissionProblem("always", precise: false))
    }

    @MainActor func testElderPhoneFetchesHomeAndSendsQueuedFixesInBatches() async throws {
        let file = FileManager.default.temporaryDirectory.appendingPathComponent("fixes-\(UUID().uuidString).json")
        defer { try? FileManager.default.removeItem(at: file) }
        var uploads: [Int] = []
        StubURLProtocol.handler = { request in
            switch request.url!.path {
            case "/v1/devices": return (200, Self.registration("elder", role: "elder"))
            case "/v1/safe-zones": return (200, Data(#"[{"id":"h","name":"Home","isHome":true,"center":{"latitude":32.0621,"longitude":118.7613},"radiusMeters":100}]"#.utf8))
            default:
                let batch = try JSONSerialization.jsonObject(with: Self.body(of: request)) as! [String: Any]
                let count = (batch["points"] as! [Any]).count
                uploads.append(count)
                let results = (0..<count).map { #"{"index":\#($0),"status":"accepted"}"# }.joined(separator: ",")
                return (200, Data(#"{"results":[\#(results)],"actions":[]}"#.utf8))
            }
        }
        let queue = PendingFixQueue(file: file)
        queue.append((0..<(ElderLocationReporter.batchLimit + 20)).map {
            UploadPoint(sampledAt: Date(timeIntervalSince1970: Double($0)), latitude: 32.06, longitude: 118.76)
        })
        let reporter = ElderLocationReporter(device: DemoDevice(role: .elder, api: api, defaults: defaults), queue: queue)
        await reporter.flush()
        XCTAssertEqual(reporter.home, GeoPoint(latitude: 32.0621, longitude: 118.7613))
        XCTAssertEqual(uploads, [ElderLocationReporter.batchLimit, 20])
        XCTAssertTrue(queue.points.isEmpty)
        XCTAssertNotNil(reporter.lastUpload)

        StubURLProtocol.handler = { _ in throw URLError(.notConnectedToInternet) }
        queue.append([UploadPoint(sampledAt: Date(), latitude: 32.06, longitude: 118.76)])
        await reporter.flush()
        XCTAssertEqual(queue.points.count, 1, "kept for the next try while offline")
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
}
