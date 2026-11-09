import SwiftUI

enum PlantTheme {
    static let accent = Color(red: 32 / 255, green: 214 / 255, blue: 173 / 255)
    static let background = Color.black
    static let sheet = Color(red: 0.12, green: 0.12, blue: 0.13)
    static let field = Color(red: 0.17, green: 0.17, blue: 0.18)
    static let secondary = Color(red: 0.62, green: 0.62, blue: 0.64)
}

/// Two capsules make a track and a filled portion. SwiftUI animates width changes.
struct PlantProgressStyle: ProgressViewStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        let fraction = min(max(configuration.fractionCompleted ?? 0, 0), 1)

        return GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Capsule().fill(Color.white.opacity(0.15))
                Capsule()
                    .fill(PlantTheme.accent)
                    .frame(width: geometry.size.width * CGFloat(fraction))
            }
        }
        .frame(height: 6)
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.25), value: fraction)
    }
}

struct PlantPrimaryButton: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(
                LinearGradient(
                    colors: [PlantTheme.accent.opacity(0.55), PlantTheme.accent.opacity(0.35)],
                    startPoint: .top,
                    endPoint: .bottom
                ),
                in: Capsule()
            )
            .overlay(Capsule().stroke(PlantTheme.accent.opacity(0.65), lineWidth: 1))
            .opacity(configuration.isPressed ? 0.7 : 1)
    }
}
