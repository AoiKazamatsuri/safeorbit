import SwiftUI
import AVFoundation

struct FamilyRoot: View {
    @StateObject private var family = FamilySession.shared
    @State private var role: DemoAppRole?
    @State private var management = false
    @State private var loggingOut = false
    @Environment(\.scenePhase) private var scenePhase
    var body: some View {
        Group {
            if !family.consent {
                FamilyPrivacyPage(family: family)
            } else if let device = family.device, let session = family.session {
                Group {
                    if session.role == "elder" {
                        ElderRoot(device: device, chooseRole: { management = true })
                    } else {
                        HomeRoot(device: device, chooseRole: { loggingOut = true })
                    }
                }.id(family.viewID)
            } else {
                NavigationStack {
                    if family.restoring {
                        ProgressView("Restoring your family…")
                    } else if family.hasSavedSession && !family.isLoggedIn {
                        VStack(spacing: 20) {
                            Text("Reconnect to your family").font(.title2.bold())
                            Text(family.error ?? "Connect to the internet to restore this phone’s family.").multilineTextAlignment(.center)
                            Button("Try again") { Task { await family.restore() } }.buttonStyle(.borderedProminent)
                        }.padding(32)
                    } else if family.pending {
                        VStack(spacing: 20) {
                            Text("Finish joining your family").font(.title2.bold())
                            Text("The last request may have reached the server. Retry to safely finish the same request.").multilineTextAlignment(.center)
                            if let error = family.error { Text(error).foregroundStyle(.red) }
                            Button("Retry") { Task { await family.retryPending() } }.buttonStyle(.borderedProminent).disabled(family.busy)
                        }.padding(32)
                    } else if family.isLoggedIn {
                        FamilyEntryPage(family: family, role: .caregiver, back: { loggingOut = true })
                    } else if role == .caregiver {
                        FamilyAccountPage(family: family, back: { role = nil; family.error = nil })
                    } else if let role {
                        FamilyEntryPage(family: family, role: role, back: { self.role = nil; family.error = nil })
                    } else {
                        RolePage(family: { role = .caregiver }, elder: { role = .elder })
                            .safeAreaInset(edge: .bottom) {
                                if let error = family.error { BottomNotice(message: error) { family.error = nil } }
                            }
                    }
                }
            }
        }
        .tint(OrbitStyle.teal).environment(\.locale, Locale(identifier: "en")).preferredColorScheme(.light)
        .sheet(isPresented: $management) {
            NavigationStack { FamilyManagementPage(family: family) }
        }
        .confirmationDialog("Log out of SafeOrbit?", isPresented: $loggingOut, titleVisibility: .visible) {
            Button("Log Out", role: .destructive) { Task { await family.logOut() } }
            Button("Cancel", role: .cancel) {}
        } message: { Text("Your family membership and saved conversations remain. Log in with the same email to return.") }
        .onChange(of: family.session?.memberId) { previous, current in
            if previous != nil && current == nil { role = nil; management = false }
        }
        .task(id: family.consent) { await family.restore() }
        .task(id: scenePhase) {
            guard scenePhase == .active else { return }
            while !Task.isCancelled {
                if family.device != nil { await family.restore() }
                try? await Task.sleep(for: .seconds(5))
            }
        }
    }
}

struct FamilyPrivacyPage: View {
    @ObservedObject var family: FamilySession
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Image(systemName: "hand.raised.fill").font(.system(size: 44)).foregroundStyle(OrbitStyle.teal)
                Text("Before you begin").font(.largeTitle.bold())
                Text("SafeOrbit is for internal testing by informed team members. It is not a substitute for care or emergency services.")
                privacySection("What we collect", "The senior’s location and routes, phone battery and location permission status, account email, family names and phone numbers, care events and conversation records.")
                privacySection("How it is used", "Your family can view its own location and care records. SafeOrbit uses these records to detect unusual trips, offer navigation and notify family. The assistant may send questions and limited care summaries to the language service; precise tracks and contacts are not sent as conversation history.")
                privacySection("Maps and location", "AMap provides maps, place search and walking routes and processes location and device/network information for these services. The senior’s phone also records and uploads location in the background when location permission is granted.")
                Link("AMap Privacy Policy", destination: URL(string: "https://lbs.amap.com/pages/privacy/")!)
                privacySection("Keeping and deleting data", "The primary caregiver can delete the entire family and its data in Family Members. Members can leave; a primary caregiver needs another caregiver to take over. Delete your test family when testing ends; remaining test data will be cleared within 30 days after testing ends. Leaving a family stops this phone’s access but does not delete the family’s records.")
                if let error = family.error { Text(error).foregroundStyle(.red) }
                Button("Agree and continue") { family.acceptPrivacy(); family.error = nil }
                    .buttonStyle(.borderedProminent).controlSize(.large).accessibilityIdentifier("family-privacy-agree")
                Button("Not now") { family.declinePrivacy() }.frame(minHeight: 44).accessibilityIdentifier("family-privacy-decline")
            }.padding(32).frame(maxWidth: 600)
        }
    }
    private func privacySection(_ title: String, _ body: String) -> some View {
        VStack(alignment: .leading, spacing: 8) { Text(title).font(.headline); Text(body) }
    }
}

