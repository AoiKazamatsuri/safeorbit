import SwiftUI
import PhotosUI
import AVFoundation
import Speech

// Settings belong to this device until account and family services are connected.
struct LocalCaregiver: Codable, Equatable {
    var name = "Emma Liu"
    var phone = "+12025550101"
    var photo: String?
    var email = ""
    enum CodingKeys: String, CodingKey { case name, phone, photo, email }
    init() {}
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        name = try c.decode(String.self, forKey: .name)
        phone = try c.decode(String.self, forKey: .phone)
        photo = try c.decodeIfPresent(String.self, forKey: .photo)
        email = try c.decodeIfPresent(String.self, forKey: .email) ?? ""
    }
    var isValid: Bool { !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && name.count <= 60 && PhoneNumber.isValid(phone) && (email.isEmpty || EmailAddress.isValid(email)) }
}
struct LocalFamilyMember: Codable, Equatable, Identifiable {
    var id = UUID().uuidString
    var name: String
    var phone: String
    var relationship = ""
    enum CodingKeys: String, CodingKey { case id, name, phone, relationship }
    init(id: String = UUID().uuidString, name: String, phone: String, relationship: String = "") {
        self.id = id; self.name = name; self.phone = phone; self.relationship = relationship
    }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        name = try c.decode(String.self, forKey: .name)
        phone = try c.decode(String.self, forKey: .phone)
        relationship = try c.decodeIfPresent(String.self, forKey: .relationship) ?? ""
    }
    var isValid: Bool { !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && name.count <= 60 && (PhoneNumber.isValid(phone) || EmailAddress.isValid(phone)) }
}
struct EmergencyContact: Codable, Equatable, Identifiable {
    var id = UUID().uuidString
    var name = ""
    var relationship = ""
    var phone = ""
    var isValid: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && name.count <= 60 &&
        !relationship.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && relationship.count <= 60 && PhoneNumber.isValid(phone)
    }
}
struct CaregiverSettingsData: Codable, Equatable {
    var caregiver = LocalCaregiver()
    var senior: ElderProfile = {
        var p = ElderProfile(); p.name = "Li Lan"; p.callName = "Li Lan"
        p.phone = "+12025550100"; p.bound = true; return p
    }()
    var members: [LocalFamilyMember] = []
    var seniorRelationship = ""
    var emergencyContacts: [EmergencyContact] = []
    var primaryID = "self"
    var allowAITripHistory = true
    var autoNavigation = true
    var lowRiskNotifications = true
    var recoveryNotifications = true
    var limitedMonitoringNotifications = true
    enum CodingKeys: String, CodingKey {
        case caregiver, senior, members, primaryID, allowAITripHistory, autoNavigation, lowRiskNotifications,
             recoveryNotifications, limitedMonitoringNotifications, seniorRelationship, emergencyContacts
    }
    init() {}
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        caregiver = try c.decode(LocalCaregiver.self, forKey: .caregiver)
        senior = try c.decode(ElderProfile.self, forKey: .senior)
        members = try c.decode([LocalFamilyMember].self, forKey: .members)
        primaryID = try c.decode(String.self, forKey: .primaryID)
        allowAITripHistory = try c.decodeIfPresent(Bool.self, forKey: .allowAITripHistory) ?? true
        autoNavigation = try c.decode(Bool.self, forKey: .autoNavigation)
        lowRiskNotifications = try c.decode(Bool.self, forKey: .lowRiskNotifications)
        recoveryNotifications = try c.decode(Bool.self, forKey: .recoveryNotifications)
        limitedMonitoringNotifications = try c.decode(Bool.self, forKey: .limitedMonitoringNotifications)
        seniorRelationship = try c.decodeIfPresent(String.self, forKey: .seniorRelationship) ?? ""
        emergencyContacts = try c.decodeIfPresent([EmergencyContact].self, forKey: .emergencyContacts) ?? []
    }
}
@MainActor final class CaregiverSettingsStore: ObservableObject {
    @Published private(set) var data: CaregiverSettingsData
    private let defaults: UserDefaults
    private let key = "safeorbit.caregiver.settings.v1"
    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let raw = defaults.data(forKey: key), let value = try? JSONDecoder().decode(CaregiverSettingsData.self, from: raw),
           value.caregiver.isValid, value.senior.isValid, value.members.allSatisfy(\.isValid),
           value.emergencyContacts.allSatisfy(\.isValid), Set(value.emergencyContacts.map(\.id)).count == value.emergencyContacts.count,
           Set(value.members.map(\.id)).count == value.members.count,
           !value.members.contains(where: { $0.id == "self" }),
           value.primaryID == "self" || value.members.contains(where: { $0.id == value.primaryID }) {
            data = value
        } else { data = .init() }
        data.senior.timezone = TimeZone.current.identifier
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
        next.caregiver.email = EmailAddress.normalized(value.email)
        commit(next); return true
    }
    @discardableResult func saveSenior(_ value: ElderProfile, relationship: String, contacts: [EmergencyContact]) -> Bool {
        guard value.isValid, !relationship.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              relationship.count <= 60, contacts.allSatisfy(\.isValid), Set(contacts.map(\.id)).count == contacts.count else { return false }
        var next = data; next.senior = value
        next.senior.name = value.name.trimmingCharacters(in: .whitespacesAndNewlines)
        next.senior.callName = next.senior.name
        next.senior.timezone = TimeZone.current.identifier
        next.senior.phone = PhoneNumber.normalized(value.phone)
        next.seniorRelationship = relationship.trimmingCharacters(in: .whitespacesAndNewlines)
        next.emergencyContacts = contacts.map {
            var contact = $0
            contact.name = contact.name.trimmingCharacters(in: .whitespacesAndNewlines)
            contact.relationship = contact.relationship.trimmingCharacters(in: .whitespacesAndNewlines)
            contact.phone = PhoneNumber.normalized(contact.phone)
            return contact
        }
        commit(next); return true
    }
    @discardableResult func saveMember(_ member: LocalFamilyMember) -> Bool {
        guard member.isValid, member.id != "self" else { return false }
        var value = member
        value.name = value.name.trimmingCharacters(in: .whitespacesAndNewlines)
        value.phone = EmailAddress.isValid(value.phone) ? EmailAddress.normalized(value.phone) : PhoneNumber.normalized(value.phone)
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
    case ai = "AI Settings", navigation = "Navigation Settings", location = "Safe Zones", notifications = "Notifications", help = "Help & Privacy"
    var id: String { rawValue }
    var symbol: String {
        switch self {
        case .account: "gearshape"
        case .senior: "person.crop.circle"
        case .family: "person.3"
        case .location: "mappin.and.ellipse"
        case .ai: "sparkles"
        case .navigation: "arrow.triangle.turn.up.right.diamond"
        case .notifications: "bell"
        case .help: "questionmark.circle"
        }
    }
}

