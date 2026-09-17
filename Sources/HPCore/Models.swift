import Foundation

public enum InputError: Error, Equatable { case invalidQuantity, invalidGoal, invalidDay }
public protocol QuantityUnit: Sendable { static var maximum: Double { get } }
public enum Kilocalories: QuantityUnit { public static let maximum = 100_000.0 }
public enum Grams: QuantityUnit { public static let maximum = 5_000.0 }
public enum Kilograms: QuantityUnit { public static let maximum = 700.0 }
public struct Amount<Unit: QuantityUnit>: Codable, Sendable, Equatable {
    public let value: Double
    public init(_ value: Double) throws {
        guard value.isFinite, value >= 0, value <= Unit.maximum else { throw InputError.invalidQuantity }
        self.value = value
    }
    public init(from decoder: Decoder) throws {
        try self.init(decoder.singleValueContainer().decode(Double.self))
    }
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer(); try container.encode(value)
    }
}
public typealias EnergyAmount = Amount<Kilocalories>
public typealias ProteinAmount = Amount<Grams>
public typealias BodyWeight = Amount<Kilograms>

public enum UnavailableReason: String, Codable, Sendable {
    case noDataOrReadAccess, unsupported, queryFailed, conflictingSources, invalidData
}
public enum HealthMetric<Value: Codable & Sendable & Equatable>: Codable, Sendable, Equatable {
    case available(Value, measuredAt: Date)
    case stale(Value, measuredAt: Date)
    case unavailable(UnavailableReason)
    public var value: Value? {
        switch self { case .available(let v, _), .stale(let v, _): return v; case .unavailable: return nil }
    }
    public var measuredAt: Date? {
        switch self { case .available(_, let date), .stale(_, let date): return date; case .unavailable: return nil }
    }
    public var isStale: Bool { if case .stale = self { return true }; return false }
}
public struct DayWindow: Codable, Sendable, Equatable {
    public let start: Date
    public let end: Date
    public let timeZoneID: String
    public init(now: Date, calendar: Calendar = .autoupdatingCurrent) {
        start = calendar.startOfDay(for: now)
        end = calendar.date(byAdding: .day, value: 1, to: start)!
        timeZoneID = calendar.timeZone.identifier
    }
    public func contains(_ date: Date) -> Bool { date >= start && date < end }
    public func matches(now: Date, calendar: Calendar = .autoupdatingCurrent) -> Bool {
        self == DayWindow(now: now, calendar: calendar)
    }
}
public enum Goal: String, Codable, Sendable, CaseIterable { case lose, maintain, gain }
public enum WeightUnit: String, Codable, Sendable, CaseIterable { case kg, lb }
public struct GoalConfiguration: Codable, Sendable, Equatable {
    public let goal: Goal
    public let dailyAdjustment: Int
    public let proteinGramsPerKG: Double
    public static let maintenance = try! GoalConfiguration(goal: .maintain, dailyMagnitude: 0)
    public init(goal: Goal, dailyMagnitude: Int, proteinGramsPerKG: Double? = nil) throws {
        let factor = proteinGramsPerKG ?? (goal == .lose ? 2.0 : 1.6)
        guard (0...750).contains(dailyMagnitude), factor.isFinite, (1.2...2.2).contains(factor),
              goal != .maintain || dailyMagnitude == 0 else { throw InputError.invalidGoal }
        self.goal = goal
        dailyAdjustment = goal == .lose ? -dailyMagnitude : goal == .gain ? dailyMagnitude : 0
        self.proteinGramsPerKG = factor
    }
    public static func weekly(goal: Goal, kilograms: Double) throws -> Self {
        guard kilograms.isFinite, (0...0.5).contains(kilograms), goal != .maintain || kilograms == 0 else { throw InputError.invalidGoal }
        // A transparent planning convention, not a weight-loss prediction.
        return try Self(goal: goal, dailyMagnitude: Int((kilograms * 7700 / 7).rounded()))
    }
    public func validated() throws -> Self {
        guard (-750...750).contains(dailyAdjustment) else { throw InputError.invalidGoal }
        let result = try Self(goal: goal, dailyMagnitude: abs(dailyAdjustment), proteinGramsPerKG: proteinGramsPerKG)
        guard result.dailyAdjustment == dailyAdjustment else { throw InputError.invalidGoal }
        return result
    }
}
public struct Preferences: Codable, Sendable, Equatable {
    public var goal: GoalConfiguration = .maintenance
    public var weightUnit: WeightUnit = Locale.current.measurementSystem == .us ? .lb : .kg
    public var nutritionSourceID: String? = nil
    public var onboarded = false
    public init() {}
}
public enum WorkoutState: Codable, Sendable, Equatable {
    case unavailable
    case live(EnergyAmount) // Reserved for an Apple-supported owned/mirrored session.
    case awaitingHealthData
    case recorded(count: Int)
}
public struct DailyInput: Sendable {
    public var day: DayWindow
    public var queriedAt: Date
    public var resting: HealthMetric<EnergyAmount> = .unavailable(.noDataOrReadAccess)
    public var active: HealthMetric<EnergyAmount> = .unavailable(.noDataOrReadAccess)
    public var food: HealthMetric<EnergyAmount> = .unavailable(.noDataOrReadAccess)
    public var protein: HealthMetric<ProteinAmount> = .unavailable(.noDataOrReadAccess)
    public var weight: HealthMetric<BodyWeight> = .unavailable(.noDataOrReadAccess)
    public var steps: HealthMetric<Double> = .unavailable(.noDataOrReadAccess)
    public var workout: WorkoutState = .unavailable
    public init(day: DayWindow, queriedAt: Date) { self.day = day; self.queriedAt = queriedAt }
}
public enum BudgetStatus: String, Codable, Sendable { case available, approachingLimit, over, incomplete }
public struct DailyEnergyState: Codable, Sendable, Equatable {
    public let day: DayWindow
    public let queriedAt: Date
    public let resting: HealthMetric<EnergyAmount>
    public let active: HealthMetric<EnergyAmount>
    public let food: HealthMetric<EnergyAmount>
    public let protein: HealthMetric<ProteinAmount>
    public let weight: HealthMetric<BodyWeight>
    public let steps: HealthMetric<Double>
    public let workout: WorkoutState
    public let goalAdjustment: Int
    public let confirmedEnergyBurned: Int?
    public let dailyFoodAllowance: Int?
    public let caloriesRemaining: Int?
    public let proteinTarget: Int?
    public let remainingFraction: Double?
    public let status: BudgetStatus
    public var restingKcal: Int? { resting.value.map { Int($0.value.rounded()) } }
    public var activeKcal: Int? { active.value.map { Int($0.value.rounded()) } }
    public var eatenKcal: Int? { food.value.map { Int($0.value.rounded()) } }
    public var hasStaleEnergy: Bool { resting.isStale || active.isStale }
    public func isOutdated(at now: Date) -> Bool { now.timeIntervalSince(queriedAt) > 3600 || hasStaleEnergy }
}
