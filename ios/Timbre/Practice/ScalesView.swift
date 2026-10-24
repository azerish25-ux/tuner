import QuartzCore
import SwiftUI
import TimbreCore

/// Scales: a root and a scale, spelled in its key (B♭ in F major, E♯ in F♯ major), on the neck to the 12th fret.
/// Position pills 1–5 frame one hand position at a time (CAGED shapes on a standard-tuned guitar) and dim the rest.
/// "Hear it" plays the position (or a run up an octave) and lights each note as it sounds; "Play along" listens
/// through the tuner's pitch pipeline and lights each note as the player hits it, up the position and back down.
struct ScaleLibraryView: View {
    @EnvironmentObject private var store: AppStore
    @EnvironmentObject private var audio: AudioService
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @AppStorage(StringOrder.storageKey) private var stringOrder: StringOrder = .tab
    @State private var root = 0
    @State private var scale = ScaleFormula.all[3]
    /// Note names on the neck instead of intervals (R ♭3 4 5 ♭7).
    @State private var noteNames = false
    /// The position framed on the neck (1–5); nil shows the whole neck.
    @State private var position: Int?
    /// "Hear it": the notes it plays and the one sounding now.
    @State private var heard: [NeckSpot] = []
    @State private var heardStep: Int?
    @State private var hearTask: Task<Void, Never>?
    /// "Play along": the run being played, and a count that sends a ripple from each note hit.
    @State private var along: PlayAlong?
    @State private var hits = 0
    /// Counts finished runs: the seal bounces.
    @State private var cheers = 0
    @State private var owner = UUID()
    /// The title's size as Dynamic Type grows it, for its ♯ and ♭ (set in the system face beside Sora).
    @ScaledMetric(relativeTo: .largeTitle) private var titleSize: CGFloat = 36

    /// One sequence note and the gap after it, as `AudioService.playTones` plays them.
    private static let noteMs = 380
    private static let gapMs = 40

