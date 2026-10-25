import RealityKit
import SwiftUI
import TimbreCore

// MARK: - When a demonstration plays in 3D

/// "Show me": a lesson's demonstration played on the course instrument's own 3D model (`Resources/Models`), the closest
/// thing to a teacher's video the app can draw. A chord's fingertips land on the strings in finger order and each string
/// shimmers as its note sounds; notes on the neck land one by one as they sound; a strum's pick sweeps the strings in the
/// pattern's direction and rhythm. It plays in place of the picture, on the same clock as "Hear it", and the picture
/// (the chart, or the player's view: `ChordPicture`) is one tap away. Instruments without a model (ukulele, banjo), Reduce
/// Motion, Low Power Mode and a hot device keep the picture alone.
@MainActor
enum ShowMe {
    /// Seconds from the model appearing to the first fingertip landing: the camera's glide in.
    static let lead = 0.85
    /// Seconds between fingertips in a chord's demonstration (as on the lesson's explanation).
    static let landingStep = 0.45

    /// Whether the 3D stage may run now.
    static func allowed(reduceMotion: Bool) -> Bool {
        let info = ProcessInfo.processInfo
        return !reduceMotion && !info.isLowPowerModeEnabled && info.thermalState != .serious && info.thermalState != .critical
    }

    /// The model a course's demonstrations play on: its instrument's, when the model's strings match the course's.
    static func model(for course: LearnCourse, catalog: Catalog, reduceMotion: Bool) -> String? {
        guard allowed(reduceMotion: reduceMotion), course.fretKind != nil, let instrument = course.instrument,
              let asset = catalog.photo(instrumentId: instrument)?.asset,
              let id = ModelLibrary.modelID(forPhoto: asset), let rig = ModelLibrary.rig(id),
              ShowMeNeck(rig: rig, strings: course.stringCount, fretless: course.fretless) != nil else { return nil }
        return id
    }

    /// A chord demonstration's notes: each landing's note (the lowest string its finger holds) and that string, in
    /// landing order (finger 1 first). `open` is the instrument's open strings, lowest first.
    static func demoNotes(_ chord: ChordSpec, open: [Int]) -> [(rank: Int, midi: Int, string: Int)] {
        let ranks = ChordDiagram(chord: chord, landingOrder: .fingers).landingRanks
        var byRank: [Int: (midi: Int, string: Int)] = [:]
        for (i, fret) in chord.frets.enumerated() where fret > 0 && i < open.count && i < ranks.count {
            if byRank[ranks[i]] == nil { byRank[ranks[i]] = (midi: open[i] + fret, string: i) }
        }
        return byRank.keys.sorted().compactMap { rank in byRank[rank].map { (rank: rank, midi: $0.midi, string: $0.string) } }
    }

    /// What a strum demonstration rings, lowest string first: `chord`'s sounding strings or, without one, the
    /// instrument's first open chord (E minor on guitar, C on ukulele, G on mandolin, the open strings otherwise, as
    /// the lesson's explanation strums). `open` is the instrument's open strings, lowest first.
    static func strumNotes(_ chord: ChordSpec?, open: [Int], fretKind: String?) -> [Int] {
        if let chord {
            var notes: [Int] = []
            for (i, fret) in chord.frets.enumerated() where fret >= 0 && i < open.count {
                notes.append(open[i] + fret)
            }
            if !notes.isEmpty { return notes }
        }
        let shape: [Int]
        switch fretKind {
        case "guitar": shape = [0, 2, 2, 0, 0, 0]
        case "ukulele": shape = [0, 0, 0, 3]
        case "mandolin": shape = [0, 0, 2, 3]
        default: shape = Array(repeating: 0, count: open.count)
        }
        return zip(open, shape).map { $0 + $1 }
    }

    /// Notes on the neck in words for VoiceOver, in the order given ("String 3, fret 2; String 2 open").
    static func words(dots: [Fretting]) -> String {
        dots.map { dot in
            dot.fret == 0 ? String(localized: "String \(dot.string) open") : String(localized: "String \(dot.string), fret \(dot.fret)")
        }
        .joined(separator: "; ")
    }
}

// MARK: - The stage

