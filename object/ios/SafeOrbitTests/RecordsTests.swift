import XCTest
import SwiftUI
@testable import SafeOrbit

final class RecordsTests: XCTestCase {
    @MainActor func testRecordingLayoutMatrixAndRealScrollReachability() async throws {
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.first as? UIWindowScene)
        let previous = scene.windows.first(where: \.isKeyWindow)
        let folder = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("T15Snapshots")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let sizes = [CGSize(width: 320, height: 568), CGSize(width: 375, height: 812),
                     CGSize(width: 390, height: 844), CGSize(width: 393, height: 852),
                     CGSize(width: 402, height: 874), CGSize(width: 430, height: 932)]
        let types: [(String, DynamicTypeSize)] = [("large", .large), ("xxxLarge", .xxxLarge),
                                                 ("accessibility1", .accessibility1), ("accessibility5", .accessibility5)]
        for size in sizes {
            for (typeName, type) in types {
                for trend in [false, true] {
                    let name = "\(trend ? "trend" : "data")-\(Int(size.width))x\(Int(size.height))-\(typeName)"
                    var frames: [String: CGRect] = [:]
                    let window = UIWindow(windowScene: scene)
                    window.frame = CGRect(origin: .zero, size: size)
                    window.rootViewController = UIHostingController(rootView: ZStack {
                        RecordsPage(showTrendInitially: trend, onLayout: { frames = $0 })
                        CaregiverTabBar(selection: .constant(.records))
                    }.environment(\.dynamicTypeSize, type).environment(\.colorScheme, .light))
                    window.makeKeyAndVisible()
                    defer { window.isHidden = true; previous?.makeKeyAndVisible() }
                    try await Task.sleep(for: .milliseconds(250))
                    let view = try XCTUnwrap(window.rootViewController?.view)
                    view.layoutIfNeeded()
                    try snapshotRecording(window, to: folder.appendingPathComponent(name + "-top.png"))
                    let title = try XCTUnwrap(frames["title"], name)
                    let picker = try XCTUnwrap(frames["picker"], name)
                    XCTAssertLessThanOrEqual(title.maxY, picker.minY, name)
                    print("Recording \(name): pickerHeight=\(picker.height), calendarHeight=\(frames["calendar"]?.height ?? 0)")
                    var visited = frames
                    let scrolls = recordingScrollViews(in: view)
                    let vertical = try XCTUnwrap(scrolls.first(where: { $0.bounds.height > 0 && $0.contentSize.height > $0.bounds.height + 1 })
                        ?? scrolls.max(by: { $0.bounds.height < $1.bounds.height }), name)
                    var end: CGFloat = 0
                    for _ in 0..<100 {
                        end = max(0, vertical.contentSize.height - vertical.bounds.height + vertical.adjustedContentInset.bottom)
                        let next = min(end, vertical.contentOffset.y + vertical.bounds.height * 0.8)
                        vertical.setContentOffset(CGPoint(x: 0, y: next), animated: false)
                        try await Task.sleep(for: .milliseconds(70))
                        visited.merge(frames, uniquingKeysWith: { _, latest in latest })
                        if abs(vertical.contentOffset.y - end) < 1 { break }
                    }
                    XCTAssertEqual(vertical.contentOffset.y, end, accuracy: 1, name)
                    if end == 0 {
                        XCTAssertLessThanOrEqual(vertical.contentSize.height, vertical.bounds.height + 0.5,
                                                 name + " content fits without vertical scrolling")
                    }
                    XCTAssertEqual(frames["title"], title, name + " title must stay fixed")
                    XCTAssertEqual(frames["picker"], picker, name + " picker must stay fixed")
                    try snapshotRecording(window, to: folder.appendingPathComponent(name + "-bottom.png"))
                    if let horizontal = scrolls.first(where: { $0.contentSize.width > $0.bounds.width + 1 }) {
                        let trailing = horizontal.contentSize.width - horizontal.bounds.width
                        horizontal.setContentOffset(CGPoint(x: trailing, y: 0), animated: false)
                        try await Task.sleep(for: .milliseconds(80))
                        XCTAssertEqual(horizontal.contentOffset.x, trailing, accuracy: 1, name + " horizontal end is reachable")
                    }
                    for (key, rect) in visited {
                        XCTAssertGreaterThan(rect.width, 0, name + " " + key)
                        XCTAssertGreaterThanOrEqual(rect.minX, -0.5, name + " " + key)
                        XCTAssertLessThanOrEqual(rect.maxX, size.width + 0.5, name + " " + key)
                    }
                    if trend {
                        for metric in ["Unusual Movement", "Navigation Assistance", "High-risk Events", "Safe Return Rate"] {
                            let card = try XCTUnwrap(visited["metric-" + metric], name + metric)
                            for prefix in ["metric-summary-", "metric-bars-"] {
                                let field = try XCTUnwrap(visited[prefix + metric], name + prefix + metric)
                                XCTAssertGreaterThanOrEqual(field.minX, card.minX, name + prefix)
                                XCTAssertLessThanOrEqual(field.maxX, card.maxX + 0.5, name + prefix)
                            }
                        }
                        let summary = try XCTUnwrap(visited["trend-summary"], name)
                        let chart = try XCTUnwrap(visited["trend-chart-viewport"], name)
                        XCTAssertTrue(summary.maxX <= chart.minX + 0.5 || summary.maxY <= chart.minY + 0.5, name)
                    } else {
                        for control in ["previous-month", "next-month", "previous-week", "next-week", "expand-week"] {
                            let rect = try XCTUnwrap(visited[control], name + control)
                            XCTAssertGreaterThanOrEqual(rect.width + 0.0001, 44, name + control)
                            if !control.hasSuffix("month") {
                                XCTAssertGreaterThanOrEqual(rect.height + 0.0001, 44, name + control)
                            }
                        }
                        for trip in DemoRecords.trips.filter({ $0.month == 8 && (24...27).contains($0.day) }) {
                            let row = try XCTUnwrap(visited["trip-" + trip.id], name)
                            let fields = try ["date-", "risk-", "route-", "duration-"].map {
                                try XCTUnwrap(visited[$0 + trip.id], name + $0 + trip.id)
                            }
                            for field in fields {
                                XCTAssertGreaterThanOrEqual(field.minX, row.minX - 0.5, name)
                                XCTAssertLessThanOrEqual(field.maxX, row.maxX + 0.5, name)
                                XCTAssertGreaterThanOrEqual(field.minY, row.minY - 0.5, name)
                                XCTAssertLessThanOrEqual(field.maxY, row.maxY + 0.5, name)
                            }
                            for a in fields.indices {
                                for b in fields.indices where b > a {
                                    let intersection = fields[a].intersection(fields[b])
                                    XCTAssertTrue(intersection.isNull || intersection.width < 0.5 || intersection.height < 0.5,
                                                  name + " trip fields must not overlap")
                                }
                            }
                            if type == .large { XCTAssertLessThan(row.height, 100, name + " compact rows") }
                            if type == .xxxLarge { XCTAssertLessThan(row.height, 150, name + " grouped rows") }
                        }
                    }
                    print("T15 layout \(name): viewport=\(vertical.bounds.size), scrollEnd=\(end), measured=\(visited.count)")
                }
            }
        }
        print("T15 snapshots: \(folder.path)")
    }

    @MainActor func testRecordingCalendarFilteringExpansionAndDetailReturn() async throws {
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.first as? UIWindowScene)
        let previous = scene.windows.first(where: \.isKeyWindow)
        let window = UIWindow(windowScene: scene)
        window.frame = CGRect(x: 0, y: 0, width: 390, height: 844)
        let driver = RecordsTestDriver()
        var frames: [String: CGRect] = [:]
        var detailPresented = false
        window.rootViewController = UIHostingController(rootView: RecordsPage(onLayout: { frames = $0 },
            onDetailPresentationChanged: { detailPresented = $0 })
            .environment(\.recordsTestDriver, driver).environment(\.dynamicTypeSize, .xxxLarge))
        window.makeKeyAndVisible()
        defer { window.isHidden = true; previous?.makeKeyAndVisible() }
        try await Task.sleep(for: .milliseconds(250))
        let perform = try XCTUnwrap(driver.perform)
        func rows() -> Set<String> { Set(frames.keys.filter { $0.hasPrefix("trip-") }) }
        func trips(_ month: Int, _ days: [Int]) -> Set<String> {
            Set(days.map { "trip-2026-\(String(format: "%02d", month))-\(String(format: "%02d", $0))" })
        }
        func week(_ month: Int, _ day: Int) -> Date { DemoRecords.calendar.startOfDay(for: DemoRecords.date(2026, month, day)) }
        XCTAssertEqual(driver.weekStart, week(8, 24))
        XCTAssertNotNil(frames["this-week"])
        XCTAssertEqual(rows(), trips(8, [24, 25, 26, 27]))
        perform(.toggleExpanded)
        try await Task.sleep(for: .milliseconds(120))
        XCTAssertEqual(rows(), trips(8, [24, 25, 26, 27, 28]))
        perform(.toggleExpanded)
        try await Task.sleep(for: .milliseconds(120))
        XCTAssertEqual(rows().count, 4)
        perform(.selectDay(DemoRecords.date(2026, 8, 26)))
        try await Task.sleep(for: .milliseconds(120))
        XCTAssertEqual(driver.weekStart, week(8, 24))
        XCTAssertEqual(rows(), trips(8, [24, 25, 26, 27, 28]), "A date shows its whole week, expanded")
        XCTAssertNotNil(frames["this-week"])
        XCTAssertNil(frames["clear-day"])
        let selected = try XCTUnwrap(DemoRecords.trips.first { $0.id == "2026-08-26" })
        perform(.openTrip(selected))
        try await Task.sleep(for: .milliseconds(250))
        XCTAssertTrue(detailPresented)
        perform(.closeTrip)
        try await Task.sleep(for: .milliseconds(250))
        XCTAssertFalse(detailPresented)
        XCTAssertEqual(driver.weekStart, week(8, 24))
        XCTAssertEqual(rows(), trips(8, [24, 25, 26, 27, 28]), "Returning retains the selected week")
        perform(.selectDay(DemoRecords.date(2026, 8, 2)))
        try await Task.sleep(for: .milliseconds(120))
        XCTAssertEqual(driver.weekStart, week(7, 27), "Sunday Aug 2 belongs to the week starting Monday Jul 27")
        XCTAssertEqual(rows(), trips(7, [29]))
        XCTAssertNil(frames["this-week"], "Other weeks show only their date range")
        XCTAssertNotNil(frames["week-range"])
        XCTAssertNil(frames["clear-day"])
        perform(.selectDay(DemoRecords.date(2026, 8, 23)))
        try await Task.sleep(for: .milliseconds(120))
        XCTAssertEqual(driver.weekStart, week(8, 17))
        XCTAssertEqual(rows(), trips(8, [18, 20, 21, 22]))
        perform(.shiftWeek(2))
        try await Task.sleep(for: .milliseconds(120))
        XCTAssertEqual(driver.weekStart, week(8, 31))
        XCTAssertTrue(rows().isEmpty)
        XCTAssertNotNil(frames["empty-records"])
        perform(.shiftWeek(-1))
        try await Task.sleep(for: .milliseconds(120))
        XCTAssertEqual(driver.weekStart, week(8, 24))
        XCTAssertEqual(rows().count, 4)
        XCTAssertNotNil(frames["this-week"])
        perform(.selectDay(DemoRecords.date(2026, 8, 12)))
        try await Task.sleep(for: .milliseconds(120))
        XCTAssertEqual(rows(), trips(8, [10, 12, 13, 14, 15]))
        perform(.shiftMonth(-1))
        try await Task.sleep(for: .milliseconds(120))
        XCTAssertEqual(driver.weekStart, week(8, 10), "Month controls keep the listed week")
        XCTAssertEqual(rows(), trips(8, [10, 12, 13, 14, 15]))
        XCTAssertNil(frames["clear-day"])
        perform(.shiftMonth(1))
        perform(.shiftWeek(2))
        try await Task.sleep(for: .milliseconds(120))
        XCTAssertEqual(rows().count, 4)
        perform(.showTrend(true))
        try await Task.sleep(for: .milliseconds(120))
        XCTAssertNotNil(frames["trend-card"])
        perform(.showTrend(false))
        try await Task.sleep(for: .milliseconds(120))
        XCTAssertEqual(rows().count, 4)
    }

    @MainActor func testRecordsWeeksRunMondayToSunday() async throws {
        let calendar = DemoRecords.calendar
        XCTAssertEqual(DemoRecords.weekStarts().map { calendar.component(.weekday, from: $0) }, Array(repeating: 2, count: 8))
        XCTAssertEqual(TrendAxisDate.samples.map(\.fullLabel),
                       ["Jul 6", "Jul 13", "Jul 20", "Jul 27", "Aug 3", "Aug 10", "Aug 17", "Aug 24"])
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.first as? UIWindowScene)
        let previous = scene.windows.first(where: \.isKeyWindow)
        let window = UIWindow(windowScene: scene)
        window.frame = CGRect(x: 0, y: 0, width: 402, height: 874)
        let driver = RecordsTestDriver()
        window.rootViewController = UIHostingController(rootView: RecordsPage().environment(\.recordsTestDriver, driver))
        window.makeKeyAndVisible()
        defer { window.isHidden = true; previous?.makeKeyAndVisible() }
        try await Task.sleep(for: .milliseconds(250))
        let perform = try XCTUnwrap(driver.perform)
        var starts = [try XCTUnwrap(driver.weekStart)]
        XCTAssertEqual(starts[0], calendar.startOfDay(for: DemoRecords.date(2026, 8, 24)), "Default week is Aug 24 – Aug 30")
        XCTAssertEqual(starts[0], DemoRecords.weekStarts().last)
        for amount in [-1, 2] {
            perform(.shiftWeek(amount))
            try await Task.sleep(for: .milliseconds(120))
            starts.append(try XCTUnwrap(driver.weekStart))
        }
        XCTAssertEqual(starts, [24, 17, 31].map { calendar.startOfDay(for: DemoRecords.date(2026, 8, $0)) })
        XCTAssertEqual(starts.map { calendar.component(.weekday, from: $0) }, [2, 2, 2])
    }

    @MainActor func testMetricCardsSitSideBySideWithEqualRowHeights() async throws {
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.first as? UIWindowScene)
        let previous = scene.windows.first(where: \.isKeyWindow)
        let names = ["Unusual Movement", "Navigation Assistance", "High-risk Events", "Safe Return Rate"]
        let valueLine = UIFont.systemFont(ofSize: 36, weight: .semibold).lineHeight
        let changeLine = UIFont.systemFont(ofSize: 17, weight: .medium).lineHeight
        for (size, columns) in [(CGSize(width: 390, height: 844), 2), (CGSize(width: 402, height: 874), 2),
                                (CGSize(width: 375, height: 812), 1)] {
            let name = "\(Int(size.width))x\(Int(size.height))"
            var frames: [String: CGRect] = [:]
            let window = UIWindow(windowScene: scene)
            window.frame = CGRect(origin: .zero, size: size)
            window.rootViewController = UIHostingController(rootView: RecordsPage(showTrendInitially: true, onLayout: { frames = $0 })
                .environment(\.dynamicTypeSize, .large).environment(\.colorScheme, .light))
            window.makeKeyAndVisible()
            defer { window.isHidden = true; previous?.makeKeyAndVisible() }
            try await Task.sleep(for: .milliseconds(300))
            let content = try XCTUnwrap(frames["content"], name)
            let cards = try names.map { try XCTUnwrap(frames["metric-" + $0], name + $0) }
            for (metric, card) in zip(names, cards) {
                let label = "\(name) \(metric)"
                let summary = try XCTUnwrap(frames["metric-summary-" + metric], label)
                let bars = try XCTUnwrap(frames["metric-bars-" + metric], label)
                let value = try XCTUnwrap(frames["metric-value-" + metric], label)
                let change = try XCTUnwrap(frames["metric-change-" + metric], label)
                print("Metric \(label): card=\(card) summary=\(summary) bars=\(bars) value=\(value) change=\(change)")
                XCTAssertLessThanOrEqual(summary.maxX, bars.minX + 0.5, label + " bars sit right of the numbers")
                XCTAssertTrue(bars.minY < summary.maxY && summary.minY < bars.maxY, label + " bars overlap the numbers vertically")
                for field in [summary, bars] {
                    XCTAssertGreaterThanOrEqual(field.minX, card.minX - 0.5, label)
                    XCTAssertLessThanOrEqual(field.maxX, card.maxX + 0.5, label)
                    XCTAssertGreaterThanOrEqual(field.minY, card.minY - 0.5, label)
                    XCTAssertLessThanOrEqual(field.maxY, card.maxY + 0.5, label)
                }
                XCTAssertLessThan(value.height, valueLine * 1.5, label + " value and unit stay on one line")
                XCTAssertLessThan(change.height, changeLine * 1.5, label + " arrow and change stay on one line")
            }
            if columns == 2 {
                for row in [0, 2] {
                    let (left, right) = (cards[row], cards[row + 1])
                    XCTAssertEqual(left.minY, right.minY, accuracy: 0.5, name)
                    XCTAssertEqual(left.height, right.height, accuracy: 1, name + " cards in a row share a height")
                    XCTAssertLessThanOrEqual(left.maxX, right.minX, name)
                }
                XCTAssertLessThan(cards[1].maxY, cards[2].minY, name)
            } else {
                for (upper, lower) in zip(cards, cards.dropFirst()) {
                    XCTAssertEqual(upper.minX, lower.minX, accuracy: 0.5, name)
                    XCTAssertLessThan(upper.maxY, lower.minY, name + " single column")
                }
                XCTAssertEqual(cards[0].width, content.width, accuracy: 1, name)
            }
            XCTAssertEqual(cards[0].minX, content.minX, accuracy: 0.5, name)
            XCTAssertEqual(cards.map(\.maxX).max() ?? 0, content.maxX, accuracy: 0.5, name)
        }
    }

    func testTripDetailTrailIsSolidWithWhiteEdge() throws {
        let trip = try XCTUnwrap(DemoRecords.trips.first { $0.id == "2026-08-24" })
        let lines = TripDetailPage(trip: trip, back: {}).trailLines
        XCTAssertEqual(lines.count, 2)
        XCTAssertEqual(lines.map(\.width), [9, 6])
        XCTAssertEqual(lines.map(\.color), [.white, OrbitMapStyle.blue])
        XCTAssertTrue(lines.allSatisfy { $0.dash.isEmpty }, "The trail must not be dashed")
        for line in lines {
            XCTAssertEqual(line.coordinates.map(\.latitude), DemoRecords.route.map(\.appleCoordinate.latitude))
            XCTAssertEqual(line.coordinates.map(\.longitude), DemoRecords.route.map(\.appleCoordinate.longitude))
        }
    }

    @MainActor private func recordingScrollViews(in view: UIView) -> [UIScrollView] {
        ((view as? UIScrollView).map { [$0] } ?? []) + view.subviews.flatMap { recordingScrollViews(in: $0) }
    }
    @MainActor private func snapshotRecording(_ window: UIWindow, to path: URL) throws {
        let image = UIGraphicsImageRenderer(size: window.bounds.size).image { _ in
            window.rootViewController!.view.drawHierarchy(in: window.bounds, afterScreenUpdates: true)
        }
        try XCTUnwrap(image.pngData()).write(to: path)
    }


    @MainActor func testTrendDateLabelsFitTheRenderedChartAndDoNotOverlap() async throws {
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.first as? UIWindowScene)
        let previous = scene.windows.first(where: \.isKeyWindow)
        for (width, type) in [CGFloat(184), 206, 272, 298].flatMap({ width in
            [DynamicTypeSize.large, .xxxLarge, .accessibility1, .accessibility5].map { (width, $0) }
        }) {
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
        XCTAssertEqual(labels.map(\.fullLabel), ["Jul 6", "Jul 13", "Jul 20", "Jul 27", "Aug 3", "Aug 10", "Aug 17", "Aug 24"])
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
        XCTAssertEqual(DemoRecords.weeklyDeviations(), [0, 2, 1, 2, 0, 0, 2, 2])
        let latest = try XCTUnwrap(august.filter { $0.risk == .high }.max(by: { $0.date < $1.date }))
        XCTAssertEqual(latest.day, 24)
        XCTAssertTrue(DemoRecords.answer(to: DemoRecords.quickQuestions[0]).contains("August 24, 2026"))
        XCTAssertTrue(DemoRecords.answer(to: DemoRecords.quickQuestions[1]).contains("4 route deviations"))
        XCTAssertTrue(DemoRecords.answer(to: "What is the weather?").contains("don't have a verified answer"))
        XCTAssertTrue(DemoRecords.answer(to: "8 月路线偏离几次？").contains("演示回答"))
        XCTAssertTrue(DemoRecords.answer(to: "明天天气如何？").contains("无法核对"))
        XCTAssertEqual(DemoRecords.weekStarts().map { DemoRecords.calendar.component(.weekday, from: $0) }, Array(repeating: 2, count: 8))
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

/// T26 layout lines (product design section 10): the five required screen sizes at the default
/// text size, and a window harness that reads `layoutProbe` frames in window coordinates.
enum LayoutLineHarness {
    static let sizes = [CGSize(width: 320, height: 568), CGSize(width: 375, height: 812), CGSize(width: 390, height: 844),
                        CGSize(width: 402, height: 874), CGSize(width: 430, height: 932)]
    static let margin: CGFloat = 16
    static let textLine: CGFloat = 32

    @MainActor static func render<V: View>(_ view: V, size: CGSize, waitMilliseconds: Int = 300,
                                           inspect: (UIWindow) async throws -> Void) async throws {
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.first as? UIWindowScene)
        let previous = scene.windows.first(where: \.isKeyWindow)
        LayoutProbe.frames = [:]
        let window = UIWindow(windowScene: scene)
        window.frame = CGRect(origin: .zero, size: size)
        window.rootViewController = UIHostingController(rootView: view
            .environment(\.dynamicTypeSize, .large).environment(\.colorScheme, .light))
        window.makeKeyAndVisible()
        defer { window.isHidden = true; previous?.makeKeyAndVisible() }
        window.rootViewController?.view.frame = window.bounds
        window.rootViewController?.view.layoutIfNeeded()
        try await Task.sleep(for: .milliseconds(waitMilliseconds))
        try await inspect(window)
    }
    @MainActor static func probe(_ name: String, _ context: String,
                                 file: StaticString = #filePath, line: UInt = #line) throws -> CGRect {
        try XCTUnwrap(LayoutProbe.frames[name], "\(context): no frame for \(name)", file: file, line: line)
    }
    /// Outer edges on the page margin lines of a container `width` wide that starts at x = 0.
    static func assertOuterEdges(_ rect: CGRect, width: CGFloat, _ message: String,
                                 file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertEqual(rect.minX, margin, accuracy: 0.5, message + " leading edge", file: file, line: line)
        XCTAssertEqual(rect.maxX, width - margin, accuracy: 0.5, message + " trailing edge", file: file, line: line)
    }
    static func assertHitArea(_ rect: CGRect, _ message: String, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertGreaterThanOrEqual(rect.width + 0.0001, 44, message + " hit width", file: file, line: line)
        XCTAssertGreaterThanOrEqual(rect.height + 0.0001, 44, message + " hit height", file: file, line: line)
    }
}

