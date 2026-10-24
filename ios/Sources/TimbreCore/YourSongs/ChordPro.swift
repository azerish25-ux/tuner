import Foundation

// MARK: - The chart

/// A chord chart the player brought: the song's details from its directives, and its sections of lyrics with chords
/// over them. Read from ChordPro (`ChordProParser`); the ChordPro text stays the copy that is stored and edited, so a
/// chart always reads back as its author wrote it.
public struct ChordChart: Equatable, Sendable {
    public var title: String
    public var subtitle: String?
    public var artist: String?
    /// The key as written ("G", "Em", "Bb"), nil when the chart doesn't say.
    public var key: String?
    /// Beats per minute, when the chart gives a tempo.
    public var tempo: Double?
    public var meter: ChartMeter?
    /// The capo the chart's chords are written for (the shapes are played with it on): 0 without one.
    public var capo: Int
    public var sections: [ChartSection]
    /// Other details the chart carries (album, year, composer, copyright, duration), by directive name.
    public var extras: [String: String]

    public init(title: String = "", subtitle: String? = nil, artist: String? = nil, key: String? = nil, tempo: Double? = nil,
                meter: ChartMeter? = nil, capo: Int = 0, sections: [ChartSection] = [], extras: [String: String] = [:]) {
        self.title = title; self.subtitle = subtitle; self.artist = artist; self.key = key; self.tempo = tempo
        self.meter = meter; self.capo = capo; self.sections = sections; self.extras = extras
    }

    /// Every chord in reading order, as written (repeats included): what a tap-along times, one tap per entry.
    public var chordSequence: [ChartChordRef] {
        var refs: [ChartChordRef] = []
        for (s, section) in sections.enumerated() {
            for (l, line) in section.lines.enumerated() {
                guard case let .lyrics(segments) = line else { continue }
                for (g, segment) in segments.enumerated() {
                    guard let chord = segment.chord, ChordSymbol(chord) != nil else { continue }
                    refs.append(ChartChordRef(section: s, line: l, segment: g, chord: chord))
                }
            }
        }
        return refs
    }

    /// The distinct chords, in the order they first appear (parsed ones only: annotations such as "N.C." are left out).
    public var uniqueChords: [ChordSymbol] {
        var seen = Set<String>()
        var out: [ChordSymbol] = []
        for ref in chordSequence {
            guard let symbol = ChordSymbol(ref.chord), seen.insert(symbol.text).inserted else { continue }
            out.append(symbol)
        }
        return out
    }

    /// The key: as written, else guessed from the chords (`ChordSpelling.guessKey`).
    public var resolvedKey: (tonic: Int, minor: Bool)? {
        if let key, let parsed = ChordSpelling.key(key) { return parsed }
        return ChordSpelling.guessKey(chordSequence.compactMap { ChordSymbol($0.chord) })
    }

    public var beatsPerBar: Int { meter?.beats ?? 4 }
    public var hasLyrics: Bool {
        sections.contains { section in
            section.lines.contains { line in
                if case let .lyrics(segments) = line { return segments.contains { !$0.isBarText } }
                return false
            }
        }
    }
}

/// Where a chord sits in a chart: its section, line and segment.
public struct ChartChordRef: Equatable, Hashable, Sendable {
    public let section: Int
    public let line: Int
    public let segment: Int
    public let chord: String
}

/// A time signature, "3/4" or "6/8".
public struct ChartMeter: Equatable, Hashable, Codable, Sendable {
    public let beats: Int
    public let unit: Int
    public init(beats: Int, unit: Int) { self.beats = beats; self.unit = unit }

    /// "4/4", "3/4", "6/8", "12/8"; also "C" (common time) and "C|" (cut time).
    public init?(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        if trimmed == "C" { self.init(beats: 4, unit: 4); return }
        if trimmed == "C|" || trimmed == "¢" { self.init(beats: 2, unit: 2); return }
        let parts = trimmed.split(separator: "/").map { $0.trimmingCharacters(in: .whitespaces) }
        guard parts.count == 2, let beats = Int(parts[0]), let unit = Int(parts[1]), (1...32).contains(beats), [1, 2, 4, 8, 16].contains(unit) else { return nil }
        self.init(beats: beats, unit: unit)
    }

    public var text: String { "\(beats)/\(unit)" }
}

