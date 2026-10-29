import XCTest
import SwiftUI
@testable import SafeOrbit

final class RecordsAPITests: XCTestCase {
    private var session: URLSession!
    private var defaults: UserDefaults!
    private var suite: String!
    override func setUp() {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [StubURLProtocol.self]
        session = URLSession(configuration: config)
        suite = "org.safeorbit.records.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suite)
    }
    override func tearDown() {
        StubURLProtocol.handler = nil
        session.invalidateAndCancel()
        defaults.removePersistentDomain(forName: suite)
    }
    @MainActor private func api() -> RecordsAPI {
        RecordsAPI(device: DemoDevice(role: .caregiver,
            api: OnboardingAPI(baseURL: URL(string: "http://records.test")!, session: session), defaults: defaults))
    }
    private static let registration = Data(#"{"deviceToken":"records-token","role":"caregiver","household":{"elder":{"name":"Li","callName":"Grandma","phone":"100","timezone":"Asia/Shanghai"},"caregiver":{"name":"Wang","phone":"101"}}}"#.utf8)
    private static let tripJSON = #"{"id":"81","name":"Home–Market–Home","startedAt":"2026-10-26T01:00:00.123Z","endedAt":null,"startKnown":false,"risk":"warning","anomalies":["deviation","wandering"],"durationMinutes":40,"deviations":3,"calls":2,"returnedHome":false}"#
    private static let recordsJSON = #"{"timezone":"Asia/Shanghai","month":"2026-10","weekStart":"2026-10-26","days":[{"date":"2026-10-26","risk":"high"}],"trips":[\#(tripJSON)]}"#
    private static let trendsJSON = #"{"timezone":"Asia/Shanghai","month":"2026-10","previousMonth":"2026-09","weeks":[{"start":"2026-09-07","deviations":0},{"start":"2026-09-14","deviations":7},{"start":"2026-09-21","deviations":1},{"start":"2026-09-28","deviations":8},{"start":"2026-10-05","deviations":2},{"start":"2026-10-12","deviations":9},{"start":"2026-10-19","deviations":3},{"start":"2026-10-26","deviations":10}],"deviations":{"current":24,"previous":16},"metrics":{"unusualMovement":{"current":18,"previous":3},"navigationAssistance":{"current":4,"previous":0},"highRisk":{"current":2,"previous":1},"safeReturnRate":{"current":67,"previous":50}},"pattern":"Based on recorded trips, morning visits are common."}"#

    @MainActor func testHTTPContractUsesDeviceTokenAndDecodesAllThreeEndpoints() async throws {
        var seen: [URLRequest] = []
        StubURLProtocol.handler = { request in
            seen.append(request)
            if request.url!.path == "/v1/devices" { return (200, Self.registration) }
            XCTAssertEqual(request.httpMethod, "GET")
            XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer records-token")
            switch request.url!.path {
            case "/v1/records": return (200, Data(Self.recordsJSON.utf8))
            case "/v1/trends": return (200, Data(Self.trendsJSON.utf8))
            case "/v1/trips/81":
                let points = (0..<301).map { #"{"latitude":32.0,"longitude":\#(118 + Double($0) / 10000)}"# }.joined(separator: ",")
                return (200, Data(#"{"trip":\#(Self.tripJSON),"trail":[\#(points)],"anomalies":[{"kind":"deviation","at":"2026-10-26T01:10:00Z","latitude":32.0,"longitude":118.0}],"timeline":[{"id":"call-1","at":"2026-10-26T01:12:00.000Z","title":"Call initiated"}]}"#.utf8))
            default: XCTFail("Unexpected path"); return (404, Data())
            }
        }
        let api = api()
        let records = try await api.records(month: "2026-10", week: "2026-10-26")
        let trends = try await api.trends(month: "2026-10")
        let detail = try await api.trip(id: "81")
        XCTAssertEqual(seen.map { $0.url!.path }, ["/v1/devices", "/v1/records", "/v1/trends", "/v1/trips/81"])
        XCTAssertEqual(URLComponents(url: seen[1].url!, resolvingAgainstBaseURL: false)?.queryItems,
            [URLQueryItem(name: "month", value: "2026-10"), URLQueryItem(name: "week", value: "2026-10-26")])
        XCTAssertEqual(records.days.first?.risk, .high)
        XCTAssertEqual(records.trips.first?.anomalyLabels, "Route Deviation, Wandering")
        XCTAssertNil(records.trips.first?.endedAt)
        XCTAssertEqual(trends.weeks.map(\.deviations), [0, 7, 1, 8, 2, 9, 3, 10])
        XCTAssertEqual(trends.metrics.safeReturnRate.current, 67)
        XCTAssertEqual(trends.metrics.navigationAssistance.current, 4)
        XCTAssertEqual(detail.trail.count, 301, "Complete trail must not be capped to recent points")
        XCTAssertEqual(detail.trip.calls, 2)
        XCTAssertEqual(detail.timeline.first?.title, "Call initiated")
        XCTAssertEqual(RecordDates.format(detail.anomalies[0].at, "HH:mm", timezone: records.timezone), "09:10")
        XCTAssertEqual(TrendAxisDate.labels(weeks: trends.weeks, timezone: trends.timezone).map(\.fullLabel),
                       ["Sep 7", "Sep 14", "Sep 21", "Sep 28", "Oct 5", "Oct 12", "Oct 19", "Oct 26"])
    }

    @MainActor func testConcurrentFirstLoadsShareOneRegistration() async throws {
        var registrations = 0
        StubURLProtocol.handler = { request in
            if request.url!.path == "/v1/devices" {
                registrations += 1
                return (200, Self.registration)
            }
            XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer records-token")
            return (200, Data((request.url!.path == "/v1/records" ? Self.recordsJSON : Self.trendsJSON).utf8))
        }
        let api = api()
        async let records = api.records(month: "2026-10", week: "2026-10-26")
        async let trends = api.trends(month: "2026-10")
        let (recordValue, trendValue) = try await (records, trends)
        XCTAssertEqual(registrations, 1)
        XCTAssertEqual(recordValue.trips.count, 1)
        XCTAssertEqual(trendValue.weeks.count, 8)
    }

    @MainActor func testHTTPFailuresAreSpecificAndNeverBecomeSampleData() async throws {
        let api = api()
        for (status, expected) in [(400, RecordsFailure.invalidInput), (401, .credentials), (403, .forbidden), (404, .notFound), (503, .unavailable), (500, .invalidResponse)] {
            StubURLProtocol.handler = { request in
                request.url!.path == "/v1/devices" ? (200, Self.registration) : (status, Data())
            }
            do { _ = try await api.records(month: "2026-10", week: "2026-10-26"); XCTFail("Expected \(status)") }
            catch let error as RecordsFailure { XCTAssertEqual(error, expected) }
        }
        StubURLProtocol.handler = { _ in throw URLError(.notConnectedToInternet) }
        do { _ = try await api.trends(month: "2026-10"); XCTFail("Expected connection error") }
        catch let error as RecordsFailure { XCTAssertEqual(error, .network) }
    }

    @MainActor func testExpiredTokenRegistersOnceThenRetriesOriginalQuery() async throws {
        var registrations = 0, queries: [String?] = []
        StubURLProtocol.handler = { request in
            if request.url!.path == "/v1/devices" { registrations += 1; return (200, Self.registration) }
            queries.append(request.url!.query)
            return queries.count == 1 ? (401, Data()) : (200, Data(Self.recordsJSON.utf8))
        }
        _ = try await api().records(month: "2026-10", week: "2026-10-26")
        XCTAssertEqual(registrations, 2)
        XCTAssertEqual(queries.count, 2)
        XCTAssertEqual(queries.first!, queries.last!)
    }

    @MainActor func testMalformedTimestampAndUnknownRiskAreRejected() async throws {
        let api = api()
        for body in [Self.recordsJSON.replacingOccurrences(of: "2026-10-26T01:00:00.123Z", with: "not-a-date"),
                     Self.recordsJSON.replacingOccurrences(of: "warning", with: "unknown"), "{}"] {
            StubURLProtocol.handler = { request in
                request.url!.path == "/v1/devices" ? (200, Self.registration) : (200, Data(body.utf8))
            }
            do { _ = try await api.records(month: "2026-10", week: "2026-10-26"); XCTFail("Expected invalid response") }
            catch let error as RecordsFailure { XCTAssertEqual(error, .invalidResponse) }
        }
    }

    @MainActor func testEmptyResponseStaysEmptyAndInvalidIDNeverRequestsNetwork() async throws {
        var calls = 0
        StubURLProtocol.handler = { request in
            calls += 1
            if request.url!.path == "/v1/devices" { return (200, Self.registration) }
            return (200, Data(#"{"trip":\#(Self.tripJSON),"trail":[],"anomalies":[],"timeline":[]}"#.utf8))
        }
        let api = api()
        for id in ["", "../records", "1?month=2026-10"] {
            do { _ = try await api.trip(id: id); XCTFail("Expected invalid ID") }
            catch let error as RecordsFailure { XCTAssertEqual(error, .invalidInput) }
        }
        XCTAssertEqual(calls, 0)
        let detail = try await api.trip(id: "81")
        XCTAssertTrue(detail.trail.isEmpty)
        XCTAssertTrue(detail.timeline.isEmpty)
        let store = RecordDetailStore(service: nil, detail: detail)
        XCTAssertTrue(try XCTUnwrap(store.detail).anomalies.isEmpty)
        let page = TripDetailPage(trip: detail.trip, timezone: "Asia/Shanghai", service: nil, back: {})
        XCTAssertTrue(page.trailLines.isEmpty)
    }

    @MainActor func testDefaultRangeUsesRegisteredElderTimezoneAcrossMonthAndWeekBoundary() async throws {
        let now = ISO8601DateFormatter().date(from: "2026-05-31T16:30:00Z")!
        var keys: [String] = []
        StubURLProtocol.handler = { request in
            if request.url!.path == "/v1/devices" { return (200, Self.registration) }
            keys.append(request.url!.query ?? "")
            if request.url!.path == "/v1/trends" { return (200, Data(Self.trendsJSON.utf8)) }
            return (200, Data(#"{"timezone":"Asia/Shanghai","month":"2026-06","weekStart":"2026-06-01","days":[],"trips":[]}"#.utf8))
        }
        let store = RecordsStore(service: api(), timezone: "UTC", now: { now })
        await store.reload()
        XCTAssertEqual(store.timezone, "Asia/Shanghai")
        XCTAssertEqual(store.monthKey, "2026-06")
        XCTAssertEqual(store.weekKey, "2026-06-01")
        XCTAssertTrue(keys.contains("month=2026-06&week=2026-06-01"))
        XCTAssertTrue(store.records?.trips.isEmpty == true)
    }

    @MainActor func testWeekNavigationPreservesLocalMidnightThroughDSTAndYearBoundary() {
        let service = RecordsServiceStub()
        let store = RecordsStore(service: service, timezone: "America/New_York",
                                 now: { ISO8601DateFormatter().date(from: "2026-03-08T20:00:00Z")! })
        XCTAssertEqual(store.weekKey, "2026-03-02")
        store.shiftWeek(1)
        XCTAssertEqual(store.weekKey, "2026-03-09")
        XCTAssertEqual(store.calendar.component(.hour, from: store.weekStart), 0)
        store.selectDay(RecordDates.date("2027-01-01", timezone: store.timezone)!)
        XCTAssertEqual(store.weekKey, "2026-12-28")
        store.shiftWeek(1)
        XCTAssertEqual(store.weekKey, "2027-01-04")
        XCTAssertEqual(store.monthKey, "2027-01")
        store.shiftMonth(-1)
        XCTAssertEqual(store.monthKey, "2026-12")
    }

    @MainActor func testOlderResponseCannotOverwriteNewSelection() async throws {
        let service = RecordsServiceStub(); service.suspendRecords = true
        let store = RecordsStore(service: service, timezone: "UTC", now: { RecordDates.date("2026-10-26", timezone: "UTC")! })
        let old = Task { await store.reload() }
        while service.pending.count < 1 { await Task.yield() }
        store.shiftWeek(-1)
        XCTAssertNil(store.records)
        let new = Task { await store.reload() }
        while service.pending.count < 2 { await Task.yield() }
        service.resume(1); await new.value
        XCTAssertEqual(store.records?.weekStart, "2026-10-19")
        service.resume(0); await old.value
        XCTAssertEqual(store.records?.weekStart, "2026-10-19")
        XCTAssertFalse(store.loading)
    }

    @MainActor func testFailureClearsPreviouslyLoadedDataAndAllowsIndependentTrendSuccess() async throws {
        let service = RecordsServiceStub()
        let store = RecordsStore(service: service, timezone: "UTC")
        await store.reload()
        XCTAssertNotNil(store.records)
        service.recordsFailure = .unavailable
        await store.reload()
        XCTAssertNil(store.records)
        XCTAssertEqual(store.recordsError, RecordsFailure.unavailable.localizedDescription)
        XCTAssertNotNil(store.trends)
        XCTAssertNil(store.trendsError)
        service.recordsFailure = nil; service.trendsFailure = .network
        await store.reload()
        XCTAssertNotNil(store.records)
        XCTAssertNil(store.trends)
        XCTAssertEqual(store.trendsError, RecordsFailure.network.localizedDescription)
    }

    @MainActor func testCancellationDoesNotPublishPartialOrSampleData() async {
        let service = RecordsServiceStub(); service.suspendRecords = true
        let store = RecordsStore(service: service, timezone: "UTC")
        let task = Task { await store.reload() }
        while service.pending.isEmpty { await Task.yield() }
        task.cancel(); service.resume(0); await task.value
        XCTAssertNil(store.records); XCTAssertNil(store.trends)
        XCTAssertNil(store.recordsError); XCTAssertNil(store.trendsError)
        XCTAssertFalse(store.loading)
    }

    @MainActor func testUnavailableServiceShowsErrorAndDetailFailureClearsOldValue() async {
        let empty = RecordsStore(service: nil, timezone: "UTC")
        await empty.reload()
        XCTAssertNil(empty.records); XCTAssertNil(empty.trends)
        XCTAssertNotNil(empty.recordsError); XCTAssertNotNil(empty.trendsError)
        let detail = RecordDetailStore(service: RecordsServiceStub(), detail: .preview(DemoRecords.trips[0]))
        await detail.reload(id: "123")
        XCTAssertNil(detail.detail)
        XCTAssertEqual(detail.error, RecordsFailure.notFound.localizedDescription)
        XCTAssertFalse(detail.loading)
    }
}

@MainActor private final class RecordsServiceStub: RecordsServing {
    var recordsFailure: RecordsFailure?
    var trendsFailure: RecordsFailure?
    var suspendRecords = false
    var pending: [(String, String, CheckedContinuation<RecordsResponse, Error>)] = []
    func records(month: String, week: String) async throws -> RecordsResponse {
        if let recordsFailure { throw recordsFailure }
        if suspendRecords {
            return try await withCheckedThrowingContinuation { pending.append((month, week, $0)) }
        }
        return .init(timezone: "UTC", month: month, weekStart: week, days: [], trips: [])
    }
    func resume(_ index: Int) {
        let (month, week, continuation) = pending[index]
        continuation.resume(returning: .init(timezone: "UTC", month: month, weekStart: week, days: [], trips: []))
    }
    func trends(month: String) async throws -> RecordTrends {
        if let trendsFailure { throw trendsFailure }
        return .preview
    }
    func trip(id: String) async throws -> RecordTripDetail { throw RecordsFailure.notFound }
}
