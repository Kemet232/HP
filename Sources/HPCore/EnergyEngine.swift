import Foundation

public enum EnergyEngine {
    public static let amberThreshold = 0.2
    public static func calculate(_ input: DailyInput, goal: GoalConfiguration) throws -> DailyEnergyState {
        guard input.day.contains(input.queriedAt) else { throw InputError.invalidDay }
        let goal = try goal.validated()
        if let steps = input.steps.value, !steps.isFinite || steps < 0 || steps > 250_000 { throw InputError.invalidQuantity }
        if let weight = input.weight.value, weight.value <= 0 { throw InputError.invalidQuantity }
        // Round each visible component once so the Why screen always reconciles exactly.
        let resting = input.resting.value.map { Int($0.value.rounded()) }
        let active = input.active.value.map { Int($0.value.rounded()) }
        let food = input.food.value.map { Int($0.value.rounded()) }
        let burned: Int? = resting.flatMap { r in active.map { r + $0 } }
        let allowance = burned.map { $0 + goal.dailyAdjustment }
        let remaining = allowance.flatMap { a in food.map { a - $0 } }
        let fraction: Double? = remaining.flatMap { r in allowance.map { a in a > 0 ? min(1, max(0, Double(r) / Double(a))) : 0 } }
        let status: BudgetStatus
        if let remaining { status = remaining < 0 ? .over : (fraction ?? 0) <= amberThreshold ? .approachingLimit : .available }
        else { status = .incomplete }
        return DailyEnergyState(day: input.day, queriedAt: input.queriedAt, resting: input.resting,
            active: input.active, food: input.food, protein: input.protein, weight: input.weight,
            steps: input.steps, workout: input.workout, goalAdjustment: goal.dailyAdjustment,
            confirmedEnergyBurned: burned, dailyFoodAllowance: allowance, caloriesRemaining: remaining,
            proteinTarget: input.weight.value.map { Int(($0.value * goal.proteinGramsPerKG).rounded()) },
            remainingFraction: fraction, status: status)
    }
}

public struct NutritionSource: Codable, Sendable, Equatable, Identifiable {
    public let id: String
    public let name: String
    public init(id: String, name: String) { self.id = id; self.name = name }
}
public enum NutritionSourcePolicy {
    // HealthKit can't infer whether two apps represent the same meal. Never guess.
    public static func selectedID(sources: [NutritionSource], preferred: String?) -> Result<String?, SourceConflict> {
        if let preferred { return .success(preferred) }
        let identifiers = Set(sources.map(\.id))
        guard identifiers.count <= 1 else { return .failure(.chooseOneSource) }
        return .success(identifiers.first)
    }
    public enum SourceConflict: Error { case chooseOneSource }
}

public struct SnapshotEnvelope: Codable, Sendable {
    public let schemaVersion: Int
    public let preferences: Preferences
    public let state: DailyEnergyState?
    public let sentAt: Date
    public init(preferences: Preferences, state: DailyEnergyState?, sentAt: Date = .now) {
        schemaVersion = 1; self.preferences = preferences; self.state = state; self.sentAt = sentAt
    }
    public func usableState(now: Date, calendar: Calendar = .autoupdatingCurrent) -> DailyEnergyState? {
        guard schemaVersion == 1, let state, state.day.matches(now: now, calendar: calendar), state.queriedAt <= now.addingTimeInterval(60) else { return nil }
        // The cache and paired-device boundary must not bypass domain validation.
        var input = DailyInput(day: state.day, queriedAt: state.queriedAt)
        input.resting = state.resting; input.active = state.active; input.food = state.food
        input.protein = state.protein; input.weight = state.weight; input.steps = state.steps
        input.workout = state.workout
        guard let recomputed = try? EnergyEngine.calculate(input, goal: preferences.goal), recomputed == state else { return nil }
        return recomputed
    }
}
