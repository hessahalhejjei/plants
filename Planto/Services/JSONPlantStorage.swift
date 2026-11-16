import Foundation

struct PlantLoadResult {
    var plants: [PlantReminder] = []
    var message: String?
}

protocol PlantPersistence {
    func load() -> PlantLoadResult
    func save(_ plants: [PlantReminder]) throws
}

final class JSONPlantStorage: PlantPersistence {
    private let storageURL: URL
    private var writeBlocked = false

    init(storageURL: URL? = nil) {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        self.storageURL = storageURL ?? support
            .appendingPathComponent("Planto", isDirectory: true)
            .appendingPathComponent("reminders.json")
    }

    private struct StorageError: LocalizedError {
        let message: String
        var errorDescription: String? { message }
    }

    func load() -> PlantLoadResult {
        var result = PlantLoadResult()
        guard FileManager.default.fileExists(atPath: storageURL.path) else { return result }
        do {
            let data = try Data(contentsOf: storageURL)
            let savedPlants = try JSONDecoder().decode([PlantReminder].self, from: data)
            let namesAreValid = savedPlants.allSatisfy {
                let name = $0.name.trimmingCharacters(in: .whitespacesAndNewlines)
                return !name.isEmpty && name.count <= 60
            }
            let idsAreUnique = Set(savedPlants.map(\.id)).count == savedPlants.count
            guard namesAreValid && idsAreUnique else { throw SavedDataError.invalidPlants }
            result.plants = savedPlants
        } catch {
            // Back up unreadable data before allowing a new file to replace it.
            let backup = storageURL.deletingPathExtension()
                .appendingPathExtension("recovery-\(UUID().uuidString).json")
            do {
                try FileManager.default.copyItem(at: storageURL, to: backup)
                result.message = "Your saved plants couldn’t be read. A recovery copy of the original file was kept; new reminders can still be saved."
            } catch {
                writeBlocked = true
                result.message = "Your saved plants couldn’t be read or backed up. The original file has been preserved. Restore it before making changes."
            }
        }
        return result
    }

    private enum SavedDataError: Error {
        case invalidPlants
    }

    func save(_ updated: [PlantReminder]) throws {
        guard !writeBlocked else {
            throw StorageError(message: "Changes can’t be saved until the unreadable reminders file has been restored. Your original file is preserved.")
        }
        do {
            try FileManager.default.createDirectory(
                at: storageURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            try encoder.encode(updated).write(to: storageURL, options: .atomic)
        } catch {
            throw StorageError(message: "Your changes couldn’t be saved. Please try again. Your previous reminders are unchanged.")
        }
    }
}
