import Foundation

// MARK: - What a review brings back

/// An ear or theory question as a lesson asked it, to ask again: a listen step (an interval, a chord quality,
/// higher or lower) when it has a sound, a theory quiz otherwise.
public struct ReviewQuestion: Codable, Equatable, Sendable {
    public let prompt: LearnText
    /// The notes played, group by group; nil for a theory question.
    public let sound: [[Int]]?
    public let options: [LearnText]
    public let answer: Int
    public let why: LearnText?
    public let visual: LessonVisual

    public init(prompt: LearnText, sound: [[Int]]?, options: [LearnText], answer: Int, why: LearnText? = nil, visual: LessonVisual = LessonVisual.none) {
        self.prompt = prompt; self.sound = sound; self.options = options; self.answer = answer; self.why = why; self.visual = visual
    }

    enum CodingKeys: String, CodingKey { case prompt = "p", sound = "s", options = "o", answer = "a", why = "w", visual = "v" }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        prompt = try c.decode(LearnText.self, forKey: .prompt)
        sound = try c.decodeIfPresent([[Int]].self, forKey: .sound)
        options = try c.decode([LearnText].self, forKey: .options)
        answer = try c.decode(Int.self, forKey: .answer)
        why = try c.decodeIfPresent(LearnText.self, forKey: .why)
        visual = (try? c.decodeIfPresent(LessonVisual.self, forKey: .visual)) ?? LessonVisual.none
    }
}

/// Something spaced review can bring back: a note or chord a lesson asked for, a change between two chords, a
/// strummed or tapped rhythm, or an ear or theory question.
public enum ReviewItem: Codable, Equatable, Sendable {
    case note(midi: Int, at: Fretting?)
    case chord(ChordSpec)
    /// Changing between two chords in time (from a progression). The same two chords either way round are one item.
    case change(from: ChordSpec, to: ChordSpec)
    /// A rhythm as a strum or tap step asked for it: the pattern's beats, the meter (nil: the step's default), the
    /// tempo and, on a strum, the chord it was strummed on and its muted and accented beats (as `LessonStep.strum`
    /// counts them), so a review grades its chops and accents as the lesson did.
    case rhythm(pattern: [Double], beatsPerBar: Int?, bpm: Double, chord: ChordSpec?, strummed: Bool, muted: [Double] = [], accents: [Double] = [])
    case question(ReviewQuestion)

    /// What kind of practice an item is; a review takes the kinds in turn.
    public enum Kind: String, Codable, Sendable, CaseIterable { case note, chord, change, rhythm, interval, quiz }

    public var kind: Kind {
        switch self {
        case .note: return .note
        case .chord: return .chord
        case .change: return .change
        case .rhythm: return .rhythm
        case let .question(question): return question.sound == nil ? .quiz : .interval
        }
    }

    /// A note or chord as a lesson scored it.
    public init(_ item: PracticeItem) {
        switch item {
        case let .note(midi, at): self = .note(midi: midi, at: at)
        case let .chord(spec): self = .chord(spec)
        }
    }

    /// The note or chord as lessons score it; nil for the other kinds.
    public var practiceItem: PracticeItem? {
        switch self {
        case let .note(midi, at): return .note(midi: midi, at: at)
        case let .chord(spec): return .chord(spec)
        default: return nil
        }
    }

    /// A stable text key: what makes two items the same one (a rhythm's tempo and chord, a change's direction, do not).
    public var key: String {
        switch self {
        case let .note(midi, at): return PracticeItem.note(midi: midi, at: at).key
        case let .chord(spec): return PracticeItem.chord(spec).key
        case let .change(from, to):
            let ends = [PracticeItem.chord(from).key, PracticeItem.chord(to).key].sorted()
            return "x" + ends[0] + "~" + ends[1]
        case let .rhythm(pattern, beatsPerBar, _, _, _, _, _):
            return "r\(beatsPerBar ?? 0):" + pattern.map { "\($0)" }.joined(separator: ",")
        case let .question(question):
            let sound = question.sound.map { groups in groups.map { $0.map(String.init).joined(separator: "+") }.joined(separator: ",") } ?? ""
            let options = question.options.map(Self.textKey).joined(separator: "|")
            return "q" + Self.textKey(question.prompt) + ":" + sound + ":" + options + ":\(question.answer)"
        }
    }

