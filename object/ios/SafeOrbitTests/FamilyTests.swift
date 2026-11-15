import XCTest
@testable import SafeOrbit

final class FamilyTests: XCTestCase {
    private var network: URLSession!
    private var defaults: UserDefaults!
    private var suite: String!
    private var vault: SessionVault!
    private var pending: SessionVault!
    override func setUp() {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [StubURLProtocol.self]
        network = URLSession(configuration: config)
        suite = "org.safeorbit.family.test." + UUID().uuidString
        defaults = UserDefaults(suiteName: suite)
        vault = SessionVault(service: suite)
        pending = SessionVault(service: suite + ".pending")
    }
    override func tearDown() {
        StubURLProtocol.handler = nil
        network.invalidateAndCancel()
        vault.clear(); pending.clear()
        defaults.removePersistentDomain(forName: suite)
    }
    @MainActor private func store() -> FamilySession {
        FamilySession(api: .init(baseURL: URL(string: "http://localhost:3000")!, session: network), vault: vault, pendingVault: pending, defaults: defaults)
    }
    private static let household = #"{"elder":{"name":"Sam","callName":"Grandpa","phone":"+12025550102","timezone":"Asia/Shanghai"},"caregiver":{"name":"Alex","phone":"+12025550101"}}"#
    private static func reply(token: String? = nil, role: String = "caregiver", primary: Bool = true) -> Data {
        Data("{\(token.map { "\"deviceToken\":\"\($0)\"," } ?? "")\"role\":\"\(role)\",\"memberId\":\"member-1\",\"isPrimary\":\(primary),\"household\":\(household)}".utf8)
    }
    private static func body(_ request: URLRequest) -> Data {
        if let data = request.httpBody { return data }
        guard let stream = request.httpBodyStream else { return Data() }
        stream.open(); defer { stream.close() }
        var result = Data(), buffer = [UInt8](repeating: 0, count: 4096)
        while stream.hasBytesAvailable {
            let count = stream.read(&buffer, maxLength: buffer.count)
            if count <= 0 { break }; result.append(buffer, count: count)
        }
        return result
    }
    @MainActor func testPrivacyDeclineDoesNotCreateSessionOrSendRequest() async {
        let family = store()
        StubURLProtocol.handler = { _ in XCTFail("No calls before privacy consent"); return (500, Data()) }
        family.declinePrivacy()
        await family.join(code: "AJKD74M4NZKP", role: .elder)
        await family.restore()
        XCTAssertFalse(family.consent)
        XCTAssertNil(family.device)
        XCTAssertNil(vault.load())
        XCTAssertFalse(defaults.bool(forKey: AMapRuntime.consentKey))
    }
    @MainActor func testJoinPersistsTheExactRequestBeforeSendingAndRetriesAfterRestart() async throws {
        let family = store(); family.acceptPrivacy()
        var sent: [Data] = []
        var token = ""
        StubURLProtocol.handler = { request in
            XCTAssertEqual(request.url?.path, "/v1/family/join")
            let body = Self.body(request); sent.append(body)
            let values = try XCTUnwrap(JSONSerialization.jsonObject(with: body) as? [String: String])
            token = try XCTUnwrap(values["deviceToken"])
            XCTAssertEqual(token.count, 43)
            XCTAssertNotNil(self.pending.load(), "Pending request must be durable before sending")
            XCTAssertEqual(values["inviteCode"], "AJKD74M4NZKP")
            if sent.count == 1 { throw URLError(.networkConnectionLost) }
            return (200, Self.reply(token: token, role: "elder", primary: false))
        }
        await family.join(code: " ajkd74m4nzkp ", role: .elder)
        XCTAssertTrue(family.pending)
        XCTAssertNil(family.device)
        let restarted = store()
        await restarted.retryPending()
        XCTAssertEqual(sent.count, 2)
        XCTAssertEqual(sent.first, sent.last)
        XCTAssertEqual(vault.load(), token)
        XCTAssertNil(pending.load())
        XCTAssertEqual(restarted.device?.token, token)
        XCTAssertTrue(restarted.device?.isFamilySession == true)
    }
    @MainActor func testRestoreRetainsCredentialsOnNetworkFailureButClearsOnRevocation() async throws {
        let family = store(); family.acceptPrivacy()
        try vault.save("saved-token", role: "elder")
        defaults.set(Data("old-chat".utf8), forKey: "safeorbit.agent.sessions.v1")
        StubURLProtocol.handler = { _ in throw URLError(.notConnectedToInternet) }
        await family.restore()
        XCTAssertEqual(vault.load(), "saved-token")
        XCTAssertNil(family.device)
        StubURLProtocol.handler = { request in
            XCTAssertEqual(request.url?.path, "/v1/family/session")
            return (401, Data())
        }
        await family.restore()
        XCTAssertNil(vault.load())
        XCTAssertNil(family.device)
        XCTAssertNil(defaults.data(forKey: "safeorbit.agent.sessions.v1"))
        XCTAssertTrue(family.consent)
    }
    @MainActor func testRevokedDeviceAndRecordsNeverFallBackToDemoRegistration() async throws {
        let family = store(); family.acceptPrivacy(); try vault.save("saved-token")
        StubURLProtocol.handler = { request in
            if request.url?.path == "/v1/family/session" { return (200, Self.reply()) }
            XCTAssertEqual(request.url?.path, "/v1/records")
            return (401, Data())
        }
        await family.restore()
        let device = try XCTUnwrap(family.device)
        do { _ = try await RecordsAPI(device: device).records(month: "2026-11", week: "2026-11-09"); XCTFail("Expected revoked session") }
        catch { XCTAssertEqual(error as? RecordsFailure, .credentials) }
        XCTAssertNil(family.device)
        XCTAssertNil(vault.load())
        do { let _: EmptyResponse = try await device.request("safe-zones"); XCTFail("Must stay revoked") }
        catch let error as APIError { XCTAssertEqual(error.kind, .unauthorized) }
    }
    @MainActor func testCreateUsesWGS84HomeAndPrimarySession() async throws {
        let family = store(); family.acceptPrivacy()
        var elder = ElderProfile(); elder.name = "Sam"; elder.callName = "Grandpa"; elder.phone = "+12025550102"; elder.timezone = "Asia/Shanghai"
        StubURLProtocol.handler = { request in
            XCTAssertEqual(request.url?.path, "/v1/family")
            let body = try XCTUnwrap(JSONSerialization.jsonObject(with: Self.body(request)) as? [String: Any])
            let home = try XCTUnwrap(body["home"] as? [String: Double])
            XCTAssertEqual(home["latitude"], 31.23); XCTAssertEqual(home["radiusMeters"], 100)
            return (200, Self.reply(token: body["deviceToken"] as? String))
        }
        await family.create(caregiverName: "Alex", caregiverPhone: "+12025550101", elder: elder, home: .init(latitude: 31.23, longitude: 121.47), radius: 100)
        XCTAssertTrue(family.session?.isPrimary == true)
        XCTAssertEqual(family.device?.household?.elder.timezone, "Asia/Shanghai")
        XCTAssertEqual(family.ownProfile?.name, "Alex")
    }
    @MainActor func testMemberRemovalAndDeletionUseActiveTokenAndClearSession() async throws {
        let family = store(); family.acceptPrivacy(); try vault.save("saved-token")
        var removed = false
        StubURLProtocol.handler = { request in
            XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer saved-token")
            switch (request.httpMethod, request.url?.path) {
            case ("GET", "/v1/family/session"): return (200, Self.reply())
            case ("GET", "/v1/family/members"):
                return (200, Data(#"{"inviteCode":"AJKD74M4NZKP","members":[{"id":"other","name":"Sam","role":"elder","isPrimary":false}]}"#.utf8))
            case ("DELETE", "/v1/family/members/other"): removed = true; return (204, Data())
            case ("DELETE", "/v1/family"): return (204, Data())
            default: XCTFail("Unexpected request"); return (500, Data())
            }
        }
        await family.restore(); await family.refreshMembers()
        await family.remove(try XCTUnwrap(family.members?.members.first))
        XCTAssertTrue(removed)
        await family.leaveOrDelete()
        XCTAssertNil(family.session); XCTAssertNil(vault.load()); XCTAssertNil(family.members)
    }
    @MainActor func testInvalidInvitationCanBeCorrectedAndNonPrimaryUsesMembershipExit() async throws {
        let family = store(); family.acceptPrivacy()
        StubURLProtocol.handler = { _ in (404, Data()) }
        await family.join(code: "AAAAAAAAAAAA", role: .elder)
        XCTAssertFalse(family.pending)
        XCTAssertNil(pending.load())
        XCTAssertEqual(family.error, "Check the invitation code and try again.")
        try vault.save("elder-token", role: "elder")
        StubURLProtocol.handler = { request in
            if request.httpMethod == "DELETE" { XCTAssertEqual(request.url?.path, "/v1/family/membership"); return (204, Data()) }
            return (200, Self.reply(role: "elder", primary: false))
        }
        await family.restore(); await family.leaveOrDelete()
        XCTAssertNil(family.device)
    }
    func testInviteParserOnlyAcceptsTwelveASCIICharacters() {
        XCTAssertEqual(FamilyInvite.normalized(" ajkd74m4nzkp \n"), "AJKD74M4NZKP")
        XCTAssertNil(FamilyInvite.normalized("safeorbit://bind?token=secret"))
        XCTAssertNil(FamilyInvite.normalized("短邀请码"))
        XCTAssertNil(FamilyInvite.normalized("AJKD-74M4-NZKP"))
    }
}
