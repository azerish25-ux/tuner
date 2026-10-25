import SwiftUI
import TimbreCore

/// Guided intonation check: for each string, the 12th-fret harmonic and the fretted
/// 12th-fret note should match. The difference tells which way to move the saddle.
struct IntonationView: View {
    @EnvironmentObject private var store: AppStore
    @EnvironmentObject private var audio: AudioService
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var course = 0
    @State private var step = Step.harmonic
    @State private var samples: [Double] = []
    @State private var harmonic: [Int: Double] = [:]
    @State private var offsets: [Int: Double] = [:]
    @State private var restoreAutomatic = true
    /// The neck drawing gives up height (down to where its strings still carry names) so the footnote ends
    /// above the Listen dock instead of under it.
    @State private var neckHeight: CGFloat = 140
    @AppStorage(StringOrder.storageKey) private var stringOrder: StringOrder = .tab
    @CurrentHand private var hand

    enum Step { case harmonic, fretted }
    private static let needed = 24

    /// One entry per physical course (pairs share a check), lowest course first.
    private var strings: [Course] {
        var seen = Set<String>()
        return store.courses.filter { seen.insert($0.anchorId ?? "\($0.index)").inserted }
    }

    /// The same in the order the chips, the results and the check run: lowest to highest, left to right, as the
    /// tuner's string rail reads (right to left on a left-handed instrument, as its rail does).
    private var rail: [Course] { hand.mirrorsUpright ? Array(strings.reversed()) : strings }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                picker
                instruction
                diagram
                meter
                if !offsets.isEmpty { results }
                Label("Use fresh strings tuned to pitch. Measure with the instrument in playing position.", systemImage: "info.circle")
                    .font(.footnote).foregroundStyle(Palette.inkSoft)
                    .fixedSize(horizontal: false, vertical: true)
            }
            // Clears the dock's fade, so the footnote rests fully above the Listen button.
            .padding(.horizontal, Metrics.gutter).padding(.top, 12).padding(.bottom, 24)
        }
        .fitsHero($neckHeight, in: 120...140)
        .stageTopShade()
        .background(StageBackground(motes: false))
        .navigationTitle("Intonation")
        .navigationBarTitleDisplayMode(.inline)
        .stageDock {
            Button { audio.running ? store.pauseListening() : store.startListening() } label: {
                Label(audio.running ? "Pause" : "Listen", systemImage: audio.running ? "pause.fill" : "mic.fill")
            }
            .buttonStyle(PrimaryButtonStyle())
            .accessibilityIdentifier("intonation.listen")
        }
        .onAppear {
            restoreAutomatic = store.automatic
            store.automatic = false
            store.intonationMode = true
            select(rail.first?.index ?? 0)
        }
        .onDisappear {
            store.pauseListening()
            store.intonationMode = false
            store.automatic = restoreAutomatic
        }
        .onChange(of: store.live.reading) { _, reading in capture(reading) }
    }

    private var picker: some View {
        // Equal-width chips that always fit the row, however many strings the instrument has.
        HStack(spacing: 6) {
            ForEach(rail) { string in
                let done = offsets[string.index] != nil
                let selected = string.index == course
                Button { select(string.index) } label: {
                    VStack(spacing: 2) {
                        Text(NoteReadout.split(store.courseLabel(string)).name).font(Typeface.display(.headline)).lineLimit(1).minimumScaleFactor(0.6)
                        Image(systemName: done ? "checkmark" : "circle.dotted").font(.caption2.weight(.bold))
                    }
                    .foregroundStyle(selected ? Palette.stage : Palette.ink)
                    .frame(maxWidth: .infinity, minHeight: 52)
                    .background(RoundedRectangle(cornerRadius: Metrics.cornerTile, style: .continuous).fill(selected ? AnyShapeStyle(Palette.ink) : AnyShapeStyle(Palette.stageRaised)))
                    .overlay(RoundedRectangle(cornerRadius: Metrics.cornerTile, style: .continuous).strokeBorder(selected ? .clear : Palette.controlLine, lineWidth: 1))
                    .contentShape(Rectangle())
                }
                .buttonStyle(PressScaleStyle())
                .accessibilityAddTraits(selected ? .isSelected : [])
            }
        }
    }

    private var instruction: some View {
        let label = store.courseLabel(store.activeCourse)
        return HStack(alignment: .top, spacing: 14) {
            Glyph(step == .harmonic ? "hand.point.up.left" : "hand.raised.fingers.spread", size: Glyph.lead, tint: Palette.amber)
            VStack(alignment: .leading, spacing: 4) {
                if step == .harmonic {
                    Eyebrow("Step 1 of 2")
                    Text("Play the 12th-fret harmonic on \(label)").font(Typeface.display(.title)).foregroundStyle(Palette.ink)
                        .fixedSize(horizontal: false, vertical: true)
                    Text("Touch the string lightly right above the 12th fret, pluck, and let it ring.").font(.subheadline).foregroundStyle(Palette.inkSoft)
                } else {
                    Eyebrow("Step 2 of 2")
                    Text("Now fret \(label) at the 12th fret").font(Typeface.display(.title)).foregroundStyle(Palette.ink)
                        .fixedSize(horizontal: false, vertical: true)
                    Text("Press just behind the fret with normal pressure and let it ring.").font(.subheadline).foregroundStyle(Palette.inkSoft)
                }
            }
            Spacer(minLength: 0)
        }
        .stillCard()
    }

    /// The comparison being made, drawn: the neck from nut to saddle around the 12th fret, the harmonic
    /// (a ring right over the fret) against the fretted note (a dot just behind it), with what each measured.
    private var diagram: some View {
        let position = strings.firstIndex(where: { $0.index == course }) ?? 0
        let reference = harmonic[course]
        let cents = offsets[course]
        let frettedHz: Double? = {
            guard let reference, let cents else { return nil }
            return reference * pow(2, cents / 1200)
        }()
        let lie = hand.lying(stringOrder)
        return VStack(alignment: .leading, spacing: 12) {
            IntonationNeck(labels: strings.map { NoteReadout.split(store.courseLabel($0)).name },
                           selected: position,
                           measuringHarmonic: step == .harmonic,
                           harmonicDone: reference != nil,
                           cents: cents,
                           fretted: store.instrument.familyId != "bowed_strings",
                           thinnestOnTop: lie.order.thinnestOnTop,
                           nutOnRight: lie.nutOnRight,
                           animate: !reduceMotion)
                .frame(height: neckHeight)
                .animation(Motion.settle, value: course)
            HStack(spacing: 16) {
                legend(harmonic: true, active: step == .harmonic, done: reference != nil,
                       value: reference.map { String(format: "%.1f Hz", $0) })
                legend(harmonic: false, active: step == .fretted, done: cents != nil,
                       value: frettedHz.map { String(format: "%.1f Hz", $0) })
                Spacer(minLength: 0)
                if let cents {
                    Text(String(format: "%+.1f¢", cents)).font(Typeface.number(.body))
                        .foregroundStyle(abs(cents) <= 3 ? Palette.success : Palette.amber)
                        .transition(.opacity)
                }
            }
        }
        .stillCard()
    }

    /// "Harmonic" or "Fretted" with its marker, lit while it is the note being measured.
    private func legend(harmonic: Bool, active: Bool, done: Bool, value: String?) -> some View {
        let tint = active ? Palette.amber : (done ? Palette.mint : Palette.inkFaint)
        return HStack(spacing: 8) {
            ZStack {
                if harmonic {
                    Circle().strokeBorder(tint, lineWidth: 2.5)
                } else {
                    Circle().fill(tint)
                }
            }
            .frame(width: 14, height: 14)
            VStack(alignment: .leading, spacing: 1) {
                Text(harmonic ? "Harmonic" : "Fretted").font(.caption.weight(.semibold))
                    .foregroundStyle(active ? Palette.ink : Palette.inkSoft)
                if let value {
                    Text(verbatim: value).font(Typeface.number(.caption)).foregroundStyle(Palette.inkFaint)
                } else {
                    Text("Not yet").font(.caption2).foregroundStyle(Palette.inkFaint)
                }
            }
        }
        .animation(Motion.quick, value: active)
        .accessibilityElement(children: .combine)
    }

    private var meter: some View {
        let reading = store.live.reading
        let progress = Double(samples.count) / Double(Self.needed)
        return HStack(spacing: 16) {
            ZStack {
                Circle().stroke(Palette.line, lineWidth: 5)
                Circle().trim(from: 0, to: progress).stroke(Palette.mint, style: StrokeStyle(lineWidth: 5, lineCap: .round)).rotationEffect(.degrees(-90))
                Image(systemName: audio.running ? "waveform" : "mic.slash").font(.title3).foregroundStyle(audio.running ? Palette.mint : Palette.inkFaint)
                    .symbolEffect(.variableColor.iterative, isActive: audio.running && reading.frequency != nil)
            }
            .frame(width: 60, height: 60)
            .animation(Motion.quick, value: samples.count)
            VStack(alignment: .leading, spacing: 4) {
                if let hz = reading.frequency {
                    Text(verbatim: String(format: "%.2f Hz", hz)).font(Typeface.number(.title3)).foregroundStyle(Palette.ink)
                } else {
                    Text("Not yet").font(Typeface.number(.title3)).foregroundStyle(Palette.inkFaint)
                }
                // The microphone's status, set as every practice tool sets it.
                Text(audio.running ? (reading.stable ? String(localized: "Hold it…") : String(localized: "Listening…")) : String(localized: "Tap Listen to start"))
                    .font(.subheadline.weight(.semibold)).foregroundStyle(Palette.inkSoft)
            }
            Spacer()
        }
        .stillCard()
        .accessibilityElement(children: .combine)
    }

    private var results: some View {
        VStack(alignment: .leading, spacing: 12) {
            CardTitle("Results")
            ForEach(rail.filter { offsets[$0.index] != nil }) { string in
                let cents = offsets[string.index] ?? 0
                HStack(spacing: 12) {
                    Text(NoteReadout.split(store.courseLabel(string)).name).font(Typeface.display(.title3)).foregroundStyle(Palette.ink).frame(width: 34)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(verdict(cents)).font(.subheadline.weight(.semibold)).foregroundStyle(abs(cents) <= 3 ? Palette.success : Palette.pitch(cents, locked: false))
                        Text(advice(cents)).font(.caption).foregroundStyle(Palette.inkSoft)
                    }
                    Spacer()
                    Text(String(format: "%+.1f¢", cents)).font(Typeface.number(.body)).foregroundStyle(Palette.ink)
                }
                .accessibilityElement(children: .combine)
            }
        }
        .stillCard()
    }

    private func verdict(_ cents: Double) -> String {
        if abs(cents) <= 3 { return String(localized: "Intonation is good") }
        return cents > 0 ? String(localized: "Sharp at the 12th fret") : String(localized: "Flat at the 12th fret")
    }

    private func advice(_ cents: Double) -> String {
        if abs(cents) <= 3 { return String(localized: "Within 3 cents: nothing to change.") }
        return cents > 0 ? String(localized: "Lengthen the string: move its saddle away from the neck.")
                         : String(localized: "Shorten the string: move its saddle toward the neck.")
    }

    private func select(_ index: Int) {
        course = index
        step = .harmonic
        samples = []
        store.chooseCourse(index)
    }

    private func capture(_ reading: TuningReading) {
        guard audio.running, let hz = reading.frequency, reading.stable, let cents = reading.cents, abs(cents) < 60 else {
            if reading.frequency == nil { samples.removeAll() }
            return
        }
        samples.append(hz)
        guard samples.count >= Self.needed else { return }
        let median = samples.sorted()[samples.count / 2]
        samples = []
        Haptics.shared.lock()
        switch step {
        case .harmonic:
            harmonic[course] = median
            withAnimation(Motion.settle) { step = .fretted }
        case .fretted:
            guard let reference = harmonic[course] else { step = .harmonic; return }
            withAnimation(Motion.settle) { offsets[course] = 1200 * log2(median / reference) }
            if let next = rail.first(where: { offsets[$0.index] == nil }) {
                select(next.index)
            } else {
                store.pauseListening()
            }
        }
    }
}

