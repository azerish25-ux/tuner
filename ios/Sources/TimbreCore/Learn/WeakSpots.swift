import Foundation

// MARK: - What a lesson asked for

/// Something a lesson asks the learner to play: a note (where on the neck, when the course is fretted) or a chord.
public enum PracticeItem: Codable, Hashable, Sendable {
    case note(midi: Int, at: Fretting?)
    case chord(ChordSpec)

    /// A stable text key, for ordering and logs.
    public var key: String {
        switch self {
        case let .note(midi, at): return "n\(midi)" + (at.map { "@\($0.string).\($0.fret)" } ?? "")
        case let .chord(spec): return "c\(spec.symbol)" + spec.frets.map(String.init).joined(separator: ".")
        }
    }

    enum CodingKeys: String, CodingKey { case type = "t", midi = "m", at, chord = "c" }
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        switch try c.decode(String.self, forKey: .type) {
        case "n": self = .note(midi: try c.decode(Int.self, forKey: .midi), at: try c.decodeIfPresent(Fretting.self, forKey: .at))
        case "c": self = .chord(try c.decode(ChordSpec.self, forKey: .chord))
        default: throw DecodingError.dataCorruptedError(forKey: .type, in: c, debugDescription: "Unknown practice item")
        }
    }
    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case let .note(midi, at): try c.encode("n", forKey: .type); try c.encode(midi, forKey: .midi); try c.encodeIfPresent(at, forKey: .at)
        case let .chord(spec): try c.encode("c", forKey: .type); try c.encode(spec, forKey: .chord)
        }
    }
}

/// How one item went in a lesson, 0…1.
public struct ItemScore: Equatable, Sendable {
    public let item: PracticeItem
    public let score: Double
    public init(item: PracticeItem, score: Double) { self.item = item; self.score = score }
}

/// A note or chord that went badly, kept until a lesson or a review sees it played well.
public struct WeakSpot: Codable, Equatable, Sendable {
    public let item: PracticeItem
    /// 0…1, the last time it came up (lower is weaker).
    public let score: Double
    public let seen: Date
    public init(item: PracticeItem, score: Double, seen: Date) {
        self.item = item; self.score = max(0, min(1, score)); self.seen = seen
    }
    enum CodingKeys: String, CodingKey { case item = "i", score = "s", seen = "d" }
}

// MARK: - The review lesson

/// The words a review lesson shows (the app passes them localized).
public struct ReviewText: Sendable {
    public let title: LearnText
    public let intro: LearnText
    public let notesHint: LearnText
    public let alongTitle: LearnText
    public init(title: LearnText, intro: LearnText, notesHint: LearnText, alongTitle: LearnText) {
        self.title = title; self.intro = intro; self.notesHint = notesHint; self.alongTitle = alongTitle
    }
}

/// Builds a short lesson from a course's weak spots, out of the usual step types: a look at what's coming,
/// the weak notes one at a time, the weak chords, a slow play-along through the notes and, on strummed
/// instruments, the chords strummed in a row. Five or six steps when there is enough to review.
/// It plays like any lesson (XP included) and never changes what is unlocked.
public enum WeakSpotReview {
    public static let maxNotes = 6
    public static let maxChords = 3
    public static let bpm = 60.0
    public static let xp = 25

    /// - Parameters:
    ///   - strings: strings on the course instrument (0 without one): the opening card shows the notes on the neck.
    ///   - strums: strummed instruments get a strum or a progression through the weak chords.
    /// - Returns: nil when the course has nothing to review.
    public static func lesson(for course: LearnCourse, progress: LearnProgress, text: ReviewText, strings: Int, strums: Bool) -> Lesson? {
        lesson(courseId: course.id, spots: progress.weakSpots(in: course), text: text, strings: strings, strums: strums)
    }

