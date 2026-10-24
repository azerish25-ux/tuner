import SwiftUI
import TimbreCore
import UIKit

// MARK: - The song, read from its lesson

/// A song lesson read as a song: the take it ends on (tempo, meter, bars, length), its key, every chord it asks for,
/// its melody and its sections. Nothing is made up: sections come from the lesson's own play-alongs, each one whose
/// notes run, in order, inside the final take naming that stretch of bars ("The verse", "The hook"); bars no
/// play-along names stay plain ("Bars 5–8"), and a song with none shows its phrases of four bars. A song that ends
/// on a chord progression maps its chords instead. Built once per lesson (`of`).
struct SongSheet {
    struct Section: Identifiable, Equatable {
        let id: Int
        /// The play-along that names these bars; nil for plain bars.
        let title: LearnText?
        /// The chord the bars hold (a song that ends on a progression).
        let chord: ChordSpec?
        /// First bar (0-based) and how many bars it runs.
        let start: Int
        let bars: Int
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
            case let .strum(chord, _, _, bars, _):
                if let chord {
                    Self.keep(chord, in: &chords)
                    timeline.append((chord: chord, bars: max(1, bars)))
                }
            case let .progression(list, lengths, _, _, _):
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
        self.chords = chords

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
        case let .progression(list, lengths, pattern, rate, beats)?:
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

