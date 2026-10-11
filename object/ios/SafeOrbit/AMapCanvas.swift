import SwiftUI
import MapKit
#if !targetEnvironment(simulator)
import AMapNaviKit
#endif

/// Coordinates at this boundary are already GCJ-02. Stored GeoPoint values remain WGS-84.
struct AMapMarker {
    let id: String
    let coordinate: CLLocationCoordinate2D
    var anchor: UnitPoint = .center
    let content: AnyView
}
struct AMapCircle {
    let id: String
    let center: CLLocationCoordinate2D
    let radius: Double
    let fill: Color
    var stroke: Color = .clear
    var width: CGFloat = 1
}
struct AMapLine {
    let id: String
    let coordinates: [CLLocationCoordinate2D]
    let color: Color
    let width: CGFloat
    var dash: [CGFloat] = []
}
struct AMapCameraContext {
    let region: MKCoordinateRegion
    let heading: Double
    let wasUserAction: Bool
}

#if !targetEnvironment(simulator)
struct NativeAMapCanvas: UIViewRepresentable {
    @Binding var camera: MapCameraPosition
    var markers: [AMapMarker] = []
    var circles: [AMapCircle] = []
    var lines: [AMapLine] = []
    var bottomOverlayInset: CGFloat = 0
    var onCameraChange: (AMapCameraContext) -> Void = { _ in }

    func makeCoordinator() -> Coordinator { Coordinator(parent: self) }
    func makeUIView(context: Context) -> UIView {
        let surface = UIView()
        surface.backgroundColor = .systemGroupedBackground
        guard AMapRuntime.prepare() else { return surface }
        let map = MAMapView(frame: surface.bounds)
        map.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        map.overrideUserInterfaceStyle = .light
        map.showsCompass = false
        map.showsScale = false
        map.isRotateCameraEnabled = false
        map.showsUserLocation = false
        surface.addSubview(map)
        context.coordinator.map = map
        map.delegate = context.coordinator
        context.coordinator.update()
        return surface
    }
    func updateUIView(_ surface: UIView, context: Context) {
        context.coordinator.parent = self
        context.coordinator.update()
    }
    static func dismantleUIView(_ surface: UIView, coordinator: Coordinator) {
        coordinator.map?.delegate = nil
        coordinator.hosts.removeAll()
    }

    final class Coordinator: NSObject, MAMapViewDelegate {
        var parent: NativeAMapCanvas
        weak var map: MAMapView?
        var lastCamera: MapCameraPosition?
        var annotations: [String: MAPointAnnotation] = [:]
        var hosts: [String: UIHostingController<AnyView>] = [:]
        private var overlayStyles: [ObjectIdentifier: EitherOverlay] = [:]
        private var renderedOverlayKey = ""
        init(parent: NativeAMapCanvas) { self.parent = parent }

