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
/// This is the **single** transaction listener — SubscriptionManager delegates here.
///
/// Checklist compliance:
/// - Transaction検証を通さない付与は禁止 → `verifyAndProcess()` rejects unverified in production
/// - Transaction.updates を起動直後から監視 → `listenForTransactions()` started in `init()`
/// - 同一Transactionの二重処理を防ぐ → `processedTransactionIds` persisted in UserDefaults
/// - userCancelled は静かに戻す → returns nil, no error set
@MainActor
final class BillingManager: ObservableObject {

    static let shared = BillingManager()

    // MARK: Published state

    @Published private(set) var products: [Product] = []
    @Published private(set) var purchaseError: String?
    @Published private(set) var isPurchasing = false

    /// Tracks the last verification status for Debug screen.
    @Published private(set) var lastVerificationStatus: String?

    // MARK: Private

    private let productIds = Set(BillingProduct.allCases.map(\.rawValue))
    private var updateTask: Task<Void, Never>?

    /// Persisted set of transaction IDs that have already been processed.
    /// Prevents double-crediting when both `purchase()` and `Transaction.updates` fire.
    private var processedTransactionIds: Set<UInt64> {
        didSet { persistProcessedIds() }
    }

    private enum Keys {
        static let processedIds = "billing_processedTransactionIds"
    }