extension RecordsTests {
    @MainActor func testRecordsMarginsAndTextLinesAtRequiredSizes() async throws {
        let h = LayoutLineHarness.self
        let metrics = ["Unusual Movement", "Navigation Assistance", "High-risk Events", "Safe Return Rate"]
        for size in h.sizes {
            for trend in [false, true] {
                let name = "\(trend ? "trend" : "data") \(Int(size.width))x\(Int(size.height))"
                var frames: [String: CGRect] = [:]
                try await h.render(RecordsPage(showTrendInitially: trend, onLayout: { frames = $0 }), size: size) { _ in
                    func rect(_ key: String) throws -> CGRect { try XCTUnwrap(frames[key], name + " " + key) }
                    h.assertOuterEdges(try rect("picker"), width: size.width, name + " picker")
                    h.assertOuterEdges(try rect("content"), width: size.width, name + " content")
                    if trend {
                        h.assertOuterEdges(try rect("trend-card"), width: size.width, name + " trend card")
                        XCTAssertEqual(try rect("trend-title").minX, h.textLine, accuracy: 0.5, name + " trend title")
                        let cards = try metrics.map { try rect("metric-" + $0) }
                        XCTAssertEqual(cards.map(\.minX).min() ?? 0, h.margin, accuracy: 0.5, name)
                        XCTAssertEqual(cards.map(\.maxX).max() ?? 0, size.width - h.margin, accuracy: 0.5, name)
                        for (metric, card) in zip(metrics, cards) {
                            for key in ["metric-icon-", "metric-value-"] {
                                XCTAssertEqual(try rect(key + metric).minX - card.minX, 12,
                                               accuracy: 0.5, name + " " + key + metric)
                            }
                            if abs(card.minX - h.margin) < 0.5 {
                                XCTAssertEqual(try rect("metric-icon-" + metric).minX, 28, accuracy: 0.5, name + " " + metric)
                            }
                        }
                    } else {
                        h.assertOuterEdges(try rect("calendar"), width: size.width, name + " calendar")
                        XCTAssertEqual(try rect("previous-month-glyph").minX, h.textLine, accuracy: 1, name)
                        XCTAssertEqual(try rect("next-month-glyph").maxX, size.width - h.textLine, accuracy: 1, name)
                        XCTAssertEqual(try rect("previous-week-glyph").minX, h.margin, accuracy: 1, name)
                        XCTAssertEqual(try rect("next-week-glyph").maxX, size.width - h.margin, accuracy: 1, name)
                        for control in ["previous-week", "next-week"] { h.assertHitArea(try rect(control), name + " " + control) }
                        for control in ["previous-month", "next-month"] {
                            XCTAssertGreaterThanOrEqual(try rect(control).width + 0.0001, 44, name + " " + control)
                        }
                        for trip in DemoRecords.trips.filter({ $0.month == 8 && (24...27).contains($0.day) }) {
                            h.assertOuterEdges(try rect("trip-" + trip.id), width: size.width, name + " row " + trip.id)
                            XCTAssertEqual(try rect("date-" + trip.id).minX, h.textLine, accuracy: 0.5, name + " row text " + trip.id)
                        }
                    }
                    print("T26 records \(name): picker=\(frames["picker"] ?? .null) content=\(frames["content"] ?? .null)")
                }
            }
        }
    }

