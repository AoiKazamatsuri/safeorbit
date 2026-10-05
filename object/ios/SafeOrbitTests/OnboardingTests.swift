import XCTest
import SwiftUI
import Security
import AuthenticationServices
import CryptoKit
@testable import SafeOrbit

final class OnboardingTests: XCTestCase {
    @MainActor func testPasswordSuggestionPreviewDoesNotCommitConfirmation() {
        var confirmation = ""
        let input = SignupPasswordField(title: "Confirm password", text: Binding(
            get: { confirmation }, set: { confirmation = $0 }
        ), visible: false, confirmation: true)
        let coordinator = input.makeCoordinator()
        let field = UITextField()

        field.text = "preview"
        coordinator.textChanged(field)
        XCTAssertEqual(confirmation, "")
        XCTAssertEqual(field.text, "")
    }

    @MainActor func testAcceptedGeneratedPasswordCanFillConfirmationInEitherOrder() {
        for confirmationFirst in [true, false] {
            var password = "a"
            var confirmation = ""
            let state = SignupAutofillState()
            let primary = SignupPasswordField(title: "Password", text: Binding(
                get: { password }, set: { password = $0 }
            ), visible: false, autofillState: state, linkedConfirmation: Binding(
                get: { confirmation }, set: { confirmation = $0 }
            )).makeCoordinator()
            primary.draft = password
            let secondary = SignupPasswordField(title: "Confirm password", text: Binding(
                get: { confirmation }, set: { confirmation = $0 }
            ), visible: false, confirmation: true, autofillState: state).makeCoordinator()
            let generated = "sample-generated-password"
            let primaryField = UITextField()
            let secondaryField = UITextField()
            primaryField.text = generated
            secondaryField.text = generated

            if confirmationFirst { secondary.textChanged(secondaryField) }
            primary.textChanged(primaryField)
            if !confirmationFirst { secondary.textChanged(secondaryField) }

            XCTAssertEqual(password, generated)
            XCTAssertEqual(confirmation, generated)
        }
    }