struct FamilyAccountPage: View {
    @ObservedObject var family: FamilySession
    let back: () -> Void
    @State private var email = ""
    @State private var password = ""
    @State private var confirmation = ""
    @State private var registering = false
    @State private var claimLegacy = false
    @State private var autofill = SignupAutofillState()
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                Text(registering ? "Create your account" : "Welcome back").font(.largeTitle.bold())
                Text("Use your email to keep your family connection when you log out.").foregroundStyle(.secondary)
                AuthInput(title: "Email", symbol: "envelope", text: $email).accessibilityIdentifier("family-account-email")
                AuthInput(title: "Password", symbol: "lock", text: $password, password: true, newPassword: registering,
                          autofillState: autofill, linkedConfirmation: $confirmation).accessibilityIdentifier("family-account-password")
                if registering {
                    AuthInput(title: "Confirm password", symbol: "lock", text: $confirmation, password: true,
                              newPassword: true, confirmation: true, autofillState: autofill)
                    Text("Use at least 12 characters.").font(.footnote)
                    if family.hasLegacyCaregiver {
                        Toggle("Keep this phone’s existing family", isOn: $claimLegacy)
                        Text("Only enable this when the family already on this phone belongs to you. Its records will be linked to this account.").font(.footnote)
                    }
                }
                if let error = family.error { Text(error).foregroundStyle(.red) }
                Button(registering ? "Create account" : "Log In") {
                    Task { await family.authenticate(email: email, password: password, registering: registering, claimLegacy: claimLegacy) }
                }.buttonStyle(.borderedProminent).controlSize(.large).disabled(!valid || family.busy)
                    .accessibilityIdentifier("family-account-submit")
                if family.busy { ProgressView() }
                Button(registering ? "Already have an account? Log in" : "Create an account") {
                    registering.toggle(); password = ""; confirmation = ""; family.error = nil
                }.disabled(family.busy)
            }.padding(32).frame(maxWidth: 600)
        }
        .navigationTitle("Caregiver account").navigationBarTitleDisplayMode(.inline)
        .toolbar { ToolbarItem(placement: .topBarLeading) { Button("Back", action: back).disabled(family.busy) } }
        .onAppear { email = family.savedEmail }
    }
    private var valid: Bool {
        EmailAddress.isValid(email) && (registering ? password.count >= 12 && password == confirmation : !password.isEmpty)
    }
}

