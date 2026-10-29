import SwiftUI
import MapKit
import Charts

private enum RecordsSection: String, CaseIterable {
    case trend = "Trend", data = "Data"
}

struct RecordsPage: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @ScaledMetric(relativeTo: .body) private var titleHeight: CGFloat = 24
    @ScaledMetric(relativeTo: .body) private var calendarColumnWidth: CGFloat = 34
    @ScaledMetric(relativeTo: .body) private var metricIconSize: CGFloat = 28
    @ScaledMetric(relativeTo: .body) private var metricBarWidth: CGFloat = 28
    let onLayout: (([String: CGRect]) -> Void)?
#if DEBUG
    @Environment(\.recordsTestDriver) private var testDriver
#endif
    @State private var section: RecordsSection = .data
    @StateObject private var store: RecordsStore
    @Environment(\.scenePhase) private var scenePhase
    let isActive: Bool
    @State private var expanded = false
    @State private var selectedTrip: RecordTrip?
    let onDetailPresentationChanged: (Bool) -> Void

    init(device: DemoDevice?, isActive: Bool = true, showTrendInitially: Bool = false,
         onLayout: (([String: CGRect]) -> Void)? = nil, onDetailPresentationChanged: @escaping (Bool) -> Void = { _ in }) {
        self.onLayout = onLayout
        self.onDetailPresentationChanged = onDetailPresentationChanged
        self.isActive = isActive
        _section = State(initialValue: showTrendInitially ? .trend : .data)
        _store = StateObject(wrappedValue: RecordsStore(service: device.map { RecordsAPI(device: $0) },
            timezone: device?.household?.elder.timezone ?? "UTC"))
    }
#if DEBUG
    init(showTrendInitially: Bool = false, onLayout: (([String: CGRect]) -> Void)? = nil,
         onDetailPresentationChanged: @escaping (Bool) -> Void = { _ in }) {
        self.onLayout = onLayout; self.onDetailPresentationChanged = onDetailPresentationChanged
        isActive = true
        _section = State(initialValue: showTrendInitially ? .trend : .data)
        _store = StateObject(wrappedValue: .preview())
    }
