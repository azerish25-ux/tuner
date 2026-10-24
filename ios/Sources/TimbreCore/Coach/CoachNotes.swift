import Foundation

// MARK: - What the coach can say

/// What a lesson step trains, for "you nail single notes; chords are your weak spot".
public enum CoachSkill: String, Codable, Sendable, CaseIterable {
    case notes, chords, rhythm, ear

    /// The skill a step trains; nil for an explanation (or a kind of step the coach doesn't weigh).
    public static func of(_ step: LessonStep) -> CoachSkill? {
        switch step {
        case .playNotes, .playAlong: return .notes
        case .playChord, .strum, .progression: return .chords
        case .tapRhythm: return .rhythm
        case .listen, .quiz: return .ear
        default: return nil
        }
    }

    /// What a lesson mostly trains: the skill most of its steps practise (the earlier one in `allCases` on a tie).
    public static func of(_ lesson: Lesson) -> CoachSkill? {
        var counts: [CoachSkill: Int] = [:]
        for step in lesson.steps { if let skill = of(step) { counts[skill, default: 0] += 1 } }
        var best: CoachSkill?
        var most = 0
        for skill in allCases where (counts[skill] ?? 0) > most {
            best = skill
            most = counts[skill] ?? 0
        }
        return best
    }

    public static func of(_ item: PracticeItem) -> CoachSkill {
        switch item {
        case .note: return .notes
        case .chord: return .chords
        }
    }
}

/// What a note asks the player to do next.
public enum CoachAction: Equatable, Sendable {
    /// The course's weak-spot drill (built on the fly from what slipped).
    case review(courseId: String)
    /// Play a lesson again (or for the first time).
    case lesson(id: String)
    /// The metronome at a tempo.
    case metronome(bpm: Int)
    /// The tuner.
    case tune
    /// Today's set, on the Play tab.
    case today
}

/// The measured facts behind a note. Every number in a note's words comes from here, so a rewording (on-device
/// language model) can be checked against them.
public enum CoachFact: Equatable, Sendable {
    /// Moving from one chord (or note) to the next came in `milliseconds` late (negative: early) on `beat` of its
    /// bar, on average over the changes heard; `missed` of `count` weren't heard at all (`milliseconds` is nil when
    /// none was). `bpm` is the take's tempo.
    case change(from: PracticeItem, to: PracticeItem, milliseconds: Int?, beat: Int, missed: Int, count: Int, bpm: Int)
    /// On a flawless run (`Coach.isFlawless`) the change that still came in off the beat, as the next level to reach
    /// rather than a fix: `milliseconds` late (negative: early) on `beat` of its bar, on average.
    case nextLevel(from: PracticeItem, to: PracticeItem, milliseconds: Int, beat: Int)
    /// The notes sat `milliseconds` behind (negative: ahead of) the click on average, over `notes` notes at `bpm`.
    case lean(milliseconds: Int, notes: Int, bpm: Int)
    /// These slipped, weakest first (one or two of a kind); the weakest came out `percent` % clean.
    case slipped(items: [PracticeItem], percent: Int)
    /// One skill is clearly stronger than another (average scores in percent).
    case split(strong: CoachSkill, strongPercent: Int, weak: CoachSkill, weakPercent: Int)
    /// The lesson scored `percent` % but only below its tempo, so it stopped short of three stars; `bpm` is the full tempo.
    case belowTempo(percent: Int, bpm: Int)
    /// Every one of `items` notes and chords came out clean (90 % or better).
    case clean(items: Int)
    /// A string (its anchor id) drifts this many whole cents a day between sessions (negative: flat).
    case drift(anchor: String, centsPerDay: Int)
    /// The strings went on this many weeks ago.
    case oldStrings(weeks: Int)
    /// A streak of `days` days that today hasn't extended yet.
    case streak(days: Int)
    /// Today's set: `done` of `total` activities, `next` (about `minutes` long) up next.
    case today(done: Int, total: Int, next: DailyActivity.Kind, minutes: Int)
    /// Minutes in the last seven days, `percent` % more than the seven before.
    case moreTime(minutes: Int, percent: Int)
    /// Recent tune-ups land within `cents` on average (one decimal), down from `before` a few weeks ago.
    case closerTuning(cents: Double, before: Double)
}