        func update() {
            guard let map else { return }
            map.layoutMargins = UIEdgeInsets(top: 0, left: 12, bottom: parent.bottomOverlayInset, right: 12)
            // Move attribution above the existing editing/navigation cards.
            map.logoCenter = CGPoint(x: 45, y: max(20, map.bounds.height - parent.bottomOverlayInset - 12))
            let wanted = Set(parent.markers.map(\.id))
            for id in Array(annotations.keys) where !wanted.contains(id) {
                if let annotation = annotations.removeValue(forKey: id) { map.removeAnnotation(annotation) }
                hosts.removeValue(forKey: id)
            }
            for marker in parent.markers {
                if let annotation = annotations[marker.id] {
                    annotation.coordinate = marker.coordinate
                    if let view = map.view(for: annotation) { install(marker, into: view) }
                } else {
                    let annotation = MAPointAnnotation()
                    annotation.coordinate = marker.coordinate
                    annotations[marker.id] = annotation
                    map.addAnnotation(annotation)
                }
            }
            let key = parent.circles.map { "\($0.id):\($0.center.latitude):\($0.center.longitude):\($0.radius):\($0.fill):\($0.stroke):\($0.width)" }.joined(separator: "|")
                + parent.lines.map { "\($0.id):\($0.coordinates.map { "\($0.latitude),\($0.longitude)" }):\($0.color):\($0.width):\($0.dash)" }.joined(separator: "|")
            if key != renderedOverlayKey {
                map.removeOverlays(map.overlays)
                overlayStyles.removeAll()
                for circle in parent.circles where circle.radius.isFinite && circle.radius > 0 {
                    let overlay = MACircle(center: circle.center, radius: circle.radius)!
                    overlayStyles[ObjectIdentifier(overlay)] = .circle(circle)
                    map.add(overlay)
                }
                for line in parent.lines where line.coordinates.count > 1 {
                    var points = line.coordinates
                    let overlay = MAPolyline(coordinates: &points, count: UInt(points.count))!
                    overlayStyles[ObjectIdentifier(overlay)] = .line(line)
                    map.add(overlay)
                }
                renderedOverlayKey = key
            }
            if lastCamera != parent.camera {
                lastCamera = parent.camera
                if let region = parent.camera.region {
                    map.setRegion(MACoordinateRegion(center: region.center, span: MACoordinateSpan(latitudeDelta: region.span.latitudeDelta, longitudeDelta: region.span.longitudeDelta)), animated: false)
                    map.rotationDegree = 0
                } else if let camera = parent.camera.camera {
                    let region = MKCoordinateRegion(center: camera.centerCoordinate, latitudinalMeters: camera.distance, longitudinalMeters: camera.distance)
                    map.setRegion(MACoordinateRegion(center: region.center, span: MACoordinateSpan(latitudeDelta: region.span.latitudeDelta, longitudeDelta: region.span.longitudeDelta)), animated: false)
                    map.rotationDegree = CGFloat(camera.heading)
                }
            }
        }
        private func install(_ marker: AMapMarker, into view: MAAnnotationView) {
            let host: UIHostingController<AnyView>
            if let existing = hosts[marker.id] { host = existing; host.rootView = marker.content }
            else {
                host = UIHostingController(rootView: marker.content)
                host.view.backgroundColor = .clear
                hosts[marker.id] = host
            }
            let size = host.sizeThatFits(in: CGSize(width: 360, height: 240))
            view.bounds = CGRect(origin: .zero, size: size)
            view.centerOffset = CGPoint(x: (0.5 - marker.anchor.x) * size.width,
                                        y: (0.5 - marker.anchor.y) * size.height)
            if host.view.superview !== view { view.addSubview(host.view) }
            host.view.frame = view.bounds
            host.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
            view.canShowCallout = false
        }
        func mapView(_ mapView: MAMapView!, viewFor annotation: MAAnnotation!) -> MAAnnotationView! {
            guard let id = annotations.first(where: { $0.value === annotation as AnyObject })?.key,
                  let marker = parent.markers.first(where: { $0.id == id }) else { return nil }
            let view = mapView.dequeueReusableAnnotationView(withIdentifier: id)
                ?? MAAnnotationView(annotation: annotation, reuseIdentifier: id)!
            view.annotation = annotation
            install(marker, into: view)
            return view
        }
        func mapView(_ mapView: MAMapView!, rendererFor overlay: MAOverlay!) -> MAOverlayRenderer! {
            guard let style = overlayStyles[ObjectIdentifier(overlay as AnyObject)] else { return nil }
            switch style {
            case .circle(let style):
                let renderer = MACircleRenderer(circle: (overlay as! MACircle))!
                renderer.fillColor = UIColor(style.fill)
                renderer.strokeColor = UIColor(style.stroke)
                renderer.lineWidth = style.width
                return renderer
            case .line(let style):
                let renderer = MAPolylineRenderer(polyline: (overlay as! MAPolyline))!
                renderer.strokeColor = UIColor(style.color)
                renderer.lineWidth = style.width
                renderer.lineCapType = MALineCapType(rawValue: 3)
                renderer.lineJoinType = MALineJoinType(rawValue: 2)
                if !style.dash.isEmpty { renderer.strokeImage = Self.dashTexture(style) }
                return renderer
            }
        }
        private static func dashTexture(_ line: AMapLine) -> UIImage {
            let period = max(1, line.dash.reduce(0, +))
            return UIGraphicsImageRenderer(size: CGSize(width: period, height: line.width)).image { context in
                context.cgContext.setFillColor(UIColor(line.color).cgColor)
                var x: CGFloat = 0
                for (index, length) in line.dash.enumerated() {
                    if index.isMultiple(of: 2) { context.cgContext.fill(CGRect(x: x, y: 0, width: length, height: line.width)) }
                    x += length
                }
            }
        }
        func mapView(_ mapView: MAMapView!, regionDidChangeAnimated animated: Bool, wasUserAction: Bool) {
            let region = MKCoordinateRegion(center: mapView.region.center, span: MKCoordinateSpan(latitudeDelta: mapView.region.span.latitudeDelta, longitudeDelta: mapView.region.span.longitudeDelta))
            let context = AMapCameraContext(region: region, heading: Double(mapView.rotationDegree), wasUserAction: wasUserAction)
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                if wasUserAction {
                    let camera = MapCameraPosition.camera(MapCamera(centerCoordinate: region.center, distance: region.span.latitudeDelta * 111_320, heading: context.heading, pitch: 0))
                    self.lastCamera = camera
                    self.parent.camera = camera
                }
                self.parent.onCameraChange(context)
            }
        }
        private enum EitherOverlay { case circle(AMapCircle), line(AMapLine) }
    }
}