#endif
    private var calendar: Calendar { store.calendar }
    private var month: Date { store.month }
    private var weekStart: Date { store.weekStart }
    private var weekTrips: [RecordTrip] { store.records?.trips ?? [] }

    var body: some View {
        VStack(spacing: 0) {
            CaregiverTopBar(height: max(47, titleHeight + 16)) {
                Text("Recording")
                    .orbitDisplayFont(20)
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .recordsFrame("title")
                    .padding(.horizontal, OrbitLayout.pageMargin)
            }
            VStack(spacing: 0) {
                sectionPicker.recordsFrame("picker").layoutProbe("records-picker")
                    .padding(.horizontal, OrbitLayout.pageMargin)
                    .padding(.top, 12)
                    .padding(.bottom, 23)
                ScrollView {
                    VStack(spacing: 0) {
                        if section == .data { dataContent }
                        else { trendContent }
                    }
                    .recordsFrame("content").layoutProbe("records-content")
                    .padding(.horizontal, OrbitLayout.pageMargin)
                    .padding(.bottom, 112)
                }
                .refreshable { await store.reload() }
            }
            .background(.white, in: UnevenRoundedRectangle(topLeadingRadius: 28, topTrailingRadius: 28))
            .background(alignment: .top) { OrbitStyle.teal.frame(height: 40) }
        }
        .background(Color.white.ignoresSafeArea(edges: .bottom))
        .coordinateSpace(name: "RecordsPage")
        .onPreferenceChange(RecordsFrames.self) { onLayout?($0) }
        .task(id: store.queryKey + ":\(isActive):\(scenePhase == .active)") {
            guard isActive, scenePhase == .active else { return }
#if DEBUG
            if store.isPreview { return }
#endif
            while !Task.isCancelled {
                await store.reload()
                do { try await Task.sleep(for: .seconds(3)) } catch { return }
            }
        }
#if DEBUG
        .onChange(of: weekStart) { _, start in testDriver?.weekStart = start }
        .onAppear {
            testDriver?.weekStart = weekStart
            testDriver?.perform = { action in
                switch action {
                case .selectDay(let date): selectDay(date)
                case .shiftMonth(let amount): shiftMonth(amount)
                case .shiftWeek(let amount): shiftWeek(amount)
                case .toggleExpanded: expanded.toggle()
                case .openTrip(let trip): selectedTrip = RecordTrip(preview: trip)
                case .closeTrip: selectedTrip = nil
                case .showTrend(let show): section = show ? .trend : .data
                }
            }
        }
#endif
        .settingsSlide(item: $selectedTrip) { trip in
#if DEBUG
            if store.isPreview, let sample = DemoRecords.trips.first(where: { $0.id == trip.id }) {
                TripDetailPage(trip: sample) { selectedTrip = nil }
            } else {
                TripDetailPage(trip: trip, timezone: store.timezone, service: store.service) { selectedTrip = nil }
            }
#else
            TripDetailPage(trip: trip, timezone: store.timezone, service: store.service) { selectedTrip = nil }
#endif
        }
        .onChange(of: selectedTrip?.id) { _, id in onDetailPresentationChanged(id != nil) }
        .onDisappear { onDetailPresentationChanged(false) }
    }

    private var sectionPicker: some View {
        HStack(spacing: 4) {
            ForEach(RecordsSection.allCases, id: \.self) { item in
                Button { section = item } label: {
                    Text(item.rawValue)
                        .caregiverText()
                        .frame(maxWidth: .infinity).frame(minHeight: 30).padding(.vertical, 3)
                        .foregroundStyle(section == item ? .black : .white)
                        .background(section == item ? .white : .clear, in: Capsule())
                }.accessibilityAddTraits(section == item ? .isSelected : [])
            }
        }
        .padding(4).background(OrbitStyle.teal, in: Capsule())
    }

    private var dataContent: some View {
        VStack(spacing: 22) {
            calendarCard
            HStack(spacing: 4) {
                weekButton(-1)
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 8) { weekTitle; weekRange.fixedSize() }
                    VStack(alignment: .leading, spacing: 4) { weekTitle; weekRange }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                weekButton(1)
            }
            .buttonStyle(.plain)
            weekCard
        }
    }

    // Other weeks are named by their date range alone.
    @ViewBuilder private var weekTitle: some View {
        if weekStart == store.currentWeekStart {
            Text("This Week")
                .recordingFont(18, weight: .medium).fixedSize(horizontal: false, vertical: true)
                .recordsFrame("this-week")
        }
    }
    private var weekRange: some View {
        Text("\(shortDate(weekStart)) – \(shortDate(calendar.date(byAdding: .day, value: 6, to: weekStart)!))")
            .caregiverText(.secondary).foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true).recordsFrame("week-range")
    }
    // The chevrons' visible edges sit on the content edges; the hit areas extend inward.
    private func weekButton(_ amount: Int) -> some View {
        Button { shiftWeek(amount) } label: {
            Image(systemName: amount < 0 ? "chevron.left" : "chevron.right")
                .recordsFrame(amount < 0 ? "previous-week-glyph" : "next-week-glyph")
                .iconHitArea(amount < 0 ? .leading : .trailing)
        }
        .accessibilityLabel(amount < 0 ? "Previous week" : "Next week")
        .recordsFrame(amount < 0 ? "previous-week" : "next-week")
    }
    private var calendarCard: some View {
        VStack(spacing: 9) {
            HStack(spacing: 4) {
                monthButton(-1)
                Text(monthTitle(month)).recordingFont(19, weight: .medium)
                    .fixedSize(horizontal: false, vertical: true).multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity).recordsFrame("month-title")
                monthButton(1)
            }.buttonStyle(.plain)
            // Keep seven aligned columns and full weekday names at every text size.
            // When their natural widths no longer fit, the entire calendar scrolls.
            RecordsHorizontalViewport(minimumWidth: calendarColumnWidth * 7 + 12) {
                VStack(spacing: 9) {
                    HStack(spacing: 2) {
                        ForEach(["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"], id: \.self) { label in
                            Text(label).caregiverText(.secondary).foregroundStyle(.secondary)
                                .fixedSize().frame(maxWidth: .infinity)
                        }
                    }
                    let days = monthCells
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 2), count: 7), spacing: 3) {
                        ForEach(days.indices, id: \.self) { index in
                            if let day = days[index] {
                                let date = calendar.date(bySetting: .day, value: day, of: month)!
                                let key = RecordDates.format(date, "yyyy-MM-dd", timezone: store.timezone)
                                let risk = store.records?.days.first { $0.date == key }?.risk
                                Button { selectDay(date) } label: {
                                    Text("\(day)").caregiverText().fixedSize()
                                        .foregroundStyle(risk == .high ? .white : .black)
                                        .frame(maxWidth: .infinity).frame(minHeight: dynamicTypeSize.isAccessibilitySize ? 44 : 30)
                                        .background(riskColor(risk), in: Circle())

                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel("\(dayTitle(date)), \(risk?.title ?? "No trips")")
                            } else { Color.clear.frame(height: dynamicTypeSize.isAccessibilitySize ? 44 : 30) }
                        }
                    }
                }
            }
            .accessibilityIdentifier("records-calendar")
        }
        .padding(.horizontal, OrbitLayout.cardPadding)
        .padding(.vertical, dynamicTypeSize.isAccessibilitySize ? 8 : 14)
        .caregiverCard().recordsFrame("calendar")
    }
    // Inside the card the chevrons sit on the card's text lines. Natural row height (T16).
    private func monthButton(_ amount: Int) -> some View {
        Button { shiftMonth(amount) } label: {
            Image(systemName: amount < 0 ? "chevron.left" : "chevron.right")
                .recordsFrame(amount < 0 ? "previous-month-glyph" : "next-month-glyph")
                .iconHitArea(amount < 0 ? .leading : .trailing, minHeight: nil)
        }
        .accessibilityLabel(amount < 0 ? "Previous month" : "Next month")
        .recordsFrame(amount < 0 ? "previous-month" : "next-month")
    }
    // A date opens its whole Monday–Sunday week, already expanded.
    private func selectDay(_ date: Date) {
        store.selectDay(date)
        expanded = true
    }

    private var monthCells: [Int?] {
        let first = calendar.date(from: DateComponents(year: calendar.component(.year, from: month),
                                                       month: calendar.component(.month, from: month), day: 1))!
        let offset = calendar.component(.weekday, from: first) - 1
        let count = calendar.range(of: .day, in: .month, for: first)!.count
        return Array(repeating: nil, count: offset) + (1...count).map { Optional($0) }
    }

    private var weekCard: some View {
        VStack(spacing: 0) {
            if let error = store.recordsError {
                recordsMessage(error)
            } else if store.records == nil {
                ProgressView("Loading records…").caregiverText().padding(22)
            } else if weekTrips.isEmpty {
                Text("No trips in this period").caregiverText().foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true).recordsFrame("empty-records")
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, OrbitLayout.cardPadding).padding(.vertical, 22)
            } else {
                ForEach(Array(weekTrips.prefix(expanded ? weekTrips.count : 4).enumerated()), id: \.element.id) { index, trip in
                    Button { selectedTrip = trip } label: {
                        ViewThatFits(in: .horizontal) {
                            HStack(spacing: 8) {
                                tripDate(trip)
                                tripRisk(trip)
                                tripRoute(trip).frame(minWidth: 70, maxWidth: .infinity, alignment: .leading)
                                tripDuration(trip)
                            }
                            VStack(alignment: .leading, spacing: 8) {
                                RecordsFlowLayout(spacing: 10) {
                                    tripDate(trip)
                                    tripRisk(trip)
                                    tripDuration(trip)
                                }
                                tripRoute(trip).frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }
                        .padding(.horizontal, OrbitLayout.cardPadding).padding(.vertical, 8).frame(minHeight: 50)
                        .recordsFrame("trip-\(trip.id)")
                    }.buttonStyle(.plain)
                    if index < min(weekTrips.count, expanded ? weekTrips.count : 4) - 1 {
                        Divider().padding(.horizontal, OrbitLayout.cardPadding)
                    }
                }
                if weekTrips.count > 4 {
                    Button { expanded.toggle() } label: {
                        Label(expanded ? "View Less" : "View More", systemImage: expanded ? "chevron.up" : "chevron.down")
                            .caregiverText().foregroundStyle(.black)
                            .frame(maxWidth: .infinity).frame(minHeight: 44).padding(.vertical, 4)
                            .recordsFrame("expand-week")
                    }
                }
            }
        }
        .caregiverCard()
    }

    private func tripDate(_ trip: RecordTrip) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(shortDate(trip.date)).caregiverText().foregroundStyle(.black)
            Text(weekday(trip.date)).caregiverText(.caption).foregroundStyle(.secondary)
        }.fixedSize().recordsFrame("date-\(trip.id)")
    }
    private func tripRisk(_ trip: RecordTrip) -> some View {
        Text(trip.risk.title)
            .caregiverText(.caption).fixedSize()
            .padding(.horizontal, 8).padding(.vertical, 4)
            .foregroundStyle(trip.risk == .high ? .white : .black)
            .background(riskColor(trip.risk), in: Capsule())
            .recordsFrame("risk-\(trip.id)")
    }
    private func tripRoute(_ trip: RecordTrip) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(trip.name).caregiverText(.caption).foregroundStyle(.black)
            if !trip.anomalies.isEmpty {
                Text(trip.anomalyLabels).caregiverText(.caption).foregroundStyle(.secondary)
            }
        }.fixedSize(horizontal: false, vertical: true).recordsFrame("route-\(trip.id)")
    }
    private func tripDuration(_ trip: RecordTrip) -> some View {
        HStack(spacing: 8) {
            Text("\(trip.durationMinutes) min").caregiverText(.caption)
            Image(systemName: "chevron.right").recordingFont(13, weight: .semibold)
        }.foregroundStyle(.black).fixedSize().recordsFrame("duration-\(trip.id)")
    }

    private var trendContent: some View {
        VStack(spacing: 16) {
            if let error = store.trendsError {
                recordsMessage(error).caregiverCard()
            } else if store.trends != nil {
                trendCard
                metricGrid
                Text(store.trends?.pattern ?? "").caregiverText()
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(OrbitLayout.cardPadding).caregiverCard()
            } else {
                ProgressView("Loading trends…").caregiverText().padding(22)
            }
        }
    }

    private var trendCard: some View {
        let current = store.trends?.deviations.current ?? 0
        let previous = store.trends?.deviations.previous ?? 0
        return VStack(alignment: .leading, spacing: 18) {
            Text("Route Deviation Trend").orbitDisplayFont(20, weight: .semibold)
                .fixedSize(horizontal: false, vertical: true).recordsFrame("trend-title")
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .bottom, spacing: 8) {
                    trendSummary(current, previous: previous).fixedSize(horizontal: true, vertical: false)
                    TrendDeviationChart(weeks: store.trends?.weeks ?? [], timezone: store.timezone).frame(minWidth: 206).recordsFrame("trend-chart-viewport")
                }
                VStack(alignment: .leading, spacing: 16) {
                    trendSummary(current, previous: previous)
                    TrendDeviationChart(weeks: store.trends?.weeks ?? [], timezone: store.timezone).recordsFrame("trend-chart-viewport")
                }
            }
        }
        .padding(.horizontal, OrbitLayout.cardPadding).padding(.vertical, 24)
        .caregiverCard().recordsFrame("trend-card")
    }

    private func trendSummary(_ current: Int, previous: Int) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("\(current)").orbitDisplayFont(47, weight: .bold)
            Text("events").caregiverText(.secondary).foregroundStyle(.secondary)
            Text(percentChange(current, previous)).orbitDisplayFont(20).padding(.top, 16)
            Text("vs last month").caregiverText(.caption).foregroundStyle(.secondary)
        }
        .fixedSize(horizontal: false, vertical: true).recordsFrame("trend-summary")
    }

    private var metricGrid: some View {
        let values = store.trends?.metrics
        let metrics: [(String, String, Int, Int, String)] = [
            ("Unusual Movement", "exclamationmark.circle.fill", values?.unusualMovement.current ?? 0,
             values?.unusualMovement.previous ?? 0, "events"),
            ("Navigation Assistance", "point.topleft.down.curvedto.point.bottomright.up", values?.navigationAssistance.current ?? 0,
             values?.navigationAssistance.previous ?? 0, "events"),
            ("High-risk Events", "exclamationmark.triangle.fill", values?.highRisk.current ?? 0,
             values?.highRisk.previous ?? 0, "events"),
            ("Safe Return Rate", "shield.lefthalf.filled", values?.safeReturnRate.current ?? 0,
             values?.safeReturnRate.previous ?? 0, "%")
        ]
        let columns = dynamicTypeSize > .large ? [GridItem(.flexible())]
            : [GridItem(.adaptive(minimum: 170), spacing: 18, alignment: .top)]
        return LazyVGrid(columns: columns, spacing: 16) {
            ForEach(metrics, id: \.0) { metric in
                metricCard(metric)
            }
        }
    }

    private func metricCard(_ metric: (String, String, Int, Int, String)) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .center, spacing: 8) {
                Image(systemName: metric.1).orbitDisplayFont(16)
                    .frame(width: metricIconSize, height: metricIconSize).background(OrbitStyle.pale, in: Circle())
                    .recordsFrame("metric-icon-\(metric.0)")
                Text(metric.0).caregiverText(.caption).fixedSize(horizontal: false, vertical: true)
                    .recordsFrame("metric-title-\(metric.0)")
            }.frame(minHeight: 28, alignment: .leading)
            // Restore the original width allocation; one card must not choose a taller layout.
            (dynamicTypeSize > .large
                ? AnyLayout(VStackLayout(alignment: .leading, spacing: 8))
                : AnyLayout(HStackLayout(alignment: .bottom, spacing: 4))) {
                metricSummary(metric).layoutPriority(1)
                if dynamicTypeSize <= .large { Spacer(minLength: 0) }
                metricBars(metric)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 136,
               maxHeight: dynamicTypeSize <= .large ? 136 : nil, alignment: .leading)
        .padding(OrbitLayout.compactCardPadding)
        .caregiverCard(radius: 24, opacity: 0.13).recordsFrame("metric-\(metric.0)")
    }
    private func metricSummary(_ metric: (String, String, Int, Int, String)) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("\(metric.2)\(metric.4 == "%" ? "%" : "")").orbitDisplayFont(36, weight: .semibold)
                .lineLimit(1).fixedSize()
                .recordsFrame("metric-value-\(metric.0)")
            if metric.4 != "%" { Text(metric.4).caregiverText(.secondary).foregroundStyle(.secondary) }
            Text(metric.4 == "%" ? percentagePointChange(metric.2, metric.3) : percentChange(metric.2, metric.3))
                .orbitDisplayFont(17)
                .lineLimit(1).fixedSize()
                .recordsFrame("metric-change-\(metric.0)")
            Text("vs. last month").caregiverText(.caption).foregroundStyle(.secondary)
        }.fixedSize(horizontal: false, vertical: true).recordsFrame("metric-summary-\(metric.0)")
    }
    private func metricBars(_ metric: (String, String, Int, Int, String)) -> some View {
        HStack(alignment: .bottom, spacing: 4) {
            bar(metric.3, maxValue: max(metric.2, metric.3), percent: metric.4 == "%", lighter: true)
            bar(metric.2, maxValue: max(metric.2, metric.3), percent: metric.4 == "%", lighter: false)
        }.recordsFrame("metric-bars-\(metric.0)")
    }
    private func bar(_ value: Int, maxValue: Int, percent: Bool, lighter: Bool) -> some View {
        VStack(spacing: 3) {
            Text("\(value)\(percent ? "%" : "")").caregiverText(.caption).fixedSize()
                .foregroundStyle(OrbitStyle.teal)
            RoundedRectangle(cornerRadius: 4)
                .fill(lighter ? OrbitStyle.pale : OrbitStyle.teal.opacity(0.65))
                .frame(width: 22, height: CGFloat(max(8, value * 52 / max(1, maxValue))))
            Text(lighter ? "Last\nmonth" : "This\nmonth")
                .caregiverText(.caption).foregroundStyle(.secondary).multilineTextAlignment(.center).fixedSize()
        }.frame(minWidth: metricBarWidth)
    }

    private func recordsMessage(_ message: String) -> some View {
        VStack(spacing: 12) {
            Text(message).caregiverText().fixedSize(horizontal: false, vertical: true)
            Button("Try Again") { Task { await store.reload() } }
                .caregiverText().frame(minHeight: 44)
        }.frame(maxWidth: .infinity).padding(OrbitLayout.cardPadding)
    }

    private func shiftMonth(_ amount: Int) {
        store.shiftMonth(amount)
    }
    private func shiftWeek(_ amount: Int) {
        store.shiftWeek(amount)
        expanded = false
    }
    private func monthTitle(_ date: Date) -> String {
        let formatter = DateFormatter(); formatter.locale = Locale(identifier: "en_US")
        formatter.timeZone = calendar.timeZone; formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: date)
    }
    private func shortDate(_ date: Date) -> String {
        let formatter = DateFormatter(); formatter.locale = Locale(identifier: "en_US")
        formatter.timeZone = calendar.timeZone; formatter.dateFormat = "MMM d"
        return formatter.string(from: date)
    }
    private func dayTitle(_ date: Date) -> String { shortDate(date) }
    private func weekday(_ date: Date) -> String {
        let formatter = DateFormatter(); formatter.locale = Locale(identifier: "en_US")
        formatter.timeZone = calendar.timeZone; formatter.dateFormat = "EEE"
        return formatter.string(from: date)
    }
    private func riskColor(_ risk: TripRisk?) -> Color {
        switch risk {
        case .normal: Color(red: 0.83, green: 0.91, blue: 0.78)
        case .warning: Color(red: 0.89, green: 0.68, blue: 0.44)
        case .high: Color(red: 0.92, green: 0.29, blue: 0.30)
        case nil: .clear
        }
    }
    private func percentChange(_ current: Int, _ previous: Int) -> String {
        guard previous > 0 else { return current > 0 ? "New" : "—" }
        let delta = Int((100.0 * Double(current - previous) / Double(previous)).rounded())
        return "\(delta >= 0 ? "▲ +" : "▼ ")\(delta)%"
    }
    private func percentagePointChange(_ current: Int, _ previous: Int) -> String {
        let delta = current - previous
        return "\(delta >= 0 ? "▲ +" : "▼ ")\(delta) pts"
    }
}

