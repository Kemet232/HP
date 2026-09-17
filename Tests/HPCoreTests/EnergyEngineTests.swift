import Foundation
import Testing
@testable import HPCore

struct EnergyEngineTests {
    let now = Date(timeIntervalSince1970: 1_790_000_000)
    func input(resting: Double = 1486, active: Double = 382, food: Double = 621) throws -> DailyInput {
        var input = DailyInput(day: DayWindow(now: now), queriedAt: now)
        input.resting = .available(try EnergyAmount(resting), measuredAt: now)
        input.active = .available(try EnergyAmount(active), measuredAt: now)
        input.food = .available(try EnergyAmount(food), measuredAt: now)
        input.weight = .available(try BodyWeight(80), measuredAt: now)
        return input
    }
    @Test func explanationExample() throws {
        let state = try EnergyEngine.calculate(input(), goal: GoalConfiguration(goal: .lose, dailyMagnitude: 400))
        #expect(state.caloriesRemaining == 847)
        #expect(state.confirmedEnergyBurned == 1868)
        #expect(state.dailyFoodAllowance == 1468)
        #expect(state.proteinTarget == 160)
    }
    @Test(arguments: [0.0, 1868, 2109]) func foodBalances(food: Double) throws {
        let state = try EnergyEngine.calculate(input(food: food), goal: .maintenance)
        #expect(state.caloriesRemaining == 1868 - Int(food))
        #expect(state.status == (food == 0 ? .available : food == 1868 ? .approachingLimit : .over))
    }
    @Test func activeIncrease() throws {
        let a = try EnergyEngine.calculate(input(active: 0), goal: .maintenance)
        let b = try EnergyEngine.calculate(input(active: 280), goal: .maintenance)
        #expect(b.caloriesRemaining! - a.caloriesRemaining! == 280)
    }
    @Test(arguments: [Goal.lose, .maintain, .gain]) func goals(goal: Goal) throws {
        let config = try GoalConfiguration(goal: goal, dailyMagnitude: goal == .maintain ? 0 : 400)
        let state = try EnergyEngine.calculate(input(), goal: config)
        #expect(state.caloriesRemaining == 1247 + config.dailyAdjustment)
    }
    @Test func workoutNeverAddedTwice() throws {
        var data = try input(active: 620)
        let baseline = try EnergyEngine.calculate(data, goal: .maintenance)
        data.workout = .live(try EnergyAmount(280))
        #expect(try EnergyEngine.calculate(data, goal: .maintenance).caloriesRemaining == baseline.caloriesRemaining)
        data.workout = .recorded(count: 1)
        #expect(try EnergyEngine.calculate(data, goal: .maintenance).activeKcal == 620)
        data.workout = .awaitingHealthData
        #expect(try EnergyEngine.calculate(data, goal: .maintenance).caloriesRemaining == baseline.caloriesRemaining)
    }
    @Test func unknownIsNotZero() throws {
        var data = try input(active: 0, food: 0)
        #expect(try EnergyEngine.calculate(data, goal: .maintenance).caloriesRemaining == 1486)
        data.food = .unavailable(.noDataOrReadAccess)
        #expect(try EnergyEngine.calculate(data, goal: .maintenance).caloriesRemaining == nil)
        data = try input(); data.active = .unavailable(.queryFailed)
        #expect(try EnergyEngine.calculate(data, goal: .maintenance).caloriesRemaining == nil)
        data = try input(); data.resting = .unavailable(.unsupported)
        #expect(try EnergyEngine.calculate(data, goal: .maintenance).caloriesRemaining == nil)
    }
    @Test func optionalMetrics() throws {
        var data = try input()
        data.weight = .unavailable(.noDataOrReadAccess)
        let state = try EnergyEngine.calculate(data, goal: .maintenance)
        #expect(state.proteinTarget == nil)
        #expect(state.protein.value == nil)
        #expect(state.caloriesRemaining == 1247)
    }
    @Test func staleDataPreservesTimestamp() throws {
        var data = try input()
        let earlier = now.addingTimeInterval(-14400)
        data.active = .stale(try EnergyAmount(382), measuredAt: earlier)
        let state = try EnergyEngine.calculate(data, goal: .maintenance)
        #expect(state.hasStaleEnergy)
        #expect(state.active.measuredAt == earlier)
        #expect(state.isOutdated(at: now))
    }
    @Test func highActivityAndStepsDoNotInventCalories() throws {
        var data = try input(active: 12000)
        data.steps = .available(80000, measuredAt: now)
        #expect(try EnergyEngine.calculate(data, goal: .maintenance).caloriesRemaining == 12865)
    }
    @Test(arguments: [-1.0, .nan, .infinity, 100001]) func malformedEnergy(value: Double) {
        #expect(throws: InputError.self) { try EnergyAmount(value) }
    }
    @Test func malformedOtherInputs() throws {
        #expect(throws: InputError.self) { try GoalConfiguration(goal: .lose, dailyMagnitude: 1000) }
        #expect(throws: InputError.self) { try GoalConfiguration.weekly(goal: .lose, kilograms: 0.75) }
        #expect(throws: InputError.self) { try GoalConfiguration(goal: .maintain, dailyMagnitude: 400) }
        #expect(throws: InputError.self) { try GoalConfiguration(goal: .gain, dailyMagnitude: 400, proteinGramsPerKG: .nan) }
        var data = try input(); data.steps = .available(.nan, measuredAt: now)
        #expect(throws: InputError.self) { try EnergyEngine.calculate(data, goal: .maintenance) }
        data = try input(); data.weight = .available(try BodyWeight(0), measuredAt: now)
        #expect(throws: InputError.self) { try EnergyEngine.calculate(data, goal: .maintenance) }
    }
    @Test func roundingReconciles() throws {
        let state = try EnergyEngine.calculate(input(resting: 1486.6, active: 382.6, food: 621.4), goal: GoalConfiguration(goal: .lose, dailyMagnitude: 400))
        #expect(state.caloriesRemaining == state.restingKcal! + state.activeKcal! + state.goalAdjustment - state.eatenKcal!)
    }
    @Test func earlyMorningNegativeAllowanceIsNotClamped() throws {
        let state = try EnergyEngine.calculate(input(resting: 10, active: 0, food: 0), goal: GoalConfiguration(goal: .lose, dailyMagnitude: 400))
        #expect(state.dailyFoodAllowance == -390)
        #expect(state.caloriesRemaining == -390)
        #expect(state.remainingFraction == 0)
    }
    @Test func weeklyRate() throws {
        #expect(try GoalConfiguration.weekly(goal: .lose, kilograms: 0.25).dailyAdjustment == -275)
        #expect(try GoalConfiguration.weekly(goal: .gain, kilograms: 0.5).dailyAdjustment == 550)
    }
    @Test func serializationRetainsValues() throws {
        let state = try EnergyEngine.calculate(input(), goal: .maintenance)
        let envelope = SnapshotEnvelope(preferences: Preferences(), state: state, sentAt: now)
        let decoded = try JSONDecoder().decode(SnapshotEnvelope.self, from: JSONEncoder().encode(envelope))
        #expect(decoded.usableState(now: now) == state)
        #expect(decoded.usableState(now: now.addingTimeInterval(86400)) == nil)
        #expect(throws: InputError.self) { try JSONDecoder().decode(EnergyAmount.self, from: Data("-5".utf8)) }
    }
    @Test func corruptedGoalFailsWithoutIntegerOverflow() throws {
        let data = Data("{\"goal\":\"lose\",\"dailyAdjustment\":-9223372036854775808,\"proteinGramsPerKG\":2}".utf8)
        let decoded = try JSONDecoder().decode(GoalConfiguration.self, from: data)
        #expect(throws: InputError.self) { try decoded.validated() }
    }
    @Test func cacheRejectsMismatchedCalculation() throws {
        let config = try GoalConfiguration(goal: .lose, dailyMagnitude: 400)
        let state = try EnergyEngine.calculate(input(), goal: config)
        let envelope = SnapshotEnvelope(preferences: Preferences(), state: state, sentAt: now)
        #expect(envelope.usableState(now: now) == nil)
    }
    @Test func amberBoundary() throws {
        let state = try EnergyEngine.calculate(input(resting: 1000, active: 0, food: 800), goal: .maintenance)
        #expect(state.status == .approachingLimit)
        #expect(try EnergyEngine.calculate(input(resting: 1000, active: 0, food: 799), goal: .maintenance).status == .available)
    }

}
