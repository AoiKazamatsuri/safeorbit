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
    @ScaledMetric(relativeTo: .body) private var minimumMetricWidth: CGFloat = 154
    @ScaledMetric(relativeTo: .body) private var metricIconSize: CGFloat = 28
    @ScaledMetric(relativeTo: .body) private var metricBarWidth: CGFloat = 30
    let onLayout: (([String: CGRect]) -> Void)?
#if DEBUG
    @Environment(\.recordsTestDriver) private var testDriver
#endif
    @State private var section: RecordsSection = .data
    @State private var month = DemoRecords.date(2026, 8, 1)
    @State private var weekStart = DemoRecords.date(2026, 8, 23)
    @State private var expanded = false
    @State private var selectedDay: Date?
    @State private var selectedTrip: DemoTrip?
    let onDetailPresentationChanged: (Bool) -> Void

    init(showTrendInitially: Bool = false, onLayout: (([String: CGRect]) -> Void)? = nil, onDetailPresentationChanged: @escaping (Bool) -> Void = { _ in }) {
        self.onLayout = onLayout
        self.onDetailPresentationChanged = onDetailPresentationChanged
        _section = State(initialValue: showTrendInitially ? .trend : .data)
    }

    private let calendar = DemoRecords.calendar
    private var weekEnd: Date { calendar.date(byAdding: .day, value: 7, to: weekStart)! }
    private var weekTrips: [DemoTrip] {
        DemoRecords.trips.filter { $0.date >= weekStart && $0.date < weekEnd &&
            (selectedDay == nil || calendar.isDate($0.date, inSameDayAs: selectedDay!)) }
            .sorted { $0.date < $1.date }
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
                    .padding(.horizontal, 34)
                    .padding(.top, 12)
                    .padding(.bottom, 23)
                ScrollView {
                    VStack(spacing: 0) {
                        if section == .data { dataContent.padding(.horizontal, dynamicTypeSize.isAccessibilitySize ? 0 : 12) }
                        else { trendContent }
                    }
                    .recordsFrame("content")
                    .padding(.horizontal, 22)
                    .padding(.bottom, 112)
                }
            }
            .background(.white, in: UnevenRoundedRectangle(topLeadingRadius: 28, topTrailingRadius: 28))
            .background(alignment: .top) { OrbitStyle.teal.frame(height: 40) }
        }
        .background(Color.white.ignoresSafeArea(edges: .bottom))
        .coordinateSpace(name: "RecordsPage")
        .onPreferenceChange(RecordsFrames.self) { onLayout?($0) }