// Measure the proposed width rather than using a device-size breakpoint.
private struct RecordsHorizontalViewport<Content: View>: View {
    let minimumWidth: CGFloat
    @ViewBuilder let content: () -> Content
    @State private var availableWidth: CGFloat = 0
    var body: some View {
        ScrollView(.horizontal) {
            content().frame(width: max(availableWidth, minimumWidth))
        }
        .fixedSize(horizontal: false, vertical: true)
        .background {
            GeometryReader { geometry in
                Color.clear.onAppear { availableWidth = geometry.size.width }
                    .onChange(of: geometry.size.width) { _, width in availableWidth = width }
            }
        }
    }
}

// Only metadata groups wrap; a duration and its disclosure arrow stay together.
private struct RecordsFlowLayout: Layout {
    let spacing: CGFloat
    private func arrangement(_ subviews: Subviews, width: CGFloat) -> (CGSize, [CGPoint]) {
        var x: CGFloat = 0, y: CGFloat = 0, rowHeight: CGFloat = 0
        var positions: [CGPoint] = []
        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if x > 0 && x + size.width > width {
                x = 0; y += rowHeight + spacing; rowHeight = 0
            }
            positions.append(CGPoint(x: x, y: y))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
        return (CGSize(width: width, height: y + rowHeight), positions)
    }
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let ideal = subviews.reduce(CGFloat(0)) { $0 + $1.sizeThatFits(.unspecified).width + spacing }
        return arrangement(subviews, width: proposal.width ?? max(0, ideal - spacing)).0
    }
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let positions = arrangement(subviews, width: bounds.width).1
        for (view, position) in zip(subviews, positions) {
            view.place(at: CGPoint(x: bounds.minX + position.x, y: bounds.minY + position.y),
                       anchor: .topLeading, proposal: .unspecified)
        }
    }
}

