import SwiftUI

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
