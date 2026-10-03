import XCTest
import MapKit
import SwiftUI
@testable import SafeOrbit

@MainActor private final class RouteStub: WalkingRouteProvider {
    var origin: GeoPoint? = LocationPreviewData.startingPoint
    var result: WalkingRoute? = WalkingRoute(coordinates: [LocationPreviewData.startingPoint.appleCoordinate,
        LocationPreviewData.trail[3].appleCoordinate, LocationPreviewData.campus.appleCoordinate],
        distanceMeters: 210, expectedSeconds: 180, steps: ["Continue toward Hankou Road", "Arrive at Nanjing University"])
    var error: NavigationIssue?
    var calls = 0
    func currentPoint() async throws -> GeoPoint { if let error { throw error }; return origin! }
    func route(from: GeoPoint, to: GeoPoint) async throws -> WalkingRoute { calls += 1; if let error { throw error }; return result! }
}

final class LocationTests: XCTestCase {
    func testRiskPreviewArgumentsAreExplicit() {
        XCTAssertEqual(CaregiverRiskState.preview(arguments: []), .normal)
        XCTAssertEqual(CaregiverRiskState.preview(arguments: ["-safeorbitRiskState", "warning"]), .warning)
        XCTAssertEqual(CaregiverRiskState.preview(arguments: ["-safeorbitRiskState", "high"]), .high)
        XCTAssertEqual(CaregiverRiskState.preview(arguments: ["-safeorbitRiskState", "unknown"]), .normal)
        XCTAssertEqual(CaregiverRiskState.preview(arguments: ["-safeorbitRiskState"]), .normal)
        XCTAssertEqual(CaregiverRiskState.warning.headline, "Wandering for 7 minutes")
        XCTAssertEqual(CaregiverRiskState.high.headline, "Wandering for 15 minutes")
    }
    @MainActor func testRiskHomeSnapshots() async throws {
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.first as? UIWindowScene)
        let previous = scene.windows.first(where: \.isKeyWindow)
        let folder = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("FrontendSnapshots")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        var profile = ElderProfile()
        profile.name = "Li Lan"
        profile.phone = "+12025550100"
        for risk in [CaregiverRiskState.warning, .high] {
            let window = UIWindow(windowScene: scene)
            window.frame = CGRect(x: 0, y: 0, width: 393, height: 852)
            window.rootViewController = UIHostingController(rootView: ZStack {
                LocationPage(profile: profile, snapshot: LocationPreviewData.snapshot(), message: nil,
                             loading: false, refresh: {}, agent: {}, navigate: {}, riskState: risk)
                VStack { Spacer(); CaregiverTabBar(selection: .constant(.location)) }
            }.environment(\.colorScheme, .light))
            window.makeKeyAndVisible()
            window.rootViewController?.view.frame = window.bounds
            window.rootViewController?.view.layoutIfNeeded()
            try await Task.sleep(for: .milliseconds(2500))
            let image = UIGraphicsImageRenderer(size: window.bounds.size).image { _ in
                window.rootViewController!.view.drawHierarchy(in: window.bounds, afterScreenUpdates: true)
            }
            let data = try XCTUnwrap(image.pngData())
            try data.write(to: folder.appendingPathComponent("location-\(risk.rawValue).png"))
            let attachment = XCTAttachment(data: data, uniformTypeIdentifier: "public.png")
            attachment.name = "location-\(risk.rawValue)"; attachment.lifetime = .keepAlways; add(attachment)
            window.isHidden = true
            previous?.makeKeyAndVisible()
        }
    }
    private func snapshot(age: TimeInterval = 0) -> ElderLocationSnapshot {
        LocationPreviewData.snapshot(recordedAt: Date().addingTimeInterval(-age))
    }
    func testCoordinatesAndFreshness() {
        let nanjing = LocationPreviewData.campus
        XCTAssertTrue(nanjing.isValid)
        XCTAssertNotEqual(MainlandCoordinates.toGCJ02(nanjing), nanjing)
        let london = GeoPoint(latitude: 51.5, longitude: -0.12)
        XCTAssertEqual(MainlandCoordinates.toGCJ02(london), london)
        let taipei = GeoPoint(latitude: 25.04, longitude: 121.56)
        XCTAssertEqual(MainlandCoordinates.toGCJ02(taipei), taipei)
        XCTAssertFalse(GeoPoint(latitude: 91, longitude: 10).isValid)
        XCTAssertTrue(snapshot().isCurrent)
        XCTAssertFalse(snapshot(age: 301).isCurrent)
        XCTAssertEqual(LocationPreviewData.trail.first, LocationPreviewData.startingPoint)
        XCTAssertEqual(LocationPreviewData.trail.last, LocationPreviewData.campus)
        XCTAssertGreaterThan(LocationPreviewData.trail.count, 3)
    }
    @MainActor func testWalkingRouteSuccessAndFailure() async {
        let stub = RouteStub()
        let model = WalkingNavigationModel(provider: stub)
        await model.plan(to: nil)
        XCTAssertEqual(model.issue, .missingDestination); XCTAssertEqual(stub.calls, 0)
        await model.plan(to: snapshot(age: 400))
        XCTAssertEqual(model.issue, .staleDestination); XCTAssertEqual(stub.calls, 0)
        await model.plan(to: snapshot())
        XCTAssertNil(model.issue); XCTAssertEqual(model.route?.distanceMeters, 210)
        XCTAssertEqual(model.route?.steps, ["Continue toward Hankou Road", "Arrive at Nanjing University"]); XCTAssertEqual(stub.calls, 1)
        stub.error = .locationDenied
        await model.plan(to: snapshot())
        XCTAssertEqual(model.issue, .locationDenied); XCTAssertNil(model.route)
        stub.error = .routeUnavailable
        await model.plan(to: snapshot())
        XCTAssertEqual(model.issue, .routeUnavailable); XCTAssertNil(model.route)
    }
    @MainActor func testBoundRoutingAndRefreshRetainsLastLocation() async throws {
        let config = URLSessionConfiguration.ephemeral; config.protocolClasses = [StubURLProtocol.self]
        let network = URLSession(configuration: config)
        let vault = SessionVault(service: "org.safeorbit.locationtest." + UUID().uuidString)
        defer { network.invalidateAndCancel(); StubURLProtocol.handler = nil; vault.clear() }
        let store = OnboardingStore(api: .init(baseURL: URL(string: "http://localhost")!, session: network), vault: vault)
        StubURLProtocol.handler = { request in
            XCTAssertEqual(request.url?.path, "/v1/auth/email/login")
            return (200, Data(#"{"token":"test-token","role":"caregiver","caregiver":{"id":"c","phone":"+8613800000000"},"elder":{"id":"e","name":"Li Lan","callName":"Li Lan","phone":"+8613800000000","timezone":"Asia/Shanghai","bound":true}}"#.utf8))
        }
        store.email = "test@example.com"; store.password = "password"
        await store.signInWithEmail()
        XCTAssertEqual(store.screen, .caregiverHome)
        StubURLProtocol.handler = { request in
            XCTAssertEqual(request.url?.path, "/v1/location")
            XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer test-token")
            let point = LocationPreviewData.campus
            return (200, Data(#"{"coordinate":{"latitude":\#(point.latitude),"longitude":\#(point.longitude)},"recordedAt":"2026-10-02T10:00:00Z","heading":120,"status":"At Nanjing University","batteryPercent":45,"address":"22 Hankou Road, Gulou District, Nanjing","trail":[],"safeZones":[]}"#.utf8))
        }
        await store.refreshLocation()
        XCTAssertEqual(store.location?.coordinate.latitude, LocationPreviewData.campus.latitude)
        StubURLProtocol.handler = { _ in (503, Data()) }
        await store.refreshLocation()
        XCTAssertEqual(store.location?.coordinate.latitude, LocationPreviewData.campus.latitude)
        XCTAssertNotNil(store.locationError)
        XCTAssertEqual(store.screen, .caregiverHome)
    }
    @MainActor func testWalkingRouteScreenRendersPlannedSteps() async throws {
        let model = WalkingNavigationModel(provider: RouteStub())
        await model.plan(to: snapshot())
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.first as? UIWindowScene)
        let previous = scene.windows.first(where: \.isKeyWindow)
        let window = UIWindow(windowScene: scene)
        window.frame = CGRect(x: 0, y: 0, width: 393, height: 852)
        window.rootViewController = UIHostingController(rootView: WalkingNavigationPage(snapshot: snapshot(), name: "Li Lan", model: model, end: {}))
        window.makeKeyAndVisible()
        defer { window.isHidden = true; previous?.makeKeyAndVisible() }
        window.rootViewController?.view.frame = window.bounds
        window.rootViewController?.view.layoutIfNeeded()
        try await Task.sleep(for: .milliseconds(2500))
        let image = UIGraphicsImageRenderer(size: window.bounds.size).image { _ in
            window.rootViewController!.view.drawHierarchy(in: window.bounds, afterScreenUpdates: true)
        }
        let data = try XCTUnwrap(image.pngData())
        let folder = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent("FrontendSnapshots")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        try data.write(to: folder.appendingPathComponent("navigation-route.png"))
        let attachment = XCTAttachment(data: data, uniformTypeIdentifier: "public.png")
        attachment.name = "navigation-route"; attachment.lifetime = .keepAlways; add(attachment)
        XCTAssertEqual(model.route?.steps.count, 2)
    }
}
