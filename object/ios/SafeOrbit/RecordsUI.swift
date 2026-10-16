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
    @ScaledMetric(relativeTo: .body) private var metricBarWidth: CGFloat = 30
    let onLayout: (([String: CGRect]) -> Void)?
#if DEBUG
    @Environment(\.recordsTestDriver) private var testDriver
#endif
    @State private var section: RecordsSection = .data
    @State private var month = DemoRecords.date(2026, 8, 1)
    @State private var weekStart = RecordsPage.currentWeekStart
    @State private var expanded = false
    @State private var selectedTrip: DemoTrip?
    @State private var pageWidth: CGFloat = 402
    let onDetailPresentationChanged: (Bool) -> Void

    init(showTrendInitially: Bool = false, onLayout: (([String: CGRect]) -> Void)? = nil, onDetailPresentationChanged: @escaping (Bool) -> Void = { _ in }) {
        self.onLayout = onLayout
        self.onDetailPresentationChanged = onDetailPresentationChanged
        _section = State(initialValue: showTrendInitially ? .trend : .data)
    }

    private let calendar = DemoRecords.calendar
    // The demo's "today" week; the trend chart ends with the same Monday.
    static let currentWeekStart = DemoRecords.weekStarts().last!
    private var weekEnd: Date { calendar.date(byAdding: .day, value: 7, to: weekStart)! }
    private var weekTrips: [DemoTrip] {
        DemoRecords.trips.filter { $0.date >= weekStart && $0.date < weekEnd }.sorted { $0.date < $1.date }
    }

    var body: some View {
        VStack(spacing: 0) {
            CaregiverTopBar(height: max(47, titleHeight + 16)) {
                Text("Recording")
                    .orbitDisplayFont(20)
                    .foregroundStyle(.white)
                    .recordsFrame("title")
            }
            VStack(spacing: 0) {
                sectionPicker.recordsFrame("picker")
                    .padding(.horizontal, OrbitLayout.pageMargin)
                    .padding(.top, 12)
                    .padding(.bottom, 23)
                ScrollView {
                    VStack(spacing: 0) {
                        if section == .data { dataContent }
                        else { trendContent }
                    }
                    .recordsFrame("content")
                    .padding(.horizontal, OrbitLayout.pageMargin)
                    .padding(.bottom, 112)
                }
            }
            .background(.white, in: UnevenRoundedRectangle(topLeadingRadius: 28, topTrailingRadius: 28))
            .background(alignment: .top) { OrbitStyle.teal.frame(height: 40) }
        }
        .background(Color.white.ignoresSafeArea(edges: .bottom))
        .background {
            GeometryReader { geometry in
                Color.clear.onAppear { pageWidth = geometry.size.width }
                    .onChange(of: geometry.size.width) { _, width in pageWidth = width }
            }
        }
        .coordinateSpace(name: "RecordsPage")
        .onPreferenceChange(RecordsFrames.self) { onLayout?($0) }
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
                case .openTrip(let trip): selectedTrip = trip
                case .closeTrip: selectedTrip = nil
                case .showTrend(let show): section = show ? .trend : .data
                }
            }
        }