    @MainActor func testSignupPasswordDraftRestoresUnexpectedClearButAllowsUserDelete() {
        var password = "sample"
        let input = SignupPasswordField(title: "Password", text: Binding(get: { password }, set: { password = $0 }), visible: false)
        let coordinator = input.makeCoordinator()
        let field = UITextField()
        coordinator.draft = password
        field.text = ""
        coordinator.textChanged(field)
        XCTAssertEqual(field.text?.count, 6)
        XCTAssertEqual(password.count, 6)

        field.text = password
        XCTAssertTrue(coordinator.textField(field, shouldChangeCharactersIn: NSRange(location: 0, length: 6), replacementString: ""))
        field.text = ""
        coordinator.textChanged(field)
        XCTAssertEqual(password.count, 0)
        XCTAssertEqual(field.text?.count, 0)
    }
    @MainActor func testSignupPasswordRestoresSystemClearedDisplayWithoutChangingDraft() {
        var password = "sample"
        let input = SignupPasswordField(title: "Password", text: Binding(get: { password }, set: { password = $0 }), visible: false)
        let coordinator = input.makeCoordinator()
        let window = UIWindow()
        let field = UITextField()
        window.addSubview(field)
        coordinator.field = field
        coordinator.draft = password

        field.text = ""
        coordinator.textFieldDidChangeSelection(field)
        XCTAssertEqual(field.text?.count, 6)
        XCTAssertEqual(password.count, 6)

        field.text = ""
        NotificationCenter.default.post(name: UIResponder.keyboardDidShowNotification, object: nil)
        XCTAssertEqual(field.text?.count, 6)
        XCTAssertEqual(password.count, 6)
    }
#if DEBUG
    @MainActor func testDebugEmailPreviewEntersHomeWithoutBackendSession() async {
        let store = OnboardingStore(previewAccessEnabled: true)
        store.screen = .login
        store.email = "invalid"; store.password = "password123"
        await store.signInWithEmail()
        XCTAssertEqual(store.screen, .login)
        store.email = "person@example.com"; store.password = "short"
        await store.signInWithEmail()
        XCTAssertEqual(store.screen, .login)
        store.password = "password123"
        await store.signInWithEmail()
        XCTAssertEqual(store.screen, .caregiverHome)
        XCTAssertTrue(store.previewSession)
        XCTAssertNil(store.token)
        XCTAssertNotNil(store.location)
        await store.refreshLocation()
        XCTAssertNil(store.locationError)
        await store.signOut()
        XCTAssertEqual(store.screen, .role)
        XCTAssertFalse(store.previewSession)

        store.screen = .emailSignup
        store.email = "new@example.com"; store.password = "password123"; store.confirmPassword = "different"
        await store.registerWithEmail()
        XCTAssertEqual(store.screen, .emailSignup)
        store.confirmPassword = store.password
        await store.registerWithEmail()
        XCTAssertEqual(store.screen, .caregiverHome)
        XCTAssertNil(store.token)
    }
#endif
    func testProfileValidationAndInternationalPhone() {
        var profile = ElderProfile()
        XCTAssertFalse(profile.isValid)
        profile.name = "李兰"; profile.callName = "奶奶"; profile.phone = "+86 138 0000 0000"; profile.timezone = "Asia/Shanghai"
        XCTAssertTrue(profile.isValid)
        profile.callName = ""; XCTAssertTrue(profile.isValid)
        profile.name = "  \n"; XCTAssertFalse(profile.isValid)
        profile.name = "李兰"; profile.timezone = "Nowhere/Test"; XCTAssertFalse(profile.isValid)
        XCTAssertFalse(PhoneNumber.isValid("13800000000"))
        XCTAssertFalse(PhoneNumber.isValid("+00 13800000000"))
        XCTAssertEqual(PhoneNumber.normalized("+86 (138) 0000-0000"), "+8613800000000")
    }
    func testCountryPhoneEntryAndValidation() {
        var entry = PhoneEntry()
        XCTAssertEqual(entry.country.code, "+86"); XCTAssertFalse(entry.showsError)
        entry.digits = PhoneEntry.filtered("(138) 0000-0000 abc")
        XCTAssertEqual(entry.fullNumber, "+8613800000000"); XCTAssertFalse(entry.showsError)
        for country in PhoneCountry.choices {
            entry.country = country
            XCTAssertEqual(entry.digits, "13800000000")
            XCTAssertEqual(PhoneEntry(entry.fullNumber), entry)
        }
        for number in ["+49 151 23456789", "+353 851234567", "+7 9123456789"] {
            XCTAssertEqual(PhoneEntry(number).fullNumber, PhoneNumber.normalized(number))
        }
        entry.digits = "1"; XCTAssertTrue(entry.showsError)
        entry.digits = "1234567890123456"; XCTAssertTrue(entry.showsError)
        entry.digits = "123456789"; XCTAssertFalse(entry.showsError)
        entry.digits = ""; XCTAssertFalse(entry.showsError)
    }
    @MainActor func testSingleLoginEntryRetriesAndBlocksDuplicates() async throws {
        let config = URLSessionConfiguration.ephemeral; config.protocolClasses = [StubURLProtocol.self]
        let network = URLSession(configuration: config)
        defer { network.invalidateAndCancel(); StubURLProtocol.handler = nil }
        let store = OnboardingStore(api: .init(baseURL: URL(string: "http://localhost")!, session: network))
        store.screen = .login
        StubURLProtocol.handler = { _ in (503, Data()) }
        await store.prepareLogin()
        XCTAssertFalse(store.loginReady); XCTAssertNotNil(store.error)
        var launches = 0
        await store.startLogin { _ in launches += 1 }
        XCTAssertEqual(launches, 0); XCTAssertFalse(store.loginInProgress)
        StubURLProtocol.handler = { request in
            XCTAssertEqual(request.url?.path, "/v1/auth/challenge")
            return (200, Data(#"{"id":"challenge","nonce":"random-test-nonce"}"#.utf8))
        }
        await store.startLogin { request in
            launches += 1
            XCTAssertEqual(request.state, "challenge")
            XCTAssertEqual(request.nonce, SHA256.hash(data: Data("random-test-nonce".utf8)).map { String(format: "%02x", $0) }.joined())
        }
        XCTAssertEqual(launches, 1); XCTAssertTrue(store.authorizing); XCTAssertNil(store.error)
        await store.startLogin { _ in launches += 1 }
        await store.prepareLogin()
        XCTAssertEqual(launches, 1); XCTAssertTrue(store.loginReady)
        await store.completeLogin(.failure(ASAuthorizationError(.canceled)))
        XCTAssertNil(store.error); XCTAssertFalse(store.loginInProgress); XCTAssertFalse(store.loginReady)
    }
    func testEmailAndGoogleCallbackValidation() {
        XCTAssertTrue(EmailAddress.isValid(" person@gmail.com "))
        for email in ["", "name", "a@@gmail.com", "a b@gmail.com", "a@-gmail.com"] { XCTAssertFalse(EmailAddress.isValid(email)) }
        let valid = GoogleChallenge(authorizationURL: "https://accounts.google.com/o/oauth2/v2/auth?state=test", state: "test")
        XCTAssertNotNil(valid.validatedURL)
        for url in ["http://accounts.google.com/?state=test", "https://evil.test/?state=test", "https://accounts.google.com/?state=wrong", "https://accounts.google.com/?state=test&state=test"] {
            XCTAssertNil(GoogleChallenge(authorizationURL: url, state: "test").validatedURL)
        }
        XCTAssertEqual(GoogleChallenge.callbackCode(URL(string: "safeorbit://oauth?state=test&code=abc")!, state: "test"), "abc")
        for url in ["safeorbit://oauth?state=wrong&code=abc", "safeorbit://oauth?state=test&code=a&code=b", "safeorbit://oauth/path?state=test&code=abc", "https://oauth?state=test&code=abc"] {
            XCTAssertNil(GoogleChallenge.callbackCode(URL(string: url)!, state: "test"))
        }
    }
    @MainActor func testEmailAuthFailureRecoveryAndReset() async throws {
        let config = URLSessionConfiguration.ephemeral; config.protocolClasses = [StubURLProtocol.self]
        let network = URLSession(configuration: config)
        let vault = SessionVault(service: "org.safeorbit.test." + UUID().uuidString)
        defer { network.invalidateAndCancel(); StubURLProtocol.handler = nil; vault.clear() }
        let store = OnboardingStore(api: .init(baseURL: URL(string: "http://localhost")!, session: network), vault: vault)
        store.screen = .emailSignup; store.email = " person@gmail.com "; store.password = "test-password"; store.confirmPassword = "other"
        XCTAssertFalse(store.emailSignupValid)
        store.confirmPassword = store.password; XCTAssertTrue(store.emailSignupValid)
        StubURLProtocol.handler = { request in
            XCTAssertEqual(request.url?.path, "/v1/auth/email/register"); return (503, Data())
        }
        await store.registerWithEmail()
        XCTAssertEqual(store.email, " person@gmail.com "); XCTAssertEqual(store.password, "test-password")
        XCTAssertNotNil(store.error); XCTAssertNil(store.token)
        store.showAuth(.forgotPassword); XCTAssertEqual(store.password, "")
        StubURLProtocol.handler = { request in
            XCTAssertEqual(request.url?.path, "/v1/auth/email/forgot-password")
            return (200, Data(#"{"ok":true}"#.utf8))
        }
        await store.sendPasswordReset(); XCTAssertTrue(store.resetEmailSent)
        store.showAuth(.login); XCTAssertFalse(store.resetEmailSent)
        store.password = "test-password"
        StubURLProtocol.handler = { request in
            XCTAssertEqual(request.url?.path, "/v1/auth/email/login")
            return (200, Data(#"{"token":"test-token","role":"caregiver","caregiver":{"id":"test"}}"#.utf8))
        }
        await store.signInWithEmail()
        XCTAssertEqual(store.screen, .phone); XCTAssertEqual(store.token, "test-token")
        XCTAssertEqual(vault.load(), "test-token"); XCTAssertEqual(store.password, "")
    }
    @MainActor func testGooglePreparationCancellationAndStateRecovery() async throws {
        let config = URLSessionConfiguration.ephemeral; config.protocolClasses = [StubURLProtocol.self]
        let network = URLSession(configuration: config)
        let vault = SessionVault(service: "org.safeorbit.test." + UUID().uuidString)
        defer { network.invalidateAndCancel(); StubURLProtocol.handler = nil; vault.clear() }
        let store = OnboardingStore(api: .init(baseURL: URL(string: "http://localhost")!, session: network), vault: vault)
        var starts = 0
        StubURLProtocol.handler = { _ in (503, Data()) }
        await store.startGoogleLogin { _ in starts += 1 }
        XCTAssertEqual(starts, 0); XCTAssertFalse(store.authorizing)
        StubURLProtocol.handler = { request in
            XCTAssertEqual(request.url?.path, "/v1/auth/google/start")
            return (200, Data(#"{"authorizationURL":"https://accounts.google.com/o/oauth2/v2/auth?state=test","state":"test"}"#.utf8))
        }
        await store.startGoogleLogin { _ in starts += 1 }
        XCTAssertTrue(store.authorizing)
        await store.startGoogleLogin { _ in starts += 1 }; XCTAssertEqual(starts, 1)
        await store.completeGoogleLogin(.failure(ASWebAuthenticationSessionError(.canceledLogin)))
        XCTAssertNil(store.error); XCTAssertFalse(store.loginInProgress)
        await store.startGoogleLogin { _ in starts += 1 }
        await store.completeGoogleLogin(.success(URL(string: "safeorbit://oauth?state=wrong&code=abc")!))
        XCTAssertNotNil(store.error); XCTAssertNil(store.token)
        await store.startGoogleLogin { _ in starts += 1 }
        StubURLProtocol.handler = { request in
            XCTAssertEqual(request.url?.path, "/v1/auth/google")
            return (200, Data(#"{"token":"google-test-token","role":"caregiver","caregiver":{"id":"test"}}"#.utf8))
        }
        await store.completeGoogleLogin(.success(URL(string: "safeorbit://oauth?state=test&code=abc")!))
        XCTAssertEqual(store.screen, .phone); XCTAssertEqual(vault.load(), "google-test-token")
    }
    func testBindingRejectsUnrelatedAndAmbiguousLinks() {
        let token = String(repeating: "a", count: 43)
        XCTAssertEqual(BindingPayload.token(from: "safeorbit://bind?token=\(token)"), token)
        for link in ["https://evil.example/bind?token=\(token)", "safeorbit://bind/path?token=\(token)",
                     "safeorbit://bind?token=\(token)&token=\(token)", "safeorbit://bind?token=short",
                     "safeorbit://user@bind?token=\(token)", "safeorbit://bind:3000?token=\(token)",
                     "safeorbit://bind?token=\(token)#fragment"] {
            XCTAssertNil(BindingPayload.token(from: link), link)
        }
        XCTAssertNotNil(QRCodeImage.image(for: "safeorbit://bind?token=\(token)"))
    }
    func testProfileResponseCanOmitOptionalPhotoAndBound() throws {
        let data = Data(#"{"id":"test","name":"李兰","callName":"奶奶","phone":"+8613800000000","timezone":"Asia/Shanghai"}"#.utf8)
        let profile = try JSONDecoder().decode(ElderProfile.self, from: data)
        XCTAssertNil(profile.photo); XCTAssertFalse(profile.bound); XCTAssertTrue(profile.isValid)
    }
    func testAPIPathsHeadersAndExpiryTimestamp() async throws {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [StubURLProtocol.self]
        let session = URLSession(configuration: config)
        defer { session.invalidateAndCancel(); StubURLProtocol.handler = nil }
        StubURLProtocol.handler = { request in
            XCTAssertEqual(request.url?.absoluteString, "http://localhost:3000/v1/binding")
            XCTAssertEqual(request.httpMethod, "POST")
            XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer test-token")
            return (200, Data(#"{"token":"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa","expiresAt":"2026-10-02T10:00:00.123Z"}"#.utf8))
        }
        let api = OnboardingAPI(baseURL: URL(string: "http://localhost:3000")!, session: session)
        let value: BindingCode = try await api.request("binding", method: "POST", token: "test-token")
        XCTAssertEqual(BindingPayload.token(from: value.payload), value.token)
        XCTAssertEqual(value.expiresAt.timeIntervalSince1970, 1790935200.123, accuracy: 0.001)
        for (status, kind) in [(401, APIError.Kind.unauthorized), (404, .unavailable), (410, .invalidCode), (400, .invalidInput), (503, .unavailable)] {
            StubURLProtocol.handler = { _ in (status, Data()) }
            do { let _: BindingCode = try await api.request("binding"); XCTFail("Expected error") }
            catch let error as APIError { XCTAssertEqual(error.kind, kind) }
        }
        StubURLProtocol.handler = { _ in (200, Data("broken json".utf8)) }
        do { let _: BindingCode = try await api.request("binding"); XCTFail("Expected error") }
        catch let error as APIError { XCTAssertEqual(error.kind, .other) }
    }
    @MainActor func testExpiredSessionIsCleared() async throws {
        let vault = SessionVault(service: "org.safeorbit.test." + UUID().uuidString)
        defer { vault.clear(); StubURLProtocol.handler = nil }
        do { try vault.save("expired-test-token") }
        catch let error as SessionVaultError where error.status == errSecMissingEntitlement {
            throw XCTSkip("Unsigned simulator build cannot access Keychain; run the ad-hoc signed test command.")
        }
        let config = URLSessionConfiguration.ephemeral; config.protocolClasses = [StubURLProtocol.self]
        let network = URLSession(configuration: config); defer { network.invalidateAndCancel() }
        StubURLProtocol.handler = { _ in (401, Data()) }
        let store = OnboardingStore(api: .init(baseURL: URL(string: "http://localhost")!, session: network), vault: vault)
        await store.restore()
        XCTAssertNil(vault.load()); XCTAssertNil(store.token); XCTAssertNotNil(store.error); XCTAssertFalse(store.busy)
        try vault.save("expired-elder-token", role: "elder")
        let elderStore = OnboardingStore(api: .init(baseURL: URL(string: "http://localhost")!, session: network), vault: vault)
        await elderStore.restore()
        XCTAssertNil(vault.load()); XCTAssertEqual(elderStore.screen, .scan)
        XCTAssertNotEqual(elderStore.error, APIError(kind: .unauthorized).localizedDescription)
    }
    @MainActor func testProfileFailurePreservesDraftAndBindingTransitions() async throws {
        let vault = SessionVault(service: "org.safeorbit.test." + UUID().uuidString)
        defer { vault.clear(); StubURLProtocol.handler = nil }
        do { try vault.save("test-family") }
        catch let error as SessionVaultError where error.status == errSecMissingEntitlement {
            throw XCTSkip("Keychain requires an ad-hoc signed simulator build.")
        }
        let config = URLSessionConfiguration.ephemeral; config.protocolClasses = [StubURLProtocol.self]
        let network = URLSession(configuration: config); defer { network.invalidateAndCancel() }
        let store = OnboardingStore(api: .init(baseURL: URL(string: "http://localhost")!, session: network), vault: vault)
        StubURLProtocol.handler = { _ in (200, Data(#"{"role":"caregiver","caregiver":{"id":"test","phone":"+8613800000000"}}"#.utf8)) }
        await store.restore(); XCTAssertEqual(store.screen, .profile)
        store.screen = .phone; store.caregiverPhone = PhoneEntry("+442071234567").fullNumber
        StubURLProtocol.handler = { _ in (503, Data()) }
        await store.savePhone()
        XCTAssertEqual(store.screen, .phone)
        XCTAssertEqual(PhoneEntry(store.caregiverPhone).country.code, "+44")
        XCTAssertEqual(PhoneEntry(store.caregiverPhone).digits, "2071234567")
        StubURLProtocol.handler = { request in
            XCTAssertEqual(request.url?.path, "/v1/caregiver")
            XCTAssertEqual(request.httpMethod, "PUT")
            return (200, Data(#"{"id":"test","phone":"+442071234567"}"#.utf8))
        }
        await store.savePhone(); XCTAssertEqual(store.screen, .profile)
        store.elder.name = "Li Lan"; store.elder.phone = "+8613800000000"
        store.elder.timezone = "Asia/Shanghai"
        let draft = store.elder
        StubURLProtocol.handler = { _ in (503, Data()) }
        await store.saveProfile()
        XCTAssertEqual(store.elder, draft); XCTAssertEqual(store.screen, .profile); XCTAssertNotNil(store.error)
        StubURLProtocol.handler = { request in
            XCTAssertEqual(request.httpMethod, "PUT")
            var body = request.httpBody ?? Data()
            if let stream = request.httpBodyStream {
                stream.open(); defer { stream.close() }
                var buffer = [UInt8](repeating: 0, count: 1024)
                while stream.hasBytesAvailable {
                    let count = stream.read(&buffer, maxLength: buffer.count)
                    guard count > 0 else { break }
                    body.append(contentsOf: buffer.prefix(count))
                }
            }
            let sent = try JSONDecoder().decode(ElderProfile.self, from: body)
            XCTAssertEqual(sent.callName, "Li Lan")
            XCTAssertEqual(sent.timezone, "Asia/Shanghai")
            return (200, Data(#"{"id":"elder","name":"Li Lan","callName":"Grandma","phone":"+8613800000000","timezone":"Asia/Shanghai","bound":false}"#.utf8))
        }
        await store.saveProfile(); XCTAssertEqual(store.screen, .familyBinding); XCTAssertNil(store.error)
        StubURLProtocol.handler = { _ in (200, Data(#"{"token":"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa","expiresAt":"2099-10-02T10:00:00Z"}"#.utf8)) }
        await store.generateCode(); XCTAssertNotNil(store.code)
        StubURLProtocol.handler = { _ in (200, Data(#"{"id":"elder","name":"Li Lan","callName":"Grandma","phone":"+8613800000000","timezone":"Asia/Shanghai","bound":true}"#.utf8)) }
        await store.refreshBinding(); XCTAssertTrue(store.elder.bound); XCTAssertNil(store.code); XCTAssertEqual(store.screen, .caregiverHome)
        StubURLProtocol.handler = { _ in (503, Data()) }
        await store.signOut(); XCTAssertNil(vault.load()); XCTAssertNil(store.token); XCTAssertEqual(store.screen, .role)
    }
    @MainActor func testRenderPagesForVisualReview() async throws {
        var profile = ElderProfile(); profile.name = "Li Lan"; profile.callName = "Grandma"
        profile.phone = "+86 138 0000 0000"; profile.timezone = "Asia/Shanghai"
        let code = BindingCode(token: String(repeating: "a", count: 43), expiresAt: Date().addingTimeInterval(300))
        let config = URLSessionConfiguration.ephemeral; config.protocolClasses = [StubURLProtocol.self]
        let network = URLSession(configuration: config)
        defer { network.invalidateAndCancel(); StubURLProtocol.handler = nil }
        StubURLProtocol.handler = { _ in (200, Data(#"{"id":"preview","nonce":"preview-nonce"}"#.utf8)) }
        let authStore = OnboardingStore(api: .init(baseURL: URL(string: "http://localhost")!, session: network))
        await authStore.prepareLogin()
#if DEBUG
        let previewStore = OnboardingStore(previewAccessEnabled: true)
        previewStore.email = "person@example.com"; previewStore.password = "password123"
        await previewStore.signInWithEmail()
#endif
        let sampleLocation = LocationPreviewData.snapshot()
        var pages: [(String, AnyView)] = [
            ("role", AnyView(RolePage(family: {}, elder: {}))),
            ("login", AnyView(LoginPage(store: authStore))),
            ("login-warning", AnyView(LoginPage(store: authStore).safeAreaInset(edge: .bottom) {
                BottomNotice(message: "Check your connection and try again.", dismiss: {})
            })),
            ("signup", AnyView(SignupPage(store: authStore))),
            ("email-signup", AnyView(EmailSignupPage(store: OnboardingStore()))),
            ("reset-password", AnyView(ForgotPasswordPage(store: OnboardingStore()))),
            ("phone", AnyView(PhonePage(phone: .constant("+86 138 0000 0000"), busy: false, next: {}))),
            ("phone-empty", AnyView(PhonePage(phone: .constant(""), busy: false, next: {}))),
            ("phone-invalid", AnyView(PhonePage(phone: .constant("+861"), busy: false, next: {}))),
            ("phone-other-region", AnyView(PhonePage(phone: .constant("+4915123456789"), busy: false, next: {}))),
            ("profile", AnyView(ProfilePage(profile: .constant(profile), busy: false, next: {}))),
            ("binding", AnyView(FamilyBindingPage(profile: profile, code: code, busy: false, generate: {}, refresh: {}, edit: {}))),
            ("expired", AnyView(FamilyBindingPage(profile: profile, code: .init(token: code.token, expiresAt: .distantPast), busy: false, generate: {}, refresh: {}, edit: {}))),
            ("scan", AnyView(ScanPage(busy: false, payload: .constant(""), bind: { _ in }))),
            ("ready", AnyView(ElderReadyPage(profile: profile))),
            ("location", AnyView(ZStack { LocationPage(profile: profile, snapshot: sampleLocation, message: nil, loading: false, refresh: {}, agent: {}, navigate: {}); VStack { Spacer(); CaregiverTabBar(selection: .constant(.location)) } })),
            ("location-empty", AnyView(ZStack { LocationPage(profile: profile, snapshot: nil, message: nil, loading: false, refresh: {}, agent: {}, navigate: {}); VStack { Spacer(); CaregiverTabBar(selection: .constant(.location)) } })),
            ("navigation-unavailable", AnyView(WalkingNavigationPage(snapshot: nil, name: profile.name, end: {})))
        ]
#if DEBUG
        pages.append(("location-interactive-preview", AnyView(CaregiverHomePage(store: previewStore))))
        pages.append(("location-settings-preview", AnyView(CaregiverHomePage(store: previewStore, settingsInitiallyOpen: true))))
#endif
        let folder = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent("FrontendSnapshots")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        for (name, page) in pages {
            let data = try await snapshot(page, size: CGSize(width: 393, height: 852),
                                          waitMilliseconds: name.hasPrefix("location") ? 2500 : 120)
            try data.write(to: folder.appendingPathComponent(name + ".png"))
            let attachment = XCTAttachment(data: data, uniformTypeIdentifier: "public.png")
            attachment.name = name; attachment.lifetime = .keepAlways; add(attachment)
        }
        let large = AnyView(ProfilePage(profile: .constant(profile), busy: false, next: {}).environment(\.dynamicTypeSize, .accessibility2))
        try await snapshot(large, size: CGSize(width: 375, height: 812)).write(to: folder.appendingPathComponent("profile-large-text.png"))
        let locationLarge = AnyView(LocationPage(profile: profile, snapshot: sampleLocation, message: nil, loading: false, refresh: {}, agent: {}, navigate: {})
            .environment(\.dynamicTypeSize, .accessibility2))
        try await snapshot(locationLarge, size: CGSize(width: 375, height: 812), waitMilliseconds: 2500)
            .write(to: folder.appendingPathComponent("location-large-text.png"))
    }
    @MainActor private func snapshot(_ page: AnyView, size: CGSize, waitMilliseconds: Int = 120) async throws -> Data {
        let previous = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.flatMap(\.windows).first(where: \.isKeyWindow)
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.first as? UIWindowScene)
        let window = UIWindow(windowScene: scene)
        window.frame = CGRect(origin: .zero, size: size)
        window.rootViewController = UIHostingController(rootView: NavigationStack { page }.environment(\.colorScheme, .light))
        window.makeKeyAndVisible()
        defer { window.isHidden = true; previous?.makeKeyAndVisible() }
        window.rootViewController?.view.frame = window.bounds
        window.rootViewController?.view.setNeedsLayout()
        window.rootViewController?.view.layoutIfNeeded()
        window.layoutIfNeeded()
        try await Task.sleep(for: .milliseconds(waitMilliseconds))
        let image = UIGraphicsImageRenderer(size: size).image { _ in
            window.rootViewController!.view.drawHierarchy(in: window.bounds, afterScreenUpdates: true)
        }
        return try XCTUnwrap(image.pngData())
    }
}
final class StubURLProtocol: URLProtocol {
    static var handler: ((URLRequest) throws -> (Int, Data))?
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        do {
            let (status, data) = try Self.handler!(request)
            client?.urlProtocol(self, didReceive: HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: nil, headerFields: nil)!, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data); client?.urlProtocolDidFinishLoading(self)
        } catch { client?.urlProtocol(self, didFailWithError: error) }
    }
    override func stopLoading() {}
}
