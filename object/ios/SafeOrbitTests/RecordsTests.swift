import XCTest
import SwiftUI
@testable import SafeOrbit

final class RecordsTests: XCTestCase {
    @MainActor func testTrendDateLabelsFitTheRenderedChartAndDoNotOverlap() async throws {
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.first as? UIWindowScene)
        let previous = scene.windows.first(where: \.isKeyWindow)
        for (width, type) in [(CGFloat(206), DynamicTypeSize.large), (CGFloat(184), .large), (CGFloat(272), .accessibility1)] {
            var frames: [Int: CGRect] = [:]
            var contentSize: CGSize = .zero
            let window = UIWindow(windowScene: scene)
            window.frame = CGRect(x: 0, y: 0, width: 402, height: 874)
            let chart = TrendDeviationChart { measuredWidth, labels in
                contentSize = measuredWidth; frames = labels
            }.frame(width: width).environment(\.dynamicTypeSize, type)
            window.rootViewController = UIHostingController(rootView: chart)
            window.makeKeyAndVisible()
            defer { window.isHidden = true; previous?.makeKeyAndVisible() }
            try await Task.sleep(for: .milliseconds(300))
            XCTAssertEqual(frames.count, 8, "All eight dates must be rendered")
            for index in 0...7 {
                let rect = try XCTUnwrap(frames[index])
                XCTAssertGreaterThan(rect.width, 0)
                XCTAssertLessThanOrEqual(rect.maxY, contentSize.height + 0.5)
                XCTAssertGreaterThanOrEqual(rect.minX, -0.5)
                XCTAssertLessThanOrEqual(rect.maxX, contentSize.width + 0.5)
                if index < 7 { XCTAssertLessThanOrEqual(rect.maxX, try XCTUnwrap(frames[index + 1]).minX + 0.5) }
            }
        }
    }
    func testTrendDatesCoverEveryDataPointInChronologicalOrder() {
        let labels = TrendAxisDate.samples
        XCTAssertEqual(labels.count, DemoRecords.weeklyDeviations().count)
        XCTAssertEqual(labels.map(\.fullLabel), ["Jul 5", "Jul 12", "Jul 19", "Jul 26", "Aug 2", "Aug 9", "Aug 16", "Aug 23"])
        XCTAssertEqual(labels.map(\.id), Array(0...7))
        XCTAssertTrue(labels.allSatisfy { !$0.month.isEmpty && !$0.day.isEmpty })
    }
    func testAgentTripHistoryPermissionBlocksAllSampleAnswers() {
        for question in DemoRecords.quickQuestions + ["8 月路线偏离几次？"] {
            let answer = DemoRecords.answer(to: question, allowTripHistory: false)
            XCTAssertTrue(answer.contains("access is off") || answer.contains("已关闭"))
            XCTAssertFalse(answer.contains("August 24"))
            XCTAssertFalse(answer.contains("route deviations"))
        }
        XCTAssertTrue(DemoRecords.answer(to: DemoRecords.quickQuestions[0], allowTripHistory: true).contains("August 24"))
    }
    func testSampleRecordsStayConsistentAcrossPages() throws {
        let august = DemoRecords.trips.filter { $0.month == 8 }
        XCTAssertEqual(august.reduce(0) { $0 + $1.deviations }, 4)
        XCTAssertEqual(DemoRecords.highestRisk(on: DemoRecords.date(2026, 8, 24)), .high)
        XCTAssertNil(DemoRecords.highestRisk(on: DemoRecords.date(2026, 8, 23)))
        XCTAssertTrue(DemoRecords.trips(on: DemoRecords.date(2026, 8, 12)).contains { $0.incomplete })
        XCTAssertEqual(DemoRecords.weeklyDeviations().count, 8)
        XCTAssertEqual(DemoRecords.weeklyDeviations().suffix(4).reduce(0, +), 4)
        let latest = try XCTUnwrap(august.filter { $0.risk == .high }.max(by: { $0.date < $1.date }))
        XCTAssertEqual(latest.day, 24)
        XCTAssertTrue(DemoRecords.answer(to: DemoRecords.quickQuestions[0]).contains("August 24, 2026"))
        XCTAssertTrue(DemoRecords.answer(to: DemoRecords.quickQuestions[1]).contains("4 route deviations"))
        XCTAssertTrue(DemoRecords.answer(to: "What is the weather?").contains("don't have a verified answer"))
        XCTAssertTrue(DemoRecords.answer(to: "8 月路线偏离几次？").contains("演示回答"))
        XCTAssertTrue(DemoRecords.answer(to: "明天天气如何？").contains("无法核对"))
        XCTAssertEqual(DemoRecords.weekStarts().map { DemoRecords.calendar.component(.weekday, from: $0) }, Array(repeating: 1, count: 8))
        for trip in DemoRecords.trips {
            XCTAssertEqual(trip.events.last?.minute, DemoRecords.calendar.component(.hour, from: trip.date) * 60
                           + DemoRecords.calendar.component(.minute, from: trip.date) + trip.durationMinutes)
            XCTAssertEqual(trip.events.map(\.minute), trip.events.map(\.minute).sorted())
        }
    }

    func testSpeechPermissionDescriptionsExist() {
        XCTAssertNotNil(Bundle.main.object(forInfoDictionaryKey: "NSMicrophoneUsageDescription"))
        XCTAssertNotNil(Bundle.main.object(forInfoDictionaryKey: "NSSpeechRecognitionUsageDescription"))
    }

    @MainActor func testCaregiverPageSnapshots() async throws {
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.first as? UIWindowScene)
        let previous = scene.windows.first(where: \.isKeyWindow)
        let folder = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("FrontendSnapshots")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let screens: [(String, CGSize, DynamicTypeSize, AnyView)] = [
            ("records-trend-design", CGSize(width: 402, height: 874), .large,
             AnyView(RecordsPage(showTrendInitially: true))),
            ("records-trend-compact", CGSize(width: 320, height: 568), .accessibility1,
             AnyView(RecordsPage(showTrendInitially: true))),
            ("agent-chat", CGSize(width: 393, height: 852), .large,
             AnyView(NavigationStack {
                 AgentSessionPage(sessions: AgentSessionStore(defaults: UserDefaults(suiteName: UUID().uuidString)!), settings: CaregiverSettingsStore(), keyboardVisible: false).toolbar(.hidden, for: .navigationBar)
             })),
            ("records-data", CGSize(width: 393, height: 852), .large,
             AnyView(RecordsPage())),
            ("records-trend", CGSize(width: 393, height: 852), .large,
             AnyView(RecordsPage(showTrendInitially: true))),
            ("records-detail", CGSize(width: 393, height: 852), .large,
             AnyView(TripDetailPage(trip: DemoRecords.trips.first { $0.month == 8 && $0.day == 24 }!, back: {}))),
            ("records-data-small-large-text", CGSize(width: 375, height: 812), .accessibility1,
             AnyView(RecordsPage())),
            ("records-trend-small-large-text", CGSize(width: 375, height: 812), .accessibility1,
             AnyView(RecordsPage(showTrendInitially: true)))
        ]
        for (name, size, type, view) in screens {
            let window = UIWindow(windowScene: scene)
            window.frame = CGRect(origin: .zero, size: size)
            let rendered: AnyView = name == "records-detail" ? view : AnyView(ZStack {
                view
                VStack { Spacer(); CaregiverTabBar(selection: .constant(name == "agent-chat" ? .agent : .records)) }
            })
            window.rootViewController = UIHostingController(rootView: rendered
                .environment(\.dynamicTypeSize, type).environment(\.colorScheme, .light))
            window.makeKeyAndVisible()
            window.rootViewController?.view.frame = window.bounds
            window.rootViewController?.view.layoutIfNeeded()
            try await Task.sleep(for: .milliseconds(name == "records-detail" ? 2500 : 300))
            let image = UIGraphicsImageRenderer(size: size).image { _ in
                window.rootViewController!.view.drawHierarchy(in: window.bounds, afterScreenUpdates: true)
            }
            let data = try XCTUnwrap(image.pngData())
            try data.write(to: folder.appendingPathComponent("\(name).png"))
            let attachment = XCTAttachment(data: data, uniformTypeIdentifier: "public.png")
            attachment.name = name
            attachment.lifetime = .keepAlways
            add(attachment)
            if name.contains("records-trend") && type.isAccessibilitySize {
                func horizontalScroll(in view: UIView) -> UIScrollView? {
                    if let scroll = view as? UIScrollView, scroll.contentSize.width > scroll.bounds.width + 1 { return scroll }
                    return view.subviews.lazy.compactMap { horizontalScroll(in: $0) }.first
                }
                let chartScroll = try XCTUnwrap(horizontalScroll(in: window.rootViewController!.view))
                chartScroll.setContentOffset(CGPoint(x: chartScroll.contentSize.width - chartScroll.bounds.width, y: 0), animated: false)
                try await Task.sleep(for: .milliseconds(200))
                XCTAssertGreaterThan(chartScroll.contentOffset.x, 0, "Large date labels must be reachable by horizontal scrolling")
                let trailing = UIGraphicsImageRenderer(size: size).image { _ in
                    window.rootViewController!.view.drawHierarchy(in: window.bounds, afterScreenUpdates: true)
                }
                try XCTUnwrap(trailing.pngData()).write(to: folder.appendingPathComponent("\(name)-chart-trailing.png"))
                chartScroll.setContentOffset(.zero, animated: false)
            }
            if name.contains("records-") && name != "records-detail" {
                func scrollView(in view: UIView) -> UIScrollView? {
                    if let scroll = view as? UIScrollView { return scroll }
                    return view.subviews.lazy.compactMap { scrollView(in: $0) }.first
                }
                if let scroll = scrollView(in: window.rootViewController!.view) {
                    scroll.setContentOffset(CGPoint(x: 0, y: max(0, scroll.contentSize.height - scroll.bounds.height + scroll.adjustedContentInset.bottom)), animated: false)
                    try await Task.sleep(for: .milliseconds(300))
                    let bottom = UIGraphicsImageRenderer(size: size).image { _ in
                        window.rootViewController!.view.drawHierarchy(in: window.bounds, afterScreenUpdates: true)
                    }
                    try XCTUnwrap(bottom.pngData()).write(to: folder.appendingPathComponent("\(name)-bottom.png"))
                    if name == "records-data" || name == "records-trend" {
                        let scale = image.scale
                        let selector = CGRect(x: 40 * scale, y: 122 * scale,
                                              width: (size.width - 80) * scale, height: 28 * scale)
                        let before = try XCTUnwrap(image.cgImage?.cropping(to: selector))
                        let after = try XCTUnwrap(bottom.cgImage?.cropping(to: selector))
                        XCTAssertEqual(UIImage(cgImage: before).pngData(), UIImage(cgImage: after).pngData(),
                                       "Trend/Data control must stay fixed while records scroll")
                    }
                }
            }
            window.isHidden = true
            previous?.makeKeyAndVisible()
        }
    }
}

