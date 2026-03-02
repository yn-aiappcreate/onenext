import WidgetKit
import SwiftUI

// MARK: - Timeline Entry

struct StepProgressEntry: TimelineEntry {
    let date: Date
    let totalSteps: Int
    let completedSteps: Int
    let topSteps: [WidgetStep]

    var progress: Double {
        guard totalSteps > 0 else { return 0 }
        return Double(completedSteps) / Double(totalSteps)
    }

    static var placeholder: StepProgressEntry {
        StepProgressEntry(
            date: Date(),
            totalSteps: 5,
            completedSteps: 2,
            topSteps: [
                WidgetStep(title: "企画書を作成", isDone: true),
                WidgetStep(title: "ホテルを予約", isDone: true),
                WidgetStep(title: "航空券を購入", isDone: false),
            ]
        )
    }

    static var empty: StepProgressEntry {
        StepProgressEntry(date: Date(), totalSteps: 0, completedSteps: 0, topSteps: [])
    }
}

struct WidgetStep {
    let title: String
    let isDone: Bool
}

// MARK: - Timeline Provider

struct StepProgressProvider: TimelineProvider {
    func placeholder(in context: Context) -> StepProgressEntry {
        .placeholder
    }

    func getSnapshot(in context: Context, completion: @escaping (StepProgressEntry) -> Void) {
        if context.isPreview {
            completion(.placeholder)
        } else {
            completion(loadEntry())
        }
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<StepProgressEntry>) -> Void) {
        let entry = loadEntry()
        // Refresh every 30 minutes
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 30, to: Date()) ?? Date()
        let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
        completion(timeline)
    }

    private func loadEntry() -> StepProgressEntry {
        // Read from UserDefaults shared via App Group
        let defaults = UserDefaults(suiteName: "group.com.ynlabs.tsugiichi") ?? .standard
        let total = defaults.integer(forKey: "widget_totalSteps")
        let completed = defaults.integer(forKey: "widget_completedSteps")

        var steps: [WidgetStep] = []
        if let data = defaults.data(forKey: "widget_topSteps"),
           let decoded = try? JSONDecoder().decode([CodableWidgetStep].self, from: data) {
            steps = decoded.map { WidgetStep(title: $0.title, isDone: $0.isDone) }
        }

        return StepProgressEntry(date: Date(), totalSteps: total, completedSteps: completed, topSteps: steps)
    }
}

private struct CodableWidgetStep: Codable {
    let title: String
    let isDone: Bool
}

// MARK: - Widget Views

struct TsugiIchiWidgetEntryView: View {
    var entry: StepProgressEntry
    @Environment(\.widgetFamily) var family

    var body: some View {
        switch family {
        case .systemSmall:
            smallView
        case .systemMedium:
            mediumView
        default:
            smallView
        }
    }

    // MARK: Small Widget

    private var smallView: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "flame.fill")
                    .foregroundStyle(.orange)
                Text("今週のStep")
                    .font(.caption)
                    .fontWeight(.semibold)
            }

            if entry.totalSteps == 0 {
                Spacer()
                Text("Stepなし")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
            } else {
                Spacer()

                ZStack {
                    Circle()
                        .stroke(Color(.systemGray5), lineWidth: 6)
                    Circle()
                        .trim(from: 0, to: entry.progress)
                        .stroke(progressColor, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                    VStack(spacing: 0) {
                        Text("\(entry.completedSteps)/\(entry.totalSteps)")
                            .font(.system(.body, design: .rounded, weight: .bold))
                        Text("完了")
                            .font(.system(size: 9))
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(width: 64, height: 64)
                .frame(maxWidth: .infinity)

                Spacer()
            }
        }
        .padding()
    }

    // MARK: Medium Widget

    private var mediumView: some View {
        HStack(spacing: 16) {
            // Left: progress ring
            VStack(spacing: 8) {
                ZStack {
                    Circle()
                        .stroke(Color(.systemGray5), lineWidth: 6)
                    Circle()
                        .trim(from: 0, to: entry.progress)
                        .stroke(progressColor, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                    VStack(spacing: 0) {
                        Text("\(Int(entry.progress * 100))%")
                            .font(.system(.title3, design: .rounded, weight: .bold))
                    }
                }
                .frame(width: 56, height: 56)

                Text("\(entry.completedSteps)/\(entry.totalSteps)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            // Right: step list
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Image(systemName: "flame.fill")
                        .foregroundStyle(.orange)
                        .font(.caption)
                    Text("今週のStep")
                        .font(.caption)
                        .fontWeight(.semibold)
                }

                if entry.topSteps.isEmpty {
                    Text("Stepがありません")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(Array(entry.topSteps.prefix(4).enumerated()), id: \.offset) { _, step in
                        HStack(spacing: 4) {
                            Image(systemName: step.isDone ? "checkmark.circle.fill" : "circle")
                                .font(.caption2)
                                .foregroundStyle(step.isDone ? .green : .secondary)
                            Text(step.title)
                                .font(.caption2)
                                .lineLimit(1)
                                .strikethrough(step.isDone)
                                .foregroundStyle(step.isDone ? .secondary : .primary)
                        }
                    }
                }

                Spacer()
            }
        }
        .padding()
    }

    private var progressColor: Color {
        if entry.progress >= 1.0 { return .green }
        if entry.progress >= 0.5 { return .blue }
        return .orange
    }
}

// MARK: - Widget Configuration

struct TsugiIchiWidget: Widget {
    let kind: String = "TsugiIchiWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: StepProgressProvider()) { entry in
            if #available(iOS 17.0, *) {
                TsugiIchiWidgetEntryView(entry: entry)
                    .containerBackground(.fill.tertiary, for: .widget)
            } else {
                TsugiIchiWidgetEntryView(entry: entry)
                    .padding()
                    .background()
            }
        }
        .configurationDisplayName("今週のStep進捗")
        .description("ホーム画面で今週のStep完了状況を確認できます。")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

// MARK: - Widget Bundle

@main
struct TsugiIchiWidgetBundle: WidgetBundle {
    var body: some Widget {
        TsugiIchiWidget()
    }
}

// MARK: - Preview

#Preview(as: .systemSmall) {
    TsugiIchiWidget()
} timeline: {
    StepProgressEntry.placeholder
    StepProgressEntry.empty
}

#Preview(as: .systemMedium) {
    TsugiIchiWidget()
} timeline: {
    StepProgressEntry.placeholder
}
