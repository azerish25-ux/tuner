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
    /// Where each lesson sits, built once: `lesson(id:)` is a lookup rather than a walk through every course.
    private let locations: [String: Location]

    private struct Location: Sendable {
        let course: Int
        let unit: Int
        let lesson: Int
    }

    enum CodingKeys: String, CodingKey { case version, courses }

    public init(version: Int = 1, courses: [LearnCourse]) {
        self.version = version
        self.courses = courses
        locations = Self.locate(courses)
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.init(version: try c.decode(Int.self, forKey: .version), courses: try c.decode([LearnCourse].self, forKey: .courses))
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(version, forKey: .version)
        try c.encode(courses, forKey: .courses)
    }

    /// The first place each lesson id appears (course, then unit order), as a scan would find it.
    private static func locate(_ courses: [LearnCourse]) -> [String: Location] {
        var result: [String: Location] = [:]
        for (c, course) in courses.enumerated() {
            for (u, unit) in course.units.enumerated() {
                for (l, lesson) in unit.lessons.enumerated() where result[lesson.id] == nil {
                    result[lesson.id] = Location(course: c, unit: u, lesson: l)
                }
            }
        }
        return result
    }

    public static func bundled() throws -> Curriculum {
        guard let url = Bundle.module.url(forResource: "curriculum", withExtension: "json") else { throw CurriculumError.missing }
        return try JSONDecoder().decode(Curriculum.self, from: Data(contentsOf: url))
    }
    public enum CurriculumError: Error { case missing }

    public func course(id: String) -> LearnCourse? { courses.first { $0.id == id } }
    public func lesson(id: String) -> (course: LearnCourse, unit: LearnUnit, lesson: Lesson)? {
        guard let at = locations[id] else { return nil }
        let course = courses[at.course]
        let unit = course.units[at.unit]
        return (course, unit, unit.lessons[at.lesson])
    }
    /// Lessons that teach: the instrument, ear, theory, rhythm and voice courses. A songbook's lessons are its songs,
    /// counted as songs (by title) rather than a second time as lessons.
    public var lessonCount: Int { courses.reduce(0) { $0 + ($1.isSongbook ? 0 : $1.lessons.count) } }
    /// The courses that teach (songbooks aside), as `lessonCount` counts them.
    public var courseCount: Int { courses.filter { !$0.isSongbook }.count }
    /// How many different songs the catalogue holds: song lessons counted by title, so a song taught in two lessons or
    /// arranged for two instruments counts once. The paywall's proof line and the store listing say this number.
    public var distinctTuneCount: Int {
        Set(courses.flatMap(\.lessons).filter { $0.kind == .song }.map(\.title.defaultValue)).count
    }
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
    /// Every lesson in path order, built once with the course (the Learn path, Songs and the widgets read it for
    /// each of their nodes).
    public let lessons: [Lesson]
    /// Each lesson's place in `lessons` (its first, should an id repeat).
    private let positions: [String: Int]
    /// A song collection (Originals, Standards, Songs): songs and unit challenges only, no teaching lessons. Its songs
    /// are a library to pick from, so each one is open (Pro still gates the paid ones); its challenges keep the path.
    public let isSongbook: Bool

    enum CodingKeys: String, CodingKey { case id, title, subtitle, instrument, symbol, accent, units }

    public init(id: String, title: LearnText, subtitle: LearnText, instrument: String?, symbol: String, accent: String, units: [LearnUnit]) {
        self.id = id; self.title = title; self.subtitle = subtitle; self.instrument = instrument
        self.symbol = symbol; self.accent = accent; self.units = units
        let lessons = units.flatMap(\.lessons)
        self.lessons = lessons
        var positions: [String: Int] = [:]
        for (index, lesson) in lessons.enumerated() where positions[lesson.id] == nil { positions[lesson.id] = index }
        self.positions = positions
        isSongbook = lessons.contains { $0.kind == .song } && !lessons.contains { $0.kind == .lesson }
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.init(id: try c.decode(String.self, forKey: .id),
                  title: try c.decode(LearnText.self, forKey: .title),
                  subtitle: try c.decode(LearnText.self, forKey: .subtitle),
                  instrument: try c.decodeIfPresent(String.self, forKey: .instrument),
                  symbol: try c.decode(String.self, forKey: .symbol),
                  accent: try c.decode(String.self, forKey: .accent),
                  units: try c.decode([LearnUnit].self, forKey: .units))
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(title, forKey: .title)
        try c.encode(subtitle, forKey: .subtitle)
        try c.encodeIfPresent(instrument, forKey: .instrument)
        try c.encode(symbol, forKey: .symbol)
        try c.encode(accent, forKey: .accent)
        try c.encode(units, forKey: .units)
    }

    /// Where a lesson sits in `lessons` (0 first); nil when it is not in this course.
    public func position(of lessonId: String) -> Int? { positions[lessonId] }
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
    /// A song's whole arrangement (sections, chord chart, lyric credit); its last step is then the whole song with its
    /// words (`songTake`). Nil for every other lesson.
    public var arrangement: SongArrangement?
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

