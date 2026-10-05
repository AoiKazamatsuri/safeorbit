import XCTest
import SwiftUI
@testable import SafeOrbit

final class SettingsTests: XCTestCase {
    @MainActor func testProfilesValidateAndPersistWithoutSavingDraft() throws {
        let suite = "org.safeorbit.settings-test." + UUID().uuidString
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let store = CaregiverSettingsStore(defaults: defaults)
        var draft = store.data.caregiver
        draft.name = "Updated caregiver"
        XCTAssertEqual(CaregiverSettingsStore(defaults: defaults).data.caregiver.name, "Emma Liu")
        draft.phone = "invalid"
        XCTAssertFalse(store.saveCaregiver(draft))
        XCTAssertEqual(store.data.caregiver.name, "Emma Liu")
        draft.phone = "+86 138 0000 0000"
        XCTAssertTrue(store.saveCaregiver(draft))
        var elder = store.data.senior
        elder.name = "  Test senior  "; elder.callName = ""; elder.timezone = "invalid/timezone"
        XCTAssertFalse(store.saveSenior(elder))
        elder.timezone = "Asia/Shanghai"
        XCTAssertTrue(store.saveSenior(elder))
        let reopened = CaregiverSettingsStore(defaults: defaults)
        XCTAssertEqual(reopened.data.caregiver.name, "Updated caregiver")
        XCTAssertEqual(reopened.data.caregiver.phone, "+8613800000000")
        XCTAssertEqual(reopened.data.senior.name, "Test senior")
        XCTAssertEqual(reopened.data.senior.callName, "Test senior")
    }
    @MainActor func testFamilyPrimaryRemainsValidAfterRemovalAndReload() throws {
        let suite = "org.safeorbit.settings-test." + UUID().uuidString
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let store = CaregiverSettingsStore(defaults: defaults)
        XCTAssertFalse(store.saveMember(.init(id: "self", name: "Invalid duplicate", phone: "+12025550100")))
        let member = LocalFamilyMember(name: "Another caregiver", phone: "+12025550102")
        XCTAssertTrue(store.saveMember(member))
        store.makePrimary(member.id)
        XCTAssertEqual(CaregiverSettingsStore(defaults: defaults).data.primaryID, member.id)
        store.makePrimary("unknown")
        XCTAssertEqual(store.data.primaryID, member.id)
        store.removeMember(member.id)
        XCTAssertEqual(store.data.primaryID, "self")
        XCTAssertTrue(CaregiverSettingsStore(defaults: defaults).data.members.isEmpty)
    }
    @MainActor func testPreferencesPersistAndCorruptDataFallsBack() throws {
        let suite = "org.safeorbit.settings-test." + UUID().uuidString
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let store = CaregiverSettingsStore(defaults: defaults)
        store.set(\.autoNavigation, false)
        store.set(\.lowRiskNotifications, false)
        store.set(\.recoveryNotifications, false)
        store.set(\.limitedMonitoringNotifications, false)
        let reopened = CaregiverSettingsStore(defaults: defaults)
        XCTAssertFalse(reopened.data.autoNavigation)
        XCTAssertFalse(reopened.data.lowRiskNotifications)
        XCTAssertFalse(reopened.data.recoveryNotifications)
        XCTAssertFalse(reopened.data.limitedMonitoringNotifications)
        defaults.set(Data("bad-json".utf8), forKey: "safeorbit.caregiver.settings.v1")
        XCTAssertEqual(CaregiverSettingsStore(defaults: defaults).data, CaregiverSettingsData())
    }
    @MainActor func testSettingsPagesSnapshots() async throws {
        let suite = "org.safeorbit.settings-snapshots." + UUID().uuidString
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let store = CaregiverSettingsStore(defaults: defaults)
        let onboarding = OnboardingStore(homeAccessEnabled: true)
        let zones = SafeZoneSessionStore()
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.first as? UIWindowScene)
        let previous = scene.windows.first(where: \.isKeyWindow)
        let folder = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent("FrontendSnapshots/settings")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        for item in CaregiverSettingsItem.allCases {
            for largeText in [false, true] {
                let window = UIWindow(windowScene: scene)
                window.frame = CGRect(origin: .zero, size: CGSize(width: largeText ? 375 : 393, height: largeText ? 812 : 852))
                window.rootViewController = UIHostingController(rootView:
                    CaregiverSettingsDetail(item: item, settings: store, onboarding: onboarding, zones: zones, back: {})
                        .environment(\.dynamicTypeSize, largeText ? .accessibility1 : .large)
                        .environment(\.colorScheme, .light))
                window.makeKeyAndVisible()
                window.rootViewController?.view.frame = window.bounds
                window.rootViewController?.view.layoutIfNeeded()
                try await Task.sleep(for: .milliseconds(300))
                let image = UIGraphicsImageRenderer(size: window.bounds.size).image { _ in
                    window.rootViewController!.view.drawHierarchy(in: window.bounds, afterScreenUpdates: true)
                }
                let raw = try XCTUnwrap(image.pngData())
                let name = item.rawValue.lowercased().replacingOccurrences(of: " ", with: "-") + (largeText ? "-large" : "")
                try raw.write(to: folder.appendingPathComponent(name + ".png"))
                let attachment = XCTAttachment(data: raw, uniformTypeIdentifier: "public.png")
                attachment.name = name; attachment.lifetime = .keepAlways; add(attachment)
                window.isHidden = true; previous?.makeKeyAndVisible()
            }
        }
    }
}
