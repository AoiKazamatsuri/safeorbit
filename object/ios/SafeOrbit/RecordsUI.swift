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

    init(showTrendInitially: Bool = false) {
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
            Text("Recording")
                .font(.system(size: 27, weight: .semibold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 45, alignment: .center)
                .padding(.bottom, 5)
                .background(OrbitStyle.teal.ignoresSafeArea(edges: .top))
            ScrollView {
                VStack(spacing: 14) {
                    sectionPicker
                    if section == .data { dataContent }
                    else { trendContent }
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)
                .padding(.bottom, 112)
            }
            .background(.white, in: UnevenRoundedRectangle(topLeadingRadius: 29, topTrailingRadius: 29))
            .background(OrbitStyle.teal)
        }
        .background(.white)
        .background(OrbitStyle.teal.ignoresSafeArea(edges: .top))
        .fullScreenCover(item: $selectedTrip) { TripDetailPage(trip: $0) { selectedTrip = nil } }
    }

    private var sectionPicker: some View {
        HStack(spacing: 4) {
            ForEach(RecordsSection.allCases, id: \.self) { item in
                Button { section = item } label: {
                    Text(item.rawValue)
                        .font(.system(size: 20, weight: .medium))
                        .frame(maxWidth: .infinity).frame(height: 38)
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
            HStack(spacing: 8) {
                Button { shiftWeek(-1) } label: { Image(systemName: "chevron.left").frame(width: 26) }
                    .accessibilityLabel("Previous week")
                Text(selectedDay == nil ? "This Week" : dayTitle(selectedDay!))
                    .font(.system(size: 18, weight: .medium))
                if selectedDay != nil {
                    Button("Clear") { selectedDay = nil }.font(.caption)
                }
                Spacer()
                Text("\(shortDate(weekStart)) – \(shortDate(calendar.date(byAdding: .day, value: 6, to: weekStart)!))")
                    .font(.system(size: 13)).foregroundStyle(.secondary)
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
                Text(monthTitle(month)).font(.system(size: 19, weight: .medium))
                Spacer()
                Button { shiftMonth(1) } label: { Image(systemName: "chevron.right") }
                    .accessibilityLabel("Next month")
            }.buttonStyle(.plain)
            HStack(spacing: 0) {
                ForEach(["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"], id: \.self) { label in
                    Text(label).font(.system(size: 13)).foregroundStyle(.secondary)
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
                                .font(.system(size: 16, weight: selectedDay.map { calendar.isDate($0, inSameDayAs: date) } == true ? .semibold : .regular))
                                .foregroundStyle(risk == .high ? .white : .black)
                                .frame(width: 30, height: 30)
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
        .padding(17)
        .background(.white, in: RoundedRectangle(cornerRadius: 25))
        .shadow(color: .black.opacity(0.16), radius: 7, y: 3)
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
                        HStack(spacing: 9) {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(shortDate(trip.date)).font(.system(size: 16, weight: .medium)).foregroundStyle(.black)
                                Text(weekday(trip.date)).font(.caption).foregroundStyle(.secondary)
                            }.frame(width: 63, alignment: .leading)
                            Text(trip.risk == .high ? "Risk" : trip.risk.title)
                                .font(.system(size: 11, weight: .medium))
                                .padding(.horizontal, 8).padding(.vertical, 4)
                                .foregroundStyle(trip.risk == .high ? .white : .black)
                                .background(riskColor(trip.risk), in: Capsule())
                            VStack(alignment: .leading, spacing: 2) {
                                Text(trip.name).lineLimit(1)
                                    .font(.system(size: 12)).foregroundStyle(.black)
                                if trip.deviations > 0 {
                                    Text("Route Deviation").font(.system(size: 11)).foregroundStyle(.secondary)
                                }
                            }.frame(maxWidth: .infinity, alignment: .leading)
                            Text("\(trip.durationMinutes) min")
                                .font(.system(size: 11)).foregroundStyle(.black)
                            Image(systemName: "chevron.right").font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(.black)
                        }
                        .padding(.horizontal, 14).frame(minHeight: 59)
                    }.buttonStyle(.plain)
                    if index < min(weekTrips.count, expanded ? weekTrips.count : 4) - 1 {
                        Divider().padding(.horizontal, 12)
                    }
                }
                if weekTrips.count > 4 {
                    Button { expanded.toggle() } label: {
                        Label(expanded ? "View Less" : "View More", systemImage: expanded ? "chevron.up" : "chevron.down")
                            .font(.system(size: 16)).foregroundStyle(.black)
                            .frame(maxWidth: .infinity).padding(.vertical, 10)
                    }
                }
            }
        }
        .background(.white, in: RoundedRectangle(cornerRadius: 25))
        .shadow(color: .black.opacity(0.16), radius: 7, y: 3)
    }

    private var trendContent: some View {
        VStack(spacing: 16) {
            trendCard
            metricGrid
            Text(patternDescription)
                .font(.system(size: 16))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(20)
                .background(.white, in: RoundedRectangle(cornerRadius: 24))
                .shadow(color: .black.opacity(0.13), radius: 6, y: 3)
        }
    }

    private var trendCard: some View {
        let current = DemoRecords.trips.filter { $0.month == 8 }.reduce(0) { $0 + $1.deviations }
        let previous = DemoRecords.trips.filter { $0.month == 7 }.reduce(0) { $0 + $1.deviations }
        let values = DemoRecords.weeklyDeviations()
        let weekStarts = DemoRecords.weekStarts()
        return VStack(alignment: .leading, spacing: 12) {
            Text("Route Deviation Trend").font(.system(size: 22, weight: .semibold))
            HStack(alignment: .center, spacing: 8) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("\(current)").font(.system(size: 47, weight: .bold))
                    Text("events").foregroundStyle(.secondary)
                    Text(percentChange(current, previous))
                        .font(.system(size: 20, weight: .medium)).padding(.top, 8)
                    Text("vs last month").font(.caption).foregroundStyle(.secondary)
                }.frame(width: 115, alignment: .leading)
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
                .chartXAxis(.hidden)
                .chartYAxis {
                    AxisMarks(position: .leading, values: [0, 1, 2, 3])
                }
                .frame(height: 128)
                HStack(spacing: 0) {
                    ForEach(0..<8, id: \.self) { index in
                        Text("\(calendar.component(.month, from: weekStarts[index]) == 7 ? "Jul" : "Aug")\n\(calendar.component(.day, from: weekStarts[index]))")
                            .font(.system(size: 8)).multilineTextAlignment(.center)
                            .frame(maxWidth: .infinity)
                    }
                }.foregroundStyle(.secondary)
                }
            }
        }
        .padding(21)
        .background(.white, in: RoundedRectangle(cornerRadius: 25))
        .shadow(color: .black.opacity(0.16), radius: 7, y: 3)
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
                Image(systemName: metric.1).font(.system(size: 15))
                    .frame(width: 26, height: 26).background(OrbitStyle.pale, in: Circle())
                Text(metric.0).font(.system(size: 11, weight: .medium)).lineLimit(2)
            }.frame(height: 31, alignment: .leading)
            HStack(alignment: .bottom, spacing: 4) {
                VStack(alignment: .leading, spacing: 1) {
                    Text("\(metric.2)\(metric.4 == "%" ? "%" : "")")
                        .font(.system(size: 30, weight: .semibold)).minimumScaleFactor(0.7)
                    if metric.4 != "%" { Text(metric.4).font(.caption).foregroundStyle(.secondary) }
                }
                Spacer(minLength: 2)
                HStack(alignment: .bottom, spacing: 4) {
                    bar(metric.3, maxValue: max(metric.2, metric.3), lighter: true)
                    bar(metric.2, maxValue: max(metric.2, metric.3), lighter: false)
                }.frame(height: 43, alignment: .bottom)
            }
            Text(metric.4 == "%" ? percentagePointChange(metric.2, metric.3) : percentChange(metric.2, metric.3))
                .font(.system(size: 17, weight: .medium))
            Text("vs last month").font(.system(size: 11)).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 118, alignment: .leading)
        .padding(11)
        .background(.white, in: RoundedRectangle(cornerRadius: 24))
        .shadow(color: .black.opacity(0.13), radius: 6, y: 3)
    }

    private func bar(_ value: Int, maxValue: Int, lighter: Bool) -> some View {
        VStack(spacing: 2) {
            Text("\(value)\(maxValue > 10 ? "%" : "")").font(.system(size: 9))
                .foregroundStyle(OrbitStyle.teal)
            RoundedRectangle(cornerRadius: 3)
                .fill(lighter ? OrbitStyle.pale : OrbitStyle.teal.opacity(0.65))
                .frame(width: 22, height: CGFloat(max(8, value * 32 / max(1, maxValue))))
        }
    }

    private var patternDescription: String {
        let august = DemoRecords.trips.filter { $0.month == 8 }
        let monday = august.filter { calendar.component(.weekday, from: $0.date) == 2 }.count
        return "In August 2026, \(monday) of \(august.count) market trips started on a Monday morning. Most trips began around 9 AM."
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
            HStack(spacing: 12) {
                Button(action: back) { Image(systemName: "chevron.left")
                    .font(.system(size: 21, weight: .semibold)) }
                    .accessibilityLabel("Back to records")
                Text("\(trip.month == 8 ? "Aug" : "Jul") \(trip.day)").font(.system(size: 25, weight: .semibold))
                Spacer()
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 23).frame(height: 45, alignment: .center)
            .padding(.bottom, 5)
            .background(OrbitStyle.teal.ignoresSafeArea(edges: .top))
            Map(initialPosition: .region(region)) {
                MapPolyline(coordinates: route)
                    .stroke(OrbitStyle.teal, style: StrokeStyle(lineWidth: 4, lineCap: .round, dash: [6, 5]))
                Annotation("Home", coordinate: route.first!) {
                    Image(systemName: "house.fill").font(.system(size: 18))
                        .foregroundStyle(.white).padding(10).background(OrbitStyle.teal, in: Circle())
                }
                Annotation("Market", coordinate: route.last!) {
                    Image(systemName: "storefront.fill").font(.system(size: 18))
                        .foregroundStyle(.white).padding(10).background(OrbitStyle.teal, in: Circle())
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
                                }.font(.system(size: 16))
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
        .background(OrbitStyle.teal.ignoresSafeArea(edges: .top))
    }

    @ViewBuilder private var summaryPills: some View {
        pill(trip.name)
        pill("\(trip.deviations) \(trip.deviations == 1 ? "deviation" : "deviations")")
        pill("\(trip.calls) \(trip.calls == 1 ? "call" : "calls")")
    }
    private func pill(_ text: String) -> some View {
        Text(text).font(.system(size: 14)).lineLimit(1)
            .padding(.horizontal, 10).padding(.vertical, 5)
            .background(OrbitStyle.pale, in: Capsule())
    }
    private func time(_ minute: Int) -> String {
        let hour = (minute / 60) % 24
        return String(format: "%d:%02d %@", hour % 12 == 0 ? 12 : hour % 12,
                      minute % 60, hour < 12 ? "AM" : "PM")
    }
}