    static func lesson(courseId: String, spots: [WeakSpot], text: ReviewText, strings: Int, strums: Bool) -> Lesson? {
        var notes: [TimedNote] = []
        var chords: [ChordSpec] = []
        for spot in spots {
            switch spot.item {
            case let .note(midi, at):
                if notes.count < maxNotes, !notes.contains(where: { $0.midi == midi }) { notes.append(TimedNote(midi: midi, beat: 0, beats: 1, at: at)) }
            case let .chord(spec):
                if chords.count < maxChords, !chords.contains(where: { $0.symbol == spec.symbol }) { chords.append(spec) }
            }
        }
        guard !notes.isEmpty || !chords.isEmpty else { return nil }
        // With chords to review as well, the four weakest notes are enough for one sitting.
        if !chords.isEmpty { notes = Array(notes.prefix(4)) }
        // The weakest were chosen; they are played low to high.
        notes.sort { $0.midi < $1.midi }

        var steps: [LessonStep] = [.explain(title: text.title, body: text.intro, visual: introVisual(notes: notes, chords: chords, strings: strings))]
        let firstNotes = Array(notes.prefix(notes.count > 4 ? (notes.count + 1) / 2 : notes.count))
        let moreNotes = Array(notes.dropFirst(firstNotes.count))
        if !firstNotes.isEmpty { steps.append(.playNotes(notes: numbered(firstNotes), hint: text.notesHint)) }
        // Chords between the note steps; with notes to review too, two of them.
        for chord in chords.prefix(notes.isEmpty ? maxChords : 2) { steps.append(.playChord(chord: chord)) }
        if !moreNotes.isEmpty { steps.append(.playNotes(notes: numbered(moreNotes), hint: text.notesHint)) }
        if !notes.isEmpty {
            steps.append(.playAlong(notes: line(notes), bpm: bpm, beatsPerBar: 4, title: text.alongTitle))
            // Notes only: once more from the top down, so the review has some repetition.
            if chords.isEmpty { steps.append(.playNotes(notes: numbered(Array(notes.reversed())), hint: text.notesHint)) }
        }
        if strums, let first = chords.first {
            if chords.count >= 2 {
                let shown = Array(chords.prefix(notes.isEmpty ? maxChords : 2))
                steps.append(.progression(chords: shown, bars: shown.map { _ in 1 }, pattern: [0, 1, 2, 3], bpm: bpm, beatsPerBar: 4))
            } else {
                steps.append(.strum(chord: first, pattern: [0, 1, 2, 3], bpm: bpm, bars: 2, beatsPerBar: 4))
            }
        } else if chords.count == 1 && notes.isEmpty {
            // One chord on a bowed or plucked course: once more after a breath.
            steps.append(.playChord(chord: chords[0]))
        }
        return Lesson(id: LearnProgress.reviewId(courseId: courseId), title: text.title, kind: .review, minutes: 4, xp: xp, free: true, steps: steps)
    }

    /// The notes on the neck when the course has one (and knows where they sit), on a staff otherwise; the
    /// first chord when there are no notes.
    private static func introVisual(notes: [TimedNote], chords: [ChordSpec], strings: Int) -> LessonVisual {
        if !notes.isEmpty {
            let dots = notes.compactMap(\.at)
            if strings > 0, dots.count == notes.count {
                let highest = dots.map(\.fret).max() ?? 0
                return .fretboard(strings: strings, dots: dots, frets: min(12, max(5, highest + 1)), start: 1)
            }
            let average = Double(notes.map(\.midi).reduce(0, +)) / Double(notes.count)
            return .staff(midi: notes.map(\.midi), clef: average < 57 ? "bass" : "treble")
        }
        if let chord = chords.first { return .chord(chord) }
        return LessonVisual.none
    }

    /// Notes one beat apart, in the given order (play-at-your-own-pace steps ignore the beats).
    private static func numbered(_ notes: [TimedNote]) -> [TimedNote] {
        notes.enumerated().map { index, note in TimedNote(midi: note.midi, beat: Double(index), beats: 1, at: note.at) }
    }

    /// Up through the notes and back down, two beats each, so every note gets time to land.
    static func line(_ notes: [TimedNote]) -> [TimedNote] {
        let path = notes + Array(notes.dropLast().reversed())
        return path.enumerated().map { index, note in TimedNote(midi: note.midi, beat: Double(index) * 2, beats: 2, at: note.at) }
    }
}