    @MainActor func testTripDetailMarginsAtRequiredSizes() async throws {
        let h = LayoutLineHarness.self
        let trip = try XCTUnwrap(DemoRecords.trips.first { $0.month == 8 && $0.day == 24 })
        for size in h.sizes {
            let name = "trip detail \(Int(size.width))x\(Int(size.height))"
            try await h.render(TripDetailPage(trip: trip, back: {}), size: size, waitMilliseconds: 600) { _ in
                XCTAssertEqual(try h.probe("trip-back-glyph", name).minX, h.margin, accuracy: 1, name + " back glyph")
                h.assertHitArea(try h.probe("trip-back", name), name + " back")
                let pills = try h.probe("trip-pills", name)
                XCTAssertEqual(pills.minX, h.margin, accuracy: 0.5, name + " pills")
                XCTAssertLessThanOrEqual(pills.maxX, size.width - h.margin + 0.5, name + " pills")
                h.assertOuterEdges(try h.probe("trip-timeline", name), width: size.width, name + " timeline")
            }
        }
    }
}

extension AgentSessionTests {
    @MainActor func testConversationListAndChatLinesAtRequiredSizes() async throws {
        let h = LayoutLineHarness.self
        func defaults() -> UserDefaults { UserDefaults(suiteName: "safeorbit.test.lines.\(UUID().uuidString)")! }
        let settings = CaregiverSettingsStore(defaults: defaults())
        for size in h.sizes {
            let label = "\(Int(size.width))x\(Int(size.height))"
            let sessions = AgentSessionStore(defaults: defaults())
            for question in DemoRecords.quickQuestions.prefix(2) {
                let id = try XCTUnwrap(sessions.newConversation())
                sessions.send(question, in: id, allowTripHistory: true)
            }
            sessions.showList()
            let page = AgentSessionPage(sessions: sessions, settings: settings, keyboardVisible: false)
            try await h.render(page, size: size) { _ in
                let name = "agent list " + label
                XCTAssertEqual(try h.probe("agent-recent-title", name).minX, h.margin, accuracy: 0.5, name + " title")
                for session in sessions.sessions {
                    XCTAssertEqual(try h.probe("agent-row-\(session.id)", name).minX, h.margin, accuracy: 0.5, name + " row")
                }
                XCTAssertEqual(try h.probe("agent-new-glyph", name).maxX, size.width - h.margin, accuracy: 1, name + " new glyph")
                h.assertHitArea(try h.probe("agent-new", name), name + " new conversation")
            }
            let conversation = try XCTUnwrap(sessions.recent.first)
            sessions.open(conversation.id)
            try await h.render(page, size: size) { _ in
                let name = "agent chat " + label
                XCTAssertEqual(try h.probe("chat-back-glyph", name).minX, h.margin, accuracy: 1, name + " back glyph")
                h.assertHitArea(try h.probe("chat-back", name), name + " back")
                for message in conversation.messages {
                    let bubble = try h.probe("chat-bubble-\(message.id)", name)
                    if message.fromCaregiver {
                        XCTAssertEqual(bubble.maxX, size.width - h.margin, accuracy: 0.5, name + " caregiver bubble")
                    } else {
                        XCTAssertEqual(bubble.minX, h.margin, accuracy: 0.5, name + " agent bubble")
                    }
                }
                h.assertOuterEdges(try h.probe("chat-composer", name), width: size.width, name + " composer")
            }
            let damaged = defaults()
            damaged.set(Data("corrupt".utf8), forKey: AgentSessionStore.storageKey)
            try await h.render(AgentSessionPage(sessions: AgentSessionStore(defaults: damaged), settings: settings,
                                                keyboardVisible: false), size: size) { _ in
                let name = "agent load error " + label
                XCTAssertEqual(try h.probe("agent-load-error", name).minX, h.margin, accuracy: 0.5, name)
                XCTAssertEqual(try h.probe("agent-recent-title", name).minX, h.margin, accuracy: 0.5, name)
            }
        }
    }
}

