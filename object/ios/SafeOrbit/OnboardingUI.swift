import SwiftUI
import PhotosUI
import AuthenticationServices
import CoreImage.CIFilterBuiltins

enum OrbitStyle {
    static let teal = Color(red: 0.29, green: 0.46, blue: 0.45)
    static let pale = Color(red: 0.92, green: 0.95, blue: 0.92)
    static let border = Color(red: 0.88, green: 0.89, blue: 0.91)
    static let secondary = Color(red: 0.43, green: 0.45, blue: 0.49)
    static let background = Color.white
}
struct PageLayout<Content: View>: View {
    let step: String
    let title: String
    var subtitle: String = ""
    @ViewBuilder var content: Content
    var body: some View {
        ScrollView {
            VStack(spacing: 30) {
                VStack(spacing: 12) {
                    Text(title).font(.system(.title2, design: .default, weight: .bold)).foregroundStyle(OrbitStyle.teal)
                    if !step.isEmpty { Text(step).font(.footnote).foregroundStyle(OrbitStyle.secondary) }
                    if !subtitle.isEmpty {
                        Text(subtitle).font(.subheadline).foregroundStyle(OrbitStyle.secondary).fixedSize(horizontal: false, vertical: true)
                    }
                }.multilineTextAlignment(.center).frame(maxWidth: .infinity)
                content
            }.padding(.horizontal, 36).padding(.top, 72).padding(.bottom, 36)
                .frame(maxWidth: 480).frame(maxWidth: .infinity)
        }.background(OrbitStyle.background).environment(\.locale, Locale(identifier: "en"))
            .tint(OrbitStyle.teal).scrollDismissesKeyboard(.interactively)
    }
}
struct Card<Content: View>: View {
    @ViewBuilder var content: Content
    var body: some View {
        VStack(alignment: .leading, spacing: 18) { content }.frame(maxWidth: .infinity, alignment: .leading)
    }
}
struct PrimaryButton: View {
    let title: String
    var busy = false
    var enabled = true
    var capsule = true
    var symbol: String? = nil
    var action: () -> Void
    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                if busy { ProgressView().tint(.white) }
                else if let symbol { Image(systemName: symbol).font(.body) }
                Text(title).font(.system(.body, weight: .medium)).multilineTextAlignment(.center)
            }.frame(maxWidth: .infinity).padding(.horizontal, 18).padding(.vertical, 14).frame(minHeight: 48)
        }.buttonStyle(.plain).foregroundStyle(.white)
            .background(OrbitStyle.teal.opacity(enabled && !busy ? 1 : 0.45), in: Capsule())
            .disabled(!enabled || busy)
    }
}
struct LabeledInput: View {
    let label: String
    let placeholder: String
    @Binding var value: String
    var phone = false
    var showsLabel = true
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if showsLabel { Text(label).font(.subheadline).foregroundStyle(OrbitStyle.secondary) }
            TextField(placeholder, text: $value)
                .keyboardType(phone ? .phonePad : .default)
                .textContentType(phone ? .telephoneNumber : nil)
                .textInputAutocapitalization(phone ? .never : .words)
                .padding(.horizontal, 18).padding(.vertical, 14)
                .overlay(Capsule().stroke(OrbitStyle.border, lineWidth: 1))
                .accessibilityLabel(label)
        }
    }
}
struct RolePage: View {
    var family: () -> Void
    var elder: () -> Void
    var body: some View {
        PageLayout(step: "", title: "Welcome", subtitle: "Choose your role") {
            VStack(spacing: 16) {
                roleButton("Caregiver", icon: "person.2", action: family)
                roleButton("Older adult", icon: "figure.walk", action: elder)
            }
        }
    }
    private func roleButton(_ title: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon).foregroundStyle(OrbitStyle.teal)
                Text(title).font(.body.weight(.medium))
            }.frame(maxWidth: .infinity).padding(18).foregroundStyle(OrbitStyle.teal)
                .background(OrbitStyle.pale, in: Capsule())
        }.buttonStyle(.plain)
    }
}
struct AuthDivider: View {
    var body: some View {
        HStack(spacing: 18) {
            Rectangle().fill(OrbitStyle.border).frame(height: 1)
            Text("or").font(.footnote).foregroundStyle(OrbitStyle.secondary)
            Rectangle().fill(OrbitStyle.border).frame(height: 1)
        }.padding(.vertical, 2)
    }
}
struct AuthInput: View {
    let title: String
    let symbol: String
    @Binding var text: String
    var password = false
    var newPassword = false
    @State private var visible = false
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: symbol).foregroundStyle(OrbitStyle.secondary).frame(width: 20)
            Group {
                if password && !visible { SecureField(title, text: $text, prompt: Text(title).foregroundStyle(OrbitStyle.secondary)) }
                else { TextField(title, text: $text, prompt: Text(title).foregroundStyle(OrbitStyle.secondary)).keyboardType(password ? .default : .emailAddress) }
            }.textInputAutocapitalization(.never).autocorrectionDisabled()
                .textContentType(password ? (newPassword ? .newPassword : .password) : .emailAddress)
                .accessibilityLabel(title)
            if password {
                Button { visible.toggle() } label: {
                    Image(systemName: visible ? "eye.slash" : "eye").foregroundStyle(OrbitStyle.secondary)
                }.accessibilityLabel(visible ? "Hide password" : "Show password")
            }
        }.font(.subheadline).padding(.horizontal, 18).padding(.vertical, 14).frame(minHeight: 48)
            .overlay(Capsule().stroke(OrbitStyle.border, lineWidth: 1))
    }
}
struct SocialLoginButtons: View {
    @ObservedObject var store: OnboardingStore
    @StateObject private var apple = AppleLoginAuthorization()
    @StateObject private var google = GoogleLoginAuthorization()
    var body: some View {
        VStack(spacing: 12) {
            socialButton("Continue with Google", google: true) {
                Task { await store.startGoogleLogin { google.start($0, store: store) } }
            }
            socialButton("Continue with Apple", google: false) {
                Task { await store.startLogin { apple.start($0, store: store) } }
            }
            if store.loginInProgress { ProgressView().frame(maxWidth: .infinity) }
        }.disabled(store.loginInProgress)
    }
    private func socialButton(_ title: String, google: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 10) {
                if google { Image("GoogleLogo").resizable().scaledToFit().frame(width: 28, height: 28) }
                else { Image(systemName: "apple.logo").font(.system(size: 22)) }
                Text(title).font(.body.weight(.medium))
            }.foregroundStyle(.primary).frame(maxWidth: .infinity).padding(.horizontal, 12).padding(.vertical, 13)
                .frame(minHeight: 48).background(OrbitStyle.pale, in: Capsule())
        }.buttonStyle(.plain).disabled(!google && store.preparingLogin)
    }
}
struct AccountSwitch: View {
    let prompt: String
    let title: String
    var action: () -> Void
    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 4) { Text(prompt).foregroundStyle(OrbitStyle.secondary); Button(title, action: action).fontWeight(.semibold) }
            VStack(spacing: 6) { Text(prompt).foregroundStyle(OrbitStyle.secondary); Button(title, action: action).fontWeight(.semibold) }
        }.font(.footnote).foregroundStyle(OrbitStyle.teal).frame(maxWidth: .infinity).padding(.top, 8)
    }
}
struct LoginPage: View {
    @ObservedObject var store: OnboardingStore
    var body: some View {
        PageLayout(step: "", title: "Login") {
            VStack(spacing: 12) {
                AuthInput(title: "Email", symbol: "envelope", text: $store.email)
                AuthInput(title: "Password", symbol: "lock", text: $store.password, password: true)
                Button { store.showAuth(.forgotPassword) } label: {
                    Text("Forgot password?").font(.footnote).underline()
                }.padding(.top, 4)
                PrimaryButton(title: "Login", busy: store.busy, enabled: store.emailLoginValid && !store.authorizing) {
                    Task { await store.signInWithEmail() }
                }
                AuthDivider()
                SocialLoginButtons(store: store)
                AccountSwitch(prompt: "Need an account?", title: "Sign up") { store.showAuth(.signup) }
            }.disabled(store.loginInProgress)
        }.task { await store.prepareLogin() }
    }
}
struct SignupPage: View {
    @ObservedObject var store: OnboardingStore
    var body: some View {
        PageLayout(step: "", title: "Sign up") {
            VStack(spacing: 12) {
                PrimaryButton(title: "Sign up with email", enabled: !store.loginInProgress, symbol: "envelope") { store.showAuth(.emailSignup) }
                AuthDivider()
                SocialLoginButtons(store: store)
                AccountSwitch(prompt: "Already have an account?", title: "Login") { store.showAuth(.login) }
            }.disabled(store.loginInProgress)
        }.task { await store.prepareLogin() }
    }
}
struct EmailSignupPage: View {
    @ObservedObject var store: OnboardingStore
    var body: some View {
        PageLayout(step: "", title: "Create account") {
            VStack(spacing: 14) {
                AuthInput(title: "Email", symbol: "envelope", text: $store.email)
                AuthInput(title: "Password", symbol: "lock", text: $store.password, password: true, newPassword: true)
                AuthInput(title: "Confirm password", symbol: "lock", text: $store.confirmPassword, password: true, newPassword: true)
                if !store.password.isEmpty && store.password.count < 8 {
                    Text("Use at least 8 characters.").font(.footnote).foregroundStyle(.red).frame(maxWidth: .infinity, alignment: .leading)
                } else if !store.confirmPassword.isEmpty && store.confirmPassword != store.password {
                    Text("Passwords don't match.").font(.footnote).foregroundStyle(.red).frame(maxWidth: .infinity, alignment: .leading)
                }
                PrimaryButton(title: "Create account", busy: store.busy, enabled: store.emailSignupValid) {
                    Task { await store.registerWithEmail() }
                }
                AccountSwitch(prompt: "Already have an account?", title: "Login") { store.showAuth(.login) }
            }.disabled(store.loginInProgress)
        }
    }
}
struct ForgotPasswordPage: View {
    @ObservedObject var store: OnboardingStore
    var body: some View {
        PageLayout(step: "", title: "Reset password") {
            VStack(spacing: 18) {
                if store.resetEmailSent {
                    Text("Check your email for a reset link.").font(.subheadline).foregroundStyle(OrbitStyle.secondary).multilineTextAlignment(.center).frame(maxWidth: .infinity)
                } else {
                    AuthInput(title: "Email", symbol: "envelope", text: $store.email)
                    PrimaryButton(title: "Send reset link", busy: store.busy, enabled: EmailAddress.isValid(store.email)) {
                        Task { await store.sendPasswordReset() }
                    }
                }
                Button("Back to login") { store.showAuth(.login) }.font(.footnote.weight(.semibold))
            }.disabled(store.loginInProgress)
        }
    }
}
struct PhonePage: View {
    @Binding var phone: String
    var busy: Bool
    var next: () -> Void
    var body: some View {
        PageLayout(step: "Family setup · 1 of 3", title: "Your phone number") {
            CountryPhoneInput(phone: $phone).disabled(busy)
            PrimaryButton(title: "Continue", busy: busy, enabled: PhoneNumber.isValid(phone), action: next)
        }
    }
}
struct ProfilePage: View {
    @Binding var profile: ElderProfile
    var busy: Bool
    var next: () -> Void
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var photoError: String?
    @State private var loadingPhoto = false
    var body: some View {
        PageLayout(step: "Family setup · 2 of 3", title: "Senior profile") {
            Card {
                PhotosPicker(selection: $selectedPhoto, matching: .images) {
                    VStack(spacing: 8) {
                        ProfileAvatar(photo: profile.photo, size: 90)
                        Text("Choose a photo").font(.subheadline.weight(.medium)).foregroundStyle(OrbitStyle.teal)
                    }.frame(maxWidth: .infinity)
                }.disabled(busy || loadingPhoto)
                if loadingPhoto { ProgressView().frame(maxWidth: .infinity) }
                if profile.photo != nil { Button("Remove photo") { profile.photo = nil; selectedPhoto = nil }.frame(maxWidth: .infinity) }
                if let photoError { Text(photoError).font(.footnote).foregroundStyle(.red) }
                LabeledInput(label: "Name", placeholder: "Full name", value: $profile.name)
                CountryPhoneInput(phone: $profile.phone, label: "Phone number")
            }.disabled(busy)
            PrimaryButton(title: "Save profile", busy: busy,
                          enabled: profile.isValid && !loadingPhoto, capsule: true, action: next)
        }.onChange(of: selectedPhoto) { _, item in
            Task { await loadPhoto(item) }
        }
    }
    @MainActor private func loadPhoto(_ item: PhotosPickerItem?) async {
        guard let item else { return }
        loadingPhoto = true; photoError = nil
        defer { loadingPhoto = false }
        do {
            guard let data = try await item.loadTransferable(type: Data.self), let image = UIImage(data: data) else { throw APIError(kind: .other) }
            guard selectedPhoto == item else { return }
            let scale = min(1, 640 / max(image.size.width, image.size.height))
            let size = CGSize(width: image.size.width * scale, height: image.size.height * scale)
            let format = UIGraphicsImageRendererFormat(); format.scale = 1
            let resized = UIGraphicsImageRenderer(size: size, format: format).image { _ in image.draw(in: CGRect(origin: .zero, size: size)) }
            guard let jpeg = resized.jpegData(compressionQuality: 0.75), jpeg.count <= 512000 else { throw APIError(kind: .other) }
            profile.photo = "data:image/jpeg;base64," + jpeg.base64EncodedString()
        } catch { photoError = "Couldn't load that photo. Please choose another." }
    }
}
struct ProfileAvatar: View {
    let photo: String?
    var size: CGFloat = 64
    var body: some View {
        Group {
            if let photo, let comma = photo.firstIndex(of: ","), let data = Data(base64Encoded: String(photo[photo.index(after: comma)...])), let image = UIImage(data: data) {
                Image(uiImage: image).resizable().scaledToFill()
            } else {
                Circle().fill(OrbitStyle.pale).overlay { Image(systemName: "person.crop.circle").font(.system(size: size * 0.48)).foregroundStyle(OrbitStyle.teal) }
            }
        }.frame(width: size, height: size).clipShape(Circle()).accessibilityHidden(true)
    }
}
struct QRCodeImage: View {
    let value: String
    static func image(for value: String) -> UIImage? {
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(value.utf8); filter.correctionLevel = "M"
        guard let output = filter.outputImage,
              let cg = CIContext().createCGImage(output.transformed(by: CGAffineTransform(scaleX: 8, y: 8)), from: output.extent.applying(CGAffineTransform(scaleX: 8, y: 8))) else { return nil }
        return UIImage(cgImage: cg)
    }
    var body: some View {
        if let image = Self.image(for: value) {
            Image(uiImage: image).resizable().interpolation(.none).scaledToFit().padding(20)
                .background(.white).accessibilityLabel("Phone connection QR code")
        }
    }
}
struct FamilyBindingPage: View {
    let profile: ElderProfile
    let code: BindingCode?
    let busy: Bool
    var generate: () -> Void
    var refresh: () -> Void
    var edit: () -> Void
    var body: some View {
        PageLayout(step: "Family setup · 3 of 3",
                   title: profile.bound ? "Connected" : "Connect phone",
                   subtitle: profile.bound ? "" : "Scan this code on the other phone.") {
            Card {
                HStack(spacing: 14) { ProfileAvatar(photo: profile.photo); VStack(alignment: .leading, spacing: 4) {
                    Text(profile.name).font(.headline)
                    if !profile.callName.isEmpty && profile.callName != profile.name {
                        Text(profile.callName).font(.subheadline).foregroundStyle(OrbitStyle.secondary)
                    }
                }; Spacer(); Button(action: edit) { Image(systemName: "pencil").font(.title3) }.accessibilityLabel("Edit profile") }
            }
            if profile.bound {
                Card {
                    Image(systemName: "checkmark.circle.fill").font(.system(size: 60)).foregroundStyle(OrbitStyle.teal).frame(maxWidth: .infinity)
                }
            } else if let code {
                TimelineView(.periodic(from: .now, by: 1)) { context in
                    let remaining = max(0, Int(code.expiresAt.timeIntervalSince(context.date)))
                    Card {
                        if remaining > 0 {
                            QRCodeImage(value: code.payload).frame(maxWidth: 230).frame(maxWidth: .infinity)
                            Text("Expires in" + String(format: " %d:%02d", remaining / 60, remaining % 60))
                                .font(.subheadline.monospacedDigit()).foregroundStyle(OrbitStyle.secondary).frame(maxWidth: .infinity)
                            ShareLink(item: code.payload) { Label("Share link", systemImage: "square.and.arrow.up") }.frame(maxWidth: .infinity)
                        } else {
                            Label("Code expired", systemImage: "clock").font(.headline)
                        }
                    }
                }
                PrimaryButton(title: "New code", busy: busy, action: generate)
                Button("Check connection", action: refresh).font(.body.weight(.medium)).frame(maxWidth: .infinity).padding(14).background(OrbitStyle.pale, in: Capsule()).disabled(busy)
            } else {
                Card {
                    Image(systemName: "qrcode").font(.system(size: 80)).foregroundStyle(OrbitStyle.teal).frame(maxWidth: .infinity).padding(24)
                }
                PrimaryButton(title: "Create code", busy: busy, action: generate)
            }
        }
    }
}

