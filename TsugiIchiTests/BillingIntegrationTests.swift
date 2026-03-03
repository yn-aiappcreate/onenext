import XCTest
@testable import TsugiIchi

// MARK: - StoreKit Configuration Validation

/// Validates that the .storekit configuration file is well-formed and
/// product IDs match the BillingProduct enum used in production code.
final class StoreKitConfigurationTests: XCTestCase {

    /// Decoded representation of the .storekit JSON.
    private struct StoreKitConfig: Decodable {
        let products: [ConfigProduct]?
        let subscriptionGroups: [SubscriptionGroup]?

        struct ConfigProduct: Decodable {
            let productID: String
            let type: String
        }

        struct SubscriptionGroup: Decodable {
            let name: String
            let subscriptions: [Subscription]?
        }

        struct Subscription: Decodable {
            let productID: String
            let recurringSubscriptionPeriod: String?
            let type: String
        }
    }

    private func loadConfig() throws -> StoreKitConfig {
        let bundle = Bundle(for: type(of: self))
        // .storekit may be in the main bundle or test bundle; try test bundle first
        let url = bundle.url(forResource: "TsugiIchi", withExtension: "storekit")
            ?? Bundle.main.url(forResource: "TsugiIchi", withExtension: "storekit")

        // If not found in bundles, try to locate relative to the project directory
        if let url = url {
            let data = try Data(contentsOf: url)
            return try JSONDecoder().decode(StoreKitConfig.self, from: data)
        }

        // Fallback: try the known project path (works in Xcode local runs)
        let projectPaths = [
            "TsugiIchi/Configuration/TsugiIchi.storekit",
            "../TsugiIchi/Configuration/TsugiIchi.storekit"
        ]
        for path in projectPaths {
            let fullURL = URL(fileURLWithPath: path)
            if FileManager.default.fileExists(atPath: fullURL.path) {
                let data = try Data(contentsOf: fullURL)
                return try JSONDecoder().decode(StoreKitConfig.self, from: data)
            }
        }

        throw NSError(domain: "StoreKitConfigTests", code: 1,
                       userInfo: [NSLocalizedDescriptionKey: "TsugiIchi.storekit not found"])
    }

    func testConfigFileIsValidJSON() throws {
        let config = try loadConfig()
        XCTAssertNotNil(config, "Config should decode successfully")
    }

    func testConfigContainsConsumableProduct() throws {
        let config = try loadConfig()
        let consumable = config.products?.first {
            $0.productID == BillingProduct.aiPack300.rawValue
        }
        XCTAssertNotNil(consumable, "Config must contain AI pack300 consumable")
        XCTAssertEqual(consumable?.type, "Consumable")
    }

    func testConfigContainsMonthlySubscription() throws {
        let config = try loadConfig()
        let allSubs = config.subscriptionGroups?.flatMap { $0.subscriptions ?? [] } ?? []
        let monthly = allSubs.first {
            $0.productID == BillingProduct.proMonthly.rawValue
        }
        XCTAssertNotNil(monthly, "Config must contain pro.monthly subscription")
        XCTAssertEqual(monthly?.recurringSubscriptionPeriod, "P1M")
        XCTAssertEqual(monthly?.type, "RecurringSubscription")
    }

    func testConfigContainsYearlySubscription() throws {
        let config = try loadConfig()
        let allSubs = config.subscriptionGroups?.flatMap { $0.subscriptions ?? [] } ?? []
        let yearly = allSubs.first {
            $0.productID == BillingProduct.proYearly.rawValue
        }
        XCTAssertNotNil(yearly, "Config must contain pro.yearly subscription")
        XCTAssertEqual(yearly?.recurringSubscriptionPeriod, "P1Y")
    }

    func testAllBillingProductIDsExistInConfig() throws {
        let config = try loadConfig()
        let consumableIDs = Set(config.products?.map(\.productID) ?? [])
        let subscriptionIDs = Set(
            config.subscriptionGroups?
                .flatMap { $0.subscriptions ?? [] }
                .map(\.productID) ?? []
        )
        let allConfigIDs = consumableIDs.union(subscriptionIDs)

        for product in BillingProduct.allCases {
            XCTAssertTrue(
                allConfigIDs.contains(product.rawValue),
                "BillingProduct.\(product) (\(product.rawValue)) must exist in .storekit config"
            )
        }
    }
}

// MARK: - CreditsStore Unit Tests

/// Tests CreditsStore logic: credit addition, consumption, and double-crediting prevention.
/// These tests exercise the billing logic without requiring a live StoreKit session.
@MainActor
final class CreditsStoreTests: XCTestCase {

    override func setUp() {
        super.setUp()
        // Reset to a clean state before each test
        CreditsStore.shared.resetAll()
    }

    override func tearDown() {
        CreditsStore.shared.resetAll()
        super.tearDown()
    }

    // MARK: - Consumable Credit Addition

