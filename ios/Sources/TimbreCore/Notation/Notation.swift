import Foundation

// Engraving a melody as standard notation: how a pitch is spelled in a key, where it sits on a clef, how a meter is
// counted and which written note values exist. The score itself (bars, rests, ties, beams) is `NotationScore`; line
// breaking is `NotationLayout`. All pure, so the song sheet and the note steps draw from the same rules and the tests
// can check them without a screen.

// MARK: - Pitch spelling

/// A pitch as written: a letter (0 is C … 6 is B), its alteration in semitones (−2 … 2) and its octave (4 holds middle
/// C). B♯3 and C4 sound alike but sit on different lines of the staff.
public struct SpelledPitch: Equatable, Hashable, Sendable {
    /// The natural notes' pitch classes, C to B.
    public static let naturals = [0, 2, 4, 5, 7, 9, 11]

    public let letter: Int
    public let alter: Int
    public let octave: Int

    public init(letter: Int, alter: Int, octave: Int) {
        self.letter = ((letter % 7) + 7) % 7
        self.alter = alter
        self.octave = octave
    }

    /// `midi` written on `letter` with `alter` (which must spell it), at the octave that makes it sound right.
    public init(midi: Int, letter: Int, alter: Int) {
        let clamped = ((letter % 7) + 7) % 7
        self.letter = clamped
        self.alter = alter
        let base = midi - Self.naturals[clamped] - alter
        octave = Int((Double(base) / 12).rounded(.down)) - 1
    }

    /// Diatonic steps from C0: each line and each space of the staff is one.
    public var step: Int { octave * 7 + letter }

    /// The pitch it sounds.
    public var midi: Int { (octave + 1) * 12 + Self.naturals[letter] + alter }
}

// MARK: - Key signature

/// The sharps or flats at the head of each line, and how the notes of a melody are spelled under them.
public struct KeySignature: Equatable, Hashable, Sendable {
    /// Sharps (positive) or flats (negative), −7 … 7.
    public let fifths: Int
    /// The key's tonic (a pitch class) when known: a minor key writes its raised sixth and seventh as raised notes.
    public let tonic: Int?
    public let minor: Bool

    /// The order sharps are written in (F C G D A E B) and flats (B E A D G C F), as letters.
    public static let sharpOrder = [3, 0, 4, 1, 5, 2, 6]
    public static let flatOrder = [6, 2, 5, 1, 4, 0, 3]

    /// No sharps or flats (C major, A minor without its tonic known).
    public static let empty = KeySignature(fifths: 0)

    public init(fifths: Int) {
        self.fifths = max(-7, min(7, fifths))
        tonic = nil
        minor = false
    }

    /// The signature of a key, written the way that needs fewer accidentals (D♭ major rather than C♯, B major rather
    /// than C♭). Where both need six, the app's usual names decide, as the Chords and Scales tools spell them: F♯ major
    /// and E♭ minor.
    public init(tonic: Int, minor: Bool) {
        let pitchClass = ((tonic % 12) + 12) % 12
        let major = minor ? (pitchClass + 3) % 12 : pitchClass
        let table = [0, -5, 2, -3, 4, -1, 6, 1, -4, 3, -2, 5]
        var count = table[major]
        if major == 6 && minor { count = -6 }
        fifths = count
        self.tonic = pitchClass
        self.minor = minor
    }

    /// The letters the signature alters, in the order they are written.
    public var letters: [Int] {
        fifths >= 0 ? Array(Self.sharpOrder.prefix(fifths)) : Array(Self.flatOrder.prefix(-fifths))
    }

    /// What the signature does to `letter`: 1 a sharp, −1 a flat, 0 nothing.
    public func alter(ofLetter letter: Int) -> Int {
        guard letters.contains(letter) else { return 0 }
        return fifths > 0 ? 1 : -1
    }

    /// `midi` spelled as a note of the key (its own letter), nil for a note outside it.
    public func diatonic(_ midi: Int) -> SpelledPitch? {
        let pitchClass = ((midi % 12) + 12) % 12
        for letter in 0..<7 {
            let shift = alter(ofLetter: letter)
            if ((SpelledPitch.naturals[letter] + shift) % 12 + 12) % 12 == pitchClass {
                return SpelledPitch(midi: midi, letter: letter, alter: shift)
            }
        }
        return nil
    }