enum CaregiverSettingsGroup: String, CaseIterable, Identifiable {
    case people = "Profiles & Family"
    case ai = "AI Settings"
    case navigation = "Navigation Settings"
    case notifications = "Notifications"
    case zones = "Safe Zones"
    case help = "Help & Privacy"
    var id: String { rawValue }
    var symbol: String {
        switch self {
        case .people: "person.3"
        case .ai: "sparkles"
        case .navigation: "arrow.triangle.turn.up.right.diamond"
        case .notifications: "bell"
        case .zones: "mappin.and.ellipse"
        case .help: "questionmark.circle"
        }
    }
}
struct CaregiverSettingsGroupPage: View {
    let group: CaregiverSettingsGroup
    @ObservedObject var settings: CaregiverSettingsStore
    @ObservedObject var onboarding: OnboardingStore
    @ObservedObject var zones: SafeZoneSessionStore
    let back: () -> Void
    var body: some View {
        switch group {
        case .people: SettingsProfilesFamilyPage(settings: settings, back: back)
        case .ai: SettingsAIPage(settings: settings, back: back)
        case .navigation: detail(.navigation)
        case .notifications: detail(.notifications)
        case .zones: detail(.location)
        case .help: detail(.help)
        }
    }
    private func detail(_ item: CaregiverSettingsItem) -> some View {
        CaregiverSettingsDetail(item: item, settings: settings, onboarding: onboarding, zones: zones, back: back)
    }
}

