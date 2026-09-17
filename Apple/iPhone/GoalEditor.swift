import SwiftUI
import HPCore
struct GoalEditor: View {
    @Binding var selection: Goal
    @Binding var advanced: Bool
    @Binding var weeklyRate: Double
    @Binding var magnitude: Int
    @Binding var proteinFactor: Double
    var body: some View {
        Section("Your goal") {
            Picker("Goal", selection: $selection) {
                ForEach(Goal.allCases, id: \.self) { Text($0.rawValue.capitalized).tag($0) }
            }.pickerStyle(.segmented)
            if selection != .maintain {
                Toggle("Advanced calorie target", isOn: $advanced)
                if advanced {
                    Stepper("\(magnitude) kcal / day", value: $magnitude, in: 0...750, step: 25)
                } else {
                    Picker("Weekly change", selection: $weeklyRate) {
                        Text("0.25 kg / 0.55 lb").tag(0.25)
                        Text("0.5 kg / 1.1 lb").tag(0.5)
                    }
                }
                Text("\(selection == .lose ? "Deficit" : "Surplus"): \(advanced ? magnitude : Int((weeklyRate * 7700 / 7).rounded())) kcal per day. Weekly change is a planning approximation, not a prediction.")
                    .font(.footnote).foregroundStyle(.secondary)
            }
        }
        Section("Protein") {
            Stepper("\(proteinFactor.formatted(.number.precision(.fractionLength(1)))) g / kg", value: $proteinFactor, in: 1.2...2.2, step: 0.1)
            Text("Target uses your latest Apple Health weight. Default: 2.0 g/kg for Lose, 1.6 g/kg for Maintain or Gain. You can change this factor.").font(.footnote).foregroundStyle(.secondary)
        }
        Section {
            Text("Designed for adults. Calorie targets and protein needs are individual; these settings are not suitable guidance for children, pregnancy or a medical nutrition plan.").font(.footnote).foregroundStyle(.secondary)
        }
    }
}