public struct ChartSection: Equatable, Sendable {
    public enum Kind: String, Codable, Sendable {
        case verse, chorus, bridge, tab, grid, other
        /// Lines outside any `{start_of_…}`.
        case untitled
    }

    public var kind: Kind
    /// Its own name ("Chorus 2", "Intro"), when the chart gives one.
    public var label: String?
    public var lines: [ChartLine]
    /// A `{chorus}` that repeats the chorus before it.
    public var isRepeat: Bool

    public init(kind: Kind, label: String? = nil, lines: [ChartLine] = [], isRepeat: Bool = false) {
        self.kind = kind; self.label = label; self.lines = lines; self.isRepeat = isRepeat
    }

    /// Whether anything but blank lines is in it.
    public var hasContent: Bool { lines.contains { $0 != .blank } }
}

public enum ChartLine: Equatable, Sendable {
    /// Lyrics with chords over them (or chords alone).
    case lyrics([ChartSegment])
    /// A note to the player: `{comment: …}`, `{c: …}`.
    case comment(String)
    /// A line of a tab or grid section, kept exactly as written.
    case verbatim(String)
    case blank
}

/// A chord and the words under it: a chord applies from the start of its text ("[G]Amazing [C]grace").
public struct ChartSegment: Equatable, Sendable {
    /// The chord as written between the brackets; nil for the words before a line's first chord.
    public var chord: String?
    public var text: String
    public init(chord: String?, text: String) { self.chord = chord; self.text = text }

    /// Only bar lines, slashes, dots or spaces ("| ", " / / "): a chord row rather than words.
    public var isBarText: Bool { text.allSatisfy { $0 == " " || $0 == "|" || $0 == "/" || $0 == "." || $0 == "-" || $0 == "%" } }
}

// MARK: - Reading ChordPro

/// Reads ChordPro and real-world chord files leniently: directives in any case with or without a colon, their short
/// forms (`{t:}`, `{st:}`, `{soc}`, `{c:}`), ChordPro 6 labels (`{start_of_verse: Verse 2}`, `label="…"`), custom
/// sections (`{start_of_solo}`), `{chorus}` repeats, `#` comment lines, unclosed brackets, Windows and old Mac line
/// ends, a byte-order mark and tabs. Unknown directives are skipped, never shown. A file of chords written over lyrics
/// (as most chord sites print them) is converted first (`ChordProImport.convert`).
public enum ChordProParser {
    public static func parse(_ source: String) -> ChordChart {
        let text = ChordProImport.normalize(source)
        let input = ChordProImport.looksLikeChordPro(text) ? text : ChordProImport.convert(text, fallbackTitle: nil)
        var builder = Builder()
        for line in input.components(separatedBy: "\n") { builder.read(line) }
        return builder.finish()
    }

    /// A directive line's name (lower-cased, without a `-selector`) and value; nil when the line isn't one.
    public static func directive(_ line: String) -> (name: String, value: String)? {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        guard trimmed.hasPrefix("{"), trimmed.hasSuffix("}"), trimmed.count >= 3 else { return nil }
        let inner = String(trimmed.dropFirst().dropLast()).trimmingCharacters(in: .whitespaces)
        var name = ""
        var value = ""
        // "{title: Song}", "{title:Song}" and "{title Song}"; in "{start_of_verse label="V: 1"}" the first colon comes
        // after a space, so the name ends at the space (a name never holds one).
        if let colon = inner.firstIndex(of: ":"), !inner[..<colon].contains(" ") {
            name = String(inner[..<colon])
            value = String(inner[inner.index(after: colon)...])
        } else {
            let split = inner.split(separator: " ", maxSplits: 1).map(String.init)
            name = split.first ?? ""
            value = split.count > 1 ? split[1] : ""
        }
        var key = name.trimmingCharacters(in: .whitespaces).lowercased()
        // Conditional directives ("{title-ukulele: …}") apply to everyone here.
        if let dash = key.firstIndex(of: "-") { key = String(key[..<dash]) }
        guard !key.isEmpty, key.allSatisfy({ $0.isLetter || $0.isNumber || $0 == "_" }) else { return nil }
        return (key, value.trimmingCharacters(in: .whitespaces))
    }