struct CountryPhoneInput: View {
    @Binding var phone: String
    var label: String? = nil
    @State private var entry: PhoneEntry
    init(phone: Binding<String>, label: String? = nil) {
        _phone = phone; self.label = label
        _entry = State(initialValue: PhoneEntry(phone.wrappedValue))
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let label { Text(label).font(.subheadline).foregroundStyle(OrbitStyle.secondary) }
            HStack(spacing: 12) {
                Menu {
                    ForEach(options) { country in
                        Button("\(country.name) (\(country.code))") {
                            entry.country = country; phone = entry.fullNumber
                        }
                    }
                } label: {
                    HStack(spacing: 5) {
                        Text(entry.country.code)
                        Image(systemName: "chevron.down").font(.caption)
                    }.foregroundStyle(OrbitStyle.teal)
                }.accessibilityLabel("Country or region: \(entry.country.name), \(entry.country.code)")
                Divider().frame(height: 24)
                TextField("Phone number", text: Binding(get: { entry.digits }, set: {
                    entry.digits = PhoneEntry.filtered($0); phone = entry.fullNumber
                })).keyboardType(.numberPad).textContentType(.telephoneNumber)
                    .accessibilityLabel(label ?? "Phone number")
            }.padding(.horizontal, 18).padding(.vertical, 14).overlay(Capsule().stroke(OrbitStyle.border, lineWidth: 1))
            if entry.showsError {
                Text("Enter a valid phone number.").font(.footnote).foregroundStyle(.red)
            }
        }.onChange(of: phone) { _, value in
            if PhoneNumber.normalized(value) != entry.fullNumber { entry = PhoneEntry(value) }
        }
    }
    private var options: [PhoneCountry] {
        PhoneCountry.choices.contains(entry.country) ? PhoneCountry.choices : [entry.country] + PhoneCountry.choices
    }
}

