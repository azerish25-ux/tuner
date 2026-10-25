import Foundation

// MARK: - Play-along (note highway)

/// Judges a play-along against live pitch readings: each note has a window around its start;
/// the first matching reading in the window scores it by timing and intonation.
public struct PlayAlongJudge: Sendable {
    public enum Grade: String, Codable, Sendable { case perfect, good, ok, miss }
    public struct Judgment: Equatable, Sendable {
        public let index: Int
        public let grade: Grade
        /// Seconds early (negative) or late (positive); nil for a miss.
        public let offset: Double?
    }

    public static let earlySeconds = 0.20
    public static let lateSeconds = 0.32
    public static let perfectSeconds = 0.07
    public static let goodSeconds = 0.15

    public let notes: [TimedNote]
    public let secondsPerBeat: Double
    /// Pipeline delay from string to reading, added to every note time.
    public let latency: Double
    /// Voice lessons accept the right note in any octave.
    public let anyOctave: Bool
    public private(set) var judgments: [Judgment] = []
    /// Perfect and good notes in a row; a late/early note or a miss ends the run.
    public private(set) var combo = 0
    public private(set) var bestCombo = 0
    private var next = 0
    private var lastHitMidi: Int?
    private var rearmed = true

    public init(notes: [TimedNote], bpm: Double, latency: Double = 0.08, anyOctave: Bool = false) {
        self.notes = notes.sorted { $0.beat < $1.beat }
        secondsPerBeat = 60 / max(20, bpm)
        self.latency = latency
        self.anyOctave = anyOctave
    }

    public func time(of index: Int) -> Double { notes[index].beat * secondsPerBeat + latency }
    public var duration: Double { notes.last.map { ($0.beat + $0.beats) * secondsPerBeat } ?? 0 }
    public var isFinished: Bool { next >= notes.count }
    /// The next note waiting to be played.
    public var nextIndex: Int { next }

    /// Feeds one reading (`midi` nil while silent; `onset` when a new attack was heard).
    /// Returns the notes judged by this reading, including misses that just expired.
    public mutating func update(time: Double, midi: Int?, cents: Double?, onset: Bool = false) -> [Judgment] {
        var out: [Judgment] = []
        if onset || midi == nil || midi != lastHitMidi { rearmed = true }
        while next < notes.count, time > self.time(of: next) + Self.lateSeconds {
            out.append(judge(next, .miss, offset: nil))
        }
        guard next < notes.count, let midi else { return out }
        let start = self.time(of: next)
        guard time >= start - Self.earlySeconds else { return out }
        let target = notes[next].midi
        let matches = anyOctave ? (midi - target) % 12 == 0 : midi == target
        guard matches, abs(cents ?? 0) <= 50 else { return out }
        // A repeated pitch needs a fresh attack, not the previous note still ringing.
        if midi == lastHitMidi && !rearmed { return out }
        let offset = time - start
        let inTune = abs(cents ?? 0) <= 20
        let grade: Grade = abs(offset) <= Self.perfectSeconds && inTune ? .perfect : abs(offset) <= Self.goodSeconds ? .good : .ok
        lastHitMidi = midi
        rearmed = false
        out.append(judge(next, grade, offset: offset))
        return out
    }

    private mutating func judge(_ index: Int, _ grade: Grade, offset: Double?) -> Judgment {
        let judgment = Judgment(index: index, grade: grade, offset: offset)
        judgments.append(judgment)
        next = index + 1
        switch grade {
        case .perfect, .good: combo += 1; bestCombo = max(bestCombo, combo)
        case .ok, .miss: combo = 0
        }
        return judgment
    }

    /// 0…1 credit for one judged note: perfect 1, good 0.8, ok 0.5, miss 0.
    public static func credit(_ grade: Grade) -> Double {
        switch grade { case .perfect: return 1; case .good: return 0.8; case .ok: return 0.5; case .miss: return 0 }
    }

    /// 0…1: perfect 1, good 0.8, ok 0.5, miss 0, over all notes.
    public var accuracy: Double {
        guard !notes.isEmpty else { return 1 }
        return judgments.reduce(0.0) { $0 + Self.credit($1.grade) } / Double(notes.count)
    }
}

// MARK: - Tempo ladder