    /// A section's label from a directive's value: plain text ("Chorus 2") or a ChordPro 6 attribute (`label="…"`).
    static func label(_ value: String) -> String? {
        let trimmed = value.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return nil }
        if let range = trimmed.range(of: "label=") {
            var rest = trimmed[range.upperBound...]
            let quote = rest.first
            if quote == "\"" || quote == "'" {
                rest = rest.dropFirst()
                let end = rest.firstIndex(of: quote!) ?? rest.endIndex
                let found = String(rest[..<end]).trimmingCharacters(in: .whitespaces)
                return found.isEmpty ? nil : found
            }
            let found = rest.split(separator: " ").first.map(String.init) ?? ""
            return found.isEmpty ? nil : found
        }
        return trimmed
    }

    /// A lyric line's segments: the words before the first chord, then each chord with the words up to the next.
    /// An unclosed bracket is read as words; an empty pair `[]` is dropped.
    public static func segments(_ line: String) -> [ChartSegment] {
        var segments: [ChartSegment] = []
        var chord: String?
        var text = ""
        var index = line.startIndex
        while index < line.endIndex {
            let character = line[index]
            if character == "[", let close = line[line.index(after: index)...].firstIndex(of: "]") {
                let inside = line[line.index(after: index)..<close].trimmingCharacters(in: .whitespaces)
                if !inside.isEmpty && !inside.contains("[") {
                    if chord != nil || !text.isEmpty { segments.append(ChartSegment(chord: chord, text: text)) }
                    chord = inside
                    text = ""
                }
                index = line.index(after: close)
                continue
            }
            text.append(character)
            index = line.index(after: index)
        }
        if chord != nil || !text.isEmpty { segments.append(ChartSegment(chord: chord, text: text)) }
        return segments
    }

    /// Builds a chart line by line.
    private struct Builder {
        var chart = ChordChart()
        var current: ChartSection?
        var lastChorus: ChartSection?
        var inSong = true
        var songCount = 0

        mutating func read(_ raw: String) {
            let line = raw.replacingOccurrences(of: "\u{00A0}", with: " ")
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if let directive = ChordProParser.directive(line) {
                apply(directive.name, directive.value)
                return
            }
            guard inSong else { return }
            // A line starting with # is a comment for the file, not the player (ChordPro); in a tab it's music.
            let verbatim = current?.kind == .tab || current?.kind == .grid
            if trimmed.hasPrefix("#") && !verbatim { return }
            if trimmed.isEmpty {
                append(.blank)
                return
            }
            if verbatim {
                append(.verbatim(line.replacingOccurrences(of: "\t", with: "    ")))
                return
            }
            append(.lyrics(ChordProParser.segments(line)))
        }

        mutating func apply(_ name: String, _ value: String) {
            switch name {
            case "new_song", "ns":
                songCount += 1
                // A songbook file: the first song is the chart.
                if songCount > 1 || hasContent { inSong = false }
            default: break
            }
            guard inSong else { return }
            switch name {
            case "title", "t": if chart.title.isEmpty { chart.title = value }
            case "subtitle", "st", "su": chart.subtitle = value.isEmpty ? nil : value
            case "artist": chart.artist = value.isEmpty ? nil : value
            case "key": chart.key = value.isEmpty ? nil : value
            case "tempo":
                let digits = value.prefix { $0.isNumber || $0 == "." || $0 == "," }.replacingOccurrences(of: ",", with: ".")
                if let bpm = Double(digits), (20...400).contains(bpm) { chart.tempo = bpm }
            case "time": chart.meter = ChartMeter(value) ?? chart.meter
            case "capo":
                if let capo = Int(value.prefix { $0.isNumber }), (0...12).contains(capo) { chart.capo = capo }
            case "meta":
                let parts = value.split(separator: " ", maxSplits: 1).map(String.init)
                if parts.count == 2 { apply(parts[0].lowercased(), parts[1].trimmingCharacters(in: .whitespaces)) }
            case "album", "year", "composer", "lyricist", "copyright", "duration", "arranger":
                if !value.isEmpty { chart.extras[name] = value }
            case "comment", "c", "comment_italic", "ci", "comment_box", "cb", "highlight", "guitar_comment", "gc":
                if !value.isEmpty { append(.comment(value)) }
            case "soc", "start_of_chorus": open(.chorus, label: ChordProParser.label(value))
            case "sov", "start_of_verse": open(.verse, label: ChordProParser.label(value))
            case "sob", "start_of_bridge": open(.bridge, label: ChordProParser.label(value))
            case "sot", "start_of_tab": open(.tab, label: ChordProParser.label(value))
            case "sog", "start_of_grid": open(.grid, label: ChordProParser.label(value))
            case "eoc", "end_of_chorus", "eov", "end_of_verse", "eob", "end_of_bridge", "eot", "end_of_tab", "eog", "end_of_grid":
                close()
            case "chorus":
                close()
                if var repeated = lastChorus {
                    repeated.isRepeat = true
                    if let label = ChordProParser.label(value) { repeated.label = label }
                    chart.sections.append(repeated)
                } else {
                    chart.sections.append(ChartSection(kind: .chorus, label: ChordProParser.label(value), isRepeat: true))
                }
            default:
                if name.hasPrefix("start_of_") {
                    let custom = String(name.dropFirst("start_of_".count)).replacingOccurrences(of: "_", with: " ")
                    open(.other, label: ChordProParser.label(value) ?? custom.capitalized)
                } else if name.hasPrefix("end_of_") {
                    close()
                }
            }
        }

        var hasContent: Bool { !chart.sections.isEmpty || current?.hasContent == true }

        mutating func open(_ kind: ChartSection.Kind, label: String?) {
            close()
            current = ChartSection(kind: kind, label: label)
        }

        mutating func close() {
            guard var section = current else { return }
            current = nil
            section.lines = Self.trimmed(section.lines)
            guard section.hasContent || section.label != nil else { return }
            if section.kind == .chorus { lastChorus = section }
            chart.sections.append(section)
        }

        mutating func append(_ line: ChartLine) {
            if current == nil {
                // A blank line between loose lines ends a paragraph: the next one is its own section.
                if line == .blank { return }
                current = ChartSection(kind: .untitled)
            }
            if line == .blank, current?.kind == ChartSection.Kind.untitled, current?.hasContent == true {
                close()
                return
            }
            if line == .blank, current?.lines.last == .blank { return }
            current?.lines.append(line)
        }

        mutating func finish() -> ChordChart {
            close()
            chart.title = chart.title.trimmingCharacters(in: .whitespaces)
            return chart
        }

        /// Without blank lines at either end.
        static func trimmed(_ lines: [ChartLine]) -> [ChartLine] {
            var out = lines
            while out.first == .blank { out.removeFirst() }
            while out.last == .blank { out.removeLast() }
            return out
        }
    }
}

