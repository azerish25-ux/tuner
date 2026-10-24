import Foundation

/// A chord symbol as charts write it: "G", "F#m7", "Bbmaj7", "D/F#", "Asus4", "C(add9)", "E7#9", "G6/9", "Bø7".
/// The root and the bass are pitch classes with their written spelling; the suffix is kept exactly as written, so a
/// chart reads back the way its author typed it. `ChordSymbol(_:)` is strict: it accepts what a chord chart would
/// print and nothing else, so "And", "Go" or "Bed" in a line of lyrics are never taken for chords.
public struct ChordSymbol: Equatable, Hashable, Sendable, CustomStringConvertible {
    /// Pitch class of the root, 0–11 (C = 0).
    public let root: Int
    /// The root as written in ASCII: a letter and at most one accidental ("F#", "Bb", "E").
    public let rootName: String
    /// Everything between the root and the slash, as written ("m7", "", "sus4", "(add9)").
    public let suffix: String
    /// Pitch class of a slash bass ("D/F#" has 6), nil without one.
    public let bass: Int?
    public let bassName: String?

    public init(root: Int, rootName: String, suffix: String, bass: Int? = nil, bassName: String? = nil) {
        self.root = ((root % 12) + 12) % 12
        self.rootName = rootName
        self.suffix = suffix
        self.bass = bass.map { (($0 % 12) + 12) % 12 }
        self.bassName = bassName
    }

    /// Parses a chord symbol; nil for anything a chart wouldn't print as one. Unicode accidentals (♯ ♭) are read and
    /// stored as ASCII; surrounding brackets of an optional chord ("(G)") are not part of the symbol.
    public init?(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty, trimmed.count <= 16 else { return nil }
        let characters = Array(trimmed)
        guard let (root, rootName, afterRoot) = Self.note(characters, at: 0) else { return nil }
        var rest = String(characters[afterRoot...])
        var bass: Int?
        var bassName: String?
        // A slash bass is a note after the last slash ("D/F#"); "G6/9" keeps its slash in the suffix.
        if let slash = rest.lastIndex(of: "/") {
            let tail = Array(rest[rest.index(after: slash)...])
            if let (pitch, name, end) = Self.note(tail, at: 0), end == tail.count {
                bass = pitch
                bassName = name
                rest = String(rest[..<slash])
            }
        }
        guard Self.isValidSuffix(rest) else { return nil }
        self.init(root: root, rootName: rootName, suffix: rest, bass: bass, bassName: bassName)
    }

    /// The symbol in ASCII, as stored: "F#m7", "D/F#".
    public var text: String { rootName + suffix + (bassName.map { "/" + $0 } ?? "") }
    public var description: String { text }

    // MARK: Transposing

    /// The chord moved by `semitones`, its root and bass respelled with flats or sharps. Moving by a whole number of
    /// octaves (0 included) keeps the spelling as written.
    public func transposed(by semitones: Int, preferFlats: Bool) -> ChordSymbol {
        transposed(by: semitones, names: preferFlats ? ChordSpelling.flatNames : ChordSpelling.sharpNames)
    }

    /// The chord moved by `semitones`, its root and bass spelled from `names` (twelve names, C first).
    public func transposed(by semitones: Int, names: [String]) -> ChordSymbol {
        let shift = ((semitones % 12) + 12) % 12
        guard shift != 0, names.count == 12 else { return self }
        let newRoot = (root + shift) % 12
        let newBass = bass.map { ($0 + shift) % 12 }
        return ChordSymbol(root: newRoot, rootName: names[newRoot], suffix: suffix, bass: newBass, bassName: newBass.map { names[$0] })
    }

    // MARK: What it is

    /// The nearest `ChordFormula` (its id), for drawing a shape: "maj", "min", "7", "maj7", "m7", "sus2", "sus4",
    /// "6", "m6", "add9", "9", "dim", "aug" or "5". Extensions fold onto the chord they colour (E7#9 → 7, Cmaj9 → maj7,
    /// Am11 → m7, Bø7 → dim), so every chord gets a playable box.
    public var formulaId: String { Self.formulaId(suffix: suffix) }

    /// The chord the recognizer listens for (major, minor, 7, maj7, m7, sus2, sus4, 5), nil for the qualities it can't
    /// hear apart (dim, aug). Added sixths and ninths are heard as their triad or seventh.
    public var target: ChordTarget? {
        let quality: ChordRecognizer.Quality
        switch formulaId {
        case "maj", "6", "add9": quality = .major
        case "min", "m6": quality = .minor
        case "7", "9": quality = .dominant7
        case "maj7": quality = .major7
        case "m7": quality = .minor7
        case "sus2": quality = .sus2
        case "sus4": quality = .sus4
        case "5": quality = .power
        default: return nil
        }
        return ChordTarget(root: root, quality: quality)
    }