    private static func textKey(_ text: LearnText) -> String { text.key.isEmpty ? text.defaultValue : text.key }

    enum CodingKeys: String, CodingKey {
        case type = "t", midi = "m", at, chord = "c", to = "o", pattern = "p", beatsPerBar = "b", bpm = "v", strummed = "s", question = "q"
        case muted = "mu", accents = "ac"
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        switch try c.decode(String.self, forKey: .type) {
        case "n": self = .note(midi: try c.decode(Int.self, forKey: .midi), at: try c.decodeIfPresent(Fretting.self, forKey: .at))
        case "c": self = .chord(try c.decode(ChordSpec.self, forKey: .chord))
        case "x": self = .change(from: try c.decode(ChordSpec.self, forKey: .chord), to: try c.decode(ChordSpec.self, forKey: .to))
        case "r":
            self = .rhythm(pattern: try c.decode([Double].self, forKey: .pattern), beatsPerBar: try c.decodeIfPresent(Int.self, forKey: .beatsPerBar),
                           bpm: try c.decode(Double.self, forKey: .bpm), chord: try c.decodeIfPresent(ChordSpec.self, forKey: .chord),
                           strummed: try c.decodeIfPresent(Bool.self, forKey: .strummed) ?? false,
                           muted: try c.decodeIfPresent([Double].self, forKey: .muted) ?? [],
                           accents: try c.decodeIfPresent([Double].self, forKey: .accents) ?? [])
        case "q": self = .question(try c.decode(ReviewQuestion.self, forKey: .question))
        default: throw DecodingError.dataCorruptedError(forKey: .type, in: c, debugDescription: "Unknown review item")
        }
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case let .note(midi, at):
            try c.encode("n", forKey: .type); try c.encode(midi, forKey: .midi); try c.encodeIfPresent(at, forKey: .at)
        case let .chord(spec):
            try c.encode("c", forKey: .type); try c.encode(spec, forKey: .chord)
        case let .change(from, to):
            try c.encode("x", forKey: .type); try c.encode(from, forKey: .chord); try c.encode(to, forKey: .to)
        case let .rhythm(pattern, beatsPerBar, bpm, chord, strummed, muted, accents):
            try c.encode("r", forKey: .type); try c.encode(pattern, forKey: .pattern); try c.encodeIfPresent(beatsPerBar, forKey: .beatsPerBar)
            try c.encode(bpm, forKey: .bpm); try c.encodeIfPresent(chord, forKey: .chord); try c.encode(strummed, forKey: .strummed)
            // Only when there are any, so a plain rhythm is stored as it always was.
            if !muted.isEmpty { try c.encode(muted, forKey: .muted) }
            if !accents.isEmpty { try c.encode(accents, forKey: .accents) }
        case let .question(question):
            try c.encode("q", forKey: .type); try c.encode(question, forKey: .question)
        }
    }
}

/// How one item went (0…1): from a lesson's note and chord scores, or from a whole step (`SpacedReview.credits`).
public struct ReviewCredit: Equatable, Sendable {
    public let item: ReviewItem
    public let score: Double
    public init(item: ReviewItem, score: Double) { self.item = item; self.score = score }

    /// A lesson's note and chord scores as credits.
    public static func from(_ scores: [ItemScore]) -> [ReviewCredit] {
        scores.map { ReviewCredit(item: ReviewItem($0.item), score: $0.score) }
    }
}

// MARK: - The schedule