// MARK: - Bringing a file in

/// Turns whatever the player brings (a ChordPro file, a chord sheet copied from the web with chords over the words,
/// a text file of either) into ChordPro text, the form every chart is stored in.
public enum ChordProImport {
    /// Line ends to "\n", no byte-order mark, no zero-width characters, tabs to spaces (stops of 8, as chord sites
    /// line chords up), trailing spaces off.
    public static func normalize(_ text: String) -> String {
        var out = text.replacingOccurrences(of: "\u{FEFF}", with: "")
            .replacingOccurrences(of: "\u{200B}", with: "")
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
            .replacingOccurrences(of: "\u{2028}", with: "\n")
        if out.contains("\t") {
            out = out.components(separatedBy: "\n").map(expandTabs).joined(separator: "\n")
        }
        return out.components(separatedBy: "\n").map { line in
            var trimmed = line
            while trimmed.last == " " { trimmed.removeLast() }
            return trimmed
        }.joined(separator: "\n")
    }

    private static func expandTabs(_ line: String) -> String {
        guard line.contains("\t") else { return line }
        var out = ""
        for character in line {
            if character == "\t" {
                let spaces = 8 - out.count % 8
                out += String(repeating: " ", count: spaces)
            } else {
                out.append(character)
            }
        }
        return out
    }

    /// ChordPro when it has a directive line, or a bracketed chord that isn't a whole-line section name.
    public static func looksLikeChordPro(_ text: String) -> Bool {
        for line in text.components(separatedBy: "\n") {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if ChordProParser.directive(trimmed) != nil { return true }
            if sectionHeader(trimmed) != nil { continue }
            for segment in ChordProParser.segments(trimmed) where segment.chord.map({ ChordSymbol($0) != nil }) == true {
                return true
            }
        }
        return false
    }

