import Foundation

enum TripRisk: Int, CaseIterable {
    case normal, warning, high

    var title: String {
        switch self {
        case .normal: "Normal"
        case .warning: "Warning"
        case .high: "High Risk"
        }
    }
}

struct TripEvent: Identifiable {
    let id: String
    let minute: Int
    let title: String
}

struct DemoTrip: Identifiable {
    let id: String
    let date: Date
    let name: String
    let risk: TripRisk
    let durationMinutes: Int
    let deviations: Int
    let calls: Int
    let unusualMovement: Bool
    let navigationAssisted: Bool
    let returnedHome: Bool
    let incomplete: Bool
    let events: [TripEvent]

    var day: Int { DemoRecords.calendar.component(.day, from: date) }
    var month: Int { DemoRecords.calendar.component(.month, from: date) }
    var year: Int { DemoRecords.calendar.component(.year, from: date) }
}

enum DemoRecords {
    static var calendar: Calendar {
        var result = Calendar(identifier: .gregorian)
        result.timeZone = TimeZone(identifier: "Asia/Shanghai")!
        result.firstWeekday = 1
        return result
    }

    static func date(_ year: Int = 2026, _ month: Int, _ day: Int, _ hour: Int = 9, _ minute: Int = 5) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour, minute: minute))!
    }

    private static func trip(_ month: Int, _ day: Int, risk: TripRisk, deviations: Int = 0,
                             calls: Int = 0, unusual: Bool = false, navigation: Bool = false,
                             home: Bool = true, incomplete: Bool = false) -> DemoTrip {
        let start = day == 24 && month == 8 ? 9 * 60 + 5 : 9 * 60 + (day % 4) * 5
        let total = day == 25 && month == 8 ? 17 : risk == .normal ? 34 : 80
        let labels: [(Int, String)] = deviations > 0 ? [
            (0, "Left home"), (13, "Arrived at market"),
            (43, "Route deviation detected"), (51, "Agent check-in sent"),
            (57, calls > 0 ? "Caregiver call started" : "Walking on familiar route"),
            (total, home ? "Returned home" : "Trip ended")
        ] : [
            (0, "Left home"), (min(13, total - 4), "Arrived at market"),
            (total, home ? "Returned home" : "Trip ended")
        ]
        return DemoTrip(id: "2026-\(String(format: "%02d", month))-\(String(format: "%02d", day))",
                        date: date(2026, month, day, start / 60, start % 60),
                        name: "Home–Market–Home", risk: risk, durationMinutes: total,
                        deviations: deviations, calls: calls, unusualMovement: unusual,
                        navigationAssisted: navigation, returnedHome: home,
                        incomplete: incomplete,
                        events: labels.enumerated().map { index, value in
                            TripEvent(id: "\(month)-\(day)-\(index)", minute: start + value.0, title: value.1)
                        })
    }

    static let trips: [DemoTrip] = [
        trip(7, 7, risk: .normal, navigation: true), trip(7, 13, risk: .warning, deviations: 2, navigation: true),
        trip(7, 18, risk: .normal), trip(7, 22, risk: .high, deviations: 1, calls: 1, unusual: true),
        trip(7, 29, risk: .warning, deviations: 2),
        trip(8, 3, risk: .normal), trip(8, 4, risk: .normal),
        trip(8, 5, risk: .normal), trip(8, 10, risk: .normal),
        trip(8, 12, risk: .normal, incomplete: true),
        trip(8, 13, risk: .normal), trip(8, 14, risk: .normal),
        trip(8, 15, risk: .normal),
        trip(8, 18, risk: .warning, deviations: 1),
        trip(8, 20, risk: .high, deviations: 1, calls: 1, unusual: true),
        trip(8, 21, risk: .normal), trip(8, 22, risk: .normal),
        trip(8, 24, risk: .high, deviations: 1, calls: 1, unusual: true, navigation: true),
        trip(8, 25, risk: .normal),
        trip(8, 26, risk: .warning, deviations: 1),
        trip(8, 27, risk: .normal), trip(8, 28, risk: .normal)
    ]

    private static let routeOnMap: [GeoPoint] = [
        GeoPoint(latitude: 32.0599101, longitude: 118.7677551),
        GeoPoint(latitude: 32.0597504, longitude: 118.7689515),
        GeoPoint(latitude: 32.0595408, longitude: 118.7706009),
        GeoPoint(latitude: 32.0587606, longitude: 118.7709242),
        GeoPoint(latitude: 32.0576466, longitude: 118.7712769),
        GeoPoint(latitude: 32.0564731, longitude: 118.7718559)
    ]
    static let route = routeOnMap.map(MainlandCoordinates.toWGS84)

    static func trips(on day: Date) -> [DemoTrip] {
        trips.filter { calendar.isDate($0.date, inSameDayAs: day) }
    }

    static func highestRisk(on day: Date) -> TripRisk? {
        trips(on: day).map(\.risk).max { $0.rawValue < $1.rawValue }
    }

    static func count(month: Int, _ predicate: (DemoTrip) -> Bool) -> Int {
        trips.filter { $0.month == month && predicate($0) }.count
    }

    static func safeReturnRate(month: Int) -> Int {
        let affected = trips.filter { $0.month == month && $0.risk != .normal }
        guard !affected.isEmpty else { return 0 }
        return Int((100.0 * Double(affected.filter { $0.returnedHome && $0.risk != .high }.count)
                    / Double(affected.count)).rounded())
    }

    static func weekStarts(endingAt lastDay: Date = date(2026, 8, 29)) -> [Date] {
        let weekStart = calendar.dateInterval(of: .weekOfYear, for: lastDay)!.start
        return (0..<8).map { offset in
            calendar.date(byAdding: .weekOfYear, value: offset - 7, to: weekStart)!
        }
    }

    static func weeklyDeviations(endingAt lastDay: Date = date(2026, 8, 29)) -> [Int] {
        weekStarts(endingAt: lastDay).map { start in
            let end = calendar.date(byAdding: .day, value: 7, to: start)!
            return trips.filter { $0.date >= start && $0.date < end }.reduce(0) { $0 + $1.deviations }
        }
    }

    static let quickQuestions = [
        "When was the last high-risk event?",
        "How many route deviations happened in August?",
        "Has unusual movement increased?"
    ]

    static func answer(to question: String, allowTripHistory: Bool = true) -> String {
        let text = question.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let chinese = text.unicodeScalars.contains { (0x4E00...0x9FFF).contains($0.value) }
        guard allowTripHistory else {
            return chinese ? "已关闭 AI 使用出行记录。可以在 AI 设置中开启。" : "Trip history access is off. You can enable it in AI Settings."
        }
        if text.contains("high-risk") || text.contains("high risk") || text.contains("走失") || text.contains("高风险") {
            guard let latest = trips.filter({ $0.risk == .high }).max(by: { $0.date < $1.date }) else {
                return chinese ? "演示回答：样例记录中没有高风险出行。" : "Demo answer: No high-risk trip appears in the sample records."
            }
            if chinese {
                return "演示回答：最近一次高风险出行是 2026 年 8 月 \(latest.day) 日；发生 \(latest.deviations) 次路线偏离和 \(latest.calls) 次家属通话，出行 \(latest.durationMinutes) 分钟后回到家。"
            }
            return "Demo answer: The latest high-risk trip was on August \(latest.day), 2026. There \(latest.deviations == 1 ? "was 1 route deviation" : "were \(latest.deviations) route deviations") and \(latest.calls) caregiver call was started. The trip lasted \(latest.durationMinutes) minutes and ended at home."
        }
        if text.contains("deviation") || text.contains("偏离") {
            let total = trips.filter { $0.month == 8 }.reduce(0) { $0 + $1.deviations }
            if chinese { return "演示回答：2026 年 8 月 1 日至 31 日，样例记录中共有 \(total) 次路线偏离。" }
            return "Demo answer: From August 1–31, 2026, the sample records contain \(total) route deviations."
        }
        if text.contains("unusual") || text.contains("wandering") || text.contains("徘徊") || text.contains("异常移动") {
            let current = count(month: 8) { $0.unusualMovement }
            let previous = count(month: 7) { $0.unusualMovement }
            if chinese { return "演示回答：2026 年 8 月样例记录有 \(current) 次异常移动，7 月有 \(previous) 次。" }
            return "Demo answer: Unusual movement appears \(current) times in August 2026, compared with \(previous) time in July 2026."
        }
        return chinese ? "现有样例记录无法核对这个问题的答案。可以试试常用问题。" : "I don't have a verified answer for that question in the available sample records. Try one of the suggested questions."
    }
}
