import Foundation

/// Note and chord names in the note-naming system the player picked (Settings › Note names).
///
/// Systems: "english" (letters, the default), "german" (letters, but B natural is H and B flat is B, as read in
/// German, Czech, Slovak, Polish, Hungarian and the Nordic languages), "solfege" (Do Re Mi), "sargam" (Sa Re Ga)
/// and "numbered" (1 2 3).
public enum NoteNames {
    public static let sharps = ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"]
    public static let flats = ["C", "Db", "D", "Eb", "E", "F", "Gb", "G", "Ab", "A", "Bb", "B"]
    /// Every system the Note names setting offers, in menu order.
    public static let systems = ["english", "german", "solfege", "sargam", "numbered"]

    /// The system on screen. The app sets it from `UserSettings.notation` at launch and on every settings change;
    /// the chord and scale tools, lesson diagrams and lesson chord names (`ChordSpec.name`) read it.
    public static var active = "english"

    private static let letters: [Character] = ["C", "D", "E", "F", "G", "A", "B"]
    private static let accidentals: Set<Character> = ["#", "b", "♯", "♭"]
    private static let solfege = ["Do", "Re", "Mi", "Fa", "Sol", "La", "Si"]
    private static let sargam = ["Sa", "Re", "Ga", "Ma", "Pa", "Dha", "Ni"]
    private static let numbers = ["1", "2", "3", "4", "5", "6", "7"]

    /// Names a pitch class for chord and scale tools in `system` (nil: the active one). Letters, German letters
    /// and solfège are used as they are; sargam and numbers keep letters here, as chord charts in those traditions do.
    public static func name(_ pitchClass: Int, preferFlats: Bool = false, system: String? = nil) -> String {
        let letter = (preferFlats ? flats : sharps)[((pitchClass % 12) + 12) % 12]
        return spell(letter, system: chordSystem(system ?? active))
    }

    /// A chord symbol from its root and suffix ("m", "7", "maj7" …): B minor is "Hm" and B♭ major "B" in German.
    public static func chord(root: Int, suffix: String, preferFlats: Bool = false, system: String? = nil) -> String {
        name(root, preferFlats: preferFlats, system: system) + suffix
    }

    /// Respells a letter name with its accidentals ("B", "Bb", "B♭", "F#", "C♯") in `system`. In German, B
    /// becomes H and B♭ becomes B; anything that isn't a letter name comes back unchanged.
    public static func spell(_ letterName: String, system: String) -> String {
        guard let letter = letterName.first, let index = letters.firstIndex(of: letter) else { return letterName }
        let accidental = String(letterName.dropFirst())
        guard accidental.allSatisfy({ accidentals.contains($0) }) else { return letterName }
        switch system {
        case "german":
            guard letter == "B" else { return letterName }
            // B♭ is B (and B♭♭ is B♭); B natural is H, B♯ is H♯.
            if let first = accidental.first, first == "b" || first == "♭" { return "B" + String(accidental.dropFirst()) }
            return "H" + accidental
        case "solfege": return solfege[index] + accidental
        case "sargam": return sargam[index] + accidental
        case "numbered": return numbers[index] + accidental
        default: return letterName
        }
    }

    /// A note written as a letter, accidentals and anything after ("Bb3", "B3", "C#4", "B") respelled in
    /// `system`: "B3" and "H3" in German.
    public static func spellNote(_ note: String, system: String) -> String {
        guard let letter = note.first, letters.contains(letter) else { return note }
        let accidental = note.dropFirst().prefix { accidentals.contains($0) }
        let rest = note.dropFirst(1 + accidental.count)
        return spell(String(letter) + String(accidental), system: system) + String(rest)
    }

    /// A chord symbol as authored in letters ("Bm", "B7", "Bbmaj7", "D/F#") respelled in `system` (nil: the
    /// active one): "Hm", "H7", "Bmaj7" in German, "Sim", "Si7" in solfège. Sargam and numbers keep letters.
    public static func chordSymbol(_ symbol: String, system: String? = nil) -> String {
        let target = chordSystem(system ?? active)
        guard target != "english", !symbol.isEmpty else { return symbol }
        let parts = symbol.split(separator: "/", maxSplits: 1, omittingEmptySubsequences: false).map(String.init)
        let main = spellNote(parts[0], system: target)
        guard parts.count == 2 else { return main }
        return main + "/" + spellNote(parts[1], system: target)
    }

    /// The system a language reads by default: German letters (H) for German, letters otherwise.
    public static func defaultSystem(language: String) -> String {
        let code = language.lowercased().split(whereSeparator: { $0 == "-" || $0 == "_" }).first.map(String.init) ?? ""
        return code == "de" ? "german" : "english"
    }

    /// The system chord symbols use under `system`: sargam and numbers fall back to letters.
    static func chordSystem(_ system: String) -> String {
        system == "german" || system == "solfege" ? system : "english"
    }
}
