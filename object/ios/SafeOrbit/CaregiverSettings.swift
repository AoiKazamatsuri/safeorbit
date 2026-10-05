import SwiftUI
import PhotosUI

// Settings belong to this device until account and family services are connected.
struct LocalCaregiver: Codable, Equatable {
    var name = "Emma Liu"
    var phone = "+12025550101"
    var photo: String?
    var isValid: Bool { !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && name.count <= 60 && PhoneNumber.isValid(phone) }
}
struct LocalFamilyMember: Codable, Equatable, Identifiable {
    var id = UUID().uuidString
    var name: String
    var phone: String
    var isValid: Bool { !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && name.count <= 60 && PhoneNumber.isValid(phone) }
}
struct CaregiverSettingsData: Codable, Equatable {
    var caregiver = LocalCaregiver()
    var senior: ElderProfile = {
        var p = ElderProfile(); p.name = "Li Lan"; p.callName = "Li Lan"
        p.phone = "+12025550100"; p.bound = true; return p
    }()
    var members: [LocalFamilyMember] = []
    var primaryID = "self"
    var autoNavigation = true
    var lowRiskNotifications = true
    var recoveryNotifications = true
    var limitedMonitoringNotifications = true
}
@MainActor final class CaregiverSettingsStore: ObservableObject {
    @Published private(set) var data: CaregiverSettingsData
    private let defaults: UserDefaults
    private let key = "safeorbit.caregiver.settings.v1"
    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let raw = defaults.data(forKey: key), let value = try? JSONDecoder().decode(CaregiverSettingsData.self, from: raw),
           value.caregiver.isValid, value.senior.isValid, value.members.allSatisfy(\.isValid),
           Set(value.members.map(\.id)).count == value.members.count,
           !value.members.contains(where: { $0.id == "self" }),
           value.primaryID == "self" || value.members.contains(where: { $0.id == value.primaryID }) {
            data = value
        } else { data = .init() }
    }
    private func commit(_ value: CaregiverSettingsData) {
        guard let raw = try? JSONEncoder().encode(value) else { return }
        defaults.set(raw, forKey: key)
        data = value
    }
    @discardableResult func saveCaregiver(_ value: LocalCaregiver) -> Bool {
        guard value.isValid else { return false }
        var next = data; next.caregiver = value
        next.caregiver.name = value.name.trimmingCharacters(in: .whitespacesAndNewlines)
        next.caregiver.phone = PhoneNumber.normalized(value.phone)
        commit(next); return true
    }
    @discardableResult func saveSenior(_ value: ElderProfile) -> Bool {
        guard value.isValid, value.callName.count <= 60 else { return false }
        var next = data; next.senior = value
        next.senior.name = value.name.trimmingCharacters(in: .whitespacesAndNewlines)
        next.senior.callName = value.callName.trimmingCharacters(in: .whitespacesAndNewlines)
        if next.senior.callName.isEmpty { next.senior.callName = next.senior.name }
        next.senior.phone = PhoneNumber.normalized(value.phone)
        commit(next); return true
    }
    @discardableResult func saveMember(_ member: LocalFamilyMember) -> Bool {
        guard member.isValid, member.id != "self" else { return false }
        var value = member
        value.name = value.name.trimmingCharacters(in: .whitespacesAndNewlines)
        value.phone = PhoneNumber.normalized(value.phone)
        var next = data
        if let index = next.members.firstIndex(where: { $0.id == value.id }) { next.members[index] = value }
        else { next.members.append(value) }
        commit(next); return true
    }
    func removeMember(_ id: String) {
        guard data.members.contains(where: { $0.id == id }) else { return }
        var next = data; next.members.removeAll { $0.id == id }
        if next.primaryID == id { next.primaryID = "self" }
        commit(next)
    }
    func makePrimary(_ id: String) {
        guard id == "self" || data.members.contains(where: { $0.id == id }) else { return }
        var next = data; next.primaryID = id; commit(next)
    }
    func set(_ path: WritableKeyPath<CaregiverSettingsData, Bool>, _ value: Bool) {
        var next = data; next[keyPath: path] = value; commit(next)
    }
    func binding(_ path: WritableKeyPath<CaregiverSettingsData, Bool>) -> Binding<Bool> {
        Binding(get: { self.data[keyPath: path] }, set: { self.set(path, $0) })
    }
}

