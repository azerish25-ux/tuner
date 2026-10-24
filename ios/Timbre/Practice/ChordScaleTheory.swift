import SwiftUI
import TimbreCore

// Music theory for the Chords and Scales tools: note spelling per key, what a chord shape is called and how
// hard it is to hold, and the five hand positions of a scale. Pure functions; the views live beside them.

// MARK: - Spelling

/// Note names as a musician writes them in a key: every tone of a chord or scale on its own letter (F♯ major has
/// an E♯, F major a B♭ and never an A♯), the root written whichever way needs fewer accidentals and no double ones
/// (C♯ minor but D♭ major; E♭ minor and F♯ major, where both read alike, keep the tool's usual D♭ E♭ F♯ A♭ B♭).
enum Spelling {
    /// A letter (0 is C … 6 is B) and its accidental in semitones (−2 … 2).
    struct Note: Hashable, Sendable {
        let letter: Int
        let accidental: Int
        var pitchClass: Int { ((Spelling.naturals[letter] + accidental) % 12 + 12) % 12 }
    }

    static let letters = ["C", "D", "E", "F", "G", "A", "B"]
    static let naturals = [0, 2, 4, 5, 7, 9, 11]
    /// Letters above the root for an interval in semitones: 0 the unison … 6 the seventh. Six semitones is a ♭5,
    /// eight a ♭6.
    private static let steps = [0, 1, 1, 2, 2, 3, 4, 4, 5, 5, 6, 6]

    /// A scale's root and its tones, in `intervals` order. With `bluesNote`, the blues scale's added tone reads as
    /// a ♭5 unless a ♯4 is plainer (E, not F♭, in B♭ blues; A, not B𝄫, in E♭ blues).
    static func scale(root: Int, intervals: [Int], bluesNote: Bool = false) -> (root: Note, tones: [Note]) {
        spell(root: root, intervals: intervals, flexibleTritone: bluesNote)
    }

    /// A chord's root and its tones, in `intervals` order: a ♭5 in a diminished chord, a ♯5 in an augmented one.
    static func chord(root: Int, intervals: [Int]) -> (root: Note, tones: [Note]) {
        spell(root: root, intervals: intervals, flexibleTritone: false)
    }

    /// The tool's usual names on the black keys: D♭, E♭, F♯, A♭, B♭.
    static func prefersFlat(_ pitchClass: Int) -> Bool { [1, 3, 8, 10].contains(pitchClass) }

    /// "E♭", "F♯", "B" in the player's naming system: German letters (B♭ is B, B is H) and solfège as `NoteNames`
    /// spells them; sargam and numbers read chord charts in letters.
    static func name(_ note: Note) -> String {
        let marks = note.accidental > 0
            ? String(repeating: "♯", count: note.accidental)
            : String(repeating: "♭", count: -note.accidental)
        return NoteNames.spell(letters[note.letter] + marks, system: system)
    }

    static var system: String { ["german", "solfege"].contains(NoteNames.active) ? NoteNames.active : "english" }

    /// How a chord tone is named against its root, and where it sorts: 1, ♭3 or 3, 4, ♭5, 5 or ♯5, 6, ♭7 or 7,
    /// then 9; a 2 stands in for the third in a sus2.
    static func chordDegree(_ interval: Int, in intervals: [Int]) -> (label: String, order: Int) {
        let hasThird = intervals.contains(3) || intervals.contains(4)
        switch ((interval % 12) + 12) % 12 {
        case 0: return ("1", 1)
        case 1: return ("♭9", 9)
        case 2: return hasThird ? ("9", 9) : ("2", 2)
        case 3: return ("♭3", 3)
        case 4: return ("3", 3)
        case 5: return ("4", 4)
        case 6: return ("♭5", 5)
        case 7: return ("5", 5)
        case 8: return intervals.contains(7) ? ("♭6", 6) : ("♯5", 5)
        case 9: return ("6", 6)
        case 10: return ("♭7", 7)
        default: return ("7", 7)
        }
    }

