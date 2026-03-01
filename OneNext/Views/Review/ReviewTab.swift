import SwiftUI
import SwiftData

struct ReviewTab: View {
    var body: some View {
        NavigationStack {
            Text("Review")
                .font(.title)
                .foregroundStyle(.secondary)
                .navigationTitle("週次レビュー")
        }
    }
}

#Preview {
    ReviewTab()
        .modelContainer(for: ReviewLog.self, inMemory: true)
}
