#if DEBUG
import SwiftUI
import WidgetKit
import HPCore
private var exampleEntry: HPEntry {
    HPEntry(date: .now, state: try? EnergyEngine.calculate(DebugScenarios.input("normal"), goal: GoalConfiguration(goal: .lose, dailyMagnitude: 400)))
}
#Preview(as: .accessoryCircular) { HPWidgets() } timeline: { exampleEntry }
#Preview(as: .accessoryRectangular) { HPWidgets() } timeline: { exampleEntry }
#Preview(as: .accessoryInline) { HPWidgets() } timeline: { exampleEntry }
#if os(iOS)
#Preview(as: .systemSmall) { HPWidgets() } timeline: { exampleEntry }
#Preview(as: .systemMedium) { HPWidgets() } timeline: { exampleEntry }
#else
#Preview(as: .accessoryCorner) { HPWidgets() } timeline: { exampleEntry }
#endif
#endif