/// One note of a play-along: when (in beats from the start), how long, what, and where to play it, and in a song with
/// words, the syllable sung on it (`LyricSheet` reads them as lines).
public struct TimedNote: Codable, Equatable, Sendable {
    public let midi: Int
    public let beat: Double
    public let beats: Double
    public let at: Fretting?
    /// The syllable sung on this note: ending in "-" when it joins the next into a word ("Twin-", "kle,"), or
    /// `TimedNote.held` for a note that holds the syllable before it. Nil for a note outside the words.
    public let lyric: String?
    /// The syllable starts a new lyric line.
    public let startsLine: Bool

    /// The `lyric` of a note that holds the syllable before it (a melisma).
    public static let held = "_"

    public init(midi: Int, beat: Double, beats: Double, at: Fretting? = nil, lyric: String? = nil, startsLine: Bool = false) {
        self.midi = midi; self.beat = beat; self.beats = beats; self.at = at; self.lyric = lyric; self.startsLine = startsLine
    }

    /// The syllable as read ("Twin", "kle,"), without its joining hyphen; nil for a held or wordless note.
    public var syllable: String? {
        guard let lyric, lyric != Self.held else { return nil }
        return lyric.hasSuffix("-") ? String(lyric.dropLast()) : lyric
    }
    /// The syllable runs on into the next one with no space ("Twin-" + "kle").
    public var joinsNextSyllable: Bool { lyric.map { $0 != Self.held && $0.hasSuffix("-") } ?? false }
    /// The note carries on the syllable before it.
    public var holdsSyllable: Bool { lyric == Self.held }

    enum CodingKeys: String, CodingKey { case midi = "m", beat = "b", beats = "d", at, lyric = "y", startsLine = "yl" }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        midi = try c.decode(Int.self, forKey: .midi)
        beat = try c.decode(Double.self, forKey: .beat)
        beats = try c.decode(Double.self, forKey: .beats)
        at = try c.decodeIfPresent(Fretting.self, forKey: .at)
        lyric = try c.decodeIfPresent(String.self, forKey: .lyric)
        startsLine = (try c.decodeIfPresent(Int.self, forKey: .startsLine) ?? 0) != 0
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(midi, forKey: .midi)
        try c.encode(beat, forKey: .beat)
        try c.encode(beats, forKey: .beats)
        try c.encodeIfPresent(at, forKey: .at)
        try c.encodeIfPresent(lyric, forKey: .lyric)
        if startsLine { try c.encode(1, forKey: .startsLine) }
    }
}

/// A chord a lesson asks for: root pitch class, quality, and the shape to show.
public struct ChordSpec: Codable, Equatable, Hashable, Sendable {
    /// The chord symbol as the curriculum writes it, in letters ("Bm", "F#m").
    public let symbol: String
    public let root: Int
    public let quality: String
    /// Fret per string from the lowest string; -1 muted.
    public let frets: [Int]
    public let fingers: [Int]?
    public let baseFret: Int?
    /// The fret a capo sits at, when the shape is played behind one ("a G shape on capo 2 reads A"). `frets` are then
    /// still absolute: the capo's own fret shows on the strings it stops, and fingers count from the capo.
    public let capo: Int?
    /// The symbol as the player reads it, in the active note-naming system (`NoteNames.active`): "Hm" and "H7"
    /// in German, so diagrams agree with the lesson text.
    public var name: String { NoteNames.chordSymbol(symbol) }
    enum CodingKeys: String, CodingKey { case symbol = "name", root, quality, frets, fingers, baseFret, capo }
    public init(name: String, root: Int, quality: String, frets: [Int], fingers: [Int]? = nil, baseFret: Int? = nil, capo: Int? = nil) {
        self.symbol = name; self.root = root; self.quality = quality; self.frets = frets; self.fingers = fingers; self.baseFret = baseFret
        self.capo = capo
    }
}

/// What an explanation card draws.
public enum LessonVisual: Codable, Equatable, Sendable {
    case none
    /// `start`: the fret at the left edge (1 shows the nut).
    case fretboard(strings: Int, dots: [Fretting], frets: Int, start: Int)
    case chord(ChordSpec)
    case staff(midi: [Int], clef: String)
    case rhythm(pattern: [Double], beatsPerBar: Int)
    case keyboard(midi: [Int])
    case instrument(part: String)
    /// A short looping clip (or a set of photos) of a hand doing what the words describe: a bow hold, a pick grip,
    /// palm muting. `name` is the bundled resource's name without its extension.
    case clip(name: String)

