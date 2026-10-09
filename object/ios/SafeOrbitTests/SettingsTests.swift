import XCTest
import SwiftUI
@testable import SafeOrbit

final class SettingsTests: XCTestCase {
    @MainActor func testSettingsSlideEntersFromLeftAndLeavesToLeft() async throws {
        try await verifySlide(reduceMotion: false)
    }
    @MainActor func testSettingsSlideReduceMotionDoesNotMoveHorizontally() async throws {
        try await verifySlide(reduceMotion: true)
    }
    @MainActor private func verifySlide(reduceMotion: Bool) async throws {
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.first as? UIWindowScene)
        let previous = scene.windows.first(where: \.isKeyWindow)
        let window = UIWindow(windowScene: scene)
        window.frame = CGRect(x: 0, y: 0, width: 393, height: 852)
        let state = SlideTestState()
        let marker = UIView()
        marker.backgroundColor = .red
        window.rootViewController = UIHostingController(rootView: SlideTestPage(state: state, marker: marker, reduceMotion: reduceMotion))
        window.makeKeyAndVisible()
        defer { window.isHidden = true; previous?.makeKeyAndVisible() }
        try await Task.sleep(for: .milliseconds(100))
        state.item = .init(id: "detail")
        try await Task.sleep(for: .milliseconds(120))
        let entering = try slideFrame(marker, in: window)
        if reduceMotion { XCTAssertEqual(entering.minX, 0, accuracy: 1) }
        else { XCTAssertLessThan(entering.minX, -1); XCTAssertGreaterThan(entering.maxX, 1) }
        try await Task.sleep(for: .milliseconds(250))
        XCTAssertEqual(try slideFrame(marker, in: window).minX, 0, accuracy: 1)
        state.item = nil
        try await Task.sleep(for: .milliseconds(100))
        let leaving = try slideFrame(marker, in: window)
        if reduceMotion { XCTAssertEqual(leaving.minX, 0, accuracy: 1) }
        else { XCTAssertLessThan(leaving.minX, -1); XCTAssertGreaterThan(leaving.maxX, 1) }
        try await Task.sleep(for: .milliseconds(300))
        XCTAssertNil(marker.window, "Outgoing detail must be removed so its draft resets on re-entry")
        state.item = .init(id: "another-detail")
        try await Task.sleep(for: .milliseconds(350))
        XCTAssertNotNil(marker.window, "Settings must support reopening after returning")
    }
    @MainActor private func slideFrame(_ marker: UIView, in window: UIWindow) throws -> CGRect {
        XCTAssertNotNil(marker.window, "The destination must remain mounted during its exit animation")
        let layer = try XCTUnwrap(marker.layer.presentation())
        return layer.convert(layer.bounds, to: window.layer.presentation() ?? window.layer)
    }

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
        store.set(\.allowAITripHistory, false)
        store.set(\.autoNavigation, false)
        store.set(\.lowRiskNotifications, false)
        store.set(\.recoveryNotifications, false)
        store.set(\.limitedMonitoringNotifications, false)
        let reopened = CaregiverSettingsStore(defaults: defaults)
        XCTAssertFalse(reopened.data.allowAITripHistory)
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
        json.removeValue(forKey: "allowAITripHistory")
        var account = try XCTUnwrap(json["caregiver"] as? [String: Any]); account.removeValue(forKey: "email"); json["caregiver"] = account
        var members = try XCTUnwrap(json["members"] as? [[String: Any]])
        members[0].removeValue(forKey: "relationship"); json["members"] = members
        json.removeValue(forKey: "seniorRelationship"); json.removeValue(forKey: "emergencyContacts")
        defaults.set(try JSONSerialization.data(withJSONObject: json), forKey: "safeorbit.caregiver.settings.v1")
        let restored = CaregiverSettingsStore(defaults: defaults)
        XCTAssertTrue(restored.data.allowAITripHistory)
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
    @MainActor func testInlineProfileGroupsSaveIndependentlyAndDiscardUnsavedDrafts() throws {
        let suite = "org.safeorbit.inline." + UUID().uuidString
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let store = CaregiverSettingsStore(defaults: defaults)
        let account = SettingsProfileDraft(data: store.data, senior: false)
        let senior = SettingsProfileDraft(data: store.data, senior: true)
        account.caregiver.name = "Account saved"
        senior.profile.name = "Senior draft"
        senior.relationship = "Mother"
        let contact = EmergencyContact(name: "Draft contact", relationship: "Son", phone: "+12025550103")
        senior.updateContact(contact)
        account.save(to: store)
        XCTAssertTrue(account.saved)
        XCTAssertFalse(senior.saved)
        XCTAssertEqual(senior.profile.name, "Senior draft")
        XCTAssertEqual(senior.contacts, [contact])
        var reopened = CaregiverSettingsStore(defaults: defaults)
        XCTAssertEqual(reopened.data.caregiver.name, "Account saved")
        XCTAssertEqual(reopened.data.senior.name, "Li Lan")
        XCTAssertTrue(reopened.data.emergencyContacts.isEmpty)
        account.caregiver.email = "unsaved@example.com"
        XCTAssertFalse(account.saved)
        senior.save(to: store)
        XCTAssertTrue(senior.saved)
        XCTAssertEqual(account.caregiver.email, "unsaved@example.com")
        reopened = CaregiverSettingsStore(defaults: defaults)
        XCTAssertEqual(reopened.data.caregiver.email, "")
        XCTAssertEqual(reopened.data.senior.name, "Senior draft")
        XCTAssertEqual(reopened.data.emergencyContacts, [contact])
        XCTAssertEqual(SettingsProfileDraft(data: reopened.data, senior: false).caregiver.email, "")
        senior.contacts.removeAll()
        XCTAssertFalse(senior.saved)
        XCTAssertEqual(reopened.data.emergencyContacts, [contact])
    }
    @MainActor func testInlineProfileLoadingAndValidationAreIsolated() throws {
        let suite = "org.safeorbit.inline-loading." + UUID().uuidString
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let store = CaregiverSettingsStore(defaults: defaults)
        let account = SettingsProfileDraft(data: store.data, senior: false)
        let senior = SettingsProfileDraft(data: store.data, senior: true)
        senior.relationship = "Mother"
        account.photoLoading = true
        XCTAssertFalse(account.canSave)
        XCTAssertTrue(senior.canSave)
        account.caregiver.name = "Loading draft"
        account.save(to: store)
        XCTAssertEqual(store.data.caregiver.name, "Emma Liu")
        senior.save(to: store)
        XCTAssertTrue(senior.saved)
        account.photoLoading = false
        account.caregiver.email = "invalid email"
        XCTAssertFalse(account.canSave)
        XCTAssertTrue(senior.canSave)
        account.save(to: store)
        XCTAssertEqual(store.data.caregiver.name, "Emma Liu")
        account.caregiver.email = ""
        account.save(to: store)
        XCTAssertTrue(account.saved)
        senior.photoLoading = true
        XCTAssertFalse(senior.canSave)
        XCTAssertTrue(account.canSave)
        account.caregiver.photo = "new-photo-draft"
        XCTAssertFalse(account.saved)
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
        let folder = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent("FrontendSnapshots/settings-inline")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let member = LocalFamilyMember(name: "Sample Member", phone: "+12025550102", relationship: "Daughter")
        let contact = EmergencyContact(name: "Sample Contact", relationship: "Son", phone: "+12025550103")
        var pages: [(String, AnyView)] = CaregiverSettingsGroup.allCases.map {
            ($0.rawValue.lowercased().replacingOccurrences(of: " ", with: "-"), AnyView(CaregiverSettingsGroupPage(group: $0, settings: store, onboarding: onboarding, zones: zones, back: {})))
        }
        pages += [
            ("member-detail", AnyView(SettingsMemberDetail(member: member, isSelf: false, settings: store, back: {}))),
            ("self-detail", AnyView(SettingsMemberDetail(member: .init(id: "self", name: "Emma Liu", phone: "+12025550101"), isSelf: true, settings: store, back: {}))),
            ("emergency-contact", AnyView(EmergencyContactEditor(contact: contact, save: { _ in }, back: {}))),
            ("privacy-policy", AnyView(SettingsPrivacyPage(back: {})))
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
                if pageName == "profiles-&-family", let scroll = findScrollView(window.rootViewController!.view) {
                    XCTAssertGreaterThan(scroll.contentSize.height, scroll.bounds.height)
                    scroll.setContentOffset(CGPoint(x: 0, y: max(0, scroll.contentSize.height - scroll.bounds.height + scroll.adjustedContentInset.bottom)), animated: false)
                    try await Task.sleep(for: .milliseconds(200))
                    let bottom = UIGraphicsImageRenderer(size: window.bounds.size).image { _ in
                        window.rootViewController!.view.drawHierarchy(in: window.bounds, afterScreenUpdates: true)
                    }
                    let bottomRaw = try XCTUnwrap(bottom.pngData())
                    try bottomRaw.write(to: folder.appendingPathComponent(name + "-bottom.png"))
                }
                window.isHidden = true; previous?.makeKeyAndVisible()
            }
        }
    }
    @MainActor private func findScrollView(_ view: UIView) -> UIScrollView? {
        if let scroll = view as? UIScrollView { return scroll }
        for child in view.subviews { if let scroll = findScrollView(child) { return scroll } }
        return nil
    }

}

private struct SlideTestItem: Identifiable { let id: String }
@MainActor private final class SlideTestState: ObservableObject {
    @Published var item: SlideTestItem?
}
private struct SlideTestMarker: UIViewRepresentable {
    let view: UIView
    func makeUIView(context: Context) -> UIView { view }
    func updateUIView(_ uiView: UIView, context: Context) {}
}
private struct SlideTestPage: View {
    @ObservedObject var state: SlideTestState
    let marker: UIView
    let reduceMotion: Bool
    var body: some View {
        if reduceMotion {
            Color.blue.modifier(SettingsSlideModifier(isPresented: state.item != nil, reduceMotionOverride: true) {
                SlideTestMarker(view: marker)
            })
        } else {
            Color.blue.settingsSlide(item: $state.item) { _ in SlideTestMarker(view: marker) }
        }
    }
}
