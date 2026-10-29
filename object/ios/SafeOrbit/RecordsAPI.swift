import Foundation
import Combine

extension TripRisk: Decodable {
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        switch try container.decode(String.self) {
        case "normal": self = .normal
        case "warning": self = .warning
        case "high": self = .high
        default: throw DecodingError.dataCorruptedError(in: container, debugDescription: "Unknown trip risk")
        }
    }
}

struct RecordTrip: Decodable, Identifiable {
    let id: String
    let name: String
    let startedAt: Date
    let endedAt: Date?
    let startKnown: Bool
    let risk: TripRisk
    let anomalies: [String]
    let durationMinutes: Int
    let deviations: Int
    let calls: Int
    let returnedHome: Bool
    var date: Date { startedAt }
    var anomalyLabels: String {
        anomalies.map { kind in
            switch kind {
            case "deviation": "Route Deviation"
            case "wandering": "Wandering"
            default: kind.replacingOccurrences(of: "_", with: " ").capitalized
            }
        }.joined(separator: ", ")
    }
}
struct RecordsResponse: Decodable {
    struct Day: Decodable { let date: String; let risk: TripRisk }
    let timezone: String
    let month: String
    let weekStart: String
    let days: [Day]
    let trips: [RecordTrip]
}
struct RecordComparison: Decodable { let current: Int; let previous: Int }
struct RecordWeek: Decodable { let start: String; let deviations: Int }
struct RecordTrends: Decodable {
    struct Metrics: Decodable {
        let unusualMovement: RecordComparison
        let navigationAssistance: RecordComparison
        let highRisk: RecordComparison
        let safeReturnRate: RecordComparison
    }
    let timezone: String
    let month: String
    let previousMonth: String
    let weeks: [RecordWeek]
    let deviations: RecordComparison
    let metrics: Metrics
    let pattern: String
}
struct RecordTripDetail: Decodable {
    struct Anomaly: Decodable {
        let kind: String
        let at: Date
        let latitude: Double
        let longitude: Double
        var point: GeoPoint { GeoPoint(latitude: latitude, longitude: longitude) }
    }
    struct Event: Decodable, Identifiable { let id: String; let at: Date; let title: String }
    let trip: RecordTrip
    let trail: [GeoPoint]
    let anomalies: [Anomaly]
    let timeline: [Event]
}

enum RecordsFailure: Error, LocalizedError, Equatable {
    case credentials, forbidden, notFound, invalidInput, unavailable, network, invalidResponse
    var errorDescription: String? {
        switch self {
        case .credentials: "Could not verify this phone. Try again."
        case .forbidden: "Records are available on the caregiver phone."
        case .notFound: "This trip is no longer available."
        case .invalidInput: "Could not load this date range. Try again."
        case .unavailable: "Records are temporarily unavailable. Try again."
        case .network: "Check your connection and try again."
        case .invalidResponse: "Could not read the records. Try again."
        }
    }
}

@MainActor protocol RecordsServing {
    func prepareTimezone() async throws -> String?
    func records(month: String, week: String) async throws -> RecordsResponse
    func trends(month: String) async throws -> RecordTrends
    func trip(id: String) async throws -> RecordTripDetail
}

extension RecordsServing {
    func prepareTimezone() async throws -> String? { nil }
}