struct FamilyEntryPage: View {
    @ObservedObject var family: FamilySession
    let role: DemoAppRole
    let back: () -> Void
    @State private var creating = false
    @State private var name = ""
    @State private var phone = ""
    @State private var elder = ElderProfile()
    @State private var code = ""
    @State private var home: GeoPoint?
    @State private var radius = 100
    @State private var selectingHome = false
    @State private var scanning = false
    @State private var cameraError: String?
    var body: some View {
        Form {
            if role == .caregiver {
                Section {
                    Picker("Family", selection: $creating) {
                        Text("Join family").tag(false)
                        Text("Create family").tag(true)
                    }.pickerStyle(.segmented)
                }
                Section("Your details") {
                    TextField("Your name", text: $name).textContentType(.name).accessibilityIdentifier("family-name")
                    TextField("Phone number, including country code", text: $phone).keyboardType(.phonePad).textContentType(.telephoneNumber).accessibilityIdentifier("family-phone")
                }
            }
            if creating && role == .caregiver {
                Section("Senior profile") {
                    TextField("Senior name", text: $elder.name).accessibilityIdentifier("family-elder-name")
                    TextField("Call name, e.g. Grandpa", text: $elder.callName).accessibilityIdentifier("family-call-name")
                    TextField("Senior phone, including country code", text: $elder.phone).keyboardType(.phonePad).accessibilityIdentifier("family-elder-phone")
                    Picker("Time zone", selection: $elder.timezone) {
                        ForEach(TimeZone.knownTimeZoneIdentifiers, id: \.self) { Text($0).tag($0) }
                    }
                }
                Section("Home") {
                    Button(home == nil ? "Choose home on map" : "Change home location") { selectingHome = true }
                        .accessibilityIdentifier("family-home-map")
                    if let home { Text(String(format: "Selected: %.5f, %.5f", home.latitude, home.longitude)).font(.footnote).foregroundStyle(.secondary) }
                    Picker("Home radius", selection: $radius) {
                        ForEach([100, 200, 500, 1000, 2000], id: \.self) { Text("\($0) m").tag($0) }
                    }
                }
            } else {
                Section("Invitation") {
                    TextField("12-character code", text: $code).textInputAutocapitalization(.characters).autocorrectionDisabled()
                        .accessibilityIdentifier("family-invite-code")
                    Button("Scan QR code") { Task { await openScanner() } }.frame(minHeight: 44)
                    if let cameraError { Text(cameraError).foregroundStyle(.secondary) }
                    Text("Ask a caregiver to open Family Members and share the invitation code.").font(.footnote)
                }
            }
            if let error = family.error { Section { Text(error).foregroundStyle(.red).accessibilityIdentifier("family-error") } }
            Section {
                Button {
                    Task {
                        if creating, let home { await family.create(caregiverName: name, caregiverPhone: phone, elder: elder, home: home, radius: radius) }
                        else { await family.join(code: code, role: role, name: name, phone: phone) }
                    }
                } label: {
                    HStack { Text(creating ? "Create family" : "Join family"); if family.busy { ProgressView() } }
                        .frame(maxWidth: .infinity, minHeight: 44)
                }.disabled(!valid || family.busy).accessibilityIdentifier("family-submit")
            }
        }
        .disabled(family.busy)
        .navigationTitle(role == .elder ? "Join your family" : "Your family")
        .toolbar { ToolbarItem(placement: .topBarLeading) { Button(family.isLoggedIn ? "Log Out" : "Back", action: back) } }
        .sheet(isPresented: $selectingHome) { FamilyHomePicker(home: $home, radius: radius) }
        .sheet(isPresented: $scanning) {
            NavigationStack {
                QRScanner { result in
                    scanning = false
                    switch result {
                    case .success(let scanned):
                        if let valid = FamilyInvite.normalized(scanned) { code = valid; cameraError = nil }
                        else { cameraError = "Check that this is a SafeOrbit family invitation." }
                    case .failure: cameraError = "Camera unavailable. Enter the invitation code instead."
                    }
                }.navigationTitle("Scan invitation")
                    .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { scanning = false } } }
            }
        }
    }
    private var valid: Bool {
        let person = role == .elder || (!name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && name.count <= 60 && PhoneNumber.isValid(phone))
        return person && (creating ? elder.isValid && !elder.callName.isEmpty && elder.callName.count <= 60 && home != nil : FamilyInvite.normalized(code) != nil)
    }
    private func openScanner() async {
        guard AVCaptureDevice.default(for: .video) != nil else { cameraError = "No camera available. Enter the invitation code instead."; return }
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        var granted = status == .authorized
        if status == .notDetermined { granted = await AVCaptureDevice.requestAccess(for: .video) }
        if granted { scanning = true; cameraError = nil }
        else { cameraError = "Allow camera access in iPhone Settings, or enter the invitation code." }
    }
}

private struct FamilyHomePicker: View {
    @Binding var home: GeoPoint?
    let radius: Int
    @Environment(\.dismiss) private var dismiss
    @State private var selected: GeoPoint?
    @State private var available = false
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Text("Move the pin to your home, then confirm.").padding()
                SafeZoneSelectionMap(initialCenter: selected ?? home ?? LocationPreviewData.campus, radiusMeters: radius,
                    onSelection: { selected = $0 }, onAvailability: { available = $0 })
                Button("Confirm home") { home = selected ?? home ?? LocationPreviewData.campus; dismiss() }
                    .buttonStyle(.borderedProminent).controlSize(.large).padding().disabled(!available)
                    .accessibilityIdentifier("family-home-confirm")
            }.navigationTitle("Home location").navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } } }
        }
    }
}