/// Where everything sits on the neck drawing: the nut at the left, the saddle at the right and, between two
/// breaks, the stretch of neck around the 12th fret, enlarged with every fret where it really falls
/// (fret n at 1 − 2^(−n/12) of the scale) so the harmonic and the fretted note sit clearly apart.
private struct NeckLayout {
    let size: CGSize
    let strings: Int
    let nut: CGFloat
    let saddle: CGFloat
    /// The enlarged stretch, frets 9½ to 15½, and the breaks either side of it.
    let sectionStart: CGFloat
    let sectionEnd: CGFloat
    var breakBefore: CGFloat { (nut + sectionStart) / 2 + 2 }
    var breakAfter: CGFloat { sectionEnd + 12 }
    /// The top and bottom string's y.
    let top: CGFloat
    let bottom: CGFloat
    /// Tab order (Settings › String order): the last course, string 1, on top instead of the first.
    let reversed: Bool

    private static let first = 9.5
    private static let last = 15.5

    init(size: CGSize, strings: Int, reversed: Bool = false) {
        self.reversed = reversed
        let nutX: CGFloat = 30
        let start = nutX + 28
        let saddleX = max(start + 120, size.width - 28)
        let span = min(CGFloat(max(0, strings - 1)) * 18, max(0, size.height - 64))
        self.size = size
        self.strings = max(1, strings)
        nut = nutX
        sectionStart = start
        saddle = saddleX
        sectionEnd = saddleX - 58
        top = (size.height - span) / 2
        bottom = (size.height - span) / 2 + span
    }

