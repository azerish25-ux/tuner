import Foundation

/// The game layer: experience and levels, daily quests, achievements and string health.
/// Everything here is pure; the app persists the small `ProgressState` inside UserSettings.
public struct ProgressState: Codable, Equatable, Sendable {
    public var xp = 0
    /// Lifetime counters ("stringsTuned", "fullTunes", "bullseyes", "sniperBest", "sniperWins", "earCorrect").
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
    public init() {}

    public static let sampleLimit = 600
    public var isValid: Bool {
        xp >= 0 && xp <= 50_000_000 && stats.values.allSatisfy { $0 >= 0 } && stringSamples.count <= Self.sampleLimit
            && questProgress.values.allSatisfy { $0 >= 0 } && questsClaimed.count <= 16 && achievements.count <= 128
            && instrumentsTuned.count <= 128 && stringSamples.allSatisfy { $0.cents.isFinite && abs($0.cents) <= 1200 }
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
    public enum Kind: String, Sendable, CaseIterable { case tuneAll, holdInTune, sniperWin, bullseyes, practiceMinutes, earCorrect }
    public let kind: Kind
    public let target: Int
    public let xp: Int
    public var id: String { kind.rawValue }
}

public enum Quests {
    /// Three quests a day: always "tune every string", plus two from the pool, stable for the date.
    public static func daily(for date: Date, calendar: Calendar = .current) -> [Quest] {
        let day = UInt64(calendar.ordinality(of: .day, in: .era, for: date) ?? 0)
        var rng = SplitMix64(seed: day &* 2_654_435_761)
        var pool: [Quest] = [
            Quest(kind: .sniperWin, target: 1, xp: 30), Quest(kind: .bullseyes, target: 5, xp: 25),
            Quest(kind: .practiceMinutes, target: 5, xp: 15), Quest(kind: .earCorrect, target: 10, xp: 20),
            Quest(kind: .holdInTune, target: 3, xp: 15),
        ]
        pool.shuffle(using: &rng)
        return [Quest(kind: .tuneAll, target: 1, xp: 20)] + pool.prefix(2)
    }

    public static func dayKey(_ date: Date, calendar: Calendar = .current) -> String {
        let c = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
    }
}

// MARK: - Recording progress

public enum ProgressEvent: Equatable, Sendable {
    /// A string locked in tune (`all` when it completed every course of the instrument).
    case stringTuned(instrumentId: String, all: Bool)
    case practiceMinutes(Int)
    case earCorrect
    case sniperRound(bullseye: Bool)
    case sniperGame(score: Int, won: Bool)
}

public struct ProgressUpdate: Equatable, Sendable {
    public var xpGained = 0
    public var levelUp: Level?
    public var questsCompleted: [Quest] = []
    public var achievementsEarned: [Achievement] = []
}

extension ProgressState {
    /// Applies one event: XP, counters, today's quests (rolling over at midnight) and achievements.
    public mutating func record(_ event: ProgressEvent, streakBest: Int = 0, customTunings: Int = 0, now: Date = Date(), calendar: Calendar = .current) -> ProgressUpdate {
        var update = ProgressUpdate()
        let before = Progression.level(for: xp)
        let key = Quests.dayKey(now, calendar: calendar)
        if questDay != key { questDay = key; questProgress = [:]; questsClaimed = [] }
        func bump(_ stat: String, by n: Int = 1) { stats[stat, default: 0] += n }
        func quest(_ kind: Quest.Kind, by n: Int = 1) { questProgress[kind.rawValue, default: 0] += n }
        switch event {
        case .stringTuned(let instrument, let all):
            update.xpGained += XPReward.stringTuned
            bump("stringsTuned"); quest(.holdInTune)
            if !instrumentsTuned.contains(instrument) { instrumentsTuned.append(instrument) }
            if all { update.xpGained += XPReward.fullTune; bump("fullTunes"); quest(.tuneAll) }
        case .practiceMinutes(let minutes):
            update.xpGained += XPReward.practiceMinute * max(0, minutes); quest(.practiceMinutes, by: max(0, minutes))
        case .earCorrect:
            update.xpGained += XPReward.earCorrect; bump("earCorrect"); quest(.earCorrect)
        case .sniperRound(let bullseye):
            if bullseye { update.xpGained += XPReward.sniperBullseye; bump("bullseyes"); quest(.bullseyes) }
        case .sniperGame(let score, let won):
            stats["sniperBest"] = max(stats["sniperBest"] ?? 0, score)
            if won { update.xpGained += XPReward.sniperWin; bump("sniperWins"); quest(.sniperWin) }
        }
        for q in Quests.daily(for: now, calendar: calendar) where !questsClaimed.contains(q.id) && (questProgress[q.id] ?? 0) >= q.target {
            questsClaimed.append(q.id)
            update.questsCompleted.append(q)
            update.xpGained += q.xp
        }
        xp += update.xpGained
        let after = Progression.level(for: xp)
        if after.number > before.number { update.levelUp = after }
        for a in Achievements.all where !achievements.contains(a.id) && a.isEarned(self, streakBest: streakBest, customTunings: customTunings) {
            achievements.append(a.id)
            update.achievementsEarned.append(a)
        }
        return update
    }

