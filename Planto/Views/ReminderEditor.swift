import SwiftUI

@MainActor
struct ReminderEditor: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @StateObject private var model: ReminderEditorViewModel

    init(plant: PlantReminder?, plants: PlantsViewModel) {
        _model = StateObject(wrappedValue: ReminderEditorViewModel(plant: plant, plants: plants))
    }

    var body: some View {
        VStack(spacing: 0) {
            navigationBar
            ScrollView {
                VStack(spacing: 32) {
                    nameField

                    VStack(spacing: 0) {
                        pickerRow("Room", symbol: "paperplane", selection: $model.draft.room, options: Room.allCases) { $0.displayName }
                        rowDivider
                        pickerRow("Light", symbol: model.draft.light.symbolName, selection: $model.draft.light, options: LightLevel.allCases) { $0.displayName }
                    }
                    .background(PlantTheme.field, in: RoundedRectangle(cornerRadius: 22))

                    VStack(spacing: 0) {
                        pickerRow("Watering Days", symbol: "drop", selection: $model.draft.frequency, options: WateringFrequency.allCases) { $0.displayName }
                        rowDivider
                        pickerRow("Water", symbol: "drop", selection: $model.draft.waterAmount, options: WaterAmount.allCases) { $0.displayName }
                    }
                    .background(PlantTheme.field, in: RoundedRectangle(cornerRadius: 22))

                    if model.isEditing {
                        Button("Delete Reminder", role: .destructive) {
                            model.showingDeleteConfirmation = true
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
        .confirmationDialog("Delete \(model.trimmedName)?", isPresented: $model.showingDeleteConfirmation, titleVisibility: .visible) {
            Button("Delete Reminder", role: .destructive) {
                if model.delete() { dismiss() }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will remove the plant and its scheduled reminders.")
        }
        .alert("Unable to save changes", isPresented: Binding(
            get: { model.errorMessage != nil },
            set: { if !$0 { model.errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) { model.errorMessage = nil }
        } message: {
            Text(model.errorMessage ?? "Please try again.")
        }
    }

    private var navigationBar: some View {
        HStack {
            Button { dismiss() } label: {
                Image(systemName: "xmark")
            }
            .buttonStyle(PlantRoundButton())
            .accessibilityLabel("Cancel")
            .accessibilityIdentifier("reminder.cancel")
            Spacer(minLength: 8)
            Text("Set Reminder")
                .font(.headline)
                .accessibilityAddTraits(.isHeader)
            Spacer(minLength: 8)
            Button(action: save) {
                Image(systemName: "checkmark")
            }
            .buttonStyle(PlantRoundButton(isProminent: true))
            .disabled(!model.validName)
            .accessibilityLabel("Save reminder")
            .accessibilityIdentifier("reminder.save")
        }
        .padding(.horizontal, 16)
        .padding(.top, 20)
        .padding(.bottom, 8)
    }

    private var nameField: some View {
        // Change the layout without replacing the focused text field while typing.
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 8))
            : AnyLayout(HStackLayout(spacing: 10))

        return VStack(alignment: .leading, spacing: 8) {
            layout {
                Text("Plant Name").fixedSize(horizontal: false, vertical: true)
                input
            }
            .font(.subheadline)
            .padding(.horizontal, 16)
            .padding(.vertical, 15)
            .background(PlantTheme.field, in: Capsule())
            if model.trimmedName.count > 60 {
                Text("Keep your plant’s name to 60 characters or fewer.")
                    .font(.caption)
                    .foregroundStyle(.red)
                    .padding(.horizontal, 8)
            }
        }
    }

    private var input: some View {
        TextField("Pothos", text: $model.draft.name)
            .textInputAutocapitalization(.words)
            .autocorrectionDisabled()
            .submitLabel(.done)
            .tint(PlantTheme.accent)
            .accessibilityLabel("Plant name")
            .accessibilityIdentifier("reminder.name")
            .onSubmit { if model.validName { save() } }
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
        if model.save() { dismiss() }
    }
}