    private static func along(_ fret: Double) -> Double { 1 - pow(2, -fret / 12) }

    /// A fret's x (only frets inside the enlarged stretch are drawn).
    func fret(_ n: Int) -> CGFloat {
        let from = Self.along(Self.first), to = Self.along(Self.last)
        return sectionStart + (sectionEnd - sectionStart) * CGFloat((Self.along(Double(n)) - from) / (to - from))
    }
    /// The y of course `string` (its position in the course list, lowest course first).
    func y(_ string: Int) -> CGFloat {
        let row = reversed ? strings - 1 - string : string
        return strings > 1 ? top + (bottom - top) * CGFloat(row) / CGFloat(strings - 1) : (top + bottom) / 2
    }
    var spacing: CGFloat { strings > 1 ? (bottom - top) / CGFloat(strings - 1) : 18 }
    /// Touched lightly right over the 12th fret.
    func harmonicPoint(_ string: Int) -> CGPoint { CGPoint(x: fret(12), y: y(string)) }
    /// Pressed just behind the 12th fret.
    func frettedPoint(_ string: Int) -> CGPoint { CGPoint(x: fret(11) + (fret(12) - fret(11)) * 0.5, y: y(string)) }
}

/// The neck from nut to saddle, its strings in the player's string order (Settings › String order: string 1
/// on top as in tab, or the lowest string on top as you look down at it while playing), each string
/// named at the nut. On the string being checked: the harmonic point (a ring over the 12th fret) and the
/// fretted note (a dot just behind it), the one being measured in amber with a breathing ring; once both
/// are in, an arrow at the saddle shows which way it should move (a check when it's within 3 cents). For a
/// left-handed player the nut is on the right and the saddle on the left (`nutOnRight`), the words reading as usual.
private struct IntonationNeck: View {
    let labels: [String]
    let selected: Int
    let measuringHarmonic: Bool
    let harmonicDone: Bool
    let cents: Double?
    /// Frets drawn; a bowed instrument's fingerboard shows only its octave point.
    let fretted: Bool
    /// String 1 (the last course) on top.
    let thinnestOnTop: Bool
    /// The nut on the right (a left-handed player's neck).
    var nutOnRight = false
    let animate: Bool

