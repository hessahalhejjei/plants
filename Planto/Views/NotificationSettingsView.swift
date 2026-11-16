import SwiftUI
import UIKit
import UserNotifications

@MainActor
struct NotificationSettingsView: View {
    @EnvironmentObject private var notifications: NotificationManager
    @EnvironmentObject private var store: PlantStore
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @State private var requesting = false

    private var isUITesting: Bool {
        ProcessInfo.processInfo.arguments.contains("--ui-testing")
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                HStack {
                    Text("A little nudge to grow")
                        .font(.title3.bold())
                        .accessibilityAddTraits(.isHeader)
                    Spacer()
                    Button { dismiss() } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .foregroundStyle(PlantTheme.secondary)
                            .frame(minWidth: 44, minHeight: 44)
                    }
                    .accessibilityLabel("Close notification settings")
                }
                Image(systemName: notifications.isAuthorized ? "bell.badge.fill" : "bell")
                    .font(.system(size: 34))
                    .foregroundStyle(PlantTheme.accent)
                    .accessibilityHidden(true)
                Text(statusDescription)
                    .font(.subheadline)
                    .foregroundStyle(PlantTheme.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)

                if notifications.status == .notDetermined {
                    Button {
                        guard !isUITesting else { return }
                        requesting = true
                        Task {
                            await notifications.requestAuthorization()
                            await notifications.sync(plants: store.plants)
                            requesting = false
                        }
                    } label: {
                        if requesting {
                            ProgressView().tint(.white)
                        } else {
                            Text("Enable Reminders")
                        }
                    }
                    .buttonStyle(PlantPrimaryButton())
                    .disabled(requesting)
                } else {
                    Button("Open Notification Settings") {
                        guard !isUITesting else { return }
                        if let url = URL(string: UIApplication.openSettingsURLString) {
                            openURL(url)
                        }
                    }
                    .buttonStyle(PlantPrimaryButton())
                }

                if let message = notifications.message {
                    Text(message)
                        .font(.caption)
                        .foregroundStyle(PlantTheme.secondary)
                        .multilineTextAlignment(.center)
                }
                Text("Open Planto regularly to keep future reminders up to date.")
                    .font(.caption)
                    .foregroundStyle(PlantTheme.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(24)
            .frame(maxWidth: .infinity)
        }
        .background(PlantTheme.sheet)
        .task {
            guard !isUITesting else { return }
            await notifications.refreshAuthorization()
        }
    }

    private var statusDescription: String {
        if notifications.isAuthorized {
            return "Reminders are enabled. We’ll send a nudge at 9:00 AM when a plant is due for water."
        }
        if notifications.status == .denied {
            return "Notifications are turned off. You can enable them in Settings to receive watering reminders at 9:00 AM. Your plants are always available here."
        }
        return "Let Planto remind you at 9:00 AM when a plant is due for water. You can change notification permissions in Settings at any time."
    }
}