@MainActor final class AppleLoginAuthorization: NSObject, ObservableObject, ASAuthorizationControllerDelegate, ASAuthorizationControllerPresentationContextProviding {
    private var controller: ASAuthorizationController?
    private weak var store: OnboardingStore?
    private var anchor: ASPresentationAnchor?
    func start(_ request: ASAuthorizationAppleIDRequest, store: OnboardingStore) {
        guard let window = UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene })
            .filter({ $0.activationState == .foregroundActive }).flatMap(\.windows).first(where: \.isKeyWindow) else {
            Task { await store.completeLogin(.failure(APIError(kind: .other))) }; return
        }
        self.store = store; anchor = window
        let controller = ASAuthorizationController(authorizationRequests: [request])
        self.controller = controller; controller.delegate = self; controller.presentationContextProvider = self
        controller.performRequests()
    }
    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor { anchor! }
    func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        finish(.success(authorization))
    }
    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        finish(.failure(error))
    }
    private func finish(_ result: Result<ASAuthorization, Error>) {
        let store = store; controller = nil; anchor = nil
        Task { await store?.completeLogin(result) }
    }
}

@MainActor final class GoogleLoginAuthorization: NSObject, ObservableObject, ASWebAuthenticationPresentationContextProviding {
    private var session: ASWebAuthenticationSession?
    private var anchor: ASPresentationAnchor?
    func start(_ challenge: GoogleChallenge, store: OnboardingStore) {
        guard let url = challenge.validatedURL,
              let window = UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene })
                .filter({ $0.activationState == .foregroundActive }).flatMap(\.windows).first(where: \.isKeyWindow) else {
            Task { await store.completeGoogleLogin(.failure(APIError(kind: .other))) }; return
        }
        anchor = window
        let session = ASWebAuthenticationSession(url: url, callbackURLScheme: "safeorbit") { [weak self, weak store] url, error in
            Task { @MainActor in
                self?.session = nil; self?.anchor = nil
                if let url { await store?.completeGoogleLogin(.success(url)) }
                else { await store?.completeGoogleLogin(.failure(error ?? APIError(kind: .other))) }
            }
        }
        self.session = session; session.presentationContextProvider = self
        if !session.start() {
            self.session = nil; anchor = nil
            Task { await store.completeGoogleLogin(.failure(APIError(kind: .other))) }
        }
    }
    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor { anchor! }
}