struct SettingsAIPage: View {
    @ObservedObject var settings: CaregiverSettingsStore
    let back: () -> Void
    @Environment(\.scenePhase) private var scenePhase
    @State private var microphonePermission = AVAudioApplication.shared.recordPermission
    @State private var speechPermission = SFSpeechRecognizer.authorizationStatus()
    var body: some View {
        SettingsPage("AI Settings", back: back) {
            SettingsSection("Data use") {
                SettingsCard {
                    Toggle(isOn: settings.binding(\.allowAITripHistory)) {
                        Label("Use trip history", systemImage: "clock.arrow.circlepath")
                    }.frame(minHeight: 44)
                    SettingsNote(text: "Allow Agent to use sample trip records in answers. Turning this off clears the current chat.")
                }
            }
            SettingsSection("Voice input permissions") {
                SettingsCard {
                    permissionRow("Microphone", symbol: "mic", status: microphoneStatus)
                    Divider()
                    permissionRow("Speech recognition", symbol: "waveform", status: speechStatus)
                    Divider()
                    Button {
                        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
                        UIApplication.shared.open(url)
                    } label: {
                        HStack {
                            Text("Open iPhone Settings")
                            Spacer()
                            Image(systemName: "arrow.up.right").font(.footnote)
                        }.frame(minHeight: 44)
                    }
                }
            }
        }
        .onAppear(perform: refreshPermissions)
        .onChange(of: scenePhase) { _, phase in if phase == .active { refreshPermissions() } }
    }
    private func permissionRow(_ title: String, symbol: String, status: String) -> some View {
        HStack(spacing: 12) {
            Label(title, systemImage: symbol)
            Spacer(minLength: 8)
            Text(status).font(.subheadline).foregroundStyle(.secondary)
        }.frame(minHeight: 44).accessibilityElement(children: .combine)
    }
    private var microphoneStatus: String {
        switch microphonePermission {
        case .granted: "Allowed"
        case .denied: "Denied"
        case .undetermined: "Not requested"
        @unknown default: "Unavailable"
        }
    }
    private var speechStatus: String {
        switch speechPermission {
        case .authorized: "Allowed"
        case .denied: "Denied"
        case .restricted: "Restricted"
        case .notDetermined: "Not requested"
        @unknown default: "Unavailable"
        }
    }
    private func refreshPermissions() {
        microphonePermission = AVAudioApplication.shared.recordPermission
        speechPermission = SFSpeechRecognizer.authorizationStatus()
    }
}

// Keep the underlying page mounted so nested editors preserve its draft and scroll position.
struct SettingsSlideModifier<Destination: View>: ViewModifier {
    let isPresented: Bool
    var reduceMotionOverride: Bool? = nil
    @ViewBuilder let destination: () -> Destination
    @Environment(\.accessibilityReduceMotion) private var systemReduceMotion
    private var reduceMotion: Bool { reduceMotionOverride ?? systemReduceMotion }

    func body(content: Content) -> some View {
        ZStack {
            content
                .allowsHitTesting(!isPresented)
                .accessibilityElement(children: .contain)
                .accessibilityHidden(isPresented)
            GeometryReader { geometry in
                ZStack {
                    if isPresented {
                        destination()
                            .frame(width: geometry.size.width, height: geometry.size.height)
                            .background(Color.white.ignoresSafeArea())
                            .accessibilityAddTraits(.isModal)
                            .transition(reduceMotion ? .opacity : .asymmetric(
                                insertion: .offset(x: -geometry.size.width),
                                removal: .offset(x: -geometry.size.width)))
                    }
                }
            }
            .allowsHitTesting(isPresented)
            .accessibilityElement(children: .contain)
            .accessibilityHidden(!isPresented)
            .zIndex(1)
        }
        .animation(.easeInOut(duration: 0.28), value: isPresented)
        .onChange(of: isPresented) { _, _ in
            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        }
    }
}

private struct SettingsItemSlideModifier<Item: Identifiable, Destination: View>: ViewModifier {
    @Binding var item: Item?
    @State private var lastItem: Item?
    @ViewBuilder let destination: (Item) -> Destination

    func body(content: Content) -> some View {
        content.settingsSlide(isPresented: Binding(get: { item != nil }, set: { if !$0 { item = nil } })) {
            // Retain the outgoing item's content until its removal animation finishes.
            if let value = item ?? lastItem { destination(value) }
        }
        .onChange(of: item?.id, initial: true) { _, _ in
            if let item { lastItem = item }
        }
    }
}

