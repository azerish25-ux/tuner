import Foundation

public struct ChordFormula: Identifiable, Equatable, Hashable, Sendable {
    public let id: String
    public let name: String
    public let suffix: String
    public let intervals: [Int]
    /// Interval that may be left out when strings run short (usually the fifth).
    public let optional: Int?

    public static let all: [ChordFormula] = [
        .init(id: "maj", name: "Major", suffix: "", intervals: [0, 4, 7], optional: nil),
        .init(id: "min", name: "Minor", suffix: "m", intervals: [0, 3, 7], optional: nil),
        .init(id: "7", name: "Dominant 7", suffix: "7", intervals: [0, 4, 7, 10], optional: 7),
        .init(id: "maj7", name: "Major 7", suffix: "maj7", intervals: [0, 4, 7, 11], optional: 7),
        .init(id: "m7", name: "Minor 7", suffix: "m7", intervals: [0, 3, 7, 10], optional: 7),
        .init(id: "sus2", name: "Suspended 2", suffix: "sus2", intervals: [0, 2, 7], optional: nil),
        .init(id: "sus4", name: "Suspended 4", suffix: "sus4", intervals: [0, 5, 7], optional: nil),
        .init(id: "6", name: "Major 6", suffix: "6", intervals: [0, 4, 7, 9], optional: 7),
        .init(id: "m6", name: "Minor 6", suffix: "m6", intervals: [0, 3, 7, 9], optional: 7),
        .init(id: "add9", name: "Add 9", suffix: "add9", intervals: [0, 2, 4, 7], optional: 7),
        .init(id: "9", name: "Dominant 9", suffix: "9", intervals: [0, 2, 4, 7, 10], optional: 7),
        .init(id: "dim", name: "Diminished", suffix: "dim", intervals: [0, 3, 6], optional: nil),
        .init(id: "aug", name: "Augmented", suffix: "aug", intervals: [0, 4, 8], optional: nil),
        .init(id: "5", name: "Power chord", suffix: "5", intervals: [0, 7], optional: nil),
    ]
    public static func byId(_ id: String) -> ChordFormula { all.first { $0.id == id } ?? all[0] }
}

public struct ChordShape: Equatable, Hashable, Sendable {
    /// One entry per string from the lowest-numbered course (viewer's left) to the highest; nil = muted.
    public let frets: [Int?]
    public let score: Double
    public var lowestFret: Int { frets.compactMap { $0 }.filter { $0 > 0 }.min() ?? 0 }
    public var highestFret: Int { frets.compactMap { $0 }.max() ?? 0 }
    /// Compact notation, e.g. "x32010"; once any fret is above 9, frets are separated: "8-10-10-9-8-8".
    public var notation: String {
        let parts = frets.map { $0.map(String.init) ?? "x" }
        return frets.contains { ($0 ?? 0) > 9 } ? parts.joined(separator: "-") : parts.joined()
    }
    /// Within a four-fret span and needing at most four fingers (a barre counts as one).
    public var isPlayable: Bool { ChordFingering.isPlayable(frets) }
    /// Suggested fingers per string (1 index … 4 little, 0 open or muted); nil when none fits.
    public var fingers: [Int]? { ChordFingering.fingers(frets) }
}

/// How a hand plays a shape: barres, finger counts and a suggested fingering.
public enum ChordFingering {
    /// Strings a barre at `fret` covers: the run of strings ending at the highest string fretted there,
    /// every one of them fretted at or above the barre (an open or muted string, or a lower fret,
    /// ends it). Nil unless it holds down at least two notes.
    static func barre(_ frets: [Int?], at fret: Int) -> [Int]? {
        guard let last = frets.lastIndex(where: { $0 == fret }) else { return nil }
        var start = last
        while start > 0, let below = frets[start - 1], below > 0, below >= fret { start -= 1 }
        let covered = (start...last).filter { frets[$0] == fret }
        return covered.count >= 2 ? covered : nil
    }

    /// Fingers the shape needs: one per fretted note, or one barre plus the notes it doesn't cover.
    public static func fingersNeeded(_ frets: [Int?]) -> Int {
        let fretted = frets.compactMap { $0 }.filter { $0 > 0 }
        var best = fretted.count
        for fret in Set(fretted) {
            if let covered = barre(frets, at: fret) { best = min(best, 1 + fretted.count - covered.count) }
        }
        return best
    }

