import Foundation

/// The app language, resolved once per change and read by every lookup: SwiftUI's `Text` (through the locale the
/// root view sets from `locale(for:)`), the app's `String(localized:)` and `NSLocalizedString` (Localization.swift),
/// and the catalogue's and curriculum's own strings. One bundle for all of them, so a screen never mixes languages.
///
/// `language` is the Settings value. "system" follows the device, or the language chosen for Timbre in iOS Settings
/// (iOS relaunches the app in it and `Bundle.main` follows). A code ("de", "zh-CN") is a language picked in Timbre;
/// one without a localization falls back to the system's.
public enum TimbreLocalization {
    /// The Settings value that follows the device.
    public static let system = "system"

    private struct Resolved {
        let setting: String
        let bundle: Bundle
    }

    private static let lock = NSLock()
    nonisolated(unsafe) private static var resolved = Resolved(setting: system, bundle: .main)

    /// The Settings value now in effect. Setting it resolves the bundle once; reads are safe from any thread.
    public static var language: String {
        get {
            lock.lock()
            defer { lock.unlock() }
            return resolved.setting
        }
        set {
            let next = Resolved(setting: newValue, bundle: localizationBundle(for: newValue) ?? .main)
            lock.lock()
            resolved = next
            lock.unlock()
        }
    }

    /// The bundle strings resolve in: `Bundle.main` for "system", else the picked language's `.lproj`.
    public static var bundle: Bundle {
        lock.lock()
        defer { lock.unlock() }
        return resolved.bundle
    }

    /// The language a setting shows the app in: the one picked when the app has it, else the localization the app
    /// launched in.
    public static func resolvedLanguage(for setting: String) -> String {
        if setting != system, localizationBundle(for: setting) != nil { return canonicalLanguage(for: setting) }
        return Bundle.main.preferredLocalizations.first ?? "en"
    }

    /// The locale for SwiftUI's environment and for formatting: the device's for "system", else the picked language.
    public static func locale(for setting: String) -> Locale {
        setting == system ? .current : Locale(identifier: setting)
    }

    /// Whether a setting lays the app out right to left (Arabic, Hebrew, Persian, Urdu).
    public static func isRightToLeft(_ setting: String) -> Bool {
        Locale.Language(identifier: resolvedLanguage(for: setting)).characterDirection == .rightToLeft
    }

    /// Canonical resource identifier for an explicit language or regional alias. Script takes
    /// precedence over region: Traditional Chinese must never collapse into Simplified Chinese.
    /// Automatic language still uses Foundation's preference negotiation unchanged.
    public static func canonicalLanguage(for setting: String) -> String {
        let parts = setting.replacingOccurrences(of: "_", with: "-").lowercased().split(separator: "-").map(String.init)
        guard let language = parts.first else { return setting }
        if language == "zh" {
            if parts.contains("hant") { return "zh-Hant" }
            if parts.contains("hans") { return "zh-CN" }
            if parts.contains(where: { ["tw", "hk", "mo"].contains($0) }) { return "zh-Hant" }
            return "zh-CN"
        }
        if language == "nb" || language == "nn" { return "no" }
        return language
    }

    private static func localizationBundle(for setting: String) -> Bundle? {
        guard setting != system,
              let path = Bundle.main.path(forResource: canonicalLanguage(for: setting), ofType: "lproj") else { return nil }
        return Bundle(path: path)
    }
}
