import Combine
import Foundation
import TimbreCore
import UIKit

/// What the owner can change without a build: which paywall a person sees (and the yearly product it sells), whether
/// the App Store rating may show, the referral offer code, lessons opened to everyone and named switches for
/// experiments. Read from a small JSON file at `AppLinks.remoteConfig`, kept from the last good copy and fetched again
/// when the app comes forward (at most every few hours). With no address in the build, offline, or with a file that
/// doesn't parse, the last good copy or the built-in defaults hold; nothing ever waits for it. The request carries no
/// identifier.
///
///     {
///       "paywall": [{ "id": "control", "weight": 50 },
///                   { "id": "annual_b", "weight": 50, "annualProductId": "timbre_pro_annual_b" }],
///       "rating": { "show": true },
///       "referralCode": "FRIENDMONTH",
///       "freeSongs": ["song-silent-night", "uke-sb-song-silent-night"],
///       "flags": { "unit2Free": true }
///     }
///
/// A person keeps the paywall variant they were first given for as long as it is listed: assignment draws once from a
/// random number fixed for the install, weighted by `weight`. Dropping a variant from the list (or giving it weight 0)
/// moves its people to the others, so flipping the file flips the paywall without a build. An arm's
/// `annualProductId` is one of `TimbreProduct.yearly`; anything else sells the standard year.
///
/// `freeSongs` and `flags.unit2Free` open lessons to everyone (`FreeOpenings`): the app applies them as the file
/// loads, so the lesson locks, the plan and the paywall's Free and Pro table follow them at once.
@MainActor
final class RemoteConfig: ObservableObject {
    static let shared = RemoteConfig()

    /// One arm of a paywall test.
    struct PaywallVariant: Codable, Equatable, Sendable {
        var id: String
        /// Its share of people, against the other variants' (1 when left out).
        var weight: Double?
        /// The yearly product to sell instead of the default one. It must exist in App Store Connect, in the same
        /// subscription group; the commerce service loads it and the paywall reads its price from StoreKit.
        var annualProductId: String?
        /// Onboarding's paywall also offers the lifetime unlock (left out, it shows the year and the month only).
        var onboardingLifetime: Bool?
        /// Onboarding's headline: "song" ("Play your first song this week", when the plan reaches one that soon, the
        /// default) or "plan" ("Unlock your full plan").
        var headline: String?

        static let control = PaywallVariant(id: "control")

        fileprivate var share: Double { weight ?? 1 }
    }

    /// The paywall's rating line: `show: false` keeps it off. Its figures always come from the App Store itself
    /// (`StoreRating`), per storefront; numbers written into the file are ignored.
    struct Rating: Codable, Equatable, Sendable {
        var show: Bool?
        var stars: Double?
        var count: Int?
    }

    struct Values: Codable, Equatable, Sendable {
        var paywall: [PaywallVariant]?
        var rating: Rating?
        var referralCode: String?
        /// Song lessons opened to everyone for now (a seasonal shelf's first week), by lesson id.
        var freeSongs: [String]?
        var flags: [String: Bool]?
    }

    @Published private(set) var values: Values
    /// This install's paywall arm (`PaywallVariant.control` without a test running).
    @Published private(set) var paywallVariant: PaywallVariant

    private var started = false
    private var fetching = false
    private var foreground: AnyCancellable?

    private enum Keys {
        static let cache = "remote.config"
        static let fetchedAt = "remote.fetchedAt"
        static let bucket = "remote.bucket"
        static let assigned = "remote.paywallVariant"
    }

    /// The file is fetched again after this long.
    private static let interval: TimeInterval = 6 * 3600
    private static let maxBytes = 64_000
    private static let session = URLSession(configuration: .ephemeral)

    /// Automated runs and the demo modes keep the built-in defaults, so what they show never depends on the network.
    private static var quiet: Bool { TestSupport.isAutomated }

    private init() {
        let cached = Self.quiet ? nil : UserDefaults.standard.data(forKey: Keys.cache).flatMap { try? JSONDecoder().decode(Values.self, from: $0) }
        let initial = Self.sanitized(cached ?? Values())
        values = initial
        paywallVariant = Self.assign(initial.paywall ?? [])
        FreeOpenings.current = Self.openings(initial)
    }

    // MARK: Reading

    /// The yearly product this install's paywall sells, when its arm names one.
    var annualProductID: String? { paywallVariant.annualProductId }

    /// The App Store rating may show on the paywall (`StoreRating` has the figures); on unless the file turns it off.
    var ratingAllowed: Bool { values.rating?.show != false }

    /// The offer code "Give a friend a month" shares.
    var referralCode: String? { values.referralCode }

    /// A named switch; `fallback` while the file doesn't set it.
    func flag(_ name: String, default fallback: Bool = false) -> Bool {
        values.flags?[name] ?? fallback
    }

