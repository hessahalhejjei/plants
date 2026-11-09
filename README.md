# Planto 🌱

A native SwiftUI plant-care reminder app, built from the supplied designs. Requires **iOS 17+** and **Xcode 15+ on macOS**. There are no external app dependencies, accounts, API keys, or backend services.

## Run

1. Open `Planto.xcodeproj` in Xcode.
2. Select the **Planto** scheme and an iPhone simulator running iOS 17 or later.
3. Press **⌘R**. To run on your own iPhone, choose your development team under **Signing & Capabilities** and use your own bundle identifier if needed.

The app starts with the welcome screen and an empty collection. Tap **Set Plant Reminder** to add your first plant.

## Features

- Add and edit a plant’s name, room, light level, watering interval, and water amount.
- Mark a due plant as watered, undo today’s completion, and track animated daily progress.
- See an **All Done!** state when all due plants are watered. **View my plants** keeps completed and upcoming reminders accessible.
- Tap a plant’s details to edit, or swipe for edit/delete actions. Deleting from the editor asks for confirmation.
- Keep plants and watering history across launches using an atomic local JSON file in `Application Support/Planto/reminders.json`.
- Enable local notifications from the bell button. Permission is requested only after tapping **Enable Reminders**.
- Dark styling, scalable vector artwork, Dynamic Type, VoiceOver labels, and Reduce Motion support.

All care options from the references are included: five rooms, three light levels, six watering intervals, and four water amounts.

## Care dates and notifications

A new plant is due immediately. Watering advances its next due day by the selected interval using local calendar days, including daylight-saving changes. Undo removes only today’s completion. Upcoming plants remain editable and cannot be accidentally checked early. The app refreshes progress on foreground entry and at day rollover while open.

Notifications arrive at **9:00 AM in the device’s local time zone**. If a plant is already overdue and today’s 9:00 AM has passed, its first alert is tomorrow morning. Completing, editing, or deleting a reminder refreshes its pending notifications.

iOS limits an app to 64 pending local notifications. Planto fills a rolling queue with the earliest upcoming occurrences across all plants and refreshes it on launch, foreground entry, and changes. Open the app periodically to replenish the queue; alerts do not continue indefinitely without reopening. Notification presentation also depends on iOS permission, Focus, and system settings. No remote push service is used.

Plant data stays on the device. No analytics or network requests are made by the app. If a saved file cannot be decoded, Planto preserves a recovery copy before allowing a replacement; a failed save leaves the previous in-memory state unchanged and displays an error.

## Tests

In Xcode, press **⌘U**, or run this from the repository directory on a Mac:

```sh
./scripts/test-ios.sh
```

The script chooses an installed iOS 17+ iPhone simulator. Set `SIMULATOR_ID` to a simulator UUID to select a specific device. The shared scheme includes **26 unit tests and 6 UI tests**. Unit tests cover persistence, completion/undo, stale edit history, daily rollover, name boundaries, failed writes, invalid-file recovery, watering intervals, daylight-saving changes, and notification ordering/limits. UI tests cover the main add/edit/cancel/check/undo/delete flows and use separate storage/preferences. They never clear your normal plant data or request system notification permission.

The Foundation-only date and notification-planning tests also run without an iOS simulator using Swift 5.9+:

```sh
swift test
```

This runs 14 of the unit tests. Store and UI tests require the iOS app target in Xcode. A GitHub Actions workflow runs the full simulator test command on macOS after code is pushed; that workflow has not been run from this workspace.

Manual acceptance checks on a simulator or device:

1. Add a plant, change every care field, save, and relaunch to verify persistence.
2. Add a second plant. Check one to see partial progress; check both to see **All Done!**. View the plants and undo a completion.
3. Water a weekly plant and verify it appears under **Upcoming** the next day.
4. Edit a plant and delete it from the sheet; swipe another row to delete it. Verify the empty state and add button.
5. Enable notifications using the bell, check the permission state, then verify a due reminder at 9:00 AM on a device. Edit/delete it before delivery to verify cancellation.
6. Check a large Dynamic Type size, VoiceOver, and Reduce Motion in iOS accessibility settings.

## Validation in this workspace

The authoring environment is Linux and does not include Xcode, Apple SDKs, or an iOS simulator. A signature-verified Swift 6.0.3 toolchain was used to build and execute the Foundation-only suite: **14 tests passed, 0 failed**. The remaining 12 store tests and 6 UI tests have not run here. Swift syntax, the Xcode project, source/resource membership, shared scheme, asset catalogs, privacy manifest, and test script are checked separately. **The full iOS build and visual/device checks still need Xcode.** Run the checks above before treating the app as release-ready.

Future cloud tasks should use the existing checkout directly; no additional Git worktree is needed. Native builds and simulator validation require a Mac.

For a beginner-friendly map of the eight learning topics in your reference, read [the learning guide](docs/LEARNING_GUIDE.md). The audit and remaining device checks are recorded in [the coverage review](docs/COVERAGE_REVIEW.md).
