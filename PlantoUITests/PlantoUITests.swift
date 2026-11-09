import XCTest

final class PlantoUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testWelcomeRequiresAValidPlantNameAndCancelDoesNotSave() async {
        let app = launchApp()
        XCTAssertTrue(app.staticTexts["welcome.title"].waitForExistence(timeout: 5))
        app.buttons["welcome.start"].tap()

        let save = app.buttons["reminder.save"]
        XCTAssertTrue(save.waitForExistence(timeout: 5))
        assertEnabled(false, for: save)
        let name = app.textFields["reminder.name"].firstMatch
        name.tap()
        name.typeText("   ")
        assertEnabled(false, for: save)
        replaceName(in: app, with: String(repeating: "A", count: 61))
        assertEnabled(false, for: save)
        XCTAssertTrue(app.staticTexts["Keep your plant’s name to 60 characters or fewer."].exists)

        app.buttons["reminder.cancel"].tap()
        XCTAssertTrue(app.staticTexts["welcome.title"].waitForExistence(timeout: 5))

        app.buttons["notifications.settings"].tap()
        XCTAssertTrue(app.staticTexts["A little nudge to grow"].waitForExistence(timeout: 5))
        let reminderNote = app.staticTexts["Open Planto regularly to keep future reminders up to date."]
        XCTAssertTrue(reminderNote.exists)
        app.buttons["Close notification settings"].tap()
        XCTAssertTrue(app.staticTexts["welcome.title"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testAddPlantPersistsAcrossRelaunch() async {
        let app = launchApp()
        addPlant("Monstera", in: app)
        XCTAssertTrue(editButton("Monstera", in: app).waitForExistence(timeout: 5))

        app.terminate()
        // Relaunch without the reset flag: the isolated test file must be retained.
        app.launchArguments = ["--ui-testing"]
        app.launch()
        XCTAssertTrue(editButton("Monstera", in: app).waitForExistence(timeout: 5))
        editButton("Monstera", in: app).tap()
        XCTAssertEqual(app.textFields["reminder.name"].firstMatch.value as? String, "Monstera")
        XCTAssertEqual(app.buttons["care.Room"].value as? String, "Bedroom")
        XCTAssertEqual(app.buttons["care.Light"].value as? String, "Full Sun")
        XCTAssertEqual(app.buttons["care.Watering Days"].value as? String, "Every day")
        XCTAssertEqual(app.buttons["care.Water"].value as? String, "20–50 ml")
    }

    @MainActor
    func testCareOptionsSaveAndEditCancellationKeepsPreviousDetails() async {
        let app = launchApp()
        app.buttons["welcome.start"].tap()
        choose("Kitchen", for: "Room", in: app)
        choose("Low Light", for: "Light", in: app)
        choose("Once a week", for: "Watering Days", in: app)
        choose("100–200 ml", for: "Water", in: app)
        replaceName(in: app, with: "Orchid")
        app.buttons["reminder.save"].tap()
        XCTAssertTrue(editButton("Orchid", in: app).waitForExistence(timeout: 5))

        editButton("Orchid", in: app).tap()
        XCTAssertEqual(app.buttons["care.Room"].value as? String, "Kitchen")
        XCTAssertEqual(app.buttons["care.Light"].value as? String, "Low Light")
        XCTAssertEqual(app.buttons["care.Watering Days"].value as? String, "Once a week")
        XCTAssertEqual(app.buttons["care.Water"].value as? String, "100–200 ml")
        replaceName(in: app, with: "Unsaved name")
        app.buttons["reminder.cancel"].tap()
        XCTAssertTrue(editButton("Orchid", in: app).waitForExistence(timeout: 5))
        XCTAssertFalse(editButton("Unsaved name", in: app).exists)

        editButton("Orchid", in: app).tap()
        replaceName(in: app, with: "Orchid updated")
        app.buttons["reminder.save"].tap()
        XCTAssertTrue(editButton("Orchid updated", in: app).waitForExistence(timeout: 5))
        XCTAssertFalse(editButton("Orchid", in: app).exists)
    }

    @MainActor
    func testCompletionProgressAllDoneAndUndo() async {
        let app = launchApp()
        addPlant("Pothos", in: app)
        addPlant("Spider", in: app)
        app.buttons["plant.toggle.Pothos"].tap()
        XCTAssertTrue(app.staticTexts["1 of 2 plants feel loved today ✨"].waitForExistence(timeout: 5))
        app.buttons["plant.toggle.Spider"].tap()
        XCTAssertTrue(app.staticTexts["reminders.allDone"].waitForExistence(timeout: 5))

        app.buttons["reminders.showPlants"].tap()
        let completed = app.buttons["plant.toggle.Pothos"]
        if !completed.isHittable { app.swipeUp() }
        XCTAssertTrue(completed.waitForExistence(timeout: 5))
        XCTAssertEqual(completed.value as? String, "Watered today")
        completed.tap()
        XCTAssertFalse(app.staticTexts["reminders.allDone"].exists)
        XCTAssertTrue(app.staticTexts["1 of 2 plants feel loved today ✨"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.buttons["plant.toggle.Pothos"].value as? String, "Due today")
    }

    @MainActor
    func testDeleteConfirmationAndEmptyStateCanAddAgain() async {
        let app = launchApp()
        addPlant("Fern", in: app)
        editButton("Fern", in: app).tap()
        app.buttons["reminder.delete"].tap()
        // Restrict the query to the native dialog, away from the editor's button.
        let title = "Delete Fern?"
        let dialogs = [
            app.sheets.containing(.staticText, identifier: title).firstMatch,
            app.alerts.containing(.staticText, identifier: title).firstMatch,
            app.popovers.containing(.staticText, identifier: title).firstMatch
        ]
        guard let dialog = dialogs.first(where: { $0.waitForExistence(timeout: 2) }) else {
            XCTFail("The delete confirmation dialog did not appear.")
            return
        }
        let confirmation = dialog.buttons["Delete Reminder"].firstMatch
        XCTAssertTrue(confirmation.waitForExistence(timeout: 5))
        confirmation.tap()
        XCTAssertTrue(app.staticTexts["reminders.empty"].waitForExistence(timeout: 5))

        addPlant("New Fern", in: app)
        XCTAssertTrue(editButton("New Fern", in: app).waitForExistence(timeout: 5))
    }

    @MainActor
    func testSwipeDeleteRemovesOnlySelectedPlant() async {
        let app = launchApp()
        addPlant("Monstera", in: app)
        addPlant("Pothos", in: app)
        editButton("Monstera", in: app).swipeLeft()
        let delete = app.buttons["Delete"].firstMatch
        XCTAssertTrue(delete.waitForExistence(timeout: 5))
        delete.tap()
        XCTAssertTrue(editButton("Pothos", in: app).waitForExistence(timeout: 5))
        XCTAssertFalse(editButton("Monstera", in: app).exists)
    }

    @MainActor
    private func launchApp() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing", "--reset-ui-test-data"]
        app.launch()
        XCTAssertTrue(app.staticTexts["welcome.title"].waitForExistence(timeout: 5))
        return app
    }

    @MainActor
    private func addPlant(_ name: String, in app: XCUIApplication) {
        let start = app.buttons["welcome.start"]
        if start.exists {
            start.tap()
        } else {
            app.buttons["reminders.add"].tap()
        }
        replaceName(in: app, with: name)
        app.buttons["reminder.save"].tap()
        XCTAssertTrue(editButton(name, in: app).waitForExistence(timeout: 5))
    }

    @MainActor
    private func replaceName(in app: XCUIApplication, with name: String) {
        let field = app.textFields["reminder.name"].firstMatch
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        let previous = field.value as? String ?? ""
        // Tapping in the middle can leave the cursor before the end of an old name.
        field.coordinate(withNormalizedOffset: CGVector(dx: 0.98, dy: 0.5)).tap()
        if !previous.isEmpty {
            // An empty field may report its placeholder; extra deletes are harmless.
            field.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: previous.count))
        }
        field.typeText(name)
        let entered = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "value == %@", name), object: field
        )
        XCTAssertEqual(XCTWaiter.wait(for: [entered], timeout: 5), .completed,
                       "The name field must contain the requested text before testing the form.")
    }

    @MainActor
    private func assertEnabled(_ enabled: Bool, for element: XCUIElement) {
        let updated = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "enabled == %@", NSNumber(value: enabled)),
            object: element
        )
        XCTAssertEqual(XCTWaiter.wait(for: [updated], timeout: 5), .completed)
        XCTAssertEqual(element.isEnabled, enabled)
    }

    @MainActor
    private func choose(_ option: String, for field: String, in app: XCUIApplication) {
        app.buttons["care.\(field)"].tap()
        let choice = app.buttons[option].firstMatch
        // Some iOS versions expose a Picker as a submenu inside its Menu.
        if !choice.waitForExistence(timeout: 2) {
            let submenu = app.buttons.matching(identifier: field).firstMatch
            XCTAssertTrue(submenu.waitForExistence(timeout: 3))
            submenu.tap()
        }
        XCTAssertTrue(choice.waitForExistence(timeout: 5))
        choice.tap()
        XCTAssertEqual(app.buttons["care.\(field)"].value as? String, option)
    }

    @MainActor
    private func editButton(_ name: String, in app: XCUIApplication) -> XCUIElement {
        app.buttons["plant.edit.\(name)"]
    }
}
