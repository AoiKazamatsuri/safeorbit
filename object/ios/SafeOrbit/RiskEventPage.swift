import SwiftUI
import MapKit

struct RiskEventSelection: Identifiable, Equatable {
    let id: String
    /// A new value reopens the page with freshly loaded data, e.g. after a notification tap.
    var opened = UUID()
}

/// Caregiver risk event page (product design section 5.3, task T38): where she is and her trail, the
/// risk level, behavior and duration, the agent's account, help already given and a timeline; then
/// "Call senior", "Navigate", "We've Met" and, after resolution, "Mark as False Alarm".
/// Uses the settings page frame: 16 pt page margins and cards, 44 pt tap targets (section 10).
struct RiskEventPage: View {
    @StateObject private var store: RiskEventStore
    let profile: ElderProfile
    let navigate: () -> Void
    let back: () -> Void
    /// Polls while open, so the page shows a resolution or new help without a manual refresh.
    var refreshInterval: Duration = .seconds(5)
    @Environment(\.openURL) private var openURL
    @Environment(\.scenePhase) private var scenePhase
    @State private var camera: MapCameraPosition = .automatic
    @State private var framedEvent: String?
    @State private var confirmingMet = false
    @State private var confirmingFalseAlarm = false

    init(store: RiskEventStore, profile: ElderProfile, navigate: @escaping () -> Void, back: @escaping () -> Void) {
        _store = StateObject(wrappedValue: store)
        self.profile = profile; self.navigate = navigate; self.back = back
    }

    private var canCall: Bool { PhoneNumber.isValid(profile.phone) }

    var body: some View {
        SettingsPage("Risk event", back: back) {
            if let detail = store.detail {
                if let error = store.error { SettingsCard { SettingsNote(text: error) } }
                summary(detail)
                actions(detail)
                map(detail)
                SettingsSection("What happened") {
                    SettingsCard {
                        SettingsNote(text: detail.explanation?.isEmpty == false ? detail.explanation!
                                     : "The agent's account of this event will appear here.")
                    }
                }
                SettingsSection("Help given") {
                    SettingsCard {
                        if detail.help.isEmpty { SettingsNote(text: "No help has been given yet.") }
                        ForEach(Array(detail.help.enumerated()), id: \.offset) { index, item in
                            if index > 0 { Divider() }
                            row(time: item.at, text: item.text, symbol: Self.symbol(help: item))
                        }
                    }.accessibilityIdentifier("risk-event-help")
                }
                SettingsSection("Timeline") {
                    SettingsCard {
                        ForEach(Array(detail.timeline.enumerated()), id: \.offset) { index, item in
                            if index > 0 { Divider() }
                            row(time: item.at, text: item.text, symbol: nil)
                        }
                    }.accessibilityIdentifier("risk-event-timeline")
                }
            } else if let error = store.error {
                SettingsCard {
                    SettingsNote(text: error)
                    Button("Try again") { Task { await store.load() } }.frame(minHeight: OrbitLayout.minimumHitSize)
                }
            } else {
                ProgressView().tint(OrbitStyle.teal).frame(maxWidth: .infinity, minHeight: 120)
            }
        }
        .task(id: scenePhase) {
            guard scenePhase == .active else { return }
            while !Task.isCancelled {
                await store.load()
                do { try await Task.sleep(for: refreshInterval) } catch { return }
            }
        }
        .confirmationDialog("Have you met her?", isPresented: $confirmingMet, titleVisibility: .visible) {
            Button("We've Met") { Task { await store.markMet() } }
            Button("Cancel", role: .cancel) {}
        } message: { Text("This resolves the risk now, even if her phone is offline.") }
        .confirmationDialog("Mark as a false alarm?", isPresented: $confirmingFalseAlarm, titleVisibility: .visible) {
            Button("Mark as False Alarm") { Task { await store.markFalseAlarm() } }
            Button("Cancel", role: .cancel) {}
        } message: { Text("False alarms are left out of the calendar and trends.") }
        .onChange(of: store.detail?.id, initial: true) { _, _ in frameMap() }
    }

