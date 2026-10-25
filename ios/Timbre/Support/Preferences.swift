import Foundation

/// The small per-device choices the app keeps in `UserDefaults` rather than in the saved state (`LocalStore`): where
/// Learn was left, the daily commitment, what this device last knew about Pro. One key each, named here once; code
/// reads and writes them through this type, and a view binds one with `@AppStorage(Preferences.Key.learnCourse)`.
///
/// None of them is practice history: "Clear practice history" leaves them, as it leaves the settings.
enum Preferences {
    enum Key {
        /// The course Learn shows (`LearnView`, the Today card, Songs' shelf), by course id.
        static let learnCourse = "learn.course"
        /// Minutes a day the player committed to on onboarding's plan (5, 10 or 15).
        static let dailyMinutes = "plan.dailyMinutes"
        /// Whether Pro was active the last time StoreKit answered on this device.
        static let proActive = "analytics.proActive"
    }

    /// The course Learn opens on before the player has picked one.
    static let defaultLearnCourse = "guitar"
    /// The daily commitment before onboarding has asked for one.
    static let defaultDailyMinutes = 10

    /// The course Learn shows: the one saved, else `defaultLearnCourse`.
    static var learnCourse: String {
        get { savedLearnCourse ?? defaultLearnCourse }
        set { UserDefaults.standard.set(newValue, forKey: Key.learnCourse) }
    }

    /// The course saved for Learn; nil until one has been.
    static var savedLearnCourse: String? { UserDefaults.standard.string(forKey: Key.learnCourse) }

    /// Minutes a day the player committed to.
    static var dailyMinutes: Int {
        get { UserDefaults.standard.object(forKey: Key.dailyMinutes) as? Int ?? defaultDailyMinutes }
        set { UserDefaults.standard.set(newValue, forKey: Key.dailyMinutes) }
    }

    /// Whether Pro was active when StoreKit last answered on this device; nil before it ever has.
    static var proActive: Bool? {
        get { UserDefaults.standard.object(forKey: Key.proActive) as? Bool }
        set { UserDefaults.standard.set(newValue, forKey: Key.proActive) }
    }
}
