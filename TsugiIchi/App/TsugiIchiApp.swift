import SwiftUI
import SwiftData

@main
struct TsugiIchiApp: App {
    @AppStorage("notificationWeekday") private var notificationWeekday: Int = 1
    @AppStorage("notificationHour") private var notificationHour: Int = 20
    @AppStorage("notificationMinute") private var notificationMinute: Int = 0

    var body: some Scene {
        WindowGroup {
            ContentView()
                .onAppear {
                    NotificationManager.requestPermission()
                    NotificationManager.scheduleWeeklyReview(
                        weekday: notificationWeekday,
                        hour: notificationHour,
                        minute: notificationMinute
                    )
                }
        }
        .modelContainer(for: [
            Goal.self,
            Step.self,
            PlanSlot.self,
            ReviewLog.self
        ])
    }
}