    /// The text as ChordPro: a ChordPro file comes back normalised; anything else is read as a chord sheet (chords on
    /// their own lines over the words) and rewritten with each chord in brackets where it sat over the words. Section
    /// names ("[Chorus]", "Verse 2:") become sections, "Capo 2", "Key: G" and "Tempo: 96" become directives, and runs
    /// of tab lines become tab sections. The title is `fallbackTitle` (the file's name), else the first line when it
    /// reads like one ("Artist - Title" fills in both).
    public static func convert(_ source: String, fallbackTitle: String?) -> String {
        let text = normalize(source)
        if looksLikeChordPro(text) {
            guard ChordProParser.parse(text).title.isEmpty, let fallbackTitle, !fallbackTitle.isEmpty else { return text }
            return "{title: \(fallbackTitle)}\n" + text
        }
        var lines = text.components(separatedBy: "\n")
        var header: [String] = []
        var title = fallbackTitle?.trimmingCharacters(in: .whitespaces) ?? ""
        var artist: String?
        // The first line names the song when it isn't music: "Wonderwall", "Oasis - Wonderwall". A first line of
        // lyrics runs straight on into the next one, so a bare title must stand apart (a blank line or the music after
        // it), or match the file's name.
        if let first = lines.firstIndex(where: { !$0.trimmingCharacters(in: .whitespaces).isEmpty }) {
            let candidate = lines[first].trimmingCharacters(in: .whitespaces)
            let isMusic = chordLine(candidate) != nil || sectionHeader(candidate) != nil || isTabLine(candidate) || metadata(candidate) != nil
            let next = first + 1 < lines.count ? lines[first + 1].trimmingCharacters(in: .whitespaces) : ""
            let standsApart = next.isEmpty || chordLine(next) != nil || sectionHeader(next) != nil || metadata(next) != nil
            let named = candidate.contains(" - ") || candidate.range(of: " by ", options: .caseInsensitive) != nil
            let matchesFile = !title.isEmpty && candidate.localizedCaseInsensitiveContains(title)
            if !isMusic, candidate.count <= 70, matchesFile || (named && standsApart) || (title.isEmpty && (standsApart || named)) {
                let dash = candidate.components(separatedBy: " - ")
                if dash.count == 2 {
                    artist = dash[0].trimmingCharacters(in: .whitespaces)
                    title = dash[1].trimmingCharacters(in: .whitespaces)
                } else if let by = candidate.range(of: " by ", options: .caseInsensitive) {
                    title = String(candidate[..<by.lowerBound]).trimmingCharacters(in: .whitespaces)
                    artist = String(candidate[by.upperBound...]).trimmingCharacters(in: .whitespaces)
                } else {
                    title = candidate
                }
                lines.removeSubrange(0...first)
            }
        }
        if !title.isEmpty { header.append("{title: \(title)}") }
        if let artist, !artist.isEmpty { header.append("{artist: \(artist)}") }

        var body: [String] = []
        var openSection: String?
        var inTab = false
        func closeSection() {
            if let open = openSection { body.append("{end_of_\(open)}") }
            openSection = nil
        }
        var index = 0
        while index < lines.count {
            let line = lines[index]
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if isTabLine(trimmed) {
                if !inTab { closeSection(); body.append("{start_of_tab}"); inTab = true }
                body.append(line)
                index += 1
                continue
            }
            if inTab { body.append("{end_of_tab}"); inTab = false }
            if let directive = metadata(trimmed) {
                header.append(directive)
                index += 1
                continue
            }
            if let section = sectionHeader(trimmed) {
                closeSection()
                body.append("{start_of_\(section.kind): \(section.label)}")
                openSection = section.kind
                index += 1
                continue
            }
            if let chords = chordLine(line) {
                let next = index + 1 < lines.count ? lines[index + 1] : ""
                let nextTrimmed = next.trimmingCharacters(in: .whitespaces)
                let nextIsWords = !nextTrimmed.isEmpty && chordLine(next) == nil && sectionHeader(nextTrimmed) == nil
                    && !isTabLine(nextTrimmed) && metadata(nextTrimmed) == nil
                if nextIsWords {
                    body.append(merge(chords, into: next))
                    index += 2
                } else {
                    body.append(chordRow(chords))
                    index += 1
                }
                continue
            }
            body.append(line)
            index += 1
        }
        if inTab { body.append("{end_of_tab}") }
        closeSection()
        // Blank lines at the ends of the body add nothing.
        while body.first?.trimmingCharacters(in: .whitespaces).isEmpty == true { body.removeFirst() }
        while body.last?.trimmingCharacters(in: .whitespaces).isEmpty == true { body.removeLast() }
        return (header + (header.isEmpty ? [] : [""]) + body).joined(separator: "\n")
    }