/// One thing the coach says: a fact with its numbers, what to do about it, and how much it matters.
public struct CoachNote: Identifiable, Equatable, Sendable {
    /// One note per topic makes the cut, so the coach never says the same thing twice.
    public enum Topic: String, Sendable { case timing, items, skills, tempo, strings, habit, growth, tuning }
    /// Something to fix, something done well, or a nudge to keep the habit.
    public enum Tone: String, Sendable { case fix, praise, habit }

    public let fact: CoachFact
    public let action: CoachAction?
    /// 0…1, higher first.
    public let priority: Double

    public init(fact: CoachFact, action: CoachAction?, priority: Double) {
        self.fact = fact; self.action = action; self.priority = max(0, min(1, priority))
    }

    public var topic: Topic {
        switch fact {
        case .change, .lean, .nextLevel: return .timing
        case .slipped, .clean: return .items
        case .split: return .skills
        case .belowTempo: return .tempo
        case .drift, .oldStrings: return .strings
        case .streak, .today: return .habit
        case .moreTime: return .growth
        case .closerTuning: return .tuning
        }
    }

    public var tone: Tone {
        switch fact {
        case .clean, .moreTime, .closerTuning, .nextLevel: return .praise
        case .streak, .today: return .habit
        default: return .fix
        }
    }

    /// Stable for the same advice about the same thing (the drift of one string, the change between two chords).
    public var id: String {
        switch fact {
        case let .change(from, to, _, _, _, _, _): return "change.\(from.key)>\(to.key)"
        case let .nextLevel(from, to, _, _): return "next.\(from.key)>\(to.key)"
        case .lean: return "lean"
        case let .slipped(items, _): return "slipped." + items.map(\.key).joined(separator: "+")
        case let .split(strong, _, weak, _): return "split.\(strong.rawValue)>\(weak.rawValue)"
        case .belowTempo: return "tempo"
        case .clean: return "clean"
        case let .drift(anchor, _): return "drift.\(anchor)"
        case .oldStrings: return "strings.old"
        case .streak: return "streak"
        case .today: return "today"
        case .moreTime: return "week"
        case .closerTuning: return "tuning"
        }
    }
}

// MARK: - The rules

/// The coach: turns what Timbre already measures (play-along timing, how each note and chord went, string drift,
/// the streak and Today's set, the week) into a few specific notes, each with its numbers and one thing to do.
/// Pure: the app passes what it knows and words the notes (`CoachFact`); nothing here is invented.
public enum Coach {
    /// Below this a note or chord has slipped (as for the weak spots).
    public static let slipBelow = LearnProgress.weakBelow
    /// At or above this everything counts as clean.
    public static let cleanAbove = 0.9
    /// A change this far off the beat on average is worth a word…
    public static let lateChange = 0.12
    /// …when it is this much worse than staying put.
    public static let standOut = 0.06
    /// A change never heard counts as this late.
    public static let missCost = 0.3
    /// Takes leaning this far behind or ahead of the click.
    public static let leanSeconds = 0.09
    /// Less spread than this around a lean is the audio route's delay, not the player.
    public static let steadySpread = 0.025
    /// Notes a card shows at most.
    public static let limit = 3
    /// Three stars at this accuracy or better is "Flawless" on the results.
    public static let flawlessAbove = 0.98

    /// A run the results call "Flawless" (three stars, 98 % or better). The coach agrees with the headline then: it
    /// has nothing to fix, only praise or the next level to reach.
    public static func isFlawless(_ result: LessonResult) -> Bool {
        result.stars >= 3 && result.accuracy >= flawlessAbove
    }