/// A play-along's tempo ladder: a take runs at 75 %, 90 %, 100 % or 110 % of the lesson tempo. It starts at
/// the lesson tempo; the learner can step down for an easier run, and a take of 90 % or better steps it up a
/// rung on its own. The step counts in full once a take at the lesson tempo (or faster) is in; finishing on
/// slower takes only is allowed, but then the lesson tops out at two stars.
public struct TempoLadder: Equatable, Sendable {
    public static let rungs: [Double] = [0.75, 0.9, 1.0, 1.1]
    /// The rung at the lesson tempo.
    public static let lessonRung = 2
    /// A take this good moves the next one up a rung.
    public static let stepUpAccuracy = 0.9
    /// Stars a lesson can reach when its play-along was only finished below the lesson tempo.
    public static let slowStarCap = 2

    /// What the step reports: its score, and a star cap when no take reached the lesson tempo.
    public struct Outcome: Equatable, Sendable {
        public let score: Double
        public let starCap: Int?
    }

    /// The lesson's tempo (100 %).
    public let bpm: Double
    public private(set) var rung: Int
    /// Best accuracy of a take at the lesson tempo or faster.
    public private(set) var bestFull: Double?
    /// Best accuracy of a slower take.
    public private(set) var bestSlow: Double?

    public init(bpm: Double, rung: Int = TempoLadder.lessonRung) {
        self.bpm = bpm
        self.rung = min(Self.rungs.count - 1, max(0, rung))
    }

    public var rate: Double { Self.rungs[rung] }
    /// Percent of the lesson tempo, for display.
    public var percent: Int { Int((rate * 100).rounded()) }
    /// BPM of the current rung.
    public var tempo: Double { tempo(at: rung) }
    public func tempo(at rung: Int) -> Double {
        let index = min(Self.rungs.count - 1, max(0, rung))
        // Never below the slowest click the metronome plays, so the runway, the judge and the click agree.
        return max(Double(MetronomePattern.tempoRange.lowerBound), (bpm * Self.rungs[index]).rounded())
    }
    public var isFullTempo: Bool { rung >= Self.lessonRung }

    public mutating func select(_ rung: Int) { self.rung = min(Self.rungs.count - 1, max(0, rung)) }

    /// Records a finished take at the current rung. Returns true when it stepped the ladder up.
    @discardableResult public mutating func record(accuracy: Double) -> Bool {
        let accuracy = max(0, min(1, accuracy))
        if isFullTempo { bestFull = max(bestFull ?? 0, accuracy) } else { bestSlow = max(bestSlow ?? 0, accuracy) }
        guard accuracy >= Self.stepUpAccuracy, rung < Self.rungs.count - 1 else { return false }
        rung += 1
        return true
    }

    /// Whether a take of `accuracy` at the current rung would become the step's outcome: any take at the
    /// lesson tempo beats every slower one; within a group, the better take counts.
    public func improvesOutcome(_ accuracy: Double) -> Bool {
        if isFullTempo { return accuracy > (bestFull ?? -1) }
        return bestFull == nil && accuracy > (bestSlow ?? -1)
    }

    /// The best take at the lesson tempo or faster; else the best slower take, capped. Nil before any take.
    public var outcome: Outcome? {
        if let bestFull { return Outcome(score: bestFull, starCap: nil) }
        if let bestSlow { return Outcome(score: bestSlow, starCap: Self.slowStarCap) }
        return nil
    }
}

// MARK: - Timing calibration

/// Tap-along latency calibration: the learner taps on a click for a few seconds; the typical gap between a
/// click leaving the engine and the tap is how late this audio route is heard (Bluetooth adds 150–300 ms).
public enum LatencyCalibration {
    /// Clicks before this are a warm-up and don't count.
    public static let warmUpBeats = 2
    public static let minimumTaps = 6
    /// Gaps farther than this from the median are stray taps.
    public static let tolerance = 0.09
    public static let range = 0.0...0.6

