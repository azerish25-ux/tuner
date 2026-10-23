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
    /// Compact notation, e.g. "x32010"; frets above 9 are written in brackets.
    public var notation: String { frets.map { $0.map { $0 > 9 ? "(\($0))" : String($0) } ?? "x" }.joined() }
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
}

public enum ScaleMap {
    public static func positions(root: Int, scale: ScaleFormula, openMidi: [Int], frets: ClosedRange<Int> = 0...12) -> [FretPosition] {
        let rootClass = ((root % 12) + 12) % 12
        var out: [FretPosition] = []
        for (string, open) in openMidi.enumerated() {
            for fret in frets {
                let interval = ((open + fret - rootClass) % 12 + 12) % 12
                if let degree = scale.intervals.firstIndex(of: interval) {
                    out.append(FretPosition(string: string, fret: fret, isRoot: interval == 0, degree: degree + 1))
                }
            }
        }
        return out
    }
}