    /// A chord written over the words, at its column.
    struct PlacedChord: Equatable {
        let column: Int
        let text: String
    }

    /// The chords of a line that holds only chords (with bar lines, repeat marks and "N.C." allowed among them), each at
    /// its column; nil for any other line.
    static func chordLine(_ line: String) -> [PlacedChord]? {
        let characters = Array(line)
        var placed: [PlacedChord] = []
        var index = 0
        var sawChord = false
        while index < characters.count {
            if characters[index] == " " { index += 1; continue }
            let start = index
            while index < characters.count && characters[index] != " " { index += 1 }
            var token = String(characters[start..<index])
            if isFiller(token) { continue }
            // "(G)" and "G*" are still chords.
            if token.hasPrefix("(") && token.hasSuffix(")") && token.count > 2 { token = String(token.dropFirst().dropLast()) }
            while token.hasSuffix("*") { token.removeLast() }
            guard ChordSymbol(token) != nil else { return nil }
            sawChord = true
            placed.append(PlacedChord(column: start, text: token))
        }
        return sawChord ? placed : nil
    }

    private static func isFiller(_ token: String) -> Bool {
        let lower = token.lowercased()
        if ["|", "||", "|:", ":|", "/", "//", "-", "--", "%", ".", "..", "...", "n.c.", "nc", "n.c", "(n.c.)", "x", "*"].contains(lower) { return true }
        // Repeat counts: "x2", "2x", "(x3)", "[x4]".
        let core = lower.trimmingCharacters(in: CharacterSet(charactersIn: "()[]"))
        if core.hasPrefix("x"), Int(core.dropFirst()) != nil { return true }
        if core.hasSuffix("x"), Int(core.dropLast()) != nil { return true }
        return lower.allSatisfy { $0 == "|" || $0 == "-" || $0 == "/" || $0 == ":" }
    }

    /// The words with each chord in brackets at its column; chords past the end of the words go after them.
    static func merge(_ chords: [PlacedChord], into words: String) -> String {
        var characters = Array(words)
        for chord in chords.sorted(by: { $0.column > $1.column }) {
            if chord.column > characters.count {
                characters += Array(repeating: " ", count: chord.column - characters.count)
            }
            characters.insert(contentsOf: Array("[\(chord.text)]"), at: chord.column)
        }
        var out = String(characters)
        while out.last == " " { out.removeLast() }
        return out
    }

    /// A row of chords alone, spaced as written (at least two spaces apart).
    static func chordRow(_ chords: [PlacedChord]) -> String {
        var out = ""
        var column = 0
        for chord in chords {
            let gap = max(out.isEmpty ? 0 : 2, chord.column - column)
            out += String(repeating: " ", count: gap) + "[\(chord.text)]"
            column = chord.column + chord.text.count
        }
        return out.trimmingCharacters(in: .whitespaces)
    }

    /// The section kinds a converted chart uses and the words that name them.
    private static let sectionWords: [(words: [String], kind: String)] = [
        (["chorus", "refrain", "hook", "estribillo", "coro", "refrão", "ritornello"], "chorus"),
        (["pre-chorus", "prechorus", "pre chorus", "bridge", "puente", "ponte", "middle 8"], "bridge"),
        (["verse", "verso", "strophe", "couplet", "estrofa", "intro", "outro", "solo", "interlude", "instrumental",
          "coda", "tag", "ending", "break", "riff"], "verse"),
    ]

    /// A line that only names a section: "[Chorus]", "[Verse 2]", "Chorus:", "INTRO", "(Bridge)". The kind is the
    /// directive's (`chorus`, `bridge`, `verse`); the label is the name as written, tidied.
    static func sectionHeader(_ line: String) -> (kind: String, label: String)? {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty, trimmed.count <= 32 else { return nil }
        var name = trimmed
        if (name.hasPrefix("[") && name.hasSuffix("]")) || (name.hasPrefix("(") && name.hasSuffix(")")) {
            name = String(name.dropFirst().dropLast())
        }
        if name.hasSuffix(":") { name = String(name.dropLast()) }
        name = name.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty, ChordSymbol(name) == nil else { return nil }
        let lower = name.lowercased()
        // The name, then at most a number or a repeat mark: "Verse 2", "Chorus x2", "Intro (x2)".
        for entry in sectionWords {
            for word in entry.words where lower.hasPrefix(word) {
                let rest = lower.dropFirst(word.count).trimmingCharacters(in: .whitespaces)
                let allowed = rest.isEmpty || rest.allSatisfy { $0.isNumber || $0 == "x" || $0 == "(" || $0 == ")" || $0 == " " || $0 == "#" || $0 == "." }
                guard allowed else { continue }
                let label = name.prefix(1).uppercased() + name.dropFirst()
                return (entry.kind, label)
            }
        }
        return nil
    }

