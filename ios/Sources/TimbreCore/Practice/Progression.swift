import Foundation

/// The game layer: experience and levels, daily quests, achievements and string health.
/// Everything here is pure; the app persists the small `ProgressState` inside UserSettings.
public struct ProgressState: Codable, Equatable, Sendable {
    public var xp = 0
    /// Lifetime counters ("stringsTuned", "fullTunes", "preciseLocks", "bullseyes", "sniperBest", "sniperWins",
    /// "earCorrect", "earPerfect", "lessons", "perfectLessons", "dailySets").
    public var stats: [String: Int] = [:]
    /// Today's quest progress, keyed by quest id, for `questDay` ("yyyy-MM-dd").
    public var questDay: String?
    public var questProgress: [String: Int] = [:]
    public var questsClaimed: [String] = []
    public var achievements: [String] = []
    /// Instruments tuned at least once (for the multi-instrumentalist badge).
    public var instrumentsTuned: [String] = []
    /// First reading of each string per session, for drift between sessions.
    public var stringSamples: [StringSample] = []
    /// When each instrument was last restrung.
    public var restrung: [String: Date] = [:]
    /// Banked streak freezes, the days they covered, and the day ("yyyy-MM-dd") the last one was earned.
    /// Optional so saves from before streak freezes still decode.
    public var streakFreezes: Int?
    public var frozenDays: [Date]?
    public var freezeAwardDay: String?
    /// Strings locked today, per instrument (course indices), for `questDay`. It outlives a tuning session, so
    /// pausing, switching tabs or relaunching never sets the tuning quest back. Optional: older saves decode.
    public var tunedToday: [String: [Int]]?
    /// The day ("yyyy-MM-dd") the daily set was last completed; its bonus pays once a day.
    public var dailySetDay: String?
    public init() {}

    public static let sampleLimit = 600
    public var isValid: Bool {
        xp >= 0 && xp <= 50_000_000 && stats.values.allSatisfy { $0 >= 0 } && stringSamples.count <= Self.sampleLimit
            && questProgress.values.allSatisfy { $0 >= 0 } && questsClaimed.count <= 16 && achievements.count <= 128
            && instrumentsTuned.count <= 128 && stringSamples.allSatisfy { $0.cents.isFinite && abs($0.cents) <= 1200 }
            && (0...StreakFreeze.cap).contains(streakFreezes ?? 0) && (frozenDays?.count ?? 0) <= 400
            && (tunedToday?.count ?? 0) <= 128 && (tunedToday?.values.allSatisfy { $0.count <= 64 } ?? true)
    }

    /// How many of `courses` were locked today on this instrument (0 once the day has rolled over).
    public func stringsTunedToday(instrumentId: String, courses: [Int], now: Date = Date(), calendar: Calendar = .current) -> Int {
        guard questDay == Quests.dayKey(now, calendar: calendar), let tuned = tunedToday?[instrumentId] else { return 0 }
        return Set(courses).intersection(tuned).count
    }

    /// Today's progress toward a quest, capped at its target (0 once the day has rolled over).
    public func todayProgress(_ quest: Quest, now: Date = Date(), calendar: Calendar = .current) -> Int {
        questDay == Quests.dayKey(now, calendar: calendar) ? min(quest.target, max(0, questProgress[quest.id] ?? 0)) : 0
    }
}

public struct StringSample: Codable, Equatable, Sendable {
    public var instrumentId: String
    public var anchor: String
    public var date: Date
    /// Signed distance from the target when the string was first heard this session.
    public var cents: Double
    public init(instrumentId: String, anchor: String, date: Date, cents: Double) {
        self.instrumentId = instrumentId; self.anchor = anchor; self.date = date; self.cents = cents
    }
}

// MARK: - Levels

public struct Level: Equatable, Sendable {
    public let number: Int
    public let name: String
    /// XP at which this level starts and the next one begins.
    public let floor: Int
    public let next: Int
    public func progress(_ xp: Int) -> Double { Double(xp - floor) / Double(max(1, next - floor)) }
}