    private static func spell(root: Int, intervals: [Int], flexibleTritone: Bool) -> (root: Note, tones: [Note]) {
        let pitchClass = ((root % 12) + 12) % 12
        var best: (penalty: Int, preference: Int, root: Note, tones: [Note])?
        for candidate in candidates(pitchClass) {
            let tones = intervals.map { tone(from: candidate, interval: $0, intervals: intervals, flexibleTritone: flexibleTritone) }
            // Every accidental costs one; a double sharp or flat costs ten more.
            let penalty = tones.reduce(0) { total, note in total + abs(note.accidental) + (abs(note.accidental) >= 2 ? 10 : 0) }
            let preference = (candidate.accidental < 0) == prefersFlat(pitchClass) ? 0 : 1
            if let current = best, (current.penalty, current.preference) <= (penalty, preference) { continue }
            best = (penalty, preference, candidate, tones)
        }
        if let best { return (best.root, best.tones) }
        return (Note(letter: 0, accidental: 0), [])
    }

    /// The ways to write a pitch class with at most one accidental: a natural alone, else its sharp and its flat.
    private static func candidates(_ pitchClass: Int) -> [Note] {
        if let natural = naturals.firstIndex(of: pitchClass) { return [Note(letter: natural, accidental: 0)] }
        var found: [Note] = []
        for (letter, natural) in naturals.enumerated() {
            let accidental = signed(pitchClass - natural)
            if abs(accidental) == 1 { found.append(Note(letter: letter, accidental: accidental)) }
        }
        return found
    }

    private static func tone(from root: Note, interval: Int, intervals: [Int], flexibleTritone: Bool) -> Note {
        let semitones = ((interval % 12) + 12) % 12
        var options = [steps[semitones]]
        if semitones == 8 && !intervals.contains(7) { options = [4] }   // an augmented fifth
        if semitones == 6 && flexibleTritone { options = [4, 3] }       // the blue note: ♭5, or ♯4 where plainer
        let target = (root.pitchClass + semitones) % 12
        func note(_ step: Int) -> Note {
            let letter = (root.letter + step) % 7
            return Note(letter: letter, accidental: signed(target - naturals[letter]))
        }
        var best = note(options[0])
        for step in options.dropFirst() {
            let other = note(step)
            if abs(other.accidental) < abs(best.accidental) { best = other }
        }
        return best
    }

    /// Semitones folded into −5 … 6.
    private static func signed(_ semitones: Int) -> Int {
        let wrapped = ((semitones % 12) + 12) % 12
        return wrapped > 6 ? wrapped - 12 : wrapped
    }
}

// MARK: - Chord shapes

/// What a chord shape is called on its card and how hard it is to hold. "Open chord" while an open string rings;
/// otherwise by the hand at its lowest fret: "Barre · 3fr" when one finger lies across strings, "Power · 5fr",
/// "Triad · 8fr" on three strings, "Movable · 10fr" for the other closed shapes.
struct VoicingProfile: Equatable {
    enum Kind: Equatable { case open, barre, power, triad, movable }

    enum Level: Int, Equatable {
        case easy = 1, medium, hard

        var name: String {
            switch self {
            case .easy: return String(localized: "Easy")
            case .medium: return String(localized: "Medium")
            case .hard: return String(localized: "Hard")
            }
        }

        var tint: Color {
            switch self {
            case .easy: return Palette.mint
            case .medium: return Palette.amber
            case .hard: return Palette.coral
            }
        }
    }

    let kind: Kind
    /// The lowest fretted fret: the "3" of "Barre · 3fr".
    let fret: Int
    let level: Level

