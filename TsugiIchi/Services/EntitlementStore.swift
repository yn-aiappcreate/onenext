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
            let transaction: Transaction
            switch result {
            case .verified(let t):
                transaction = t
                print("[EntitlementStore] verified transaction: \(t.productID)")
            case .unverified(let t, let error):
                // In Sandbox, transactions may be unverified — still count them
                transaction = t
                print("[EntitlementStore] unverified transaction: \(t.productID), error: \(error)")
            }

            if transaction.productID == BillingProduct.proMonthly.rawValue
                || transaction.productID == BillingProduct.proYearly.rawValue {
                if transaction.revocationDate == nil {
                    foundPro = true
                    activeProductId = transaction.productID
                    jws = result.jwsRepresentation
                    print("[EntitlementStore] Pro entitlement found: \(transaction.productID)")
                } else {
                    print("[EntitlementStore] transaction revoked: \(transaction.productID)")
                }
            }
        }

        isPro = foundPro
        proTransactionJWS = jws
        if !foundPro { activeProductId = nil }
        print("[EntitlementStore] refresh complete — isPro=\(foundPro)")

        // Fallback: if currentEntitlements didn't find Pro, check latest transactions directly
        if !foundPro {
            await checkLatestTransactions()
        }
    }

    /// Fallback check using Transaction.latest(for:) for each Pro product.
    private func checkLatestTransactions() async {
        let proProductIds = [BillingProduct.proMonthly.rawValue, BillingProduct.proYearly.rawValue]
        for productId in proProductIds {
            guard let result = await Transaction.latest(for: productId) else {
                print("[EntitlementStore] no latest transaction for \(productId)")
                continue
            }
            let transaction: Transaction
            switch result {
            case .verified(let t): transaction = t
            case .unverified(let t, _): transaction = t
            }
            // Check subscription is not expired or revoked
            if transaction.revocationDate == nil,
               transaction.expirationDate.map({ $0 > Date() }) ?? true {
                isPro = true
                activeProductId = transaction.productID
                proTransactionJWS = result.jwsRepresentation
                print("[EntitlementStore] fallback: Pro found via latest transaction: \(productId)")
                return
            } else {
                print("[EntitlementStore] fallback: transaction expired/revoked for \(productId)")
            }
        }
        print("[EntitlementStore] fallback: no active Pro subscription found")
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

    /// Free tier allows up to 5 active goals.
    static let freeGoalLimit = 5
}
