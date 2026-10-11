import SwiftUI
import MapKit
import Charts

private enum RecordsSection: String, CaseIterable {
    case trend = "Trend", data = "Data"
}

struct RecordsPage: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var pageWidth: CGFloat = 402
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
                    .orbitDisplayFont(20)
                    .foregroundStyle(.white)
            }
            ScrollView {
                VStack(spacing: 23) {
                    sectionPicker.padding(.horizontal, 12)
                    if section == .data { dataContent.padding(.horizontal, dynamicTypeSize.isAccessibilitySize ? 0 : 12) }
                    else { trendContent }
                }
                .padding(.horizontal, 22)
                .padding(.top, 12)
                .padding(.bottom, 112)
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
            (dynamicTypeSize.isAccessibilitySize ? AnyLayout(VStackLayout(alignment: .leading, spacing: 8)) : AnyLayout(HStackLayout(spacing: 8))) {
                Button { shiftWeek(-1) } label: { Image(systemName: "chevron.left").frame(width: 26) }
                    .accessibilityLabel("Previous week")
                Text(selectedDay == nil ? "This Week" : dayTitle(selectedDay!))
                    .recordingFont(18, weight: .medium)
                if selectedDay != nil {
                    Button("Clear") { selectedDay = nil }.caregiverText(.caption)
                }
                Spacer()
                Text("\(shortDate(weekStart)) – \(shortDate(calendar.date(byAdding: .day, value: 6, to: weekStart)!))")
                    .caregiverText(.secondary).foregroundStyle(.secondary)
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
                    Text(dynamicTypeSize.isAccessibilitySize ? String(label.prefix(1)) : label).caregiverText(.secondary).foregroundStyle(.secondary)
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
                                .caregiverText()
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

    private var stackedRecordRows: Bool { dynamicTypeSize > .large }

    private var weekCard: some View {
        VStack(spacing: 0) {
            if weekTrips.isEmpty {
                Text("No trips in this period").foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity).padding(22)
            } else {
                ForEach(Array(weekTrips.prefix(expanded ? weekTrips.count : 4).enumerated()), id: \.element.id) { index, trip in
                    Button { selectedTrip = trip } label: {
                        (stackedRecordRows ? AnyLayout(VStackLayout(alignment: .leading, spacing: 8)) : AnyLayout(HStackLayout(spacing: 8))) {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(shortDate(trip.date)).caregiverText().fixedSize(horizontal: !stackedRecordRows, vertical: true).foregroundStyle(.black)
                                Text(weekday(trip.date)).caregiverText(.caption).foregroundStyle(.secondary)
                            }.frame(width: stackedRecordRows ? nil : 52, alignment: .leading)
                            Text(trip.risk == .high ? "Risk" : trip.risk.title)
                                .caregiverText(.caption).fixedSize()
                                .padding(.horizontal, 8).padding(.vertical, 4)
                                .foregroundStyle(trip.risk == .high ? .white : .black)
                                .background(riskColor(trip.risk), in: Capsule())
                                .frame(width: stackedRecordRows ? nil : 60, alignment: .leading)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(trip.name).fixedSize(horizontal: false, vertical: true)
                                    .caregiverText(.caption).foregroundStyle(.black)
                                if trip.deviations > 0 {
                                    Text("Route Deviation").caregiverText(.caption).foregroundStyle(.secondary)
                                }
                            }.frame(maxWidth: .infinity, alignment: .leading)
                            Text("\(trip.durationMinutes) min")
                                .caregiverText(.caption).foregroundStyle(.black)
                                .frame(width: stackedRecordRows ? nil : 40, alignment: .leading)
                            Image(systemName: "chevron.right").recordingFont(13, weight: .semibold)
                                .foregroundStyle(.black)
                                .frame(width: stackedRecordRows ? nil : 12, alignment: .leading)
                        }
                        .padding(.horizontal, 14).padding(.vertical, stackedRecordRows ? 12 : 0).frame(minHeight: 50)
                    }.buttonStyle(.plain)
                    if index < min(weekTrips.count, expanded ? weekTrips.count : 4) - 1 {
                        Divider().padding(.horizontal, 12)
                    }
                }
                if weekTrips.count > 4 {
                    Button { expanded.toggle() } label: {
                        Label(expanded ? "View Less" : "View More", systemImage: expanded ? "chevron.up" : "chevron.down")
                            .caregiverText().foregroundStyle(.black)
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
        return VStack(alignment: .leading, spacing: 18) {
            Text("Route Deviation Trend").orbitDisplayFont(20, weight: .semibold)
                .fixedSize(horizontal: false, vertical: true)
            ViewThatFits(in: .horizontal) {
                if !dynamicTypeSize.isAccessibilitySize {
                    HStack(alignment: .bottom, spacing: 8) {
                        trendSummary(current, previous: previous).frame(width: 76, alignment: .leading)
                        TrendDeviationChart().frame(minWidth: 206)
                    }
                }
                VStack(alignment: .leading, spacing: 16) {
                    trendSummary(current, previous: previous)
                    TrendDeviationChart()
                }
            }
        }
        .padding(24)
        .caregiverCard()
    }

    private func trendSummary(_ current: Int, previous: Int) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("\(current)").orbitDisplayFont(47, weight: .bold)
            Text("events").caregiverText(.secondary).foregroundStyle(.secondary)
            Text(percentChange(current, previous)).orbitDisplayFont(20).padding(.top, 16)
            Text("vs last month").caregiverText(.caption).foregroundStyle(.secondary)
        }
        .fixedSize(horizontal: false, vertical: true)
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
        let columns = (dynamicTypeSize.isAccessibilitySize || pageWidth < 380) ? [GridItem(.flexible())]
            : [GridItem(.flexible(), spacing: 18), GridItem(.flexible(), spacing: 18)]
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
                    .frame(width: 28, height: 28).background(OrbitStyle.pale, in: Circle())
                Text(metric.0).caregiverText(.caption).fixedSize(horizontal: false, vertical: true)
            }.frame(minHeight: 28, alignment: .leading)
            (dynamicTypeSize.isAccessibilitySize ? AnyLayout(VStackLayout(alignment: .leading, spacing: 8)) : AnyLayout(HStackLayout(alignment: .bottom, spacing: 4))) {
                metricSummary(metric).layoutPriority(1)
                if !dynamicTypeSize.isAccessibilitySize { Spacer(minLength: 0) }
                metricBars(metric)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 136, alignment: .leading)
        .padding(12)
        .caregiverCard(radius: 24, opacity: 0.13)
    }
    private func metricSummary(_ metric: (String, String, Int, Int, String)) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("\(metric.2)\(metric.4 == "%" ? "%" : "")").orbitDisplayFont(36, weight: .semibold)
            if metric.4 != "%" { Text(metric.4).caregiverText(.secondary).foregroundStyle(.secondary) }
            Text(metric.4 == "%" ? percentagePointChange(metric.2, metric.3) : percentChange(metric.2, metric.3))
                .orbitDisplayFont(17)
            Text("vs. last month").caregiverText(.caption).foregroundStyle(.secondary)
        }.fixedSize(horizontal: false, vertical: true)
    }
    private func metricBars(_ metric: (String, String, Int, Int, String)) -> some View {
        HStack(alignment: .bottom, spacing: 4) {
            bar(metric.3, maxValue: max(metric.2, metric.3), percent: metric.4 == "%", lighter: true)
            bar(metric.2, maxValue: max(metric.2, metric.3), percent: metric.4 == "%", lighter: false)
        }
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
