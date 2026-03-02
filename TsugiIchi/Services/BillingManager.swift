import Foundation
import StoreKit

// MARK: - Product identifiers

enum BillingProduct: String, CaseIterable {
    case proMonthly = "com.ynlabs.tsugiichi.pro.monthly"
    case proYearly  = "com.ynlabs.tsugiichi.pro.yearly"
    case aiPack300  = "com.ynlabs.tsugiichi.ai.pack300"
}

// MARK: - BillingManager

/// Handles StoreKit 2 product fetching, purchases, restore, and transaction listening.
@MainActor
final class BillingManager: ObservableObject {

    static let shared = BillingManager()

    // MARK: Published state

    @Published private(set) var products: [Product] = []
    @Published private(set) var purchaseError: String?
    @Published private(set) var isPurchasing = false

    // MARK: Private

    private let productIds = Set(BillingProduct.allCases.map(\.rawValue))
    private var updateTask: Task<Void, Never>?

    private init() {
        updateTask = Task { [weak self] in
            await self?.listenForTransactions()
        }
    }

    deinit {
        updateTask?.cancel()
    }

    // MARK: - Load products

    func loadProducts() async {
        do {
            let storeProducts = try await Product.products(for: productIds)
            products = storeProducts.sorted { $0.price < $1.price }
        } catch {
            print("[BillingManager] Failed to load products: \(error)")
        }
    }

    /// Convenience accessor for the Pro monthly product.
    var proMonthlyProduct: Product? {
        products.first { $0.id == BillingProduct.proMonthly.rawValue }
    }

    /// Convenience accessor for the Pro yearly product.
    var proYearlyProduct: Product? {
        products.first { $0.id == BillingProduct.proYearly.rawValue }
    }

    /// Convenience accessor for the AI pack product.
    var packProduct: Product? {
        products.first { $0.id == BillingProduct.aiPack300.rawValue }
    }

    // MARK: - Purchase

    func purchase(_ product: Product) async -> Transaction? {
        isPurchasing = true
        purchaseError = nil
        defer { isPurchasing = false }

        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                let transaction = extractTransaction(verification)
                await transaction.finish()
                await EntitlementStore.shared.refresh()
                // If consumable pack, credit the purchased amount
                if product.id == BillingProduct.aiPack300.rawValue {
                    CreditsStore.shared.addPurchasedCredits(300)
                }
                print("[BillingManager] purchase success: \(product.id)")
                return transaction
            case .userCancelled:
                print("[BillingManager] purchase cancelled by user")
                return nil
            case .pending:
                print("[BillingManager] purchase pending")
                return nil
            @unknown default:
                return nil
            }
        } catch {
            purchaseError = error.localizedDescription
            print("[BillingManager] purchase error: \(error)")
            return nil
        }
    }

    // MARK: - Restore

    func restorePurchases() async {
        do {
            try await AppStore.sync()
            await EntitlementStore.shared.refresh()
        } catch {
            purchaseError = error.localizedDescription
        }
    }

    // MARK: - Transaction listener

    private func listenForTransactions() async {
        for await result in Transaction.updates {
            let transaction = extractTransaction(result)
            await transaction.finish()
            // If consumable pack, credit the purchased amount
            if transaction.productID == BillingProduct.aiPack300.rawValue {
                CreditsStore.shared.addPurchasedCredits(300)
            }
            await EntitlementStore.shared.refresh()
            print("[BillingManager] transaction update: \(transaction.productID)")
        }
    }

    // MARK: - Verification

    /// Extract the transaction regardless of verification status.
    /// In Sandbox, transactions may be unverified — we still process them.
    private func extractTransaction(_ result: VerificationResult<Transaction>) -> Transaction {
        switch result {
        case .verified(let transaction):
            print("[BillingManager] verified transaction: \(transaction.productID)")
            return transaction
        case .unverified(let transaction, let error):
            print("[BillingManager] unverified transaction: \(transaction.productID), error: \(error)")
            return transaction
        }
    }
}
