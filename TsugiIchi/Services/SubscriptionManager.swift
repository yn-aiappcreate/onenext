import StoreKit
import SwiftUI

/// Product identifiers – must match App Store Connect configuration.
enum SubscriptionProduct: String, CaseIterable {
    case monthlyPro = "com.ynlabs.tsugiichi.pro.monthly"
    case yearlyPro  = "com.ynlabs.tsugiichi.pro.yearly"

    var displayName: String {
        switch self {
        case .monthlyPro: "Pro（月額）"
        case .yearlyPro:  "Pro（年額）"
        }
    }
}

/// Manages StoreKit 2 subscriptions for the Pro tier.
/// NOTE: Transaction.updates listening is consolidated in BillingManager (single listener).
/// This class delegates to EntitlementStore for Pro status.
@MainActor
final class SubscriptionManager: ObservableObject {
    static let shared = SubscriptionManager()

    @Published private(set) var products: [Product] = []
    @Published private(set) var currentSubscription: Product.SubscriptionInfo.Status?
    @Published private(set) var purchaseError: String?

    /// Pro status is derived from EntitlementStore (single source of truth).
    var isProUser: Bool {
        EntitlementStore.shared.isPro
    }

    /// The group ID for the auto-renewable subscription group (set in App Store Connect).
    private let productIds = Set(SubscriptionProduct.allCases.map(\.rawValue))

    private init() {
        // Transaction.updates listening is handled by BillingManager.
        // No duplicate listener here.
    }

    // MARK: - Load Products

    func loadProducts() async {
        do {
            let storeProducts = try await Product.products(for: productIds)
            products = storeProducts.sorted { $0.price < $1.price }
            BillingEventLog.shared.log(.purchase, "SubscriptionManager.loadProducts count=\(products.count)")
        } catch {
            BillingEventLog.shared.log(.error, "SubscriptionManager.loadProducts error=\(error)")
            print("[SubscriptionManager] Failed to load products: \(error)")
        }
    }

    // MARK: - Purchase

    /// Purchase delegates to BillingManager which handles verification + dedup.
    func purchase(_ product: Product) async {
        purchaseError = nil
        BillingEventLog.shared.log(.purchase, "SubscriptionManager.purchase start product=\(product.id)")
        let transaction = await BillingManager.shared.purchase(product)
        if let tx = transaction {
            BillingEventLog.shared.log(.purchase,
                "SubscriptionManager.purchase success product=\(product.id) txId=\(tx.id)")
        } else if let error = BillingManager.shared.purchaseError {
            purchaseError = error
        }
        // purchaseError is nil for userCancelled (silent return)
    }

    // MARK: - Restore

    /// Restore delegates to BillingManager.
    func restorePurchases() async {
        BillingEventLog.shared.log(.restore, "SubscriptionManager.restorePurchases start")
        await BillingManager.shared.restorePurchases()
    }

    // MARK: - Status Check

    /// Refresh subscription status from EntitlementStore (single source of truth).
    func updateSubscriptionStatus() async {
        await EntitlementStore.shared.refresh()
        BillingEventLog.shared.log(.entitlement,
            "SubscriptionManager.updateSubscriptionStatus isProUser=\(isProUser)")
    }
}

// MARK: - Pro Feature Check

extension SubscriptionManager {
    /// Features gated behind Pro subscription.
    enum ProFeature {
        case aiAssist
        case csvExport
        case calendarSync
        case unlimitedGoals

        var displayName: String {
            switch self {
            case .aiAssist:       "AIアシスト"
            case .csvExport:      "CSVエクスポート"
            case .calendarSync:   "カレンダー連携"
            case .unlimitedGoals: "無制限のGoal"
            }
        }
    }

    /// Free tier allows up to 5 active goals.
    static let freeGoalLimit = 5

    /// Check if the user can use a Pro feature.
    /// Returns `true` if subscribed or if the feature doesn't require Pro.
    func canUse(_ feature: ProFeature) -> Bool {
        return isProUser
    }
}
