import SwiftUI
import MapKit
import CoreLocation
import UIKit

@MainActor final class SafeZoneSessionStore: ObservableObject {
    @Published private(set) var edits: [String: SafeZone] = [:]
    @Published private(set) var removed: Set<String> = []

    func visibleZones(in snapshot: ElderLocationSnapshot?) -> [SafeZone] {
        let original = snapshot?.safeZones ?? []
        let originalIDs = Set(original.map(\.id))
        return original.compactMap { zone in
            removed.contains(zone.id) ? nil : (edits[zone.id] ?? zone)
        } + edits.values.filter { !originalIDs.contains($0.id) && !removed.contains($0.id) }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    func save(_ zone: SafeZone) {
        removed.remove(zone.id)
        edits[zone.id] = zone
    }

    func delete(_ zone: SafeZone) {
        edits.removeValue(forKey: zone.id)
        removed.insert(zone.id)
    }
}

private struct SafeZoneEditorSelection: Identifiable {
    let zone: SafeZone?
    var id: String { zone?.id ?? "new" }
}

enum CaregiverTab: String, CaseIterable {
    case location = "Location", agent = "Agent", records = "Records"
    var symbol: String {
        switch self {
        case .location: return "person.badge.location.fill"
        case .agent: return "sparkle"
        case .records: return "chart.bar.xaxis"
        }
    }
}

enum CaregiverRiskState: String {
    case normal, warning, high

    var headline: String? {
        switch self {
        case .normal: nil
        case .warning: "Wandering for 7 minutes"
        case .high: "Wandering for 15 minutes"
        }
    }
    var label: String {
        switch self {
        case .normal: "Normal"
        case .warning: "Warning"
        case .high: "High Risk"
        }
    }
    var color: Color {
        switch self {
        case .normal: Color(red: 0.84, green: 0.91, blue: 0.80)
        case .warning: Color(red: 0.89, green: 0.67, blue: 0.43)
        case .high: Color(red: 0.91, green: 0.29, blue: 0.30)
        }
    }
#if DEBUG
    static func preview(arguments: [String]) -> Self {
        guard let index = arguments.firstIndex(of: "-safeorbitRiskState"),
              arguments.indices.contains(index + 1) else { return .normal }
        return Self(rawValue: arguments[index + 1]) ?? .normal
    }
#endif
}

struct CaregiverTabBar: View {
    @Binding var selection: CaregiverTab
    var body: some View {
        HStack(spacing: 0) {
            ForEach(CaregiverTab.allCases, id: \.self) { tab in
                Button { selection = tab } label: {
                    Image(systemName: tab.symbol)
                        .font(.system(size: 28, weight: .semibold))
                        .frame(maxWidth: .infinity).frame(height: 54)
                        .foregroundStyle(.black)
                        .background(selection == tab ? Color(red: 0.82, green: 0.90, blue: 0.90) : .clear, in: Capsule())
                }.accessibilityLabel(tab.rawValue).accessibilityAddTraits(selection == tab ? .isSelected : [])
            }
        }
        .padding(7).frame(maxWidth: 294)
        .background {
            Capsule().fill(.white)
                .shadow(color: .black.opacity(0.133), radius: 9, y: 4)
        }
    }
}

struct CaregiverHomePage: View {
    @ObservedObject var store: OnboardingStore
    @StateObject private var zoneStore = SafeZoneSessionStore()
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var tab: CaregiverTab = .location
    @State private var navigating = false
    @State private var showingSettings: Bool
    @State private var keyboardVisible = false
    init(store: OnboardingStore, settingsInitiallyOpen: Bool = false) {
        self.store = store
        _showingSettings = State(initialValue: settingsInitiallyOpen)
    }
    private var riskState: CaregiverRiskState {
#if DEBUG
        if store.previewSession { return .preview(arguments: ProcessInfo.processInfo.arguments) }
#endif
        return .normal
    }
    private func setSettings(_ open: Bool) {
        withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.28)) { showingSettings = open }
    }
    var body: some View {
        ZStack {
            if tab == .location {
                LocationPage(profile: store.elder, snapshot: store.location,
                             message: store.locationError, loading: store.locationLoading,
                             refresh: { Task { await store.refreshLocation() } },
                             agent: { tab = .agent }, navigate: { navigating = true },
                             settings: { setSettings(true) }, riskState: riskState,
                             zoneStore: zoneStore, usesPreviewTrail: store.previewSession)
            } else if tab == .agent {
                AgentChatPage(keyboardVisible: keyboardVisible)
            } else {
                RecordsPage()
            }
            if !keyboardVisible {
                VStack { Spacer(); CaregiverTabBar(selection: $tab) }
            }
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    if showingSettings {
                        Color.black.opacity(0.36).ignoresSafeArea()
                            .onTapGesture { setSettings(false) }
                            .transition(.opacity)
                        CaregiverSettingsPanel(
                            name: store.previewSession ? "Emma Liu" : "Caregiver",
                            showsPreviewPortrait: store.previewSession,
                            logout: { Task { await store.signOut(); setSettings(false) } }
                        )
                        .frame(width: geometry.size.width * 0.765, height: geometry.size.height)
                        .transition(reduceMotion ? .opacity : .move(edge: .leading))
                    }
                }
            }
            .ignoresSafeArea()
            .allowsHitTesting(showingSettings)
            .zIndex(2)
        }
        .toolbar(.hidden, for: .navigationBar)
        .task { await store.refreshLocation() }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { _ in
            keyboardVisible = true
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in
            keyboardVisible = false
        }
        .fullScreenCover(isPresented: $navigating) {
            WalkingNavigationPage(snapshot: store.location, name: store.elder.name) { navigating = false }
        }
    }
}

