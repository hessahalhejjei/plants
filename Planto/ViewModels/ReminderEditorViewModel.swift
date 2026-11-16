import Foundation
#if canImport(Combine)
import Combine
#else
import OpenCombine
#endif

@MainActor
final class ReminderEditorViewModel: ObservableObject {
    // Inputs change this copy. The saved plant changes only after Save succeeds.
    @Published var draft: PlantReminder
    @Published var showingDeleteConfirmation = false
    @Published var errorMessage: String? {
        didSet { plants.errorMessage = errorMessage }
    }
    let isEditing: Bool
    private let plants: PlantsViewModel

    init(plant: PlantReminder?, plants: PlantsViewModel) {
        draft = plant ?? PlantReminder(name: "")
        isEditing = plant != nil
        self.plants = plants
        errorMessage = plants.errorMessage
    }

    var trimmedName: String { draft.name.trimmingCharacters(in: .whitespacesAndNewlines) }
    var validName: Bool { !trimmedName.isEmpty && trimmedName.count <= 60 }

    func save() -> Bool {
        guard validName else { return false }
        // Don't recreate a plant deleted while this editor was open.
        guard !isEditing || plants.plants.contains(where: { $0.id == draft.id }) else {
            errorMessage = "This reminder was deleted. Close the editor to return to your plants."
            return false
        }
        draft.name = trimmedName
        let saved = plants.save(draft)
        errorMessage = plants.errorMessage
        return saved
    }

    func delete() -> Bool {
        let deleted = plants.delete(draft)
        errorMessage = plants.errorMessage
        return deleted
    }
}
