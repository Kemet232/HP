import Foundation
import Testing
@testable import HPCore
struct BoundaryAndSourceTests {
    func calendar(_ zone: String) -> Calendar { var c = Calendar(identifier: .gregorian); c.timeZone = TimeZone(identifier: zone)!; return c }
    func date(_ string: String) -> Date { ISO8601DateFormatter().date(from: string)! }
    @Test func dstSpring() {
        let day = DayWindow(now: date("2026-03-08T17:00:00Z"), calendar: calendar("America/New_York"))
        #expect(day.end.timeIntervalSince(day.start) == 23 * 3600)
    }
    @Test func dstFall() {
        let day = DayWindow(now: date("2026-11-01T17:00:00Z"), calendar: calendar("America/New_York"))
        #expect(day.end.timeIntervalSince(day.start) == 25 * 3600)
    }
    @Test func midnightAndTimeZone() {
        let now = date("2026-09-17T20:00:00Z")
        let day = DayWindow(now: now, calendar: calendar("Europe/London"))
        #expect(day.contains(day.start))
        #expect(!day.contains(day.end))
        #expect(!day.matches(now: now, calendar: calendar("Asia/Tokyo")))
        #expect(!day.matches(now: day.end, calendar: calendar("Europe/London")))
    }
    @Test func rejectsWrongDay() throws {
        let now = date("2026-09-17T20:00:00Z")
        var input = DailyInput(day: DayWindow(now: now), queriedAt: now)
        input.queriedAt = input.day.end
        #expect(throws: InputError.self) { try EnergyEngine.calculate(input, goal: .maintenance) }
    }
    @Test func nutritionSources() throws {
        let a = NutritionSource(id: "a", name: "Food tracker")
        let b = NutritionSource(id: "b", name: "Duplicate writer")
        #expect(try NutritionSourcePolicy.selectedID(sources: [], preferred: nil).get() == nil)
        #expect(try NutritionSourcePolicy.selectedID(sources: [a, a], preferred: nil).get() == "a")
        #expect(throws: NutritionSourcePolicy.SourceConflict.self) { try NutritionSourcePolicy.selectedID(sources: [a, b], preferred: nil).get() }
        #expect(try NutritionSourcePolicy.selectedID(sources: [a, b], preferred: "a").get() == "a")
        // A selected writer disappearing must not silently switch to another writer.
        #expect(try NutritionSourcePolicy.selectedID(sources: [b], preferred: "a").get() == "a")
    }
}
