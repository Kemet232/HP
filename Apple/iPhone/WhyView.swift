import SwiftUI
import HPCore
struct WhyView: View {
    let state: DailyEnergyState?
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        NavigationStack {
            List {
                Section("Confirmed so far") {
                    row("Resting energy", state?.restingKcal)
                    row("Active energy", state?.activeKcal)
                    row("Goal adjustment", state?.goalAdjustment)
                    row("Food eaten", state?.eatenKcal.map { -$0 })
                    row("Calories remaining", state?.caloriesRemaining, bold: true)
                }
                Section {
                    Text("Resting + Active + Goal adjustment − Food eaten. Each component is rounded to whole kcal before addition, so these numbers reconcile exactly.")
                    Text("Workout energy is already represented by Active Energy. HP never adds workouts or steps again.")
                    Text("The whole daily goal adjustment applies from midnight. Early in the day, a low or negative balance is expected. This is not a recommendation to skip food.")
                    Text("No future resting or active energy is included. Nutrition totals reflect entries received from your selected Health source, not a complete record of everything you may have eaten.")
                }.font(.footnote).foregroundStyle(.secondary)
                if let state {
                    Section("Data freshness") {
                        Text("Last checked \(state.queriedAt.formatted(date: .abbreviated, time: .shortened))")
                        if let date = state.resting.measuredAt { Text("Latest resting sample: \(date.formatted(date: .omitted, time: .shortened))") }
                        if let date = state.active.measuredAt { Text("Latest active sample: \(date.formatted(date: .omitted, time: .shortened))") }
                        if state.hasStaleEnergy { Text("Energy samples are older than three hours. Your current balance may have changed.") }
                    }.font(.footnote)
                }
            }.navigationTitle("Why \(HPStyle.number(state?.caloriesRemaining))?")
                .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
        }
    }
    private func row(_ title: String, _ value: Int?, bold: Bool = false) -> some View {
        LabeledContent(title, value: "\(HPStyle.number(value)) kcal").fontWeight(bold ? .semibold : .regular).monospacedDigit()
    }
}
