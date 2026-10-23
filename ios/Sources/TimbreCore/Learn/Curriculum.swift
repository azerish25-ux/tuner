import Foundation

/// Lesson text from Learn.strings (English default in the curriculum file).
public struct LearnText: Codable, Equatable, Hashable, Sendable, CustomStringConvertible {
    public let key: String
    public let defaultValue: String
    enum CodingKeys: String, CodingKey { case key = "k"; case defaultValue = "t" }
    public init(key: String = "", _ defaultValue: String) { self.key = key; self.defaultValue = defaultValue }
    public var description: String { defaultValue }
    public var localized: String {
        key.isEmpty ? defaultValue : NSLocalizedString(key, tableName: "Learn", bundle: TimbreLocalization.bundle, value: defaultValue, comment: "")
    }
}

/// The whole course catalogue: courses → units → lessons → steps (curriculum.json, built by tools/curriculum).
public struct Curriculum: Codable, Sendable {
    public let version: Int
    public let courses: [LearnCourse]

    public init(version: Int = 1, courses: [LearnCourse]) { self.version = version; self.courses = courses }

    public static func bundled() throws -> Curriculum {
        guard let url = Bundle.module.url(forResource: "curriculum", withExtension: "json") else { throw CurriculumError.missing }
        return try JSONDecoder().decode(Curriculum.self, from: Data(contentsOf: url))
    }
    public enum CurriculumError: Error { case missing }

    public func course(id: String) -> LearnCourse? { courses.first { $0.id == id } }
    public func lesson(id: String) -> (course: LearnCourse, unit: LearnUnit, lesson: Lesson)? {
        for course in courses { for unit in course.units { if let lesson = unit.lessons.first(where: { $0.id == id }) { return (course, unit, lesson) } } }
        return nil
    }
    public var lessonCount: Int { courses.reduce(0) { $0 + $1.lessons.count } }
}

public struct LearnCourse: Codable, Identifiable, Sendable {
    public let id: String
    public let title: LearnText
    public let subtitle: LearnText
    /// Catalogue instrument the course is played on (e.g. "guitar.acoustic.6"); "voice" for singing; nil for any instrument.
    public let instrument: String?
    /// SF Symbol and accent ("mint", "amber", "violet", "coral", "sky").
    public let symbol: String
    public let accent: String
    public let units: [LearnUnit]
    public var lessons: [Lesson] { units.flatMap(\.lessons) }
}

public struct LearnUnit: Codable, Identifiable, Sendable {
    public let id: String
    public let title: LearnText
    public let summary: LearnText
    public let lessons: [Lesson]
}

public struct Lesson: Codable, Identifiable, Sendable {
    public enum Kind: String, Codable, Sendable { case lesson, song, review, challenge }
    public let id: String
    public let title: LearnText
    public let kind: Kind
    public let minutes: Int
    public let xp: Int
    /// Free lessons are open to everyone; the rest need Timbre Pro.
    public let free: Bool
    public let steps: [LessonStep]
}

/// A position on a fretted instrument: string 1 is the highest-pitched string, fret 0 is open.
public struct Fretting: Codable, Equatable, Hashable, Sendable {
    public let string: Int
    public let fret: Int
    /// Suggested finger (1 index … 4 little), nil for open strings.
    public let finger: Int?
    public init(string: Int, fret: Int, finger: Int? = nil) { self.string = string; self.fret = fret; self.finger = finger }
    enum CodingKeys: String, CodingKey { case string = "s", fret = "f", finger = "g" }
}

/// One note of a play-along: when (in beats from the start), how long, what, and where to play it.
public struct TimedNote: Codable, Equatable, Sendable {
    public let midi: Int
    public let beat: Double
    public let beats: Double
    public let at: Fretting?
    public init(midi: Int, beat: Double, beats: Double, at: Fretting? = nil) { self.midi = midi; self.beat = beat; self.beats = beats; self.at = at }
    enum CodingKeys: String, CodingKey { case midi = "m", beat = "b", beats = "d", at }
}

/// A chord a lesson asks for: root pitch class, quality, and the shape to show.
public struct ChordSpec: Codable, Equatable, Sendable {
    public let name: String
    public let root: Int
    public let quality: String
    /// Fret per string from the lowest string; -1 muted.
    public let frets: [Int]
    public let fingers: [Int]?
    public let baseFret: Int?
    public init(name: String, root: Int, quality: String, frets: [Int], fingers: [Int]? = nil, baseFret: Int? = nil) {
        self.name = name; self.root = root; self.quality = quality; self.frets = frets; self.fingers = fingers; self.baseFret = baseFret
    }
}

