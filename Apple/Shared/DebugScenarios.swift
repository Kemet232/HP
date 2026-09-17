#if DEBUG
import Foundation
import HPCore

enum DebugScenarios {
    static func input(_ name: String, now: Date = .now) -> DailyInput {
        var input = DailyInput(day: DayWindow(now: now), queriedAt: now)
        guard name != "missing", name != "read-unavailable" else { return input }
        input.resting = .available(try! EnergyAmount(1486), measuredAt: now)
        input.active = .available(try! EnergyAmount(name == "high-activity" ? 6000 : 382), measuredAt: now)
        let food: Double = name == "amber" ? 1318 : name == "over" ? 1709 : 621
        input.food = .available(try! EnergyAmount(food), measuredAt: now)
        input.protein = .available(try! ProteinAmount(136), measuredAt: now)
        input.weight = .available(try! BodyWeight(80), measuredAt: now)
        input.steps = .available(8429, measuredAt: now)
        if name == "live" { input.workout = .live(try! EnergyAmount(173)) }
        if name == "completed" { input.workout = .recorded(count: 1) }
        if name == "updating" { input.workout = .awaitingHealthData }
        if name == "no-food" { input.food = .unavailable(.noDataOrReadAccess) }
        if name == "no-protein" { input.protein = .unavailable(.noDataOrReadAccess) }
        if name == "stale" { input.active = .stale(try! EnergyAmount(382), measuredAt: now.addingTimeInterval(-14400)) }
        return input
    }
}
#endif
