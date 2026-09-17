import SwiftUI
import Observation
import WidgetKit
import HPCore

@MainActor @Observable final class WatchModel {
    var snapshot = SnapshotCache.read()
    var reachable = false
    var storageMessage: String?
    private let bridge = WatchBridge()
    init(debugScenario: String? = nil) {
        #if DEBUG
        if let debugScenario {
            var preferences = Preferences()
            preferences.goal = try! GoalConfiguration(goal: .lose, dailyMagnitude: 400)
            snapshot = SnapshotEnvelope(preferences: preferences, state: try? EnergyEngine.calculate(DebugScenarios.input(debugScenario), goal: preferences.goal))
            return
        }
        #endif
        bridge.onReceive = { [weak self] envelope in
            guard let self, envelope.sentAt >= (snapshot?.sentAt ?? .distantPast) else { return }
            snapshot = envelope
            do { try SnapshotCache.write(envelope); storageMessage = nil }
            catch { storageMessage = "Complication cache unavailable" }
            WidgetCenter.shared.reloadAllTimelines()
        }
        bridge.onStatus = { [weak self] in self?.reachable = self?.bridge.reachable ?? false }
    }
    func refresh() { bridge.requestRefresh() }
}
@main struct HPWatchApp: App {
    @State private var model = WatchModel()
    @Environment(\.scenePhase) private var phase
    var body: some Scene {
        WindowGroup {
            WatchHomeView(model: model)
                .onChange(of: phase) { _, phase in if phase == .active { model.refresh() } }
        }
    }
}
struct WatchHomeView: View {
    @Bindable var model: WatchModel
    var body: some View {
        TimelineView(.periodic(from: .now, by: 60)) { context in
            let state = model.snapshot?.usableState(now: context.date)
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    Text("HP").font(.caption.weight(.bold)).foregroundStyle(.secondary)
                    Text(HPStyle.number(state?.caloriesRemaining)).font(.system(size: 52, weight: .semibold, design: .rounded))
                        .monospacedDigit().minimumScaleFactor(0.4).lineLimit(1)
                        .accessibilityLabel(state?.caloriesRemaining.map { "\($0) kilocalories remaining today" } ?? "Balance unavailable")
                    Text("KCAL LEFT").font(.caption2.weight(.semibold)).foregroundStyle(.secondary)
                    HealthBar(fraction: state?.remainingFraction, status: state?.status ?? .incomplete)
                    if let state {
                        Text(HPStyle.description(state)).font(.caption2).foregroundStyle(.secondary)
                        Divider()
                        Text("\(HPStyle.number(state.eatenKcal)) eaten")
                        Text("\(HPStyle.number(state.activeKcal)) active")
                        Text(state.proteinText + " protein")
                        Text("\(state.steps.value.map { Int($0.rounded()).formatted() } ?? "—") steps")
                        Text(state.weightText(unit: model.snapshot?.preferences.weightUnit ?? .kg))
                        if state.caloriesRemaining == nil { Text("Check Health access and nutrition sources on iPhone.").font(.caption2) }
                        Text(state.isOutdated(at: context.date) ? "Earlier iPhone snapshot" : "Confirmed so far").font(.caption2).foregroundStyle(.secondary)
                        Text(state.queriedAt, style: .relative).font(.caption2).foregroundStyle(.secondary)
                    } else {
                        Text("Open HP on iPhone to connect Apple Health and refresh today’s balance.").font(.footnote).foregroundStyle(.secondary)
                    }
                    Button("Refresh from iPhone", systemImage: "arrow.clockwise") { model.refresh() }
                        .frame(minHeight: 44).disabled(!model.reachable)
                    if !model.reachable { Text("iPhone not reachable. Updates resume when connected.").font(.caption2).foregroundStyle(.secondary) }
                    if let message = model.storageMessage { Text(message).font(.caption2) }
                }.frame(maxWidth: .infinity, alignment: .leading).padding(.horizontal, 8).padding(.bottom)
            }
        }
    }
}
#if DEBUG
#Preview("Watch · empty") { WatchHomeView(model: WatchModel(debugScenario: "missing")) }
#Preview("Watch · 847") { WatchHomeView(model: WatchModel(debugScenario: "normal")) }
#Preview("Watch · over") { WatchHomeView(model: WatchModel(debugScenario: "over")) }
#endif