/// The 3D demonstration in a card: the model on a dark stage feathered into the card, the camera gliding in to the shot
/// as it appears (`ShowMeController`), the fingertips and marks drawn over it, the outer strings named under a neck.
/// It shows once the model is in place (`onReady`); `onFailure` hands the card back to its picture.
///
/// Inputs follow the 2D pictures': `ringing` lights strings and each newly lit one starts to ring (a chord), a run of
/// notes rings each note as it lands, and `landStart` is the demonstration's clock (the first fingertip presses then,
/// the rest `landingStep` apart; nil: every finger in place). VoiceOver reads it as one element: `label`, then `value`.
struct ShowMeStage: View {
    let modelID: String
    /// The course's strings (lowest first in the shapes).
    let strings: Int
    var fretless = false
    let shot: ShowMeShot
    var accent: Color = Palette.mint
    var ringing: Set<Int> = []
    var landStart: Date?
    var landingStep: Double = 0.45
    var edges: StringEdges?
    let label: Text
    var value: String = ""
    var onReady: () -> Void = {}
    var onFailure: () -> Void = {}
    @State private var box = ShowMeBox()
    @State private var attached = false
    @State private var ready = false
    /// The overlay redraws every frame only while something moves (the glide, a landing, a string ringing).
    @State private var live = false
    @State private var liveUntil = Date.distantPast
    /// Fret and string numbers grow with Dynamic Type from the 11 pt floor (`DiagramType`).
    @ScaledMetric(relativeTo: .caption2) private var typeScale: CGFloat = 1

    private var controller: ShowMeController { box.controller }

    var body: some View {
        VStack(spacing: 6) {
            scene
            if case .fretting = shot, let edges, strings >= 2 {
                EdgeNamesRow(leading: edges.label(strings), trailing: edges.label(1))
                    .opacity(ready ? 1 : 0)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(label)
        .accessibilityValue(Text(value))
        .accessibilityIdentifier("lesson.showme.stage")
    }

    private var scene: some View {
        RealityView { content in
            content.camera = .virtual
            if let environment = await ModelCache.shared.environment() { controller.setEnvironment(environment) }
            configure()
            controller.attach(&content)
            attached = true
        } update: { _ in
            configure()
        }
        // One load per model; the model itself comes from the lesson's cache (`ModelCache`).
        .task(id: modelID) {
            configure()
            await controller.load(modelID, strings: strings, fretless: fretless, accent: accent)
            guard !Task.isCancelled else { return }
            report()
        }
        .onChange(of: attached) { _, _ in report() }
        .onChange(of: ringing) { old, new in
            configure()
            let added = new.subtracting(old)
            guard !added.isEmpty else { return }
            controller.strike(added)
            keepAlive(for: 1.9)
        }
        .onChange(of: landStart) { _, start in
            configure()
            controller.schedule(start)
            if let start { keepAlive(until: start.addingTimeInterval(landingLength + 1.9)) }
        }
        .onGeometryChange(for: CGSize.self) { proxy in proxy.size } action: { size in
            controller.viewSize = size
            keepAlive(for: 0.3)
        }
        // Feathered, so the stage melts into the card whatever the renderer clears to.
        .mask { StageFeather(close: 1) }
        .overlay { marks }
        .opacity(ready ? 1 : 0)
        .animation(Motion.reveal, value: ready)
    }

    private func configure() {
        controller.shot = shot
        controller.ringing = ringing
        controller.landStart = landStart
        controller.landingStep = landingStep
    }

    /// From the first fingertip's start to the last one's ring fading.
    private var landingLength: Double {
        guard case let .fretting(shape) = shot else { return 0 }
        return Double(max(0, shape.landingCount - 1)) * landingStep + 0.7
    }

    /// Ready once the model is on stage and the scene attached: the camera starts its glide in and the host hears of it.
    private func report() {
        if controller.failed {
            onFailure()
            return
        }
        guard attached, controller.loaded, !ready else { return }
        controller.beginGlide()
        ready = true
        keepAlive(for: 1.5)
        onReady()
    }

    private func keepAlive(for seconds: Double) { keepAlive(until: Date().addingTimeInterval(seconds)) }

    /// Runs the overlay's timeline until `end` (or a later end already asked for), then lets it rest.
    private func keepAlive(until end: Date) {
        let target = max(end, liveUntil)
        liveUntil = target
        live = true
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(max(0.05, target.timeIntervalSinceNow + 0.05)))
            if liveUntil == target { live = false }
        }
    }