enum CaregiverSettingsItem: String, CaseIterable, Identifiable {
    case account = "Account Settings", senior = "Senior Profile", family = "Family Members"
    case agent = "AI Agent Settings", location = "Location Settings", notifications = "Notifications", help = "Help"
    var id: String { rawValue }
    var symbol: String {
        switch self {
        case .account: "gearshape"
        case .senior: "person.crop.circle"
        case .family: "person.3"
        case .agent: "sparkles"
        case .location: "mappin.and.ellipse"
        case .notifications: "bell"
        case .help: "questionmark.circle"
        }
    }
}

struct SettingsPage<Content: View>: View {
    let title: String
    let back: () -> Void
    @ViewBuilder let content: Content
    init(_ title: String, back: @escaping () -> Void, @ViewBuilder content: () -> Content) {
        self.title = title; self.back = back; self.content = content()
    }
    var body: some View {
        VStack(spacing: 0) {
            CaregiverTopBar {
                HStack {
                    Button(action: back) { Image(systemName: "chevron.left").font(.system(size: 20, weight: .semibold)).frame(width: 48, height: 44) }
                        .accessibilityLabel("Back to settings")
                    Spacer()
                    Image(systemName: "gearshape").font(.system(size: 22, weight: .medium)).accessibilityHidden(true)
                    Spacer()
                    Color.clear.frame(width: 48, height: 44)
                }.foregroundStyle(.white).padding(.horizontal, 12)
            }
            ScrollView {
                VStack(spacing: 22) {
                    Text(title).font(.system(size: 27, weight: .semibold)).foregroundStyle(OrbitStyle.teal)
                        .multilineTextAlignment(.center).padding(.top, 8).accessibilityAddTraits(.isHeader)
                    content
                }.padding(.horizontal, 24).padding(.top, 18).padding(.bottom, 32)
            }
            .background(.white, in: UnevenRoundedRectangle(topLeadingRadius: 29, topTrailingRadius: 29))
            .background(alignment: .top) { OrbitStyle.teal.frame(height: 40) }
        }
        .background(.white).tint(OrbitStyle.teal).preferredColorScheme(.light)
        .toolbar(.hidden, for: .navigationBar)
        .scrollDismissesKeyboard(.interactively)
    }
}
struct SettingsCard<Content: View>: View {
    @ViewBuilder let content: Content
    var body: some View {
        VStack(alignment: .leading, spacing: 18) { content }
            .padding(20).frame(maxWidth: .infinity, alignment: .leading).caregiverCard(radius: 25, opacity: 0.09)
    }
}
struct SettingsNote: View {
    let text: String
    var body: some View {
        Text(text).font(.system(size: 14)).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}
struct SettingsField: View {
    let label: String
    @Binding var value: String
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label).font(.system(size: 14, weight: .medium)).foregroundStyle(.secondary)
            TextField(label, text: $value).font(.system(size: 17)).padding(.horizontal, 16).padding(.vertical, 13)
                .background(RoundedRectangle(cornerRadius: 22).stroke(OrbitStyle.teal.opacity(0.35), lineWidth: 1))
                .accessibilityLabel(label)
        }
    }
}
struct SettingsPhotoPicker: View {
    @Binding var photo: String?
    @Binding var loading: Bool
    @State private var selection: PhotosPickerItem?
    @State private var error: String?
    var body: some View {
        VStack(spacing: 10) {
            PhotosPicker(selection: $selection, matching: .images) {
                VStack(spacing: 10) {
                    ProfileAvatar(photo: photo, size: 86)
                    Text("Change photo").font(.system(size: 14, weight: .medium))
                }
            }.disabled(loading)
            if loading { ProgressView() }
            if photo != nil { Button("Remove photo") { photo = nil; selection = nil }.font(.footnote) }
            if let error { Text(error).font(.footnote).foregroundStyle(.red) }
        }.frame(maxWidth: .infinity).onChange(of: selection) { _, item in
            Task { await load(item) }
        }
    }
    @MainActor private func load(_ item: PhotosPickerItem?) async {
        guard let item else { return }
        loading = true; error = nil
        defer { loading = false }
        do {
            guard let raw = try await item.loadTransferable(type: Data.self), let image = UIImage(data: raw) else { throw APIError(kind: .other) }
            guard selection == item else { return }
            let scale = min(1, 640 / max(image.size.width, image.size.height))
            let size = CGSize(width: image.size.width * scale, height: image.size.height * scale)
            let format = UIGraphicsImageRendererFormat(); format.scale = 1
            let resized = UIGraphicsImageRenderer(size: size, format: format).image { _ in image.draw(in: CGRect(origin: .zero, size: size)) }
            guard let jpeg = resized.jpegData(compressionQuality: 0.75), jpeg.count <= 512_000 else { throw APIError(kind: .other) }
            photo = "data:image/jpeg;base64," + jpeg.base64EncodedString()
        } catch { self.error = "Couldn't load that photo. Choose another." }
    }
}