    enum CodingKeys: String, CodingKey { case type, strings, dots, frets, start, chord, midi, clef, pattern, beatsPerBar, part, name }
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        switch try c.decode(String.self, forKey: .type) {
        case "fretboard": self = .fretboard(strings: try c.decode(Int.self, forKey: .strings), dots: try c.decode([Fretting].self, forKey: .dots), frets: try c.decodeIfPresent(Int.self, forKey: .frets) ?? 5, start: try c.decodeIfPresent(Int.self, forKey: .start) ?? 1)
        case "chord": self = .chord(try c.decode(ChordSpec.self, forKey: .chord))
        case "staff": self = .staff(midi: try c.decode([Int].self, forKey: .midi), clef: try c.decodeIfPresent(String.self, forKey: .clef) ?? "treble")
        case "rhythm": self = .rhythm(pattern: try c.decode([Double].self, forKey: .pattern), beatsPerBar: try c.decodeIfPresent(Int.self, forKey: .beatsPerBar) ?? 4)
        case "keyboard": self = .keyboard(midi: try c.decode([Int].self, forKey: .midi))
        case "instrument": self = .instrument(part: try c.decode(String.self, forKey: .part))
        case "clip": self = .clip(name: try c.decode(String.self, forKey: .name))
        default: self = .none
        }
    }
    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .none: try c.encode("none", forKey: .type)
        case let .fretboard(strings, dots, frets, start): try c.encode("fretboard", forKey: .type); try c.encode(strings, forKey: .strings); try c.encode(dots, forKey: .dots); try c.encode(frets, forKey: .frets); try c.encode(start, forKey: .start)
        case let .chord(spec): try c.encode("chord", forKey: .type); try c.encode(spec, forKey: .chord)
        case let .staff(midi, clef): try c.encode("staff", forKey: .type); try c.encode(midi, forKey: .midi); try c.encode(clef, forKey: .clef)
        case let .rhythm(pattern, beatsPerBar): try c.encode("rhythm", forKey: .type); try c.encode(pattern, forKey: .pattern); try c.encode(beatsPerBar, forKey: .beatsPerBar)
        case let .keyboard(midi): try c.encode("keyboard", forKey: .type); try c.encode(midi, forKey: .midi)
        case let .instrument(part): try c.encode("instrument", forKey: .type); try c.encode(part, forKey: .part)
        case let .clip(name): try c.encode("clip", forKey: .type); try c.encode(name, forKey: .name)
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
    /// Strum a chord on the beats of a pattern (beatsPerBar nil: 4, or longer if the pattern needs it).
    /// `muted` and `accents` are beats of the pattern, counted within the bar as `pattern` is: a muted stroke is a
    /// chop or chunk (no chord should ring), an accented one is played harder. Both empty for plain strokes.
    case strum(chord: ChordSpec?, pattern: [Double], bpm: Double, bars: Int, beatsPerBar: Int?,
               muted: [Double] = [], accents: [Double] = [])
    /// Tap the screen on the beats of a pattern.
    case tapRhythm(pattern: [Double], bpm: Double, bars: Int, beatsPerBar: Int?)
    /// Strum a chord progression in time: each chord for its number of bars, the pattern in every bar, with its muted
    /// and accented beats (as `strum`'s) in every bar too.
    case progression(chords: [ChordSpec], bars: [Int], pattern: [Double], bpm: Double, beatsPerBar: Int?,
                     muted: [Double] = [], accents: [Double] = [])
    /// Listen and pick the answer (intervals, chord qualities, higher/lower, which note).
    case listen(prompt: LearnText, sound: [[Int]], options: [LearnText], answer: Int)
    /// A theory question.
    case quiz(prompt: LearnText, options: [LearnText], answer: Int, why: LearnText?, visual: LessonVisual)

    enum CodingKeys: String, CodingKey {
        case type, title, body, visual, notes, hint, bpm, beatsPerBar, chord, chords, pattern, bars, prompt, sound, options, answer, why
        case muted, accents
    }
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        // Muted and accented beats are optional: a step without them (every curriculum written before them) has none.
        let muted = try c.decodeIfPresent([Double].self, forKey: .muted) ?? []
        let accents = try c.decodeIfPresent([Double].self, forKey: .accents) ?? []
        switch try c.decode(String.self, forKey: .type) {
        case "explain": self = .explain(title: try c.decode(LearnText.self, forKey: .title), body: try c.decode(LearnText.self, forKey: .body), visual: try c.decodeIfPresent(LessonVisual.self, forKey: .visual) ?? .none)
        case "notes": self = .playNotes(notes: try c.decode([TimedNote].self, forKey: .notes), hint: try c.decodeIfPresent(LearnText.self, forKey: .hint))
        case "along": self = .playAlong(notes: try c.decode([TimedNote].self, forKey: .notes), bpm: try c.decode(Double.self, forKey: .bpm), beatsPerBar: try c.decodeIfPresent(Int.self, forKey: .beatsPerBar) ?? 4, title: try c.decodeIfPresent(LearnText.self, forKey: .title))
        case "chord": self = .playChord(chord: try c.decode(ChordSpec.self, forKey: .chord))
        case "strum": self = .strum(chord: try c.decodeIfPresent(ChordSpec.self, forKey: .chord), pattern: try c.decode([Double].self, forKey: .pattern), bpm: try c.decode(Double.self, forKey: .bpm), bars: try c.decodeIfPresent(Int.self, forKey: .bars) ?? 2, beatsPerBar: try c.decodeIfPresent(Int.self, forKey: .beatsPerBar), muted: muted, accents: accents)
        case "tap": self = .tapRhythm(pattern: try c.decode([Double].self, forKey: .pattern), bpm: try c.decode(Double.self, forKey: .bpm), bars: try c.decodeIfPresent(Int.self, forKey: .bars) ?? 2, beatsPerBar: try c.decodeIfPresent(Int.self, forKey: .beatsPerBar))
        case "progression": self = .progression(chords: try c.decode([ChordSpec].self, forKey: .chords), bars: try c.decode([Int].self, forKey: .bars), pattern: try c.decode([Double].self, forKey: .pattern), bpm: try c.decode(Double.self, forKey: .bpm), beatsPerBar: try c.decodeIfPresent(Int.self, forKey: .beatsPerBar), muted: muted, accents: accents)
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
        case let .strum(chord, pattern, bpm, bars, beatsPerBar, muted, accents): try c.encode("strum", forKey: .type); try c.encodeIfPresent(chord, forKey: .chord); try c.encode(pattern, forKey: .pattern); try c.encode(bpm, forKey: .bpm); try c.encode(bars, forKey: .bars); try c.encodeIfPresent(beatsPerBar, forKey: .beatsPerBar); try Self.encodeMarks(muted: muted, accents: accents, into: &c)
        case let .tapRhythm(pattern, bpm, bars, beatsPerBar): try c.encode("tap", forKey: .type); try c.encode(pattern, forKey: .pattern); try c.encode(bpm, forKey: .bpm); try c.encode(bars, forKey: .bars); try c.encodeIfPresent(beatsPerBar, forKey: .beatsPerBar)
        case let .progression(chords, bars, pattern, bpm, beatsPerBar, muted, accents): try c.encode("progression", forKey: .type); try c.encode(chords, forKey: .chords); try c.encode(bars, forKey: .bars); try c.encode(pattern, forKey: .pattern); try c.encode(bpm, forKey: .bpm); try c.encodeIfPresent(beatsPerBar, forKey: .beatsPerBar); try Self.encodeMarks(muted: muted, accents: accents, into: &c)
        case let .listen(prompt, sound, options, answer): try c.encode("listen", forKey: .type); try c.encode(prompt, forKey: .prompt); try c.encode(sound, forKey: .sound); try c.encode(options, forKey: .options); try c.encode(answer, forKey: .answer)
        case let .quiz(prompt, options, answer, why, visual): try c.encode("quiz", forKey: .type); try c.encode(prompt, forKey: .prompt); try c.encode(options, forKey: .options); try c.encode(answer, forKey: .answer); try c.encodeIfPresent(why, forKey: .why); try c.encode(visual, forKey: .visual)
        }
    }

    /// Muted and accented beats are written only when there are some, so a plain step encodes as it always has.
    private static func encodeMarks(muted: [Double], accents: [Double], into c: inout KeyedEncodingContainer<CodingKeys>) throws {
        if !muted.isEmpty { try c.encode(muted, forKey: .muted) }
        if !accents.isEmpty { try c.encode(accents, forKey: .accents) }
    }

    /// The beats of a strum or progression step's pattern played muted (chops, chunks); empty for every other step.
    public var muted: [Double] {
        switch self {
        case let .strum(_, _, _, _, _, muted, _), let .progression(_, _, _, _, _, muted, _): return muted
        default: return []
        }
    }

    /// The beats of a strum or progression step's pattern played accented; empty for every other step.
    public var accents: [Double] {
        switch self {
        case let .strum(_, _, _, _, _, _, accents), let .progression(_, _, _, _, _, _, accents): return accents
        default: return []
        }
    }

    /// Steps the player has to perform on the instrument (they need the microphone).
    public var usesMicrophone: Bool {
        switch self {
        case .playNotes, .playAlong, .playChord, .strum, .progression: return true
        default: return false
        }
    }
}
