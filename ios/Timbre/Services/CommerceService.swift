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
                SubscriptionOutcomes.transactionArrived(transaction)
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

    /// The yearly plan the paywall sells: the one this install's paywall arm names (`RemoteConfig.annualProductID`),
    /// else the standard one, also when the named one isn't on sale in this storefront.
    var annual: Product? { yearly(for: RemoteConfig.shared.annualProductID) }
    var monthly: Product? { products.first { $0.id == TimbreProduct.monthly } }
    var lifetime: Product? { products.first { $0.id == TimbreProduct.lifetime } }

    /// The yearly plan a paywall arm naming `remote` sells: that plan when it is on sale here, else the standard year.
    func yearly(for remote: String?) -> Product? {
        let named = Self.annualProductID(remote: remote)
        return products.first { $0.id == named } ?? products.first { $0.id == TimbreProduct.annual }
    }

    /// The remote settings' yearly product when it is one of Timbre's yearly plans (`TimbreProduct.yearly`: the standard
    /// year and its price-test arms), else the standard year. Anything else (the month, lifetime, a typo) would sell a
    /// plan the arm didn't mean, or one that never grants Pro (`AccessPolicy.isPro` counts known products only).
    static func annualProductID(remote: String?) -> String {
        guard let remote, TimbreProduct.yearly.contains(remote) else { return TimbreProduct.annual }
        return remote
    }

    // MARK: Free trials

    /// Days of the free trial that buying `product` starts for this person: its introductory offer, when that is a free
    /// trial and the group's introductory offer is still theirs. StoreKit applies it by itself to whichever plan of the
    /// group has one, so a plan's trial is said wherever that plan is sold. Nil for a plan without one, or after a trial.
    func trialDays(for product: Product?) -> Int? {
        guard trialEligible, let offer = product?.subscription?.introductoryOffer, offer.paymentMode == .freeTrial else { return nil }
        return Self.days(of: offer.period, count: offer.periodCount)
    }

    /// "14-day free trial", "1-month free trial": `product`'s free trial as its button names it; nil without one.
    func trialLabel(for product: Product?) -> String? {
        guard trialDays(for: product) != nil, let period = product?.subscription?.introductoryOffer?.period else { return nil }
        let count = period.value
        switch period.unit {
        case .day: return String(localized: "\(count)-day free trial")
        case .week: return String(localized: "\(count * 7)-day free trial")
        case .month: return String(localized: "\(count)-month free trial")
        default: return String(localized: "Free trial")
        }
    }

    /// A period `count` times over, in days (a month counts 30, a year 365).
    static func days(of period: Product.SubscriptionPeriod, count: Int = 1) -> Int {
        let length = period.value * max(1, count)
        switch period.unit {
        case .day: return length
        case .week: return length * 7
        case .month: return length * 30
        case .year: return length * 365
        default: return length
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
            // One answer for the whole group: an introductory offer is once per subscription group.
            if let subscription = products.compactMap(\.subscription).first { trialEligible = await subscription.isEligibleForIntroOffer }
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
                    Analytics.log("purchase_failed", Self.purchaseProperties(product, error: "unverified"))
                    return false
                }
                await refreshEntitlements()
                await transaction.finish()
                // StoreKit can list a transaction it has just verified in the current entitlements a moment late: one
                // more look a second on, so a slow update can't leave Pro off after a purchase that went through.
                if !isPro {
                    try? await Task.sleep(for: .seconds(1))
                    await refreshEntitlements()
                }
                return isPro
            case .pending:
                pending = true
            case .userCancelled:
                Analytics.log("purchase_cancelled", Self.purchaseProperties(product))
            @unknown default:
                error = String(localized: "The App Store returned an unknown status. Please restore purchases.")
                Analytics.log("purchase_failed", Self.purchaseProperties(product, error: "unknown_result"))
            }
        } catch {
            self.error = error.localizedDescription
            let cause = Self.failureCause(error)
            if cause == "cancelled" {
                Analytics.log("purchase_cancelled", Self.purchaseProperties(product))
            } else {
                Analytics.log("purchase_failed", Self.purchaseProperties(product, error: cause))
            }
        }
        return false
    }

    /// The paywall's purchase properties (product, price, currency), with `error` naming why a purchase failed.
    private static func purchaseProperties(_ product: Product, error: String? = nil) -> [String: String] {
        var properties = ["product": product.id, "price": "\(product.price)", "currency": product.priceFormatStyle.currencyCode]
        if let error { properties["error"] = error }
        return properties
    }

    /// A short, non-identifying name for why a purchase threw.
    private static func failureCause(_ error: Error) -> String {
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
            if active?.0 != TimbreProduct.lifetime, let statuses = await Self.subscriptionStatuses() {
                issue = BillingIssue(statuses)
                SubscriptionOutcomes.statusChecked(statuses)
            }
            guard revision == refreshRevision else { continue }
            // Pro arriving once entitlements were already known (a purchase, a restore, an approved Ask to Buy), not a
            // subscriber's launch.
            let unlocked = entitlementResolved && !isPro && AccessPolicy.isPro(evidence)
            isPro = AccessPolicy.isPro(evidence)
            if unlocked { Self.announceUnlock() }
            activeProductID = active?.0
            renewalDate = active?.1
            billingIssue = issue
            entitlementResolved = true
            // In the grace period the paid period has already ended: Pro ends with the grace period instead.
            if case .gracePeriod(let until?)? = issue { scheduleExpiryCheck(until) } else { scheduleExpiryCheck(active?.1) }
            break
        }
        refreshInProgress = false
        let waiting = refreshWaiters
        refreshWaiters.removeAll()
        for continuation in waiting { continuation.resume() }
    }

    /// Pro just unlocked: Timbre's motif, once, quietly (`SoundFX` stays silent when sounds are off), and only while
    /// the app is on screen.
    private static func announceUnlock() {
        guard UIApplication.shared.applicationState == .active else { return }
        SoundFX.shared.play(.motif)
    }

    /// The subscription group's statuses, found through the latest transaction of any of its plans, so someone who
    /// never subscribed costs no status request; nil for them, or when the App Store can't be reached.
    private static func subscriptionStatuses() async -> [Product.SubscriptionInfo.Status]? {
        for productID in TimbreProduct.yearly + [TimbreProduct.monthly] {
            guard let latest = await Transaction.latest(for: productID), case .verified(let transaction) = latest,
                  let group = transaction.subscriptionGroupID else { continue }
            return try? await Product.SubscriptionInfo.status(for: group)
        }
        return nil
    }
}

