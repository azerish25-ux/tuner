import SwiftUI
import TimbreCore
import UIKit

// MARK: - The song, read from its lesson

/// A song lesson read as a song: the take it ends on (tempo, meter, bars, length), its key, every chord it asks for,
/// its melody and its sections. A whole arrangement (`Lesson.arrangement`) gives all of it: its sections in playing
/// order ("Intro", "Verse 1", "Chorus"), its length in bars and seconds, and the chords of its chart. Without one,
/// nothing is made up: sections come from the lesson's own play-alongs, each one whose notes run, in order, inside the
/// final take naming that stretch of bars ("The verse", "The hook"); bars no play-along names stay plain ("Bars
/// 5–8"), and a song with none shows its phrases of four bars. A song that ends on a chord progression maps its
/// chords instead. Built once per lesson (`of`).
struct SongSheet {
    struct Section: Identifiable, Equatable {
        let id: Int
        /// The arrangement's name for the section, or the play-along that names these bars; nil for plain bars.
        let title: LearnText?
        /// The chord the bars hold (a song that ends on a progression).
        let chord: ChordSpec?
        /// First bar (0-based) and how many bars it runs.
        let start: Int
        let bars: Int
        /// The arrangement's own section (its kind, the upbeat it starts on); nil for a song without one.
        var part: SongArrangement.Section? = nil
    }

    /// The final take's tempo and meter.
    let bpm: Double
    let beatsPerBar: Int
    /// Bars of the final take.
    let bars: Int
    /// Seconds the final take runs at its tempo.
    let seconds: Double
    /// The final take's notes from beat 0; empty when the song ends on a chord progression.
    let finale: [TimedNote]
    /// The melody: the final take, else the lesson's last play-along (at `melodyBpm` in `melodyMeter`).
    let melody: [TimedNote]
    let melodyBpm: Double
    let melodyMeter: Int
    let key: (tonic: Int, minor: Bool)?
    /// Every chord the lesson asks for, once each, in the order they first come.
    let chords: [ChordSpec]
    let sections: [Section]
    /// Notes per second of the final take (strokes per second for a progression).
    let density: Double
    /// The whole arrangement the sheet is read from, when the lesson ends on the whole song with one.
    let arrangement: SongArrangement?

    @MainActor private static var cache: [String: SongSheet] = [:]

    /// The lesson's sheet, read once and kept (it depends on nothing but the curriculum).
    @MainActor static func of(_ lesson: Lesson) -> SongSheet {
        if let known = cache[lesson.id] { return known }
        let sheet = SongSheet(lesson: lesson)
        if cache.count > 400 { cache.removeAll() }
        cache[lesson.id] = sheet
        return sheet
    }

    init(lesson: Lesson) {
        var chords: [ChordSpec] = []
        var timeline: [(chord: ChordSpec, bars: Int)] = []
        var parts: [(title: LearnText?, notes: [TimedNote], bpm: Double, meter: Int)] = []
        for step in lesson.steps {
            switch step {
            case let .explain(_, _, visual), let .quiz(_, _, _, _, visual):
                if case let .chord(spec) = visual { Self.keep(spec, in: &chords) }
            case let .playChord(chord):
                Self.keep(chord, in: &chords)
                timeline.append((chord: chord, bars: 1))
            case let .strum(chord, _, _, bars, _, _, _):
                if let chord {
                    Self.keep(chord, in: &chords)
                    timeline.append((chord: chord, bars: max(1, bars)))
                }
            case let .progression(list, lengths, _, _, _, _, _):
                for (index, chord) in list.enumerated() {
                    Self.keep(chord, in: &chords)
                    timeline.append((chord: chord, bars: index < lengths.count ? max(1, lengths[index]) : 1))
                }
            case let .playAlong(notes, rate, beats, title):
                parts.append((title: title, notes: notes.sorted { $0.beat < $1.beat }, bpm: rate, meter: max(1, beats)))
            default:
                break
            }
        }
        // A whole arrangement's chart names the song's own chords first, in the order they come.
        let arrangement = lesson.songTake != nil ? lesson.arrangement : nil
        if let arrangement {
            var charted = arrangement.shapes
            for chord in chords where !charted.contains(where: { $0.symbol == chord.symbol }) { charted.append(chord) }
            chords = charted
            timeline = Self.runs(arrangement.chordPerBar)
        }
        self.chords = chords
        self.arrangement = arrangement

        var bpm = parts.last?.bpm ?? 80
        var meter = parts.last?.meter ?? 4
        var finale: [TimedNote] = []
        var progression: [(chord: ChordSpec, bars: Int)] = []
        var named: [(title: LearnText?, notes: [TimedNote])] = []
        var strokes = 0.0
        switch lesson.steps.last {
        case let .playAlong(notes, rate, beats, _)?:
            finale = notes.sorted { $0.beat < $1.beat }
            bpm = rate
            meter = max(1, beats)
            named = parts.dropLast().map { (title: $0.title, notes: $0.notes) }
        case let .progression(list, lengths, pattern, rate, beats, _, _)?:
            bpm = rate
            // As the strum step counts it: 4, or longer if the pattern needs it.
            meter = beats ?? max(4, Int((pattern.max() ?? 3) + 1))
            for (index, chord) in list.enumerated() {
                progression.append((chord: chord, bars: index < lengths.count ? max(1, lengths[index]) : 1))
            }
            strokes = Double(pattern.count)
        default:
            break
        }
        let tempo = max(20, bpm)
        self.bpm = tempo
        beatsPerBar = meter
        self.finale = finale

        let melody = finale.isEmpty ? (parts.last?.notes ?? []) : finale
        let melodyTempo = finale.isEmpty ? max(20, parts.last?.bpm ?? tempo) : tempo
        let melodyBar = finale.isEmpty ? (parts.last?.meter ?? meter) : meter
        self.melody = melody
        melodyBpm = melodyTempo
        melodyMeter = melodyBar
        key = KeyEstimate.key(of: melody, chords: timeline)

        if let arrangement, !finale.isEmpty {
            // The arrangement's own bars and length (an outro's last chord rings past its last note).
            let count = max(1, arrangement.bars)
            let length = arrangement.seconds
            bars = count
            seconds = length
            density = length > 0 ? Double(finale.count) / length : 0
            sections = Self.sections(of: arrangement)
        } else if !finale.isEmpty {
            let end = finale.map { $0.beat + $0.beats }.max() ?? Double(meter)
            let count = max(1, Int((end / Double(meter) - 1e-6).rounded(.up)))
            let length = end * 60 / tempo
            bars = count
            seconds = length
            density = length > 0 ? Double(finale.count) / length : 0
            sections = Self.sections(finale: finale, meter: meter, bars: count, parts: named, song: lesson.title)
        } else if !progression.isEmpty {
            let count = max(1, progression.reduce(0) { $0 + $1.bars })
            bars = count
            seconds = Double(count * meter) * 60 / tempo
            density = strokes / (Double(meter) * 60 / tempo)
            sections = Self.chordSections(progression, bars: count)
        } else {
            let end = melody.map { $0.beat + $0.beats }.max() ?? 0
            let count = max(1, Int((end / Double(melodyBar) - 1e-6).rounded(.up)))
            let length = end * 60 / melodyTempo
            bars = count
            seconds = length
            density = length > 0 ? Double(melody.count) / length : 0
            sections = Self.phrases(bars: count)
        }
    }

    private static func keep(_ chord: ChordSpec, in chords: inout [ChordSpec]) {
        if !chords.contains(where: { $0.symbol == chord.symbol }) { chords.append(chord) }
    }