/// What an explanation card draws.
public enum LessonVisual: Codable, Equatable, Sendable {
    case none
    case fretboard(strings: Int, dots: [Fretting], frets: Int)
    case chord(ChordSpec)
    case staff(midi: [Int], clef: String)
    case rhythm(pattern: [Double], beatsPerBar: Int)
    case keyboard(midi: [Int])
    case instrument(part: String)

    enum CodingKeys: String, CodingKey { case type, strings, dots, frets, chord, midi, clef, pattern, beatsPerBar, part }
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        switch try c.decode(String.self, forKey: .type) {
        case "fretboard": self = .fretboard(strings: try c.decode(Int.self, forKey: .strings), dots: try c.decode([Fretting].self, forKey: .dots), frets: try c.decodeIfPresent(Int.self, forKey: .frets) ?? 5)
        case "chord": self = .chord(try c.decode(ChordSpec.self, forKey: .chord))
        case "staff": self = .staff(midi: try c.decode([Int].self, forKey: .midi), clef: try c.decodeIfPresent(String.self, forKey: .clef) ?? "treble")
        case "rhythm": self = .rhythm(pattern: try c.decode([Double].self, forKey: .pattern), beatsPerBar: try c.decodeIfPresent(Int.self, forKey: .beatsPerBar) ?? 4)
        case "keyboard": self = .keyboard(midi: try c.decode([Int].self, forKey: .midi))
        case "instrument": self = .instrument(part: try c.decode(String.self, forKey: .part))
        default: self = .none
        }
    }
    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .none: try c.encode("none", forKey: .type)
        case let .fretboard(strings, dots, frets): try c.encode("fretboard", forKey: .type); try c.encode(strings, forKey: .strings); try c.encode(dots, forKey: .dots); try c.encode(frets, forKey: .frets)
        case let .chord(spec): try c.encode("chord", forKey: .type); try c.encode(spec, forKey: .chord)
        case let .staff(midi, clef): try c.encode("staff", forKey: .type); try c.encode(midi, forKey: .midi); try c.encode(clef, forKey: .clef)
        case let .rhythm(pattern, beatsPerBar): try c.encode("rhythm", forKey: .type); try c.encode(pattern, forKey: .pattern); try c.encode(beatsPerBar, forKey: .beatsPerBar)
        case let .keyboard(midi): try c.encode("keyboard", forKey: .type); try c.encode(midi, forKey: .midi)
        case let .instrument(part): try c.encode("instrument", forKey: .type); try c.encode(part, forKey: .part)
        }
    }
}

/// One screen of a lesson.
public enum LessonStep: Codable, Equatable, Sendable {
    /// Read and look: a short idea with a picture.
    case explain(title: LearnText, body: LearnText, visual: LessonVisual)
    /// Play (or sing) these notes one after another, each held in tune, no clock.
    case playNotes(notes: [TimedNote], hint: LearnText?)
    /// Play along with the note highway at a tempo.
    case playAlong(notes: [TimedNote], bpm: Double, beatsPerBar: Int, title: LearnText?)
    /// Play this chord and let it ring.
    case playChord(chord: ChordSpec)
    /// Strum a chord on the beats of a pattern.
    case strum(chord: ChordSpec?, pattern: [Double], bpm: Double, bars: Int)
    /// Tap the screen on the beats of a pattern.
    case tapRhythm(pattern: [Double], bpm: Double, bars: Int)
    /// Listen and pick the answer (intervals, chord qualities, higher/lower, which note).
    case listen(prompt: LearnText, sound: [[Int]], options: [LearnText], answer: Int)
    /// A theory question.
    case quiz(prompt: LearnText, options: [LearnText], answer: Int, why: LearnText?, visual: LessonVisual)

