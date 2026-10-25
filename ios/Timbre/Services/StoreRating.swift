import Combine
import Foundation
import StoreKit

/// The app's App Store rating in this person's storefront, for the paywall's rating line. The figures come from Apple's
/// public lookup (`itunes.apple.com/lookup?id=…&country=…`), never from a number typed by hand, and only for the
/// storefront the person buys in, as App Store ratings are counted per storefront. The line shows once the rating
/// clears the bar (`minimumStars` from at least `minimumRatings` ratings) and the remote settings haven't turned it
/// off. Fetched at most once a day; the request names the app and the storefront, nothing about the person. Until the
/// build carries the app's Apple ID, and under automation, nothing is fetched and no line shows.
@MainActor
final class StoreRating: ObservableObject {
    static let shared = StoreRating()

    /// A storefront's rating as the App Store reports it.
    struct Line: Codable, Equatable {
        let stars: Double
        let count: Int
        /// The storefront it was read for (ISO 3166-1 alpha-3, as StoreKit names it).
        let storefront: String
    }

    static let minimumStars = 4.6
    static let minimumRatings = 200

    private static let interval: TimeInterval = 24 * 3600
    private static let cacheKey = "storeRating.line"
    private static let fetchedKey = "storeRating.fetchedAt"
    private static let maxBytes = 256_000
    private static let session = URLSession(configuration: .ephemeral)

    /// The last rating read, whether or not it clears the bar.
    @Published private(set) var fetched: Line?
    private var fetching = false

    private init() {
        fetched = UserDefaults.standard.data(forKey: Self.cacheKey).flatMap { try? JSONDecoder().decode(Line.self, from: $0) }
    }

    /// The line to show: this storefront's rating when it clears the bar and the remote settings allow it.
    var line: Line? {
        guard RemoteConfig.shared.ratingAllowed, let fetched,
              fetched.stars >= Self.minimumStars, fetched.count >= Self.minimumRatings else { return nil }
        return fetched
    }

    /// Reads the rating again when the last reading is a day old or was for another storefront.
    func refresh() async {
        guard !TestSupport.isAutomated, !fetching, let id = AppLinks.appStoreID,
              let storefront = await Storefront.current?.countryCode else { return }
        let defaults = UserDefaults.standard
        if let last = defaults.object(forKey: Self.fetchedKey) as? Date, Date().timeIntervalSince(last) < Self.interval,
           fetched?.storefront == storefront { return }
        fetching = true
        defer { fetching = false }
        var components = URLComponents(string: "https://itunes.apple.com/lookup")
        components?.queryItems = [URLQueryItem(name: "id", value: id), URLQueryItem(name: "country", value: Self.lookupCountry(storefront))]
        guard let url = components?.url else { return }
        var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 8)
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        guard let (data, response) = try? await Self.session.data(for: request),
              (response as? HTTPURLResponse)?.statusCode == 200, data.count <= Self.maxBytes,
              let lookup = try? JSONDecoder().decode(Lookup.self, from: data) else { return }
        defaults.set(Date(), forKey: Self.fetchedKey)
        var next: Line?
        if let result = lookup.results.first, let stars = result.averageUserRating, let count = result.userRatingCount,
           stars.isFinite, (0...5).contains(stars), count >= 0 {
            next = Line(stars: stars, count: count, storefront: storefront)
        }
        if let next, let data = try? JSONEncoder().encode(next) {
            defaults.set(data, forKey: Self.cacheKey)
        } else {
            defaults.removeObject(forKey: Self.cacheKey)
        }
        if next != fetched { fetched = next }
    }

    /// The lookup's answer, reduced to the rating (every other field is ignored).
    private struct Lookup: Decodable {
        struct Result: Decodable {
            let averageUserRating: Double?
            let userRatingCount: Int?
        }
        let results: [Result]
    }

    /// The lookup's two-letter country for a StoreKit storefront code (ISO 3166-1 alpha-3). Most alpha-3 codes begin
    /// with their alpha-2 code; these are the ones that don't (from the ISO 3166-1 table), and Kosovo's storefront.
    static func lookupCountry(_ storefront: String) -> String {
        let code = storefront.uppercased()
        return alpha2Exceptions[code] ?? String(code.prefix(2)).lowercased()
    }

    private static let alpha2Exceptions: [String: String] = [
        "ABW": "aw", "AGO": "ao", "ALA": "ax", "AND": "ad", "ARE": "ae", "ARM": "am", "ATA": "aq", "ATF": "tf",
        "ATG": "ag", "AUT": "at", "BDI": "bi", "BEN": "bj", "BES": "bq", "BGD": "bd", "BHS": "bs", "BIH": "ba",
        "BLR": "by", "BLZ": "bz", "BRB": "bb", "BRN": "bn", "CAF": "cf", "CHL": "cl", "CHN": "cn", "COD": "cd",
        "COG": "cg", "COK": "ck", "COM": "km", "CPV": "cv", "CUW": "cw", "CYM": "ky", "DNK": "dk", "ESH": "eh",
        "EST": "ee", "FLK": "fk", "FRO": "fo", "FSM": "fm", "GIN": "gn", "GLP": "gp", "GNB": "gw", "GNQ": "gq",
        "GRD": "gd", "GRL": "gl", "GUF": "gf", "GUY": "gy", "IRL": "ie", "IRQ": "iq", "ISR": "il", "JAM": "jm",
        "KAZ": "kz", "KOR": "kr", "LBR": "lr", "LBY": "ly", "MAC": "mo", "MAF": "mf", "MDG": "mg", "MDV": "mv",
        "MEX": "mx", "MLT": "mt", "MNE": "me", "MNP": "mp", "MOZ": "mz", "MTQ": "mq", "MYT": "yt", "NIU": "nu",
        "PAK": "pk", "PCN": "pn", "PLW": "pw", "PNG": "pg", "POL": "pl", "PRK": "kp", "PRT": "pt", "PRY": "py",
        "PYF": "pf", "SEN": "sn", "SGS": "gs", "SLB": "sb", "SLV": "sv", "SPM": "pm", "SRB": "rs", "SUR": "sr",
        "SVK": "sk", "SVN": "si", "SWE": "se", "SWZ": "sz", "SYC": "sc", "TCD": "td", "TKM": "tm", "TUN": "tn",
        "TUR": "tr", "TUV": "tv", "UKR": "ua", "URY": "uy", "WLF": "wf", "XKS": "xk",
    ]
}
