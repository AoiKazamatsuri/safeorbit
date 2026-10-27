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
    var emailLoginValid: Bool { EmailAddress.isValid(email) && password.count >= 8 }
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
    let previewAccessEnabled: Bool
    let homeAccessEnabled: Bool
    /// Live Demo caregiver phone (task T37): registered with the care API instead of an account.
    let device: DemoDevice?
    /// Plans home-to-zone walking routes for the care agent's deviation check (task T38).
    private let routePlanner: ReferenceRoutePlanning?
    private(set) var previewSession = false
    private var challenge: AuthChallenge?
    init(api: OnboardingAPI = .init(baseURL: ServerConfiguration.baseURL), vault: SessionVault = .init(), previewAccessEnabled: Bool = false, homeAccessEnabled: Bool = false,
         device: DemoDevice? = nil, routePlanner: ReferenceRoutePlanning? = nil) {
        self.api = api; self.vault = vault; self.device = device
        self.routePlanner = routePlanner ?? (device == nil ? nil : AMapReferenceRoutePlanner())
        self.homeAccessEnabled = homeAccessEnabled
#if DEBUG
        self.previewAccessEnabled = previewAccessEnabled
#else
        self.previewAccessEnabled = false
#endif
        if homeAccessEnabled { enterPreviewHome() }
        else if device != nil { screen = .caregiverHome }
    }
    func restore() async {
        if homeAccessEnabled || previewAccessEnabled || device != nil { return }
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
#if DEBUG
        if previewAccessEnabled { enterPreviewHome(); return }
#endif
        await perform {
            let session: AppSession = try await self.api.request("auth/email/login", method: "POST",
                body: OnboardingAPI.body(["email": EmailAddress.normalized(self.email), "password": self.password]))
            try self.accept(session)
        }
    }
    func registerWithEmail() async {
        guard !loginInProgress, emailSignupValid else { return }
#if DEBUG
        if previewAccessEnabled { enterPreviewHome(); return }
#endif
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
        guard !homeAccessEnabled, device == nil else { return }
        guard let token else { reset(); return }
        guard !busy else { return }
        busy = true
        // Local sign-out must remain possible when the service is offline.
        let _: [String: Bool]? = try? await api.request("session", method: "DELETE", token: token)
        reset(); busy = false
    }
    /// Live mode keeps the location page current: one refresh every 3 s while the page is shown
    /// (engineering architecture section 8, caregiver refresh interval).
    func followLocation(every interval: Duration = .seconds(3)) async {
        while !Task.isCancelled {
            await refreshLocation()
            try? await Task.sleep(for: interval)
        }
    }
    /// Saves a safe zone edit to the care API, then reloads so the map shows the stored zones.
    func persistZone(_ change: SafeZoneChange) async throws {
        guard let device else { return }
        var needsRoute: RemoteSafeZone?
        switch change {
        case .save(let zone):
            let previous = location?.safeZones.first { $0.id == zone.id }
            let saved: RemoteSafeZone = try await device.request(previous != nil ? "safe-zones/\(zone.id)" : "safe-zones",
                method: previous != nil ? "PUT" : "POST", body: OnboardingAPI.json(SafeZoneBody(zone)))
            // The care API drops a moved zone's route; a new or moved zone gets a newly planned one.
            if !saved.isHome && previous?.center != saved.center { needsRoute = saved }
        case .delete(let zone):
            let _: EmptyResponse = try await device.request("safe-zones/\(zone.id)", method: "DELETE")
        }
        while locationLoading { try? await Task.sleep(for: .milliseconds(100)) }
        await refreshLocation()
        if let needsRoute { await uploadReferenceRoute(zoneID: needsRoute.id, to: needsRoute.center) }
    }
    /// Plans the walking route from home to the zone with AMap and uploads it in WGS-84. Without a route
    /// (on the simulator AMap is compiled out, or offline) the care agent simply has no reference there,
    /// so nothing is shown to the caregiver.
    func uploadReferenceRoute(zoneID: String, to center: GeoPoint) async {
        guard let device, let routePlanner,
              let home = location?.safeZones.first(where: \.isHomeZone)?.center else { return }
        do {
            let points = try await routePlanner.plan(from: home, to: center)
            guard points.count >= 2 else { return }
            let _: ReferenceRouteReply = try await device.request("safe-zones/\(zoneID)/route", method: "PUT",
                body: OnboardingAPI.json(ReferenceRouteBody(points: points)))
        } catch {}
    }
    /// Sends this phone's APNs token with a fresh registration so the care API can push to it.
    func registerPushToken(_ token: String) async {
        guard let device, device.pushToken != token else { return }
        device.pushToken = token
        _ = try? await device.register()
    }
    /// Records a call from the person card before the system dialler opens (linked to the current risk).
    func recordCall() async {
        guard let device else { return }
        await DeviceRiskEventClient(device: device).recordCall(riskEventID: location?.riskEventId)
    }
    private func refreshLive(_ device: DemoDevice) async {
        guard !locationLoading else { return }
        locationLoading = true
        defer { locationLoading = false }
        do {
            if device.token == nil {
                let household = try await device.register().household
                elder = household.elderProfile
                caregiverPhone = household.caregiver.phone
            }
            let latest: ElderLocationSnapshot = try await device.request("location")
            guard latest.coordinate.isValid else { throw APIError(kind: .other) }
            location = latest
            locationError = nil
        } catch is CancellationError {
        } catch let error as APIError where error.kind == .notFound {
            location = nil
            locationError = "Waiting for the senior's phone to share its location."
        } catch let error as APIError where error.kind == .network {
            locationError = "Can't reach the SafeOrbit server. Check that this phone is on the same Wi-Fi as the computer."
        } catch let error as APIError where error.kind == .unauthorized {
            locationError = "Reconnecting to the SafeOrbit server…"  // the next refresh registers again
        } catch {
            locationError = (error as? APIError)?.errorDescription ?? "Location is unavailable. Try again."
        }
    }
    func refreshLocation() async {
        if previewSession {
            location = LocationPreviewData.snapshot()
            return
        }
        if let device { await refreshLive(device); return }
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
        previewSession = false
        caregiverPhone = ""; email = ""; clearPasswords(); googleState = nil; resetEmailSent = false
        screen = .role; error = nil; authorizing = false; location = nil; locationError = nil; locationLoading = false
    }

    private func enterPreviewHome() {
        previewSession = true
        token = nil
        elder.name = "Li Lan"
        elder.callName = "Li Lan"
        elder.phone = "+12025550100" // Reserved fictional number for the sample call handoff.
        elder.bound = true
        location = LocationPreviewData.snapshot()
        clearPasswords()
        error = nil
        screen = .caregiverHome
    }
}