struct LocationPage: View {
    let profile: ElderProfile
    let snapshot: ElderLocationSnapshot?
    let message: String?
    let loading: Bool
    let refresh: () -> Void
    let agent: () -> Void
    let navigate: () -> Void
    var settings: () -> Void = {}
    var riskState: CaregiverRiskState = .normal
    @ObservedObject var zoneStore = SafeZoneSessionStore()
    var usesPreviewTrail = false
    @State private var camera: MapCameraPosition = .automatic
    @State private var defaultRegion: MKCoordinateRegion?
    @State private var baselineVisibleRegion: MKCoordinateRegion?
    @State private var awaitingBaseline = true
    @State private var showingReset = false
    @State private var visibleRegion: MKCoordinateRegion?
    @State private var zoneEditor: SafeZoneEditorSelection?

    private var point: CLLocationCoordinate2D? { snapshot?.coordinate.isValid == true ? snapshot?.coordinate.appleCoordinate : nil }
    var body: some View {
        ZStack(alignment: .top) {
            Map(position: $camera) {
                ForEach(zoneStore.visibleZones(in: snapshot).filter { $0.center.isValid && $0.radiusMeters.isFinite && $0.radiusMeters > 0 }, id: \.renderKey) { zone in
                        MapCircle(center: zone.center.appleCoordinate, radius: zone.radiusMeters)
                            .foregroundStyle(OrbitStyle.teal.opacity(0.10))
                            .stroke(OrbitStyle.teal.opacity(0.35), lineWidth: 1)
                        Annotation(zone.name, coordinate: zone.center.appleCoordinate, anchor: .bottom) {
                            Button { zoneEditor = SafeZoneEditorSelection(zone: zone) } label: {
                                VStack(spacing: 2) {
                                    Image(systemName: zone.name.lowercased() == "home" ? "house.fill" : "storefront.fill")
                                        .font(.system(size: 21)).foregroundStyle(.white)
                                        .frame(width: 39, height: 39).background(OrbitStyle.teal, in: Circle())
                                    Circle().fill(OrbitStyle.teal).frame(width: 11, height: 11)
                                }
                            }
                            .accessibilityLabel("Edit \(zone.name) safe zone")
                        }
                }
                if let snapshot {
                    if usesPreviewTrail && snapshot.trail.count > 1 {
                        MapPolyline(coordinates: snapshot.trail.filter(\.isValid).map(\.appleCoordinate))
                            .stroke(OrbitStyle.teal, style: StrokeStyle(lineWidth: 2.3, lineCap: .round, dash: [4, 5]))
                    } else if !usesPreviewTrail {
                        ForEach(Array(snapshot.trail.filter(\.isValid).enumerated()), id: \.offset) { _, sample in
                            MapCircle(center: sample.appleCoordinate, radius: 2.5)
                                .foregroundStyle(OrbitStyle.teal)
                        }
                    }
                    if let point {
                        Annotation("Senior", coordinate: point) {
                            ZStack {
                                Image(systemName: "location.north.fill")
                                    .font(.system(size: 31, weight: .bold))
                                    .rotationEffect(.degrees(snapshot.validHeading ?? 0))
                                    .foregroundStyle(OrbitStyle.teal)
                                if let headline = riskState.headline, snapshot.isCurrent {
                                    Text(headline)
                                        .font(.system(size: 15, weight: .medium))
                                        .foregroundStyle(riskState == .high ? .white : .black)
                                        .padding(.horizontal, 17).padding(.vertical, 9)
                                        .background(riskState.color, in: Capsule())
                                        .shadow(color: .black.opacity(0.22), radius: 5, y: 3)
                                        .fixedSize()
                                        .offset(y: -49)
                                        .accessibilityLabel(headline)
                                }
                            }
                        }
                    }
                }
            }
            .mapStyle(.standard(elevation: .flat, pointsOfInterest: .excludingAll))
            .mapControlVisibility(.hidden)
            .onMapCameraChange(frequency: .onEnd) { context in
                visibleRegion = context.region
                guard defaultRegion != nil else { return }
                if awaitingBaseline || baselineVisibleRegion == nil {
                    baselineVisibleRegion = context.region
                    awaitingBaseline = false
                } else if let baselineVisibleRegion {
                    let from = CLLocation(latitude: baselineVisibleRegion.center.latitude,
                                          longitude: baselineVisibleRegion.center.longitude)
                    let to = CLLocation(latitude: context.region.center.latitude,
                                        longitude: context.region.center.longitude)
                    let moved = from.distance(from: to) > 5
                    let resized = abs(context.region.span.latitudeDelta / baselineVisibleRegion.span.latitudeDelta - 1) > 0.015
                        || abs(context.region.span.longitudeDelta / baselineVisibleRegion.span.longitudeDelta - 1) > 0.015
                    showingReset = moved || resized
                }
            }
            .ignoresSafeArea()
            VStack(alignment: .leading) {
                HStack(alignment: .top) {
                    Button(action: settings) {
                        Circle().fill(.white)
                            .shadow(color: .black.opacity(0.16), radius: 3)
                            .frame(width: 55, height: 55)
                            .overlay(Image(systemName: "person.crop.circle.fill").font(.system(size: 48)).foregroundStyle(OrbitStyle.teal))
                    }
                    .buttonStyle(.plain)
                    .offset(y: 10)
                    .accessibilityLabel("Open settings")
                    Spacer(minLength: 0)
                }
                if showingReset {
                    Button {
                        guard let defaultRegion else { return }
                        awaitingBaseline = true
                        withAnimation(.easeInOut(duration: 0.25)) { camera = .region(defaultRegion) }
                        showingReset = false
                    } label: {
                        Label("Back to default view", systemImage: "arrow.uturn.backward")
                            .font(.system(size: 13, weight: .medium))
                            .padding(.horizontal, 14).padding(.vertical, 9)
                            .background(.white, in: Capsule())
                            .shadow(color: .black.opacity(0.14), radius: 4, y: 2)
                    }
                    .frame(maxWidth: .infinity)
                    .accessibilityLabel("Back to default view")
                }
                Spacer(minLength: 0)
                if riskState == .normal, let snapshot, snapshot.isCurrent, let status = snapshot.status, !status.isEmpty {
                    Text(status).font(.system(size: 15, weight: .medium))
                        .padding(.horizontal, 16).padding(.vertical, 9)
                        .background {
                            Capsule().fill(.white)
                                .shadow(color: .black.opacity(0.16), radius: 5)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.bottom, 15)
                        .offset(y: -70)
                }
                HStack {
                    Spacer()
                    VStack(spacing: 12) {
                        FloatingMapButton(symbol: "sparkle", label: "Agent", action: agent)
                        FloatingMapButton(symbol: "plus", label: "Add safe zone") {
                            zoneEditor = SafeZoneEditorSelection(zone: nil)
                        }
                        FloatingMapButton(symbol: "arrow.clockwise", label: "Refresh location", action: refresh)
                            .disabled(loading)
                    }
                }.padding(.bottom, 23)
                if snapshot == nil || snapshot?.isCurrent == false || message != nil {
                    Text(message ?? (snapshot == nil ? "Location is not available yet." : "Senior location is out of date."))
                        .font(.footnote).foregroundStyle(.primary)
                        .padding(12).frame(maxWidth: .infinity)
                        .background(.white, in: RoundedRectangle(cornerRadius: 14))
                        .padding(.bottom, 8)
                }
                SeniorLocationCard(profile: profile, snapshot: snapshot, navigate: navigate, riskState: riskState)
                    .padding(.bottom, 80)
            }.padding(.horizontal, 20).padding(.top, 4)
        }
        .toolbar(.hidden, for: .navigationBar)
        .onChange(of: snapshot?.recordedAt) { _, _ in focusOnSenior() }
        .onAppear { focusOnSenior() }
        .fullScreenCover(item: $zoneEditor) { selection in
            SafeZoneEditorPage(
                zone: selection.zone,
                initialCenter: selection.zone?.center ?? visibleRegion.map {
                    MainlandCoordinates.toWGS84(GeoPoint(latitude: $0.center.latitude, longitude: $0.center.longitude))
                } ?? snapshot?.coordinate ?? GeoPoint(latitude: 32.05664, longitude: 118.77361),
                nearbyZones: zoneStore.visibleZones(in: snapshot),
                save: { zoneStore.save($0) }, delete: { zoneStore.delete($0) }
            )
        }
    }
    private func focusOnSenior() {
        guard let point else { return }
        let trail = snapshot?.trail.filter(\.isValid).map(\.appleCoordinate) ?? []
        let coordinates = trail + [point]
        let latitudes = coordinates.map(\.latitude)
        let longitudes = coordinates.map(\.longitude)
        guard let minLatitude = latitudes.min(), let maxLatitude = latitudes.max(),
              let minLongitude = longitudes.min(), let maxLongitude = longitudes.max() else { return }
        let eastWest = max(abs(point.longitude - minLongitude), abs(maxLongitude - point.longitude))
        let horizontalMeters = CLLocation(latitude: point.latitude, longitude: point.longitude)
            .distance(from: CLLocation(latitude: point.latitude, longitude: point.longitude + eastWest))
        let northMeters = CLLocation(latitude: point.latitude, longitude: point.longitude)
            .distance(from: CLLocation(latitude: maxLatitude, longitude: point.longitude))
        let southMeters = CLLocation(latitude: point.latitude, longitude: point.longitude)
            .distance(from: CLLocation(latitude: minLatitude, longitude: point.longitude))
        let visibleMeters = max(640, horizontalMeters * 2.2, northMeters / 0.32, southMeters / 0.62)
        let center = CLLocationCoordinate2D(latitude: point.latitude - visibleMeters * 0.15 / 111_320,
                                            longitude: point.longitude)
        let region = MKCoordinateRegion(center: center, latitudinalMeters: visibleMeters,
                                        longitudinalMeters: visibleMeters)
        defaultRegion = region
        if !showingReset {
            awaitingBaseline = true
            camera = .region(region)
        }
    }
}

