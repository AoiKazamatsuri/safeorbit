import Foundation
import CoreLocation

/// Coordinates received from the care API are WGS-84. Convert only when handing a mainland point to Apple maps.
struct GeoPoint: Codable, Equatable {
    let latitude: Double
    let longitude: Double
    var isValid: Bool { latitude.isFinite && longitude.isFinite && (-90...90).contains(latitude) && (-180...180).contains(longitude) }
    var appleCoordinate: CLLocationCoordinate2D {
        let point = MainlandCoordinates.toGCJ02(self)
        return CLLocationCoordinate2D(latitude: point.latitude, longitude: point.longitude)
    }
}

enum MainlandCoordinates {
    // Mainland bounds are deliberately conservative; Hong Kong, Macau and Taiwan remain WGS-84.
    static func applies(to p: GeoPoint) -> Bool {
        p.isValid && (18.0...53.6).contains(p.latitude) && (73.6...135.1).contains(p.longitude)
        && !(p.latitude < 22.6 && p.longitude > 113.5 && p.longitude < 114.6)
        && !(p.latitude < 25.5 && p.longitude > 119.2 && p.longitude < 122.1)
    }
    static func toGCJ02(_ p: GeoPoint) -> GeoPoint {
        guard applies(to: p) else { return p }
        let x = p.longitude - 105, y = p.latitude - 35
        let pi = Double.pi
        var lat = -100 + 2*x + 3*y + 0.2*y*y + 0.1*x*y + 0.2*sqrt(abs(x))
        lat += (20*sin(6*x*pi) + 20*sin(2*x*pi))*2/3
        lat += (20*sin(y*pi) + 40*sin(y*pi/3))*2/3
        lat += (160*sin(y*pi/12) + 320*sin(y*pi/30))*2/3
        var lon = 300 + x + 2*y + 0.1*x*x + 0.1*x*y + 0.1*sqrt(abs(x))
        lon += (20*sin(6*x*pi) + 20*sin(2*x*pi))*2/3
        lon += (20*sin(x*pi) + 40*sin(x*pi/3))*2/3
        lon += (150*sin(x*pi/12) + 300*sin(x*pi/30))*2/3
        let rad = p.latitude / 180 * pi
        let magic = 1 - 0.00669342162296594323 * pow(sin(rad), 2)
        let root = sqrt(magic)
        lat = lat * 180 / ((6335552.717000426 * (1 - 0.00669342162296594323)) / (magic*root) * pi)
        lon = lon * 180 / (6378245 / root * cos(rad) * pi)
        return GeoPoint(latitude: p.latitude + lat, longitude: p.longitude + lon)
    }

    /// Undo the display conversion for a point selected on the Apple map.
    static func toWGS84(_ point: GeoPoint) -> GeoPoint {
        guard applies(to: point) else { return point }
        var estimate = point
        for _ in 0..<6 {
            let projected = toGCJ02(estimate)
            estimate = GeoPoint(latitude: estimate.latitude + point.latitude - projected.latitude,
                                longitude: estimate.longitude + point.longitude - projected.longitude)
        }
        return estimate
    }
}

struct SafeZone: Decodable, Identifiable {
    let id: String
    let name: String
    let center: GeoPoint
    let radiusMeters: Double
    /// Sent by the care API; older samples leave it out and the name decides.
    var isHome: Bool? = nil
    var renderKey: String { "\(id):\(name):\(center.latitude):\(center.longitude):\(radiusMeters)" }
    var isHomeZone: Bool { isHome ?? (name.trimmingCharacters(in: .whitespaces).lowercased() == "home") }
}

struct ElderLocationSnapshot: Decodable {
    let coordinate: GeoPoint
    let recordedAt: Date
    let heading: Double?
    let status: String?
    let batteryPercent: Int?
    let address: String?
    let trail: [GeoPoint]
    let safeZones: [SafeZone]
    // Task T38: decided by the care agent. Optional so older replies and the fixed sample still decode.
    var riskLevel: String? = nil
    /// e.g. "Wandering for 7 minutes"; null while normal.
    var riskHeadline: String? = nil
    var riskAnomaly: String? = nil
    var riskSince: Date? = nil
    /// The active risk event, else one resolved within the last 30 minutes.
    var riskEventId: String? = nil
    var riskEventStatus: String? = nil
    /// "Monitoring" or "Learning daily routes (n/5 trips)", shown under her name.
    var agentStatus: String? = nil

    var isCurrent: Bool { coordinate.isValid && recordedAt <= Date().addingTimeInterval(60) && Date().timeIntervalSince(recordedAt) <= 300 }
    var validHeading: Double? { guard let heading, heading.isFinite, (0..<360).contains(heading) else { return nil }; return heading }
    var riskState: CaregiverRiskState { riskLevel.flatMap(CaregiverRiskState.init(rawValue:)) ?? .normal }
}

/// Illustrative road-aligned sample near Nanjing University's Gulou Campus; never used by the live location flow.
enum LocationPreviewData {
    // Interior points are the vertices of an Apple Maps walking route (MapKit
    // coordinates, fetched once on 2026-10-15) along Beijing West Road and
    // Ninghai Road, so the trail follows the roads instead of cutting corners.
    // The first and last points keep the original sample endpoints, 3 m and
    // 25 m from the route ends. MapKit coordinates are converted to the WGS-84
    // form used by snapshots and the live API.
    private static let walkingMapGeometry = [
        GeoPoint(latitude: 32.0600471, longitude: 118.7665265),
        GeoPoint(latitude: 32.0596075, longitude: 118.7695238),
        GeoPoint(latitude: 32.0595431, longitude: 118.7700819),
        GeoPoint(latitude: 32.0595270, longitude: 118.7701677),
        GeoPoint(latitude: 32.0594706, longitude: 118.7701946),
        GeoPoint(latitude: 32.0576495, longitude: 118.7709991),
        GeoPoint(latitude: 32.0568178, longitude: 118.7713961),
        GeoPoint(latitude: 32.0567159, longitude: 118.7715947),
        GeoPoint(latitude: 32.0566731, longitude: 118.7717071),
        GeoPoint(latitude: 32.0566797, longitude: 118.7717591),
        GeoPoint(latitude: 32.0564731, longitude: 118.7718559)]
    static let trail = walkingMapGeometry.map(MainlandCoordinates.toWGS84)
    static let startingPoint = trail[0]
    static let campus = trail[trail.count - 1]
    static let address = "Ninghai Road, Gulou District, Nanjing"
    static func snapshot(recordedAt: Date = Date()) -> ElderLocationSnapshot {
        ElderLocationSnapshot(coordinate: campus, recordedAt: recordedAt, heading: 120,
            status: "At Nanjing University", batteryPercent: 45, address: address,
            trail: trail,
            safeZones: [.init(id: "campus", name: "Campus", center: startingPoint, radiusMeters: 200)])
    }
}
