import StoreKit
import SwiftUI
import TimbreCore

// The one-time offer a paywall makes as it is turned down for the second time (onboarding's paywall being the first
// time). It is only ever an offer the App Store itself holds for this person on a real product, at the App Store's
// price, never a made-up discount:
//   1. someone whose subscription lapsed: the best win-back offer the App Store says they may redeem
//      (App Store Connect → Subscriptions → the plan → Win-Back Offers);
//   2. someone who never had a trial in the group: the monthly plan's own introductory offer, when App Store Connect
//      gives it one (a free week, say), as a lighter start than the year;
//   3. otherwise nothing: the paywall simply closes.
// Made once per install, never under the UI tests or the demo modes.

/// A real App Store offer to make on the way out.
struct ExitOffer {
    enum Kind: String {
        case winBack = "win_back"
        case introductory
    }

    let kind: Kind
    let product: Product
    let offer: Product.SubscriptionOffer

    /// A win-back offer goes with the purchase; an introductory offer applies by itself.
    var options: Set<Product.PurchaseOption> { kind == .winBack ? [.winBackOffer(offer)] : [] }

    /// Days a free offer lasts (for the reminder before it renews); nil for a paid one.
    var freeDays: Int? {
        guard offer.paymentMode == .freeTrial else { return nil }
        let count = offer.period.value * max(1, offer.periodCount)
        switch offer.period.unit {
        case .day: return count
        case .week: return count * 7
        case .month: return count * 30
        case .year: return count * 365
        default: return nil
        }
    }
}

extension CommerceService {
    /// The offer to make as a paywall is turned down, if the App Store holds one for this person (see the note above).
    func exitOffer() async -> ExitOffer? {
        guard !isPro else { return nil }
        let plans = [annual, monthly].compactMap { $0 }
        // A lapsed subscriber: the renewal info lists the win-back offers they may redeem, best first.
        if let group = plans.first?.subscription, let statuses = try? await group.status {
            var eligible: [String] = []
            for status in statuses {
                if case .verified(let renewal) = status.renewalInfo { eligible += renewal.eligibleWinBackOfferIDs }
            }
            for id in eligible {
                for plan in plans {
                    if let offer = plan.subscription?.winBackOffers.first(where: { $0.id == id }) {
                        return ExitOffer(kind: .winBack, product: plan, offer: offer)
                    }
                }
            }
        }
        // Never had an introductory offer in the group: the monthly plan's, when it has one.
        if let monthly, let subscription = monthly.subscription, let intro = subscription.introductoryOffer,
           await subscription.isEligibleForIntroOffer {
            return ExitOffer(kind: .introductory, product: monthly, offer: intro)
        }
        return nil
    }
}

/// How many times a paywall has been turned down, and whether the exit offer has been made.
enum PaywallDeclines {
    private static let countKey = "paywall.declines"
    private static let offeredKey = "paywall.exitOfferMade"

    /// Off under XCTest, the UI tests and the demo and screenshot modes: their tours close paywalls many times over.
    private static let enabled: Bool = {
        let environment = ProcessInfo.processInfo.environment
        let quiet = ["XCTestConfigurationFilePath", "TIMBRE_TEST_STORAGE_ID", "TIMBRE_DEMO_PITCH", "TIMBRE_DEMO_DATA", "TIMBRE_SCENE"]
        return !quiet.contains { environment[$0] != nil }
    }()

    static var count: Int { UserDefaults.standard.integer(forKey: countKey) }

    /// The next decline makes the offer: one has gone before, and the offer has never been made.
    static var offerDue: Bool { enabled && count >= 1 && !UserDefaults.standard.bool(forKey: offeredKey) }

    static func record() { UserDefaults.standard.set(count + 1, forKey: countKey) }

    static func markOffered() { UserDefaults.standard.set(true, forKey: offeredKey) }
}

/// The exit offer over the paywall: what the App Store offers, what it costs afterwards and how it renews, the button
/// that takes it and "No thanks", which closes the paywall.
struct ExitOfferCard: View {
    let offer: ExitOffer
    let purchasing: Bool
    let accept: () -> Void
    let decline: () -> Void
    @Environment(\.locale) private var locale
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var shown = false

    var body: some View {
        ZStack(alignment: .bottom) {
            Palette.stageDeep.opacity(0.78)
                .ignoresSafeArea()
                .accessibilityHidden(true)
            card
                .offset(y: shown || reduceMotion ? 0 : 40)
                .opacity(shown ? 1 : 0)
        }
        .onAppear {
            withMotion(Motion.pluck, reduceMotion: reduceMotion) { shown = true }
            Haptics.shared.selection()
        }
    }

