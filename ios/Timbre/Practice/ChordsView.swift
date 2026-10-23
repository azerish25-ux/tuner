import SwiftUI
import TimbreCore

struct ChordsView: View {
    enum Mode { case chords, scales }
    let mode: Mode
    @EnvironmentObject private var store: AppStore
    @EnvironmentObject private var audio: AudioService
    @State private var root = 0
    @State private var formula = ChordFormula.all[0]
    @State private var scale = ScaleFormula.all[3]
    /// The voicing that is sounding: its card lights and its strings glow until the strum fades.
    @State private var ringing: ChordShape?

    /// Open-string pitches for the current tuning, one per physical string group.
    private var openMidi: [Int] {
        var seen = Set<String>()
        return store.courses.compactMap { course in
            let key = course.anchorId ?? "\(course.index)"
            return seen.insert(key).inserted ? course.targetMidi : nil
        }
    }

    private var rootName: String { NoteNames.name(root, preferFlats: [1, 3, 8, 10].contains(root)) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text(store.tuning.name.localized + " · " + store.instrumentDisplayName).font(.subheadline).foregroundStyle(Palette.inkSoft)
                rootPicker
                if mode == .chords { chordContent } else { scaleContent }
            }
            .padding(.horizontal, Metrics.gutter).padding(.top, 12).padding(.bottom, 28)
        }
        .stageTopShade()
        .background(StageBackground(motes: false))
        .navigationTitle(mode == .chords ? "Chords" : "Scales")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { store.beginPractice(mode == .chords ? DailyActivity.Kind.chord.rawValue : DailyActivity.Kind.scale.rawValue) }
        .onDisappear { store.finishPractice(mode == .chords ? .chord : .scale) }
    }

    private var rootPicker: some View {
        EdgeRail(spacing: 6, selection: root) {
            ForEach(0..<12, id: \.self) { pc in
                Button(NoteNames.name(pc, preferFlats: [1, 3, 8, 10].contains(pc))) { root = pc; Haptics.shared.selection() }
                    .buttonStyle(ChipButtonStyle(selected: root == pc))
                    .id(pc)
            }
        }
    }

    @ViewBuilder private var chordContent: some View {
        EdgeRail(spacing: 6, selection: formula.id) {
            ForEach(ChordFormula.all) { f in
                Button(f.suffix.isEmpty ? String(localized: "Major") : f.suffix) { formula = f; Haptics.shared.selection() }
                    .buttonStyle(ChipButtonStyle(selected: formula == f))
                    .id(f.id)
            }
        }
        let name = rootName + formula.suffix
        HStack(alignment: .firstTextBaseline) {
            Text(name).font(Typeface.display(56)).foregroundStyle(Palette.ink)
            Text(formula.name).font(.subheadline).foregroundStyle(Palette.inkSoft)
            Spacer()
        }
        let shapes = ChordFinder.shapes(root: root, formula: formula, openMidi: openMidi, limit: 6)
        if shapes.isEmpty {
            Text("No comfortable shape for this chord in this tuning.").foregroundStyle(Palette.inkSoft).stillCard()
        }
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 12)], spacing: 12) {
            ForEach(shapes, id: \.self) { shape in voicingCard(shape, name: name) }
        }
    }

    /// One voicing: the chord box with suggested fingers, its fret notation and a play button.
    /// The whole card strums it; while it rings, the card lights and the sounding strings glow.
    private func voicingCard(_ shape: ChordShape, name: String) -> some View {
        let lit = ringing == shape
        return Button { strum(shape) } label: {
            VStack(spacing: 10) {
                ChordDiagram(chord: spec(for: shape), showName: false, ringing: lit ? soundingStrings(shape) : [], reservesFretLabel: true)
                    .frame(height: 150)
                HStack(spacing: 8) {
                    Text(shape.notation).font(Typeface.number(13)).foregroundStyle(Palette.inkSoft)
                        .lineLimit(1).minimumScaleFactor(0.7)
                    Spacer(minLength: 4)
                    playGlyph(lit: lit)
                }
            }
            .stillCard(cornerRadius: 22, padding: 12, tint: lit ? Palette.mint : nil)
        }
        .buttonStyle(PressScaleStyle())
        .accessibilityLabel(Text("\(name), \(shape.notation). Double tap to hear."))
    }

    private func playGlyph(lit: Bool) -> some View {
        Image(systemName: lit ? "speaker.wave.2.fill" : "play.fill")
            .font(.system(size: 11, weight: .bold))
            .foregroundStyle(lit ? Palette.onAccent : Palette.mint)
            .contentTransition(.symbolEffect(.replace))
            .frame(width: 30, height: 30)
            .background(Circle().fill(lit ? Palette.mint : Palette.mint.opacity(0.14)))
            .overlay(Circle().strokeBorder(Palette.mint.opacity(lit ? 0 : 0.3), lineWidth: 1))
    }

    private func spec(for shape: ChordShape) -> ChordSpec {
        ChordSpec(name: "", root: root, quality: formula.name, frets: shape.frets.map { $0 ?? -1 },
                  fingers: Self.fingering(shape), baseFret: shape.highestFret <= 4 ? nil : shape.lowestFret)
    }

    private func soundingStrings(_ shape: ChordShape) -> Set<Int> {
        Set(shape.frets.indices.filter { shape.frets[$0] != nil })
    }

    /// Suggested fingers (1 index … 4 little) for a voicing: a first-finger barre when the shape needs more
    /// than four fingers, otherwise one finger per note in fret order, low strings first. Nil (dots only)
    /// when no comfortable assignment exists.
    static func fingering(_ shape: ChordShape) -> [Int]? {
        var notes: [(string: Int, fret: Int)] = []
        for (index, fret) in shape.frets.enumerated() {
            if let fret, fret > 0 { notes.append((string: index, fret: fret)) }
        }
        guard let low = notes.map({ $0.fret }).min() else { return nil }
        notes.sort { $0.fret != $1.fret ? $0.fret < $1.fret : $0.string < $1.string }
        var fingers = Array(repeating: 0, count: shape.frets.count)
        var next = 1
        if notes.count > 4 {
            let barre = notes.filter { $0.fret == low }
            guard barre.count > 1 else { return nil }
            for note in barre { fingers[note.string] = 1 }
            notes.removeAll { $0.fret == low }
            next = 2
        }
        for (offset, note) in notes.enumerated() {
            // One finger per fret where possible, closing up when the fingers would run out.
            let remaining = notes.count - offset - 1
            let finger = max(next, min(note.fret - low + 1, 4 - remaining))
            guard finger <= 4 else { return nil }
            fingers[note.string] = finger
            next = finger + 1
        }
        return fingers
    }

    private func strum(_ shape: ChordShape) {
        let frequencies = shape.frets.enumerated().compactMap { index, fret in
            fret.map { PitchMath.frequency(midi: Double(openMidi[index] + $0), reference: store.settings.referencePitchHz) }
        }
        audio.playTones(frequencies, together: true, noteMs: 1500)
        Haptics.shared.selection()
        withAnimation(Motion.quick) { ringing = shape }
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(1800))
            if ringing == shape { withAnimation(Motion.settle) { ringing = nil } }
        }
    }

    /// Chip names are sentence case ("Minor pentatonic"); after the note name they read in lower case
    /// ("C minor pentatonic"), except the modes, which keep their capital ("C Dorian").
    private var scaleTitle: String {
        let name = ["dorian", "mixolydian"].contains(scale.id) ? scale.name : scale.name.prefix(1).lowercased() + String(scale.name.dropFirst())
        return rootName + " " + name
    }

    @ViewBuilder private var scaleContent: some View {
        EdgeRail(spacing: 6, selection: scale.id) {
            ForEach(ScaleFormula.all) { s in
                Button(s.name) { scale = s; Haptics.shared.selection() }
                    .buttonStyle(ChipButtonStyle(selected: scale == s))
                    .id(s.id)
            }
        }
        Text(scaleTitle).font(Typeface.display(36)).foregroundStyle(Palette.ink)
            .fixedSize(horizontal: false, vertical: true)
        scaleBoard
        Button {
            let base = (openMidi.min() ?? 48) + ((root - (openMidi.min() ?? 48)) % 12 + 12) % 12
            let notes = (scale.intervals + [12]).map { PitchMath.frequency(midi: Double(base + $0), reference: store.settings.referencePitchHz) }
            audio.playTones(notes, together: false, noteMs: 380, gapMs: 40)
        } label: { Label("Hear the scale", systemImage: "speaker.wave.2.fill") }
        .buttonStyle(BrassButtonStyle())
    }

    /// String names stay pinned in their own column while the neck scrolls beside them, running on
    /// under the card's edge.
    private var scaleBoard: some View {
        let height = CGFloat(openMidi.count) * 30 + 40
        return HStack(spacing: 0) {
            FretboardStringNames(openMidi: openMidi)
                .frame(width: 24, height: height)
            ScrollView(.horizontal, showsIndicators: false) {
                Fretboard(openMidi: openMidi, positions: ScaleMap.positions(root: root, scale: scale, openMidi: openMidi, frets: 0...15), frets: 15)
                    .frame(width: 900, height: height)
            }
            .railBleed(leading: 0, trailing: 12)
        }
        .stillCard(padding: 12)
    }
}

