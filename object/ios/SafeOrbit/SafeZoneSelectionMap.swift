import SwiftUI
import CoreLocation
import MapTilerSDK
import UIKit

/// The editor alone uses WGS-84 vector tiles. The rest of the app keeps its Apple Maps adapter.
struct SafeZoneSelectionMap: View {
    let initialCenter: GeoPoint
    let radiusMeters: Int
    let onSelection: (GeoPoint) -> Void
    let onAvailability: (Bool) -> Void

    @State private var map: MTMapView
    @State private var pin: MTMarker
    @State private var circleSource: MTGeoJSONSource
    @State private var circleLayer: MTFillLayer
    @State private var selectedCenter: GeoPoint
    @State private var configured = false
    @State private var loaded = false
    @State private var issue: String?

    private var apiKey: String {
        (Bundle.main.object(forInfoDictionaryKey: "MapTilerAPIKey") as? String ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    init(initialCenter: GeoPoint, radiusMeters: Int,
         onSelection: @escaping (GeoPoint) -> Void, onAvailability: @escaping (Bool) -> Void) {
        self.initialCenter = initialCenter
        self.radiusMeters = radiusMeters
        self.onSelection = onSelection
        self.onAvailability = onAvailability
        let point = CLLocationCoordinate2D(latitude: initialCenter.latitude, longitude: initialCenter.longitude)
        let options = MTMapOptions(language: .country(.english), center: point, zoom: 16.5,
                                   maptilerLogoIsVisible: true, shouldPinchToRotateAndZoom: true,
                                   dragPanIsEnabled: true, attributionControlIsVisible: true,
                                   eventLevel: .all)
        _map = State(initialValue: MTMapView(frame: .zero, options: options, referenceStyle: .streets))
        _pin = State(initialValue: MTMarker(coordinates: point, icon: Self.pinImage(),
                                           draggable: true, anchor: .bottom))
        _circleSource = State(initialValue: MTGeoJSONSource(
            identifier: "selected-safe-zone", jsonString: Self.circleJSON(center: initialCenter, radius: radiusMeters)))
        let fill = MTFillLayer(identifier: "selected-safe-zone-fill", sourceIdentifier: "selected-safe-zone")
        fill.color = UIColor(red: 0.28, green: 0.47, blue: 0.46, alpha: 1)
        fill.opacity = 0.25
        fill.outlineColor = UIColor(red: 0.28, green: 0.47, blue: 0.46, alpha: 0.55)
        _circleLayer = State(initialValue: fill)
        _selectedCenter = State(initialValue: initialCenter)
    }

    var body: some View {
        ZStack {
            if configured {
                MTMapViewContainer(map: map) {
                    circleSource
                    circleLayer
                    pin
                }
                .didTriggerEvent { event, data in
                    if event == .didLoad {
                        loaded = true
                        issue = nil
                        onAvailability(true)
                    } else if event == .dragDidEnd, data?.id == pin.identifier,
                              let coordinate = data?.coordinate {
                        let point = GeoPoint(latitude: coordinate.latitude, longitude: coordinate.longitude)
                        guard point.isValid else { return }
                        selectedCenter = point
                        onSelection(point)
                        updateCircle()
                    }
                }
            } else {
                Color(red: 0.95, green: 0.97, blue: 0.96)
            }
            if let issue {
                VStack {
                    Text(issue)
                        .font(.system(size: 15, weight: .medium))
                        .multilineTextAlignment(.center)
                        .foregroundStyle(OrbitStyle.teal)
                        .padding(18)
                        .background(.white, in: RoundedRectangle(cornerRadius: 16))
                    Spacer()
                }
                .padding(.horizontal, 30)
                .padding(.top, 24)
            }
        }
        .task {
            guard !apiKey.isEmpty, !apiKey.contains("$(") else {
                issue = "Map unavailable. Add MAPTILER_API_KEY to Config/Local.xcconfig."
                onAvailability(false)
                return
            }
            await MTConfig.shared.setAPIKey(apiKey)
            configured = true
            try? await Task.sleep(for: .seconds(15))
            if !loaded {
                issue = "Map unavailable. Check the network or MapTiler key."
                onAvailability(false)
            }
        }
        .onChange(of: radiusMeters) { _, _ in updateCircle() }
    }

    private func updateCircle() {
        guard configured, loaded else { return }
        let json = Self.circleJSON(center: selectedCenter, radius: radiusMeters)
        guard let url = URL(string: "data:application/json;base64,\(Data(json.utf8).base64EncodedString())") else { return }
        Task { await circleSource.setData(data: url, in: map) }
    }

    static func circleJSON(center: GeoPoint, radius: Int) -> String {
        let latitudeRadius = Double(radius) / 111_320
        let longitudeRadius = latitudeRadius / max(0.01, cos(center.latitude * .pi / 180))
        let ring = (0...64).map { index -> [Double] in
            let angle = Double(index) * 2 * .pi / 64
            return [center.longitude + longitudeRadius * cos(angle),
                    center.latitude + latitudeRadius * sin(angle)]
        }
        let object: [String: Any] = ["type": "FeatureCollection", "features": [[
            "type": "Feature", "geometry": ["type": "Polygon", "coordinates": [ring]],
            "properties": [:] as [String: String]
        ]]]
        guard let data = try? JSONSerialization.data(withJSONObject: object),
              let json = String(data: data, encoding: .utf8) else { return "{}" }
        return json
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
