import Foundation

/// Records billing and credit consumption events for debugging.
/// Stores the most recent entries in UserDefaults (last 10 by default).
@MainActor
final class BillingEventLog: ObservableObject {

    static let shared = BillingEventLog()

    /// Maximum number of events to keep.
    static let maxEntries = 10

    private enum Keys {
        static let storedEntries = "billingEventLog_entries_v1"
    }

    private let defaults = UserDefaults.standard
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    /// A single billing event entry.
    struct Entry: Identifiable {
        let id = UUID()
        let date: Date
        let category: Category
        let message: String

        enum Category: String, Codable {
            case entitlement   = "Entitlement"
            case purchase      = "Purchase"
            case credit        = "Credit"
            case proxy         = "Proxy"
            case transactionUp = "Tx.Update"
            case restore       = "Restore"
            case error         = "Error"
        }

        /// Short date string for display.
        var timeString: String {
            let f = DateFormatter()
            f.dateFormat = "HH:mm:ss"
            return f.string(from: date)
        }
    }

    // MARK: - Published state

    @Published private(set) var entries: [Entry] = []

    private struct StoredEntry: Codable {
        let date: Date
        let category: Entry.Category
        let message: String
    }

    private init() {
        load()
    }

    // MARK: - Logging

    /// Append a new event. Trims to `maxEntries`.
    func log(_ category: Entry.Category, _ message: String) {
        let entry = Entry(date: Date(), category: category, message: message)
        entries.insert(entry, at: 0) // newest first
        if entries.count > Self.maxEntries {
            entries = Array(entries.prefix(Self.maxEntries))
        }
        print("[BillingEventLog] [\(category.rawValue)] \(message)")
        save()
    }

    // MARK: - Export

    /// Returns all entries as a plain-text string for clipboard / share.
    func exportText() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"

        var lines: [String] = [
            "=== TsugiIchi Billing Event Log ===",
            "Exported: \(formatter.string(from: Date()))",
            "Entries: \(entries.count)",
            "---"
        ]

        for entry in entries {
            lines.append("[\(formatter.string(from: entry.date))] [\(entry.category.rawValue)] \(entry.message)")
        }

        // Append current state snapshot
        let ent = EntitlementStore.shared
        let cred = CreditsStore.shared

        lines.append("")
        lines.append("=== Current State Snapshot ===")
        lines.append("isPro: \(ent.isPro)")
        lines.append("activeProductId: \(ent.activeProductId ?? "(nil)")")
        lines.append("proTransactionJWS: \(ent.proTransactionJWS != nil ? "present" : "nil")")
        lines.append("monthlyLimit: \(cred.monthlyLimit)")
        lines.append("monthlyUsed: \(cred.monthlyUsedCount)")
        lines.append("monthlyRemaining: \(cred.monthlyRemaining)")
        lines.append("purchasedCredits: \(cred.purchasedCredits)")
        lines.append("totalRemaining: \(cred.totalRemaining)")
        lines.append("windowStartDate: \(cred.windowStartDate.map { formatter.string(from: $0) } ?? "(nil)")")
        lines.append("lastProxyRemaining: \(cred.lastProxyRemaining.map(String.init) ?? "(nil)")")
        lines.append("lastProxySyncDate: \(cred.lastProxySyncDate.map { formatter.string(from: $0) } ?? "(nil)")")
        lines.append("lastVerificationMethod: \(cred.lastVerificationMethod ?? "(nil)")")
        lines.append("clientId: \(ClientId.current)")

        return lines.joined(separator: "\n")
    }

    /// Clear all entries.
    func clear() {
        entries.removeAll()
        save()
    }

    // MARK: - Persistence

    private func save() {
        let stored = entries.map { StoredEntry(date: $0.date, category: $0.category, message: $0.message) }
        do {
            let data = try encoder.encode(stored)
            defaults.set(data, forKey: Keys.storedEntries)
        } catch {
            print("[BillingEventLog] save failed: \(error)")
        }
    }

    private func load() {
        guard let data = defaults.data(forKey: Keys.storedEntries) else {
            entries = []
            return
        }
        do {
            let stored = try decoder.decode([StoredEntry].self, from: data)
            entries = stored.map { Entry(date: $0.date, category: $0.category, message: $0.message) }
        } catch {
            print("[BillingEventLog] load failed: \(error)")
            entries = []
        }
    }
}
