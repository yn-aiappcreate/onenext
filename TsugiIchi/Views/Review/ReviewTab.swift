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

    // MARK: - Undo support
    @State private var undoStep: Step?
    @State private var undoPreviousStatus: StepStatus?
    @State private var showUndoBanner = false

    private var currentWeekId: String { DateHelper.weekId() }

    /// 今週のスケジュール済みで未完了のStep
    private var unfinishedScheduledSteps: [Step] {
        let weekSlots = allSlots.filter { $0.weekId == currentWeekId }
        return weekSlots
            .compactMap { $0.step }
            .filter { $0.status == .scheduled }
            .sorted { $0.sortOrder < $1.sortOrder }
    }

    /// 今週の完了Step数
    private var weekDoneCount: Int {
        weekStepsAll.filter { $0.status == .done }.count
    }

    /// 今週の延期Step数
    private var weekPostponedCount: Int {
        weekStepsAll.filter { $0.status == .postponed }.count
    }

    /// 今週の破棄Step数
    private var weekDiscardedCount: Int {
        weekStepsAll.filter { $0.status == .discarded }.count
    }

    /// 今週の全Step（スロットに紐づくもの全て、orphaned slots除外）
    private var weekStepsAll: [Step] {
        allSlots.filter { $0.weekId == currentWeekId && $0.step != nil }.compactMap { $0.step }
    }

    /// 延期済みのStep（再スケジュール候補）
    private var postponedSteps: [Step] {
        allGoals
            .flatMap { $0.steps }
            .filter { $0.status == .postponed }
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

    /// 今週のスロット数（orphaned slots除外）
    private var currentWeekSlotCount: Int {
        allSlots.filter { $0.weekId == currentWeekId && $0.step != nil }.count
    }

    var body: some View {
        NavigationStack {
            List {
                // MARK: - Section 0: 今週のサマリー
                if !weekStepsAll.isEmpty {
                    Section("今週のサマリー") {
                        HStack {
                            SummaryBadge(count: weekDoneCount, label: "完了", color: .green, icon: "checkmark.circle.fill")
                            Spacer()
                            SummaryBadge(count: weekPostponedCount, label: "延期", color: .orange, icon: "arrow.uturn.right.circle")
                            Spacer()
                            SummaryBadge(count: weekDiscardedCount, label: "破棄", color: .red, icon: "xmark.circle")
                        }
                        .padding(.vertical, 4)
                    }
                }

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

                // MARK: - Section 1.5: 延期済みStepの再スケジュール
                if !postponedSteps.isEmpty {
                    Section {
                        ForEach(postponedSteps) { step in
                            HStack(spacing: 12) {
                                Image(systemName: "arrow.uturn.right.circle")
                                    .foregroundStyle(.orange)
                                    .frame(width: 20)

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(step.title)
                                        .font(.body)
                                    if let goalTitle = step.goal?.title {
                                        Text(goalTitle)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }

                                Spacer()

                                Button {
                                    rescheduleStep(step)
                                } label: {
                                    Label("再配置", systemImage: "calendar.badge.plus")
                                        .font(.caption)
                                }
                                .buttonStyle(.bordered)
                                .controlSize(.small)
                                .disabled(currentWeekSlotCount >= Constants.maxWeeklySlots)
                            }
                        }
                    } header: {
                        HStack {
                            Text("延期中のStep")
                            Spacer()
                            Text("\(postponedSteps.count)件")
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
            .overlay(alignment: .bottom) {
                if showUndoBanner, let step = undoStep {
                    undoBannerView(stepTitle: step.title)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
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

    // MARK: - Undo Banner

    private func undoBannerView(stepTitle: String) -> some View {
        HStack {
            Image(systemName: "arrow.uturn.backward.circle.fill")
                .foregroundStyle(.white)
            Text("\(stepTitle) を変更しました")
                .font(.subheadline)
                .foregroundStyle(.white)
                .lineLimit(1)
            Spacer()
            Button("元に戻す") {
                performUndo()
            }
            .font(.subheadline.bold())
            .foregroundStyle(.white)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color(.systemGray2), in: RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal, 16)
        .padding(.bottom, 8)
    }

    /// ステップのステータスを変更
    private func markStep(_ step: Step, as newStatus: StepStatus) {
        // Save previous state for undo
        undoStep = step
        undoPreviousStatus = step.status

        step.status = newStatus
        checkGoalCompletion(for: step)

        // Show undo banner
        withAnimation { showUndoBanner = true }
        // Auto-dismiss after 5 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
            withAnimation { showUndoBanner = false }
        }
    }

    private func performUndo() {
        guard let step = undoStep, let previousStatus = undoPreviousStatus else { return }
        step.status = previousStatus
        // Reverse goal auto-completion if needed
        if let goal = step.goal, goal.status == .completed {
            let allDone = goal.steps.allSatisfy { $0.status == .done || $0.status == .discarded }
            if !allDone {
                goal.status = .active
            }
        }
        withAnimation {
            showUndoBanner = false
            undoStep = nil
            undoPreviousStatus = nil
        }
    }

    /// 延期Stepを今週枠に再配置
    private func rescheduleStep(_ step: Step) {
        let weekId = currentWeekId
        let nextIndex = allSlots.filter { $0.weekId == weekId }.count
        let slot = PlanSlot(weekId: weekId, index: nextIndex, step: step)
        modelContext.insert(slot)
        step.status = .scheduled
        step.scheduledAt = Date()
    }

    /// 全Step完了時にGoalを自動完了
    private func checkGoalCompletion(for step: Step) {
        guard let goal = step.goal, !goal.steps.isEmpty else { return }
        let allDone = goal.steps.allSatisfy { $0.status == .done || $0.status == .discarded }
        let hasAtLeastOneDone = goal.steps.contains { $0.status == .done }
        if allDone && hasAtLeastOneDone && goal.status != .completed {
            goal.status = .completed
        }
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
                                            Label(category.localizedName, systemImage: category.systemImage)
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

// MARK: - SummaryBadge

private struct SummaryBadge: View {
    let count: Int
    let label: String
    let color: Color
    let icon: String

    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(color)
            Text("\(count)")
                .font(.title3)
                .fontWeight(.bold)
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

#Preview {
    ReviewTab()
        .modelContainer(for: [Goal.self, Step.self, PlanSlot.self, ReviewLog.self], inMemory: true)
}
