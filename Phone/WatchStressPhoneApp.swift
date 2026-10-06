import SwiftUI

@main
struct WatchStressPhoneApp: App {
    @StateObject private var health = HealthStore()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            NavigationStack {
                SummaryView(health: health)
                    .navigationTitle("压力观察")
                    .navigationBarTitleDisplayMode(.inline)
            }
            .task { await health.refresh() }
            .onChange(of: scenePhase) { _, phase in
                if phase == .active { Task { await health.refresh() } }
            }
        }
    }
}

