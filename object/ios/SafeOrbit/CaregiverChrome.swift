import SwiftUI

/// Horizontal layout lines from product design section 10. Fixed points: margins never scale
/// with Dynamic Type.
enum OrbitLayout {
    /// Screen edge to the outer edge of cards, pickers, composers, full-width buttons and bubbles.
    static let pageMargin: CGFloat = 16
    static let cardPadding: CGFloat = 16
    /// Small cards that sit two to a row.
    static let compactCardPadding: CGFloat = 12
    /// Where text inside a card starts; group titles above cards use the same line.
    static let cardTextInset: CGFloat = pageMargin + cardPadding
    /// Role choice, login and phone connection pages with a centered title.
    static let centeredPageMargin: CGFloat = 32
    static let minimumHitSize: CGFloat = 44
}

extension View {
    /// Icon button label whose visible glyph edge sits on a layout line. `inset` is the distance
    /// from the button's edge to that line (the page margin when the button touches the screen
    /// edge). The 44 pt hit area grows away from the line.
    func iconHitArea(_ edge: HorizontalEdge, inset: CGFloat = 0,
                     minHeight: CGFloat? = OrbitLayout.minimumHitSize) -> some View {
        padding(edge == .leading ? .leading : .trailing, inset)
            .frame(minWidth: OrbitLayout.minimumHitSize, minHeight: minHeight,
                   alignment: edge == .leading ? .leading : .trailing)
            .contentShape(Rectangle())
    }

    /// Test hook: records this view's frame in window coordinates. Release builds keep the view as is.
    @ViewBuilder func layoutProbe(_ name: String) -> some View {
#if DEBUG
        background {
            GeometryReader { proxy in
                let frame = proxy.frame(in: .global)
                Color.clear
                    .onAppear { LayoutProbe.frames[name] = frame }
                    .onChange(of: frame) { _, latest in LayoutProbe.frames[name] = latest }
            }
        }
#else
        self
#endif
    }
}

#if DEBUG
/// Written and read on the main thread only: by view updates and by the layout tests.
enum LayoutProbe {
    static var frames: [String: CGRect] = [:]
}
#endif

enum CaregiverBottomLayout {
    static let barPadding: CGFloat = 7
    static let buttonHeight: CGFloat = 54
    static var barHeight: CGFloat { buttonHeight + barPadding * 2 }

    static func gap(safeAreaBottom: CGFloat) -> CGFloat {
        // Figma measures to the screen edge. The capsule's inner padding protects its buttons.
        max(30, safeAreaBottom - barPadding)
    }

    static func cardBottomPadding(safeAreaBottom: CGFloat) -> CGFloat {
        barHeight + 12 + gap(safeAreaBottom: safeAreaBottom) - safeAreaBottom
    }
}

struct CaregiverBottomOverlay<Content: View>: View {
    let content: Content
    init(@ViewBuilder content: () -> Content) { self.content = content() }
    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                Spacer(minLength: 0)
                content
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(.bottom, CaregiverBottomLayout.gap(safeAreaBottom: geometry.safeAreaInsets.bottom))
            .ignoresSafeArea(.container, edges: .bottom)
        }
    }
}

/// The teal strip used above caregiver pages that are not the full-screen location map.
struct CaregiverTopBar<Content: View>: View {
    let height: CGFloat
    let content: Content

    init(height: CGFloat = 47, @ViewBuilder content: () -> Content) {
        self.height = height
        self.content = content()
    }

    var body: some View {
        content
            .frame(maxWidth: .infinity)
            .frame(height: height)
            .background(OrbitStyle.teal)
            .background(OrbitStyle.teal.ignoresSafeArea(edges: .top))
    }
}

extension View {
    /// Keep the shadow on the card silhouette; applying it to the whole view also shadows its contents.
    func caregiverCard(radius: CGFloat = 24, opacity: Double = 0.14) -> some View {
        background {
            RoundedRectangle(cornerRadius: radius)
                .fill(.white)
                .shadow(color: .black.opacity(opacity), radius: 7, y: 3)
        }
    }
}

// Shared map accent matches the system-blue current-location dot in both rendering APIs.
enum OrbitMapStyle {
    static let uiBlue = UIColor.systemBlue
    static let blue = Color(uiColor: uiBlue)
}

private struct RecordingFont: ViewModifier {
    @ScaledMetric(relativeTo: .body) var size: CGFloat = 10
    let weight: Font.Weight
    init(size: CGFloat, weight: Font.Weight) {
        _size = ScaledMetric(wrappedValue: size, relativeTo: .body)
        self.weight = weight
    }
    func body(content: Content) -> some View { content.font(.system(size: max(10, size), weight: weight)) }
}
extension View {
    func recordingFont(_ size: CGFloat, weight: Font.Weight = .regular) -> some View {
        modifier(RecordingFont(size: max(10, size), weight: size <= 10 ? .medium : weight))
    }
}

// SF Pro is the system's default design. Keep the two audiences' scales separate.
enum CaregiverTextStyle: CaseIterable {
    case body, secondary, caption
    var size: CGFloat { switch self { case .body: 16; case .secondary: 14; case .caption: 10 } }
    var weight: Font.Weight { self == .secondary ? .regular : .medium }
}
enum ElderTextStyle: CaseIterable {
    case heading, body
    var size: CGFloat { self == .heading ? 24 : 20 }
}
private struct OrbitTextFont: ViewModifier {
    @ScaledMetric(relativeTo: .body) private var size: CGFloat = 16
    let weight: Font.Weight
    init(size: CGFloat, weight: Font.Weight) {
        _size = ScaledMetric(wrappedValue: size, relativeTo: .body)
        self.weight = weight
    }
    func body(content: Content) -> some View {
        content.font(.system(size: max(10, size), weight: weight, design: .default))
    }
}
extension View {
    func caregiverText(_ style: CaregiverTextStyle = .body) -> some View {
        modifier(OrbitTextFont(size: style.size, weight: style.weight))
    }
    func elderText(_ style: ElderTextStyle = .body) -> some View {
        modifier(OrbitTextFont(size: style.size, weight: .medium))
    }
    func orbitDisplayFont(_ size: CGFloat, weight: Font.Weight = .medium) -> some View {
        modifier(OrbitTextFont(size: size, weight: weight))
    }
}