@MainActor struct RecordsAPI: RecordsServing {
    let device: DemoDevice
    private let registration: RecordsRegistration
    init(device: DemoDevice) { self.device = device; registration = RecordsRegistration(device: device) }
    func prepareTimezone() async throws -> String? {
        try await registration.prepare()
        return device.household?.elder.timezone
    }
    func records(month: String, week: String) async throws -> RecordsResponse {
        try await request("records", query: [URLQueryItem(name: "month", value: month), URLQueryItem(name: "week", value: week)])
    }
    func trends(month: String) async throws -> RecordTrends {
        try await request("trends", query: [URLQueryItem(name: "month", value: month)])
    }
    func trip(id: String) async throws -> RecordTripDetail {
        guard !id.isEmpty, id.allSatisfy(\.isNumber) else { throw RecordsFailure.invalidInput }
        return try await request("trips/" + id)
    }
    private func request<T: Decodable>(_ path: String, query: [URLQueryItem] = [], retry: Bool = true) async throws -> T {
        try await registration.prepare()
        let sentToken = device.token
        var components = URLComponents(url: device.api.baseURL.appendingPathComponent("v1").appendingPathComponent(path), resolvingAgainstBaseURL: false)!
        components.queryItems = query.isEmpty ? nil : query
        guard let url = components.url else { throw RecordsFailure.invalidInput }
        var request = URLRequest(url: url)
        request.timeoutInterval = 15
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.setValue("Bearer \(device.token ?? "")", forHTTPHeaderField: "Authorization")
        let data: Data; let response: URLResponse
        do { (data, response) = try await device.api.session.data(for: request) }
        catch {
            if error is CancellationError || (error as? URLError)?.code == .cancelled { throw CancellationError() }
            throw RecordsFailure.network
        }
        guard let http = response as? HTTPURLResponse else { throw RecordsFailure.invalidResponse }
        if http.statusCode == 401 && retry {
            // Concurrent record/trend failures share one refresh. A request rejected with an
            // older token reuses the replacement already obtained by the other request.
            if sentToken == device.token { try await registration.prepare(force: true) }
            return try await self.request(path, query: query, retry: false)
        }
        guard (200..<300).contains(http.statusCode) else {
            switch http.statusCode {
            case 400: throw RecordsFailure.invalidInput
            case 401: throw RecordsFailure.credentials
            case 403: throw RecordsFailure.forbidden
            case 404: throw RecordsFailure.notFound
            case 503: throw RecordsFailure.unavailable
            default: throw RecordsFailure.invalidResponse
            }
        }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let value = try decoder.singleValueContainer().decode(String.self)
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if let date = formatter.date(from: value) { return date }
            formatter.formatOptions = [.withInternetDateTime]
            if let date = formatter.date(from: value) { return date }
            throw DecodingError.dataCorrupted(.init(codingPath: decoder.codingPath, debugDescription: "Invalid timestamp"))
        }
        do { return try decoder.decode(T.self, from: data) }
        catch { throw RecordsFailure.invalidResponse }
    }
}

@MainActor private final class RecordsRegistration {
    let device: DemoDevice
    private var pending: Task<Void, Error>?
    init(device: DemoDevice) { self.device = device }
    func prepare(force: Bool = false) async throws {
        if let pending { return try await pending.value }
        guard force || device.token == nil else { return }
        let task = Task { @MainActor in
            do { try await device.register() }
            catch is CancellationError { throw CancellationError() }
            catch let failure as APIError {
                switch failure.kind {
                case .unauthorized: throw RecordsFailure.credentials
                case .network: throw RecordsFailure.network
                case .unavailable: throw RecordsFailure.unavailable
                default: throw RecordsFailure.invalidResponse
                }
            }
        }
        pending = task
        defer { pending = nil }
        try await task.value
    }
}

enum RecordDates {
    static func calendar(_ timezone: String) -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: timezone) ?? TimeZone(secondsFromGMT: 0)!
        calendar.firstWeekday = 2
        calendar.minimumDaysInFirstWeek = 4
        return calendar
    }
    static func format(_ date: Date, _ pattern: String, timezone: String) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = calendar(timezone)
        formatter.timeZone = formatter.calendar.timeZone
        formatter.dateFormat = pattern
        return formatter.string(from: date)
    }
    static func date(_ value: String, timezone: String) -> Date? {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = calendar(timezone)
        formatter.timeZone = formatter.calendar.timeZone
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.date(from: value)
    }
}