    /// Going from one chord to another is a "change"; between single notes it is a "move" (a melody has no chord to
    /// change), which is how the coach words it.
    public static func changesChord(from: PracticeItem, to: PracticeItem) -> Bool {
        CoachSkill.of(from) == .chords || CoachSkill.of(to) == .chords
    }

    // MARK: After a lesson

    public struct LessonContext: Sendable {
        public var lesson: Lesson
        public var courseId: String
        public var result: LessonResult
        /// This lesson's takes (play-alongs and strummed steps).
        public var takes: [CoachTake]
        /// A rhythm was tapped on the glass rather than played: its timing says nothing about the instrument.
        public var tapped: Bool
        /// Whether the course can build its weak-spot drill now (it has something to review).
        public var canReview: Bool

        public init(lesson: Lesson, courseId: String, result: LessonResult, takes: [CoachTake] = [], tapped: Bool = false, canReview: Bool = false) {
            self.lesson = lesson; self.courseId = courseId; self.result = result
            self.takes = takes; self.tapped = tapped; self.canReview = canReview
        }
    }

    /// What to say at the end of a lesson, best first (empty when there is nothing specific). Under "Flawless" the
    /// coach agrees with the headline: no fixes, and a change still off the beat comes as the next level to reach.
    public static func lessonNotes(_ context: LessonContext) -> [CoachNote] {
        let flawless = isFlawless(context.result)
        var notes: [CoachNote] = []
        if !context.tapped {
            if flawless {
                if let tip = nextLevelNote(context.takes) { notes.append(tip) }
            } else {
                notes += timingNotes(context.takes, weight: 1)
                if let note = belowTempoNote(context) { notes.append(note) }
            }
        }
        // A weak-spot review is the drill itself: it doesn't send you to it again.
        let review = context.canReview && !LearnProgress.isReview(context.lesson.id) ? CoachAction.review(courseId: context.courseId) : nil
        let scores = context.result.items.map { (item: $0.item, score: $0.score) }
        notes += itemNotes(scores, review: review, base: 0.6)
        if let note = splitNote(scores, review: review) { notes.append(note) }
        return rank(flawless ? notes.filter { $0.tone != .fix } : notes)
    }

    /// On a flawless run: the change that kept coming in off the beat (heard every time, and off on average by at
    /// least `lateChange`), as a tip with no slower tempo to practise it at. It leads the clean-run praise.
    static func nextLevelNote(_ takes: [CoachTake]) -> CoachNote? {
        guard let change = worstChange(in: takes), change.missed == 0, let offset = change.meanOffset,
              abs(offset) >= lateChange else { return nil }
        return CoachNote(fact: .nextLevel(from: change.from, to: change.to, milliseconds: milliseconds(offset), beat: change.beat),
                         action: nil, priority: 0.3)
    }

    /// Timing notes from takes: the change that kept landing late, then a lean behind or ahead of the click.
    /// `weight` scales their priority (older takes matter less).
    public static func timingNotes(_ takes: [CoachTake], weight: Double) -> [CoachNote] {
        var notes: [CoachNote] = []
        if let change = worstChange(in: takes) {
            let fact = CoachFact.change(from: change.from, to: change.to, milliseconds: change.meanOffset.map { milliseconds($0) },
                                        beat: change.beat, missed: change.missed, count: change.count, bpm: Int(change.bpm.rounded()))
            let priority = min(0.95, 0.7 + (change.cost - lateChange)) * weight
            notes.append(CoachNote(fact: fact, action: .metronome(bpm: loopTempo(change.bpm)), priority: priority))
        }
        if let leaning = lean(in: takes) {
            let tempo = Int(leaning.bpm.rounded())
            notes.append(CoachNote(fact: .lean(milliseconds: milliseconds(leaning.offset), notes: leaning.notes, bpm: tempo),
                                   action: .metronome(bpm: tempo), priority: 0.42 * weight))
        }
        return notes
    }