/// Spaced review: an SM-2 schedule, Leitner-style at the start. An item that slips in a lesson (credit under
/// `admitBelow`) comes back the next day; each review passed spaces it further (3 days, a week, then the interval
/// times the item's ease), a slip brings it back the next day and lowers its ease. Days are whole calendar days,
/// so nothing recorded today is due again today. Once an item would wait `maxIntervalDays` or more it has stuck
/// and leaves the deck; a later slip adds it again.
public enum SpacedReview {
    /// Ease of a new item, a little under SM-2's 2.5: these items already slipped once.
    public static let startEase = 2.3
    public static let easeRange = 1.3...2.8
    /// The longest wait; an item passed past it retires.
    public static let maxIntervalDays = 60
    /// The first waits after a new or lapsed item's next-day review, before the ease takes over.
    public static let firstIntervals = [3, 7]
    /// A lesson's credit below this adds an item (the weak-spot line, `LearnProgress.weakBelow`).
    public static let admitBelow = LearnProgress.weakBelow
    /// The deck's size; past it the items closest to sticking leave first.
    public static let capacity = 300
    /// A review session: about three minutes.
    public static let sessionMinutes = 3
    public static let sessionSeconds = 180
    /// At most this many items in a session.
    public static let maxItems = 10

    /// SM-2's 0…5 quality from a 0…1 credit; 3 and up is a pass.
    public static func quality(_ score: Double) -> Int {
        guard score.isFinite else { return 0 }
        if score >= 0.95 { return 5 }
        if score >= 0.8 { return 4 }
        if score >= 0.6 { return 3 }
        if score >= 0.4 { return 2 }
        if score >= 0.2 { return 1 }
        return 0
    }

    /// Roughly how long one item takes in a session, in seconds (a third of a notes step, a chord ringing, four bars
    /// of a change at 60 BPM, two bars of a rhythm, a question).
    public static func seconds(_ kind: ReviewItem.Kind) -> Int {
        switch kind {
        case .note: return 10
        case .chord: return 20
        case .change: return 25
        case .rhythm: return 20
        case .interval: return 12
        case .quiz: return 15
        }
    }

    /// Most items of a kind in one session.
    public static func cap(_ kind: ReviewItem.Kind) -> Int {
        switch kind {
        case .note: return 6
        case .chord: return 3
        case .change, .rhythm: return 2
        case .interval: return 4
        case .quiz: return 3
        }
    }

    /// The explanation that opens a session.
    static let introSeconds = 10

    /// The kinds in turn (a note, a chord, a question, then the next note…), each kind keeping its order.
    static func interleaved(_ cards: [ReviewCard]) -> [ReviewCard] {
        var kinds: [ReviewItem.Kind] = []
        var queues: [ReviewItem.Kind: [ReviewCard]] = [:]
        for card in cards {
            if queues[card.kind] == nil { kinds.append(card.kind) }
            queues[card.kind, default: []].append(card)
        }
        var out: [ReviewCard] = []
        var round = 0
        while out.count < cards.count {
            for kind in kinds {
                let queue = queues[kind, default: []]
                if round < queue.count { out.append(queue[round]) }
            }
            round += 1
        }
        return out
    }

    static func day(_ day: Date, plus days: Int, calendar: Calendar) -> Date {
        calendar.date(byAdding: .day, value: days, to: day) ?? day.addingTimeInterval(Double(days) * 86_400)
    }
}

/// One item on the schedule, in one course.
public struct ReviewCard: Codable, Equatable, Sendable, Identifiable {
    public internal(set) var item: ReviewItem
    public let courseId: String
    /// The start of the day it comes back.
    public internal(set) var due: Date
    /// Days from its last review to `due` (1 for a new or lapsed item).
    public internal(set) var interval: Int
    /// How fast its waits grow (SM-2's easiness), within `SpacedReview.easeRange`.
    public internal(set) var ease: Double
    /// Reviews passed in a row since it was added or last slipped.
    public internal(set) var streak: Int
    /// Times it slipped once on the schedule.
    public internal(set) var lapses: Int
    /// 0…1, the last time it came up (lower is weaker).
    public internal(set) var score: Double
    public internal(set) var seen: Date