    enum CodingKeys: String, CodingKey { case type, title, body, visual, notes, hint, bpm, beatsPerBar, chord, pattern, bars, prompt, sound, options, answer, why }
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        switch try c.decode(String.self, forKey: .type) {
        case "explain": self = .explain(title: try c.decode(LearnText.self, forKey: .title), body: try c.decode(LearnText.self, forKey: .body), visual: try c.decodeIfPresent(LessonVisual.self, forKey: .visual) ?? .none)
        case "notes": self = .playNotes(notes: try c.decode([TimedNote].self, forKey: .notes), hint: try c.decodeIfPresent(LearnText.self, forKey: .hint))
        case "along": self = .playAlong(notes: try c.decode([TimedNote].self, forKey: .notes), bpm: try c.decode(Double.self, forKey: .bpm), beatsPerBar: try c.decodeIfPresent(Int.self, forKey: .beatsPerBar) ?? 4, title: try c.decodeIfPresent(LearnText.self, forKey: .title))
        case "chord": self = .playChord(chord: try c.decode(ChordSpec.self, forKey: .chord))
        case "strum": self = .strum(chord: try c.decodeIfPresent(ChordSpec.self, forKey: .chord), pattern: try c.decode([Double].self, forKey: .pattern), bpm: try c.decode(Double.self, forKey: .bpm), bars: try c.decodeIfPresent(Int.self, forKey: .bars) ?? 2)
        case "tap": self = .tapRhythm(pattern: try c.decode([Double].self, forKey: .pattern), bpm: try c.decode(Double.self, forKey: .bpm), bars: try c.decodeIfPresent(Int.self, forKey: .bars) ?? 2)
        case "listen": self = .listen(prompt: try c.decode(LearnText.self, forKey: .prompt), sound: try c.decode([[Int]].self, forKey: .sound), options: try c.decode([LearnText].self, forKey: .options), answer: try c.decode(Int.self, forKey: .answer))
        case "quiz": self = .quiz(prompt: try c.decode(LearnText.self, forKey: .prompt), options: try c.decode([LearnText].self, forKey: .options), answer: try c.decode(Int.self, forKey: .answer), why: try c.decodeIfPresent(LearnText.self, forKey: .why), visual: try c.decodeIfPresent(LessonVisual.self, forKey: .visual) ?? .none)
        default: throw DecodingError.dataCorruptedError(forKey: .type, in: c, debugDescription: "Unknown lesson step")
        }
    }
    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case let .explain(title, body, visual): try c.encode("explain", forKey: .type); try c.encode(title, forKey: .title); try c.encode(body, forKey: .body); try c.encode(visual, forKey: .visual)
        case let .playNotes(notes, hint): try c.encode("notes", forKey: .type); try c.encode(notes, forKey: .notes); try c.encodeIfPresent(hint, forKey: .hint)
        case let .playAlong(notes, bpm, beatsPerBar, title): try c.encode("along", forKey: .type); try c.encode(notes, forKey: .notes); try c.encode(bpm, forKey: .bpm); try c.encode(beatsPerBar, forKey: .beatsPerBar); try c.encodeIfPresent(title, forKey: .title)
        case let .playChord(chord): try c.encode("chord", forKey: .type); try c.encode(chord, forKey: .chord)
        case let .strum(chord, pattern, bpm, bars): try c.encode("strum", forKey: .type); try c.encodeIfPresent(chord, forKey: .chord); try c.encode(pattern, forKey: .pattern); try c.encode(bpm, forKey: .bpm); try c.encode(bars, forKey: .bars)
        case let .tapRhythm(pattern, bpm, bars): try c.encode("tap", forKey: .type); try c.encode(pattern, forKey: .pattern); try c.encode(bpm, forKey: .bpm); try c.encode(bars, forKey: .bars)
        case let .listen(prompt, sound, options, answer): try c.encode("listen", forKey: .type); try c.encode(prompt, forKey: .prompt); try c.encode(sound, forKey: .sound); try c.encode(options, forKey: .options); try c.encode(answer, forKey: .answer)
        case let .quiz(prompt, options, answer, why, visual): try c.encode("quiz", forKey: .type); try c.encode(prompt, forKey: .prompt); try c.encode(options, forKey: .options); try c.encode(answer, forKey: .answer); try c.encodeIfPresent(why, forKey: .why); try c.encode(visual, forKey: .visual)
        }
    }

    /// Steps the player has to perform on the instrument (they need the microphone).
    public var usesMicrophone: Bool {
        switch self {
        case .playNotes, .playAlong, .playChord, .strum: return true
        default: return false
        }
    }
}
