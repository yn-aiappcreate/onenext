import SwiftUI
import SwiftData

struct GoalFormSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    var editingGoal: Goal?

    @State private var title: String = ""
    @State private var category: GoalCategory?
    @State private var priority: GoalPriority = .medium
    @State private var dueDate: Date?
    @State private var hasDueDate: Bool = false
    @State private var note: String = ""

    private var isEditing: Bool { editingGoal != nil }
    private var isValid: Bool { !title.trimmingCharacters(in: .whitespaces).isEmpty }

    var body: some View {
        NavigationStack {
            Form {
                Section("タイトル") {
                    TextField("やりたいこと", text: $title)
                }

                Section("カテゴリ") {
                    Picker("カテゴリ", selection: $category) {
                        Text("未設定").tag(GoalCategory?.none)
                        ForEach(GoalCategory.allCases) { cat in
                            Label(cat.rawValue, systemImage: cat.systemImage)
                                .tag(GoalCategory?.some(cat))
                        }
                    }
                    .pickerStyle(.menu)
                }

                Section("優先度") {
                    Picker("優先度", selection: $priority) {
                        ForEach(GoalPriority.allCases) { p in
                            Text(p.label).tag(p)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                Section("期限") {
                    Toggle("期限を設定", isOn: $hasDueDate)
                    if hasDueDate {
                        DatePicker(
                            "期限日",
                            selection: Binding(
                                get: { dueDate ?? Date() },
                                set: { dueDate = $0 }
                            ),
                            displayedComponents: .date
                        )
                    }
                }

                Section("メモ") {
                    TextField("メモ（任意）", text: $note, axis: .vertical)
                        .lineLimit(3...6)
                }
            }
            .navigationTitle(isEditing ? "Goal を編集" : "Goal を作成")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(isEditing ? "保存" : "作成") {
                        save()
                        dismiss()
                    }
                    .disabled(!isValid)
                }
            }
            .onAppear {
                if let goal = editingGoal {
                    title = goal.title
                    category = goal.category
                    priority = goal.priority
                    dueDate = goal.dueDate
                    hasDueDate = goal.dueDate != nil
                    note = goal.note ?? ""
                }
            }
        }
    }

    private func save() {
        let trimmedTitle = title.trimmingCharacters(in: .whitespaces)
        let trimmedNote = note.trimmingCharacters(in: .whitespaces)

        if let goal = editingGoal {
            goal.title = trimmedTitle
            goal.category = category
            goal.priority = priority
            goal.dueDate = hasDueDate ? dueDate : nil
            goal.note = trimmedNote.isEmpty ? nil : trimmedNote
        } else {
            let goal = Goal(
                title: trimmedTitle,
                category: category,
                priority: priority,
                dueDate: hasDueDate ? dueDate : nil,
                note: trimmedNote.isEmpty ? nil : trimmedNote
            )
            modelContext.insert(goal)
        }
    }
}

#Preview("Create") {
    GoalFormSheet()
        .modelContainer(for: Goal.self, inMemory: true)
}
