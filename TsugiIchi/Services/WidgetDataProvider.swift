import Foundation
import SwiftData

/// Writes Step progress data to shared UserDefaults so the Widget can read it.
enum WidgetDataProvider {

    private static let suiteName = "group.com.ynlabs.tsugiichi"

    /// Call this whenever Steps change (done, scheduled, etc.) to keep widget data fresh.
    static func updateWidgetData(steps: [Step]) {
        guard let defaults = UserDefaults(suiteName: suiteName) else { return }

        let weekId = DateHelper.weekId()

        // Filter to this week's scheduled/done steps
        let weekSteps = steps.filter { step in
            guard let scheduled = step.scheduledAt else { return false }
            return DateHelper.weekId(for: scheduled) == weekId
        }

        let total = weekSteps.count
        let completed = weekSteps.filter { $0.status == .done }.count

        defaults.set(total, forKey: "widget_totalSteps")
        defaults.set(completed, forKey: "widget_completedSteps")

        // Encode top steps for display
        struct CodableStep: Codable {
            let title: String
            let isDone: Bool
        }

        let topSteps = weekSteps
            .sorted { ($0.sortOrder, $0.title) < ($1.sortOrder, $1.title) }
            .prefix(6)
            .map { CodableStep(title: $0.title, isDone: $0.status == .done) }

        if let data = try? JSONEncoder().encode(topSteps) {
            defaults.set(data, forKey: "widget_topSteps")
        }

        // Request widget refresh
        reloadWidgets()
    }

    /// Triggers WidgetKit to reload all widgets.
    static func reloadWidgets() {
        // WidgetCenter is only available when WidgetKit is linked.
        // Use dynamic dispatch to avoid hard dependency.
        if let widgetCenter = NSClassFromString("WidgetCenter") as? NSObject.Type,
           let shared = widgetCenter.value(forKey: "shared") as? NSObject {
            shared.perform(NSSelectorFromString("reloadAllTimelines"))
        }
    }
}
