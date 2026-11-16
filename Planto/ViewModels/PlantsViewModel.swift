import Foundation
#if canImport(Combine)
import Combine
#else
import OpenCombine
#endif

@MainActor
final class PlantsViewModel: ObservableObject {
    @Published private(set) var plants: [PlantReminder] = []
    @Published var errorMessage: String?
    @Published private(set) var currentDay: Date
    @Published private(set) var hasCreatedPlant: Bool

    private let storage: PlantPersistence
    private let defaults: UserDefaults
    private let now: () -> Date
    private let calendar: Calendar

    init(
        storageURL: URL? = nil,
        now: @escaping () -> Date = Date.init,
        calendar: Calendar = .autoupdatingCurrent,
        storage: PlantPersistence? = nil,
        defaults: UserDefaults = .standard
    ) {
        self.storage = storage ?? JSONPlantStorage(storageURL: storageURL)
        self.defaults = defaults
        self.hasCreatedPlant = defaults.bool(forKey: "hasCreatedPlant")
        self.now = now
        self.calendar = calendar
        self.currentDay = calendar.startOfDay(for: now())
        let loaded = self.storage.load()
        plants = loaded.plants
        errorMessage = loaded.message
        updatePresentation()
    }

    var dueToday: [PlantReminder] {
        plants.filter { $0.isDue(on: currentDay, calendar: calendar) }
    }

    var completedTodayCount: Int {
        plants.filter { $0.isCompleted(on: currentDay, calendar: calendar) }.count
    }

    var totalTodayCount: Int { dueToday.count + completedTodayCount }
    var allDoneToday: Bool { completedTodayCount > 0 && dueToday.isEmpty }
    var hasPlants: Bool { !plants.isEmpty }

    func refreshDay() {
        currentDay = calendar.startOfDay(for: now())
        updatePresentation()
    }

    @discardableResult
    func save(_ plant: PlantReminder) -> Bool {
        var edited = plant
        edited.name = edited.name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !edited.name.isEmpty else {
            errorMessage = "Give your plant a name before saving."
            return false
        }
        guard edited.name.count <= 60 else {
            errorMessage = "Keep your plant’s name to 60 characters or fewer."
            return false
        }
        var updated = plants
        if let index = updated.firstIndex(where: { $0.id == edited.id }) {
            // Keep watering changes made after this editor draft was opened.
            edited.createdAt = updated[index].createdAt
            edited.wateringDates = updated[index].wateringDates
            updated[index] = edited
        } else {
            updated.append(edited)
        }
        return commit(updated)
    }

    @discardableResult
    func delete(_ plant: PlantReminder) -> Bool {
        commit(plants.filter { $0.id != plant.id })
    }

    @discardableResult
    func toggleCompletion(for plant: PlantReminder) -> Bool {
        refreshDay()
        guard let index = plants.firstIndex(where: { $0.id == plant.id }) else { return false }
        var updated = plants
        if updated[index].isCompleted(on: currentDay, calendar: calendar) {
            updated[index].wateringDates.removeAll {
                calendar.isDate($0, inSameDayAs: currentDay)
            }
        } else {
            // Upcoming plants cannot be accidentally marked as a task due today.
            guard updated[index].isDue(on: currentDay, calendar: calendar) else { return false }
            updated[index].wateringDates.append(now())
        }
        return commit(updated)
    }

    var todayPlants: [PlantReminder] {
        plants.filter { $0.isDue(on: currentDay, calendar: calendar) || $0.isCompleted(on: currentDay, calendar: calendar) }
    }

    var upcomingPlants: [PlantReminder] {
        plants.filter { !$0.isDue(on: currentDay, calendar: calendar) && !$0.isCompleted(on: currentDay, calendar: calendar) }
            .sorted { $0.nextWateringDate(calendar: calendar) < $1.nextWateringDate(calendar: calendar) }
    }

    var progressMessage: String {
        if totalTodayCount == 0 { return "Your plants are all set for today 🌿" }
        if completedTodayCount == 0 { return "Your plants are waiting for a sip 💦" }
        return "\(completedTodayCount) of your plants feel loved today!✨"
    }

    private func updatePresentation() {
        if hasPlants {
            hasCreatedPlant = true
            defaults.set(true, forKey: "hasCreatedPlant")
        }
    }

    private func commit(_ updated: [PlantReminder]) -> Bool {
        do {
            // Save first so a failed write leaves the list unchanged.
            try storage.save(updated)
            plants = updated
            errorMessage = nil
            refreshDay()
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }
}
