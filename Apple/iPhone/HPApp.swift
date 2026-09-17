import SwiftUI

@main struct HPApp: App {
    @State private var model = AppModel()
    @Environment(\.scenePhase) private var phase
    var body: some Scene {
        WindowGroup {
            Group {
                if model.preferences.onboarded { HomeView(model: model) }
                else { OnboardingView(model: model) }
            }
            .tint(.green)
            .task { if model.preferences.onboarded { await model.refresh() } }
            .onChange(of: phase) { _, phase in
                if phase == .active, model.preferences.onboarded { Task { await model.refresh() } }
            }
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.significantTimeChangeNotification)) { _ in
                if model.preferences.onboarded { Task { await model.refresh() } }
            }
        }
    }
}