private enum CaregiverSettingsItem: String, CaseIterable, Identifiable {
    case account = "Account Settings"
    case senior = "Senior Profile"
    case family = "Family Members"
    case agent = "AI Agent Settings"
    case location = "Location Settings"
    case notifications = "Notifications"
    case help = "Help"
    var id: String { rawValue }
    var symbol: String {
        switch self {
        case .account: "gearshape"
        case .senior: "person.crop.circle"
        case .family: "person.3"
        case .agent: "sparkles"
        case .location: "mappin.and.ellipse"
        case .notifications: "bell"
        case .help: "questionmark.circle"
        }
    }
}

private struct CaregiverSettingsPanel: View {
    let name: String
    let showsPreviewPortrait: Bool
    let logout: () -> Void
    @State private var selectedItem: CaregiverSettingsItem?

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 14) {
                Group {
                    if showsPreviewPortrait {
                        Image("PreviewCaregiver").resizable().scaledToFill()
                    } else {
                        Image(systemName: "person.crop.circle.fill")
                            .resizable().scaledToFit().foregroundStyle(OrbitStyle.teal)
                    }
                }
                .frame(width: 57, height: 57).clipShape(Circle())
                VStack(alignment: .leading, spacing: 5) {
                    Text(name).font(.system(size: 18, weight: .semibold)).lineLimit(1)
                    Text("Caregiver")
                        .font(.system(size: 12, weight: .medium)).foregroundStyle(.white)
                        .padding(.horizontal, 11).padding(.vertical, 4)
                        .background(OrbitStyle.teal, in: Capsule())
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 13).frame(height: 84)
            .background(.white, in: Capsule())
            .padding(.horizontal, 27)
            .padding(.top, 57)

            if let selectedItem {
                VStack(alignment: .leading, spacing: 24) {
                    Button { self.selectedItem = nil } label: {
                        Label("Settings", systemImage: "chevron.left")
                            .font(.system(size: 16, weight: .medium))
                    }
                    .accessibilityLabel("Back to settings")
                    Text(selectedItem.rawValue).font(.system(size: 23, weight: .semibold))
                    Text("Coming soon").font(.system(size: 15)).foregroundStyle(.secondary)
                    Spacer()
                }
                .foregroundStyle(.black)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 38).padding(.top, 44)
            } else {
                VStack(spacing: 0) {
                    ForEach(CaregiverSettingsItem.allCases) { item in
                        Button { selectedItem = item } label: {
                            HStack(spacing: 17) {
                                if item == .family {
                                    Image("FamilyMembers")
                                        .resizable().interpolation(.high).scaledToFit()
                                        .frame(width: 30, height: 24)
                                        .frame(width: 30)
                                        .accessibilityHidden(true)
                                } else {
                                    Image(systemName: item.symbol)
                                        .font(.system(size: 24, weight: .regular))
                                        .frame(width: 30)
                                }
                                Text(item.rawValue)
                                    .font(.system(size: 16, weight: .medium))
                                    .lineLimit(1)
                                Spacer(minLength: 0)
                            }
                            .foregroundStyle(.black)
                            .frame(height: 52)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 34).padding(.top, 20)
                Spacer(minLength: 0)
            }

            Button(action: logout) {
                Label("Log Out", systemImage: "rectangle.portrait.and.arrow.right")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(.black)
                    .frame(maxWidth: .infinity).frame(height: 51)
                    .background(Color(red: 0.83, green: 0.91, blue: 0.91), in: Capsule())
            }
            .padding(.horizontal, 28).padding(.bottom, 42)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background {
            UnevenRoundedRectangle(topLeadingRadius: 0, bottomLeadingRadius: 0,
                                   bottomTrailingRadius: 37, topTrailingRadius: 37)
                .fill(Color(red: 0.975, green: 0.982, blue: 0.978))
                .shadow(color: .black.opacity(0.14), radius: 10, x: 4)
        }
        .accessibilityAddTraits(.isModal)
    }
}