    /// Fretted notes within four frets of each other, four fingers or fewer.
    public static func isPlayable(_ frets: [Int?]) -> Bool {
        let fretted = frets.compactMap { $0 }.filter { $0 > 0 }
        if let low = fretted.min(), let high = fretted.max(), high - low > 3 { return false }
        return fingersNeeded(frets) <= 4
    }

    /// Fingers per string: the lowest workable barre when the shape has more than four notes (or four
    /// with two of them on the lowest fret, like F xx3211), then one finger per fret in order, closing
    /// up when the fingers would run out. Nil when no assignment fits in four fingers.
    public static func fingers(_ frets: [Int?]) -> [Int]? {
        let notes: [(string: Int, fret: Int)] = frets.enumerated().compactMap { index, fret in
            guard let fret, fret > 0 else { return nil }
            return (string: index, fret: fret)
        }
        guard let low = notes.map({ $0.fret }).min() else { return nil }
        var held: [Int] = []
        var barreFret = 0
        if notes.count > 4 {
            for fret in Set(notes.map { $0.fret }).sorted() {
                if let covered = barre(frets, at: fret), 1 + notes.count - covered.count <= 4 { held = covered; barreFret = fret; break }
            }
            guard !held.isEmpty else { return nil }
        } else if notes.count == 4, let covered = barre(frets, at: low) {
            held = covered; barreFret = low
        }
        // Units to finger in order: the barre (as one) and each note it doesn't hold.
        var units: [(fret: Int, string: Int, strings: [Int])] = []
        if let first = held.first { units.append((fret: barreFret, string: first, strings: held)) }
        for note in notes where !held.contains(note.string) { units.append((fret: note.fret, string: note.string, strings: [note.string])) }
        units.sort { $0.fret != $1.fret ? $0.fret < $1.fret : $0.string < $1.string }
        var result = Array(repeating: 0, count: frets.count)
        var next = 1
        for (offset, unit) in units.enumerated() {
            let remaining = units.count - offset - 1
            let finger = max(next, min(unit.fret - low + 1, 4 - remaining))
            guard finger <= 4 else { return nil }
            for string in unit.strings { result[string] = finger }
            next = finger + 1
        }
        return result
    }
}

public enum NoteNames {
    public static let sharps = ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"]
    public static let flats = ["C", "Db", "D", "Eb", "E", "F", "Gb", "G", "Ab", "A", "Bb", "B"]
    public static func name(_ pitchClass: Int, preferFlats: Bool = false) -> String {
        (preferFlats ? flats : sharps)[((pitchClass % 12) + 12) % 12]
    }
}

public enum ChordFinder {
    /// Playable voicings of root + formula on strings tuned to `openMidi` (viewer's left to right).
    public static func shapes(root: Int, formula: ChordFormula, openMidi: [Int], maxFret: Int = 12, span: Int = 4, limit: Int = 8) -> [ChordShape] {
        guard !openMidi.isEmpty else { return [] }
        let tones = Set(formula.intervals.map { (root + $0) % 12 })
        let required = formula.optional.map { opt in tones.subtracting([(root + opt) % 12]) } ?? tones
        let rootClass = ((root % 12) + 12) % 12
        let minSounding = min(openMidi.count, max(formula.intervals.count == 2 ? 2 : 3, openMidi.count - 2))
        var found: [[Int?]: Double] = [:]
        for start in 1...max(1, maxFret - span + 1) {
            let window = start...(start + span - 1)
            let candidates: [[Int?]] = openMidi.map { open in
                var options: [Int?] = [nil]
                if tones.contains(open % 12) { options.append(0) }
                for fret in window where tones.contains((open + fret) % 12) { options.append(fret) }
                return options
            }
            var current: [Int?] = []
            func walk(_ string: Int) {
                if string == openMidi.count { evaluate(current) ; return }
                for option in candidates[string] { current.append(option); walk(string + 1); current.removeLast() }
            }
            func evaluate(_ frets: [Int?]) {
                let sounding = frets.enumerated().compactMap { index, fret in fret.map { (index, openMidi[index] + $0) } }
                guard sounding.count >= minSounding else { return }
                let classes = Set(sounding.map { $0.1 % 12 })
                guard required.isSubset(of: classes), classes.isSubset(of: tones) else { return }
                guard let bass = sounding.min(by: { $0.1 < $1.1 }), bass.1 % 12 == rootClass else { return }
                let fretted = frets.compactMap { $0 }.filter { $0 > 0 }
                if let lo = fretted.min(), let hi = fretted.max(), hi - lo >= span { return }
                // Fingers: a barre at the lowest fret covers every string from its first use.
                let lowFret = fretted.min() ?? 0
                let atLow = frets.filter { $0 == lowFret }.count
                let fingers = fretted.count - (atLow > 1 ? atLow - 1 : 0)
                guard fingers <= 4 else { return }
                // Muted strings should sit on the outside of the voicing.
                let muted = frets.enumerated().filter { $0.element == nil }.map(\.offset)
                let interiorMutes = muted.filter { m in frets[..<m].contains { $0 != nil } && frets[(m + 1)...].contains { $0 != nil } }.count
                guard interiorMutes <= 1 else { return }
                let opens = frets.filter { $0 == 0 }.count
                var score: Double = Double(sounding.count) * 2
                score -= Double(muted.count) * 1.5
                score -= Double(interiorMutes) * 3
                score += Double(opens) * 0.8
                score -= Double(lowFret) * 0.6
                score -= Double(fingers) * 0.3
                let highest = fretted.max() ?? 0
                if highest <= 3 { score += 2.5 }  // open-position shapes come first
                score -= Double(highest - lowFret) * 0.5
                if bass.0 == frets.firstIndex(where: { $0 != nil }) { score += 1 }
                let previous: Double = found[frets] ?? -Double.infinity
                found[frets] = Swift.max(previous, score)
            }
            walk(0)
        }
        let shapes: [ChordShape] = found.map { entry in ChordShape(frets: entry.key, score: entry.value) }
        let ordered: [ChordShape] = shapes.sorted { (a: ChordShape, b: ChordShape) -> Bool in
            if a.score != b.score { return a.score > b.score }
            return a.notation < b.notation
        }
        return Array(ordered.prefix(limit))
    }
}