private struct RecordsFrames: PreferenceKey {
    static var defaultValue: [String: CGRect] = [:]
    static func reduce(value: inout [String: CGRect], nextValue: () -> [String: CGRect]) {
        value.merge(nextValue(), uniquingKeysWith: { _, new in new })
    }
}
private extension View {
    func recordsFrame(_ name: String) -> some View {
        background {
            GeometryReader { geometry in
                Color.clear.preference(key: RecordsFrames.self,
                    value: [name: geometry.frame(in: .named("RecordsPage"))])
            }
        }
    }
}

#if DEBUG
// Internal render-test entry: exercises the same state changes as the controls.
// This does not substitute for a physical touch or a device acceptance test.
enum RecordsTestAction {
    case selectDay(Date), shiftMonth(Int), shiftWeek(Int), toggleExpanded
    case openTrip(DemoTrip), closeTrip, showTrend(Bool)
}
final class RecordsTestDriver {
    var perform: ((RecordsTestAction) -> Void)?
    fileprivate(set) var weekStart: Date?
}
private struct RecordsTestDriverKey: EnvironmentKey {
    static let defaultValue: RecordsTestDriver? = nil
}
extension EnvironmentValues {
    var recordsTestDriver: RecordsTestDriver? {
        get { self[RecordsTestDriverKey.self] }
        set { self[RecordsTestDriverKey.self] = newValue }
    }
}
#endif

