import SwiftUI
import MapKit
#if !targetEnvironment(simulator)
import AMapNaviKit
#if DEBUG
import OSLog
#endif
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

enum CaregiverTrailStyle {
    static let width: CGFloat = 8
    static let dash: [CGFloat] = [10, 8]

    static func line(coordinates: [CLLocationCoordinate2D]) -> AMapLine? {
        guard coordinates.count > 1 else { return nil }
        return AMapLine(id: "senior-trail", coordinates: coordinates,
                        color: OrbitMapStyle.blue, width: width, dash: dash)
    }
}
struct AMapCameraContext {
    let region: MKCoordinateRegion
    let heading: Double
    let wasUserAction: Bool
}

/// At the 402×874 reference size, the visible map is about 400 metres per
/// centimetre of the iPhone 18 Pro display (roughly 5.8 km vertically).
enum OrbitMapScale {
    static let metersPerPoint = 5_800.0 / 874.0

    /// Place the senior halfway between the map's top edge and the card that
    /// covers its bottom. Match the map's portrait aspect instead of asking
    /// either SDK to fit a square region into a tall viewport.
    static func caregiverHomeRegion(center: CLLocationCoordinate2D,
                                    mapFrame: CGRect, cardTop: CGFloat) -> MKCoordinateRegion {
        let width = max(1, Double(mapFrame.width))
        let height = max(1, Double(mapFrame.height))
        let visibleBottom = min(max(Double(cardTop), Double(mapFrame.minY)), Double(mapFrame.maxY))
        let targetY = (Double(mapFrame.minY) + visibleBottom) / 2
        let offset = (Double(mapFrame.midY) - targetY) / height
        var region = MKCoordinateRegion(center: center,
                                        latitudinalMeters: height * metersPerPoint,
                                        longitudinalMeters: width * metersPerPoint)
        region.center.latitude -= region.span.latitudeDelta * offset
        return region
    }

    static func region(center: CLLocationCoordinate2D, viewportHeight: CGFloat,
                       verticalOffset: Double = 0) -> MKCoordinateRegion {
        let height = max(1, Double(viewportHeight))
        let span = height * metersPerPoint
        var region = MKCoordinateRegion(center: center, latitudinalMeters: span, longitudinalMeters: span)
        region.center.latitude -= region.span.latitudeDelta * verticalOffset
        return region
    }

    /// Ground spans follow the full viewport so both axes share one metres-per-point
    /// scale; `verticalOffset` is a fraction of the height the place sits above centre.
    static func region(center: CLLocationCoordinate2D, viewportSize: CGSize,
                       verticalOffset: Double = 0) -> MKCoordinateRegion {
        let width = max(1, Double(viewportSize.width))
        let height = max(1, Double(viewportSize.height))
        var region = MKCoordinateRegion(center: center, latitudinalMeters: height * metersPerPoint,
                                        longitudinalMeters: width * metersPerPoint)
        region.center.latitude -= region.span.latitudeDelta * verticalOffset
        return region
    }
}

/// Holds the newest camera request until the native map has both finished initialising
/// and received a non-zero size; either may arrive first. A request counts as handled
/// only after `didApply`, and a user gesture drops whatever is still waiting.
struct MapCameraGate<Request: Equatable> {
    private(set) var engineReady = false
    private(set) var viewSized = false
    private(set) var closed = false
    private(set) var pending: Request?
    private(set) var applied: Request?
    private var lastRequest: Request?
    private var appliedOnce = false
    var isReady: Bool { engineReady && viewSized && !closed }
    /// The request to send now, if the map can take it.
    var due: Request? { isReady ? pending : nil }

    mutating func request(_ request: Request) {
        guard !closed, request != lastRequest else { return }
        lastRequest = request
        pending = request == applied ? nil : request
    }
    mutating func engineDidInitialize() { engineReady = true }
    mutating func layout(_ size: CGSize) { viewSized = size.width > 0 && size.height > 0 }
    /// Records a sent request; returns true for the first one this map applied.
    @discardableResult mutating func didApply(_ request: Request) -> Bool {
        applied = request
        if pending == request { pending = nil }
        defer { appliedOnce = true }
        return !appliedOnce
    }
    mutating func userMoved(to request: Request? = nil) {
        pending = nil
        if let request { applied = request }
    }
    mutating func close() { closed = true; pending = nil }
}

/// The region and heading a native map should show. `.automatic` and other positions
/// without an explicit region (for example before a senior fix) yield nil.
enum AMapCameraTarget {
    static func resolve(_ camera: MapCameraPosition) -> (region: MKCoordinateRegion, heading: Double)? {
        if let region = camera.region { return (region, 0) }
        guard let camera = camera.camera else { return nil }
        return (MKCoordinateRegion(center: camera.centerCoordinate, latitudinalMeters: camera.distance,
                                   longitudinalMeters: camera.distance), camera.heading)
    }
}

#if !targetEnvironment(simulator)
#if DEBUG
/// Debug-only scale readings for on-device checks; never logs keys or coordinates.
enum AMapScaleProbe {
    private static let log = Logger(subsystem: "org.safeorbit.demo", category: "map-scale")
    static func record(_ map: MAMapView, page: String, stage: String) {
        let size = map.bounds.size, zoom = Double(map.zoomLevel), meters = map.metersPerPointForCurrentZoom
        log.notice("\(page, privacy: .public) \(stage, privacy: .public): view \(Double(size.width), format: .fixed(precision: 0), privacy: .public)x\(Double(size.height), format: .fixed(precision: 0), privacy: .public) zoom \(zoom, format: .fixed(precision: 3), privacy: .public) m/pt \(meters, format: .fixed(precision: 3), privacy: .public) target \(OrbitMapScale.metersPerPoint, format: .fixed(precision: 3), privacy: .public)")
    }
}
#endif