    private var card: some View {
        let shape = RoundedRectangle(cornerRadius: Metrics.cornerHero, style: .continuous)
        return VStack(spacing: 12) {
            Image(systemName: offer.kind == .winBack ? "arrow.uturn.backward.circle.fill" : "gift.fill")
                .font(.system(size: 26, weight: .semibold))
                .foregroundStyle(Palette.proGold)
                .frame(width: 60, height: 60)
                .background(Circle().fill(Palette.amber.opacity(0.14)))
                .overlay(Circle().strokeBorder(Palette.amber.opacity(0.3), lineWidth: 1))
                .symbolEffect(.bounce, value: shown)
                .accessibilityHidden(true)
            Eyebrow(Text(offer.kind == .winBack ? "Welcome back" : "Before you go"), color: Palette.amber)
            Text(verbatim: headline)
                .font(Typeface.display(26)).tracking(-0.5).foregroundStyle(Palette.ink)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)
            Text(verbatim: terms)
                .font(.subheadline).foregroundStyle(Palette.inkSoft)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            // The paywall's own action button and label font (the style's). While the purchase runs it is disabled but
            // stays lit (`busy`), so its spinner reads as work, never as a dead grey button.
            Button(action: accept) {
                if purchasing {
                    ProgressView().tint(Palette.onAccent)
                } else {
                    Text(offer.offer.paymentMode == .freeTrial ? "Start free trial" : "Claim offer")
                        .lineLimit(2).multilineTextAlignment(.center)
                }
            }
            .buttonStyle(GlassActionButtonStyle(busy: purchasing))
            .disabled(purchasing)
            .padding(.top, 6)
            .accessibilityIdentifier("paywall.exitOffer.accept")
            Button(action: decline) {
                Text("No thanks").font(.subheadline.weight(.semibold)).foregroundStyle(Palette.inkSoft)
                    .padding(.horizontal, 16).tapTarget()
            }
            .buttonStyle(.plain)
            .disabled(purchasing)
            .accessibilityIdentifier("paywall.exitOffer.decline")
        }
        .padding(.horizontal, 22).padding(.top, 24).padding(.bottom, 14)
        .frame(maxWidth: 480)
        .background {
            ZStack {
                shape.fill(Palette.stageRaised)
                shape.fill(RadialGradient(colors: [Palette.amber.opacity(0.16), .clear], center: .top, startRadius: 0, endRadius: 260))
            }
        }
        .overlay(shape.strokeBorder(Palette.amber.opacity(0.22), lineWidth: 1))
        .shadow(color: .black.opacity(0.5), radius: 30, y: 10)
        .padding(.horizontal, 12).padding(.bottom, 8)
        .accessibilityElement(children: .contain)
        .accessibilityAddTraits(.isModal)
        .accessibilityIdentifier("paywall.exitOffer")
    }

    /// "Try Pro free for 7 days", "$2.99 a month for your first 3 months", "3 months of Pro for $9.99": the offer as the
    /// App Store holds it.
    private var headline: String {
        let deal = offer.offer
        let length = Self.span(deal.period, times: deal.periodCount, locale: locale)
        switch deal.paymentMode {
        case .freeTrial:
            return String(localized: "Try Pro free for \(length)")
        case .payAsYouGo:
            return String(localized: "\(Self.price(deal.displayPrice, every: deal.period, locale: locale)) for your first \(length)")
        case .payUpFront:
            return String(localized: "\(length) of Pro for \(deal.displayPrice)")
        default:
            return String(localized: "A Timbre Pro offer for you")
        }
    }

    /// "Then $6.99 a month. It renews automatically until you cancel in Settings."
    private var terms: String {
        let renewal = offer.product.subscription.map { Self.price(offer.product.displayPrice, every: $0.subscriptionPeriod, locale: locale) }
            ?? offer.product.displayPrice
        return String(localized: "Then \(renewal). It renews automatically until you cancel in Settings.")
    }

    /// "7 days", "2 weeks", "3 months": a period, `times` over, in the reader's language.
    static func span(_ period: Product.SubscriptionPeriod, times: Int, locale: Locale) -> String {
        let count = period.value * max(1, times)
        var parts = DateComponents()
        switch period.unit {
        case .day: parts.day = count
        case .week: parts.weekOfMonth = count
        case .month: parts.month = count
        case .year: parts.year = count
        default: parts.day = count
        }
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = locale
        let formatter = DateComponentsFormatter()
        formatter.calendar = calendar
        formatter.unitsStyle = .full
        formatter.allowedUnits = [.day, .weekOfMonth, .month, .year]
        formatter.maximumUnitCount = 1
        return formatter.string(from: parts) ?? ""
    }

    /// "$6.99 a month", "$34.99 a year"; "$9.99 every 3 months" for a longer period.
    static func price(_ price: String, every period: Product.SubscriptionPeriod, locale: Locale) -> String {
        guard period.value == 1 else { return String(localized: "\(price) every \(span(period, times: 1, locale: locale))") }
        switch period.unit {
        case .day: return String(localized: "\(price) a day")
        case .week: return String(localized: "\(price) a week")
        case .year: return String(localized: "\(price) a year")
        default: return String(localized: "\(price) a month")
        }
    }
}