    /// A chart's chords bar by bar as runs (a chord held over several bars counting once), for the key.
    private static func runs(_ perBar: [ChordSpec?]) -> [(chord: ChordSpec, bars: Int)] {
        var runs: [(chord: ChordSpec, bars: Int)] = []
        for entry in perBar {
            guard let chord = entry else { continue }
            if let last = runs.last, last.chord.symbol == chord.symbol {
                runs[runs.count - 1].bars += 1
            } else {
                runs.append((chord: chord, bars: 1))
            }
        }
        return runs
    }

    // MARK: Sections

    /// The arrangement's sections as the song plays them, each named ("Verse 1", "Chorus") over its bars.
    private static func sections(of arrangement: SongArrangement) -> [Section] {
        arrangement.sections.enumerated().map { index, part in
            Section(id: index, title: part.name, chord: nil, start: part.bar, bars: max(1, part.bars), part: part)
        }
    }

    /// A section as its loop on the song sheet plays it: from beat 0 of its first bar and exactly its bars long. With
    /// an arrangement, the upbeat it starts on (sounding in the bar before) closes each pass, leading into the next,
    /// and the next section's upbeat stays out; without one, the notes that start in its bars.
    func loopMelody(_ section: Section) -> [TimedNote] {
        let meter = max(1, beatsPerBar)
        guard let arrangement, let part = section.part else {
            let from = Double(section.start * meter)
            let to = Double((section.start + section.bars) * meter)
            return finale.filter { $0.beat >= from - 1e-6 && $0.beat < to - 1e-6 }
                .map { TimedNote(midi: $0.midi, beat: $0.beat - from, beats: $0.beats, at: $0.at) }
        }
        let from = arrangement.startBeat(of: part)
        let to = arrangement.endBeat(of: part)
        let origin = Double(part.bar * meter)
        let length = Double(max(1, part.bars) * meter)
        return finale.filter { $0.beat >= from - 1e-6 && $0.beat < to - 1e-6 }
            .map { note -> TimedNote in
                var beat = note.beat - origin
                if beat < -1e-6 { beat += length }
                return TimedNote(midi: note.midi, beat: beat, beats: max(0.05, min(note.beats, length - beat)), at: note.at)
            }
            .sorted { $0.beat < $1.beat }
    }

    /// How many times through a part's practice play-along goes: four for a short part, down to once for a long one
    /// (about sixteen bars in all).
    static func passes(bars: Int) -> Int { max(1, min(4, 16 / max(1, bars))) }

    /// The play-alongs found in the final take, in bar order, with the bars between them left plain. A play-along of
    /// (nearly) the whole song is the song, not a section of it; one named like the song itself names nothing.
    private static func sections(finale: [TimedNote], meter: Int, bars: Int, parts: [(title: LearnText?, notes: [TimedNote])],
                                 song: LearnText) -> [Section] {
        let sequence = finale.map(\.midi)
        let songName = CoverArt.mainTitle(song.defaultValue).lowercased()
        var found: [(start: Int, end: Int, title: LearnText?)] = []
        for part in parts {
            let melody = part.notes.map(\.midi)
            guard melody.count >= 3, let index = Self.firstIndex(of: melody, in: sequence) else { continue }
            let first = finale[index], last = finale[index + melody.count - 1]
            let start = Int((first.beat / Double(meter) + 1e-6).rounded(.down))
            let end = min(bars, Int(((last.beat + last.beats) / Double(meter) - 1e-6).rounded(.up)))
            guard end > start, Double(end - start) < Double(bars) * 0.9 else { continue }
            let title = part.title.flatMap { CoverArt.mainTitle($0.defaultValue).lowercased() == songName ? nil : $0 }
            found.append((start: start, end: end, title: title))
        }
        found.sort { $0.start < $1.start }
        var kept: [(start: Int, end: Int, title: LearnText?)] = []
        for item in found {
            if let previous = kept.last, item.start < previous.end { continue }
            kept.append(item)
        }
        guard kept.contains(where: { $0.title != nil }) else { return Self.phrases(bars: bars) }
        var spans: [(start: Int, end: Int, title: LearnText?)] = []
        var cursor = 0
        for item in kept {
            if item.start > cursor { spans.append((start: cursor, end: item.start, title: nil)) }
            spans.append(item)
            cursor = item.end
        }
        if cursor < bars { spans.append((start: cursor, end: bars, title: nil)) }
        return spans.enumerated().map { Section(id: $0.offset, title: $0.element.title, chord: nil, start: $0.element.start, bars: $0.element.end - $0.element.start) }
    }

    /// Phrases of four bars (two on a short song, eight on a long one), the last taking what is left.
    static func phrases(bars: Int) -> [Section] {
        guard bars >= 4 else { return [Section(id: 0, title: nil, chord: nil, start: 0, bars: max(1, bars))] }
        var size = bars >= 8 ? 4 : 2
        while bars / size > 8 { size *= 2 }
        let count = max(1, bars / size)
        return (0..<count).map { index in
            Section(id: index, title: nil, chord: nil, start: index * size, bars: index == count - 1 ? bars - index * size : size)
        }
    }

    /// A progression's chords as they run, a chord held over several entries counting once; phrases when there
    /// are too many changes to read.
    private static func chordSections(_ progression: [(chord: ChordSpec, bars: Int)], bars: Int) -> [Section] {
        var runs: [(chord: ChordSpec, start: Int, bars: Int)] = []
        var cursor = 0
        for entry in progression {
            if let last = runs.last, last.chord.symbol == entry.chord.symbol {
                runs[runs.count - 1].bars += entry.bars
            } else {
                runs.append((chord: entry.chord, start: cursor, bars: entry.bars))
            }
            cursor += entry.bars
        }
        guard (2...8).contains(runs.count) else { return Self.phrases(bars: bars) }
        return runs.enumerated().map { Section(id: $0.offset, title: nil, chord: $0.element.chord, start: $0.element.start, bars: $0.element.bars) }
    }

    private static func firstIndex(of part: [Int], in whole: [Int]) -> Int? {
        guard !part.isEmpty, part.count <= whole.count else { return nil }
        for start in 0...(whole.count - part.count) where whole[start] == part[0] {
            if Array(whole[start..<(start + part.count)]) == part { return start }
        }
        return nil
    }

    // MARK: For display

    /// "G major", "E minor", in the player's note names.
    var keyName: String? {
        guard let key else { return nil }
        let name = NoteName.pitchClass(key.tonic)
        return key.minor ? String(localized: "\(name) minor", bundle: TimbreLocalization.bundle)
                         : String(localized: "\(name) major", bundle: TimbreLocalization.bundle)
    }

    /// "4/4", "3/4"; dotted meters ("6/8") in eighths.
    var meterName: String { beatsPerBar >= 6 && beatsPerBar % 3 == 0 ? "\(beatsPerBar)/8" : "\(beatsPerBar)/4" }

    /// The final take's length, "0:22".
    var length: String { Duration.seconds(max(1, seconds.rounded())).formatted(.time(pattern: .minuteSecond)) }

    /// The melody's notes, once each, low to high.
    var noteSet: [Int] { Array(Set(melody.map(\.midi))).sorted() }

    /// How demanding the song is, 1 to 3: how far into its course it comes (`unit` of `units`, which is how the
    /// course grades it), how busy its final take is, and how many chords it asks for.
    func difficulty(unit: Int, of units: Int) -> Int {
        let position = Double(unit) / Double(max(1, units - 1))
        let busy = min(1, max(0, (density - 0.8) / 1.4))
        let harmony = min(1, max(0, Double(chords.count - 2) / 4))
        let raw = 0.5 * position + 0.35 * busy + 0.15 * harmony
        return raw < 0.3 ? 1 : raw < 0.6 ? 2 : 3
    }

