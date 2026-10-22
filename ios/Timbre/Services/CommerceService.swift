import Foundation
import StoreKit
import Combine

/// Apple purchases are verified by StoreKit. Google Play ownership is not an Apple entitlement.
@MainActor
final class CommerceService: ObservableObject {
    static let productID = "timbre_plus_lifetime"
    @Published private(set) var isPlus = false
    @Published private(set) var entitlementResolved = false
    @Published private(set) var loading = false
    @Published private(set) var product: Product?
    @Published private(set) var error: String?
    @Published private(set) var pending = false
    private var updatesTask: Task<Void, Never>?
    private var entitlementRefreshInProgress = false
    private var entitlementRefreshRevision = 0
    private var entitlementRefreshWaiters: [CheckedContinuation<Void, Never>] = []

    init() {
        updatesTask = Task { [weak self] in
            for await result in Transaction.updates {
                guard !Task.isCancelled else { return }
                guard case .verified(let transaction) = result,
                      transaction.productID == Self.productID else { continue }
                await self?.refreshEntitlements()
                self?.pending = false
                await transaction.finish()
            }
        }
        Task { [weak self] in await self?.refreshEntitlements() }
    }

    deinit { updatesTask?.cancel() }

    func load() async {
        guard !loading else { return }
        loading = true
        error = nil
        defer { loading = false }
        await refreshEntitlements()
        do {
            product = try await Product.products(for: [Self.productID]).first { $0.id == Self.productID && $0.type == .nonConsumable }
            if product == nil { error = "Timbre Plus is unavailable in the App Store right now. Please try again later." }
        } catch { self.error = error.localizedDescription }
    }

    func purchase() async {
        guard !loading else { return }
        guard let product else {
            error = "Timbre Plus is unavailable in the App Store right now. Please try again later."
            return
        }
        loading = true
        error = nil
        pending = false
        defer { loading = false }
        do {
            switch try await product.purchase() {
            case .success(let result):
                guard case .verified(let transaction) = result,
                      transaction.productID == Self.productID else {
                    error = "The App Store purchase could not be verified. Please restore purchases or try again."
                    return
                }
                await refreshEntitlements()
                await transaction.finish()
            case .pending:
                pending = true
            case .userCancelled:
                break
            @unknown default:
                error = "The App Store returned an unknown purchase status. Please restore purchases."
            }
        } catch { self.error = error.localizedDescription }
    }

    func restore() async {
        guard !loading else { return }
        loading = true
        error = nil
        defer { loading = false }
        do {
            try await StoreKit.AppStore.sync()
            await refreshEntitlements()
            if !isPlus { error = "No Timbre Plus purchase was found for this Apple Account." }
        } catch { self.error = error.localizedDescription }
    }

    private func refreshEntitlements() async {
        entitlementRefreshRevision += 1
        if entitlementRefreshInProgress {
            await withCheckedContinuation { entitlementRefreshWaiters.append($0) }
            return
        }
        entitlementRefreshInProgress = true
        // Init, foreground loading and transaction updates can request snapshots while
        // an earlier enumeration is suspended. Never publish that superseded snapshot;
        // enumerate again and release every caller only after the newest request settles.
        while true {
            let revision = entitlementRefreshRevision
            var entitled = false
            for await result in Transaction.currentEntitlements {
                guard case .verified(let transaction) = result,
                      transaction.productID == Self.productID,
                      transaction.productType == .nonConsumable,
                      transaction.revocationDate == nil,
                      !transaction.isUpgraded else { continue }
                entitled = true
            }
            guard revision == entitlementRefreshRevision else { continue }
            isPlus = entitled
            entitlementResolved = true
            break
        }
        entitlementRefreshInProgress = false
        let waiting = entitlementRefreshWaiters
        entitlementRefreshWaiters.removeAll()
        for continuation in waiting { continuation.resume() }
    }
}
