import SwiftUI
import TimbreCore

// MARK: - Drawing a line

/// How a sheet's notes light up: not at all, under a playhead (bars from the top of the song: the notes passed are
/// ink, the one sounding glows in the tint, the ones to come are dimmed), or a step's notes (`done` already played in
/// the tint, `current` glowing, the rest soft).
enum NotationHighlight: Equatable {
    case none
    case playhead(Double)
    case step(current: Int?, done: Int)
}

/// One engraved line, drawn in one Canvas. Equatable on the line's identity, the tint and the highlight, so while a
/// song plays only the line the playhead is in redraws.
struct EngravedLineView: View, Equatable {
    let line: EngravedLine
    let tint: Color
    var highlight: NotationHighlight = .none

    static func == (lhs: EngravedLineView, rhs: EngravedLineView) -> Bool {
        lhs.line.id == rhs.line.id && lhs.line.width == rhs.line.width && lhs.tint == rhs.tint && lhs.highlight == rhs.highlight
    }

    var body: some View {
        // As wide as its card (the line is engraved for that width), so nothing at its end is cut.
        Canvas { context, _ in draw(&context) }
            .frame(maxWidth: .infinity, minHeight: line.height, maxHeight: line.height, alignment: .topLeading)
            .accessibilityHidden(true)
    }

    private func draw(_ context: inout GraphicsContext) {
        let space = line.type.space
        for note in glowing {
            guard let point = line.heads[note] else { continue }
            let radius = 1.9 * space
            let rect = CGRect(x: point.x - radius, y: point.y - radius, width: radius * 2, height: radius * 2)
            context.fill(Path(ellipseIn: rect),
                         with: .radialGradient(Gradient(colors: [tint.opacity(0.5), tint.opacity(0)]), center: point, startRadius: 0, endRadius: radius))
        }
        for mark in line.marks {
            switch mark {
            case let .shape(path, evenOdd, role):
                context.fill(path, with: .color(color(role)), style: FillStyle(eoFill: evenOdd))
            case let .text(string, point, face, anchor, role):
                let text = Text(verbatim: string).font(line.type.font(face)).foregroundStyle(color(role))
                context.draw(text, at: point, anchor: anchor)
            }
        }
        if case let .playhead(position) = highlight, let x = line.playheadX(at: position) {
            let rect = CGRect(x: x - 1, y: line.playTop, width: 2, height: max(0, line.playBottom - line.playTop))
            context.fill(Path(roundedRect: rect.insetBy(dx: -3, dy: 0), cornerRadius: 3), with: .color(tint.opacity(0.28)))
            context.fill(Path(roundedRect: rect, cornerRadius: 1), with: .color(.white))
        }
    }

    /// The notes sounding now.
    private var glowing: [Int] {
        switch highlight {
        case .none:
            return []
        case let .playhead(position):
            return line.spans.compactMap { note, span in span.start <= position + 1e-6 && span.end > position ? note : nil }
        case let .step(current, _):
            return current.map { [$0] } ?? []
        }
    }

    private func color(_ role: MarkRole) -> Color {
        switch role {
        case .frame: return Palette.inkSoft.opacity(0.5)
        case .ink: return Palette.ink.opacity(0.92)
        case let .note(index): return noteColor(index, words: false)
        case let .lyric(index): return noteColor(index, words: true)
        }
    }

    private func noteColor(_ index: Int, words: Bool) -> Color {
        let plain = words ? Palette.ink.opacity(0.85) : Palette.ink
        switch highlight {
        case .none:
            return plain
        case let .playhead(position):
            guard let span = line.spans[index] else { return plain }
            if span.start > position + 1e-6 { return Palette.ink.opacity(0.42) }
            return span.end > position ? tint : plain
        case let .step(current, done):
            if index == current { return Palette.ink }
            return index < done ? tint : Palette.inkSoft.opacity(0.8)
        }
    }
}

// MARK: - A song's sheet, engraved

/// A song lesson's lead sheet engraved for one width and one way of showing it: each section's lines (see
/// `NotationEngraver`). Built from the lead chart: the melody (or, for a song that ends on its chords, slashes on the
/// strum pattern), the key the sheet is in, the clef the course's instrument reads, the chord changes, the words and,
/// for a fretted course, the tab. Kept per lesson, width and choice, so the playhead's frames cost nothing.
struct EngravedSheet {
    /// The padding of a section's card on the lead sheet: its lines are engraved for the width inside it.
    static let cardInset: CGFloat = 12