public enum XPReward {
    public static let stringTuned = 5
    public static let fullTune = 20
    public static let practiceMinute = 3
    public static let earCorrect = 2
    public static let sniperBullseye = 4
    public static let sniperWin = 30
    /// Every activity of the day's practice set done.
    public static let dailySet = 25
}

public enum Progression {
    public static let names = ["Open String", "First Fret", "Steady Hands", "Good Ear", "Sweet Spot", "Tuned Ear",
                               "Perfect Fifth", "Golden Ratio", "Concert Pitch", "Virtuoso"]
    /// Level n starts at 50·n·(n−1) XP: 0, 100, 300, 600, 1000, 1500, 2100 ...
    public static func floor(of level: Int) -> Int { 50 * level * (level - 1) }
    public static func level(for xp: Int) -> Level {
        var n = 1
        while floor(of: n + 1) <= max(0, xp) { n += 1 }
        let name = names[min(n - 1, names.count - 1)]
        return Level(number: n, name: n > names.count ? "\(name) \(n - names.count + 1)" : name, floor: floor(of: n), next: floor(of: n + 1))
    }
}

// MARK: - Daily quests

public struct Quest: Identifiable, Equatable, Sendable {
    public enum Kind: String, Sendable, CaseIterable { case tuneAll, holdInTune, sniperWin, bullseyes, practiceMinutes, earCorrect, lessons }
    public let kind: Kind
    public let target: Int
    public let xp: Int
    public var id: String { kind.rawValue }
}

public enum Quests {
    /// Quest kinds that count tuning. Only `tuneAll` is ever offered: one tuning quest, one counter, so the
    /// Play hub, the tuner's quest line and the reward toast all describe the same thing. `holdInTune`
    /// stays a kind (and keeps counting) so progress saved under its id still decodes.
    public static let tuningKinds: Set<Quest.Kind> = [.tuneAll, .holdInTune]

    /// Three quests a day: always "tune every string", plus two from the pool, stable for the date.
    /// The pool shuffles exactly as it always has; a retired tuning quest is skipped rather than removed,
    /// so every other day keeps the quests it had.
    public static func daily(for date: Date, calendar: Calendar = .current) -> [Quest] {
        let day = UInt64(calendar.ordinality(of: .day, in: .era, for: date) ?? 0)
        var rng = SplitMix64(seed: day &* 2_654_435_761)
        var pool: [Quest] = [
            Quest(kind: .sniperWin, target: 1, xp: 30), Quest(kind: .bullseyes, target: 5, xp: 25),
            Quest(kind: .practiceMinutes, target: 5, xp: 15), Quest(kind: .earCorrect, target: 10, xp: 20),
            Quest(kind: .holdInTune, target: 3, xp: 15), Quest(kind: .lessons, target: 2, xp: 30),
        ]
        pool.shuffle(using: &rng)
        return [Quest(kind: .tuneAll, target: 1, xp: 20)] + pool.filter { !tuningKinds.contains($0.kind) }.prefix(2)
    }

    /// The one counter a quest shows. The tuning quest counts in strings, like the tuner's quest line
    /// ("4 / 6": strings locked this session out of the instrument's strings) and reads full once it has
    /// paid out today; every other quest counts its own progress toward its target.
    public static func counter(for quest: Quest, progress: Int, lockedStrings: Int, strings: Int) -> (done: Int, total: Int) {
        let claimed = progress >= quest.target
        guard quest.kind == .tuneAll, strings > 0 else { return (done: min(max(0, progress), quest.target), total: quest.target) }
        return (done: claimed ? strings : min(max(0, lockedStrings), strings), total: strings)
    }

    /// The counter every quest display shows, read from saved progress: the tuning quest counts the strings
    /// of this instrument locked today (`tunedToday`), so it never drops back when a session ends.
    /// `courses` are the current tuning's course indices (empty in chromatic mode); nil instrument counts none.
    public static func counter(for quest: Quest, state: ProgressState, instrumentId: String?, courses: [Int], now: Date = Date(), calendar: Calendar = .current) -> (done: Int, total: Int) {
        let tuned = instrumentId.map { state.stringsTunedToday(instrumentId: $0, courses: courses, now: now, calendar: calendar) } ?? 0
        return counter(for: quest, progress: state.todayProgress(quest, now: now, calendar: calendar), lockedStrings: tuned, strings: courses.count)
    }