#endif
        .settingsSlide(item: $selectedTrip) { TripDetailPage(trip: $0) { selectedTrip = nil } }
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
        if weekStart == RecordsPage.currentWeekStart {
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
                                let date = DemoRecords.date(calendar.component(.year, from: month),
                                                            calendar.component(.month, from: month), day)
                                let risk = DemoRecords.highestRisk(on: date)
                                let incomplete = DemoRecords.trips(on: date).contains { $0.incomplete }
                                Button { selectDay(date) } label: {
                                    Text("\(day)").caregiverText().fixedSize()
                                        .foregroundStyle(risk == .high ? .white : .black)
                                        .frame(maxWidth: .infinity).frame(minHeight: dynamicTypeSize.isAccessibilitySize ? 44 : 30)
                                        .background(riskColor(risk), in: Circle())
                                        .overlay {
                                            if incomplete { Circle().stroke(.gray, style: StrokeStyle(lineWidth: 1.5, dash: [3, 2])) }
                                        }
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel("\(dayTitle(date)), \(risk?.title ?? "No trips")\(incomplete ? ", incomplete record" : "")")
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
        weekStart = calendar.dateInterval(of: .weekOfYear, for: date)!.start
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
            if weekTrips.isEmpty {
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

    private func tripDate(_ trip: DemoTrip) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(shortDate(trip.date)).caregiverText().foregroundStyle(.black)
            Text(weekday(trip.date)).caregiverText(.caption).foregroundStyle(.secondary)
        }.fixedSize().recordsFrame("date-\(trip.id)")
    }
    private func tripRisk(_ trip: DemoTrip) -> some View {
        Text(trip.risk == .high ? "Risk" : trip.risk.title)
            .caregiverText(.caption).fixedSize()
            .padding(.horizontal, 8).padding(.vertical, 4)
            .foregroundStyle(trip.risk == .high ? .white : .black)
            .background(riskColor(trip.risk), in: Capsule())
            .recordsFrame("risk-\(trip.id)")
    }
    private func tripRoute(_ trip: DemoTrip) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(trip.name).caregiverText(.caption).foregroundStyle(.black)
            if trip.deviations > 0 {
                Text("Route Deviation").caregiverText(.caption).foregroundStyle(.secondary)
            }
        }.fixedSize(horizontal: false, vertical: true).recordsFrame("route-\(trip.id)")
    }
    private func tripDuration(_ trip: DemoTrip) -> some View {
        HStack(spacing: 8) {
            Text("\(trip.durationMinutes) min").caregiverText(.caption)
            Image(systemName: "chevron.right").recordingFont(13, weight: .semibold)
        }.foregroundStyle(.black).fixedSize().recordsFrame("duration-\(trip.id)")
    }

    private var trendContent: some View {
        VStack(spacing: 16) {
            trendCard
            metricGrid
        }
    }

    private var trendCard: some View {
        let current = DemoRecords.trips.filter { $0.month == 8 }.reduce(0) { $0 + $1.deviations }
        let previous = DemoRecords.trips.filter { $0.month == 7 }.reduce(0) { $0 + $1.deviations }
        return VStack(alignment: .leading, spacing: 18) {
            Text("Route Deviation Trend").orbitDisplayFont(20, weight: .semibold)
                .fixedSize(horizontal: false, vertical: true).recordsFrame("trend-title")
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .bottom, spacing: 8) {
                    trendSummary(current, previous: previous).fixedSize(horizontal: true, vertical: false)
                    TrendDeviationChart().frame(minWidth: 206).recordsFrame("trend-chart-viewport")
                }
                VStack(alignment: .leading, spacing: 16) {
                    trendSummary(current, previous: previous)
                    TrendDeviationChart().recordsFrame("trend-chart-viewport")
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
        let current = DemoRecords.trips.filter { $0.month == 8 }
        let previous = DemoRecords.trips.filter { $0.month == 7 }
        let metrics: [(String, String, Int, Int, String)] = [
            ("Unusual Movement", "exclamationmark.circle.fill", current.filter(\.unusualMovement).count,
             previous.filter(\.unusualMovement).count, "events"),
            ("Navigation Assistance", "point.topleft.down.curvedto.point.bottomright.up", current.filter(\.navigationAssisted).count,
             previous.filter(\.navigationAssisted).count, "events"),
            ("High-risk Events", "exclamationmark.triangle.fill", current.filter { $0.risk == .high }.count,
             previous.filter { $0.risk == .high }.count, "events"),
            ("Safe Return Rate", "shield.lefthalf.filled", DemoRecords.safeReturnRate(month: 8),
             DemoRecords.safeReturnRate(month: 7), "%")
        ]
        // Two columns from 380 pt at standard text sizes. Grid rows give both cards in a row
        // the height of the taller one.
        let columns = dynamicTypeSize.isAccessibilitySize || pageWidth < 380 ? 1 : 2
        return Grid(horizontalSpacing: 18, verticalSpacing: 16) {
            ForEach(Array(stride(from: 0, to: metrics.count, by: columns)), id: \.self) { start in
                GridRow {
                    ForEach(metrics[start..<min(start + columns, metrics.count)], id: \.0) { metric in
                        metricCard(metric)
                    }
                }
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
            }.frame(minHeight: 28, alignment: .leading)
            // Numbers keep their natural width and the bars sit at the trailing edge. No extra
            // spacing: the bars' own side inset is the gap, so "50%" fits a 170 pt card.
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .bottom, spacing: 0) {
                    metricSummary(metric).fixedSize(horizontal: true, vertical: false)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    metricBars(metric).fixedSize()
                }
                VStack(alignment: .leading, spacing: 8) {
                    metricSummary(metric)
                    metricBars(metric)
                }
            }
        }
        .frame(maxWidth: .infinity, minHeight: 136, maxHeight: .infinity, alignment: .topLeading)
        .padding(OrbitLayout.compactCardPadding)
        .caregiverCard(radius: 24, opacity: 0.13).recordsFrame("metric-\(metric.0)")
    }
    private func metricSummary(_ metric: (String, String, Int, Int, String)) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("\(metric.2)\(metric.4 == "%" ? "%" : "")").orbitDisplayFont(36, weight: .semibold)
                .recordsFrame("metric-value-\(metric.0)")
            if metric.4 != "%" { Text(metric.4).caregiverText(.secondary).foregroundStyle(.secondary) }
            Text(metric.4 == "%" ? percentagePointChange(metric.2, metric.3) : percentChange(metric.2, metric.3))
                .orbitDisplayFont(17).recordsFrame("metric-change-\(metric.0)")
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

    private func shiftMonth(_ amount: Int) {
        month = calendar.date(byAdding: .month, value: amount, to: month)!
    }
    private func shiftWeek(_ amount: Int) {
        weekStart = calendar.date(byAdding: .weekOfYear, value: amount, to: weekStart)!
        expanded = false
        month = calendar.dateInterval(of: .month, for: weekStart)!.start
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
    let trip: DemoTrip
    let back: () -> Void
    @State private var mapCamera: MapCameraPosition = .automatic

    private var route: [CLLocationCoordinate2D] { DemoRecords.route.map(\.appleCoordinate) }
    private var region: MKCoordinateRegion {
        MKCoordinateRegion(center: DemoRecords.route[3].appleCoordinate,
                           span: MKCoordinateSpan(latitudeDelta: 0.006, longitudeDelta: 0.007))
    }
    private var tripMarkers: [AMapMarker] {
        var markers = [
            AMapMarker(id: "home", coordinate: route.first!, content: AnyView(
                Image(systemName: "house.fill").recordingFont(18, weight: .regular)
                    .foregroundStyle(.white).padding(10).background(OrbitMapStyle.blue, in: Circle()))),
            AMapMarker(id: "market", coordinate: route.last!, content: AnyView(
                Image(systemName: "storefront.fill").recordingFont(18, weight: .regular)
                    .foregroundStyle(.white).padding(10).background(OrbitMapStyle.blue, in: Circle())))
        ]
        if trip.deviations > 0 {
            markers.append(AMapMarker(id: "deviation", coordinate: route[3], content: AnyView(
                Image(systemName: "exclamationmark").foregroundStyle(.white).padding(8).background(.red, in: Circle()))))
        }
        return markers
    }
    // Same solid trail as the location page.
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
                    Text("\(trip.month == 8 ? "Aug" : "Jul") \(trip.day)")
                        .recordingFont(25, weight: .semibold)
                    Spacer()
                }
                .foregroundStyle(.white)
                .padding(.trailing, OrbitLayout.pageMargin)
            }
            AMapConsentSurface {
                AMapCanvas(camera: $mapCamera, markers: tripMarkers, lines: trailLines)
            }
            .onAppear { mapCamera = .region(region) }
            .frame(height: 280)
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    ViewThatFits {
                        HStack(spacing: 6) { summaryPills }
                        VStack(alignment: .leading, spacing: 6) { summaryPills }
                    }
                    .layoutProbe("trip-pills")
                    VStack(alignment: .leading, spacing: 0) {
                        ForEach(Array(trip.events.enumerated()), id: \.element.id) { index, event in
                            HStack(alignment: .top, spacing: 17) {
                                VStack(spacing: 0) {
                                    Circle().fill(OrbitStyle.teal).frame(width: 12, height: 12)
                                    Rectangle().fill(OrbitStyle.teal)
                                        .frame(width: 1, height: index == trip.events.count - 1 ? 0 : 66)
                                }
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(time(event.minute)).caregiverText(.secondary).foregroundStyle(.secondary)
                                    Text(event.title).caregiverText().foregroundStyle(.black)
                                }.caregiverText()
                                Spacer()
                            }
                            .frame(minHeight: 76, alignment: .top)
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
    }

    @ViewBuilder private var summaryPills: some View {
        pill(trip.name)
        pill("\(trip.deviations) \(trip.deviations == 1 ? "deviation" : "deviations")")
        pill("\(trip.calls) \(trip.calls == 1 ? "call" : "calls")")
    }
    private func pill(_ text: String) -> some View {
        Text(text).caregiverText(.secondary).lineLimit(1)
            .padding(.horizontal, 10).padding(.vertical, 5)
            .background(OrbitStyle.pale, in: Capsule())
    }
    private func time(_ minute: Int) -> String {
        let hour = (minute / 60) % 24
        return String(format: "%d:%02d %@", hour % 12 == 0 ? 12 : hour % 12,
                      minute % 60, hour < 12 ? "AM" : "PM")
    }
}
