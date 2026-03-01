import Foundation

enum DateHelper {

    /// Returns the ISO 8601 week identifier for a given date, e.g. "2026-W09".
    static func weekId(for date: Date = Date()) -> String {
        let calendar = Calendar(identifier: .iso8601)
        let year = calendar.component(.yearForWeekOfYear, from: date)
        let week = calendar.component(.weekOfYear, from: date)
        return String(format: "%04d-W%02d", year, week)
    }

    /// Returns the start (Monday) of the ISO week containing the given date.
    static func startOfWeek(for date: Date = Date()) -> Date {
        let calendar = Calendar(identifier: .iso8601)
        var components = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: date)
        components.weekday = 2 // Monday
        return calendar.date(from: components) ?? date
    }

    /// Returns the end (Sunday 23:59:59) of the ISO week containing the given date.
    static func endOfWeek(for date: Date = Date()) -> Date {
        let start = startOfWeek(for: date)
        let calendar = Calendar(identifier: .iso8601)
        return calendar.date(byAdding: .day, value: 6, to: start)
            .flatMap { calendar.date(bySettingHour: 23, minute: 59, second: 59, of: $0) }
            ?? date
    }
}
