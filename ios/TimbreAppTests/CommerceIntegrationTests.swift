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
        var cleanupError: Error?
        if let session {
            session.clearTransactions()
            do { try await StoreKitTestEnvironment.waitUntilClean(session) }
            catch { cleanupError = error }
        }
        session = nil
        try await super.tearDown()
        if let cleanupError { throw cleanupError }
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
        XCTAssertEqual(annual.id, TimbreProduct.annual, "no test arm runs: the standard year is sold")
        XCTAssertEqual(annual.type, .autoRenewable)
        XCTAssertEqual(annual.subscription?.introductoryOffer?.paymentMode, .freeTrial)
        XCTAssertTrue(try XCTUnwrap(commerce.trialLabel(for: annual)).contains("14"))
        XCTAssertEqual(commerce.lifetime?.type, .nonConsumable)
    }

    // MARK: Free trials on any plan

    /// Every plan's own free trial is found and said, whichever plan it is on: the year's two weeks, a test arm's one
    /// week; a plan without one (the fixture's month, lifetime) starts paid.
    func testEachPlansFreeTrialIsItsOwn() throws {
        let annual = try XCTUnwrap(commerce.annual)
        let weekArm = try XCTUnwrap(commerce.products.first { $0.id == TimbreProduct.annualC })
        XCTAssertEqual(commerce.trialDays(for: annual), 14)
        XCTAssertEqual(commerce.trialDays(for: weekArm), 7)
        XCTAssertTrue(try XCTUnwrap(commerce.trialLabel(for: weekArm)).contains("7"))
        XCTAssertNil(commerce.trialDays(for: commerce.monthly))
        XCTAssertNil(commerce.trialLabel(for: commerce.monthly))
        XCTAssertNil(commerce.trialDays(for: commerce.lifetime))
        XCTAssertNil(commerce.trialDays(for: nil))
    }

    /// After a free trial in the group, no plan offers another.
    func testNoTrialAfterOne() async throws {
        let annual = try XCTUnwrap(commerce.annual)
        _ = await commerce.purchase(annual)
        try await waitUntil { self.commerce.isPro }
        await commerce.load()
        XCTAssertNil(commerce.trialDays(for: commerce.yearly(for: TimbreProduct.annualC)))
        XCTAssertNil(commerce.trialDays(for: commerce.annual))
    }

    // MARK: The yearly price test

    /// A remote paywall arm that names a yearly test product sells it; anything else sells the standard year.
    func testRemoteArmSellsItsYearlyPlan() throws {
        XCTAssertEqual(CommerceService.annualProductID(remote: TimbreProduct.annualB), TimbreProduct.annualB)
        XCTAssertEqual(CommerceService.annualProductID(remote: TimbreProduct.annualC), TimbreProduct.annualC)
        for other in [nil, TimbreProduct.monthly, TimbreProduct.lifetime, "timbre_pro_annual_typo"] {
            XCTAssertEqual(CommerceService.annualProductID(remote: other), TimbreProduct.annual, other ?? "nil")
        }
        XCTAssertEqual(commerce.yearly(for: TimbreProduct.annualB)?.id, TimbreProduct.annualB)
        XCTAssertEqual(commerce.yearly(for: TimbreProduct.annualC)?.id, TimbreProduct.annualC)
        XCTAssertEqual(commerce.yearly(for: "timbre_pro_annual_typo")?.id, TimbreProduct.annual)
        XCTAssertEqual(commerce.yearly(for: nil)?.id, TimbreProduct.annual)
    }

    /// Buying the arm's yearly plan grants Pro, as the standard year does.
    func testYearlyArmGrantsPro() async throws {
        let arm = try XCTUnwrap(commerce.yearly(for: TimbreProduct.annualB))
        XCTAssertEqual(arm.id, TimbreProduct.annualB)
        XCTAssertEqual(commerce.trialDays(for: arm), 14)
        let granted = await commerce.purchase(arm)
        try await waitUntil { self.commerce.isPro }
        XCTAssertTrue(granted || commerce.isPro)
        XCTAssertEqual(commerce.activeProductID, TimbreProduct.annualB)
        XCTAssertNotNil(commerce.renewalDate)
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
