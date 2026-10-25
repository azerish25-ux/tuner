import Foundation

/// Every Game Center identifier the app uses, in one place. Each one must be created in App Store Connect
/// (the app → Game Center) with exactly this ID before it does anything; until then GameKit answers
/// "unknown" and the app carries on without it: the Leaderboard chips stay hidden, "Challenge a friend" sends a
/// "Beat my score" link instead, and reports are dropped quietly. docs/ios/APPLE-DELIVERY.md § 6.1 lists the same
/// setup as owner steps. IDs use letters, digits and periods only (challenge IDs allow nothing else).
///
/// Leaderboards ("Integer", sorted high to low, no score format suffix):
///
///     timbre.sniper.best    Classic     Best score     "Pitch Sniper"            Score range 0 – 25,000
///     timbre.sniper.weekly  Recurring   Best score     "Pitch Sniper this week"  Starts Monday 00:00 UTC, lasts 1 week,
///                                                                                restarts every week; 0 – 25,000
///     timbre.ear.level      Classic     Best score     "Ear trainer level"       Score range 1 – 100
///     timbre.streak         Classic     Most recent    "Practice streak"         Score range 0 – 10,000 (days)
///     timbre.song.<slug>    Classic     Best score     the song's title          Score range 0 – 200,000, one per
///                                                                                featured song (`songs` below)
///
/// Challenges (iOS 26, built on those leaderboards; at most 20 per app):
///
///     timbre.challenge.sniper        on timbre.sniper.weekly, repeatable (players pick 1, 3 or unlimited tries)
///     timbre.challenge.song.<slug>   on timbre.song.<slug>, not repeatable (one take; classic boards allow 1 day,
///                                    3 days or a week)
///
/// Activities (iOS 26, optional: they bring a player who taps a challenge in the Games app to the right screen):
///
///     timbre.activity.sniper         Pitch Sniper; associate timbre.sniper.weekly and timbre.sniper.best
///     timbre.activity.song.<slug>    that song; associate timbre.song.<slug>. A `lesson` property set to the song's
///                                    lesson ID works too, on any activity.
///
/// Achievements: `badges` below, one per line, ID `timbre.badge.<app badge id>`, the points given, not hidden,
/// not achievable more than once. Title and description are the app's own badge title and detail
/// (TimbreCore `Achievements.all`); each needs a 1024 × 1024 image. 31 achievements, 895 points (the cap is 1,000).
enum GameCenterIDs {
    // MARK: Leaderboards

    /// Pitch Sniper's best game, all time. Ten rounds of at most 500 points × the ×5 combo: 25,000 at most.
    static let sniperBest = "timbre.sniper.best"
    /// Pitch Sniper's best game this week: a recurring leaderboard, the weekly league. Its challenge lives here.
    static let sniperWeekly = "timbre.sniper.weekly"
    /// The ear trainer's level as the Play hub shows it ("Level 3"): the highest drill level plus one.
    static let earLevel = "timbre.ear.level"
    /// The practice streak in days, as the app counts it ("Most recent score": it goes down when a streak ends). Read
    /// back for friends only, for the "Streak #2 of 5 among friends" line on Progress's week card.
    static let streak = "timbre.streak"

    /// A featured song's Perform board: the points of a whole take at the song's own tempo (each note's credit × 100 ×
    /// the combo multiplier). Slower takes and practice loops never count.
    struct Song {
        /// The song's lesson ID in the curriculum.
        let lesson: String
        /// Letters only: the end of each ID.
        let slug: String
        /// The board's English name in App Store Connect.
        let title: String
        var leaderboardID: String { "timbre.song." + slug }
        var challengeID: String { "timbre.challenge.song." + slug }
        var activityID: String { "timbre.activity.song." + slug }
    }

    /// The featured songs: free songs (anyone can take the challenge), well known or the catalogue's own, short enough
    /// for one sitting. Eight, so the twenty-challenge cap keeps room for Pitch Sniper and later songs.
    static let songs: [Song] = [
        Song(lesson: "song-twinkle", slug: "twinkle", title: "Twinkle, Twinkle, Little Star"),
        Song(lesson: "song-ode-to-joy", slug: "odetojoy", title: "Ode to Joy"),
        Song(lesson: "song-jingle-bells", slug: "jinglebells", title: "Jingle Bells"),
        Song(lesson: "song-saints", slug: "saints", title: "When the Saints Go Marching In"),
        Song(lesson: "orig-kite-weather", slug: "kiteweather", title: "Kite Weather"),
        Song(lesson: "orig-dust-on-the-dashboard", slug: "dashboard", title: "Dust on the Dashboard"),
        Song(lesson: "std-loch-lomond", slug: "lochlomond", title: "Loch Lomond"),
        Song(lesson: "std-shell-be-coming", slug: "mountain", title: "She'll Be Coming 'Round the Mountain"),
    ]

    /// The featured song a lesson is, if it is one.
    static func song(forLesson id: String) -> Song? {
        songs.first { $0.lesson == id }
    }

    /// The most a note can score in a take: 100 points × the ×4 combo. A take claiming more is not sent.
    static let pointsPerNote = 400

    static let leaderboards = [sniperBest, sniperWeekly, earLevel, streak] + songs.map(\.leaderboardID)

    // MARK: Challenges and activities (iOS 26)

    static let sniperChallenge = "timbre.challenge.sniper"
    /// The challenges named here win when App Store Connect has two on the same leaderboard.
    static let challenges = [sniperChallenge] + songs.map(\.challengeID)

    static let sniperActivity = "timbre.activity.sniper"
    /// An activity property naming the lesson to open (any activity may carry it).
    static let lessonProperty = "lesson"

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
