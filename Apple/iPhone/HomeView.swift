import SwiftUI
import HPCore

struct HomeView: View {
    @Bindable var model: AppModel
    @State private var showWhy = false
    @State private var showSettings = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var typeSize
    var body: some View {
        NavigationStack {
            TimelineView(.periodic(from: .now, by: 60)) { context in
                let state = model.state.flatMap { $0.day.matches(now: context.date) ? $0 : nil }
                ScrollView {
                    VStack(alignment: .leading, spacing: 32) {
                        VStack(alignment: .leading, spacing: 16) {
                            Text(model.isDebugSession ? "SIMULATED · DEBUG" : "TODAY, SO FAR").font(.caption.weight(.semibold)).tracking(2).foregroundStyle(.secondary)
                            Button { showWhy = true } label: {
                                VStack(alignment: .leading, spacing: 0) {
                                    Text(HPStyle.number(state?.caloriesRemaining))
                                        .font(.system(size: typeSize.isAccessibilitySize ? 78 : 104, weight: .semibold, design: .rounded))
                                        .monospacedDigit().minimumScaleFactor(0.45).lineLimit(1)
                                        .contentTransition(.numericText())
                                    Text("KCAL LEFT").font(.subheadline.weight(.semibold)).tracking(3).foregroundStyle(.secondary)
                                }.frame(maxWidth: .infinity, alignment: .leading).contentShape(Rectangle())
                            }.buttonStyle(.plain).accessibilityIdentifier("calorieBalance")
                                .accessibilityLabel(state?.caloriesRemaining.map { "\($0) kilocalories remaining today" } ?? "Calorie balance unavailable")
                                .accessibilityHint("Shows how HP calculates your allowance")
                                .animation(reduceMotion ? nil : .smooth(duration: 0.5), value: state?.caloriesRemaining)
                            HealthBar(fraction: state?.remainingFraction, status: state?.status ?? .incomplete)
                            Text(HPStyle.description(state)).font(.subheadline).foregroundStyle(.secondary)
                            Text("\(HPStyle.number(state?.eatenKcal)) kcal eaten").font(.title3).monospacedDigit()
                        }.padding(.top, 18)
                        if let state {
                            if state.caloriesRemaining == nil { missingData(state) }
                            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), alignment: .leading), count: typeSize.isAccessibilitySize ? 1 : 2), alignment: .leading, spacing: 26) {
                                MetricLabel(title: "Active", value: state.activeKcal.map { "+\($0.formatted()) kcal" } ?? "—", detail: state.active.isStale ? "Earlier Health data" : nil)
                                MetricLabel(title: "Protein", value: state.proteinText, detail: state.protein.value == nil ? "No protein data" : state.weight.isStale ? "Target uses older weight" : nil)
                                MetricLabel(title: "Steps", value: state.steps.value.map { Int($0.rounded()).formatted() } ?? "—")
                                MetricLabel(title: "Weight", value: state.weightText(unit: model.preferences.weightUnit), detail: state.weight.measuredAt.map { $0.formatted(date: .abbreviated, time: .omitted) })
                            }
                            workoutDetail(state.workout)
                            VStack(alignment: .leading, spacing: 6) {
                                Text(state.isOutdated(at: context.date) || model.isCached ? "Earlier snapshot · updates may be delayed" : "Confirmed Apple Health data")
                                Text("Checked \(state.queriedAt.formatted(.relative(presentation: .named)))")
                            }.font(.caption).foregroundStyle(.secondary)
                        } else {
                            ContentUnavailableView("Waiting for Apple Health", systemImage: "heart.text.square", description: Text("Connect Health in Settings. HP needs resting energy, active energy and food data to show a balance."))
                        }
                        if !model.watchReady {
                            VStack(alignment: .leading, spacing: 8) {
                                Label("Apple Watch required", systemImage: "applewatch").font(.headline)
                                Text("Pair Apple Watch in the Watch app, install HP on it, and allow Activity tracking. Your iPhone data remains available while your Watch is disconnected.").font(.footnote).foregroundStyle(.secondary)
                            }
                        }
                        Text("This is energy recorded so far, not a full-day eating recommendation. HP does not count future expenditure.").font(.footnote).foregroundStyle(.secondary)
                        if let message = model.message { Text(message).font(.footnote).foregroundStyle(.secondary) }
                    }.padding(.horizontal, 28).padding(.bottom, 30)
                }.refreshable { await model.refresh() }
                .onChange(of: context.date) { _, date in
                    if let state = model.state, !state.day.matches(now: date) { Task { await model.refresh() } }
                }
            }
            .navigationTitle("HP").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Settings", systemImage: "slider.horizontal.3") { showSettings = true }.accessibilityIdentifier("settings")
                }
                ToolbarItem(placement: .topBarLeading) { if model.isRefreshing { ProgressView().accessibilityLabel("Updating Health data") } }
            }
            .sheet(isPresented: $showWhy) { WhyView(state: model.state) }
            .sheet(isPresented: $showSettings) { SettingsView(model: model) }
        }
    }
    @ViewBuilder private func missingData(_ state: DailyEnergyState) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("A little more data is needed").font(.headline)
            if state.resting.value == nil { Text("No resting energy available.") }
            if state.active.value == nil { Text("No active energy available.") }
            if case .unavailable(.conflictingSources) = state.food {
                Text("More than one app supplied nutrition. Choose one in Settings to avoid counting food twice.")
            } else if state.food.value == nil {
                Text("HP hasn’t received dietary energy today. Allow your food tracker to write it to Apple Health.")
            }
            Text("Missing data can also mean read access is off. Check Apple Health → Sharing → Apps → HP.")
        }.font(.footnote).foregroundStyle(.secondary)
    }
    @ViewBuilder private func workoutDetail(_ workout: WorkoutState) -> some View {
        switch workout {
        case .live(let amount): Label("WORKOUT ACTIVE · +\(Int(amount.value)) kcal live", systemImage: "figure.run")
        case .awaitingHealthData: Label("Workout data updating", systemImage: "arrow.triangle.2.circlepath")
        case .recorded(let count): Text("\(count) recorded workout\(count == 1 ? "" : "s") · energy included in Active").font(.footnote).foregroundStyle(.secondary)
        case .unavailable: EmptyView()
        }
    }
}
