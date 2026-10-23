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

/// One activity in Today, the day's one practice session.
public struct DailyActivity: Identifiable, Equatable, Sendable {
    /// `lesson` is the next lesson of the learner's course and `review` a review Learn has due; both are
    /// played in Learn. The rest are tool reps.
    public enum Kind: String, Sendable, CaseIterable { case tune, ear, chord, scale, rhythm, voice, drone, lesson, review }
    public let kind: Kind
    public let minutes: Int
    public var id: String { kind.rawValue }
    public init(kind: Kind, minutes: Int) { self.kind = kind; self.minutes = minutes }
    /// Played in Learn rather than in a tool.
    public var isLearn: Bool { kind == .lesson || kind == .review }
}

/// Today: one session of about ten minutes, the same set on Tune, Learn and Play.
public enum DailySet {
    /// Activities that need Timbre Pro (chords, scales, the drone).
    public static let proKinds: Set<DailyActivity.Kind> = [.chord, .scale, .drone]
    /// The lesson's place on the ring: its own estimate, kept within these minutes.
    public static let lessonMinutes = 3...8
    /// A review's place on the ring.
    public static let reviewMinutes = 2...6

    /// Today's session, about `target` minutes long (the player's daily commitment). With `lessonMinutes` (the
    /// next lesson of the learner's course, nil when there is none they can play) it opens with that lesson,
    /// then a review when Learn has one due (`reviewMinutes`, a hook for the weak-spot reviews), then two tool
    /// reps: a one-minute tune-up and the day's tool for the goal, which fills the rest. Without a lesson a
    /// second tool takes its place. Deterministic per calendar day so the set is stable across launches;
    /// without Pro no Pro tool is picked, so a free player can always finish the whole set.
    public static func activities(instrument: Instrument, goal: String?, pro: Bool = true, lessonMinutes: Int? = nil, reviewMinutes: Int? = nil,
                                  target: Int = 10, date: Date = Date(), calendar: Calendar = .current) -> [DailyActivity] {
        let day = max(0, calendar.ordinality(of: .day, in: .era, for: date) ?? 0)
        let rotation = tools(instrument: instrument, goal: goal, pro: pro)
        let first = rotation[day % rotation.count]
        let lesson = lessonMinutes.map { clamp($0, to: Self.lessonMinutes) }
        let review = reviewMinutes.map { clamp($0, to: Self.reviewMinutes) }
        // What the tools have left of the target, a couple of minutes each at least.
        let toolTime = max(target, 5) - 1 - (lesson ?? 0) - (review ?? 0)
        var set: [DailyActivity] = []
        if let lesson { set.append(DailyActivity(kind: .lesson, minutes: lesson)) }
        if let review { set.append(DailyActivity(kind: .review, minutes: review)) }
        set.append(DailyActivity(kind: .tune, minutes: 1))
        if lesson != nil {
            set.append(DailyActivity(kind: first, minutes: clamp(toolTime, to: 2...10)))
        } else {
            // The next different tool of the rotation stands in for the lesson.
            let second = (1..<max(2, rotation.count)).map { rotation[(day + $0) % rotation.count] }.first { $0 != first } ?? (first == .ear ? .rhythm : .ear)
            let half = (toolTime + 1) / 2
            set.append(DailyActivity(kind: first, minutes: clamp(half, to: 2...10)))
            set.append(DailyActivity(kind: second, minutes: clamp(toolTime - half, to: 2...10)))
        }
        return set
    }

    /// The tools a goal rotates through, one a day; the goal's own tool comes round every other day.
    static func tools(instrument: Instrument, goal: String?, pro: Bool) -> [DailyActivity.Kind] {
        let fretted = ["guitar", "ukulele", "mandolin", "folk_world_strings"].contains(instrument.familyId) && instrument.anchorType == "MACHINE_HEAD"
        let list: [DailyActivity.Kind]
        switch goal {
        case "voice": list = [.voice, .ear, .voice, .drone]
        case "ear": list = [.ear, .drone, .ear, .rhythm]
        case "rhythm": list = [.rhythm, .ear, .rhythm, fretted ? .chord : .drone]
        default: list = fretted ? [.chord, .ear, .scale, .rhythm] : [.drone, .ear, .rhythm, .ear]
        }
        let open = pro ? list : list.filter { !proKinds.contains($0) }
        return open.isEmpty ? [.ear, .rhythm] : open
    }

    private static func clamp(_ minutes: Int, to range: ClosedRange<Int>) -> Int { min(range.upperBound, max(range.lowerBound, minutes)) }

    /// The quest that rides along with an activity of the set: the Play hub shows it on that activity's row
    /// (an XP side goal) instead of as a second item for the same practice.
    public static func quest(for kind: DailyActivity.Kind, in quests: [Quest]) -> Quest? {
        quests.first { $0.dailyKind == kind }
    }

    /// The quests that stand on their own beside the set (none of its activities covers them).
    public static func sideQuests(_ quests: [Quest], beside set: [DailyActivity]) -> [Quest] {
        let kinds = Set(set.map(\.kind))
        return quests.filter { quest in quest.dailyKind.map { !kinds.contains($0) } ?? true }
    }
}

extension Quest {
    /// The Today activity that covers the same practice, if any.
    public var dailyKind: DailyActivity.Kind? {
        switch kind {
        case .tuneAll, .holdInTune: return .tune
        case .earCorrect: return .ear
        case .lessons: return .lesson
        case .practiceMinutes, .sniperWin, .bullseyes: return nil
        }
    }
}