    /// "E minor" for a minor chord, "G major" for a major one, the symbol for the rest ("D7", "Cmaj7").
    static func spoken(_ chord: ChordSpec) -> String {
        let name = NoteName.pitchClass(chord.root)
        switch chord.quality {
        case "maj": return String(localized: "\(name) major", bundle: TimbreLocalization.bundle)
        case "min": return String(localized: "\(name) minor", bundle: TimbreLocalization.bundle)
        default: return chord.name
        }
    }
}

// MARK: - A chord box for a strip

/// A chord box small enough for a strip of them: the nut (or the first fret's number), the strings, a dot per fretted
/// string (a bar where one finger holds several), open and muted marks above. Its name sits beside it, so the drawing
/// is hidden from VoiceOver.
struct MiniChordGlyph: View {
    let chord: ChordSpec
    var accent: Color = Palette.mint
    /// The chord is sounding: its strings light.
    var lit = false

    var body: some View {
        Canvas { context, size in draw(&context, size: size) }
            .accessibilityHidden(true)
    }

    private func draw(_ context: inout GraphicsContext, size: CGSize) {
        let count = chord.frets.count
        guard count >= 2, size.width > 10, size.height > 16 else { return }
        let rows = 4
        let base = max(1, chord.baseFret ?? 1)
        let top: CGFloat = 12, bottom = size.height - 2
        let left: CGFloat = base > 1 ? 14 : 5, right = size.width - 5
        let gap = (right - left) / CGFloat(count - 1)
        let row = (bottom - top) / CGFloat(rows)
        let radius = max(2, min(gap, row) * 0.36)
        let string = lit ? accent : Palette.inkSoft
        for r in 0...rows {
            let y = top + CGFloat(r) * row
            context.fill(Path(CGRect(x: left, y: y - 0.5, width: right - left, height: 1)), with: .color(Palette.inkSoft.opacity(0.4)))
        }
        if base == 1 {
            context.fill(Path(roundedRect: CGRect(x: left - 1, y: top - 2.5, width: right - left + 2, height: 3), cornerRadius: 1), with: .color(Palette.ink))
        } else {
            context.draw(Text(verbatim: "\(base)").font(.system(size: 10, weight: .bold, design: .rounded)).foregroundStyle(Palette.inkSoft),
                         at: CGPoint(x: left - 8, y: top + row / 2))
        }
        for i in 0..<count {
            let x = left + CGFloat(i) * gap
            let weight = 0.6 + 0.9 * CGFloat(count - 1 - i) / CGFloat(count - 1)
            context.fill(Path(CGRect(x: x - weight / 2, y: top, width: weight, height: bottom - top)), with: .color(string.opacity(lit ? 0.9 : 0.6)))
            let fret = chord.frets[i]
            if fret < 0 {
                context.draw(Text(verbatim: "×").font(.system(size: 9, weight: .bold)).foregroundStyle(Palette.inkFaint), at: CGPoint(x: x, y: 5))
            } else if fret == 0 {
                context.stroke(Path(ellipseIn: CGRect(x: x - 2.4, y: 2.6, width: 4.8, height: 4.8)), with: .color(lit ? accent : Palette.ink), lineWidth: 1)
            }
        }
        // Barres first, then the single dots.
        var barred = Set<Int>()
        if let fingers = chord.fingers {
            for finger in Set(fingers.filter { $0 > 0 }) {
                let held = chord.frets.indices.filter { fingers[safe: $0] == finger && chord.frets[$0] > 0 }
                guard held.count >= 2, let first = held.first, let last = held.last else { continue }
                let fret = chord.frets[first]
                guard held.allSatisfy({ chord.frets[$0] == fret }) else { continue }
                let y = top + (CGFloat(fret - base) + 0.5) * row
                let x0 = left + CGFloat(first) * gap, x1 = left + CGFloat(last) * gap
                let bar = CGRect(x: x0 - radius, y: y - radius, width: x1 - x0 + radius * 2, height: radius * 2)
                context.fill(Path(roundedRect: bar, cornerRadius: radius), with: .color(accent))
                barred.formUnion(held)
            }
        }
        for i in 0..<count where !barred.contains(i) {
            let fret = chord.frets[i]
            guard fret > 0 else { continue }
            let x = left + CGFloat(i) * gap
            let y = top + (CGFloat(fret - base) + 0.5) * row
            context.fill(Path(ellipseIn: CGRect(x: x - radius, y: y - radius, width: radius * 2, height: radius * 2)), with: .color(accent))
        }
    }
}

// MARK: - The song map

extension SongSheet.Section {
    /// The part a song is known by: an arrangement's chorus, or a section its lesson names the hook, the chorus or
    /// the refrain.
    var isHook: Bool {
        if let part { return part.kind == .chorus }
        guard let name = title?.defaultValue.lowercased() else { return false }
        return ["hook", "chorus", "refrain"].contains { name.contains($0) }
    }

    /// An intro or outro: the band's bookends, drawn quieter than the parts with words.
    var isBookend: Bool { part.map { $0.kind == .intro || $0.kind == .outro } ?? false }

    /// The lead sheet's card for the section, to scroll to (a string, apart from the map's own section ids).
    var anchor: String { "leadsheet.section.\(id)" }
}

extension SongSheet {
    /// A section picked on the song sheet to practise on its own, at a share of the song's tempo.
    struct Loop: Equatable {
        let section: Section
        /// 0.5, 0.75 or 1 of the song's tempo.
        let speed: Double
        /// The tempo that makes, in beats per minute.
        let bpm: Double
    }
}

/// The song's sections as one row of tiles, each named and nothing more ("Verse 1", "Chorus", the chord it holds; a
/// glyph for the band's intro and outro), its bars on a long press and to VoiceOver. A tile is as wide as its share of
/// the bars, but never narrower than its name: when the names need more room than the screen has, the row scrolls
/// (to `bleed` past its edges), keeping the section playing, or the one picked, in view. While the song plays,
/// `progress` (0…1 of the song) fills the sections behind a playhead. Given `onSelect`, each section is a button (the
/// song sheet loops it) and `selected` stands out with a loop mark.
struct SongSectionMap: View {
    let sections: [SongSheet.Section]
    let bars: Int
    var accent: Color = Palette.mint
    var progress: Double?
    var height: CGFloat = 50
    /// How far the row may scroll past its own edges (to the screen's), resting aligned with them.
    var bleed: CGFloat = 0
    /// The section looping on the song sheet.
    var selected: Int?
    var onSelect: ((SongSheet.Section) -> Void)?

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// The tile held down (shrunk under the finger), and the one showing its bars.
    @State private var pressed: Int?
    @State private var peek: Int?

    private static let spacing: CGFloat = 4

    var body: some View {
        GeometryReader { proxy in
            ScrollViewReader { reader in
                ScrollView(.horizontal, showsIndicators: false) {
                    SectionRow(available: proxy.size.width, weights: sections.map { max(1, $0.bars) }, spacing: Self.spacing) {
                        ForEach(sections) { section in
                            tile(section).id(section.id)
                        }
                    }
                    .frame(height: proxy.size.height)
                }
                .scrollBounceBehavior(.basedOnSize, axes: .horizontal)
                .railBleed(leading: bleed, trailing: bleed)
                .onAppear {
                    guard let focus else { return }
                    reader.scrollTo(focus, anchor: .center)
                }
                .onChange(of: focus) { _, value in
                    guard let value else { return }
                    withAnimation(reduceMotion ? nil : Motion.settle) { reader.scrollTo(value, anchor: .center) }
                }
            }
        }
        // The song runs left to right in every language, as its playhead and the runway do.
        .environment(\.layoutDirection, .leftToRight)
        .frame(height: height)
        .modifier(MapAccessibility(interactive: onSelect != nil, summary: spokenSections))
    }

    /// The section to keep in view: the one the playhead is in, else the one picked.
    private var focus: Int? {
        if let progress {
            let bar = progress * Double(max(1, bars))
            if let playing = sections.first(where: { bar < Double($0.start + $0.bars) }) { return playing.id }
        }
        return selected
    }

