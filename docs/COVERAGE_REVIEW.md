# Reference coverage review

Reviewed against the supplied screens, option lists, six user stories, and eight learning topics.

## User stories and screens

| Requirement | Implementation | Check |
| --- | --- | --- |
| Add reminders with care details | Welcome/add button opens the editor; name, room, light, interval, and amount are saved. | Store tests and UI creation/options tests. |
| Update plant information | Tap a row or use swipe Edit; Save persists a local draft; Cancel leaves it unchanged. | Store edit/stale-history tests and UI edit/cancel test. |
| Delete a reminder | Swipe Delete or confirmed deletion in the editor; remaining plants stay present. | Store deletion tests and two UI deletion tests. |
| View daily reminders | Today includes due/overdue and today’s completed plants; Upcoming shows later dates. | Due-date tests, day-rollover store test, UI list checks. |
| Mark done and track progress | Check/uncheck saves watering dates; the custom capsule progress bar animates. | Store progress/undo tests and UI completion test. |
| Confirm all complete | All Done appears when no due plants remain and at least one was completed today; View my plants permits undo/edit. | Store all-done assertions and UI completion/undo test. |
| Empty states | First launch shows the welcome artwork; removing all plants shows No reminders and an add button. | UI welcome and empty-state tests. |
| Local reminder | Explicit opt-in, system authorization/settings state, local 9:00 AM alerts, queue replacement on care changes. | Executed pure date/queue tests; actual permission/delivery still needs a device. |

All required care choices are in the model enums and editor pickers:

- **Rooms:** Bedroom, Living Room, Kitchen, Balcony, Bathroom.
- **Light:** Full Sun, Partial Sun, Low Light.
- **Watering:** Every day, every 2 days, every 3 days, once a week, every 10 days, every 2 weeks.
- **Water:** 20–50 ml, 50–100 ml, 100–200 ml, 200–300 ml.

The eight learning topics are mapped to concrete code in [LEARNING_GUIDE.md](LEARNING_GUIDE.md). The custom editor bar, native pickers, stacks, list, scrolling, progress style, row interactions, notifications, and centralized dark theme are all present. Artwork remains in a separate view so it does not obscure the beginner screen code.

## Corrections made during this review

- Rows and progress now use the same stored day. iOS’s significant-time-change notification refreshes midnight/time-zone changes while active; foreground entry refreshes after time away.
- An older care-edit draft preserves current watering history and creation date.
- Invalid saved names and duplicate IDs enter the recovery path instead of publishing broken rows. Failed writes leave existing state unchanged.
- Added a small custom animated progress style that respects Reduce Motion.
- VoiceOver row values include due/completed/upcoming dates.
- Dark-mode enforcement lives once at the app root.
- Extracted pure scheduling rules so actual Swift tests can run without an Apple SDK.
- Added isolated UI-test storage/preferences and a shared UI-test target.

## Executed checks

- **14 Foundation-only XCTest cases passed, 0 failed**, using Swift 6.0.3 on Linux. These execute the same model/date files used by the app.
- Swift compiler parsing and structural checks cover the app/test sources, target file membership, shared scheme, asset JSON, opaque app icon, privacy plist, and shell syntax.

## Still to execute on a Mac/device

The Linux authoring machine cannot compile SwiftUI/UIKit/UserNotifications or run an iOS simulator. **12 store tests and 6 UI tests are included but unrun here.** Run `./scripts/test-ios.sh` on a Mac for the complete build and 32 tests. The macOS CI workflow is provided but has not run yet.

Device acceptance checks remain necessary for visual comparison, VoiceOver navigation, large Dynamic Type, Reduce Motion, keyboard/sheet behavior, iPad layout, notification permission denial/re-enabling, delivered alerts, and cancellation after editing/deletion. The app uses local notifications with iOS’s 64-pending-alert limit; reopening replenishes future alerts. No claim of perfect runtime behavior is made before those checks pass.
