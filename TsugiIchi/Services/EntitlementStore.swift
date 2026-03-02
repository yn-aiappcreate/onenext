import Foundation
import StoreKit

/// Determines Pro entitlement status from StoreKit 2 currentEntitlements.
@MainActor
final class EntitlementStore: ObservableObject {

    static let shared = EntitlementStore()

    @Published private(set) var isPro: Bool = false
    @Published private(set) var activeProductId: String?

    /// The JWS representation of the current Pro transaction for server-side verification (M12).
    /// This is sent to the Proxy so it can cryptographically verify Pro status.
    private(set) var proTransactionJWS: String?

    private init() {
        Task { await refresh() }
    }

    // MARK: - Refresh

    /// Re-check subscription status from StoreKit.
    func refresh() async {
        var foundPro = false
        var jws: String?

        for await result in Transaction.currentEntitlements {
            guard case .verified(let transaction) = result else { continue }
            if transaction.productID == BillingProduct.proMonthly.rawValue
                || transaction.productID == BillingProduct.proYearly.rawValue {
                // Check the subscription hasn't been revoked
                if transaction.revocationDate == nil {
                    foundPro = true
                    activeProductId = transaction.productID
                    jws = result.jwsRepresentation
                }
            }
        }

        isPro = foundPro
        proTransactionJWS = jws
        if !foundPro { activeProductId = nil }
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