struct TripDetailPage: View {
    let initialTrip: RecordTrip
    let timezone: String
    let back: () -> Void
    @StateObject private var store: RecordDetailStore
    @State private var mapCamera: MapCameraPosition = .automatic
    init(trip: RecordTrip, timezone: String, service: (any RecordsServing)?, back: @escaping () -> Void) {
        initialTrip = trip; self.timezone = timezone; self.back = back
        _store = StateObject(wrappedValue: RecordDetailStore(service: service))
    }
#if DEBUG
    init(trip: DemoTrip, back: @escaping () -> Void) {
        initialTrip = RecordTrip(preview: trip); timezone = "Asia/Shanghai"; self.back = back
        _store = StateObject(wrappedValue: RecordDetailStore(service: nil, detail: .preview(trip)))
    }
#endif
    private var trip: RecordTrip { store.detail?.trip ?? initialTrip }
    private var events: [RecordTripDetail.Event] { store.detail?.timeline ?? [] }
    private var route: [CLLocationCoordinate2D] { (store.detail?.trail ?? []).filter(\.isValid).map(\.appleCoordinate) }
    private var region: MKCoordinateRegion? {
        let points = route + (store.detail?.anomalies ?? []).filter { $0.point.isValid }.map { $0.point.appleCoordinate }
        guard let first = points.first else { return nil }
        let latitudes = points.map(\.latitude), longitudes = points.map(\.longitude)
        let south = latitudes.min() ?? first.latitude, north = latitudes.max() ?? first.latitude
        let west = longitudes.min() ?? first.longitude, east = longitudes.max() ?? first.longitude
        return MKCoordinateRegion(center: CLLocationCoordinate2D(latitude: (south + north) / 2, longitude: (west + east) / 2),
            span: MKCoordinateSpan(latitudeDelta: max(0.003, (north - south) * 1.35), longitudeDelta: max(0.003, (east - west) * 1.35)))
    }
    private var tripMarkers: [AMapMarker] {
        var markers: [AMapMarker] = []
        if let first = route.first {
            markers.append(marker("start", first, symbol: trip.startKnown ? "house.fill" : "mappin"))
        }
        if let last = route.last, route.count > 1 {
            markers.append(marker("end", last, symbol: trip.returnedHome ? "house.fill" : "flag.fill"))
        }
        for (index, anomaly) in (store.detail?.anomalies ?? []).enumerated() where anomaly.point.isValid {
            markers.append(marker("anomaly-\(index)", anomaly.point.appleCoordinate, symbol: "exclamationmark", anomaly: true))
        }
        return markers
    }
    private func marker(_ id: String, _ coordinate: CLLocationCoordinate2D, symbol: String, anomaly: Bool = false) -> AMapMarker {
        AMapMarker(id: id, coordinate: coordinate, content: AnyView(
            Image(systemName: symbol).recordingFont(18, weight: .regular)
                .foregroundStyle(.white).padding(10).background(anomaly ? Color.red : OrbitMapStyle.blue, in: Circle())))
    }
    // The care API returns the complete WGS-84 trail; conversion happens only for map display.
    var trailLines: [AMapLine] { CaregiverTrailStyle.lines(coordinates: route) }
    var body: some View {
        VStack(spacing: 0) {
            CaregiverTopBar {
                // The back button starts at the screen edge so its glyph lands on the margin line.
                HStack(spacing: 0) {
                    Button(action: back) {
                        Image(systemName: "chevron.left").recordingFont(21, weight: .semibold)
                            .layoutProbe("trip-back-glyph")
                            .iconHitArea(.leading, inset: OrbitLayout.pageMargin)
                    }
                    .accessibilityLabel("Back to records").layoutProbe("trip-back")
                    Text(RecordDates.format(trip.startedAt, "MMM d", timezone: timezone))
                        .recordingFont(25, weight: .semibold)
                        .fixedSize(horizontal: false, vertical: true)
                        .layoutProbe("trip-title")
                    Spacer()
                }
                .foregroundStyle(.white)
                .padding(.trailing, OrbitLayout.pageMargin)
            }
            .layoutProbe("trip-top-bar")
            Group {
                if region != nil {
                    AMapConsentSurface {
                        AMapCanvas(camera: $mapCamera, markers: tripMarkers, lines: trailLines)
                    }
                } else {
                    Text(store.detail == nil ? "" : "No recorded route").caregiverText().foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity).background(OrbitStyle.pale)
                }
            }
            .onAppear { if let region { mapCamera = .region(region) } }
            .onChange(of: store.detail?.trip.id) { _, _ in if let region { mapCamera = .region(region) } }
            .frame(height: 280)
            .layoutProbe("trip-map")
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    if store.loading {
                        ProgressView("Loading trip…").caregiverText()
                    } else if let error = store.error {
                        Text(error).caregiverText().fixedSize(horizontal: false, vertical: true)
                        Button("Try Again") { Task { await store.reload(id: initialTrip.id) } }
                            .caregiverText().frame(minHeight: 44)
                    }
                    ViewThatFits {
                        HStack(spacing: 6) { summaryPills }
                        VStack(alignment: .leading, spacing: 6) { summaryPills }
                    }
                    .layoutProbe("trip-pills")
                    VStack(alignment: .leading, spacing: 0) {
                        ForEach(Array(events.enumerated()), id: \.element.id) { index, event in
                            let last = index == events.count - 1
                            HStack(alignment: .top, spacing: 17) {
                                Circle().fill(OrbitStyle.teal).frame(width: 12, height: 12)
                                    .layoutProbe("trip-dot-\(index)")
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(RecordDates.format(event.at, "MMM d, h:mm a", timezone: timezone)).caregiverText(.secondary).foregroundStyle(.secondary)
                                        .fixedSize(horizontal: false, vertical: true)
                                        .layoutProbe("trip-event-time-\(index)")
                                    Text(event.title).caregiverText().foregroundStyle(.black)
                                        .fixedSize(horizontal: false, vertical: true)
                                        .layoutProbe("trip-event-title-\(index)")
                                }.caregiverText()
                                Spacer()
                            }
                            // 12 pt dot plus a 66 pt line at the default text size; with larger text
                            // the row grows and the connector runs to the next dot (rule 8).
                            .frame(minHeight: last ? 76 : 78, alignment: .top)
                            .background(alignment: .topLeading) {
                                if !last {
                                    Rectangle().fill(OrbitStyle.teal).frame(width: 1)
                                        .layoutProbe("trip-line-\(index)")
                                        .padding(.top, 12).frame(width: 12)
                                }
                            }
                            .layoutProbe("trip-event-\(index)")
                        }
                    }
                    .layoutProbe("trip-timeline")
                }
                .padding(.horizontal, OrbitLayout.pageMargin).padding(.top, 20)
            }
            .background(.white, in: UnevenRoundedRectangle(topLeadingRadius: 28, topTrailingRadius: 28))
            .padding(.top, -18)
        }
        .background(Color.white.ignoresSafeArea(edges: .bottom))
        .task { await store.reload(id: initialTrip.id) }
    }

    @ViewBuilder private var summaryPills: some View {
        pill(trip.name, key: "name")
        pill("\(trip.deviations) \(trip.deviations == 1 ? "deviation" : "deviations")", key: "deviations")
        pill("\(trip.calls) \(trip.calls == 1 ? "call" : "calls")", key: "calls")
    }
    // A pill wraps rather than truncating when its words no longer fit on one line (rule 8).
    private func pill(_ text: String, key: String) -> some View {
        Text(text).caregiverText(.secondary)
            .fixedSize(horizontal: false, vertical: true)
            .layoutProbe("trip-pill-text-" + key)
            .padding(.horizontal, 10).padding(.vertical, 5)
            .background(OrbitStyle.pale, in: Capsule())
            .layoutProbe("trip-pill-" + key)
    }
}
