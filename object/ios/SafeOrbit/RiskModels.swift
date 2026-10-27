import Foundation
import CoreLocation

// Care API shapes added for risk and alerts (task T38). Ids are integer strings, times ISO 8601 UTC,
// coordinates WGS-84.

/// An action the care API hands the elder phone in a location upload reply. The same action repeats in
/// later replies until its result is posted, it expires or it is withdrawn.
struct ElderAction: Decodable, Equatable {
    static let startNavigation = "startNavigation"
    let id: String
    let type: String
    let riskEventId: String?
    let expiresAt: Date?
}
struct ActionResultBody: Encodable, Equatable {
    let result: String
    let reason: String?
    static let started = ActionResultBody(result: "started", reason: nil)
    /// The care API accepts at most 200 characters.
    static func failed(_ reason: String) -> ActionResultBody {
        ActionResultBody(result: "failed", reason: String(reason.prefix(200)))
    }
}
struct ActionResultReply: Decodable { let id: String; let status: String }

/// The four agent and notification switches the care API acts on. High-risk alerts are always on.
struct CaregiverServerSettings: Codable, Equatable {
    var autoNavigation: Bool
    var lowRiskNotifications: Bool
    var recoveryNotifications: Bool
    var limitedMonitoringNotifications: Bool
}

/// Risk event page data (product design section 5.3). Help and timeline rows use the server's text.
struct RiskEventDetail: Decodable, Equatable, Identifiable {
    struct Help: Decodable, Equatable { let kind: String; let status: String; let text: String; let at: Date }
    struct TimelineItem: Decodable, Equatable { let at: Date; let kind: String; let text: String }
    let id: String
    let level: String
    let status: String
    let anomaly: String
    let anomalyStartedAt: Date
    let openedAt: Date
    let escalatedAt: Date?
    let resolvedAt: Date?
    let resolution: String?
    let falseAlarm: Bool
    let headline: String
    let durationMinutes: Int
    let canMarkFalseAlarm: Bool
    let explanation: String?
    let coordinate: GeoPoint?
    let recordedAt: Date?
    let trail: [GeoPoint]
    let help: [Help]
    let timeline: [TimelineItem]

    var isActive: Bool { status == "active" }
    var riskState: CaregiverRiskState { level == "high" ? .high : .warning }
    /// "We've Met" resolves an active risk; afterwards only "Mark as False Alarm" remains (once).
    var canMarkMet: Bool { isActive }
    var anomalyText: String { anomaly == "deviation" ? "Off her usual route" : "Wandering" }
    var statusText: String {
        if falseAlarm { return "Resolved · marked as false alarm" }
        guard !isActive else { return "In progress" }
        switch resolution {
        case "met": return "Resolved · you met her"
        case "home": return "Resolved · back home"
        default: return "Resolved"
        }
    }
    var durationText: String { "\(durationMinutes) minute\(durationMinutes == 1 ? "" : "s")" }
}

/// Planned walking route from home to a safe zone, uploaded so the care agent can judge deviation.
struct ReferenceRouteBody: Encodable { let points: [GeoPoint] }
struct ReferenceRouteReply: Decodable { let zoneId: String; let pointCount: Int }

enum ReferenceRoute {
    static let maxPoints = 5000
    /// AMap returns GCJ-02 display coordinates; the care API stores WGS-84 (engineering architecture
    /// section 10). Long routes are thinned evenly, always keeping both ends.
    static func wgs84(_ coordinates: [CLLocationCoordinate2D]) -> [GeoPoint] {
        let points = coordinates.map { MainlandCoordinates.toWGS84(GeoPoint(latitude: $0.latitude, longitude: $0.longitude)) }
            .filter(\.isValid)
        guard points.count > maxPoints else { return points }
        let step = Double(points.count - 1) / Double(maxPoints - 1)
        return (0..<maxPoints).map { points[Int((Double($0) * step).rounded())] }
    }
}

@MainActor protocol ReferenceRoutePlanning {
    /// WGS-84 walking route from `from` to `to`.
    func plan(from: GeoPoint, to: GeoPoint) async throws -> [GeoPoint]
}
/// Uses AMap walking route planning; on the simulator AMap is compiled out and this throws `sdkNotReady`.
@MainActor final class AMapReferenceRoutePlanner: ReferenceRoutePlanning {
    private let provider = AMapWalkingRouteProvider()
    func plan(from: GeoPoint, to: GeoPoint) async throws -> [GeoPoint] {
        ReferenceRoute.wgs84(try await provider.route(from: from, to: to).coordinates)
    }
}
