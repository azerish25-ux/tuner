import Foundation
import StoreKit
import StoreKitTest

/// StoreKit's clearTransactions propagates asynchronously to currentEntitlements.
/// Wait for the actual verified store view, not the app's local entitlement flag.
@MainActor
enum StoreKitTestEnvironment {
    enum Failure: Error { case transactionsDidNotClear }
    static func waitUntilClean(_ session: SKTestSession, productID: String = "timbre_plus_lifetime", timeout: TimeInterval = 12) async throws {
        let deadline = Date().addingTimeInterval(timeout)
        var consecutiveCleanSnapshots = 0
        while Date() < deadline {
            var activePurchase = false
            for await result in Transaction.currentEntitlements {
                guard case .verified(let transaction) = result,
                      transaction.productID == productID,
                      transaction.productType == .nonConsumable,
                      transaction.revocationDate == nil,
                      !transaction.isUpgraded else { continue }
                activePurchase = true
            }
            let clean = !activePurchase && session.allTransactions().isEmpty
            consecutiveCleanSnapshots = clean ? consecutiveCleanSnapshots + 1 : 0
            if consecutiveCleanSnapshots >= 2 { return }
            try await Task.sleep(for: .milliseconds(100))
        }
        throw Failure.transactionsDidNotClear
    }
}
