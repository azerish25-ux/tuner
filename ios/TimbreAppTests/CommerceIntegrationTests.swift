import XCTest
import StoreKit
import StoreKitTest
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

    func testInitialFreeAndLocalProduct() async throws {
        XCTAssertFalse(commerce.isPlus)
        XCTAssertFalse(commerce.loading)
        XCTAssertFalse(commerce.pending)
        let product = try XCTUnwrap(commerce.product, commerce.error ?? "Product did not load")
        XCTAssertEqual(product.id, CommerceService.productID)
        XCTAssertEqual(product.type, .nonConsumable)
        XCTAssertFalse(product.displayPrice.isEmpty)
        XCTAssertNil(commerce.error)
    }

    func testPurchaseGrantsVerifiedLifetimeAccess() async throws {
        _ = try XCTUnwrap(commerce.product)
        await commerce.purchase()
        try await waitUntil { self.commerce.isPlus }
        XCTAssertFalse(commerce.pending)
        XCTAssertNil(commerce.error)
        let transactions = session.allTransactions()
        XCTAssertEqual(transactions.filter { $0.productIdentifier == CommerceService.productID }.count, 1)
    }

    func testExistingVerifiedPurchaseRestoresInFreshService() async throws {
        try session.buyProduct(productIdentifier: CommerceService.productID)
        // Re-create service; entitlement must come from StoreKit, never persisted local flags.
        commerce = CommerceService()
        await commerce.load()
        try await waitUntil { self.commerce.isPlus }
        await commerce.restore()
        XCTAssertTrue(commerce.isPlus)
        XCTAssertNil(commerce.error)
    }

    func testRefundRevokesAccessAndSurvivesReload() async throws {
        await commerce.purchase()
        try await waitUntil { self.commerce.isPlus }
        let transaction = try XCTUnwrap(session.allTransactions().first { $0.productIdentifier == CommerceService.productID })
        async let overlappingLoad: Void = commerce.load()
        try session.refundTransaction(identifier: transaction.identifier)
        await overlappingLoad
        try await waitUntil { !self.commerce.isPlus }
        await commerce.load()
        XCTAssertFalse(commerce.isPlus)
    }

    func testAskToBuyRemainsFreeUntilApproved() async throws {
        session.askToBuyEnabled = true
        await commerce.purchase()
        XCTAssertTrue(commerce.pending)
        XCTAssertFalse(commerce.isPlus)
        let transaction = try XCTUnwrap(session.allTransactions().first { $0.productIdentifier == CommerceService.productID })
        try session.approveAskToBuyTransaction(identifier: transaction.identifier)
        try await waitUntil { self.commerce.isPlus && !self.commerce.pending }
    }

    func testEmptyRestoreDoesNotInventEntitlement() async {
        await commerce.restore()
        XCTAssertFalse(commerce.isPlus)
        XCTAssertNotNil(commerce.error)
    }

    private func waitUntil(timeout: TimeInterval = 12, _ condition: @escaping @MainActor () -> Bool) async throws {
        let deadline = Date().addingTimeInterval(timeout)
        while !condition(), Date() < deadline { try await Task.sleep(for: .milliseconds(100)) }
        XCTAssertTrue(condition(), "StoreKit transaction update did not arrive before timeout")
    }
}
