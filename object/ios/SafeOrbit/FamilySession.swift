import Foundation
import Security
import CryptoKit
import SwiftUI

/// Only explicit Debug launches can enter the historical, preset household.
enum DemoLaunch {
    static var enabled: Bool {
#if DEBUG
        ProcessInfo.processInfo.arguments.contains("-safeorbitDemoFamily") || ProcessInfo.processInfo.arguments.contains("-safeorbitSampleData")
#else
        false
#endif
    }
}

struct FamilySessionReply: Decodable {
    let deviceToken: String?
    let role: String
    let memberId: String
    let isPrimary: Bool
    let household: DeviceHousehold
    var member: FamilyCreateRequest.Person? = nil
}
struct FamilyMember: Decodable, Identifiable, Equatable {
    let id: String
    let name: String
    let role: String
    let isPrimary: Bool
}
struct FamilyMembers: Decodable {
    let inviteCode: String
    let members: [FamilyMember]
}
struct FamilyCreateRequest: Encodable {
    struct Person: Codable { let name: String; let phone: String }
    struct Senior: Encodable { let name: String; let callName: String; let phone: String; let timezone: String }
    struct Home: Encodable { let latitude: Double; let longitude: Double; let radiusMeters: Int }
    let installationId: String
    let deviceToken: String
    let caregiver: Person
    let elder: Senior
    let home: Home
}
struct FamilyJoinRequest: Encodable {
    let installationId: String
    let deviceToken: String
    let inviteCode: String
    let role: String
    let name: String?
    let phone: String?
}
enum FamilyInvite {
    static func normalized(_ value: String) -> String? {
        let code = value.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        return code.range(of: "^[A-Z0-9]{12}$", options: .regularExpression) != nil ? code : nil
    }
}

struct AccountSessionReply: Decodable {
    let accountId: String
    let accountToken: String?
    let email: String
    let family: FamilySessionReply?
}