    /// The heard delay in seconds from tap times and the first click (same clock), nil when the taps were
    /// too few or too scattered to trust. Each tap pairs with the click it is closest to after the warm-up.
    public static func estimate(taps: [Double], firstClick: Double, secondsPerBeat: Double) -> Double? {
        guard secondsPerBeat > 0.1 else { return nil }
        let gaps: [Double] = taps.compactMap { tap in
            // The click this tap answers: up to most of a beat late, a little early (anticipation).
            let beats = ((tap - firstClick) / secondsPerBeat - 0.75).rounded(.up)
            guard beats >= Double(warmUpBeats) else { return nil }
            return tap - (firstClick + beats * secondsPerBeat)
        }
        guard gaps.count >= minimumTaps else { return nil }
        let middle = median(gaps)
        let kept = gaps.filter { abs($0 - middle) <= tolerance }
        guard kept.count >= minimumTaps, Double(kept.count) >= Double(gaps.count) * 0.6 else { return nil }
        return min(range.upperBound, max(range.lowerBound, median(kept)))
    }

    private static func median(_ values: [Double]) -> Double {
        let sorted = values.sorted()
        let mid = sorted.count / 2
        return sorted.count % 2 == 0 ? (sorted[mid - 1] + sorted[mid]) / 2 : sorted[mid]
    }
}

// MARK: - Notes in order, no clock

/// Play each note in turn and hold it in tune; for first notes, scales at your own pace, singing.
public struct NoteSequenceJudge: Sendable {
    public let notes: [Int]
    public let holdSeconds: Double
    public let toleranceCents: Double
    public let anyOctave: Bool
    public private(set) var index = 0
    public private(set) var wrongNotes = 0
    private var holdStart: Double?
    private var lastWrong: Int?

    public init(notes: [Int], holdSeconds: Double = 0.35, toleranceCents: Double = 30, anyOctave: Bool = false) {
        self.notes = notes; self.holdSeconds = holdSeconds; self.toleranceCents = toleranceCents; self.anyOctave = anyOctave
    }

    public var current: Int? { index < notes.count ? notes[index] : nil }
    public var isFinished: Bool { index >= notes.count }

    public enum Event: Equatable, Sendable { case holding(Double), hit(Int), wrong(Int) }

    public mutating func update(time: Double, midi: Int?, cents: Double?) -> Event? {
        guard let target = current else { return nil }
        guard let midi else { holdStart = nil; return nil }
        let right = anyOctave ? (midi - target) % 12 == 0 : midi == target
        if right, abs(cents ?? 0) <= toleranceCents {
            lastWrong = nil
            if holdStart == nil { holdStart = time }
            let held = time - (holdStart ?? time)
            if held >= holdSeconds { holdStart = nil; index += 1; return .hit(index - 1) }
            return .holding(held / holdSeconds)
        }
        holdStart = nil
        // Count a wrong note once per note heard, not once per frame.
        if !right, midi != lastWrong { lastWrong = midi; wrongNotes += 1; return .wrong(midi) }
        return nil
    }

    public var accuracy: Double { notes.isEmpty ? 1 : Double(notes.count) / Double(notes.count + wrongNotes) }
}

// MARK: - A lesson in progress

public struct LessonRun: Sendable {
    public let lesson: Lesson
    public private(set) var index = 0
    /// Score 0…1 for each step that is scored (explanations are not).
    public private(set) var scores: [Int: Double] = [:]
    public let startedAt: Date
    /// The most stars this run can earn (a play-along finished below the lesson tempo lowers it).
    public private(set) var starCap = 3
    /// How each note and chord the lesson asked for went, summed over every time it came up.
    private var tallies: [PracticeItem: (sum: Double, count: Int)] = [:]

    public init(lesson: Lesson, now: Date = Date()) { self.lesson = lesson; startedAt = now }

    /// Limits the stars this run can earn (never below one).
    public mutating func capStars(_ stars: Int) { starCap = max(1, min(starCap, stars)) }

    /// Notes how one note or chord went (0…1); a lesson's weak spots come from these.
    public mutating func score(_ item: PracticeItem, _ score: Double) {
        guard score.isFinite else { return }
        let entry = tallies[item] ?? (sum: 0, count: 0)
        tallies[item] = (sum: entry.sum + max(0, min(1, score)), count: entry.count + 1)
    }

    /// Each item's average, weakest first.
    public var itemScores: [ItemScore] {
        tallies.map { ItemScore(item: $0.key, score: $0.value.sum / Double(max(1, $0.value.count))) }
            .sorted { $0.score != $1.score ? $0.score < $1.score : $0.item.key < $1.item.key }
    }

