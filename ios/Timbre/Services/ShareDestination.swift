import StoreKit
import SwiftUI

/// Addresses the build carries in its Info.plist, set per build in project.yml. An empty or unexpanded value
/// (`$(…)`) counts as unset; the privacy policy falls back to its published address.
///
///     TimbreAppStoreID        the app's Apple ID in App Store Connect (digits): the App Store page and offer codes
///     TimbreShareURL          an https page that opens a shared route in Timbre, or sends a newcomer to the App Store
///     TimbrePrivacyURL        the privacy policy
///     TimbreRemoteConfigURL   the remote settings file (`RemoteConfig`)
enum AppLinks {
    private static let publishedPrivacy = URL(string: "https://timbre-support.timbre.workers.dev/privacy")!

    /// The privacy policy the paywall and Settings link to.
    static var privacy: URL { url("TimbrePrivacyURL") ?? publishedPrivacy }

    /// Public help remains available when analytics or song requests are disabled.
    static let support = URL(string: "https://timbre-support.timbre.workers.dev/support")!

    /// Apple's standard licence agreement, which serves as Timbre's terms of use.
    static let terms = URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!

    /// The app's Apple ID in App Store Connect; nil until the build carries it.
    static var appStoreID: String? {
        guard let id = string("TimbreAppStoreID"), id.allSatisfy(\.isNumber) else { return nil }
        return id
    }

    /// The App Store page; nil until the build carries the app's Apple ID.
    static var appStore: URL? { appStoreID.flatMap { URL(string: "https://apps.apple.com/app/id\($0)") } }

    /// The page shared links point at; nil leaves shares on the App Store page.
    static var share: URL? { url("TimbreShareURL") }

    /// The remote settings file; nil keeps the built-in defaults.
    static var remoteConfig: URL? { url("TimbreRemoteConfigURL") }

    /// An Info.plist string, trimmed; nil when missing, empty or left unexpanded by the build.
    static func string(_ key: String) -> String? {
        guard let raw = Bundle.main.object(forInfoDictionaryKey: key) as? String else { return nil }
        let value = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty || value.hasPrefix("$(") ? nil : value
    }

    /// An https address from the Info.plist; anything else counts as unset.
    private static func url(_ key: String) -> URL? {
        guard let value = string(key), let url = URL(string: value), url.scheme == "https", url.host != nil else { return nil }
        return url
    }
}

/// Where a share sends the person who receives it. A `timbre://` route only opens where Timbre is installed (and some
/// apps don't make it tappable), so every share carries an https link instead: the share page with the route as its
/// path (`…/lesson?id=…`), which opens the route in Timbre or the App Store for someone without it; without a share
/// page, the App Store page; without either (a build before the app has its page), no link at all.
enum ShareDestination {
    /// The https link for `route` (a `timbre://` link), or for Timbre itself when there is no route.
    static func link(for route: URL? = nil) -> URL? {
        guard let base = AppLinks.share else { return AppLinks.appStore }
        guard let route, route.scheme == DeepLink.scheme, let host = route.host else { return base }
        var components = URLComponents(url: base.appendingPathComponent(host), resolvingAgainstBaseURL: false)
        let items = URLComponents(url: route, resolvingAgainstBaseURL: false)?.queryItems ?? []
        components?.queryItems = items.isEmpty ? nil : items
        return components?.url ?? base
    }

    /// "Get Timbre: https://…", the line a share sheet sends with a card; nil when the build has nowhere to send them.
    static func line(for route: URL? = nil) -> String? {
        link(for: route).map { String(localized: "Get Timbre: \($0.absoluteString)") }
    }

    /// `line(for:)` as a share sheet's message (`ShareLink(item:message:preview:)`).
    static func message(for route: URL? = nil) -> Text? {
        line(for: route).map { Text(verbatim: $0) }
    }