    /// The fingertips and marks over a neck; the outer strings' names over a strum.
    private var marks: some View {
        GeometryReader { geometry in
            TimelineView(.animation(minimumInterval: 1.0 / 60, paused: !live)) { timeline in
                overlay(size: geometry.size, now: timeline.date)
            }
        }
        .opacity(ready ? 1 : 0)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    @ViewBuilder private func overlay(size: CGSize, now: Date) -> some View {
        switch shot {
        case .fretting:
            fretMarks(size: size, now: now)
        case .strum:
            strumLabels(size: size)
        }
    }

    /// The fingertips, the open and muted marks and the numbers, as they stand at `now`.
    private func fretMarks(size: CGSize, now: Date) -> some View {
        let frame = controller.marks(in: size, now: now, ringing: ringing, landStart: landStart, landingStep: landingStep)
        let scale = typeScale
        let tint = accent
        return Canvas { context, _ in
            if let frame { ShowMeDrawing.draw(&context, frame, accent: tint, scale: scale) }
        }
    }

    /// The outer strings' names above the top string and below the bottom one.
    @ViewBuilder private func strumLabels(size: CGSize) -> some View {
        if let edges, let points = controller.strumEdges(in: size) {
            ZStack {
                if let top = edges.label(strings) {
                    top.font(.system(.caption2, design: .rounded).weight(.semibold)).foregroundStyle(Palette.inkSoft)
                        .fixedSize()
                        .position(x: points.top.x, y: points.top.y - 8)
                }
                if let bottom = edges.label(1) {
                    bottom.font(.system(.caption2, design: .rounded).weight(.semibold)).foregroundStyle(Palette.inkSoft)
                        .fixedSize()
                        .position(x: points.bottom.x, y: points.bottom.y + 8)
                }
            }
            .dynamicTypeSize(...DynamicTypeSize.accessibility1)
        }
    }
}

/// Holds a stage's controller, made on first use (a controller makes RealityKit entities; `@State` evaluates its
/// initial value each time the view is initialised).
@MainActor
final class ShowMeBox {
    private(set) lazy var controller = ShowMeController()
}

/// A strum demonstrated in 3D over the rhythm's beat row: the pick sweeps the strings on every stroke while the
/// playhead runs along the row, both on the loop's clock (`RhythmLoop`'s), so the strokes meet their sound.
struct ShowMeRhythm: View {
    let modelID: String
    let strings: Int
    let strum: ShowMeStrum
    var accent: Color = Palette.mint
    /// Down and up arrows on the beat row (strummed instruments).
    var arrows = true
    var edges: StringEdges?
    var onReady: () -> Void = {}
    var onFailure: () -> Void = {}
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// The model is in place: until then the picture's own beat row shows, not this one.
    @State private var ready = false

    var body: some View {
        VStack(spacing: 10) {
            ShowMeStage(modelID: modelID, strings: strings, shot: .strum(strum), accent: accent, edges: edges,
                        label: Text("Strum pattern"), value: String(localized: "Down strokes go from the thickest string to the thinnest, up strokes back."),
                        onReady: { ready = true; onReady() }, onFailure: onFailure)
                .frame(maxHeight: .infinity)
            TimelineView(.animation(paused: reduceMotion || !ready)) { timeline in
                RhythmBar(pattern: strum.pattern, beatsPerBar: strum.beatsPerBar, accent: accent,
                          playhead: reduceMotion ? nil : playhead(at: timeline.date), arrows: arrows)
            }
        }
        .opacity(ready ? 1 : 0)
        .animation(Motion.reveal, value: ready)
    }