    /// The neck's names and numbers (the string names, "12"): the caption step, growing with it, held at
    /// the xxLarge size (`body`) so the drawing keeps its layout.
    private static var label: Font { Typeface.label(.caption) }

    var body: some View {
        GeometryReader { geometry in
            let layout = NeckLayout(size: geometry.size, strings: labels.count, reversed: thinnestOnTop)
            let mirror = CanvasMirror(on: nutOnRight, width: geometry.size.width)
            ZStack(alignment: .topLeading) {
                Canvas { context, size in
                    draw(&context, layout: NeckLayout(size: size, strings: labels.count, reversed: thinnestOnTop),
                         mirror: CanvasMirror(on: nutOnRight, width: size.width))
                }
                NeckBreath(animate: animate && cents == nil)
                    .position(mirror.point(measuringHarmonic ? layout.harmonicPoint(selected) : layout.frettedPoint(selected)))
            }
        }
        .dynamicTypeSize(...DynamicTypeSize.xxLarge)
        .accessibilityIgnoresInvertColors()
        .accessibilityHidden(true)
    }

    /// Draws the neck nut-left; `mirror` turns the shapes over for a nut on the right and sets the words at the
    /// mirrored points.
    private func draw(_ context: inout GraphicsContext, layout: NeckLayout, mirror: CanvasMirror) {
        let shapes = mirror.shapes(context)
        let count = labels.count
        let edgeTop = layout.top - 10
        let edgeBottom = layout.bottom + 10
        // Fingerboard (running on past the second break) and bridge.
        let boardEnd = layout.breakAfter + 10
        shapes.fill(Path(roundedRect: CGRect(x: layout.nut, y: edgeTop, width: boardEnd - layout.nut, height: edgeBottom - edgeTop), cornerRadius: 5),
                     with: .linearGradient(Gradient(colors: [Palette.surface, Palette.stageDeep]), startPoint: CGPoint(x: 0, y: edgeTop), endPoint: CGPoint(x: 0, y: edgeBottom)))
        let bridge = CGRect(x: layout.saddle - 8, y: edgeTop - 2, width: 18, height: edgeBottom - edgeTop + 4)
        shapes.fill(Path(roundedRect: bridge, cornerRadius: 4), with: .color(Palette.surface))
        shapes.stroke(Path(roundedRect: bridge, cornerRadius: 4), with: .color(Palette.line), lineWidth: 1)
        var saddleLine = Path()
        saddleLine.move(to: CGPoint(x: layout.saddle, y: edgeTop + 1))
        saddleLine.addLine(to: CGPoint(x: layout.saddle, y: edgeBottom - 1))
        shapes.stroke(saddleLine, with: .color(Palette.ink.opacity(0.7)), style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
        if fretted {
            for n in 10...15 where n != 12 {
                var fret = Path()
                fret.move(to: CGPoint(x: layout.fret(n), y: edgeTop))
                fret.addLine(to: CGPoint(x: layout.fret(n), y: edgeBottom))
                shapes.stroke(fret, with: .color(Palette.inkFaint.opacity(0.36)), lineWidth: 1.4)
            }
            let inlay = CGPoint(x: (layout.fret(14) + layout.fret(15)) / 2, y: (layout.top + layout.bottom) / 2)
            shapes.fill(Path(ellipseIn: CGRect(x: inlay.x - 3, y: inlay.y - 3, width: 6, height: 6)), with: .color(Palette.inkFaint.opacity(0.28)))
        }
        // The 12th fret (or octave point): the midpoint of the string.
        let twelve = layout.fret(12)
        var octave = Path()
        octave.move(to: CGPoint(x: twelve, y: edgeTop - 3))
        octave.addLine(to: CGPoint(x: twelve, y: edgeBottom + 3))
        shapes.stroke(octave, with: .color(Palette.ink.opacity(fretted ? 0.75 : 0.4)),
                       style: StrokeStyle(lineWidth: fretted ? 2.2 : 1.2, lineCap: .round, dash: fretted ? [] : [3, 3]))
        context.draw(Text(verbatim: "12").font(Self.label).foregroundStyle(Palette.inkSoft), at: mirror.point(CGPoint(x: twelve, y: edgeTop - 12)))
        // A word every language translates: the system face, at `.caption2` like the names.
        context.draw(Text("Saddle").font(.caption2.weight(.semibold)).foregroundStyle(Palette.inkSoft), at: mirror.point(CGPoint(x: layout.saddle, y: edgeBottom + 13)))
        // Nut.
        shapes.fill(Path(roundedRect: CGRect(x: layout.nut - 3, y: edgeTop - 1, width: 5, height: edgeBottom - edgeTop + 2), cornerRadius: 1.5),
                     with: .color(Palette.ink.opacity(0.82)))
        // Strings, thick to thin, the one being checked lit; every string named while the rows have room for the
        // names at the current text size, else just the one being checked.
        let nameHeight = context.resolve(Text(verbatim: "E").font(Self.label)).measure(in: CGSize(width: 100, height: 100)).height
        let named = layout.spacing >= max(11, nameHeight * 0.8)
        for i in 0..<count {
            let y = layout.y(i)
            let thickness = count > 1 ? 2.2 - 1.2 * CGFloat(i) / CGFloat(count - 1) : 1.6
            var line = Path()
            line.move(to: CGPoint(x: layout.nut, y: y))
            line.addLine(to: CGPoint(x: layout.saddle, y: y))
            if i == selected {
                shapes.stroke(line, with: .color(Palette.mint.opacity(0.18)), lineWidth: thickness + 6)
                shapes.stroke(line, with: .color(Palette.mint), lineWidth: thickness)
            } else {
                shapes.stroke(line, with: .color(Palette.inkSoft.opacity(0.32)), lineWidth: thickness)
            }
            if named || i == selected {
                context.draw(Text(verbatim: labels[i]).font(Self.label).foregroundStyle(i == selected ? Palette.ink : Palette.inkSoft),
                             at: mirror.point(CGPoint(x: layout.nut - 9, y: y)), anchor: mirror.anchor(.trailing))
            }
        }
        // Breaks either side of the enlarged stretch.
        for x in [layout.breakBefore, layout.breakAfter] {
            let slant: CGFloat = 4
            let a = CGPoint(x: x - 3 + slant, y: edgeTop - 5), b = CGPoint(x: x + 3 + slant, y: edgeTop - 5)
            let c = CGPoint(x: x + 3 - slant, y: edgeBottom + 5), d = CGPoint(x: x - 3 - slant, y: edgeBottom + 5)
            var band = Path()
            band.addLines([a, b, c, d])
            band.closeSubpath()
            shapes.fill(band, with: .color(Palette.stageRaised))
            var edges = Path()
            edges.move(to: a); edges.addLine(to: d)
            edges.move(to: b); edges.addLine(to: c)
            shapes.stroke(edges, with: .color(Palette.inkFaint.opacity(0.5)), lineWidth: 1)
        }
        drawMarkers(shapes, layout: layout)
    }

    /// The two notes being compared on the lit string, and the saddle's verdict.
    private func drawMarkers(_ context: GraphicsContext, layout: NeckLayout) {
        guard labels.indices.contains(selected) else { return }
        let ring = layout.harmonicPoint(selected)
        let dot = layout.frettedPoint(selected)
        let ringColor = measuringHarmonic ? Palette.amber : (harmonicDone ? Palette.mint : Palette.inkFaint)
        let dotColor = !measuringHarmonic ? Palette.amber : (cents != nil ? Palette.mint : Palette.inkFaint)
        context.fill(Path(ellipseIn: CGRect(x: ring.x - 8, y: ring.y - 8, width: 16, height: 16)), with: .color(Palette.stageRaised.opacity(0.7)))
        context.stroke(Path(ellipseIn: CGRect(x: ring.x - 7, y: ring.y - 7, width: 14, height: 14)), with: .color(ringColor), lineWidth: 2.5)
        context.fill(Path(ellipseIn: CGRect(x: dot.x - 6.5, y: dot.y - 6.5, width: 13, height: 13)), with: .color(dotColor))
        guard let cents else { return }
        let y = layout.y(selected)
        let x = layout.saddle
        if abs(cents) <= 3 {
            var check = Path()
            check.move(to: CGPoint(x: x + 13, y: y))
            check.addLine(to: CGPoint(x: x + 16.5, y: y + 3.5))
            check.addLine(to: CGPoint(x: x + 23, y: y - 4))
            context.stroke(check, with: .color(Palette.mint), style: StrokeStyle(lineWidth: 2.2, lineCap: .round, lineJoin: .round))
        } else {
            // Sharp: lengthen the string (saddle away from the neck); flat: shorten it.
            let direction: CGFloat = cents > 0 ? 1 : -1
            let start = CGPoint(x: x + direction * 6, y: y)
            let end = CGPoint(x: x + direction * 22, y: y)
            var arrow = Path()
            arrow.move(to: start)
            arrow.addLine(to: end)
            arrow.move(to: CGPoint(x: end.x - direction * 6, y: y - 5))
            arrow.addLine(to: end)
            arrow.addLine(to: CGPoint(x: end.x - direction * 6, y: y + 5))
            context.stroke(arrow, with: .color(Palette.amber), style: StrokeStyle(lineWidth: 2.4, lineCap: .round, lineJoin: .round))
        }
    }
}

/// A ring breathing out from the note being measured. Hidden with Reduce Motion (its marker is amber anyway).
private struct NeckBreath: View {
    let animate: Bool
    @State private var out = false

    var body: some View {
        Circle().strokeBorder(Palette.amber, lineWidth: 2)
            .frame(width: 16, height: 16)
            .scaleEffect(out ? 2.4 : 1)
            .opacity(animate ? (out ? 0 : 0.9) : 0)
            .onAppear { breathe() }
            .onChange(of: animate) { _, _ in breathe() }
            .allowsHitTesting(false)
    }

    private func breathe() {
        guard animate, !out else { return }
        withAnimation(.easeOut(duration: 1.4).repeatForever(autoreverses: false)) { out = true }
    }
}
