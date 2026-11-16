import Combine
import SwiftUI
import UIKit

@main
@MainActor
struct PlantoApp: App {
    @StateObject private var plants: PlantsViewModel
    @StateObject private var notifications: NotificationSettingsViewModel
    @Environment(\.scenePhase) private var scenePhase
    private let launchSettings: AppLaunchSettings

    init() {
        let settings = AppLaunchSettings()
        launchSettings = settings
        _plants = StateObject(wrappedValue: PlantsViewModel(storageURL: settings.storageURL, defaults: settings.defaults))
        _notifications = StateObject(wrappedValue: NotificationSettingsViewModel(service: NotificationService(), isUITesting: settings.isUITesting))
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(plants)
                .environmentObject(notifications)
                .preferredColorScheme(.dark)
                .tint(Color(red: 0.12, green: 0.84, blue: 0.67))
                .task {
                    guard !launchSettings.isUITesting else { return }
                    await notifications.sync(plants: plants.plants)
                }
                .onChange(of: plants.plants) { _, _ in
                    guard !launchSettings.isUITesting else { return }
                    Task { await notifications.sync(plants: plants.plants) }
                }
                .onChange(of: scenePhase) { _, phase in
                    guard phase == .active else { return }
                    plants.refreshDay()
                    guard !launchSettings.isUITesting else { return }
                    Task {
                        await notifications.sync(plants: plants.plants)
                    }
                }
                // iOS sends this at midnight and when its time or time zone changes.
                .onReceive(NotificationCenter.default.publisher(for: UIApplication.significantTimeChangeNotification)) { _ in
                    guard scenePhase == .active else { return }
                    plants.refreshDay()
                    guard !launchSettings.isUITesting else { return }
                    Task { await notifications.sync(plants: plants.plants) }
                }
        }
    }
}

/// UI tests use their own file and defaults. Normal launches never reset user data.
private struct AppLaunchSettings {
    let isUITesting: Bool
    let storageURL: URL?
    let defaults: UserDefaults

    init() {
        let arguments = ProcessInfo.processInfo.arguments
        isUITesting = arguments.contains("--ui-testing")
        guard isUITesting else {
            storageURL = nil
            defaults = .standard
            return
        }

        let suiteName = "PlantoUITests"
        guard let testDefaults = UserDefaults(suiteName: suiteName) else {
            preconditionFailure("Could not create isolated UI-test preferences.")
        }
        defaults = testDefaults
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let testDirectory = support.appendingPathComponent("PlantoUITests", isDirectory: true)
        storageURL = testDirectory.appendingPathComponent("reminders.json")

        if arguments.contains("--reset-ui-test-data") {
            defaults.removePersistentDomain(forName: suiteName)
            if FileManager.default.fileExists(atPath: testDirectory.path) {
                do {
                    try FileManager.default.removeItem(at: testDirectory)
                } catch {
                    preconditionFailure("Could not reset isolated UI-test reminders.")
                }
            }
        }
    }
}