    public static func dayKey(_ date: Date, calendar: Calendar = .current) -> String {
        let c = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
    }
}

// MARK: - Recording progress

public enum ProgressEvent: Equatable, Sendable {
    /// A string locked in tune (`all` when it completed every course of the instrument in one session).
    /// `course` is the string's course index and `courses` every course index of the tuning: together they
    /// keep today's per-instrument list, which completes the tuning quest across sessions. `precise`: locked
    /// at Pro precision (±1¢).
    case stringTuned(instrumentId: String, all: Bool, course: Int? = nil, courses: [Int] = [], precise: Bool = false)
    case practiceMinutes(Int)
    case earCorrect
    /// A finished ear-training round (ten questions); a perfect one counts toward a badge.
    case earRound(questions: Int, correct: Int)
    case sniperRound(bullseye: Bool)
    case sniperGame(score: Int, won: Bool)
    /// A lesson finished (its XP already scaled by stars).
    case lessonCompleted(stars: Int, xp: Int)
    /// Every activity of today's practice set done (pays once a day).
    case dailySetCompleted
}

public struct ProgressUpdate: Equatable, Sendable {
    public var xpGained = 0
    public var levelUp: Level?
    public var questsCompleted: [Quest] = []
    public var achievementsEarned: [Achievement] = []
    /// Today's practice set was just completed (its bonus is in `xpGained`).
    public var dailySetCompleted = false
    public init(xpGained: Int = 0, levelUp: Level? = nil, questsCompleted: [Quest] = [], achievementsEarned: [Achievement] = [], dailySetCompleted: Bool = false) {
        self.xpGained = xpGained; self.levelUp = levelUp; self.questsCompleted = questsCompleted; self.achievementsEarned = achievementsEarned
        self.dailySetCompleted = dailySetCompleted
    }

    /// Two updates that land together (one action recording several events) as one announcement.
    public func merged(with next: ProgressUpdate) -> ProgressUpdate {
        var all = self
        all.xpGained += next.xpGained
        if let level = next.levelUp, level.number > (all.levelUp?.number ?? 0) { all.levelUp = level }
        all.questsCompleted += next.questsCompleted.filter { q in !all.questsCompleted.contains { $0.id == q.id } }
        all.achievementsEarned += next.achievementsEarned.filter { a in !all.achievementsEarned.contains { $0.id == a.id } }
        all.dailySetCompleted = all.dailySetCompleted || next.dailySetCompleted
        return all
    }
}