    /// How far through the bar the loop is at `date` (0…1).
    private func playhead(at date: Date) -> Double {
        let bar = Double(max(1, strum.beatsPerBar)) * 60 / max(30, strum.bpm)
        let into = (date.timeIntervalSince(strum.origin) / bar).truncatingRemainder(dividingBy: 1)
        return into < 0 ? into + 1 : into
    }
}

// MARK: - Controls

/// "Show me": plays the picture's demonstration on the instrument in 3D, in place (again, once it shows). A spinner
/// stands in for its glyph while the model loads.
struct ShowMeButton: View {
    var accent: Color = Palette.mint
    var loading = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 7) {
                ZStack {
                    if loading {
                        ProgressView().controlSize(.small).tint(accent)
                    } else {
                        Image(systemName: "rotate.3d").font(.system(size: 14, weight: .semibold))
                    }
                }
                .frame(width: 18, height: 18)
                Text("Show me").font(Typeface.label(14)).lineLimit(1)
            }
            .foregroundStyle(accent)
            .padding(.horizontal, 14)
            .frame(minHeight: 36)
            .background(Capsule().fill(accent.opacity(0.12)))
            .overlay(Capsule().strokeBorder(accent.opacity(0.45), lineWidth: 1))
            .contentShape(Capsule())
        }
        .buttonStyle(PressScaleStyle())
        .frame(minHeight: Metrics.minTarget)
        .fixedSize()
        .accessibilityLabel(Text("Show me"))
        .accessibilityHint(Text("Plays it on a 3D model of the instrument"))
        .accessibilityIdentifier("lesson.showme")
    }
}

/// The switch between the 3D demonstration and the picture: "3D", and the app's one picture choice by its own name
/// (Chart, or Player view: `ChordPicture`), styled as that choice's switch (`ChordPictureToggle`) with the chosen side
/// filled in the accent. It never changes the stored choice: the picture comes back as the learner left it.
struct ShowMeToggle: View {
    @Binding var on: Bool
    var accent: Color = Palette.mint
    /// What VoiceOver calls the switch.
    var label: LocalizedStringKey = "Chord view"
    @AppStorage(ChordPicture.storageKey) private var picture: ChordPicture = .chart
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Namespace private var thumb

    var body: some View {
        HStack(spacing: 2) {
            segment(Text("3D"), spoken: Text("3D model"), selected: on, id: "lesson.showme.3d") { on = true }
            segment(Text(picture.title), spoken: Text(picture.spoken), selected: !on, id: "lesson.showme.picture") { on = false }
        }
        .padding(3)
        .background(Capsule().fill(Palette.surface))
        .overlay(Capsule().strokeBorder(Palette.controlLine, lineWidth: 1))
        .fixedSize()
        .accessibilityElement(children: .contain)
        .accessibilityLabel(Text(label))
    }

    private func segment(_ title: Text, spoken: Text, selected: Bool, id: String, action: @escaping () -> Void) -> some View {
        Button {
            guard !selected else { return }
            Haptics.shared.selection()
            withMotion(Motion.settle, reduceMotion: reduceMotion) { action() }
        } label: {
            title
                .font(Typeface.label(12))
                .lineLimit(1)
                .foregroundStyle(selected ? Palette.onAccent : Palette.inkSoft)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background {
                    if selected {
                        Capsule().fill(accent).matchedGeometryEffect(id: "thumb", in: thumb)
                    }
                }
                .contentShape(Capsule())
        }
        .buttonStyle(PressScaleStyle())
        .accessibilityLabel(spoken)
        .accessibilityAddTraits(selected ? .isSelected : [])
        .accessibilityIdentifier(id)
    }
}

/// A chord card's top line while its 3D demonstration shows: the name, and the switch back to the picture where the
/// picture switch sits (`ChordCardHeader`), at the same height, so the card holds still.
struct ShowMeCardHeader: View {
    let name: String
    @Binding var on: Bool
    var accent: Color = Palette.mint

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .center, spacing: 12) {
                title
                Spacer(minLength: 8)
                ShowMeToggle(on: $on, accent: accent)
            }
            VStack(spacing: 8) {
                title
                ShowMeToggle(on: $on, accent: accent)
            }
        }
    }

    private var title: some View {
        Text(name).font(Typeface.display(28)).foregroundStyle(Palette.ink)
            .lineLimit(1)
            .accessibilityHidden(true)
    }
}

// MARK: - Drawing the marks

/// The overlay's drawing, from flat values (`ShowMeMarks`): the player's-view fingertips (`PlayerNeck`'s, in 3D), the
/// open strings' rings and the muted strings' crosses over the nut, the fret numbers down the bass side and the string
/// numbers past the last fret.
enum ShowMeDrawing {
    static func draw(_ context: inout GraphicsContext, _ marks: ShowMeMarks, accent: Color, scale: CGFloat) {
        for ring in marks.opens { open(&context, ring) }
        for ring in marks.mutes { mute(&context, ring) }
        for label in marks.frets { fretNumber(&context, label, accent: accent, scale: scale) }
        for label in marks.strings { stringNumber(&context, label, accent: accent, scale: scale) }
        for finger in marks.fingers { press(&context, finger, accent: accent) }
    }