extension View {
    func settingsSlide<Destination: View>(isPresented: Binding<Bool>,
                                         @ViewBuilder destination: @escaping () -> Destination) -> some View {
        modifier(SettingsSlideModifier(isPresented: isPresented.wrappedValue, destination: destination))
    }
    func settingsSlide<Item: Identifiable, Destination: View>(item: Binding<Item?>,
                                                            @ViewBuilder destination: @escaping (Item) -> Destination) -> some View {
        modifier(SettingsItemSlideModifier(item: item, destination: destination))
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
                ZStack {
                    Text(title).font(.system(size: 27, weight: .semibold))
                        .lineLimit(1).minimumScaleFactor(0.7).padding(.horizontal, 58).accessibilityAddTraits(.isHeader)
                    HStack {
                        Button(action: back) { Image(systemName: "chevron.left").font(.system(size: 20, weight: .semibold)).frame(width: 48, height: 44) }
                            .accessibilityLabel("Back")
                        Spacer()
                    }.padding(.horizontal, 12)
                }.foregroundStyle(.white)
            }
            ScrollView {
                VStack(spacing: 20) {
                    content
                }.padding(.horizontal, 20).padding(.top, 22).padding(.bottom, 32)
            }
            .background(Color(uiColor: .systemGroupedBackground), in: UnevenRoundedRectangle(topLeadingRadius: 29, topTrailingRadius: 29))
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
        VStack(alignment: .leading, spacing: 14) { content }
            .padding(18).frame(maxWidth: .infinity, alignment: .leading)
            .background(.white, in: RoundedRectangle(cornerRadius: 22))
    }
}
struct SettingsSection<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content
    init(_ title: String, @ViewBuilder content: () -> Content) { self.title = title; self.content = content() }
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title).font(.headline).padding(.horizontal, 6).accessibilityAddTraits(.isHeader)
            content
        }.frame(maxWidth: .infinity, alignment: .leading)
    }
}
struct SettingsPrivacyPage: View {
    let back: () -> Void
    var body: some View {
        SettingsPage("Privacy Policy", back: back) {
            SettingsCard { SettingsNote(text: "A privacy policy is not yet available for this demo.") }
        }
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
    var compact = false
    @State private var selection: PhotosPickerItem?
    @State private var error: String?
    var body: some View {
        VStack(spacing: 10) {
            PhotosPicker(selection: $selection, matching: .images) {
                if compact {
                    HStack(spacing: 14) {
                        ProfileAvatar(photo: photo, size: 48)
                        Text("Change photo").font(.system(size: 16, weight: .medium))
                        Spacer()
                    }.frame(minHeight: 48)
                } else {
                    VStack(spacing: 10) {
                        ProfileAvatar(photo: photo, size: 86)
                        Text("Change photo").font(.system(size: 14, weight: .medium))
                    }
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
    @State private var editingMember: LocalFamilyMember?
    @State private var editingZone: SafeZone?
    @State private var addingZone = false
    @State private var showingPrivacy = false

    var body: some View {
        Group {
            if item == .account { SettingsProfilesFamilyPage(settings: settings, back: back) }
            else if item == .senior { SettingsProfilesFamilyPage(settings: settings, back: back) }
            else {
                SettingsPage(item.rawValue, back: back) {
                    switch item {
                    case .family: family
                    case .ai: EmptyView()
                    case .navigation: navigation
                    case .location: location
                    case .notifications: notifications
                    case .help: help
                    default: EmptyView()
                    }
                }
            }
        }
        .settingsSlide(item: $editingMember) { member in
            SettingsMemberDetail(member: member, isSelf: member.id == "self", settings: settings) { editingMember = nil }
        }
        .settingsSlide(item: $editingZone) { zone in zoneEditor(zone) }
        .settingsSlide(isPresented: $addingZone) { zoneEditor(nil) }
        .settingsSlide(isPresented: $showingPrivacy) { SettingsPrivacyPage(back: { showingPrivacy = false }) }
    }

    private var family: some View {
        SettingsCard {
            familyRow(LocalFamilyMember(id: "self", name: settings.data.caregiver.name,
                phone: settings.data.caregiver.phone, relationship: ""))
            ForEach(settings.data.members) { member in
                Divider()
                familyRow(member)
            }
        }
    }
    private func familyRow(_ member: LocalFamilyMember) -> some View {
        Button { editingMember = member } label: {
            HStack(spacing: 12) {
                Image(systemName: "person.crop.circle").font(.title2).foregroundStyle(OrbitStyle.teal)
                Text(member.name).foregroundStyle(.primary)
                Spacer()
                Image(systemName: "chevron.right").font(.footnote).foregroundStyle(.tertiary)
            }.frame(minHeight: 44).contentShape(Rectangle())
        }
    }
    private var navigation: some View {
        SettingsCard {
            Toggle(isOn: settings.binding(\.autoNavigation)) {
                Label("Automatic voice navigation", systemImage: "arrow.triangle.turn.up.right.diamond")
            }.frame(minHeight: 44)
            SettingsNote(text: "Start guidance home when a low-risk situation is detected.")
        }
    }
    private var notifications: some View {
        SettingsCard {
            Toggle(isOn: settings.binding(\.lowRiskNotifications)) { Label("Low-risk alerts", systemImage: "bell") }.frame(minHeight: 44)
            Divider()
            Toggle(isOn: settings.binding(\.recoveryNotifications)) { Label("Safe return & recovery", systemImage: "checkmark.shield") }.frame(minHeight: 44)
            Divider()
            Toggle(isOn: settings.binding(\.limitedMonitoringNotifications)) { Label("Monitoring limited", systemImage: "location.slash") }.frame(minHeight: 44)
            Divider()
            HStack(spacing: 12) {
                Label("High-risk alerts", systemImage: "exclamationmark.shield")
                Spacer(minLength: 8)
                Text("Always on").font(.subheadline).foregroundStyle(.secondary)
            }.frame(minHeight: 44)
        }
    }
    private var location: some View {
        SettingsCard {
            let visible = zones.visibleZones(in: onboarding.location)
            if visible.isEmpty { SettingsNote(text: "Add a familiar place such as home or the market.") }
            ForEach(visible) { zone in
                Button { editingZone = zone } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "mappin.circle").font(.title2).foregroundStyle(OrbitStyle.teal)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(zone.name).foregroundStyle(.primary)
                            Text("\(Int(zone.radiusMeters)) m radius").font(.subheadline).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Image(systemName: "chevron.right").font(.footnote).foregroundStyle(.tertiary)
                    }.frame(minHeight: 44)
                }.accessibilityLabel("Edit " + zone.name + " safe zone")
                Divider()
            }
            Button { addingZone = true } label: { Label("Add safe zone", systemImage: "plus.circle").frame(minHeight: 44) }
        }
    }
    @ViewBuilder private func zoneEditor(_ zone: SafeZone?) -> some View {
        SafeZoneEditorPage(zone: zone, initialCenter: onboarding.location?.coordinate ?? LocationPreviewData.campus,
                           nearbyZones: zones.visibleZones(in: onboarding.location), save: { zones.save($0) }, delete: { zones.delete($0) },
                           close: { editingZone = nil; addingZone = false })
    }
    private var help: some View {
        VStack(spacing: 20) {
            SettingsSection("Getting started") {
                SettingsCard {
                    DisclosureGroup("Where do I find trips and guidance?") {
                        SettingsNote(text: "Location shows familiar places. Agent answers questions about trips. Records shows the calendar, trip details and trends.").padding(.top, 8)
                    }.frame(minHeight: 44)
                }
            }
            SettingsSection("Frequently asked questions") {
                SettingsCard {
                    DisclosureGroup("What is a safe zone?") { SettingsNote(text: "A familiar place, such as home or the market. Leaving a safe zone alone does not mean something is wrong.").padding(.top, 8) }.frame(minHeight: 44)
                    Divider()
                    DisclosureGroup("What do the risk colors mean?") { SettingsNote(text: "Green means normal. Yellow indicates low risk. Red indicates high risk and needs family attention.").padding(.top, 8) }.frame(minHeight: 44)
                    Divider()
                    DisclosureGroup("How do I change a safe zone?") { SettingsNote(text: "Open Safe Zones, choose a place or add one, then move the pin, choose a radius and save. Changes last for this app session.").padding(.top, 8) }.frame(minHeight: 44)
                }
            }
            SettingsCard {
                Button { showingPrivacy = true } label: {
                    HStack {
                        Label("Privacy Policy", systemImage: "hand.raised")
                        Spacer()
                        Image(systemName: "chevron.right").font(.footnote).foregroundStyle(.tertiary)
                    }.frame(minHeight: 44)
                }.foregroundStyle(.primary)
                Divider()
                DisclosureGroup("About this demo") {
                    SettingsNote(text: "Trips and locations use sample data. Preferences and profiles are saved on this phone. Live monitoring, voice navigation and push notifications are not connected. Emergency dispatch is unavailable.").padding(.top, 8)
                }.frame(minHeight: 44)
            }
        }
    }

}

@MainActor final class SettingsProfileDraft: ObservableObject {
    @Published var caregiver: LocalCaregiver { didSet { saved = false } }
    @Published var profile: ElderProfile { didSet { saved = false } }
    @Published var relationship: String { didSet { saved = false } }
    @Published var contacts: [EmergencyContact] { didSet { saved = false } }
    @Published var editingContact: EmergencyContact?
    @Published var removingContact: EmergencyContact?
    @Published var saved = false
    @Published var photoLoading = false
    let senior: Bool
    init(data: CaregiverSettingsData, senior: Bool) {
        caregiver = data.caregiver; profile = data.senior
        relationship = data.seniorRelationship; contacts = data.emergencyContacts
        self.senior = senior
    }
    var valid: Bool {
        senior ? profile.isValid && !relationship.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && relationship.count <= 60 && contacts.allSatisfy(\.isValid) : caregiver.isValid
    }
    var canSave: Bool { valid && !photoLoading }
    func save(to settings: CaregiverSettingsStore) {
        guard canSave else { return }
        saved = senior ? settings.saveSenior(profile, relationship: relationship, contacts: contacts) : settings.saveCaregiver(caregiver)
    }
    func updateContact(_ contact: EmergencyContact) {
        if let index = contacts.firstIndex(where: { $0.id == contact.id }) { contacts[index] = contact }
        else { contacts.append(contact) }
        editingContact = nil
    }
}

struct SettingsProfilesFamilyPage: View {
    @ObservedObject var settings: CaregiverSettingsStore
    let back: () -> Void
    @StateObject private var account: SettingsProfileDraft
    @StateObject private var senior: SettingsProfileDraft
    @State private var editingMember: LocalFamilyMember?
    init(settings: CaregiverSettingsStore, back: @escaping () -> Void) {
        self.settings = settings; self.back = back
        _account = StateObject(wrappedValue: SettingsProfileDraft(data: settings.data, senior: false))
        _senior = StateObject(wrappedValue: SettingsProfileDraft(data: settings.data, senior: true))
    }
    var body: some View {
        SettingsPage("Profiles & Family", back: back) {
            SettingsSection("Account Settings") {
                SettingsProfileSection(settings: settings, draft: account)
            }
            SettingsSection("Senior Profile") {
                SettingsProfileSection(settings: settings, draft: senior)
            }
            SettingsSection("Family Members") {
                SettingsCard {
                    memberRow(LocalFamilyMember(id: "self", name: settings.data.caregiver.name,
                        phone: settings.data.caregiver.phone, relationship: ""))
                    ForEach(settings.data.members) { member in
                        Divider()
                        memberRow(member)
                    }
                }
            }
        }
        .settingsSlide(item: $senior.editingContact) { contact in
            EmergencyContactEditor(contact: contact, save: { senior.updateContact($0) }, back: { senior.editingContact = nil })
        }
        .settingsSlide(item: $editingMember) { member in
            SettingsMemberDetail(member: member, isSelf: member.id == "self", settings: settings, back: { editingMember = nil })
        }
    }
    private func memberRow(_ member: LocalFamilyMember) -> some View {
        Button { editingMember = member } label: {
            HStack(spacing: 12) {
                Image(systemName: "person.crop.circle").font(.title2).foregroundStyle(OrbitStyle.teal)
                Text(member.name).foregroundStyle(.primary)
                Spacer()
                Image(systemName: "chevron.right").font(.footnote).foregroundStyle(.tertiary)
            }.frame(minHeight: 44).contentShape(Rectangle())
        }
    }
}

struct SettingsProfileSection: View {
    @ObservedObject var settings: CaregiverSettingsStore
    @ObservedObject var draft: SettingsProfileDraft
    var body: some View {
        SettingsCard {
            SettingsPhotoPicker(photo: draft.senior ? $draft.profile.photo : $draft.caregiver.photo, loading: $draft.photoLoading, compact: true)
            Divider()
            SettingsField(label: "Full name", value: draft.senior ? $draft.profile.name : $draft.caregiver.name)
            Divider()
            CountryPhoneInput(phone: draft.senior ? $draft.profile.phone : $draft.caregiver.phone, label: "Phone number")
            Divider()
            if draft.senior {
                SettingsField(label: "Relationship to you", value: $draft.relationship)
                Divider()
                Text("Emergency contacts").font(.subheadline.weight(.medium)).accessibilityAddTraits(.isHeader)
                if draft.contacts.isEmpty { Text("No emergency contacts added.").font(.footnote).foregroundStyle(.secondary) }
                ForEach(draft.contacts) { contact in
                    HStack {
                        Button { draft.editingContact = contact } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(contact.name).font(.system(size: 17, weight: .medium))
                                Text(contact.relationship).font(.subheadline).foregroundStyle(.secondary)
                                Text(contact.phone).font(.subheadline).foregroundStyle(.secondary)
                            }.frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                        }.accessibilityLabel("Edit " + contact.name)
                        Button { draft.removingContact = contact } label: { Image(systemName: "minus.circle").frame(width: 44, height: 44) }
                            .foregroundStyle(.red).accessibilityLabel("Remove " + contact.name)
                    }
                    Divider()
                }
                Button { draft.editingContact = EmergencyContact() } label: { Label("Add emergency contact", systemImage: "plus.circle").frame(minHeight: 44) }
            } else {
                SettingsField(label: "Email (optional)", value: $draft.caregiver.email)
                    .keyboardType(.emailAddress).textInputAutocapitalization(.never).autocorrectionDisabled()
            }
            Divider()
            PrimaryButton(title: "Save", busy: false, enabled: draft.canSave, capsule: true) { draft.save(to: settings) }
                .accessibilityLabel(draft.senior ? "Save senior profile" : "Save account settings")
            if !draft.valid {
                Text(draft.senior ? "Enter a name, valid phone number and relationship." : "Enter a name, valid phone number and valid email if provided.")
                    .font(.footnote).foregroundStyle(.red)
            }
            if draft.saved { Label("Saved", systemImage: "checkmark.circle.fill").font(.subheadline).foregroundStyle(OrbitStyle.teal) }
        }
        .confirmationDialog("Remove this emergency contact?", isPresented: Binding(get: { draft.removingContact != nil }, set: { if !$0 { draft.removingContact = nil } }), titleVisibility: .visible) {
            Button("Remove contact", role: .destructive) {
                if let contact = draft.removingContact { draft.contacts.removeAll { $0.id == contact.id } }
                draft.removingContact = nil
            }
            Button("Cancel", role: .cancel) { draft.removingContact = nil }
        }
    }
}