struct SafeZoneEditorPage: View {
    let zone: SafeZone?
    let nearbyZones: [SafeZone]
    let save: (SafeZone) -> Void
    let delete: (SafeZone) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var selectedCenter: GeoPoint
    @State private var mapAvailable = false
    @State private var tag: String
    @State private var radius: Int
    @State private var address = ""
    @State private var newTag = ""
    @State private var showingNewTag = false
    @State private var confirmingDelete = false
    private let radii = [100, 200, 500, 1000, 2000]
    private let presets = ["Home", "Market", "Hospital"]

    init(zone: SafeZone?, initialCenter: GeoPoint, nearbyZones: [SafeZone],
         save: @escaping (SafeZone) -> Void, delete: @escaping (SafeZone) -> Void) {
        self.zone = zone; self.nearbyZones = nearbyZones
        self.save = save; self.delete = delete
        let point = zone?.center ?? initialCenter
        _selectedCenter = State(initialValue: point)
        _tag = State(initialValue: zone?.name ?? "Home")
        let savedRadius = zone?.radiusMeters ?? 200
        _radius = State(initialValue: savedRadius.isFinite && (1...20_000).contains(savedRadius)
            ? Int(savedRadius.rounded()) : 200)
    }

    private var coordinateText: String {
        String(format: "%.5f, %.5f", selectedCenter.latitude, selectedCenter.longitude)
    }
    private var tagChoices: [String] { presets.contains(tag) ? presets : presets + [tag] }