struct FamilyManagementPage: View {
    @ObservedObject var family: FamilySession
    var close: (() -> Void)? = nil
    @Environment(\.dismiss) private var dismiss
    @State private var removing: FamilyMember?
    @State private var leaving = false
    @State private var deleting = false
    var body: some View {
        Group {
            if let close {
                let corners = UnevenRoundedRectangle(topLeadingRadius: 28, topTrailingRadius: 28)
                let surface = Color(uiColor: .systemGroupedBackground)
                VStack(spacing: 0) {
                    caregiverHeader(close: close)
                    membersForm
                        .scrollContentBackground(.hidden)
                        .background(surface, in: corners)
                        .clipShape(corners)
                        .background(alignment: .top) { OrbitStyle.teal.frame(height: 40) }
                }
                .background(surface.ignoresSafeArea(edges: .bottom))
            } else {
                membersForm
                    .navigationTitle("Family Members").navigationBarTitleDisplayMode(.inline)
                    .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Done") { dismiss() } } }
            }
        }
        .task {
            while !Task.isCancelled && family.session?.role == "caregiver" {
                await family.refreshMembers()
                try? await Task.sleep(for: .seconds(3))
            }
        }
        .confirmationDialog("Remove this member?", isPresented: Binding(get: { removing != nil }, set: { if !$0 { removing = nil } }), titleVisibility: .visible) {
            Button("Remove member", role: .destructive) { if let member = removing { Task { await family.remove(member) } }; removing = nil }
            Button("Cancel", role: .cancel) { removing = nil }
        } message: { Text("This phone will immediately lose access to your family.") }
        .confirmationDialog("Leave this family?", isPresented: $leaving, titleVisibility: .visible) {
            Button("Leave Family", role: .destructive) { Task { await family.leaveFamily() } }
            Button("Cancel", role: .cancel) {}
        } message: { Text("Your account stays signed in. A primary caregiver must have another caregiver who can take over.") }
        .confirmationDialog("Delete this family and all its data?", isPresented: $deleting, titleVisibility: .visible) {
            Button("Delete Family", role: .destructive) { Task { await family.deleteFamily() } }
            Button("Cancel", role: .cancel) {}
        }
    }

    private var membersForm: some View {
        Form {
            if let session = family.session {
                Section("Senior profile") {
                    LabeledContent("Name", value: session.household.elder.name)
                    LabeledContent("Call name", value: session.household.elder.callName)
                    LabeledContent("Phone", value: session.household.elder.phone)
                    LabeledContent("Time zone", value: session.household.elder.timezone)
                }
                Section("Primary caregiver") {
                    LabeledContent("Name", value: session.household.caregiver.name)
                    LabeledContent("Phone", value: session.household.caregiver.phone)
                }
                if session.role == "caregiver", let membership = family.members {
                    Section("Invite to your family") {
                        QRCodeImage(value: membership.inviteCode).frame(height: 200).frame(maxWidth: .infinity)
                        Text(membership.inviteCode).font(.title2.monospaced().bold()).textSelection(.enabled)
                            .accessibilityIdentifier("family-current-invite")
                        ShareLink("Share invitation code", item: membership.inviteCode)
                        Text("This code has no expiry. Share it only with people who should have access to this family.").font(.footnote)
                    }
                    Section("Family members") {
                        ForEach(membership.members) { member in
                            VStack(alignment: .leading, spacing: 8) {
                                Text(member.name).font(.headline)
                                Text(member.isPrimary ? "Primary caregiver" : member.role == "elder" ? "Senior phone" : "Caregiver").foregroundStyle(.secondary)
                                if member.id == session.memberId { Text("This phone").font(.caption) }
                                if session.isPrimary && member.id != session.memberId {
                                    Button("Remove member", role: .destructive) { removing = member }.frame(minHeight: 44)
                                }
                            }
                        }
                    }
                }
                if let error = family.error { Section { Text(error).foregroundStyle(.red) } }
                if session.role == "caregiver" { Section { Button("Refresh members") { Task { await family.refreshMembers() } } } }
                Section {
                    Button("Leave Family", role: .destructive) { leaving = true }
                        .frame(minHeight: 44).accessibilityIdentifier("family-leave")
                } footer: {
                    Text("Leaving removes your membership. Your account stays signed in so you can create or join another family. Existing conversations stay archived and will not appear in another family.")
                }
                if session.isPrimary {
                    Section {
                        Button("Delete Family", role: .destructive) { deleting = true }
                            .frame(minHeight: 44).accessibilityIdentifier("family-delete")
                    } footer: { Text("Deleting removes this family’s records and disconnects every member. This cannot be undone.") }
                }
            }
        }
        .disabled(family.busy)
    }

    private func caregiverHeader(close: @escaping () -> Void) -> some View {
        CaregiverTopBar {
            HStack(spacing: 0) {
                Button(action: close) {
                    Image(systemName: "chevron.left").font(.system(size: 20, weight: .semibold))
                        .frame(width: 56, height: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Back")
                .accessibilityIdentifier("family-management-back")
                Text("Family Members").orbitDisplayFont(20).multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity)
                    .accessibilityAddTraits(.isHeader)
                Color.clear.frame(width: 56, height: 1).accessibilityHidden(true)
            }.foregroundStyle(.white)
        }
    }
}
