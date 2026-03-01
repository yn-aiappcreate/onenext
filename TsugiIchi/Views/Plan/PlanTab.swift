import SwiftUI
import SwiftData

struct PlanTab: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var allSlots: [PlanSlot]

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
                                PlanSlotRow(slot: slot, step: step) {
                                    removeFromPlan(slot: slot, step: step)
                                }
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
    }

    private func formattedDuration(_ minutes: Int) -> String {
        if minutes < 60 {
            return "\(minutes)分"
        }
        let hours = minutes / 60
        let remaining = minutes % 60
        if remaining == 0 {
            return "\(hours)時間"
        }
        return "\(hours)時間\(remaining)分"
    }
}

// MARK: - PlanSlotRow

private struct PlanSlotRow: View {
    let slot: PlanSlot
    let step: Step
    let onRemove: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
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

            Button {
                onRemove()
            } label: {
                Image(systemName: "minus.circle.fill")
                    .foregroundStyle(.red)
                    .font(.title3)
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 2)
    }
}

#Preview {
    PlanTab()
        .modelContainer(for: [PlanSlot.self, Goal.self, Step.self], inMemory: true)
}