    var body: some View {
        ZStack(alignment: .bottom) {
            Color.white.ignoresSafeArea()
            VStack(spacing: 0) {
                CaregiverTopBar {
                    HStack {
                        Button { dismiss() } label: {
                            Label("Back", systemImage: "chevron.left")
                                .font(.system(size: 21, weight: .medium)).foregroundStyle(.white)
                        }
                        .accessibilityLabel("Back")
                        Spacer()
                    }
                    .padding(.horizontal, 26)
                }
                SafeZoneSelectionMap(initialCenter: selectedCenter, radiusMeters: radius,
                                     onSelection: { point in
                                         selectedCenter = point
                                         address = ""
                                         Task { await resolveAddress() }
                                     }, onAvailability: { mapAvailable = $0 })
                    .clipShape(UnevenRoundedRectangle(topLeadingRadius: 34, topTrailingRadius: 34))
                    .ignoresSafeArea(edges: .bottom)
            }
            VStack(spacing: 0) {
                    Spacer(minLength: 0)
                    HStack(spacing: 12) {
                        Text(address.isEmpty ? coordinateText : address)
                            .font(.system(size: 16)).lineLimit(1)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        Image(systemName: "mappin.circle.fill")
                            .font(.system(size: 29)).foregroundStyle(.black)
                            .frame(width: 46, height: 46)
                            .background(Color(red: 0.83, green: 0.91, blue: 0.91), in: Circle())
                    }
                    .padding(.leading, 23).padding(.trailing, 8).frame(height: 60)
                    .background {
                        Capsule().fill(.white)
                            .shadow(color: .black.opacity(0.13), radius: 5, y: 2)
                    }
                    .padding(.bottom, 10)

                    VStack(alignment: .leading, spacing: 17) {
                        Text("Tag").font(.system(size: 17, weight: .semibold))
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 7) {
                                ForEach(tagChoices, id: \.self) { choice in
                                    Button("#\(choice)") { tag = choice }
                                        .font(.system(size: 14))
                                        .foregroundStyle(tag == choice ? .white : .black)
                                        .padding(.horizontal, 12).frame(height: 31)
                                        .background(tag == choice ? OrbitStyle.teal : Color(red: 0.83, green: 0.91, blue: 0.91), in: Capsule())
                                }
                                Button("＋ New Tag") { newTag = ""; showingNewTag = true }
                                    .font(.system(size: 14)).foregroundStyle(.black)
                                    .padding(.horizontal, 11).frame(height: 31)
                                    .overlay(Capsule().stroke(.black, lineWidth: 1))
                            }
                        }
                        Text("Safe Zone Radius").font(.system(size: 17, weight: .semibold))
                            .padding(.top, 2)
                        HStack(alignment: .center, spacing: 4) {
                            HStack(spacing: 0) {
                                ForEach(radii, id: \.self) { value in
                                    Button { radius = value } label: {
                                        VStack(spacing: 5) {
                                            Circle().fill(radius == value ? OrbitStyle.teal : Color(red: 0.82, green: 0.90, blue: 0.90))
                                                .frame(width: radius == value ? 16 : 10, height: radius == value ? 16 : 10)
                                                .frame(height: 16)
                                            Text("\(value.formatted())m")
                                                .font(.system(size: 10)).foregroundStyle(.secondary)
                                        }
                                        .frame(maxWidth: .infinity)
                                    }
                                    .accessibilityLabel("\(value) meters")
                                }
                            }
                            .background(alignment: .top) {
                                GeometryReader { track in
                                    Capsule().fill(Color(red: 0.82, green: 0.90, blue: 0.90))
                                        .frame(width: track.size.width * 0.8, height: 3)
                                        .position(x: track.size.width / 2, y: 8)
                                }
                            }
                            Text("\(radius)m")
                                .font(.system(size: 13, weight: .medium))
                                .frame(width: 57, height: 27)
                                .background(Color(red: 0.82, green: 0.90, blue: 0.90), in: Capsule())
                        }
                        HStack(spacing: 12) {
                            Button("Cancel") { dismiss() }
                                .foregroundStyle(.black)
                                .frame(maxWidth: .infinity).frame(height: 49)
                                .background(Color(red: 0.83, green: 0.91, blue: 0.91), in: Capsule())
                            Button(zone == nil ? "Create Safe Zone" : "Save Changes") {
                                let value = SafeZone(id: zone?.id ?? UUID().uuidString, name: tag,
                                                     center: selectedCenter, radiusMeters: Double(radius))
                                save(value); dismiss()
                            }
                            .disabled(!selectedCenter.isValid || !mapAvailable)
                            .foregroundStyle(.white.opacity(mapAvailable ? 1 : 0.75))
                            .frame(maxWidth: .infinity, maxHeight: 49)
                            .background(mapAvailable ? OrbitStyle.teal : OrbitStyle.teal.opacity(0.45), in: Capsule())
                        }
                        .font(.system(size: 16, weight: .medium))
                        if zone != nil {
                            Button("Delete Safe Zone", role: .destructive) { confirmingDelete = true }
                                .font(.system(size: 12)).frame(maxWidth: .infinity)
                        }
                    }
                    .padding(19)
                    .caregiverCard(radius: 28)
            }
            .padding(.horizontal, 20).padding(.bottom, 26)
        }
        .background(.white)
        .task { await resolveAddress() }
        .alert("New Tag", isPresented: $showingNewTag) {
            TextField("Tag name", text: $newTag)
            Button("Add") {
                let value = newTag.trimmingCharacters(in: .whitespacesAndNewlines)
                    .trimmingCharacters(in: CharacterSet(charactersIn: "#"))
                if !value.isEmpty { tag = String(value.prefix(24)) }
            }
            Button("Cancel", role: .cancel) {}
        } message: { Text("Enter a name for this safe zone.") }
        .confirmationDialog("Delete this safe zone?", isPresented: $confirmingDelete) {
            if let zone {
                Button("Delete Safe Zone", role: .destructive) { delete(zone); dismiss() }
            }
        } message: { Text("This safe zone will be removed.") }
    }

    private func resolveAddress() async {
        let point = selectedCenter
        let geocoder = CLGeocoder()
        let mapPoint = point.appleCoordinate
        guard let placemark = try? await geocoder.reverseGeocodeLocation(
            CLLocation(latitude: mapPoint.latitude, longitude: mapPoint.longitude),
            preferredLocale: Locale(identifier: "en_US")).first,
              selectedCenter == point else { return }
        let road = [placemark.subThoroughfare, placemark.thoroughfare]
            .compactMap { $0 }.joined(separator: " ")
        let components = [placemark.name, road, placemark.subLocality, placemark.locality]
            .compactMap { $0 }.filter { !$0.isEmpty }
            .map { $0.applyingTransform(.toLatin, reverse: false) ?? $0 }
        var unique: [String] = []
        for component in components where !unique.contains(component) { unique.append(component) }
        address = unique.isEmpty ? coordinateText : (unique.joined(separator: ", ") + " · " + coordinateText)
    }
}

