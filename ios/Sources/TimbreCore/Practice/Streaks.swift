import Foundation

public struct StreakSummary: Equatable, Sendable {
    public let current: Int
    public let best: Int
    public let practicedToday: Bool
    public let activeDays: Set<Date>
    public let totalMinutes: Int
}

public enum Streaks {
    /// A day counts when any practice record falls on it. The current streak survives
    /// until the end of today, so an evening session still extends yesterday's run.
    /// `frozen` days (covered by a streak freeze) keep a run going without adding to it.
    public static func summary(records: [PracticeRecord], frozen: Set<Date> = [], now: Date = Date(), calendar: Calendar = .current) -> StreakSummary {
        let days = Set(records.filter { $0.date <= now }.map { calendar.startOfDay(for: $0.date) })
        let ice = Set(frozen.map { calendar.startOfDay(for: $0) }).subtracting(days)
        let today = calendar.startOfDay(for: now)
        var current = 0
        var cursor = days.contains(today) ? today : calendar.date(byAdding: .day, value: -1, to: today)!
        while days.contains(cursor) || ice.contains(cursor) {
            if days.contains(cursor) { current += 1 }
            cursor = calendar.date(byAdding: .day, value: -1, to: cursor)!
        }
        var best = 0, run = 0
        var previous: Date?
        for day in days.union(ice).sorted() {
            if let previous, calendar.date(byAdding: .day, value: 1, to: previous) == day {
                if days.contains(day) { run += 1 }
            } else {
                run = days.contains(day) ? 1 : 0
            }
            best = max(best, run)
            previous = day
        }
        let minutes = records.compactMap(\.durationMs).reduce(0, +) / 60000
        return StreakSummary(current: current, best: max(best, current), practicedToday: days.contains(today), activeDays: days, totalMinutes: minutes)
    }
}

/// Streak freezes: one is earned on every seventh day of a run (up to `cap` banked), and banked
/// freezes cover missed days automatically, as long as there are enough of them for the whole gap.
public enum StreakFreeze {
    public static let cap = 2

    /// The missed days (oldest first) between the last practised or frozen day and yesterday,
    /// if `available` freezes can cover all of them; otherwise none (the streak is over).
    public static func daysToCover(records: [PracticeRecord], frozen: Set<Date>, available: Int, now: Date = Date(), calendar: Calendar = .current) -> [Date] {
        guard available > 0 else { return [] }
        let today = calendar.startOfDay(for: now)
        let covered = Set(records.filter { $0.date <= now }.map { calendar.startOfDay(for: $0.date) }).union(frozen.map { calendar.startOfDay(for: $0) })
        guard let last = covered.filter({ $0 < today }).max() else { return [] }
        var gap: [Date] = []
        var cursor = calendar.date(byAdding: .day, value: 1, to: last)!
        while cursor < today {
            gap.append(cursor)
            if gap.count > available { return [] }
            cursor = calendar.date(byAdding: .day, value: 1, to: cursor)!
        }
        return gap
    }

    /// Whether today's practice earns a freeze: on every seventh day of the current run, once a day, below the cap.
    public static func earnsFreeze(summary: StreakSummary, banked: Int, lastAwardDay: String?, todayKey: String) -> Bool {
        summary.practicedToday && summary.current > 0 && summary.current % 7 == 0 && banked < cap && lastAwardDay != todayKey
    }
}

/// One activity in the daily practice set.
public struct DailyActivity: Identifiable, Equatable, Sendable {
    public enum Kind: String, Sendable, CaseIterable { case tune, ear, chord, scale, rhythm, voice, drone }
    public let kind: Kind
    public let minutes: Int
    public var id: String { kind.rawValue }
}

public enum DailySet {
    /// Builds about ten minutes of practice for the player's instrument and goal.
    /// Deterministic per calendar day so the set is stable across launches.
    public static func activities(instrument: Instrument, goal: String?, date: Date = Date(), calendar: Calendar = .current) -> [DailyActivity] {
        let day = calendar.ordinality(of: .day, in: .era, for: date) ?? 0
        let fretted = ["guitar", "ukulele", "mandolin", "folk_world_strings"].contains(instrument.familyId) && instrument.anchorType == "MACHINE_HEAD"
        var set: [DailyActivity] = [DailyActivity(kind: .tune, minutes: 1)]
        switch goal {
        case "voice": set += [DailyActivity(kind: .voice, minutes: 4), DailyActivity(kind: .ear, minutes: 3)]
        case "ear": set += [DailyActivity(kind: .ear, minutes: 5), DailyActivity(kind: .drone, minutes: 2)]
        case "rhythm": set += [DailyActivity(kind: .rhythm, minutes: 5), DailyActivity(kind: .ear, minutes: 2)]
        default:
            set.append(DailyActivity(kind: fretted ? (day % 2 == 0 ? .chord : .scale) : .drone, minutes: 4))
            set.append(DailyActivity(kind: .ear, minutes: 3))
        }
        set.append(DailyActivity(kind: .rhythm, minutes: 2))
        var seen = Set<DailyActivity.Kind>()
        return set.filter { seen.insert($0.kind).inserted }
    }
}
