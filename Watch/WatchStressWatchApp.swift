import SwiftUI

@main
struct WatchStressWatchApp: App {
    @StateObject private var health = HealthStore()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            SummaryView(health: health)
                .task { await health.refresh() }
                .onChange(of: scenePhase) { _, phase in
                    if phase == .active { Task { await health.refresh() } }
                }
        }
    }
}