private struct FloatingMapButton: View {
    let symbol: String
    let label: String
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            Image(systemName: symbol).font(.system(size: 23, weight: .semibold))
                .foregroundStyle(.black).frame(width: 48, height: 48)
                .background {
                    Circle().fill(.white)
                        .shadow(color: .black.opacity(0.126), radius: 5, y: 2)
                }
        }.accessibilityLabel(label)
    }
}

private struct SeniorLocationCard: View {
    let profile: ElderProfile
    let snapshot: ElderLocationSnapshot?
    let navigate: () -> Void
    var riskState: CaregiverRiskState = .normal
    @Environment(\.openURL) private var openURL
    private var canNavigate: Bool { snapshot?.isCurrent == true }
    private var canCall: Bool { PhoneNumber.isValid(profile.phone) }
    var body: some View {
        VStack(alignment: .leading, spacing: 11) {
            HStack(spacing: 14) {
                ProfileAvatar(photo: profile.photo, size: 60)
                VStack(alignment: .leading, spacing: 6) {
                    Text(profile.name).font(.system(size: 18, weight: .semibold)).lineLimit(1)
                    HStack(spacing: 8) {
                        if snapshot?.isCurrent == true {
                            Label(riskState.label, systemImage: riskState == .normal ? "checkmark.shield" : "exclamationmark.circle")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(riskState == .high ? .white : .black)
                                .padding(.horizontal, 9).padding(.vertical, 4)
                                .background(riskState.color, in: Capsule())
                        } else { Text("Location unavailable").font(.caption).foregroundStyle(.secondary) }
                        if let battery = snapshot?.batteryPercent, (0...100).contains(battery) {
                            Label("\(battery)%", systemImage: "battery.100percent")
                                .font(.system(size: 12)).foregroundStyle(.secondary)
                        }
                    }
                }.frame(maxWidth: .infinity, alignment: .leading)
                Button {
                    guard canCall, let url = URL(string: "tel:\(PhoneNumber.normalized(profile.phone))") else { return }
                    openURL(url)
                } label: {
                    Image(systemName: "phone.fill")
                        .font(.system(size: 22))
                        .foregroundStyle(riskState == .high ? .white : .black)
                        .frame(width: 54, height: 54)
                        .background(riskState == .normal ? Color(red: 0.82, green: 0.90, blue: 0.90) : riskState.color, in: Circle())
                        .padding(riskState == .high ? 5 : 0)
                        .background(riskState == .high ? riskState.color.opacity(0.35) : .clear, in: Circle())
                }.disabled(!canCall).accessibilityLabel("Call senior")
            }
            Rectangle().fill(.black.opacity(0.1)).frame(height: 1)
            HStack(spacing: 10) {
                Image(systemName: "mappin.and.ellipse").font(.system(size: 20)).foregroundStyle(.secondary)
                Text(snapshot?.address.flatMap { $0.isEmpty ? nil : $0 } ?? "Address unavailable")
                    .font(.system(size: 12)).foregroundStyle(.secondary).lineLimit(2)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Button(action: navigate) {
                    Label("Navigate", systemImage: "arrow.up.right")
                        .labelStyle(.titleAndIcon).font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.white).padding(.horizontal, 14).frame(height: 42)
                        .background(OrbitStyle.teal, in: Capsule())
                }.disabled(!canNavigate)
            }
        }
        .padding(11)
        .background {
            RoundedRectangle(cornerRadius: 23).fill(.white)
                .shadow(color: .black.opacity(0.168), radius: 8, y: 4)
        }
    }
}