    let lines: [Int: [EngravedLine]]
    /// The melody swings (written straight).
    let swing: Bool

    func lines(for section: Int) -> [EngravedLine] { lines[section] ?? [] }

    @MainActor private static var cache: [String: EngravedSheet] = [:]

    /// The sheet for `lesson`, `width` points wide (a section card's inside). `mode` is the reader's choice; a course
    /// without tab (fretless strings, voice, a song of chords) shows the staff alone.
    @MainActor static func of(lesson: Lesson, course: LearnCourse, mode: NotationMode, width: CGFloat, textScale: CGFloat,
                              thinnestOnTop: Bool) -> EngravedSheet {
        let rounded = Int(width.rounded())
        let key = "\(lesson.id)|\(rounded)|\(mode.rawValue)|\(Int(textScale * 100))|\(thinnestOnTop)|\(NoteNames.active)"
        if let known = cache[key] { return known }
        let sheet = build(lesson: lesson, course: course, mode: mode, width: CGFloat(rounded), textScale: textScale,
                          thinnestOnTop: thinnestOnTop, key: key)
        if cache.count > 24 { cache.removeAll() }
        cache[key] = sheet
        return sheet
    }

    /// Whether the course reads tab for this lesson (fretted, with a melody).
    @MainActor static func hasTab(lesson: Lesson, course: LearnCourse) -> Bool {
        course.fretKind != nil && !course.fretless && course.stringCount > 0 && !LeadChart.of(lesson).notes.isEmpty
    }

    @MainActor private static func build(lesson: Lesson, course: LearnCourse, mode: NotationMode, width: CGFloat,
                                          textScale: CGFloat, thinnestOnTop: Bool, key: String) -> EngravedSheet {
        let chart = LeadChart.of(lesson)
        let sheet = SongSheet.of(lesson)
        let meter = max(1, chart.meter)
        let slashes = chart.notes.isEmpty
        let notes = slashes ? strokes(chart) : chart.notes
        let signature = sheet.key.map { KeySignature(tonic: $0.tonic, minor: $0.minor) } ?? .empty
        let clef = Clef.reading(instrument: course.instrument, midis: chart.notes.map(\.midi))
        let score = NotationScore(notes: notes, beatsPerBar: meter, bars: chart.bars, key: signature, clef: clef, slashes: slashes)
        let barTicks = score.meter.barTicks
        var chords: [ChordMark] = []
        for mark in chart.marks {
            guard let chord = mark.chord else { continue }
            let bar = Int((mark.beat / Double(meter) + 1e-6).rounded(.down))
            let tick = score.meter.ticks(mark.beat - Double(bar * meter))
            guard bar >= 0, bar < max(chart.bars, score.measures.count), tick >= 0, tick < barTicks else { continue }
            chords.append(ChordMark(bar: bar, tick: tick, name: ChordMark.engraved(chord.name)))
        }
        var tab: NotationTab?
        if mode.showsTab, hasTab(lesson: lesson, course: course) {
            tab = NotationTab(frets: chart.notes.map { $0.at ?? course.fretting(for: $0.midi) }, strings: course.stringCount,
                              thinnestOnTop: thinnestOnTop)
        }
        let spans = notes.map { NoteSpan(start: $0.beat / Double(meter), end: ($0.beat + $0.beats) / Double(meter)) }
        let space = max(8, min(10, width / 40))
        let type = NotationType(space: space, lyric: ((width >= 600 ? 13 : 12) * textScale).rounded(), chord: (14 * textScale).rounded())
        let engraver = NotationEngraver(score: score, lyrics: slashes ? [] : chart.lyrics, chords: chords, tab: tab, spans: spans,
                                        showStaff: tab == nil || mode.showsStaff, showTab: tab != nil, type: type)
        var lines: [Int: [EngravedLine]] = [:]
        for (index, section) in sheet.sections.enumerated() {
            let bars = section.start..<(section.start + max(1, section.bars))
            let opening = chart.chord(atBeat: Double(section.start * meter)).map { ChordMark.engraved($0.name) }
            lines[section.id] = engraver.engrave(bars: bars, width: width, opening: index == 0, closes: true,
                                                 ends: index == sheet.sections.count - 1, carried: opening, key: "\(key)|\(section.id)")
        }
        return EngravedSheet(lines: lines, swing: score.swing)
    }

