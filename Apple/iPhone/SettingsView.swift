import SwiftUI
import HPCore
struct SettingsView: View {
    @Bindable var model: AppModel
    @Environment(\.dismiss) private var dismiss
    @State private var goal: Goal
    @State private var advanced = true
    @State private var weekly = 0.25
    @State private var magnitude: Int
    @State private var protein: Double
    @State private var unit: WeightUnit
    @State private var source: String
    @State private var requesting = false
    init(model: AppModel) {
        self.model = model
        let p = model.preferences
        _goal = State(initialValue: p.goal.goal)
        _magnitude = State(initialValue: abs(p.goal.dailyAdjustment))
        _protein = State(initialValue: p.goal.proteinGramsPerKG)
        _unit = State(initialValue: p.weightUnit)
        _source = State(initialValue: p.nutritionSourceID ?? "")
    }
    var body: some View {
        NavigationStack {
            Form {
                GoalEditor(selection: $goal, advanced: $advanced, weeklyRate: $weekly, magnitude: $magnitude, proteinFactor: $protein)
                Section("Display") {
                    Picker("Weight unit", selection: $unit) { ForEach(WeightUnit.allCases, id: \.self) { Text($0.rawValue).tag($0) } }
                }
                Section("Nutrition source") {
                    Picker("Read food from", selection: $source) {
                        Text("Automatic · one source only").tag("")
                        ForEach(model.nutritionSources) { Text($0.name).tag($0.id) }
                        if !source.isEmpty, !model.nutritionSources.contains(where: { $0.id == source }) { Text("Selected source · no data today").tag(source) }
                    }
                    Text("If several apps write nutrition, choose one. Apple Health can’t reliably identify duplicate meals. Both calories and protein use this source.").font(.footnote).foregroundStyle(.secondary)
                }
                Section("Apple Health") {
                    Button(requesting ? "Requesting…" : "Request Health access") {
                        requesting = true
                        Task { await model.authorize(); requesting = false }
                    }.disabled(requesting)
                    Text("Manage existing permissions in Apple Health → Sharing → Apps → HP. Read permissions are private: HP cannot tell whether access is denied or no samples exist.").font(.footnote).foregroundStyle(.secondary)
                    if let message = model.message { Text(message).font(.footnote) }
                }
                Section("Apple Watch") {
                    Label(model.watchReady ? "HP installed" : "Pair Watch and install HP in the Watch app", systemImage: "applewatch")
                    Text("HP sends a protected daily snapshot through Apple’s paired-device connection. Open HP on iPhone to get the latest Health data.").font(.footnote).foregroundStyle(.secondary)
                }
                Section("Privacy") {
                    Text("No account. No analytics. No advertising. No HP server. Calculations stay on your devices.")
                    Text("Only preferences and the latest derived daily state are saved. Health values are excluded from HP’s file backup and never logged. Health permissions can be revoked in Apple Health.")
                    Text("HP does not send notifications or run continuous sensor polling.")
                }.font(.footnote).foregroundStyle(.secondary)
                Section("About") { Text("HP · Version 1.0"); Text("Now > History").foregroundStyle(.secondary) }
            }.navigationTitle("Settings")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let amount = goal == .maintain ? 0 : advanced ? magnitude : Int((weekly * 7700 / 7).rounded())
                        guard let config = try? GoalConfiguration(goal: goal, dailyMagnitude: amount, proteinGramsPerKG: protein) else { return }
                        model.preferences.goal = config; model.preferences.weightUnit = unit
                        model.preferences.nutritionSourceID = source.isEmpty ? nil : source
                        model.savePreferences()
                        Task { await model.refresh() }
                        dismiss()
                    }.accessibilityIdentifier("saveSettings")
                }
            }
        }
    }
}
