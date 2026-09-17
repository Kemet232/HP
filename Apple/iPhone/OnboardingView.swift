import SwiftUI
import HPCore
struct OnboardingView: View {
    @Bindable var model: AppModel
    @State private var step = 0
    @State private var goal: Goal = .maintain
    @State private var advanced = false
    @State private var weekly = 0.25
    @State private var magnitude = 275
    @State private var protein = 1.6
    @State private var requesting = false
    var body: some View {
        NavigationStack {
            Group {
                if step == 0 {
                    VStack(alignment: .leading, spacing: 24) {
                        Spacer()
                        Image(systemName: "battery.75percent").font(.system(size: 56)).foregroundStyle(.green).accessibilityHidden(true)
                        Text("HP").font(.system(size: 76, weight: .bold, design: .rounded))
                        Text("Your daily energy\nhealth bar.").font(.largeTitle.weight(.semibold))
                        Text("See what’s left, as your day unfolds. Powered by Apple Health and your Apple Watch.").font(.title3).foregroundStyle(.secondary)
                        Spacer()
                        Button("Get started") { step = 1 }.buttonStyle(.borderedProminent).controlSize(.large).accessibilityIdentifier("getStarted")
                    }.padding(28)
                } else if step == 1 {
                    Form {
                        GoalEditor(selection: $goal, advanced: $advanced, weeklyRate: $weekly, magnitude: $magnitude, proteinFactor: $protein)
                        Button("Continue") {
                            let amount = goal == .maintain ? 0 : advanced ? magnitude : Int((weekly * 7700 / 7).rounded())
                            if let config = try? GoalConfiguration(goal: goal, dailyMagnitude: amount, proteinGramsPerKG: protein) {
                                model.preferences.goal = config; model.savePreferences(); step = 2
                            }
                        }.accessibilityIdentifier("continueGoal")
                    }.navigationTitle("A goal that fits")
                    .onChange(of: goal) { _, goal in protein = goal == .lose ? 2 : 1.6 }
                } else {
                    Form {
                        Section("Only what HP needs") {
                            Label("Resting + active energy", systemImage: "flame")
                            Label("Food calories + protein", systemImage: "fork.knife")
                            Label("Weight + steps + workouts", systemImage: "figure.walk")
                            Text("HP reads these values to calculate your allowance and show context. It never writes to Apple Health. No account, ads or health-data server.").font(.footnote).foregroundStyle(.secondary)
                        }
                        Section("Apple Watch") {
                            Label(model.watchReady ? "HP is installed on your Watch" : "Pair your Watch and install HP", systemImage: "applewatch")
                            Text("Open the Watch app on your iPhone to install HP. The Watch shows the same confirmed snapshot as your iPhone; refresh timing is controlled by Apple.").font(.footnote).foregroundStyle(.secondary)
                        }
                        Section {
                            Button(requesting ? "Requesting access…" : "Connect Apple Health") {
                                requesting = true
                                Task { await model.authorize(); requesting = false }
                            }.disabled(requesting).accessibilityIdentifier("connectHealth")
                            Button("Open HP") { model.finishOnboarding() }.disabled(requesting).accessibilityIdentifier("finishOnboarding")
                            Text("You can open HP without granting access. Missing values stay unavailable until Health data can be read.").font(.footnote).foregroundStyle(.secondary)
                            if let message = model.message { Text(message).font(.footnote) }
                        }
                    }.navigationTitle("Connect your day")
                }
            }.toolbar { if step > 0 { ToolbarItem(placement: .topBarLeading) { Button("Back") { step -= 1 } } } }
        }
    }
}