    /// Difficulty adds up what the hand has to do: three fingers (1) or four (2), each barre (2 across four strings
    /// or more, 1 for a short one), a stretch over four frets (1) and every muted string inside the shape (1). Up to
    /// 1 is Easy (C, G, Em, power chords), up to 3 Medium (the small F, A-shape barres), beyond that Hard.
    init(_ shape: ChordShape, formulaId: String) {
        let frets = shape.frets
        let fingers = shape.fingers
        let sounding = frets.compactMap { $0 }
        let fretted = sounding.filter { $0 > 0 }
        let barres = Self.barreSpans(frets, fingers: fingers)
        fret = fretted.min() ?? 0
        if sounding.contains(0) { kind = .open }
        else if !barres.isEmpty { kind = .barre }
        else if formulaId == "5" { kind = .power }
        else if sounding.count == 3 { kind = .triad }
        else { kind = .movable }

        let used = fingers.map { Set($0.filter { $0 > 0 }).count } ?? min(4, fretted.count)
        var score = used >= 4 ? 2 : (used == 3 ? 1 : 0)
        for span in barres { score += span >= 4 ? 2 : 1 }
        if let low = fretted.min(), let high = fretted.max(), high - low >= 3 { score += 1 }
        if let first = frets.firstIndex(where: { $0 != nil }), let last = frets.lastIndex(where: { $0 != nil }) {
            score += (first...last).filter { frets[$0] == nil }.count
        }
        level = score <= 1 ? .easy : (score <= 3 ? .medium : .hard)
    }

    var title: String {
        switch kind {
        case .open: return String(localized: "Open chord")
        case .barre: return String(localized: "Barre · \(fret)fr")
        case .power: return String(localized: "Power · \(fret)fr")
        case .triad: return String(localized: "Triad · \(fret)fr")
        case .movable: return String(localized: "Movable · \(fret)fr")
        }
    }

    /// Strings under each barre of the suggested fingering, as the chord box draws them: one finger on two strings
    /// or more at one fret, every string between them fretted at or above it.
    static func barreSpans(_ frets: [Int?], fingers: [Int]?) -> [Int] {
        guard let fingers, fingers.count == frets.count else { return [] }
        var spans: [Int] = []
        for finger in Set(fingers.filter { $0 > 0 }).sorted() {
            let held = frets.indices.filter { fingers[$0] == finger && (frets[$0] ?? 0) > 0 }
            guard held.count >= 2, let first = held.first, let last = held.last, let fret = frets[first] else { continue }
            guard held.allSatisfy({ frets[$0] == fret }), (first...last).allSatisfy({ (frets[$0] ?? -1) >= fret }) else { continue }
            spans.append(last - first + 1)
        }
        return spans
    }
}

// MARK: - Scale positions

/// A place on the neck: a string (lowest-numbered course first, as `openMidi`) and a fret.
struct NeckSpot: Hashable, Sendable {
    let string: Int
    let fret: Int
}

/// One hand position of a scale: the frets it spans and its notes, lowest first, each pitch on one string.
struct ScalePosition: Identifiable, Equatable {
    let number: Int
    let frets: ClosedRange<Int>
    let spots: [NeckSpot]
    /// The CAGED chord shape it is built around (E, D, C, A or G), on six strings tuned as standard.
    let shape: String?
    var id: Int { number }
}

/// The five positions that cover the neck, as guitarists learn them. Each grows from a box of the pentatonic
/// scale: two notes a string, starting on the scale's next tone on the lowest string, so position 1 starts on the
/// root (the minor pentatonic's box 1). A pentatonic scale is its boxes; the blues and seven-note scales fill
/// each box's frets with their other tones, every pitch once, reaching a fret either side where the hand must
/// stretch (the G string's fourth fret in A minor). For strings tuned in fourths (and the guitar's one third);
/// other tunings show the whole neck only.
enum ScalePositions {
    /// CAGED shapes in position order, from position 1 (root on the sixth string, E shape) up the neck.
    static let shapes = ["E", "D", "C", "A", "G"]

    static func available(_ openMidi: [Int]) -> Bool {
        guard openMidi.count >= 4 else { return false }
        return zip(openMidi, openMidi.dropFirst()).allSatisfy { pair in [4, 5].contains(pair.1 - pair.0) }
    }

