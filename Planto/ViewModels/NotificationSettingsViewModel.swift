import Foundation
#if canImport(Combine)
import Combine
#else
import OpenCombine
#endif

enum NotificationAuthorization {
    case notDetermined, denied, authorized
}

@MainActor
protocol NotificationProviding {
    var status: NotificationAuthorization { get }
    var message: String? { get }
    func refreshAuthorization() async
    func requestAuthorization() async
    func sync(plants: [PlantReminder]) async
}

@MainActor
final class NotificationSettingsViewModel: ObservableObject {
    @Published private(set) var status: NotificationAuthorization = .notDetermined
    @Published private(set) var message: String?
    @Published private(set) var requesting = false
    private let service: NotificationProviding
    private let isUITesting: Bool

    init(service: NotificationProviding, isUITesting: Bool = false) {
        self.service = service
        self.isUITesting = isUITesting
        updateStatus()
    }

    var isAuthorized: Bool { status == .authorized }
    var canOpenSettings: Bool { !isUITesting }
    var statusDescription: String {
        if isAuthorized {
            return "Reminders are enabled. We’ll send a nudge at 9:00 AM when a plant is due for water."
        }
        if status == .denied {
            return "Notifications are turned off. You can enable them in Settings to receive watering reminders at 9:00 AM. Your plants are always available here."
        }
        return "Let Planto remind you at 9:00 AM when a plant is due for water. You can change notification permissions in Settings at any time."
    }

    func refreshAuthorization() async {
        guard !isUITesting else { return }
        await service.refreshAuthorization()
        updateStatus()
    }

    func enableReminders(currentPlants: () -> [PlantReminder]) async {
        guard !isUITesting, !requesting else { return }
        requesting = true
        defer { requesting = false }
        await service.requestAuthorization()
        // Permission can suspend while another window edits or deletes a plant.
        await service.sync(plants: currentPlants())
        updateStatus()
    }

    func sync(plants: [PlantReminder]) async {
        guard !isUITesting else { return }
        await service.sync(plants: plants)
        updateStatus()
    }

    private func updateStatus() {
        status = service.status
        message = service.message
    }
}
