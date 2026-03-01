import SwiftUI
import SwiftData

struct BacklogTab: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Goal.createdAt, order: .reverse) private var goals: [Goal]

    @State private var showCreateSheet = false

    var body: some View {
        NavigationStack {
            Group {
                if goals.isEmpty {
                    EmptyStateView(
                        title: "Goalがありません",
                        systemImage: "tray",
                        description: "右上の＋ボタンからGoalを作成しましょう"
                    )
                } else {
                    List {
                        ForEach(goals) { goal in
                            NavigationLink(value: goal) {
                                GoalRow(goal: goal)
                            }
                        }
                        .onDelete(perform: deleteGoals)
                    }
                }
            }
            .navigationTitle("Backlog")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showCreateSheet = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .navigationDestination(for: Goal.self) { goal in
                GoalDetailView(goal: goal)
            }
            .sheet(isPresented: $showCreateSheet) {
                GoalFormSheet()
            }
        }
    }

    private func deleteGoals(at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(goals[index])
        }
    }
}

// MARK: - GoalRow

private struct GoalRow: View {
    let goal: Goal

    var body: some View {
        HStack(spacing: 12) {
            if let category = goal.category {
                Image(systemName: category.systemImage)
                    .foregroundStyle(.accent)
                    .frame(width: 24)
            } else {
                Image(systemName: "target")
                    .foregroundStyle(.secondary)
                    .frame(width: 24)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(goal.title)
                    .font(.body)
                    .lineLimit(1)

                HStack(spacing: 8) {
                    Text("優先度: \(goal.priority.label)")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    if let dueDate = goal.dueDate {
                        Text(dueDate, style: .date)
                            .font(.caption)
                            .foregroundStyle(dueDate < Date() ? .red : .secondary)
                    }

                    if !goal.steps.isEmpty {
                        Text("\(goal.steps.filter { $0.status == .done }.count)/\(goal.steps.count) Steps")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .padding(.vertical, 2)
    }
}

#Preview {
    BacklogTab()
        .modelContainer(for: Goal.self, inMemory: true)
}
