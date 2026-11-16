import Foundation
#if canImport(Combine)
import Combine
#else
import OpenCombine
#endif

// Each window owns its sheets and list expansion; plant data is shared separately.
@MainActor
final class ContentViewModel: ObservableObject {
    @Published var editor: ReminderSheet?
    @Published var showingNotifications = false
    @Published var showingCompletedPlants = false

    func addPlant() {
        editor = ReminderSheet(plant: nil)
    }

    func editPlant(_ plant: PlantReminder) {
        editor = ReminderSheet(plant: plant)
    }

    func toggleCompletedPlants() {
        showingCompletedPlants.toggle()
    }

    func updateCompletionState(allDone: Bool) {
        if !allDone { showingCompletedPlants = false }
    }
}

struct ReminderSheet: Identifiable {
    let id = UUID()
    let plant: PlantReminder?
}