@MainActor final class FamilySession: ObservableObject {
    static let shared = FamilySession()
    static let consentKey = "safeorbit.family.privacy.v1"
    static let installationKey = "safeorbit.family.installation.v1"
    @Published private(set) var consent: Bool
    @Published private(set) var device: DemoDevice?
    @Published private(set) var session: FamilySessionReply?
    @Published private(set) var account: AccountSessionReply?
    @Published private(set) var members: FamilyMembers?
    @Published private(set) var busy = false
    @Published private(set) var restoring = false
    @Published private(set) var pending = false
    @Published private(set) var viewID = UUID()
    @Published var error: String?
    private let api: OnboardingAPI
    private let vault: SessionVault
    private let accountVault: SessionVault
    private let pendingVault: SessionVault
    private let defaults: UserDefaults
    private var accountToken: String?
    private var recovering = false
    private var workID = UUID()
    private struct Pending: Codable {
        let path: String
        let body: Data
        let token: String
        let role: String
        let caregiver: FamilyCreateRequest.Person?
        var accountId: String? = nil
    }
    private struct LegacyClaim: Codable { let email: String; let memberId: String }
    init(api: OnboardingAPI = .init(baseURL: ServerConfiguration.baseURL),
         vault: SessionVault = .init(service: "org.safeorbit.family.session"),
         pendingVault: SessionVault = .init(service: "org.safeorbit.family.pending"),
         accountVault: SessionVault? = nil,
         defaults: UserDefaults = .standard) {
        self.api = api; self.vault = vault; self.pendingVault = pendingVault; self.defaults = defaults
        self.accountVault = accountVault ?? SessionVault(service: "org.safeorbit.account." + Self.serverID(api.baseURL))
        consent = defaults.bool(forKey: Self.consentKey)
        pending = pendingVault.load() != nil
    }
    private static func serverID(_ url: URL) -> String {
        SHA256.hash(data: Data(url.absoluteString.utf8)).map { String(format: "%02x", $0) }.joined()
    }
    static func chatStorageKey(baseURL: URL, memberId: String) -> String {
        "safeorbit.agent.membership.v2." + serverID(baseURL) + "." + memberId
    }
    private var claimKey: String { "safeorbit.family.legacy-claim." + Self.serverID(api.baseURL) }
    private var emailKey: String { "safeorbit.account.email." + Self.serverID(api.baseURL) }
    var savedEmail: String { defaults.string(forKey: emailKey) ?? "" }
    var isLoggedIn: Bool { account != nil && accountToken != nil }
    var hasLegacyCaregiver: Bool { vault.role() == "caregiver" && vault.load() != nil }
    var hasSavedSession: Bool { accountVault.load() != nil || (vault.role() == "elder" && vault.load() != nil) }
    var installationID: String {
        if let value = defaults.string(forKey: Self.installationKey) { return value }
        let value = UUID().uuidString
        defaults.set(value, forKey: Self.installationKey)
        return value
    }
    func acceptPrivacy() {
        defaults.set(true, forKey: Self.consentKey); defaults.set(true, forKey: AMapRuntime.consentKey); consent = true
    }
    func declinePrivacy() { error = "You can continue only after agreeing to the privacy notice." }
    static func freshToken() throws -> String {
        var bytes = [UInt8](repeating: 0, count: 32)
        let status = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        guard status == errSecSuccess else { throw SessionVaultError(status: status) }
        return Data(bytes).base64EncodedString().replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_").replacingOccurrences(of: "=", with: "")
    }
    func authenticate(email: String, password: String, registering: Bool, claimLegacy: Bool = false) async {
        guard consent, !busy, !isLoggedIn, EmailAddress.isValid(email),
              registering ? password.count >= 12 : !password.isEmpty else { return }
        let work = UUID(); workID = work
        busy = true; error = nil
        defer { if workID == work { busy = false } }
        let email = EmailAddress.normalized(email)
        do {
            var legacyToken: String?
            if registering && claimLegacy && hasLegacyCaregiver, let token = vault.load() {
                let old: FamilySessionReply = try await api.request("family/session", token: token)
                guard old.role == "caregiver" else { throw APIError(kind: .forbidden) }
                // Validate the old caregiver identity before explicitly claiming its family.
                defaults.set(try JSONEncoder().encode(LegacyClaim(email: email, memberId: old.memberId)), forKey: claimKey)
                legacyToken = token
            }
            let reply: AccountSessionReply = try await api.request(registering ? "account/register" : "account/login", method: "POST", token: legacyToken,
                body: OnboardingAPI.body(["email": email, "password": password]))
            try acceptAccount(reply)
        } catch let failure as APIError {
            switch failure.kind {
            case .unauthorized: error = claimLegacy && registering ? "The old family connection is no longer valid. Create an account without importing it." : "Email or password is incorrect."
            case .conflict: error = "This email already has an account. Log in instead."
            default: error = failure.localizedDescription
            }
        } catch { self.error = error.localizedDescription }
    }
    private func acceptAccount(_ reply: AccountSessionReply) throws {
        guard let token = reply.accountToken ?? accountToken ?? accountVault.load(), !token.isEmpty else { throw APIError(kind: .other) }
        try accountVault.save(token, role: "caregiver")
        accountToken = token; account = reply
        defaults.set(reply.email, forKey: emailKey)
        if let family = reply.family {
            guard family.role == "caregiver", let scoped = family.deviceToken, !scoped.isEmpty else { throw APIError(kind: .other) }
            if let raw = defaults.data(forKey: claimKey), let claim = try? JSONDecoder().decode(LegacyClaim.self, from: raw),
               claim.email == reply.email, claim.memberId == family.memberId {
                // Historical Demo and family transcripts shared one key, so their provenance
                // cannot be established. Preserve that key exclusively for the historical Demo.
                vault.clear()
            }
            activate(family, token: scoped)
        } else { unmountFamily(deleteHistory: false) }
        defaults.removeObject(forKey: claimKey)
    }
    func create(caregiverName: String, caregiverPhone: String, elder: ElderProfile, home: GeoPoint, radius: Int) async {
        guard consent, !busy, !recovering, device == nil, isLoggedIn else { return }
        if pending { await retryPending(); return }
        guard !caregiverName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              caregiverName.count <= 60, PhoneNumber.isValid(caregiverPhone), elder.isValid,
              !elder.callName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              elder.callName.count <= 60, home.isValid else { error = "Check your details and home location."; return }
        await perform {
            let token = try Self.freshToken()
            let person = FamilyCreateRequest.Person(name: caregiverName.trimmingCharacters(in: .whitespacesAndNewlines), phone: PhoneNumber.normalized(caregiverPhone))
            let body = FamilyCreateRequest(installationId: self.installationID, deviceToken: token, caregiver: person,
                elder: .init(name: elder.name.trimmingCharacters(in: .whitespacesAndNewlines), callName: elder.callName.trimmingCharacters(in: .whitespacesAndNewlines), phone: PhoneNumber.normalized(elder.phone), timezone: elder.timezone),
                home: .init(latitude: home.latitude, longitude: home.longitude, radiusMeters: radius))
            try await self.submit(Pending(path: "family", body: OnboardingAPI.json(body), token: token, role: "caregiver", caregiver: person, accountId: self.account?.accountId))
        }
    }
    func join(code: String, role: DemoAppRole, name: String = "", phone: String = "") async {
        guard consent, !busy, !recovering, device == nil, role == .elder ? !isLoggedIn && !hasSavedSession : isLoggedIn else { return }
        if pending { await retryPending(); return }
        guard let code = FamilyInvite.normalized(code) else { error = "Check the 12-character invitation code."; return }
        guard role == .elder || (!name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && name.count <= 60 && PhoneNumber.isValid(phone)) else {
            error = "Enter your name and phone number, including country code."; return
        }
        await perform {
            let token = try Self.freshToken()
            let person = role == .caregiver ? FamilyCreateRequest.Person(name: name.trimmingCharacters(in: .whitespacesAndNewlines), phone: PhoneNumber.normalized(phone)) : nil
            let body = FamilyJoinRequest(installationId: self.installationID, deviceToken: token, inviteCode: code, role: role.apiName, name: person?.name, phone: person?.phone)
            try await self.submit(Pending(path: "family/join", body: OnboardingAPI.json(body), token: token, role: role.apiName, caregiver: person, accountId: self.account?.accountId))
        }
    }
    private func submit(_ operation: Pending) async throws {
        guard operation.role != "caregiver" || (isLoggedIn && operation.accountId == account?.accountId) else { throw APIError(kind: .unauthorized) }
        let encoded = try JSONEncoder().encode(operation).base64EncodedString()
        try pendingVault.save(encoded, role: operation.role); pending = true
        let previous = viewID
        do {
            let reply: FamilySessionReply = try await api.request(operation.path, method: "POST",
                token: operation.role == "caregiver" ? accountToken : nil, body: operation.body)
            guard previous == viewID else { throw CancellationError() }
            guard let scoped = reply.deviceToken, !scoped.isEmpty, reply.role == operation.role else { throw APIError(kind: .other) }
            if operation.role == "elder" {
                guard scoped == operation.token else { throw APIError(kind: .other) }
                try vault.save(scoped, role: "elder")
            }
            clearTemporaryData()
            activate(reply, token: scoped)
            if let caregiver = operation.caregiver {
                defaults.set(try JSONEncoder().encode(caregiver), forKey: "safeorbit.family.profile.v1")
                CaregiverSettingsStore(defaults: defaults).applyFamily(reply, ownProfile: caregiver)
            }
            pendingVault.clear(); pending = false
        } catch let failure as APIError {
            guard previous == viewID else { throw CancellationError() }
            if [.invalidInput, .notFound, .invalidCode, .conflict, .forbidden].contains(failure.kind) { pendingVault.clear(); pending = false }
            if failure.kind == .notFound { throw APIError(kind: .invalidCode) }
            throw failure
        }
    }
    func retryPending() async {
        guard consent, !busy, let encoded = pendingVault.load(), let data = Data(base64Encoded: encoded),
              let operation = try? JSONDecoder().decode(Pending.self, from: data) else { return }
        await perform { try await self.submit(operation) }
    }
    func restore() async {
        guard consent, !busy, !recovering else { return }
        let generation = viewID
        let work = UUID(); workID = work
        restoring = device == nil; busy = true
        defer { if workID == work { restoring = false; busy = false } }
        do {
            if let device, let token = device.token {
                let previous = viewID
                let reply: FamilySessionReply = try await api.request("family/session", token: token)
                guard previous == viewID else { return }
                activate(reply, token: token)
            } else if let token = accountVault.load() {
                try await restoreAccount(token)
            } else if vault.role() == "elder", let token = vault.load() {
                let reply: FamilySessionReply = try await api.request("family/session", token: token)
                activate(reply, token: token)
            }
        } catch let failure as APIError where failure.kind == .unauthorized {
            guard generation == viewID else { return }
            unmountFamily(deleteHistory: false)
            if let token = accountVault.load() {
                let recoveryGeneration = viewID
                do { try await restoreAccount(token) }
                catch let e as APIError where e.kind == .unauthorized { if recoveryGeneration == viewID { clearAccount(); error = "Your login expired. Log in again." } }
                catch { if recoveryGeneration == viewID { self.error = error.localizedDescription } }
            } else { vault.clear(); error = "This phone is no longer in the family. Join again with an invitation." }
        } catch { if generation == viewID { self.error = error.localizedDescription } }
    }
    private func restoreAccount(_ token: String) async throws {
        let previous = viewID
        let reply: AccountSessionReply = try await api.request("account/session", method: "POST", token: token)
        guard previous == viewID else { throw CancellationError() }
        accountToken = token
        try acceptAccount(reply)
    }
    private func activate(_ reply: FamilySessionReply, token: String) {
        guard ["elder", "caregiver"].contains(reply.role) else { error = "Unable to restore this family."; return }
        if device?.token != token || session?.memberId != reply.memberId {
            unmountFamily(deleteHistory: false)
            let current = viewID
            device = DemoDevice(role: reply.role == "elder" ? .elder : .caregiver, api: api,
                familyToken: token, household: reply.household,
                chatStorageKey: reply.role == "caregiver" ? Self.chatStorageKey(baseURL: api.baseURL, memberId: reply.memberId) : nil,
                onInvalidation: { [weak self] in
                    guard let self, self.viewID == current else { return }
                    self.credentialsRejected()
                })
        }
        session = reply; error = nil
        CaregiverSettingsStore(defaults: defaults).applyFamily(reply, ownProfile: ownProfile)
    }
    var ownProfile: FamilyCreateRequest.Person? {
        session?.member ?? defaults.data(forKey: "safeorbit.family.profile.v1").flatMap { try? JSONDecoder().decode(FamilyCreateRequest.Person.self, from: $0) }
    }
    func refreshMembers() async {
        guard session?.role == "caregiver", let device else { return }
        await perform { self.members = try await device.request("family/members") }
    }
    func remove(_ member: FamilyMember) async {
        guard session?.isPrimary == true, member.id != session?.memberId, let device else { return }
        await perform {
            let _: EmptyResponse = try await device.request("family/members/" + member.id, method: "DELETE")
            self.members = try await device.request("family/members")
        }
    }
    func leaveFamily() async {
        guard let device else { return }
        await perform {
            do {
                let _: EmptyResponse = try await device.request("family/membership", method: "DELETE")
                self.unmountFamily(deleteHistory: false); self.vault.clear(); self.clearPending()
            } catch let failure as APIError where failure.kind == .conflict {
                guard device.token != nil else { throw CancellationError() }
                self.error = "Invite another caregiver before leaving so someone can take over as primary caregiver."
            }
        }
    }
    func deleteFamily() async {
        guard session?.isPrimary == true, let device else { return }
        await perform {
            let _: EmptyResponse = try await device.request("family", method: "DELETE")
            self.unmountFamily(deleteHistory: true); self.vault.clear(); self.clearPending()
        }
    }
    func logOut() async {
        guard let token = accountToken ?? accountVault.load() else { return }
        // Clear the sensitive view and all local credentials before waiting for the network.
        unmountFamily(deleteHistory: false); clearAccount(); vault.clear(); clearPending()
        let work = UUID(); workID = work
        busy = true; error = nil; restoring = false
        let generation = viewID
        defer { if workID == work { busy = false } }
        do { let _: EmptyResponse = try await api.request("account/session", method: "DELETE", token: token) }
        catch let failure as APIError where failure.kind == .unauthorized {}
        catch { if generation == viewID { self.error = "Logged out on this phone. The server could not confirm logout; reconnect and log in again before continuing." } }
    }
    private func clearAccount() { accountVault.clear(); accountToken = nil; account = nil }
    private func clearPending() { pendingVault.clear(); pending = false }
    func invalidate(message: String? = "This phone is no longer in the family. Join again with an invitation.") {
        unmountFamily(deleteHistory: false); vault.clear(); clearPending(); error = message
    }
    private func credentialsRejected() {
        unmountFamily(deleteHistory: false)
        guard let token = accountToken ?? accountVault.load() else { vault.clear(); error = "This phone is no longer in the family. Join again with an invitation."; return }
        recovering = true; restoring = true
        let generation = viewID
        Task {
            defer { recovering = false; restoring = false }
            do { try await restoreAccount(token) }
            catch let failure as APIError where failure.kind == .unauthorized { if generation == viewID { clearAccount(); error = "Your login expired. Log in again." } }
            catch { if generation == viewID { self.error = error.localizedDescription } }
        }
    }
    private func unmountFamily(deleteHistory: Bool) {
        if deleteHistory, let key = device?.chatStorageKey { defaults.removeObject(forKey: key) }
        viewID = UUID(); device?.revoke(); device = nil; session = nil; members = nil
        clearTemporaryData()
        _ = NotificationRouter.shared.take(for: .elder); _ = NotificationRouter.shared.take(for: .caregiver)
    }
    private func clearTemporaryData() {
        for key in ["safeorbit.caregiver.settings.v1", "safeorbit.home.coordinate.v1", "safeorbit.family.profile.v1"] { defaults.removeObject(forKey: key) }
        PendingFixQueue().clear()
    }
    private func perform(_ action: () async throws -> Void) async {
        guard !busy else { return }
        let work = UUID(); workID = work
        busy = true; error = nil
        let generation = viewID
        defer { if workID == work { busy = false } }
        do { try await action() }
        catch is CancellationError {}
        catch let failure as APIError where failure.kind == .unauthorized {
            guard generation == viewID else { return }
            if device != nil || (isLoggedIn && !recovering) { credentialsRejected() }
            else if !recovering && !isLoggedIn { error = "Log in again to continue." }
        }
        catch { if generation == viewID { self.error = error.localizedDescription } }
    }
}
