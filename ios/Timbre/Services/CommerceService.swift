import Foundation
import StoreKit
import Combine
import TimbreCore
import UIKit

/// StoreKit 2 commerce: Timbre Pro annual/monthly subscriptions and the lifetime unlock.
/// Access comes only from verified, unrevoked, unexpired transactions.
@MainActor
final class CommerceService: ObservableObject {
    @Published private(set) var isPro = false
    @Published private(set) var entitlementResolved = false
    @Published private(set) var loading = false
    @Published private(set) var purchasing: String?
    @Published private(set) var products: [Product] = []
    @Published private(set) var error: String?
    @Published private(set) var pending = false
    @Published private(set) var trialEligible = true
    @Published private(set) var activeProductID: String?
    @Published private(set) var renewalDate: Date?
    private var updatesTask: Task<Void, Never>?
    private var refreshInProgress = false
    private var refreshRevision = 0
    private var refreshWaiters: [CheckedContinuation<Void, Never>] = []
    /// A subscription that lapses without renewing sends no transaction: entitlements are checked again whenever the
    /// app comes forward, and at the moment the active subscription is due to end.
    private var foreground: AnyCancellable?
    private var expiryCheck: Task<Void, Never>?
    private var expiryDate: Date?

    init() {
        updatesTask = Task { [weak self] in
            for await result in Transaction.updates {
                guard !Task.isCancelled else { return }
                guard case .verified(let transaction) = result, TimbreProduct.all.contains(transaction.productID) else { continue }
                await self?.refreshEntitlements()
                self?.pending = false
                await transaction.finish()
            }
        }
        Task { [weak self] in await self?.refreshEntitlements() }
        foreground = NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)
            .sink { [weak self] _ in Task { await self?.refreshEntitlements() } }
    }

    deinit {
        updatesTask?.cancel()
        expiryCheck?.cancel()
    }

    /// Checks again a moment after the active subscription's end date, so an expiry without renewal takes Pro away
    /// while the app stays open (one that renews arrives as a transaction first).
    private func scheduleExpiryCheck(_ date: Date?) {
        // Called at the end of every refresh: a check already waiting for this date stays as it is.
        guard date != expiryDate else { return }
        expiryDate = date
        expiryCheck?.cancel()
        expiryCheck = nil
        guard let date else { return }
        let wait = max(1, date.timeIntervalSinceNow + 2)
        // Further off than this the app will have come forward (and checked) many times before.
        guard wait < 45 * 86_400 else { return }
        expiryCheck = Task { [weak self] in
            try? await Task.sleep(for: .seconds(wait))
            guard !Task.isCancelled else { return }
            await self?.refreshEntitlements()
        }
    }

    var annual: Product? { products.first { $0.id == TimbreProduct.annual } }
    var monthly: Product? { products.first { $0.id == TimbreProduct.monthly } }
    var lifetime: Product? { products.first { $0.id == TimbreProduct.lifetime } }

    /// "14 days free" style label for the annual intro offer, when eligible.
    var trialLabel: String? {
        guard trialEligible, let offer = annual?.subscription?.introductoryOffer, offer.paymentMode == .freeTrial else { return nil }
        let period = offer.period
        let count = period.value
        switch period.unit {
        case .day: return String(localized: "\(count)-day free trial")
        case .week: return String(localized: "\(count * 7)-day free trial")
        case .month: return String(localized: "\(count)-month free trial")
        default: return String(localized: "Free trial")
        }
    }

    func load() async {
        guard !loading else { return }
        loading = true
        error = nil
        // An Ask to Buy request a parent declined never sends a transaction: a paywall opening again starts clear, and a
        // repeat request is StoreKit's to handle.
        pending = false
        defer { loading = false }
        await refreshEntitlements()
        do {
            let fetched = try await Product.products(for: TimbreProduct.all)
            products = TimbreProduct.all.compactMap { id in fetched.first { $0.id == id } }
            if let subscription = annual?.subscription { trialEligible = await subscription.isEligibleForIntroOffer }
            if products.isEmpty { error = String(localized: "Timbre Pro is unavailable in the App Store right now. Please try again later.") }
        } catch { self.error = error.localizedDescription }
    }

    /// Buys `product`; `options` carries an offer to apply (a win-back offer). An introductory offer applies by itself.
    @discardableResult
    func purchase(_ product: Product, options: Set<Product.PurchaseOption> = []) async -> Bool {
        guard purchasing == nil else { return false }
        purchasing = product.id
        error = nil
        pending = false
        defer { purchasing = nil }
        do {
            switch try await product.purchase(options: options) {
            case .success(let result):
                guard case .verified(let transaction) = result, TimbreProduct.all.contains(transaction.productID) else {
                    error = String(localized: "The App Store purchase could not be verified. Restore purchases or try again.")
                    return false
                }
                await refreshEntitlements()
                await transaction.finish()
                return isPro
            case .pending:
                pending = true
            case .userCancelled:
                break
            @unknown default:
                error = String(localized: "The App Store returned an unknown status. Please restore purchases.")
            }
        } catch { self.error = error.localizedDescription }
        return false
    }

    func restore() async {
        guard !loading else { return }
        loading = true
        error = nil
        pending = false
        defer { loading = false }
        do {
            try await StoreKit.AppStore.sync()
            await refreshEntitlements()
            if !isPro { error = String(localized: "No Timbre Pro purchase was found for this Apple Account.") }
        } catch { self.error = error.localizedDescription }
    }

    func refreshEntitlements() async {
        refreshRevision += 1
        if refreshInProgress {
            await withCheckedContinuation { refreshWaiters.append($0) }
            return
        }
        refreshInProgress = true
        // Init, foreground and transaction updates can overlap; publish only the newest snapshot.
        while true {
            let revision = refreshRevision
            var evidence: [EntitlementEvidence] = []
            var active: (String, Date?)?
            for await result in Transaction.currentEntitlements {
                guard case .verified(let transaction) = result, TimbreProduct.all.contains(transaction.productID) else { continue }
                let item = EntitlementEvidence(productID: transaction.productID, isSubscription: transaction.productType == .autoRenewable,
                                               revoked: transaction.revocationDate != nil, expiresAt: transaction.expirationDate)
                evidence.append(item)
                if AccessPolicy.isPro([item]) { active = (transaction.productID, transaction.expirationDate) }
            }
            guard revision == refreshRevision else { continue }
            isPro = AccessPolicy.isPro(evidence)
            activeProductID = active?.0
            renewalDate = active?.1
            entitlementResolved = true
            scheduleExpiryCheck(active?.1)
            break
        }
        refreshInProgress = false
        let waiting = refreshWaiters
        refreshWaiters.removeAll()
        for continuation in waiting { continuation.resume() }
    }
}
