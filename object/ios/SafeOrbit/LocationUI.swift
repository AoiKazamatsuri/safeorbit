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
    var onSelection: ((CaregiverTab) -> Void)? = nil
    var body: some View {
        CaregiverBottomOverlay {
        HStack(spacing: 0) {
            ForEach(CaregiverTab.allCases, id: \.self) { tab in
                Button { onSelection?(tab); selection = tab } label: {
                    Image(systemName: tab.symbol)
                        .font(.system(size: 28, weight: .semibold))
                        .frame(maxWidth: .infinity).frame(height: CaregiverBottomLayout.buttonHeight)
                        .foregroundStyle(.black)
                        .background(selection == tab ? Color(red: 0.82, green: 0.90, blue: 0.90) : .clear, in: Capsule())
                }.accessibilityLabel(tab.rawValue).accessibilityAddTraits(selection == tab ? .isSelected : [])
            }
        }
        .padding(CaregiverBottomLayout.barPadding).frame(maxWidth: 294)
        .background {
            Capsule().fill(.white)
                .shadow(color: .black.opacity(0.133), radius: 9, y: 4)
        }
        }
    }
}

struct CaregiverHomePage: View {
    @ObservedObject var store: OnboardingStore
    let chooseRole: (() -> Void)?
    @StateObject private var zoneStore = SafeZoneSessionStore()
    @StateObject private var settingsStore = CaregiverSettingsStore()
    @StateObject private var agentSessions = AgentSessionStore()
    @State private var selectedSettings: CaregiverSettingsGroup?
    @State private var tab: CaregiverTab = .location
    @StateObject private var navigation: WalkingNavigationModel
    @State private var showingSettings: Bool
    @State private var keyboardVisible = false
    @State private var recordsDetailPresented = false
    @State private var zoneEditorPresented = false
    init(store: OnboardingStore, settingsInitiallyOpen: Bool = false, chooseRole: (() -> Void)? = nil) {
        self.store = store
        self.chooseRole = chooseRole
        _showingSettings = State(initialValue: settingsInitiallyOpen)
        #if targetEnvironment(simulator)
        _navigation = StateObject(wrappedValue: store.previewSession
            ? WalkingNavigationModel(provider: PreviewWalkingRouteProvider(), isDemoRoute: true)
            : WalkingNavigationModel())
        #else
        _navigation = StateObject(wrappedValue: WalkingNavigationModel())
        #endif
    }
    private var riskState: CaregiverRiskState {
#if DEBUG
        if store.previewSession { return .preview(arguments: ProcessInfo.processInfo.arguments) }
#endif
        return .normal
    }
    private func setSettings(_ open: Bool) {
        showingSettings = open
    }
    var body: some View {
        ZStack {
            ZStack {
                LocationPage(profile: store.elder, snapshot: store.location,
                             message: store.locationError, loading: store.locationLoading,
                             refresh: { Task { await store.refreshLocation() } },
                             agent: { agentSessions.showList(); tab = .agent }, navigate: { Task {
                                 if navigation.isDemoRoute { await store.refreshLocation() }
                                 await navigation.start(to: store.location)
                             } },
                             settings: { setSettings(true) }, riskState: riskState,
                             zoneStore: zoneStore, usesPreviewTrail: store.previewSession,
                             navigation: navigation, refreshDestination: { await store.refreshLocation(); return store.location },
                             onEditorPresentationChanged: { zoneEditorPresented = $0 })
                    .opacity(tab == .location ? 1 : 0)
                    .allowsHitTesting(tab == .location)
                    .accessibilityElement(children: tab == .location ? .contain : .ignore)
                    .accessibilityHidden(tab != .location)
                AgentSessionPage(sessions: agentSessions, settings: settingsStore, keyboardVisible: keyboardVisible, isActive: tab == .agent && !showingSettings && selectedSettings == nil)
                    .opacity(tab == .agent ? 1 : 0)
                    .allowsHitTesting(tab == .agent)
                    .accessibilityElement(children: tab == .agent ? .contain : .ignore)
                    .accessibilityHidden(tab != .agent)
                RecordsPage(onDetailPresentationChanged: { recordsDetailPresented = $0 })
                    .opacity(tab == .records ? 1 : 0)
                    .allowsHitTesting(tab == .records)
                    .accessibilityElement(children: tab == .records ? .contain : .ignore)
                    .accessibilityHidden(tab != .records)
                if !keyboardVisible && !navigation.isPresented && !recordsDetailPresented && !zoneEditorPresented
                    && (tab != .agent || agentSessions.activeID == nil) {
                    CaregiverTabBar(selection: $tab, onSelection: { if $0 == .agent { agentSessions.showList() } })
                }
            }
            .allowsHitTesting(!showingSettings)
            .accessibilityElement(children: showingSettings ? .ignore : .contain)
            .accessibilityHidden(showingSettings)
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    if showingSettings {
                        Color.black.opacity(0.36).ignoresSafeArea()
                            .onTapGesture { setSettings(false) }

                        CaregiverSettingsPanel(
                            name: settingsStore.data.caregiver.name,
                            photo: settingsStore.data.caregiver.photo,
                            primary: settingsStore.data.primaryID == "self",
                            showsPreviewPortrait: store.previewSession,
                            showsLogout: !store.homeAccessEnabled,
                            chooseRole: chooseRole,
                            select: { selectedSettings = $0 },
                            logout: { Task { await store.signOut(); setSettings(false) } }
                        )
                        .frame(width: geometry.size.width * 0.765, height: geometry.size.height)

                    }
                }
            }
            .ignoresSafeArea()
            .allowsHitTesting(showingSettings)
            .zIndex(2)
        }
        .caregiverText()
        .toolbar(.hidden, for: .navigationBar)
        .task {
            if store.previewSession { store.elder = settingsStore.data.senior }
            await store.refreshLocation()
        }
        .onChange(of: settingsStore.data.senior) { _, profile in
            if store.previewSession { store.elder = profile }
        }
        .settingsSlide(item: $selectedSettings) { item in
            CaregiverSettingsGroupPage(group: item, settings: settingsStore, onboarding: store, zones: zoneStore) { selectedSettings = nil }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { _ in
            keyboardVisible = true
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in
            keyboardVisible = false
        }
        .onDisappear { navigation.end() }
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
    @ObservedObject var navigation = WalkingNavigationModel()
    var refreshDestination: (() async -> ElderLocationSnapshot?)? = nil
    var onEditorPresentationChanged: (Bool) -> Void = { _ in }
    @Environment(\.scenePhase) private var scenePhase
    @State private var previousCamera: MapCameraPosition?
    @State private var followsUser = false
    @State private var showsOverview = true
    @State private var visibleHeading = 0.0
    private var navigationRunning: Bool { navigation.isPresented && !navigation.suspended && !navigation.arrived && scenePhase == .active }
    @State private var camera: MapCameraPosition = .automatic
    @State private var defaultRegion: MKCoordinateRegion?
    @State private var baselineVisibleRegion: MKCoordinateRegion?
    @State private var awaitingBaseline = true
    @State private var showingReset = false
    @State private var visibleRegion: MKCoordinateRegion?
    @State private var zoneEditor: SafeZoneEditorSelection?

    private var point: CLLocationCoordinate2D? { snapshot?.coordinate.isValid == true ? snapshot?.coordinate.appleCoordinate : nil }
    var body: some View {
        GeometryReader { geometry in
        ZStack(alignment: .top) {
            AMapConsentSurface {
                AMapCanvas(camera: $camera, markers: mapMarkers, circles: mapCircles,
                           lines: mapLines, onCameraChange: { context in
                visibleRegion = context.region
                visibleHeading = context.heading
                if navigation.isPresented {
                    if context.wasUserAction { followsUser = false; showsOverview = false }
                    return
                }
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
            })
            }
            .ignoresSafeArea()
            if !navigation.isPresented {
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
                            .caregiverText(.caption)
                            .padding(.horizontal, 14).padding(.vertical, 9)
                            .background(.white, in: Capsule())
                            .shadow(color: .black.opacity(0.14), radius: 4, y: 2)
                    }
                    .frame(maxWidth: .infinity)
                    .accessibilityLabel("Back to default view")
                }
                Spacer(minLength: 0)
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
                        .caregiverText(.caption).foregroundStyle(.primary)
                        .padding(12).frame(maxWidth: .infinity)
                        .background(.white, in: RoundedRectangle(cornerRadius: 16))
                        .padding(.bottom, 8)
                }
                SeniorLocationCard(profile: profile, snapshot: snapshot, navigate: navigate, riskState: riskState)
                    .padding(.bottom, CaregiverBottomLayout.cardBottomPadding(safeAreaBottom: geometry.safeAreaInsets.bottom))
            }.padding(.horizontal, 20).padding(.top, 4)
            } else {
                WalkingNavigationOverlay(model: navigation,
                    refreshMessage: message,
                    retry: { Task {
                        let latest = await refreshDestination?() ?? snapshot
                        guard navigation.isPresented, !Task.isCancelled else { return }
                        await navigation.plan(to: latest)
                    } },
                    follow: { followsUser = true; showsOverview = false; followCurrentPosition() },
                    overview: { followsUser = false; showsOverview = true; showRouteOverview() }, end: { navigation.end() })
            }
        }
        }
        .toolbar(.hidden, for: .navigationBar)
        .onChange(of: snapshot?.recordedAt) { _, _ in
            if navigation.isPresented { navigation.updateDestination(snapshot) }
            else { focusOnSenior() }
        }
        .onChange(of: navigation.isPresented) { _, presented in
            if presented { previousCamera = camera; followsUser = false; showsOverview = true; showRouteOverview() }
            else if let previousCamera { camera = previousCamera; self.previousCamera = nil }
        }
        .onChange(of: navigation.fix?.timestamp) { _, _ in
            if navigationRunning {
                if followsUser { followCurrentPosition() }
                else if showsOverview { showRouteOverview() }
            }
        }
        .onChange(of: navigation.routeVersion) { _, _ in
            if navigation.isPresented && showsOverview { showRouteOverview() }
        }
        .onChange(of: navigation.destination?.coordinate) { _, _ in
            if navigation.isPresented && showsOverview { showRouteOverview() }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase != .active { navigation.pause() }
        }
        .task(id: scenePhase) {
            if scenePhase == .active && navigation.suspended {
                let latest = await refreshDestination?() ?? snapshot
                guard !Task.isCancelled, scenePhase == .active else { return }
                await navigation.resume(to: latest)
            }
        }
        .task(id: navigationRunning) {
            guard navigationRunning else { return }
            while !Task.isCancelled {
                let latest = await refreshDestination?() ?? snapshot
                guard !Task.isCancelled, navigationRunning else { return }
                navigation.updateDestination(latest)
                do { try await Task.sleep(for: .seconds(30)) } catch { return }
            }
        }
        .task(id: navigationRunning) {
            guard navigationRunning else { return }
            while !Task.isCancelled {
                navigation.tick()
                do { try await Task.sleep(for: .seconds(1)) } catch { return }
            }
        }
        .onAppear {
            if navigation.isPresented { showRouteOverview() } else { focusOnSenior() }
        }
        .onDisappear { navigation.end() }
        .onChange(of: zoneEditor?.id) { _, id in onEditorPresentationChanged(id != nil) }
        .settingsSlide(item: $zoneEditor) { selection in
            SafeZoneEditorPage(
                zone: selection.zone,
                initialCenter: selection.zone?.center ?? visibleRegion.map {
                    MainlandCoordinates.toWGS84(GeoPoint(latitude: $0.center.latitude, longitude: $0.center.longitude))
                } ?? snapshot?.coordinate ?? GeoPoint(latitude: 32.05664, longitude: 118.77361),
                nearbyZones: zoneStore.visibleZones(in: snapshot),
                save: { zoneStore.save($0) }, delete: { zoneStore.delete($0) }, close: { zoneEditor = nil }
            )
        }
    }
    private var mapCircles: [AMapCircle] {
        guard !navigation.isPresented else { return [] }
        var result = zoneStore.visibleZones(in: snapshot).filter {
            $0.center.isValid && $0.radiusMeters.isFinite && $0.radiusMeters > 0
        }.map { zone in
            AMapCircle(id: "zone-" + zone.renderKey, center: zone.center.appleCoordinate,
                       radius: zone.radiusMeters, fill: OrbitStyle.teal.opacity(0.10),
                       stroke: OrbitStyle.teal.opacity(0.35))
        }
        if !usesPreviewTrail {
            result += (snapshot?.trail.filter(\.isValid) ?? []).enumerated().map { index, sample in
                AMapCircle(id: "trail-\(index)", center: sample.appleCoordinate, radius: 2.5,
                           fill: OrbitMapStyle.blue)
            }
        }
        return result
    }
    private var mapLines: [AMapLine] {
        if navigation.isPresented {
            return navigation.route.map { [
                AMapLine(id: "navigation-border", coordinates: $0.coordinates,
                         color: Color(red: 0.0, green: 0.32, blue: 0.72), width: 12),
                AMapLine(id: "navigation", coordinates: $0.coordinates,
                         color: Color(red: 0.0, green: 0.65, blue: 1.0), width: 8)
            ] } ?? []
        }
        guard usesPreviewTrail, let snapshot, snapshot.trail.count > 1 else { return [] }
        return [AMapLine(id: "preview-trail", coordinates: snapshot.trail.filter(\.isValid).map(\.appleCoordinate),
                         color: OrbitMapStyle.blue, width: 2.3, dash: [4, 5])]
    }
    private var mapMarkers: [AMapMarker] {
        if navigation.isPresented {
            var result: [AMapMarker] = []
            if let route = navigation.route {
                for index in stride(from: 1, to: route.coordinates.count, by: 2) {
                    let a = route.coordinates[index - 1], b = route.coordinates[index]
                    let bearing = atan2((b.longitude - a.longitude) * cos(a.latitude * .pi / 180),
                                        b.latitude - a.latitude) * 180 / .pi
                    let center = CLLocationCoordinate2D(latitude: (a.latitude + b.latitude) / 2,
                                                        longitude: (a.longitude + b.longitude) / 2)
                    result.append(AMapMarker(id: "route-direction-\(index)", coordinate: center,
                        content: AnyView(Image(systemName: "chevron.up")
                            .font(.system(size: 12, weight: .bold)).foregroundStyle(.white)
                            .rotationEffect(.degrees(bearing - visibleHeading)).accessibilityHidden(true))))
                }
            }
            if let destination = navigation.destination, destination.coordinate.isValid {
                result.append(AMapMarker(id: "destination", coordinate: destination.coordinate.appleCoordinate,
                    anchor: .bottom, content: AnyView(VStack(spacing: 4) {
                        Text(profile.name)
                            .caregiverText(.caption).padding(6).background(.white, in: Capsule())
                        Image(systemName: "mappin.circle.fill").font(.system(size: 36)).foregroundStyle(OrbitMapStyle.blue)
                    })))
            }
            if let fix = navigation.fix {
                result.append(AMapMarker(id: "self", coordinate: fix.point.appleCoordinate,
                    content: AnyView(CurrentLocationDot(heading: navigation.markerHeading.map { $0 - visibleHeading },
                                                       label: "Your location"))))
            }
            return result
        }
        var result = zoneStore.visibleZones(in: snapshot).filter {
            $0.center.isValid && $0.radiusMeters.isFinite && $0.radiusMeters > 0
        }.map { zone in
            AMapMarker(id: "zone-" + zone.renderKey, coordinate: zone.center.appleCoordinate,
                anchor: .bottom, content: AnyView(Button { zoneEditor = SafeZoneEditorSelection(zone: zone) } label: {
                    VStack(spacing: 2) {
                        Image(systemName: zone.name.lowercased() == "home" ? "house.fill" : "storefront.fill")
                            .font(.system(size: 21)).foregroundStyle(.white)
                            .frame(width: 39, height: 39).background(OrbitStyle.teal, in: Circle())
                        Circle().fill(OrbitStyle.teal).frame(width: 11, height: 11)
                    }
                }.accessibilityLabel("Edit \(zone.name) safe zone")))
        }
        if let snapshot, let point {
            let headline = riskState == .normal ? snapshot.status : riskState.headline
            result.append(AMapMarker(id: "senior", coordinate: point, content: AnyView(ZStack {
                CurrentLocationDot(heading: snapshot.validHeading.map { $0 - visibleHeading }, label: "Senior location")
                if let headline, !headline.isEmpty, snapshot.isCurrent {
                    Text(headline).caregiverText()
                        .foregroundStyle(riskState == .high ? .white : .black)
                        .padding(.horizontal, 17).padding(.vertical, 9)
                        .background(riskState == .normal ? .white : riskState.color, in: Capsule())
                        .shadow(color: .black.opacity(0.22), radius: 5, y: 3)
                        .fixedSize().offset(y: -65).accessibilityLabel(headline)
                }
            })))
        }
        return result
    }
    private func followCurrentPosition() {
        guard let fix = navigation.fix, fix.point.isValid else { return }
        camera = .camera(MapCamera(centerCoordinate: fix.point.appleCoordinate, distance: 550,
                                   heading: fix.course >= 0 && fix.course.isFinite ? fix.course : 0, pitch: 0))
    }
    private func showRouteOverview() {
        var coordinates = navigation.route?.coordinates ?? []
        if let point = navigation.fix?.point, point.isValid { coordinates.append(point.appleCoordinate) }
        if let point = navigation.destination?.coordinate, point.isValid { coordinates.append(point.appleCoordinate) }
        guard !coordinates.isEmpty else { return }
        let latitudes = coordinates.map(\.latitude), longitudes = coordinates.map(\.longitude)
        camera = .region(MKCoordinateRegion(center: CLLocationCoordinate2D(
            latitude: (latitudes.min()! + latitudes.max()!) / 2,
            longitude: (longitudes.min()! + longitudes.max()!) / 2),
            span: MKCoordinateSpan(latitudeDelta: max(0.004, (latitudes.max()! - latitudes.min()!) * 1.8),
                                   longitudeDelta: max(0.004, (longitudes.max()! - longitudes.min()!) * 1.8))))
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

private struct CaregiverSettingsPanel: View {
    let name: String
    let photo: String?
    let primary: Bool
    let showsPreviewPortrait: Bool
    let showsLogout: Bool
    let chooseRole: (() -> Void)?
    let select: (CaregiverSettingsGroup) -> Void
    let logout: () -> Void

    var body: some View {
        GeometryReader { geometry in
        ScrollView {
        VStack(spacing: 0) {
            HStack(spacing: 14) {
                Group {
                    if let photo {
                        ProfileAvatar(photo: photo, size: 57)
                    } else if showsPreviewPortrait {
                        Image("PreviewCaregiver").resizable().scaledToFill()
                    } else {
                        Image(systemName: "person.crop.circle.fill")
                            .resizable().scaledToFit().foregroundStyle(OrbitStyle.teal)
                    }
                }
                .frame(width: 57, height: 57).clipShape(Circle())
                VStack(alignment: .leading, spacing: 5) {
                    Text(name).caregiverText().fixedSize(horizontal: false, vertical: true)
                    Text(primary ? "Primary caregiver" : "Caregiver")
                        .caregiverText(.caption).foregroundStyle(.white)
                        .padding(.horizontal, 11).padding(.vertical, 4)
                        .background(OrbitStyle.teal, in: Capsule())
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 13).padding(.vertical, 12).frame(minHeight: 84)
            .background(.white, in: Capsule())
            .padding(.horizontal, 27)
            .padding(.top, 57)

                VStack(spacing: 0) {
                    ForEach(CaregiverSettingsGroup.allCases) { item in
                        Button { select(item) } label: {
                            HStack(spacing: 17) {
                                if item == .people {
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
                                    .caregiverText()
                                    .lineLimit(2)
                                Spacer(minLength: 0)
                            }
                            .foregroundStyle(.black)
                            .padding(.vertical, 10).frame(minHeight: 52)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 34).padding(.top, 20)
                Spacer(minLength: 0)

            if let chooseRole {
                Button(action: chooseRole) {
                    Label("Choose role", systemImage: "person.2")
                        .caregiverText().foregroundStyle(.black)
                        .frame(maxWidth: .infinity).frame(minHeight: 51)
                        .background(Color(red: 0.83, green: 0.91, blue: 0.91), in: Capsule())
                }
                .accessibilityIdentifier("caregiver-choose-role")
                .padding(.horizontal, 28).padding(.bottom, 42)
            }
            if showsLogout {
                Button(action: logout) {
                    Label("Log Out", systemImage: "rectangle.portrait.and.arrow.right")
                        .caregiverText()
                        .foregroundStyle(.black)
                        .frame(maxWidth: .infinity).frame(height: 51)
                        .background(Color(red: 0.83, green: 0.91, blue: 0.91), in: Capsule())
                }
                .padding(.horizontal, 28).padding(.bottom, 42)
            }
        }
        .frame(maxWidth: .infinity, minHeight: geometry.size.height)
        }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background {
            UnevenRoundedRectangle(topLeadingRadius: 0, bottomLeadingRadius: 0,
                                   bottomTrailingRadius: 36, topTrailingRadius: 36)
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
    let close: (() -> Void)?
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
         save: @escaping (SafeZone) -> Void, delete: @escaping (SafeZone) -> Void,
         close: (() -> Void)? = nil) {
        self.zone = zone; self.nearbyZones = nearbyZones
        self.save = save; self.delete = delete
        self.close = close
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

    private func closePage() {
        if let close { close() } else { dismiss() }
    }

    @State private var editorOverlayHeight: CGFloat = 0

    var body: some View {
        GeometryReader { geometry in
        ZStack(alignment: .bottom) {
            Color.white.ignoresSafeArea()
            VStack(spacing: 0) {
                CaregiverTopBar {
                    HStack {
                        Button { closePage() } label: {
                            Label("Back", systemImage: "chevron.left")
                                .orbitDisplayFont(20).foregroundStyle(.white)
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
                                     }, onAvailability: { mapAvailable = $0 },
                                     bottomOverlayInset: editorOverlayHeight + 12 + max(0,
                                         CaregiverBottomLayout.gap(safeAreaBottom: geometry.safeAreaInsets.bottom) - geometry.safeAreaInsets.bottom))
                    .ignoresSafeArea(edges: .bottom)
                    .clipShape(UnevenRoundedRectangle(topLeadingRadius: 28, topTrailingRadius: 28))
                    .background(alignment: .top) { OrbitStyle.teal.frame(height: 40) }
            }
            .ignoresSafeArea(edges: .bottom)
            CaregiverBottomOverlay {
                    VStack(spacing: 0) {
                    HStack(spacing: 12) {
                        Text(address.isEmpty ? coordinateText : address)
                            .caregiverText().lineLimit(1)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        Image(systemName: "mappin.circle.fill")
                            .font(.system(size: 29)).foregroundStyle(OrbitStyle.teal)
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
                        Text("Tag").caregiverText()
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
                                    .caregiverText(.secondary).foregroundStyle(.black)
                                    .padding(.horizontal, 11).frame(height: 31)
                                    .overlay(Capsule().stroke(.black, lineWidth: 1))
                            }
                        }
                        Text("Safe Zone Radius").caregiverText()
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
                                                .caregiverText(.caption).foregroundStyle(.secondary)
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
                                .caregiverText(.caption)
                                .frame(width: 57, height: 27)
                                .background(Color(red: 0.82, green: 0.90, blue: 0.90), in: Capsule())
                        }
                        HStack(spacing: 12) {
                            Button("Cancel") { closePage() }
                                .foregroundStyle(.black)
                                .frame(maxWidth: .infinity).frame(height: 49)
                                .background(Color(red: 0.83, green: 0.91, blue: 0.91), in: Capsule())
                            Button(zone == nil ? "Create Safe Zone" : "Save Changes") {
                                let value = SafeZone(id: zone?.id ?? UUID().uuidString, name: tag,
                                                     center: selectedCenter, radiusMeters: Double(radius))
                                save(value); closePage()
                            }
                            .disabled(!selectedCenter.isValid || !mapAvailable)
                            .foregroundStyle(.white.opacity(mapAvailable ? 1 : 0.75))
                            .frame(maxWidth: .infinity, maxHeight: 49)
                            .background(mapAvailable ? OrbitStyle.teal : OrbitStyle.teal.opacity(0.45), in: Capsule())
                        }
                        .caregiverText()
                        if zone != nil {
                            Button("Delete Safe Zone", role: .destructive) { confirmingDelete = true }
                                .caregiverText(.secondary).frame(maxWidth: .infinity)
                        }
                    }
                    .padding(19)
                    .caregiverCard(radius: 20)
                    }
                    .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { editorOverlayHeight = $0 }
            }
            .padding(.horizontal, 20)
        }
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
                Button("Delete Safe Zone", role: .destructive) { delete(zone); closePage() }
            }
        } message: { Text("This safe zone will be removed.") }
    }

    private func resolveAddress() async {
        let point = selectedCenter
        guard let resolved = await AMapGeocoder.address(at: point), selectedCenter == point else { return }
        address = resolved.isEmpty ? coordinateText : resolved + " · " + coordinateText
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
    private var canCall: Bool { PhoneNumber.isValid(profile.phone) }
    var body: some View {
        VStack(alignment: .leading, spacing: 11) {
            HStack(spacing: 14) {
                ProfileAvatar(photo: profile.photo, size: 60)
                VStack(alignment: .leading, spacing: 6) {
                    Text(profile.name).caregiverText().lineLimit(1)
                    HStack(spacing: 8) {
                        if snapshot?.isCurrent == true {
                            Label(riskState.label, systemImage: riskState == .normal ? "checkmark.shield" : "exclamationmark.circle")
                                .caregiverText(.secondary)
                                .foregroundStyle(riskState == .high ? .white : .black)
                                .padding(.horizontal, 9).padding(.vertical, 4)
                                .background(riskState.color, in: Capsule())
                        } else { Text("Location unavailable").caregiverText(.caption).foregroundStyle(.secondary) }
                        if let battery = snapshot?.batteryPercent, (0...100).contains(battery) {
                            Label("\(battery)%", systemImage: "battery.100percent")
                                .caregiverText(.caption).foregroundStyle(.secondary)
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
                    .caregiverText(.caption).foregroundStyle(.secondary).lineLimit(2)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Button(action: navigate) {
                    Label("Navigate", systemImage: "arrow.up.right")
                        .labelStyle(.titleAndIcon).caregiverText(.secondary)
                        .foregroundStyle(.white).padding(.horizontal, 14).frame(height: 42)
                        .background(OrbitStyle.teal, in: Capsule())
                }.accessibilityIdentifier("navigate-to-senior")
            }
        }
        .padding(11)
        .background {
            RoundedRectangle(cornerRadius: 24).fill(.white)
                .shadow(color: .black.opacity(0.168), radius: 8, y: 4)
        }
    }
}

struct NavigationGuidanceCard: View {
    let title: String
    let subtitle: String
    let symbol: String
    let muted: Bool
    let elder: Bool
    let toggleVoice: () -> Void
    var voiceIdentifier = "navigation-voice-toggle"
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    var body: some View {
        (dynamicTypeSize.isAccessibilitySize ? AnyLayout(VStackLayout(alignment: .leading, spacing: 12))
            : AnyLayout(HStackLayout(alignment: .center, spacing: 12))) {
            Image(systemName: symbol).font(.system(size: 42, weight: .bold))
                .frame(width: 42).accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 6) {
                Group {
                    if elder { Text(title).elderText(.heading) }
                    else { Text(title).caregiverText() }
                }.fixedSize(horizontal: false, vertical: true)
                Group {
                    if elder { Text(subtitle).elderText() }
                    else { Text(subtitle).caregiverText(.secondary) }
                }.foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            }.frame(maxWidth: .infinity, alignment: .leading)
            Button(action: toggleVoice) {
                Image(systemName: muted ? "speaker.slash.fill" : "speaker.wave.2.fill")
                    .font(.system(size: 20)).frame(width: 44, height: 44)
                    .background(Color(red: 0.83, green: 0.91, blue: 0.91), in: Circle())
            }.buttonStyle(.plain)
                .accessibilityLabel(muted ? "Unmute guidance" : "Mute guidance")
                .accessibilityIdentifier(voiceIdentifier)
        }
        .foregroundStyle(.black).padding(16).frame(maxWidth: .infinity, minHeight: elder ? 108 : 88)
        .background(.white, in: RoundedRectangle(cornerRadius: 24))
    }
}

struct WalkingNavigationOverlay: View {
    @ObservedObject var model: WalkingNavigationModel
    let refreshMessage: String?
    let retry: () -> Void
    let follow: () -> Void
    let overview: () -> Void
    let end: () -> Void
    @State private var confirmingExit = false
    var body: some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                ScrollView { overlayContent }
            } else { overlayContent }
        }
    }
    private var overlayContent: some View {
        VStack(spacing: 12) {
            instructionCard
            Spacer(minLength: 8)
            HStack {
                Spacer()
                VStack(spacing: 10) {
                    navigationButton("location.fill", label: "Back to my location", action: follow)
                    navigationButton("arrow.up.left.and.arrow.down.right", label: "Route overview", action: overview)
                }
            }
            NavigationSummaryCard(model: model, confirmingExit: $confirmingExit, end: end)
        }
        .padding(.horizontal, 20).padding(.top, 8)
        .tint(OrbitMapStyle.blue)
    }
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    private var hasDirections: Bool { model.route != nil && model.issue == nil && !model.loading && !model.arrived && !model.suspended }
    private var instructionTitle: String {
        guard hasDirections else { return model.instruction }
        let distance = WalkingNavigationModel.distanceText(model.turnMeters)
        switch model.directionSymbol {
        case "arrow.turn.up.right": return "Turn right in \(distance)"
        case "arrow.turn.up.left": return "Turn left in \(distance)"
        default: return "Continue for \(distance)"
        }
    }
    private var instructionCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            NavigationGuidanceCard(title: instructionTitle,
                subtitle: hasDirections ? "To senior · \(Int(ceil(model.remainingSeconds / 60))) min" : "Walking navigation",
                symbol: model.directionSymbol, muted: model.muted, elder: false,
                toggleVoice: model.toggleMuted)
            if model.isDemoRoute { Text("Demo route").caregiverText(.caption).foregroundStyle(.secondary) }
            if model.loading { ProgressView().tint(OrbitStyle.teal) }
            if let refreshMessage { Text(refreshMessage).caregiverText(.caption).foregroundStyle(.secondary) }
            if model.issue != nil && !model.suspended {
                Button("Try again", action: retry).caregiverText().disabled(model.loading).frame(minHeight: 44)
            }
        }
        .padding(model.isDemoRoute || model.issue != nil || model.loading || refreshMessage != nil ? 12 : 0)
        .background(.white, in: RoundedRectangle(cornerRadius: 24))
        .caregiverCard(radius: 24)
        .accessibilityIdentifier("navigation-instruction")
    }
    private func navigationButton(_ symbol: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol).font(.system(size: 20, weight: .semibold))
                .foregroundStyle(OrbitMapStyle.blue).frame(width: 48, height: 48)
                .background(.white, in: Circle()).shadow(color: .black.opacity(0.13), radius: 5, y: 2)
        }.accessibilityLabel(label)
    }
}

struct NavigationSummaryCard: View {
    @ObservedObject var model: WalkingNavigationModel
    @Binding var confirmingExit: Bool
    let end: () -> Void

    var body: some View {
        Group {
            if confirmingExit {
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 12) { exitButton; cancelButton }
                    VStack(spacing: 10) { exitButton; cancelButton }
                }
            } else {
                HStack(spacing: 8) {
                    Button { confirmingExit = true } label: {
                        Image(systemName: "xmark").font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(OrbitMapStyle.blue).frame(width: 44, height: 44)
                    }
                    .accessibilityLabel("Exit navigation")
                    .accessibilityIdentifier("request-exit-navigation")
                    ViewThatFits(in: .horizontal) {
                        HStack(alignment: .firstTextBaseline, spacing: 8) { distance; duration; arrival }
                        VStack(spacing: 12) { distance; duration; arrival }
                    }.frame(maxWidth: .infinity)
                }
            }
        }
        .padding(16).frame(maxWidth: .infinity, minHeight: 88)
        .background(.white, in: Capsule())
        .compositingGroup()
        .caregiverCard(radius: 24)
        .accessibilityIdentifier("navigation-summary")
    }
    private var distance: some View {
        metric(model.route == nil ? "—" : "\(Int(model.remainingMeters.rounded())) m", label: "Remaining")
    }
    private var duration: some View {
        metric(model.route == nil ? "—" : "\(Int(ceil(model.remainingSeconds / 60))) min", label: "To arrive")
    }
    private var arrival: some View {
        metric(model.estimatedArrival?.formatted(date: .omitted, time: .shortened) ?? "—", label: "Arrival")
    }
    private func metric(_ value: String, label: String) -> some View {
        VStack(spacing: 6) {
            Text(value).font(.system(.title2, design: .default, weight: .bold)).foregroundStyle(OrbitMapStyle.blue).fixedSize()
            Text(label).caregiverText(.secondary).foregroundStyle(.secondary).fixedSize()
        }.frame(maxWidth: .infinity)
    }
    private var exitButton: some View {
        Button("Exit navigation", action: end)
            .caregiverText().fixedSize(horizontal: true, vertical: false)
            .frame(maxWidth: .infinity, minHeight: 56)
            .foregroundStyle(.white).background(OrbitMapStyle.blue, in: Capsule())
            .buttonStyle(.plain)
            .accessibilityIdentifier("end-navigation")
    }
    private var cancelButton: some View {
        Button("Cancel") { confirmingExit = false }
            .caregiverText().fixedSize(horizontal: true, vertical: false)
            .frame(maxWidth: .infinity, minHeight: 56)
            .foregroundStyle(OrbitMapStyle.blue).background(OrbitMapStyle.blue.opacity(0.10), in: Capsule())
            .buttonStyle(.plain)
            .accessibilityIdentifier("cancel-exit-navigation")
    }
}

