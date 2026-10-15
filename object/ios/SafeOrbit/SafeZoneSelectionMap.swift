import SwiftUI
import MapKit
#if !targetEnvironment(simulator)
import AMapNaviKit
#endif

struct SafeZoneSelectionMap: View {
    let initialCenter: GeoPoint
    let radiusMeters: Int
    let onSelection: (GeoPoint) -> Void
    let onAvailability: (Bool) -> Void
    var bottomOverlayInset: CGFloat = 12

    @State private var issue: String?
    @State private var retryID = 0

    var body: some View {
        ZStack {
            AMapConsentSurface {
            SafeZoneMapView(initialCenter: initialCenter, radiusMeters: radiusMeters,
                            onSelection: onSelection, onState: { available, message in
                                issue = message
                                onAvailability(available)
                            }, bottomOverlayInset: bottomOverlayInset)
                .id(retryID)
            }
            if let issue {
                VStack {
                    VStack(spacing: 10) {
                        Text(issue).multilineTextAlignment(.center)
                        Button("Try again") {
                            self.issue = nil
                            onAvailability(false)
                            retryID += 1
                        }
                    }
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(OrbitStyle.teal)
                    .padding(18)
                    .background(.white, in: RoundedRectangle(cornerRadius: 16))
                    Spacer()
                }
                .padding(.horizontal, 30).padding(.top, 24)
            }
        }
        .onAppear { onAvailability(false) }
    }

    /// Convert only at the MapKit boundary; persisted selections remain WGS-84.
    static func circle(center: GeoPoint, radius: Int) -> MKPolygon {
        let origin = MKMapPoint(center.appleCoordinate)
        let mapRadius = Double(radius) / MKMetersPerMapPointAtLatitude(center.appleCoordinate.latitude)
        let points = (0...64).map { index in
            let angle = Double(index) * 2 * .pi / 64
            return MKMapPoint(x: origin.x + mapRadius * cos(angle), y: origin.y + mapRadius * sin(angle))
        }
        return MKPolygon(points: points, count: points.count)
    }
}

/// Draft state is separate from the map camera and retains WGS-84 values.
struct SafeZoneSelectionState {
    private(set) var selectedCenter: GeoPoint
    private(set) var draggedCenter: GeoPoint?
    private(set) var available = false
    private(set) var issue: String?
    var circleCenter: GeoPoint { draggedCenter ?? selectedCenter }
    init(center: GeoPoint) { selectedCenter = center }
    mutating func move(displayed: CLLocationCoordinate2D) -> Bool {
        let point = MainlandCoordinates.toWGS84(GeoPoint(latitude: displayed.latitude, longitude: displayed.longitude))
        guard point.isValid else { return false }
        draggedCenter = point
        return true
    }
    mutating func finish(commit: Bool) -> GeoPoint? {
        defer { draggedCenter = nil }
        guard commit, let draggedCenter, draggedCenter.isValid else { return nil }
        selectedCenter = draggedCenter
        return selectedCenter
    }
    mutating func report(available: Bool, issue: String?) -> Bool {
        guard self.available != available || self.issue != issue else { return false }
        self.available = available
        self.issue = issue
        return true
    }
}

#if !targetEnvironment(simulator)
struct SafeZoneMapView: UIViewRepresentable {
    let initialCenter: GeoPoint
    let radiusMeters: Int
    let onSelection: (GeoPoint) -> Void
    let onState: (Bool, String?) -> Void
    var bottomOverlayInset: CGFloat = 12

    func makeCoordinator() -> Coordinator { Coordinator(parent: self) }

    func makeUIView(context: Context) -> UIView {
        let surface = NativeMapSurface()
        guard AMapRuntime.prepare() else {
            context.coordinator.report(false, issue: AMapRuntime.hasKey
                ? "Map unavailable. Enable map services to continue."
                : "Map configuration required. Add the AMap iOS SDK key to this device’s local build configuration.")
            return surface
        }
        let map = MAMapView(frame: surface.bounds)
        map.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        surface.addSubview(map)
        map.overrideUserInterfaceStyle = .light
        map.isScrollEnabled = true
        map.isZoomEnabled = true
        map.isRotateEnabled = false
        map.isRotateCameraEnabled = false
        map.showsCompass = false
        map.layoutMargins = UIEdgeInsets(top: 0, left: 12, bottom: bottomOverlayInset, right: 12)
        context.coordinator.configure(map)
        surface.onLayout = { [weak coordinator = context.coordinator] in coordinator?.layoutMap() }
        return surface
    }

