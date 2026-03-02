import EventKit
import Foundation
import UIKit

/// Manages synchronization between PlanSlot steps and the iOS Calendar app.
enum CalendarService {
    private static let store = EKEventStore()

    /// UserDefaults key for the calendar identifier we create/use.
    private static let calendarIdKey = "tsugiichi_calendarId"

    // MARK: - Authorization

    /// Current authorization status.
    static var isAuthorized: Bool {
        if #available(iOS 17.0, *) {
            return EKEventStore.authorizationStatus(for: .event) == .fullAccess
        } else {
            return EKEventStore.authorizationStatus(for: .event) == .authorized
        }
    }

    /// Request calendar access. Returns `true` if granted.
    @MainActor
    static func requestAccess() async -> Bool {
        if #available(iOS 17.0, *) {
            return (try? await store.requestFullAccessToEvents()) ?? false
        } else {
            return (try? await store.requestAccess(to: .event)) ?? false
        }
    }

    // MARK: - Calendar

    /// Returns (or creates) the dedicated "ツギイチ" calendar.
    static func getOrCreateCalendar() -> EKCalendar? {
        // Try to find an existing calendar by stored identifier
        if let savedId = UserDefaults.standard.string(forKey: calendarIdKey),
           let existing = store.calendar(withIdentifier: savedId) {
            return existing
        }

        // Try to find by title
        let calendars = store.calendars(for: .event)
        if let existing = calendars.first(where: { $0.title == "ツギイチ" }) {
            UserDefaults.standard.set(existing.calendarIdentifier, forKey: calendarIdKey)
            return existing
        }

        // Create a new one
        let calendar = EKCalendar(for: .event, eventStore: store)
        calendar.title = "ツギイチ"
        calendar.cgColor = UIColor.systemBlue.cgColor

        // Pick a writable source (prefer iCloud, then Local)
        let sources = store.sources
        if let iCloud = sources.first(where: { $0.sourceType == .calDAV }) {
            calendar.source = iCloud
        } else if let local = sources.first(where: { $0.sourceType == .local }) {
            calendar.source = local
        } else {
            calendar.source = store.defaultCalendarForNewEvents?.source
        }

        do {
            try store.saveCalendar(calendar, commit: true)
            UserDefaults.standard.set(calendar.calendarIdentifier, forKey: calendarIdKey)
            return calendar
        } catch {
            print("[CalendarService] Failed to create calendar: \(error)")
            return nil
        }
    }

    // MARK: - Events

    /// Add a calendar event for a step that was scheduled to the weekly plan.
    /// The event is placed at the user's preferred hour (nearest future occurrence).
    @discardableResult
    static func addEvent(for stepTitle: String, stepId: UUID, durationMin: Int, goalTitle: String?) -> String? {
        guard isAuthorized, let calendar = getOrCreateCalendar() else { return nil }

        let event = EKEvent(eventStore: store)
        event.title = stepTitle
        event.calendar = calendar

        // Use the user's preferred hour for calendar events
        let start = nextPreferredDate()
        event.startDate = start
        event.endDate = start.addingTimeInterval(Double(durationMin) * 60)
        event.isAllDay = false

        if let goalTitle {
            event.notes = "Goal: \(goalTitle)"
        }
        // Store stepId in the URL field for later lookup
        event.url = URL(string: "tsugiichi://step/\(stepId.uuidString)")

        do {
            try store.save(event, span: .thisEvent)
            // Persist mapping: stepId -> eventIdentifier
            saveEventId(event.eventIdentifier, for: stepId)
            return event.eventIdentifier
        } catch {
            print("[CalendarService] Failed to save event: \(error)")
            return nil
        }
    }

    /// Remove the calendar event associated with a step.
    static func removeEvent(for stepId: UUID) {
        guard isAuthorized else { return }
        guard let eventId = loadEventId(for: stepId) else { return }
        guard let event = store.event(withIdentifier: eventId) else {
            clearEventId(for: stepId)
            return
        }
        do {
            try store.remove(event, span: .thisEvent)
            clearEventId(for: stepId)
        } catch {
            print("[CalendarService] Failed to remove event: \(error)")
        }
    }

    /// Update a calendar event title (e.g. prefix with checkmark when done).
    static func markEventDone(for stepId: UUID) {
        guard isAuthorized else { return }
        guard let eventId = loadEventId(for: stepId) else { return }
        guard let event = store.event(withIdentifier: eventId) else { return }
        if event.title?.hasPrefix("[DONE] ") != true {
            event.title = "[DONE] \(event.title ?? "")"
        }
        do {
            try store.save(event, span: .thisEvent)
        } catch {
            print("[CalendarService] Failed to update event: \(error)")
        }
    }

    // MARK: - Preferred time helper

    /// Calculate the nearest future occurrence of the user's preferred hour.
    /// For example, if preferred hour is 20 and current time is 21:00, returns tomorrow 20:00.
    /// If current time is 15:00, returns today 20:00.
    static func nextPreferredDate() -> Date {
        let preferredHour = UserDefaults.standard.integer(forKey: "calendarPreferredHour")
        // Default to 20 if not set (0 is also valid, so check if key exists)
        let hour = UserDefaults.standard.object(forKey: "calendarPreferredHour") != nil ? preferredHour : 20

        let now = Date()
        let cal = Calendar.current
        var components = cal.dateComponents([.year, .month, .day], from: now)
        components.hour = hour
        components.minute = 0
        components.second = 0

        // Try today first
        if let candidate = cal.date(from: components), candidate > now {
            return candidate
        }
        // Otherwise use tomorrow
        components.day = (components.day ?? 0) + 1
        return cal.date(from: components) ?? now
    }

    // MARK: - Persistence helpers (stepId <-> eventIdentifier)

    private static func saveEventId(_ eventId: String, for stepId: UUID) {
        var mapping = loadMapping()
        mapping[stepId.uuidString] = eventId
        UserDefaults.standard.set(mapping, forKey: "tsugiichi_stepEventMapping")
    }

    private static func loadEventId(for stepId: UUID) -> String? {
        let mapping = loadMapping()
        return mapping[stepId.uuidString]
    }

    private static func clearEventId(for stepId: UUID) {
        var mapping = loadMapping()
        mapping.removeValue(forKey: stepId.uuidString)
        UserDefaults.standard.set(mapping, forKey: "tsugiichi_stepEventMapping")
    }

    private static func loadMapping() -> [String: String] {
        (UserDefaults.standard.dictionary(forKey: "tsugiichi_stepEventMapping") as? [String: String]) ?? [:]
    }
}
