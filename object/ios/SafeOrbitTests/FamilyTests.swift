import XCTest
@testable import SafeOrbit

final class FamilyTests: XCTestCase {
    private var network: URLSession!
    private var defaults: UserDefaults!
    private var suite: String!
    private var vault: SessionVault!
    private var pending: SessionVault!
    private var accounts: SessionVault!
    override func setUp() {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [StubURLProtocol.self]
        network = URLSession(configuration: config)
        suite = "org.safeorbit.family.test." + UUID().uuidString
        defaults = UserDefaults(suiteName: suite)
        vault = SessionVault(service: suite)
        pending = SessionVault(service: suite + ".pending")
        accounts = SessionVault(service: suite + ".account")
    }
    override func tearDown() {
        StubURLProtocol.handler = nil
        network.invalidateAndCancel()
        vault.clear(); pending.clear(); accounts.clear()
        defaults.removePersistentDomain(forName: suite)
    }
    @MainActor private func store() -> FamilySession {
        FamilySession(api: .init(baseURL: URL(string: "http://localhost:3000")!, session: network), vault: vault, pendingVault: pending, accountVault: accounts, defaults: defaults)
    }
    private static let household = #"{"elder":{"name":"Sam","callName":"Grandpa","phone":"+12025550102","timezone":"Asia/Shanghai"},"caregiver":{"name":"Alex","phone":"+12025550101"}}"#
    private static func reply(token: String? = nil, role: String = "caregiver", primary: Bool = true) -> Data {
        Data("{\(token.map { "\"deviceToken\":\"\($0)\"," } ?? "")\"role\":\"\(role)\",\"memberId\":\"member-1\",\"isPrimary\":\(primary),\"household\":\(household)}".utf8)
    }
    private static func accountReply(family: Data? = nil) -> Data {
        Data("{\"accountId\":\"account-1\",\"accountToken\":\"account-token\",\"email\":\"alex@example.com\",\"family\":\(family.map { String(decoding: $0, as: UTF8.self) } ?? "null")}".utf8)
    }
    @MainActor private func login(_ store: FamilySession, family: Data? = nil) async {
        StubURLProtocol.handler = { request in
            XCTAssertEqual(request.url?.path, "/v1/account/login")
            return (200, Self.accountReply(family: family))
        }
        await store.authenticate(email: "Alex@Example.com", password: "a secure password", registering: false)
        XCTAssertTrue(store.isLoggedIn)
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
        XCTAssertEqual(defaults.data(forKey: "safeorbit.agent.sessions.v1"), Data("old-chat".utf8), "Demo history must remain untouched")
        XCTAssertTrue(family.consent)
    }
    @MainActor func testRevokedDeviceAndRecordsNeverFallBackToDemoRegistration() async throws {
        let family = store(); family.acceptPrivacy(); try vault.save("saved-token", role: "elder")
        StubURLProtocol.handler = { request in
            if request.url?.path == "/v1/family/session" { return (200, Self.reply(role: "elder", primary: false)) }
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
        await login(family)
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
        let family = store(); family.acceptPrivacy(); await login(family, family: Self.reply(token: "saved-token"))
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
        await family.deleteFamily()
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
        await family.restore(); await family.leaveFamily()
        XCTAssertNil(family.device)
    }
    @MainActor func testLogoutPreservesMembershipArchiveAndLoginRestoresStableMember() async throws {
        let family = store(); family.acceptPrivacy()
        await login(family, family: Self.reply(token: "first-session"))
        let oldDevice = try XCTUnwrap(family.device), key = try XCTUnwrap(oldDevice.chatStorageKey)
        let archive = Data("saved transcript".utf8)
        defaults.set(archive, forKey: key)
        StubURLProtocol.handler = { request in
            XCTAssertEqual(request.url?.path, "/v1/account/session")
            XCTAssertEqual(request.httpMethod, "DELETE")
            XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer account-token")
            return (204, Data())
        }
        await family.logOut()
        XCTAssertNil(family.device); XCTAssertNil(family.account); XCTAssertNil(accounts.load()); XCTAssertNil(oldDevice.token)
        XCTAssertEqual(defaults.data(forKey: key), archive)
        await login(family, family: Self.reply(token: "new-session"))
        XCTAssertEqual(family.device?.chatStorageKey, key)
        XCTAssertEqual(family.session?.memberId, "member-1")
        XCTAssertEqual(defaults.data(forKey: key), archive)
    }
    @MainActor func testLeaveKeepsAccountAndArchiveButNewMembershipHasSeparateHistory() async throws {
        let family = store(); family.acceptPrivacy()
        await login(family, family: Self.reply(token: "first-session", primary: false))
        let key = try XCTUnwrap(family.device?.chatStorageKey), archive = Data("old family".utf8)
        defaults.set(archive, forKey: key)
        StubURLProtocol.handler = { request in
            XCTAssertEqual(request.url?.path, "/v1/family/membership")
            return (204, Data())
        }
        await family.leaveFamily()
        XCTAssertTrue(family.isLoggedIn); XCTAssertNil(family.device); XCTAssertNil(family.members)
        XCTAssertEqual(defaults.data(forKey: key), archive)
        StubURLProtocol.handler = { request in
            XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer account-token")
            return (200, Data(String(decoding: Self.reply(token: "second", primary: false), as: UTF8.self).replacingOccurrences(of: "member-1", with: "member-2").utf8))
        }
        await family.join(code: "AJKD74M4NZKP", role: .caregiver, name: "Alex", phone: "+12025550101")
        let nextKey = try XCTUnwrap(family.device?.chatStorageKey)
        XCTAssertNotEqual(nextKey, key); XCTAssertNil(defaults.data(forKey: nextKey))
        XCTAssertEqual(defaults.data(forKey: key), archive)
        XCTAssertEqual(family.ownProfile?.name, "Alex")
    }
    @MainActor func testPrimaryLeaveConflictKeepsFamilyAndLogoutOfflineClearsCredentials() async throws {
        let family = store(); family.acceptPrivacy()
        await login(family, family: Self.reply(token: "first-session"))
        StubURLProtocol.handler = { _ in (409, Data()) }
        await family.leaveFamily()
        XCTAssertNotNil(family.device); XCTAssertTrue(family.error?.contains("another caregiver") == true)
        StubURLProtocol.handler = { _ in throw URLError(.notConnectedToInternet) }
        await family.logOut()
        XCTAssertNil(family.device); XCTAssertFalse(family.isLoggedIn); XCTAssertNil(accounts.load())
        XCTAssertTrue(family.error?.contains("could not confirm") == true)
    }
    @MainActor func testExplicitLegacyClaimValidatesBearerButDoesNotCopyMixedDemoTranscript() async throws {
        let family = store(); family.acceptPrivacy(); try vault.save("legacy", role: "caregiver")
        let archive = Data("mixed legacy history".utf8)
        defaults.set(archive, forKey: AgentSessionStore.storageKey)
        var calls = 0
        StubURLProtocol.handler = { request in
            calls += 1
            XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer legacy")
            if request.url?.path == "/v1/family/session" { return (200, Self.reply()) }
            XCTAssertEqual(request.url?.path, "/v1/account/register")
            return (200, Self.accountReply(family: Self.reply(token: "scoped")))
        }
        await family.authenticate(email: "alex@example.com", password: "twelve characters", registering: true, claimLegacy: true)
        XCTAssertEqual(calls, 2); XCTAssertTrue(family.isLoggedIn); XCTAssertNil(vault.load())
        XCTAssertEqual(defaults.data(forKey: AgentSessionStore.storageKey), archive)
        XCTAssertNil(defaults.data(forKey: try XCTUnwrap(family.device?.chatStorageKey)))
    }
    @MainActor func testRevokedMembershipRestoresSignedInUnboundAccount() async throws {
        let family = store(); family.acceptPrivacy()
        await login(family, family: Self.reply(token: "revoked"))
        let old = try XCTUnwrap(family.device), key = try XCTUnwrap(old.chatStorageKey)
        defaults.set(Data("archive".utf8), forKey: key)
        StubURLProtocol.handler = { request in
            if request.url?.path == "/v1/account/session" { return (200, Self.accountReply()) }
            return (401, Data())
        }
        await family.restore()
        XCTAssertNil(family.device); XCTAssertNil(old.token); XCTAssertTrue(family.isLoggedIn)
        XCTAssertNotNil(defaults.data(forKey: key))
    }
    @MainActor func testLogoutOverlappingRestoreIgnoresLateSuccessAndUnauthorized() async throws {
        for status in [200, 401] {
            let config = URLSessionConfiguration.ephemeral
            config.protocolClasses = [DelayedFamilyProtocol.self]
            let delayedNetwork = URLSession(configuration: config)
            defer { delayedNetwork.invalidateAndCancel(); DelayedFamilyProtocol.handler = nil }
            let family = FamilySession(api: .init(baseURL: URL(string: "http://localhost:3000")!, session: delayedNetwork),
                                       vault: vault, pendingVault: pending, accountVault: accounts, defaults: defaults)
            family.acceptPrivacy()
            DelayedFamilyProtocol.handler = { request in request.finish(200, Self.accountReply(family: Self.reply(token: "old-device"))) }
            await family.authenticate(email: "alex@example.com", password: "secure password", registering: false)
            let began = expectation(description: "restore began")
            var delayed: DelayedFamilyProtocol?
            DelayedFamilyProtocol.handler = { request in
                if request.request.httpMethod == "DELETE" { request.finish(204, Data()) }
                else { delayed = request; began.fulfill() }
            }
            let restore = Task { await family.restore() }
            await fulfillment(of: [began], timeout: 2)
            await family.logOut()
            XCTAssertNil(family.device); XCTAssertNil(accounts.load())
            // Re-login before the old request completes: stale 401 must not clear this account.
            DelayedFamilyProtocol.handler = { request in request.finish(200, Self.accountReply(family: Self.reply(token: "new-device"))) }
            await family.authenticate(email: "alex@example.com", password: "secure password", registering: false)
            try XCTUnwrap(delayed).finish(status, Self.reply())
            await restore.value
            XCTAssertEqual(family.device?.token, "new-device")
            XCTAssertTrue(family.isLoggedIn); XCTAssertNotNil(accounts.load()); XCTAssertNil(family.error)
            DelayedFamilyProtocol.handler = { $0.finish(204, Data()) }
            await family.logOut()
        }
    }
    @MainActor private final class PendingChat: AgentChatServing {
        var continuation: CheckedContinuation<AgentResponse, Error>?
        var returned = false
        func ask(_ question: AgentQuestion) async throws -> AgentResponse {
            defer { returned = true }
            return try await withCheckedThrowingContinuation { continuation = $0 }
        }
    }
    @MainActor func testPendingChatCannotCrossActualLogoutOrLeaveAndRejoin() async throws {
        for leaving in [false, true] {
            for failing in [false, true] {
                let family = store(); family.acceptPrivacy()
                await login(family, family: Self.reply(token: "old-device", primary: false))
                let oldDevice = try XCTUnwrap(family.device), key = try XCTUnwrap(oldDevice.chatStorageKey)
                defaults.removeObject(forKey: key)
                let service = PendingChat()
                let chat = AgentSessionStore(defaults: defaults, service: service, storageKey: key,
                                             sessionIsValid: { oldDevice.token != nil })
                let id = try XCTUnwrap(chat.newConversation())
                XCTAssertTrue(chat.send("Question for my original family", in: id, allowTripHistory: false))
                for _ in 0..<100 where service.continuation == nil { await Task.yield() }
                let response = try XCTUnwrap(service.continuation)
                let archive = try XCTUnwrap(defaults.data(forKey: key))
                StubURLProtocol.handler = { _ in (204, Data()) }
                if leaving { await family.leaveFamily() } else { await family.logOut() }
                chat.endViewSession()
                XCTAssertNil(oldDevice.token); XCTAssertTrue(chat.sessions.isEmpty)
                if leaving {
                    StubURLProtocol.handler = { _ in
                        (200, Data(String(decoding: Self.reply(token: "joined-device", primary: false), as: UTF8.self).replacingOccurrences(of: "member-1", with: "new-family-member").utf8))
                    }
                    await family.join(code: "AJKD74M4NZKP", role: .caregiver, name: "Alex", phone: "+12025550101")
                } else { await login(family, family: Self.reply(token: "logged-in-device", primary: false)) }
                let newKey = try XCTUnwrap(family.device?.chatStorageKey)
                let current = AgentSessionStore(defaults: defaults, storageKey: newKey)
                if leaving { XCTAssertTrue(current.sessions.isEmpty); XCTAssertNotEqual(key, newKey) }
                else { XCTAssertEqual(current.conversation(id)?.messages.count, 1); XCTAssertEqual(key, newKey) }
                if failing { response.resume(throwing: APIError(kind: .unauthorized)) }
                else { response.resume(returning: AgentResponse(outcome: "general", paragraphs: ["Old family reply"], citations: [])) }
                for _ in 0..<100 where !service.returned { await Task.yield() }
                await Task.yield()
                XCTAssertTrue(service.returned); XCTAssertEqual(defaults.data(forKey: key), archive)
                XCTAssertTrue(chat.sessions.isEmpty)
                if leaving { XCTAssertNil(defaults.data(forKey: newKey)) }
                StubURLProtocol.handler = { _ in (204, Data()) }
                await family.logOut()
            }
        }
    }
    @MainActor func testChatStorageIncludesServerAndMembership() {
        let a = URL(string: "http://localhost:3000")!, b = URL(string: "http://localhost:4000")!
        XCTAssertNotEqual(FamilySession.chatStorageKey(baseURL: a, memberId: "one"), FamilySession.chatStorageKey(baseURL: b, memberId: "one"))
        XCTAssertNotEqual(FamilySession.chatStorageKey(baseURL: a, memberId: "one"), FamilySession.chatStorageKey(baseURL: a, memberId: "two"))
    }
    func testInviteParserOnlyAcceptsTwelveASCIICharacters() {
        XCTAssertEqual(FamilyInvite.normalized(" ajkd74m4nzkp \n"), "AJKD74M4NZKP")
        XCTAssertNil(FamilyInvite.normalized("safeorbit://bind?token=secret"))
        XCTAssertNil(FamilyInvite.normalized("短邀请码"))
        XCTAssertNil(FamilyInvite.normalized("AJKD-74M4-NZKP"))
    }
}

private final class DelayedFamilyProtocol: URLProtocol {
    static var handler: ((DelayedFamilyProtocol) -> Void)?
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() { Self.handler?(self) }
    override func stopLoading() {}
    func finish(_ status: Int, _ data: Data) {
        client?.urlProtocol(self, didReceive: HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: nil, headerFields: nil)!, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: data)
        client?.urlProtocolDidFinishLoading(self)
    }
}
