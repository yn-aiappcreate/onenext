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

    /// Schedule a weekly review reminder every Sunday at 20:00 (local time).
    /// Replaces any existing reminder so it's safe to call repeatedly.
    static func scheduleWeeklyReview() {
        let center = UNUserNotificationCenter.current()

        // Remove previous to avoid duplicates
        center.removePendingNotificationRequests(
            withIdentifiers: [reviewNotificationId]
        )

        let content = UNMutableNotificationContent()
        content.title = "週次レビューの時間です"
        content.body = "今週のStepを振り返り、来週のプランを立てましょう"
        content.sound = .default

        // Every Sunday at 20:00 local
        var dateComponents = DateComponents()
        dateComponents.weekday = 1  // Sunday
        dateComponents.hour = 20
        dateComponents.minute = 0

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