@MainActor private final class ElderVoiceSpy: ElderVoiceOutput {
    var utterances: [(String, Float, String)] = []
    var stops = 0
    func speak(_ text: String, volume: Float, language: String) { utterances.append((text, volume, language)) }
    func stop() { stops += 1 }
}

final class ElderFrontendTests: XCTestCase {
    @MainActor func testRoleChoiceAlwaysStartsEmptyAndReturnsWithoutRetainingRole() {
        let router = DemoRoleRouter()
        XCTAssertNil(router.role)
        router.choose(.caregiver)
        XCTAssertEqual(router.role, .caregiver)
        router.returnToSelection()
        XCTAssertNil(router.role)
        router.choose(.elder)
        XCTAssertEqual(router.role, .elder)
        XCTAssertNil(DemoRoleRouter().role, "New launches must show the role selector")
    }
    @MainActor func testDemoNavigationVoiceMuteAndConfirmedExit() {
        let voice = ElderVoiceSpy()
        let session = ElderDemoSession(voice: voice)
        let locale = Locale(identifier: "en")
        session.startNavigation(locale: locale)
        XCTAssertTrue(session.navigating)
        XCTAssertEqual(voice.utterances.count, 1)
        XCTAssertTrue(voice.utterances[0].0.contains("Demo"))
        session.setVoice(false, locale: locale)
        session.announce(locale: locale)
        XCTAssertEqual(voice.utterances.count, 1)
        XCTAssertGreaterThan(voice.stops, 0)
        session.setVoice(true, locale: locale)
        XCTAssertEqual(voice.utterances.count, 2)
        session.requestEnd()
        XCTAssertTrue(session.confirmingEnd)
        XCTAssertTrue(session.navigating)
        session.cancelEnd()
        XCTAssertFalse(session.confirmingEnd)
        XCTAssertTrue(session.navigating)
        session.requestEnd()
        session.confirmEnd()
        XCTAssertFalse(session.navigating)
        XCTAssertFalse(session.confirmingEnd)
        session.announce(locale: locale)
        XCTAssertEqual(voice.utterances.count, 2)
    }
    @MainActor func testCallPreviewStopsGuidanceAndCanReturnToEitherHomeOrNavigation() {
        let voice = ElderVoiceSpy()
        let session = ElderDemoSession(voice: voice)
        let locale = Locale(identifier: "en")
        session.showCall()
        XCTAssertTrue(session.calling)
        XCTAssertFalse(session.navigating)
        session.dismissCall(locale: locale)
        XCTAssertFalse(session.calling)
        XCTAssertEqual(voice.utterances.count, 0)
        session.startNavigation(locale: locale)
        session.showCall()
        XCTAssertTrue(session.navigating)
        session.announce(locale: locale)
        XCTAssertEqual(voice.utterances.count, 1)
        session.dismissCall(locale: locale)
        XCTAssertTrue(session.navigating)
        XCTAssertEqual(voice.utterances.count, 2)
    }
    @MainActor func testVolumeValidationAndSystemLanguageGuidance() {
        let voice = ElderVoiceSpy()
        let session = ElderDemoSession(voice: voice)
        session.setVolume(-0.5); XCTAssertEqual(session.volume, 0)
        session.startNavigation(locale: Locale(identifier: "zh-Hans"))
        XCTAssertTrue(voice.utterances.isEmpty)
        session.setVolume(1.5); XCTAssertEqual(session.volume, 1)
        session.announce(locale: Locale(identifier: "zh-Hans"))
        XCTAssertEqual(voice.utterances.last?.2, "zh-CN")
        XCTAssertEqual(voice.utterances.last?.1, 1)
        XCTAssertTrue(voice.utterances.last?.0.contains("演示") == true)
        session.setVolume(.nan); XCTAssertEqual(session.volume, 0)
        session.suspendSpeech()
        XCTAssertGreaterThan(voice.stops, 0)
        XCTAssertEqual(ElderCopy.text("Home", "家", locale: Locale(identifier: "zh-Hant")), "家")
        XCTAssertEqual(ElderCopy.text("Home", "家", locale: Locale(identifier: "fr")), "Home")
    }
    func testDemoMapRegionContainsAllRequiredPlaces() {
        let region = ElderDemoMapData.region
        for point in [ElderDemoMapData.home, ElderDemoMapData.position, ElderDemoMapData.market] {
            let coordinate = point.appleCoordinate
            XCTAssertLessThan(abs(coordinate.latitude - region.center.latitude), region.span.latitudeDelta / 2)
            XCTAssertLessThan(abs(coordinate.longitude - region.center.longitude), region.span.longitudeDelta / 2)
        }
        XCTAssertEqual(ElderDemoMapData.route.first, ElderDemoMapData.position)
        XCTAssertEqual(ElderDemoMapData.route.last, ElderDemoMapData.home)
    }
    @MainActor func testElderVolumeSurvivesExitAndNewSessionWithoutClearingHome() throws {
        let suite = "elder-volume-" + UUID().uuidString
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let homePoint = GeoPoint(latitude: 32.06, longitude: 118.77)
        HomeLocationStore(defaults: defaults).save(homePoint)
        let voice = ElderVoiceSpy()
        let session = ElderDemoSession(voice: voice, defaults: defaults)
        session.setVolume(0.35)
        session.startNavigation(locale: Locale(identifier: "en"))
        session.showingSettings = true
        session.finishSession()
        XCTAssertFalse(session.navigating); XCTAssertFalse(session.showingSettings)
        XCTAssertGreaterThan(voice.stops, 0)
        XCTAssertEqual(ElderDemoSession(voice: ElderVoiceSpy(), defaults: defaults).volume, 0.35)
        XCTAssertEqual(HomeLocationStore(defaults: defaults).point, homePoint)
    }
    @MainActor func testElderScreenSnapshotsAtDesignAndAdaptiveSizes() async throws {
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.first as? UIWindowScene)
        let previous = scene.windows.first(where: \.isKeyWindow)
        let folder = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent("FrontendSnapshots")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let sizes: [(String, CGSize, DynamicTypeSize)] = [
            ("design", CGSize(width: 402, height: 874), .large),
            ("393", CGSize(width: 393, height: 852), .large),
            ("375", CGSize(width: 375, height: 812), .large),
            ("compact-large", CGSize(width: 320, height: 568), .accessibility1)
        ]
        for (sizeName, size, type) in sizes {
            for state in ["home", "navigation", "call", "settings", "role"] {
                let session = ElderDemoSession(voice: ElderVoiceSpy())
                if state == "navigation" { session.startNavigation(locale: Locale(identifier: "en")) }
                if state == "call" { session.showCall() }
                let window = UIWindow(windowScene: scene)
                window.frame = CGRect(origin: .zero, size: size)
                var frames: [String: CGRect] = [:]
                let screen: AnyView = state == "role" ? AnyView(DemoRoleRoot()) : AnyView(NavigationStack { ElderHomePage(session: session, chooseRole: {}, onLayout: { frames = $0 }) })
                let view = screen
                    .environment(\.dynamicTypeSize, type).environment(\.locale, Locale(identifier: "en"))
                window.rootViewController = UIHostingController(rootView: view)
                window.makeKeyAndVisible()
                defer { window.isHidden = true; previous?.makeKeyAndVisible() }
                window.rootViewController?.view.frame = window.bounds
                if state == "settings" { session.showingSettings = true }
                try await Task.sleep(for: .milliseconds(2500))
                window.rootViewController?.view.layoutIfNeeded()
                _ = UIGraphicsImageRenderer(size: size).image { _ in
                    window.rootViewController!.view.drawHierarchy(in: window.bounds, afterScreenUpdates: true)
                }
                try await Task.sleep(for: .milliseconds(100))
                print("Elder layout \(sizeName) \(state): \(frames)")
                if state != "settings" && state != "role" {
                    let expected = state == "home" ? ["go-home", "call-family"] : state == "navigation" ? ["guidance-card", "call-family"] : ["call-card"]
                    for name in expected {
                        let frame = try XCTUnwrap(frames[name])
                        XCTAssertGreaterThan(frame.width, 0)
                        XCTAssertGreaterThanOrEqual(frame.minX, -0.5)
                        XCTAssertLessThanOrEqual(frame.maxX, size.width + 0.5)
                        if !type.isAccessibilitySize {
                            XCTAssertGreaterThanOrEqual(frame.minY, -0.5)
                            XCTAssertLessThanOrEqual(frame.maxY, size.height + 0.5)
                        }
                    }
                    if state == "navigation" {
                        let guidance = try XCTUnwrap(frames[type.isAccessibilitySize ? "guidance-viewport" : "guidance-card"])
                        let cancel = try XCTUnwrap(frames["cancel-navigation"])
                        let call = try XCTUnwrap(frames["call-family"])
                        XCTAssertLessThanOrEqual(guidance.maxY, cancel.minY + 0.5, "Top guidance must not overlap bottom actions")
                        XCTAssertEqual(cancel.width, call.width, accuracy: 1)
                        XCTAssertEqual(cancel.maxY, call.maxY, accuracy: 1)
                    }
                    if state == "call", let close = frames["dismiss-call"], let card = frames["call-card"] {
                        XCTAssertLessThanOrEqual(close.maxY, card.minY + 0.5, "Close button must remain above the call card")
                    }
                    if state == "home" {
                        let go = try XCTUnwrap(frames["go-home"]), call = try XCTUnwrap(frames["call-family"])
                        XCTAssertTrue(go.maxX <= call.minX + 0.5 || go.maxY <= call.minY + 0.5)
                    }
                }
                let image = UIGraphicsImageRenderer(size: size).image { _ in
                    window.rootViewController!.view.drawHierarchy(in: window.bounds, afterScreenUpdates: true)
                }
                XCTAssertEqual(image.size, size)
                let data = try XCTUnwrap(image.pngData())
                let name = "elder-\(state)-\(sizeName)"
                try data.write(to: folder.appendingPathComponent("\(name).png"))
                let attachment = XCTAttachment(data: data, uniformTypeIdentifier: "public.png")
                attachment.name = name; attachment.lifetime = .keepAlways; add(attachment)
            }
        }
    }
}