    /// `midi` spelled in the key, between the note written before it (`previous`) and the next different one
    /// (`next`). A note of the key takes its own letter. A note outside it is a neighbouring note of the key raised or
    /// lowered: a minor key's raised sixth and seventh are raised (G♯ in A minor, E♯ in F♯ minor); otherwise the
    /// spelling with the plainer sign wins (F♮ in G major, never E♯; a double sharp or flat only when nothing else
    /// spells it), then the one that reads as the step it is from its neighbours (E F♯ E, G A♭ G: never a diminished
    /// third or a chromatic unison), then the way the melody moves (up through G♯, down through A♭), then the side of
    /// the key (sharps in a sharp key), then the app's usual names (F♯, C♯ … but E♭, A♭, B♭, D♭).
    public func spell(_ midi: Int, after previous: SpelledPitch? = nil, before next: Int? = nil) -> SpelledPitch {
        if let own = diatonic(midi) { return own }
        let pitchClass = ((midi % 12) + 12) % 12
        var raised: (letter: Int, alter: Int)?
        var lowered: (letter: Int, alter: Int)?
        for letter in 0..<7 {
            let shift = alter(ofLetter: letter)
            let natural = SpelledPitch.naturals[letter]
            if ((natural + shift + 1) % 12 + 12) % 12 == pitchClass { raised = (letter: letter, alter: shift + 1) }
            if ((natural + shift - 1) % 12 + 12) % 12 == pitchClass { lowered = (letter: letter, alter: shift - 1) }
        }
        guard let up = raised else {
            let down = lowered ?? (letter: 0, alter: pitchClass)
            return SpelledPitch(midi: midi, letter: down.letter, alter: down.alter)
        }
        let sharpened = SpelledPitch(midi: midi, letter: up.letter, alter: up.alter)
        guard let down = lowered else { return sharpened }
        let flattened = SpelledPitch(midi: midi, letter: down.letter, alter: down.alter)
        if minor, let tonic, pitchClass == (tonic + 11) % 12 || pitchClass == (tonic + 9) % 12 { return sharpened }
        let upCost = abs(up.alter) >= 2 ? 10 : abs(up.alter)
        let downCost = abs(down.alter) >= 2 ? 10 : abs(down.alter)
        if upCost != downCost { return upCost < downCost ? sharpened : flattened }
        let following = next.flatMap { diatonic($0) }
        let upMisfits = Self.misfits(sharpened, previous: previous, next: following)
        let downMisfits = Self.misfits(flattened, previous: previous, next: following)
        if upMisfits != downMisfits { return upMisfits < downMisfits ? sharpened : flattened }
        var direction = 0
        if let next, next != midi {
            direction = next > midi ? 1 : -1
        } else if let previous, previous.midi != midi {
            direction = midi > previous.midi ? 1 : -1
        }
        let wantsRaised: Bool
        if direction != 0 {
            wantsRaised = direction > 0
        } else if fifths != 0 {
            wantsRaised = fifths > 0
        } else {
            wantsRaised = ![1, 3, 8, 10].contains(pitchClass)
        }
        return wantsRaised ? sharpened : flattened
    }

    /// How many of a note's neighbours it reads wrongly against.
    private static func misfits(_ pitch: SpelledPitch, previous: SpelledPitch?, next: SpelledPitch?) -> Int {
        var count = 0
        if let previous, !SpelledPitch.readsAsSounded(previous, pitch) { count += 1 }
        if let next, !SpelledPitch.readsAsSounded(pitch, next) { count += 1 }
        return count
    }
}

extension SpelledPitch {
    /// Whether two written notes read as the interval they sound: a second for one or two semitones, a third for three
    /// or four, a fourth or fifth for six, and so on (a chromatic unison or a diminished third reads wrongly).
    public static func readsAsSounded(_ a: SpelledPitch, _ b: SpelledPitch) -> Bool {
        let semitones = abs(b.midi - a.midi)
        let steps = abs(b.step - a.step)
        let within = semitones % 12
        let expected = [0, 1, 1, 2, 2, 3, 3, 4, 5, 5, 6, 6][within] + (semitones / 12) * 7
        if within == 6 { return steps == expected || steps == expected + 1 }
        return steps == expected
    }
}

// MARK: - Clef

/// The clef a part is written in. Guitar and banjo read treble clef an octave above where they sound, and bass guitar
/// bass clef an octave above (`octaveDown`: the clef carries a small 8 underneath).
public struct Clef: Equatable, Hashable, Sendable {
    public enum Sign: String, Sendable {
        case treble, bass
    }

    public let sign: Sign
    public let octaveDown: Bool

    public init(_ sign: Sign, octaveDown: Bool = false) {
        self.sign = sign
        self.octaveDown = octaveDown
    }

    public static let treble = Clef(.treble)
    public static let bass = Clef(.bass)