    /// A section: tapped, it loops; held, it shows its bars until let go.
    @ViewBuilder private func tile(_ section: SongSheet.Section) -> some View {
        let tint = Self.tint(of: section, in: sections, accent: accent)
        let content = SectionTile(section: section, tint: tint, fill: fill(of: section), selected: selected == section.id,
                                  peeking: peek == section.id, pressed: pressed == section.id, playing: progress != nil)
        if let onSelect {
            content
                .contentShape(RoundedRectangle(cornerRadius: Metrics.cornerChip, style: .continuous))
                .onTapGesture { onSelect(section) }
                .onLongPressGesture(minimumDuration: 0.35) {
                    Haptics.shared.selection()
                    withAnimation(reduceMotion ? nil : Motion.quick) { peek = section.id }
                } onPressingChanged: { pressing in
                    withAnimation(reduceMotion ? nil : Motion.quick) { pressed = pressing ? section.id : nil }
                    guard !pressing else { return }
                    Task { @MainActor in
                        // Let go: the bars stay a beat, then the name comes back.
                        try? await Task.sleep(for: .seconds(0.9))
                        guard peek == section.id, pressed != section.id else { return }
                        withAnimation(reduceMotion ? nil : Motion.settle) { peek = nil }
                    }
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(Text(verbatim: Self.spoken(section)))
                .accessibilityHint(Text("Loops this part"))
                .accessibilityAddTraits(selected == section.id ? [.isButton, .isSelected] : [.isButton])
                .accessibilityAction { onSelect(section) }
        } else {
            content
        }
    }

    /// The hook (or chorus) always in gold, the other named sections in the accent and the colours after it (the same
    /// name always the same colour), chords in the accent, plain bars in grey. An arrangement's sections are coloured by
    /// kind (`tint(of:accent:)`). The lead sheet uses the same. None is a status colour: mint, amber and coral say how
    /// something went, never which part of a song it is.
    static func tint(of section: SongSheet.Section, in sections: [SongSheet.Section], accent: Color) -> Color {
        if section.chord != nil { return accent }
        if let part = section.part { return tint(of: part.kind, accent: accent) }
        guard let title = section.title else { return Palette.inkSoft }
        if section.isHook { return Palette.starGold }
        let names = sections.filter { !$0.isHook }.compactMap { $0.title?.defaultValue }.reduce(into: [String]()) { list, name in
            if !list.contains(name) { list.append(name) }
        }
        let tints = [accent, Palette.violet, Palette.sky, Palette.orchid]
        let index = names.firstIndex(of: title.defaultValue) ?? 0
        return tints[index % tints.count]
    }

    /// An arrangement's sections by kind: every chorus gold (the hook), the verses in the accent, a bridge violet (sky
    /// beside a violet accent), a solo or interlude sky (orchid beside a sky accent), the intro and outro grey.
    static func tint(of kind: SongArrangement.Section.Kind, accent: Color) -> Color {
        let verse = accent
        switch kind {
        case .chorus: return Palette.starGold
        case .verse: return verse
        case .bridge: return verse == Palette.violet ? Palette.sky : Palette.violet
        case .solo, .interlude: return verse == Palette.sky ? Palette.orchid : Palette.sky
        case .intro, .outro: return Palette.inkSoft
        }
    }

    /// The colour a section's notes are drawn in on the lead sheet: its own, the verse's for an intro or outro.
    static func noteTint(of section: SongSheet.Section, in sections: [SongSheet.Section], accent: Color) -> Color {
        guard section.part != nil else { return section.isHook ? Palette.starGold : accent }
        return section.isBookend ? tint(of: .verse, accent: accent) : tint(of: section, in: sections, accent: accent)
    }

    private func fill(of section: SongSheet.Section) -> Double {
        guard let progress else { return 0 }
        let bar = progress * Double(max(1, bars))
        return min(1, max(0, (bar - Double(section.start)) / Double(max(1, section.bars))))
    }

    /// "The hook, Bars 5–8", "G, Bars 1–2", "Bars 1–4".
    static func spoken(_ section: SongSheet.Section) -> String {
        let range = section.bars == 1
            ? String(localized: "Bar \(section.start + 1)", bundle: TimbreLocalization.bundle)
            : String(localized: "Bars \(section.start + 1)–\(section.start + section.bars)", bundle: TimbreLocalization.bundle)
        if let title = section.title { return title.localized + ", " + range }
        if let chord = section.chord { return chord.name + ", " + range }
        return range
    }

    private var spokenSections: String {
        sections.map(Self.spoken).joined(separator: "; ")
    }
}

/// The map's tiles side by side: each its bars' share of the width, never narrower than its own label (a tile that
/// needs more keeps its label's width and the rest share what is left). When even the labels need more room than
/// there is, the row is as wide as they make it, and scrolls.
private struct SectionRow: Layout {
    let available: CGFloat
    let weights: [Int]
    let spacing: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let widths = widths(subviews)
        let total = widths.reduce(0, +) + spacing * CGFloat(max(0, subviews.count - 1))
        let tallest = subviews.map { $0.sizeThatFits(.unspecified).height }.max() ?? 0
        return CGSize(width: total, height: proposal.height ?? tallest)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let widths = widths(subviews)
        var x = bounds.minX
        for (index, subview) in subviews.enumerated() {
            let width = index < widths.count ? widths[index] : 0
            subview.place(at: CGPoint(x: x, y: bounds.minY), anchor: .topLeading,
                          proposal: ProposedViewSize(width: width, height: bounds.height))
            x += width + spacing
        }
    }

    private func widths(_ subviews: Subviews) -> [CGFloat] {
        let minimums = subviews.map { ceil($0.sizeThatFits(.unspecified).width) }
        guard minimums.count == weights.count, !minimums.isEmpty else { return minimums }
        let room = available - spacing * CGFloat(max(0, minimums.count - 1))
        guard room > minimums.reduce(0, +) else { return minimums }
        var held = Set<Int>()
        var unit: CGFloat = 0
        while true {
            let freeWeight = weights.indices.filter { !held.contains($0) }.reduce(Int(0)) { $0 + weights[$1] }
            let freeRoom = room - held.reduce(CGFloat(0)) { $0 + minimums[$1] }
            guard freeWeight > 0 else { break }
            unit = freeRoom / CGFloat(freeWeight)
            let short = weights.indices.filter { !held.contains($0) && unit * CGFloat(weights[$0]) < minimums[$0] }
            if short.isEmpty { break }
            held.formUnion(short)
        }
        return weights.indices.map { held.contains($0) ? minimums[$0] : unit * CGFloat(weights[$0]) }
    }
}

