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
@MainActor
final class SubscriptionManager: ObservableObject {
    static let shared = SubscriptionManager()

    @Published private(set) var products: [Product] = []
    @Published private(set) var isProUser: Bool = false
    @Published private(set) var currentSubscription: Product.SubscriptionInfo.Status?
    @Published private(set) var purchaseError: String?

    /// The group ID for the auto-renewable subscription group (set in App Store Connect).
    private let productIds = Set(SubscriptionProduct.allCases.map(\.rawValue))

    private var updateTask: Task<Void, Never>?

    private init() {
        updateTask = Task { [weak self] in
            await self?.listenForTransactions()
        }
    }

    deinit {
        updateTask?.cancel()
    }

    // MARK: - Load Products

    func loadProducts() async {
        do {
            let storeProducts = try await Product.products(for: productIds)
            products = storeProducts.sorted { $0.price < $1.price }
        } catch {
            print("[SubscriptionManager] Failed to load products: \(error)")
        }
    }

    // MARK: - Purchase

    func purchase(_ product: Product) async {
        purchaseError = nil
        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                let transaction = try checkVerified(verification)
                await transaction.finish()
                await updateSubscriptionStatus()
            case .userCancelled:
                break
            case .pending:
                purchaseError = "購入が保留中です"
            @unknown default:
                break
            }
        } catch {
            purchaseError = "購入に失敗しました: \(error.localizedDescription)"
        }
    }

    // MARK: - Restore

    func restorePurchases() async {
        try? await AppStore.sync()
        await updateSubscriptionStatus()
    }

    // MARK: - Status Check

    func updateSubscriptionStatus() async {
        var hasActiveSubscription = false

        for await result in Transaction.currentEntitlements {
            guard let transaction = try? checkVerified(result) else { continue }
            if productIds.contains(transaction.productID) {
                hasActiveSubscription = true
            }
        }

        isProUser = hasActiveSubscription
    }

    // MARK: - Transaction Listener

    private func listenForTransactions() async {
        for await result in Transaction.updates {
            guard let transaction = try? checkVerified(result) else { continue }
            await transaction.finish()
            await updateSubscriptionStatus()
        }
    }

    // MARK: - Verification

    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified(_, let error):
            throw error
        case .verified(let value):
            return value
        }
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

    /// Free tier allows up to 3 active goals.
    static let freeGoalLimit = 3

    /// Check if the user can use a Pro feature.
    /// Returns `true` if subscribed or if the feature doesn't require Pro.
    func canUse(_ feature: ProFeature) -> Bool {
        return isProUser
    }
}
