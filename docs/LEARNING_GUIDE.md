# Learning SwiftUI and MVVM with Planto

MVVM separates plant data (**Model**), screen layout (**View**), and state/actions (**ViewModel**). File storage and iOS notifications live in services.

## Comparing the reference

Use CakeBakery's [`MVVM` branch](https://github.com/adatwq/CakeBakery-HelloWorld/tree/9da956d0c9479489781fb7eb7a5ed634507a547b). Its `main` branch is the earlier version that keeps state in the view.

The example has four Swift files: `Cake.swift`, `CakeViewModel.swift`, `ContentView.swift`, and the app entry point. `Cake` is an `Identifiable` struct. `CakeViewModel` publishes form fields, the cake array, and the sheet flag. The view owns it with `@StateObject`, binds inputs, and calls `addCake()` to save.

| In CakeBakery | In Planto |
| --- | --- |
| `Cake` | `PlantReminder`: care details, identity, and watering history. |
| Published `cakes` array | `PlantsViewModel.plants`: shared saved plants. |
| Published form fields | `ReminderEditorViewModel.draft`: an editable copy of a plant. |
| `showAddCakeSheet` | `ContentViewModel.editor`: the current add/edit sheet. |
| `addCake()` | Editor `save()` calls `PlantsViewModel.save(_:)`. |
| View-owned `@StateObject` | Each content view owns its screen model; each editor owns its draft model. |

Planto uses separate models because it also supports persistence, editing, watering history, and notification permissions. `PlantsViewModel` is shared by the app. `ContentViewModel` belongs to one window, so opening a sheet does not open it in other windows. The menu also exposes completed plants without adding a permanent button to the All Done screen.

## Files to read

Start with `PlantReminder`, `PlantsViewModel`, and `ReminderEditor`. They show the data, actions, and form inputs. Storage, notifications, and glass styling are separate so you can learn them later without changing how the main flow works.

1. **`Models/PlantReminder.swift`** — the plant struct, care enums, and due/completed checks. `WateringSchedule.swift` calculates future alert dates without calling iOS APIs.
2. **`ViewModels/PlantsViewModel.swift`** — saved plants, today's progress, list sections, and save/delete/water actions. It writes to storage before publishing changes.
3. **`ViewModels/ContentViewModel.swift`** and **`Views/ContentView.swift`** — published sheet/list state and the screen that binds to it.
4. **`ViewModels/ReminderEditorViewModel.swift`** and **`Views/ReminderEditor.swift`** — draft inputs and name validation. Layout, keyboard focus, and dismissal stay in the view.
5. **`Services/JSONPlantStorage.swift`** — atomic JSON writes and recovery copies for unreadable files. `PlantPersistence` lets tests substitute in-memory storage.
6. **`ViewModels/NotificationSettingsViewModel.swift`** and **`Services/NotificationService.swift`** — permission state and iOS scheduling. Tests use `NotificationProviding` instead of asking for real permissions.
7. **`PlantoApp.swift`** — creates shared models and refreshes dates/notifications on launch, plant changes, foreground entry, and time changes.

## The eight SwiftUI topics

| Topic | Code to look at |
| --- | --- |
| `VStack`, `HStack`, `ZStack` | Screen layout in `ContentView` and `ReminderEditor`; layered progress in `PlantTheme`. |
| Custom navigation bar and sheet | `ContentView.sheet(item:)` and `ReminderEditor.navigationBar`. |
| `TextField`, `Picker`, custom input rows | `ReminderEditor.nameField` and `pickerRow`. |
| `List` and `ScrollView` | `ContentView.reminderList`, the welcome screen, and the editor. |
| Custom animated `ProgressView` | `PlantTheme.swift` → `PlantProgressStyle`; respects Reduce Motion. |
| Check/uncheck and swipe to delete | `ContentView.row` → `PlantsViewModel.toggleCompletion` / `delete`. |
| Local notifications | `NotificationSettingsViewModel`, `NotificationService`, and `WateringSchedule`. |
| Theming and dark mode | `PlantTheme` for shared styles; `PlantoApp` for the root appearance; native glass is limited to action/navigation controls. |

`PlantIllustration` displays the supplied `PlantWelcome` or `PlantWink` artwork from the asset catalog. The originals are vector PDFs, so they stay sharp as the screen scales. It needs no view model because it has no plant data or save actions.

## Understanding the bindings

