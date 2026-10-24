import Foundation

/// Note and chord names in the note-naming system the player picked (Settings › Note names).
///
/// Systems: "english" (letters, the default), "german" (letters, but B natural is H and B flat is B, as read in
/// German, Czech, Slovak, Polish, Hungarian and the Nordic languages), "solfege" (Do Re Mi), "sargam" (Sa Re Ga)
/// and "numbered" (1 2 3).
public enum NoteNames {
    /// Spellings as data, in ASCII ("C#", "Bb"): parsed, stored and compared. On screen they go through `glyphs`.
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

    // MARK: - On screen

    /// The signs a note is shown with.
    public static let sharpSign: Character = "♯"
    public static let flatSign: Character = "♭"

    /// What a written accidental can follow: solfège and sargam syllables (longest first, so "Dha#" is not read as
    /// "D"), the letters with German H, and the numbered system's degrees.
    private static let stems = ["Sol", "Dha", "Do", "Re", "Mi", "Fa", "La", "Si", "Sa", "Ga", "Ma", "Pa", "Ni",
                                "A", "B", "C", "D", "E", "F", "G", "H", "1", "2", "3", "4", "5", "6", "7"]
    /// What may follow a letter's accidental inside one chord symbol ("Ebmaj7", "F#m", "Bbsus4", "Abdim", "EbM7").
    private static let chordSuffixes = ["m", "M", "dim", "aug", "sus", "add"]

    /// The one way notes are written on screen and read to VoiceOver ("E flat"): ASCII accidentals in note names
    /// become signs. "Bb3" → "B♭3", "F#m7" → "F♯m7", "D/F#" → "D/F♯", "Sib" → "Si♭", "Dha#" → "Dha♯", "1#4" → "1♯4",
    /// "Eb standard" → "E♭ standard", "Key of Bb" → "Key of B♭", "Ebスタンダード" → "E♭スタンダード". A # or b counts only
    /// right after a note that starts a word, and only where the word ends there (or a chord's suffix follows), so
    /// other words ("Abend", "Bass", "Tonart Es"), German letters ("B", "H") and interval names ("b3") stay as they
    /// are. Names, chord symbols and labels stay ASCII as data; this is for text that names notes, not prose.
    public static func glyphs(_ text: String) -> String {
        guard text.contains(where: { $0 == "#" || $0 == "b" }) else { return text }
        let characters = Array(text)
        var result = ""
        result.reserveCapacity(text.utf8.count)
        var index = 0
        while index < characters.count {
            if let note = signedNote(characters, at: index) {
                result += note.text
                index = note.end
            } else {
                result.append(characters[index])
                index += 1
            }
        }
        return result
    }

    /// The note starting a word at `start` with its accidentals as signs, and where it ends; nil when there is no
    /// note there or it carries no accidental.
    private static func signedNote(_ characters: [Character], at start: Int) -> (text: String, end: Int)? {
        if start > 0 && isWordCharacter(characters[start - 1]) { return nil }
        for stem in stems where matches(stem, in: characters, at: start) {
            var end = start + stem.count
            var signs = ""
            while end < characters.count, let sign = sign(characters[end]) {
                signs.append(sign)
                end += 1
            }
            guard !signs.isEmpty, endsNote(characters, at: end, letter: stem.count == 1 && stem.first?.isLetter == true) else { return nil }
            return (stem + signs, end)
        }
        return nil
    }

    private static func matches(_ stem: String, in characters: [Character], at start: Int) -> Bool {
        guard start + stem.count <= characters.count else { return false }
        return zip(stem, characters[start...]).allSatisfy { $0 == $1 }
    }

    private static func sign(_ character: Character) -> Character? {
        switch character {
        case "#", sharpSign: return sharpSign
        case "b", flatSign: return flatSign
        default: return nil
        }
    }

    /// Whether the note's accidentals end the word at `index`: the text ends, or what follows is not a Latin letter
    /// (an octave, a space, "/", "-", "(", a Japanese or Korean word), or a letter's chord suffix follows.
    private static func endsNote(_ characters: [Character], at index: Int, letter: Bool) -> Bool {
        guard index < characters.count, isLatinLetter(characters[index]) else { return true }
        guard letter else { return false }
        let rest = String(characters[index...])
        return chordSuffixes.contains { rest.hasPrefix($0) }
    }

    private static func isWordCharacter(_ character: Character) -> Bool { character.isLetter || character.isNumber }

    private static func isLatinLetter(_ character: Character) -> Bool {
        guard character.isLetter, let scalar = character.unicodeScalars.first else { return false }
        return scalar.value < 0x0250
    }
}