    /// The step on the bottom line: E4 in treble clef, G2 in bass clef.
    public var bottomStep: Int { sign == .treble ? 30 : 18 }

    /// Where `pitch` sits, in half spaces above the bottom line: 0 the bottom line, 8 the top one, −2 the first ledger
    /// line below, 10 the first above.
    public func position(of pitch: SpelledPitch) -> Int { pitch.step - bottomStep }

    /// The note a sounding pitch is written as.
    public func written(_ midi: Int) -> Int { octaveDown ? midi + 12 : midi }

    /// Where a signature's sharps or flats sit, in the order they are written.
    public func positions(of key: KeySignature) -> [Int] {
        let treble = key.fifths >= 0 ? [8, 5, 9, 6, 3, 7, 4] : [4, 7, 3, 6, 2, 5, 1]
        let shift = sign == .treble ? 0 : -2
        return treble.prefix(min(7, abs(key.fifths))).map { $0 + shift }
    }

    /// The clef a course's instrument reads (`LearnCourse.instrument`): treble an octave up for guitar and banjo,
    /// bass an octave up for bass guitar, bass clef for cello, treble for violin, mandolin and ukulele; a voice or any
    /// instrument by the notes, bass clef for a low part.
    public static func reading(instrument: String?, midis: [Int]) -> Clef {
        let id = instrument ?? ""
        if id.hasPrefix("guitar") || id.hasPrefix("banjo") { return Clef(.treble, octaveDown: true) }
        if id.hasPrefix("bass") { return Clef(.bass, octaveDown: true) }
        if id.hasPrefix("cello") { return .bass }
        if id.hasPrefix("violin") || id.hasPrefix("mandolin") || id.hasPrefix("ukulele") { return .treble }
        guard !midis.isEmpty else { return .treble }
        let mean = Double(midis.reduce(0, +)) / Double(midis.count)
        return mean < 57 ? .bass : .treble
    }
}

// MARK: - Meter and note values

/// A bar as the curriculum counts it, in ticks of a sixteenth. Six, nine or twelve beats are eighths in compound time
/// (6/8: two dotted-quarter pulses); fewer are quarters (2/4, 3/4, 4/4).
public struct NotationMeter: Equatable, Hashable, Sendable {
    /// Beats in a bar, as `TimedNote.beat` counts them.
    public let beats: Int

    public init(beatsPerBar: Int) { beats = max(1, beatsPerBar) }

    public var compound: Bool { beats >= 6 && beats % 3 == 0 }
    /// The time signature's lower number.
    public var unit: Int { compound ? 8 : 4 }
    /// Sixteenths in a beat.
    public var ticksPerBeat: Int { compound ? 2 : 4 }
    public var barTicks: Int { beats * ticksPerBeat }
    /// Sixteenths in the felt pulse: a quarter, or a dotted quarter in compound time.
    public var pulseTicks: Int { compound ? 6 : 4 }

    /// Ticks from the start of the song for `beat`.
    public func ticks(_ beat: Double) -> Int { Int((beat * Double(ticksPerBeat)).rounded()) }
}

/// A written note value: whole (level 0) to sixteenth (level 4), plain or dotted, in ticks of a sixteenth.
public struct NoteDuration: Equatable, Hashable, Sendable {
    public let level: Int
    public let dotted: Bool

    public init(level: Int, dotted: Bool = false) {
        self.level = max(0, min(4, level))
        self.dotted = dotted
    }

    public var ticks: Int {
        let base = 16 >> level
        return dotted ? base + base / 2 : base
    }

    /// Beams (or flags): one on an eighth, two on a sixteenth.
    public var beams: Int { max(0, level - 2) }
    /// Whole and half notes are open.
    public var hollow: Bool { level <= 1 }
    public var hasStem: Bool { level >= 1 }

    public static let whole = NoteDuration(level: 0)
    public static let half = NoteDuration(level: 1)
    public static let quarter = NoteDuration(level: 2)
    public static let eighth = NoteDuration(level: 3)
    public static let sixteenth = NoteDuration(level: 4)

    /// Every value that can be written in whole ticks, longest first (a dotted sixteenth can't).
    public static let all: [NoteDuration] = [
        NoteDuration(level: 0, dotted: true), .whole, NoteDuration(level: 1, dotted: true), .half,
        NoteDuration(level: 2, dotted: true), .quarter, NoteDuration(level: 3, dotted: true), .eighth, .sixteenth
    ]

    /// The value lasting exactly `ticks`, if one does.
    public static func lasting(_ ticks: Int) -> NoteDuration? { all.first { $0.ticks == ticks } }
}
