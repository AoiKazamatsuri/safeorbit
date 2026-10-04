import XCTest
import SwiftUI
@testable import SafeOrbit

final class RecordsTests: XCTestCase {
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
            ("agent-chat", CGSize(width: 393, height: 852), .large,
             AnyView(AgentChatPage(keyboardVisible: false))),
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
            window.isHidden = true
            previous?.makeKeyAndVisible()
        }
    }
}
