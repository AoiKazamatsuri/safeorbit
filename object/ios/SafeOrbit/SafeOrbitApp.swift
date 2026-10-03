import SwiftUI

@main struct SafeOrbitApp: App {
    var body: some Scene { WindowGroup { OnboardingRoot() } }
}
struct OnboardingRoot: View {
#if DEBUG
    @StateObject private var store = OnboardingStore(previewAccessEnabled: true)
#else
    @StateObject private var store = OnboardingStore()
#endif
    @State private var payload = ""
    @State private var confirmLogout = false
    var body: some View {
        NavigationStack {
            Group {
                if store.restoring {
                    ProgressView("Restoring your connection…")
                } else {
                    switch store.screen {
                    case .role: RolePage(family: { store.screen = .login }, elder: { store.screen = .scan })
                    case .login: LoginPage(store: store)
                    case .signup: SignupPage(store: store)
                    case .emailSignup: EmailSignupPage(store: store)
                    case .forgotPassword: ForgotPasswordPage(store: store)
                    case .phone: PhonePage(phone: $store.caregiverPhone, busy: store.busy) { Task { await store.savePhone() } }
                    case .profile: ProfilePage(profile: $store.elder, busy: store.busy) { Task { await store.saveProfile() } }
                    case .familyBinding: FamilyBindingPage(profile: store.elder, code: store.code, busy: store.busy,
                        generate: { Task { await store.generateCode() } }, refresh: { Task { await store.refreshBinding() } },
                        edit: { store.screen = .profile })
                    case .caregiverHome: CaregiverHomePage(store: store)
                    case .scan: ScanPage(busy: store.busy, payload: $payload) { value in Task { await store.bind(value) } }
                    case .elderReady: ElderReadyPage(profile: store.elder)
                    }
                }
            }.tint(OrbitStyle.teal).navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        if [.login, .signup, .emailSignup, .forgotPassword, .scan].contains(store.screen) {
                            Button {
                                if store.screen == .emailSignup { store.showAuth(.signup) }
                                else if store.screen == .forgotPassword { store.showAuth(.login) }
                                else { store.showAuth(.role) }
                            } label: { Image(systemName: "chevron.left") }
                                .accessibilityLabel("Back").disabled(store.loginInProgress)
                        }
                    }
                    ToolbarItem(placement: .topBarTrailing) {
                        if store.token != nil && store.screen != .caregiverHome {
                            Button("Sign out") { confirmLogout = true }.disabled(store.busy)
                        }
                    }
                }
                .safeAreaInset(edge: .bottom) {
                    if let message = store.error {
                        HStack(alignment: .center, spacing: 12) {
                            Image(systemName: "exclamationmark.circle").foregroundStyle(OrbitStyle.teal)
                            Text(message).font(.subheadline).frame(maxWidth: .infinity, alignment: .leading)
                            Button { store.error = nil } label: { Image(systemName: "xmark") }.accessibilityLabel("Dismiss message")
                        }
                        .padding(.horizontal, 18).padding(.vertical, 14)
                        .background(OrbitStyle.pale.opacity(0.5), in: Capsule())
                        .padding(.horizontal, 5).padding(.bottom, 6)
                        .accessibilityElement(children: .contain)
                    }
                }
                .confirmationDialog("Sign out on this phone?", isPresented: $confirmLogout, titleVisibility: .visible) {
                    Button("Sign out", role: .destructive) { Task { await store.signOut() } }
                    Button("Cancel", role: .cancel) {}
                }
        }.environment(\.locale, Locale(identifier: "en")).preferredColorScheme(.light).task { await store.restore() }
            .onOpenURL { url in
                guard store.token == nil, url.host != "oauth" else { return }
                store.screen = .scan; payload = url.absoluteString
            }
    }
}
#if DEBUG
private struct ProfilePreview: View {
    @State private var profile = ElderProfile()
    var body: some View { NavigationStack { ProfilePage(profile: $profile, busy: false, next: {}) } }
}
private struct PhonePreview: View {
    @State private var phone = ""
    var body: some View { NavigationStack { PhonePage(phone: $phone, busy: false, next: {}) } }
}
private struct ScanPreview: View {
    @State private var payload = ""
    var body: some View { NavigationStack { ScanPage(busy: false, payload: $payload, bind: { _ in }) } }
}
private func previewProfile() -> ElderProfile {
    var profile = ElderProfile()
    profile.name = "Li Lan"; profile.callName = "Grandma"; profile.phone = "+86 138 0000 0000"
    return profile
}
#Preview("Choose role") { NavigationStack { RolePage(family: {}, elder: {}) } }
#Preview("Caregiver sign in") { NavigationStack { LoginPage(store: OnboardingStore()) } }
#Preview("Sign up") { NavigationStack { SignupPage(store: OnboardingStore()) } }
#Preview("Email registration") { NavigationStack { EmailSignupPage(store: OnboardingStore()) } }
#Preview("Reset password") { NavigationStack { ForgotPasswordPage(store: OnboardingStore()) } }
#Preview("Phone") { PhonePreview() }
#Preview("Senior profile") { ProfilePreview() }
#Preview("Connect phones") { NavigationStack {
    FamilyBindingPage(profile: previewProfile(), code: .init(token: String(repeating: "a", count: 43), expiresAt: Date().addingTimeInterval(300)),
                      busy: false, generate: {}, refresh: {}, edit: {})
} }
#Preview("Expired code") { NavigationStack {
    FamilyBindingPage(profile: previewProfile(), code: .init(token: String(repeating: "a", count: 43), expiresAt: .distantPast),
                      busy: false, generate: {}, refresh: {}, edit: {})
} }
#Preview("Scan code") { ScanPreview() }
#Preview("Connected") { ElderReadyPage(profile: previewProfile()) }
#endif