    static func formulaId(suffix raw: String) -> String {
        var s = raw.replacingOccurrences(of: "(", with: "").replacingOccurrences(of: ")", with: "")
            .replacingOccurrences(of: "♭", with: "b").replacingOccurrences(of: "♯", with: "#")
        // Major sevenths first: "maj", "Maj", "M7", "Δ", "^".
        let majorSeventh = s.hasPrefix("maj") || s.hasPrefix("Maj") || s.hasPrefix("Δ") || s.hasPrefix("^")
            || (s.hasPrefix("M") && s.dropFirst().first.map { $0.isNumber } == true)
        if majorSeventh {
            let body = s.drop { !$0.isNumber }
            return body.isEmpty && !s.hasPrefix("Δ") && !s.hasPrefix("^") ? "maj" : "maj7"
        }
        if s == "M" { return "maj" }
        if s.hasPrefix("ø") || s.contains("m7b5") || s.hasPrefix("dim") || s.hasPrefix("°") || s.hasPrefix("o") { return "dim" }
        if s.hasPrefix("aug") || s.hasPrefix("+") || s.contains("#5") && !s.hasPrefix("m") { return "aug" }
        var minor = false
        if s.hasPrefix("min") { minor = true; s = String(s.dropFirst(3)) }
        else if s.hasPrefix("m") { minor = true; s = String(s.dropFirst()) }
        else if s.hasPrefix("-") { minor = true; s = String(s.dropFirst()) }
        if minor {
            if s.hasPrefix("6") { return "m6" }
            if s.hasPrefix("7") || s.hasPrefix("9") || s.hasPrefix("11") || s.hasPrefix("13") { return "m7" }
            return "min"
        }
        if s.hasPrefix("5") { return "5" }
        if s.contains("sus2") || s == "2" { return "sus2" }
        if s.contains("sus") { return "sus4" }
        if s.hasPrefix("add") || s.hasPrefix("2") { return "add9" }
        if s.hasPrefix("6") { return "6" }
        if s.hasPrefix("9") { return "9" }
        if s.hasPrefix("7") || s.hasPrefix("11") || s.hasPrefix("13") { return "7" }
        return "maj"
    }

    // MARK: Parsing

    private static let letters: [Character: Int] = ["C": 0, "D": 2, "E": 4, "F": 5, "G": 7, "A": 9, "B": 11]

    /// A note at `index`: an upper-case letter and at most one accidental; the pitch class, its ASCII spelling and
    /// where it ends.
    static func note(_ characters: [Character], at index: Int) -> (Int, String, Int)? {
        guard index < characters.count, let pitch = letters[characters[index]] else { return nil }
        var end = index + 1
        var name = String(characters[index])
        var value = pitch
        if end < characters.count {
            switch characters[end] {
            case "#", "♯": value += 1; name += "#"; end += 1
            case "b", "♭":
                // "Bb" is B flat; in "Cb5"-like oddities the b is still the accidental.
                value -= 1; name += "b"; end += 1
            default: break
            }
        }
        return ((value + 12) % 12, name, end)
    }

    /// The words a suffix may be made of, longest first.
    private static let words = ["maj", "Maj", "min", "dim", "aug", "sus", "add", "alt", "omit", "no", "M", "m", "+", "-",
                                "°", "ø", "Δ", "^", "(", ")", ",", "/"]

    /// A chord's suffix: chord words, digits, and alterations (b5, #9) only, ten characters at most. An accidental or a
    /// slash must lead to a number ("b9", "6/9"), and "o" counts only as "o7", so lyrics never pass.
    static func isValidSuffix(_ suffix: String) -> Bool {
        guard suffix.count <= 10 else { return false }
        let characters = Array(suffix)
        var index = 0
        var depth = 0
        while index < characters.count {
            let character = characters[index]
            if character.isASCII && character.isNumber { index += 1; continue }
            if character == "b" || character == "#" || character == "♭" || character == "♯" || character == "/" {
                guard index + 1 < characters.count, characters[index + 1].isASCII, characters[index + 1].isNumber else { return false }
                index += 1
                continue
            }
            if character == "o" {
                guard index + 1 < characters.count, characters[index + 1] == "7" else { return false }
                index += 1
                continue
            }
            if character == "-" && index > 0 && !(index + 1 < characters.count && characters[index + 1].isNumber) { return false }
            var matched = false
            for word in words where matches(word, characters, at: index) {
                if word == "(" { depth += 1 }
                if word == ")" { depth -= 1; if depth < 0 { return false } }
                index += word.count
                matched = true
                break
            }
            if !matched { return false }
        }
        return depth == 0
    }

