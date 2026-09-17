import Foundation
import Observation
import WidgetKit
import HPCore

@MainActor @Observable final class AppModel {
    var preferences = PreferenceStore.read()
    var state: DailyEnergyState?
    var nutritionSources: [NutritionSource] = []
    var isRefreshing = false
    var message: String?
    var isCached = false
    var watchReady = false
    private let health = HealthKitClient()
    private let bridge = WatchBridge()
    private var runningRefresh: Task<Void, Never>?
    private var refreshAgain = false
    private var lastInput: DailyInput?
    private var isDebugSession = false
    init(debugScenario: String? = nil) {
        #if DEBUG
        let args = ProcessInfo.processInfo.arguments
        if debugScenario != nil || args.contains("--hp-ui-testing") {
            isDebugSession = true
            preferences = Preferences()
            preferences.onboarded = !args.contains("--hp-onboarding")
            let name = debugScenario ?? args.first(where: { $0.hasPrefix("--hp-scenario=") })?.components(separatedBy: "=").last ?? "normal"
            lastInput = DebugScenarios.input(name)
            preferences.goal = try! GoalConfiguration(goal: .lose, dailyMagnitude: 400)
            state = try? EnergyEngine.calculate(lastInput!, goal: preferences.goal)
            watchReady = name != "no-watch"
            return
        }
        #endif
        if let cache = SnapshotCache.read() { state = cache.usableState(now: .now); isCached = state != nil }
        bridge.onStatus = { [weak self] in self?.watchReady = self?.bridge.watchReady ?? false }
        bridge.onRefreshRequest = { [weak self] in Task { await self?.refresh() } }
        // Register at launch so HealthKit background wakes can be acknowledged promptly.
        if preferences.onboarded { beginObserving() }
    }
    private func beginObserving() {
        guard !isDebugSession else { return }
        health.observe { [weak self] completion in
            Task { @MainActor in
                defer { completion() }
                await self?.refresh()
            }
        }
    }
    func authorize() async {
        guard !isDebugSession else { return }
        message = nil
        do { try await health.requestAuthorization(); beginObserving(); await refresh() }
        catch { message = health.supported ? "Health access couldn’t be requested. Try again, or check HP in Apple Health → Sharing → Apps." : "Apple Health isn’t available on this device." }
    }
    func finishOnboarding() {
        preferences.onboarded = true
        savePreferences()
        beginObserving()
    }
    func savePreferences() {
        if isDebugSession {
            if let input = lastInput { state = try? EnergyEngine.calculate(input, goal: preferences.goal) }
            return
        }
        do {
            _ = try preferences.goal.validated()
            if PreferenceStore.read().nutritionSourceID != preferences.nutritionSourceID { lastInput = nil; state = nil }
            try PreferenceStore.write(preferences)
            if let input = lastInput, input.day.matches(now: .now) {
                state = try EnergyEngine.calculate(input, goal: preferences.goal)
            } else { state = nil }
            publish()
        } catch { message = "Your settings couldn’t be saved. Please try again." }
    }
    func refresh() async {
        guard !isDebugSession else { return }
        if let runningRefresh {
            refreshAgain = true
            await runningRefresh.value
            return
        }
        let task = Task { @MainActor [weak self] in
            guard let self else { return }
            isRefreshing = true
            defer { isRefreshing = false }
            repeat {
                refreshAgain = false
                await performRefresh()
            } while refreshAgain
        }
        runningRefresh = task
        await task.value
        runningRefresh = nil
    }
    private func performRefresh() async {
        let now = Date()
        if state?.day.matches(now: now) == false { state = nil; lastInput = nil; publish() }
        let source = preferences.nutritionSourceID
        let result = await health.fetch(now: now, preferredNutritionSource: source)
        guard result.input.day.matches(now: .now), source == preferences.nutritionSourceID else { refreshAgain = true; return }
        do {
            lastInput = result.input
            state = try EnergyEngine.calculate(result.input, goal: preferences.goal)
            nutritionSources = result.sources
            isCached = false
            publish()
        } catch { state = nil; message = "Some Health values couldn’t be used. Check the entries in Apple Health."; publish() }
    }
    private func publish() {
        let envelope = SnapshotEnvelope(preferences: preferences, state: state)
        do { try SnapshotCache.write(envelope) }
        catch { message = "HP couldn’t save its widget snapshot. Check the App Group signing configuration." }
        WidgetCenter.shared.reloadAllTimelines()
        bridge.send(envelope)
    }
}
