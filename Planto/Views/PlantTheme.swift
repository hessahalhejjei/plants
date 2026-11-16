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
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.weight(.medium))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, minHeight: 44)
            .contentShape(Capsule())
            .modifier(PlantControlSurface(shape: Capsule(), isProminent: true))
            .opacity(isEnabled ? (configuration.isPressed ? 0.8 : 1) : 0.4)
    }
}

struct PlantRoundButton: ButtonStyle {
    var isProminent = false
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.body.weight(.medium))
            .foregroundStyle(.white)
            .frame(width: 44, height: 44)
            .contentShape(Circle())
            .modifier(PlantControlSurface(shape: Circle(), isProminent: isProminent))
            .opacity(isEnabled ? (configuration.isPressed ? 0.8 : 1) : 0.4)
    }
}

// Glass belongs on controls. Form fields, list rows, and backgrounds stay opaque.
private struct PlantControlSurface<ControlShape: Shape>: ViewModifier {
    let shape: ControlShape
    let isProminent: Bool
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    @ViewBuilder
    func body(content: Content) -> some View {
        // Xcode 26 supplies these APIs; older compilers build the solid fallback.
        #if compiler(>=6.2)
        if #available(iOS 26.0, *), !reduceTransparency {
            if isProminent {
                content.glassEffect(.regular.tint(PlantTheme.accent).interactive(), in: shape)
            } else {
                content.glassEffect(.regular.interactive(), in: shape)
            }
        } else {
            solidControl(content)
        }
        #else
        solidControl(content)
        #endif
    }

    private func solidControl(_ content: Content) -> some View {
        content
            .background(
                isProminent ? Color(red: 0.12, green: 0.44, blue: 0.36) : PlantTheme.field,
                in: shape
            )
            .overlay(shape.stroke(Color.white.opacity(0.2), lineWidth: 1))
    }
}