// Both roles use the same sidebar geometry and interaction boundary.
struct SettingsSidebarModifier<Panel: View>: ViewModifier {
    @Binding var isPresented: Bool
    let widthFraction: CGFloat
    @ViewBuilder var panel: () -> Panel
    func body(content: Content) -> some View {
        ZStack {
            content.allowsHitTesting(!isPresented).accessibilityHidden(isPresented)
            GeometryReader { geometry in
                if isPresented {
                    ZStack(alignment: .leading) {
                        Color.black.opacity(0.36).ignoresSafeArea()
                            .onTapGesture { isPresented = false }
                            .accessibilityLabel("Close settings")
                            .accessibilityAddTraits(.isButton)
                        panel().frame(width: geometry.size.width * widthFraction, height: geometry.size.height)
                            .accessibilityAddTraits(.isModal)
                    }
                }
            }.ignoresSafeArea().allowsHitTesting(isPresented).zIndex(2)
        }
        .onChange(of: isPresented) { _, _ in
            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        }
    }
}
extension View {
    func settingsSidebar<Panel: View>(isPresented: Binding<Bool>, widthFraction: CGFloat,
                                     @ViewBuilder panel: @escaping () -> Panel) -> some View {
        modifier(SettingsSidebarModifier(isPresented: isPresented, widthFraction: widthFraction, panel: panel))
    }
}
struct SettingsSidebarPanel<Portrait: View, Entries: View>: View {
    let name: String
    var badge: String? = nil
    var elder = false
    let logout: () -> Void
    @ViewBuilder var portrait: () -> Portrait
    @ViewBuilder var entries: () -> Entries
    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                VStack(spacing: 0) {
                    HStack(spacing: elder ? 16 : 14) {
                        portrait().frame(width: elder ? 72 : 57, height: elder ? 72 : 57).clipShape(Circle())
                        VStack(alignment: .leading, spacing: 5) {
                            Group {
                                if elder { Text(name).elderText(.heading) }
                                else { Text(name).caregiverText() }
                            }.fixedSize(horizontal: false, vertical: true)
                            if let badge {
                                Text(badge).caregiverText(.caption).foregroundStyle(.white)
                                    .padding(.horizontal, 11).padding(.vertical, 4)
                                    .background(OrbitStyle.teal, in: Capsule())
                            }
                        }
                        Spacer(minLength: 0)
                    }
                    .padding(.horizontal, OrbitLayout.cardPadding).padding(.vertical, 12)
                    .frame(minHeight: elder ? 96 : 84).background(.white, in: Capsule())
                    .layoutProbe("drawer-header")
                    .padding(.horizontal, OrbitLayout.pageMargin).padding(.top, 57)
                    // Rows have no card, so their content starts on the page margin line.
                    VStack(spacing: 0) { entries() }.padding(.horizontal, OrbitLayout.pageMargin).padding(.top, 20)
                    Spacer(minLength: 24)
                    Button(action: logout) {
                        Label {
                            if elder { Text("Log Out").elderText() }
                            else { Text("Log Out").caregiverText() }
                        } icon: { Image(systemName: "rectangle.portrait.and.arrow.right") }
                        .foregroundStyle(.black).fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, minHeight: elder ? 56 : 51)
                        .padding(.vertical, elder ? 4 : 0)
                        .background(Color(red: 0.83, green: 0.91, blue: 0.91), in: Capsule())
                    }.buttonStyle(.plain)
                    .accessibilityIdentifier(elder ? "elder-log-out" : "caregiver-log-out")
                    .layoutProbe("drawer-logout")
                    .padding(.horizontal, OrbitLayout.pageMargin).padding(.bottom, 42)
                }.frame(maxWidth: .infinity, minHeight: geometry.size.height)
            }
        }
        .background(Color(red: 0.975, green: 0.982, blue: 0.978))
        .clipShape(UnevenRoundedRectangle(topLeadingRadius: 0, bottomLeadingRadius: 0,
            bottomTrailingRadius: 36, topTrailingRadius: 36))
        .compositingGroup()
        .shadow(color: .black.opacity(0.14), radius: 10, x: 4)
        .foregroundStyle(.black)
    }
}
struct SettingsSidebarRow: View {
    let title: String
    let symbol: String
    var familyIcon = false
    var elder = false
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            HStack(spacing: 17) {
                Group {
                    if familyIcon { Image("FamilyMembers").resizable().scaledToFit().frame(width: 30, height: 24) }
                    else { Image(systemName: symbol).font(.system(size: elder ? 28 : 24)) }
                }.frame(width: elder ? 34 : 30).accessibilityHidden(true)
                Group {
                    if elder { Text(title).elderText() }
                    else { Text(title).caregiverText() }
                }.fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
            }.foregroundStyle(.black).padding(.vertical, 10)
                .frame(minHeight: elder ? 56 : 52).contentShape(Rectangle())
        }.buttonStyle(.plain).layoutProbe("drawer-row-" + title)
    }
}