    /// The first stable reading of a string in a session; older samples roll off.
    public mutating func sample(_ sample: StringSample) {
        stringSamples.append(sample)
        if stringSamples.count > Self.sampleLimit { stringSamples.removeFirst(stringSamples.count - Self.sampleLimit) }
    }
}

// MARK: - Achievements

public struct Achievement: Identifiable, Equatable, Sendable {
    public let id: String
    public let title: String
    public let detail: String
    public let symbol: String
    /// Counter (or derived value) and the goal it must reach.
    public let metric: String
    public let goal: Int

    public func value(_ state: ProgressState, streakBest: Int, customTunings: Int) -> Int {
        switch metric {
        case "streakBest": return streakBest
        case "level": return Progression.level(for: state.xp).number
        case "instruments": return state.instrumentsTuned.count
        case "customTunings": return customTunings
        default: return state.stats[metric] ?? 0
        }
    }
    public func isEarned(_ state: ProgressState, streakBest: Int, customTunings: Int) -> Bool {
        value(state, streakBest: streakBest, customTunings: customTunings) >= goal
    }
}

public enum Achievements {
    public static let all: [Achievement] = [
        Achievement(id: "first_tune", title: "First in tune", detail: "Tune your first string", symbol: "checkmark", metric: "stringsTuned", goal: 1),
        Achievement(id: "full_tune", title: "All six", detail: "Tune every string of an instrument", symbol: "music.note", metric: "fullTunes", goal: 1),
        Achievement(id: "streak_7", title: "Perfect week", detail: "Play seven days in a row", symbol: "flame.fill", metric: "streakBest", goal: 7),
        Achievement(id: "strings_100", title: "Hundred strings", detail: "Tune 100 strings", symbol: "100.circle", metric: "stringsTuned", goal: 100),
        Achievement(id: "bullseye", title: "Bullseye", detail: "Hit a bullseye in Pitch Sniper", symbol: "scope", metric: "bullseyes", goal: 1),
        Achievement(id: "sharpshooter", title: "Sharpshooter", detail: "Score 2,000 in Pitch Sniper", symbol: "target", metric: "sniperBest", goal: 2000),
        Achievement(id: "golden_ear", title: "Golden ear", detail: "Answer 50 ear questions right", symbol: "ear", metric: "earCorrect", goal: 50),
        Achievement(id: "level_5", title: "Sweet spot", detail: "Reach level 5", symbol: "star.fill", metric: "level", goal: 5),
        Achievement(id: "multi", title: "Multi-instrumentalist", detail: "Tune three different instruments", symbol: "guitars", metric: "instruments", goal: 3),
        Achievement(id: "own_tuning", title: "Your own sound", detail: "Create a custom tuning", symbol: "slider.horizontal.3", metric: "customTunings", goal: 1),
        Achievement(id: "streak_30", title: "Month of music", detail: "Play thirty days in a row", symbol: "calendar", metric: "streakBest", goal: 30),
        Achievement(id: "strings_1000", title: "Thousand strings", detail: "Tune 1,000 strings", symbol: "sparkles", metric: "stringsTuned", goal: 1000),
    ]
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
