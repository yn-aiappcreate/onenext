import SwiftUI
import SwiftData

struct GoalDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var goal: Goal

    @State private var showEditSheet = false
    @State private var showTemplatePicker = false
    @State private var showRegenerateConfirm = false
    @State private var showAddStepSheet = false
    @State private var showAIStepSheet = false

    @AppStorage("aiAssistEnabled") private var aiAssistEnabled = true

    private var doneCount: Int {
        goal.steps.filter { $0.status == .done }.count
    }

    private var totalCount: Int {
        goal.steps.count
    }

    private var progress: Double {
        guard totalCount > 0 else { return 0 }
        return Double(doneCount) / Double(totalCount)
    }

    var body: some View {
        List {
            Section("基本情報") {
                LabeledContent("タイトル", value: goal.title)

                if let category = goal.category {
                    LabeledContent("カテゴリ") {
                        Label(category.localizedName, systemImage: category.systemImage)
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

            // MARK: - 進捗
            if !goal.steps.isEmpty {
                Section("進捗") {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("\(doneCount)/\(totalCount) 完了")
                                .font(.headline)
                            Spacer()
                            Text("\(Int(progress * 100))%")
                                .font(.headline)
                                .foregroundStyle(progress >= 1.0 ? .green : .primary)
                        }
                        ProgressView(value: progress)
                            .tint(progress >= 1.0 ? .green : Color.accentColor)
                    }

                    if goal.status == .completed {
                        HStack {
                            Image(systemName: "checkmark.seal.fill")
                                .foregroundStyle(.green)
                            Text("Goal達成！")
                                .foregroundStyle(.green)
                                .fontWeight(.semibold)
                        }
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
                        StepRow(step: step, onStatusChange: { checkGoalCompletion() })
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

                Button {
                    showAddStepSheet = true
                } label: {
                    Label("Stepを手動追加", systemImage: "plus.circle")
                }

                if aiAssistEnabled {
                    Button {
                        showAIStepSheet = true
                    } label: {
                        Label("AIでステップ案を作る", systemImage: "cpu")
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
                LabeledContent("ステータス", value: goal.status.localizedName)
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
        .sheet(isPresented: $showAddStepSheet) {
            ManualStepSheet(goal: goal)
        }
        .sheet(isPresented: $showAIStepSheet) {
            AIStepSheet(goal: goal)
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

    /// 全Step完了時にGoalを自動完了
    private func checkGoalCompletion() {
        guard !goal.steps.isEmpty else { return }
        let allDone = goal.steps.allSatisfy { $0.status == .done || $0.status == .discarded }
        let hasAtLeastOneDone = goal.steps.contains { $0.status == .done }
        if allDone && hasAtLeastOneDone && goal.status != .completed {
            goal.status = .completed
        }
    }
}

// MARK: - StepRow

private struct StepRow: View {
    @Environment(\.modelContext) private var modelContext
    let step: Step
    var onStatusChange: (() -> Void)?
    @Query private var allSlots: [PlanSlot]

    private var isScheduled: Bool {
        step.status == .scheduled
    }

    private var currentWeekSlotCount: Int {
        let weekId = DateHelper.weekId()
        return allSlots.filter { $0.weekId == weekId }.count
    }

    private var canSchedule: Bool {
        currentWeekSlotCount < Constants.maxWeeklySlots
    }

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
                    } else if step.type == .ai {
                        Text("AI生成")
                            .font(.caption2)
                            .foregroundStyle(.purple)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(.purple.opacity(0.15), in: RoundedRectangle(cornerRadius: 3))
                    }
                    if isScheduled {
                        Text("今週枠")
                            .font(.caption2)
                            .foregroundStyle(.white)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(.blue, in: RoundedRectangle(cornerRadius: 3))
                    }
                }
            }

            Spacer()

            if step.status == .pending {
                Button {
                    addToPlan()
                } label: {
                    Image(systemName: "calendar.badge.plus")
                        .foregroundStyle(canSchedule ? Color.accentColor : .secondary)
                }
                .buttonStyle(.plain)
                .disabled(!canSchedule)
            } else if isScheduled {
                Button {
                    removeFromPlan()
                } label: {
                    Image(systemName: "calendar.badge.minus")
                        .foregroundStyle(.orange)
                }
                .buttonStyle(.plain)
            } else if step.status == .done {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
            } else if step.status == .postponed {
                Image(systemName: "arrow.uturn.right.circle")
                    .foregroundStyle(.orange)
            } else if step.status == .discarded {
                Image(systemName: "xmark.circle")
                    .foregroundStyle(.red)
            }
        }
    }

    private func addToPlan() {
        let weekId = DateHelper.weekId()
        let nextIndex = allSlots.filter { $0.weekId == weekId }.count
        let slot = PlanSlot(weekId: weekId, index: nextIndex, step: step)
        modelContext.insert(slot)
        step.status = .scheduled
        step.scheduledAt = Date()
        onStatusChange?()
    }

    private func removeFromPlan() {
        let weekId = DateHelper.weekId()
        if let slot = allSlots.first(where: { $0.weekId == weekId && $0.step?.id == step.id }) {
            modelContext.delete(slot)
        }
        step.status = .pending
        step.scheduledAt = nil
        onStatusChange?()
    }

    private var statusIcon: String {
        switch step.status {
        case .done: "checkmark.circle.fill"
        case .scheduled: "calendar.circle.fill"
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

// MARK: - ManualStepSheet

struct ManualStepSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    let goal: Goal

    @State private var title: String = ""
    @State private var durationMin: Int = Constants.defaultStepDurationMin

    private var isValid: Bool { !title.trimmingCharacters(in: .whitespaces).isEmpty }

    var body: some View {
        NavigationStack {
            Form {
                Section("Step名") {
                    TextField("やること", text: $title)
                }

                Section("所要時間（分）") {
                    Stepper("\(durationMin)分", value: $durationMin, in: 5...240, step: 5)
                }
            }
            .navigationTitle("Stepを追加")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("追加") {
                        addStep()
                        dismiss()
                    }
                    .disabled(!isValid)
                }
            }
        }
    }

    private func addStep() {
        let trimmed = title.trimmingCharacters(in: .whitespaces)
        let nextOrder = (goal.steps.map { $0.sortOrder }.max() ?? -1) + 1
        let step = Step(
            title: trimmed,
            durationMin: durationMin,
            type: .manual,
            sortOrder: nextOrder
        )
        goal.steps.append(step)
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