    var body: some View {
        let sheet = ScaleSheet(strings: OpenStrings(store), root: root, scale: scale)
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text(store.tuning.name.localized + " · " + store.instrumentDisplayName).font(.subheadline).foregroundStyle(Palette.inkSoft)
                RootRail(root: $root) { pitchClass in
                    Spelling.name(Spelling.scale(root: pitchClass, intervals: scale.intervals, bluesNote: scale.id == "blues").root)
                }
                scaleRail
                VStack(alignment: .leading, spacing: 12) {
                    NoteGlyphs.text(sheet.title, size: titleSize).font(Typeface.display(36)).foregroundStyle(Palette.ink)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityAddTraits(.isHeader)
                    ToneStrip(tones: sheet.tones)
                }
                Picker("Note names", selection: $noteNames) {
                    Text("Intervals").tag(false)
                    Text("Note names").tag(true)
                }
                .pickerStyle(.segmented)
                if !sheet.positions.isEmpty { positionPicker(sheet) }
                neckCard(sheet)
                if audio.permissionDenied && along != nil {
                    MicrophoneHint().padding(.horizontal, -Metrics.gutter)
                }
            }
            .padding(.horizontal, Metrics.gutter).padding(.top, 12).padding(.bottom, 28)
        }
        .stageTopShade()
        .background(StageBackground(motes: false))
        .navigationTitle("Scales")
        .navigationBarTitleDisplayMode(.inline)
        .stageDock { dock(sheet) }
        .onAppear { store.beginPractice(DailyActivity.Kind.scale.rawValue) }
        .onDisappear {
            stopHearing()
            stopAlong()
            store.finishPractice(.scale)
        }
        .onChange(of: root) { _, _ in reset() }
        .onChange(of: scale) { _, _ in reset() }
    }

    private var scaleRail: some View {
        EdgeRail(spacing: 6, selection: scale.id) {
            ForEach(ScaleFormula.all) { s in
                Button(s.name) { scale = s; Haptics.shared.selection() }
                    .buttonStyle(ChipButtonStyle(selected: scale == s))
                    .id(s.id)
            }
        }
    }

    // MARK: Positions

    private func positionPicker(_ sheet: ScaleSheet) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                pill(nil, title: String(localized: "All"))
                ForEach(sheet.positions) { item in pill(item.number, title: "\(item.number)") }
            }
            Text(caption(sheet)).font(.footnote).foregroundStyle(Palette.inkSoft)
                .contentTransition(.opacity)
                .animation(Motion.quick, value: position)
        }
    }

    private func pill(_ number: Int?, title: String) -> some View {
        Button {
            guard position != number else { return }
            stopHearing()
            stopAlong()
            Haptics.shared.selection()
            withAnimation(Motion.settle) { position = number }
        } label: {
            Text(title).frame(maxWidth: .infinity)
        }
        .buttonStyle(ChipButtonStyle(selected: position == number))
        .accessibilityLabel(number.map { Text("Position \($0)") } ?? Text("Whole neck"))
        .accessibilityAddTraits(position == number ? .isSelected : [])
        .accessibilityIdentifier("scales.position.\(number ?? 0)")
    }

    /// "Position 2 · D shape · frets 9–13"; the whole neck says how to narrow it down.
    private func caption(_ sheet: ScaleSheet) -> String {
        guard let focus = sheet.positions.first(where: { $0.number == position }) else {
            return String(localized: "Whole neck · pick a position to focus on")
        }
        let low = focus.frets.lowerBound, high = focus.frets.upperBound
        if let shape = focus.shape {
            return String(localized: "Position \(focus.number) · \(shape) shape · frets \(low)–\(high)")
        }
        return String(localized: "Position \(focus.number) · frets \(low)–\(high)")
    }

    // MARK: Neck

    /// The neck card: string names pinned beside a neck drawn to the 15th fret, sized so the nut and twelve frets
    /// fill the card; a position past the 12th fret (or a note to play there) slides the neck along to it.
    private func neckCard(_ sheet: ScaleSheet) -> some View {
        let focus = sheet.positions.first { $0.number == position }
        let height = ScaleNeck.height(strings: sheet.strings.midi.count)
        let state = neckState(sheet, focus: focus)
        return HStack(spacing: 0) {
            StringNameColumn(names: sheet.strings.names, order: stringOrder)
                .frame(width: 26, height: height)
            GeometryReader { geometry in
                let fretWidth = ScaleNeck.fretSpacing(visible: geometry.size.width)
                ScrollViewReader { proxy in
                    ScrollView(.horizontal, showsIndicators: false) {
                        ScaleNeck(openMidi: sheet.strings.midi, notes: sheet.notes, names: noteNames ? sheet.names : nil,
                                  focus: focus.map { Set($0.spots) }, window: focus?.frets, lit: state.lit, trail: state.trail,
                                  target: along != nil && !(along?.finished ?? true), hit: along?.lastHit, hits: hits,
                                  fretWidth: fretWidth, order: stringOrder,
                                  focusKey: "\(root).\(scale.id).\(position ?? 0).\(noteNames)")
                            .frame(width: ScaleNeck.width(fretWidth: fretWidth), height: height)
                    }
                    .railBleed(leading: 0, trailing: 12)
                    .onAppear { ScaleNeck.reveal(state.reach, proxy: proxy, animated: false) }
                    .onChange(of: state.reach) { _, reach in ScaleNeck.reveal(reach, proxy: proxy, animated: true) }
                }
            }
            .frame(height: height)
        }
        .stillCard(padding: Metrics.tilePadding)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("\(sheet.title). \(caption(sheet))"))
    }

    /// The lit note (sounding, or the one to play), the notes behind it, and the highest fret the neck must show.
    private func neckState(_ sheet: ScaleSheet, focus: ScalePosition?) -> (lit: NeckSpot?, trail: Set<NeckSpot>, reach: Int) {
        if let along {
            let index = along.judge.index
            let lit = along.spots.indices.contains(index) ? along.spots[index] : nil
            let start = index > along.turn ? along.turn : 0
            let trail = index > start ? Set(along.spots[start..<index]) : []
            return (lit, trail, along.spots.map(\.fret).max() ?? 0)
        }
        if let step = heardStep, heard.indices.contains(step) {
            return (heard[step], Set(heard.prefix(step)), heard.map(\.fret).max() ?? 0)
        }
        return (nil, [], focus?.frets.upperBound ?? 0)
    }

    // MARK: Dock

    @ViewBuilder private func dock(_ sheet: ScaleSheet) -> some View {
        Group {
            if let along {
                if along.finished { finishedBar(along, sheet: sheet) } else { playingBar(along) }
            } else {
                HStack(spacing: 12) {
                    Button { hear(sheet) } label: {
                        Label("Hear it", systemImage: "speaker.wave.2.fill")
                            .symbolEffect(.variableColor.iterative, isActive: heardStep != nil && !reduceMotion)
                    }
                    .buttonStyle(SecondaryButtonStyle())
                    .frame(width: 136)
                    .accessibilityIdentifier("scales.hear")
                    Button { startAlong(sheet) } label: { Label("Play along", systemImage: "mic.fill") }
                        .buttonStyle(PrimaryButtonStyle())
                        .accessibilityIdentifier("scales.playAlong")
                        .accessibilityHint(Text("Listens and lights each note as you play it."))
                }
            }
        }
        .animation(Motion.settle, value: along == nil)
        .animation(Motion.settle, value: along?.finished ?? false)
    }

    /// Playing along: the note to play next, how far through the run, and what the microphone hears.
    private func playingBar(_ run: PlayAlong) -> some View {
        let index = run.judge.index
        let next = run.midis.indices.contains(index) ? run.name(of: run.midis[index]) : ""
        let wrong = run.heard.map { run.isSlip($0) } ?? false
        return HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    Text("Next: \(next)").font(.subheadline.weight(.semibold)).foregroundStyle(Palette.ink)
                        .contentTransition(.opacity)
                    if let heard = run.heard, wrong {
                        Text("Hearing \(run.name(of: heard))").font(.footnote).foregroundStyle(Palette.amber)
                            .transition(.opacity)
                    }
                    Spacer(minLength: 0)
                    Text.fraction(index, run.midis.count).font(Typeface.number(13)).foregroundStyle(Palette.inkSoft)
                        .contentTransition(.numericText())
                }
                ProgressLine(value: Double(index) / Double(max(1, run.midis.count)), color: Palette.mint, height: 4)
            }
            .padding(.horizontal, 16).padding(.vertical, 10)
            .frame(maxWidth: .infinity, minHeight: 54)
            .background(RoundedRectangle(cornerRadius: Metrics.corner, style: .continuous).fill(Palette.stageRaised))
            .overlay(RoundedRectangle(cornerRadius: Metrics.corner, style: .continuous).strokeBorder(Palette.mint.opacity(0.35), lineWidth: 1))
            .animation(Motion.quick, value: index)
            .accessibilityElement(children: .combine)
            Button("Stop") { stopAlong() }
                .buttonStyle(SecondaryButtonStyle())
                .frame(width: 96)
                .accessibilityIdentifier("scales.stop")
        }
    }

    /// The run is done: a seal, how clean it was (notes asked for over notes played), and Play again.
    private func finishedBar(_ run: PlayAlong, sheet: ScaleSheet) -> some View {
        let percent = Int((run.accuracy * 100).rounded())
        return HStack(spacing: 12) {
            HStack(spacing: 12) {
                Image(systemName: "checkmark.seal.fill").font(.system(size: 20, weight: .semibold)).foregroundStyle(Palette.mint)
                    .symbolEffect(.bounce, value: cheers)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Nice — that’s right.").font(.subheadline.weight(.semibold)).foregroundStyle(Palette.ink)
                    Text("\(percent)% clean").font(.footnote).foregroundStyle(ScoreTint.color(run.accuracy))
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 16)
            .frame(maxWidth: .infinity, minHeight: 54)
            .background(Capsule().fill(Palette.mint.opacity(0.12)))
            .overlay(Capsule().strokeBorder(Palette.mint.opacity(0.5), lineWidth: 1))
            .accessibilityElement(children: .combine)
            Button("Play again") { startAlong(sheet) }
                .buttonStyle(PrimaryButtonStyle())
                .frame(width: 132)
                .accessibilityIdentifier("scales.playAlong")
        }
    }

    // MARK: Hear it

    /// The notes "Hear it" plays and "Play along" starts from: the position up from its lowest note, or on the
    /// whole neck the scale once up an octave in one hand position.
    private func ascending(_ sheet: ScaleSheet) -> [NeckSpot] {
        if let focus = sheet.positions.first(where: { $0.number == position }) { return focus.spots }
        return ScaleMap.run(root: root, scale: scale, openMidi: sheet.strings.midi, frets: 0...ScaleNeck.frets)
            .map { NeckSpot(string: $0.string, fret: $0.fret) }
    }

    private func hear(_ sheet: ScaleSheet) {
        let spots = ascending(sheet)
        guard !spots.isEmpty else { return }
        let reference = store.settings.referencePitchHz
        let midi = sheet.strings.midi
        audio.playTones(spots.map { PitchMath.frequency(midi: Double(midi[$0.string] + $0.fret), reference: reference) },
                        together: false, noteMs: Self.noteMs, gapMs: Self.gapMs)
        Haptics.shared.selection()
        hearTask?.cancel()
        heard = spots
        hearTask = Task { @MainActor in
            for index in spots.indices {
                withAnimation(Motion.quick) { heardStep = index }
                try? await Task.sleep(for: .milliseconds(Self.noteMs + Self.gapMs))
                if Task.isCancelled { return }
            }
            withAnimation(Motion.settle) { heardStep = nil }
        }
    }

    private func stopHearing() {
        hearTask?.cancel()
        hearTask = nil
        heardStep = nil
    }

    // MARK: Play along

    /// Listens for the position (or the run) up and back down, through the lessons' microphone pipeline: the
    /// tuner's pitch tracker, the nearest note held a moment within 45 cents. Each note lights as it is hit.
    private func startAlong(_ sheet: ScaleSheet) {
        stopHearing()
        let up = ascending(sheet)
        guard up.count >= 2 else { return }
        let spots = up + up.dropLast().reversed()
        let midi = sheet.strings.midi
        let notes = spots.map { midi[$0.string] + $0.fret }
        let run = PlayAlong(spots: spots, midis: notes, turn: up.count - 1, names: sheet.names,
                            judge: NoteSequenceJudge(notes: notes, holdSeconds: 0.12, toleranceCents: 45))
        withAnimation(Motion.settle) { along = run }
        Haptics.shared.selection()
        let reference = store.settings.referencePitchHz
        store.gameTargetHz = notes.first.map { PitchMath.frequency(midi: Double($0), reference: reference) }
        let low = PitchMath.frequency(midi: Double((notes.min() ?? 40) - 3), reference: reference)
        let high = PitchMath.frequency(midi: Double((notes.max() ?? 76) + 7), reference: reference)
        store.startLessonListening(owner: owner, lowHz: max(30, low), highHz: min(2400, high)) { hz, _ in
            heardPitch(hz)
        }
    }

    private func heardPitch(_ hz: Double?) {
        guard var run = along, !run.finished else { return }
        let reference = store.settings.referencePitchHz
        let note = HeardNote(hz: hz, reference: reference)
        let event = run.judge.update(time: CACurrentMediaTime(), midi: note?.midi, cents: note?.cents)
        run.heard = note?.midi
        switch event {
        case .wrong(let midi)?:
            if run.isSlip(midi) { run.slips += 1 }
        case .hit(let index)?:
            run.lastHit = run.spots.indices.contains(index) ? run.spots[index] : nil
            hits += 1
            if run.finished {
                along = run
                finishAlong()
                return
            }
            Haptics.shared.selection()
            store.gameTargetHz = run.judge.current.map { PitchMath.frequency(midi: Double($0), reference: reference) }
        default:
            break
        }
        along = run
    }

    private func finishAlong() {
        store.stopLessonListening(owner: owner)
        SoundFX.shared.play(.complete)
        Haptics.shared.done()
        // A beat later, once the finished bar is on screen, so its seal bounces.
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(80))
            cheers += 1
        }
    }

    private func stopAlong() {
        guard along != nil else { return }
        store.stopLessonListening(owner: owner)
        withAnimation(Motion.settle) { along = nil }
    }

    /// A new root or scale: whatever was sounding or listening stops, and the neck shows the whole scale again
    /// unless the position still exists.
    private func reset() {
        stopHearing()
        stopAlong()
    }
}

