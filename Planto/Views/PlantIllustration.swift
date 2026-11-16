import SwiftUI

struct PlantIllustration: View {
    var isCelebrating = false

    var body: some View {
        ZStack {
            if isCelebrating {
                Circle().fill(Color.white.opacity(0.035))
            }
            Image(isCelebrating ? "PlantWink" : "PlantWelcome")
                .resizable()
                .scaledToFit()
        }
        .accessibilityHidden(true)
    }
}
