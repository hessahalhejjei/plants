import Combine
import Foundation

@MainActor
final class PlantStore: ObservableObject {
    @Published private(set) var plants: [PlantReminder] = []
    @Published var errorMessage: String?
    @Published private(set) var currentDay: Date

    private let storageURL: URL
    private let now: () -> Date
    private let calendar: Calendar
    private var writeBlocked = false

    init(
        storageURL: URL? = nil,
        now: @escaping () -> Date = Date.init,
        calendar: Calendar = .autoupdatingCurrent
    ) {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        self.storageURL = storageURL ?? support
            .appendingPathComponent("Planto", isDirectory: true)
            .appendingPathComponent("reminders.json")
        self.now = now
        self.calendar = calendar
        self.currentDay = calendar.startOfDay(for: now())
        load()
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
            // The editor changes care details. Keep the live history in case an
            // older draft was opened before the plant was checked or unchecked.
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

    private func load() {
        guard FileManager.default.fileExists(atPath: storageURL.path) else { return }
        do {
            let data = try Data(contentsOf: storageURL)
            let savedPlants = try JSONDecoder().decode([PlantReminder].self, from: data)
            let namesAreValid = savedPlants.allSatisfy {
                let name = $0.name.trimmingCharacters(in: .whitespacesAndNewlines)
                return !name.isEmpty && name.count <= 60
            }
            let idsAreUnique = Set(savedPlants.map(\.id)).count == savedPlants.count
            guard namesAreValid && idsAreUnique else { throw SavedDataError.invalidPlants }
            plants = savedPlants
        } catch {
            // Keep the original bytes recoverable if an interrupted migration or outside edit
            // made the saved file unreadable. Never overwrite the only copy.
            let backup = storageURL.deletingPathExtension()
                .appendingPathExtension("recovery-\(UUID().uuidString).json")
            do {
                try FileManager.default.copyItem(at: storageURL, to: backup)
                errorMessage = "Your saved plants couldn’t be read. A recovery copy of the original file was kept; new reminders can still be saved."
            } catch {
                writeBlocked = true
                errorMessage = "Your saved plants couldn’t be read or backed up. The original file has been preserved. Restore it before making changes."
            }
        }
    }

    private enum SavedDataError: Error {
        case invalidPlants
    }

    private func commit(_ updated: [PlantReminder]) -> Bool {
        guard !writeBlocked else {
            errorMessage = "Changes can’t be saved until the unreadable reminders file has been restored. Your original file is preserved."
            return false
        }
        do {
            try FileManager.default.createDirectory(
                at: storageURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            try encoder.encode(updated).write(to: storageURL, options: .atomic)
            plants = updated
            refreshDay()
            return true
        } catch {
            errorMessage = "Your changes couldn’t be saved. Please try again. Your previous reminders are unchanged."
            return false
        }
    }
}
