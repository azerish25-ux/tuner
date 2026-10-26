import Foundation

/// Capture navigation uses the exact strings exported from the app's current tables.
/// A requested translation without its fixture fails the caller, never silently becoming English.
enum CaptureLocalization {
    static let language = ProcessInfo.processInfo.environment["TIMBRE_UI_LANGUAGE"].flatMap { $0.isEmpty ? nil : $0 } ?? "en"
    static let locale = ProcessInfo.processInfo.environment["TIMBRE_UI_LOCALE"].flatMap { $0.isEmpty ? nil : $0 } ?? "en_US"

    private static let labels: [String: [String: String]]? = {
        guard let url = Bundle(for: CaptureLocalizationBundle.self).url(forResource: "CaptureLocalizationExpected", withExtension: "json"),
              let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode([String: [String: String]].self, from: data)
    }()

    static func tabLabel(_ name: String) -> String? {
        let fields = ["Tune": "tune", "Learn": "learn", "Songs": "songs", "Practice": "practice", "Progress": "progress"]
        guard let field = fields[name] else { return nil }
        if let translated = labels?[language]?[field], !translated.isEmpty { return translated }
        return language == "en" ? name : nil
    }
}

private final class CaptureLocalizationBundle: NSObject {}