    /// Song lessons the file opens to everyone, by lesson id (`freeSongs`); empty by default.
    var freeSongs: [String] { values.freeSongs ?? [] }

    /// Unit 2 of every course is free (`flags.unit2Free`); off by default.
    var unit2Free: Bool { flag("unit2Free") }

    /// What the file opens to everyone: `freeSongs` and, with `unit2Free`, every course's second unit.
    var freeOpenings: FreeOpenings { Self.openings(values) }

    private static func openings(_ values: Values) -> FreeOpenings {
        FreeOpenings(lessons: Set(values.freeSongs ?? []), unit2: values.flags?["unit2Free"] ?? false)
    }

    // MARK: Fetching

    /// Fetches now, then whenever the app comes forward (each at most every few hours). Safe to call more than once.
    func start() {
        guard !started else { return }
        started = true
        refresh()
        foreground = NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)
            .sink { _ in Task { @MainActor in RemoteConfig.shared.refresh() } }
    }

    /// Fetches the file when the build has its address and the last copy is older than the interval (or `force`).
    func refresh(force: Bool = false) {
        guard !Self.quiet, !fetching, let url = AppLinks.remoteConfig else { return }
        let defaults = UserDefaults.standard
        if !force, let last = defaults.object(forKey: Keys.fetchedAt) as? Date, Date().timeIntervalSince(last) < Self.interval { return }
        fetching = true
        Task {
            defer { fetching = false }
            var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 8)
            request.setValue("application/json", forHTTPHeaderField: "Accept")
            guard let (data, response) = try? await Self.session.data(for: request),
                  (response as? HTTPURLResponse)?.statusCode == 200, data.count <= Self.maxBytes,
                  let decoded = try? JSONDecoder().decode(Values.self, from: data) else { return }
            defaults.set(data, forKey: Keys.cache)
            defaults.set(Date(), forKey: Keys.fetchedAt)
            apply(Self.sanitized(decoded))
        }
    }

    private func apply(_ next: Values) {
        guard next != values else { return }
        values = next
        FreeOpenings.current = Self.openings(next)
        let variant = Self.assign(next.paywall ?? [])
        if variant != paywallVariant { paywallVariant = variant }
    }

    // MARK: Rules

    /// What a hand-edited file may hold: named variants with a positive weight (eight at most), the rating's switch,
    /// a plain offer code, a few dozen free songs and a few dozen switches. Anything else is dropped rather than shown.
    private static func sanitized(_ values: Values) -> Values {
        var clean = Values()
        let variants = (values.paywall ?? []).filter { variant in
            !variant.id.isEmpty && variant.id.count <= 40 && variant.share.isFinite && variant.share > 0
        }
        clean.paywall = variants.isEmpty ? nil : Array(variants.prefix(8))
        // Only the switch is kept: the rating's figures come from the App Store.
        if let show = values.rating?.show { clean.rating = Rating(show: show) }
        if let code = values.referralCode, (1...64).contains(code.count), code.allSatisfy({ $0.isASCII && ($0.isLetter || $0.isNumber) }) {
            clean.referralCode = code
        }
        if let flags = values.flags, flags.count <= 64 { clean.flags = flags }
        // Lesson ids as the curriculum writes them ("gtr-2-4"): letters, digits, dashes, dots and underscores; a
        // few dozen at most.
        let songs = (values.freeSongs ?? []).filter { id in
            (1...64).contains(id.count) && id.allSatisfy { $0.isASCII && ($0.isLetter || $0.isNumber || $0 == "-" || $0 == "_" || $0 == ".") }
        }
        clean.freeSongs = songs.isEmpty ? nil : Array(songs.prefix(64))
        return clean
    }

    /// The arm this install keeps while it is listed, else a weighted draw from the install's fixed number.
    private static func assign(_ listed: [PaywallVariant]) -> PaywallVariant {
        let defaults = UserDefaults.standard
        guard !listed.isEmpty else {
            defaults.removeObject(forKey: Keys.assigned)
            return .control
        }
        if let kept = defaults.string(forKey: Keys.assigned), let variant = listed.first(where: { $0.id == kept }) { return variant }
        let total = listed.reduce(0.0) { $0 + $1.share }
        var point = bucket * total
        var chosen = listed[listed.count - 1]
        for variant in listed {
            if point < variant.share { chosen = variant; break }
            point -= variant.share
        }
        defaults.set(chosen.id, forKey: Keys.assigned)
        return chosen
    }

    /// A number in 0..<1 drawn once per install.
    private static var bucket: Double {
        let defaults = UserDefaults.standard
        if let stored = defaults.object(forKey: Keys.bucket) as? Double, (0..<1).contains(stored) { return stored }
        let fresh = Double.random(in: 0..<1)
        defaults.set(fresh, forKey: Keys.bucket)
        return fresh
    }
}