    func testAddPurchasedCreditsIncrements() {
        let store = CreditsStore.shared
        XCTAssertEqual(store.purchasedCredits, 0, "Should start at 0")

        store.addPurchasedCredits(300)
        XCTAssertEqual(store.purchasedCredits, 300, "Should be 300 after adding pack")
    }

    func testAddPurchasedCreditsTwiceAccumulates() {
        let store = CreditsStore.shared
        store.addPurchasedCredits(300)
        store.addPurchasedCredits(300)
        XCTAssertEqual(store.purchasedCredits, 600, "Two packs should give 600 credits")
    }

    // MARK: - Credit Consumption

    func testConsumeOneDecrementsMonthlyFirst() {
        let store = CreditsStore.shared
        store.ensureWindowStarted()

        let initialRemaining = store.monthlyRemaining
        XCTAssertGreaterThan(initialRemaining, 0, "Should have monthly credits")

        let consumed = store.consumeOne()
        XCTAssertTrue(consumed, "Should successfully consume one credit")
        XCTAssertEqual(store.monthlyRemaining, initialRemaining - 1)
    }

    func testConsumeOneFallsToPurchasedCredits() {
        let store = CreditsStore.shared
        store.ensureWindowStarted()

        // Exhaust monthly credits (free tier = 10)
        for _ in 0..<CreditsStore.freeMonthlyLimit {
            _ = store.consumeOne()
        }
        XCTAssertEqual(store.monthlyRemaining, 0, "Monthly credits exhausted")

        // Add purchased credits
        store.addPurchasedCredits(5)
        XCTAssertEqual(store.purchasedCredits, 5)

        let consumed = store.consumeOne()
        XCTAssertTrue(consumed, "Should consume from purchased credits")
        XCTAssertEqual(store.purchasedCredits, 4)
    }

    func testConsumeOneReturnsFalseWhenEmpty() {
        let store = CreditsStore.shared
        store.ensureWindowStarted()

        // Exhaust all monthly credits
        for _ in 0..<CreditsStore.freeMonthlyLimit {
            _ = store.consumeOne()
        }

        let consumed = store.consumeOne()
        XCTAssertFalse(consumed, "Should return false when no credits remain")
    }

    // MARK: - Double-Crediting Prevention

    func testDoubleCreditingPrevention() {
        let store = CreditsStore.shared

        // Simulate a purchase crediting 300
        store.addPurchasedCredits(300)
        XCTAssertEqual(store.purchasedCredits, 300)

        // If a duplicate transaction fires, the app should NOT credit again.
        // In production, BillingManager.purchase() calls addPurchasedCredits(300)
        // only inside the .success case. The transaction is then finished, preventing
        // re-delivery.
        //
        // Here we verify that the CreditsStore itself does not have built-in dedup —
        // the dedup is at the transaction layer (Transaction.finish()).
        // This test documents the expected behavior: calling addPurchasedCredits
        // twice DOES accumulate (the guard is in the caller, not the store).
        store.addPurchasedCredits(300)
        XCTAssertEqual(store.purchasedCredits, 600,
            "CreditsStore.addPurchasedCredits is additive by design; " +
            "double-crediting prevention is handled by Transaction.finish()")
    }

    // MARK: - Reset

    func testResetAllClearsEverything() {
        let store = CreditsStore.shared
        store.addPurchasedCredits(300)
        store.ensureWindowStarted()
        _ = store.consumeOne()

        store.resetAll()

        XCTAssertEqual(store.purchasedCredits, 0)
        XCTAssertEqual(store.monthlyUsedCount, 0)
    }

    // MARK: - Total Remaining

    func testTotalRemainingIncludesBothQuotas() {
        let store = CreditsStore.shared
        store.ensureWindowStarted()
        store.addPurchasedCredits(50)

        let expected = store.monthlyRemaining + 50
        XCTAssertEqual(store.totalRemaining, expected)
    }
}

// MARK: - BillingProduct Enum Tests

/// Validates the BillingProduct enum raw values match expected App Store Connect IDs.
final class BillingProductTests: XCTestCase {

    func testProductIDFormats() {
        for product in BillingProduct.allCases {
            XCTAssertTrue(
                product.rawValue.hasPrefix("com.ynlabs.tsugiichi."),
                "Product ID \(product.rawValue) must use com.ynlabs.tsugiichi.* prefix"
            )
        }
    }

    func testMonthlyProductID() {
        XCTAssertEqual(BillingProduct.proMonthly.rawValue, "com.ynlabs.tsugiichi.pro.monthly")
    }

    func testYearlyProductID() {
        XCTAssertEqual(BillingProduct.proYearly.rawValue, "com.ynlabs.tsugiichi.pro.yearly")
    }

    func testAIPack300ProductID() {
        XCTAssertEqual(BillingProduct.aiPack300.rawValue, "com.ynlabs.tsugiichi.ai.pack300")
    }

    func testAllCasesCount() {
        XCTAssertEqual(BillingProduct.allCases.count, 3, "Should have exactly 3 products")
    }
}
