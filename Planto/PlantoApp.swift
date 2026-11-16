import Combine
import SwiftUI
import UIKit

@main
@MainActor
struct PlantoApp: App {
    @StateObject private var store: PlantStore
    @StateObject private var notifications = NotificationManager()
    @Environment(\.scenePhase) private var scenePhase
    private let launchSettings: AppLaunchSettings

    init() {
        let settings = AppLaunchSettings()
        launchSettings = settings
        _store = StateObject(wrappedValue: PlantStore(storageURL: settings.storageURL))
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .defaultAppStorage(launchSettings.defaults)
                .environmentObject(store)
                .environmentObject(notifications)
                .preferredColorScheme(.dark)
                .tint(Color(red: 0.12, green: 0.84, blue: 0.67))
                .task {
                    guard !launchSettings.isUITesting else { return }
                    await notifications.sync(plants: store.plants)
                }
                .onChange(of: store.plants) { _, plants in
                    guard !launchSettings.isUITesting else { return }
                    Task { await notifications.sync(plants: plants) }
                }
                .onChange(of: scenePhase) { _, phase in
                    guard phase == .active else { return }
                    store.refreshDay()
                    guard !launchSettings.isUITesting else { return }
                    Task {
                        await notifications.sync(plants: store.plants)
                    }
                }
                // iOS sends this at midnight and when its time or time zone changes.
                .onReceive(NotificationCenter.default.publisher(for: UIApplication.significantTimeChangeNotification)) { _ in
                    guard scenePhase == .active else { return }
                    store.refreshDay()
                    guard !launchSettings.isUITesting else { return }
                    Task { await notifications.sync(plants: store.plants) }
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
