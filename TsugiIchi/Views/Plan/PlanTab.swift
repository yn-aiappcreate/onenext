import SwiftUI
import SwiftData

struct PlanTab: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var allSlots: [PlanSlot]
    @Query private var allGoals: [Goal]
    @AppStorage("calendarSyncEnabled") private var calendarSyncEnabled = false

    private var currentWeekId: String { DateHelper.weekId() }

    private var weekSlots: [PlanSlot] {
        allSlots
            .filter { $0.weekId == currentWeekId }
            .sorted { $0.index < $1.index }
    }

    private var totalMinutes: Int {
        weekSlots.compactMap { $0.step?.durationMin }.reduce(0, +)
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack {
                        Label("今週", systemImage: "calendar")
                        Spacer()
                        Text(currentWeekId)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    HStack {
                        Text("予定Step")
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text("\(weekSlots.count)件")
                            .font(.headline)
                    }

                    HStack {
                        Text("合計時間")
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text(formattedDuration(totalMinutes))
                            .font(.headline)
                    }
                } header: {
                    Text("サマリー")
                }

                Section {
                    if weekSlots.isEmpty {
                        VStack(spacing: 8) {
                            Image(systemName: "calendar.badge.plus")
                                .font(.largeTitle)
                                .foregroundStyle(.secondary)
                            Text("今週のプランはまだありません")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            Text("Goal詳細画面からStepを今週枠に追加できます")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 20)
                    } else {
                        ForEach(weekSlots) { slot in
                            if let step = slot.step {
                                PlanSlotRow(
                                    slot: slot,
                                    step: step,
                                    onRemove: { removeFromPlan(slot: slot, step: step) },
                                    onDone: { markStep(step, as: .done) },
                                    onPostpone: { markStep(step, as: .postponed) },
                                    onDiscard: { markStep(step, as: .discarded) }
                                )
                            }
                        }
                    }
                } header: {
                    HStack {
                        Text("今週のStep")
                        Spacer()
                        if !weekSlots.isEmpty {
                            Text("上限 \(Constants.maxWeeklySlots)件")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .navigationTitle("今週のプラン")
        }
    }

    private func removeFromPlan(slot: PlanSlot, step: Step) {
        step.status = .pending
        step.scheduledAt = nil
        modelContext.delete(slot)
        if calendarSyncEnabled {
            CalendarService.removeEvent(for: step.id)
        }
    }

    private func markStep(_ step: Step, as newStatus: StepStatus) {
        step.status = newStatus
        checkGoalCompletion(for: step)
        if calendarSyncEnabled {
            switch newStatus {
            case .done:
                CalendarService.markEventDone(for: step.id)
            case .postponed, .discarded:
                CalendarService.removeEvent(for: step.id)
            default:
                break
            }
        }
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

    private func formattedDuration(_ minutes: Int) -> String {
        if minutes < 60 {
            return String(localized: "\(minutes)分")
        }
        let hours = minutes / 60
        let remaining = minutes % 60
        if remaining == 0 {
            return String(localized: "\(hours)時間")
        }
        return String(localized: "\(hours)時間\(remaining)分")
    }
}

// MARK: - PlanSlotRow

private struct PlanSlotRow: View {
    let slot: PlanSlot
    let step: Step
    let onRemove: () -> Void
    let onDone: () -> Void
    let onPostpone: () -> Void
    let onDiscard: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 12) {
                Image(systemName: stepStatusIcon)
                    .foregroundStyle(stepStatusColor)
                    .frame(width: 20)

                VStack(alignment: .leading, spacing: 4) {
                    Text(step.title)
                        .font(.body)
                        .strikethrough(step.status == .done || step.status == .discarded)
                        .foregroundStyle(step.status == .discarded ? .secondary : .primary)

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

            if step.status == .scheduled {
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
            } else {
                HStack {
                    Spacer()
                    Text(stepStatusLabel)
                        .font(.caption)
                        .foregroundStyle(stepStatusColor)
                }
            }
        }
        .padding(.vertical, 2)
    }

    private var stepStatusIcon: String {
        switch step.status {
        case .done: "checkmark.circle.fill"
        case .scheduled: "calendar.circle.fill"
        case .postponed: "arrow.uturn.right.circle"
        case .discarded: "xmark.circle"
        case .pending: "circle"
        }
    }

    private var stepStatusColor: Color {
        switch step.status {
        case .done: .green
        case .scheduled: .blue
        case .postponed: .orange
        case .discarded: .red
        case .pending: .secondary
        }
    }

    private var stepStatusLabel: String {
        switch step.status {
        case .done: String(localized: "完了済み")
        case .postponed: String(localized: "延期済み")
        case .discarded: String(localized: "破棄済み")
        default: ""
        }
    }
}

#Preview {
    PlanTab()
        .modelContainer(for: [PlanSlot.self, Goal.self, Step.self], inMemory: true)
}
