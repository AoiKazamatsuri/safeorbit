import XCTest
import MapKit
#if !targetEnvironment(simulator)
import AMapNaviKit
#endif
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
    func testCaregiverTrailUsesTheSameVisibleStyleForBothMapBackends() throws {
        let coordinates = LocationPreviewData.trail.map(\.appleCoordinate)
        let line = try XCTUnwrap(CaregiverTrailStyle.line(coordinates: coordinates))
        XCTAssertEqual(line.id, "senior-trail")
        XCTAssertEqual(line.coordinates.count, coordinates.count)
        XCTAssertEqual(line.width, 8)
        XCTAssertEqual(line.dash, [10, 8])
        XCTAssertNil(CaregiverTrailStyle.line(coordinates: Array(coordinates.prefix(1))))
    }

    func testWalkingRouteErrorsKeepActionableCause() {
        XCTAssertEqual(NavigationIssue.amapSearchError(code: 1008), .routeConfiguration)
        XCTAssertEqual(NavigationIssue.amapSearchError(code: 1102), .routeTimedOut)
        XCTAssertEqual(NavigationIssue.amapSearchError(code: 1806), .routeNetworkUnavailable)
        XCTAssertEqual(NavigationIssue.amapSearchError(code: 3001), .routeUnavailable)
    }

    func testReferenceMapScaleStaysCenteredOnSelectedPlace() {
        let center = LocationPreviewData.campus.appleCoordinate
        let region = OrbitMapScale.region(center: center, viewportHeight: 874)
        XCTAssertEqual(region.center.latitude, center.latitude, accuracy: 0.000001)
        XCTAssertEqual(region.center.longitude, center.longitude, accuracy: 0.000001)
        XCTAssertEqual(CLLocation(latitude: center.latitude - region.span.latitudeDelta / 2, longitude: center.longitude)
            .distance(from: CLLocation(latitude: center.latitude + region.span.latitudeDelta / 2, longitude: center.longitude)),
                       5_800, accuracy: 100)
    }

    func testCaregiverHomeScaleCentersSeniorAboveMeasuredCard() {
        let senior = LocationPreviewData.campus.appleCoordinate
        let mapFrame = CGRect(x: 0, y: 0, width: 402, height: 874)
        for cardTop in [CGFloat(530), CGFloat(640)] {
            let region = OrbitMapScale.caregiverHomeRegion(center: senior,
                                                           mapFrame: mapFrame, cardTop: cardTop)
            let seniorY = mapFrame.midY - (senior.latitude - region.center.latitude)
                / region.span.latitudeDelta * mapFrame.height
            XCTAssertEqual(seniorY, (mapFrame.minY + cardTop) / 2, accuracy: 0.01)
            let verticalMeters = CLLocation(latitude: region.center.latitude - region.span.latitudeDelta / 2,
                                            longitude: region.center.longitude)
                .distance(from: CLLocation(latitude: region.center.latitude + region.span.latitudeDelta / 2,
                                           longitude: region.center.longitude))
            let horizontalMeters = CLLocation(latitude: region.center.latitude,
                                              longitude: region.center.longitude - region.span.longitudeDelta / 2)
                .distance(from: CLLocation(latitude: region.center.latitude,
                                           longitude: region.center.longitude + region.span.longitudeDelta / 2))
            XCTAssertEqual(verticalMeters / mapFrame.height, OrbitMapScale.metersPerPoint, accuracy: 0.1)
            XCTAssertEqual(horizontalMeters / mapFrame.width, OrbitMapScale.metersPerPoint, accuracy: 0.1)
        }
    }

    func testSafeZoneScaleMatchesBothAxesAndKeepsPinAboveCard() {
        let center = LocationPreviewData.campus.appleCoordinate
        let size = CGSize(width: 402, height: 874)
        let region = OrbitMapScale.region(center: center, viewportSize: size, verticalOffset: 0.15)
        let verticalMeters = CLLocation(latitude: region.center.latitude - region.span.latitudeDelta / 2,
                                        longitude: region.center.longitude)
            .distance(from: CLLocation(latitude: region.center.latitude + region.span.latitudeDelta / 2,
                                       longitude: region.center.longitude))
        let horizontalMeters = CLLocation(latitude: region.center.latitude,
                                          longitude: region.center.longitude - region.span.longitudeDelta / 2)
            .distance(from: CLLocation(latitude: region.center.latitude,
                                       longitude: region.center.longitude + region.span.longitudeDelta / 2))
        XCTAssertEqual(verticalMeters / size.height, horizontalMeters / size.width, accuracy: 0.1)
        XCTAssertEqual(verticalMeters / size.height, OrbitMapScale.metersPerPoint, accuracy: 0.1)
        XCTAssertEqual(region.center.longitude, center.longitude, accuracy: 0.000001)
        let pinY = size.height / 2 - (center.latitude - region.center.latitude) / region.span.latitudeDelta * size.height
        XCTAssertEqual(pinY, size.height * 0.35, accuracy: 0.01, "The pin stays above the editor card")
    }

    func testMapCameraGateAppliesWhenInitCompletesBeforeLayout() {
        var gate = MapCameraGate<Int>()
        gate.request(1)
        gate.engineDidInitialize()
        XCTAssertNil(gate.due, "No size yet")
        gate.layout(.zero)
        XCTAssertNil(gate.due, "A zero-size layout keeps the request")
        gate.layout(CGSize(width: 402, height: 874))
        XCTAssertEqual(gate.due, 1)
        XCTAssertTrue(gate.didApply(1))
        XCTAssertNil(gate.due)
        XCTAssertEqual(gate.applied, 1)
    }

    func testMapCameraGateAppliesWhenLayoutPrecedesInit() {
        var gate = MapCameraGate<Int>()
        gate.request(1)
        gate.layout(CGSize(width: 390, height: 750))
        XCTAssertNil(gate.due, "Engine not initialised")
        XCTAssertNil(gate.applied, "Nothing is recorded before it is sent")
        gate.engineDidInitialize()
        XCTAssertEqual(gate.due, 1)
        gate.didApply(1)
        XCTAssertNil(gate.due)
    }

    func testMapCameraGateIgnoresRepeatedCallbacksAfterApplying() {
        var gate = MapCameraGate<Int>()
        gate.request(1)
        gate.engineDidInitialize()
        gate.layout(CGSize(width: 402, height: 874))
        XCTAssertTrue(gate.didApply(1))
        for _ in 0..<3 {
            gate.engineDidInitialize()
            gate.layout(CGSize(width: 402, height: 874))
            gate.request(1)
            XCTAssertNil(gate.due, "Later loads and layouts must not snap back to the first region")
        }
        gate.request(2)
        XCTAssertEqual(gate.due, 2)
        XCTAssertFalse(gate.didApply(2), "Only the first application is reported as first")
    }

    func testMapCameraGateKeepsTheNewestRequestWhenReplacedDuringUpdate() {
        var gate = MapCameraGate<Int>()
        gate.request(1)
        gate.request(2)
        gate.engineDidInitialize()
        gate.layout(CGSize(width: 402, height: 874))
        XCTAssertEqual(gate.due, 2, "Only the newest waiting request is applied")
        gate.request(3)
        gate.didApply(2)
        XCTAssertEqual(gate.due, 3, "A request that arrives while another is sent stays pending")
        gate.didApply(3)
        XCTAssertNil(gate.due)
    }

    func testMapCameraGateDropsWorkAfterDismantle() {
        var gate = MapCameraGate<Int>()
        gate.request(1)
        gate.close()
        gate.engineDidInitialize()
        gate.layout(CGSize(width: 402, height: 874))
        gate.request(2)
        XCTAssertTrue(gate.closed)
        XCTAssertNil(gate.pending)
        XCTAssertNil(gate.due)
    }

    func testMapCameraGateLetsUserGesturesWinOverLateInitialRegion() {
        var gate = MapCameraGate<Int>()
        gate.request(1)
        gate.layout(CGSize(width: 402, height: 874))
        gate.userMoved(to: 9)
        gate.engineDidInitialize()
        XCTAssertNil(gate.due, "A late init callback cannot override the gesture")
        gate.request(1)
        XCTAssertNil(gate.due, "Re-reading the old binding before the gesture is written back is ignored")
        gate.request(9)
        XCTAssertNil(gate.due, "The written-back gesture camera is already shown")
        gate.request(1)
        XCTAssertEqual(gate.due, 1, "An explicit later request such as reset still applies")
        gate.didApply(1)
        gate.userMoved()
        XCTAssertNil(gate.due)
        XCTAssertEqual(gate.applied, 1)
    }

    func testMapCameraGateTreatsAutomaticAsNotYetApplied() throws {
        var gate = MapCameraGate<MapCameraPosition>()
        gate.request(.automatic)
        gate.engineDidInitialize()
        gate.layout(CGSize(width: 402, height: 874))
        XCTAssertEqual(gate.due, .automatic)
        XCTAssertNil(AMapCameraTarget.resolve(.automatic), "No senior fix means no region to send")
        XCTAssertNil(gate.applied)
        let region = OrbitMapScale.caregiverHomeRegion(center: LocationPreviewData.campus.appleCoordinate,
                                                       mapFrame: CGRect(x: 0, y: 0, width: 402, height: 874), cardTop: 600)
        gate.request(.region(region))
        let due = try XCTUnwrap(gate.due)
        let target = try XCTUnwrap(AMapCameraTarget.resolve(due))
        XCTAssertEqual(target.region.span.latitudeDelta, region.span.latitudeDelta, accuracy: 0.0000001)
        XCTAssertEqual(target.heading, 0)
        gate.didApply(due)
        XCTAssertNil(gate.due)
        let camera = try XCTUnwrap(AMapCameraTarget.resolve(.camera(MapCamera(centerCoordinate: region.center,
                                                                             distance: 650, heading: 90, pitch: 0))))
        XCTAssertEqual(camera.heading, 90)
    }

    @MainActor func testSafeZoneCircleUsesMapCoordinatesAndMeters() {
        let center = GeoPoint(latitude: 32.061, longitude: 118.778)
        let circle = SafeZoneSelectionMap.circle(center: center, radius: 200)
        XCTAssertEqual(circle.coordinate.latitude, center.appleCoordinate.latitude, accuracy: 0.000001)
        XCTAssertEqual(circle.coordinate.longitude, center.appleCoordinate.longitude, accuracy: 0.000001)
        XCTAssertEqual(circle.pointCount, 65)
        let edge = circle.points()[0].coordinate
        let distance = CLLocation(latitude: edge.latitude, longitude: edge.longitude)
            .distance(from: CLLocation(latitude: center.appleCoordinate.latitude, longitude: center.appleCoordinate.longitude))
        XCTAssertEqual(distance, 200, accuracy: 2)
        let london = GeoPoint(latitude: 51.5, longitude: -0.12)
        XCTAssertEqual(SafeZoneSelectionMap.circle(center: london, radius: 500).coordinate.latitude, london.latitude, accuracy: 0.000001)
    }

    func testSafeZoneDragStoresWGS84AndPanPreservesSelection() throws {
        let original = LocationPreviewData.campus
        let target = GeoPoint(latitude: original.latitude + 0.001, longitude: original.longitude + 0.001)
        var draft = SafeZoneSelectionState(center: original)
        // Panning the map is deliberately absent from draft state: it cannot select a new point.
        XCTAssertEqual(draft.selectedCenter, original)
        XCTAssertNil(draft.draggedCenter)
        XCTAssertTrue(draft.move(displayed: target.appleCoordinate))
        XCTAssertEqual(draft.selectedCenter, original, "Dragging must not save before release")
        let saved = try XCTUnwrap(draft.finish(commit: true))
        XCTAssertEqual(saved.latitude, target.latitude, accuracy: 0.000001)
        XCTAssertEqual(saved.longitude, target.longitude, accuracy: 0.000001)
        XCTAssertEqual(draft.selectedCenter, saved)
        XCTAssertNil(draft.draggedCenter)
        XCTAssertNil(draft.finish(commit: true), "A duplicate release must not emit a second selection")
        XCTAssertFalse(draft.move(displayed: CLLocationCoordinate2D(latitude: .nan, longitude: 0)))
        XCTAssertEqual(draft.selectedCenter, saved)
    }

    func testSafeZoneRangeKeepsCompleteCircleDuringRepeatedDragsAndRadiusChanges() throws {
        let original = LocationPreviewData.campus
        var draft = SafeZoneSelectionState(center: original)
        #if !targetEnvironment(simulator)
        let circle = try XCTUnwrap(MACircle(center: original.appleCoordinate, radius: 200))
        #endif
        for index in 0..<40 {
            let target = GeoPoint(latitude: original.latitude + Double(index % 8 - 4) * 0.001,
                                  longitude: original.longitude + Double(index / 8 - 2) * 0.001)
            XCTAssertTrue(draft.move(displayed: target.appleCoordinate))
        #if !targetEnvironment(simulator)
            XCTAssertTrue(circle.setCircleWithCenterCoordinate(draft.circleCenter.appleCoordinate, radius: 200))
        #endif
        #if !targetEnvironment(simulator)
            XCTAssertEqual(circle.coordinate.latitude, target.appleCoordinate.latitude, accuracy: 0.000001)
        #endif
        #if !targetEnvironment(simulator)
            XCTAssertEqual(circle.coordinate.longitude, target.appleCoordinate.longitude, accuracy: 0.000001)
        #endif
        #if !targetEnvironment(simulator)
            XCTAssertEqual(circle.radius, 200)
        #endif
        #if !targetEnvironment(simulator)
            XCTAssertGreaterThan(circle.boundingMapRect.size.width, 0)
        #endif
        #if !targetEnvironment(simulator)
            XCTAssertGreaterThan(circle.boundingMapRect.size.height, 0)
        #endif
            XCTAssertEqual(draft.selectedCenter, original)
        }
        XCTAssertNil(draft.finish(commit: false))
        XCTAssertEqual(draft.circleCenter, original)
        XCTAssertNil(draft.draggedCenter)
        #if !targetEnvironment(simulator)
        XCTAssertTrue(circle.setCircleWithCenterCoordinate(draft.circleCenter.appleCoordinate, radius: 200))
        #endif
        #if !targetEnvironment(simulator)
        XCTAssertEqual(circle.coordinate.latitude, original.appleCoordinate.latitude, accuracy: 0.000001)
        #endif
        let target = GeoPoint(latitude: original.latitude + 0.001, longitude: original.longitude + 0.001)
        XCTAssertTrue(draft.move(displayed: target.appleCoordinate))
        let saved = try XCTUnwrap(draft.finish(commit: true))
        for radius in [100, 200, 500, 1000, 2000] {
        #if !targetEnvironment(simulator)
            XCTAssertTrue(circle.setCircleWithCenterCoordinate(draft.circleCenter.appleCoordinate, radius: Double(radius)))
        #endif
        #if !targetEnvironment(simulator)
            XCTAssertEqual(circle.radius, Double(radius))
        #endif
            XCTAssertEqual(draft.selectedCenter, saved)
        #if !targetEnvironment(simulator)
            XCTAssertEqual(circle.coordinate.latitude, saved.appleCoordinate.latitude, accuracy: 0.000001)
        #endif
        #if !targetEnvironment(simulator)
            XCTAssertGreaterThan(circle.boundingMapRect.size.width, 0)
        #endif
        }
    }

    func testSafeZoneMapFailureDisablesSaveAndLoadingRecovers() {
        var draft = SafeZoneSelectionState(center: LocationPreviewData.campus)
        XCTAssertFalse(draft.available)
        XCTAssertTrue(draft.report(available: false, issue: "Map unavailable. Check your internet connection."))
        XCTAssertFalse(draft.available)
        XCTAssertNotNil(draft.issue)
        XCTAssertFalse(draft.report(available: false, issue: draft.issue), "Duplicate errors should not emit another callback")
        XCTAssertTrue(draft.report(available: true, issue: nil))
        XCTAssertTrue(draft.available)
        XCTAssertNil(draft.issue)
        XCTAssertFalse(draft.report(available: true, issue: nil))
        XCTAssertTrue(draft.report(available: false, issue: "Map unavailable. Check your internet connection."))
        XCTAssertFalse(draft.available, "A later map failure must disable saving again")
    }

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
        for risk in [CaregiverRiskState.normal, .warning, .high] {
            let window = UIWindow(windowScene: scene)
            window.frame = risk == .normal
                ? CGRect(x: 0, y: 0, width: 402, height: 874)
                : CGRect(x: 0, y: 0, width: 393, height: 852)
            window.rootViewController = UIHostingController(rootView: ZStack {
                LocationPage(profile: profile, snapshot: LocationPreviewData.snapshot(), message: nil,
                             agent: {}, navigate: {}, riskState: risk)
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
    @MainActor func testSafeZoneEditorSnapshots() async throws {
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.first as? UIWindowScene)
        let previous = scene.windows.first(where: \.isKeyWindow)
        let folder = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("FrontendSnapshots")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        for (name, size, type) in [
            ("safe-zone-add-design", CGSize(width: 402, height: 874), DynamicTypeSize.large),
            ("safe-zone-add", CGSize(width: 393, height: 852), DynamicTypeSize.large),
            ("safe-zone-edit-small-large-text", CGSize(width: 375, height: 812), DynamicTypeSize.accessibility1)
        ] {
            let window = UIWindow(windowScene: scene)
            window.frame = CGRect(origin: .zero, size: size)
            window.rootViewController = UIHostingController(rootView: SafeZoneEditorPage(
                zone: name.hasPrefix("safe-zone-add") ? nil : LocationPreviewData.snapshot().safeZones[0],
                initialCenter: LocationPreviewData.campus,
                nearbyZones: LocationPreviewData.snapshot().safeZones,
                save: { _ in }, delete: { _ in }
            ).environment(\.dynamicTypeSize, type).environment(\.colorScheme, .light))
            window.makeKeyAndVisible()
            window.rootViewController?.view.frame = window.bounds
            window.rootViewController?.view.layoutIfNeeded()
            try await Task.sleep(for: .milliseconds(2500))
            let image = UIGraphicsImageRenderer(size: window.bounds.size).image { _ in
                window.rootViewController!.view.drawHierarchy(in: window.bounds, afterScreenUpdates: true)
            }
            let data = try XCTUnwrap(image.pngData())
            try data.write(to: folder.appendingPathComponent("\(name).png"))
            let attachment = XCTAttachment(data: data, uniformTypeIdentifier: "public.png")
            attachment.name = name; attachment.lifetime = .keepAlways; add(attachment)
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
        XCTAssertEqual(snapshot().safeZones.first?.radiusMeters, 200)
        let displayed = nanjing.appleCoordinate
        let recovered = MainlandCoordinates.toWGS84(GeoPoint(latitude: displayed.latitude, longitude: displayed.longitude))
        XCTAssertLessThan(CLLocation(latitude: recovered.latitude, longitude: recovered.longitude)
            .distance(from: CLLocation(latitude: nanjing.latitude, longitude: nanjing.longitude)), 1)
    }
    @MainActor func testSafeZoneChangesLastOnlyForSession() {
        let original = snapshot()
        let store = SafeZoneSessionStore()
        XCTAssertEqual(store.visibleZones(in: original).first?.radiusMeters, 200)
        let changed = SafeZone(id: "campus", name: "Market", center: LocationPreviewData.campus, radiusMeters: 500)
        store.save(changed)
        XCTAssertEqual(store.visibleZones(in: original).first?.name, "Market")
        let added = SafeZone(id: "new", name: "Home", center: LocationPreviewData.startingPoint, radiusMeters: 200)
        store.save(added)
        XCTAssertEqual(store.visibleZones(in: original).count, 2)
        store.delete(changed)
        XCTAssertEqual(store.visibleZones(in: original).map(\.id), ["new"])
        XCTAssertEqual(SafeZoneSessionStore().visibleZones(in: original).map(\.id), ["campus"])
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
        await model.start(to: snapshot())
        XCTAssertEqual(model.route?.steps.count, 2)
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

@MainActor private final class NavigationClock {
    var date = Date()
    func advance(_ seconds: Double = 1) { date = date.addingTimeInterval(seconds) }
}
@MainActor private final class NavigationVoiceSpy: NavigationSpeaking {
    var spoken: [String] = []
    var stops = 0
    func speak(_ text: String) { spoken.append(text) }
    func stop() { stops += 1 }
}
@MainActor private final class NavigationProviderStub: WalkingRouteProvider {
    let source = GeoPoint(latitude: 0, longitude: 0)
    var target = GeoPoint(latitude: 0.001, longitude: 0.001)
    var calls = 0
    var stops = 0
    var cancelled = 0
    var error: NavigationIssue?
    var routeGate: CheckedContinuation<WalkingRoute, Error>?
    var holdRoute = false
    var receiver: ((Result<NavigationFix, NavigationIssue>) -> Void)?
    var headingReceiver: ((NavigationHeading) -> Void)?
    var destinations: [GeoPoint] = []
    var customRoute: WalkingRoute?
    var result: WalkingRoute {
        if let customRoute { return customRoute }
        let corner = CLLocationCoordinate2D(latitude: 0, longitude: 0.001)
        return WalkingRoute(coordinates: [source.appleCoordinate, corner, target.appleCoordinate], distanceMeters: 222,
                            expectedSeconds: 180, steps: ["Walk east", "Turn left and walk north"], segments: [
            WalkingStep(instruction: "Walk east", coordinates: [source.appleCoordinate, corner], distanceMeters: 111),
            WalkingStep(instruction: "Turn left and walk north", coordinates: [corner, target.appleCoordinate], distanceMeters: 111)])
    }
    func currentPoint() async throws -> GeoPoint { if let error { throw error }; return source }
    func route(from: GeoPoint, to: GeoPoint) async throws -> WalkingRoute {
        calls += 1; destinations.append(to)
        if let error { throw error }
        if holdRoute { return try await withCheckedThrowingContinuation { routeGate = $0 } }
        return result
    }
    func startUpdates(_ receive: @escaping (Result<NavigationFix, NavigationIssue>) -> Void) { receiver = receive }
    func startHeadingUpdates(_ receive: @escaping (NavigationHeading) -> Void) { headingReceiver = receive }
    func stopUpdates() { stops += 1; receiver = nil; headingReceiver = nil }
    func cancelRoute() { cancelled += 1 }
}

extension LocationTests {
    @MainActor private func navigationSnapshot(_ point: GeoPoint, at date: Date) -> ElderLocationSnapshot {
        ElderLocationSnapshot(coordinate: point, recordedAt: date, heading: nil, status: nil,
                              batteryPercent: nil, address: nil, trail: [], safeZones: [])
    }
    @MainActor func testNavigationProgressVoiceMuteAndArrival() async {
        let clock = NavigationClock(), provider = NavigationProviderStub(), voice = NavigationVoiceSpy()
        let model = WalkingNavigationModel(provider: provider, voice: voice, now: { clock.date })
        await model.start(to: navigationSnapshot(provider.target, at: clock.date))
        XCTAssertGreaterThan(model.turnMeters, 0)
        func fix(_ latitude: Double, _ longitude: Double, accuracy: Double = 5) {
            clock.advance()
            model.receive(NavigationFix(point: .init(latitude: latitude, longitude: longitude), accuracy: accuracy, timestamp: clock.date))
        }
        fix(0, 0.0002)
        XCTAssertEqual(model.stepIndex, 0); XCTAssertLessThan(model.remainingMeters, 222)
        XCTAssertEqual(voice.spoken.count, 1)
        fix(0, 0.0003)
        XCTAssertEqual(voice.spoken.count, 1)
        fix(0, 0.0008)
        XCTAssertEqual(voice.spoken.count, 2)
        fix(0, 0.00081)
        XCTAssertEqual(voice.spoken.count, 2)
        model.toggleMuted()
        fix(0.0002, 0.001)
        XCTAssertEqual(model.stepIndex, 1); XCTAssertEqual(voice.spoken.count, 2)
        model.toggleMuted()
        fix(0.0003, 0.001)
        XCTAssertEqual(voice.spoken.count, 3)
        let remaining = model.remainingMeters
        fix(0.00095, 0.001, accuracy: 80)
        XCTAssertEqual(model.remainingMeters, remaining); XCTAssertFalse(model.arrived)
        fix(0.00095, 0.001); fix(0.00096, 0.001)
        XCTAssertFalse(model.arrived)
        fix(0.00097, 0.001)
        XCTAssertTrue(model.arrived); XCTAssertEqual(model.remainingMeters, 0)
        XCTAssertGreaterThan(provider.stops, 0)
        XCTAssertTrue(voice.spoken.last?.contains("near") == true)
        let stops = voice.stops
        model.pause()
        XCTAssertGreaterThan(voice.stops, stops)
        XCTAssertTrue(model.arrived)
        model.end(); XCTAssertFalse(model.isPresented); XCTAssertNil(model.route)
    }
    @MainActor func testNavigationDeviationThrottleAndMovingSenior() async {
        let clock = NavigationClock(), provider = NavigationProviderStub()
        let model = WalkingNavigationModel(provider: provider, voice: NavigationVoiceSpy(), now: { clock.date })
        await model.start(to: navigationSnapshot(provider.target, at: clock.date))
        for _ in 0..<3 {
            clock.advance()
            model.receive(NavigationFix(point: .init(latitude: -0.001, longitude: 0.0005), accuracy: 5, timestamp: clock.date))
        }
        XCTAssertEqual(provider.calls, 1)
        clock.advance(30)
        model.receive(NavigationFix(point: .init(latitude: -0.001, longitude: 0.0005), accuracy: 5, timestamp: clock.date))
        for _ in 0..<10 { await Task.yield() }
        XCTAssertEqual(provider.calls, 2)
        let moved = GeoPoint(latitude: 0.002, longitude: 0.001)
        model.updateDestination(navigationSnapshot(moved, at: clock.date))
        XCTAssertEqual(provider.calls, 2)
        clock.advance(31)
        model.receive(NavigationFix(point: provider.source, accuracy: 5, timestamp: clock.date))
        for _ in 0..<10 { await Task.yield() }
        XCTAssertEqual(provider.calls, 3); XCTAssertEqual(provider.destinations.last, moved)
        let latest = model.destination?.recordedAt
        model.updateDestination(navigationSnapshot(provider.target, at: clock.date.addingTimeInterval(-100)))
        XCTAssertEqual(model.destination?.recordedAt, latest)
        model.end()
    }
    @MainActor func testNavigationStaleLocationPausesAndRecovers() async {
        let clock = NavigationClock(), provider = NavigationProviderStub()
        let model = WalkingNavigationModel(provider: provider, voice: NavigationVoiceSpy(), now: { clock.date })
        await model.start(to: navigationSnapshot(provider.target, at: clock.date))
        model.receive(NavigationFix(point: provider.source, accuracy: 5, timestamp: clock.date))
        clock.advance(16); model.tick()
        XCTAssertEqual(model.issue, .locationUnavailable)
        let remaining = model.remainingMeters
        model.receive(NavigationFix(point: provider.target, accuracy: 5, timestamp: clock.date.addingTimeInterval(-16)))
        XCTAssertEqual(model.remainingMeters, remaining); XCTAssertFalse(model.arrived)
        clock.advance(301); model.tick()
        XCTAssertEqual(model.issue, .staleDestination)
        model.updateDestination(navigationSnapshot(provider.target, at: clock.date))
        clock.advance()
        model.receive(NavigationFix(point: provider.source, accuracy: 5, timestamp: clock.date))
        for _ in 0..<10 { await Task.yield() }
        XCTAssertEqual(provider.calls, 2); XCTAssertNil(model.issue)
        model.pause(); XCTAssertTrue(model.suspended)
        let calls = provider.calls
        model.receive(NavigationFix(point: provider.target, accuracy: 5, timestamp: clock.date))
        XCTAssertEqual(provider.calls, calls)
        await model.resume(to: navigationSnapshot(provider.target, at: clock.date))
        XCTAssertFalse(model.suspended); XCTAssertEqual(provider.calls, calls + 1)
        model.end()
    }
    @MainActor func testNavigationCancellationIgnoresLateRouteAndLocation() async {
        let clock = NavigationClock(), provider = NavigationProviderStub()
        provider.holdRoute = true
        let model = WalkingNavigationModel(provider: provider, voice: NavigationVoiceSpy(), now: { clock.date })
        let task = Task { await model.start(to: navigationSnapshot(provider.target, at: clock.date)) }
        for _ in 0..<20 { if provider.routeGate != nil { break }; await Task.yield() }
        XCTAssertNotNil(provider.routeGate)
        let oldReceiver = provider.receiver
        model.end()
        provider.routeGate?.resume(returning: provider.result); provider.routeGate = nil
        await task.value
        oldReceiver?(.success(NavigationFix(point: provider.target, accuracy: 5, timestamp: clock.date)))
        XCTAssertNil(model.route); XCTAssertNil(model.fix); XCTAssertFalse(model.loading); XCTAssertFalse(model.isPresented)
    }
}

extension LocationTests {
    @MainActor func testInlineNavigationSnapshotsAndExit() async throws {
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.first as? UIWindowScene)
        let previous = scene.windows.first(where: \.isKeyWindow)
        let folder = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent("FrontendSnapshots")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let clock = NavigationClock()
        for (name, size, type, unavailable) in [
            ("refined-navigation-design", CGSize(width: 402, height: 874), DynamicTypeSize.large, false),
            ("refined-navigation", CGSize(width: 393, height: 852), DynamicTypeSize.large, false),
            ("refined-navigation-narrow", CGSize(width: 375, height: 812), DynamicTypeSize.large, false),
            ("refined-navigation-small", CGSize(width: 320, height: 568), DynamicTypeSize.accessibility1, false),
            ("refined-navigation-small-large-text", CGSize(width: 375, height: 812), DynamicTypeSize.accessibility1, false),
            ("refined-navigation-unavailable", CGSize(width: 393, height: 852), DynamicTypeSize.large, true)
        ] {
            #if targetEnvironment(simulator)
            let provider: any WalkingRouteProvider = unavailable ? RouteStub() : PreviewWalkingRouteProvider()
            #else
            let provider: any WalkingRouteProvider = RouteStub()
            #endif
            let voice = NavigationVoiceSpy()
            let model = WalkingNavigationModel(provider: provider, voice: voice, isDemoRoute: !unavailable)
            let senior = LocationPreviewData.snapshot(recordedAt: clock.date)
            await model.start(to: unavailable ? nil : senior)
            if !unavailable {
                model.receive(NavigationFix(point: LocationPreviewData.startingPoint, accuracy: 5, timestamp: clock.date))
            }
            var profile = ElderProfile(); profile.name = "Li Lan"
            let window = UIWindow(windowScene: scene)
            window.frame = CGRect(origin: .zero, size: size)
            window.rootViewController = UIHostingController(rootView:
                LocationPage(profile: profile, snapshot: senior, message: nil,
                             agent: {}, navigate: {}, navigation: model)
                .environment(\.dynamicTypeSize, type).environment(\.colorScheme, .light))
            window.makeKeyAndVisible()
            window.rootViewController?.view.frame = window.bounds
            window.rootViewController?.view.layoutIfNeeded()
            try await Task.sleep(for: .milliseconds(2500))
            let image = UIGraphicsImageRenderer(size: window.bounds.size).image { _ in
                window.rootViewController!.view.drawHierarchy(in: window.bounds, afterScreenUpdates: true)
            }
            let data = try XCTUnwrap(image.pngData())
            try data.write(to: folder.appendingPathComponent(name + ".png"))
            let attachment = XCTAttachment(data: data, uniformTypeIdentifier: "public.png")
            attachment.name = name; attachment.lifetime = .keepAlways; add(attachment)
            if name == "refined-navigation-small" {
                func scrollView(in view: UIView) -> UIScrollView? {
                    if let scroll = view as? UIScrollView, scroll.contentSize.height > scroll.bounds.height + 1 { return scroll }
                    return view.subviews.lazy.compactMap { scrollView(in: $0) }.first
                }
                let scroll = try XCTUnwrap(scrollView(in: window.rootViewController!.view))
                scroll.setContentOffset(CGPoint(x: 0, y: scroll.contentSize.height - scroll.bounds.height + scroll.adjustedContentInset.bottom), animated: false)
                try await Task.sleep(for: .milliseconds(300))
                let bottom = UIGraphicsImageRenderer(size: window.bounds.size).image { _ in
                    window.rootViewController!.view.drawHierarchy(in: window.bounds, afterScreenUpdates: true)
                }
                try XCTUnwrap(bottom.pngData()).write(to: folder.appendingPathComponent("refined-navigation-small-scrolled.png"))
            }
            XCTAssertTrue(model.isPresented)
            model.end(); XCTAssertFalse(model.isPresented)
            window.isHidden = true; previous?.makeKeyAndVisible()
        }
    }
}

extension LocationTests {
    @MainActor func testNavigationErrorsRemainActionableAndRetry() async {
        let clock = NavigationClock(), provider = NavigationProviderStub()
        let model = WalkingNavigationModel(provider: provider, voice: NavigationVoiceSpy(), now: { clock.date })
        provider.error = .locationDenied
        await model.start(to: navigationSnapshot(provider.target, at: clock.date))
        model.tick()
        XCTAssertEqual(model.issue, .locationDenied)
        provider.error = .routeUnavailable
        await model.plan(to: navigationSnapshot(provider.target, at: clock.date))
        model.tick()
        XCTAssertEqual(model.issue, .routeUnavailable)
        provider.error = nil
        await model.plan(to: navigationSnapshot(provider.target, at: clock.date))
        XCTAssertNotNil(model.route); XCTAssertNil(model.issue)
        clock.advance()
        let nearby = GeoPoint(latitude: provider.target.latitude + 0.00005, longitude: provider.target.longitude)
        model.updateDestination(navigationSnapshot(nearby, at: clock.date))
        XCTAssertEqual(provider.calls, 1)
        model.updateDestination(navigationSnapshot(.init(latitude: 90.1, longitude: 0), at: clock.date.addingTimeInterval(1)))
        XCTAssertEqual(model.issue, .missingDestination)
        model.end()
    }
}


extension LocationTests {
    @MainActor func testEstimatedArrivalUsesValidProgressAndClearsOnExit() async throws {
        let clock = NavigationClock(), provider = NavigationProviderStub()
        let model = WalkingNavigationModel(provider: provider, voice: NavigationVoiceSpy(), now: { clock.date })
        await model.start(to: navigationSnapshot(provider.target, at: clock.date))
        XCTAssertEqual(try XCTUnwrap(model.estimatedArrival).timeIntervalSince(clock.date), model.remainingSeconds, accuracy: 0.01)
        clock.advance()
        model.receive(NavigationFix(point: .init(latitude: 0, longitude: 0.0005), accuracy: 5, timestamp: clock.date))
        XCTAssertEqual(try XCTUnwrap(model.estimatedArrival).timeIntervalSince(clock.date), model.remainingSeconds, accuracy: 0.01)
        let arrival = model.estimatedArrival
        clock.advance()
        model.receive(NavigationFix(point: provider.target, accuracy: 80, timestamp: clock.date))
        XCTAssertEqual(model.estimatedArrival, arrival)
        model.end()
        XCTAssertNil(model.estimatedArrival)
        await model.start(to: nil)
        XCTAssertNil(model.estimatedArrival)
        model.end()
    }
}

extension LocationTests {
    @MainActor func testNavigationHeadingPrefersCompassAndFallsBackToCourseThenRoute() async throws {
        let clock = NavigationClock(), provider = NavigationProviderStub()
        let model = WalkingNavigationModel(provider: provider, voice: NavigationVoiceSpy(), now: { clock.date })
        await model.start(to: navigationSnapshot(provider.target, at: clock.date))
        model.receive(NavigationFix(point: provider.source, accuracy: 5, timestamp: clock.date))
        XCTAssertEqual(try XCTUnwrap(model.markerHeading), 90, accuracy: 0.1)
        clock.date.addTimeInterval(1)
        model.receive(NavigationFix(point: provider.source, accuracy: 5, timestamp: clock.date, course: 120))
        XCTAssertEqual(model.markerHeading, 120)
        provider.headingReceiver?(NavigationHeading(degrees: 270, accuracy: 5, timestamp: clock.date))
        XCTAssertEqual(model.markerHeading, 270)
        clock.date.addTimeInterval(16)
        XCTAssertEqual(model.markerHeading, 120)
        provider.headingReceiver?(NavigationHeading(degrees: 10, accuracy: -1, timestamp: clock.date))
        XCTAssertEqual(model.markerHeading, 120)
        provider.headingReceiver?(NavigationHeading(degrees: .nan, accuracy: 5, timestamp: clock.date))
        XCTAssertEqual(model.markerHeading, 120)
        clock.date.addTimeInterval(1)
        model.receive(NavigationFix(point: .init(latitude: 0.0005, longitude: 0.001), accuracy: 5, timestamp: clock.date))
        XCTAssertEqual(try XCTUnwrap(model.markerHeading), 0, accuracy: 0.1)
        model.end()
        XCTAssertNil(model.markerHeading)
    }

    @MainActor func testHeadingCallbacksCannotRevivePausedOrEndedNavigation() async {
        let clock = NavigationClock(), provider = NavigationProviderStub()
        let model = WalkingNavigationModel(provider: provider, voice: NavigationVoiceSpy(), now: { clock.date })
        await model.start(to: navigationSnapshot(provider.target, at: clock.date))
        let oldReceiver = provider.headingReceiver
        model.pause()
        oldReceiver?(NavigationHeading(degrees: 270, accuracy: 5, timestamp: clock.date))
        XCTAssertNil(model.markerHeading)
        await model.resume(to: navigationSnapshot(provider.target, at: clock.date))
        let newReceiver = provider.headingReceiver
        clock.date.addTimeInterval(1)
        oldReceiver?(NavigationHeading(degrees: 270, accuracy: 5, timestamp: clock.date))
        XCTAssertNil(model.markerHeading)
        newReceiver?(NavigationHeading(degrees: 45, accuracy: 5, timestamp: clock.date))
        XCTAssertEqual(model.markerHeading, 45)
        model.end()
        newReceiver?(NavigationHeading(degrees: 90, accuracy: 5, timestamp: clock.date))
        XCTAssertNil(model.markerHeading)
        XCTAssertNil(provider.headingReceiver)
    }
}

#if targetEnvironment(simulator)
extension LocationTests {
    @MainActor func testPreviewNavigationUsesRoadRouteAndRefreshesOnlySampleFixes() async throws {
        let provider = PreviewWalkingRouteProvider(), voice = NavigationVoiceSpy()
        let model = WalkingNavigationModel(provider: provider, voice: voice, isDemoRoute: true)
        await model.start(to: LocationPreviewData.snapshot())
        await Task.yield()
        XCTAssertTrue(model.isDemoRoute)
        XCTAssertNil(model.issue)
        let route = try XCTUnwrap(model.route)
        XCTAssertEqual(route.coordinates.count, LocationPreviewData.trail.count)
        XCTAssertEqual(route.coordinates.first?.latitude, LocationPreviewData.startingPoint.appleCoordinate.latitude)
        XCTAssertEqual(route.coordinates.last?.longitude, LocationPreviewData.campus.appleCoordinate.longitude)
        XCTAssertGreaterThan(route.distanceMeters, 500)
        XCTAssertEqual(route.segments.count, 2)
        let firstFix = try XCTUnwrap(model.fix)
        try await Task.sleep(for: .milliseconds(1100))
        XCTAssertGreaterThan(try XCTUnwrap(model.fix).timestamp, firstFix.timestamp)
        XCTAssertEqual(model.fix?.point, LocationPreviewData.startingPoint)
        model.toggleMuted(); XCTAssertTrue(model.muted)
        model.end(); XCTAssertFalse(model.isPresented); XCTAssertNil(model.route); XCTAssertNil(model.fix)
        do {
            _ = try await provider.route(from: LocationPreviewData.startingPoint, to: GeoPoint(latitude: 0, longitude: 0))
            XCTFail("Preview must reject destinations outside its fixed illustrative route")
        } catch { XCTAssertEqual(error as? NavigationIssue, .routeUnavailable) }
    }
}
#endif

extension LocationTests {
    @MainActor func testFollowCameraUsesDirectedRouteInsteadOfCompassAndTurnsAtCorner() async throws {
        let clock = NavigationClock(), provider = NavigationProviderStub()
        let model = WalkingNavigationModel(provider: provider, voice: NavigationVoiceSpy(), now: { clock.date })
        await model.start(to: navigationSnapshot(provider.target, at: clock.date))
        model.receive(NavigationFix(point: provider.source, accuracy: 5, timestamp: clock.date, course: 270))
        provider.headingReceiver?(NavigationHeading(degrees: 180, accuracy: 5, timestamp: clock.date))
        var camera = try XCTUnwrap(model.followCamera)
        XCTAssertEqual(camera.heading, 90, accuracy: 0.1)
        XCTAssertEqual(camera.centerCoordinate.latitude, provider.source.appleCoordinate.latitude, accuracy: 0.000001)
        XCTAssertEqual(camera.centerCoordinate.longitude, provider.source.appleCoordinate.longitude, accuracy: 0.000001)
        XCTAssertEqual(model.markerHeading, 180)
        clock.advance()
        let corner = GeoPoint(latitude: 0, longitude: 0.001)
        model.receive(NavigationFix(point: corner, accuracy: 5, timestamp: clock.date))
        camera = try XCTUnwrap(model.followCamera)
        XCTAssertEqual(camera.heading, 0, accuracy: 0.1)
        XCTAssertEqual(camera.centerCoordinate.longitude, corner.appleCoordinate.longitude, accuracy: 0.000001)
        clock.advance(16)
        XCTAssertNil(model.followCamera, "Stale fixes cannot move the camera")
        model.end(); XCTAssertNil(model.followCamera)

        let westProvider = NavigationProviderStub()
        let westCorner = GeoPoint(latitude: 0, longitude: -0.001)
        westProvider.target = GeoPoint(latitude: -0.001, longitude: -0.001)
        westProvider.customRoute = WalkingRoute(coordinates: [westProvider.source.appleCoordinate, westCorner.appleCoordinate, westProvider.target.appleCoordinate], distanceMeters: 222, expectedSeconds: 180, steps: ["Walk west", "Turn left and walk south"], segments: [
            WalkingStep(instruction: "Walk west", coordinates: [westProvider.source.appleCoordinate, westCorner.appleCoordinate], distanceMeters: 111),
            WalkingStep(instruction: "Turn left and walk south", coordinates: [westCorner.appleCoordinate, westProvider.target.appleCoordinate], distanceMeters: 111)])
        let west = WalkingNavigationModel(provider: westProvider, voice: NavigationVoiceSpy(), now: { clock.date })
        await west.start(to: navigationSnapshot(westProvider.target, at: clock.date))
        west.receive(NavigationFix(point: westProvider.source, accuracy: 5, timestamp: clock.date))
        XCTAssertEqual(try XCTUnwrap(west.followCamera).heading, 270, accuracy: 0.1)
        clock.advance()
        west.receive(NavigationFix(point: westCorner, accuracy: 5, timestamp: clock.date))
        XCTAssertEqual(try XCTUnwrap(west.followCamera).heading, 180, accuracy: 0.1)
        west.pause(); XCTAssertNil(west.followCamera)
        west.end()
    }
}


extension LocationTests {
    func testNavigationMarkersPreserveSeparateCoordinatesAndLastValidEndpoint() throws {
        let senior = LocationPreviewData.campus.appleCoordinate
        let end = LocationPreviewData.startingPoint.appleCoordinate
        let invalid = CLLocationCoordinate2D(latitude: .nan, longitude: 0)
        let route = WalkingRoute(coordinates: [end, invalid], distanceMeters: 100, expectedSeconds: 60, steps: [])
        let separated = CaregiverNavigationMarkers.make(route: route, senior: senior, name: "Li Lan")
        XCTAssertEqual(separated.map(\.id), ["route-end", "destination"])
        XCTAssertEqual(separated[0].coordinate.latitude, end.latitude)
        XCTAssertEqual(separated[0].coordinate.longitude, end.longitude)
        XCTAssertEqual(separated[1].coordinate.latitude, senior.latitude)
        XCTAssertEqual(separated[1].coordinate.longitude, senior.longitude)
        let combined = CaregiverNavigationMarkers.make(route: route, senior: end, name: "Li Lan")
        XCTAssertEqual(combined.map(\.id), ["route-end-and-senior"])
        XCTAssertEqual(combined[0].coordinate.latitude, end.latitude)
        XCTAssertEqual(combined[0].coordinate.longitude, end.longitude)
        XCTAssertEqual(CaregiverNavigationMarkers.make(route: nil, senior: senior, name: "Li Lan").map(\.id), ["destination"])
        XCTAssertEqual(CaregiverNavigationMarkers.make(route: route, senior: nil, name: "Li Lan").map(\.id), ["route-end"])
        XCTAssertTrue(CaregiverNavigationMarkers.make(route: nil, senior: invalid, name: "Li Lan").isEmpty)
    }

    @MainActor func testNavigationMarkerMapSnapshots() async throws {
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.first as? UIWindowScene)
        let previous = scene.windows.first(where: \.isKeyWindow)
        let folder = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent("FrontendSnapshots")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let end = LocationPreviewData.campus.appleCoordinate
        for (name, separated, missing, heading) in [
            ("navigation-markers-combined", false, false, 0.0),
            ("navigation-markers-separated", true, false, 0.0),
            ("navigation-markers-rotated", false, false, 90.0),
            ("navigation-markers-missing-route", false, true, 0.0)
        ] {
            let senior = CLLocationCoordinate2D(latitude: end.latitude + (separated ? 0.001 : 0), longitude: end.longitude)
            let route = WalkingRoute(coordinates: [LocationPreviewData.startingPoint.appleCoordinate, end], distanceMeters: 750, expectedSeconds: 660, steps: [])
            let markers = CaregiverNavigationMarkers.make(route: missing ? nil : route, senior: senior, name: "Li Lan")
            let window = UIWindow(windowScene: scene)
            window.frame = CGRect(x: 0, y: 0, width: 402, height: 874)
            window.rootViewController = UIHostingController(rootView:
                AMapCanvas(camera: .constant(.camera(MapCamera(centerCoordinate: end, distance: 650, heading: heading, pitch: 0))),
                    markers: markers, lines: missing ? [] : [AMapLine(id: "route", coordinates: route.coordinates, color: OrbitMapStyle.blue, width: 8)])
                    .environment(\.colorScheme, .light))
            window.makeKeyAndVisible()
            window.rootViewController?.view.frame = window.bounds
            try await Task.sleep(for: .milliseconds(1800))
            let image = UIGraphicsImageRenderer(size: window.bounds.size).image { _ in
                window.rootViewController!.view.drawHierarchy(in: window.bounds, afterScreenUpdates: true)
            }
            try XCTUnwrap(image.pngData()).write(to: folder.appendingPathComponent(name + ".png"))
            window.isHidden = true; previous?.makeKeyAndVisible()
        }
    }
}
