import Foundation
import HealthKit
import HPCore

/// Read-only adapter. No authorizationStatus(for:) checks: that API describes WRITE access.
final class HealthKitClient {
    private let store = HKHealthStore()
    private var observers: [HKObserverQuery] = []
    static let identifiers: [HKQuantityTypeIdentifier] = [.basalEnergyBurned, .activeEnergyBurned, .dietaryEnergyConsumed, .dietaryProtein, .bodyMass, .stepCount]
    private var readTypes: Set<HKObjectType> {
        Set(Self.identifiers.compactMap { HKObjectType.quantityType(forIdentifier: $0) as HKObjectType? } + [HKObjectType.workoutType()])
    }
    var supported: Bool { HKHealthStore.isHealthDataAvailable() }
    func requestAuthorization() async throws {
        guard supported else { throw HealthFailure.unsupported }
        try await store.requestAuthorization(toShare: [], read: readTypes)
    }
    enum HealthFailure: Error { case unsupported, failed }

    /// Keep completion callbacks alive until the refresh has finished, including failure paths.
    func observe(onChange: @escaping (@escaping () -> Void) -> Void) {
        guard supported, observers.isEmpty else { return }
        for type in readTypes.compactMap({ $0 as? HKSampleType }) {
            let observer = HKObserverQuery(sampleType: type, predicate: nil) { _, completion, error in
                guard error == nil else { completion(); return }
                onChange(completion)
            }
            observers.append(observer)
            store.execute(observer)
            store.enableBackgroundDelivery(for: type, frequency: .hourly) { _, _ in }
        }
    }
    deinit { observers.forEach(store.stop) }

    struct Result { let input: DailyInput; let sources: [NutritionSource] }
    func fetch(now: Date, preferredNutritionSource: String?) async -> Result {
        let day = DayWindow(now: now)
        var input = DailyInput(day: day, queriedAt: now)
        guard supported else {
            input.resting = .unavailable(.unsupported); input.active = .unavailable(.unsupported)
            input.food = .unavailable(.unsupported); input.protein = .unavailable(.unsupported)
            input.weight = .unavailable(.unsupported); input.steps = .unavailable(.unsupported)
            return Result(input: input, sources: [])
        }
        let sourceResult = await nutritionSources(day: day, now: now)
        let sources = (try? sourceResult.get()) ?? []
        let selection = NutritionSourcePolicy.selectedID(sources: sources.map { NutritionSource(id: $0.bundleIdentifier, name: $0.name) }, preferred: preferredNutritionSource)
        // Bounded, independent queries; HealthKit performs the cumulative energy aggregation.
        async let resting = amount(.basalEnergyBurned, unit: .kilocalorie(), day: day, now: now, staleAfter: 10800, as: Kilocalories.self)
        async let active = amount(.activeEnergyBurned, unit: .kilocalorie(), day: day, now: now, staleAfter: 10800, as: Kilocalories.self)
        async let steps = statistic(.stepCount, unit: .count(), day: day, now: now)
        async let weight = latestWeight(now: now)
        async let workouts = workoutCount(day: day, now: now)
        input.resting = await resting; input.active = await active
        input.steps = await steps; input.weight = await weight; input.workout = await workouts
        switch (sourceResult, selection) {
        case (.failure, _):
            input.food = .unavailable(.queryFailed); input.protein = .unavailable(.queryFailed)
        case (_, .failure):
            input.food = .unavailable(.conflictingSources); input.protein = .unavailable(.conflictingSources)
        case (_, .success(let id)):
            if let id, !sources.contains(where: { $0.bundleIdentifier == id }) {
                input.food = .unavailable(.noDataOrReadAccess); input.protein = .unavailable(.noDataOrReadAccess)
            } else {
                let source = sources.first { $0.bundleIdentifier == id }
                async let food = amount(.dietaryEnergyConsumed, unit: .kilocalorie(), day: day, now: now, source: source, as: Kilocalories.self)
                async let protein = amount(.dietaryProtein, unit: .gram(), day: day, now: now, source: source, as: Grams.self)
                input.food = await food; input.protein = await protein
            }
        }
        return Result(input: input, sources: sources.map { NutritionSource(id: $0.bundleIdentifier, name: $0.name) }.sorted { $0.name < $1.name })
    }

    private func nutritionSources(day: DayWindow, now: Date) async -> Swift.Result<[HKSource], Error> {
        do {
            var result = Set<HKSource>()
            for id in [HKQuantityTypeIdentifier.dietaryEnergyConsumed, .dietaryProtein] {
                let type = HKQuantityType.quantityType(forIdentifier: id)!
                let sources: Set<HKSource> = try await withCheckedThrowingContinuation { continuation in
                    let query = HKSourceQuery(sampleType: type, samplePredicate: HKQuery.predicateForSamples(withStart: day.start, end: now)) { _, sources, error in
                        if let error { continuation.resume(throwing: error) }
                        else { continuation.resume(returning: sources ?? []) }
                    }
                    store.execute(query)
                }
                result.formUnion(sources)
            }
            return .success(Array(result))
        } catch { return .failure(error) }
    }

