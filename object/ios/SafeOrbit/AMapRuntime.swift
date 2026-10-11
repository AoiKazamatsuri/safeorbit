import SwiftUI
#if !targetEnvironment(simulator)
import AMapFoundationKit
import AMapNaviKit
import AMapLocationKit
import AMapSearchKit
#endif

/// SDK construction follows the user's on-device consent; configuration never contains a repository key.
@MainActor enum AMapRuntime {
    static let consentKey = "safeorbit.amap.consent.v1"
    static var hasConsent: Bool { UserDefaults.standard.bool(forKey: consentKey) }
    static var hasKey: Bool {
        guard let key = Bundle.main.object(forInfoDictionaryKey: "AMapAPIKey") as? String else { return false }
        return !key.isEmpty && !key.contains("$(")
    }
    static func prepare() -> Bool {
        guard hasConsent, hasKey else { return false }
        #if targetEnvironment(simulator)
        return false
        #else
        let services = AMapServices.shared()!
        services.apiKey = Bundle.main.object(forInfoDictionaryKey: "AMapAPIKey") as? String
        services.enableHTTPS = true
        services.regionLanguageType = .en
        services.analysisAgree = false
        MAMapView.updatePrivacyShow(.didShow, privacyInfo: .didContain)
        MAMapView.updatePrivacyAgree(.didAgree)
        AMapLocationManager.updatePrivacyShow(.didShow, privacyInfo: .didContain)
        AMapLocationManager.updatePrivacyAgree(.didAgree)
        AMapSearchAPI.updatePrivacyShow(.didShow, privacyInfo: .didContain)
        AMapSearchAPI.updatePrivacyAgree(.didAgree)
        return true
        #endif
    }
}

struct AMapConsentSurface<Content: View>: View {
    @AppStorage(AMapRuntime.consentKey) private var consent = false
    @ViewBuilder let content: () -> Content
    private var displaysWithoutConsent: Bool {
        #if targetEnvironment(simulator)
        return true
        #else
        return !AMapRuntime.hasKey
        #endif
    }
    var body: some View {
        if displaysWithoutConsent || consent { content() }
        else {
            VStack(spacing: 20) {
                Image(systemName: "map.fill").font(.system(size: 40)).foregroundStyle(OrbitStyle.teal)
                Text(AMapRuntime.hasKey ? "Enable map services" : "Map configuration required")
                    .font(.system(size: 24, weight: .medium))
                if AMapRuntime.hasKey {
                    Text("AMap provides the map, location and walking routes. It processes location and device/network information to provide these services. Your location is used only while this app is open.")
                        .font(.system(size: 16, weight: .medium))
                    Link("AMap Privacy Policy", destination: URL(string: "https://lbs.amap.com/pages/privacy/")!)
                    Button("Agree and continue") {
                        UserDefaults.standard.set(true, forKey: AMapRuntime.consentKey)
                        consent = true
                    }.buttonStyle(.borderedProminent).tint(OrbitStyle.teal)
                        .accessibilityIdentifier("amap-consent-accept")
                } else {
                    Text("Add the iOS SDK key to this device’s local build configuration.")
                        .font(.system(size: 16, weight: .medium))
                }
            }.multilineTextAlignment(.center).padding(32).frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(OrbitStyle.pale).accessibilityIdentifier("amap-consent-surface")
        }
    }
}
