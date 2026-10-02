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
        var magic = 1 - 0.00669342162296594323 * pow(sin(rad), 2)
        let root = sqrt(magic)
        lat = lat * 180 / ((6335552.717000426 * (1 - 0.00669342162296594323)) / (magic*root) * pi)
        lon = lon * 180 / (6378245 / root * cos(rad) * pi)
        return GeoPoint(latitude: p.latitude + lat, longitude: p.longitude + lon)
    }
}

struct SafeZone: Decodable, Identifiable {
    let id: String
    let name: String
    let center: GeoPoint
    let radiusMeters: Double
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

    var isCurrent: Bool { coordinate.isValid && recordedAt <= Date().addingTimeInterval(60) && Date().timeIntervalSince(recordedAt) <= 300 }
    var validHeading: Double? { guard let heading, heading.isFinite, (0..<360).contains(heading) else { return nil }; return heading }
}

#if DEBUG
/// WGS-84 sample near the center of Nanjing University's Gulou Campus; never used by the live location flow.
enum LocationPreviewData {
    static let campus = GeoPoint(latitude: 32.05664, longitude: 118.77361)
    static let startingPoint = GeoPoint(latitude: 32.05780, longitude: 118.76940)
    static let midpoint = GeoPoint(latitude: 32.05720, longitude: 118.77180)
    static let address = "22 Hankou Road, Gulou District, Nanjing"
    static func snapshot(recordedAt: Date = Date()) -> ElderLocationSnapshot {
        ElderLocationSnapshot(coordinate: campus, recordedAt: recordedAt, heading: 120,
            status: "At Nanjing University", batteryPercent: 45, address: address,
            trail: [startingPoint, midpoint, campus],
            safeZones: [.init(id: "campus", name: "Campus", center: startingPoint, radiusMeters: 100)])
    }
}
#endif