struct WalkingNavigationPage: View {
    let snapshot: ElderLocationSnapshot?
    let name: String
    let end: () -> Void
    @StateObject private var model: WalkingNavigationModel
    @State private var camera: MapCameraPosition = .automatic
    init(snapshot: ElderLocationSnapshot?, name: String, end: @escaping () -> Void) {
        self.snapshot = snapshot; self.name = name; self.end = end
        _model = StateObject(wrappedValue: WalkingNavigationModel())
    }
    init(snapshot: ElderLocationSnapshot?, name: String, model: WalkingNavigationModel, end: @escaping () -> Void) {
        self.snapshot = snapshot; self.name = name; self.end = end
        _model = StateObject(wrappedValue: model)
    }
    var body: some View {
        ZStack(alignment: .bottom) {
            Map(position: $camera) {
                if let route = model.route {
                    MapPolyline(coordinates: route.coordinates).stroke(OrbitStyle.teal, lineWidth: 6)
                }
                if let snapshot, snapshot.coordinate.isValid {
                    Marker(name, coordinate: snapshot.coordinate.appleCoordinate)
                }
            }.mapStyle(.standard(elevation: .flat)).ignoresSafeArea()
            VStack {
                HStack {
                    Button(action: end) { Image(systemName: "xmark")
                        .font(.system(size: 16, weight: .semibold)).frame(width: 44, height: 44)
                        .background(.white, in: Capsule()) }
                        .accessibilityLabel("Close navigation")
                    Spacer()
                }.padding(.horizontal, 20).padding(.top, 12)
                Spacer()
                VStack(alignment: .leading, spacing: 12) {
                    Text("Walking to \(name)").font(.title3.bold())
                    if model.loading { ProgressView("Finding a walking route…") }
                    else if let issue = model.issue {
                        Text(issue.localizedDescription).font(.subheadline)
                        Button("Try again") { Task { await model.plan(to: snapshot) } }
                    } else if let route = model.route {
                        Text("\(Self.distance(route.distanceMeters)) · \(Int(ceil(route.expectedSeconds / 60))) min")
                            .font(.headline).foregroundStyle(OrbitStyle.teal)
                        if route.steps.isEmpty { Text("Follow the highlighted route.") }
                        else {
                            ScrollView { VStack(alignment: .leading, spacing: 12) {
                                ForEach(Array(route.steps.enumerated()), id: \.offset) { index, step in
                                    HStack(alignment: .top) {
                                        Text("\(index + 1).").foregroundStyle(OrbitStyle.teal)
                                        Text(step)
                                    }.font(.subheadline)
                                }
                            }}.frame(maxHeight: 170)
                        }
                    }
                    Button("End navigation", action: end)
                        .frame(maxWidth: .infinity).frame(height: 50)
                        .foregroundStyle(.white).background(OrbitStyle.teal, in: Capsule())
                }.padding(20).frame(maxWidth: .infinity, alignment: .leading)
                    .background(.white, in: UnevenRoundedRectangle(topLeadingRadius: 25, topTrailingRadius: 25))
            }
        }.tint(OrbitStyle.teal)
        .task {
            await model.plan(to: snapshot)
            if let coordinates = model.route?.coordinates, !coordinates.isEmpty {
                let latitudes = coordinates.map(\.latitude), longitudes = coordinates.map(\.longitude)
                camera = .region(MKCoordinateRegion(center: CLLocationCoordinate2D(latitude: (latitudes.min()! + latitudes.max()!)/2,
                    longitude: (longitudes.min()! + longitudes.max()!)/2),
                    span: MKCoordinateSpan(latitudeDelta: max(0.004, (latitudes.max()! - latitudes.min()!)*1.4),
                                           longitudeDelta: max(0.004, (longitudes.max()! - longitudes.min()!)*1.4))))
            }
        }
    }
    private static func distance(_ meters: Double) -> String {
        meters >= 1000 ? String(format: "%.1f km", meters / 1000) : "\(Int(meters.rounded())) m"
    }
}

#if DEBUG
private func locationPreview() -> ElderLocationSnapshot {
    LocationPreviewData.snapshot()
}
#Preview("Location") {
    var elder = ElderProfile(); elder.name = "Cuilan Liu"; elder.phone = "+8613800000000"
    return LocationPage(profile: elder, snapshot: locationPreview(), message: nil, loading: false,
                        refresh: {}, agent: {}, navigate: {})
}
#Preview("Location unavailable") {
    var elder = ElderProfile(); elder.name = "Cuilan Liu"
    return LocationPage(profile: elder, snapshot: nil, message: nil, loading: false,
                        refresh: {}, agent: {}, navigate: {})
}
#endif