extension ProgressState {
    /// Applies one event: XP, counters, today's quests (rolling over at midnight) and achievements.
    /// `metrics` carries badge values the app derives elsewhere (`Achievements.learnMetrics`, practice minutes).
    public mutating func record(_ event: ProgressEvent, streakBest: Int = 0, customTunings: Int = 0, metrics: [String: Int] = [:], now: Date = Date(), calendar: Calendar = .current) -> ProgressUpdate {
        var update = ProgressUpdate()
        let before = Progression.level(for: xp)
        let key = Quests.dayKey(now, calendar: calendar)
        if questDay != key { questDay = key; questProgress = [:]; questsClaimed = []; tunedToday = nil }
        func bump(_ stat: String, by n: Int = 1) { stats[stat, default: 0] += n }
        func quest(_ kind: Quest.Kind, by n: Int = 1) { questProgress[kind.rawValue, default: 0] += n }
        switch event {
        case let .stringTuned(instrument, all, course, courses, precise):
            update.xpGained += XPReward.stringTuned
            bump("stringsTuned"); quest(.holdInTune)
            if precise { bump("preciseLocks") }
            if !instrumentsTuned.contains(instrument) { instrumentsTuned.append(instrument) }
            let everyString = markTuned(instrument, course: course, of: courses)
            if all { update.xpGained += XPReward.fullTune; bump("fullTunes") }
            if all || everyString { quest(.tuneAll) }
        case .practiceMinutes(let minutes):
            update.xpGained += XPReward.practiceMinute * max(0, minutes); quest(.practiceMinutes, by: max(0, minutes))
        case .earCorrect:
            update.xpGained += XPReward.earCorrect; bump("earCorrect"); quest(.earCorrect)
        case let .earRound(questions, correct):
            if questions >= 10 && correct >= questions { bump("earPerfect") }
        case .sniperRound(let bullseye):
            if bullseye { update.xpGained += XPReward.sniperBullseye; bump("bullseyes"); quest(.bullseyes) }
        case .sniperGame(let score, let won):
            stats["sniperBest"] = max(stats["sniperBest"] ?? 0, score)
            if won { update.xpGained += XPReward.sniperWin; bump("sniperWins"); quest(.sniperWin) }
        case .lessonCompleted(let stars, let xp):
            update.xpGained += max(0, xp); bump("lessons"); quest(.lessons)
            if stars >= 3 { bump("perfectLessons") }
        case .dailySetCompleted:
            if dailySetDay != key {
                dailySetDay = key
                update.xpGained += XPReward.dailySet; bump("dailySets")
                update.dailySetCompleted = true
            }
        }
        for q in Quests.daily(for: now, calendar: calendar) where !questsClaimed.contains(q.id) && (questProgress[q.id] ?? 0) >= q.target {
            questsClaimed.append(q.id)
            update.questsCompleted.append(q)
            update.xpGained += q.xp
        }
        xp += update.xpGained
        let after = Progression.level(for: xp)
        if after.number > before.number { update.levelUp = after }
        update.achievementsEarned = awardAchievements(streakBest: streakBest, customTunings: customTunings, metrics: metrics)
        return update
    }

    /// Adds a locked string to today's list for its instrument; true once every one of `courses` is on it.
    private mutating func markTuned(_ instrument: String, course: Int?, of courses: [Int]) -> Bool {
        guard let course else { return false }
        var lists = tunedToday ?? [:]
        var tuned = lists[instrument] ?? []
        if !tuned.contains(course) { tuned.append(course) }
        lists[instrument] = Array(tuned.suffix(64))
        tunedToday = lists
        return !courses.isEmpty && Set(courses).isSubset(of: Set(tuned))
    }

    /// Awards every achievement whose goal is met but not yet recorded (also run at launch, so a goal
    /// reached without an event — a streak kept by a freeze, say — still unlocks).
    @discardableResult
    public mutating func awardAchievements(streakBest: Int = 0, customTunings: Int = 0, metrics: [String: Int] = [:]) -> [Achievement] {
        var earned: [Achievement] = []
        for a in Achievements.all where !achievements.contains(a.id) && a.isEarned(self, streakBest: streakBest, customTunings: customTunings, metrics: metrics) {
            achievements.append(a.id)
            earned.append(a)
        }
        return earned
    }

    /// The first stable reading of a string in a session; older samples roll off.
    public mutating func sample(_ sample: StringSample) {
        stringSamples.append(sample)
        if stringSamples.count > Self.sampleLimit { stringSamples.removeFirst(stringSamples.count - Self.sampleLimit) }
    }
}

// MARK: - Achievements

public struct Achievement: Identifiable, Equatable, Sendable {
    /// The medal's rim: how far the goal is.
    public enum Tier: Int, Sendable { case bronze, silver, gold }
    /// The medal's colour: what kind of playing it rewards.
    public enum Category: String, Sendable { case tuning, dedication, ear, learning, course }

    public let id: String
    public let title: String
    public let detail: String
    public let symbol: String
    /// Counter (or derived value) and the goal it must reach.
    public let metric: String
    public let goal: Int
    public var tier: Tier = .bronze
    public var category: Category = .tuning

    /// The live value toward the goal. `metrics` holds values derived outside `ProgressState`
    /// (Learn progress, practice minutes); a key there wins over a stored counter of the same name.
    public func value(_ state: ProgressState, streakBest: Int, customTunings: Int, metrics: [String: Int] = [:]) -> Int {
        switch metric {
        case "streakBest": return streakBest
        case "level": return Progression.level(for: state.xp).number
        case "instruments": return state.instrumentsTuned.count
        case "customTunings": return customTunings
        default: return metrics[metric] ?? state.stats[metric] ?? 0
        }
    }
    public func isEarned(_ state: ProgressState, streakBest: Int, customTunings: Int, metrics: [String: Int] = [:]) -> Bool {
        value(state, streakBest: streakBest, customTunings: customTunings, metrics: metrics) >= goal
    }
}