/// One tile of the map: the section's name (a chord's symbol; for a section without one, its bars; a glyph for an
/// intro or outro) or, held down, its bars; filled behind the playhead while the song plays.
private struct SectionTile: View {
    let section: SongSheet.Section
    let tint: Color
    let fill: Double
    let selected: Bool
    let peeking: Bool
    let pressed: Bool
    let playing: Bool

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: Metrics.cornerChip, style: .continuous)
        let plain = (section.title == nil && section.chord == nil) || section.isBookend
        let base = plain ? 0.08 : 0.16
        ZStack {
            name.opacity(peeking ? 0 : 1)
            barsLabel.opacity(peeking ? 1 : 0)
        }
        .padding(.horizontal, 12)
        .frame(minWidth: 44)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background {
            ZStack(alignment: .leading) {
                shape.fill(tint.opacity(selected ? 0.3 : base))
                // The part played fills the tile under its name, brightest at the playhead's edge, so no line is ever
                // drawn across the name ("Cho|rus").
                GeometryReader { proxy in
                    LinearGradient(colors: [tint.opacity(0.36), tint.opacity(playing && fill < 1 ? 0.62 : 0.42)],
                                   startPoint: .leading, endPoint: .trailing)
                        .frame(width: proxy.size.width * CGFloat(fill))
                }
            }
        }
        .clipShape(shape)
        .overlay(shape.strokeBorder(tint.opacity(selected ? 0.95 : fill > 0 ? 0.7 : 0.35), lineWidth: selected ? 2 : 1))
        .overlay(alignment: .topTrailing) {
            if selected {
                Image(systemName: "repeat").font(.system(size: 8, weight: .heavy)).foregroundStyle(tint).padding(5)
            }
        }
        .scaleEffect(pressed ? 0.95 : 1)
        .cappedControl(Text(verbatim: SongSectionMap.spoken(section)), symbol: "repeat", cap: .xxLarge)
    }

    @ViewBuilder private var name: some View {
        if section.isBookend, let kind = section.part?.kind {
            Image(systemName: kind == .intro ? "arrow.right.to.line" : "flag.checkered")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Palette.inkSoft)
        } else if let title = section.title {
            Text(title.localized).font(Typeface.label(12)).foregroundStyle(Palette.ink).lineLimit(1).fixedSize()
        } else if let chord = section.chord {
            Text(verbatim: chord.name).font(Typeface.display(15)).foregroundStyle(Palette.ink)
                .lineLimit(1).fixedSize()
        } else {
            Text(verbatim: range).font(Typeface.number(12)).foregroundStyle(Palette.inkSoft).lineLimit(1).fixedSize()
        }
    }

    /// "BARS" over "5–12".
    private var barsLabel: some View {
        VStack(spacing: 0) {
            Text(section.bars == 1 ? LocalizedStringKey("Bar") : LocalizedStringKey("Bars"))
                .font(Typeface.badge).tracking(0.6).textCase(.uppercase)
                .foregroundStyle(tint == Palette.inkSoft ? Palette.inkSoft : tint)
            Text(verbatim: range).font(Typeface.number(13)).foregroundStyle(Palette.ink)
        }
        .lineLimit(1)
        .fixedSize()
    }

    private var range: String {
        section.bars == 1 ? "\(section.start + 1)" : "\(section.start + 1)–\(section.start + section.bars)"
    }
}

/// The map reads as one element ("Song map", its sections) unless its sections are buttons.
private struct MapAccessibility: ViewModifier {
    let interactive: Bool
    let summary: String

    @ViewBuilder func body(content: Content) -> some View {
        if interactive {
            content.accessibilityElement(children: .contain).accessibilityLabel(Text("Song map"))
        } else {
            content
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(Text("Song map"))
                .accessibilityValue(Text(verbatim: summary))
        }
    }
}

// MARK: - The lead sheet

/// A song's lead sheet: bar by bar, the chord over it, the melody in it (the final take) and the words under it, so
/// the song reads like a chart on a music stand. A whole arrangement brings its own chord chart, changes inside a
/// bar included, and its notes carry their syllables. Without one, its chords come from the lesson's own progression
/// when it spells the song bar for bar: lined up with the melody (a pickup bar shifts it by one) and kept only when
/// its chords hold most of the melody's notes, so the chart is never a guess; a melody without one shows the melody
/// alone. A song that ends on its chords is all chords, its strum pattern as slashes. Built once per lesson (`of`).
struct LeadChart {
    /// A chord change on the chart: where it comes, in beats from the top of the song, and the chord (nil: no chord).
    struct Mark: Equatable {
        let beat: Double
        let chord: ChordSpec?
    }

    let bars: Int
    let meter: Int
    /// The melody from beat 0 of the first bar; empty for a song that ends on its chords.
    let notes: [TimedNote]
    /// The chord on each bar's downbeat; nil where the lesson names none.
    let chords: [ChordSpec?]
    /// Every change of chord in playing order (two in a bar where the chart changes on its third beat).
    let marks: [Mark]
    /// The changes to another chord inside each bar, after its downbeat, by bar (`SongArrangement.played(inBar:)`):
    /// what `filledBars` adds to the downbeats. Empty for a chart of whole bars.
    private let inside: [Int: [ChordBar.Change]]
    /// A strummed song's pattern within a bar, in beats.
    let strokes: [Double]
    /// Each melody note's lyric syllable as sung ("Twin-" joining the next), `TimedNote.held` for a note holding the
    /// syllable before it, nil for a note without words.
    let lyrics: [String?]
    /// Syllables in a busy bar of the words (three bars in four hold no more), 0 for a song without words: the lead
    /// sheet gives each bar room for them.
    let syllablesPerBar: Int
    /// The melody's lowest and highest notes (an octave round middle C without one).
    let low: Int
    let high: Int

    var hasChords: Bool { chords.contains { $0 != nil } }
    var hasLyrics: Bool { syllablesPerBar > 0 }

    @MainActor private static var cache: [String: LeadChart] = [:]

    @MainActor static func of(_ lesson: Lesson) -> LeadChart {
        if let known = cache[lesson.id] { return known }
        let chart = LeadChart(lesson: lesson, sheet: SongSheet.of(lesson))
        if cache.count > 200 { cache.removeAll() }
        cache[lesson.id] = chart
        return chart
    }

    init(lesson: Lesson, sheet: SongSheet) {
        let bars = max(1, sheet.bars)
        self.bars = bars
        var melody: [TimedNote] = []
        let beats: Int
        let perBar: [ChordSpec?]
        var changes: [Mark]?
        var pattern: [Double] = []
        var split: [Int: [ChordBar.Change]] = [:]
        if let arrangement = sheet.arrangement {
            // The arrangement's chart, as written.
            melody = sheet.finale
            beats = max(1, sheet.beatsPerBar)
            let charted = arrangement.chordPerBar + [ChordSpec?](repeating: nil, count: bars)
            perBar = Array(charted.prefix(bars))
            changes = Self.marks(of: arrangement)
            split = Self.inside(arrangement, bars: bars)
        } else if case let .progression(list, lengths, strums, _, _, _, _)? = lesson.steps.last {
            beats = max(1, sheet.beatsPerBar)
            var spread: [ChordSpec?] = []
            for (index, chord) in list.enumerated() {
                let count = index < lengths.count ? max(1, lengths[index]) : 1
                spread += [ChordSpec?](repeating: chord, count: count)
            }
            spread += [ChordSpec?](repeating: nil, count: bars)
            perBar = Array(spread.prefix(bars))
            pattern = strums.filter { $0 >= 0 && $0 < Double(beats) }
        } else {
            melody = sheet.finale.isEmpty ? sheet.melody : sheet.finale
            beats = max(1, sheet.finale.isEmpty ? sheet.melodyMeter : sheet.beatsPerBar)
            perBar = Self.chart(melody, meter: beats, bars: bars, steps: lesson.steps)
        }
        meter = beats
        chords = perBar
        strokes = pattern
        notes = melody
        marks = changes ?? Self.marks(of: perBar, meter: beats)
        inside = split
        let words = Self.syllables(of: melody)
        lyrics = words
        syllablesPerBar = Self.busyBar(melody, words: words, meter: beats)
        let pitches = melody.map(\.midi)
        let lowest = pitches.min() ?? 60
        let highest = pitches.max() ?? 72
        low = lowest
        high = max(highest, lowest + 5)
    }

    /// An arrangement's chord changes, each at its beat ("N" as no chord); a symbol without a shape is left out.
    private static func marks(of arrangement: SongArrangement) -> [Mark] {
        let meter = Double(max(1, arrangement.beatsPerBar))
        return arrangement.changes.compactMap { change -> Mark? in
            let beat = Double(change.bar) * meter + change.beat
            if change.symbol == "N" { return Mark(beat: beat, chord: nil) }
            return arrangement.shape(named: change.symbol).map { Mark(beat: beat, chord: $0) }
        }
    }