    /// A line of guitar or bass tab: a string name, a bar and dashes ("e|--0--3--|", "E|-----").
    static func isTabLine(_ line: String) -> Bool {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        guard trimmed.count >= 6, let bar = trimmed.firstIndex(of: "|") else { return false }
        let name = trimmed[..<bar].trimmingCharacters(in: .whitespaces)
        guard name.count <= 2, let letter = name.first, "eEaAdDgGbBcCfF".contains(letter) else { return false }
        let body = trimmed[trimmed.index(after: bar)...]
        let dashes = body.filter { $0 == "-" }.count
        let allowed = body.allSatisfy { $0.isNumber || "-|hpbrs/\\~x()<>.^ v".contains($0) }
        return allowed && dashes * 2 >= body.count
    }

    /// "Capo 2", "Capo: 3rd fret", "Key: G", "Tempo: 96", "BPM 120", "Time: 3/4" as a directive line; nil otherwise.
    static func metadata(_ line: String) -> String? {
        let lower = line.lowercased().trimmingCharacters(in: .whitespaces)
        guard lower.count <= 40 else { return nil }
        func value(after word: String) -> String? {
            guard lower.hasPrefix(word) else { return nil }
            let rest = line.trimmingCharacters(in: .whitespaces).dropFirst(word.count)
            let cleaned = rest.trimmingCharacters(in: CharacterSet(charactersIn: " :=-"))
            return cleaned.isEmpty ? nil : cleaned
        }
        if let capo = value(after: "capo") {
            let lowerCapo = capo.lowercased()
            if lowerCapo.hasPrefix("no") { return "{capo: 0}" }
            if let fret = Int(capo.prefix { $0.isNumber }) { return "{capo: \(fret)}" }
            return nil
        }
        if let key = value(after: "key"), ChordSpelling.key(key) != nil || ChordSymbol(key) != nil { return "{key: \(key)}" }
        for word in ["tempo", "bpm"] {
            if let tempo = value(after: word), let bpm = Int(tempo.prefix { $0.isNumber }), (20...400).contains(bpm) { return "{tempo: \(bpm)}" }
        }
        if let time = value(after: "time"), let meter = ChartMeter(time) { return "{time: \(meter.text)}" }
        return nil
    }
}

// MARK: - Editing the text

/// Changes made in the editor, made to the ChordPro text itself so everything the author wrote around them stays.
public enum ChordProEdit {
    /// Sets (or, with an empty value, removes) a directive: the first `{name: …}` (or a short form of it) is replaced;
    /// a new one goes after the other details at the top.
    public static func setDirective(_ name: String, _ value: String?, in source: String) -> String {
        var lines = ChordProImport.normalize(source).components(separatedBy: "\n")
        let aliases = Self.aliases(name)
        let cleaned = value?.trimmingCharacters(in: .whitespaces).replacingOccurrences(of: "}", with: "") ?? ""
        let replacement = "{\(name): \(cleaned)}"
        if let at = lines.firstIndex(where: { line in ChordProParser.directive(line).map { aliases.contains($0.name) } ?? false }) {
            if cleaned.isEmpty { lines.remove(at: at) } else { lines[at] = replacement }
            return lines.joined(separator: "\n")
        }
        guard !cleaned.isEmpty else { return lines.joined(separator: "\n") }
        // After the leading details (title, artist, key …), before the music.
        let metadata: Set<String> = ["title", "t", "subtitle", "st", "artist", "key", "tempo", "time", "capo", "album", "year", "composer", "meta"]
        var insert = 0
        for (index, line) in lines.enumerated() {
            if let directive = ChordProParser.directive(line), metadata.contains(directive.name) { insert = index + 1; continue }
            if line.trimmingCharacters(in: .whitespaces).isEmpty || line.trimmingCharacters(in: .whitespaces).hasPrefix("#") { continue }
            break
        }
        lines.insert(replacement, at: insert)
        return lines.joined(separator: "\n")
    }

