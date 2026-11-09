import XCTest
@testable import Planto

final class PlantStoreTests: XCTestCase {
    private var calendar: Calendar {
        var value = Calendar(identifier: .gregorian)
        value.timeZone = TimeZone(secondsFromGMT: 0)!
        return value
    }

    private func date(_ day: Int) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: 11, day: day, hour: 12))!
    }

    private func temporaryFile() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("PlantoTests-\(UUID().uuidString)", isDirectory: true)
            .appendingPathComponent("reminders.json")
    }

    @MainActor
    func testAddEditAndDeletePersistAcrossStoreInstances() async throws {
        let file = temporaryFile()
        defer { try? FileManager.default.removeItem(at: file.deletingLastPathComponent()) }
        let today = date(9)
        let store = PlantStore(storageURL: file, now: { today }, calendar: calendar)
        var plant = PlantReminder(name: "  Monstera  ", createdAt: today)
        XCTAssertTrue(store.save(plant))
        XCTAssertEqual(store.plants.first?.name, "Monstera")
        plant.name = "Monstera deliciosa"
        plant.room = .kitchen
        plant.frequency = .weekly
        XCTAssertTrue(store.save(plant))
        let restored = PlantStore(storageURL: file, now: { today }, calendar: calendar)
        XCTAssertEqual(restored.plants, [plant])
        XCTAssertTrue(restored.delete(plant))
        XCTAssertTrue(PlantStore(storageURL: file).plants.isEmpty)
    }

    @MainActor
    func testCompletingAndUndoingUpdatesProgressAndSavedHistory() async {
        let file = temporaryFile()
        defer { try? FileManager.default.removeItem(at: file.deletingLastPathComponent()) }
        let today = date(9)
        let store = PlantStore(storageURL: file, now: { today }, calendar: calendar)
        let first = PlantReminder(name: "Pothos", createdAt: today)
        let second = PlantReminder(name: "Orchid", createdAt: today)
        XCTAssertTrue(store.save(first))
        XCTAssertTrue(store.save(second))
        XCTAssertEqual(store.totalTodayCount, 2)
        XCTAssertFalse(store.allDoneToday)
        XCTAssertTrue(store.toggleCompletion(for: first))
        XCTAssertEqual(store.completedTodayCount, 1)
        XCTAssertEqual(store.dueToday.map(\.id), [second.id])
        XCTAssertTrue(store.toggleCompletion(for: second))
        XCTAssertTrue(store.allDoneToday)
        XCTAssertEqual(PlantStore(storageURL: file, now: { today }, calendar: calendar).completedTodayCount, 2)
        XCTAssertTrue(store.toggleCompletion(for: first))
        XCTAssertFalse(store.allDoneToday)
        XCTAssertEqual(store.totalTodayCount, 2)
        XCTAssertEqual(store.completedTodayCount, 1)
    }

    @MainActor
    func testDayRolloverResetsDailyProgressAndKeepsUpcomingPlantOutOfDueList() async {
        let file = temporaryFile()
        defer { try? FileManager.default.removeItem(at: file.deletingLastPathComponent()) }
        var now = date(9)
        let store = PlantStore(storageURL: file, now: { now }, calendar: calendar)
        let daily = PlantReminder(name: "Daily", createdAt: now)
        let weekly = PlantReminder(name: "Weekly", frequency: .weekly, createdAt: now)
        XCTAssertTrue(store.save(daily))
        XCTAssertTrue(store.save(weekly))
        XCTAssertTrue(store.toggleCompletion(for: daily))
        XCTAssertTrue(store.toggleCompletion(for: weekly))
        now = date(10)
        store.refreshDay()
        XCTAssertEqual(store.completedTodayCount, 0)
        XCTAssertEqual(store.totalTodayCount, 1)
        XCTAssertEqual(store.dueToday.map(\.id), [daily.id])
        XCTAssertFalse(store.toggleCompletion(for: weekly))
    }

    @MainActor
    func testWhitespaceNameDoesNotCreateReminderOrPersistenceFile() async {
        let file = temporaryFile()
        let store = PlantStore(storageURL: file)
        XCTAssertFalse(store.save(PlantReminder(name: " \n ")))
        XCTAssertTrue(store.plants.isEmpty)
        XCTAssertNotNil(store.errorMessage)
        XCTAssertFalse(FileManager.default.fileExists(atPath: file.path))
    }

    @MainActor
    func testFailedWriteDoesNotClaimChangesWereSaved() async throws {
        let file = temporaryFile()
        let directory = file.deletingLastPathComponent()
        // The parent path is deliberately a file, so creating the storage directory fails.
        try Data("blocked".utf8).write(to: directory)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = PlantStore(storageURL: file)
        XCTAssertFalse(store.save(PlantReminder(name: "Fern")))
        XCTAssertTrue(store.plants.isEmpty)
        XCTAssertNotNil(store.errorMessage)
        XCTAssertEqual(try Data(contentsOf: directory), Data("blocked".utf8))
    }

    @MainActor
    func testCorruptFileIsPreservedBeforeNewRemindersAreSaved() async throws {
        let file = temporaryFile()
        let directory = file.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let original = Data("unreadable reminders".utf8)
        try original.write(to: file)
        let store = PlantStore(storageURL: file)
        XCTAssertTrue(store.plants.isEmpty)
        XCTAssertNotNil(store.errorMessage)
        XCTAssertEqual(try Data(contentsOf: file), original)
        XCTAssertTrue(store.save(PlantReminder(name: "Recovered fern")))
        let files = try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
        let backup = try XCTUnwrap(files.first { $0.lastPathComponent.contains("recovery-") })
        XCTAssertEqual(try Data(contentsOf: backup), original)
        XCTAssertEqual(PlantStore(storageURL: file).plants.count, 1)
    }

    @MainActor
    func testNameLengthBoundaryAllowsSixtyCharactersAndRejectsSixtyOne() async throws {
        let file = temporaryFile()
        defer { try? FileManager.default.removeItem(at: file.deletingLastPathComponent()) }
        let store = PlantStore(storageURL: file)
        var plant = PlantReminder(name: String(repeating: "🌿", count: 60))
        XCTAssertTrue(store.save(plant))
        let originalData = try Data(contentsOf: file)

        plant.name.append("🌿")
        XCTAssertFalse(store.save(plant))
        XCTAssertEqual(store.plants.first?.name.count, 60)
        XCTAssertEqual(try Data(contentsOf: file), originalData)
    }

    @MainActor
    func testStaleCareEditPreservesLiveCompletionAndCreationDate() async throws {
        let file = temporaryFile()
        defer { try? FileManager.default.removeItem(at: file.deletingLastPathComponent()) }
        let today = date(9)
        let store = PlantStore(storageURL: file, now: { today }, calendar: calendar)
        let plant = PlantReminder(name: "Pothos", createdAt: date(8))
        XCTAssertTrue(store.save(plant))
        var olderDraft = plant
        XCTAssertTrue(store.toggleCompletion(for: plant))

        olderDraft.name = "Golden Pothos"
        olderDraft.room = .kitchen
        olderDraft.createdAt = date(1)
        XCTAssertTrue(store.save(olderDraft))
        let edited = try XCTUnwrap(store.plants.first)
        XCTAssertEqual(edited.name, "Golden Pothos")
        XCTAssertEqual(edited.room, .kitchen)
        XCTAssertEqual(edited.createdAt, plant.createdAt)
        XCTAssertEqual(edited.wateringDates, [today])
        XCTAssertTrue(store.allDoneToday)
        XCTAssertEqual(PlantStore(storageURL: file, now: { today }, calendar: calendar).plants, [edited])
    }

    @MainActor
    func testStaleCareEditCannotRestoreAnUndoneCompletion() async {
        let file = temporaryFile()
        defer { try? FileManager.default.removeItem(at: file.deletingLastPathComponent()) }
        let today = date(9)
        let store = PlantStore(storageURL: file, now: { today }, calendar: calendar)
        let plant = PlantReminder(name: "Fern", createdAt: today)
        XCTAssertTrue(store.save(plant))
        XCTAssertTrue(store.toggleCompletion(for: plant))
        var olderDraft = store.plants[0]
        XCTAssertTrue(store.toggleCompletion(for: plant))

        olderDraft.light = .lowLight
        XCTAssertTrue(store.save(olderDraft))
        XCTAssertEqual(store.plants[0].light, .lowLight)
        XCTAssertTrue(store.plants[0].wateringDates.isEmpty)
        XCTAssertEqual(store.dueToday.count, 1)
    }

    @MainActor
    func testFailedEditAndDeletePreserveExistingStateAndSavedBytes() async throws {
        let file = temporaryFile()
        let directory = file.deletingLastPathComponent()
        let preservedDirectory = directory.appendingPathExtension("preserved")
        defer {
            try? FileManager.default.removeItem(at: directory)
            try? FileManager.default.removeItem(at: preservedDirectory)
        }
        let store = PlantStore(storageURL: file)
        let plant = PlantReminder(name: "Monstera")
        XCTAssertTrue(store.save(plant))
        let originalPlants = store.plants
        let originalData = try Data(contentsOf: file)

        // Make the storage location unavailable without relying on file permissions.
        // The saved data remains in a separate directory for byte-for-byte checks.
        try FileManager.default.moveItem(at: directory, to: preservedDirectory)
        try Data("blocked".utf8).write(to: directory)
        let preservedFile = preservedDirectory.appendingPathComponent(file.lastPathComponent)
        var draft = plant
        draft.name = "Unsaved edit"
        XCTAssertFalse(store.save(draft))
        XCTAssertEqual(store.plants, originalPlants)
        XCTAssertEqual(try Data(contentsOf: preservedFile), originalData)
        XCTAssertFalse(store.delete(plant))
        XCTAssertEqual(store.plants, originalPlants)
        XCTAssertEqual(try Data(contentsOf: preservedFile), originalData)

        try FileManager.default.removeItem(at: directory)
        try FileManager.default.moveItem(at: preservedDirectory, to: directory)
        XCTAssertEqual(PlantStore(storageURL: file).plants, originalPlants)
    }

    @MainActor
    func testDuplicateStoredIdentifiersUseRecoveryInsteadOfPublishingInvalidRows() async throws {
        let plant = PlantReminder(name: "Fern")
        try assertInvalidSavedPlantsAreRecovered([plant, plant])
    }

    @MainActor
    func testInvalidStoredNamesUseRecoveryInsteadOfPublishingInvalidRows() async throws {
        try assertInvalidSavedPlantsAreRecovered([PlantReminder(name: " \n ")])
        try assertInvalidSavedPlantsAreRecovered([PlantReminder(name: String(repeating: "a", count: 61))])
    }

    @MainActor
    private func assertInvalidSavedPlantsAreRecovered(_ plants: [PlantReminder]) throws {
        let file = temporaryFile()
        let directory = file.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let original = try JSONEncoder().encode(plants)
        try original.write(to: file)

        let store = PlantStore(storageURL: file)
        XCTAssertTrue(store.plants.isEmpty)
        XCTAssertNotNil(store.errorMessage)
        XCTAssertEqual(try Data(contentsOf: file), original)
        let files = try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
        let backup = try XCTUnwrap(files.first { $0.lastPathComponent.contains("recovery-") })
        XCTAssertEqual(try Data(contentsOf: backup), original)
        XCTAssertTrue(store.save(PlantReminder(name: "New fern")))
    }
}
