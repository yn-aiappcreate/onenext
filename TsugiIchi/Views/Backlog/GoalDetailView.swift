import SwiftUI
import SwiftData

struct GoalDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var goal: Goal

    @State private var showEditSheet = false
    @State private var showTemplatePicker = false
    @State private var showRegenerateConfirm = false

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

            Section {
                if goal.steps.isEmpty {
                    if goal.category != nil {
                        Button {
                            showTemplatePicker = true
                        } label: {
                            Label("テンプレートからStep生成", systemImage: "wand.and.stars")
                        }
                    } else {
                        VStack(spacing: 8) {
                            Text("ステップなし")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            Text("カテゴリを設定するとテンプレートからStepを自動生成できます")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                    }
                } else {
                    ForEach(sortedSteps) { step in
                        StepRow(step: step)
                    }

                    if goal.category != nil {
                        Button {
                            showRegenerateConfirm = true
                        } label: {
                            Label("テンプレートで再生成", systemImage: "arrow.clockwise")
                                .foregroundStyle(.red)
                        }
                    }
                }
            } header: {
                HStack {
                    Text("ステップ")
                    Spacer()
                    if !goal.steps.isEmpty {
                        Text("\(goal.steps.count)件")
                            .font(.caption)
                            .foregroundStyle(.secondary)
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
        .sheet(isPresented: $showTemplatePicker) {
            TemplatePickerSheet(goal: goal)
        }
        .alert("Stepを再生成しますか？", isPresented: $showRegenerateConfirm) {
            Button("キャンセル", role: .cancel) {}
            Button("再生成", role: .destructive) {
                regenerateSteps()
            }
        } message: {
            Text("既存の\(goal.steps.count)件のStepは削除され、テンプレートから新しいStepが生成されます。")
        }
    }

    private var sortedSteps: [Step] {
        goal.steps.sorted { $0.sortOrder < $1.sortOrder }
    }

    private func regenerateSteps() {
        guard let category = goal.category else { return }
        // Delete existing steps
        for step in goal.steps {
            modelContext.delete(step)
        }
        goal.steps.removeAll()
        // Generate new steps
        TemplateEngine.generateSteps(for: goal, category: category)
    }
}

// MARK: - StepRow

private struct StepRow: View {
    let step: Step

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: statusIcon)
                .foregroundStyle(statusColor)
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 2) {
                Text(step.title)
                    .font(.body)
                HStack(spacing: 8) {
                    Label("\(step.durationMin)分", systemImage: "clock")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    if step.type == .auto {
                        Text("自動生成")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(.secondary.opacity(0.15), in: RoundedRectangle(cornerRadius: 3))
                    }
                }
            }
        }
    }

    private var statusIcon: String {
        switch step.status {
        case .done: "checkmark.circle.fill"
        case .scheduled: "calendar.circle"
        case .postponed: "arrow.uturn.right.circle"
        case .discarded: "xmark.circle"
        case .pending: "circle"
        }
    }

    private var statusColor: Color {
        switch step.status {
        case .done: .green
        case .scheduled: .blue
        case .postponed: .orange
        case .discarded: .red
        case .pending: .secondary
        }
    }
}

// MARK: - TemplatePickerSheet

struct TemplatePickerSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    let goal: Goal

    @State private var selectedCategory: GoalCategory?
    @State private var previewTemplates: [TemplateEngine.StepTemplate] = []

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text("カテゴリに応じたテンプレートからStepを自動生成します。")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Section("カテゴリを選択") {
                    ForEach(GoalCategory.allCases) { category in
                        Button {
                            selectedCategory = category
                            previewTemplates = TemplateEngine.templates(for: category)
                        } label: {
                            HStack {
                                Label(category.rawValue, systemImage: category.systemImage)
                                    .foregroundStyle(.primary)
                                Spacer()
                                if selectedCategory == category {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(Color.accentColor)
                                }
                            }
                        }
                    }
                }

                if !previewTemplates.isEmpty {
                    Section("生成されるStep（\(previewTemplates.count)件）") {
                        ForEach(Array(previewTemplates.enumerated()), id: \.offset) { index, template in
                            HStack {
                                Text("\(index + 1).")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .frame(width: 20)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(template.title)
                                    Text("\(template.durationMin)分")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("テンプレート選択")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("生成") {
                        generateSteps()
                        dismiss()
                    }
                    .disabled(selectedCategory == nil)
                }
            }
            .onAppear {
                if let category = goal.category {
                    selectedCategory = category
                    previewTemplates = TemplateEngine.templates(for: category)
                }
            }
        }
    }

    private func generateSteps() {
        guard let category = selectedCategory else { return }
        // Update goal category if different
        if goal.category != category {
            goal.category = category
        }
        TemplateEngine.generateSteps(for: goal, category: category)
    }
}

#Preview {
    NavigationStack {
        GoalDetailView(goal: Goal(title: "サンプルGoal", category: .travel, priority: .high))
    }
    .modelContainer(for: Goal.self, inMemory: true)
}