/// What the Scales screen draws from: the open strings, the scale spelled in its key, every tone on the neck and
/// the five positions.
private struct ScaleSheet {
    let strings: OpenStrings
    let title: String
    let tones: [ToneStrip.Tone]
    /// Pitch class to its name in this key.
    let names: [Int: String]
    let notes: [FretPosition]
    let positions: [ScalePosition]

    init(strings: OpenStrings, root: Int, scale: ScaleFormula) {
        self.strings = strings
        let spelled = Spelling.scale(root: root, intervals: scale.intervals, bluesNote: scale.id == "blues")
        var names: [Int: String] = [:]
        var tones: [ToneStrip.Tone] = []
        for (interval, note) in zip(scale.intervals, spelled.tones) {
            let name = Spelling.name(note)
            names[note.pitchClass] = name
            tones.append(ToneStrip.Tone(name: name, degree: IntervalName.short(interval), isRoot: interval == 0))
        }
        self.names = names
        self.tones = tones
        // Chip names are sentence case ("Minor pentatonic"); after the note they read in lower case ("C minor
        // pentatonic"), except the modes, which keep their capital ("C Dorian").
        let kind = ["dorian", "mixolydian"].contains(scale.id) ? scale.name : scale.name.prefix(1).lowercased() + String(scale.name.dropFirst())
        title = Spelling.name(spelled.root) + " " + kind
        notes = ScaleMap.positions(root: root, scale: scale, openMidi: strings.midi, frets: 0...ScaleNeck.frets)
        positions = ScalePositions.positions(root: root, scale: scale, openMidi: strings.midi)
    }
}