    private func summary(_ detail: RiskEventDetail) -> some View {
        SettingsCard {
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 12) { levelBadge(detail); Spacer(minLength: 8); statusLabel(detail) }
                VStack(alignment: .leading, spacing: 8) { levelBadge(detail); statusLabel(detail) }
            }
            Text(detail.headline).orbitDisplayFont(20).fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("risk-event-headline")
            VStack(alignment: .leading, spacing: 6) {
                fact("Behavior", detail.anomalyText)
                fact("Duration", detail.durationText)
                fact("Started", detail.anomalyStartedAt.formatted(date: .omitted, time: .shortened))
            }
        }
    }
    private func levelBadge(_ detail: RiskEventDetail) -> some View {
        Label(detail.riskState.label, systemImage: "exclamationmark.circle")
            .caregiverText(.secondary)
            .foregroundStyle(detail.riskState == .high ? .white : .black)
            .padding(.horizontal, 9).padding(.vertical, 4)
            .background(detail.riskState.color, in: Capsule())
            .fixedSize()
    }
    private func statusLabel(_ detail: RiskEventDetail) -> some View {
        Text(detail.statusText).caregiverText(.secondary).foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityIdentifier("risk-event-status")
    }
    private func fact(_ label: String, _ value: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(label).caregiverText(.secondary).foregroundStyle(.secondary)
            Spacer(minLength: 8)
            Text(value).caregiverText(.secondary).multilineTextAlignment(.trailing)
        }
    }

    private func actions(_ detail: RiskEventDetail) -> some View {
        VStack(spacing: 12) {
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 12) { callButton; navigateButton }
                VStack(spacing: 12) { callButton; navigateButton }
            }
            if detail.canMarkMet {
                actionButton("We've Met", symbol: "person.2.fill", filled: true, identifier: "risk-event-met") { confirmingMet = true }
            }
            if detail.canMarkFalseAlarm {
                actionButton("Mark as False Alarm", symbol: "flag", filled: false, identifier: "risk-event-false-alarm") {
                    confirmingFalseAlarm = true
                }
            }
        }
        .disabled(store.busy)
    }
    private var callButton: some View {
        actionButton("Call senior", symbol: "phone.fill", filled: true, identifier: "risk-event-call") {
            guard canCall, let url = URL(string: "tel:\(PhoneNumber.normalized(profile.phone))") else { return }
            Task { await store.recordCall(); openURL(url) }
        }.disabled(!canCall)
    }
    private var navigateButton: some View {
        actionButton("Navigate", symbol: "arrow.up.right", filled: false, identifier: "risk-event-navigate") {
            back(); navigate()
        }
    }
    private func actionButton(_ title: String, symbol: String, filled: Bool, identifier: String,
                              action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: symbol).caregiverText()
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, minHeight: 50).padding(.horizontal, 12)
                .foregroundStyle(filled ? .white : OrbitStyle.teal)
                .background(filled ? OrbitStyle.teal : .white, in: Capsule())
                .overlay(Capsule().stroke(OrbitStyle.teal, lineWidth: filled ? 0 : 1))
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(identifier)
        .layoutProbe(identifier)
    }

    private func map(_ detail: RiskEventDetail) -> some View {
        AMapConsentSurface {
            AMapCanvas(camera: $camera, markers: markers(detail),
                       lines: CaregiverTrailStyle.lines(coordinates: detail.trail.filter(\.isValid).map(\.appleCoordinate)))
        }
        .frame(height: 240)
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .accessibilityIdentifier("risk-event-map")
    }
    private func markers(_ detail: RiskEventDetail) -> [AMapMarker] {
        guard let point = detail.coordinate, point.isValid else { return [] }
        return [AMapMarker(id: "senior", coordinate: point.appleCoordinate,
                           content: AnyView(CurrentLocationDot(heading: nil, label: "Senior location")))]
    }
    private func frameMap() {
        guard let detail = store.detail, framedEvent != detail.id else { return }
        let points = (detail.trail + [detail.coordinate].compactMap { $0 }).filter(\.isValid).map(\.appleCoordinate)
        guard !points.isEmpty else { return }
        framedEvent = detail.id
        let latitudes = points.map(\.latitude), longitudes = points.map(\.longitude)
        camera = .region(MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: (latitudes.min()! + latitudes.max()!) / 2,
                                           longitude: (longitudes.min()! + longitudes.max()!) / 2),
            span: MKCoordinateSpan(latitudeDelta: max(0.003, (latitudes.max()! - latitudes.min()!) * 1.6),
                                   longitudeDelta: max(0.003, (longitudes.max()! - longitudes.min()!) * 1.6))))
    }

    private func row(time: Date, text: String, symbol: String?) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text(time.formatted(date: .omitted, time: .shortened)).caregiverText(.secondary).foregroundStyle(.secondary)
                .fixedSize()
            if let symbol { Image(systemName: symbol).foregroundStyle(OrbitStyle.teal).accessibilityHidden(true) }
            Text(text).caregiverText(.secondary).fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(minHeight: 32)
        .accessibilityElement(children: .combine)
    }
    static func symbol(help: RiskEventDetail.Help) -> String {
        switch help.kind {
        case "navigation": return help.status == "started" ? "location.north.circle" : "exclamationmark.circle"
        case "highRiskAlert": return "bell.badge"
        default: return "bell"
        }
    }
}

#if DEBUG
enum RiskEventPreviewData {
    static func detail(status: String = "active", level: String = "warning", canMarkFalseAlarm: Bool = false,
                       now: Date = Date()) -> RiskEventDetail {
        let start = now.addingTimeInterval(-8 * 60)
        return RiskEventDetail(id: "15", level: level, status: status, anomaly: "wandering", anomalyStartedAt: start,
            openedAt: start.addingTimeInterval(7 * 60), escalatedAt: level == "high" ? now : nil,
            resolvedAt: status == "resolved" ? now : nil, resolution: status == "resolved" ? "home" : nil, falseAlarm: false,
            headline: "Wandering for 8 minutes", durationMinutes: 8, canMarkFalseAlarm: canMarkFalseAlarm, explanation: nil,
            coordinate: LocationPreviewData.campus, recordedAt: now, trail: LocationPreviewData.trail,
            help: [.init(kind: "navigation", status: "failed",
                         text: "Navigation home could not start (Route planning failed: map service unavailable on her phone)",
                         at: start.addingTimeInterval(7 * 60)),
                   .init(kind: "lowRiskNotification", status: "notConfigured",
                         text: "Low-risk notification not sent: push is not configured", at: start.addingTimeInterval(7 * 60))],
            timeline: [.init(at: start, kind: "anomalyStarted", text: "Started wandering"),
                       .init(at: start.addingTimeInterval(7 * 60), kind: "lowRisk", text: "Low risk: wandering for 7 minutes")])
    }
}
#Preview("Risk event") {
    var elder = ElderProfile(); elder.name = "Li Lan"; elder.phone = "+12025550100"
    return RiskEventPage(store: RiskEventStore(id: "15", client: nil, detail: RiskEventPreviewData.detail()),
                         profile: elder, navigate: {}, back: {})
}
#endif