/// Hand-picked guitar voicings: open chords first, then the E-, A- and D-shape barre families up the neck
/// (C: x32010, x35553, 8-10-10-9-8-8, x-x-10-12-13-12). Used for six strings in standard tuning, or standard
/// moved up or down as a whole (E♭ standard plays the same shapes). Every other tuning falls back to
/// `ChordFinder`, keeping only the shapes a hand can play.
public enum ChordLibrary {
    public static let standardGuitar = [40, 45, 50, 55, 59, 64]
    /// Highest fret a curated shape reaches.
    public static let maxFret = 14

    struct Family: Sendable {
        let string: Int
        let offsets: [Int?]
    }

    /// Voicings to show for a chord on strings tuned to `openMidi` (lowest string first), best first.
    public static func voicings(root: Int, formula: ChordFormula, openMidi: [Int], limit: Int = 6) -> [ChordShape] {
        if let shift = standardShift(openMidi) {
            let shapes = curated(root: root - shift, formula: formula)
            if !shapes.isEmpty { return Array(shapes.prefix(limit)) }
        }
        let found = ChordFinder.shapes(root: root, formula: formula, openMidi: openMidi, limit: max(1, limit) * 3)
        return Array(found.filter { $0.isPlayable }.prefix(limit))
    }

    /// Semitones between `openMidi` and standard guitar tuning when every string moves together
    /// (−1 for E♭ standard); nil for any other tuning.
    public static func standardShift(_ openMidi: [Int]) -> Int? {
        guard openMidi.count == standardGuitar.count, let first = openMidi.first else { return nil }
        let shift = first - standardGuitar[0]
        guard abs(shift) <= 7 else { return nil }
        for (string, pitch) in openMidi.enumerated() where pitch - standardGuitar[string] != shift { return nil }
        return shift
    }

    /// The curated shapes for standard tuning: open shapes as listed, then each movable family at the
    /// lowest fret it fits (skipping fret 0 when an open shape exists), lowest position first. A shape whose
    /// notes another one already plays is left out.
    public static func curated(root: Int, formula: ChordFormula) -> [ChordShape] {
        let pc = ((root % 12) + 12) % 12
        let opens: [[Int?]] = (openShapes[formula.id]?[pc] ?? []).map(parse)
        var moved: [[Int?]] = []
        for family in families[formula.id] ?? [] {
            if let frets = place(family, root: pc, formula: formula, skipOpenPosition: !opens.isEmpty) { moved.append(frets) }
        }
        moved.sort { a, b in
            let lowA = position(a), lowB = position(b)
            if lowA != lowB { return lowA < lowB }
            return (a.firstIndex { $0 != nil } ?? 0) < (b.firstIndex { $0 != nil } ?? 0)
        }
        var shapes = opens
        for frets in moved where !shapes.contains(where: { covers($0, frets) }) { shapes.append(frets) }
        return shapes.enumerated().map { index, frets in ChordShape(frets: frets, score: Double(100 - index)) }
    }