    /// Each bar's changes to another chord after its downbeat, as the band and a strummer play them (each with a shape;
    /// a symbol without one is left out).
    private static func inside(_ arrangement: SongArrangement, bars: Int) -> [Int: [ChordBar.Change]] {
        var out: [Int: [ChordBar.Change]] = [:]
        for bar in 0..<max(0, min(bars, arrangement.bars)) {
            let later = arrangement.played(inBar: bar).filter { $0.beat > 1e-6 }.compactMap { change -> ChordBar.Change? in
                arrangement.shape(named: change.symbol).map { ChordBar.Change(beat: change.beat, chord: $0) }
            }
            if !later.isEmpty { out[bar] = later }
        }
        return out
    }

    /// Bar-by-bar chords as their changes: a mark on each bar whose chord differs from the bar before (a bar without
    /// one after a chord marks no chord, so nothing carries over it).
    private static func marks(of chords: [ChordSpec?], meter: Int) -> [Mark] {
        var marks: [Mark] = []
        var previous: String?
        for (bar, entry) in chords.enumerated() where entry?.symbol != previous {
            marks.append(Mark(beat: Double(bar * max(1, meter)), chord: entry))
            previous = entry?.symbol
        }
        return marks
    }

    /// The syllables of the busiest quarter of the bars with words (the 75th percentile), 0 without words.
    private static func busyBar(_ notes: [TimedNote], words: [String?], meter: Int) -> Int {
        var counts: [Int: Int] = [:]
        for (index, note) in notes.enumerated() where index < words.count {
            guard let word = words[index], word != TimedNote.held else { continue }
            counts[Int((note.beat / Double(max(1, meter)) + 1e-6).rounded(.down)), default: 0] += 1
        }
        let sorted = counts.values.sorted()
        guard !sorted.isEmpty else { return 0 }
        return sorted[min(sorted.count - 1, sorted.count * 3 / 4)]
    }

    /// The chord sounding at `beat` of the song (the last change at or before it).
    func chord(atBeat beat: Double) -> ChordSpec? {
        marks.last { $0.beat <= beat + 1e-6 }?.chord
    }

    /// The best of the lesson's progressions laid over the bars: bar for bar from the first bar or the second (after a
    /// pickup), or twice through one half the song's length; nil bars where it ends early. Kept only when at least
    /// 55 % of the melody (by length, downbeats counting extra) sits in the chord over it.
    private static func chart(_ notes: [TimedNote], meter: Int, bars: Int, steps: [LessonStep]) -> [ChordSpec?] {
        let none = [ChordSpec?](repeating: nil, count: bars)
        guard !notes.isEmpty else { return none }
        var best: (score: Double, chart: [ChordSpec?])?
        for step in steps {
            guard case let .progression(list, lengths, _, _, _, _, _) = step else { continue }
            var flat: [ChordSpec] = []
            for (index, chord) in list.enumerated() {
                flat += Array(repeating: chord, count: index < lengths.count ? max(1, lengths[index]) : 1)
            }
            guard !flat.isEmpty else { continue }
            for shift in 0...1 where bars - shift > 0 {
                let room = bars - shift
                let tiles = room > flat.count ? room / flat.count : 1
                guard room <= flat.count + 1 || (tiles >= 2 && room - tiles * flat.count <= 1) else { continue }
                var candidate = none
                for bar in shift..<bars where bar - shift < flat.count * tiles {
                    candidate[bar] = flat[(bar - shift) % flat.count]
                }
                let score = coverage(notes, chart: candidate, meter: meter)
                if score > (best?.score ?? 0) { best = (score: score, chart: candidate) }
            }
        }
        guard let best, best.score >= 0.55 else { return none }
        return best.chart
    }

    /// The share of the melody (by length, downbeats counting half again) whose notes are tones of the chord over them.
    private static func coverage(_ notes: [TimedNote], chart: [ChordSpec?], meter: Int) -> Double {
        var total = 0.0
        var held = 0.0
        for note in notes {
            let bar = Int((note.beat / Double(meter) + 1e-6).rounded(.down))
            guard bar >= 0, bar < chart.count, let chord = chart[bar] else { continue }
            let downbeat = abs(note.beat - Double(bar * meter)) < 1e-6
            let weight = max(0.25, note.beats) * (downbeat ? 1.5 : 1)
            total += weight
            if tones(of: chord).contains(PitchMath.pitchClass(midi: note.midi)) { held += weight }
        }
        return total > 0 ? held / total : 0
    }

    /// The words under the melody, note by note, read from the notes' syllables (`TimedNote.lyric`): "Twin-" where a
    /// syllable runs on into the next, `TimedNote.held` on a note that holds the one before, nil without words.
    private static func syllables(of notes: [TimedNote]) -> [String?] {
        notes.map { note -> String? in
            if note.holdsSyllable { return TimedNote.held }
            guard let syllable = note.syllable else { return nil }
            return note.joinsNextSyllable ? syllable + "-" : syllable
        }
    }

    /// A chord's pitch classes (root and fifth for a quality the recogniser doesn't know).
    static func tones(of chord: ChordSpec) -> Set<Int> {
        let intervals = ChordTarget(root: chord.root, formulaId: chord.quality)?.quality.intervals ?? [0, 7]
        return Set(intervals.map { PitchMath.pitchClass(midi: chord.root + $0) })
    }

    /// The melody of bars `start..<start + count`, from beat 0 of its first bar.
    func melody(from start: Int, count: Int) -> [TimedNote] {
        let from = Double(start * meter)
        let to = Double((start + count) * meter)
        return notes.filter { $0.beat >= from - 1e-6 && $0.beat < to - 1e-6 }
            .map { TimedNote(midi: $0.midi, beat: $0.beat - from, beats: $0.beats, at: $0.at) }
    }

    /// The chords under a stretch of this song's melody, bar by bar from its beat 0, each change inside a bar included:
    /// `notes` as a play-along step or a practised part plays them (the verse, the hook), found in the song's take a
    /// whole number of bars in, every note in its place. Nil when they aren't a stretch of this take, or the chart names
    /// no chords.
    func bars(under notes: [TimedNote], meter: Int) -> [ChordBar]? {
        guard hasChords, meter == self.meter, let first = notes.first, !self.notes.isEmpty else { return nil }
        let beats = Double(max(1, meter))
        let end = notes.map { $0.beat + $0.beats }.max() ?? beats
        let count = max(1, Int((end / beats - 1e-6).rounded(.up)))
        for candidate in self.notes where candidate.midi == first.midi {
            let shift = candidate.beat - first.beat
            let barShift = shift / beats
            guard shift > -1e-6, abs(barShift - barShift.rounded()) < 1e-6 else { continue }
            let found = notes.allSatisfy { note in
                self.notes.contains { $0.midi == note.midi && abs($0.beat - (note.beat + shift)) < 1e-3 }
            }
            guard found else { continue }
            let bars = filledBars(from: Int(barShift.rounded()), count: count)
            return bars.isEmpty ? nil : bars
        }
        return nil
    }

    /// The song lesson of `course` with a play-along step playing exactly `notes` (in play order), and the chords
    /// under that step from the song's chart, change by change; nil for a play-along of no song, or of a song without
    /// chords.
    @MainActor static func bars(underStep notes: [TimedNote], meter: Int, in course: LearnCourse) -> [ChordBar]? {
        for lesson in course.lessons where lesson.kind == .song {
            let plays = lesson.steps.contains { step in
                guard case let .playAlong(stepNotes, _, _, _) = step, stepNotes.count == notes.count else { return false }
                return stepNotes.sorted { $0.beat < $1.beat } == notes
            }
            guard plays else { continue }
            return LeadChart.of(lesson).bars(under: notes, meter: meter)
        }
        return nil
    }

