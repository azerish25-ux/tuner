import XCTest
import StoreKit
import StoreKitTest
import TimbreCore
@testable import Timbre

/// Local StoreKit transactions only. Run serially: SKTestSession has one shared environment.
@MainActor
final class CommerceIntegrationTests: XCTestCase {
    private var session: SKTestSession!
    private var commerce: CommerceService!

    override func setUp() async throws {
        try await super.setUp()
        session = try SKTestSession(configurationFileNamed: "Timbre")
        session.resetToDefaultState()
        session.clearTransactions()
        session.disableDialogs = true
        try await StoreKitTestEnvironment.waitUntilClean(session)
        commerce = CommerceService()
        await commerce.load()
    }

    override func tearDown() async throws {
        commerce = nil
        session?.clearTransactions()
        session = nil
        try await super.tearDown()
    }

    /// Waits for `condition` without touching StoreKit: what arrives by itself (a transaction update). The limit is
    /// generous because the StoreKit test daemon is slow on a busy runner; a passing run returns as soon as it holds.
    private func waitUntil(timeout: TimeInterval = 30, _ condition: @escaping () -> Bool) async throws {
        let deadline = Date().addingTimeInterval(timeout)
        while !condition() {
            guard Date() < deadline else { XCTFail("Timed out"); return }
            try await Task.sleep(for: .milliseconds(100))
        }
    }

    /// Checks again until `condition` holds, refreshing entitlements as the app does whenever it comes forward: a
    /// failed renewal sends no transaction, and the status StoreKit reports for a renewal the session forces arrives a
    /// moment later.
    private func refreshUntil(timeout: TimeInterval = 30, _ condition: @escaping () -> Bool) async throws {
        let deadline = Date().addingTimeInterval(timeout)
        while true {
            await commerce.refreshEntitlements()
            if condition() { return }
            guard Date() < deadline else { XCTFail("Timed out"); return }
            try await Task.sleep(for: .milliseconds(250))
        }
    }

    /// What the session and the service say about a purchase, for a failure message.
    private func purchaseState(_ productID: String) -> String {
        let recorded = session.allTransactions().filter { $0.productIdentifier == productID }.count
        return "pro \(commerce.isPro), pending \(commerce.pending), error \(commerce.error ?? "none"), "
            + "\(recorded) session transactions for \(productID)"
    }

    /// Buys `product` the way the paywall does and waits for Pro; returns what `purchase` itself reported. On a busy
    /// runner the StoreKit test daemon can fail a purchase with a transient error before it records anything (the
    /// paywall's button would simply be tapped again: so is this one, once), or record it after `purchase` has
    /// returned (the refresh the app makes on coming forward picks it up: so does the wait).
    @discardableResult
    private func buy(_ product: Product, timeout: TimeInterval = 30) async throws -> Bool {
        var granted = await commerce.purchase(product)
        let recorded = session.allTransactions().contains { $0.productIdentifier == product.id }
        if !granted, !commerce.isPro, !commerce.pending, !recorded, let first = commerce.error {
            print("The purchase of \(product.id) failed before StoreKit recorded it (\(first)); buying again")
            granted = await commerce.purchase(product)
        }
        let deadline = Date().addingTimeInterval(timeout)
        while !commerce.isPro {
            guard Date() < deadline else {
                XCTFail("\(product.id) never granted Pro: \(purchaseState(product.id))")
                break
            }
            try await Task.sleep(for: .milliseconds(250))
            await commerce.refreshEntitlements()
        }
        return granted
    }

    private func subscribeMonthly() async throws {
        let monthly = try XCTUnwrap(commerce.monthly)
        try await buy(monthly)
        XCTAssertNil(commerce.billingIssue)
    }

    func testProductsLoadInPlanOrderWithTrial() throws {
        XCTAssertFalse(commerce.isPro)
        XCTAssertEqual(commerce.products.map(\.id), TimbreProduct.all, commerce.error ?? "products did not load")
        let annual = try XCTUnwrap(commerce.annual)
        XCTAssertEqual(annual.type, .autoRenewable)
        XCTAssertEqual(annual.subscription?.introductoryOffer?.paymentMode, .freeTrial)
        XCTAssertNotNil(commerce.trialLabel)
        XCTAssertEqual(commerce.lifetime?.type, .nonConsumable)
    }