        if !finale.isEmpty {
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

    // MARK: Sections

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
    /// The part a song is known by: a section its lesson names the hook, the chorus or the refrain.
    var isHook: Bool {
        guard let name = title?.defaultValue.lowercased() else { return false }
        return ["hook", "chorus", "refrain"].contains { name.contains($0) }
    }
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

/// The song's sections as one bar across the screen, each as wide as its bars: named by the lesson's play-along
/// ("The hook") over its bars, or plain bars, or the chord it holds. While the song plays, `progress` (0…1 of the
/// song) fills the sections behind a playhead. Given `onSelect`, each section is a button (the song sheet loops it)
/// and `selected` stands out with a loop mark.
struct SongSectionMap: View {
    let sections: [SongSheet.Section]
    let bars: Int
    var accent: Color = Palette.mint
    var progress: Double?
    var height: CGFloat = 50
    /// The section looping on the song sheet.
    var selected: Int?
    var onSelect: ((SongSheet.Section) -> Void)?

    private static let spacing: CGFloat = 3

    var body: some View {
        GeometryReader { proxy in
            let layout = Spans(sections: sections, bars: bars, width: proxy.size.width)
            ZStack(alignment: .topLeading) {
                ForEach(Array(sections.enumerated()), id: \.element.id) { index, section in
                    segmentSlot(section, width: layout.widths[index])
                        .offset(x: layout.lefts[index])
                }
                if let progress {
                    playhead
                        .offset(x: layout.x(for: progress) - 1.5)
                }
            }
        }
        .frame(height: height)
        .modifier(MapAccessibility(interactive: onSelect != nil, summary: spokenSections))
    }

    /// Where each section sits across `width`, with a little air between them.
    private struct Spans {
        let lefts: [CGFloat]
        let widths: [CGFloat]
        let sections: [SongSheet.Section]
        let bars: Int

        init(sections: [SongSheet.Section], bars: Int, width: CGFloat) {
            self.sections = sections
            self.bars = max(1, bars)
            let gaps = SongSectionMap.spacing * CGFloat(max(0, sections.count - 1))
            let unit = max(0, width - gaps) / CGFloat(max(1, bars))
            var lefts: [CGFloat] = []
            var widths: [CGFloat] = []
            var x: CGFloat = 0
            for section in sections {
                lefts.append(x)
                let w = unit * CGFloat(section.bars)
                widths.append(w)
                x += w + SongSectionMap.spacing
            }
            self.lefts = lefts
            self.widths = widths
        }

        /// The playhead's x for `progress` of the song.
        func x(for progress: Double) -> CGFloat {
            let bar = min(Double(bars), max(0, progress * Double(bars)))
            for (index, section) in sections.enumerated() where bar <= Double(section.start + section.bars) {
                let within = (bar - Double(section.start)) / Double(max(1, section.bars))
                return lefts[index] + widths[index] * CGFloat(max(0, min(1, within)))
            }
            return (lefts.last ?? 0) + (widths.last ?? 0)
        }
    }

    /// A section, as a button when the map picks loops.
    @ViewBuilder private func segmentSlot(_ section: SongSheet.Section, width: CGFloat) -> some View {
        if let onSelect {
            Button { onSelect(section) } label: { segment(section, width: width) }
                .buttonStyle(PressScaleStyle())
                .accessibilityLabel(Text(verbatim: Self.spoken(section)))
                .accessibilityHint(Text("Loops this part"))
                .accessibilityAddTraits(selected == section.id ? .isSelected : [])
        } else {
            segment(section, width: width)
        }
    }

    private func segment(_ section: SongSheet.Section, width: CGFloat) -> some View {
        let tint = Self.tint(of: section, in: sections, accent: accent)
        let shape = RoundedRectangle(cornerRadius: 11, style: .continuous)
        let filled = fill(of: section)
        let on = selected == section.id
        let base = section.title == nil && section.chord == nil ? 0.08 : 0.16
        return ZStack(alignment: .leading) {
            shape.fill(tint.opacity(on ? 0.3 : base))
            Rectangle().fill(tint.opacity(0.42)).frame(width: max(0, width * CGFloat(filled)))
            if width >= 34 { label(section, tint: tint).padding(.horizontal, 8) }
        }
        .frame(width: max(0, width), height: height, alignment: .leading)
        .overlay(alignment: .topTrailing) {
            if on && width >= 64 {
                Image(systemName: "repeat").font(.system(size: 10, weight: .bold)).foregroundStyle(tint).padding(6)
            }
        }
        .clipShape(shape)
        .overlay(shape.strokeBorder(tint.opacity(on ? 0.95 : filled > 0 ? 0.7 : 0.35), lineWidth: on ? 2 : 1))
        .contentShape(shape)
    }

    @ViewBuilder private func label(_ section: SongSheet.Section, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            if let title = section.title {
                Text(title.localized).font(Typeface.label(12)).foregroundStyle(Palette.ink)
                barsText(section).font(.caption2.weight(.semibold)).foregroundStyle(tint)
            } else if let chord = section.chord {
                Text(verbatim: chord.name).font(Typeface.display(15, relativeTo: .subheadline)).foregroundStyle(Palette.ink)
                barsText(section).font(.caption2.weight(.semibold)).foregroundStyle(Palette.inkSoft)
            } else {
                barsText(section).font(Typeface.label(12)).foregroundStyle(Palette.inkSoft)
            }
        }
        .lineLimit(1)
        .minimumScaleFactor(0.6)
        .dynamicTypeSize(...DynamicTypeSize.xLarge)
    }

    private func barsText(_ section: SongSheet.Section) -> Text {
        section.bars == 1 ? Text("Bar \(section.start + 1)") : Text("Bars \(section.start + 1)–\(section.start + section.bars)")
    }

    /// A white playhead with a glow in the accent.
    private var playhead: some View {
        Capsule().fill(Color.white)
            .frame(width: 3, height: height + 8)
            .offset(y: -4)
            .shadow(color: accent.opacity(0.9), radius: 6)
            .allowsHitTesting(false)
    }

    /// The hook (or chorus) always in amber, the other named sections in the accent and the colours after it (the
    /// same name always the same colour), chords in the accent, plain bars in grey. The lead sheet uses the same.
    static func tint(of section: SongSheet.Section, in sections: [SongSheet.Section], accent: Color) -> Color {
        if section.chord != nil { return accent }
        guard let title = section.title else { return Palette.inkSoft }
        if section.isHook { return Palette.amber }
        let names = sections.filter { !$0.isHook }.compactMap { $0.title?.defaultValue }.reduce(into: [String]()) { list, name in
            if !list.contains(name) { list.append(name) }
        }
        let tints = [accent, Palette.violet, Palette.sky, Palette.coral]
        let index = names.firstIndex(of: title.defaultValue) ?? 0
        return tints[index % tints.count]
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

/// A song's lead sheet: bar by bar, the chord over it and the melody in it (the final take), so the song reads like
/// a chart on a music stand. Its chords come from the lesson's own progression when it spells the song bar for bar:
/// lined up with the melody (a pickup bar shifts it by one) and kept only when its chords hold most of the melody's
/// notes, so the chart is never a guess; a melody without one shows the melody alone. A song that ends on its
/// chords is all chords, its strum pattern as slashes. Built once per lesson (`of`).
struct LeadChart {
    let bars: Int
    let meter: Int
    /// The melody from beat 0 of the first bar; empty for a song that ends on its chords.
    let notes: [TimedNote]
    /// The chord over each bar; nil where the lesson names none.
    let chords: [ChordSpec?]
    /// A strummed song's pattern within a bar, in beats.
    let strokes: [Double]
    /// The melody's lowest and highest notes (an octave round middle C without one).
    let low: Int
    let high: Int

    var hasChords: Bool { chords.contains { $0 != nil } }

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
        if case let .progression(list, lengths, pattern, _, _)? = lesson.steps.last {
            meter = max(1, sheet.beatsPerBar)
            var spread: [ChordSpec?] = []
            for (index, chord) in list.enumerated() {
                let count = index < lengths.count ? max(1, lengths[index]) : 1
                spread += [ChordSpec?](repeating: chord, count: count)
            }
            spread += [ChordSpec?](repeating: nil, count: bars)
            chords = Array(spread.prefix(bars))
            strokes = pattern.filter { $0 >= 0 && $0 < Double(max(1, sheet.beatsPerBar)) }
        } else {
            melody = sheet.finale.isEmpty ? sheet.melody : sheet.finale
            let beats = max(1, sheet.finale.isEmpty ? sheet.melodyMeter : sheet.beatsPerBar)
            meter = beats
            chords = Self.chart(melody, meter: beats, bars: bars, steps: lesson.steps)
            strokes = []
        }
        notes = melody
        let pitches = melody.map(\.midi)
        let lowest = pitches.min() ?? 60
        let highest = pitches.max() ?? 72
        low = lowest
        high = max(highest, lowest + 5)
    }

    /// The best of the lesson's progressions laid over the bars: bar for bar from the first bar or the second (after a
    /// pickup), or twice through one half the song's length; nil bars where it ends early. Kept only when at least
    /// 55 % of the melody (by length, downbeats counting extra) sits in the chord over it.
    private static func chart(_ notes: [TimedNote], meter: Int, bars: Int, steps: [LessonStep]) -> [ChordSpec?] {
        let none = [ChordSpec?](repeating: nil, count: bars)
        guard !notes.isEmpty else { return none }
        var best: (score: Double, chart: [ChordSpec?])?
        for step in steps {
            guard case let .progression(list, lengths, _, _, _) = step else { continue }
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

    /// The chords of bars `start..<start + count`, a bar without one holding the chord before it (or the next).
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

/// How the lead sheet draws the melody: its shape with note names, or fret numbers on the strings (tab).
struct LeadTab: Equatable {
    /// Where each of the chart's notes is played, in order.
    let frets: [Fretting?]
    let strings: Int
    /// String 1 (the thinnest) on the top line, else the thickest.
    let thinnestOnTop: Bool
}

/// The lead sheet, section by section: each a card headed by its name and bars (the hook marked), its bars in rows
/// (four to a row on a phone, up to eight on a wide screen), the chord symbols over them and the melody, or tab, in
/// them. Tapping a section picks it (`onSelect`); the picked one shows `controls`. While the song or a loop plays,
/// `position` (bars from the start) moves a playhead through the bars and lights the notes it has passed.
struct LeadSheetView<Controls: View>: View {
    let chart: LeadChart
    let sections: [SongSheet.Section]
    let accent: Color
    var tab: LeadTab?
    let width: CGFloat
    var position: Double?
    var selected: Int?
    let onSelect: (SongSheet.Section) -> Void
    @ViewBuilder let controls: (SongSheet.Section) -> Controls

    private static var inset: CGFloat { 12 }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(sections) { section in block(section) }
        }
    }

    /// Bars to a row: four (eight in 2/4) on a phone, twice that on a wide screen, never more than the longest section.
    private var perRow: Int {
        let base = chart.meter <= 2 ? 8 : 4
        let capacity = width >= 700 ? base * 2 : base
        let longest = sections.map(\.bars).max() ?? capacity
        return max(1, min(capacity, longest))
    }

    private struct Row: Identifiable {
        let start: Int
        let count: Int
        var id: Int { start }
    }

    private func rows(_ section: SongSheet.Section) -> [Row] {
        let end = section.start + section.bars
        return stride(from: section.start, to: end, by: perRow).map { Row(start: $0, count: min(perRow, end - $0)) }
    }

    private func block(_ section: SongSheet.Section) -> some View {
        let tint = SongSectionMap.tint(of: section, in: sections, accent: accent)
        let on = selected == section.id
        let shape = RoundedRectangle(cornerRadius: 16, style: .continuous)
        let wash = on ? 0.13 : section.isHook ? 0.07 : 0.035
        let edge = on ? 0.7 : section.isHook ? 0.34 : 0.1
        return VStack(alignment: .leading, spacing: 8) {
            header(section, tint: tint, on: on)
            ForEach(rows(section)) { row in
                rowView(row, section: section, tint: tint)
            }
            if on { controls(section) }
        }
        .padding(Self.inset)
        .background(shape.fill(tint.opacity(wash)))
        .overlay(shape.strokeBorder(tint.opacity(edge), lineWidth: on ? 1.5 : 1))
        .contentShape(shape)
        .onTapGesture { onSelect(section) }
        .id(section.id)
    }

    private func header(_ section: SongSheet.Section, tint: Color, on: Bool) -> some View {
        Button { onSelect(section) } label: {
            HStack(spacing: 8) {
                name(section).font(Typeface.label(14, relativeTo: .subheadline)).foregroundStyle(Palette.ink)
                if section.title != nil || section.chord != nil {
                    bars(section).font(Typeface.label(12)).foregroundStyle(tint)
                }
                if section.isHook { hookBadge }
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
            .font(Typeface.label(11)).foregroundStyle(Palette.onAccent)
            .padding(.horizontal, 7).padding(.vertical, 2)
            .background(Capsule().fill(Palette.amber))
            .fixedSize()
    }

    /// The section's chords as they change, for VoiceOver ("G, D, E minor, C").
    private func chordsSpoken(_ section: SongSheet.Section) -> String {
        var names: [String] = []
        var last: String?
        let end = max(section.start, min(chart.chords.count, section.start + section.bars))
        for bar in section.start..<end {
            guard let chord = chart.chords[bar], chord.symbol != last else { continue }
            names.append(SongSheet.spoken(chord))
            last = chord.symbol
        }
        return names.joined(separator: ", ")
    }

    private func rowView(_ row: Row, section: SongSheet.Section, tint: Color) -> some View {
        let from = Double(row.start * chart.meter)
        let to = Double((row.start + row.count) * chart.meter)
        var notes: [TimedNote] = []
        var frets: [Fretting?] = []
        for (index, note) in chart.notes.enumerated() where note.beat >= from - 1e-6 && note.beat < to - 1e-6 {
            notes.append(note)
            if let tab { frets.append(index < tab.frets.count ? tab.frets[index] : nil) }
        }
        let chords = Array(chart.chords[min(chart.chords.count, row.start)..<min(chart.chords.count, row.start + row.count)])
        let inRow = position.map { $0 >= Double(row.start) && $0 < Double(row.start + row.count) } ?? false
        let lead = LeadRow(start: row.start, count: row.count, perRow: perRow, meter: chart.meter, notes: notes,
                           frets: tab == nil ? nil : frets, chords: chords, showChords: chart.hasChords, strokes: chart.strokes,
                           low: chart.low, high: chart.high, tint: section.isHook ? Palette.amber : accent,
                           strings: tab?.strings ?? 0, thinnestOnTop: tab?.thinnestOnTop ?? true,
                           position: inRow ? position : nil, closes: row.start + row.count == section.start + section.bars)
        return lead.equatable()
            .frame(height: lead.height)
            .accessibilityHidden(true)
    }
}

/// One row of the lead sheet, drawn in one Canvas: bar lines (a double one closing its section), chord symbols where
/// the chord changes, then the melody as its shape (each note a bar as long as it lasts, at its pitch, named above),
/// as tab (fret numbers on the strings), or, for a strummed song, slashes on the strokes. Equatable, so only the row
/// the playhead is in redraws while a song plays.
struct LeadRow: View, Equatable {
    let start: Int
    let count: Int
    let perRow: Int
    let meter: Int
    let notes: [TimedNote]
    let frets: [Fretting?]?
    let chords: [ChordSpec?]
    let showChords: Bool
    let strokes: [Double]
    let low: Int
    let high: Int
    let tint: Color
    let strings: Int
    let thinnestOnTop: Bool
    let position: Double?
    let closes: Bool

    private static let chordLane: CGFloat = 24
    private static let labelFace = "Sora-SemiBold"

    var height: CGFloat {
        let lane = showChords ? Self.chordLane : 0
        if frets != nil { return lane + CGFloat(max(1, strings - 1)) * 12 + 18 }
        if notes.isEmpty { return lane + 34 }
        return lane + 64
    }

    var body: some View {
        Canvas { context, size in draw(&context, size: size) }
    }

    private func draw(_ context: inout GraphicsContext, size: CGSize) {
        let bar = size.width / CGFloat(max(1, perRow))
        let top = showChords ? Self.chordLane : 0
        let lane = CGRect(x: 0, y: top, width: bar * CGFloat(count), height: max(1, size.height - top))
        drawBarLines(&context, bar: bar, lane: lane)
        if showChords { drawChords(&context, bar: bar) }
        if frets != nil {
            drawTab(&context, bar: bar, lane: lane)
        } else if notes.isEmpty {
            drawStrokes(&context, bar: bar, lane: lane)
        } else {
            drawMelody(&context, bar: bar, lane: lane)
        }
        if let position { drawPlayhead(&context, x: CGFloat(position - Double(start)) * bar, lane: lane) }
    }

    /// x of a beat (from the song's start) in this row.
    private func x(_ beat: Double, bar: CGFloat) -> CGFloat { CGFloat(beat / Double(max(1, meter)) - Double(start)) * bar }

    private func drawBarLines(_ context: inout GraphicsContext, bar: CGFloat, lane: CGRect) {
        for i in 0...count {
            let final = i == count && closes
            let x = min(lane.maxX - (final ? 2.5 : 1), max(0, CGFloat(i) * bar - 0.5))
            context.fill(Path(CGRect(x: x, y: lane.minY, width: 1, height: lane.height)),
                         with: .color(Palette.inkFaint.opacity(final ? 0.75 : 0.35)))
            if final {
                context.fill(Path(CGRect(x: lane.maxX - 2.5, y: lane.minY, width: 2.5, height: lane.height)),
                             with: .color(Palette.inkFaint.opacity(0.75)))
            }
        }
    }

    private func drawChords(_ context: inout GraphicsContext, bar: CGFloat) {
        var previous: String?
        for (i, chord) in chords.enumerated() {
            defer { previous = chord?.symbol }
            guard let chord, i == 0 || chord.symbol != previous else { continue }
            let label = Text(verbatim: chord.name).font(.custom(Self.labelFace, fixedSize: 15)).foregroundStyle(Palette.ink)
            context.draw(label, at: CGPoint(x: CGFloat(i) * bar + 6, y: Self.chordLane / 2 - 1), anchor: .leading)
        }
    }

    /// Three faint guide lines, the melody's contour under its notes, each note a bar at its pitch, its name above.
    private func drawMelody(_ context: inout GraphicsContext, bar: CGFloat, lane: CGRect) {
        for k in 1...3 {
            let y = lane.minY + 14 + (lane.height - 20) * CGFloat(k) / 4
            context.fill(Path(CGRect(x: 0, y: y, width: lane.width, height: 0.5)), with: .color(Palette.inkFaint.opacity(0.14)))
        }
        let span = CGFloat(max(1, high - low))
        let floor = lane.maxY - 6
        let reach = lane.height - 28
        func y(_ midi: Int) -> CGFloat { floor - reach * CGFloat(midi - low) / span }
        var contour = Path()
        var lastLabelEnd = -CGFloat.infinity
        let playing = position != nil
        for (index, note) in notes.enumerated() {
            let left = x(note.beat, bar: bar) + 2
            let right = min(lane.maxX - 2, x(note.beat + note.beats, bar: bar) - 2)
            let width = max(5, right - left)
            let level = y(note.midi)
            if index == 0 { contour.move(to: CGPoint(x: left, y: level)) } else { contour.addLine(to: CGPoint(x: left, y: level)) }
            contour.addLine(to: CGPoint(x: left + width, y: level))
            let passed = playing && Double(note.beat) / Double(max(1, meter)) <= (position ?? 0)
            let sounding = passed && (note.beat + note.beats) / Double(max(1, meter)) > (position ?? 0)
            let rect = CGRect(x: left, y: level - 3.5, width: width, height: 7)
            if sounding {
                context.fill(Path(roundedRect: rect.insetBy(dx: -3, dy: -3), cornerRadius: 6.5), with: .color(tint.opacity(0.35)))
            }
            let shade = playing && !passed ? tint.opacity(0.5) : tint
            context.fill(Path(roundedRect: rect, cornerRadius: 3.5), with: .color(sounding ? Color.white : shade))
            let name = context.resolve(Text(verbatim: NoteName.pitchClass(note.midi))
                .font(.custom(Self.labelFace, fixedSize: 11)).foregroundStyle(Palette.inkSoft))
            let measured = name.measure(in: CGSize(width: 60, height: 20))
            if left >= lastLabelEnd + 3 {
                context.draw(name, at: CGPoint(x: left, y: level - 6), anchor: .bottomLeading)
                lastLabelEnd = left + measured.width
            }
        }
        context.stroke(contour, with: .color(tint.opacity(0.22)), style: StrokeStyle(lineWidth: 1.2, lineCap: .round, lineJoin: .round))
    }

    /// The strings as lines, each note's fret on its string (a dash after it while it rings).
    private func drawTab(_ context: inout GraphicsContext, bar: CGFloat, lane: CGRect) {
        let count = max(1, strings)
        let gap: CGFloat = 12
        let first = lane.minY + 9
        for r in 0..<count {
            let y = first + CGFloat(r) * gap
            context.fill(Path(CGRect(x: 0, y: y - 0.25, width: lane.width, height: 0.5)), with: .color(Palette.inkFaint.opacity(0.45)))
        }
        let playing = position != nil
        for (index, note) in notes.enumerated() {
            guard let frets, index < frets.count, let fret = frets[index] else { continue }
            let number = max(1, min(count, fret.string))
            let row = thinnestOnTop ? number - 1 : count - number
            let y = first + CGFloat(row) * gap
            let left = x(note.beat, bar: bar) + 3
            let passed = playing && note.beat / Double(max(1, meter)) <= (position ?? 0)
            let color = playing && !passed ? tint.opacity(0.5) : tint
            let label = context.resolve(Text(verbatim: "\(fret.fret)").font(.custom(Self.labelFace, fixedSize: 11)).foregroundStyle(color))
            let size = label.measure(in: CGSize(width: 40, height: 20))
            let chip = CGRect(x: left - 2, y: y - 7, width: size.width + 4, height: 14)
            context.fill(Path(roundedRect: chip, cornerRadius: 3), with: .color(Palette.stage))
            context.draw(label, at: CGPoint(x: left, y: y), anchor: .leading)
            let right = min(lane.maxX - 3, x(note.beat + note.beats, bar: bar) - 3)
            if right - chip.maxX > 6 {
                context.fill(Path(CGRect(x: chip.maxX + 2, y: y - 1, width: right - chip.maxX - 2, height: 2)), with: .color(color.opacity(0.35)))
            }
        }
    }

    /// A strummed song: a slash on every stroke, down-strokes (on the beat) full height, up-strokes shorter.
    private func drawStrokes(_ context: inout GraphicsContext, bar: CGFloat, lane: CGRect) {
        let middle = lane.midY
        for i in 0..<count {
            for stroke in strokes {
                let x = CGFloat(i) * bar + bar * CGFloat(stroke / Double(max(1, meter))) + 8
                guard x < CGFloat(i + 1) * bar - 4 else { continue }
                let down = abs(stroke - stroke.rounded()) < 0.01
                let half: CGFloat = down ? 8 : 5
                var slash = Path()
                slash.move(to: CGPoint(x: x - half * 0.45, y: middle + half))
                slash.addLine(to: CGPoint(x: x + half * 0.45, y: middle - half))
                context.stroke(slash, with: .color(tint.opacity(down ? 1 : 0.6)), style: StrokeStyle(lineWidth: down ? 3 : 2, lineCap: .round))
            }
        }
    }

    private func drawPlayhead(_ context: inout GraphicsContext, x: CGFloat, lane: CGRect) {
        let rect = CGRect(x: x - 1, y: 0, width: 2, height: lane.maxY)
        context.fill(Path(roundedRect: rect.insetBy(dx: -3, dy: 0), cornerRadius: 3), with: .color(tint.opacity(0.3)))
        context.fill(Path(roundedRect: rect, cornerRadius: 1), with: .color(Color.white))
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
                                 audio: AudioService, voice: InstrumentVoice, reference: Double,
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

    /// The band under a stretch of `bars` bars: the chords over them when the chart has them (bass on the roots, a
    /// pad), else drums and a bass on the melody's key; exactly `bars` long, so a loop of it stays on the bar.
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
                               bass: base.bass, pad: base.pad, swing: base.swing)
    }
}

// MARK: - Arrival

/// Calls `action` once the screen it sits in has finished arriving: when the presentation carrying it in (the zoom
/// out of a Songs sleeve or a Learn node, a slide) completes, or at once when none is running. A reveal started
/// while a zoom is still in flight can be cut short with the view left part-way (bug 64: a lesson's first step
/// frozen at about 30 % opacity), so entrances wait for this.
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
