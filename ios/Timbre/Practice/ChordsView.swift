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
    /// Scales: note names on the neck instead of intervals (R ♭3 4 5 ♭7).
    @State private var noteNames = false
    /// Scales: the note of the run sounding now while "Hear the scale" plays.
    @State private var runStep: Int?
    @State private var runTask: Task<Void, Never>?

    /// Frets drawn on the scale neck (it scrolls sideways) and its width.
    private static let neckFrets = 15
    private static let neckWidth: CGFloat = 900
    /// One sequence note and the gap after it, as AudioService.playTones plays them.
    private static let noteMs = 380
    private static let gapMs = 40

    /// Open-string pitches for the current tuning, one per physical string group (paired courses count once).
    private var openMidi: [Int] {
        var seen = Set<String>()
        return store.courses.compactMap { course in
            let key = course.anchorId ?? "\(course.index)"
            return seen.insert(key).inserted ? course.targetMidi : nil
        }
    }

    private var preferFlats: Bool { [1, 3, 8, 10].contains(root) }
    private var rootName: String { NoteNames.name(root, preferFlats: preferFlats) }

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
        .onDisappear {
            stopRun()
            store.finishPractice(mode == .chords ? .chord : .scale)
        }
        .onChange(of: root) { _, _ in stopRun() }
        .onChange(of: scale) { _, _ in stopRun() }
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

    // MARK: Chords

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
        // Curated open and barre shapes in standard guitar tuning; playable finder shapes elsewhere.
        let shapes = ChordLibrary.voicings(root: root, formula: formula, openMidi: openMidi, limit: 6)
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
                        .lineLimit(1).minimumScaleFactor(0.6)
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
                  fingers: shape.fingers, baseFret: shape.highestFret <= 4 ? nil : shape.lowestFret)
    }

    private func soundingStrings(_ shape: ChordShape) -> Set<Int> {
        Set(shape.frets.indices.filter { shape.frets[$0] != nil })
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

    // MARK: Scales

    /// Chip names are sentence case ("Minor pentatonic"); after the note name they read in lower case
    /// ("C minor pentatonic"), except the modes, which keep their capital ("C Dorian").
    private var scaleTitle: String {
        let name = ["dorian", "mixolydian"].contains(scale.id) ? scale.name : scale.name.prefix(1).lowercased() + String(scale.name.dropFirst())
        return rootName + " " + name
    }

    /// The scale once up an octave, in one hand position: what "Hear the scale" plays and lights.
    private var scaleRun: [FretPosition] {
        ScaleMap.run(root: root, scale: scale, openMidi: openMidi, frets: 0...Self.neckFrets)
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
        Picker("Note names", selection: $noteNames) {
            Text("Intervals").tag(false)
            Text("Note names").tag(true)
        }
        .pickerStyle(.segmented)
        scaleBoard
        Button(action: playScale) {
            Label("Hear the scale", systemImage: "speaker.wave.2.fill")
                .symbolEffect(.variableColor.iterative, isActive: runStep != nil)
        }
        .buttonStyle(BrassButtonStyle())
    }

    /// String names stay pinned in their own column while the neck scrolls beside them, running on
    /// under the card's edge. While the scale plays, the neck follows the lit note.
    private var scaleBoard: some View {
        let height = CGFloat(openMidi.count) * 30 + 40
        let run = scaleRun
        let step = runStep.flatMap { run.indices.contains($0) ? $0 : nil }
        return HStack(spacing: 0) {
            FretboardStringNames(openMidi: openMidi)
                .frame(width: 24, height: height)
            ScrollViewReader { proxy in
                ScrollView(.horizontal, showsIndicators: false) {
                    Fretboard(openMidi: openMidi,
                              positions: ScaleMap.positions(root: root, scale: scale, openMidi: openMidi, frets: 0...Self.neckFrets),
                              frets: Self.neckFrets, lit: step.map { run[$0] }, trail: step.map { Array(run.prefix($0)) } ?? [],
                              noteNames: noteNames, preferFlats: preferFlats)
                        .frame(width: Self.neckWidth, height: height)
                        .overlay(alignment: .topLeading) { fretAnchors(height: height) }
                }
                .railBleed(leading: 0, trailing: 12)
                .onChange(of: runStep) { _, value in
                    guard let value, run.indices.contains(value) else { return }
                    withAnimation(Motion.settle) { proxy.scrollTo(Self.anchor(run[value].fret), anchor: .center) }
                }
            }
        }
        .stillCard(padding: 12)
    }

    /// Invisible marks over each fret so the neck can scroll a lit note into view.
    private func fretAnchors(height: CGFloat) -> some View {
        ZStack(alignment: .topLeading) {
            ForEach(0...Self.neckFrets, id: \.self) { fret in
                Color.clear.frame(width: 1, height: 1)
                    .position(x: Fretboard.centerX(fret: fret, frets: Self.neckFrets, width: Self.neckWidth), y: height / 2)
                    .id(Self.anchor(fret))
            }
        }
        .frame(width: Self.neckWidth, height: height)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private static func anchor(_ fret: Int) -> String { "fret.\(fret)" }

    /// Plays the run and lights each note as it sounds.
    private func playScale() {
        let run = scaleRun
        guard !run.isEmpty else { return }
        let reference = store.settings.referencePitchHz
        let notes = run.map { PitchMath.frequency(midi: Double(openMidi[$0.string] + $0.fret), reference: reference) }
        audio.playTones(notes, together: false, noteMs: Self.noteMs, gapMs: Self.gapMs)
        Haptics.shared.selection()
        runTask?.cancel()
        runTask = Task { @MainActor in
            for index in run.indices {
                withAnimation(Motion.quick) { runStep = index }
                try? await Task.sleep(for: .milliseconds(Self.noteMs + Self.gapMs))
                if Task.isCancelled { return }
            }
            withAnimation(Motion.settle) { runStep = nil }
        }
    }

    private func stopRun() {
        runTask?.cancel()
        runTask = nil
        runStep = nil
    }
}

/// Horizontal fretboard with scale tones labelled as intervals (R ♭3 4 5 ♭7) or note names; roots glow
/// amber. The note sounding now is lit, with the notes already played ringed behind it. Open-string tones
/// sit left of the nut; the string names are drawn beside the board by `FretboardStringNames`.
struct Fretboard: View {
    let openMidi: [Int]
    let positions: [FretPosition]
    let frets: Int
    var lit: FretPosition?
    var trail: [FretPosition] = []
    var noteNames = false
    var preferFlats = false

    static let top: CGFloat = 20
    static let bottom: CGFloat = 20
    static let left: CGFloat = 30
    static let right: CGFloat = 10

    /// Vertical centre of a string (row 0 is the lowest string, drawn at the bottom).
    static func rowY(_ row: Int, rows: Int, height: CGFloat) -> CGFloat {
        let span = height - top - bottom
        return top + span - CGFloat(row) * span / CGFloat(max(1, rows - 1))
    }

    /// Horizontal centre of the space for a fret (fret 0 sits left of the nut).
    static func centerX(fret: Int, frets: Int, width: CGFloat) -> CGFloat {
        let usable = width - left - right
        func x(_ f: Int) -> CGFloat { left + usable * CGFloat(f) / CGFloat(max(1, frets)) }
        return fret == 0 ? x(0) - 15 : (x(fret) + x(fret - 1)) / 2
    }

    private func label(_ p: FretPosition) -> String {
        noteNames ? NoteNames.name((openMidi[p.string] + p.fret) % 12, preferFlats: preferFlats) : p.intervalName
    }

    var body: some View {
        Canvas { context, size in
            let top = Self.top, left = Self.left
            let width = size.width - left - Self.right, height = size.height - top - Self.bottom
            let rows = openMidi.count
            let dy = height / CGFloat(max(1, rows - 1))
            func x(_ fret: Int) -> CGFloat { left + width * CGFloat(fret) / CGFloat(frets) }
            context.fill(Path(roundedRect: CGRect(x: left, y: top - 8, width: width, height: height + 16), cornerRadius: 6), with: .color(Color(hex: 0x2A1A12)))
            // Inlays: one dot at 3, 5, 7, 9 and 15, two at 12.
            for fret in [3, 5, 7, 9, 12, 15] where fret <= frets {
                let cx = (x(fret) + x(fret - 1)) / 2
                let ys: [CGFloat] = fret == 12 ? [top + height / 3, top + height * 2 / 3] : [top + height / 2]
                for y in ys { context.fill(Path(ellipseIn: CGRect(x: cx - 5, y: y - 5, width: 10, height: 10)), with: .color(.white.opacity(0.10))) }
            }
            for fret in 0...frets {
                var line = Path(); line.move(to: CGPoint(x: x(fret), y: top - 8)); line.addLine(to: CGPoint(x: x(fret), y: top + height + 8))
                context.stroke(line, with: .color(fret == 0 ? Palette.ink : Color(hex: 0xC9C2B6).opacity(0.7)), lineWidth: fret == 0 ? 4 : 1.5)
                if [3, 5, 7, 9, 12, 15].contains(fret) {
                    context.draw(Text("\(fret)").font(.caption2).foregroundStyle(Palette.inkFaint), at: CGPoint(x: (x(fret) + x(fret - 1)) / 2, y: top + height + 16))
                }
            }
            for row in 0..<rows {
                let y = top + height - CGFloat(row) * dy
                var line = Path(); line.move(to: CGPoint(x: left, y: y)); line.addLine(to: CGPoint(x: left + width, y: y))
                context.stroke(line, with: .color(Color(hex: 0xD8CFC2).opacity(0.75)), lineWidth: 1 + CGFloat(rows - row) * 0.25)
            }
            for p in positions {
                let center = CGPoint(x: p.fret == 0 ? x(0) - 15 : (x(p.fret) + x(p.fret - 1)) / 2, y: top + height - CGFloat(p.string) * dy)
                let isLit = lit.map { $0.string == p.string && $0.fret == p.fret } ?? false
                let played = trail.contains { $0.string == p.string && $0.fret == p.fret }
                let tint = p.isRoot ? Palette.ember : Palette.brass
                let r: CGFloat = isLit ? 13 : (p.isRoot ? 11 : 10)
                if isLit {
                    context.fill(Path(ellipseIn: CGRect(x: center.x - 22, y: center.y - 22, width: 44, height: 44)),
                                 with: .radialGradient(Gradient(colors: [tint.opacity(0.55), .clear]), center: center, startRadius: 0, endRadius: 22))
                }
                let dot = Path(ellipseIn: CGRect(x: center.x - r, y: center.y - r, width: r * 2, height: r * 2))
                context.fill(dot, with: .color(isLit ? tint : tint.opacity(p.isRoot ? 1 : 0.85)))
                if isLit {
                    context.stroke(dot, with: .color(Palette.ink), lineWidth: 2)
                } else if played {
                    context.stroke(Path(ellipseIn: CGRect(x: center.x - r - 3, y: center.y - r - 3, width: (r + 3) * 2, height: (r + 3) * 2)),
                                   with: .color(Palette.ink.opacity(0.45)), lineWidth: 1.5)
                }
                context.draw(Text(label(p)).font(.system(size: isLit ? 11 : 10, weight: .bold)).foregroundStyle(Palette.onAccent), at: center)
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
