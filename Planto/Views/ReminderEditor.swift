import SwiftUI

@MainActor
struct ReminderEditor: View {
    @EnvironmentObject private var store: PlantStore
    @Environment(\.dismiss) private var dismiss
    @FocusState private var nameIsFocused: Bool
    @State private var draft: PlantReminder
    @State private var showingDeleteConfirmation = false
    private let isEditing: Bool

    init(plant: PlantReminder?) {
        _draft = State(initialValue: plant ?? PlantReminder(name: ""))
        isEditing = plant != nil
    }

    private var trimmedName: String {
        draft.name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var validName: Bool {
        !trimmedName.isEmpty && trimmedName.count <= 60
    }

    var body: some View {
        VStack(spacing: 0) {
            navigationBar
            ScrollView {
                VStack(spacing: 32) {
                    nameField

                    VStack(spacing: 0) {
                        pickerRow("Room", symbol: "location", selection: $draft.room, options: Room.allCases) { $0.displayName }
                        rowDivider
                        pickerRow("Light", symbol: draft.light.symbolName, selection: $draft.light, options: LightLevel.allCases) { $0.displayName }
                    }
                    .background(PlantTheme.field, in: RoundedRectangle(cornerRadius: 22))

                    VStack(spacing: 0) {
                        pickerRow("Watering Days", symbol: "drop", selection: $draft.frequency, options: WateringFrequency.allCases) { $0.displayName }
                        rowDivider
                        pickerRow("Water", symbol: "drop", selection: $draft.waterAmount, options: WaterAmount.allCases) { $0.displayName }
                    }
                    .background(PlantTheme.field, in: RoundedRectangle(cornerRadius: 22))

                    if isEditing {
                        Button("Delete Reminder", role: .destructive) {
                            showingDeleteConfirmation = true
                        }
                        .accessibilityIdentifier("reminder.delete")
                        .font(.subheadline)
                        .frame(maxWidth: .infinity, minHeight: 48)
                        .background(PlantTheme.field, in: Capsule())
                        .padding(.top, 16)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 32)
                .padding(.bottom, 32)
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .background(PlantTheme.sheet)
        .confirmationDialog("Delete \(trimmedName)?", isPresented: $showingDeleteConfirmation, titleVisibility: .visible) {
            Button("Delete Reminder", role: .destructive) {
                if store.delete(draft) { dismiss() }
            }
            .accessibilityIdentifier("reminder.confirmDelete")
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will remove the plant and its scheduled reminders.")
        }
        .alert("Unable to save changes", isPresented: Binding(
            get: { store.errorMessage != nil },
            set: { if !$0 { store.errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) { store.errorMessage = nil }
        } message: {
            Text(store.errorMessage ?? "Please try again.")
        }
    }

    private var navigationBar: some View {
        HStack {
            Button { dismiss() } label: {
                Image(systemName: "xmark")
                    .font(.body.weight(.medium))
                    .foregroundStyle(.white)
                    .frame(width: 44, height: 44)
                    .background(.white.opacity(0.08), in: Circle())
                    .overlay(Circle().stroke(.white.opacity(0.15), lineWidth: 1))
            }
            .accessibilityLabel("Cancel")
            .accessibilityIdentifier("reminder.cancel")
            Spacer(minLength: 8)
            Text(isEditing ? "Edit Reminder" : "Set Reminder")
                .font(.headline)
                .accessibilityAddTraits(.isHeader)
            Spacer(minLength: 8)
            Button(action: save) {
                Image(systemName: "checkmark")
                    .font(.body.weight(.medium))
                    .foregroundStyle(.white)
                    .frame(width: 44, height: 44)
                    .background(PlantTheme.accent.opacity(validName ? 0.5 : 0.15), in: Circle())
                    .overlay(Circle().stroke(PlantTheme.accent.opacity(validName ? 0.7 : 0.15), lineWidth: 1))
            }
            .disabled(!validName)
            .accessibilityLabel("Save reminder")
            .accessibilityIdentifier("reminder.save")
        }
        .padding(.horizontal, 16)
        .padding(.top, 20)
        .padding(.bottom, 8)
    }

    private var nameField: some View {
        VStack(alignment: .leading, spacing: 8) {
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 10) {
                    Text("Plant Name").fixedSize()
                    input
                }
                VStack(alignment: .leading, spacing: 8) {
                    Text("Plant Name")
                    input
                }
            }
            .font(.subheadline)
            .padding(.horizontal, 16)
            .padding(.vertical, 15)
            .background(PlantTheme.field, in: Capsule())
            if trimmedName.count > 60 {
                Text("Keep your plant’s name to 60 characters or fewer.")
                    .font(.caption)
                    .foregroundStyle(.red)
                    .padding(.horizontal, 8)
            }
        }
    }

    private var input: some View {
        TextField("Pothos", text: $draft.name)
            .focused($nameIsFocused)
            .textInputAutocapitalization(.words)
            .autocorrectionDisabled()
            .submitLabel(.done)
            .tint(PlantTheme.accent)
            .accessibilityLabel("Plant name")
            .accessibilityIdentifier("reminder.name")
            .onSubmit { if validName { save() } }
    }

    private var rowDivider: some View {
        Divider()
            .overlay(.white.opacity(0.03))
            .padding(.leading, 16)
    }

    private func pickerRow<Value: Hashable>(
        _ title: String,
        symbol: String,
        selection: Binding<Value>,
        options: [Value],
        display: @escaping (Value) -> String
    ) -> some View {
        Menu {
            Picker(title, selection: selection) {
                ForEach(options, id: \.self) { option in
                    Text(display(option)).tag(option)
                }
            }
        } label: {
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 8) {
                    Label(title, systemImage: symbol)
                        .foregroundStyle(.white)
                    Spacer(minLength: 12)
                    Text(display(selection.wrappedValue))
                        .foregroundStyle(PlantTheme.secondary)
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.caption2)
                        .foregroundStyle(PlantTheme.secondary)
                }
                VStack(alignment: .leading, spacing: 8) {
                    Label(title, systemImage: symbol)
                        .foregroundStyle(.white)
                    HStack {
                        Text(display(selection.wrappedValue))
                            .foregroundStyle(PlantTheme.secondary)
                        Spacer()
                        Image(systemName: "chevron.up.chevron.down")
                            .foregroundStyle(PlantTheme.secondary)
                    }
                }
            }
            .font(.subheadline)
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
        }
        .accessibilityLabel(title)
        .accessibilityValue(display(selection.wrappedValue))
        .accessibilityIdentifier("care.\(title)")
    }

    private func save() {
        guard validName else { return }
        draft.name = trimmedName
        if store.save(draft) { dismiss() }
    }
}
