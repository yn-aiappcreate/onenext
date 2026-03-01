import SwiftUI
import SwiftData

@main
struct TsugiIchiApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(for: [
            Goal.self,
            Step.self,
            PlanSlot.self,
            ReviewLog.self
        ])
    }
}