    /// A strong take that only came at a slower tempo: the third star is one full-tempo take away.
    static func belowTempoNote(_ context: LessonContext) -> CoachNote? {
        let result = context.result
        guard result.stars < 3, result.accuracy >= cleanAbove, !LearnProgress.isReview(context.lesson.id),
              let bpm = alongTempo(context.lesson) else { return nil }
        return CoachNote(fact: .belowTempo(percent: percent(result.accuracy), bpm: Int(bpm.rounded())),
                         action: .lesson(id: context.lesson.id), priority: 0.82)
    }

    /// The lesson tempo of a lesson's first play-along.
    static func alongTempo(_ lesson: Lesson) -> Double? {
        for step in lesson.steps {
            if case let .playAlong(_, bpm, _, _) = step { return bpm }
        }
        return nil
    }

    /// The weakest one or two of a kind that slipped, or (nothing slipped) a clean run of three or more.
    /// `base` is the priority of a note that just slipped; the further below, the higher.
    static func itemNotes(_ scores: [(item: PracticeItem, score: Double)], review: CoachAction?, base: Double) -> [CoachNote] {
        let sorted = scores.sorted { $0.score != $1.score ? $0.score < $1.score : $0.item.key < $1.item.key }
        let slipped = sorted.filter { $0.score < slipBelow }
        if let weakest = slipped.first {
            let kind = CoachSkill.of(weakest.item)
            let items = slipped.filter { CoachSkill.of($0.item) == kind }.prefix(2).map { $0.item }
            let priority = min(0.92, base + (slipBelow - weakest.score) * 0.5)
            return [CoachNote(fact: .slipped(items: Array(items), percent: percent(weakest.score)), action: review, priority: priority)]
        }
        if sorted.count >= 3, sorted.allSatisfy({ $0.score >= cleanAbove }) {
            return [CoachNote(fact: .clean(items: sorted.count), action: nil, priority: 0.24)]
        }
        return []
    }

    /// Single notes against chords within one lesson: two or more of each, one side clean on average (90 %),
    /// the other well behind (75 % or less).
    static func splitNote(_ scores: [(item: PracticeItem, score: Double)], review: CoachAction?) -> CoachNote? {
        let notes = scores.filter { CoachSkill.of($0.item) == .notes }.map { $0.score }
        let chords = scores.filter { CoachSkill.of($0.item) == .chords }.map { $0.score }
        guard notes.count >= 2, chords.count >= 2 else { return nil }
        let n = mean(notes), c = mean(chords)
        let (strong, strongScore, weak, weakScore) = n >= c ? (CoachSkill.notes, n, CoachSkill.chords, c) : (CoachSkill.chords, c, CoachSkill.notes, n)
        guard strongScore >= cleanAbove, weakScore <= 0.75 else { return nil }
        return CoachNote(fact: .split(strong: strong, strongPercent: percent(strongScore), weak: weak, weakPercent: percent(weakScore)),
                         action: review, priority: min(0.88, 0.62 + (strongScore - weakScore) * 0.6))
    }

    // MARK: On Progress

    /// One activity of Today and whether it is done.
    public struct TodayStep: Equatable, Sendable {
        public let activity: DailyActivity
        public let done: Bool
        public init(activity: DailyActivity, done: Bool) { self.activity = activity; self.done = done }
    }

    public struct JourneyContext: Sendable {
        public var now: Date
        public var calendar: Calendar
        public var records: [PracticeRecord]
        public var streakDays: Int
        public var practicedToday: Bool
        /// The current instrument's string drift (`StringHealth.drift`) and when it was restrung.
        public var drift: [StringDrift]
        public var restrung: Date?
        /// The course Learn shows, and the player's progress through it.
        public var course: LearnCourse?
        public var learn: LearnProgress
        /// Whether that course can build its weak-spot drill now.
        public var canReview: Bool
        public var today: [TodayStep]
        /// Takes from a lesson played recently (this session).
        public var takes: [CoachTake]