    /// Whether `frets` spells the chord on `openMidi`: only chord tones, every tone but the optional one,
    /// the root in the bass and at least two strings sounding.
    public static func spells(_ frets: [Int?], root: Int, formula: ChordFormula, openMidi: [Int] = standardGuitar) -> Bool {
        guard frets.count == openMidi.count else { return false }
        let pc = ((root % 12) + 12) % 12
        let tones = Set(formula.intervals.map { (pc + $0) % 12 })
        let required = formula.optional.map { tones.subtracting([(pc + $0) % 12]) } ?? tones
        var pitches: [Int] = []
        for (string, fret) in frets.enumerated() { if let fret { pitches.append(openMidi[string] + fret) } }
        guard pitches.count >= 2, let bass = pitches.min() else { return false }
        let classes = Set(pitches.map { $0 % 12 })
        return classes.isSubset(of: tones) && required.isSubset(of: classes) && bass % 12 == pc
    }

    /// A family moved to the root's fret on its string (or an octave up), if it spells the chord,
    /// is playable and stays below `maxFret`.
    private static func place(_ family: Family, root: Int, formula: ChordFormula, skipOpenPosition: Bool) -> [Int?]? {
        let base = ((root - standardGuitar[family.string]) % 12 + 12) % 12
        for fret in [base, base + 12] {
            if fret == 0 && skipOpenPosition { continue }
            let frets: [Int?] = family.offsets.map { offset in offset.map { $0 + fret } }
            let sounding = frets.compactMap { $0 }
            guard let lowest = sounding.min(), let highest = sounding.max(), lowest >= 0, highest <= maxFret else { continue }
            guard spells(frets, root: root, formula: formula), ChordFingering.isPlayable(frets) else { continue }
            return frets
        }
        return nil
    }

    /// Lowest fretted position of a shape (0 when it is all open strings).
    private static func position(_ frets: [Int?]) -> Int { frets.compactMap { $0 }.filter { $0 > 0 }.min() ?? 0 }

    /// Whether `earlier` already plays every note of `later` (same fret on each string `later` sounds).
    private static func covers(_ earlier: [Int?], _ later: [Int?]) -> Bool {
        for (string, fret) in later.enumerated() where fret != nil && earlier[string] != fret { return false }
        return true
    }

    /// "x32010" or "x-10-12-12-12-10" into frets; x is muted.
    static func parse(_ notation: String) -> [Int?] {
        let parts: [String] = notation.contains("-") ? notation.split(separator: "-").map { String($0) } : notation.map { String($0) }
        return parts.map { Int($0) }
    }

    /// Open-position shapes by quality and root pitch class, best first.
    static let openShapes: [String: [Int: [String]]] = [
        "maj": [0: ["x32010"], 2: ["xx0232"], 4: ["022100"], 5: ["xx3211"], 7: ["320003", "320033"], 9: ["x02220"]],
        "min": [2: ["xx0231"], 4: ["022000"], 9: ["x02210"]],
        "7": [0: ["x32310"], 2: ["xx0212"], 4: ["020100", "022130"], 7: ["320001"], 9: ["x02020"], 11: ["x21202"]],
        "maj7": [0: ["x32000"], 2: ["xx0222"], 4: ["021100"], 5: ["xx3210"], 7: ["320002"], 9: ["x02120"]],
        "m7": [2: ["xx0211"], 4: ["020000", "022030"], 9: ["x02010"], 11: ["x20202"]],
        "sus2": [0: ["x30033"], 2: ["xx0230"], 4: ["024400"], 7: ["300033"], 9: ["x02200"]],
        "sus4": [0: ["x33011"], 2: ["xx0233"], 4: ["022200"], 7: ["330013"], 9: ["x02230"]],
        "6": [0: ["x32210"], 2: ["xx0202"], 4: ["022120"], 7: ["320000"], 9: ["x02222"]],
        "m6": [2: ["xx0201"], 4: ["022020"], 9: ["x02212"]],
        "add9": [0: ["x32030"], 4: ["024100"], 7: ["320203"], 9: ["x02420"]],
        "9": [0: ["x32330"], 4: ["020102"], 7: ["300001"], 9: ["x02423"]],
        "dim": [2: ["xx0131"], 4: ["0120xx"], 9: ["x0121x"], 11: ["x2343x"]],
        "aug": [0: ["x32110"], 2: ["xx0332"], 4: ["032110"], 7: ["321003"], 9: ["x03221"]],
        "5": [2: ["xx023x"], 4: ["022xxx"], 9: ["x022xx"]],
    ]