/// A play-along run: its notes up the position and back down (`turn` is the top one), the judge listening for
/// them, what the microphone last heard and the last note hit.
struct PlayAlong {
    let spots: [NeckSpot]
    let midis: [Int]
    let turn: Int
    let names: [Int: String]
    var judge: NoteSequenceJudge
    var heard: Int?
    var lastHit: NeckSpot?
    /// Wrong notes played on the way (not the last note still ringing, nor the tracker hearing an octave out).
    var slips = 0

    var finished: Bool { judge.isFinished }
    /// The note just hit, which may still be ringing.
    var previous: Int? { judge.index > 0 && judge.index <= midis.count ? midis[judge.index - 1] : nil }
    /// Notes asked for over notes played.
    var accuracy: Double { midis.isEmpty ? 1 : Double(midis.count) / Double(midis.count + slips) }

    /// Whether `midi` is a slip: neither the note to play (in any octave) nor the one still ringing.
    func isSlip(_ midi: Int) -> Bool {
        guard let current = judge.current else { return false }
        return (midi - current) % 12 != 0 && midi != previous
    }

    /// A heard note named in the scale's key when it belongs to it ("E♭" in C minor), else as lessons name it.
    func name(of midi: Int) -> String {
        names[((midi % 12) + 12) % 12] ?? NoteName.pitchClass(midi)
    }
}

