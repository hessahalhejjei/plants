import SwiftUI

@MainActor
struct ContentView: View {
    @EnvironmentObject private var model: PlantsViewModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @StateObject private var viewModel = ContentViewModel()

    private var careAnimation: Animation? {
        reduceMotion ? nil : .easeInOut(duration: 0.25)
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider().overlay(.white.opacity(0.07))

            if model.hasPlants {
                if model.allDoneToday && !viewModel.showingCompletedPlants {
                    celebration
                } else {
                    reminderList
                }
            } else if model.hasCreatedPlant {
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
            if model.hasPlants || model.hasCreatedPlant {
                addButton.padding(24)
            }
        }
        .sheet(item: $viewModel.editor) { sheet in
            ReminderEditor(plant: sheet.plant, plants: model)
                .presentationDetents([.large])
                .presentationDragIndicator(.hidden)
        }
        .sheet(isPresented: $viewModel.showingNotifications) {
            NotificationSettingsView()
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
        .alert("Your reminders need attention", isPresented: Binding(
            get: { model.errorMessage != nil && viewModel.editor == nil },
            set: { if !$0 { model.errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) { model.errorMessage = nil }
        } message: {
            Text(model.errorMessage ?? "Please try again.")
        }
        .onChange(of: model.allDoneToday) { _, allDone in
            viewModel.updateCompletionState(allDone: allDone)
        }
    }

    private var header: some View {
        HStack(spacing: 12) {
            Text("My Plants 🌱")
                .font(.title2.bold())
                .accessibilityAddTraits(.isHeader)
            Spacer(minLength: 8)
            Menu {
                if model.allDoneToday {
                    Button(viewModel.showingCompletedPlants ? "Return to All Done" : "View my plants") {
                        withAnimation(careAnimation) { viewModel.toggleCompletedPlants() }
                    }
                    .accessibilityIdentifier("reminders.showPlants")
                }
                Button("Notification settings", systemImage: "bell") {
                    viewModel.showingNotifications = true
                }
                .accessibilityIdentifier("notifications.settings")
            } label: {
                Image(systemName: "ellipsis")
            }
            .buttonStyle(PlantRoundButton())
            .accessibilityLabel("More options")
            .accessibilityIdentifier("reminders.menu")
        }
        .padding(.leading, 20)
        .padding(.trailing, 8)
        .padding(.top, 12)
        .padding(.bottom, 8)
    }

    private var welcome: some View {
        centeredContent {
            VStack(spacing: 18) {
                PlantIllustration()
                    .frame(width: 190, height: 190)
                Text("Start your plant journey!")
                    .accessibilityIdentifier("welcome.title")
                    .font(.title3.bold())
                Text("Now all your plants will be in one place and\nwe will help you take care of them! 🪴")
                    .font(.footnote)
                    .foregroundStyle(PlantTheme.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                Button("Set Plant Reminder") {
                    viewModel.addPlant()
                }
                .accessibilityIdentifier("welcome.start")
                .buttonStyle(PlantPrimaryButton())
                .padding(.top, 64)
                .frame(maxWidth: 260)
            }
        }
    }

    private var celebration: some View {
        centeredContent {
            VStack(spacing: 12) {
                PlantIllustration(isCelebrating: true)
                    .frame(width: 190, height: 190)
                Text("All Done! 🎉")
                    .accessibilityIdentifier("reminders.allDone")
                    .font(.title3.bold())
                Text("All Reminders Completed")
                    .font(.footnote)
                    .foregroundStyle(PlantTheme.secondary)
            }
        }
    }

    private func centeredContent<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        let screen = content()
        return GeometryReader { geometry in
            ScrollView {
                screen
                    .padding(.horizontal, 24)
                    .padding(.vertical, 32)
                    .frame(maxWidth: .infinity, minHeight: geometry.size.height)
            }
        }
    }

    private var reminderList: some View {
        List {
            Section {
                progressHeader
                    .listRowSeparator(.hidden)
            }
            .listRowBackground(Color.clear)

            if !model.todayPlants.isEmpty {
                Section {
                    ForEach(model.todayPlants) { plant in
                        row(for: plant)
                    }
                }
                .listRowBackground(Color.clear)
            }

            if !model.upcomingPlants.isEmpty {
                Section {
                    ForEach(model.upcomingPlants) { plant in
                        row(for: plant)
                    }
                } header: {
                    Text("Upcoming")
                        .textCase(nil)
                }
                .listRowBackground(Color.clear)
            }

            Color.clear
                .frame(height: 80)
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)
                .accessibilityHidden(true)
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .animation(careAnimation, value: model.completedTodayCount)
    }

    private var progressHeader: some View {
        VStack(spacing: 12) {
            Text(model.progressMessage)
                .font(.subheadline)
                .multilineTextAlignment(.center)
            if model.totalTodayCount > 0 {
                ProgressView(
                    value: Double(model.completedTodayCount),
                    total: Double(max(1, model.totalTodayCount))
                )
                .progressViewStyle(PlantProgressStyle())
                .accessibilityIdentifier("reminders.progress")
                .accessibilityLabel("Today's watering progress")
                .accessibilityValue("\(model.completedTodayCount) of \(model.totalTodayCount) complete")
            }
        }
        .padding(.top, 28)
        .padding(.bottom, 32)
        .frame(maxWidth: .infinity)
    }

    private func row(for plant: PlantReminder) -> some View {
        PlantReminderRow(plant: plant, day: model.currentDay) {
            withAnimation(careAnimation) {
                _ = model.toggleCompletion(for: plant)
            }
        } onEdit: {
            viewModel.editPlant(plant)
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button(role: .destructive) {
                withAnimation(careAnimation) { _ = model.delete(plant) }
            } label: {
                Label("Delete", systemImage: "trash")
                    .labelStyle(.iconOnly)
            }
        }
        .listRowSeparatorTint(.white.opacity(0.14))
        .listRowInsets(EdgeInsets(top: 12, leading: 8, bottom: 12, trailing: 16))
    }

    private var addButton: some View {
        Button {
            viewModel.addPlant()
        } label: {
            Image(systemName: "plus")
        }
        .buttonStyle(PlantRoundButton(isProminent: true))
        .accessibilityLabel("Add plant reminder")
        .accessibilityIdentifier("reminders.add")
    }
}

private struct PlantReminderRow: View {
    let plant: PlantReminder
    let day: Date
    let onToggle: () -> Void
    let onEdit: () -> Void
    @ScaledMetric(relativeTo: .body) private var checkSize: CGFloat = 24

    private var model: PlantRowViewModel { PlantRowViewModel(plant: plant, day: day) }

    var body: some View {
        HStack(spacing: 8) {
            Button(action: onToggle) {
                Image(systemName: model.isComplete ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: checkSize, weight: .light))
                    .foregroundStyle(model.isComplete ? PlantTheme.accent : PlantTheme.secondary)
                    .frame(minWidth: 44, minHeight: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(!model.canComplete)
            .opacity(model.canComplete ? 1 : 0.4)
            .accessibilityLabel(model.isComplete ? "Mark \(plant.name) as not watered" : "Mark \(plant.name) as watered")
            .accessibilityValue(model.wateringStatus)
            .accessibilityIdentifier("plant.toggle.\(plant.name)")

            Button(action: onEdit) {
                VStack(alignment: .leading, spacing: 6) {
                    Label("in \(plant.room.displayName)", systemImage: "paperplane")
                        .font(.caption)
                        .foregroundStyle(PlantTheme.secondary)
                    Text(plant.name)
                        .font(.title3)
                        .foregroundStyle(model.isComplete ? PlantTheme.secondary : .white)
                        .multilineTextAlignment(.leading)
                    ViewThatFits(in: .horizontal) {
                        HStack(spacing: 8) { careBadges }
                        VStack(alignment: .leading, spacing: 6) { careBadges }
                    }
                    if !model.canComplete {
                        Text(model.nextWateringDescription)
                            .font(.caption)
                            .foregroundStyle(PlantTheme.secondary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Edit \(plant.name), in \(plant.room.displayName), \(plant.light.displayName), \(plant.waterAmount.displayName), \(plant.frequency.displayName)")
            .accessibilityValue(model.wateringStatus)
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
}

private extension View {
    func careBadge() -> some View {
        self.font(.caption)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(Color.white.opacity(0.09), in: RoundedRectangle(cornerRadius: 6))
    }
}