    func updateUIView(_ surface: UIView, context: Context) {
        guard let map = surface.subviews.first as? MAMapView else { return }
        context.coordinator.parent = self
        map.layoutMargins = UIEdgeInsets(top: 0, left: 12, bottom: bottomOverlayInset, right: 12)
        context.coordinator.layoutMap()
        // Updating the controls must not reset the user's map camera.
        context.coordinator.updateCircle(in: map, force: true)
    }

    static func dismantleUIView(_ surface: UIView, coordinator: Coordinator) {
        coordinator.loadTimeout?.cancel()
        coordinator.map?.delegate = nil
        (surface as? NativeMapSurface)?.onLayout = nil
    }

    final class Coordinator: NSObject, MAMapViewDelegate {
        var parent: SafeZoneMapView
        let pin = MAPointAnnotation()
        private(set) var selection: SafeZoneSelectionState
        var selectedCenter: GeoPoint { selection.selectedCenter }
        private var circle: MACircle?
        private var circleRenderer: MACircleRenderer?
        private var circleCenter: GeoPoint?
        private var circleRadius: Int?
        fileprivate weak var map: MAMapView?
        private var initialRegionApplied = false
        private var dragOrigin: CLLocationCoordinate2D?
        var loadTimeout: Task<Void, Never>?

        init(parent: SafeZoneMapView) {
            self.parent = parent
            selection = SafeZoneSelectionState(center: parent.initialCenter)
        }

        func configure(_ map: MAMapView) {
            self.map = map
            map.delegate = self
            guard selectedCenter.isValid else {
                report(false, issue: "Map unavailable. The selected coordinate is invalid.")
                return
            }
            pin.coordinate = selectedCenter.appleCoordinate
            pin.title = "Safe zone"
            map.addAnnotation(pin)
            updateCircle(in: map)
            layoutMap()
            loadTimeout = Task { @MainActor [weak self] in
                do { try await Task.sleep(for: .seconds(15)) } catch { return }
                guard let self, !self.selection.available else { return }
                self.report(false, issue: "Map unavailable. Check your internet connection.")
            }
        }

        func layoutMap() {
            guard let map, map.bounds.width > 0, map.bounds.height > 0 else { return }
            map.logoCenter = CGPoint(x: 45, y: map.bounds.height - max(12, map.logoSize.height / 2 + 4))
            guard !initialRegionApplied, selectedCenter.isValid else { return }
            initialRegionApplied = true
            // Keep the pin above the editor card at the same ground scale as Location.
            let region = OrbitMapScale.region(center: pin.coordinate,
                                              viewportHeight: map.bounds.height, verticalOffset: 0.15)
            map.setRegion(MACoordinateRegion(center: region.center,
                         span: MACoordinateSpan(latitudeDelta: region.span.latitudeDelta,
                                                longitudeDelta: region.span.longitudeDelta)), animated: false)
        }

        func updateCircle(in map: MAMapView, force: Bool = false) {
            let center = selection.circleCenter
            guard center.isValid,
                  force || circleCenter != center || circleRadius != parent.radiusMeters else { return }
            circleCenter = center
            circleRadius = parent.radiusMeters
            if let circle {
                circle.setCircleWithCenterCoordinate(center.appleCoordinate, radius: Double(parent.radiusMeters))
                circleRenderer?.setNeedsUpdate()
            } else {
                let overlay = MACircle(center: center.appleCoordinate, radius: Double(parent.radiusMeters))!
                circle = overlay
                map.add(overlay)
            }
        }

        func mapView(_ mapView: MAMapView!, rendererFor overlay: MAOverlay!) -> MAOverlayRenderer! {
            guard overlay as AnyObject === circle, let circle else { return nil }
            let renderer = MACircleRenderer(circle: circle)!
            renderer.fillColor = UIColor(OrbitStyle.teal).withAlphaComponent(0.25)
            renderer.strokeColor = UIColor(OrbitStyle.teal).withAlphaComponent(0.55)
            renderer.lineWidth = 1
            circleRenderer = renderer
            return renderer
        }

