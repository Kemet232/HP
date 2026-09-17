import SwiftUI
import WidgetKit
import HPCore

struct HPEntry: TimelineEntry {
    let date: Date
    let state: DailyEnergyState?
}
struct HPProvider: TimelineProvider {
    func placeholder(in context: Context) -> HPEntry { HPEntry(date: .now, state: nil) }
    func getSnapshot(in context: Context, completion: @escaping (HPEntry) -> Void) {
        completion(HPEntry(date: .now, state: SnapshotCache.read()?.usableState(now: .now)))
    }
    func getTimeline(in context: Context, completion: @escaping (Timeline<HPEntry>) -> Void) {
        let now = Date()
        let envelope = SnapshotCache.read()
        let midnight = DayWindow(now: now).end
        var entries = [HPEntry(date: now, state: envelope?.usableState(now: now))]
        // A scheduled stale entry avoids presenting an old snapshot as fresh during throttling.
        if let state = entries.first?.state {
            let staleAt = state.queriedAt.addingTimeInterval(3601)
            if staleAt > now, staleAt < midnight { entries.append(HPEntry(date: staleAt, state: state)) }
        }
        // Pre-schedule clearing at the day boundary; never roll yesterday into today's balance.
        entries.append(HPEntry(date: midnight, state: nil))
        completion(Timeline(entries: entries.sorted { $0.date < $1.date }, policy: .after(min(now.addingTimeInterval(1800), midnight))))
    }
}
struct HPWidgetView: View {
    let entry: HPEntry
    @Environment(\.widgetFamily) private var family
    private var state: DailyEnergyState? { entry.state?.day.matches(now: entry.date) == true ? entry.state : nil }
    var body: some View {
        Group {
            switch family {
            case .accessoryCircular:
                Gauge(value: state?.remainingFraction ?? 0) {
                    Text("HP")
                } currentValueLabel: {
                    Text(HPStyle.number(state?.caloriesRemaining)).font(.system(.caption, design: .rounded)).minimumScaleFactor(0.4)
                }.gaugeStyle(.accessoryCircularCapacity)
            case .accessoryInline:
                Text("HP \(HPStyle.number(state?.caloriesRemaining)) kcal\(isStale ? " · earlier" : " left")")
            #if os(watchOS)
            case .accessoryCorner:
                Text(HPStyle.number(state?.caloriesRemaining)).font(.system(.title3, design: .rounded)).widgetLabel { Text(isStale ? "HP · Earlier" : "KCAL LEFT") }
            #endif
            case .accessoryRectangular:
                VStack(alignment: .leading, spacing: 4) {
                    Text("\(HPStyle.number(state?.caloriesRemaining)) KCAL LEFT").font(.headline).minimumScaleFactor(0.5).lineLimit(1)
                    HealthBar(fraction: state?.remainingFraction, status: state?.status ?? .incomplete).frame(maxHeight: 10)
                    Text(isStale ? "Earlier snapshot" : state == nil ? "Open HP on iPhone" : "Confirmed so far").font(.caption2)
                }
            default:
                HStack(alignment: .center, spacing: 20) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("HP").font(.caption.weight(.bold)).foregroundStyle(.secondary)
                        Text(HPStyle.number(state?.caloriesRemaining)).font(.system(size: 40, weight: .semibold, design: .rounded)).minimumScaleFactor(0.4).lineLimit(1)
                        Text("KCAL LEFT").font(.caption2.weight(.semibold)).foregroundStyle(.secondary)
                        HealthBar(fraction: state?.remainingFraction, status: state?.status ?? .incomplete)
                        Text(isStale ? "Earlier snapshot" : state == nil ? "Open HP" : "Confirmed so far").font(.caption2).foregroundStyle(.secondary)
                    }
                    #if os(iOS)
                    if family == .systemMedium {
                        VStack(alignment: .leading, spacing: 16) {
                            Text("\(HPStyle.number(state?.eatenKcal)) eaten")
                            Text(state?.proteinText ?? "— g protein")
                        }.font(.subheadline).monospacedDigit()
                    }
                    #endif
                }
            }
        }
        .containerBackground(for: .widget) { Color(.black).opacity(0.04) }
        .widgetURL(URL(string: "hp://today"))
        .privacySensitive()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(state?.caloriesRemaining.map { "\($0) kilocalories remaining. \(isStale ? "Earlier snapshot." : "Confirmed so far.")" } ?? "HP balance unavailable. Open HP on iPhone.")
    }
    private var isStale: Bool { state?.isOutdated(at: entry.date) ?? false }
}
@main struct HPWidgets: Widget {
    let kind = "HPBalance"
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: HPProvider()) { HPWidgetView(entry: $0) }
            .configurationDisplayName("HP · Calories left")
            .description("Your confirmed daily energy balance.")
            #if os(watchOS)
            .supportedFamilies([.accessoryCircular, .accessoryRectangular, .accessoryInline, .accessoryCorner])
            #else
            .supportedFamilies([.systemSmall, .systemMedium, .accessoryCircular, .accessoryRectangular, .accessoryInline])
            #endif
    }
}