// MARK: - The neck

/// The neck to the 15th fret, nut on the left, its strings in the player's string order (Settings › String order):
/// every scale tone as a dot labelled with its interval or its name, roots amber. A position is framed and the
/// notes outside it shrink to faint marks. The note sounding (or to play next) is lit, the ones before it ringed;
/// while playing along the target breathes and each hit sends out a ripple.
struct ScaleNeck: View {
    let openMidi: [Int]
    let notes: [FretPosition]
    /// Pitch class to name, to label notes by name; nil labels them by interval.
    let names: [Int: String]?
    var focus: Set<NeckSpot>?
    var window: ClosedRange<Int>?
    var lit: NeckSpot?
    var trail: Set<NeckSpot> = []
    /// Playing along: `lit` is the note to play.
    var target = false
    var hit: NeckSpot?
    var hits = 0
    let fretWidth: CGFloat
    let order: StringOrder
    /// Changes with what the dots show (root, scale, position, labels): the dots cross-fade to the new set.
    let focusKey: String
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @ScaledMetric(relativeTo: .caption2) private var typeScale: CGFloat = 1

    static let frets = 15
    /// Room left of the nut for the open strings' dots.
    static let nut: CGFloat = 30
    static let top: CGFloat = 16
    static let rowGap: CGFloat = 28
    /// Under the last string: the fret numbers.
    static let bottom: CGFloat = 30