        public init(now: Date = Date(), calendar: Calendar = .current, records: [PracticeRecord], streakDays: Int, practicedToday: Bool,
                    drift: [StringDrift] = [], restrung: Date? = nil, course: LearnCourse? = nil, learn: LearnProgress = LearnProgress(),
                    canReview: Bool = false, today: [TodayStep] = [], takes: [CoachTake] = []) {
            self.now = now; self.calendar = calendar; self.records = records
            self.streakDays = streakDays; self.practicedToday = practicedToday
            self.drift = drift; self.restrung = restrung
            self.course = course; self.learn = learn; self.canReview = canReview
            self.today = today; self.takes = takes
        }
    }

    /// What to say on Progress, best first: at most `limit` notes, one per topic.
    public static func journeyNotes(_ context: JourneyContext) -> [CoachNote] {
        var notes: [CoachNote] = []
        notes += timingNotes(context.takes, weight: 0.85)
        notes += stringNotes(drift: context.drift, restrung: context.restrung, now: context.now)
        if let course = context.course {
            let review = context.canReview ? CoachAction.review(courseId: course.id) : nil
            let spots = context.learn.weakSpots(in: course).map { (item: $0.item, score: $0.score) }
            // Only what slipped: a clean record across the course is the lessons' own business.
            notes += itemNotes(spots, review: review, base: 0.5).filter { $0.tone == .fix }
            if let split = courseSplit(course, learn: context.learn, review: review) { notes.append(split) }
        }
        notes += habitNotes(context)
        notes += growthNotes(records: context.records, now: context.now, calendar: context.calendar)
        return rank(notes)
    }

    /// The string that wanders furthest, once its drift is settled and past the restring line (as the String
    /// health card judges it); else strings older than ten weeks.
    static func stringNotes(drift: [StringDrift], restrung: Date?, now: Date) -> [CoachNote] {
        let judged = drift.filter { $0.sessions >= 2 && (restrung != nil || $0.spanDays >= StringHealth.minimumSpanDays) }
        if let worst = judged.max(by: { abs($0.centsPerDay) < abs($1.centsPerDay) }), abs(worst.centsPerDay) >= StringHealth.restringCentsPerDay {
            let priority = min(0.85, 0.6 + (abs(worst.centsPerDay) - StringHealth.restringCentsPerDay) * 0.03)
            return [CoachNote(fact: .drift(anchor: worst.anchor, centsPerDay: Int(worst.centsPerDay.rounded())), action: .tune, priority: priority)]
        }
        if let restrung {
            let days = now.timeIntervalSince(restrung) / 86_400
            if days > 70 { return [CoachNote(fact: .oldStrings(weeks: Int(days / 7)), action: .tune, priority: 0.5)] }
        }
        return []
    }

    /// Across a course's finished lessons: the skill the player is best at against the one they are weakest at
    /// (two lessons or more each, by best accuracy). The drill when it covers that skill, else its weakest lesson.
    static func courseSplit(_ course: LearnCourse, learn: LearnProgress, review: CoachAction?) -> CoachNote? {
        var bySkill: [CoachSkill: [(id: String, score: Double)]] = [:]
        for lesson in course.lessons where lesson.kind != .review {
            guard let best = learn.bestAccuracy[lesson.id], let skill = CoachSkill.of(lesson) else { continue }
            bySkill[skill, default: []].append((id: lesson.id, score: best))
        }
        let skills = CoachSkill.allCases.filter { (bySkill[$0]?.count ?? 0) >= 2 }
        guard skills.count >= 2 else { return nil }
        func average(_ skill: CoachSkill) -> Double { mean((bySkill[skill] ?? []).map { $0.score }) }
        var strong = skills[0], weak = skills[0]
        for skill in skills {
            if average(skill) > average(strong) { strong = skill }
            if average(skill) < average(weak) { weak = skill }
        }
        let high = average(strong), low = average(weak)
        guard strong != weak, high >= 0.88, low <= 0.78, high - low >= 0.12 else { return nil }
        let spots = course.lessons.flatMap { learn.weakSpots[$0.id] ?? [] }
        let drillCovers = spots.contains { CoachSkill.of($0.item) == weak }
        let weakest = (bySkill[weak] ?? []).min { $0.score != $1.score ? $0.score < $1.score : $0.id < $1.id }
        let action: CoachAction? = review != nil && drillCovers ? review : weakest.map { CoachAction.lesson(id: $0.id) }
        return CoachNote(fact: .split(strong: strong, strongPercent: percent(high), weak: weak, weakPercent: percent(low)),
                         action: action, priority: 0.62)
    }

