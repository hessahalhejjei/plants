# Learn SwiftUI by reading Planto

The app uses SwiftUI’s built-in views and state tools. There are no third-party app libraries. Start with the screens, then read how the saved data and notifications support them.

## The eight topics from your design

| Topic | Where to look | What it does here |
| --- | --- | --- |
| `VStack`, `HStack`, `ZStack` | `ContentView`, `ReminderEditor`, `PlantProgressStyle` | Arrange text vertically, put controls side by side, and layer the progress fill over its track. |
| Custom navigation bar and sheet | `ContentView`’s `.sheet(item:)` and `ReminderEditor.navigationBar` | Open a form from the list and give it cancel, title, and save controls. |
| `TextField`, `Picker`, custom input rows | `ReminderEditor.nameField` and `pickerRow` | Bind the plant name and care options to an editable draft. The native pickers live inside menus. |
| `List` and `ScrollView` | `ContentView.reminderList`, `welcome`, and the editor | Render reminder rows and let longer content scroll on small screens or with large text. |
| Custom animated `ProgressView` | `PlantTheme.swift` → `PlantProgressStyle` | Use two capsules for the track and fill. Animate the filled width when the completion fraction changes. Respect Reduce Motion. |
| Check/uncheck and swipe to delete | `PlantReminderRow`, `ContentView.row`, `PlantStore.toggleCompletion` | Button actions change saved state; `.swipeActions` exposes edit and delete. |
| Local notifications | `NotificationSettingsView`, `NotificationManager`, `WateringSchedule` | Ask permission after a user action, calculate future dates, and schedule/cancel local alerts. |
| Theming and dark mode | `PlantTheme` and `PlantoApp` | Keep colors and button styling together. Apply `.preferredColorScheme(.dark)` once at the root to match the supplied design. |

## A useful reading order

1. **`PlantReminder.swift`**: a `struct` holds one plant. The four enums define the exact allowed care options. `Identifiable` gives `ForEach` a stable ID; `Codable` lets the app save and load JSON.
2. **`ContentView.swift`**: follow the `if` statements in `body`. They choose welcome, empty, reminder list, or all-done content.
3. **`ReminderEditor.swift`**: follow the draft from its initial value through each input and into the Save action.
4. **`PlantTheme.swift`**: see how a small `ButtonStyle` and `ProgressViewStyle` keep the screens consistent.
5. **`PlantStore.swift`**: read `save`, `delete`, and `toggleCompletion` before the file-loading/error-handling code.
6. **`WateringSchedule.swift`**, then **`NotificationManager.swift`**: read the date rules separately from iOS permission and delivery APIs.

`PlantIllustration.swift` is optional artwork code using `Canvas` and paths. You can learn the screen-building topics without studying how the illustration is drawn. The UI-test launch settings at the bottom of `PlantoApp.swift` only isolate automated test data.

## The state tools, simply

- **`@State`** holds a view’s temporary state, such as which sheet is open or the form’s draft.
- **`@Binding`** lets an input change a value owned somewhere else. `$draft.room` binds the room picker to the draft’s room.
- **`@StateObject`** creates one shared store/notification manager for the app’s lifetime.
- **`@EnvironmentObject`** lets child views use those shared objects without passing them through every view initializer.
- **`@Published`** tells SwiftUI when store data changed so the screen can redraw.
- **`@AppStorage`** remembers a small preference: whether the user has created a plant before.
- **`@Environment`** reads system values such as dismiss, scene activity, and Reduce Motion.
- **`@MainActor`** keeps UI-related state changes on the main actor. `async`/`await` lets iOS notification requests finish without blocking the screen.

## Follow one complete action

**Adding a plant:** tap **Set Plant Reminder** → set `editor` → SwiftUI presents the sheet → inputs change `draft` → Save trims and validates the name → `store.save(draft)` writes JSON → published plants change → the list redraws → notification dates refresh.

**Watering a plant:** tap its circle → `toggleCompletion` records today’s date → progress increases → the next due date advances by its watering interval → pending notifications refresh. Tap again to remove today’s completion. The same stored day is used for the row checks and daily progress.

**Canceling:** the form edits a local draft, so dismissing it does not change saved plants. Saving care details preserves the current watering history, even if the draft was opened earlier.

## How to practice

Use Xcode previews or a simulator and make one small change at a time: adjust the header spacing, restyle the capsules, or change a picker row’s icon. Then run **⌘U**. The tests show small examples of checking date rules, persistence, and complete user flows.

The Foundation-only model/date tests can also run with `swift test` using Swift 5.9 or later. Building the screens and running the full app tests require Xcode and an iOS simulator.
