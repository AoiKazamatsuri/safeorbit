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
            AMapConsentPrompt(hasKey: AMapRuntime.hasKey) {
                UserDefaults.standard.set(true, forKey: AMapRuntime.consentKey)
                consent = true
            }
        }
    }
}

/// The map privacy consent shown in place of a map until the user agrees (device builds only).
/// Its text follows the system text size, and it scrolls when it is taller than the space the map
/// would take (product design section 10, rule 8).
struct AMapConsentPrompt: View {
    let hasKey: Bool
    let accept: () -> Void
    var body: some View {
        GeometryReader { viewport in
            ScrollView {
                VStack(spacing: 20) {
                    Image(systemName: "map.fill").orbitDisplayFont(40, weight: .regular).foregroundStyle(OrbitStyle.teal)
                        .accessibilityHidden(true)
                    Text(hasKey ? "Enable map services" : "Map configuration required")
                        .orbitDisplayFont(24).fixedSize(horizontal: false, vertical: true)
                        .layoutProbe("amap-consent-title")
                    if hasKey {
                        Text("AMap provides the map, location and walking routes. It processes location and device/network information to provide these services. Your location is used only while this app is open.")
                            .caregiverText().fixedSize(horizontal: false, vertical: true)
                            .layoutProbe("amap-consent-body")
                        Link(destination: URL(string: "https://lbs.amap.com/pages/privacy/")!) {
                            Text("AMap Privacy Policy").caregiverText().fixedSize(horizontal: false, vertical: true)
                                .layoutProbe("amap-consent-link-text")
                                .frame(minHeight: OrbitLayout.minimumHitSize).contentShape(Rectangle())
                        }
                        .layoutProbe("amap-consent-link")
                        Button(action: accept) {
                            Text("Agree and continue").caregiverText().fixedSize(horizontal: false, vertical: true)
                                .layoutProbe("amap-consent-accept-text")
                        }
                        .buttonStyle(.borderedProminent).controlSize(.large).tint(OrbitStyle.teal)
                        .accessibilityIdentifier("amap-consent-accept")
                        .layoutProbe("amap-consent-accept")
                    } else {
                        Text("Add the iOS SDK key to this device’s local build configuration.")
                            .caregiverText().fixedSize(horizontal: false, vertical: true)
                            .layoutProbe("amap-consent-body")
                    }
                }
                .multilineTextAlignment(.center).padding(OrbitLayout.centeredPageMargin)
                .layoutProbe("amap-consent-content")
                .frame(maxWidth: .infinity, minHeight: viewport.size.height)
            }
            .scrollBounceBehavior(.basedOnSize)
        }
        .background(OrbitStyle.pale).accessibilityIdentifier("amap-consent-surface")
    }
}
