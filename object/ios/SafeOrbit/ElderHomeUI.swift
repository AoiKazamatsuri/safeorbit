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
    @State private var showingVolume = false
    @State private var overlayHeight: CGFloat = 70
    let chooseRole: () -> Void
    var onLayout: (([String: CGRect]) -> Void)? = nil

    private func text(_ en: String, _ zh: String) -> String { ElderCopy.text(en, zh, locale: locale) }
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .topLeading) {
                map
                VStack(spacing: 16) {
                    topControls.padding(.horizontal, 32)
                    if session.navigating && !session.calling {
                        if dynamicTypeSize.isAccessibilitySize {
                            ScrollView { guidanceCard.padding(.horizontal, 30).padding(.vertical, 8) }
                                .frame(height: max(100, geometry.size.height - geometry.safeAreaInsets.top - overlayHeight - 130))
                                .clipped().elderMeasured("guidance-viewport")
                        } else { guidanceCard.padding(.horizontal, 30) }
                    }
                }.padding(.top, 2)
                CaregiverBottomOverlay {
                    Group {
                        if dynamicTypeSize.isAccessibilitySize && session.calling {
                            ScrollView { bottomContent(width: geometry.size.width) }
                                .frame(height: max(160, geometry.size.height - 220))
                                .scrollIndicators(.visible)
                        } else { bottomContent(width: geometry.size.width) }
                    }
                    .background {
                        GeometryReader { panel in
                            Color.clear.preference(key: ElderOverlayHeight.self, value: panel.size.height)
                        }
                    }
                }
            }
        }
        .coordinateSpace(name: "ElderSurface")
        .onPreferenceChange(ElderControlFrames.self) { onLayout?($0) }
        .onPreferenceChange(ElderOverlayHeight.self) { overlayHeight = $0 }
        .settingsSidebar(isPresented: $session.showingSettings, widthFraction: 0.88) { settingsPage }
        .settingsSlide(isPresented: $showingVolume) { volumePage }
        .alert(text("End navigation?", "结束导航？"), isPresented: Binding(
            get: { session.confirmingEnd }, set: { if !$0 { session.cancelEnd() } }
        )) {
            Button(text("End navigation", "结束导航"), role: .destructive) { session.confirmEnd(); if session.usesLiveNavigation { live.cancel() } }
            Button(text("Keep navigating", "继续导航"), role: .cancel) { session.cancelEnd() }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase != .active { session.suspendSpeech(); if session.usesLiveNavigation { live.pause() } }
            else if session.usesLiveNavigation { Task { await live.resume() } }
        }
        .onAppear { if session.usesLiveNavigation { live.startLocation(); updateLiveVoice() } }
        .onChange(of: mapConsent) { _, allowed in if allowed && session.usesLiveNavigation { live.startLocation() } }
        .onChange(of: session.voiceOn) { _, _ in updateLiveVoice() }
        .onChange(of: session.volume) { _, _ in updateLiveVoice() }
        .onChange(of: session.calling) { _, _ in updateLiveVoice() }
        .onChange(of: live.point) { _, point in
            if session.usesLiveNavigation, let point {
                camera = .region(MKCoordinateRegion(center: point.appleCoordinate, latitudinalMeters: 750, longitudinalMeters: 750))
            }
        }
        .onReceive(Timer.publish(every: 1, on: .main, in: .common).autoconnect()) { _ in
            if session.usesLiveNavigation { live.navigation.tick() }
        }
        .sheet(isPresented: $live.showingHomeSetup) { homeSetup }
        .onDisappear { session.suspendSpeech(); if session.usesLiveNavigation { live.stop() } }
        .toolbar(.hidden, for: .navigationBar)
        .environment(\.locale, locale)
        .preferredColorScheme(.light)
    }

    private func bottomContent(width: CGFloat) -> some View {
        VStack(spacing: 20) {
            if session.calling { callCard.padding(.horizontal, 30) }
            else if session.navigating {
                HStack(spacing: 14) {
                    ElderActionButton(title: "Cancel", white: true, fillsRowHeight: true) {
                        session.requestEnd()
                    }.accessibilityLabel("Cancel navigation")
                        .accessibilityIdentifier("elder-end-navigation").elderMeasured("cancel-navigation")
                    ElderActionButton(title: "Call Family", symbol: "phone.fill", fillsRowHeight: true) {
                        session.showCall()
                    }.elderMeasured("call-family").accessibilityIdentifier("elder-call-family")
                }.fixedSize(horizontal: false, vertical: true).padding(.horizontal, 22)
            } else {
                if dynamicTypeSize.isAccessibilitySize || width < 350 {
                    VStack(spacing: 12) { goHomeButton; callButton }.padding(.horizontal, 24)
                } else {
                    HStack(spacing: 14) {
                        goHomeButton.frame(width: (width - 62) * 0.448)
                        callButton
                    }.padding(.horizontal, 24)
                }
            }
        }
    }

    private var map: some View {
        AMapConsentSurface {
            AMapCanvas(camera: $camera, markers: mapMarkers,
                       lines: mapLines, bottomOverlayInset: overlayHeight + 36)
        }.ignoresSafeArea().accessibilityIdentifier("elder-map")
    }
    private var mapMarkers: [AMapMarker] {
        var markers: [AMapMarker] = []
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
                content: AnyView(Image(systemName: "location.north.fill").font(.system(size: 58, weight: .bold))
                    .foregroundStyle(OrbitStyle.teal)
                    .rotationEffect(.degrees(session.usesLiveNavigation ? live.navigation.markerHeading ?? 0 : 0))
                    .shadow(color: .black.opacity(0.18), radius: 3, y: 3)
                    .accessibilityLabel(session.usesLiveNavigation ? "Your location" : "Sample position"))))
        }
        return markers
    }
    private var mapLines: [AMapLine] {
        guard session.navigating else { return [] }
        let coordinates = session.usesLiveNavigation ? live.navigation.route?.coordinates ?? [] : ElderDemoMapData.route.map(\.appleCoordinate)
        return coordinates.count > 1 ? [AMapLine(id: "home-route", coordinates: coordinates, color: OrbitStyle.teal, width: 4, dash: [8, 6])] : []
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
        ElderActionButton(title: text("Go Home", "回家"), white: true) {
            if session.usesLiveNavigation {
                if live.home.point == nil { live.showingHomeSetup = true }
                else {
                    session.startNavigation(locale: locale)
                    Task { await live.goHome() }
                }
            } else { session.startNavigation(locale: locale) }
        }.elderMeasured("go-home").accessibilityIdentifier("elder-go-home")
    }
    private var callButton: some View {
        ElderActionButton(title: text("Call Family", "联系家人"), symbol: "phone.fill") {
            session.showCall()
        }.elderMeasured("call-family").accessibilityIdentifier("elder-call-family")
    }

    private var guidanceCard: some View {
        NavigationGuidanceCard(
            title: session.usesLiveNavigation ? live.navigation.instruction : "Turn right in 80m",
            subtitle: session.usesLiveNavigation ? liveSummary : "Going Home · 7min",
            symbol: session.usesLiveNavigation ? live.navigation.directionSymbol : "arrow.turn.up.right",
            muted: !session.voiceOn, elder: true,
            toggleVoice: { session.setVoice(!session.voiceOn, locale: locale) },
            voiceIdentifier: "elder-voice-toggle")
        .caregiverCard(radius: 24)
        .elderMeasured("guidance-card").accessibilityIdentifier("elder-guidance-card")
    }

    private var liveSummary: String {
        guard live.navigation.route != nil else { return "Going Home" }
        return "Going Home · \(WalkingNavigationModel.distanceText(live.navigation.remainingMeters)) · \(Int(ceil(live.navigation.remainingSeconds / 60))) min"
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
        .foregroundStyle(.black).padding(20).frame(minHeight: 116)
        .caregiverCard(radius: 24)
        .elderMeasured("call-card").accessibilityIdentifier("elder-call-card")
    }

    @ViewBuilder private func portrait(size: CGFloat) -> some View {
        if let photo = settings.data.senior.photo { ProfileAvatar(photo: photo, size: size) }
        else { Image("ElderPortrait").resizable().scaledToFill().frame(width: size, height: size).clipShape(Circle()) }
    }
    private var homeSetup: some View {
        NavigationStack {
            ZStack {
                AMapConsentSurface {
                    AMapCanvas(camera: $homeCamera, markers: [], bottomOverlayInset: 160) { context in
                        selectedHome = MainlandCoordinates.toWGS84(GeoPoint(latitude: context.region.center.latitude, longitude: context.region.center.longitude))
                    }
                }.ignoresSafeArea()
                Image(systemName: "mappin.circle.fill").font(.system(size: 48)).foregroundStyle(OrbitStyle.teal)
                    .allowsHitTesting(false)
                VStack { Spacer()
                    VStack(spacing: 16) {
                        Text("Move the map to your home, then confirm.").elderText()
                        if let point = live.point {
                            Button("Use current location") {
                                selectedHome = point
                                homeCamera = .region(MKCoordinateRegion(center: point.appleCoordinate, latitudinalMeters: 500, longitudinalMeters: 500))
                            }.elderText().buttonStyle(.bordered)
                        }
                        ElderActionButton(title: "Confirm Home") {
                            if let point = selectedHome { live.home.save(point); live.showingHomeSetup = false }
                        }.disabled(selectedHome == nil || !mapConsent)
                    }.padding(24).background(.white, in: RoundedRectangle(cornerRadius: 24))
                }.padding(.horizontal, 16).padding(.bottom, 30)
            }.navigationTitle("Home location").navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { live.showingHomeSetup = false } } }
                .onAppear {
                    selectedHome = live.home.point ?? live.point
                    if let point = selectedHome {
                        homeCamera = .region(MKCoordinateRegion(center: point.appleCoordinate, latitudinalMeters: 500, longitudinalMeters: 500))
                    } else { homeCamera = .region(ElderDemoMapData.region) }
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
            }.padding(20).background(.white, in: RoundedRectangle(cornerRadius: 24))
        }
    }

}

private struct ElderActionButton: View {
    let title: String
    var symbol: String? = nil
    var white = false
    var fillsRowHeight = false
    var action: () -> Void
    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                if let symbol { Image(systemName: symbol).font(.system(size: 26)).frame(width: 26, height: 26) }
                Text(verbatim: title).elderText().fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity).padding(.horizontal, 16).padding(.vertical, 12).frame(minHeight: 50)
            .frame(maxHeight: fillsRowHeight ? .infinity : nil)
            .foregroundStyle(white ? .black : .white)
            .background(white ? .white : OrbitStyle.teal, in: Capsule())
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