    static func height(strings: Int) -> CGFloat { top + CGFloat(max(1, strings - 1)) * rowGap + bottom }
    /// The nut and twelve frets fill `visible` points.
    static func fretSpacing(visible: CGFloat) -> CGFloat { max(20, (visible - nut - 4) / 12) }
    static func width(fretWidth: CGFloat) -> CGFloat { nut + CGFloat(frets) * fretWidth + 10 }
    /// The fret wire after fret `fret` (0 is the nut).
    static func wireX(_ fret: Int, fretWidth: CGFloat) -> CGFloat { nut + CGFloat(fret) * fretWidth }
    /// The middle of the space where fret `fret` is pressed (an open string sits left of the nut).
    static func centerX(_ fret: Int, fretWidth: CGFloat) -> CGFloat {
        fret == 0 ? nut - 15 : nut + (CGFloat(fret) - 0.5) * fretWidth
    }
    /// A string's line: `index` counts from the lowest-numbered course (the thickest string on a guitar).
    static func rowY(index: Int, count: Int, order: StringOrder) -> CGFloat {
        top + CGFloat(order.row(ofString: count - index, count: count)) * rowGap
    }

    /// Slides the neck so frets up to `reach` show: home at the nut, or the 13th–15th frets brought in from the right.
    static func reveal(_ reach: Int, proxy: ScrollViewProxy, animated: Bool) {
        let id = reach > 12 ? anchor(min(frets, reach)) : anchor(0)
        let edge: UnitPoint = reach > 12 ? .trailing : .leading
        if animated {
            withAnimation(Motion.settle) { proxy.scrollTo(id, anchor: edge) }
        } else {
            proxy.scrollTo(id, anchor: edge)
        }
    }

    static func anchor(_ fret: Int) -> String { "neck.fret.\(fret)" }

    private var radius: CGFloat { min(11, fretWidth * 0.44, Self.rowGap * 0.4) }
    private var labelSize: CGFloat { 11 * min(1.3, max(1, typeScale)) }
    private var bottomY: CGFloat { Self.top + CGFloat(max(1, openMidi.count - 1)) * Self.rowGap }

    private func y(_ string: Int) -> CGFloat { Self.rowY(index: string, count: openMidi.count, order: order) }
    private func point(_ spot: NeckSpot) -> CGPoint { CGPoint(x: Self.centerX(spot.fret, fretWidth: fretWidth), y: y(spot.string)) }

    var body: some View {
        ZStack(alignment: .topLeading) {
            Canvas { context, _ in drawBoard(&context) }
            windowFrame
            Canvas { context, _ in drawDots(&context) }
                .id(focusKey)
                .transition(.opacity)
            if target, let lit { TargetPulse(center: point(lit), radius: radius, still: reduceMotion) }
            // Waiting at the target before the first hit, so that one ripples too.
            if !reduceMotion, let spot = hit ?? (target ? lit : nil) { ripple(at: point(spot)) }
            anchors
        }
        .animation(Motion.settle, value: focusKey)
        .animation(Motion.settle, value: window)
        .accessibilityHidden(true)
    }

    // MARK: Board

