import SwiftUI
import MapKit
import Charts

private enum RecordsSection: String, CaseIterable {
    case trend = "Trend", data = "Data"
}

struct RecordsPage: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var section: RecordsSection = .data
    @State private var month = DemoRecords.date(2026, 8, 1)
    @State private var weekStart = DemoRecords.date(2026, 8, 23)
    @State private var expanded = false
    @State private var selectedDay: Date?
    @State private var selectedTrip: DemoTrip?
    let onDetailPresentationChanged: (Bool) -> Void

    init(showTrendInitially: Bool = false, onDetailPresentationChanged: @escaping (Bool) -> Void = { _ in }) {
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
            CaregiverTopBar(height: dynamicTypeSize.isAccessibilitySize ? 74 : 47) {
                Text("Recording")
                    .recordingFont(27, weight: .semibold)
                    .foregroundStyle(.white)
            }
            ScrollView {
                VStack(spacing: 23) {
                    sectionPicker.padding(.horizontal, 12)
                    if section == .data { dataContent.padding(.horizontal, dynamicTypeSize.isAccessibilitySize ? 0 : 12) }
                    else { trendContent }
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)
                .padding(.bottom, 112)
            }
            .background(.white, in: UnevenRoundedRectangle(topLeadingRadius: 29, topTrailingRadius: 29))
            .background(alignment: .top) { OrbitStyle.teal.frame(height: 40) }
        }
        .background(Color.white.ignoresSafeArea(edges: .bottom))
        .settingsSlide(item: $selectedTrip) { TripDetailPage(trip: $0) { selectedTrip = nil } }
        .onChange(of: selectedTrip?.id) { _, id in onDetailPresentationChanged(id != nil) }
        .onDisappear { onDetailPresentationChanged(false) }
    }

    private var sectionPicker: some View {
        HStack(spacing: 4) {
            ForEach(RecordsSection.allCases, id: \.self) { item in
                Button { section = item } label: {
                    Text(item.rawValue)
                        .recordingFont(16, weight: .medium)
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
            (dynamicTypeSize.isAccessibilitySize ? AnyLayout(VStackLayout(alignment: .leading, spacing: 8)) : AnyLayout(HStackLayout(spacing: 8))) {
                Button { shiftWeek(-1) } label: { Image(systemName: "chevron.left").frame(width: 26) }
                    .accessibilityLabel("Previous week")
                Text(selectedDay == nil ? "This Week" : dayTitle(selectedDay!))
                    .recordingFont(18, weight: .medium)
                if selectedDay != nil {
                    Button("Clear") { selectedDay = nil }.font(.caption)
                }
                Spacer()
                Text("\(shortDate(weekStart)) – \(shortDate(calendar.date(byAdding: .day, value: 6, to: weekStart)!))")
                    .recordingFont(13, weight: .regular).foregroundStyle(.secondary)
                Button { shiftWeek(1) } label: { Image(systemName: "chevron.right").frame(width: 26) }
                    .accessibilityLabel("Next week")
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 9)
            weekCard
        }
    }

    private var calendarCard: some View {
        VStack(spacing: 9) {
            HStack {
                Button { shiftMonth(-1) } label: { Image(systemName: "chevron.left") }
                    .accessibilityLabel("Previous month")
                Spacer()
                Text(monthTitle(month)).recordingFont(19, weight: .medium)
                Spacer()
                Button { shiftMonth(1) } label: { Image(systemName: "chevron.right") }
                    .accessibilityLabel("Next month")
            }.buttonStyle(.plain)
            HStack(spacing: 0) {
                ForEach(["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"], id: \.self) { label in
                    Text(dynamicTypeSize.isAccessibilitySize ? String(label.prefix(1)) : label).recordingFont(13, weight: .regular).foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
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
                        Button {
                            selectedDay = date
                            weekStart = calendar.dateInterval(of: .weekOfYear, for: date)!.start
                            expanded = true
                        } label: {
                            Text("\(day)")
                                .recordingFont(16, weight: selectedDay.map { calendar.isDate($0, inSameDayAs: date) } == true ? .semibold : .regular)
                                .foregroundStyle(risk == .high ? .white : .black)
                                .frame(maxWidth: .infinity).frame(minHeight: dynamicTypeSize.isAccessibilitySize ? 44 : 30)
                                .background(riskColor(risk), in: Circle())
                                .overlay {
                                    if incomplete { Circle().stroke(.gray, style: StrokeStyle(lineWidth: 1.5, dash: [3, 2])) }
                                }
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("\(dayTitle(date)), \(risk?.title ?? "No trips")\(incomplete ? ", incomplete record" : "")")
                    } else { Color.clear.frame(height: 30) }
                }
            }
        }
        .padding(dynamicTypeSize.isAccessibilitySize ? 8 : 14)
        .caregiverCard()
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
                Text("No trips in this period").foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity).padding(22)
            } else {
                ForEach(Array(weekTrips.prefix(expanded ? weekTrips.count : 4).enumerated()), id: \.element.id) { index, trip in
                    Button { selectedTrip = trip } label: {
                        (dynamicTypeSize.isAccessibilitySize ? AnyLayout(VStackLayout(alignment: .leading, spacing: 8)) : AnyLayout(HStackLayout(spacing: 9))) {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(shortDate(trip.date)).recordingFont(16, weight: .medium).foregroundStyle(.black)
                                Text(weekday(trip.date)).font(.caption).foregroundStyle(.secondary)
                            }.frame(width: dynamicTypeSize.isAccessibilitySize ? nil : 63, alignment: .leading)
                            Text(trip.risk == .high ? "Risk" : trip.risk.title)
                                .recordingFont(11, weight: .medium).fixedSize()
                                .padding(.horizontal, 8).padding(.vertical, 4)
                                .foregroundStyle(trip.risk == .high ? .white : .black)
                                .background(riskColor(trip.risk), in: Capsule())
                            VStack(alignment: .leading, spacing: 2) {
                                Text(trip.name).fixedSize(horizontal: false, vertical: true)
                                    .recordingFont(12, weight: .regular).foregroundStyle(.black)
                                if trip.deviations > 0 {
                                    Text("Route Deviation").recordingFont(11, weight: .regular).foregroundStyle(.secondary)
                                }
                            }.frame(maxWidth: .infinity, alignment: .leading)
                            Text("\(trip.durationMinutes) min")
                                .recordingFont(11, weight: .regular).foregroundStyle(.black)
                            Image(systemName: "chevron.right").recordingFont(13, weight: .semibold)
                                .foregroundStyle(.black)
                        }
                        .padding(.horizontal, 14).padding(.vertical, dynamicTypeSize.isAccessibilitySize ? 12 : 0).frame(minHeight: 50)
                    }.buttonStyle(.plain)
                    if index < min(weekTrips.count, expanded ? weekTrips.count : 4) - 1 {
                        Divider().padding(.horizontal, 12)
                    }
                }
                if weekTrips.count > 4 {
                    Button { expanded.toggle() } label: {
                        Label(expanded ? "View Less" : "View More", systemImage: expanded ? "chevron.up" : "chevron.down")
                            .recordingFont(16, weight: .regular).foregroundStyle(.black)
                            .frame(maxWidth: .infinity).frame(height: 36)
                    }
                }
            }
        }
        .caregiverCard()
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
        let values = DemoRecords.weeklyDeviations()
        let weekStarts = DemoRecords.weekStarts()
        return VStack(alignment: .leading, spacing: 12) {
            Text("Route Deviation Trend").recordingFont(22, weight: .semibold)
            (dynamicTypeSize.isAccessibilitySize ? AnyLayout(VStackLayout(alignment: .leading, spacing: 12)) : AnyLayout(HStackLayout(alignment: .center, spacing: 0))) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("\(current)").recordingFont(47, weight: .bold)
                    Text("events").foregroundStyle(.secondary)
                    Text(percentChange(current, previous))
                        .recordingFont(20, weight: .medium).padding(.top, 8)
                    Text("vs last month").font(.caption).foregroundStyle(.secondary)
                }.frame(width: dynamicTypeSize.isAccessibilitySize ? nil : 90, alignment: .leading)
                VStack(spacing: 2) {
                Chart {
                    ForEach(values.indices, id: \.self) { index in
                        AreaMark(x: .value("Week", index), y: .value("Events", values[index]))
                            .foregroundStyle(LinearGradient(colors: [OrbitStyle.teal.opacity(0.38), .clear],
                                                            startPoint: .top, endPoint: .bottom))
                        LineMark(x: .value("Week", index), y: .value("Events", values[index]))
                            .foregroundStyle(OrbitStyle.teal).lineStyle(StrokeStyle(lineWidth: 2))
                        PointMark(x: .value("Week", index), y: .value("Events", values[index]))
                            .foregroundStyle(OrbitStyle.teal)
                    }
                }
                .chartYScale(domain: 0...max(3, (values.max() ?? 0) + 1))
                .chartXScale(domain: 0...7, range: .plotDimension(padding: 18))
                .chartXAxis(.hidden)
                .chartYAxis {
                    AxisMarks(position: .leading, values: [0, 1, 2, 3]) { value in
                        AxisGridLine()
                        AxisValueLabel { if let number = value.as(Int.self) { Text("\(number)").recordingFont(10, weight: .medium) } }
                    }
                }
                .frame(height: dynamicTypeSize.isAccessibilitySize ? 190 : 145)
                HStack {
                    Text(shortDate(weekStarts[0]))
                    Spacer(minLength: 4)
                    if !dynamicTypeSize.isAccessibilitySize {
                        Text(shortDate(weekStarts[3]))
                        Spacer(minLength: 4)
                    }
                    Text(shortDate(weekStarts[7]))
                }
                .recordingFont(10, weight: .medium)
                .lineLimit(1).fixedSize(horizontal: false, vertical: true)
                .foregroundStyle(.secondary)


                }
            }
        }
        .padding(21)
        .caregiverCard()
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
        let columns = dynamicTypeSize.isAccessibilitySize ? [GridItem(.flexible())]
            : [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]
        return LazyVGrid(columns: columns, spacing: 12) {
            ForEach(metrics, id: \.0) { metric in
                metricCard(metric)
            }
        }
    }

    private func metricCard(_ metric: (String, String, Int, Int, String)) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .center, spacing: 5) {
                Image(systemName: metric.1).recordingFont(15, weight: .regular)
                    .frame(width: 26, height: 26).background(OrbitStyle.pale, in: Circle())
                Text(metric.0).recordingFont(11, weight: .medium).fixedSize(horizontal: false, vertical: true)
            }.frame(minHeight: 31, alignment: .leading)
            HStack(alignment: .bottom, spacing: 4) {
                VStack(alignment: .leading, spacing: 1) {
                    Text("\(metric.2)\(metric.4 == "%" ? "%" : "")")
                        .recordingFont(30, weight: .semibold)
                    if metric.4 != "%" { Text(metric.4).font(.caption).foregroundStyle(.secondary) }
                }
                Spacer(minLength: 2)
                HStack(alignment: .bottom, spacing: 4) {
                    bar(metric.3, maxValue: max(metric.2, metric.3), lighter: true)
                    bar(metric.2, maxValue: max(metric.2, metric.3), lighter: false)
                }.frame(minHeight: 43, alignment: .bottom)
            }
            Text(metric.4 == "%" ? percentagePointChange(metric.2, metric.3) : percentChange(metric.2, metric.3))
                .recordingFont(17, weight: .medium)
            Text("vs last month").recordingFont(11, weight: .regular).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 138, alignment: .leading)
        .padding(11)
        .caregiverCard(radius: 24, opacity: 0.13)
    }

    private func bar(_ value: Int, maxValue: Int, lighter: Bool) -> some View {
        VStack(spacing: 2) {
            Text("\(value)\(maxValue > 10 ? "%" : "")").recordingFont(10, weight: .medium).fixedSize()
                .foregroundStyle(OrbitStyle.teal)
            RoundedRectangle(cornerRadius: 3)
                .fill(lighter ? OrbitStyle.pale : OrbitStyle.teal.opacity(0.65))
                .frame(width: 22, height: CGFloat(max(8, value * 32 / max(1, maxValue))))
        }.frame(minWidth: dynamicTypeSize.isAccessibilitySize ? 55 : 28)
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

struct TripDetailPage: View {
    let trip: DemoTrip
    let back: () -> Void

    private var route: [CLLocationCoordinate2D] { DemoRecords.route.map(\.appleCoordinate) }
    private var region: MKCoordinateRegion {
        MKCoordinateRegion(center: DemoRecords.route[3].appleCoordinate,
                           span: MKCoordinateSpan(latitudeDelta: 0.006, longitudeDelta: 0.007))
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
            Map(initialPosition: .region(region)) {
                MapPolyline(coordinates: route)
                    .stroke(OrbitMapStyle.blue, style: StrokeStyle(lineWidth: 4, lineCap: .round, dash: [6, 5]))
                Annotation("Home", coordinate: route.first!) {
                    Image(systemName: "house.fill").recordingFont(18, weight: .regular)
                        .foregroundStyle(.white).padding(10).background(OrbitMapStyle.blue, in: Circle())
                }
                Annotation("Market", coordinate: route.last!) {
                    Image(systemName: "storefront.fill").recordingFont(18, weight: .regular)
                        .foregroundStyle(.white).padding(10).background(OrbitMapStyle.blue, in: Circle())
                }
                if trip.deviations > 0 {
                    Annotation("Deviation", coordinate: route[3]) {
                        Image(systemName: "exclamationmark")
                            .foregroundStyle(.white).padding(8).background(.red, in: Circle())
                    }
                }
            }
            .mapStyle(.standard(elevation: .flat))
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
                                    Text(time(event.minute)).foregroundStyle(.secondary)
                                    Text(event.title).foregroundStyle(.black)
                                }.recordingFont(16, weight: .regular)
                                Spacer()
                            }
                            .frame(minHeight: 76, alignment: .top)
                        }
                    }
                    .padding(.horizontal, 23)
                }
                .padding(.horizontal, 22).padding(.top, 20)
            }
            .background(.white, in: UnevenRoundedRectangle(topLeadingRadius: 26, topTrailingRadius: 26))
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
        Text(text).recordingFont(14, weight: .regular).lineLimit(1)
            .padding(.horizontal, 10).padding(.vertical, 5)
            .background(OrbitStyle.pale, in: Capsule())
    }
    private func time(_ minute: Int) -> String {
        let hour = (minute / 60) % 24
        return String(format: "%d:%02d %@", hour % 12 == 0 ? 12 : hour % 12,
                      minute % 60, hour < 12 ? "AM" : "PM")
    }
}
