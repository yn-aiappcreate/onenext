import Foundation

/// Manages AI credit consumption with a 30-day rolling window.
///
/// Credits are consumed in order:
/// 1. Monthly quota (Free: 10, Pro: 300) — resets every 30 days
/// 2. Purchased credits (pack300) — never expire
///
/// All state is persisted in UserDefaults.
@MainActor
final class CreditsStore: ObservableObject {

    static let shared = CreditsStore()

    // MARK: - Tier limits

    static let freeMonthlyLimit = 10
    static let proMonthlyLimit  = 300
    static let packSize         = 300

    // MARK: - UserDefaults keys

    private enum Keys {
        static let monthlyUsedCount   = "credits_monthlyUsedCount"
        static let windowStartDate    = "credits_windowStartDate"
        static let purchasedCredits   = "credits_purchasedCredits"
    }

    // MARK: - Published state

    /// Number of monthly-quota credits used in the current 30-day window.
    @Published private(set) var monthlyUsedCount: Int

    /// Start of the current 30-day window.
    @Published private(set) var windowStartDate: Date?

    /// Last `remaining` value returned by Proxy (for Debug screen).
    @Published private(set) var lastProxyRemaining: Int?

    /// Last `verificationMethod` value returned by Proxy (for Debug screen).
    @Published var lastVerificationMethod: String?

    /// Timestamp of the last Proxy sync (for Debug screen).
    @Published private(set) var lastProxySyncDate: Date?

    /// Purchased credits (from pack300). Never expire.
    @Published private(set) var purchasedCredits: Int

    private let defaults = UserDefaults.standard

    private init() {
        self.monthlyUsedCount = defaults.integer(forKey: Keys.monthlyUsedCount)
        self.purchasedCredits = defaults.integer(forKey: Keys.purchasedCredits)

        if let stored = defaults.object(forKey: Keys.windowStartDate) as? Date {
            self.windowStartDate = stored
        } else {
            self.windowStartDate = nil
        }

        // Check if the window has expired on init
        rollWindowIfNeeded()
    }

    // MARK: - Computed

    /// The current monthly limit based on Pro status.
    var monthlyLimit: Int {
        EntitlementStore.shared.isPro ? Self.proMonthlyLimit : Self.freeMonthlyLimit
    }

    /// Remaining credits in the monthly quota.
    var monthlyRemaining: Int {
        max(0, monthlyLimit - monthlyUsedCount)
    }

    /// Total remaining credits (monthly + purchased).
    var totalRemaining: Int {
        monthlyRemaining + purchasedCredits
    }

    /// Whether the user has any credits left to use AI.
    var canUseAI: Bool {
        totalRemaining > 0
    }

    // MARK: - Consume

    /// Consume one AI credit. Returns `true` if successful, `false` if no credits remain.
    @discardableResult
    func consumeOne() -> Bool {
        rollWindowIfNeeded()

        // Try monthly quota first
        if monthlyUsedCount < monthlyLimit {
            monthlyUsedCount += 1
            save()
            BillingEventLog.shared.log(.credit, "consumeOne (monthly) used=\(monthlyUsedCount)/\(monthlyLimit)")
            return true
        }

        // Then try purchased credits
        if purchasedCredits > 0 {
            purchasedCredits -= 1
            save()
            BillingEventLog.shared.log(.credit, "consumeOne (purchased) remaining=\(purchasedCredits)")
            return true
        }

        BillingEventLog.shared.log(.error, "consumeOne failed: no credits")
        // No credits left
        return false
    }

    // MARK: - Add purchased credits

    /// Add purchased credits (e.g., from pack300).
    func addPurchasedCredits(_ count: Int) {
        purchasedCredits += count
        save()
        BillingEventLog.shared.log(.credit, "addPurchasedCredits +\(count) total=\(purchasedCredits)")
    }

    // MARK: - Sync from Proxy