- `ObservableObject` and `@Published` let SwiftUI observe model changes.
- `@StateObject` keeps a view-owned model alive when SwiftUI redraws the view.
- `@EnvironmentObject` reads the shared models created by `PlantoApp`.
- `$model.draft.room` binds a picker to the editor's draft. `$viewModel.editor` lets sheet dismissal clear the selected sheet.
- `AnyLayout` changes the name field's layout for large text without replacing the field, so typing keeps its place.
- `@MainActor` keeps mutable screen state on the main actor. Notification calls use `async`/`await` so waiting for permission does not block the screen.

## Follow the actions

**Add and save:** `ContentViewModel.addPlant()` selects a new sheet. The editor creates a draft; inputs change that copy. Save trims and validates the name, writes through `PlantsViewModel`, and dismisses only on success. A failed write keeps the editor open and shows an error; a successful retry clears it. If another window deleted the plant, saving the old editor shows an error instead of bringing the plant back.

**Cancel:** closing the editor discards its draft. Existing plants stay unchanged, and opening Add again starts with a fresh draft.

**Water and undo:** `toggleCompletion` records today's watering date or removes today's completion. After storage succeeds, progress and list sections recalculate. An older care-edit draft keeps any watering changes made since it was opened.

**Enable reminders:** open **••• → Notification settings**. Permission is requested only after the button is tapped. When it returns, the model reads the current plants before scheduling, including edits or deletions made while the prompt was open. The service applies the newest schedule last if changes arrive during scheduling.

## Tests to learn from

`PlantReminderTests` checks watering intervals and daylight-saving changes. `PlantsViewModelTests` checks persistence, recovery, failed writes, history, and rollover. `ScreenViewModelTests` checks drafts, validation, window isolation, list state, and notification permissions using small test substitutes. `NotificationScheduleTests` checks the alert dates and 64-slot queue.

Run `swift test` for those unit tests. The six tests in `PlantoUITests` exercise complete screen flows and need Xcode: run `./scripts/test-ios.sh` on a Mac. Use the device checklist below to check notification delivery and accessibility.

## Running and checking the app

Open `Planto.xcodeproj` in Xcode, select the **Planto** scheme and an iPhone simulator, then press **⌘R**. Opening `Package.swift` opens the core test package instead of the app. For a physical iPhone, select your development team under **Signing & Capabilities**.

The app runs on iOS 17+. Xcode 26+ and iOS 26+ enable native Liquid Glass controls. Older Xcode versions build the solid-control fallback. Glass stays on action/navigation controls; Reduce Transparency uses solid controls and Reduce Motion disables progress/list animations.

Press **⌘U** or run `./scripts/test-ios.sh` on a Mac for app unit and UI tests. The script chooses an available iPhone simulator; `SIMULATOR_ID` can select a particular device. Run `swift test` with Swift 5.9+ for the portable core tests. Linux uses pinned OpenCombine 0.14.0; the iOS app uses Apple's Combine.

Latest local checks: **42 core unit tests passed on Linux**. The full iOS build, native glass rendering, smoothness, and six UI tests still need Xcode validation. GitHub Actions runs the simulator suite on push; its result needs checking separately.

## Storage and notification details

Plants are saved to `Application Support/Planto/reminders.json` with atomic writes. Unreadable files are backed up before replacement; a failed save leaves the current list unchanged.

New plants are due immediately. Watering advances the next due day using local calendar days; upcoming plants cannot be checked early. The app refreshes dates on launch, foreground entry, and time changes.

Notifications require explicit permission through **••• → Notification settings → Enable Reminders**. Alerts are scheduled at 9:00 AM in the device's local time zone. If that time has passed for an overdue plant, its first alert is tomorrow. Watering, editing, and deleting refresh the schedule.

iOS allows 64 pending notifications. Reopen Planto regularly to refill the queue. Focus and system settings can affect delivery.

## Device checklist

1. Add a plant, change each care field, save, and relaunch to check persistence.
2. Add another plant. Check one for partial progress, then both for **All Done!**. Choose **••• → View my plants** and undo a completion.
3. Water a weekly plant and check that it appears under **Upcoming** the next day.
4. Cancel an edit, confirm a deletion in the editor, and swipe another plant to delete. Check the empty state and add button.
5. Check notification permission, 9:00 AM delivery, and cancellation after editing/deleting on a device.
6. Check large text, VoiceOver, Reduce Motion, Reduce Transparency, keyboard focus, and sheet layout on iPhone and iPad. Compare the glass controls on iOS 26 with the solid fallback on iOS 17–18.
