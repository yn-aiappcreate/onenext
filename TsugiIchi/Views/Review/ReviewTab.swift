import SwiftUI
import SwiftData

struct ReviewTab: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var allGoals: [Goal]
    @Query private var allSlots: [PlanSlot]
    @Query private var allReviewLogs: [ReviewLog]

    @State private var showGoalPicker = false
    @State private var showAutoPlaceConfirm = false
    @State private var selectedGoal: Goal?

    private var currentWeekId: String { DateHelper.weekId() }

    /// 今週のスケジュール済みで未完了のStep
    private var unfinishedScheduledSteps: [Step] {
        let weekSlots = allSlots.filter { $0.weekId == currentWeekId }
        return weekSlots
            .compactMap { $0.step }
            .filter { $0.status == .scheduled }
            .sorted { $0.sortOrder < $1.sortOrder }
    }

    /// Backlogのアクティブなgoal（Stepあり）
    private var activeGoalsWithSteps: [Goal] {
        allGoals
            .filter { $0.status == .active && !$0.steps.isEmpty }
            .sorted { $0.createdAt > $1.createdAt }
    }

    /// 今週のレビュー済みかどうか
    private var hasReviewedThisWeek: Bool {
        allReviewLogs.contains { $0.weekId == currentWeekId }
    }

    /// 今週のスロット数
    private var currentWeekSlotCount: Int {
        allSlots.filter { $0.weekId == currentWeekId }.count
    }

    var body: some View {
        NavigationStack {
            List {
                // MARK: - Section 1: 未完了の予定Step
                Section {
                    if unfinishedScheduledSteps.isEmpty {
                        VStack(spacing: 8) {
                            Image(systemName: "checkmark.circle")
                                .font(.largeTitle)
                                .foregroundStyle(.green)
                            Text("未完了の予定Stepはありません")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                    } else {
                        ForEach(unfinishedScheduledSteps) { step in
                            ReviewStepRow(
                                step: step,
                                onDone: { markStep(step, as: .done) },
                                onPostpone: { markStep(step, as: .postponed) },
                                onDiscard: { markStep(step, as: .discarded) }
                            )
                        }
                    }
                } header: {
                    HStack {
                        Text("未完了の予定Step")
                        Spacer()
                        if !unfinishedScheduledSteps.isEmpty {
                            Text("\(unfinishedScheduledSteps.count)件")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                // MARK: - Section 2: 今週のGoalを選ぶ
                Section {
                    if activeGoalsWithSteps.isEmpty {
                        VStack(spacing: 8) {
                            Text("Stepを持つアクティブなGoalがありません")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            Text("BacklogタブでGoalを作成し、テンプレートでStepを生成してください")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                    } else {
                        Button {
                            showGoalPicker = true
                        } label: {
                            HStack {
                                Label("今週のGoalを選ぶ", systemImage: "target")
                                Spacer()
                                if let goal = selectedGoal {
                                    Text(goal.title)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(1)
                                }
                                Image(systemName: "chevron.right")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }

                        if let goal = selectedGoal {
                            let pendingSteps = nextPendingSteps(for: goal)
                            if pendingSteps.isEmpty {
                                Text("このGoalにpendingのStepがありません")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            } else {
                                Button {
                                    showAutoPlaceConfirm = true
                                } label: {
                                    Label(
                                        "次の\(pendingSteps.count)Stepを今週枠に配置",
                                        systemImage: "calendar.badge.plus"
                                    )
                                }
                                .disabled(currentWeekSlotCount >= Constants.maxWeeklySlots)

                                ForEach(pendingSteps) { step in
                                    HStack(spacing: 8) {
                                        Image(systemName: "circle")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(step.title)
                                                .font(.subheadline)
                                            Text("\(step.durationMin)分")
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                        }
                                    }
                                    .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                } header: {
                    Text("今週のGoal")
                }

                // MARK: - Section 3: レビュー完了
                Section {
                    if hasReviewedThisWeek {
                        HStack {
                            Image(systemName: "checkmark.seal.fill")
                                .foregroundStyle(.green)
                            Text("今週のレビュー完了済み")
                                .foregroundStyle(.secondary)
                        }
                    } else {
                        Button {
                            completeReview()
                        } label: {
                            Label("レビューを完了する", systemImage: "checkmark.seal")
                        }
                        .disabled(selectedGoal == nil && unfinishedScheduledSteps.isEmpty)
                    }
                } header: {
                    Text("レビュー")
                } footer: {
                    Text("週: \(currentWeekId)")
                        .font(.caption2)
                }
            }
            .navigationTitle("週次レビュー")
            .sheet(isPresented: $showGoalPicker) {
                GoalPickerSheet(
                    goals: activeGoalsWithSteps,
                    selectedGoal: $selectedGoal
                )
            }
            .alert(
                "Stepを今週枠に配置",
                isPresented: $showAutoPlaceConfirm
            ) {
                Button("キャンセル", role: .cancel) {}
                Button("配置する") {
                    autoPlaceSteps()
                }
            } message: {
                if let goal = selectedGoal {
                    let count = nextPendingSteps(for: goal).count
                    Text("\(goal.title) の次の\(count)Stepを今週枠に配置します。")
                }
            }
        }
    }

    /// Goalの次のpending Steps（最大reviewAutoPlaceCount件）
    private func nextPendingSteps(for goal: Goal) -> [Step] {
        let pending = goal.steps
            .filter { $0.status == .pending }
            .sorted { $0.sortOrder < $1.sortOrder }
        let remaining = Constants.maxWeeklySlots - currentWeekSlotCount
        let limit = min(Constants.reviewAutoPlaceCount, remaining)
        return Array(pending.prefix(max(0, limit)))
    }

    /// 選んだGoalの次のpending Stepsを今週枠に自動配置
    private func autoPlaceSteps() {
        guard let goal = selectedGoal else { return }
        let steps = nextPendingSteps(for: goal)
        let weekId = currentWeekId
        var nextIndex = allSlots.filter { $0.weekId == weekId }.count

        for step in steps {
            let slot = PlanSlot(weekId: weekId, index: nextIndex, step: step)
            modelContext.insert(slot)
            step.status = .scheduled
            step.scheduledAt = Date()
            nextIndex += 1
        }
    }

    /// ステップのステータスを変更
    private func markStep(_ step: Step, as newStatus: StepStatus) {
        step.status = newStatus
    }

    /// レビューを完了してReviewLogを記録
    private func completeReview() {
        let log = ReviewLog(weekId: currentWeekId)
        log.selectedGoalId = selectedGoal?.id
        modelContext.insert(log)
    }
}

// MARK: - ReviewStepRow

private struct ReviewStepRow: View {
    let step: Step
    let onDone: () -> Void
    let onPostpone: () -> Void
    let onDiscard: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 12) {
                Image(systemName: "calendar.circle.fill")
                    .foregroundStyle(.blue)
                    .frame(width: 20)

                VStack(alignment: .leading, spacing: 2) {
                    Text(step.title)
                        .font(.body)
                    HStack(spacing: 8) {
                        if let goalTitle = step.goal?.title {
                            Label(goalTitle, systemImage: "target")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                        Label("\(step.durationMin)分", systemImage: "clock")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()
            }

            HStack(spacing: 12) {
                Spacer()
                Button {
                    onDone()
                } label: {
                    Label("完了", systemImage: "checkmark.circle.fill")
                        .font(.caption)
                        .foregroundStyle(.green)
                }
                .buttonStyle(.plain)

                Button {
                    onPostpone()
                } label: {
                    Label("延期", systemImage: "arrow.uturn.right.circle")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
                .buttonStyle(.plain)

                Button {
                    onDiscard()
                } label: {
                    Label("破棄", systemImage: "xmark.circle")
                        .font(.caption)
                        .foregroundStyle(.red)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 2)
    }
}

// MARK: - GoalPickerSheet

struct GoalPickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    let goals: [Goal]
    @Binding var selectedGoal: Goal?

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text("今週注力するGoalを1つ選んでください。選んだGoalの次のStepが今週枠に配置されます。")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Section("Goal一覧") {
                    ForEach(goals) { goal in
                        Button {
                            selectedGoal = goal
                            dismiss()
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(goal.title)
                                        .foregroundStyle(.primary)
                                    HStack(spacing: 8) {
                                        if let category = goal.category {
                                            Label(category.rawValue, systemImage: category.systemImage)
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                        }
                                        let pendingCount = goal.steps.filter { $0.status == .pending }.count
                                        Text("残り\(pendingCount)Step")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                Spacer()
                                if selectedGoal?.id == goal.id {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(Color.accentColor)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Goalを選択")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("閉じる") { dismiss() }
                }
            }
        }
    }
}

#Preview {
    ReviewTab()
        .modelContainer(for: [Goal.self, Step.self, PlanSlot.self, ReviewLog.self], inMemory: true)
}
