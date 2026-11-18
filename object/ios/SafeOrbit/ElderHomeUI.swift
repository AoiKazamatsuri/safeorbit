import SwiftUI
import MapKit

struct ElderHomePage: View {
    private let locale = Locale(identifier: "en")
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.scenePhase) private var scenePhase
    @ObservedObject var session: ElderDemoSession
    @StateObject private var settings = CaregiverSettingsStore()
    @StateObject private var live = ElderLiveNavigation()
    @AppStorage(AMapRuntime.consentKey) private var mapConsent = false
    @State private var homeCamera: MapCameraPosition = .automatic
    @State private var selectedHome: GeoPoint?
    @State private var camera: MapCameraPosition = .region(ElderDemoMapData.region)
    @State private var previousCamera: MapCameraPosition?
    @State private var navigationCameraMode = NavigationCameraMode.follow
    @State private var visibleHeading = 0.0
    @State private var demoArrival = Date()
    @State private var showingVolume = false
    @State private var overlayHeight: CGFloat = 70
    private enum NavigationCameraMode { case follow, overview, manual }
    let chooseRole: () -> Void
    var onLayout: (([String: CGRect]) -> Void)? = nil
    /// Opens the voice volume page on appear (layout tests).
    var volumeInitiallyOpen = false
    /// Home zone from the care API (task T37); it replaces a home set on this phone.
    var serverHome: GeoPoint? = nil
    /// Starts navigation home when the care API asks (task T38); nil in previews and tests.
    var autoNavigation: ElderAutoNavigation? = nil
    /// The preset caregiver phone that "Call Family" dials after showing the call card.
    var familyPhone: String? = nil
    @Environment(\.openURL) private var openURL
    @ObservedObject private var notifications = NotificationRouter.shared

    private func text(_ en: String, _ zh: String) -> String { ElderCopy.text(en, zh, locale: locale) }
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .topLeading) {
                map
                if session.navigating && !session.calling {
                    navigationOverlay
                } else {
                    topControls.padding(.horizontal, OrbitLayout.pageMargin).padding(.top, 2)
                    CaregiverBottomOverlay {
                        Group {
                            if dynamicTypeSize.isAccessibilitySize && session.calling {
                                ScrollView { bottomContent(width: geometry.size.width) }
                                    .frame(height: max(160, geometry.size.height - 220))
                                    .scrollIndicators(.visible)
                            } else { bottomContent(width: geometry.size.width) }
                        }
                        .modifier(ElderBottomHeight())
                    }
                }
            }
        }
        .coordinateSpace(name: "ElderSurface")
        .onPreferenceChange(ElderControlFrames.self) { onLayout?($0) }
        .onPreferenceChange(ElderOverlayHeight.self) { overlayHeight = $0 }
        .settingsSidebar(isPresented: $session.showingSettings, widthFraction: 0.88) { settingsPage }
        .settingsSlide(isPresented: $showingVolume) { volumePage }
        .onChange(of: scenePhase) { _, phase in
            if phase != .active { session.suspendSpeech(); if session.usesLiveNavigation { live.pause() } }
            else if session.usesLiveNavigation { Task { await live.resume() } }
        }
        .onAppear {
            if volumeInitiallyOpen { showingVolume = true }
            if let serverHome { live.home.save(serverHome) }
            if session.usesLiveNavigation { live.startLocation(); updateLiveVoice() }
            if session.usesLiveNavigation, let autoNavigation {
                let live = live, session = session
                autoNavigation.isNavigatingHome = { live.navigation.isPresented && live.navigation.route != nil }
                autoNavigation.startNavigation = { await Self.startNavigationHome(live: live, session: session) }
            }
        }
        // The fallback notification "Tap to start navigation home" starts it like Go Home.
        .onReceive(notifications.$pending.receive(on: DispatchQueue.main)) { _ in
            guard session.usesLiveNavigation, notifications.take(for: .elder) == .elderStartNavigation else { return }
            goHome()
        }
        .onChange(of: serverHome) { _, home in if let home { live.home.save(home) } }
        .onChange(of: mapConsent) { _, allowed in if allowed && session.usesLiveNavigation { live.startLocation() } }
        .onChange(of: session.voiceOn) { _, _ in updateLiveVoice() }
        .onChange(of: session.volume) { _, _ in updateLiveVoice() }
        .onChange(of: session.calling) { _, _ in updateLiveVoice() }
        .onChange(of: session.navigating, initial: true) { _, navigating in
            if navigating {
                previousCamera = camera
                navigationCameraMode = .follow
                demoArrival = Date().addingTimeInterval(7 * 60)
                updateNavigationCamera()
            } else if let previousCamera {
                camera = previousCamera
                self.previousCamera = nil
            }
        }
        .onChange(of: live.point) { _, point in
            if session.navigating {
                updateNavigationCamera()
            } else if session.usesLiveNavigation, let point {
                camera = .region(MKCoordinateRegion(center: point.appleCoordinate, latitudinalMeters: 750, longitudinalMeters: 750))
            }
        }
        .onChange(of: live.navigation.fix?.timestamp) { _, _ in updateNavigationCamera() }
        .onChange(of: live.navigation.routeVersion) { _, _ in updateNavigationCamera() }
        .onReceive(Timer.publish(every: 1, on: .main, in: .common).autoconnect()) { _ in
            if session.usesLiveNavigation { live.navigation.tick() }
        }
        .sheet(isPresented: $live.showingHomeSetup) { homeSetup }
        .onDisappear {
            session.suspendSpeech(); if session.usesLiveNavigation { live.stop() }
            autoNavigation?.startNavigation = nil
        }
        .toolbar(.hidden, for: .navigationBar)
        .environment(\.locale, locale)
        .preferredColorScheme(.light)
    }

    // Cards and button rows sit on the page margins. Below 302 pt of row width (320 pt screens)
    // the two home buttons stack; otherwise Go Home takes 44.8 % of the row after its spacing.
    private func bottomContent(width: CGFloat) -> some View {
        let rowWidth = width - OrbitLayout.pageMargin * 2
        return VStack(spacing: 20) {
            if session.calling { callCard.padding(.horizontal, OrbitLayout.pageMargin) }
            else {
                if dynamicTypeSize.isAccessibilitySize || rowWidth < 302 {
                    VStack(spacing: 12) { goHomeButton; callButton }.padding(.horizontal, OrbitLayout.pageMargin)
                } else {
                    HStack(spacing: 14) {
                        goHomeButton.frame(width: (rowWidth - 14) * 0.448)
                        callButton
                    }.padding(.horizontal, OrbitLayout.pageMargin)
                }
            }
        }
    }

    private var map: some View {
        AMapConsentSurface {
            AMapCanvas(camera: $camera, markers: mapMarkers,
                       lines: WalkingRouteMap.lines(routeCoordinates, id: "home-route"), bottomOverlayInset: overlayHeight + 36,
                       onUserCameraMove: {
                           if session.navigating { navigationCameraMode = .manual }
                       },
                       onCameraChange: { visibleHeading = $0.heading })
        }.ignoresSafeArea().accessibilityIdentifier("elder-map")
    }
    private var mapMarkers: [AMapMarker] {
        var markers = WalkingRouteMap.arrows(routeCoordinates, heading: visibleHeading)
        let home = session.usesLiveNavigation ? live.home.point : ElderDemoMapData.home
        if let home {
            markers.append(AMapMarker(id: "home", coordinate: home.appleCoordinate, anchor: .bottom,
                content: AnyView(ElderPlaceMarker(symbol: "house.fill", label: "Home"))))
        }
        if !session.usesLiveNavigation {
            markers.append(AMapMarker(id: "market", coordinate: ElderDemoMapData.market.appleCoordinate, anchor: .bottom,
                content: AnyView(ElderPlaceMarker(symbol: "storefront.fill", label: "Market"))))
        }
        let point = session.usesLiveNavigation ? live.point : ElderDemoMapData.position
        if let point {
            markers.append(AMapMarker(id: "position", coordinate: point.appleCoordinate,
                content: AnyView(CurrentLocationDot(
                    heading: (session.usesLiveNavigation ? live.navigation.markerHeading ?? 0 : 0) - visibleHeading,
                    label: session.usesLiveNavigation ? "Your location" : "Sample position"))))
        }
        return markers
    }
    private var routeCoordinates: [CLLocationCoordinate2D] {
        guard session.navigating else { return [] }
        return session.usesLiveNavigation ? live.navigation.route?.coordinates ?? [] : ElderDemoMapData.route.map(\.appleCoordinate)
    }

    private var followCamera: MapCamera? {
        if session.usesLiveNavigation { return live.navigation.followCamera }
        let points = routeCoordinates
        guard points.count >= 2 else { return nil }
        return MapCamera(centerCoordinate: points[0], distance: 550,
                         heading: WalkingRouteMap.bearing(from: points[0], to: points[1]), pitch: 0)
    }

    private func updateNavigationCamera() {
        guard session.navigating else { return }
        switch navigationCameraMode {
        case .follow:
            if let followCamera {
                camera = .camera(followCamera)
            } else if let region = WalkingRouteMap.overview(routeCoordinates) {
                camera = .region(region)
            } else if let point = live.point {
                camera = .region(MKCoordinateRegion(center: point.appleCoordinate, latitudinalMeters: 750, longitudinalMeters: 750))
            }
        case .overview:
            let location = session.usesLiveNavigation ? live.point : ElderDemoMapData.position
            let home = session.usesLiveNavigation ? live.home.point : ElderDemoMapData.home
            let coordinates = routeCoordinates + [location, home].compactMap { $0?.appleCoordinate }
            if let region = WalkingRouteMap.overview(coordinates) { camera = .region(region) }
        case .manual:
            break
        }
    }
    private func updateLiveVoice() {
        guard session.usesLiveNavigation else { return }
        live.updateVoice(enabled: session.voiceOn, volume: session.volume, calling: session.calling)
    }

    private var topControls: some View {
        HStack(alignment: .top) {
            Button { session.showingSettings = true } label: {
                portrait(size: 60)
                    .overlay(Circle().stroke(OrbitStyle.teal, lineWidth: 1))
                    .shadow(color: .black.opacity(0.2), radius: 3, y: 2)
            }.buttonStyle(.plain)
                .elderMeasured("settings-portrait")
                .accessibilityLabel(text("Open settings", "打开设置"))
                .accessibilityIdentifier("elder-settings-button")
            Spacer(minLength: 8)
            VStack(alignment: .trailing, spacing: 10) {
                if session.calling {
                    Button { session.dismissCall(locale: locale) } label: {
                        Image(systemName: "xmark").font(.system(size: 24)).frame(width: 44, height: 44)
                            .background(.white, in: Circle())
                    }.accessibilityLabel(text("Close call preview", "关闭呼叫预览"))
                        .elderMeasured("dismiss-call").accessibilityIdentifier("elder-dismiss-call")
                }
            }.foregroundStyle(.black)
        }
    }

    private var goHomeButton: some View {
        ElderActionButton(title: text("Go Home", "回家"), white: true) { goHome() }
            .elderMeasured("go-home").accessibilityIdentifier("elder-go-home")
    }
    private func goHome() {
        if session.usesLiveNavigation {
            if live.home.point == nil { live.showingHomeSetup = true }
            else {
                session.startNavigation(locale: locale)
                Task { await live.goHome() }
            }
        } else { session.startNavigation(locale: locale) }
    }
    /// Same navigation as Go Home, for the care API's request; returns nil once a route is shown,
    /// else the reason it could not start (reported to the care API and shown on the event page).
    static func startNavigationHome(live: ElderLiveNavigation, session: ElderDemoSession) async -> String? {
        guard live.home.point != nil else { return ElderAutoNavigation.reason(for: .missingHome) }
        session.startNavigation(locale: Locale(identifier: "en"))
        await live.goHome()
        return live.navigation.route != nil ? nil : ElderAutoNavigation.reason(for: live.navigation.issue)
    }
    private var callButton: some View {
        ElderActionButton(title: text("Call Family", "联系家人"), symbol: "phone.fill") {
            callFamily()
        }.elderMeasured("call-family").accessibilityIdentifier("elder-call-family")
    }
    /// The call card first (product design section 4), then the system dialler, which asks her to confirm.
    private func callFamily() {
        session.cancelEnd()
        session.showCall()
        guard let phone = familyPhone, PhoneNumber.isValid(phone),
              let url = URL(string: "tel:\(PhoneNumber.normalized(phone))") else { return }
        Task {
            try? await Task.sleep(for: .seconds(1.5))
            if session.calling { openURL(url) }
        }
    }

    private var navigationOverlay: some View {
        let model = live.navigation
        let loading = session.usesLiveNavigation && (model.loading || !model.isPresented)
        let retry = session.usesLiveNavigation && Self.canRetryNavigation(model)
        let metrics = navigationMetrics
        let subtitle = metrics.duration.map { "Going Home · \($0)" } ?? "Going Home"
        let isDemo = !session.usesLiveNavigation || model.isDemoRoute
        let confirmingExit = Binding(get: { session.confirmingEnd }, set: {
            if $0 { session.requestEnd() } else { session.cancelEnd() }
        })
        return NavigationOverlay(
            guidance: NavigationInstructionPanel(
                card: NavigationGuidanceCard(
                    title: session.usesLiveNavigation ? model.instruction : "Turn right in 80 m",
                    subtitle: isDemo ? subtitle + " · Demo route" : subtitle,
                    symbol: session.usesLiveNavigation ? model.directionSymbol : "arrow.turn.up.right",
                    muted: !session.voiceOn, elder: true,
                    toggleVoice: { session.setVoice(!session.voiceOn, locale: locale) },
                    voiceIdentifier: "elder-voice-toggle"),
                loading: loading, retry: retry ? retryNavigation : nil
            ).elderMeasured("guidance-card").accessibilityIdentifier("elder-guidance-card"),
            summary: NavigationSummaryCard(metrics: metrics, confirmingExit: confirmingExit, end: {
                session.confirmEnd()
                if session.usesLiveNavigation { live.cancel() }
            }, elder: true)
                .modifier(ElderBottomHeight()).elderMeasured("navigation-summary"),
            follow: {
                navigationCameraMode = .follow
                updateNavigationCamera()
            },
            overview: {
                navigationCameraMode = .overview
                updateNavigationCamera()
            },
            callFamily: callFamily, canFollow: followCamera != nil, canOverview: !routeCoordinates.isEmpty)
    }

    private func retryNavigation() {
        Task {
            guard session.navigating, live.navigation.isPresented, !live.navigation.suspended else { return }
            await live.navigation.plan(to: live.homeSnapshot)
        }
    }

    static func canRetryNavigation(_ model: WalkingNavigationModel) -> Bool {
        model.isPresented && !model.loading && !model.suspended && !model.arrived
            && (model.issue != nil || model.route == nil)
    }

    private var navigationMetrics: NavigationMetrics {
        if !session.usesLiveNavigation {
            let points = routeCoordinates.map(MKMapPoint.init)
            let distance = zip(points, points.dropFirst()).reduce(0.0) { $0 + $1.0.distance(to: $1.1) }
            return NavigationMetrics(distance: WalkingNavigationModel.distanceText(distance), duration: "7 min", arrival: demoArrival)
        }
        let model = live.navigation
        guard model.route != nil, model.issue == nil, !model.loading, !model.suspended else { return NavigationMetrics() }
        return NavigationMetrics(distance: WalkingNavigationModel.distanceText(model.remainingMeters),
                                 duration: "\(Int(ceil(model.remainingSeconds / 60))) min", arrival: model.estimatedArrival)
    }
    private var callCard: some View {
        (dynamicTypeSize.isAccessibilitySize ? AnyLayout(VStackLayout(alignment: .leading, spacing: 16)) : AnyLayout(HStackLayout(spacing: 16))) {
            Image(systemName: "phone.fill").font(.system(size: 28))
                .foregroundStyle(.white).frame(width: 48, height: 48)
                .background(Color(red: 0.92, green: 0.29, blue: 0.30), in: Circle())
                .padding(6).background(Color(red: 1, green: 0.70, blue: 0.70), in: Circle())
            VStack(alignment: .leading, spacing: 12) {
                Text(verbatim: text("CALLING YOUR FAMILY", "正在呼叫你的家人")).elderText()
                Text(verbatim: text("We will keep you safe", "我们会保护你的安全"))
                    .elderText().foregroundStyle(.secondary)
            }.fixedSize(horizontal: false, vertical: true).frame(maxWidth: .infinity, alignment: .leading)
        }
        .foregroundStyle(.black)
        .padding(.horizontal, OrbitLayout.cardPadding).padding(.vertical, 20).frame(minHeight: 116)
        .caregiverCard(radius: 24)
        .elderMeasured("call-card").accessibilityIdentifier("elder-call-card")
    }

    @ViewBuilder private func portrait(size: CGFloat) -> some View {
        if let photo = settings.data.senior.photo { ProfileAvatar(photo: photo, size: size) }
        else { Image("ElderPortrait").resizable().scaledToFill().frame(width: size, height: size).clipShape(Circle()) }
    }
    private var homeSetup: some View {
        NavigationStack {
            GeometryReader { geometry in
            ZStack {
                AMapConsentSurface {
                    AMapCanvas(camera: $homeCamera, markers: [], bottomOverlayInset: 160, onCameraChange: { context in
                        selectedHome = MainlandCoordinates.toWGS84(GeoPoint(latitude: context.region.center.latitude, longitude: context.region.center.longitude))
                    })
                }.ignoresSafeArea()
                Image(systemName: "mappin.circle.fill").font(.system(size: 48)).foregroundStyle(OrbitStyle.teal)
                    .allowsHitTesting(false)
                VStack { Spacer()
                    VStack(spacing: 16) {
                        Text("Move the map to your home, then confirm.").elderText()
                        if let point = live.point {
                            ElderActionButton(title: "Use current location", tint: OrbitStyle.pale) {
                                selectedHome = point
                                homeCamera = .region(OrbitMapScale.region(center: point.appleCoordinate,
                                                                           viewportHeight: geometry.size.height))
                            }
                        }
                        ElderActionButton(title: "Confirm Home") {
                            if let point = selectedHome { live.home.save(point); live.showingHomeSetup = false }
                        }.disabled(selectedHome == nil || !mapConsent)
                    }
                    .padding(.horizontal, OrbitLayout.cardPadding).padding(.vertical, 24)
                    .background(.white, in: RoundedRectangle(cornerRadius: 24))
                }.padding(.horizontal, OrbitLayout.pageMargin).padding(.bottom, 30)
            }.navigationTitle("Home location").navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { live.showingHomeSetup = false } } }
                .onAppear {
                    selectedHome = live.home.point ?? live.point
                    if let point = selectedHome {
                        homeCamera = .region(OrbitMapScale.region(center: point.appleCoordinate,
                                                                   viewportHeight: geometry.size.height))
                    } else {
                        homeCamera = .region(OrbitMapScale.region(center: LocationPreviewData.campus.appleCoordinate,
                                                                   viewportHeight: geometry.size.height))
                    }
                }
            }
        }.environment(\.locale, Locale(identifier: "en"))
    }
    private var settingsPage: some View {
        SettingsSidebarPanel(name: settings.data.senior.name, elder: true, logout: {
            session.finishSession(); showingVolume = false
            live.stop(); chooseRole()
        }) {
            portrait(size: 72)
        } entries: {
            SettingsSidebarRow(title: "Voice volume", symbol: "speaker.wave.2", elder: true) { showingVolume = true }
                .accessibilityIdentifier("elder-volume-settings")
            SettingsSidebarRow(title: "Set Home", symbol: "house", elder: true) { live.showingHomeSetup = true }
                .accessibilityIdentifier("elder-set-home")
        }.accessibilityIdentifier("elder-settings-sidebar")
    }
    private var volumePage: some View {
        SettingsPage("Voice volume", elder: true, back: { showingVolume = false }) {
            VStack(alignment: .leading, spacing: 16) {
                Text("Voice volume").elderText()
                Slider(value: Binding(get: { session.volume }, set: { session.setVolume($0) }), in: 0...1) { editing in
                    if !editing { session.announce(locale: locale) }
                }.tint(OrbitStyle.teal).accessibilityLabel("Voice volume")
                Text("\(Int(session.volume * 100))%").elderText().foregroundStyle(.secondary)
            }
            .layoutProbe("elder-volume-content")
            .padding(.horizontal, OrbitLayout.cardPadding).padding(.vertical, 20)
            .background(.white, in: RoundedRectangle(cornerRadius: 24))
            .layoutProbe("elder-volume-card")
        }
    }

}