/// Horizontal fretboard with scale tones; roots glow. Open-string tones sit left of the nut; the string
/// names are drawn beside the board by `FretboardStringNames`, so they never sit under a dot.
struct Fretboard: View {
    let openMidi: [Int]
    let positions: [FretPosition]
    let frets: Int

    static let top: CGFloat = 20
    static let bottom: CGFloat = 20

    /// Vertical centre of a string (row 0 is the lowest string, drawn at the bottom).
    static func rowY(_ row: Int, rows: Int, height: CGFloat) -> CGFloat {
        let span = height - top - bottom
        return top + span - CGFloat(row) * span / CGFloat(max(1, rows - 1))
    }

    var body: some View {
        Canvas { context, size in
            let left: CGFloat = 30, top = Self.top
            let width = size.width - left - 10, height = size.height - top - Self.bottom
            let rows = openMidi.count
            let dy = height / CGFloat(max(1, rows - 1))
            func x(_ fret: Int) -> CGFloat { left + width * CGFloat(fret) / CGFloat(frets) }
            context.fill(Path(roundedRect: CGRect(x: left, y: top - 8, width: width, height: height + 16), cornerRadius: 6), with: .color(Color(hex: 0x2A1A12)))
            for fret in 0...frets {
                var line = Path(); line.move(to: CGPoint(x: x(fret), y: top - 8)); line.addLine(to: CGPoint(x: x(fret), y: top + height + 8))
                context.stroke(line, with: .color(fret == 0 ? Palette.ink : Color(hex: 0xC9C2B6).opacity(0.7)), lineWidth: fret == 0 ? 4 : 1.5)
                if [3, 5, 7, 9, 15].contains(fret) || fret == 12 {
                    context.draw(Text("\(fret)").font(.caption2).foregroundStyle(Palette.inkFaint), at: CGPoint(x: (x(fret) + x(fret - 1)) / 2, y: top + height + 16))
                }
            }
            for row in 0..<rows {
                let y = top + height - CGFloat(row) * dy
                var line = Path(); line.move(to: CGPoint(x: left, y: y)); line.addLine(to: CGPoint(x: left + width, y: y))
                context.stroke(line, with: .color(Color(hex: 0xD8CFC2).opacity(0.75)), lineWidth: 1 + CGFloat(rows - row) * 0.25)
            }
            for p in positions {
                let cx = p.fret == 0 ? x(0) - 15 : (x(p.fret) + x(p.fret - 1)) / 2
                let cy = top + height - CGFloat(p.string) * dy
                let r: CGFloat = p.isRoot ? 11 : 9
                context.fill(Path(ellipseIn: CGRect(x: cx - r, y: cy - r, width: r * 2, height: r * 2)), with: .color(p.isRoot ? Palette.ember : Palette.brass.opacity(0.85)))
                context.draw(Text("\(p.degree)").font(.system(size: 10, weight: .bold)).foregroundStyle(Palette.onAccent), at: CGPoint(x: cx, y: cy))
            }
        }
        .accessibilityHidden(true)
    }
}

/// The open-string names for `Fretboard`, lined up with its strings.
struct FretboardStringNames: View {
    let openMidi: [Int]
    var body: some View {
        Canvas { context, size in
            for row in openMidi.indices {
                let y = Fretboard.rowY(row, rows: openMidi.count, height: size.height)
                context.draw(Text(NoteNames.name(openMidi[row] % 12)).font(.caption2.weight(.semibold)).foregroundStyle(Palette.inkSoft),
                             at: CGPoint(x: size.width / 2 - 2, y: y))
            }
        }
        .accessibilityHidden(true)
    }
}