    /// Movable families by quality: the string the root sits on (0 is the low E) and each string's fret
    /// relative to the root's fret, nil muted. E shape (root on the 6th string), A shape (5th), D shape (4th).
    static let families: [String: [Family]] = [
        "maj": [Family(string: 0, offsets: [0, 2, 2, 1, 0, 0]), Family(string: 1, offsets: [nil, 0, 2, 2, 2, 0]), Family(string: 2, offsets: [nil, nil, 0, 2, 3, 2])],
        "min": [Family(string: 0, offsets: [0, 2, 2, 0, 0, 0]), Family(string: 1, offsets: [nil, 0, 2, 2, 1, 0]), Family(string: 2, offsets: [nil, nil, 0, 2, 3, 1])],
        "7": [Family(string: 0, offsets: [0, 2, 0, 1, 0, 0]), Family(string: 1, offsets: [nil, 0, 2, 0, 2, 0]), Family(string: 2, offsets: [nil, nil, 0, 2, 1, 2])],
        "maj7": [Family(string: 0, offsets: [0, nil, 1, 1, 0, nil]), Family(string: 1, offsets: [nil, 0, 2, 1, 2, 0]), Family(string: 2, offsets: [nil, nil, 0, 2, 2, 2])],
        "m7": [Family(string: 0, offsets: [0, 2, 0, 0, 0, 0]), Family(string: 1, offsets: [nil, 0, 2, 0, 1, 0]), Family(string: 2, offsets: [nil, nil, 0, 2, 1, 1])],
        "sus2": [Family(string: 1, offsets: [nil, 0, 2, 2, 0, 0]), Family(string: 2, offsets: [nil, nil, 0, 2, 3, 0])],
        "sus4": [Family(string: 0, offsets: [0, 2, 2, 2, 0, 0]), Family(string: 1, offsets: [nil, 0, 2, 2, 3, 0]), Family(string: 2, offsets: [nil, nil, 0, 2, 3, 3])],
        "6": [Family(string: 0, offsets: [0, nil, -1, 1, 0, nil]), Family(string: 1, offsets: [nil, 0, 2, 2, 2, 2]), Family(string: 2, offsets: [nil, nil, 0, 2, 0, 2])],
        "m6": [Family(string: 0, offsets: [0, nil, -1, 0, 0, nil]), Family(string: 1, offsets: [nil, 0, nil, -1, 1, 0]), Family(string: 2, offsets: [nil, nil, 0, 2, 0, 1])],
        "add9": [Family(string: 1, offsets: [nil, 0, -1, -3, 0, nil]), Family(string: 2, offsets: [nil, nil, 0, -1, -2, 0]), Family(string: 1, offsets: [nil, 0, -1, nil, 0, 0])],
        "9": [Family(string: 0, offsets: [0, 2, 0, 1, 0, 2]), Family(string: 1, offsets: [nil, 0, -1, 0, 0, 0])],
        "dim": [Family(string: 0, offsets: [0, 1, 2, 0, nil, nil]), Family(string: 1, offsets: [nil, 0, 1, 2, 1, nil]), Family(string: 2, offsets: [nil, nil, 0, 1, 0, 1])],
        "aug": [Family(string: 0, offsets: [0, nil, 2, 1, 1, nil]), Family(string: 1, offsets: [nil, 0, -1, -2, -2, nil]), Family(string: 2, offsets: [nil, nil, 0, 3, 3, 2])],
        "5": [Family(string: 0, offsets: [0, 2, 2, nil, nil, nil]), Family(string: 1, offsets: [nil, 0, 2, 2, nil, nil]), Family(string: 2, offsets: [nil, nil, 0, 2, 3, nil])],
    ]
}

