import Foundation

// Caregiver phone services for risk and alerts (task T38): the agent and notification switches kept in
// step with the care API, and the risk event page's data and actions.

/// The phone keeps its switches (so the settings page works offline); the care API acts on its copy.
/// At launch and on returning to the foreground the phone takes the server's values, unless a change
/// made here has not reached the server yet, in which case the phone's values are sent first.
@MainActor final class CaregiverSettingsSync {
    private let device: DemoDevice
    private let settings: CaregiverSettingsStore
    private(set) var pendingUpload = false
    init(device: DemoDevice, settings: CaregiverSettingsStore) {
        self.device = device; self.settings = settings
        settings.onServerSettingChange = { [weak self] change in
            guard let self else { return }
            Task { await self.push(change) }
        }
    }

    func sync() async {
        do {
            let server: CaregiverServerSettings
            if pendingUpload {
                server = try await device.request("caregiver-settings", method: "PUT", body: OnboardingAPI.json(settings.serverSettings))
            } else {
                server = try await device.request("caregiver-settings")
            }
            pendingUpload = false
            settings.applyServerSettings(server)
        } catch is CancellationError {
        } catch {}
    }

    /// Sends one changed switch (a partial update); on failure the next sync sends all four.
    func push(_ change: [String: Bool]) async {
        do {
            let server: CaregiverServerSettings = try await device.request("caregiver-settings", method: "PUT", body: OnboardingAPI.json(change))
            if !pendingUpload { settings.applyServerSettings(server) }
        } catch is CancellationError {
        } catch { pendingUpload = true }
    }
}

@MainActor protocol RiskEventClient {
    func detail(_ id: String) async throws -> RiskEventDetail
    func markMet(_ id: String) async throws -> RiskEventDetail
    func markFalseAlarm(_ id: String) async throws -> RiskEventDetail
    func recordCall(riskEventID: String?) async
}
@MainActor struct DeviceRiskEventClient: RiskEventClient {
    let device: DemoDevice
    func detail(_ id: String) async throws -> RiskEventDetail { try await device.request("risk-events/\(id)") }
    func markMet(_ id: String) async throws -> RiskEventDetail { try await device.request("risk-events/\(id)/met", method: "POST") }
    func markFalseAlarm(_ id: String) async throws -> RiskEventDetail {
        try await device.request("risk-events/\(id)/false-alarm", method: "POST")
    }
    /// "Call" is recorded before the system dialler opens; the App never learns whether the call connected.
    func recordCall(riskEventID: String?) async {
        let body = riskEventID.flatMap { try? OnboardingAPI.body(["riskEventId": $0]) }
        let _: EmptyResponse? = try? await device.request("calls", method: "POST", body: body)
    }
}

@MainActor final class RiskEventStore: ObservableObject {
    let id: String
    @Published private(set) var detail: RiskEventDetail?
    @Published private(set) var error: String?
    @Published private(set) var busy = false
    private let client: RiskEventClient?

    init(id: String, client: RiskEventClient?, detail: RiskEventDetail? = nil) {
        self.id = id; self.client = client; self.detail = detail
    }

    func load() async {
        guard let client else { if detail == nil { error = "Risk details are unavailable." }; return }
        do { detail = try await client.detail(id); error = nil }
        catch is CancellationError {}
        catch { if detail == nil || (error as? APIError)?.kind != .network { self.error = Self.message(error) } }
    }
    func markMet() async { await perform { try await $0.markMet(self.id) } }
    func markFalseAlarm() async { await perform { try await $0.markFalseAlarm(self.id) } }
    func recordCall() async { await client?.recordCall(riskEventID: id) }

    private func perform(_ action: (RiskEventClient) async throws -> RiskEventDetail) async {
        guard let client, !busy else { return }
        busy = true
        defer { busy = false }
        do { detail = try await action(client); error = nil }
        catch is CancellationError {}
        catch {
            let message = (error as? APIError)?.kind == .invalidCode ? "This risk has already changed. Showing the latest." : Self.message(error)
            await load()
            self.error = message
        }
    }

    static func message(_ error: Error) -> String {
        switch (error as? APIError)?.kind {
        case .network: return "Can't reach the SafeOrbit server. Check the connection."
        case .notFound: return "This risk event is no longer available."
        default: return "Couldn't update the risk event. Try again."
        }
    }
}