#if DEBUG
// Compatibility fixture for historical snapshot tests; renders the same Location map.
// Production Navigate does not present this view.
struct WalkingNavigationPage: View {
    let snapshot: ElderLocationSnapshot?
    let name: String
    @StateObject private var model: WalkingNavigationModel
    let end: () -> Void
    init(snapshot: ElderLocationSnapshot?, name: String, model: WalkingNavigationModel, end: @escaping () -> Void) {
        self.snapshot = snapshot; self.name = name; self.end = end
        _model = StateObject(wrappedValue: model)
    }
    init(snapshot: ElderLocationSnapshot?, name: String, end: @escaping () -> Void) {
        self.init(snapshot: snapshot, name: name, model: WalkingNavigationModel(), end: end)
    }
    var body: some View {
        LocationPage(profile: ElderProfile(), snapshot: snapshot, message: nil, loading: false,
                     refresh: {}, agent: {}, navigate: {}, navigation: model)
            .task { await model.start(to: snapshot) }
    }
}
#endif

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

/// The dot stays centered on the coordinate; only the direction beam rotates with the camera.
private struct CurrentLocationDot: View {
    let heading: Double?
    let label: LocalizedStringKey
    private let blue = OrbitMapStyle.blue

    var body: some View {
        ZStack {
            if let heading, heading.isFinite {
                Path { path in
                    let center = CGPoint(x: 54, y: 54)
                    path.move(to: center)
                    path.addArc(center: center, radius: 50,
                                startAngle: .degrees(-125), endAngle: .degrees(-55), clockwise: false)
                    path.closeSubpath()
                }
                .fill(RadialGradient(colors: [blue.opacity(0.45), blue.opacity(0.22), blue.opacity(0)],
                                     center: .center, startRadius: 8, endRadius: 50))
                .blur(radius: 2)
                .rotationEffect(.degrees(heading))
                .accessibilityHidden(true)
            }
            Circle()
                .fill(blue)
                .frame(width: 24, height: 24)
                .overlay(Circle().strokeBorder(.white, lineWidth: 3))
                .shadow(color: .black.opacity(0.18), radius: 3, y: 1)
        }
        .frame(width: 108, height: 108)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(label)
    }
}