/// What happens to a subscription after the purchase, logged from the device until a server hears it from App Store
/// Server Notifications:
/// - `subscription_state {state, will_renew, offer, product}` whenever the group's status changes: a trial cancelled on
///   its first day shows as `will_renew=0`, a lapse as `state=expired`;
/// - `renewal {product, offer}` for each later period of a subscription (a new transaction on the same purchase);
/// - `refund {product, reason}` when the App Store revokes a purchase.
/// Plan names and states only, never anything about the person.
@MainActor
enum SubscriptionOutcomes {
    /// The state last logged, so a launch that finds it unchanged logs nothing.
    private static let stateKey = "commerce.subscriptionState"

    /// A transaction from `Transaction.updates`: a renewal or a refund. (A purchase made in the app reports itself.)
    static func transactionArrived(_ transaction: Transaction) {
        if transaction.revocationDate != nil {
            var reason = "other"
            if let revocation = transaction.revocationReason, revocation == .developerIssue { reason = "developer_issue" }
            Analytics.log("refund", ["product": transaction.productID, "reason": reason])
        } else if transaction.productType == .autoRenewable, transaction.reason == .renewal, !transaction.isUpgraded {
            Analytics.log("renewal", ["product": transaction.productID, "offer": offerName(transaction.offer?.type)])
        }
    }

    /// The group's status as the App Store just reported it, logged when it differs from the one logged last.
    static func statusChecked(_ statuses: [Product.SubscriptionInfo.Status]) {
        guard let status = statuses.first(where: { $0.state == .subscribed }) ?? statuses.first else { return }
        var properties = ["state": stateName(status.state), "offer": "none"]
        if case .verified(let transaction) = status.transaction {
            properties["product"] = transaction.productID
            properties["offer"] = offerName(transaction.offer?.type)
        }
        if case .verified(let renewal) = status.renewalInfo {
            properties["will_renew"] = renewal.willAutoRenew ? "1" : "0"
        }
        let snapshot = properties.sorted { $0.key < $1.key }.map { "\($0.key)=\($0.value)" }.joined(separator: "&")
        let defaults = UserDefaults.standard
        guard defaults.string(forKey: stateKey) != snapshot else { return }
        defaults.set(snapshot, forKey: stateKey)
        Analytics.log("subscription_state", properties)
    }

    private static func stateName(_ state: Product.SubscriptionInfo.RenewalState) -> String {
        switch state {
        case .subscribed: return "subscribed"
        case .expired: return "expired"
        case .inGracePeriod: return "grace_period"
        case .inBillingRetryPeriod: return "billing_retry"
        case .revoked: return "revoked"
        default: return "unknown"
        }
    }

    /// The offer a period was bought with: an introductory offer (a free trial), a promotional or win-back offer, an
    /// offer code, or none.
    private static func offerName(_ type: Transaction.OfferType?) -> String {
        guard let type else { return "none" }
        switch type {
        case .introductory: return "introductory"
        case .promotional: return "promotional"
        case .code: return "code"
        case .winBack: return "win_back"
        default: return "other"
        }
    }
}
