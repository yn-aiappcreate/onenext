import SwiftUI
import SwiftData

struct PlanTab: View {
    var body: some View {
        NavigationStack {
            Text("Plan")
                .font(.title)
                .foregroundStyle(.secondary)
                .navigationTitle("今週のプラン")
        }
    }
}

#Preview {
    PlanTab()
        .modelContainer(for: PlanSlot.self, inMemory: true)
}