    func testAnnualSubscriptionGrantsPro() async throws {
        let annual = try XCTUnwrap(commerce.annual)
        let granted = try await buy(annual)
        XCTAssertTrue(granted || commerce.isPro, purchaseState(annual.id))
        XCTAssertEqual(commerce.activeProductID, TimbreProduct.annual)
        XCTAssertNotNil(commerce.renewalDate)
    }

    func testLifetimeGrantsProWithoutRenewal() async throws {
        let lifetime = try XCTUnwrap(commerce.lifetime)
        try await buy(lifetime)
        XCTAssertNil(commerce.renewalDate)
    }

    func testExpiredSubscriptionReturnsToFree() async throws {
        let monthly = try XCTUnwrap(commerce.monthly)
        try await buy(monthly)
        try session.expireSubscription(productIdentifier: TimbreProduct.monthly)
        try await Task.sleep(for: .milliseconds(400))
        try await refreshUntil { !self.commerce.isPro }
    }

    func testRefundRevokesLifetime() async throws {
        let lifetime = try XCTUnwrap(commerce.lifetime)
        try await buy(lifetime)
        let transaction = try XCTUnwrap(session.allTransactions().first { $0.productIdentifier == TimbreProduct.lifetime })
        try session.refundTransaction(identifier: transaction.identifier)
        try await Task.sleep(for: .milliseconds(400))
        try await refreshUntil { !self.commerce.isPro }
    }

    func testExistingPurchaseIsFoundByFreshService() async throws {
        commerce = nil
        _ = try await session.buyProduct(identifier: TimbreProduct.lifetime, options: [])
        try await StoreKitTestEnvironment.waitUntilVerifiedPurchase(session, productID: TimbreProduct.lifetime)
        commerce = CommerceService()
        await commerce.load()
        try await waitUntil { self.commerce.isPro }
    }

    // MARK: Billing problems and Ask to Buy

    func testProStaysOnThroughTheBillingGracePeriod() async throws {
        session.billingGracePeriodIsEnabled = true
        session.shouldEnterBillingRetryOnRenewal = true
        try await subscribeMonthly()
        try session.forceRenewalOfSubscription(productIdentifier: TimbreProduct.monthly)
        try await refreshUntil { self.commerce.billingIssue != nil }
        guard case .gracePeriod? = commerce.billingIssue else {
            return XCTFail("expected the grace period, got \(String(describing: commerce.billingIssue))")
        }
        XCTAssertTrue(commerce.isPro, "a payer keeps Pro while the App Store retries the payment")
    }

    func testBillingRetryPausesProAndSaysWhy() async throws {
        session.billingGracePeriodIsEnabled = false
        session.shouldEnterBillingRetryOnRenewal = true
        try await subscribeMonthly()
        try session.forceRenewalOfSubscription(productIdentifier: TimbreProduct.monthly)
        try await refreshUntil { self.commerce.billingIssue == .billingRetry }
        XCTAssertFalse(commerce.isPro)
    }

    func testAskToBuyWaitsForTheParentsYes() async throws {
        session.askToBuyEnabled = true
        let annual = try XCTUnwrap(commerce.annual)
        let granted = await commerce.purchase(annual)
        XCTAssertFalse(granted)
        XCTAssertTrue(commerce.pending)
        XCTAssertFalse(commerce.isPro)
        let request = try XCTUnwrap(session.allTransactions().first { $0.productIdentifier == TimbreProduct.annual })
        try session.approveAskToBuyTransaction(identifier: request.identifier)
        try await waitUntil { self.commerce.isPro }
        XCTAssertFalse(commerce.pending)
    }

    func testAskToBuyDeclinedStaysFree() async throws {
        session.askToBuyEnabled = true
        let annual = try XCTUnwrap(commerce.annual)
        _ = await commerce.purchase(annual)
        XCTAssertTrue(commerce.pending)
        let request = try XCTUnwrap(session.allTransactions().first { $0.productIdentifier == TimbreProduct.annual })
        try session.declineAskToBuyTransaction(identifier: request.identifier)
        try await Task.sleep(for: .milliseconds(400))
        await commerce.refreshEntitlements()
        XCTAssertFalse(commerce.isPro)
        // A paywall opening again starts clear.
        await commerce.load()
        XCTAssertFalse(commerce.pending)
    }
}