struct CaregiverSettingsDetail: View {
    let item: CaregiverSettingsItem
    @ObservedObject var settings: CaregiverSettingsStore
    @ObservedObject var onboarding: OnboardingStore
    @ObservedObject var zones: SafeZoneSessionStore
    let back: () -> Void
    @State private var notice: String?
    @State private var editingMember: LocalFamilyMember?
    @State private var removingMember: LocalFamilyMember?
    @State private var editingZone: SafeZone?
    @State private var addingZone = false

    var body: some View {
        Group {
            if item == .account { SettingsProfileEditor(settings: settings, senior: false, back: back) }
            else if item == .senior { SettingsProfileEditor(settings: settings, senior: true, back: back) }
            else {
                SettingsPage(item.rawValue, back: back) {
                    switch item {
                    case .family: family
                    case .agent: agent
                    case .location: location
                    case .notifications: notifications
                    case .help: help
                    default: EmptyView()
                    }
                    if let notice { Text(notice).font(.footnote).foregroundStyle(OrbitStyle.teal).accessibilityLabel(notice) }
                }
            }
        }
        .fullScreenCover(item: $editingMember) { member in
            SettingsMemberEditor(member: member, settings: settings) { editingMember = nil }
        }
        .fullScreenCover(item: $editingZone) { zone in zoneEditor(zone) }
        .fullScreenCover(isPresented: $addingZone) { zoneEditor(nil) }
        .confirmationDialog("Remove this local family member?", isPresented: Binding(get: { removingMember != nil }, set: { if !$0 { removingMember = nil } }), titleVisibility: .visible) {
            Button("Remove member", role: .destructive) {
                if let member = removingMember { settings.removeMember(member.id) }
                removingMember = nil
            }
            Button("Cancel", role: .cancel) { removingMember = nil }
        }
    }
    private var family: some View {
        VStack(spacing: 22) {
            SettingsCard {
                memberRow(id: "self", name: settings.data.caregiver.name, phone: settings.data.caregiver.phone, isSelf: true)
                ForEach(settings.data.members) { member in
                    Divider()
                    memberRow(id: member.id, name: member.name, phone: member.phone, isSelf: false)
                }
            }
            PrimaryButton(title: "Add family member", busy: false, enabled: true, capsule: true) {
                editingMember = LocalFamilyMember(name: "", phone: "")
            }
            SettingsNote(text: "Members are saved on this phone only. Invitations and shared care will be available when family accounts are connected.")
        }
    }
    private func memberRow(id: String, name: String, phone: String, isSelf: Bool) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                Image(systemName: "person.crop.circle.fill").font(.system(size: 38)).foregroundStyle(OrbitStyle.teal)
                VStack(alignment: .leading, spacing: 4) {
                    Text(name + (isSelf ? " (You)" : "")).font(.system(size: 17, weight: .semibold))
                    Text(phone).font(.system(size: 13)).foregroundStyle(.secondary)
                    Text(settings.data.primaryID == id ? "Primary caregiver" : "Caregiver")
                        .font(.system(size: 12, weight: .medium)).foregroundStyle(OrbitStyle.teal)
                }
                Spacer(minLength: 0)
                if !isSelf {
                    Menu {
                        Button("Edit member") { editingMember = settings.data.members.first { $0.id == id } }
                        Button("Remove member", role: .destructive) { removingMember = settings.data.members.first { $0.id == id } }
                    } label: { Image(systemName: "ellipsis").frame(width: 44, height: 44) }.accessibilityLabel("Manage " + name)
                }
            }
            if settings.data.primaryID != id {
                Button("Make primary caregiver") { settings.makePrimary(id); notice = "Primary caregiver saved on this phone." }
                    .font(.system(size: 14, weight: .medium)).frame(minHeight: 44)
            }
        }
    }
    private var agent: some View {
        VStack(spacing: 22) {
            SettingsCard {
                Label("Support on the way home", systemImage: "sparkles").font(.system(size: 18, weight: .semibold)).foregroundStyle(OrbitStyle.teal)
                Toggle("Automatic voice navigation", isOn: settings.binding(\.autoNavigation))
                SettingsNote(text: "Start guidance home when a low-risk situation is detected.")
            }
            SettingsNote(text: "Saved automatically on this phone. Automatic monitoring and navigation are not connected in this version.")
        }
    }
    private var notifications: some View {
        VStack(spacing: 22) {
            SettingsCard {
                Toggle("Low-risk alerts", isOn: settings.binding(\.lowRiskNotifications))
                SettingsNote(text: "Know when guidance home is needed.")
                Divider()
                Toggle("Safe return & recovery", isOn: settings.binding(\.recoveryNotifications))
                SettingsNote(text: "Know when a risk has ended.")
                Divider()
                Toggle("Monitoring limited", isOn: settings.binding(\.limitedMonitoringNotifications))
                SettingsNote(text: "Know when location updates are unavailable.")
            }
            SettingsCard {
                HStack {
                    Label("High-risk alerts", systemImage: "exclamationmark.shield").font(.system(size: 17, weight: .semibold))
                    Spacer()
                    Text("Always on").font(.system(size: 13, weight: .medium)).foregroundStyle(OrbitStyle.teal)
                }
                SettingsNote(text: "High-risk alerts cannot be turned off here.")
            }
            SettingsNote(text: "Preferences are saved on this phone. Push notifications are not connected yet; these switches do not change iPhone permissions.")
        }
    }
    private var location: some View {
        VStack(spacing: 22) {
            SettingsCard {
                Label("Monitoring status", systemImage: "location.circle").font(.system(size: 18, weight: .semibold)).foregroundStyle(OrbitStyle.teal)
                Text(onboarding.previewSession ? "Sample location" : (onboarding.location == nil ? "Location unavailable" : "Location available"))
                SettingsNote(text: onboarding.previewSession ? "The home map shows a local sample near Nanjing University. No senior device is connected." : (onboarding.locationError ?? "Location updates come from the connected service."))
            }
            SettingsCard {
                Text("Safe zones").font(.system(size: 18, weight: .semibold)).foregroundStyle(OrbitStyle.teal)
                let visible = zones.visibleZones(in: onboarding.location)
                if visible.isEmpty { SettingsNote(text: "Add a familiar place such as home or the market.") }
                ForEach(visible) { zone in
                    Button { editingZone = zone } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "mappin.circle.fill").font(.system(size: 28)).foregroundStyle(OrbitStyle.teal)
                            VStack(alignment: .leading, spacing: 5) {
                                Text(zone.name).font(.system(size: 17, weight: .medium)).foregroundStyle(.primary)
                                Text("\(Int(zone.radiusMeters)) m radius").font(.system(size: 13)).foregroundStyle(.secondary)
                            }
                            Spacer()
                            Image(systemName: "chevron.right").foregroundStyle(OrbitStyle.teal)
                        }.frame(minHeight: 50)
                    }.accessibilityLabel("Edit " + zone.name + " safe zone")
                    if zone.id != visible.last?.id { Divider() }
                }
                Button { addingZone = true } label: { Label("Add safe zone", systemImage: "plus.circle").frame(minHeight: 44) }
                SettingsNote(text: "Safe-zone changes last for this app session.")
            }
            SettingsCard {
                Label("Senior phone", systemImage: "iphone").font(.system(size: 18, weight: .semibold)).foregroundStyle(OrbitStyle.teal)
                Text("Not connected")
                SettingsNote(text: "Phone binding and replacement are paused while account access is frozen.")
            }
        }
    }
    @ViewBuilder private func zoneEditor(_ zone: SafeZone?) -> some View {
        SafeZoneEditorPage(zone: zone, initialCenter: onboarding.location?.coordinate ?? LocationPreviewData.campus,
                           nearbyZones: zones.visibleZones(in: onboarding.location), save: { zones.save($0) }, delete: { zones.delete($0) })
    }
    private var help: some View {
        VStack(spacing: 22) {
            SettingsCard {
                Label("Getting started", systemImage: "hand.wave").font(.system(size: 18, weight: .semibold)).foregroundStyle(OrbitStyle.teal)
                SettingsNote(text: "Location shows the senior's position and familiar places. Agent answers questions about sample trips. Records contains the calendar, trip details and trends.")
            }
            SettingsCard {
                Text("Frequently asked questions").font(.system(size: 18, weight: .semibold)).foregroundStyle(OrbitStyle.teal)
                DisclosureGroup("What is a safe zone?") { SettingsNote(text: "A familiar place, such as home or the market. Leaving a safe zone alone does not mean something is wrong.").padding(.top, 8) }
                Divider()
                DisclosureGroup("What do the risk colors mean?") { SettingsNote(text: "Green means normal. Yellow indicates a low-risk situation. Red indicates a high-risk situation that needs family attention.").padding(.top, 8) }
                Divider()
                DisclosureGroup("Are these live records?") { SettingsNote(text: "This version uses local sample locations and August 2026 trip records. Account access, live monitoring and push notifications are paused.").padding(.top, 8) }
                Divider()
                DisclosureGroup("How do I change a safe zone?") { SettingsNote(text: "Open Location Settings or tap a safe-zone marker on the home map. Move the pin, choose a radius and save. Changes remain for the current app session.").padding(.top, 8) }
            }
            SettingsNote(text: "SafeOrbit · Classroom demo\nThis version has no emergency dispatch service.")
        }
    }
}