@MainActor final class RecordsStore: ObservableObject {
    @Published private(set) var month: Date
    @Published private(set) var weekStart: Date
    @Published private(set) var timezone: String
    @Published private(set) var records: RecordsResponse?
    @Published private(set) var trends: RecordTrends?
    @Published private(set) var recordsError: String?
    @Published private(set) var trendsError: String?
    @Published private(set) var loading = false
    let service: (any RecordsServing)?
    let now: () -> Date
    private var generation = 0
    private var selectedRange = false
    var calendar: Calendar { RecordDates.calendar(timezone) }
    var monthKey: String { RecordDates.format(month, "yyyy-MM", timezone: timezone) }
    var weekKey: String { RecordDates.format(weekStart, "yyyy-MM-dd", timezone: timezone) }
    var queryKey: String { monthKey + ":" + weekKey }
    var currentWeekStart: Date { calendar.dateInterval(of: .weekOfYear, for: now())!.start }
    init(service: (any RecordsServing)?, timezone: String, now: @escaping () -> Date = Date.init) {
        self.service = service; self.timezone = timezone; self.now = now
        let calendar = RecordDates.calendar(timezone)
        month = calendar.dateInterval(of: .month, for: now())!.start
        weekStart = calendar.dateInterval(of: .weekOfYear, for: now())!.start
    }
    func shiftMonth(_ amount: Int) {
        selectedRange = true
        month = calendar.date(byAdding: .month, value: amount, to: month)!
        invalidate()
    }
    func shiftWeek(_ amount: Int) {
        selectedRange = true
        weekStart = calendar.date(byAdding: .weekOfYear, value: amount, to: weekStart)!
        month = calendar.dateInterval(of: .month, for: weekStart)!.start
        invalidate()
    }
    func selectDay(_ date: Date) {
        selectedRange = true
        weekStart = calendar.dateInterval(of: .weekOfYear, for: date)!.start
        invalidate()
    }
    private func invalidate() {
        generation += 1
        records = nil; trends = nil; recordsError = nil; trendsError = nil
#if DEBUG
        if isPreview { updatePreview() }
#endif
    }
    func reload() async {
#if DEBUG
        if isPreview { return }
#endif
        guard let service else {
            records = nil; trends = nil
            recordsError = "Connect the caregiver phone to load records."
            trendsError = recordsError
            return
        }
        generation += 1
        let version = generation
        loading = true
        do {
            if let zone = try await service.prepareTimezone(), zone != timezone {
                guard version == generation, !Task.isCancelled else { return }
                let previousMonth = monthKey, previousWeek = weekKey
                timezone = zone
                if selectedRange {
                    month = RecordDates.date(previousMonth + "-01", timezone: zone) ?? month
                    weekStart = RecordDates.date(previousWeek, timezone: zone) ?? weekStart
                } else {
                    month = calendar.dateInterval(of: .month, for: now())!.start
                    weekStart = calendar.dateInterval(of: .weekOfYear, for: now())!.start
                }
            }
        } catch {
            guard version == generation else { return }
            loading = false
            guard !Task.isCancelled else { return }
            records = nil; trends = nil
            recordsError = error.localizedDescription; trendsError = recordsError
            return
        }
        guard version == generation, !Task.isCancelled else {
            if version == generation { loading = false }
            return
        }
        let month = monthKey, week = weekKey
        async let recordResult = capture { try await service.records(month: month, week: week) }
        async let trendResult = capture { try await service.trends(month: month) }
        let (record, trend) = await (recordResult, trendResult)
        guard version == generation else { return }
        loading = false
        guard !Task.isCancelled else { return }
        switch record {
        case .success(let value): records = value; recordsError = nil
        case .failure(let error): records = nil; recordsError = error.localizedDescription
        }
        switch trend {
        case .success(let value): trends = value; trendsError = nil
        case .failure(let error): trends = nil; trendsError = error.localizedDescription
        }
    }
    private func capture<T>(_ operation: () async throws -> T) async -> Result<T, Error> {
        do { return .success(try await operation()) } catch { return .failure(error) }
    }
#if DEBUG
    var isPreview = false
    static func preview() -> RecordsStore {
        let store = RecordsStore(service: nil, timezone: "Asia/Shanghai", now: { DemoRecords.date(2026, 8, 29) })
        store.isPreview = true
        store.updatePreview()
        return store
    }
    private func updatePreview() {
        records = .init(timezone: timezone, month: monthKey, weekStart: weekKey,
            days: (1...31).compactMap { day in
                guard let date = RecordDates.date(monthKey + String(format: "-%02d", day), timezone: timezone),
                      let risk = DemoRecords.highestRisk(on: date) else { return nil }
                return .init(date: RecordDates.format(date, "yyyy-MM-dd", timezone: timezone), risk: risk)
            }, trips: DemoRecords.trips.filter {
                $0.date >= weekStart && $0.date < calendar.date(byAdding: .day, value: 7, to: weekStart)!
            }.map { RecordTrip(preview: $0) })
        trends = .preview
    }
#endif
}

@MainActor final class RecordDetailStore: ObservableObject {
    @Published private(set) var detail: RecordTripDetail?
    @Published private(set) var error: String?
    @Published private(set) var loading = false
    let service: (any RecordsServing)?
    private var generation = 0
    init(service: (any RecordsServing)?, detail: RecordTripDetail? = nil) { self.service = service; self.detail = detail }
    func reload(id: String) async {
        guard let service else {
            if detail == nil { error = "Connect the caregiver phone to load this trip." }
            return
        }
        generation += 1
        let version = generation
        detail = nil; loading = true; error = nil
        do {
            let value = try await service.trip(id: id)
            guard version == generation else { return }
            guard !Task.isCancelled else { loading = false; return }
            detail = value
        } catch {
            guard version == generation else { return }
            guard !Task.isCancelled else { loading = false; return }
            detail = nil; self.error = error.localizedDescription
        }
        loading = false
    }
}