    /// The five positions, each placed where it fits by the 12th fret if it can (else as low as it goes, by the 15th).
    static func positions(root: Int, scale: ScaleFormula, openMidi: [Int]) -> [ScalePosition] {
        guard available(openMidi), let lowest = openMidi.first else { return [] }
        let rootClass = ((root % 12) + 12) % 12
        let intervals = scale.intervals
        let pentatonic = intervals.count == 5 ? intervals : (intervals.contains(4) ? [0, 2, 4, 7, 9] : [0, 3, 5, 7, 10])
        let tones = Set(intervals.map { (rootClass + $0) % 12 })
        let caged = openMidi.count == 6 && ChordLibrary.standardShift(openMidi) != nil
        var result: [ScalePosition] = []
        for (index, degree) in pentatonic.enumerated() {
            let start = ((rootClass + degree - lowest) % 12 + 12) % 12
            let boxes = [start, start + 12].compactMap { Self.box(pentatonic: pentatonic, root: rootClass, openMidi: openMidi, base: $0) }
            guard let chosen = boxes.first(where: { ($0.map(\.fret).max() ?? 0) <= 12 }) ?? boxes.first else { continue }
            let low = chosen.map(\.fret).min() ?? 0
            let high = chosen.map(\.fret).max() ?? 0
            let spots = intervals.count == 5 ? chosen : (fill(tones: tones, openMidi: openMidi, frets: low...high) ?? chosen)
            let frets = (spots.map(\.fret).min() ?? low)...(spots.map(\.fret).max() ?? high)
            result.append(ScalePosition(number: index + 1, frets: frets, spots: spots, shape: caged ? shapes[index] : nil))
        }
        return result
    }

    /// The pentatonic box starting `base` frets up the lowest string: the next two scale tones on each string in turn.
    private static func box(pentatonic: [Int], root: Int, openMidi: [Int], base: Int) -> [NeckSpot]? {
        let classes = Set(pentatonic.map { (root + $0) % 12 })
        var pitches: [Int] = []
        var pitch = openMidi[0] + base
        while pitches.count < openMidi.count * 2 {
            if classes.contains(((pitch % 12) + 12) % 12) { pitches.append(pitch) }
            pitch += 1
        }
        var spots: [NeckSpot] = []
        for (string, open) in openMidi.enumerated() {
            for note in pitches[(string * 2)..<(string * 2 + 2)] {
                let fret = note - open
                guard fret >= 0 else { return nil }
                spots.append(NeckSpot(string: string, fret: fret))
            }
        }
        return spots
    }

    /// Every scale pitch from the lowest one on the lowest string to the highest on the top string within `frets`,
    /// walking up: on the string in hand while it is in reach, else the next one; a fret outside the box only where
    /// no string has the note inside it (the index finger reaching back on the next string, else the little finger
    /// reaching up on this one).
    private static func fill(tones: Set<Int>, openMidi: [Int], frets: ClosedRange<Int>) -> [NeckSpot]? {
        guard let first = openMidi.first, let last = openMidi.last else { return nil }
        func isTone(_ pitch: Int) -> Bool { tones.contains(((pitch % 12) + 12) % 12) }
        guard let low = frets.map({ first + $0 }).first(where: isTone),
              let high = frets.map({ last + $0 }).last(where: isTone), low <= high else { return nil }
        var string = 0
        var spots: [NeckSpot] = []
        for pitch in low...high where isTone(pitch) {
            var placed: NeckSpot?
            for candidate in string..<openMidi.count where frets.contains(pitch - openMidi[candidate]) {
                placed = NeckSpot(string: candidate, fret: pitch - openMidi[candidate])
                break
            }
            if placed == nil, string + 1 < openMidi.count, frets.lowerBound >= 1, pitch - openMidi[string + 1] == frets.lowerBound - 1 {
                placed = NeckSpot(string: string + 1, fret: frets.lowerBound - 1)
            }
            if placed == nil, pitch - openMidi[string] == frets.upperBound + 1 {
                placed = NeckSpot(string: string, fret: frets.upperBound + 1)
            }
            guard let spot = placed else { return nil }
            string = spot.string
            spots.append(spot)
        }
        return spots
    }
}
