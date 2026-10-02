import SwiftUI
import AuthenticationServices
import CryptoKit

@MainActor final class OnboardingStore: ObservableObject {
    enum Screen { case role, login, signup, emailSignup, forgotPassword, phone, profile, familyBinding, caregiverHome, scan, elderReady }
    @Published var screen: Screen = .role
    @Published var email = ""
    @Published var password = ""
    @Published var confirmPassword = ""
    @Published private(set) var resetEmailSent = false
    private var googleState: String?
    var emailLoginValid: Bool { EmailAddress.isValid(email) && !password.isEmpty }
    var emailSignupValid: Bool { emailLoginValid && password.count >= 8 && password == confirmPassword }
    @Published var busy = false
    @Published var error: String?
    @Published var elder = ElderProfile()
    @Published var caregiverPhone = ""
    @Published var code: BindingCode?
    @Published private(set) var location: ElderLocationSnapshot?
    @Published private(set) var locationLoading = false
    @Published private(set) var locationError: String?
    @Published var restoring = false
    @Published private(set) var authorizing = false
    @Published private(set) var preparingLogin = false
    var loginInProgress: Bool { busy || authorizing }
    private(set) var token: String?
    private var tokenRole = "caregiver"
    private let api: OnboardingAPI
    private let vault: SessionVault
    private var challenge: AuthChallenge?
    init(api: OnboardingAPI = .init(baseURL: ServerConfiguration.baseURL), vault: SessionVault = .init()) {
        self.api = api; self.vault = vault
    }
    func restore() async {
        guard let saved = vault.load() else { return }
        token = saved; tokenRole = vault.role() ?? "caregiver"; restoring = true
        await perform { self.route(try await self.api.request("session", token: saved) as AppSession) }
        restoring = false
    }
    private func route(_ session: AppSession) {
        tokenRole = session.role
        caregiverPhone = session.caregiver?.phone ?? ""
        if let profile = session.elder { elder = profile }
        if session.role == "elder" { screen = .elderReady }
        else if caregiverPhone.isEmpty { screen = .phone }
        else if session.elder == nil { screen = .profile }
        else { screen = session.elder?.bound == true ? .caregiverHome : .familyBinding }
    }
    private func accept(_ session: AppSession) throws {
        guard ["caregiver", "elder"].contains(session.role),
              session.role != "elder" || session.elder != nil,
              let token = session.token, !token.isEmpty else { throw APIError(kind: .other) }
        try vault.save(token, role: session.role); self.token = token; clearPasswords(); route(session)
    }
    func perform(_ action: () async throws -> Void) async {
        guard !busy else { return }
        busy = true; error = nil
        defer { busy = false }
        do { try await action() }
        catch is CancellationError {}
        catch {
            if let e = error as? APIError, e.kind == .unauthorized, token != nil {
                vault.clear(); token = nil; screen = tokenRole == "elder" ? .scan : .login; challenge = nil
                if tokenRole == "elder" {
                    self.error = "Connection expired. Ask your family for a new code."
                    return
                }
            }
            self.error = (error as? APIError)?.errorDescription ?? (error as? SessionVaultError)?.errorDescription ?? "Something went wrong. Try again."
        }
    }
    func prepareLogin() async {
        guard !loginInProgress, !preparingLogin, challenge == nil else { return }
        preparingLogin = true
        defer { preparingLogin = false }
        do { challenge = try await api.request("auth/challenge", method: "POST") }
        catch is CancellationError {}
        catch { if !loginInProgress && (screen == .login || screen == .signup) { self.error = (error as? APIError)?.errorDescription ?? "Couldn't sign in. Try again." } }
    }
    var loginReady: Bool { challenge != nil }
    func startLogin(authorize: (ASAuthorizationAppleIDRequest) -> Void) async {
        guard !loginInProgress, !preparingLogin else { return }
        if !loginReady { await prepareLogin() }
        guard loginReady, !busy else { return }
        error = nil
        let request = ASAuthorizationAppleIDProvider().createRequest()
        configure(request)
        authorizing = true
        authorize(request)
    }
    func configure(_ request: ASAuthorizationAppleIDRequest) {
        guard let challenge else { return }
        request.nonce = SHA256.hash(data: Data(challenge.nonce.utf8)).map { String(format: "%02x", $0) }.joined()
        request.state = challenge.id
    }
    func completeLogin(_ result: Result<ASAuthorization, Error>) async {
        authorizing = false
        guard let challenge else { return }
        if case .failure(let error) = result, (error as? ASAuthorizationError)?.code == .canceled {
            self.challenge = nil; self.error = nil; return
        }
        switch result {
        case .failure(let error):
            if (error as? ASAuthorizationError)?.code != .canceled { self.error = (error as? APIError)?.errorDescription ?? (error as? SessionVaultError)?.errorDescription ?? "Something went wrong. Try again." }
        case .success(let authorization):
            await perform {
                guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
                      credential.state == challenge.id, let data = credential.identityToken,
                      let identity = String(data: data, encoding: .utf8) else { throw APIError(kind: .other) }
                let session: AppSession = try await self.api.request("auth/apple", method: "POST",
                    body: OnboardingAPI.body(["challengeId": challenge.id, "identityToken": identity]))
                try self.accept(session)
            }
        }
        let message = self.error
        self.challenge = nil
        if screen == .login || screen == .signup { await prepareLogin() }
        if let message { self.error = message }
    }
    private func clearPasswords() { password = ""; confirmPassword = "" }
    func showAuth(_ destination: Screen) {
        guard !loginInProgress else { return }
        screen = destination; error = nil; resetEmailSent = false; clearPasswords()
    }
    func signInWithEmail() async {
        guard !loginInProgress, emailLoginValid else { return }
        await perform {
            let session: AppSession = try await self.api.request("auth/email/login", method: "POST",
                body: OnboardingAPI.body(["email": EmailAddress.normalized(self.email), "password": self.password]))
            try self.accept(session)
        }
    }
    func registerWithEmail() async {
        guard !loginInProgress, emailSignupValid else { return }
        await perform {
            let session: AppSession = try await self.api.request("auth/email/register", method: "POST",
                body: OnboardingAPI.body(["email": EmailAddress.normalized(self.email), "password": self.password]))
            try self.accept(session)
        }
    }
    func sendPasswordReset() async {
        guard !loginInProgress, EmailAddress.isValid(email) else { return }
        await perform {
            let response: [String: Bool] = try await self.api.request("auth/email/forgot-password", method: "POST",
                body: OnboardingAPI.body(["email": EmailAddress.normalized(self.email)]))
            guard response["ok"] == true else { throw APIError(kind: .other) }
            self.resetEmailSent = true
        }
    }
    func startGoogleLogin(authorize: (GoogleChallenge) -> Void) async {
        guard !loginInProgress else { return }
        var result: GoogleChallenge?
        await perform {
            let challenge: GoogleChallenge = try await self.api.request("auth/google/start", method: "POST")
            guard challenge.validatedURL != nil else { throw APIError(kind: .other) }
            result = challenge
        }
        guard let result else { return }
        googleState = result.state; authorizing = true; authorize(result)
    }
    func completeGoogleLogin(_ result: Result<URL, Error>) async {
        guard let state = googleState else { return }
        googleState = nil; authorizing = false
        switch result {
        case .failure(let failure):
            if (failure as? ASWebAuthenticationSessionError)?.code == .canceledLogin { error = nil }
            else { error = (failure as? APIError)?.errorDescription ?? "Couldn't sign in. Try again." }
        case .success(let url):
            await perform {
                guard let code = GoogleChallenge.callbackCode(url, state: state) else { throw APIError(kind: .other) }
                let session: AppSession = try await self.api.request("auth/google", method: "POST",
                    body: OnboardingAPI.body(["code": code, "state": state]))
                try self.accept(session)
            }
        }
    }
    func savePhone() async {
        guard PhoneNumber.isValid(caregiverPhone), let token else { return }
        await perform {
            let _: Caregiver = try await self.api.request("caregiver", method: "PUT", token: token,
                body: OnboardingAPI.body(["phone": PhoneNumber.normalized(self.caregiverPhone)]))
            self.screen = .profile
        }
    }
    func saveProfile() async {
        guard elder.isValid, let token else { return }
        await perform {
            var value = self.elder
            value.name = value.name.trimmingCharacters(in: .whitespacesAndNewlines)
            value.callName = value.callName.trimmingCharacters(in: .whitespacesAndNewlines)
            if value.callName.isEmpty { value.callName = value.name }
            value.phone = PhoneNumber.normalized(value.phone)
            self.elder = try await self.api.request("elder", method: "PUT", token: token, body: JSONEncoder().encode(value))
            self.screen = .familyBinding
        }
    }
    func generateCode() async {
        guard let token, !elder.bound else { return }
        await perform { self.code = try await self.api.request("binding", method: "POST", token: token) }
    }
    func refreshBinding() async {
        guard let token else { return }
        await perform {
            let profile: ElderProfile = try await self.api.request("elder", token: token)
            self.elder = profile
            if profile.bound { self.code = nil; self.screen = .caregiverHome }
        }
    }
    func bind(_ payload: String) async {
        guard let value = BindingPayload.token(from: payload) else {
            error = "Not a SafeOrbit code. Scan again."; return
        }
        await perform {
            let session: AppSession = try await self.api.request("binding/claim", method: "POST",
                body: OnboardingAPI.body(["token": value]))
            try self.accept(session)
        }
    }
    func signOut() async {
        guard let token else { reset(); return }
        guard !busy else { return }
        busy = true
        // Local sign-out must remain possible when the service is offline.
        let _: [String: Bool]? = try? await api.request("session", method: "DELETE", token: token)
        reset(); busy = false
    }
    func refreshLocation() async {
        guard let token, screen == .caregiverHome, !locationLoading else { return }
        locationLoading = true
        defer { locationLoading = false }
        do {
            let latest: ElderLocationSnapshot = try await api.request("location", token: token)
            guard latest.coordinate.isValid else { throw APIError(kind: .other) }
            location = latest
            locationError = nil
        } catch is CancellationError {
        } catch {
            if let apiError = error as? APIError, apiError.kind == .unauthorized {
                reset(); screen = .login
                self.error = "Session expired. Sign in again."
            } else {
                locationError = (error as? APIError)?.errorDescription ?? "Location is unavailable. Try again."
            }
        }
    }
    func reset() {
        vault.clear(); token = nil; elder = .init(); code = nil; challenge = nil
        caregiverPhone = ""; email = ""; clearPasswords(); googleState = nil; resetEmailSent = false
        screen = .role; error = nil; authorizing = false; location = nil; locationError = nil; locationLoading = false
    }
}
