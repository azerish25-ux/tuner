import Foundation
import StoreKit
import StoreKitTest
import TimbreCore

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

    static func waitUntilVerifiedPurchase(_ session: SKTestSession, productID: String, timeout: TimeInterval = 12) async throws {
        let deadline = Date().addingTimeInterval(timeout)
        var snapshot: [String] = []
        while Date() < deadline {
            snapshot.removeAll()
            for await result in Transaction.currentEntitlements {
                if case .verified(let transaction) = result {
                    snapshot.append(transaction.productID)
                    if transaction.productID == productID, transaction.revocationDate == nil { return }
                }
            }
            try await Task.sleep(for: .milliseconds(100))
        }
        throw Failure.verifiedPurchaseDidNotPropagate("entitlements=[\(snapshot.joined(separator: ","))]")
    }

    static func waitUntilClean(_ session: SKTestSession, timeout: TimeInterval = 12) async throws {
        let deadline = Date().addingTimeInterval(timeout)
        var clean = 0
        while Date() < deadline {
            var active = false
            for await result in Transaction.currentEntitlements {
                if case .verified(let transaction) = result, TimbreProduct.all.contains(transaction.productID), transaction.revocationDate == nil { active = true }
            }
            clean = !active && session.allTransactions().isEmpty ? clean + 1 : 0
            if clean >= 2 { return }
            try await Task.sleep(for: .milliseconds(100))
        }
        throw Failure.transactionsDidNotClear
    }
}
