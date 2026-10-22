import Foundation
import StoreKit
import StoreKitTest

/// StoreKit's clearTransactions propagates asynchronously to currentEntitlements.
/// Wait for the actual verified store view, not the app's local entitlement flag.
@MainActor
enum StoreKitTestEnvironment {
    enum Failure: Error, CustomStringConvertible {
        case transactionsDidNotClear
        case verifiedPurchaseDidNotPropagate(String)
        var description: String {
            switch self {
            case .transactionsDidNotClear: return "StoreKit test transactions did not clear before timeout"
            case .verifiedPurchaseDidNotPropagate(let details): return "External StoreKit purchase did not reach verified currentEntitlements: " + details
            }
        }
    }
    /// External test purchases are asynchronous across StoreKit's transaction and
    /// entitlement views. Establish the real store precondition before cold-launching
    /// a service; waiting on that service would conflate fixture setup with app behavior.
    static func waitUntilVerifiedPurchase(_ session: SKTestSession, productID: String = "timbre_plus_lifetime", timeout: TimeInterval = 12) async throws {
        let deadline = Date().addingTimeInterval(timeout)
        var lastSnapshot: [String] = []
        while Date() < deadline {
            lastSnapshot.removeAll()
            for await result in Transaction.currentEntitlements {
                switch result {
                case .verified(let transaction):
                    lastSnapshot.append("verified:\(transaction.productID),revoked:\(transaction.revocationDate != nil),type:\(transaction.productType)")
                    if transaction.productID == productID, transaction.productType == .nonConsumable,
                       transaction.revocationDate == nil, !transaction.isUpgraded { return }
                case .unverified(let transaction, let error):
                    lastSnapshot.append("unverified:\(transaction.productID),error:\(error)")
                }
            }
            try await Task.sleep(for: .milliseconds(100))
        }
        let transactions = session.allTransactions().map { "\($0.productIdentifier):\($0.identifier):state=\($0.state.rawValue)" }.joined(separator: ",")
        throw Failure.verifiedPurchaseDidNotPropagate("session=[\(transactions)], entitlementSnapshot=[\(lastSnapshot.joined(separator: ","))]")
    }
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