    /// Update local state from Proxy's `remaining` response.
    ///
    /// Checklist: **remainingの真実は一箇所にする（Proxyを正とする）**
    /// The Proxy is the authoritative source of truth for credit tracking (M11).
    /// Local state is always overwritten to match Proxy — both upward and downward.
    func syncFromProxy(remaining: Int, verificationMethod: String? = nil) {
        let proxyRemaining = max(0, remaining)
        let previousTotal = totalRemaining
        lastProxyRemaining = proxyRemaining
        lastProxySyncDate = Date()
        if let method = verificationMethod {
            lastVerificationMethod = method
        }
        BillingEventLog.shared.log(.proxy,
            "syncFromProxy remaining=\(proxyRemaining) localTotal=\(previousTotal) method=\(verificationMethod ?? "nil")")

        // Proxy is authoritative — always reconcile local to match.
        // remaining = (monthlyLimit - monthlyUsed) + purchasedCredits
        // => monthlyUsed = monthlyLimit - (remaining - purchasedCredits)
        let monthlyRemainingFromProxy = max(0, proxyRemaining - purchasedCredits)
        let newUsed = max(0, monthlyLimit - monthlyRemainingFromProxy)
        if newUsed != monthlyUsedCount {
            BillingEventLog.shared.log(.proxy,
                "syncFromProxy adjusted monthlyUsed \(monthlyUsedCount) -> \(newUsed) (limit=\(monthlyLimit), purchased=\(purchasedCredits))")
        }
        monthlyUsedCount = newUsed
        save()

        let newTotal = totalRemaining
        if newTotal != previousTotal {
            BillingEventLog.shared.log(.proxy,
                "syncFromProxy totalRemaining changed \(previousTotal) -> \(newTotal)")
        }
    }

    // MARK: - Pro status change

    /// Called when Pro status changes to recalculate limits.
    /// If downgrading from Pro, the monthly used count may exceed the new limit,
    /// which naturally results in 0 monthly remaining.
    func onProStatusChanged() {
        BillingEventLog.shared.log(.entitlement, "CreditsStore.onProStatusChanged isPro=\(EntitlementStore.shared.isPro) monthlyLimit=\(monthlyLimit)")
        objectWillChange.send()
    }

    // MARK: - 30-day rolling window

    /// If the window has expired (>30 days), reset monthly usage.
    private func rollWindowIfNeeded() {
        guard let start = windowStartDate else {
            // No window yet — will be created on first use
            return
        }

        let elapsed = Date().timeIntervalSince(start)
        let thirtyDays: TimeInterval = 30 * 24 * 60 * 60

        if elapsed >= thirtyDays {
            monthlyUsedCount = 0
            windowStartDate = Date()
            save()
            BillingEventLog.shared.log(.credit, "rollWindowIfNeeded reset windowStart=\(windowStartDate.map(String.init(describing:)) ?? "nil")")
        }
    }

    /// Ensure a window exists. Called when AI is first used.
    func ensureWindowStarted() {
        if windowStartDate == nil {
            windowStartDate = Date()
            save()
            BillingEventLog.shared.log(.credit, "ensureWindowStarted windowStart=\(windowStartDate.map(String.init(describing:)) ?? "nil")")
        }
    }

    // MARK: - Persistence

    private func save() {
        defaults.set(monthlyUsedCount, forKey: Keys.monthlyUsedCount)
        defaults.set(purchasedCredits, forKey: Keys.purchasedCredits)
        if let start = windowStartDate {
            defaults.set(start, forKey: Keys.windowStartDate)
        }
    }

    // MARK: - Testing / Debug

    /// Reset all credits (for testing purposes).
    func resetAll() {
        monthlyUsedCount = 0
        windowStartDate = nil
        purchasedCredits = 0
        lastProxyRemaining = nil
        lastProxySyncDate = nil
        lastVerificationMethod = nil
        defaults.removeObject(forKey: Keys.monthlyUsedCount)
        defaults.removeObject(forKey: Keys.windowStartDate)
        defaults.removeObject(forKey: Keys.purchasedCredits)
        BillingEventLog.shared.log(.credit, "resetAll completed")
    }
}
