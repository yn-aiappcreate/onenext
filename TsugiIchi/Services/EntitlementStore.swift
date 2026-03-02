import Foundation
import StoreKit

/// Determines Pro entitlement status from StoreKit 2 currentEntitlements.
@MainActor
final class EntitlementStore: ObservableObject {

    static let shared = EntitlementStore()

    @Published private(set) var isPro: Bool = false

    private init() {
        Task { await refresh() }
    }

    // MARK: - Refresh

    /// Re-check subscription status from StoreKit.
    func refresh() async {
        var foundPro = false

        for await result in Transaction.currentEntitlements {
            guard case .verified(let transaction) = result else { continue }
            if transaction.productID == BillingProduct.proMonthly.rawValue {
                // Check the subscription hasn't been revoked
                if transaction.revocationDate == nil {
                    foundPro = true
                }
            }
        }

        isPro = foundPro
    }

    // MARK: - Convenience

    /// Whether the user can use AI (has remaining credits).
    /// This combines Pro status with credit availability.
    var canUseAI: Bool {
        CreditsStore.shared.totalRemaining > 0
    }

    /// The tier-specific monthly limit.
    var monthlyLimit: Int {
        isPro ? CreditsStore.proMonthlyLimit : CreditsStore.freeMonthlyLimit
    }
}
