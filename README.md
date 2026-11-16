# Planto 🌱

A SwiftUI app for plant-care reminders. Runs on **iOS 17+**. Use **Xcode 26+ on macOS** to build the native Liquid Glass controls; Xcode 15–16 builds use the solid-control fallback. Plant data stays on the device; there are no accounts, API keys, backend services, or external iOS app dependencies.

## Run

1. Double-click `Planto.xcodeproj` in Finder. The Xcode scheme should say **Planto**; **PlantoCore** is the test package.
2. Select the **Planto** scheme and an iPhone simulator running iOS 17 or later.
3. Press **⌘R**. For a physical iPhone, choose your development team under **Signing & Capabilities**.

Tap **Set Plant Reminder** to add the first plant. You can edit its name, room, light, watering interval, and water amount. Check a plant when watered, undo today's completion, or swipe to edit/delete it. Removing the last plant leaves the add button available.

## Code structure

- `Models`: plant data, care choices, and watering dates.
- `ViewModels`: observable data, form drafts, validation, and screen state.
- `Views`: layout, styling, bindings, and user interactions.
- `Services`: local JSON storage and iOS notifications.
- `PlantoApp.swift`: shared models and app lifecycle events.

The screens use the supplied welcome/wink artwork and dark content layout. The **•••** menu opens notification settings and, after completing all reminders, **View my plants** for editing or undo.

The MVVM structure follows the [CakeBakery MVVM example](https://github.com/adatwq/CakeBakery-HelloWorld/tree/MVVM). The [learning guide](docs/LEARNING_GUIDE.md) maps the example and the eight SwiftUI topics to Planto's files.

## Liquid Glass

On iOS 26+, the add, menu, Cancel, and Save controls use native `glassEffect` surfaces. Plant rows, form inputs, artwork, and the black background keep the reference design. Reduce Transparency uses solid controls; Reduce Motion disables progress/list animations.

The glass code requires the iOS 26 SDK and is excluded from older compilers. See Apple's [Liquid Glass guidance](https://developer.apple.com/documentation/swiftui/applying-liquid-glass-to-custom-views) and [materials guidelines](https://developer.apple.com/design/human-interface-guidelines/materials).

## Storage and reminders

Plants and watering history are saved to `Application Support/Planto/reminders.json`. Writes are atomic. An unreadable file is backed up before replacement; a failed save leaves the list unchanged.

A new plant is due immediately. Watering moves its next due day forward by the chosen interval, using local calendar days. Upcoming plants cannot be checked early. The app refreshes dates when opened, brought to the foreground, or left open across midnight.

Notifications require tapping **Enable Reminders** and granting permission. Alerts are scheduled for **9:00 AM in the device's local time zone**. If that time has passed for an overdue plant, its first alert is tomorrow morning. Watering, editing, and deleting update the schedule.

iOS allows 64 pending notifications. Planto schedules the earliest reminders across all plants; reopen it regularly to refill the queue. Focus and system notification settings can affect delivery.

## Tests

On a Mac, press **⌘U** in Xcode or run:

```sh
./scripts/test-ios.sh
```

The script chooses an available iOS 17+ iPhone simulator. Set `SIMULATOR_ID` to select a device. UI tests use separate storage and preferences and do not request notification permission.

The core unit tests also run on Linux or macOS with Swift 5.9+:

```sh
swift test
```

The Linux package uses pinned OpenCombine 0.14.0 to test the same view models. The iOS app uses Apple's Combine. Keep `Package.resolved` so test dependencies remain reproducible.

Latest local validation: **42 unit tests passed on Linux**. The full iOS build, native glass path, animation smoothness, and **six UI tests** still need validation in Xcode 26+. GitHub Actions runs the simulator suite on push; its result should be checked separately.

## Manual checks on a simulator or iPhone

1. Add a plant, change each care field, save, and relaunch to check persistence.
2. Add another plant. Check one for partial progress, then both for **All Done!**. Choose **••• → View my plants** and undo a completion.
3. Water a weekly plant and check that it appears under **Upcoming** the next day.
4. Cancel an edit, confirm a deletion in the editor, and swipe another plant to delete. Check the empty state and add button.
5. Check notification permission, 9:00 AM delivery, and cancellation after editing/deleting on a device.
6. Check large text, VoiceOver, Reduce Motion, Reduce Transparency, keyboard focus, and sheet layout on iPhone and iPad. Compare the glass controls on iOS 26 with the solid fallback on iOS 17–18.
