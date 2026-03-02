import SwiftUI
import SwiftData

struct BacklogTab: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Goal.createdAt, order: .reverse) private var goals: [Goal]
    @ObservedObject private var entitlements = EntitlementStore.shared

    @State private var showCreateSheet = false
    @State private var showPaywall = false

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
                        if !entitlements.isPro && activeGoalCount >= SubscriptionManager.freeGoalLimit {
                            showPaywall = true
                        } else {
                            showCreateSheet = true
                        }
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
            .sheet(isPresented: $showPaywall) {
                PaywallView()
            }
        }
    }

    /// Count of active (non-completed) goals for free tier limit check.
    private var activeGoalCount: Int {
        goals.filter { $0.status != .completed }.count
    }

    private func deleteGoals(at offsets: IndexSet) {
        for index in offsets {
            let goal = goals[index]
            // Clean up PlanSlots that reference this goal's steps before cascade delete
            cleanUpPlanSlots(for: goal)
            modelContext.delete(goal)
        }
    }

    /// Remove PlanSlots whose step belongs to the given goal (prevents orphaned slots after cascade delete)
    private func cleanUpPlanSlots(for goal: Goal) {
        let stepIds = Set(goal.steps.map { $0.id })
        let descriptor = FetchDescriptor<PlanSlot>()
        guard let allSlots = try? modelContext.fetch(descriptor) else { return }
        for slot in allSlots {
            if let step = slot.step, stepIds.contains(step.id) {
                modelContext.delete(slot)
            }
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
                    .foregroundStyle(Color.accentColor)
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
