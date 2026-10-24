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

/// The song's sections as one bar across the screen, each as wide as its bars: named by the lesson's play-along
/// ("The hook") over its bars, or plain bars, or the chord it holds. While the song plays, `progress` (0…1 of the
/// song) fills the sections behind a playhead.
struct SongSectionMap: View {
    let sections: [SongSheet.Section]
    let bars: Int
    var accent: Color = Palette.mint
    var progress: Double?
    var height: CGFloat = 50

    private static let spacing: CGFloat = 3

    var body: some View {
        GeometryReader { proxy in
            let layout = Spans(sections: sections, bars: bars, width: proxy.size.width)
            ZStack(alignment: .topLeading) {
                ForEach(Array(sections.enumerated()), id: \.element.id) { index, section in
                    segment(section, index: index, width: layout.widths[index])
                        .offset(x: layout.lefts[index])
                }
                if let progress {
                    playhead
                        .offset(x: layout.x(for: progress) - 1.5)
                }
            }
        }
        .frame(height: height)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("Song map"))
        .accessibilityValue(Text(verbatim: spokenSections))
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

    private func segment(_ section: SongSheet.Section, index: Int, width: CGFloat) -> some View {
        let tint = color(of: section)
        let shape = RoundedRectangle(cornerRadius: 11, style: .continuous)
        let filled = fill(of: section)
        return ZStack(alignment: .leading) {
            shape.fill(tint.opacity(section.title == nil && section.chord == nil ? 0.08 : 0.16))
            Rectangle().fill(tint.opacity(0.42)).frame(width: max(0, width * CGFloat(filled)))
            if width >= 34 { label(section, tint: tint).padding(.horizontal, 8) }
        }
        .frame(width: max(0, width), height: height, alignment: .leading)
        .clipShape(shape)
        .overlay(shape.strokeBorder(tint.opacity(filled > 0 ? 0.7 : 0.35), lineWidth: 1))
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

    /// Named sections in the accent and the colours after it (the same name always the same colour), chords in the
    /// accent, plain bars in grey.
    private func color(of section: SongSheet.Section) -> Color {
        if section.chord != nil { return accent }
        guard let title = section.title else { return Palette.inkSoft }
        let names = sections.compactMap { $0.title?.defaultValue }.reduce(into: [String]()) { list, name in
            if !list.contains(name) { list.append(name) }
        }
        let tints = [accent, Palette.amber, Palette.violet, Palette.sky, Palette.coral]
        let index = names.firstIndex(of: title.defaultValue) ?? 0
        return tints[index % tints.count]
    }

    private func fill(of section: SongSheet.Section) -> Double {
        guard let progress else { return 0 }
        let bar = progress * Double(max(1, bars))
        return min(1, max(0, (bar - Double(section.start)) / Double(max(1, section.bars))))
    }

    private var spokenSections: String {
        sections.map { section in
            let range = section.bars == 1
                ? String(localized: "Bar \(section.start + 1)", bundle: TimbreLocalization.bundle)
                : String(localized: "Bars \(section.start + 1)–\(section.start + section.bars)", bundle: TimbreLocalization.bundle)
            if let title = section.title { return title.localized + ", " + range }
            if let chord = section.chord { return chord.name + ", " + range }
            return range
        }
        .joined(separator: "; ")
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