#endif

/// Display-only fallback; location and route providers still use their existing availability checks.
struct AMapCanvas: View {
    @Binding var camera: MapCameraPosition
    var markers: [AMapMarker] = []
    var circles: [AMapCircle] = []
    var lines: [AMapLine] = []
    var bottomOverlayInset: CGFloat = 0
    var onCameraChange: (AMapCameraContext) -> Void = { _ in }

    var body: some View {
        #if !targetEnvironment(simulator)
        if AMapRuntime.hasKey {
            NativeAMapCanvas(camera: $camera, markers: markers, circles: circles,
                             lines: lines, bottomOverlayInset: bottomOverlayInset,
                             onCameraChange: onCameraChange)
        } else { previewMap }
        #else
        previewMap
        #endif
    }

    private var previewMap: some View {
        Map(position: $camera, interactionModes: [.pan, .zoom]) {
            ForEach(circles, id: \.id) { circle in
                MapCircle(center: circle.center, radius: circle.radius)
                    .foregroundStyle(circle.fill)
                    .stroke(circle.stroke, lineWidth: circle.width)
            }
            ForEach(lines, id: \.id) { line in
                MapPolyline(coordinates: line.coordinates)
                    .stroke(line.color, style: StrokeStyle(lineWidth: line.width,
                        lineCap: .round, lineJoin: .round, dash: line.dash))
            }
            ForEach(markers, id: \.id) { marker in
                Annotation("", coordinate: marker.coordinate, anchor: marker.anchor) {
                    marker.content
                }.annotationTitles(.hidden)
            }
        }
        .mapStyle(.standard(elevation: .flat, pointsOfInterest: .excludingAll, showsTraffic: false))
        .environment(\.colorScheme, .light)
        .onMapCameraChange(frequency: .onEnd) { context in
            onCameraChange(AMapCameraContext(region: context.region,
                heading: context.camera.heading, wasUserAction: camera.positionedByUser))
        }
        .onAppear {
            if markers.isEmpty && camera == .automatic {
                camera = .region(MKCoordinateRegion(
                    center: CLLocationCoordinate2D(latitude: 32.0617, longitude: 118.7780),
                    span: MKCoordinateSpan(latitudeDelta: 0.012, longitudeDelta: 0.012)))
            }
        }
        .accessibilityIdentifier("map-display-fallback")
    }
}
