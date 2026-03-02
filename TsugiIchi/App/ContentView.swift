import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
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
            .onAppear {
                cleanUpOrphanedPlanSlots()
            }
        } else {
            OnboardingView(hasCompletedOnboarding: $hasCompletedOnboarding)
        }
    }

    /// Remove PlanSlots whose step has been deleted (orphaned by cascade delete)
    private func cleanUpOrphanedPlanSlots() {
        let descriptor = FetchDescriptor<PlanSlot>()
        guard let allSlots = try? modelContext.fetch(descriptor) else { return }
        for slot in allSlots {
            if slot.step == nil {
                modelContext.delete(slot)
            }
        }
        try? modelContext.save()
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
