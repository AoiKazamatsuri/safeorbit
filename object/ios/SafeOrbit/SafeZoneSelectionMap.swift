import SwiftUI
import MapKit

struct SafeZoneSelectionMap: View {
    let initialCenter: GeoPoint
    let radiusMeters: Int
    let onSelection: (GeoPoint) -> Void
    let onAvailability: (Bool) -> Void

    @State private var issue: String?
    @State private var retryID = 0

    var body: some View {
        ZStack {
            SafeZoneMapView(initialCenter: initialCenter, radiusMeters: radiusMeters,
                            onSelection: onSelection, onState: { available, message in
                                issue = message
                                onAvailability(available)
                            })
                .id(retryID)
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

struct SafeZoneMapView: UIViewRepresentable {
    let initialCenter: GeoPoint
    let radiusMeters: Int
    let onSelection: (GeoPoint) -> Void
    let onState: (Bool, String?) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(parent: self) }

    func makeUIView(context: Context) -> MKMapView {
        let map = MKMapView()
        map.overrideUserInterfaceStyle = .light
        map.isScrollEnabled = true
        map.isZoomEnabled = true
        map.isRotateEnabled = false
        map.isPitchEnabled = false
        map.showsCompass = false
        map.layoutMargins = UIEdgeInsets(top: 0, left: 12, bottom: 12, right: 12)
        context.coordinator.configure(map)
        return map
    }

    func updateUIView(_ map: MKMapView, context: Context) {
        context.coordinator.parent = self
        // Updating the controls must not reset the user's map camera.
        context.coordinator.updateCircle(in: map, force: true)
    }

    static func dismantleUIView(_ map: MKMapView, coordinator: Coordinator) {
        coordinator.loadTimeout?.cancel()
        map.delegate = nil
    }

    final class Coordinator: NSObject, MKMapViewDelegate {
        var parent: SafeZoneMapView
        let pin = MKPointAnnotation()
        private(set) var selectedCenter: GeoPoint
        private var circle: MKPolygon?
        private var circleCenter: GeoPoint?
        private var circleRadius: Int?
        private var available = false
        private var issue: String?
        private weak var map: MKMapView?
        private var dragOrigin: CLLocationCoordinate2D?
        private var draggedCenter: GeoPoint?
        var loadTimeout: Task<Void, Never>?

        init(parent: SafeZoneMapView) {
            self.parent = parent
            selectedCenter = parent.initialCenter
        }

        func configure(_ map: MKMapView) {
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
            let distance = max(800, Double(parent.radiusMeters) * 3.5)
            var region = MKCoordinateRegion(center: pin.coordinate,
                                            latitudinalMeters: distance, longitudinalMeters: distance)
            // Keep the pin above the address and editing cards without changing its coordinate.
            region.center.latitude -= region.span.latitudeDelta * 0.15
            map.setRegion(region, animated: false)
            loadTimeout = Task { @MainActor [weak self] in
                do { try await Task.sleep(for: .seconds(15)) } catch { return }
                guard let self, !self.available else { return }
                self.report(false, issue: "Map unavailable. Check your internet connection.")
            }
        }

        func updateCircle(in map: MKMapView, force: Bool = false) {
            let center = draggedCenter ?? selectedCenter
            guard center.isValid,
                  force || circleCenter != center || circleRadius != parent.radiusMeters else { return }
            if let circle { map.removeOverlay(circle) }
            let updated = SafeZoneSelectionMap.circle(center: center, radius: parent.radiusMeters)
            circle = updated
            circleCenter = center
            circleRadius = parent.radiusMeters
            map.addOverlay(updated)
        }

        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            guard let circle = overlay as? MKPolygon else { return MKOverlayRenderer(overlay: overlay) }
            let renderer = MKPolygonRenderer(polygon: circle)
            renderer.fillColor = UIColor(red: 0.28, green: 0.47, blue: 0.46, alpha: 0.25)
            renderer.strokeColor = UIColor(red: 0.28, green: 0.47, blue: 0.46, alpha: 0.55)
            renderer.lineWidth = 1
            return renderer
        }

        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            guard annotation === pin else { return nil }
            let view = mapView.dequeueReusableAnnotationView(withIdentifier: "safe-zone-pin")
                ?? MKAnnotationView(annotation: annotation, reuseIdentifier: "safe-zone-pin")
            view.annotation = annotation
            view.image = Self.pinImage()
            view.centerOffset = CGPoint(x: 0, y: -27.5)
            // A dedicated pan keeps the pin gesture separate from MapKit's map gestures.
            view.isDraggable = false
            view.canShowCallout = false
            view.displayPriority = .required
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
                let point = MainlandCoordinates.toWGS84(GeoPoint(latitude: coordinate.latitude,
                                                               longitude: coordinate.longitude))
                if point.isValid {
                    pin.coordinate = coordinate
                    draggedCenter = point
                    updateCircle(in: map)
                }
            }
            if gesture.state == .ended {
                commitSelection(in: map)
                endDirectDrag(in: map)
            } else if [.cancelled, .failed].contains(gesture.state), dragOrigin != nil {
                pin.coordinate = selectedCenter.appleCoordinate
                endDirectDrag(in: map)
            }
        }

        private func endDirectDrag(in map: MKMapView) {
            draggedCenter = nil
            dragOrigin = nil
            // Recreate the renderer after the touch transaction so its final geometry is visible.
            DispatchQueue.main.async { [weak self, weak map] in
                guard let self, let map else { return }
                self.updateCircle(in: map, force: true)
            }
        }

        func commitSelection(in map: MKMapView) {
            let displayed = GeoPoint(latitude: pin.coordinate.latitude, longitude: pin.coordinate.longitude)
            let point = MainlandCoordinates.toWGS84(displayed)
            if point.isValid {
                selectedCenter = point
                updateCircle(in: map)
                parent.onSelection(point)
            } else {
                pin.coordinate = selectedCenter.appleCoordinate
            }
        }

        func mapViewDidFinishRenderingMap(_ mapView: MKMapView, fullyRendered: Bool) {
            guard fullyRendered, selectedCenter.isValid else { return }
            loadTimeout?.cancel()
            report(true, issue: nil)
        }

        func mapViewDidFailLoadingMap(_ mapView: MKMapView, withError error: Error) {
            report(false, issue: "Map unavailable. Check your internet connection.")
        }

        private func report(_ available: Bool, issue: String?) {
            guard self.available != available || self.issue != issue else { return }
            self.available = available
            self.issue = issue
            DispatchQueue.main.async { [weak self] in
                self?.parent.onState(available, issue)
            }
        }

        private static func pinImage() -> UIImage {
            UIGraphicsImageRenderer(size: CGSize(width: 36, height: 55)).image { _ in
                UIColor.black.setFill()
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
