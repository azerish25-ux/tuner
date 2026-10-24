import Foundation

/// Every Game Center identifier the app uses, in one place. Each one must be created in App Store Connect
/// (the app → Features → Game Center) with exactly this ID before it does anything; until then GameKit answers
/// "unknown" and the app carries on without it: the Leaderboard chips stay hidden and reports are dropped quietly.
/// docs/ios/APPLE-DELIVERY.md § Game Center lists the same setup as owner steps.
///
/// Leaderboards (all "Integer", "High score", sorted high to low, no score format suffix):
///
///     timbre.sniper.best    Classic     "Pitch Sniper"            Score range 0 – 25,000
///     timbre.sniper.weekly  Recurring   "Pitch Sniper this week"  Starts Monday 00:00, lasts 1 week, repeats
///                                                                 every week; score range 0 – 25,000
///     timbre.ear.level      Classic     "Ear trainer level"       Score range 1 – 100
///
/// Achievements: `badges` below, one per line, ID `timbre.badge.<app badge id>`, the points given, not hidden,
/// not achievable more than once. Title and description are the app's own badge title and detail
/// (TimbreCore `Achievements.all`); each needs a 1024 × 1024 image. 31 achievements, 895 points (the cap is 1,000).
enum GameCenterIDs {
    // MARK: Leaderboards

    /// Pitch Sniper's best game, all time. Ten rounds of at most 500 points × the ×5 combo: 25,000 at most.
    static let sniperBest = "timbre.sniper.best"
    /// Pitch Sniper's best game this week: a recurring leaderboard, the weekly league.
    static let sniperWeekly = "timbre.sniper.weekly"
    /// The ear trainer's level as the Play hub shows it ("Level 3"): the highest drill level plus one.
    static let earLevel = "timbre.ear.level"

    static let leaderboards = [sniperBest, sniperWeekly, earLevel]

    // MARK: Achievements

    /// An app badge that is also a Game Center achievement, and what it is worth there.
    struct Badge {
        /// The badge's id in `Achievements.all`.
        let id: String
        let points: Int
        var gameCenterID: String { "timbre.badge." + id }
    }

    /// The badges worth a place in Game Center: every tier of tuning, practice, ear games and learning that anyone can
    /// earn on the free plan. Left out: the eight per-instrument course badges (they would crowd the list) and the
    /// badges only Pro can reach (custom tunings, Pro-precision locks).
    static let badges: [Badge] = [
        // Tuning
        Badge(id: "first_tune", points: 5),
        Badge(id: "full_tune", points: 10),
        Badge(id: "strings_100", points: 20),
        Badge(id: "full_25", points: 25),
        Badge(id: "multi", points: 20),
        Badge(id: "strings_1000", points: 50),
        // Dedication
        Badge(id: "streak_3", points: 10),
        Badge(id: "streak_7", points: 25),
        Badge(id: "streak_30", points: 50),
        Badge(id: "streak_100", points: 100),
        Badge(id: "level_5", points: 25),
        Badge(id: "minutes_60", points: 10),
        Badge(id: "minutes_600", points: 50),
        Badge(id: "daily_1", points: 5),
        Badge(id: "daily_30", points: 50),
        // Ear and games
        Badge(id: "bullseye", points: 5),
        Badge(id: "sniper_win", points: 10),
        Badge(id: "bullseyes_50", points: 25),
        Badge(id: "sharpshooter", points: 50),
        Badge(id: "golden_ear", points: 25),
        Badge(id: "ear_perfect", points: 25),
        Badge(id: "ear_500", points: 50),
        // Learning
        Badge(id: "first_lesson", points: 5),
        Badge(id: "units_1", points: 10),
        Badge(id: "songs_1", points: 10),
        Badge(id: "lessons_25", points: 25),
        Badge(id: "perfect_10", points: 25),
        Badge(id: "units_10", points: 25),
        Badge(id: "lessons_100", points: 50),
        Badge(id: "course_done", points: 50),
        Badge(id: "songs_25", points: 50),
    ]

    /// The Game Center achievement for an app badge, if it has one.
    static func achievementID(forBadge id: String) -> String? {
        badges.first { $0.id == id }?.gameCenterID
    }
}