public enum Achievements {
    /// The first sixteen keep their ids, metrics and goals, so saved badges stay earned.
    public static let all: [Achievement] = [
        Achievement(id: "first_tune", title: "First in tune", detail: "Tune your first string", symbol: "checkmark", metric: "stringsTuned", goal: 1, tier: .bronze, category: .tuning),
        Achievement(id: "full_tune", title: "All six", detail: "Tune every string of an instrument", symbol: "music.note", metric: "fullTunes", goal: 1, tier: .bronze, category: .tuning),
        Achievement(id: "streak_7", title: "Perfect week", detail: "Play seven days in a row", symbol: "flame.fill", metric: "streakBest", goal: 7, tier: .silver, category: .dedication),
        Achievement(id: "strings_100", title: "Hundred strings", detail: "Tune 100 strings", symbol: "tuningfork", metric: "stringsTuned", goal: 100, tier: .silver, category: .tuning),
        Achievement(id: "bullseye", title: "Bullseye", detail: "Hit a bullseye in Pitch Sniper", symbol: "scope", metric: "bullseyes", goal: 1, tier: .bronze, category: .ear),
        Achievement(id: "sharpshooter", title: "Sharpshooter", detail: "Score 2,000 in Pitch Sniper", symbol: "target", metric: "sniperBest", goal: 2000, tier: .gold, category: .ear),
        Achievement(id: "golden_ear", title: "Golden ear", detail: "Answer 50 ear questions right", symbol: "ear", metric: "earCorrect", goal: 50, tier: .silver, category: .ear),
        Achievement(id: "level_5", title: "Rising star", detail: "Reach level 5", symbol: "star.fill", metric: "level", goal: 5, tier: .silver, category: .dedication),
        Achievement(id: "multi", title: "Multi-instrumentalist", detail: "Tune three different instruments", symbol: "guitars", metric: "instruments", goal: 3, tier: .silver, category: .tuning),
        Achievement(id: "own_tuning", title: "Your own sound", detail: "Create a custom tuning", symbol: "slider.horizontal.3", metric: "customTunings", goal: 1, tier: .bronze, category: .tuning),
        Achievement(id: "streak_30", title: "Month of music", detail: "Play thirty days in a row", symbol: "calendar", metric: "streakBest", goal: 30, tier: .gold, category: .dedication),
        Achievement(id: "strings_1000", title: "Thousand strings", detail: "Tune 1,000 strings", symbol: "sparkles", metric: "stringsTuned", goal: 1000, tier: .gold, category: .tuning),
        Achievement(id: "first_lesson", title: "First lesson", detail: "Finish your first lesson", symbol: "graduationcap.fill", metric: "lessons", goal: 1, tier: .bronze, category: .learning),
        Achievement(id: "lessons_25", title: "Regular", detail: "Finish 25 lessons", symbol: "books.vertical.fill", metric: "lessons", goal: 25, tier: .silver, category: .learning),
        Achievement(id: "lessons_100", title: "Scholar", detail: "Finish 100 lessons", symbol: "medal.fill", metric: "lessons", goal: 100, tier: .gold, category: .learning),
        Achievement(id: "perfect_10", title: "Flawless", detail: "Earn three stars on 10 lessons", symbol: "star.circle.fill", metric: "perfectLessons", goal: 10, tier: .silver, category: .learning),
        // Tuning
        Achievement(id: "full_25", title: "Tune-up habit", detail: "Tune every string 25 times", symbol: "checkmark.seal.fill", metric: "fullTunes", goal: 25, tier: .silver, category: .tuning),
        Achievement(id: "precise_10", title: "Hairline", detail: "Lock 10 strings at Pro precision", symbol: "smallcircle.filled.circle", metric: "preciseLocks", goal: 10, tier: .silver, category: .tuning),
        Achievement(id: "precise_100", title: "Laser tuned", detail: "Lock 100 strings at Pro precision", symbol: "rays", metric: "preciseLocks", goal: 100, tier: .gold, category: .tuning),
        // Dedication
        Achievement(id: "streak_3", title: "Warming up", detail: "Play three days in a row", symbol: "flame", metric: "streakBest", goal: 3, tier: .bronze, category: .dedication),
        Achievement(id: "streak_100", title: "Hundred days", detail: "Play 100 days in a row", symbol: "crown.fill", metric: "streakBest", goal: 100, tier: .gold, category: .dedication),
        Achievement(id: "minutes_60", title: "First hour", detail: "Practice for an hour in all", symbol: "clock.fill", metric: "minutes", goal: 60, tier: .bronze, category: .dedication),
        Achievement(id: "minutes_600", title: "Ten hours", detail: "Practice for ten hours in all", symbol: "hourglass", metric: "minutes", goal: 600, tier: .silver, category: .dedication),
        Achievement(id: "daily_1", title: "Daily set", detail: "Finish a daily set", symbol: "sun.max.fill", metric: "dailySets", goal: 1, tier: .bronze, category: .dedication),
        Achievement(id: "daily_30", title: "Creature of habit", detail: "Finish 30 daily sets", symbol: "calendar.badge.checkmark", metric: "dailySets", goal: 30, tier: .gold, category: .dedication),
        // Ear and games
        Achievement(id: "sniper_win", title: "Marksman", detail: "Win a round of Pitch Sniper", symbol: "flag.checkered", metric: "sniperWins", goal: 1, tier: .bronze, category: .ear),
        Achievement(id: "bullseyes_50", title: "Dead center", detail: "Hit 50 bullseyes", symbol: "circle.circle.fill", metric: "bullseyes", goal: 50, tier: .silver, category: .ear),
        Achievement(id: "ear_perfect", title: "Clean sweep", detail: "Get all ten right in an ear round", symbol: "10.circle.fill", metric: "earPerfect", goal: 1, tier: .silver, category: .ear),
        Achievement(id: "ear_500", title: "Master listener", detail: "Answer 500 ear questions right", symbol: "ear.and.waveform", metric: "earCorrect", goal: 500, tier: .gold, category: .ear),
        // Learning
        Achievement(id: "units_1", title: "Unit cleared", detail: "Finish every lesson in a unit", symbol: "square.stack.3d.up.fill", metric: "units", goal: 1, tier: .bronze, category: .learning),
        Achievement(id: "units_10", title: "Ten units", detail: "Finish ten units", symbol: "rectangle.stack.fill", metric: "units", goal: 10, tier: .silver, category: .learning),
        Achievement(id: "course_done", title: "Graduate", detail: "Finish a whole course", symbol: "rosette", metric: "courses", goal: 1, tier: .gold, category: .learning),
        Achievement(id: "songs_1", title: "First song", detail: "Play your first song", symbol: "music.note", metric: "songs", goal: 1, tier: .bronze, category: .learning),
        Achievement(id: "songs_25", title: "Songbook", detail: "Play 25 songs", symbol: "music.note.list", metric: "songs", goal: 25, tier: .gold, category: .learning),
        // A milestone per instrument course (ten lessons)
        Achievement(id: "course_guitar", title: "Guitarist", detail: "Finish 10 guitar lessons", symbol: "guitars", metric: "course.guitar", goal: 10, tier: .silver, category: .course),
        Achievement(id: "course_ukulele", title: "Uke player", detail: "Finish 10 ukulele lessons", symbol: "music.note", metric: "course.ukulele", goal: 10, tier: .silver, category: .course),
        Achievement(id: "course_bass", title: "Bassist", detail: "Finish 10 bass lessons", symbol: "waveform", metric: "course.bass", goal: 10, tier: .silver, category: .course),
        Achievement(id: "course_violin", title: "Violinist", detail: "Finish 10 violin lessons", symbol: "music.note", metric: "course.violin", goal: 10, tier: .silver, category: .course),
        Achievement(id: "course_cello", title: "Cellist", detail: "Finish 10 cello lessons", symbol: "music.note", metric: "course.cello", goal: 10, tier: .silver, category: .course),
        Achievement(id: "course_mandolin", title: "Mandolinist", detail: "Finish 10 mandolin lessons", symbol: "music.note.list", metric: "course.mandolin", goal: 10, tier: .silver, category: .course),
        Achievement(id: "course_banjo", title: "Banjo picker", detail: "Finish 10 banjo lessons", symbol: "music.note", metric: "course.banjo", goal: 10, tier: .silver, category: .course),
        Achievement(id: "course_voice", title: "Singer", detail: "Finish 10 singing lessons", symbol: "music.mic", metric: "course.voice", goal: 10, tier: .silver, category: .course),
    ]