    private static func matches(_ word: String, _ characters: [Character], at index: Int) -> Bool {
        guard index + word.count <= characters.count else { return false }
        return zip(word, characters[index...]).allSatisfy { $0 == $1 }
    }
}

/// Spelling chord roots after a transposition, and guessing a chart's key from its chords.
public enum ChordSpelling {
    public static let sharpNames = NoteNames.sharps
    public static let flatNames = NoteNames.flats
    /// The usual spelling of each root when no key says otherwise: B♭, E♭, A♭ and C♯, F♯ as most charts write them.
    public static let commonNames = ["C", "C#", "D", "Eb", "E", "F", "F#", "G", "Ab", "A", "Bb", "B"]

    /// Major keys written with flats (F, B♭, E♭, A♭, D♭, G♭); a minor key follows its relative major.
    public static func prefersFlats(tonic: Int, minor: Bool) -> Bool {
        let major = ((minor ? tonic + 3 : tonic) % 12 + 12) % 12
        return [5, 10, 3, 8, 1, 6].contains(major)
    }

    /// A key written as charts do: "G", "Em", "Bb", "F#m", "C major", "A minor". Nil for anything else.
    public static func key(_ text: String) -> (tonic: Int, minor: Bool)? {
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        let characters = Array(trimmed)
        guard let (tonic, _, end) = ChordSymbol.note(characters, at: 0) else { return nil }
        let rest = String(characters[end...]).trimmingCharacters(in: .whitespaces).lowercased()
        switch rest {
        case "", "maj", "major", "dur": return (tonic, false)
        case "m", "min", "minor", "moll": return (tonic, true)
        default: return nil
        }
    }

    /// The key that best explains a chart's chords: each chord counts toward the keys it is diatonic in (I, IV and V
    /// major, ii, iii and vi minor, V7), weighted by how often it is played; the opening and closing chords lean the
    /// choice toward their own key, which also tells a major key from its relative minor. Nil without chords.
    public static func guessKey(_ chords: [ChordSymbol]) -> (tonic: Int, minor: Bool)? {
        guard !chords.isEmpty else { return nil }
        var best: (tonic: Int, minor: Bool, score: Double)?
        for tonic in 0..<12 {
            for minor in [false, true] {
                let major = minor ? (tonic + 3) % 12 : tonic
                var score = 0.0
                for chord in chords {
                    let degree = (chord.root - major + 12) % 12
                    let id = chord.formulaId
                    let isMinor = id == "min" || id == "m7" || id == "m6"
                    let isMajor = id == "maj" || id == "maj7" || id == "6" || id == "add9" || id == "sus2" || id == "sus4" || id == "5"
                    let isDominant = id == "7" || id == "9"
                    switch degree {
                    case 0, 5: if isMajor { score += 1 }
                    case 7: if isMajor || isDominant { score += 1 }
                    case 2, 4, 9: if isMinor { score += 1 }
                    case 11: if id == "dim" { score += 0.5 }
                    default: break
                    }
                    // V7 of the relative minor (E7 in C / A minor) is common in minor keys.
                    if minor && degree == 4 && (isMajor || isDominant) { score += 0.6 }
                }
                let home = { (chord: ChordSymbol) -> Bool in
                    let id = chord.formulaId
                    let chordMinor = id == "min" || id == "m7" || id == "m6"
                    return chord.root == tonic && chordMinor == minor
                }
                if let first = chords.first, home(first) { score += 1.5 }
                if let last = chords.last, home(last) { score += 1 }
                if best == nil || score > best!.score + 1e-9 { best = (tonic, minor, score) }
            }
        }
        return best.map { (tonic: $0.tonic, minor: $0.minor) }
    }

    /// "G", "Em", "Bb", "F#m": a key as `{key}` writes it.
    public static func keyName(tonic: Int, minor: Bool) -> String {
        let names = prefersFlats(tonic: tonic, minor: minor) ? flatNames : sharpNames
        return names[((tonic % 12) + 12) % 12] + (minor ? "m" : "")
    }
}
