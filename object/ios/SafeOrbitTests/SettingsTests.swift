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
        XCTAssertFalse(store.saveSenior(elder, relationship: "Mother", contacts: []))
        elder.timezone = "Asia/Shanghai"
        XCTAssertTrue(store.saveSenior(elder, relationship: "Mother", contacts: []))
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
    @MainActor func testLegacySettingsKeepProfilesMembersAndPreferences() throws {
        let suite = "org.safeorbit.settings-legacy." + UUID().uuidString
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let store = CaregiverSettingsStore(defaults: defaults)
        var caregiver = store.data.caregiver; caregiver.name = "Legacy caregiver"
        XCTAssertTrue(store.saveCaregiver(caregiver))
        XCTAssertTrue(store.saveMember(.init(name: "Legacy member", phone: "+12025550102")))
        store.set(\.autoNavigation, false)
        let raw = try XCTUnwrap(defaults.data(forKey: "safeorbit.caregiver.settings.v1"))
        var json = try XCTUnwrap(JSONSerialization.jsonObject(with: raw) as? [String: Any])
        var account = try XCTUnwrap(json["caregiver"] as? [String: Any]); account.removeValue(forKey: "email"); json["caregiver"] = account
        var members = try XCTUnwrap(json["members"] as? [[String: Any]])
        members[0].removeValue(forKey: "relationship"); json["members"] = members
        json.removeValue(forKey: "seniorRelationship"); json.removeValue(forKey: "emergencyContacts")
        defaults.set(try JSONSerialization.data(withJSONObject: json), forKey: "safeorbit.caregiver.settings.v1")
        let restored = CaregiverSettingsStore(defaults: defaults)
        XCTAssertEqual(restored.data.caregiver.name, "Legacy caregiver")
        XCTAssertEqual(restored.data.caregiver.email, "")
        XCTAssertEqual(restored.data.members.first?.name, "Legacy member")
        XCTAssertEqual(restored.data.members.first?.relationship, "")
        XCTAssertEqual(restored.data.seniorRelationship, "")
        XCTAssertTrue(restored.data.emergencyContacts.isEmpty)
        XCTAssertFalse(restored.data.autoNavigation)
    }
    @MainActor func testEmailAndEmergencyContactsCommitTogether() throws {
        let suite = "org.safeorbit.settings-contacts." + UUID().uuidString
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let store = CaregiverSettingsStore(defaults: defaults)
        var caregiver = store.data.caregiver; caregiver.email = "bad email"
        XCTAssertFalse(store.saveCaregiver(caregiver))
        caregiver.email = "demo@example.com"; XCTAssertTrue(store.saveCaregiver(caregiver))
        var contact = EmergencyContact(); contact.name = "Sample Contact"; contact.relationship = "Daughter"; contact.phone = "+12025550102"
        var profile = store.data.senior; profile.name = "Updated senior"; profile.callName = "Old name"
        XCTAssertFalse(store.saveSenior(profile, relationship: "", contacts: [contact]))
        var draft = [contact]; draft[0].phone = "invalid"
        XCTAssertFalse(store.saveSenior(profile, relationship: "Mother", contacts: draft))
        XCTAssertTrue(CaregiverSettingsStore(defaults: defaults).data.emergencyContacts.isEmpty)
        XCTAssertEqual(store.data.senior.name, "Li Lan")
        XCTAssertTrue(store.saveSenior(profile, relationship: "Mother", contacts: [contact]))
        let restored = CaregiverSettingsStore(defaults: defaults)
        XCTAssertEqual(restored.data.senior.callName, "Updated senior")
        XCTAssertEqual(restored.data.senior.timezone, TimeZone.current.identifier)
        XCTAssertEqual(restored.data.emergencyContacts, [contact])
        contact.name = "Edited Contact"
        XCTAssertTrue(store.saveSenior(profile, relationship: "Mother", contacts: [contact]))
        XCTAssertEqual(store.data.emergencyContacts.first?.name, "Edited Contact")
        XCTAssertTrue(store.saveSenior(profile, relationship: "Mother", contacts: []))
        XCTAssertTrue(CaregiverSettingsStore(defaults: defaults).data.emergencyContacts.isEmpty)
        XCTAssertEqual(store.data.caregiver.email, "demo@example.com")
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
        let folder = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent("FrontendSnapshots/settings-revision")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let member = LocalFamilyMember(name: "Sample Member", phone: "+12025550102", relationship: "Daughter")
        let contact = EmergencyContact(name: "Sample Contact", relationship: "Son", phone: "+12025550103")
        var pages: [(String, AnyView)] = CaregiverSettingsItem.allCases.map {
            ($0.rawValue.lowercased().replacingOccurrences(of: " ", with: "-"), AnyView(CaregiverSettingsDetail(item: $0, settings: store, onboarding: onboarding, zones: zones, back: {})))
        }
        pages += [
            ("member-detail", AnyView(SettingsMemberDetail(member: member, isSelf: false, settings: store, back: {}))),
            ("self-detail", AnyView(SettingsMemberDetail(member: .init(id: "self", name: "Emma Liu", phone: "+12025550101"), isSelf: true, settings: store, back: {}))),
            ("emergency-contact", AnyView(EmergencyContactEditor(contact: contact, save: { _ in }, back: {}))),
            ("privacy-policy", AnyView(SettingsPage("Privacy Policy", back: {}) { SettingsCard { SettingsNote(text: "A formal privacy policy has not been provided for this classroom demo. This page is not a published privacy policy.") } }))
        ]
        for (pageName, page) in pages {
            for largeText in [false, true] {
                let window = UIWindow(windowScene: scene)
                window.frame = CGRect(origin: .zero, size: CGSize(width: largeText ? 375 : 393, height: largeText ? 812 : 852))
                window.rootViewController = UIHostingController(rootView:
                    page
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
                let name = pageName + (largeText ? "-large" : "")
                try raw.write(to: folder.appendingPathComponent(name + ".png"))
                let attachment = XCTAttachment(data: raw, uniformTypeIdentifier: "public.png")
                attachment.name = name; attachment.lifetime = .keepAlways; add(attachment)
                window.isHidden = true; previous?.makeKeyAndVisible()
            }
        }
    }
}