    /// The course a per-course badge belongs to ("course.guitar" → "guitar"), for its artwork.
    public static func courseId(of achievement: Achievement) -> String? {
        achievement.metric.hasPrefix("course.") ? String(achievement.metric.dropFirst("course.".count)) : nil
    }

    /// Badge values that come from Learn progress, so lessons finished before a badge existed still count:
    /// lessons finished per course ("course.<id>"), whole units ("units") and courses ("courses") finished,
    /// and song and challenge lessons played ("songs", "challenges").
    public static func learnMetrics(_ learn: LearnProgress, curriculum: Curriculum) -> [String: Int] {
        var metrics: [String: Int] = ["units": 0, "courses": 0, "songs": 0, "challenges": 0]
        for course in curriculum.courses {
            var finished = 0, lessons = 0
            for unit in course.units {
                let done = unit.lessons.filter { learn.isFinished($0.id) }
                finished += done.count; lessons += unit.lessons.count
                if !unit.lessons.isEmpty && done.count == unit.lessons.count { metrics["units", default: 0] += 1 }
                metrics["songs", default: 0] += done.filter { $0.kind == .song }.count
                metrics["challenges", default: 0] += done.filter { $0.kind == .challenge }.count
            }
            metrics["course." + course.id] = finished
            if lessons > 0 && finished == lessons { metrics["courses", default: 0] += 1 }
        }
        return metrics
    }
}

