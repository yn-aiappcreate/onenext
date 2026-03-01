import SwiftUI

struct ContentView: View {
    var body: some View {
        TabView {
            BacklogTab()
                .tabItem {
                    Label("Backlog", systemImage: "tray.full")
                }

            PlanTab()
                .tabItem {
                    Label("Plan", systemImage: "calendar")
                }

            ReviewTab()
                .tabItem {
                    Label("Review", systemImage: "checkmark.circle")
                }

            SettingsTab()
                .tabItem {
                    Label("Settings", systemImage: "gearshape")
                }
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [
            Goal.self,
            Step.self,
            PlanSlot.self,
            ReviewLog.self
        ], inMemory: true)
}
