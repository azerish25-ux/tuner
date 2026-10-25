import Foundation
import StoreKit
import Combine
import TimbreCore
import UIKit

/// A subscription payment the App Store couldn't collect (`CommerceService.billingIssue`, `BillingIssueBanner`).
enum BillingIssue: Equatable {
    /// The Billing Grace Period: Pro carries on until `until` while the App Store retries the payment.
    case gracePeriod(until: Date?)
    /// Billing Retry: Pro has paused while the App Store keeps retrying the payment.
    case billingRetry

    /// The issue the group's statuses show, if any. A family member's active status, or any active one, means none.
    init?(_ statuses: [Product.SubscriptionInfo.Status]) {
        if statuses.contains(where: { $0.state == .subscribed }) { return nil }
        if let grace = statuses.first(where: { $0.state == .inGracePeriod }) {
            var until: Date?
            if case .verified(let renewal) = grace.renewalInfo { until = renewal.gracePeriodExpirationDate }
            self = .gracePeriod(until: until)
        } else if statuses.contains(where: { $0.state == .inBillingRetryPeriod }) {
            self = .billingRetry
        } else {
            return nil
        }
    }
}

/// StoreKit 2 commerce: Timbre Pro annual/monthly subscriptions and the lifetime unlock.
/// Access comes only from verified, unrevoked transactions in the current entitlements (`AccessPolicy.isPro`).
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
    /// A subscription payment that didn't go through, while the App Store retries it; nil for a lifetime owner.
    @Published private(set) var billingIssue: BillingIssue?
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
            .sink { [weak self] _ in
                guard let self else { return }
                Task { await self.refreshEntitlements() }
            }
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
                    Analytics.log("purchase_failed", ["product": product.id, "reason": "unverified"])
                    return false
                }
                await refreshEntitlements()
                await transaction.finish()
                return isPro
            case .pending:
                pending = true
            case .userCancelled:
                Analytics.log("purchase_cancelled", ["product": product.id])
            @unknown default:
                error = String(localized: "The App Store returned an unknown status. Please restore purchases.")
                Analytics.log("purchase_failed", ["product": product.id, "reason": "unknown_result"])
            }
        } catch {
            self.error = error.localizedDescription
            let reason = Self.failureReason(error)
            Analytics.log(reason == "cancelled" ? "purchase_cancelled" : "purchase_failed", ["product": product.id, "reason": reason])
        }
        return false
    }

    /// A short, non-identifying name for why a purchase threw.
    private static func failureReason(_ error: Error) -> String {
        if let store = error as? StoreKitError {
            switch store {
            case .userCancelled: return "cancelled"
            case .networkError: return "network"
            case .systemError: return "system"
            case .notAvailableInStorefront: return "storefront"
            case .notEntitled: return "not_entitled"
            default: return "store_unknown"
            }
        }
        return error is Product.PurchaseError ? "purchase_error" : "other"
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
                // Lifetime wins: it never lapses, so there is no renewal date to show or to wait for.
                if AccessPolicy.isPro([item]), active?.0 != TimbreProduct.lifetime { active = (transaction.productID, transaction.expirationDate) }
            }
            var issue: BillingIssue?
            if active?.0 != TimbreProduct.lifetime { issue = await Self.currentBillingIssue() }
            guard revision == refreshRevision else { continue }
            isPro = AccessPolicy.isPro(evidence)
            activeProductID = active?.0
            renewalDate = active?.1
            billingIssue = issue
            entitlementResolved = true
            // In the grace period the paid period has already ended: Pro ends with the grace period instead.
            if case .gracePeriod(let until?) = issue { scheduleExpiryCheck(until) } else { scheduleExpiryCheck(active?.1) }
            break
        }
        refreshInProgress = false
        let waiting = refreshWaiters
        refreshWaiters.removeAll()
        for continuation in waiting { continuation.resume() }
    }

    /// The subscription group's billing problem, if any. The group is found through the latest transaction of either
    /// plan, so someone who never subscribed costs no status request.
    private static func currentBillingIssue() async -> BillingIssue? {
        for productID in [TimbreProduct.annual, TimbreProduct.monthly] {
            guard let latest = await Transaction.latest(for: productID), case .verified(let transaction) = latest,
                  let group = transaction.subscriptionGroupID else { continue }
            guard let statuses = try? await Product.SubscriptionInfo.status(for: group) else { return nil }
            return BillingIssue(statuses)
        }
        return nil
    }
}