    private func drawBoard(_ context: inout GraphicsContext) {
        let top = Self.top, bottom = bottomY
        let left = Self.nut, right = Self.wireX(Self.frets, fretWidth: fretWidth)
        context.fill(Path(roundedRect: CGRect(x: left, y: top - 10, width: right - left, height: bottom - top + 20), cornerRadius: 6),
                     with: .linearGradient(Gradient(colors: [Color(hex: 0x30200F), Color(hex: 0x22150C)]),
                                           startPoint: CGPoint(x: 0, y: top), endPoint: CGPoint(x: 0, y: bottom)))
        // Inlays at 3, 5, 7, 9 and 15, two at 12.
        for fret in [3, 5, 7, 9, 12, 15] where fret <= Self.frets {
            let x = Self.centerX(fret, fretWidth: fretWidth)
            let ys: [CGFloat] = fret == 12 ? [top + (bottom - top) / 3, top + (bottom - top) * 2 / 3] : [(top + bottom) / 2]
            for y in ys { context.fill(Path(ellipseIn: CGRect(x: x - 4.5, y: y - 4.5, width: 9, height: 9)), with: .color(.white.opacity(0.10))) }
        }
        for fret in 0...Self.frets {
            let x = Self.wireX(fret, fretWidth: fretWidth)
            var wire = Path()
            wire.move(to: CGPoint(x: x, y: top - 10))
            wire.addLine(to: CGPoint(x: x, y: bottom + 10))
            context.stroke(wire, with: .color(fret == 0 ? Palette.ink : Color(hex: 0xC9C2B6).opacity(0.6)), lineWidth: fret == 0 ? 4 : 1.5)
        }
        for fret in [3, 5, 7, 9, 12, 15] where fret <= Self.frets {
            context.draw(Text("\(fret)").font(.system(size: labelSize, weight: .semibold, design: .rounded)).foregroundStyle(Palette.inkFaint),
                         at: CGPoint(x: Self.centerX(fret, fretWidth: fretWidth), y: bottom + 21))
        }
        // Strings, thicker as they go lower.
        let pitches = openMidi.sorted()
        for (index, open) in openMidi.enumerated() {
            let rank = CGFloat(pitches.firstIndex(of: open) ?? 0)
            let thickness = 1 + 1.6 * (1 - rank / CGFloat(max(1, openMidi.count - 1)))
            var line = Path()
            line.move(to: CGPoint(x: left, y: y(index)))
            line.addLine(to: CGPoint(x: right, y: y(index)))
            context.stroke(line, with: .color(Color(hex: 0xD8CFC2).opacity(0.75)), lineWidth: thickness)
        }
    }

    /// The chosen position's frets, framed in mint across every string.
    @ViewBuilder private var windowFrame: some View {
        if let window {
            let left = window.lowerBound == 0 ? 2 : Self.wireX(window.lowerBound - 1, fretWidth: fretWidth)
            let right = Self.wireX(max(0, window.upperBound), fretWidth: fretWidth)
            let shape = RoundedRectangle(cornerRadius: 10, style: .continuous)
            shape.fill(Palette.mint.opacity(0.08))
                .overlay(shape.strokeBorder(Palette.mint.opacity(0.6), lineWidth: 1.5))
                .frame(width: max(fretWidth, right - left), height: bottomY - Self.top + 26)
                .offset(x: left, y: Self.top - 13)
                .transition(.opacity)
        }
    }

    // MARK: Dots

    private func drawDots(_ context: inout GraphicsContext) {
        let r = radius
        for note in notes {
            let spot = NeckSpot(string: note.string, fret: note.fret)
            let center = point(spot)
            let tint = note.isRoot ? Palette.amber : Palette.mint
            if let focus, !focus.contains(spot) {
                // In the scale, outside the position: a faint mark keeps the neck's map without crowding the box.
                let mark = r * 0.5
                context.fill(Path(ellipseIn: CGRect(x: center.x - mark, y: center.y - mark, width: mark * 2, height: mark * 2)),
                             with: .color(tint.opacity(0.28)))
                continue
            }
            let isLit = lit == spot
            let size = isLit ? r + 2.5 : r
            if isLit {
                context.fill(Path(ellipseIn: CGRect(x: center.x - 24, y: center.y - 24, width: 48, height: 48)),
                             with: .radialGradient(Gradient(colors: [tint.opacity(0.55), .clear]), center: center, startRadius: 0, endRadius: 24))
            }
            let dot = Path(ellipseIn: CGRect(x: center.x - size, y: center.y - size, width: size * 2, height: size * 2))
            context.fill(dot, with: .color(isLit ? tint : tint.opacity(note.isRoot ? 1 : 0.88)))
            if isLit {
                context.stroke(dot, with: .color(Palette.ink), lineWidth: 2)
            } else if trail.contains(spot) {
                context.stroke(Path(ellipseIn: CGRect(x: center.x - size - 3, y: center.y - size - 3, width: (size + 3) * 2, height: (size + 3) * 2)),
                               with: .color(Palette.ink.opacity(0.5)), lineWidth: 1.5)
            }
            let label = names?[((openMidi[note.string] + note.fret) % 12 + 12) % 12] ?? note.intervalName
            let points = label.count > 2 ? labelSize - 2.5 : (isLit ? labelSize + 1 : labelSize)
            context.draw(Text(label).font(.system(size: points, weight: .bold, design: .rounded)).foregroundStyle(Palette.onAccent), at: center)
        }
    }

