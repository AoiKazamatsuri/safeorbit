import SwiftUI

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
    func caregiverCard(radius: CGFloat = 25, opacity: Double = 0.14) -> some View {
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
