import XCTest
#if canImport(Combine)
import Combine
#else
import OpenCombine
#endif
@testable import Planto

final class ScreenViewModelTests: XCTestCase {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }
    private func date(_ day: Int) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: 11, day: day, hour: 12))!
    }
    private func preferences() -> UserDefaults {
        let name = "PlantoTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        addTeardownBlock { defaults.removePersistentDomain(forName: name) }
        return defaults
    }

    @MainActor
    func testContentPresentationIsIndependentForEachWindow() async {
        let first = ContentViewModel()
        let second = ContentViewModel()
        let plant = PlantReminder(name: "Fern")
        first.editPlant(plant)
        first.showingNotifications = true
        first.toggleCompletedPlants()
        XCTAssertEqual(first.editor?.plant, plant)
        XCTAssertNil(second.editor)
        XCTAssertFalse(second.showingNotifications)
        XCTAssertFalse(second.showingCompletedPlants)

        let editID = first.editor?.id
        first.addPlant()
        XCTAssertNotNil(first.editor)
        XCTAssertNil(first.editor?.plant)
        XCTAssertNotEqual(first.editor?.id, editID)
        first.editor = nil // Interactive sheet dismissal writes through the binding.
        XCTAssertNil(first.editor)
    }

    @MainActor
    func testCompletionPresentationResetsOnlyWhenWorkRemains() async {
        let model = ContentViewModel()
        model.toggleCompletedPlants()
        model.updateCompletionState(allDone: true)
        XCTAssertTrue(model.showingCompletedPlants)
        model.updateCompletionState(allDone: false)
        XCTAssertFalse(model.showingCompletedPlants)
        model.updateCompletionState(allDone: true)
        XCTAssertFalse(model.showingCompletedPlants)
    }

    @MainActor
    func testCancelingAnAddThenReopeningStartsWithAFreshDraft() async {
        let storage = MemoryStorage()
        let plants = PlantsViewModel(storage: storage, defaults: preferences())
        let screen = ContentViewModel()
        screen.addPlant()
        let canceled = ReminderEditorViewModel(plant: screen.editor?.plant, plants: plants)
        canceled.draft.name = "Unsaved fern"
        canceled.draft.room = .kitchen
        screen.editor = nil
        screen.addPlant()
        let reopened = ReminderEditorViewModel(plant: screen.editor?.plant, plants: plants)
        XCTAssertEqual(reopened.draft.name, "")
        XCTAssertEqual(reopened.draft.room, PlantReminder(name: "").room)
        XCTAssertTrue(plants.plants.isEmpty)
        XCTAssertEqual(storage.writes, 0)
        reopened.draft.name = "Pothos"
        XCTAssertTrue(reopened.save())
        XCTAssertEqual(plants.plants.map(\.name), ["Pothos"])
        XCTAssertEqual(storage.writes, 1)
    }

    @MainActor
    func testPublishedScreenStateNotifiesObservers() async {
        let plants = PlantsViewModel(storage: MemoryStorage(), defaults: preferences())
        let editor = ReminderEditorViewModel(plant: nil, plants: plants)
        let notifications = NotificationSettingsViewModel(service: FakeNotifications())
        var plantChanges = 0
        var editorChanges = 0
        var notificationChanges = 0
        let subscriptions = [
            plants.objectWillChange.sink { plantChanges += 1 },
            editor.objectWillChange.sink { editorChanges += 1 },
            notifications.objectWillChange.sink { notificationChanges += 1 }
        ]
        editor.draft.name = "Fern"
        XCTAssertTrue(editor.save())
        await notifications.enableReminders(currentPlants: { plants.plants })
        XCTAssertGreaterThan(plantChanges, 0)
        XCTAssertGreaterThan(editorChanges, 0)
        XCTAssertGreaterThan(notificationChanges, 0)
        withExtendedLifetime(subscriptions) {}
    }

    @MainActor
    func testListSectionsProgressAndRolloverUseTheInjectedCalendar() async {
        var now = date(9)
        let model = PlantsViewModel(now: { now }, calendar: calendar, storage: MemoryStorage(), defaults: preferences())
        let daily = PlantReminder(name: "Daily", createdAt: now)
        let weekly = PlantReminder(name: "Weekly", frequency: .weekly, createdAt: now)
        let biweekly = PlantReminder(name: "Biweekly", frequency: .biweekly, createdAt: now)
        for plant in [biweekly, weekly, daily] { XCTAssertTrue(model.save(plant)) }
        XCTAssertEqual(model.progressMessage, "Your plants are waiting for a sip 💦")
        XCTAssertTrue(model.toggleCompletion(for: weekly))
        XCTAssertEqual(model.progressMessage, "1 of your plants feel loved today!✨")
        XCTAssertEqual(model.todayPlants.count, 3)
        XCTAssertTrue(model.toggleCompletion(for: biweekly))
        XCTAssertTrue(model.toggleCompletion(for: daily))
        now = date(10)
        model.refreshDay()
        XCTAssertEqual(model.todayPlants.map(\.id), [daily.id])
        XCTAssertEqual(model.upcomingPlants.map(\.id), [weekly.id, biweekly.id])
    }

    @MainActor
    func testWelcomePreferenceSurvivesDeletionAndNewViewModel() async {
        let storage = MemoryStorage()
        let defaults = preferences()
        let model = PlantsViewModel(storage: storage, defaults: defaults)
        XCTAssertFalse(model.hasCreatedPlant)
        let plant = PlantReminder(name: "Fern")
        XCTAssertTrue(model.save(plant))
        XCTAssertTrue(model.delete(plant))
        XCTAssertFalse(model.hasPlants)
        XCTAssertTrue(model.hasCreatedPlant)
        XCTAssertTrue(PlantsViewModel(storage: storage, defaults: defaults).hasCreatedPlant)
    }

    @MainActor
    func testEditorDraftIsIsolatedAndValidatesNamesBeforeSaving() async {
        let storage = MemoryStorage()
        let plants = PlantsViewModel(storage: storage, defaults: preferences())
        let editor = ReminderEditorViewModel(plant: nil, plants: plants)
        XCTAssertFalse(editor.isEditing)
        editor.draft.name = " \n "
        XCTAssertFalse(editor.validName)
        XCTAssertFalse(editor.save())
        editor.draft.name = String(repeating: "🌿", count: 61)
        XCTAssertFalse(editor.save())
        XCTAssertEqual(storage.writes, 0)
        editor.draft.name = "  Fern  "
        editor.draft.room = .kitchen
        XCTAssertTrue(plants.plants.isEmpty)
        XCTAssertTrue(editor.save())
        XCTAssertEqual(plants.plants.first?.name, "Fern")
        XCTAssertEqual(plants.plants.first?.room, .kitchen)
        let edit = ReminderEditorViewModel(plant: plants.plants[0], plants: plants)
        XCTAssertTrue(edit.isEditing)
        edit.draft.name = "Canceled edit"
        XCTAssertEqual(plants.plants[0].name, "Fern")
        XCTAssertTrue(edit.delete())
        XCTAssertTrue(plants.plants.isEmpty)
    }

    @MainActor
    func testFailedEditorSaveAndDeleteKeepStateAndExposeDismissibleError() async {
        let storage = MemoryStorage()
        let plant = PlantReminder(name: "Fern")
        storage.plants = [plant]
        let plants = PlantsViewModel(storage: storage, defaults: preferences())
        let editor = ReminderEditorViewModel(plant: plant, plants: plants)
        storage.shouldFail = true
        editor.draft.name = "Unsaved"
        XCTAssertFalse(editor.save())
        XCTAssertEqual(plants.plants, [plant])
        XCTAssertNotNil(editor.errorMessage)
        editor.errorMessage = nil
        XCTAssertNil(plants.errorMessage)
        XCTAssertFalse(editor.delete())
        XCTAssertEqual(plants.plants, [plant])
    }

    @MainActor
    func testSavingAnOlderEditorCannotRestoreADeletedPlant() async {
        let storage = MemoryStorage()
        let removed = PlantReminder(name: "Fern")
        let retained = PlantReminder(name: "Pothos")
        storage.plants = [removed, retained]
        let plants = PlantsViewModel(storage: storage, defaults: preferences())
        let editor = ReminderEditorViewModel(plant: removed, plants: plants)

        // Another window deletes the plant while this editor is still open.
        XCTAssertTrue(plants.delete(removed))
        let writesAfterDeletion = storage.writes
        editor.draft.name = "Edited fern"

        XCTAssertFalse(editor.save())
        XCTAssertEqual(plants.plants, [retained])
        XCTAssertEqual(storage.plants, [retained])
        XCTAssertEqual(storage.writes, writesAfterDeletion)
        XCTAssertNotNil(editor.errorMessage)
    }

    @MainActor
    func testSuccessfulEditorRetryClearsThePreviousSaveError() async {
        let storage = MemoryStorage()
        let plants = PlantsViewModel(storage: storage, defaults: preferences())
        let editor = ReminderEditorViewModel(plant: nil, plants: plants)
        editor.draft.name = "Fern"

        storage.shouldFail = true
        XCTAssertFalse(editor.save())
        XCTAssertNotNil(editor.errorMessage)
        XCTAssertNotNil(plants.errorMessage)
        XCTAssertTrue(plants.plants.isEmpty)

        storage.shouldFail = false
        XCTAssertTrue(editor.save())
        XCTAssertEqual(plants.plants.map(\.name), ["Fern"])
        XCTAssertEqual(storage.writes, 1)
        XCTAssertNil(editor.errorMessage)
        XCTAssertNil(plants.errorMessage)
    }

    func testRowStatesDescribeDueCompletedTomorrowAndLater() {
        let today = date(9)
        var plant = PlantReminder(name: "Fern", createdAt: today)
        XCTAssertEqual(PlantRowViewModel(plant: plant, day: today, calendar: calendar).wateringStatus, "Due today")
        plant.wateringDates = [today]
        XCTAssertEqual(PlantRowViewModel(plant: plant, day: today, calendar: calendar).wateringStatus, "Watered today")
        plant.createdAt = date(10)
        plant.wateringDates = []
        let tomorrow = PlantRowViewModel(plant: plant, day: today, calendar: calendar)
        XCTAssertFalse(tomorrow.canComplete)
        XCTAssertEqual(tomorrow.wateringStatus, "Water tomorrow")
        plant.createdAt = date(12)
        XCTAssertTrue(PlantRowViewModel(plant: plant, day: today, calendar: calendar).wateringStatus.hasPrefix("Water "))
    }

    @MainActor
    func testNotificationPermissionIsRequestedOnlyByExplicitActionThenSchedulesPlants() async {
        let service = FakeNotifications()
        let model = NotificationSettingsViewModel(service: service)
        await model.refreshAuthorization()
        XCTAssertEqual(service.requests, 0)
        XCTAssertFalse(model.isAuthorized)
        let plants = [PlantReminder(name: "Fern")]
        await model.enableReminders(currentPlants: { plants })
        XCTAssertEqual(service.requests, 1)
        XCTAssertEqual(service.snapshots, [plants])
        XCTAssertTrue(model.isAuthorized)
        XCTAssertFalse(model.requesting)
        XCTAssertTrue(model.statusDescription.contains("Reminders are enabled"))
        service.status = .denied
        service.message = "Permission denied"
        await model.refreshAuthorization()
        XCTAssertFalse(model.isAuthorized)
        XCTAssertEqual(model.message, "Permission denied")
        XCTAssertTrue(model.statusDescription.contains("turned off"))
    }

    @MainActor
    func testPermissionRequestStaysBusyAndRejectsDuplicateTapsWhileSuspended() async {
        let service = FakeNotifications()
        service.suspendRequest = true
        let started = expectation(description: "Permission request started")
        service.onRequest = { started.fulfill() }
        let model = NotificationSettingsViewModel(service: service)
        let request = Task { await model.enableReminders(currentPlants: { [] }) }
        await fulfillment(of: [started], timeout: 2)
        XCTAssertTrue(model.requesting)
        await model.enableReminders(currentPlants: { [] })
        XCTAssertEqual(service.requests, 1)
        service.permissionContinuation?.resume()
        await request.value
        XCTAssertFalse(model.requesting)
        XCTAssertTrue(model.isAuthorized)
        XCTAssertEqual(service.snapshots.count, 1)
    }

    @MainActor
    func testPermissionCompletionSchedulesCurrentPlantsAfterAnEditAndDeletion() async {
        let service = FakeNotifications()
        service.suspendRequest = true
        let started = expectation(description: "Permission request started")
        service.onRequest = { started.fulfill() }
        let storage = MemoryStorage()
        let removed = PlantReminder(name: "Removed fern")
        let retained = PlantReminder(name: "Pothos")
        storage.plants = [removed, retained]
        let plants = PlantsViewModel(storage: storage, defaults: preferences())
        let model = NotificationSettingsViewModel(service: service)
        let request = Task { await model.enableReminders(currentPlants: { plants.plants }) }
        await fulfillment(of: [started], timeout: 2)

        XCTAssertTrue(plants.delete(removed))
        var edited = retained
        edited.name = "Updated pothos"
        edited.frequency = .weekly
        XCTAssertTrue(plants.save(edited))
        await model.sync(plants: plants.plants)
        service.permissionContinuation?.resume()
        await request.value

        XCTAssertEqual(service.snapshots, [[edited], [edited]])
        XCTAssertFalse(model.requesting)
    }

    @MainActor
    func testUITestingNeverRequestsPermissionsOrSchedulesNotifications() async {
        let service = FakeNotifications()
        let model = NotificationSettingsViewModel(service: service, isUITesting: true)
        await model.refreshAuthorization()
        await model.enableReminders(currentPlants: { [] })
        await model.sync(plants: [])
        XCTAssertEqual(service.requests, 0)
        XCTAssertEqual(service.refreshes, 0)
        XCTAssertTrue(service.snapshots.isEmpty)
        XCTAssertFalse(model.canOpenSettings)
    }

    @MainActor
    func testNotificationSyncPublishesServiceErrorsAndClearsThemOnRetry() async {
        let service = FakeNotifications()
        let model = NotificationSettingsViewModel(service: service)
        service.message = "Scheduling failed"
        await model.sync(plants: [])
        XCTAssertEqual(model.message, "Scheduling failed")
        service.message = nil
        await model.sync(plants: [])
        XCTAssertNil(model.message)
        XCTAssertEqual(service.snapshots.count, 2)
    }
}

private final class MemoryStorage: PlantPersistence {
    var plants: [PlantReminder] = []
    var writes = 0
    var shouldFail = false
    func load() -> PlantLoadResult { PlantLoadResult(plants: plants) }
    func save(_ plants: [PlantReminder]) throws {
        if shouldFail { throw CocoaError(.fileWriteUnknown) }
        writes += 1
        self.plants = plants
    }
}

@MainActor
private final class FakeNotifications: NotificationProviding {
    var status: NotificationAuthorization = .notDetermined
    var message: String?
    var suspendRequest = false
    var onRequest: (() -> Void)?
    var permissionContinuation: CheckedContinuation<Void, Never>?
    var requests = 0
    var refreshes = 0
    var snapshots: [[PlantReminder]] = []
    func refreshAuthorization() async { refreshes += 1 }
    func requestAuthorization() async {
        requests += 1
        if suspendRequest {
            await withCheckedContinuation { continuation in
                permissionContinuation = continuation
                onRequest?()
            }
        }
        status = .authorized
    }
    func sync(plants: [PlantReminder]) async { snapshots.append(plants) }
}
