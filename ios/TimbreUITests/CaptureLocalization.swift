import Foundation

/// Capture navigation uses exact current shipped strings. A requested translation
/// without its fixture fails the caller; no listing-only fallback is accepted.
enum CaptureLocalization {
    static let language = ProcessInfo.processInfo.environment["TIMBRE_UI_LANGUAGE"].flatMap { $0.isEmpty ? nil : $0 } ?? "en"
    static let locale = ProcessInfo.processInfo.environment["TIMBRE_UI_LOCALE"].flatMap { $0.isEmpty ? nil : $0 } ?? "en_US"
    static let listingLocale = ProcessInfo.processInfo.environment["TIMBRE_LISTING_LOCALE"] ?? ""

    /// The requested device preference list is separate from the expected app
    /// language. Every listing now requires its actual supported UI language;
    /// fixture checks must not silently force English.
    static let appleLanguages: [String] = {
        let requested = ProcessInfo.processInfo.environment["TIMBRE_UI_APPLE_LANGUAGES"] ?? language
        let values = requested.split(separator: ",", omittingEmptySubsequences: false).map(String.init)
        precondition(!values.isEmpty && Set(values).count == values.count && values.allSatisfy {
            $0.range(of: #"^[A-Za-z]+(?:-[A-Za-z0-9]+)*$"#, options: .regularExpression) != nil
        }, "Invalid capture AppleLanguages preference list")
        return values
    }()

    static var launchArguments: [String] {
        ["-AppleLanguages", "(\(appleLanguages.joined(separator: ",")))", "-AppleLocale", locale]
    }

    private static let labels: [String: [String: String]]? = {
        guard let url = Bundle(for: CaptureLocalizationBundle.self).url(forResource: "CaptureLocalizationExpected", withExtension: "json"),
              let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode([String: [String: String]].self, from: data)
    }()

    static func tabLabel(_ name: String) -> String? {
        let fields = ["Tune": "tune", "Learn": "learn", "Songs": "songs", "Practice": "practice", "Progress": "progress"]
        guard let field = fields[name] else { return nil }
        return label(field: field, source: name)
    }

    static func lessonButtonLabel(_ name: String) -> String? {
        let fields = ["Start": "lesson_start", "Continue": "lesson_continue"]
        guard let field = fields[name] else { return nil }
        return label(field: field, source: name)
    }

    static var tuned: String? { label(field: "tuned", source: "Tuned") }
    static var inTune: String? { label(field: "in_tune", source: "In tune") }
    static var allTuned: String? { label(field: "all_tuned", source: "All strings in tune") }

    private static func label(field: String, source: String) -> String? {
        if let translated = labels?[language]?[field], !translated.isEmpty { return translated }
        return language == "en" ? source : nil
    }

    /// Argument provenance is not actual-language proof. The separate evidence
    /// test emits VERIFIED only after matching the app's visible tab labels.
    static func recordLaunch(context: String) {
        record(event: "LAUNCH", extra: ["context": context])
    }

    static func recordVerified(fields: [String], observed: [String: String]) {
        record(event: "VERIFIED", extra: ["checked_fields": fields, "observed_labels": observed])
    }

    private static func record(event: String, extra: [String: Any]) {
        guard !listingLocale.isEmpty else { return }
        var fields: [String: Any] = [
            "listing_locale": listingLocale,
            "app_language": language,
            "apple_languages": appleLanguages,
            "apple_locale": locale,
        ]
        fields.merge(extra) { _, new in new }
        guard let data = try? JSONSerialization.data(withJSONObject: fields, options: [.sortedKeys]),
              let line = String(data: data, encoding: .utf8) else {
            preconditionFailure("Could not serialize capture language evidence")
        }
        print("TIMBRE_CAPTURE_\(event) \(line)")
    }
}

private final class CaptureLocalizationBundle: NSObject {}