    private init() {
        // Load persisted processed transaction IDs
        let stored = UserDefaults.standard.array(forKey: Keys.processedIds) as? [UInt64] ?? []
        self.processedTransactionIds = Set(stored)

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
            BillingEventLog.shared.log(.purchase, "loadProducts count=\(products.count)")
        } catch {
            BillingEventLog.shared.log(.error, "loadProducts error=\(error)")
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
        BillingEventLog.shared.log(.purchase, "purchase start product=\(product.id)")
        defer { isPurchasing = false }

        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                guard let transaction = verifyAndProcess(verification, source: "purchase") else {
                    // Verification failed — do not grant
                    return nil
                }
                await transaction.finish()
                BillingEventLog.shared.log(.purchase,
                    "purchase success product=\(product.id) txId=\(transaction.id)")
                return transaction

            case .userCancelled:
                // Checklist: userCancelled は静かに戻す — no error, no UI change
                BillingEventLog.shared.log(.purchase, "purchase cancelled product=\(product.id)")
                return nil

            case .pending:
                BillingEventLog.shared.log(.purchase, "purchase pending product=\(product.id)")
                return nil

            @unknown default:
                BillingEventLog.shared.log(.purchase, "purchase unknown result product=\(product.id)")
                return nil
            }
        } catch {
            purchaseError = error.localizedDescription
            BillingEventLog.shared.log(.error, "purchase error product=\(product.id) error=\(error)")
            print("[BillingManager] purchase error: \(error)")
            return nil
        }
    }

    // MARK: - Restore

    func restorePurchases() async {
        BillingEventLog.shared.log(.restore, "restorePurchases start")
        do {
            try await AppStore.sync()
            BillingEventLog.shared.log(.restore, "AppStore.sync success")
            await EntitlementStore.shared.refresh()
        } catch {
            purchaseError = error.localizedDescription
            BillingEventLog.shared.log(.error, "restorePurchases error=\(error)")
        }
    }

    // MARK: - Transaction listener (single listener for the whole app)

    private func listenForTransactions() async {
        for await result in Transaction.updates {
            let _ = verifyAndProcess(result, source: "Transaction.updates")
            // Finish the transaction regardless of verification outcome
            // so StoreKit doesn't keep re-delivering it.
            switch result {
            case .verified(let tx):
                await tx.finish()
            case .unverified(let tx, _):
                await tx.finish()
            }
        }
    }

    // MARK: - Verification & Processing

    /// Verify the transaction and process it (grant entitlements/credits) if valid.
    ///
    /// Checklist compliance:
    /// - **Transaction検証を通さない付与は禁止**: Only verified transactions grant entitlements.
    ///   In Sandbox (#if DEBUG), unverified transactions are processed with a warning log.
    /// - **同一Transactionの二重処理を防ぐ**: Checks `processedTransactionIds` before granting.
    ///
    /// Returns the underlying `Transaction` if processing succeeded, `nil` if rejected.
    @discardableResult
    private func verifyAndProcess(
        _ result: VerificationResult<Transaction>,
        source: String
    ) -> Transaction? {
        let transaction: Transaction
        let isVerified: Bool

        switch result {
        case .verified(let tx):
            transaction = tx
            isVerified = true
            lastVerificationStatus = "verified"
            BillingEventLog.shared.log(.purchase,
                "[\(source)] verified tx=\(tx.productID) id=\(tx.id)")

        case .unverified(let tx, let error):
            transaction = tx
            isVerified = false
            lastVerificationStatus = "unverified"
            BillingEventLog.shared.log(.error,
                "[\(source)] unverified tx=\(tx.productID) id=\(tx.id) error=\(error)")

            #if !DEBUG
            // Production: reject unverified — do NOT grant entitlements/credits
            BillingEventLog.shared.log(.error,
                "[\(source)] REJECTED unverified transaction in production: \(tx.productID)")
            purchaseError = "トランザクション検証に失敗しました。再度お試しください。"
            return nil
            #else
            // Sandbox: allow unverified with warning
            BillingEventLog.shared.log(.purchase,
                "[\(source)] allowing unverified in Sandbox: \(tx.productID)")
            #endif
        }

        // Checklist: 同一Transactionの二重処理を防ぐ
        guard !processedTransactionIds.contains(transaction.id) else {
            BillingEventLog.shared.log(.purchase,
                "[\(source)] SKIPPED already-processed txId=\(transaction.id) product=\(transaction.productID)")
            return transaction // Already processed — skip granting but return tx
        }

        // Mark as processed BEFORE granting to prevent race conditions
        processedTransactionIds.insert(transaction.id)

        // Grant entitlements/credits based on product type
        grantForTransaction(transaction, isVerified: isVerified, source: source)

        return transaction
    }

    /// Actually grant the entitlement or credits for a transaction.
    /// Called only after verification + dedup checks pass.
    private func grantForTransaction(
        _ transaction: Transaction,
        isVerified: Bool,
        source: String
    ) {
        let productID = transaction.productID

        if productID == BillingProduct.aiPack300.rawValue {
            // Consumable: add purchased credits
            CreditsStore.shared.addPurchasedCredits(CreditsStore.packSize)
            BillingEventLog.shared.log(.credit,
                "[\(source)] granted \(CreditsStore.packSize) credits txId=\(transaction.id) verified=\(isVerified)")
        }

        if productID == BillingProduct.proMonthly.rawValue
            || productID == BillingProduct.proYearly.rawValue {
            // Subscription: mark update received for UI reflection
            EntitlementStore.shared.markTransactionUpdateReceived(productId: productID)
            BillingEventLog.shared.log(.entitlement,
                "[\(source)] subscription update: \(productID) txId=\(transaction.id) verified=\(isVerified)")
        }

        // Always refresh entitlement state so UI updates
        Task {
            await EntitlementStore.shared.refresh()
        }
    }

    // MARK: - Persistence for processed transaction IDs

    private func persistProcessedIds() {
        // Keep only the most recent 500 IDs to prevent unbounded growth
        let trimmed = Array(processedTransactionIds.suffix(500))
        UserDefaults.standard.set(trimmed, forKey: Keys.processedIds)
    }

    /// Exposed for testing: check if a transaction ID has been processed.
    func isTransactionProcessed(_ id: UInt64) -> Bool {
        processedTransactionIds.contains(id)
    }

    /// Exposed for testing/debug: clear processed transaction IDs.
    func clearProcessedTransactionIds() {
        processedTransactionIds.removeAll()
        BillingEventLog.shared.log(.purchase, "clearProcessedTransactionIds")
    }
}