    public var step: LessonStep? { index < lesson.steps.count ? lesson.steps[index] : nil }
    public var isFinished: Bool { index >= lesson.steps.count }
    /// 0…1 through the lesson, for the progress bar.
    public var progress: Double { lesson.steps.isEmpty ? 1 : Double(index) / Double(lesson.steps.count) }

    public mutating func complete(score: Double?) {
        guard !isFinished else { return }
        if let score { scores[index] = max(0, min(1, score)) }
        index += 1
    }

    public var accuracy: Double {
        scores.isEmpty ? 1 : scores.values.reduce(0, +) / Double(scores.count)
    }

    // MARK: The final play-along

    /// A take this good (in whole percent, as its card shows it) reads "Great work" on the play-along's card…
    public static let greatTake = 90
    /// …from here it reads "Keep going", and below it "Just warming up" (`AlongStep`'s verdicts).
    public static let warmTake = 50

    /// The most stars a lesson can earn when its final play-along scored `score`: the lesson never reads better
    /// than its test did. Three from a "Great work" take (90 %), two from "Keep going" (50 %), else one.
    public static func starCap(finalTake score: Double) -> Int {
        let percent = Int((max(0, min(1, score)) * 100).rounded())
        return percent >= greatTake ? 3 : percent >= warmTake ? 2 : 1
    }

    /// The lesson's last play-along, its test: that step's index, nil for a lesson without one.
    public var finalAlongIndex: Int? {
        lesson.steps.lastIndex { step in
            if case .playAlong = step { return true }
            return false
        }
    }

    /// The final play-along's score once it is in.
    public var finalTake: Double? { finalAlongIndex.flatMap { scores[$0] } }

    /// Stars from the average of the scored steps (90 % three, 70 % two), never more than the final play-along earns
    /// on its own (`starCap(finalTake:)`) or a slow take allows (`capStars`).
    public func result(now: Date = Date()) -> LessonResult {
        let earned = accuracy >= 0.9 ? 3 : accuracy >= 0.7 ? 2 : 1
        let take = finalTake
        let stars = min(starCap, earned, take.map { Self.starCap(finalTake: $0) } ?? 3)
        let xp = Int((Double(lesson.xp) * (0.6 + 0.2 * Double(stars))).rounded())
        return LessonResult(lessonId: lesson.id, stars: stars, accuracy: accuracy, xp: xp,
                            minutes: max(1, Int(now.timeIntervalSince(startedAt) / 60 + 0.5)), items: itemScores, finalTake: take)
    }
}

public struct LessonResult: Equatable, Sendable {
    public let lessonId: String
    public let stars: Int
    public let accuracy: Double
    public let xp: Int
    public let minutes: Int
    /// How each note and chord went, weakest first (empty for lessons that play none).
    public let items: [ItemScore]
    /// The score of the lesson's final play-along (`LessonRun.finalTake`), which gates its stars; nil without one.
    public let finalTake: Double?
    public init(lessonId: String, stars: Int, accuracy: Double, xp: Int, minutes: Int, items: [ItemScore] = [], finalTake: Double? = nil) {
        self.lessonId = lessonId; self.stars = stars; self.accuracy = accuracy; self.xp = xp; self.minutes = minutes; self.items = items
        self.finalTake = finalTake
    }
}

// MARK: - Progress through the courses

public struct LearnProgress: Codable, Equatable, Sendable {
    /// Best stars per finished lesson.
    public var stars: [String: Int] = [:]
    public var bestAccuracy: [String: Double] = [:]
    public var lastLessonId: String?
    public var lastCourseId: String?
    public var finishedDates: [String: Date] = [:]
    /// Placement from onboarding: per course, the last unit (0-based) the learner starts past.
    /// Those units and the lesson after them are open; nothing in them counts as finished.
    public var placedThrough: [String: Int] = [:]
    /// Per lesson, the notes and chords its latest take found weak (weakest first); a weak-spot review
    /// clears the ones it sees played well.
    public var weakSpots: [String: [WeakSpot]] = [:]
    /// Per course, lessons finished since its last weak-spot review.
    public var sinceReview: [String: Int] = [:]
    public init() {}

