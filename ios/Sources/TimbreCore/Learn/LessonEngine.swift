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
        if grade == .miss { combo = 0 } else { combo += 1; bestCombo = max(bestCombo, combo) }
        return judgment
    }

    /// 0…1: perfect 1, good 0.8, ok 0.5, miss 0, over all notes.
    public var accuracy: Double {
        guard !notes.isEmpty else { return 1 }
        let points = judgments.reduce(0.0) { sum, j in
            switch j.grade { case .perfect: return sum + 1; case .good: return sum + 0.8; case .ok: return sum + 0.5; case .miss: return sum }
        }
        return points / Double(notes.count)
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

    public init(lesson: Lesson, now: Date = Date()) { self.lesson = lesson; startedAt = now }

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

    public func result(now: Date = Date()) -> LessonResult {
        let stars = accuracy >= 0.9 ? 3 : accuracy >= 0.7 ? 2 : 1
        let xp = Int((Double(lesson.xp) * (0.6 + 0.2 * Double(stars))).rounded())
        return LessonResult(lessonId: lesson.id, stars: stars, accuracy: accuracy, xp: xp,
                            minutes: max(1, Int(now.timeIntervalSince(startedAt) / 60 + 0.5)))
    }
}

public struct LessonResult: Equatable, Sendable {
    public let lessonId: String
    public let stars: Int
    public let accuracy: Double
    public let xp: Int
    public let minutes: Int
}

// MARK: - Progress through the courses

public struct LearnProgress: Codable, Equatable, Sendable {
    /// Best stars per finished lesson.
    public var stars: [String: Int] = [:]
    public var bestAccuracy: [String: Double] = [:]
    public var lastLessonId: String?
    public var lastCourseId: String?
    public var finishedDates: [String: Date] = [:]
    public init() {}

    public var isValid: Bool {
        stars.count <= 5_000 && stars.values.allSatisfy { (1...3).contains($0) } && bestAccuracy.values.allSatisfy { (0...1).contains($0) }
    }

    public func isFinished(_ lessonId: String) -> Bool { stars[lessonId] != nil }

    /// Lessons open in order: the first of each course, then each one after a finished lesson.
    public func isUnlocked(_ lesson: Lesson, in course: LearnCourse) -> Bool {
        let all = course.lessons
        guard let position = all.firstIndex(where: { $0.id == lesson.id }) else { return false }
        return position == 0 || isFinished(all[position - 1].id) || isFinished(lesson.id)
    }

    /// The next lesson to play in a course (the first unfinished one), nil when the course is done.
    public func nextLesson(in course: LearnCourse) -> Lesson? { course.lessons.first { !isFinished($0.id) } }

    public func finishedCount(in course: LearnCourse) -> Int { course.lessons.filter { isFinished($0.id) }.count }
    public func stars(in unit: LearnUnit) -> Int { unit.lessons.reduce(0) { $0 + (stars[$1.id] ?? 0) } }

    /// Records a result; returns true when it improved the lesson's stars (first finish included).
    @discardableResult public mutating func record(_ result: LessonResult, courseId: String, now: Date = Date()) -> Bool {
        let improved = result.stars > (stars[result.lessonId] ?? 0)
        stars[result.lessonId] = max(result.stars, stars[result.lessonId] ?? 0)
        bestAccuracy[result.lessonId] = max(result.accuracy, bestAccuracy[result.lessonId] ?? 0)
        lastLessonId = result.lessonId
        lastCourseId = courseId
        finishedDates[result.lessonId] = now
        return improved
    }
}
