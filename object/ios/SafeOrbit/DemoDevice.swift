import Foundation

/// No accounts in the Demo (task T37): each phone registers its role with the care API and
/// sends the returned device token. Registration is repeatable, so the token is kept in memory only.
struct DeviceHousehold: Decodable, Equatable {
    struct Elder: Decodable, Equatable { let name: String; let callName: String; let phone: String; let timezone: String }
    struct Caregiver: Decodable, Equatable { let name: String; let phone: String }
    let elder: Elder
    let caregiver: Caregiver

    var elderProfile: ElderProfile {
        var profile = ElderProfile()
        profile.name = elder.name; profile.callName = elder.callName
        profile.phone = elder.phone; profile.timezone = elder.timezone; profile.bound = true
        return profile
    }
}
struct DeviceRegistration: Decodable {
    let deviceToken: String
    let role: String
    let household: DeviceHousehold
}
/// Safe zone as the care API returns it; `isHome` marks the one zone named Home.
struct RemoteSafeZone: Decodable, Equatable {
    let id: String
    let name: String
    let isHome: Bool
    let center: GeoPoint
    let radiusMeters: Double
}
struct SafeZoneBody: Encodable {
    let name: String
    let center: GeoPoint
    let radiusMeters: Int
    init(_ zone: SafeZone) {
        name = zone.name; center = zone.center
        radiusMeters = Int(zone.radiusMeters.rounded())
    }
}

extension DemoAppRole {
    var apiName: String { self == .elder ? "elder" : "caregiver" }
}

@MainActor final class DemoDevice {
    static let installationKey = "safeorbit.device.installation-id.v1"
    let api: OnboardingAPI
    let role: DemoAppRole
    private let defaults: UserDefaults
    private(set) var token: String?
    /// Household from the latest registration: call name for the reminder, caregiver phone for "Call Family".
    private(set) var household: DeviceHousehold?
    /// APNs device token (hex) once iOS hands it over; sent with every registration (task T38).
    var pushToken: String?

    init(role: DemoAppRole, api: OnboardingAPI = .init(baseURL: ServerConfiguration.baseURL), defaults: UserDefaults = .standard) {
        self.role = role; self.api = api; self.defaults = defaults
    }

    /// Stable per installation; the care API keys the phone's registration on it.
    var installationID: String {
        if let saved = defaults.string(forKey: Self.installationKey) { return saved }
        let fresh = UUID().uuidString
        defaults.set(fresh, forKey: Self.installationKey)
        return fresh
    }

    @discardableResult
    func register() async throws -> DeviceRegistration {
        var body = ["role": role.apiName, "installationId": installationID]
        if let pushToken { body["pushToken"] = pushToken }
        let reply: DeviceRegistration = try await api.request("devices", method: "POST", body: OnboardingAPI.body(body))
        token = reply.deviceToken
        household = reply.household
        return reply
    }

    /// Calls the care API with the device token; a rejected token is dropped so the next call registers again.
    func request<T: Decodable & Sendable>(_ path: String, method: String = "GET", body: Data? = nil) async throws -> T {
        if token == nil { try await register() }
        do { return try await api.request(path, method: method, token: token, body: body) }
        catch let error as APIError where error.kind == .unauthorized { token = nil; throw error }
    }
}