    /// Bars `start..<start + count` as they are played: each downbeat's chord (`filledChords`), then every change to
    /// another chord inside the bar, at its beat. Twinkle's first two bars are "C · G" and "D · G".
    func filledBars(from start: Int, count: Int) -> [ChordBar] {
        let downbeats = filledChords(from: start, count: count)
        let first = min(chords.count, max(0, start))
        return downbeats.enumerated().map { offset, chord -> ChordBar in
            var later: [ChordBar.Change] = []
            var sounding = chord.symbol
            for change in inside[first + offset] ?? [] where change.chord.symbol != sounding {
                later.append(change)
                sounding = change.chord.symbol
            }
            return ChordBar(chord, later: later)
        }
    }

    /// The chords on the downbeats of bars `start..<start + count`, a bar without one holding the chord before it (or
    /// the next).
    func filledChords(from start: Int, count: Int) -> [ChordSpec] {
        let first = min(chords.count, max(0, start))
        let range = Array(chords[first..<max(first, min(chords.count, start + count))])
        var out: [ChordSpec] = []
        var held = range.first { $0 != nil } ?? nil
        for chord in range {
            if let chord { held = chord }
            if let held { out.append(held) }
        }
        return out
    }
}

/// One bar of a chart as it is played: the chord on its downbeat, then each change to another chord inside it, at the
/// beat it comes on (counted from the downbeat). The band plays each chord for its stretch of the bar, and "Chords &
/// words" asks for a strum on each.
struct ChordBar: Equatable {
    struct Change: Equatable {
        /// Beats from the bar's downbeat.
        let beat: Double
        let chord: ChordSpec
    }

    let downbeat: ChordSpec
    /// The changes after the downbeat, in order.
    let later: [Change]

    init(_ downbeat: ChordSpec, later: [Change] = []) {
        self.downbeat = downbeat
        // After the downbeat, in order, never two on the same beat.
        var kept: [Change] = []
        for change in later.sorted(by: { $0.beat < $1.beat }) where change.beat > 1e-6 {
            if let last = kept.last, change.beat - last.beat <= 1e-6 { continue }
            kept.append(change)
        }
        self.later = kept
    }

    /// Every chord of the bar in order, the downbeat's first (at beat 0).
    var changes: [Change] { [Change(beat: 0, chord: downbeat)] + later }
    /// The chord sounding as the bar ends.
    var last: ChordSpec { later.last?.chord ?? downbeat }
    var isSplit: Bool { !later.isEmpty }
    /// "C · G".
    var name: String { changes.map { $0.chord.name }.joined(separator: " · ") }

    /// The bar's harmony as the band plays it: each chord's root and tones from its beat.
    var segments: [BandArrangement.Segment] {
        changes.map { change -> BandArrangement.Segment in
            let chord = change.chord
            let tones = ChordTarget(root: chord.root, formulaId: chord.quality)?.quality.intervals ?? [0, 7]
            return BandArrangement.Segment(beat: change.beat, root: PitchMath.pitchClass(midi: chord.root), tones: tones)
        }
    }
}

/// The lead sheet, section by section: each a card headed by its name and bars (the hook marked), its music engraved
/// in lines (`EngravedSheet`: a staff with clef, key and time, beamed rhythms, rests and ties, the tab under it or
/// either alone, the chord symbols over them and the words under them). Tapping a section picks it (`onSelect`); the
/// picked one shows `controls`. While the song or a loop plays, `position` (bars from the start) moves a playhead
/// through the bars and lights the notes and syllables it reaches.
struct LeadSheetView<Controls: View>: View {
    let chart: LeadChart
    let sections: [SongSheet.Section]
    let accent: Color
    let engraved: EngravedSheet
    var position: Double?
    var selected: Int?
    let onSelect: (SongSheet.Section) -> Void
    @ViewBuilder let controls: (SongSheet.Section) -> Controls

    /// The card's inset: the sheet is engraved for the width inside it.
    private static var inset: CGFloat { EngravedSheet.cardInset }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(sections) { section in block(section) }
        }
    }

    /// The first hook: only it wears the Hook badge (an arrangement's later choruses are the same part again).
    private var firstHook: Int? { sections.first { $0.isHook }?.id }

    private func block(_ section: SongSheet.Section) -> some View {
        let tint = SongSectionMap.tint(of: section, in: sections, accent: accent)
        let on = selected == section.id
        let shape = RoundedRectangle(cornerRadius: Metrics.cornerTile, style: .continuous)
        let wash = on ? 0.13 : section.isHook ? 0.07 : 0.035
        let edge = on ? 0.7 : section.isHook ? 0.34 : 0.1
        return VStack(alignment: .leading, spacing: 4) {
            header(section, tint: tint, on: on)
            ForEach(engraved.lines(for: section.id)) { line in
                lineView(line, section: section)
            }
            if on { controls(section).padding(.top, 4) }
        }
        .padding(Self.inset)
        .background(shape.fill(tint.opacity(wash)))
        .overlay(shape.strokeBorder(tint.opacity(edge), lineWidth: on ? 1.5 : 1))
        .contentShape(shape)
        .onTapGesture { onSelect(section) }
        .id(section.anchor)
    }

    private func lineView(_ line: EngravedLine, section: SongSheet.Section) -> some View {
        var highlight = NotationHighlight.none
        if let position, line.bars.contains(where: { $0.index == Int(position.rounded(.down)) }) {
            highlight = .playhead(position)
        }
        return EngravedLineView(line: line, tint: SongSectionMap.noteTint(of: section, in: sections, accent: accent), highlight: highlight)
            .equatable()
    }

    private func header(_ section: SongSheet.Section, tint: Color, on: Bool) -> some View {
        Button { onSelect(section) } label: {
            HStack(spacing: 8) {
                name(section).font(Typeface.label(.footnote)).foregroundStyle(Palette.ink)
                if section.title != nil || section.chord != nil {
                    bars(section).font(Typeface.label(12)).foregroundStyle(tint)
                }
                if section.isHook && (section.part == nil || section.id == firstHook) { hookBadge }
                Spacer(minLength: 8)
                Image(systemName: on ? "repeat.circle.fill" : "repeat")
                    .font(.system(size: on ? 18 : 13, weight: .bold))
                    .foregroundStyle(on ? tint : Palette.inkFaint)
                    .contentTransition(.symbolEffect(.replace))
            }
            .lineLimit(1)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(verbatim: SongSectionMap.spoken(section)))
        .accessibilityValue(Text(verbatim: chordsSpoken(section)))
        .accessibilityHint(Text("Loops this part"))
        .accessibilityAddTraits(on ? .isSelected : [])
    }

    private func name(_ section: SongSheet.Section) -> Text {
        if let title = section.title { return Text(title.localized) }
        if let chord = section.chord { return Text(verbatim: chord.name) }
        return bars(section)
    }

    private func bars(_ section: SongSheet.Section) -> Text {
        section.bars == 1 ? Text("Bar \(section.start + 1)") : Text("Bars \(section.start + 1)–\(section.start + section.bars)")
    }

    private var hookBadge: some View {
        Label("Hook", systemImage: "sparkles")
            .font(Typeface.badge).foregroundStyle(Palette.onGold)
            .padding(.horizontal, 7).padding(.vertical, 2)
            .background(Capsule().fill(Palette.starGold))
            .fixedSize()
    }

    /// The section's chords as they change, for VoiceOver ("G, D, E minor, C").
    private func chordsSpoken(_ section: SongSheet.Section) -> String {
        let from = Double(section.start * chart.meter)
        let to = Double((section.start + section.bars) * chart.meter)
        var names: [String] = []
        var last: String?
        if let opening = chart.chord(atBeat: from) {
            names.append(SongSheet.spoken(opening))
            last = opening.symbol
        }
        for mark in chart.marks where mark.beat > from + 1e-6 && mark.beat < to - 1e-6 {
            guard let chord = mark.chord, chord.symbol != last else { continue }
            names.append(SongSheet.spoken(chord))
            last = chord.symbol
        }
        return names.joined(separator: ", ")
    }
}