    /// An open string: a ring in its colour over the nut with a glow, brighter while it rings.
    private static func open(_ context: inout GraphicsContext, _ ring: ShowMeMarks.Ring) {
        let r = max(4, ring.radius)
        let alpha = Double(ring.alpha)
        var light = context
        light.blendMode = .plusLighter
        let halo = r * (ring.lit ? 3.4 : 2.6)
        let strength = (ring.lit ? 0.6 : 0.4) * alpha
        context.fill(circle(ring.point, r + 2), with: .color(Palette.stageRaised.opacity(0.85 * alpha)))
        light.fill(circle(ring.point, halo), with: .radialGradient(Gradient(colors: [ring.tint.opacity(strength), ring.tint.opacity(0)]),
                                                                  center: ring.point, startRadius: 0, endRadius: halo))
        context.stroke(circle(ring.point, r), with: .color(ring.tint.mix(with: .white, by: ring.lit ? 0.6 : 0.35).opacity(alpha)), lineWidth: 2)
    }

    /// A muted string: a cross on a dark disc, so the string running up to the head doesn't cut through it.
    private static func mute(_ context: inout GraphicsContext, _ ring: ShowMeMarks.Ring) {
        let r = max(4, ring.radius)
        context.fill(circle(ring.point, r + 2.5), with: .color(Palette.stageRaised.opacity(0.9)))
        let mark = Text(verbatim: "×").font(.system(size: max(11, r * 2.2), weight: .bold)).foregroundStyle(Palette.inkSoft)
        context.draw(mark, at: ring.point)
    }

    private static func fretNumber(_ context: inout GraphicsContext, _ label: ShowMeMarks.Label, accent: Color, scale: CGFloat) {
        let text = Text(verbatim: "\(label.value)")
            .font(DiagramType.font(12, weight: label.lit ? .heavy : .semibold, scale: scale))
            .foregroundStyle(label.lit ? accent : Palette.inkFaint)
        context.draw(text, at: label.point)
    }

    private static func stringNumber(_ context: inout GraphicsContext, _ label: ShowMeMarks.Label, accent: Color, scale: CGFloat) {
        var tone = label.tint.mix(with: .white, by: 0.45)
        if label.faint { tone = Palette.inkFaint.opacity(0.6) }
        if label.lit { tone = accent }
        let text = Text(verbatim: "\(label.value)").font(DiagramType.font(11, scale: scale)).foregroundStyle(tone)
        context.draw(text, at: label.point)
    }

    /// One fingertip, or a finger laid across several strings: coming down it is bigger and higher, its shadow wide and
    /// soft on the board; pressing, the shadow tightens under it, it squashes a touch and a ring runs out across the
    /// board. A glowing, glossy pad in the accent with its finger number.
    private static func press(_ context: inout GraphicsContext, _ finger: ShowMeMarks.Finger, accent: Color) {
        let down = min(1, max(0, finger.down))
        guard down > 0.01 else { return }
        let air = 1 - down * down
        let alpha = Double(min(1, down * 2.5))
        let base = max(4, finger.radius)
        var grow: CGFloat = 1 + 0.35 * air
        if let since = finger.since, since < 0.5 {
            grow *= 1 - CGFloat(0.09 * exp(-since * 9) * cos(since * 32))
        }
        let r = base * grow
        shadow(&context, finger, radius: base * (1 + 0.6 * air), air: air, alpha: alpha)
        if let since = finger.since, since < 0.45 {
            pressRing(&context, finger, radius: base, since: since, accent: accent)
        }
        let end = finger.end ?? finger.tip
        let middle = CGPoint(x: (finger.tip.x + end.x) / 2, y: (finger.tip.y + end.y) / 2)
        // The glow around the pad.
        var light = context
        light.blendMode = .plusLighter
        for point in finger.end == nil ? [finger.tip] : [finger.tip, end] {
            let halo = r * 2.3
            light.fill(circle(point, halo), with: .radialGradient(Gradient(colors: [accent.opacity(0.32 * alpha), accent.opacity(0)]),
                                                                  center: point, startRadius: 0, endRadius: halo))
        }
        let pad = padPath(from: finger.tip, to: end, radius: r)
        let bounds = pad.boundingRect
        context.fill(pad.offsetBy(dx: 0, dy: 2.5), with: .color(accent.mix(with: .black, by: 0.45).opacity(alpha)))
        let face = Gradient(colors: [accent.mix(with: .white, by: 0.35).opacity(alpha), accent.opacity(alpha), accent.mix(with: .black, by: 0.15).opacity(alpha)])
        context.fill(pad, with: .linearGradient(face, startPoint: CGPoint(x: bounds.midX, y: bounds.minY), endPoint: CGPoint(x: bounds.midX, y: bounds.maxY)))
        let gloss = CGRect(x: bounds.minX + r * 0.35, y: bounds.minY + r * 0.14, width: max(0, bounds.width - r * 0.7), height: r * 0.7)
        context.fill(Path(roundedRect: gloss, cornerRadius: r * 0.35),
                     with: .linearGradient(Gradient(colors: [Color.white.opacity(0.5 * alpha), Color.white.opacity(0)]),
                                           startPoint: CGPoint(x: 0, y: gloss.minY), endPoint: CGPoint(x: 0, y: gloss.maxY)))
        context.stroke(pad, with: .color(Color.white.opacity(0.35 * alpha)), lineWidth: 1)
        if down > 0.6, let number = finger.finger, number > 0 {
            let label = Text(verbatim: "\(number)").font(.system(size: max(8, r * 1.1), weight: .heavy, design: .rounded))
                .foregroundStyle(Palette.onAccent.opacity(alpha))
            context.draw(label, at: middle)
        }
    }

