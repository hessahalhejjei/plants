import SwiftUI
import UIKit

@MainActor
struct NotificationSettingsView: View {
    @EnvironmentObject private var notifications: NotificationSettingsViewModel
    @EnvironmentObject private var store: PlantsViewModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL

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
                Text(notifications.statusDescription)
                    .font(.subheadline)
                    .foregroundStyle(PlantTheme.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)

                if notifications.status == .notDetermined {
                    Button {
                        Task { await notifications.enableReminders { store.plants } }
                    } label: {
                        if notifications.requesting {
                            ProgressView().tint(.white)
                        } else {
                            Text("Enable Reminders")
                        }
                    }
                    .buttonStyle(PlantPrimaryButton())
                    .disabled(notifications.requesting)
                    .accessibilityLabel("Enable Reminders")
                    .accessibilityValue(notifications.requesting ? "Requesting permission" : "")
                    .accessibilityIdentifier("notifications.enable")
                } else {
                    Button("Open Notification Settings") {
                        guard notifications.canOpenSettings else { return }
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
            await notifications.refreshAuthorization()
        }
    }
}