    /// A song of chords as rhythm slashes: every bar with a chord strummed on the song's pattern (once a beat without
    /// one), each stroke lasting to the next.
    private static func strokes(_ chart: LeadChart) -> [TimedNote] {
        let meter = max(1, chart.meter)
        let pattern = chart.strokes.isEmpty ? (0..<meter).map(Double.init) : chart.strokes.sorted()
        var notes: [TimedNote] = []
        for bar in 0..<chart.bars where bar < chart.chords.count && chart.chords[bar] != nil {
            for (index, stroke) in pattern.enumerated() {
                let next = index + 1 < pattern.count ? pattern[index + 1] : Double(meter)
                notes.append(TimedNote(midi: 71, beat: Double(bar * meter) + stroke, beats: max(0.25, next - stroke)))
            }
        }
        return notes
    }
}

// MARK: - A phrase on a staff

/// A few notes on a staff, as a note step shows what to play: the clef the instrument reads, the notes as written with
/// their accidentals, no time signature or bars; the note to play glows, the ones played take the accent.
struct NotationPhrase: View {
    let notes: [TimedNote]
    let clef: Clef
    var accent: Color = Palette.mint
    var current: Int?
    var done = 0
    @State private var width: CGFloat = 0

    @MainActor private static var cache: [String: EngravedLine] = [:]

    var body: some View {
        let line = width > 40 ? Self.line(notes, clef: clef, width: width) : nil
        ZStack(alignment: .topLeading) {
            if let line {
                EngravedLineView(line: line, tint: accent, highlight: .step(current: current, done: done))
                    .equatable()
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(height: line?.height ?? 96)
        .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { width = $0 }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(verbatim: notes.map { NoteNames.spokenInApp(NoteName.name($0.midi)) }.joined(separator: ", ")))
    }

    @MainActor private static func line(_ notes: [TimedNote], clef: Clef, width: CGFloat) -> EngravedLine? {
        let rounded = Int(width.rounded())
        let key = "\(rounded)|\(clef.sign.rawValue)\(clef.octaveDown)|" + notes.map { "\($0.midi):\($0.beat):\($0.beats)" }.joined(separator: ",")
        if let known = cache[key] { return known }
        // As timed, from the first note; one after another as quarters when the times don't run in order.
        let start = notes.map(\.beat).min() ?? 0
        let ordered = zip(notes, notes.dropFirst()).allSatisfy { $1.beat > $0.beat }
        let shifted = ordered
            ? notes.map { TimedNote(midi: $0.midi, beat: $0.beat - start, beats: $0.beats) }
            : notes.enumerated().map { TimedNote(midi: $0.element.midi, beat: Double($0.offset), beats: 1) }
        let length = shifted.map { $0.beat + $0.beats }.max() ?? 1
        let beats = max(1, Int(length.rounded(.up)))
        let score = NotationScore(notes: shifted, beatsPerBar: beats, bars: 1, key: .empty, clef: clef, compound: false)
        let type = NotationType(space: 9, lyric: 13, chord: 14)
        var engraver = NotationEngraver(score: score, lyrics: [], chords: [], tab: nil,
                                        spans: shifted.map { NoteSpan(start: $0.beat, end: $0.beat + $0.beats) },
                                        showStaff: true, showTab: false, type: type)
        engraver.barlines = false
        engraver.timeSignature = false
        let line = engraver.engrave(bars: 0..<1, width: CGFloat(rounded), opening: false, closes: false, ends: false,
                                    carried: nil, key: "phrase|\(key)").first
        if cache.count > 40 { cache.removeAll() }
        cache[key] = line
        return line
    }
}

// MARK: - Staff, Tab or Both

/// The lead sheet's choice of notation (Staff, Tab, Both): the app's segmented pill, hugging its labels, with a 44 pt
/// target on every segment.
struct NotationModePicker: View {
    @Binding var mode: NotationMode

    var body: some View {
        SegmentedPill(options: NotationMode.allCases, selection: $mode,
                      identifier: { "song.notation.\($0.rawValue)" }) { option in
            Text(option.title).font(Typeface.label(12)).lineLimit(1).fixedSize()
        }
        .fixedSize()
        .cappedControl(Text(mode.title), cap: .xxLarge)
    }
}
