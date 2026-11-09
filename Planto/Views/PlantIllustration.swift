import SwiftUI

/// A vector illustration that stays crisp at every text and display size.
struct PlantIllustration: View {
    var isCelebrating = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var appeared = false

    var body: some View {
        ZStack {
            Circle()
                .fill(Color.white.opacity(0.035))
                .frame(width: 184, height: 184)
                .offset(y: 13)

            Canvas { context, size in
                let scale = min(size.width, size.height) / 240
                context.scaleBy(x: scale, y: scale)

                // The outer leaves fan out behind the upright new growth.
                leaf(in: &context, base: CGPoint(x: 111, y: 139), tip: CGPoint(x: 44, y: 52), bend: -32,
                     color: Color(red: 0.04, green: 0.62, blue: 0.42))
                leaf(in: &context, base: CGPoint(x: 121, y: 143), tip: CGPoint(x: 200, y: 44), bend: 35,
                     color: Color(red: 0.04, green: 0.66, blue: 0.45))
                leaf(in: &context, base: CGPoint(x: 110, y: 143), tip: CGPoint(x: 83, y: 20), bend: -35,
                     color: Color(red: 0.06, green: 0.82, blue: 0.57))
                leaf(in: &context, base: CGPoint(x: 128, y: 145), tip: CGPoint(x: 162, y: 22), bend: 29,
                     color: Color(red: 0.10, green: 0.86, blue: 0.61))
                leaf(in: &context, base: CGPoint(x: 117, y: 145), tip: CGPoint(x: 115, y: 34), bend: -19,
                     color: Color(red: 0.35, green: 0.94, blue: 0.70))
                leaf(in: &context, base: CGPoint(x: 128, y: 147), tip: CGPoint(x: 181, y: 71), bend: 18,
                     color: Color(red: 0.24, green: 0.91, blue: 0.64))
                leaf(in: &context, base: CGPoint(x: 112, y: 148), tip: CGPoint(x: 59, y: 85), bend: -11,
                     color: Color(red: 0.16, green: 0.88, blue: 0.61))

                var pot = Path()
                pot.move(to: CGPoint(x: 68, y: 140))
                pot.addLine(to: CGPoint(x: 172, y: 140))
                pot.addLine(to: CGPoint(x: 164, y: 191))
                pot.addQuadCurve(to: CGPoint(x: 145, y: 210), control: CGPoint(x: 162, y: 210))
                pot.addQuadCurve(to: CGPoint(x: 95, y: 210), control: CGPoint(x: 120, y: 217))
                pot.addQuadCurve(to: CGPoint(x: 76, y: 191), control: CGPoint(x: 77, y: 208))
                pot.closeSubpath()
                context.fill(pot, with: .linearGradient(
                    Gradient(colors: [Color(red: 1, green: 0.65, blue: 0.49), Color(red: 0.96, green: 0.48, blue: 0.36)]),
                    startPoint: CGPoint(x: 80, y: 140), endPoint: CGPoint(x: 160, y: 215)))

                let rim = Path(roundedRect: CGRect(x: 61, y: 131, width: 118, height: 28), cornerRadius: 11)
                context.fill(rim, with: .color(Color(red: 1, green: 0.72, blue: 0.56)))
                for x in stride(from: 72, through: 170, by: 14) {
                    var rib = Path()
                    rib.move(to: CGPoint(x: CGFloat(x), y: 136))
                    rib.addLine(to: CGPoint(x: CGFloat(x - 1), y: 152))
                    context.stroke(rib, with: .color(.white.opacity(0.35)), style: StrokeStyle(lineWidth: 2, lineCap: .round))
                }

                let ink = Color(red: 0.24, green: 0.12, blue: 0.10)
                context.fill(Path(ellipseIn: CGRect(x: 93, y: 174, width: 9, height: 12)), with: .color(ink))
                context.fill(Path(ellipseIn: CGRect(x: 95, y: 175, width: 3, height: 3)), with: .color(.white))
                if isCelebrating {
                    var wink = Path()
                    wink.move(to: CGPoint(x: 140, y: 174))
                    wink.addLine(to: CGPoint(x: 132, y: 179))
                    wink.addLine(to: CGPoint(x: 140, y: 182))
                    context.stroke(wink, with: .color(ink), style: StrokeStyle(lineWidth: 2.7, lineCap: .round, lineJoin: .round))
                } else {
                    context.fill(Path(ellipseIn: CGRect(x: 134, y: 174, width: 9, height: 12)), with: .color(ink))
                    context.fill(Path(ellipseIn: CGRect(x: 136, y: 175, width: 3, height: 3)), with: .color(.white))
                }
                var smile = Path()
                smile.move(to: CGPoint(x: 111, y: 185))
                smile.addQuadCurve(to: CGPoint(x: 126, y: 185), control: CGPoint(x: 118, y: 195))
                context.stroke(smile, with: .color(ink), style: StrokeStyle(lineWidth: 2.4, lineCap: .round))
                for x in [87.0, 147.0] {
                    context.fill(Path(ellipseIn: CGRect(x: x, y: 185, width: 10, height: 5)), with: .color(Color(red: 0.95, green: 0.36, blue: 0.29).opacity(0.65)))
                }
            }
            .frame(width: 220, height: 220)
            .rotationEffect(.degrees(appeared && !reduceMotion ? -2 : 0), anchor: .bottom)
        }
        .frame(width: 240, height: 240)
        .accessibilityHidden(true)
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 2.5).repeatForever(autoreverses: true)) { appeared = true }
        }
    }

    private func leaf(in context: inout GraphicsContext, base: CGPoint, tip: CGPoint, bend: CGFloat, color: Color) {
        let midY = (base.y + tip.y) / 2
        var shape = Path()
        shape.move(to: base)
        shape.addQuadCurve(to: tip, control: CGPoint(x: tip.x + bend, y: midY))
        shape.addQuadCurve(to: base, control: CGPoint(x: base.x + bend * 0.35 + 13, y: midY + 4))
        context.fill(shape, with: .color(color))
        var vein = Path()
        vein.move(to: base)
        vein.addQuadCurve(to: tip, control: CGPoint(x: tip.x + bend * 0.25, y: midY + 10))
        context.stroke(vein, with: .color(.white.opacity(0.25)), style: StrokeStyle(lineWidth: 1.5, lineCap: .round))
    }
}
