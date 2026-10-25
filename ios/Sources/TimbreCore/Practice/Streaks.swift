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

/// `Streaks.summary` worked out once and kept until something it reads changes: the records, the frozen days, the
/// calendar day or the time zone. A record dated later than the last count starts to count when its time comes.
/// The owner bumps `revision` whenever its records change (the cache never compares the records themselves).
public struct StreakCache {
    private var revision: Int?
    private var frozen: [Date] = []
    private var timeZone: TimeZone?
    private var validFrom = Date.distantFuture
    private var validUntil = Date.distantPast
    private var cached: StreakSummary?

    public init() {}

    public mutating func summary(records: [PracticeRecord], revision: Int, frozen: [Date], now: Date = Date(), calendar: Calendar = .current) -> StreakSummary {
        if let cached, self.revision == revision, self.frozen == frozen, timeZone == calendar.timeZone, validFrom <= now, now < validUntil {
            return cached
        }
        let summary = Streaks.summary(records: records, frozen: Set(frozen), now: now, calendar: calendar)
        let today = calendar.startOfDay(for: now)
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: today) ?? now
        let nextRecord = records.lazy.map(\.date).filter { $0 > now }.min()
        self.revision = revision
        self.frozen = frozen
        timeZone = calendar.timeZone
        validFrom = today
        validUntil = nextRecord.map { min($0, tomorrow) } ?? tomorrow
        cached = summary
        return summary
    }

    /// Forgets the summary: the next read counts again.
    public mutating func invalidate() { cached = nil }
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
    ///
    /// `pinned` is the day's tools as the player first saw them (`toolReps(in:)` of that set): they stay, whatever
    /// instrument the tuner is on now, so switching instruments never reshuffles a plan already shown (see
    /// `toolPicks`). `done` is what today's set has ticked off.
    public static func activities(instrument: Instrument, goal: String?, pro: Bool = true, lessonMinutes: Int? = nil, reviewMinutes: Int? = nil,
                                  target: Int = 10, pinned: [DailyActivity.Kind]? = nil, done: Set<DailyActivity.Kind> = [],
                                  date: Date = Date(), calendar: Calendar = .current) -> [DailyActivity] {
        let lesson = lessonMinutes.map { clamp($0, to: Self.lessonMinutes) }
        let review = reviewMinutes.map { clamp($0, to: Self.reviewMinutes) }
        // One tool beside a lesson; without one, a second tool stands in for it.
        let picks = toolPicks(instrument: instrument, goal: goal, pro: pro, count: lesson == nil ? 2 : 1, pinned: pinned, done: done,
                              date: date, calendar: calendar)
        // What the tools have left of the target, shared out (the first gets any odd minute), a couple of minutes each at least.
        let toolTime = max(target, 5) - 1 - (lesson ?? 0) - (review ?? 0)
        let share = toolTime / max(1, picks.count)
        let extra = toolTime - share * max(1, picks.count)
        var set: [DailyActivity] = []
        if let lesson { set.append(DailyActivity(kind: .lesson, minutes: lesson)) }
        if let review { set.append(DailyActivity(kind: .review, minutes: review)) }
        set.append(DailyActivity(kind: .tune, minutes: 1))
        for (index, kind) in picks.enumerated() {
            set.append(DailyActivity(kind: kind, minutes: clamp(share + (index < extra ? 1 : 0), to: 2...10)))
        }
        return set
    }

    /// The tool reps of a set (neither the tune-up nor Learn's lesson and review): what `pinned` keeps for the day.
    public static func toolReps(in set: [DailyActivity]) -> [DailyActivity.Kind] {
        set.map(\.kind).filter { $0 != .tune && $0 != .lesson && $0 != .review }
    }

    /// The day's `count` tool reps. Fresh, they are the goal's tool of the day, then the next different tools of its
    /// rotation. With `pinned` (the tools the player has already seen today) those stay, in their order, even when
    /// the instrument or the plan has changed since: only a tool that can no longer be played (a Pro tool once Pro
    /// has lapsed) gives way, unless it is already `done`. When the set has room for fewer (a lesson joined it) the
    /// last ones not yet done step out; when it needs more (the lesson left it, or a tool gave way) the day's
    /// rotation fills in.
    public static func toolPicks(instrument: Instrument, goal: String?, pro: Bool = true, count: Int, pinned: [DailyActivity.Kind]? = nil,
                                 done: Set<DailyActivity.Kind> = [], date: Date = Date(), calendar: Calendar = .current) -> [DailyActivity.Kind] {
        let day = max(0, calendar.ordinality(of: .day, in: .era, for: date) ?? 0)
        let rotation = tools(instrument: instrument, goal: goal, pro: pro)
        // The rotation from today's tool on, each tool once, then ear training and rhythm should it hold only one.
        var candidates: [DailyActivity.Kind] = []
        for offset in 0..<rotation.count {
            let kind = rotation[(day + offset) % rotation.count]
            if !candidates.contains(kind) { candidates.append(kind) }
        }
        for kind in [DailyActivity.Kind.ear, .rhythm] where !candidates.contains(kind) { candidates.append(kind) }
        let wanted = max(1, count)
        var picks: [DailyActivity.Kind] = []
        for kind in pinned ?? [] where kind != .tune && kind != .lesson && kind != .review && !picks.contains(kind) {
            if done.contains(kind) || pro || !proKinds.contains(kind) { picks.append(kind) }
        }
        while picks.count > wanted, let index = picks.lastIndex(where: { !done.contains($0) }) { picks.remove(at: index) }
        for kind in candidates where picks.count < wanted && !picks.contains(kind) { picks.append(kind) }
        return picks
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