private struct ElderActionButton: View {
    let title: String
    var symbol: String? = nil
    var white = false
    var tint: Color? = nil
    var action: () -> Void
    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                if let symbol { Image(systemName: symbol).font(.system(size: 26)).frame(width: 26, height: 26) }
                Text(verbatim: title).elderText().fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity).padding(.horizontal, 16).padding(.vertical, 12).frame(minHeight: 56)
            .foregroundStyle(white || tint != nil ? .black : .white)
            .background(tint ?? (white ? .white : OrbitStyle.teal), in: Capsule())
            .shadow(color: .black.opacity(0.16), radius: 4, y: 3)
        }.buttonStyle(.plain)
    }
}
private struct ElderPlaceMarker: View {
    let symbol: String
    let label: String
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: symbol).font(.system(size: 32, weight: .bold))
                .foregroundStyle(.white).frame(width: 58, height: 58)
                .background(OrbitStyle.teal, in: Circle())
                .shadow(color: .black.opacity(0.18), radius: 3, y: 3)
            Circle().fill(OrbitStyle.teal).frame(width: 16, height: 16)
                .shadow(color: .black.opacity(0.16), radius: 3, y: 2)
        }.accessibilityElement(children: .ignore).accessibilityLabel(label)
    }
}
private struct ElderOverlayHeight: PreferenceKey {
    static var defaultValue: CGFloat = 70
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = nextValue() }
}

private struct ElderBottomHeight: ViewModifier {
    func body(content: Content) -> some View {
        content.background {
            GeometryReader { panel in
                Color.clear.preference(key: ElderOverlayHeight.self, value: panel.size.height)
            }
        }
    }
}

private struct ElderControlFrames: PreferenceKey {
    static var defaultValue: [String: CGRect] = [:]
    static func reduce(value: inout [String: CGRect], nextValue: () -> [String: CGRect]) {
        value.merge(nextValue(), uniquingKeysWith: { _, latest in latest })
    }
}
private extension View {
    func elderMeasured(_ name: String) -> some View {
        background { GeometryReader { proxy in
            Color.clear.preference(key: ElderControlFrames.self, value: [name: proxy.frame(in: .global)])
        } }
    }
}