// MARK: - String health

public struct StringDrift: Equatable, Sendable {
    public let anchor: String
    /// Average signed drift per day between sessions (negative: goes flat).
    public let centsPerDay: Double
    public let sessions: Int
}

public enum StringHealth {
    /// Drift per string from consecutive sessions: each session ends in tune, so the next session's
    /// first reading over the days in between is how fast that string wanders.
    public static func drift(_ samples: [StringSample], instrumentId: String, since: Date? = nil, minimumGapHours: Double = 6) -> [StringDrift] {
        let mine = samples.filter { sample in sample.instrumentId == instrumentId && (since.map { sample.date > $0 } ?? true) }
        var result: [StringDrift] = []
        for (anchor, list) in Dictionary(grouping: mine, by: \.anchor) {
            let sorted = list.sorted { $0.date < $1.date }
            var rates: [Double] = []
            for (a, b) in zip(sorted, sorted.dropFirst()) {
                let days = b.date.timeIntervalSince(a.date) / 86_400
                guard days * 24 >= minimumGapHours else { continue }
                rates.append(b.cents / days)
            }
            guard !rates.isEmpty else { continue }
            rates.sort()
            let median = rates.count % 2 == 1 ? rates[rates.count / 2] : (rates[rates.count / 2 - 1] + rates[rates.count / 2]) / 2
            result.append(StringDrift(anchor: anchor, centsPerDay: median, sessions: rates.count))
        }
        return result.sorted { abs($0.centsPerDay) > abs($1.centsPerDay) }
    }

    /// Restring advice: strings that wander more than 4 cents a day, or that are more than ten weeks old.
    public static func needsRestring(_ drifts: [StringDrift], restrung: Date?, now: Date = Date()) -> Bool {
        if let worst = drifts.first, abs(worst.centsPerDay) >= 4, worst.sessions >= 2 { return true }
        if let restrung, now.timeIntervalSince(restrung) > 70 * 86_400 { return true }
        return false
    }
}
