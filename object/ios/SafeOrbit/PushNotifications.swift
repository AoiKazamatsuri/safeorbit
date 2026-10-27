import UIKit
import UserNotifications

/// Where a tapped notification leads (product design section 5.9, task T38).
enum NotificationRoute: Equatable {
    /// Low risk and risk resolved: the caregiver's location page.
    case location
    /// High risk: the caregiver's risk event page.
    case riskEvent(String)
    /// Elder fallback "Tap to start navigation home".
    case elderStartNavigation

    /// Caregiver pushes carry `kind` (riskLow, riskHigh, riskResolved) and `riskEventId` beside `aps`.
    static func from(userInfo: [AnyHashable: Any]) -> NotificationRoute? {
        let eventID = (userInfo["riskEventId"] as? String) ?? (userInfo["riskEventId"] as? NSNumber)?.stringValue
        switch userInfo["kind"] as? String {
        case "riskHigh": return eventID.map { .riskEvent($0) } ?? .location
        case "riskLow", "riskResolved": return .location
        case ElderFallbackNotification.kind: return .elderStartNavigation
        default: return nil
        }
    }
    var role: DemoAppRole { self == .elderStartNavigation ? .elder : .caregiver }
}

/// Hands notification taps and the APNs token from the app delegate to the pages.
@MainActor final class NotificationRouter: ObservableObject {
    static let shared = NotificationRouter()
    /// Hex APNs device token, once iOS has registered this phone for remote notifications.
    @Published private(set) var pushToken: String?
    /// The latest tapped notification, until a page takes it.
    @Published private(set) var pending: NotificationRoute?

    func open(_ route: NotificationRoute) { pending = route }
    /// Returns the pending route when it belongs to `role`, and clears it.
    func take(for role: DemoAppRole) -> NotificationRoute? {
        guard let route = pending, route.role == role else { return nil }
        pending = nil
        return route
    }
    func receive(deviceToken: Data) { pushToken = Self.hex(deviceToken) }
    static func hex(_ token: Data) -> String { token.map { String(format: "%02x", $0) }.joined() }

    /// Asks once per install; later calls only re-register for a token.
    static func requestAuthorization(remote: Bool) async {
        let granted = (try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge])) ?? false
        if remote && granted { UIApplication.shared.registerForRemoteNotifications() }
    }
}

final class SafeOrbitAppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        return true
    }
    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        Task { @MainActor in NotificationRouter.shared.receive(deviceToken: deviceToken) }
    }
    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        // Without a token the care API simply has no phone to push to; polling keeps the page current.
    }
    // Shown as a banner while the app is open, too.
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification) async -> UNNotificationPresentationOptions {
        [.banner, .list, .sound]
    }
    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse) async {
        guard response.actionIdentifier == UNNotificationDefaultActionIdentifier,
              let route = NotificationRoute.from(userInfo: response.notification.request.content.userInfo) else { return }
        await MainActor.run { NotificationRouter.shared.open(route) }
    }
}
