import Foundation
import UserNotifications

enum NotificationManager {

    private static let reviewNotificationId = "weekly-review-reminder"

    /// Request notification permission. Call once on app launch.
    static func requestPermission() {
        UNUserNotificationCenter.current().requestAuthorization(
            options: [.alert, .badge, .sound]
        ) { _, _ in }
    }

    /// Schedule a weekly review reminder at the specified day/time (local time).
    /// Replaces any existing reminder so it's safe to call repeatedly.
    /// - Parameters:
    ///   - weekday: 1=Sunday, 2=Monday, ..., 7=Saturday (default: 1)
    ///   - hour: 0-23 (default: 20)
    ///   - minute: 0-59 (default: 0)
    static func scheduleWeeklyReview(weekday: Int = 1, hour: Int = 20, minute: Int = 0) {
        let center = UNUserNotificationCenter.current()

        // Remove previous to avoid duplicates
        center.removePendingNotificationRequests(
            withIdentifiers: [reviewNotificationId]
        )

        let content = UNMutableNotificationContent()
        content.title = String(localized: "週次レビューの時間です")
        content.body = String(localized: "今週のStepを振り返り、来週のプランを立てましょう")
        content.sound = .default

        var dateComponents = DateComponents()
        dateComponents.weekday = weekday
        dateComponents.hour = hour
        dateComponents.minute = minute

        let trigger = UNCalendarNotificationTrigger(
            dateMatching: dateComponents,
            repeats: true
        )

        let request = UNNotificationRequest(
            identifier: reviewNotificationId,
            content: content,
            trigger: trigger
        )

        center.add(request) { _ in }
    }
}