    /// The fingertip's shadow on the board: wide, faint and offset while it is in the air, small and dark under it as it presses.
    private static func shadow(_ context: inout GraphicsContext, _ finger: ShowMeMarks.Finger, radius: CGFloat, air: CGFloat, alpha: Double) {
        let shade = Double(0.55 - 0.35 * air) * alpha
        let blur = 2 + 8 * air
        let path = flatPath(from: finger.shadow, to: finger.shadowEnd ?? finger.shadow, radius: radius, squash: finger.squash)
            .offsetBy(dx: 1.5 + 6 * air, dy: 3 + 10 * air)
        context.drawLayer { layer in
            layer.addFilter(.blur(radius: blur))
            layer.fill(path, with: .color(.black.opacity(shade)))
        }
    }

    /// The ring a press sends out, lying flat on the board.
    private static func pressRing(_ context: inout GraphicsContext, _ finger: ShowMeMarks.Finger, radius: CGFloat, since: Double, accent: Color) {
        let q = CGFloat(min(1, since / 0.45))
        let eased = 1 - (1 - q) * (1 - q)
        let spread = radius * (1.1 + 1.8 * eased)
        let path = flatPath(from: finger.shadow, to: finger.shadowEnd ?? finger.shadow, radius: spread, squash: finger.squash)
        context.stroke(path, with: .color(accent.opacity(0.6 * Double(1 - q))), lineWidth: 0.6 + 2 * (1 - q))
    }

    /// A round pad, or a capsule from `a` to `b` (a barre).
    private static func padPath(from a: CGPoint, to b: CGPoint, radius: CGFloat) -> Path {
        guard hypot(b.x - a.x, b.y - a.y) > 0.5 else { return circle(a, radius) }
        var line = Path()
        line.move(to: a)
        line.addLine(to: b)
        return line.strokedPath(StrokeStyle(lineWidth: radius * 2, lineCap: .round))
    }

    /// A pad's outline lying on the board: an ellipse flattened by `squash` (a capsule for a barre).
    private static func flatPath(from a: CGPoint, to b: CGPoint, radius: CGFloat, squash: CGFloat) -> Path {
        let h = radius * max(0.25, min(1, squash))
        guard hypot(b.x - a.x, b.y - a.y) > 0.5 else {
            return Path(ellipseIn: CGRect(x: a.x - radius, y: a.y - h, width: radius * 2, height: h * 2))
        }
        var line = Path()
        line.move(to: a)
        line.addLine(to: b)
        return line.strokedPath(StrokeStyle(lineWidth: h * 2, lineCap: .round))
    }

    private static func circle(_ center: CGPoint, _ radius: CGFloat) -> Path {
        Path(ellipseIn: CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2))
    }
}