@MainActor private final class HomeRouteStub: WalkingRouteProvider {
    var routeCalls = 0
    var stops = 0
    var receive: ((Result<NavigationFix, NavigationIssue>) -> Void)?
    func currentPoint() async throws -> GeoPoint { LocationPreviewData.startingPoint }
    func route(from: GeoPoint, to: GeoPoint) async throws -> WalkingRoute {
        routeCalls += 1
        return WalkingRoute(coordinates: [from.appleCoordinate, to.appleCoordinate], distanceMeters: 210,
                            expectedSeconds: 180, steps: ["Continue straight"])
    }
    func startUpdates(_ receive: @escaping (Result<NavigationFix, NavigationIssue>) -> Void) { self.receive = receive }
    func stopUpdates() { stops += 1; receive = nil }
}
final class ElderLiveNavigationTests: XCTestCase {
    @MainActor func testHomeStorageRequiresValidCoordinateAndDoesNotChangeProfileStorage() throws {
        let name = "HomeStorageTest-" + UUID().uuidString
        let defaults = try XCTUnwrap(UserDefaults(suiteName: name))
        defer { defaults.removePersistentDomain(forName: name) }
        let store = HomeLocationStore(defaults: defaults)
        XCTAssertNil(store.point)
        store.save(GeoPoint(latitude: .nan, longitude: 118))
        XCTAssertNil(store.point)
        store.save(LocationPreviewData.campus)
        XCTAssertEqual(HomeLocationStore(defaults: defaults).point, LocationPreviewData.campus)
        store.save(GeoPoint(latitude: 91, longitude: 118))
        XCTAssertEqual(store.point, LocationPreviewData.campus)
        XCTAssertNil(defaults.object(forKey: "safeorbit.caregiver.settings.v1"))
    }
    @MainActor func testGoHomeRequiresConfiguredHomeWithoutRequestingSampleRoute() async throws {
        let name = "HomeMissingTest-" + UUID().uuidString
        let defaults = try XCTUnwrap(UserDefaults(suiteName: name))
        defer { defaults.removePersistentDomain(forName: name) }
        let provider = HomeRouteStub()
        let live = ElderLiveNavigation(home: HomeLocationStore(defaults: defaults), provider: provider, navigationProvider: provider)
        await live.goHome()
        XCTAssertTrue(live.showingHomeSetup)
        XCTAssertFalse(live.navigation.isPresented)
        XCTAssertNil(live.point)
        XCTAssertEqual(provider.routeCalls, 0)
        live.home.save(LocationPreviewData.campus)
        await live.goHome()
        XCTAssertTrue(live.navigation.isPresented)
        XCTAssertEqual(provider.routeCalls, 1)
        XCTAssertEqual(live.navigation.destination?.coordinate, LocationPreviewData.campus)
        live.cancel()
        XCTAssertFalse(live.navigation.isPresented)
        XCTAssertNil(live.navigation.route)
        XCTAssertGreaterThan(provider.stops, 0)
    }
    @MainActor func testStaticHomeDoesNotExpireAndLiveSessionNeverSpeaksSampleGuidance() async {
        let provider = HomeRouteStub()
        let voice = ElderVoiceSpy()
        let session = ElderDemoSession(voice: voice, usesLiveNavigation: true)
        session.startNavigation(locale: Locale(identifier: "en"))
        XCTAssertTrue(voice.utterances.isEmpty)
        let old = ElderLocationSnapshot(coordinate: LocationPreviewData.campus, recordedAt: .distantPast,
                                       heading: nil, status: nil, batteryPercent: nil, address: nil, trail: [], safeZones: [])
        let home = WalkingNavigationModel(provider: provider, destinationKind: .home)
        await home.start(to: old)
        XCTAssertNotNil(home.route)
        XCTAssertNil(home.issue)
        home.end()
        let senior = WalkingNavigationModel(provider: provider)
        await senior.start(to: old)
        XCTAssertEqual(senior.issue, .staleDestination)
        XCTAssertNil(senior.route)
        senior.end()
    }
}