extension ElderFrontendTests {
    @MainActor func testElderPagesUsePageMarginsAtRequiredSizes() async throws {
        let h = LayoutLineHarness.self
        for size in h.sizes {
            for state in ["home", "navigation", "call", "settings", "volume"] {
                let name = "elder \(state) \(Int(size.width))x\(Int(size.height))"
                let session = ElderDemoSession(voice: ElderVoiceSpy())
                if state == "navigation" { session.startNavigation(locale: Locale(identifier: "en")) }
                if state == "call" { session.showCall() }
                if state == "settings" { session.showingSettings = true }
                var frames: [String: CGRect] = [:]
                let page = NavigationStack {
                    ElderHomePage(session: session, chooseRole: {}, onLayout: { frames = $0 },
                                  volumeInitiallyOpen: state == "volume")
                }.environment(\.locale, Locale(identifier: "en"))
                try await h.render(page, size: size, waitMilliseconds: 800) { _ in
                    func rect(_ key: String) throws -> CGRect { try XCTUnwrap(frames[key], name + " " + key) }
                    switch state {
                    case "home":
                        XCTAssertEqual(try rect("settings-portrait").minX, h.margin, accuracy: 0.5, name)
                        let go = try rect("go-home"), call = try rect("call-family")
                        XCTAssertEqual(go.minX, h.margin, accuracy: 0.5, name + " go home")
                        XCTAssertEqual(call.maxX, size.width - h.margin, accuracy: 0.5, name + " call family")
                        if go.maxY <= call.minY + 0.5 {
                            h.assertOuterEdges(go, width: size.width, name + " stacked go home")
                            h.assertOuterEdges(call, width: size.width, name + " stacked call family")
                        } else {
                            XCTAssertLessThanOrEqual(go.maxX, call.minX + 0.5, name + " buttons side by side")
                        }
                    case "navigation":
                        h.assertOuterEdges(try rect("guidance-card"), width: size.width, name + " guidance card")
                        XCTAssertEqual(try rect("cancel-navigation").minX, h.margin, accuracy: 0.5, name)
                        XCTAssertEqual(try rect("call-family").maxX, size.width - h.margin, accuracy: 0.5, name)
                    case "call":
                        h.assertOuterEdges(try rect("call-card"), width: size.width, name + " call card")
                        XCTAssertEqual(try rect("dismiss-call").maxX, size.width - h.margin, accuracy: 0.5, name)
                        XCTAssertEqual(try rect("settings-portrait").minX, h.margin, accuracy: 0.5, name)
                    case "settings":
                        let panel = size.width * 0.88
                        h.assertOuterEdges(try h.probe("drawer-header", name), width: panel, name + " drawer header")
                        h.assertOuterEdges(try h.probe("drawer-row-Voice volume", name), width: panel, name + " drawer row")
                        h.assertOuterEdges(try h.probe("drawer-logout", name), width: panel, name + " drawer log out")
                    default:
                        XCTAssertEqual(try h.probe("settings-back-glyph", name).minX, h.margin, accuracy: 1, name + " back glyph")
                        h.assertHitArea(try h.probe("settings-back", name), name + " back")
                        h.assertOuterEdges(try h.probe("elder-volume-card", name), width: size.width, name + " volume card")
                        XCTAssertEqual(try h.probe("elder-volume-content", name).minX, h.textLine, accuracy: 0.5, name)
                    }
                }
            }
        }
    }
}
