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

    private func waitUntil(timeout: TimeInterval = 10, _ condition: @escaping () -> Bool) async throws {
        let deadline = Date().addingTimeInterval(timeout)
        while !condition() {
            guard Date() < deadline else { XCTFail("Timed out"); return }
            try await Task.sleep(for: .milliseconds(100))
        }
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
        let granted = await commerce.purchase(annual)
        try await waitUntil { self.commerce.isPro }
        XCTAssertTrue(granted || commerce.isPro)
        XCTAssertEqual(commerce.activeProductID, TimbreProduct.annual)
        XCTAssertNotNil(commerce.renewalDate)
    }

    func testLifetimeGrantsProWithoutRenewal() async throws {
        let lifetime = try XCTUnwrap(commerce.lifetime)
        _ = await commerce.purchase(lifetime)
        try await waitUntil { self.commerce.isPro }
        XCTAssertNil(commerce.renewalDate)
    }

    func testExpiredSubscriptionReturnsToFree() async throws {
        let monthly = try XCTUnwrap(commerce.monthly)
        _ = await commerce.purchase(monthly)
        try await waitUntil { self.commerce.isPro }
        try session.expireSubscription(productIdentifier: TimbreProduct.monthly)
        try await Task.sleep(for: .milliseconds(400))
        await commerce.refreshEntitlements()
        try await waitUntil { !self.commerce.isPro }
    }

    func testRefundRevokesLifetime() async throws {
        let lifetime = try XCTUnwrap(commerce.lifetime)
        _ = await commerce.purchase(lifetime)
        try await waitUntil { self.commerce.isPro }
        let transaction = try XCTUnwrap(session.allTransactions().first { $0.productIdentifier == TimbreProduct.lifetime })
        try session.refundTransaction(identifier: transaction.identifier)
        try await Task.sleep(for: .milliseconds(400))
        await commerce.refreshEntitlements()
        try await waitUntil { !self.commerce.isPro }
    }

    func testExistingPurchaseIsFoundByFreshService() async throws {
        commerce = nil
        _ = try await session.buyProduct(identifier: TimbreProduct.lifetime, options: [])
        try await StoreKitTestEnvironment.waitUntilVerifiedPurchase(session, productID: TimbreProduct.lifetime)
        commerce = CommerceService()
        await commerce.load()
        try await waitUntil { self.commerce.isPro }
    }
}