    private static func aliases(_ name: String) -> Set<String> {
        switch name {
        case "title": return ["title", "t"]
        case "subtitle": return ["subtitle", "st", "su"]
        default: return [name]
        }
    }

    /// A word of a lyric line in the text, for tapping a chord onto it: where it starts in the source line (after any
    /// chords before it), the chord already on it, and the word as shown.
    public struct Word: Equatable, Hashable, Sendable {
        /// The line's index in the text.
        public let line: Int
        /// Character offset in that line where the word (or the chord in front of it) starts.
        public let offset: Int
        public let text: String
        public let chord: String?
    }

    /// The text's lyric lines split into words: one row per lyric line (directives, comments, tabs and blank lines
    /// left out), each word with the chord placed on it, if any. A chord standing alone (no words under it) is a word
    /// of its own with empty text.
    public static func words(in source: String) -> [[Word]] {
        let lines = ChordProImport.normalize(source).components(separatedBy: "\n")
        var rows: [[Word]] = []
        var inTab = false
        for (number, line) in lines.enumerated() {
            if let directive = ChordProParser.directive(line) {
                if ["sot", "start_of_tab", "sog", "start_of_grid"].contains(directive.name) { inTab = true }
                if ["eot", "end_of_tab", "eog", "end_of_grid"].contains(directive.name) { inTab = false }
                continue
            }
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if inTab || trimmed.isEmpty || trimmed.hasPrefix("#") { continue }
            rows.append(words(ofLine: line, number: number))
        }
        return rows
    }

    static func words(ofLine line: String, number: Int) -> [Word] {
        let characters = Array(line)
        var out: [Word] = []
        var index = 0
        var pendingChord: String?
        var pendingStart: Int?
        while index < characters.count {
            let character = characters[index]
            if character == "[", let close = characters[(index + 1)...].firstIndex(of: "]") {
                if let chord = pendingChord, let start = pendingStart {
                    out.append(Word(line: number, offset: start, text: "", chord: chord))
                }
                pendingChord = String(characters[(index + 1)..<close]).trimmingCharacters(in: .whitespaces)
                pendingStart = index
                index = close + 1
                continue
            }
            if character == " " {
                if let chord = pendingChord, let start = pendingStart, index < characters.count, (index + 1 >= characters.count || characters[index + 1] == " " || characters[index + 1] == "[") {
                    out.append(Word(line: number, offset: start, text: "", chord: chord))
                    pendingChord = nil
                    pendingStart = nil
                }
                index += 1
                continue
            }
            let start = pendingStart ?? index
            var end = index
            while end < characters.count && characters[end] != " " && characters[end] != "[" { end += 1 }
            out.append(Word(line: number, offset: start, text: String(characters[index..<end]), chord: pendingChord))
            pendingChord = nil
            pendingStart = nil
            index = end
        }
        if let chord = pendingChord, let start = pendingStart { out.append(Word(line: number, offset: start, text: "", chord: chord)) }
        return out
    }

    /// Puts `chord` on `word` (replacing the chord it had), or takes its chord off when `chord` is nil.
    public static func setChord(_ chord: String?, on word: Word, in source: String) -> String {
        var lines = ChordProImport.normalize(source).components(separatedBy: "\n")
        guard lines.indices.contains(word.line) else { return source }
        var characters = Array(lines[word.line])
        guard word.offset <= characters.count else { return source }
        // Take off the chord in front of the word, if there is one.
        if word.chord != nil, word.offset < characters.count, characters[word.offset] == "[",
           let close = characters[(word.offset + 1)...].firstIndex(of: "]") {
            characters.removeSubrange(word.offset...close)
        }
        if let chord = chord?.trimmingCharacters(in: .whitespaces), !chord.isEmpty {
            characters.insert(contentsOf: Array("[\(chord)]"), at: word.offset)
        }
        lines[word.line] = String(characters)
        return lines.joined(separator: "\n")
    }

    /// A new chart's text: its details, then the words as typed (each line as a lyric line).
    public static func newChart(title: String, artist: String?, lyrics: String) -> String {
        var lines = ["{title: \(title.trimmingCharacters(in: .whitespaces))}"]
        if let artist = artist?.trimmingCharacters(in: .whitespaces), !artist.isEmpty { lines.append("{artist: \(artist)}") }
        lines.append("")
        lines.append(ChordProImport.normalize(lyrics))
        return lines.joined(separator: "\n")
    }
}