public struct ScaleFormula: Identifiable, Hashable, Sendable {
    public let id: String
    public let name: String
    public let intervals: [Int]
    public static let all: [ScaleFormula] = [
        .init(id: "major", name: "Major", intervals: [0, 2, 4, 5, 7, 9, 11]),
        .init(id: "minor", name: "Natural minor", intervals: [0, 2, 3, 5, 7, 8, 10]),
        .init(id: "pent_major", name: "Major pentatonic", intervals: [0, 2, 4, 7, 9]),
        .init(id: "pent_minor", name: "Minor pentatonic", intervals: [0, 3, 5, 7, 10]),
        .init(id: "blues", name: "Blues", intervals: [0, 3, 5, 6, 7, 10]),
        .init(id: "dorian", name: "Dorian", intervals: [0, 2, 3, 5, 7, 9, 10]),
        .init(id: "mixolydian", name: "Mixolydian", intervals: [0, 2, 4, 5, 7, 9, 10]),
        .init(id: "harmonic_minor", name: "Harmonic minor", intervals: [0, 2, 3, 5, 7, 8, 11]),
    ]
}

public struct FretPosition: Hashable, Sendable {
    public let string: Int
    public let fret: Int
    public let isRoot: Bool
    public let degree: Int
    /// Semitones above the root, 0…11.
    public let interval: Int
    /// The tone named as an interval from the root: "R", "♭3", "4", "5", "♭7" …
    public var intervalName: String { IntervalName.short(interval) }
}

/// Short interval names as players read them on a neck diagram.
public enum IntervalName {
    public static let names = ["R", "♭2", "2", "♭3", "3", "4", "♭5", "5", "♭6", "6", "♭7", "7"]
    public static func short(_ semitones: Int) -> String { names[((semitones % 12) + 12) % 12] }
}

public enum ScaleMap {
    public static func positions(root: Int, scale: ScaleFormula, openMidi: [Int], frets: ClosedRange<Int> = 0...12) -> [FretPosition] {
        let rootClass = ((root % 12) + 12) % 12
        var out: [FretPosition] = []
        for (string, open) in openMidi.enumerated() {
            for fret in frets {
                let interval = ((open + fret - rootClass) % 12 + 12) % 12
                if let degree = scale.intervals.firstIndex(of: interval) {
                    out.append(FretPosition(string: string, fret: fret, isRoot: interval == 0, degree: degree + 1, interval: interval))
                }
            }
        }
        return out
    }

    private struct Place {
        let string: Int
        let fret: Int
    }

    /// The scale played once up an octave from its lowest root, one place per note, as a hand would:
    /// it starts on the root's lowest fret, stays in that position (a window from one fret below to three
    /// above) and moves across the strings toward the treble, leaving the window only when it must.
    /// Pitches are `openMidi[string] + fret`, in playing order.
    public static func run(root: Int, scale: ScaleFormula, openMidi: [Int], frets: ClosedRange<Int> = 0...15) -> [FretPosition] {
        guard let lowest = openMidi.min() else { return [] }
        let rootClass = ((root % 12) + 12) % 12
        let base = lowest + ((rootClass - lowest) % 12 + 12) % 12
        let notes = (scale.intervals + [12]).map { base + $0 }
        func places(_ midi: Int) -> [Place] {
            var found: [Place] = []
            for (string, open) in openMidi.enumerated() where frets.contains(midi - open) { found.append(Place(string: string, fret: midi - open)) }
            return found
        }
        func position(_ place: Place) -> FretPosition {
            let interval = ((openMidi[place.string] + place.fret - rootClass) % 12 + 12) % 12
            let degree = (scale.intervals.firstIndex(of: interval) ?? 0) + 1
            return FretPosition(string: place.string, fret: place.fret, isRoot: interval == 0, degree: degree, interval: interval)
        }
        guard let first = notes.first,
              let start = places(first).min(by: { $0.fret != $1.fret ? $0.fret < $1.fret : $0.string < $1.string }) else { return [] }
        let window = (start.fret - 1)...(start.fret + 3)
        var previous = start
        var result = [position(start)]
        for midi in notes.dropFirst() {
            let all = places(midi)
            let forward = all.filter { $0.string >= previous.string }
            let inPosition = forward.filter { window.contains($0.fret) }.min { $0.string < $1.string }
            let nearest = (forward.isEmpty ? all : forward).min { abs($0.fret - start.fret) < abs($1.fret - start.fret) }
            guard let pick = inPosition ?? nearest else { break }
            result.append(position(pick))
            previous = pick
        }
        return result
    }
}