struct SettingsProfileEditor: View {
    @ObservedObject var settings: CaregiverSettingsStore
    let senior: Bool
    let back: () -> Void
    @State private var caregiver: LocalCaregiver
    @State private var profile: ElderProfile
    @State private var saved = false
    @State private var photoLoading = false
    init(settings: CaregiverSettingsStore, senior: Bool, back: @escaping () -> Void) {
        self.settings = settings; self.senior = senior; self.back = back
        _caregiver = State(initialValue: settings.data.caregiver)
        _profile = State(initialValue: settings.data.senior)
    }
    private var valid: Bool { senior ? profile.isValid && profile.callName.count <= 60 : caregiver.isValid }
    var body: some View {
        SettingsPage(senior ? "Senior Profile" : "Account Settings", back: back) {
            SettingsCard {
                SettingsPhotoPicker(photo: senior ? $profile.photo : $caregiver.photo, loading: $photoLoading)
                SettingsField(label: "Full name", value: senior ? $profile.name : $caregiver.name)
                if senior { SettingsField(label: "Preferred name", value: $profile.callName) }
                CountryPhoneInput(phone: senior ? $profile.phone : $caregiver.phone, label: "Phone number")
                if senior {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Time zone").font(.system(size: 14, weight: .medium)).foregroundStyle(.secondary)
                        Picker("Time zone", selection: $profile.timezone) {
                            ForEach(TimeZone.knownTimeZoneIdentifiers, id: \.self) { Text($0.replacingOccurrences(of: "_", with: " ")).tag($0) }
                        }.pickerStyle(.menu).labelsHidden().frame(maxWidth: .infinity, alignment: .leading)
                    }
                } else {
                    HStack { Text("App language"); Spacer(); Text("English").foregroundStyle(.secondary) }
                    SettingsNote(text: "Account sign-in and registration are paused.")
                }
            }
            PrimaryButton(title: "Save changes", busy: false, enabled: valid && !photoLoading, capsule: true) {
                saved = senior ? settings.saveSenior(profile) : settings.saveCaregiver(caregiver)
            }
            if !valid { Text("Enter a name and a valid phone number.").font(.footnote).foregroundStyle(.red) }
            if saved { Label("Saved on this phone", systemImage: "checkmark.circle.fill").font(.subheadline).foregroundStyle(OrbitStyle.teal) }
            SettingsNote(text: "Changes are saved on this phone only. Return without saving to discard your edits.")
        }.onChange(of: caregiver) { _, _ in saved = false }.onChange(of: profile) { _, _ in saved = false }
    }
}
struct SettingsMemberEditor: View {
    @State var member: LocalFamilyMember
    @ObservedObject var settings: CaregiverSettingsStore
    let back: () -> Void
    var body: some View {
        SettingsPage("Family Member", back: back) {
            SettingsCard {
                SettingsField(label: "Full name", value: $member.name)
                CountryPhoneInput(phone: $member.phone, label: "Phone number")
            }
            PrimaryButton(title: "Save member", busy: false, enabled: member.isValid, capsule: true) {
                if settings.saveMember(member) { back() }
            }
            SettingsNote(text: "This adds a local family entry. No invitation is sent.")
        }
    }
}
