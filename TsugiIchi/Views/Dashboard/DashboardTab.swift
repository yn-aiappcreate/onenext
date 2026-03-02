import SwiftUI
import SwiftData

struct DashboardTab: View {
    @Query private var allGoals: [Goal]
    @Query private var allSteps: [Step]
    @Query private var allSlots: [PlanSlot]

    @State private var selectedPeriod: StatsPeriod = .week

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    periodPicker
                    summaryCards
                    completionChart
                    categoryBreakdown
                    recentAchievements
                }
                .padding()
            }
            .navigationTitle("ダッシュボード")
            .background(Color(.systemGroupedBackground))
        }
    }

    // MARK: - Period Picker

    private var periodPicker: some View {
        Picker("期間", selection: $selectedPeriod) {
            ForEach(StatsPeriod.allCases) { period in
                Text(period.label).tag(period)
            }
        }
        .pickerStyle(.segmented)
    }

    // MARK: - Summary Cards

    private var summaryCards: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            StatCard(
                title: String(localized: "完了Step"),
                value: "\(completedStepsInPeriod)",
                icon: "checkmark.circle.fill",
                color: .green
            )
            StatCard(
                title: String(localized: "完了率"),
                value: "\(completionRateInPeriod)%",
                icon: "chart.pie.fill",
                color: .blue
            )
            StatCard(
                title: String(localized: "達成Goal"),
                value: "\(completedGoalsInPeriod)",
                icon: "trophy.fill",
                color: .yellow
            )
            StatCard(
                title: String(localized: "合計時間"),
                value: totalTimeLabel,
                icon: "clock.fill",
                color: .purple
            )
        }
    }

    // MARK: - Completion Chart

    private var completionChart: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("完了率推移")
                .font(.headline)

            VStack(spacing: 8) {
                ForEach(chartData, id: \.label) { entry in
                    HStack(spacing: 8) {
                        Text(entry.label)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .frame(width: 50, alignment: .trailing)

                        GeometryReader { geometry in
                            ZStack(alignment: .leading) {
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(Color(.systemGray5))
                                    .frame(height: 20)

                                RoundedRectangle(cornerRadius: 4)
                                    .fill(barColor(for: entry.rate))
                                    .frame(width: max(0, geometry.size.width * entry.rate), height: 20)
                            }
                        }
                        .frame(height: 20)

                        Text("\(Int(entry.rate * 100))%")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .frame(width: 36, alignment: .trailing)
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Category Breakdown

    private var categoryBreakdown: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("カテゴリ別")
                .font(.headline)

            if categoryStats.isEmpty {
                Text("データなし")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
            } else {
                ForEach(categoryStats, id: \.category) { stat in
                    HStack(spacing: 12) {
                        Image(systemName: stat.category.systemImage)
                            .foregroundStyle(Color.accentColor)
                            .frame(width: 24)

                        Text(stat.category.localizedName)
                            .font(.subheadline)

                        Spacer()

                        Text("\(stat.completed)/\(stat.total)")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)

                        CircularProgress(progress: stat.total > 0 ? Double(stat.completed) / Double(stat.total) : 0)
                            .frame(width: 28, height: 28)
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Recent Achievements

    private var recentAchievements: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("最近の達成")
                .font(.headline)

            if recentCompletedGoals.isEmpty {
                Text("まだGoalが達成されていません")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
            } else {
                ForEach(recentCompletedGoals) { goal in
                    HStack(spacing: 12) {
                        Image(systemName: "trophy.fill")
                            .foregroundStyle(.yellow)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(goal.title)
                                .font(.subheadline)
                                .fontWeight(.medium)
                            Text("\(goal.steps.count) Steps")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        if let category = goal.category {
                            Image(systemName: category.systemImage)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Computed Properties

    private var periodStartDate: Date {
        let calendar = Calendar(identifier: .iso8601)
        switch selectedPeriod {
        case .week:
            return DateHelper.startOfWeek()
        case .month:
            return calendar.date(from: calendar.dateComponents([.year, .month], from: Date())) ?? Date()
        case .all:
            return Date.distantPast
        }
    }

    private var completedStepsInPeriod: Int {
        allSteps.filter { step in
            step.status == .done && isInPeriod(step.scheduledAt)
        }.count
    }

    private var completionRateInPeriod: Int {
        let relevantSteps = allSteps.filter { step in
            (step.status == .done || step.status == .scheduled) && isInPeriod(step.scheduledAt)
        }
        guard !relevantSteps.isEmpty else { return 0 }
        let done = relevantSteps.filter { $0.status == .done }.count
        return Int(Double(done) / Double(relevantSteps.count) * 100)
    }

    private var completedGoalsInPeriod: Int {
        allGoals.filter { $0.status == .completed }.count
    }

    private var totalTimeLabel: String {
        let totalMin = allSteps.filter { step in
            step.status == .done && isInPeriod(step.scheduledAt)
        }.reduce(0) { $0 + $1.durationMin }
        if totalMin >= 60 {
            return "\(totalMin / 60)h\(totalMin % 60)m"
        }
        return "\(totalMin)m"
    }

    private var chartData: [ChartEntry] {
        let calendar = Calendar(identifier: .iso8601)
        switch selectedPeriod {
        case .week:
            return weeklyChartData(calendar: calendar)
        case .month:
            return monthlyChartData(calendar: calendar)
        case .all:
            return allTimeChartData(calendar: calendar)
        }
    }

    private func weeklyChartData(calendar: Calendar) -> [ChartEntry] {
        let startOfWeek = DateHelper.startOfWeek()
        let dayNames = ["月", "火", "水", "木", "金", "土", "日"]
        return (0..<7).map { dayOffset in
            guard let dayStart = calendar.date(byAdding: .day, value: dayOffset, to: startOfWeek),
                  let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) else {
                return ChartEntry(label: dayNames[dayOffset], rate: 0)
            }
            let daySteps = allSteps.filter { step in
                guard let scheduled = step.scheduledAt else { return false }
                return scheduled >= dayStart && scheduled < dayEnd &&
                       (step.status == .done || step.status == .scheduled)
            }
            let done = daySteps.filter { $0.status == .done }.count
            let rate = daySteps.isEmpty ? 0.0 : Double(done) / Double(daySteps.count)
            return ChartEntry(label: dayNames[dayOffset], rate: rate)
        }
    }

    private func monthlyChartData(calendar: Calendar) -> [ChartEntry] {
        let now = Date()
        return (0..<4).reversed().map { weekOffset in
            guard let weekStart = calendar.date(byAdding: .weekOfYear, value: -weekOffset, to: now) else {
                return ChartEntry(label: "W\(weekOffset)", rate: 0)
            }
            let weekId = DateHelper.weekId(for: weekStart)
            let weekSteps = allSteps.filter { step in
                guard let scheduled = step.scheduledAt else { return false }
                let stepWeekId = DateHelper.weekId(for: scheduled)
                return stepWeekId == weekId && (step.status == .done || step.status == .scheduled)
            }
            let done = weekSteps.filter { $0.status == .done }.count
            let rate = weekSteps.isEmpty ? 0.0 : Double(done) / Double(weekSteps.count)
            let label = String(weekId.suffix(3))
            return ChartEntry(label: label, rate: rate)
        }
    }

    private func allTimeChartData(calendar: Calendar) -> [ChartEntry] {
        let now = Date()
        let formatter = DateFormatter()
        formatter.dateFormat = "M月"
        return (0..<6).reversed().map { monthOffset in
            guard let monthStart = calendar.date(byAdding: .month, value: -monthOffset, to: now),
                  let monthEnd = calendar.date(byAdding: .month, value: 1, to: monthStart) else {
                return ChartEntry(label: "", rate: 0)
            }
            let adjustedStart = calendar.date(from: calendar.dateComponents([.year, .month], from: monthStart)) ?? monthStart
            let monthSteps = allSteps.filter { step in
                guard let scheduled = step.scheduledAt else { return false }
                return scheduled >= adjustedStart && scheduled < monthEnd &&
                       (step.status == .done || step.status == .scheduled)
            }
            let done = monthSteps.filter { $0.status == .done }.count
            let rate = monthSteps.isEmpty ? 0.0 : Double(done) / Double(monthSteps.count)
            return ChartEntry(label: formatter.string(from: monthStart), rate: rate)
        }
    }

    private var categoryStats: [CategoryStat] {
        GoalCategory.allCases.compactMap { category in
            let goals = allGoals.filter { $0.category == category }
            guard !goals.isEmpty else { return nil }
            let total = goals.flatMap { $0.steps }.count
            let completed = goals.flatMap { $0.steps }.filter { $0.status == .done }.count
            return CategoryStat(category: category, total: total, completed: completed)
        }
    }

    private var recentCompletedGoals: [Goal] {
        allGoals
            .filter { $0.status == .completed }
            .sorted { $0.createdAt > $1.createdAt }
            .prefix(5)
            .map { $0 }
    }

    private func isInPeriod(_ date: Date?) -> Bool {
        guard let date else {
            return selectedPeriod == .all
        }
        return date >= periodStartDate
    }

    private func barColor(for rate: Double) -> Color {
        if rate >= 0.8 { return .green }
        if rate >= 0.5 { return Color.accentColor }
        if rate > 0 { return .orange }
        return Color(.systemGray4)
    }
}

// MARK: - Supporting Types

enum StatsPeriod: String, CaseIterable, Identifiable {
    case week
    case month
    case all

    var id: String { rawValue }

    var label: String {
        switch self {
        case .week:  String(localized: "今週")
        case .month: String(localized: "今月")
        case .all:   String(localized: "全期間")
        }
    }
}

private struct ChartEntry {
    let label: String
    let rate: Double
}

private struct CategoryStat {
    let category: GoalCategory
    let total: Int
    let completed: Int
}

// MARK: - StatCard

private struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .foregroundStyle(color)
                Spacer()
            }
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - CircularProgress

private struct CircularProgress: View {
    let progress: Double

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color(.systemGray5), lineWidth: 3)
            Circle()
                .trim(from: 0, to: progress)
                .stroke(Color.accentColor, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                .rotationEffect(.degrees(-90))
            Text("\(Int(progress * 100))")
                .font(.system(size: 8, weight: .bold))
        }
    }
}

#Preview {
    DashboardTab()
        .modelContainer(for: [Goal.self, Step.self, PlanSlot.self, ReviewLog.self], inMemory: true)
}
