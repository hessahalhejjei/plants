import SwiftUI

@MainActor
struct ContentView: View {
    @EnvironmentObject private var store: PlantStore
    @EnvironmentObject private var notifications: NotificationManager
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @AppStorage("hasCreatedPlant") private var hasCreatedPlant = false
    @State private var editor: ReminderSheet?
    @State private var showingNotifications = false
    @State private var showingCompletedPlants = false

    private var todayPlants: [PlantReminder] {
        store.plants.filter {
            $0.isDue(on: store.currentDay) || $0.isCompleted(on: store.currentDay)
        }
    }

    private var upcomingPlants: [PlantReminder] {
        store.plants.filter {
            !$0.isDue(on: store.currentDay) && !$0.isCompleted(on: store.currentDay)
        }
            .sorted { $0.nextWateringDate() < $1.nextWateringDate() }
    }

    private var careAnimation: Animation? {
        reduceMotion ? nil : .easeInOut(duration: 0.25)
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider().overlay(.white.opacity(0.07))

            if store.hasPlants {
                reminderList
            } else if hasCreatedPlant {
                Text("No reminders set yet…")
                    .accessibilityIdentifier("reminders.empty")
                    .font(.subheadline)
                    .foregroundStyle(PlantTheme.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                welcome
            }
        }
        .background(PlantTheme.background)
        .overlay(alignment: .bottomTrailing) {
            if store.hasPlants || hasCreatedPlant {
                addButton.padding(24)
            }
        }
        .sheet(item: $editor) { sheet in
            ReminderEditor(plant: sheet.plant)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showingNotifications) {
            NotificationSettingsView()
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
        .alert("Your reminders need attention", isPresented: Binding(
            get: { store.errorMessage != nil && editor == nil },
            set: { if !$0 { store.errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) { store.errorMessage = nil }
        } message: {
            Text(store.errorMessage ?? "Please try again.")
        }
        .onChange(of: store.plants) { _, plants in
            if !plants.isEmpty { hasCreatedPlant = true }
            if !store.allDoneToday { showingCompletedPlants = false }
        }
        .onAppear {
            if store.hasPlants { hasCreatedPlant = true }
        }
    }

    private var header: some View {
        HStack(spacing: 12) {
            Text("My Plants 🌱")
                .font(.title2.bold())
                .accessibilityAddTraits(.isHeader)
            Spacer(minLength: 8)
            Button {
                showingNotifications = true
            } label: {
                Image(systemName: notifications.isAuthorized ? "bell.badge" : "bell")
                    .font(.body)
                    .foregroundStyle(PlantTheme.secondary)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .accessibilityLabel("Notification settings")
            .accessibilityIdentifier("notifications.settings")
        }
        .padding(.leading, 20)
        .padding(.trailing, 8)
        .padding(.top, 12)
        .padding(.bottom, 8)
    }

    private var welcome: some View {
        ScrollView {
            VStack(spacing: 18) {
                PlantIllustration(isCelebrating: false)
                    .frame(width: 190, height: 190)
                    .accessibilityHidden(true)
                Text("Start your plant journey!")
                    .accessibilityIdentifier("welcome.title")
                    .font(.title3.bold())
                Text("Now all your plants will be in one place,\nand we’ll help you take care of them. 🌿")
                    .font(.subheadline)
                    .foregroundStyle(PlantTheme.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                Button("Set Plant Reminder") {
                    editor = ReminderSheet(plant: nil)
                }
                .accessibilityIdentifier("welcome.start")
                .buttonStyle(PlantPrimaryButton())
                .padding(.top, 36)
                .frame(maxWidth: 300)
            }
            .padding(.horizontal, 28)
            .padding(.vertical, 48)
            .frame(maxWidth: .infinity)
        }
        .defaultScrollAnchor(.center)
    }

    private var reminderList: some View {
        List {
            if store.allDoneToday {
                Section {
                    VStack(spacing: 12) {
                        PlantIllustration(isCelebrating: true)
                            .frame(width: 180, height: 180)
                            .accessibilityHidden(true)
                        Text("All Done! 🎉")
                            .accessibilityIdentifier("reminders.allDone")
                            .font(.title3.bold())
                        Text("All reminders completed")
                            .font(.subheadline)
                            .foregroundStyle(PlantTheme.secondary)
                        Button(showingCompletedPlants ? "Hide plants" : "View my plants") {
                            withAnimation(careAnimation) { showingCompletedPlants.toggle() }
                        }
                        .accessibilityIdentifier("reminders.showPlants")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(PlantTheme.accent)
                        .padding(.top, 12)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 42)
                    .listRowSeparator(.hidden)
                }
                .listRowBackground(Color.clear)
            } else {
                Section {
                    progressHeader
                        .listRowSeparator(.hidden)
                }
                .listRowBackground(Color.clear)
            }

            if !store.allDoneToday || showingCompletedPlants {
                if !todayPlants.isEmpty {
                    Section {
                        ForEach(todayPlants) { plant in
                            row(for: plant)
                        }
                    } header: {
                        Text("Today")
                            .textCase(nil)
                    }
                    .listRowBackground(Color.clear)
                }

                if !upcomingPlants.isEmpty {
                    Section {
                        ForEach(upcomingPlants) { plant in
                            row(for: plant)
                        }
                    } header: {
                        Text("Upcoming")
                            .textCase(nil)
                    }
                    .listRowBackground(Color.clear)
                }
            }

            Color.clear
                .frame(height: 80)
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)
                .accessibilityHidden(true)
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .animation(careAnimation, value: store.completedTodayCount)
    }

    private var progressHeader: some View {
        VStack(spacing: 12) {
            Text(progressMessage)
                .font(.subheadline)
                .multilineTextAlignment(.center)
            if store.totalTodayCount > 0 {
                ProgressView(
                    value: Double(store.completedTodayCount),
                    total: Double(max(1, store.totalTodayCount))
                )
                .progressViewStyle(PlantProgressStyle())
                .accessibilityIdentifier("reminders.progress")
                .accessibilityLabel("Today's watering progress")
                .accessibilityValue("\(store.completedTodayCount) of \(store.totalTodayCount) complete")
            }
        }
        .padding(.vertical, 16)
        .frame(maxWidth: .infinity)
    }

    private var progressMessage: String {
        if store.totalTodayCount == 0 { return "Your plants are all set for today 🌿" }
        if store.completedTodayCount == 0 { return "Your plants are waiting for a sip 💦" }
        return "\(store.completedTodayCount) of \(store.totalTodayCount) plants feel loved today ✨"
    }

    private func row(for plant: PlantReminder) -> some View {
        PlantReminderRow(plant: plant, day: store.currentDay) {
            withAnimation(careAnimation) {
                _ = store.toggleCompletion(for: plant)
            }
        } onEdit: {
            editor = ReminderSheet(plant: plant)
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button(role: .destructive) {
                withAnimation(careAnimation) { _ = store.delete(plant) }
            } label: {
                Label("Delete", systemImage: "trash")
            }
            Button {
                editor = ReminderSheet(plant: plant)
            } label: {
                Label("Edit", systemImage: "pencil")
            }
            .tint(PlantTheme.accent.opacity(0.6))
        }
        .listRowSeparatorTint(.white.opacity(0.14))
        .listRowInsets(EdgeInsets(top: 12, leading: 16, bottom: 12, trailing: 20))
    }

    private var addButton: some View {
        Button {
            editor = ReminderSheet(plant: nil)
        } label: {
            Image(systemName: "plus")
                .font(.title2.weight(.medium))
                .foregroundStyle(.white)
                .frame(width: 52, height: 52)
                .background(PlantTheme.accent.opacity(0.5), in: Circle())
                .overlay(Circle().stroke(PlantTheme.accent.opacity(0.7), lineWidth: 1))
        }
        .accessibilityLabel("Add plant reminder")
        .accessibilityIdentifier("reminders.add")
        .shadow(color: .black.opacity(0.4), radius: 8, y: 3)
    }
}

private struct ReminderSheet: Identifiable {
    let id = UUID()
    let plant: PlantReminder?
}

private struct PlantReminderRow: View {
    let plant: PlantReminder
    let day: Date
    let onToggle: () -> Void
    let onEdit: () -> Void
    @ScaledMetric(relativeTo: .body) private var checkSize: CGFloat = 24

    private var isComplete: Bool { plant.isCompleted(on: day) }
    private var canComplete: Bool { plant.isDue(on: day) || isComplete }

    private var wateringStatus: String {
        if isComplete { return "Watered today" }
        if canComplete { return "Due today" }
        return nextWateringDescription
    }

    var body: some View {
        HStack(spacing: 12) {
            Button(action: onToggle) {
                Image(systemName: isComplete ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: checkSize, weight: .light))
                    .foregroundStyle(isComplete ? PlantTheme.accent : PlantTheme.secondary)
                    .frame(minWidth: 44, minHeight: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(!canComplete)
            .opacity(canComplete ? 1 : 0.4)
            .accessibilityLabel(isComplete ? "Mark \(plant.name) as not watered" : "Mark \(plant.name) as watered")
            .accessibilityValue(wateringStatus)
            .accessibilityIdentifier("plant.toggle.\(plant.name)")

            Button(action: onEdit) {
                VStack(alignment: .leading, spacing: 6) {
                    Label("in \(plant.room.displayName)", systemImage: "location")
                        .font(.caption)
                        .foregroundStyle(PlantTheme.secondary)
                    Text(plant.name)
                        .font(.title3)
                        .foregroundStyle(isComplete ? PlantTheme.secondary : .white)
                        .multilineTextAlignment(.leading)
                    ViewThatFits(in: .horizontal) {
                        HStack(spacing: 8) { careBadges }
                        VStack(alignment: .leading, spacing: 6) { careBadges }
                    }
                    if !canComplete {
                        Text(nextWateringDescription)
                            .font(.caption)
                            .foregroundStyle(PlantTheme.secondary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Edit \(plant.name), in \(plant.room.displayName), \(plant.light.displayName), \(plant.waterAmount.displayName), \(plant.frequency.displayName)")
            .accessibilityValue(wateringStatus)
            .accessibilityIdentifier("plant.edit.\(plant.name)")
        }
    }

    @ViewBuilder private var careBadges: some View {
        Label(plant.light.displayName, systemImage: plant.light.symbolName)
            .foregroundStyle(Color(red: 0.76, green: 0.70, blue: 0.42))
            .careBadge()
        Label(plant.waterAmount.displayName, systemImage: "drop")
            .foregroundStyle(Color(red: 0.66, green: 0.83, blue: 0.90))
            .careBadge()
    }

    private var nextWateringDescription: String {
        let date = plant.nextWateringDate()
        let calendar = Calendar.current
        if let tomorrow = calendar.date(byAdding: .day, value: 1, to: day),
           calendar.isDate(date, inSameDayAs: tomorrow) {
            return "Water tomorrow"
        }
        return "Water \(date.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day()))"
    }
}

private extension View {
    func careBadge() -> some View {
        self.font(.caption)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(Color.white.opacity(0.09), in: RoundedRectangle(cornerRadius: 6))
    }
}
