import SwiftUI
import HPCore

enum HPStyle {
    static func color(_ status: BudgetStatus) -> Color {
        switch status { case .available: return Color(red: 0.1, green: 0.62, blue: 0.39)
        case .approachingLimit: return .orange
        case .over: return .red
        case .incomplete: return .secondary }
    }
    static func number(_ value: Int?) -> String { value.map { $0.formatted() } ?? "—" }
    static func description(_ state: DailyEnergyState?) -> String {
        guard let value = state?.caloriesRemaining else { return "Waiting for Health data" }
        if value < 0 { return "\(abs(value).formatted()) kcal over the confirmed allowance" }
        return state?.status == .approachingLimit ? "Near the confirmed allowance" : "Within the confirmed allowance"
    }
}
struct HealthBar: View {
    let fraction: Double?
    let status: BudgetStatus
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Capsule().fill(.primary.opacity(0.08))
                Capsule().fill(HPStyle.color(status).gradient)
                    .frame(width: max(0, geometry.size.width * (fraction ?? 0)))
            }
        }
        .frame(height: 15)
        .animation(reduceMotion ? nil : .smooth(duration: 0.6), value: fraction)
        .accessibilityLabel("Remaining allowance")
        .accessibilityValue(fraction.map { "\(Int(($0 * 100).rounded())) percent" } ?? "Unavailable")
    }
}
struct MetricLabel: View {
    let title: String
    let value: String
    var detail: String? = nil
    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title.uppercased()).font(.caption.weight(.semibold)).foregroundStyle(.secondary)
            Text(value).font(.title2.weight(.medium)).monospacedDigit()
            if let detail { Text(detail).font(.caption).foregroundStyle(.secondary) }
        }.accessibilityElement(children: .combine)
    }
}
extension DailyEnergyState {
    var proteinText: String {
        let consumed = protein.value.map { Int($0.value.rounded()).formatted() } ?? "—"
        return "\(consumed) / \(HPStyle.number(proteinTarget)) g"
    }
    func weightText(unit: WeightUnit) -> String {
        guard let weight = weight.value else { return "—" }
        let value = unit == .kg ? weight.value : weight.value * 2.2046226218
        return "\(value.formatted(.number.precision(.fractionLength(1)))) \(unit.rawValue)"
    }
}
