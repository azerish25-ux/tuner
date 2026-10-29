import Foundation
import Synchronization

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
    /// the chord and scale tools, lesson diagrams and lesson chord names (`ChordSpec.name`) read it, from any thread.
    public static var active: String {
        get { activeSystem.withLock { $0 } }
        set { activeSystem.withLock { $0 = newValue } }
    }
    private static let activeSystem = Mutex("english")

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
            while end < characters.count, let mark = sign(characters[end]) {
                signs.append(mark)
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

    /// Letters, digits and accidentals: what a note inside a word ("C7b9"'s 7) follows, so it isn't one.
    private static func isWordCharacter(_ character: Character) -> Bool {
        character.isLetter || character.isNumber || sign(character) != nil
    }

    private static func isLatinLetter(_ character: Character) -> Bool {
        guard character.isLetter, let scalar = character.unicodeScalars.first else { return false }
        return scalar.value < 0x0250
    }

    // MARK: - Spoken

    /// A note as a musician says it, for VoiceOver: "E flat 3", "F sharp 3" in English; "Es 3", "Fis 3", "B 3" in German
    /// (and the Dutch, Nordic, Czech, Polish and Hungarian forms); "Mi bémol 3", "Fa dièse 3" in French, with the fixed-do
    /// syllables and words of the Romance languages, Russian, Ukrainian, Greek, Turkish, Arabic and Hebrew; "Fシャープ 3",
    /// "升F 3", "F 샵 3" in Japanese, Chinese and Korean. Any other language gets the English words.
    ///
    /// `note` is a note as the app writes it, in any naming system, with ASCII or sign accidentals and an optional octave
    /// ("Eb3", "F♯3", "H2", "Sib4", "Dha#3", "5#3", "C#"). `system` is the system it was written in (nil: `active`), which
    /// says what a German "B" is (B flat). Text that isn't a note comes back as it is.
    public static func spoken(_ note: String, language: String, system: String? = nil) -> String {
        guard let parsed = parse(note, system: system ?? active) else { return note }
        let code = languageCode(language)
        let name: String
        if let family = germanicFamily(code) {
            // Germanic languages name the pitch with their own letters, whatever the system on screen.
            name = germanic(parsed.degree, accidental: parsed.accidental, family: family)
        } else {
            let words = SpokenWords.of(code) ?? SpokenWords.english
            let letter = String(letters[parsed.degree])
            let stem: String
            switch parsed.system {
            case "sargam", "numbered": stem = parsed.stem
            case "solfege": stem = words.fixedDo?[parsed.degree] ?? parsed.stem
            default: stem = words.fixedDo?[parsed.degree] ?? letter
            }
            name = words.join(stem, parsed.accidental)
        }
        return parsed.rest.isEmpty ? name : name + " " + parsed.rest
    }

    /// A note taken apart: its degree (0 C … 6 B), the sharps (+) or flats (−) on it, the stem as written, the system it
    /// reads in, and what follows (the octave).
    private struct ParsedNote {
        var degree: Int
        var accidental: Int
        var stem: String
        var system: String
        var rest: String
    }

    private static func parse(_ note: String, system: String) -> ParsedNote? {
        let characters = Array(note.trimmingCharacters(in: .whitespaces))
        guard let stem = stems.first(where: { matches($0, in: characters, at: 0) }) else { return nil }
        var accidental = 0
        var end = stem.count
        while end < characters.count, let mark = sign(characters[end]) {
            accidental += mark == sharpSign ? 1 : -1
            end += 1
        }
        let rest = String(characters[end...]).trimmingCharacters(in: .whitespaces)
        // What follows must be an octave (or nothing): "Bass" and "Do it" are not notes.
        guard rest.isEmpty || rest.first.map({ $0.isNumber || $0 == "-" }) == true else { return nil }
        let degree: Int
        let kind: String
        if stem == "Re" {
            // Re is the second degree in solfège and in sargam alike.
            degree = 1; kind = system == "sargam" ? "sargam" : "solfege"
        } else if let index = solfege.firstIndex(of: stem) {
            degree = index; kind = "solfege"
        } else if let index = sargam.firstIndex(of: stem) {
            degree = index; kind = "sargam"
        } else if let index = numbers.firstIndex(of: stem) {
            degree = index; kind = "numbered"
        } else if stem == "H" {
            degree = 6; kind = "german"
        } else if let letter = stem.first, let index = letters.firstIndex(of: letter) {
            degree = index; kind = system == "german" ? "german" : "english"
            // A German B is B flat.
            if letter == "B" && system == "german" { accidental -= 1 }
        } else {
            return nil
        }
        return ParsedNote(degree: degree, accidental: accidental, stem: stem, system: kind, rest: rest)
    }

    /// "de-CH" → "de", "zh-Hant" → "zh", "nb_NO" → "nb".
    private static func languageCode(_ language: String) -> String {
        language.lowercased().split(whereSeparator: { $0 == "-" || $0 == "_" }).first.map(String.init) ?? "en"
    }

    /// How a Germanic language adds accidentals to a letter: German "Fis", "Es", "B"; Dutch "Bes" (its B is B natural);
    /// Swedish "Fiss", "Ess"; Hungarian "Fisz", "Esz".
    private struct Germanic {
        var sharp: String
        var flat: String
        /// B natural: H, or B in Dutch.
        var bNatural: String
        /// B flat: B, or Bes in Dutch.
        var bFlat: String
    }

    private static func germanicFamily(_ code: String) -> Germanic? {
        switch code {
        case "de", "da", "nb", "nn", "no", "fi", "cs", "sk", "pl":
            return Germanic(sharp: "is", flat: "es", bNatural: "H", bFlat: "B")
        case "nl":
            return Germanic(sharp: "is", flat: "es", bNatural: "B", bFlat: "Bes")
        case "sv":
            return Germanic(sharp: "iss", flat: "ess", bNatural: "H", bFlat: "B")
        case "hu":
            return Germanic(sharp: "isz", flat: "esz", bNatural: "H", bFlat: "B")
        default:
            return nil
        }
    }

    /// "Cis", "Fisis", "Es", "As", "Des", "Heses"…
    private static func germanic(_ degree: Int, accidental: Int, family: Germanic) -> String {
        let base = degree == 6 ? family.bNatural : String(letters[degree])
        if accidental > 0 { return base + String(repeating: family.sharp, count: accidental) }
        if accidental == 0 { return base }
        if degree == 6 {
            // B flat has a name of its own; a double flat goes on from it ("Heses" in German).
            if accidental == -1 { return family.bFlat }
            return family.bNatural + String(repeating: family.flat, count: -accidental)
        }
        // E and A take a bare "s" for the first flat: "Es", "As" (Dutch and German alike); the rest add the whole suffix.
        if degree == 2 || degree == 5 {
            let first = String(family.flat.dropFirst())
            return base + first + String(repeating: family.flat, count: -accidental - 1)
        }
        return base + String(repeating: family.flat, count: -accidental)
    }

    /// A language's words for the accidentals, its fixed-do syllables where it reads notes that way, and how they join.
    private struct SpokenWords {
        var sharp: String
        var flat: String
        var doubleSharp: String
        var doubleFlat: String
        /// Do Re Mi … for the seven letters C … B; nil: letters.
        var fixedDo: [String]? = nil
        /// The accidental comes first ("升F").
        var prefix = false
        /// Joined with a hyphen ("фа-диез").
        var hyphen = false
        /// No space between the note and the word ("Fシャープ").
        var tight = false

        func join(_ stem: String, _ accidental: Int) -> String {
            guard accidental != 0 else { return stem }
            let word: String
            switch accidental {
            case 2...: word = doubleSharp
            case 1: word = sharp
            case -1: word = flat
            default: word = doubleFlat
            }
            if prefix { return word + stem }
            if hyphen { return stem + "-" + word }
            return stem + (tight ? "" : " ") + word
        }

        static let english = SpokenWords(sharp: "sharp", flat: "flat", doubleSharp: "double sharp", doubleFlat: "double flat")

        static func of(_ code: String) -> SpokenWords? {
            let latin = ["Do", "Re", "Mi", "Fa", "Sol", "La", "Si"]
            switch code {
            case "en": return english
            case "fr": return SpokenWords(sharp: "dièse", flat: "bémol", doubleSharp: "double dièse", doubleFlat: "double bémol",
                                          fixedDo: ["Do", "Ré", "Mi", "Fa", "Sol", "La", "Si"])
            case "it": return SpokenWords(sharp: "diesis", flat: "bemolle", doubleSharp: "doppio diesis", doubleFlat: "doppio bemolle", fixedDo: latin)
            case "es": return SpokenWords(sharp: "sostenido", flat: "bemol", doubleSharp: "doble sostenido", doubleFlat: "doble bemol", fixedDo: latin)
            case "ca": return SpokenWords(sharp: "sostingut", flat: "bemoll", doubleSharp: "doble sostingut", doubleFlat: "doble bemoll", fixedDo: latin)
            case "pt": return SpokenWords(sharp: "sustenido", flat: "bemol", doubleSharp: "dobrado sustenido", doubleFlat: "dobrado bemol",
                                          fixedDo: ["Dó", "Ré", "Mi", "Fá", "Sol", "Lá", "Si"])
            case "ro": return SpokenWords(sharp: "diez", flat: "bemol", doubleSharp: "dublu diez", doubleFlat: "dublu bemol", fixedDo: latin)
            case "tr": return SpokenWords(sharp: "diyez", flat: "bemol", doubleSharp: "çift diyez", doubleFlat: "çift bemol", fixedDo: latin)
            case "ru": return SpokenWords(sharp: "диез", flat: "бемоль", doubleSharp: "дубль-диез", doubleFlat: "дубль-бемоль",
                                          fixedDo: ["До", "Ре", "Ми", "Фа", "Соль", "Ля", "Си"], hyphen: true)
            case "uk": return SpokenWords(sharp: "дієз", flat: "бемоль", doubleSharp: "дубль-дієз", doubleFlat: "дубль-бемоль",
                                          fixedDo: ["До", "Ре", "Мі", "Фа", "Соль", "Ля", "Сі"], hyphen: true)
            case "el": return SpokenWords(sharp: "δίεση", flat: "ύφεση", doubleSharp: "διπλή δίεση", doubleFlat: "διπλή ύφεση",
                                          fixedDo: ["Ντο", "Ρε", "Μι", "Φα", "Σολ", "Λα", "Σι"])
            case "ar": return SpokenWords(sharp: "دييز", flat: "بيمول", doubleSharp: "دبل دييز", doubleFlat: "دبل بيمول",
                                          fixedDo: ["دو", "ري", "مي", "فا", "صول", "لا", "سي"])
            case "he": return SpokenWords(sharp: "דיאז", flat: "במול", doubleSharp: "דאבל דיאז", doubleFlat: "דאבל במול",
                                          fixedDo: ["דו", "רה", "מי", "פה", "סול", "לה", "סי"])
            case "ja": return SpokenWords(sharp: "シャープ", flat: "フラット", doubleSharp: "ダブルシャープ", doubleFlat: "ダブルフラット", tight: true)
            case "zh": return SpokenWords(sharp: "升", flat: "降", doubleSharp: "重升", doubleFlat: "重降", prefix: true)
            case "or": return SpokenWords(sharp: "ଶାର୍ପ", flat: "ଫ୍ଲାଟ୍", doubleSharp: "ଡବଲ୍ ଶାର୍ପ", doubleFlat: "ଡବଲ୍ ଫ୍ଲାଟ୍")
            case "ms": return SpokenWords(sharp: "syap", flat: "flet", doubleSharp: "syap berganda", doubleFlat: "flet berganda")
            case "ko": return SpokenWords(sharp: "샵", flat: "플랫", doubleSharp: "더블 샵", doubleFlat: "더블 플랫")
            default: return nil
            }
        }
    }
}