    private func amount<U: QuantityUnit>(_ id: HKQuantityTypeIdentifier, unit: HKUnit, day: DayWindow, now: Date,
        source: HKSource? = nil, staleAfter: TimeInterval? = nil, as: U.Type) async -> HealthMetric<Amount<U>> {
        let metric = await statistic(id, unit: unit, day: day, now: now, source: source)
        guard let value = metric.value, let measured = metric.measuredAt else {
            if case .unavailable(let reason) = metric { return .unavailable(reason) }
            return .unavailable(.invalidData)
        }
        guard let amount = try? Amount<U>(value) else { return .unavailable(.invalidData) }
        if let staleAfter, now.timeIntervalSince(measured) > staleAfter { return .stale(amount, measuredAt: measured) }
        return .available(amount, measuredAt: measured)
    }

    private func statistic(_ id: HKQuantityTypeIdentifier, unit: HKUnit, day: DayWindow, now: Date, source: HKSource? = nil) async -> HealthMetric<Double> {
        let type = HKQuantityType.quantityType(forIdentifier: id)!
        // Overlap predicate + calendar-day statistics buckets handle cross-midnight samples.
        // Do not use strictStartDate, sum raw samples, or add HKWorkout energy here.
        var predicates = [HKQuery.predicateForSamples(withStart: day.start, end: now)]
        if let source { predicates.append(HKQuery.predicateForObjects(from: source)) }
        let predicate = NSCompoundPredicate(andPredicateWithSubpredicates: predicates)
        do {
            let value: Double? = try await withCheckedThrowingContinuation { continuation in
                var interval = DateComponents(); interval.day = 1
                let query = HKStatisticsCollectionQuery(quantityType: type, quantitySamplePredicate: predicate,
                    options: .cumulativeSum, anchorDate: day.start, intervalComponents: interval)
                query.initialResultsHandler = { [weak self] query, collection, error in
                    defer { self?.store.stop(query) }
                    if let error { continuation.resume(throwing: error) }
                    else { continuation.resume(returning: collection?.statistics(for: day.start)?.sumQuantity()?.doubleValue(for: unit)) }
                }
                store.execute(query)
            }
            guard let value else { return .unavailable(.noDataOrReadAccess) }
            guard value.isFinite, value >= 0 else { return .unavailable(.invalidData) }
            let last: HKQuantitySample? = try await latestSample(type: type, predicate: predicate)
            return .available(value, measuredAt: last?.endDate ?? now)
        } catch { return .unavailable(.queryFailed) }
    }
    private func latestSample(type: HKQuantityType, predicate: NSPredicate) async throws -> HKQuantitySample? {
        try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(sampleType: type, predicate: predicate, limit: 1,
                sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)]) { _, samples, error in
                if let error { continuation.resume(throwing: error) }
                else { continuation.resume(returning: samples?.first as? HKQuantitySample) }
            }
            store.execute(query)
        }
    }
    private func latestWeight(now: Date) async -> HealthMetric<BodyWeight> {
        do {
            let type = HKQuantityType.quantityType(forIdentifier: .bodyMass)!
            let sample = try await latestSample(type: type, predicate: HKQuery.predicateForSamples(withStart: nil, end: now, options: .strictEndDate))
            guard let sample else { return .unavailable(.noDataOrReadAccess) }
            guard let value = try? BodyWeight(sample.quantity.doubleValue(for: .gramUnit(with: .kilo))), value.value > 0 else { return .unavailable(.invalidData) }
            return now.timeIntervalSince(sample.endDate) > 14 * 86400 ? .stale(value, measuredAt: sample.endDate) : .available(value, measuredAt: sample.endDate)
        } catch { return .unavailable(.queryFailed) }
    }
    private func workoutCount(day: DayWindow, now: Date) async -> WorkoutState {
        do {
            let count: Int = try await withCheckedThrowingContinuation { continuation in
                let query = HKSampleQuery(sampleType: .workoutType(), predicate: HKQuery.predicateForSamples(withStart: day.start, end: now),
                    limit: HKObjectQueryNoLimit, sortDescriptors: nil) { _, samples, error in
                    if let error { continuation.resume(throwing: error) }
                    else { continuation.resume(returning: samples?.count ?? 0) }
                }
                store.execute(query)
            }
            // No samples does not establish that the user did no workouts.
            return count > 0 ? .recorded(count: count) : .unavailable
        } catch { return .unavailable }
    }
}