    /// The `timbre://` route a link to the share page stands for (`…/lesson?id=x` is `timbre://lesson?id=x`), so a
    /// share page opened as a universal link lands where the route would; nil for any other address.
    static func route(from url: URL) -> URL? {
        guard url.scheme == "https", let base = AppLinks.share, url.host == base.host else { return nil }
        let basePath = base.path.hasSuffix("/") ? String(base.path.dropLast()) : base.path
        guard url.path.hasPrefix(basePath) else { return nil }
        let rest = url.path.dropFirst(basePath.count).split(separator: "/")
        guard let host = rest.first, !host.isEmpty else { return nil }
        var components = URLComponents()
        components.scheme = DeepLink.scheme
        components.host = String(host)
        let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []
        components.queryItems = items.isEmpty ? nil : items
        return components.url
    }

    /// "Give a friend a month": the App Store's own redemption page for the owner's offer code (`RemoteConfig`'s
    /// `referralCode`, set up under the subscription's Offer Codes in App Store Connect). The friend redeems it on the
    /// App Store, so the app never holds a code beyond the one it was given. Nil until the build has its Apple ID and
    /// the remote settings name a code.
    @MainActor static var friendOffer: URL? {
        guard let id = AppLinks.appStoreID, let code = RemoteConfig.shared.referralCode else { return nil }
        var components = URLComponents(string: "https://apps.apple.com/redeem")
        components?.queryItems = [URLQueryItem(name: "ctx", value: "offercodes"), URLQueryItem(name: "id", value: id),
                                  URLQueryItem(name: "code", value: code)]
        return components?.url
    }
}

/// "Give a friend a month", as a pill that opens the share sheet with the offer's redemption link. Nothing shows until
/// the owner has set up the offer (`ShareDestination.friendOffer`). `screen` names where it was tapped, for analytics.
struct FriendOfferLink: View {
    let screen: String
    var tint: Color = Palette.mint

    var body: some View {
        if let offer = ShareDestination.friendOffer {
            ShareLink(item: offer, subject: Text("A month of Timbre Pro"),
                      message: Text("A month of Timbre Pro on me: a precise tuner and lessons that listen as you play.")) {
                Label("Give a friend a month", systemImage: "gift.fill")
                    .font(Typeface.label(13, relativeTo: .footnote))
                    .foregroundStyle(tint)
                    .lineLimit(1).minimumScaleFactor(0.8)
                    .frame(minHeight: Metrics.minTarget)
                    .contentShape(Rectangle())
            }
            .buttonStyle(PressScaleStyle())
            .simultaneousGesture(TapGesture().onEnded { Analytics.log("referral_share", ["screen": screen]) })
            .accessibilityIdentifier("referral.share")
        }
    }
}

/// "Give a friend a month" in its own capsule, for a peak moment (a song's results, a streak): `FriendOfferLink` on a
/// tinted pill. Like the link, nothing shows until the owner has set up the offer. `screen` names where it was tapped.
struct ReferralPill: View {
    let screen: String
    var tint: Color = Palette.mint

    var body: some View {
        if ShareDestination.friendOffer != nil {
            FriendOfferLink(screen: screen, tint: tint)
                .padding(.horizontal, 14)
                .background(Capsule(style: .continuous).fill(tint.opacity(0.12)))
                .overlay(Capsule(style: .continuous).strokeBorder(tint.opacity(0.35), lineWidth: 1))
        }
    }
}

/// When to ask for an App Store rating. StoreKit decides whether the sheet actually shows (a few times a year at
/// most); this only picks the moments, and never asks under automation.
@MainActor
enum ReviewPrompt {
    /// Set once the first song played with three stars has asked.
    private static let askedKey = "review.afterSong"

    /// A song just finished with `stars` stars: the first three-star song asks, once in the app's life. Call it where
    /// the results have landed; `requestReview` is the view's `@Environment(\.requestReview)`.
    static func afterSong(stars: Int, requestReview: RequestReviewAction) {
        let defaults = UserDefaults.standard
        guard stars >= 3, !TestSupport.isAutomated, !defaults.bool(forKey: askedKey) else { return }
        defaults.set(true, forKey: askedKey)
        requestReview()
    }
}