struct EmergencyContactEditor: View {
    @State var contact: EmergencyContact
    let save: (EmergencyContact) -> Void
    let back: () -> Void
    var body: some View {
        SettingsPage("Emergency Contact", back: back) {
            SettingsCard {
                SettingsField(label: "Full name", value: $contact.name)
                SettingsField(label: "Relationship", value: $contact.relationship)
                CountryPhoneInput(phone: $contact.phone, label: "Phone number")
            }
            PrimaryButton(title: "Done", busy: false, enabled: contact.isValid, capsule: true) { save(contact) }
            SettingsNote(text: "Tap Save in the Senior Profile section to keep this contact.")
        }
    }
}
struct SettingsMemberDetail: View {
    let member: LocalFamilyMember
    let isSelf: Bool
    @ObservedObject var settings: CaregiverSettingsStore
    let back: () -> Void
    @State private var confirmingRemoval = false
    var body: some View {
        SettingsPage("Family Member", back: back) {
            SettingsCard {
                detail("Full name", member.name)
                Divider()
                detail("Relationship to senior", member.relationship)
                Divider()
                detail("Contact", member.phone)
            }
            if !isSelf {
                Button("Remove member", role: .destructive) { confirmingRemoval = true }.frame(minHeight: 44)
            }
        }.confirmationDialog("Remove this local family member?", isPresented: $confirmingRemoval, titleVisibility: .visible) {
            Button("Remove member", role: .destructive) { settings.removeMember(member.id); back() }
            Button("Cancel", role: .cancel) {}
        }
    }
    private func detail(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.system(size: 14)).foregroundStyle(.secondary)
            Text(value.isEmpty ? "Not provided" : value).font(.system(size: 17))
        }
    }
}