        func mapView(_ mapView: MAMapView!, viewFor annotation: MAAnnotation!) -> MAAnnotationView! {
            guard annotation as AnyObject === pin else { return nil }
            let view = mapView.dequeueReusableAnnotationView(withIdentifier: "safe-zone-pin")
                ?? MAAnnotationView(annotation: annotation, reuseIdentifier: "safe-zone-pin")!
            view.annotation = annotation
            view.image = Self.pinImage()
            view.centerOffset = CGPoint(x: 0, y: -27.5)
            view.isDraggable = false
            view.canShowCallout = false
            view.accessibilityLabel = "Safe zone pin"
            view.accessibilityHint = "Drag to choose the center."
            if view.gestureRecognizers?.contains(where: { $0.name == "safe-zone-direct-drag" }) != true {
                let pan = PinPanGestureRecognizer(target: self, action: #selector(dragPin(_:)))
                pan.name = "safe-zone-direct-drag"
                pan.coordinateView = mapView
                pan.maximumNumberOfTouches = 1
                view.addGestureRecognizer(pan)
            }
            return view
        }

        @objc private func dragPin(_ gesture: PinPanGestureRecognizer) {
            guard let map else { return }
            if gesture.state == .began {
                dragOrigin = pin.coordinate
            }
            if [.began, .changed, .ended].contains(gesture.state), let origin = dragOrigin,
               let touchStart = gesture.startLocation {
                let start = map.convert(origin, toPointTo: map)
                let touch = gesture.location(in: map)
                let delta = CGPoint(x: touch.x - touchStart.x, y: touch.y - touchStart.y)
                let coordinate = map.convert(CGPoint(x: start.x + delta.x, y: start.y + delta.y),
                                             toCoordinateFrom: map)
                movePin(to: coordinate, in: map)
            }
            if gesture.state == .ended {
                finishDirectDrag(in: map, commit: true)
            } else if [.cancelled, .failed].contains(gesture.state), dragOrigin != nil {
                finishDirectDrag(in: map, commit: false)
            }
        }

        func movePin(to coordinate: CLLocationCoordinate2D, in map: MAMapView) {
            guard selection.move(displayed: coordinate) else { return }
            pin.coordinate = coordinate
            updateCircle(in: map)
        }

        func finishDirectDrag(in map: MAMapView, commit: Bool) {
            if let point = selection.finish(commit: commit) { parent.onSelection(point) }
            pin.coordinate = selectedCenter.appleCoordinate
            dragOrigin = nil
            updateCircle(in: map, force: true)
        }

        func commitSelection(in map: MAMapView) {
            guard selection.move(displayed: pin.coordinate) else {
                pin.coordinate = selectedCenter.appleCoordinate
                return
            }
            finishDirectDrag(in: map, commit: true)
        }

        func mapViewDidFinishLoadingMap(_ mapView: MAMapView!) {
            guard selectedCenter.isValid else { return }
            layoutMap()
            loadTimeout?.cancel()
            report(true, issue: nil)
        }

        func mapViewDidFailLoadingMap(_ mapView: MAMapView!, withError error: Error!) {
            report(false, issue: "Map unavailable. Check your internet connection.")
        }

        fileprivate func report(_ available: Bool, issue: String?) {
            guard selection.report(available: available, issue: issue) else { return }
            DispatchQueue.main.async { [weak self] in
                self?.parent.onState(available, issue)
            }
        }

        private static func pinImage() -> UIImage {
            UIGraphicsImageRenderer(size: CGSize(width: 36, height: 55)).image { _ in
                UIColor(OrbitStyle.teal).setFill()
                UIBezierPath(roundedRect: CGRect(x: 16, y: 24, width: 4, height: 25), cornerRadius: 2).fill()
                UIBezierPath(ovalIn: CGRect(x: 13, y: 46, width: 10, height: 8)).fill()
                UIBezierPath(ovalIn: CGRect(x: 3, y: 1, width: 30, height: 30)).fill()
                UIColor.white.setFill()
                UIBezierPath(ovalIn: CGRect(x: 10, y: 8, width: 16, height: 16)).fill()
            }
        }
    }
}

private final class PinPanGestureRecognizer: UIPanGestureRecognizer {
    weak var coordinateView: UIView?
    private(set) var startLocation: CGPoint?

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent) {
        startLocation = touches.first?.location(in: coordinateView)
        super.touchesBegan(touches, with: event)
    }
}

#else
struct SafeZoneMapView: View {
    let initialCenter: GeoPoint
    let radiusMeters: Int
    let onSelection: (GeoPoint) -> Void
    let onState: (Bool, String?) -> Void
    var bottomOverlayInset: CGFloat = 12
    var body: some View {
        GeometryReader { geometry in
            AMapCanvas(camera: .constant(.region(OrbitMapScale.region(center: initialCenter.appleCoordinate,
                            viewportHeight: geometry.size.height, verticalOffset: 0.15))),
                       bottomOverlayInset: bottomOverlayInset)
                .onAppear { onState(false, "AMap requires a physical iPhone on this simulator runtime.") }
        }
    }
}
#endif