    enum CodingKeys: String, CodingKey { case item = "i", courseId = "c", due = "d", interval = "n", ease = "e", streak = "r", lapses = "l", score = "s", seen = "t" }

    public static func cardId(courseId: String, key: String) -> String { courseId + "|" + key }
    public var id: String { Self.cardId(courseId: courseId, key: item.key) }
    public var kind: ReviewItem.Kind { item.kind }

    /// A slipped item joining the deck: back tomorrow.
    init(item: ReviewItem, courseId: String, score: Double, now: Date, calendar: Calendar) {
        let score = Self.clamped(score)
        self.item = item
        self.courseId = courseId
        due = SpacedReview.day(calendar.startOfDay(for: now), plus: 1, calendar: calendar)
        interval = 1
        // A clear miss starts a little harder.
        ease = SpacedReview.quality(score) <= 1 ? SpacedReview.startEase - 0.2 : SpacedReview.startEase
        streak = 0
        lapses = 0
        self.score = score
        seen = now
    }

    /// For tests and seeding: a card with its whole schedule given.
    init(item: ReviewItem, courseId: String, due: Date, interval: Int, ease: Double = SpacedReview.startEase, streak: Int = 0,
         lapses: Int = 0, score: Double, seen: Date) {
        self.item = item; self.courseId = courseId; self.due = due; self.interval = max(1, interval)
        self.ease = min(SpacedReview.easeRange.upperBound, max(SpacedReview.easeRange.lowerBound, ease))
        self.streak = max(0, streak); self.lapses = max(0, lapses); self.score = Self.clamped(score); self.seen = seen
    }

    /// Due today or earlier (any time today counts, so the day's plan holds still).
    public func isDue(now: Date = Date(), calendar: Calendar = .current) -> Bool {
        due < SpacedReview.day(calendar.startOfDay(for: now), plus: 1, calendar: calendar)
    }

    /// Records a review (or a lesson playing it). A slip brings it back tomorrow; a pass on or after its day spaces
    /// it further, one before its day (a lesson that happened to play it) leaves the day as it was. Returns false
    /// when the pass retires it (the next wait would reach `maxIntervalDays`).
    mutating func review(score raw: Double, now: Date, calendar: Calendar) -> Bool {
        let score = Self.clamped(raw)
        let quality = SpacedReview.quality(score)
        let today = calendar.startOfDay(for: now)
        self.score = score
        seen = now
        guard quality >= 3 else {
            streak = 0
            lapses += 1
            interval = 1
            ease = max(SpacedReview.easeRange.lowerBound, ease - 0.2)
            due = SpacedReview.day(today, plus: 1, calendar: calendar)
            return true
        }
        guard isDue(now: now, calendar: calendar) else { return true }
        streak += 1
        let grown = streak <= SpacedReview.firstIntervals.count
            ? SpacedReview.firstIntervals[streak - 1]
            : Int((Double(interval) * ease).rounded())
        // A hard pass (quality 3) waits a little less long.
        let next = quality == 3 ? max(interval + 1, Int((Double(grown) * 0.6).rounded())) : max(interval + 1, grown)
        let lapse = Double(5 - quality)
        ease = min(SpacedReview.easeRange.upperBound, max(SpacedReview.easeRange.lowerBound, ease + 0.1 - lapse * (0.08 + lapse * 0.02)))
        guard next < SpacedReview.maxIntervalDays else { return false }
        interval = next
        due = SpacedReview.day(today, plus: next, calendar: calendar)
        return true
    }

    private static func clamped(_ score: Double) -> Double { score.isFinite ? max(0, min(1, score)) : 0 }
}

