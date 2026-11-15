import Foundation
import Security
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

@MainActor final class FamilySession: ObservableObject {
    static let shared = FamilySession()
    static let consentKey = "safeorbit.family.privacy.v1"
    static let installationKey = "safeorbit.family.installation.v1"
    @Published private(set) var consent: Bool
    @Published private(set) var device: DemoDevice?
    @Published private(set) var session: FamilySessionReply?
    @Published private(set) var members: FamilyMembers?
    @Published private(set) var busy = false
    @Published private(set) var restoring = false
    @Published private(set) var pending = false
    @Published var error: String?
    private let api: OnboardingAPI
    private let vault: SessionVault
    private let pendingVault: SessionVault
    private let defaults: UserDefaults
    private var generation = UUID()
    private struct Pending: Codable {
        let path: String
        let body: Data
        let token: String
        let role: String
        let caregiver: FamilyCreateRequest.Person?
    }
    init(api: OnboardingAPI = .init(baseURL: ServerConfiguration.baseURL),
         vault: SessionVault = .init(service: "org.safeorbit.family.session"),
         pendingVault: SessionVault = .init(service: "org.safeorbit.family.pending"),
         defaults: UserDefaults = .standard) {
        self.api = api; self.vault = vault; self.pendingVault = pendingVault; self.defaults = defaults
        consent = defaults.bool(forKey: Self.consentKey)
        pending = pendingVault.load() != nil
    }
    var hasSavedSession: Bool { vault.load() != nil }
    var installationID: String {
        if let value = defaults.string(forKey: Self.installationKey) { return value }
        let value = UUID().uuidString
        defaults.set(value, forKey: Self.installationKey)
        return value
    }
    func acceptPrivacy() {
        defaults.set(true, forKey: Self.consentKey)
        defaults.set(true, forKey: AMapRuntime.consentKey)
        consent = true
    }
    func declinePrivacy() { error = "You can continue only after agreeing to the privacy notice." }
    static func freshToken() throws -> String {
        var bytes = [UInt8](repeating: 0, count: 32)
        let status = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        guard status == errSecSuccess else { throw SessionVaultError(status: status) }
        return Data(bytes).base64EncodedString().replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_").replacingOccurrences(of: "=", with: "")
    }
    func create(caregiverName: String, caregiverPhone: String, elder: ElderProfile, home: GeoPoint, radius: Int) async {
        guard consent, !busy, device == nil, !hasSavedSession else { return }
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
            try await self.submit(Pending(path: "family", body: OnboardingAPI.json(body), token: token, role: "caregiver", caregiver: person))
        }
    }
    func join(code: String, role: DemoAppRole, name: String = "", phone: String = "") async {
        guard consent, !busy, device == nil, !hasSavedSession else { return }
        if pending { await retryPending(); return }
        guard let code = FamilyInvite.normalized(code) else { error = "Check the 12-character invitation code."; return }
        guard role == .elder || (!name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && name.count <= 60 && PhoneNumber.isValid(phone)) else {
            error = "Enter your name and phone number, including country code."; return
        }
        await perform {
            let token = try Self.freshToken()
            let person = role == .caregiver ? FamilyCreateRequest.Person(name: name.trimmingCharacters(in: .whitespacesAndNewlines), phone: PhoneNumber.normalized(phone)) : nil
            let body = FamilyJoinRequest(installationId: self.installationID, deviceToken: token, inviteCode: code, role: role.apiName, name: person?.name, phone: person?.phone)
            try await self.submit(Pending(path: "family/join", body: OnboardingAPI.json(body), token: token, role: role.apiName, caregiver: person))
        }
    }
    private func submit(_ operation: Pending) async throws {
        // Save before the first POST: even a lost response or app restart must reuse this exact request.
        let encoded = try JSONEncoder().encode(operation).base64EncodedString()
        try pendingVault.save(encoded, role: operation.role)
        pending = true
        do {
            let reply: FamilySessionReply = try await api.request(operation.path, method: "POST", body: operation.body)
            guard reply.deviceToken == operation.token, reply.role == operation.role else { throw APIError(kind: .other) }
            try vault.save(operation.token, role: reply.role)
            clearHouseholdData()
            if let caregiver = operation.caregiver {
                defaults.set(try JSONEncoder().encode(caregiver), forKey: "safeorbit.family.profile.v1")
            }
            activate(reply, token: operation.token)
            pendingVault.clear(); pending = false
        } catch let failure as APIError {
            // Definite rejections may be corrected; transport/decoding failures retain the request.
            if [.invalidInput, .notFound, .invalidCode, .conflict, .forbidden].contains(failure.kind) {
                pendingVault.clear(); pending = false
            }
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
        guard consent, !busy, let token = vault.load() else { return }
        restoring = device == nil
        defer { restoring = false }
        let previous = generation
        await perform {
            let reply: FamilySessionReply = try await self.api.request("family/session", token: token)
            guard previous == self.generation else { return }
            self.activate(reply, token: token)
        }
    }
    private func activate(_ reply: FamilySessionReply, token: String) {
        guard ["elder", "caregiver"].contains(reply.role) else { error = "Unable to restore this family."; return }
        session = reply
        if device?.token != token {
            let current = generation
            device = DemoDevice(role: reply.role == "elder" ? .elder : .caregiver, api: api,
                familyToken: token, household: reply.household, onInvalidation: { [weak self] in
                    guard let self, self.generation == current else { return }
                    self.invalidate()
                })
        }
        CaregiverSettingsStore(defaults: defaults).applyFamily(reply, ownProfile: ownProfile)
    }
    var ownProfile: FamilyCreateRequest.Person? {
        defaults.data(forKey: "safeorbit.family.profile.v1").flatMap { try? JSONDecoder().decode(FamilyCreateRequest.Person.self, from: $0) }
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
    func leaveOrDelete() async {
        guard let device, let session else { return }
        await perform {
            let _: EmptyResponse = try await device.request(session.isPrimary ? "family" : "family/membership", method: "DELETE")
            self.invalidate(message: nil)
        }
    }
    func invalidate(message: String? = "This phone is no longer in the family. Join again with an invitation.") {
        generation = UUID()
        device?.revoke(); device = nil; session = nil; members = nil
        vault.clear(); pendingVault.clear(); pending = false
        clearHouseholdData()
        _ = NotificationRouter.shared.take(for: .elder)
        _ = NotificationRouter.shared.take(for: .caregiver)
        error = message
    }
    private func clearHouseholdData() {
        for key in ["safeorbit.caregiver.settings.v1", "safeorbit.agent.sessions.v1", "safeorbit.home.coordinate.v1", "safeorbit.family.profile.v1"] {
            defaults.removeObject(forKey: key)
        }
        PendingFixQueue().clear()
    }
    private func perform(_ action: () async throws -> Void) async {
        guard !busy else { return }
        busy = true; error = nil
        defer { busy = false }
        do { try await action() }
        catch is CancellationError {}
        catch let failure as APIError where failure.kind == .unauthorized { invalidate() }
        catch { self.error = error.localizedDescription }
    }
}