final class NativeMapSurface: UIView {
    var onLayout: (() -> Void)?
    override func layoutSubviews() {
        super.layoutSubviews()
        onLayout?()
    }
}

struct NativeAMapCanvas: UIViewRepresentable {
    @Binding var camera: MapCameraPosition
    var markers: [AMapMarker] = []
    var circles: [AMapCircle] = []
    var lines: [AMapLine] = []
    var bottomOverlayInset: CGFloat = 0
    var onCameraChange: (AMapCameraContext) -> Void = { _ in }

    func makeCoordinator() -> Coordinator { Coordinator(parent: self) }
    func makeUIView(context: Context) -> UIView {
        let surface = NativeMapSurface()
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
        surface.onLayout = { [weak coordinator = context.coordinator] in coordinator?.update() }
        context.coordinator.update()
        return surface
    }
    func updateUIView(_ surface: UIView, context: Context) {
        context.coordinator.parent = self
        context.coordinator.update()
    }
    static func dismantleUIView(_ surface: UIView, coordinator: Coordinator) {
        coordinator.cameraGate.close()
        coordinator.map?.delegate = nil
        (surface as? NativeMapSurface)?.onLayout = nil
        coordinator.hosts.removeAll()
    }

    final class Coordinator: NSObject, MAMapViewDelegate {
        var parent: NativeAMapCanvas
        weak var map: MAMapView?
        var cameraGate = MapCameraGate<MapCameraPosition>()
        #if DEBUG
        private var probeSettled = false
        #endif
        var annotations: [String: MAPointAnnotation] = [:]
        var hosts: [String: UIHostingController<AnyView>] = [:]
        private var overlayStyles: [ObjectIdentifier: EitherOverlay] = [:]
        private var renderedOverlayKey = ""
        init(parent: NativeAMapCanvas) { self.parent = parent }

        func update() {
            guard let map else { return }
            map.layoutMargins = UIEdgeInsets(top: 0, left: 12, bottom: parent.bottomOverlayInset, right: 12)
            // Attribution sits in the clear strip below the bottom cards.
            if map.bounds.width > 0, map.bounds.height > 0 {
                map.logoCenter = CGPoint(x: 45, y: map.bounds.height - max(12, map.logoSize.height / 2 + 4))
            }
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
            cameraGate.request(parent.camera)
            cameraGate.layout(map.bounds.size)
            applyCamera(stage: "layout")
        }
        /// A region set before both engine init and a non-zero layout may not take
        /// effect, so the request stays pending until then and is marked only once sent.
        private func applyCamera(stage: String) {
            guard let map, let camera = cameraGate.due,
                  let target = AMapCameraTarget.resolve(camera) else { return }
            map.setRegion(MACoordinateRegion(center: target.region.center, span: MACoordinateSpan(latitudeDelta: target.region.span.latitudeDelta, longitudeDelta: target.region.span.longitudeDelta)), animated: false)
            map.rotationDegree = CGFloat(target.heading)
            let first = cameraGate.didApply(camera)
            #if DEBUG
            if first { AMapScaleProbe.record(map, page: "canvas", stage: "applied via \(stage)"); probeSettled = true }
            #else
            _ = first
            #endif
        }
        func mapInitComplete(_ mapView: MAMapView!) {
            cameraGate.engineDidInitialize()
            applyCamera(stage: "init")
        }
        func mapViewDidFinishLoadingMap(_ mapView: MAMapView!) {
            cameraGate.engineDidInitialize()
            applyCamera(stage: "load")
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
                if !style.dash.isEmpty { renderer.lineDashType = MALineDashType(rawValue: 1) }
                if style.id == "senior-trail" { renderer.reducePoint = false }
                return renderer
            }
        }
        func mapView(_ mapView: MAMapView!, regionDidChangeAnimated animated: Bool, wasUserAction: Bool) {
            let region = MKCoordinateRegion(center: mapView.region.center, span: MKCoordinateSpan(latitudeDelta: mapView.region.span.latitudeDelta, longitudeDelta: mapView.region.span.longitudeDelta))
            let context = AMapCameraContext(region: region, heading: Double(mapView.rotationDegree), wasUserAction: wasUserAction)
            #if DEBUG
            if probeSettled, !wasUserAction { probeSettled = false; AMapScaleProbe.record(mapView, page: "canvas", stage: "settled") }
            #endif
            var userCamera: MapCameraPosition?
            if wasUserAction {
                let camera = MapCameraPosition.camera(MapCamera(centerCoordinate: region.center, distance: region.span.latitudeDelta * 111_320, heading: context.heading, pitch: 0))
                // Drop any late programmatic request now so it cannot override the gesture.
                cameraGate.userMoved(to: camera)
                userCamera = camera
            }
            DispatchQueue.main.async { [weak self] in
                guard let self, !self.cameraGate.closed else { return }
                if let userCamera { self.parent.camera = userCamera }
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
