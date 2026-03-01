import SwiftUI
import SwiftData

struct BacklogTab: View {
    var body: some View {
        NavigationStack {
            Text("Backlog")
                .font(.title)
                .foregroundStyle(.secondary)
                .navigationTitle("Backlog")
        }
    }
}

#Preview {
    BacklogTab()
        .modelContainer(for: Goal.self, inMemory: true)
}