#if DEBUG
        .onAppear {
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
                        .frame(maxWidth: .infinity).frame(minHeight: 44).padding(.vertical, 3)
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

    private var weekTitle: some View {
        HStack(spacing: 8) {
            Text(selectedDay == nil ? "This Week" : dayTitle(selectedDay!))
                .recordingFont(18, weight: .medium).fixedSize(horizontal: false, vertical: true)
            if selectedDay != nil {
                Button("Clear") { selectedDay = nil }.caregiverText(.caption)
                    .frame(minWidth: 44, minHeight: 44).recordsFrame("clear-day")
            }
        }
    }
    private var weekRange: some View {
        Text("\(shortDate(weekStart)) – \(shortDate(calendar.date(byAdding: .day, value: 6, to: weekStart)!))")
            .caregiverText(.secondary).foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
    }
    private func weekButton(_ amount: Int) -> some View {
        Button { shiftWeek(amount) } label: {
            Image(systemName: amount < 0 ? "chevron.left" : "chevron.right")
                .frame(minWidth: 44, minHeight: 44).contentShape(Rectangle())
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
                VStack(spacing: 3) {
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
                                        .frame(maxWidth: .infinity).frame(minHeight: max(36, calendarColumnWidth))
                                        .background(riskColor(risk), in: Circle())
                                        .overlay {
                                            if incomplete { Circle().stroke(.gray, style: StrokeStyle(lineWidth: 1.5, dash: [3, 2])) }
                                        }
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel("\(dayTitle(date)), \(risk?.title ?? "No trips")\(incomplete ? ", incomplete record" : "")")
                            } else { Color.clear.frame(height: max(36, calendarColumnWidth)) }
                        }
                    }
                }
            }
            .accessibilityIdentifier("records-calendar")
        }
        .padding(dynamicTypeSize.isAccessibilitySize ? 8 : 14)
        .caregiverCard().recordsFrame("calendar")
    }
    private func monthButton(_ amount: Int) -> some View {
        Button { shiftMonth(amount) } label: {
            Image(systemName: amount < 0 ? "chevron.left" : "chevron.right")
                .frame(minWidth: 44, minHeight: 44).contentShape(Rectangle())
        }
        .accessibilityLabel(amount < 0 ? "Previous month" : "Next month")
        .recordsFrame(amount < 0 ? "previous-month" : "next-month")
    }
    private func selectDay(_ date: Date) {
        selectedDay = date
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
                    .frame(maxWidth: .infinity).padding(22)
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
                        .padding(.horizontal, 14).padding(.vertical, 8).frame(minHeight: 50)
                        .recordsFrame("trip-\(trip.id)")
                    }.buttonStyle(.plain)
                    if index < min(weekTrips.count, expanded ? weekTrips.count : 4) - 1 {
                        Divider().padding(.horizontal, 12)
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
                .fixedSize(horizontal: false, vertical: true)
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
        .padding(24)
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
        let columns = [GridItem(.adaptive(minimum: minimumMetricWidth), spacing: 18, alignment: .top)]
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
                Text(metric.0).caregiverText(.caption).fixedSize(horizontal: false, vertical: true)
            }.frame(minHeight: 28, alignment: .leading)
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .bottom, spacing: 4) {
                    metricSummary(metric).fixedSize(horizontal: true, vertical: false)
                    Spacer(minLength: 0)
                    metricBars(metric).fixedSize()
                }
                VStack(alignment: .leading, spacing: 8) {
                    metricSummary(metric)
                    metricBars(metric)
                }
            }
        }
        .frame(maxWidth: .infinity, minHeight: 136, alignment: .leading)
        .padding(12)
        .caregiverCard(radius: 24, opacity: 0.13).recordsFrame("metric-\(metric.0)")
    }
    private func metricSummary(_ metric: (String, String, Int, Int, String)) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("\(metric.2)\(metric.4 == "%" ? "%" : "")").orbitDisplayFont(36, weight: .semibold)
            if metric.4 != "%" { Text(metric.4).caregiverText(.secondary).foregroundStyle(.secondary) }
            Text(metric.4 == "%" ? percentagePointChange(metric.2, metric.3) : percentChange(metric.2, metric.3))
                .orbitDisplayFont(17)
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
        selectedDay = nil
    }
    private func shiftWeek(_ amount: Int) {
        weekStart = calendar.date(byAdding: .weekOfYear, value: amount, to: weekStart)!
        selectedDay = nil; expanded = false
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
    var body: some View {
        VStack(spacing: 0) {
            CaregiverTopBar {
                HStack(spacing: 12) {
                    Button(action: back) { Image(systemName: "chevron.left")
                        .recordingFont(21, weight: .semibold) }
                        .accessibilityLabel("Back to records")
                    Text("\(trip.month == 8 ? "Aug" : "Jul") \(trip.day)")
                        .recordingFont(25, weight: .semibold)
                    Spacer()
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 23)
            }
            AMapConsentSurface {
                AMapCanvas(camera: $mapCamera, markers: tripMarkers,
                    lines: [AMapLine(id: "trip", coordinates: route, color: OrbitMapStyle.blue,
                                     width: 4, dash: [6, 5])])
            }
            .onAppear { mapCamera = .region(region) }
            .frame(height: 280)
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    ViewThatFits {
                        HStack(spacing: 6) { summaryPills }
                        VStack(alignment: .leading, spacing: 6) { summaryPills }
                    }
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
                    .padding(.horizontal, 23)
                }
                .padding(.horizontal, 22).padding(.top, 20)
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
