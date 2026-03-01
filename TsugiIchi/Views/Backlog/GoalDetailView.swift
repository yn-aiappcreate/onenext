import SwiftUI
import SwiftData

struct GoalDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var goal: Goal

    @State private var showEditSheet = false

    var body: some View {
        List {
            Section("基本情報") {
                LabeledContent("タイトル", value: goal.title)

                if let category = goal.category {
                    LabeledContent("カテゴリ") {
                        Label(category.rawValue, systemImage: category.systemImage)
                    }
                }

                LabeledContent("優先度", value: goal.priority.label)

                if let dueDate = goal.dueDate {
                    LabeledContent("期限") {
                        Text(dueDate, style: .date)
                    }
                }

                if let note = goal.note, !note.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("メモ")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(note)
                    }
                }
            }

            Section("ステップ") {
                if goal.steps.isEmpty {
                    ContentUnavailableView(
                        "ステップなし",
                        systemImage: "list.bullet",
                        description: Text("M2でテンプレートからStep自動生成を実装予定")
                    )
                } else {
                    ForEach(goal.steps.sorted(by: { $0.sortOrder < $1.sortOrder })) { step in
                        HStack {
                            Image(systemName: step.status == .done ? "checkmark.circle.fill" : "circle")
                                .foregroundStyle(step.status == .done ? .green : .secondary)
                            VStack(alignment: .leading) {
                                Text(step.title)
                                Text("\(step.durationMin)分")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }

            Section {
                LabeledContent("作成日") {
                    Text(goal.createdAt, style: .date)
                }
                LabeledContent("ステータス", value: goal.status.rawValue)
            }
        }
        .navigationTitle(goal.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showEditSheet = true
                } label: {
                    Text("編集")
                }
            }
        }
        .sheet(isPresented: $showEditSheet) {
            GoalFormSheet(editingGoal: goal)
        }
    }
}

#Preview {
    NavigationStack {
        GoalDetailView(goal: Goal(title: "サンプルGoal", category: .travel, priority: .high))
    }
    .modelContainer(for: Goal.self, inMemory: true)
}
