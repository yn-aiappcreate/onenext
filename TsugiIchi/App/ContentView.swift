import SwiftUI

struct ContentView: View {
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false

    var body: some View {
        if hasCompletedOnboarding {
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

                DashboardTab()
                    .tabItem {
                        Label("Stats", systemImage: "chart.bar")
                    }

                SettingsTab()
                    .tabItem {
                        Label("Settings", systemImage: "gearshape")
                    }
            }
        } else {
            OnboardingView(hasCompletedOnboarding: $hasCompletedOnboarding)
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
