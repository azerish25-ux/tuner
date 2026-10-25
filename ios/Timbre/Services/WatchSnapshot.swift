import Foundation

/// What the Apple Watch companion shows (TimbreWatch, its complications), sent by the iPhone app whenever it publishes
/// the widgets (`WatchBridge`). Shared by the app, the watch app and the watch complications: Foundation only.
/// Strings arrive already localized in the language picked in Timbre; the watch draws them as they are.
struct WatchSnapshot: Codable, Equatable, Sendable {
    /// When the iPhone sent it: the context and a complication transfer can land out of order, the newer one wins.
    var sent = Date.distantPast
    /// The start of the iPhone's day these values describe; `WatchDay` carries them past midnight.
    var day = Date.distantPast
    var streak = 0
    var best = 0
    var practicedToday = false
    /// Today's set in order (the Play hub's Today card).
    var steps: [Step] = []
    /// The daily quest still open (else the first one), as the Play hub counts it.
    var quest: QuestLine?
    /// The next lesson of the course Learn shows.
    var lesson: LessonLine?
    /// The iPhone metronome's tempo and beats a bar: the wrist starts there until it is given its own.
    var tempo = 96
    var beats = 4

    struct Step: Codable, Equatable, Sendable, Identifiable {
        var kind: String
        var symbol: String
        /// The Today ring's colour name: "violet" for the lesson, "neutral" for the rest (`WatchTheme`).
        var tint: String
        var title: String
        var minutes: Int
        var done: Bool
        var id: String { kind }
    }

    struct QuestLine: Codable, Equatable, Sendable {
        var title: String
        var symbol: String
        var done: Int
        var total: Int
        var xp: Int
        /// Paid out today.
        var claimed: Bool
    }

    struct LessonLine: Codable, Equatable, Sendable {
        var course: String
        var title: String
        var symbol: String
        var accent: String
    }

    /// Equal apart from when it was sent: nothing new for the watch.
    func sameContent(as other: WatchSnapshot?) -> Bool {
        guard var other else { return false }
        other.sent = sent
        return other == self
    }

    /// Something a complication draws changed (the streak, today's flame or the set ring).
    func complicationChanged(from other: WatchSnapshot?) -> Bool {
        guard let other else { return true }
        return other.day != day || other.streak != streak || other.practicedToday != practicedToday
            || other.steps.map(\.done) != steps.map(\.done) || other.steps.count != steps.count
    }
}

extension WatchSnapshot {
    /// Tolerant of a field the other side doesn't know yet (the iPhone and watch apps update separately).
    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        sent = try values.decodeIfPresent(Date.self, forKey: .sent) ?? .distantPast
        day = try values.decodeIfPresent(Date.self, forKey: .day) ?? .distantPast
        streak = try values.decodeIfPresent(Int.self, forKey: .streak) ?? 0
        best = try values.decodeIfPresent(Int.self, forKey: .best) ?? 0
        practicedToday = try values.decodeIfPresent(Bool.self, forKey: .practicedToday) ?? false
        steps = try values.decodeIfPresent([Step].self, forKey: .steps) ?? []
        quest = try values.decodeIfPresent(QuestLine.self, forKey: .quest)
        lesson = try values.decodeIfPresent(LessonLine.self, forKey: .lesson)
        tempo = try values.decodeIfPresent(Int.self, forKey: .tempo) ?? 96
        beats = try values.decodeIfPresent(Int.self, forKey: .beats) ?? 4
    }
}

/// The snapshot as of `now`, without the iPhone: a run stays alive through the day after its last practice and is over
/// after that (as `StreakStatus` reads the widget snapshot; banked freezes are spent only when the app next opens, so
/// this never claims a run that might not survive). Today's set and quest belong to the day they were sent.
struct WatchDay: Equatable, Sendable {
    let streak: Int
    let practicedToday: Bool
    let steps: [WatchSnapshot.Step]
    let quest: WatchSnapshot.QuestLine?
    let lesson: WatchSnapshot.LessonLine?
    /// The snapshot describes today (false once midnight has passed without a new one).
    let current: Bool

    init(_ snapshot: WatchSnapshot, now: Date = Date(), calendar: Calendar = .current) {
        let age = max(0, calendar.dateComponents([.day], from: calendar.startOfDay(for: snapshot.day), to: calendar.startOfDay(for: now)).day ?? 0)
        switch age {
        case 0:
            streak = snapshot.streak; practicedToday = snapshot.practicedToday
        case 1:
            streak = snapshot.practicedToday ? snapshot.streak : 0; practicedToday = false
        default:
            streak = 0; practicedToday = false
        }
        current = age == 0
        steps = age == 0 ? snapshot.steps : []
        quest = age == 0 ? snapshot.quest : nil
        lesson = snapshot.lesson
    }

    var done: Int { steps.filter(\.done).count }
    var total: Int { steps.count }
    var complete: Bool { total > 0 && done == total }
}

/// The WatchConnectivity vocabulary both ends use.
enum WatchLink {
    /// The application context / complication transfer key: the JSON-encoded `WatchSnapshot`.
    static let snapshot = "snapshot"
    /// A message from the watch: `[action: startToday]`; the iPhone replies `[opened: Bool]`.
    static let action = "action"
    static let startToday = "startToday"
    static let opened = "opened"
    /// The Handoff activity the watch advertises after "Start today's practice": the iPhone continues it on Today
    /// (declared in NSUserActivityTypes in project.yml, handled in TimbreApp).
    static let todayActivity = "com.shahradazerisharghi.timbre.today"
}