    enum CodingKeys: String, CodingKey { case stars, bestAccuracy, lastLessonId, lastCourseId, finishedDates, placedThrough, weakSpots, sinceReview }

    /// Saves from before placement have no `placedThrough`; from before reviews, no weak spots.
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        stars = try c.decodeIfPresent([String: Int].self, forKey: .stars) ?? [:]
        bestAccuracy = try c.decodeIfPresent([String: Double].self, forKey: .bestAccuracy) ?? [:]
        lastLessonId = try c.decodeIfPresent(String.self, forKey: .lastLessonId)
        lastCourseId = try c.decodeIfPresent(String.self, forKey: .lastCourseId)
        finishedDates = try c.decodeIfPresent([String: Date].self, forKey: .finishedDates) ?? [:]
        placedThrough = try c.decodeIfPresent([String: Int].self, forKey: .placedThrough) ?? [:]
        // A malformed weak-spot list is dropped rather than losing the whole Learn progress.
        weakSpots = (try? c.decodeIfPresent([String: [WeakSpot]].self, forKey: .weakSpots)) ?? [:]
        sinceReview = (try? c.decodeIfPresent([String: Int].self, forKey: .sinceReview)) ?? [:]
    }

    public var isValid: Bool {
        let lessons = stars.count <= 5_000 && stars.values.allSatisfy { (1...3).contains($0) } && bestAccuracy.values.allSatisfy { (0...1).contains($0) }
        let placement = placedThrough.count <= 100 && placedThrough.values.allSatisfy { (0...99).contains($0) }
        let weak = weakSpots.count <= 5_000 && weakSpots.values.allSatisfy { spots in
            spots.count <= Self.weakPerLesson && spots.allSatisfy { (0.0...1.0).contains($0.score) }
        }
        let reviews = sinceReview.count <= 100 && sinceReview.values.allSatisfy { (0...Self.sinceReviewLimit).contains($0) }
        return lessons && placement && weak && reviews
    }

    public func isFinished(_ lessonId: String) -> Bool { stars[lessonId] != nil }

    // MARK: Placement

    /// The unit a self-reported level starts past (0-based) in a course, nil to start at lesson 1: the course's own
    /// start for the level (`CoursePlacement`: after the basics, the mid-course chord and song units, the barre and
    /// lead units), never past its last unit.
    public static func placementUnit(level: String, in course: LearnCourse) -> Int? {
        let start = CoursePlacement.startUnit(level: level, courseId: course.id, unitIds: course.units.map(\.id))
        return start > 0 ? start - 1 : nil
    }

    /// A course without its own starts: "novice" skips unit 1, then "intermediate", "advanced" and "pro" start
    /// 40 %, 60 % and 80 % of the way in (never before unit 2, never past the last); nil for beginners, unknown
    /// answers and one-unit courses.
    public static func placementUnit(level: String, unitCount: Int) -> Int? {
        let rung = CoursePlacement.rung(of: level)
        guard unitCount >= 2, rung > 0 else { return nil }
        let shares = [0, 0, 0.4, 0.6, 0.8]
        let start = rung == 1 ? 1 : max(1, Int((Double(unitCount - 1) * shares[min(rung, shares.count - 1)]).rounded()))
        return min(start, unitCount - 1) - 1
    }

    /// Applies (or clears, for beginners) a course placement from the onboarding answer.
    public mutating func place(level: String, in course: LearnCourse) {
        placedThrough[course.id] = Self.placementUnit(level: level, in: course)
    }

    /// Lessons a placement opened: every lesson of the placed units.
    public func placedCount(in course: LearnCourse) -> Int {
        guard let unit = placedThrough[course.id], unit >= 0 else { return 0 }
        return course.units.prefix(unit + 1).reduce(0) { $0 + $1.lessons.count }
    }

    /// Lessons open in order: the first of each course, the placed units and the lesson after them,
    /// then each one after a finished lesson.
    public func isUnlocked(_ lesson: Lesson, in course: LearnCourse) -> Bool {
        // The course's own index: no lesson list is rebuilt or searched per node.
        guard let position = course.position(of: lesson.id) else { return false }
        return position == 0 || (course.isSongbook && lesson.kind == .song) || position <= placedCount(in: course)
            || isFinished(course.lessons[position - 1].id) || isFinished(lesson.id)
    }

    /// The next lesson to play in a course: the first unfinished one after the placement
    /// (then any unfinished one before it), nil when the course is done.
    public func nextLesson(in course: LearnCourse) -> Lesson? {
        let all = course.lessons
        let placed = min(placedCount(in: course), all.count)
        return all[placed...].first { !isFinished($0.id) } ?? all.first { !isFinished($0.id) }
    }

    public func finishedCount(in course: LearnCourse) -> Int { course.lessons.filter { isFinished($0.id) }.count }
    public func stars(in unit: LearnUnit) -> Int { unit.lessons.reduce(0) { $0 + (stars[$1.id] ?? 0) } }

    /// Records a result; returns true when it improved the lesson's stars (first finish included).
    /// A weak-spot review only settles the weak spots it covered: it has no stars, place or unlocks of its own.
    @discardableResult public mutating func record(_ result: LessonResult, courseId: String, now: Date = Date()) -> Bool {
        if Self.isReview(result.lessonId) {
            settleWeakSpots(result.items, now: now)
            sinceReview[courseId] = 0
            return false
        }
        let improved = result.stars > (stars[result.lessonId] ?? 0)
        stars[result.lessonId] = max(result.stars, stars[result.lessonId] ?? 0)
        bestAccuracy[result.lessonId] = max(result.accuracy, bestAccuracy[result.lessonId] ?? 0)
        lastLessonId = result.lessonId
        lastCourseId = courseId
        finishedDates[result.lessonId] = now
        // The latest take of a lesson replaces what it found weak before.
        let weak = result.items.filter { $0.score < Self.weakBelow }.sorted { $0.score < $1.score }.prefix(Self.weakPerLesson)
            .map { WeakSpot(item: $0.item, score: $0.score, seen: now) }
        weakSpots[result.lessonId] = weak.isEmpty ? nil : Array(weak)
        sinceReview[courseId] = min(Self.sinceReviewLimit, (sinceReview[courseId] ?? 0) + 1)
        return improved
    }

    // MARK: Weak spots

    /// An item scoring below this in a lesson is a weak spot; a review clears it from here up.
    public static let weakBelow = 0.8
    public static let weakPerLesson = 8
    /// A review is offered after this many finished lessons (when there is something to review).
    public static let reviewEvery = 3
    static let sinceReviewLimit = 999
    private static let reviewPrefix = "review."

    /// The id of a course's weak-spot review lesson (it is built on the fly, never in the curriculum).
    public static func reviewId(courseId: String) -> String { reviewPrefix + courseId }
    public static func isReview(_ lessonId: String) -> Bool { lessonId.hasPrefix(reviewPrefix) }

    /// A course's weak spots, weakest first; an item weak in several lessons is listed once, at its weakest.
    public func weakSpots(in course: LearnCourse) -> [WeakSpot] {
        var weakest: [PracticeItem: WeakSpot] = [:]
        for lesson in course.lessons {
            for spot in weakSpots[lesson.id] ?? [] where spot.score < (weakest[spot.item]?.score ?? 2) {
                weakest[spot.item] = spot
            }
        }
        return weakest.values.sorted { a, b in
            if a.score != b.score { return a.score < b.score }
            if a.seen != b.seen { return a.seen > b.seen }
            return a.item.key < b.item.key
        }
    }

    /// A weak-spot review is due: a few lessons finished since the last one, and something to review.
    public func reviewDue(in course: LearnCourse) -> Bool {
        (sinceReview[course.id] ?? 0) >= Self.reviewEvery && !weakSpots(in: course).isEmpty
    }

    /// A review's results: items played well leave every lesson's list, the rest keep their new score.
    private mutating func settleWeakSpots(_ items: [ItemScore], now: Date) {
        guard !items.isEmpty else { return }
        let scores = Dictionary(items.map { ($0.item, $0.score) }, uniquingKeysWith: { min($0, $1) })
        for (lessonId, spots) in weakSpots {
            let kept: [WeakSpot] = spots.compactMap { spot in
                guard let score = scores[spot.item] else { return spot }
                return score >= Self.weakBelow ? nil : WeakSpot(item: spot.item, score: score, seen: now)
            }
            weakSpots[lessonId] = kept.isEmpty ? nil : kept.sorted { $0.score < $1.score }
        }
    }
}