    /// A streak today hasn't extended yet (a minute keeps it), or Today's set half done.
    static func habitNotes(_ context: JourneyContext) -> [CoachNote] {
        if !context.practicedToday, context.streakDays >= 2 {
            return [CoachNote(fact: .streak(days: context.streakDays), action: .tune, priority: 0.64)]
        }
        let done = context.today.filter(\.done).count
        if context.practicedToday, done >= 1, let next = context.today.first(where: { !$0.done }) {
            return [CoachNote(fact: .today(done: done, total: context.today.count, next: next.activity.kind, minutes: next.activity.minutes),
                              action: .today, priority: 0.38)]
        }
        return []
    }

    /// Praise with numbers: more time this week than last (by a fifth or more), tune-ups landing closer than a
    /// few weeks ago (by a quarter and at least 0.3 ¢).
    static func growthNotes(records: [PracticeRecord], now: Date, calendar: Calendar) -> [CoachNote] {
        var notes: [CoachNote] = []
        let today = calendar.startOfDay(for: now)
        guard let start = calendar.date(byAdding: .day, value: -6, to: today),
              let previous = calendar.date(byAdding: .day, value: -7, to: start),
              let monthAgo = calendar.date(byAdding: .day, value: -35, to: today) else { return [] }
        let week = records.filter { $0.date >= start && $0.date <= now }
        let before = records.filter { $0.date >= previous && $0.date < start }
        // Rounded as the week card rounds its minutes, so the two always agree.
        let minutes = Int((Double(week.compactMap(\.durationMs).reduce(0, +)) / 60_000).rounded())
        let earlier = Double(before.compactMap(\.durationMs).reduce(0, +)) / 60_000
        if minutes >= 10, earlier >= 5 {
            let gain = Int(((Double(minutes) - earlier) / earlier * 100).rounded())
            if gain >= 20 { notes.append(CoachNote(fact: .moreTime(minutes: minutes, percent: gain), action: nil, priority: 0.3)) }
        }
        let tunings = records.filter { $0.kind == "tuning" && $0.date <= now && $0.meanAbsoluteCents != nil }
        let recent = tunings.filter { $0.date >= start }.compactMap(\.meanAbsoluteCents)
        let older = tunings.filter { $0.date >= monthAgo && $0.date < start }.compactMap(\.meanAbsoluteCents)
        if recent.count >= 3, older.count >= 3 {
            let lately = tenths(mean(recent)), formerly = tenths(mean(older))
            if lately <= formerly * 0.75, formerly - lately >= 0.3 {
                notes.append(CoachNote(fact: .closerTuning(cents: lately, before: formerly), action: nil, priority: 0.28))
            }
        }
        return notes
    }

    // MARK: Ranking

    /// Highest priority first (ties keep their order), one note per topic, at most `limit`.
    public static func rank(_ notes: [CoachNote], limit: Int = Coach.limit) -> [CoachNote] {
        let ordered = notes.enumerated().sorted { a, b in
            a.element.priority != b.element.priority ? a.element.priority > b.element.priority : a.offset < b.offset
        }
        var topics: Set<CoachNote.Topic> = []
        var out: [CoachNote] = []
        for (_, note) in ordered where out.count < limit && !topics.contains(note.topic) {
            topics.insert(note.topic)
            out.append(note)
        }
        return out
    }

    // MARK: Helpers

    static func percent(_ score: Double) -> Int { Int((max(0, min(1, score)) * 100).rounded()) }
    static func tenths(_ value: Double) -> Double { (value * 10).rounded() / 10 }
    static func mean(_ values: [Double]) -> Double { values.isEmpty ? 0 : values.reduce(0, +) / Double(values.count) }
}
