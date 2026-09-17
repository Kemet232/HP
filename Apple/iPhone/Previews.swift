#if DEBUG
import SwiftUI
#Preview("847 · green") { HomeView(model: AppModel(debugScenario: "normal")) }
#Preview("150 · amber") { HomeView(model: AppModel(debugScenario: "amber")) }
#Preview("−241 · over") { HomeView(model: AppModel(debugScenario: "over")) }
#Preview("Live · excluded from balance") { HomeView(model: AppModel(debugScenario: "live")) }
#Preview("Health data unavailable") { HomeView(model: AppModel(debugScenario: "missing")) }
#Preview("Read access unavailable") { HomeView(model: AppModel(debugScenario: "read-unavailable")) }
#Preview("Accessibility") { HomeView(model: AppModel(debugScenario: "normal")).environment(\.dynamicTypeSize, .accessibility3) }
#Preview("Dark") { HomeView(model: AppModel(debugScenario: "normal")).preferredColorScheme(.dark) }
#Preview("Light") { HomeView(model: AppModel(debugScenario: "normal")).preferredColorScheme(.light) }
#Preview("Stale") { HomeView(model: AppModel(debugScenario: "stale")) }
#endif
