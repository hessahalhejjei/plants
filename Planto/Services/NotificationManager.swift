import Combine
import Foundation
import UserNotifications

@MainActor
final class NotificationManager: ObservableObject {
    @Published private(set) var status: UNAuthorizationStatus = .notDetermined
    @Published var message: String?

    private let center: UNUserNotificationCenter
    private let identifierPrefix = "planto.watering."
    private var latestPlants: [PlantReminder]?
    private var isSyncing = false

    var isAuthorized: Bool {
        status == .authorized || status == .provisional || status == .ephemeral
    }

    init(center: UNUserNotificationCenter = .current()) {
        self.center = center
    }

    func refreshAuthorization() async {
        status = await center.notificationSettings().authorizationStatus
    }

    /// Called only from the user's explicit Enable Notifications action.
    func requestAuthorization() async {
        do {
            _ = try await center.requestAuthorization(options: [.alert, .sound, .badge])
            await refreshAuthorization()
            message = status == .denied
                ? "Notifications are off. You can enable them for Planto in iPhone Settings."
                : nil
        } catch {
            message = "Notification permission couldn’t be requested. Please try again."
        }
    }

    /// Coalesces changes during an await and applies the newest snapshot last.
    /// This avoids an older asynchronous schedule overwriting a recent edit or deletion.
    func sync(plants: [PlantReminder]) async {
        latestPlants = plants
        guard !isSyncing else { return }
        isSyncing = true
        defer { isSyncing = false }

        while let snapshot = latestPlants {
            latestPlants = nil
            await applySchedule(for: snapshot)
        }
    }

    private func applySchedule(for plants: [PlantReminder]) async {
        await refreshAuthorization()
        let existing = await center.pendingNotificationRequests()
        let owned = existing.filter { $0.identifier.hasPrefix(identifierPrefix) }
        center.removePendingNotificationRequests(withIdentifiers: owned.map(\.identifier))
        guard isAuthorized else { return }

        let calendar = Calendar.current
        let otherCount = existing.count - owned.count
        let availableSlots = max(0, 64 - otherCount)
        let candidates = WateringSchedule.upcomingReminders(
            for: plants, limit: availableSlots, calendar: calendar
        )
        var failed = false
        for candidate in candidates {
            // A newer snapshot will replace this queue; don't prolong obsolete work.
            guard latestPlants == nil else { return }
            let content = UNMutableNotificationContent()
            content.title = "Time for a little plant care 🌱"
            content.body = "Give \(candidate.plant.name) in \(candidate.plant.room.displayName) \(candidate.plant.waterAmount.displayName) of water."
            content.sound = .default
            content.threadIdentifier = "planto.watering"

            var components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: candidate.date)
            components.calendar = calendar
            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
            let dayID = "\(components.year ?? 0)-\(components.month ?? 0)-\(components.day ?? 0)"
            let identifier = "\(identifierPrefix)\(candidate.plant.id.uuidString).\(dayID)"
            do {
                try await center.add(UNNotificationRequest(identifier: identifier, content: content, trigger: trigger))
            } catch {
                failed = true
            }
        }
        if failed {
            message = "Some watering alerts couldn’t be scheduled. Open Planto again to retry."
        } else if plants.count > availableSlots {
            message = "iOS allows 64 pending alerts. The earliest watering reminders were scheduled; open Planto regularly to refresh them."
        } else {
            message = nil
        }
    }
}