/// Every item on the schedule, across courses. Saved with the settings (`UserSettings.spacedReview`); a card that
/// cannot be read (a newer kind) is dropped rather than losing the deck.
public struct ReviewDeck: Codable, Equatable, Sendable {
    public private(set) var cards: [ReviewCard] = []
    /// Per course, items that stuck and left the deck.
    public private(set) var retired: [String: Int] = [:]

    public init() {}

    public init(cards: [ReviewCard], retired: [String: Int] = [:]) {
        self.retired = retired
        var seen = Set<String>()
        self.cards = cards.filter { seen.insert($0.id).inserted }
        trim()
    }

    enum CodingKeys: String, CodingKey { case cards = "k", retired = "x" }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let lossy = (try? c.decodeIfPresent([Lossy<ReviewCard>].self, forKey: .cards)) ?? []
        self.init(cards: lossy.compactMap(\.value), retired: (try? c.decodeIfPresent([String: Int].self, forKey: .retired)) ?? [:])
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(cards, forKey: .cards)
        if !retired.isEmpty { try c.encode(retired, forKey: .retired) }
    }

    public var isEmpty: Bool { cards.isEmpty }

    // MARK: Recording

    /// How items went in a lesson or a review of `courseId`. Items already on the schedule are reviewed (an item
    /// twice in one take counts at its average); a new item joins only if it slipped.
    public mutating func record(_ credits: [ReviewCredit], courseId: String, now: Date = Date(), calendar: Calendar = .current) {
        for credit in Self.merged(credits) {
            let id = ReviewCard.cardId(courseId: courseId, key: credit.item.key)
            if let index = cards.firstIndex(where: { $0.id == id }) {
                var card = cards[index]
                // The latest form of the item (a rhythm's tempo, a chord's fingering) is the one asked next time.
                card.item = credit.item
                if card.review(score: credit.score, now: now, calendar: calendar) {
                    cards[index] = card
                } else {
                    cards.remove(at: index)
                    retired[courseId, default: 0] += 1
                }
            } else if credit.score.isFinite, credit.score < SpacedReview.admitBelow {
                cards.append(ReviewCard(item: credit.item, courseId: courseId, score: credit.score, now: now, calendar: calendar))
            }
        }
        trim()
    }

    /// One credit per item, in first-seen order: the scores averaged, the latest form kept.
    static func merged(_ credits: [ReviewCredit]) -> [ReviewCredit] {
        var order: [String] = []
        var sums: [String: (item: ReviewItem, sum: Double, count: Int)] = [:]
        for credit in credits where credit.score.isFinite {
            let key = credit.item.key
            if let entry = sums[key] {
                sums[key] = (credit.item, entry.sum + credit.score, entry.count + 1)
            } else {
                order.append(key)
                sums[key] = (credit.item, credit.score, 1)
            }
        }
        return order.compactMap { key in sums[key].map { ReviewCredit(item: $0.item, score: $0.sum / Double($0.count)) } }
    }

    /// Past `capacity`, the items closest to sticking (longest wait, best score, oldest) leave first.
    private mutating func trim() {
        guard cards.count > SpacedReview.capacity else { return }
        let strongest = cards.sorted { a, b in
            if a.interval != b.interval { return a.interval > b.interval }
            if a.score != b.score { return a.score > b.score }
            return a.seen < b.seen
        }
        let dropped = Set(strongest.prefix(cards.count - SpacedReview.capacity).map(\.id))
        cards.removeAll { dropped.contains($0.id) }
    }

    // MARK: Reading

    public func cards(in courseId: String) -> [ReviewCard] { cards.filter { $0.courseId == courseId } }

    /// A course's items due today or earlier, the longest overdue first, then the weakest.
    public func due(in courseId: String, now: Date = Date(), calendar: Calendar = .current) -> [ReviewCard] {
        cards(in: courseId).filter { $0.isDue(now: now, calendar: calendar) }.sorted(by: Self.dueOrder)
    }

    public func dueCount(in courseId: String, now: Date = Date(), calendar: Calendar = .current) -> Int {
        cards.reduce(0) { $0 + ($1.courseId == courseId && $1.isDue(now: now, calendar: calendar) ? 1 : 0) }
    }

    /// The first day something in the course comes back (a past day when some are already due); nil for none.
    public func nextDue(in courseId: String) -> Date? { cards(in: courseId).map(\.due).min() }

    /// Items that stuck in a course and left the deck.
    public func retiredCount(in courseId: String) -> Int { retired[courseId] ?? 0 }

    /// The items for one review of about `seconds`: the due ones first (longest overdue and weakest first), then
    /// the weakest of the rest to fill the time. Kinds take turns (a note, a chord, a question, the next note…),
    /// each up to its cap (`SpacedReview.cap`), at most `maxItems`, never an item twice. At least one item when the
    /// course has any.
    public func session(in courseId: String, now: Date = Date(), calendar: Calendar = .current,
                        seconds: Int = SpacedReview.sessionSeconds) -> [ReviewCard] {
        let pool = cards(in: courseId)
        let due = pool.filter { $0.isDue(now: now, calendar: calendar) }.sorted(by: Self.dueOrder)
        let rest = pool.filter { !$0.isDue(now: now, calendar: calendar) }.sorted(by: Self.weakOrder)
        var picked: [ReviewCard] = []
        var taken = Set<String>()
        var counts: [ReviewItem.Kind: Int] = [:]
        var left = seconds - SpacedReview.introSeconds
        for card in SpacedReview.interleaved(due) + SpacedReview.interleaved(rest) {
            guard picked.count < SpacedReview.maxItems else { break }
            let kind = card.kind
            let cost = SpacedReview.seconds(kind)
            guard counts[kind, default: 0] < SpacedReview.cap(kind), cost <= left || picked.isEmpty, !taken.contains(card.id) else { continue }
            taken.insert(card.id)
            picked.append(card)
            counts[kind, default: 0] += 1
            left -= cost
        }
        return picked
    }

    static func dueOrder(_ a: ReviewCard, _ b: ReviewCard) -> Bool {
        if a.due != b.due { return a.due < b.due }
        if a.score != b.score { return a.score < b.score }
        return a.id < b.id
    }

    static func weakOrder(_ a: ReviewCard, _ b: ReviewCard) -> Bool {
        if a.score != b.score { return a.score < b.score }
        if a.ease != b.ease { return a.ease < b.ease }
        if a.due != b.due { return a.due < b.due }
        return a.id < b.id
    }

    // MARK: Weak spots from before

    /// A deck for a player whose weak spots predate spaced review: each comes back the day after it was last seen
    /// (so older ones are due at once), at its last score. `courseOf` names a lesson's course (nil skips it); an item
    /// weak in several lessons of a course is one card, at its weakest.
    public static func seeded(from weakSpots: [String: [WeakSpot]], calendar: Calendar = .current, courseOf: (String) -> String?) -> ReviewDeck {
        var cards: [String: ReviewCard] = [:]
        var order: [String] = []
        for lessonId in weakSpots.keys.sorted() {
            guard let courseId = courseOf(lessonId) else { continue }
            for spot in weakSpots[lessonId] ?? [] {
                let item = ReviewItem(spot.item)
                let id = ReviewCard.cardId(courseId: courseId, key: item.key)
                if let existing = cards[id], existing.score <= spot.score { continue }
                if cards[id] == nil { order.append(id) }
                let due = SpacedReview.day(calendar.startOfDay(for: spot.seen), plus: 1, calendar: calendar)
                cards[id] = ReviewCard(item: item, courseId: courseId, due: due, interval: 1, score: spot.score, seen: spot.seen)
            }
        }
        return ReviewDeck(cards: order.compactMap { cards[$0] })
    }
}

/// Decodes a value, or nil where it can't, so one bad element doesn't fail a whole list.
private struct Lossy<Value: Decodable>: Decodable {
    let value: Value?
    init(from decoder: Decoder) throws { value = try? Value(from: decoder) }
}
