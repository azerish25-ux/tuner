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
    public static func summary(records: [PracticeRecord], now: Date = Date(), calendar: Calendar = .current) -> StreakSummary {
        let days = Set(records.filter { $0.date <= now }.map { calendar.startOfDay(for: $0.date) })
        let today = calendar.startOfDay(for: now)
        var current = 0
        var cursor = days.contains(today) ? today : calendar.date(byAdding: .day, value: -1, to: today)!
        while days.contains(cursor) {
            current += 1
            cursor = calendar.date(byAdding: .day, value: -1, to: cursor)!
        }
        var best = 0, run = 0
        var previous: Date?
        for day in days.sorted() {
            if let previous, calendar.date(byAdding: .day, value: 1, to: previous) == day { run += 1 } else { run = 1 }
            best = max(best, run)
            previous = day
        }
        let minutes = records.compactMap(\.durationMs).reduce(0, +) / 60000
        return StreakSummary(current: current, best: max(best, current), practicedToday: days.contains(today), activeDays: days, totalMinutes: minutes)
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