    /// A ring leaving the note just hit.
    private func ripple(at center: CGPoint) -> some View {
        Circle()
            .strokeBorder(Palette.mint, lineWidth: 2)
            .frame(width: radius * 2, height: radius * 2)
            .keyframeAnimator(initialValue: RippleFrame(), trigger: hits) { ring, frame in
                ring.scaleEffect(frame.scale).opacity(frame.opacity)
            } keyframes: { _ in
                KeyframeTrack(\.scale) {
                    LinearKeyframe(1, duration: 0.01)
                    CubicKeyframe(2.6, duration: 0.45)
                }
                KeyframeTrack(\.opacity) {
                    LinearKeyframe(0.9, duration: 0.01)
                    LinearKeyframe(0, duration: 0.45)
                }
            }
            .position(center)
            .allowsHitTesting(false)
    }

    private struct RippleFrame {
        var scale: CGFloat = 1
        var opacity: Double = 0
    }

    /// Invisible marks at the nut and past each fret wire, so the neck can scroll a fret into view.
    private var anchors: some View {
        let height = Self.height(strings: openMidi.count)
        return ZStack(alignment: .topLeading) {
            ForEach(0...Self.frets, id: \.self) { fret in
                Color.clear.frame(width: 1, height: 1)
                    .position(x: fret == 0 ? 1 : Self.wireX(fret, fretWidth: fretWidth) + 8, y: height / 2)
                    .id(Self.anchor(fret))
            }
        }
        .frame(width: Self.width(fretWidth: fretWidth), height: height)
        .allowsHitTesting(false)
    }
}

/// The note to play next, breathing: a ring swelling and easing around its dot (still with Reduce Motion).
private struct TargetPulse: View {
    let center: CGPoint
    let radius: CGFloat
    let still: Bool

    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 30, paused: still)) { timeline in
            Canvas { context, _ in
                let t = timeline.date.timeIntervalSinceReferenceDate
                let phase = still ? 0.5 : (sin(t * 5) + 1) / 2
                let ring = radius + 5 + CGFloat(phase) * 5
                context.stroke(Path(ellipseIn: CGRect(x: center.x - ring, y: center.y - ring, width: ring * 2, height: ring * 2)),
                               with: .color(Palette.mint.opacity(0.9 - 0.5 * phase)), lineWidth: 2)
            }
        }
        .allowsHitTesting(false)
    }
}

/// The open strings' names beside the neck, on the neck's string lines.
struct StringNameColumn: View {
    let names: [String]
    let order: StringOrder
    @ScaledMetric(relativeTo: .caption2) private var typeScale: CGFloat = 1

    var body: some View {
        Canvas { context, size in
            for index in names.indices {
                let y = ScaleNeck.rowY(index: index, count: names.count, order: order)
                context.draw(Text(names[index]).font(.system(size: 11 * min(1.3, max(1, typeScale)), weight: .semibold, design: .rounded))
                                .foregroundStyle(Palette.inkSoft),
                             at: CGPoint(x: size.width / 2 - 2, y: y))
            }
        }
        .accessibilityHidden(true)
    }
}