// MARK: - Playing a stretch of the song

/// Plays part of a song in the course's voice on one clock, each hit (a note, or a chord's tones together) at its
/// beat: once, or round and round as a loop until the task is cancelled. Given a band (and headphones, with the
/// band switch on, which `AudioService` checks), the band and a click play under it from the first beat and land on
/// a final chord when a single pass ends. `stop` silences it all.
enum SongPlayback {
    struct Hit {
        let beat: Double
        let beats: Double
        let midis: [Int]
    }

    @MainActor static func start(_ hits: [Hit], bpm: Double, meter: Int, length: Double, band: BandArrangement?, loop: Bool,
                                 audio: AudioService, voice: InstrumentVoice?, reference: Double,
                                 finished: @escaping @MainActor () -> Void) -> Task<Void, Never> {
        let spb = 60 / max(20, bpm)
        let cycle = max(0.5, length)
        if let band {
            audio.setMetronome(bpm: Int(bpm.rounded()), beats: max(1, meter), subdivision: 1, accents: true)
            audio.playBand(band, firstBar: 0)
        }
        return Task { @MainActor in
            let clock = ContinuousClock()
            var begin = clock.now
            repeat {
                for hit in hits where hit.beat * spb < cycle {
                    try? await clock.sleep(until: begin + .seconds(hit.beat * spb))
                    guard !Task.isCancelled else { return }
                    let ms = Int(min(1600, max(160, hit.beats * spb * 950)))
                    audio.playTones(hit.midis.map { PitchMath.frequency(midi: Double($0), reference: reference) },
                                    together: hit.midis.count > 1, noteMs: ms, gapMs: 0, voice: voice)
                }
                try? await clock.sleep(until: begin + .seconds(cycle))
                guard !Task.isCancelled else { return }
                begin = begin + .seconds(cycle)
            } while loop
            if band != nil { audio.finishBand(celebrate: true) }
            try? await clock.sleep(until: begin + .seconds(0.5))
            guard !Task.isCancelled else { return }
            finished()
        }
    }

    @MainActor static func stop(_ audio: AudioService) {
        audio.stopTone()
        if audio.metronomeRunning { audio.stopMetronome() }
    }

    /// A melody's notes as hits.
    static func hits(_ notes: [TimedNote]) -> [Hit] {
        notes.map { Hit(beat: $0.beat, beats: $0.beats, midis: [$0.midi]) }
    }

    /// The band under a stretch of `bars` bars: the chords over them when the chart has them (bass on the roots, the
    /// comping on the chords), else drums and a bass on the melody's key; exactly `bars` long, so a loop of it stays
    /// on the bar. No band bass when the player's own instrument is the bass (`bass` false).
    @MainActor static func band(notes: [TimedNote], chords: [ChordSpec], bars: Int, bpm: Double, meter: Int,
                                reference: Double, bass: Bool) -> BandArrangement {
        let base: BandArrangement
        if chords.count == bars, bars > 0 {
            base = .chords(chords, bars: Array(repeating: 1, count: bars), pattern: notes.map(\.beat), bpm: bpm,
                           beatsPerBar: meter, reference: reference)
        } else {
            base = .melody(notes, bpm: bpm, beatsPerBar: meter, reference: reference, bass: bass)
        }
        var list = Array(base.bars.prefix(max(1, bars)))
        while list.count < max(1, bars) { list.append(list.last ?? BandArrangement.Bar(root: nil)) }
        return BandArrangement(bpm: base.bpm, beatsPerBar: base.beatsPerBar, reference: base.reference, bars: list,
                               bass: base.bass && bass, pad: base.pad, swing: base.swing)
    }

    /// The band under a stretch of `bars` bars played change by change (`ChordBar`): as `band(notes:chords:…)` on
    /// their downbeats, each bar carrying its changes inside it (`BandArrangement.Bar.segments`), so the band follows a
    /// chart that changes on beat 3 rather than holding the downbeat's chord under the change.
    @MainActor static func band(notes: [TimedNote], harmony: [ChordBar], bars: Int, bpm: Double, meter: Int,
                                reference: Double, bass: Bool) -> BandArrangement {
        let base = band(notes: notes, chords: harmony.map(\.downbeat), bars: bars, bpm: bpm, meter: meter, reference: reference, bass: bass)
        guard harmony.count == bars, harmony.contains(where: \.isSplit) else { return base }
        var list = base.bars
        for index in list.indices where index < harmony.count && harmony[index].isSplit {
            list[index].segments = harmony[index].segments
        }
        return BandArrangement(bpm: base.bpm, beatsPerBar: base.beatsPerBar, reference: base.reference, bars: list,
                               bass: base.bass, pad: base.pad, swing: base.swing)
    }

    /// The band under a whole take of `notes` (a lesson's play-along, a song's final take): the chart's chords under it
    /// change by change when there are any, else drums and a bass on the melody's key. Bars from beat 0, as many as the
    /// notes run, at least one.
    @MainActor static func band(take notes: [TimedNote], harmony: [ChordBar]?, bpm: Double, meter: Int, reference: Double,
                                bass: Bool) -> BandArrangement {
        let beats = Double(max(1, meter))
        let end = notes.map { $0.beat + $0.beats }.max() ?? beats
        let bars = max(1, Int((end / beats - 1e-6).rounded(.up)))
        guard var chart = harmony, !chart.isEmpty else {
            return .melody(notes, bpm: bpm, beatsPerBar: meter, reference: reference, bass: bass)
        }
        // A last note ringing past the chart's last bar holds the chord it ended on.
        while chart.count < bars, let last = chart.last { chart.append(ChordBar(last.last)) }
        let count = max(bars, chart.count)
        return band(notes: notes, harmony: Array(chart.prefix(count)), bars: count, bpm: bpm, meter: meter, reference: reference, bass: bass)
    }
}

// MARK: - Arrival

/// Calls `action` once the screen it sits in has finished arriving: when the presentation carrying it in (the zoom
/// out of a Songs sleeve or a Learn node, a slide) completes, or at once when none is running. A reveal started
/// while a zoom is still in flight can be cut short with the view left part-way (a lesson's first step frozen at
/// about 30 % opacity), so entrances wait for this.
struct ArrivalProbe: UIViewRepresentable {
    let action: () -> Void

    func makeUIView(context: Context) -> ProbeView { ProbeView(action: action) }
    func updateUIView(_ view: ProbeView, context: Context) { view.action = action }

    final class ProbeView: UIView {
        var action: () -> Void
        private var reported = false

        init(action: @escaping () -> Void) {
            self.action = action
            super.init(frame: .zero)
            isUserInteractionEnabled = false
            backgroundColor = .clear
        }

        required init?(coder: NSCoder) { nil }

        override func didMoveToWindow() {
            super.didMoveToWindow()
            guard window != nil, !reported else { return }
            // A turn of the run loop, so the presentation has set up its coordinator.
            DispatchQueue.main.async { [weak self] in self?.settle() }
        }

        private func settle() {
            guard !reported else { return }
            if let coordinator = owner?.transitionCoordinator {
                coordinator.animate(alongsideTransition: nil) { [weak self] _ in self?.report() }
            } else {
                report()
            }
        }

        private func report() {
            guard !reported else { return }
            reported = true
            action()
        }

        /// The view controller this view is shown by.
        private var owner: UIViewController? {
            var responder: UIResponder? = next
            while let current = responder {
                if let controller = current as? UIViewController { return controller }
                responder = current.next
            }
            return nil
        }
    }
}