final class AgentSessionTests: XCTestCase {
    @MainActor private func isolatedDefaults() -> UserDefaults {
        UserDefaults(suiteName: "safeorbit.test.sessions.\(UUID().uuidString)")!
    }
    @MainActor func testBlankDraftIsEphemeralAndFirstSendPersistsStableIDsAndFixedTitle() throws {
        let defaults = isolatedDefaults()
        let store = AgentSessionStore(defaults: defaults)
        XCTAssertNil(store.activeID)
        let draftID = try XCTUnwrap(store.newConversation())
        store.setDraft("Unsent draft", for: draftID)
        store.showList(); store.open(draftID)
        XCTAssertEqual(store.draft(for: draftID), "Unsent draft")
        XCTAssertTrue(store.sessions.isEmpty)
        XCTAssertFalse(store.send(" \n ", in: draftID, allowTripHistory: true))
        XCTAssertNil(defaults.object(forKey: AgentSessionStore.storageKey))
        XCTAssertTrue(AgentSessionStore(defaults: defaults).sessions.isEmpty)
        let persisted = AgentSessionStore(defaults: defaults)
        let id = try XCTUnwrap(persisted.newConversation())
        persisted.setDraft("draft", for: id)
        XCTAssertNil(defaults.object(forKey: AgentSessionStore.storageKey))
        XCTAssertTrue(persisted.send(DemoRecords.quickQuestions[0], in: id, allowTripHistory: true))
        XCTAssertEqual(persisted.sessions.count, 1)
        XCTAssertEqual(persisted.sessions[0].title, "Recent high-risk event")
        XCTAssertEqual(persisted.sessions[0].messages.count, 2)
        XCTAssertEqual(persisted.draft(for: id), "")
        XCTAssertTrue(persisted.send(DemoRecords.quickQuestions[1], in: id, allowTripHistory: true))
        let restored = AgentSessionStore(defaults: defaults)
        XCTAssertEqual(restored.sessions, persisted.sessions)
        XCTAssertEqual(restored.sessions[0].title, "Recent high-risk event")
        XCTAssertEqual(Set(restored.sessions[0].messages.map(\.id)).count, 4)
        XCTAssertNil(restored.activeID)
        XCTAssertEqual(restored.draft(for: id), "")
    }
    @MainActor func testOnlySendingChangesRecencyAndOpeningKeepsDraft() throws {
        var date = Date(timeIntervalSince1970: 100)
        let store = AgentSessionStore(defaults: isolatedDefaults(), now: { date })
        let a = try XCTUnwrap(store.newConversation())
        store.send("First question", in: a, allowTripHistory: true)
        date.addTimeInterval(1)
        let b = try XCTUnwrap(store.newConversation())
        store.send("Second question", in: b, allowTripHistory: true)
        XCTAssertEqual(store.recent.map(\.id), [b, a])
        store.open(a); store.setDraft("Follow up", for: a); store.showList(); store.showList(); store.open(a)
        XCTAssertEqual(store.draft(for: a), "Follow up")
        XCTAssertEqual(store.recent.map(\.id), [b, a])
        date.addTimeInterval(1)
        store.send(store.draft(for: a), in: a, allowTripHistory: true)
        XCTAssertEqual(store.recent.map(\.id), [a, b])
    }
    @MainActor func testConfirmedDeletionRemovesMessagesDraftAndActiveSelectionFromDisk() throws {
        let defaults = isolatedDefaults()
        let store = AgentSessionStore(defaults: defaults)
        let diskStore = AgentSessionStore(defaults: defaults)
        let id = try XCTUnwrap(diskStore.newConversation())
        diskStore.send("Question", in: id, allowTripHistory: true)
        diskStore.setDraft("draft", for: id)
        let before = defaults.data(forKey: AgentSessionStore.storageKey)
        diskStore.showList(); diskStore.open(id)
        XCTAssertEqual(defaults.data(forKey: AgentSessionStore.storageKey), before, "Opening/cancelling must not delete")
        XCTAssertTrue(diskStore.delete(id))
        XCTAssertNil(diskStore.conversation(id))
        XCTAssertNil(diskStore.activeID)
        XCTAssertEqual(diskStore.draft(for: id), "")
        XCTAssertTrue(AgentSessionStore(defaults: defaults).sessions.isEmpty)
        XCTAssertFalse(store.delete(UUID()))
    }
    @MainActor func testCorruptionCannotBeOverwrittenAndRetryRestoresOriginalHistory() throws {
        let defaults = isolatedDefaults()
        let good = AgentSessionStore(defaults: defaults)
        let id = try XCTUnwrap(good.newConversation())
        good.send("Saved question", in: id, allowTripHistory: true)
        let valid = try XCTUnwrap(defaults.data(forKey: AgentSessionStore.storageKey))
        let corrupt = Data("invalid json".utf8)
        defaults.set(corrupt, forKey: AgentSessionStore.storageKey)
        let restored = AgentSessionStore(defaults: defaults)
        XCTAssertNotNil(restored.storageError)
        XCTAssertNil(restored.newConversation())
        XCTAssertFalse(restored.send("New question", in: id, allowTripHistory: true))
        XCTAssertFalse(restored.delete(id))
        restored.retryLoading()
        XCTAssertEqual(defaults.data(forKey: AgentSessionStore.storageKey), corrupt)
        defaults.set(valid, forKey: AgentSessionStore.storageKey)
        restored.retryLoading()
        XCTAssertNil(restored.storageError)
        XCTAssertEqual(restored.sessions, good.sessions)
        defaults.set("wrong storage type", forKey: AgentSessionStore.storageKey)
        restored.retryLoading()
        XCTAssertNotNil(restored.storageError)
        XCTAssertEqual(defaults.string(forKey: AgentSessionStore.storageKey), "wrong storage type")
    }
    @MainActor func testDisablingTripHistoryKeepsPriorMessagesAndBlocksOnlyNewAnswers() throws {
        let defaults = isolatedDefaults()
        let store = AgentSessionStore(defaults: defaults)
        let sessions = AgentSessionStore(defaults: defaults)
        let id = try XCTUnwrap(sessions.newConversation())
        sessions.send(DemoRecords.quickQuestions[0], in: id, allowTripHistory: true)
        let previous = sessions.sessions[0].messages
        sessions.send(DemoRecords.quickQuestions[0], in: id, allowTripHistory: false)
        XCTAssertEqual(Array(sessions.sessions[0].messages.prefix(2)), previous)
        XCTAssertTrue(sessions.sessions[0].messages.last!.text.contains("access is off"))
        XCTAssertEqual(AgentSessionStore(defaults: defaults).sessions, sessions.sessions)
        XCTAssertTrue(store.sessions.isEmpty)
    }
    func testTitlesUseThemesFirstSentenceAndLanguageLimits() {
        XCTAssertEqual(DemoRecords.quickQuestions.map(AgentConversationTitle.make),
                       ["Recent high-risk event", "August route deviations", "Unusual movement trends"])
        XCTAssertEqual(AgentConversationTitle.make(from: "  Where is my family? More detail. "), "Where is my family")
        XCTAssertEqual(AgentConversationTitle.make(from: "one two three four five six seven eight"), "one two three four five six…")
        XCTAssertEqual(AgentConversationTitle.make(from: "one two three four five six"), "one two three four five six")
        let chinese = "老人最近出行是否偏离路线需要查看哪些具体信息"
        XCTAssertEqual(AgentConversationTitle.make(from: chinese), String(chinese.prefix(18)) + "…")
        XCTAssertEqual(AgentConversationTitle.make(from: "最近出行。其他问题"), "最近出行")
    }
    @MainActor func testSessionAndRecordsLayoutsAtAllRequiredSizes() async throws {
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.first as? UIWindowScene)
        let previous = scene.windows.first(where: \.isKeyWindow)
        let folder = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent("FrontendSnapshots")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let settings = CaregiverSettingsStore(defaults: isolatedDefaults())
        for (width, height, type) in [(402, 874, DynamicTypeSize.large), (393, 852, .large), (375, 812, .large), (320, 568, .accessibility1)] {
            let sessions = AgentSessionStore(defaults: isolatedDefaults())
            for question in DemoRecords.quickQuestions + ["How can I better understand these recent changes in outdoor movement?"] {
                let id = try XCTUnwrap(sessions.newConversation())
                sessions.send(question, in: id, allowTripHistory: true)
            }
            sessions.showList()
            for screen in ["sessions", "session-chat", "session-empty", "sessions-records", "session-load-error"] {
                if screen == "session-chat" { sessions.open(sessions.sessions[0].id) }
                if screen == "session-empty" { sessions.newConversation() }
                if screen == "session-load-error" { sessions.showList() }
                let damagedDefaults = isolatedDefaults()
                damagedDefaults.set(Data("corrupt".utf8), forKey: AgentSessionStore.storageKey)
                let displayedSessions = screen == "session-load-error" ? AgentSessionStore(defaults: damagedDefaults) : sessions
                let window = UIWindow(windowScene: scene)
                window.frame = CGRect(x: 0, y: 0, width: width, height: height)
                let page = screen == "sessions-records" ? AnyView(RecordsPage()) : AnyView(AgentSessionPage(sessions: displayedSessions, settings: settings, keyboardVisible: false))
                window.rootViewController = UIHostingController(rootView: ZStack {
                    page
                    if screen == "sessions-records" || displayedSessions.activeID == nil {
                        CaregiverTabBar(selection: .constant(screen == "sessions-records" ? .records : .agent))
                    }
                }.environment(\.dynamicTypeSize, type).environment(\.colorScheme, .light))
                window.makeKeyAndVisible()
                window.rootViewController!.view.layoutIfNeeded()
                try await Task.sleep(for: .milliseconds(300))
                let image = UIGraphicsImageRenderer(size: window.bounds.size).image { _ in window.rootViewController!.view.drawHierarchy(in: window.bounds, afterScreenUpdates: true) }
                try XCTUnwrap(image.pngData()).write(to: folder.appendingPathComponent("\(screen)-\(width)x\(height).png"))
                func scrollView(in view: UIView) -> UIScrollView? {
                    if let scroll = view as? UIScrollView { return scroll }
                    return view.subviews.lazy.compactMap { scrollView(in: $0) }.first
                }
                if let scroll = scrollView(in: window.rootViewController!.view) {
                    let bottom = max(0, scroll.contentSize.height - scroll.bounds.height + scroll.adjustedContentInset.bottom)
                    if bottom > 0 {
                        scroll.setContentOffset(CGPoint(x: 0, y: bottom), animated: false)
                        try await Task.sleep(for: .milliseconds(200))
                        XCTAssertGreaterThan(scroll.contentOffset.y, 0, "Overflow must remain reachable by scrolling")
                        let trailing = UIGraphicsImageRenderer(size: window.bounds.size).image { _ in
                            window.rootViewController!.view.drawHierarchy(in: window.bounds, afterScreenUpdates: true)
                        }
                        try XCTUnwrap(trailing.pngData()).write(to: folder.appendingPathComponent("\(screen)-\(width)x\(height)-bottom.png"))
                    }
                }
                window.isHidden = true
                previous?.makeKeyAndVisible()
            }
        }
    }
}
