import RealityKit
import SwiftUI
import TimbreCore

// MARK: - When a demonstration plays in 3D

/// "Show me": a lesson's demonstration played on the course instrument's own 3D model (`Resources/Models`), the closest
/// thing to a teacher's video the app can draw. A chord's fingertips land on the strings in finger order and each string
/// shimmers as its note sounds; notes on the neck land one by one as they sound; a strum's pick sweeps the strings in the
/// pattern's direction and rhythm. It plays in place of the picture, on the same clock as "Hear it", and the picture
/// (the chart, or the player's view: `ChordPicture`) is one tap away. Instruments without a model (ukulele, banjo), Reduce
/// Motion, Low Power Mode and a hot device keep the picture alone. A left-handed player sees the stage turned over as
/// every other picture is (`HandStyle`), its words reading as usual.
///
/// The model is a hook for more: a fretting hand rig posed from `ShowMeShape.presses` and models for the instruments
/// that have none yet plug in through `ModelLibrary` (a usdz and its rig, named by the photo it stands for in
/// models-manifest.json); nothing else here changes when they arrive.
///
/// It is the lesson's teacher: the first time a chord or a strum pattern appears in a course (`firstTime`, remembered
/// in the settings by `ShowMeKey`), its demonstration plays by itself on the model once the card has settled, never
/// while a step is listening; after that it is one tap away. A line under the button says what to watch
/// (`ShowMeCaption`), read from the shape or the pattern.
@MainActor
enum ShowMe {
    /// Seconds from the model appearing to the first fingertip landing: the camera's glide in.
    static let lead = 0.85
    /// Seconds between fingertips in a chord's demonstration (as on the lesson's explanation).
    static let landingStep = 0.45
    /// Seconds from a step appearing to its first-time demonstration starting: the card has settled.
    static let settle = 0.7
    /// Seconds a first-time demonstration waits for the model before the step carries on with its picture (and,
    /// on a playing step, opens the microphone).
    static let patience = 5.0
    /// Seconds a stage waits, once its model is on stage, for the renderer to draw it behind the picture
    /// (`ShowMeController.warm`) before showing it anyway.
    static let warmLimit = 2.5
    /// Why the last stage gave up on its model, in plain words (the DEBUG probes read it; nil while none has).
    static var lastProblem: String?

    /// Whether demonstration `key` plays by itself as its card settles: the first time it appears in `course`. The
    /// App Store chord scene keeps its chord step as it is captured (the chart with every string lit).
    static func firstTime(_ key: String, course: LearnCourse, settings: UserSettings) -> Bool {
        #if DEBUG
        if DemoScene.current == .lessonChord { return false }
        // UI tests and the App Preview walk lessons on a timed demo pitch: only the show-me scene plays by itself.
        if ProcessInfo.processInfo.environment["TIMBRE_DEMO_PITCH"] == "1" && DemoScene.current != .showMe { return false }
        #endif
        return !settings.hasShownDemo(key, in: course.id)
    }

    // MARK: What to watch

    /// The line under "Show me" for a chord, read from its shape: a finger laid flat first, the fingers landing in
    /// order, one finger, or open strings ringing.
    static func caption(for chord: ChordSpec) -> Text {
        let shape = ShowMeShape(chord: chord)
        if shape.presses.contains(where: { $0.first != $0.last }) {
            return shape.presses.count > 1 ? Text("Watch one finger lie flat, then the rest land")
                                           : Text("Watch one finger lie flat across the strings")
        }
        switch shape.landingCount {
        case 0: return Text("Watch every string ring")
        case 1: return Text("Watch the finger land, then let it ring")
        default: return Text("Watch the fingers land in order")
        }
    }

    /// The line under "Show me" for a strum, read from its pattern: strokes on the beat go down, between the beats up
    /// (as the beat row draws them).
    static func caption(pattern: [Double], beatsPerBar: Int) -> Text {
        let hits = Set(pattern.filter { $0.isFinite && $0 >= 0 && $0 < 1_000 })
        let downs = hits.filter { $0.truncatingRemainder(dividingBy: 1) == 0 }.map { Int($0) + 1 }.sorted()
        let ups = hits.count - downs.count
        if ups > 0 {
            return downs.isEmpty ? Text("Watch the pick: up between the beats")
                                 : Text("Watch the pick: down on the beat, up in between")
        }
        if downs.count == 1 { return Text("Watch the pick: one strum, then let it ring") }
        if downs.isEmpty || Set(downs) == Set(1...max(1, beatsPerBar)) { return Text("Watch the pick: down on every beat") }
        let beats = ListFormatter.localizedString(byJoining: downs.map(String.init))
        return Text("Watch the pick: down on beats \(beats)")
    }

    /// The line under "Show me" for notes on the neck.
    static var notesCaption: Text { Text("Watch each note land as it sounds") }

    /// Whether the 3D stage may run now: not with Reduce Motion, in Low Power Mode or on a hot device.
    static func allowed(reduceMotion: Bool) -> Bool {
        !reduceMotion && !StagePower.currentlyReduced
    }

    /// The line under "Show me" handing over to another (the demonstration's to the learner's turn): the old one fades
    /// out first, then the new one in, so the two never sit over each other in the one slot.
    static func captionTransition(reduceMotion: Bool) -> AnyTransition {
        .asymmetric(insertion: .opacity.animation(Motion.fade.delay(reduceMotion ? 0 : 0.16)),
                    removal: .opacity.animation(.easeOut(duration: 0.15)))
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
        for (i, fret) in chord.frets.enumerated() where chord.drawnFingered(i) && i < open.count && i < ranks.count {
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
/// It tells the host once the model is in place and the renderer has drawn it (`onReady`); it shows once the host has
/// given it the card (`revealed`, the same state that takes the host's picture away), so the stage and the picture
/// cross-fade in one move and never sit over each other. `onFailure` hands the card back to its picture.
///
/// Until then it stays behind the picture drawing at a trace rather than not at all. A RealityView at zero opacity
/// may not be drawn, so the model's first frames (where a fresh device builds its shaders, seconds on a cold start)
/// would land on the reveal and hold the card still on its first cross-fade frame. Drawn behind the picture, that cost
/// is paid while it loads.
///
/// For a left-handed player the stage is turned over as the pictures are: the neck mirrored on a left-handed
/// instrument; a strum mirrored (and, held upside down, string 1 on top) so its strokes fall as the player's do. Low
/// Power Mode or a hot device mid-lesson hands the card back to its picture (`onFailure`).
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
    /// The host shows the stage in place of its picture (its own "3D is up" state). Hosts that don't say show it as
    /// soon as it is ready.
    var revealed = true
    let label: Text
    var value: String = ""
    var onReady: () -> Void = {}
    var onFailure: () -> Void = {}
    @State private var box = ShowMeBox()
    @State private var attached = false
    /// The model is on stage, attached and drawn (or the warm-up's patience ran out): the host has been told.
    @State private var ready = false
    /// The overlay redraws every frame only while something moves (the glide, a landing, a string ringing).
    @State private var live = false
    @State private var liveUntil = Date.distantPast
    @CurrentHand private var hand
    @ObservedObject private var power = StagePower.shared
    /// Fret and string numbers grow with Dynamic Type from the 11 pt floor (`DiagramType`).
    @ScaledMetric(relativeTo: .caption2) private var typeScale: CGFloat = 1

    private var controller: ShowMeController { box.controller }

    /// The stage turned over left to right, and top to bottom, for the player's hold: a fretting shot is the
    /// instrument standing up (mirrored on a left-handed one); a strum is seen from the front, so it mirrors for either
    /// left-handed hold and turns over for one held upside down.
    private var flip: (x: Bool, y: Bool) {
        switch shot {
        case .fretting: return (hand.mirrorsUpright, false)
        case .strum: return (hand.hand.nutOnRight, hand.hand.thinnestOnTop)
        }
    }

    /// The stage is on the card: ready, and the host has taken its picture away.
    private var shown: Bool { ready && revealed }

    /// How much of the stage shows behind the picture while it loads: enough for RealityKit to draw it, too little to see.
    private static let trace: Double = 0.02

    var body: some View {
        VStack(spacing: 6) {
            scene
            if case .fretting = shot, let edges, strings >= 2 {
                // Fades in with the model, where the picture's own names stood (the host bottom-aligns both), so the
                // cross-fade never shows two sets of names.
                let lowest = edges.label(strings), first = edges.label(1)
                EdgeNamesRow(leading: flip.x ? first : lowest, trailing: flip.x ? lowest : first)
                    .opacity(shown ? 1 : 0)
                    .animation(Motion.reveal, value: shown)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(label)
        .accessibilityValue(Text(value))
        .accessibilityIdentifier("lesson.showme.stage")
        // Behind the picture VoiceOver reads the picture alone.
        .accessibilityHidden(!shown)
        .accessibilityIgnoresInvertColors()
        .onChange(of: shown, initial: true) { _, now in reveal(now) }
        .onChange(of: power.reduced) { _, reduced in
            // Low Power Mode or a hot device: the card goes back to its picture.
            if reduced { onFailure() }
        }
        #if DEBUG
        // UI tests only: the model's state, the host's, and the demonstration's clock (Root/DemoScenes.swift).
        .overlay {
            ShowMeProbe(modelID: modelID, shown: shown, ready: ready, revealed: revealed, attached: attached, controller: controller,
                        shot: shot, landStart: landStart, landingStep: landingStep, ringing: ringing.count)
        }
        #endif
    }

    private var scene: some View {
        let turn = flip
        return RealityView { content in
            content.camera = .virtual
            if let environment = await ModelCache.shared.environment() { controller.setEnvironment(environment) }
            configure()
            controller.attach(&content)
            attached = true
        } update: { _ in
            configure()
        }
        // One load per model; the model itself comes from the lesson's cache (`ModelCache`). Ready once it is on
        // stage and drawn behind the picture.
        .task(id: modelID) {
            configure()
            await controller.load(modelID, strings: strings, fretless: fretless, accent: accent)
            guard !Task.isCancelled else { return }
            await warmUp()
            guard !Task.isCancelled else { return }
            report()
        }
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
        // Feathered, so the stage melts into the card whatever the renderer clears to; turned over for the player's
        // hold, the marks over it projected to match (`configure`).
        .mask { StageFeather(close: 1) }
        .scaleEffect(x: turn.x ? -1 : 1, y: turn.y ? -1 : 1)
        .overlay { marks }
        // Behind the picture it draws at a trace, never at zero (see the type's note).
        .opacity(shown ? 1 : Self.trace)
        .animation(Motion.reveal, value: shown)
        .allowsHitTesting(shown)
    }

    private func configure() {
        controller.shot = shot
        controller.flipX = flip.x
        controller.flipY = flip.y
        controller.ringing = ringing
        controller.landStart = landStart
        controller.landingStep = landingStep
    }

    /// From the first fingertip's start to the last one's ring fading.
    private var landingLength: Double {
        guard case let .fretting(shape) = shot else { return 0 }
        return Double(max(0, shape.landingCount - 1)) * landingStep + 0.7
    }

    /// Waits, behind the picture, until the scene is attached and the renderer has drawn the model a few times
    /// (`ShowMeController.warm`), so the reveal never waits on the renderer; one that has drawn nothing yet gets
    /// `ShowMe.warmLimit` seconds and is shown anyway.
    private func warmUp() async {
        var waited = 0.0
        while !Task.isCancelled && !controller.failed {
            if attached && controller.loaded {
                if controller.warm || waited >= ShowMe.warmLimit { return }
                waited += 0.05
            }
            try? await Task.sleep(for: .milliseconds(50))
        }
    }

    /// Ready once the model is on stage, the scene attached and the model drawn: the host hears of it and gives the
    /// stage the card (`revealed`).
    private func report() {
        if controller.failed {
            onFailure()
            return
        }
        guard attached, controller.loaded, !ready else { return }
        controller.noteReady()
        ready = true
        onReady()
    }

    /// The host has put the stage on the card (or taken it off): the camera glides in from a wider shot as it appears.
    private func reveal(_ now: Bool) {
        controller.shown = now
        guard now else { return }
        controller.beginGlide()
        keepAlive(for: 1.5)
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
        .opacity(shown ? 1 : 0)
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

    /// The outer strings' names outside them: over the string on top, under the one at the bottom (whichever way the
    /// stage is turned for the player's hold).
    @ViewBuilder private func strumLabels(size: CGSize) -> some View {
        if let edges, let points = controller.strumEdges(in: size) {
            let thickestAbove = points.top.y <= points.bottom.y
            ZStack {
                if let thickest = edges.label(strings) {
                    thickest.font(.system(.caption2, design: .rounded).weight(.semibold)).foregroundStyle(Palette.inkSoft)
                        .fixedSize()
                        .position(x: points.top.x, y: points.top.y + (thickestAbove ? -8 : 8))
                }
                if let thinnest = edges.label(1) {
                    thinnest.font(.system(.caption2, design: .rounded).weight(.semibold)).foregroundStyle(Palette.inkSoft)
                        .fixedSize()
                        .position(x: points.bottom.x, y: points.bottom.y + (thickestAbove ? 8 : -8))
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
    /// The host shows the model in place of its picture (`ShowMeStage.revealed`).
    var revealed = true
    var onReady: () -> Void = {}
    var onFailure: () -> Void = {}
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// The model is in place: until then the picture's own beat row shows, not this one.
    @State private var ready = false

    private var shown: Bool { ready && revealed }

    var body: some View {
        VStack(spacing: 10) {
            // The stage keeps its own visibility (a trace behind the picture while it loads, so it is drawn).
            ShowMeStage(modelID: modelID, strings: strings, shot: .strum(strum), accent: accent, edges: edges, revealed: revealed,
                        label: Text("Strum pattern"), value: String(localized: "Down strokes go from the thickest string to the thinnest, up strokes back."),
                        onReady: { ready = true; onReady() }, onFailure: onFailure)
                .frame(maxHeight: .infinity)
            TimelineView(.animation(paused: reduceMotion || !shown)) { timeline in
                RhythmBar(pattern: strum.pattern, beatsPerBar: strum.beatsPerBar, accent: accent,
                          playhead: reduceMotion ? nil : playhead(at: timeline.date), arrows: arrows)
            }
            .opacity(shown ? 1 : 0)
            .animation(Motion.reveal, value: shown)
            .accessibilityHidden(!shown)
        }
    }

    /// How far through the bar the loop is at `date` (0…1).
    private func playhead(at date: Date) -> Double {
        let bar = Double(max(1, strum.beatsPerBar)) * 60 / max(30, strum.bpm)
        let into = (date.timeIntervalSince(strum.origin) / bar).truncatingRemainder(dividingBy: 1)
        return into < 0 ? into + 1 : into
    }
}

// MARK: - Controls

/// "Show me", the lesson's teacher: plays the picture's demonstration on the instrument in 3D, in place. It is the
/// step's hero control, not a setting: a lit disc carries the 3D glyph (a spinner while the model loads) on a capsule a
/// full touch target tall; once the model is on the card it reads "Again" with a replay glyph and plays it again. Until
/// the learner has watched (`invite`) the disc sends out a ring a few times as the card settles (not under Reduce Motion).
struct ShowMeButton: View {
    var accent: Color = Palette.mint
    var loading = false
    /// The model is on the card: the button plays the demonstration again.
    var showing = false
    /// Calls for a tap: a ring leaves the disc three times, a beat apart.
    var invite = false
    let action: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var ping = 0

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                disc
                ZStack {
                    // Both words hold their room, so the capsule keeps its width as one replaces the other.
                    Text("Show me").opacity(showing ? 0 : 1)
                    Text("Again").opacity(showing ? 1 : 0)
                }
                .font(Typeface.label(.body)).foregroundStyle(Palette.ink).lineLimit(1)
                .animation(Motion.fade, value: showing)
            }
            .padding(.leading, 6)
            .padding(.trailing, 18)
            .frame(minHeight: Metrics.minTarget)
            .background { face }
            .overlay(Capsule().strokeBorder(accent.opacity(0.6), lineWidth: 1.2))
            // Glow means live: it lights while the model is on the card.
            .shadow(color: accent.opacity(showing ? 0.28 : 0), radius: 12, y: 3)
            .contentShape(Capsule())
        }
        .buttonStyle(PressScaleStyle())
        .fixedSize()
        .accessibilityLabel(showing ? Text("Show me again") : Text("Show me"))
        .accessibilityHint(Text("Plays it on a 3D model of the instrument"))
        .accessibilityIdentifier("lesson.showme")
        .task(id: invite && !reduceMotion) { await callOut() }
    }

    /// The accent disc with the glyph, the ring leaving it on each `ping`. The spinner and the glyph are both always
    /// there and cross-fade, so the disc is never empty on the way from loading to playing (a removed spinner vanishes
    /// at once while the glyph is still fading in).
    private var disc: some View {
        ZStack {
            Circle().fill(LinearGradient(colors: [accent.mix(with: .white, by: 0.25), accent], startPoint: .top, endPoint: .bottom))
            ProgressView().controlSize(.small).tint(Palette.onAccent)
                .opacity(loading ? 1 : 0)
            Image(systemName: showing ? "arrow.counterclockwise" : "rotate.3d")
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(Palette.onAccent)
                .contentTransition(.symbolEffect(.replace))
                .opacity(loading ? 0 : 1)
        }
        .animation(Motion.fade, value: loading)
        .frame(width: 32, height: 32)
        .overlay { ShowMePingRing(trigger: ping, color: accent) }
        .accessibilityHidden(true)
    }

    /// The capsule: the accent, brighter at the top, over the card.
    private var face: some View {
        Capsule().fill(LinearGradient(colors: [accent.opacity(0.26), accent.opacity(0.1)], startPoint: .top, endPoint: .bottom))
    }

    /// Three rings from the disc, the first once the card has settled; none once the learner has watched.
    private func callOut() async {
        guard invite, !reduceMotion else { return }
        for _ in 0..<3 {
            try? await Task.sleep(for: .seconds(1.6))
            guard !Task.isCancelled else { return }
            ping += 1
        }
    }
}

/// A ring leaving "Show me"'s disc each time `trigger` changes, growing and fading out; at rest it isn't drawn.
private struct ShowMePingRing: View {
    let trigger: Int
    let color: Color

    private struct Ring {
        var scale: CGFloat = 1
        var opacity: Double = 0
    }

    var body: some View {
        Circle()
            .strokeBorder(color, lineWidth: 2)
            .keyframeAnimator(initialValue: Ring(), trigger: trigger) { ring, value in
                ring.scaleEffect(value.scale).opacity(value.opacity)
            } keyframes: { _ in
                KeyframeTrack(\.scale) {
                    MoveKeyframe(1)
                    CubicKeyframe(1.9, duration: 1.1)
                }
                KeyframeTrack(\.opacity) {
                    MoveKeyframe(0.7)
                    LinearKeyframe(0, duration: 1.1)
                }
            }
            .allowsHitTesting(false)
    }
}

/// The line under "Show me": what to watch (`ShowMe.caption`), an eye beside it, brighter while the demonstration plays
/// on the model. One line, shrinking a little rather than wrapping, so the card never jumps.
struct ShowMeCaption: View {
    let text: Text
    var accent: Color = Palette.mint
    /// The demonstration is playing on the model now.
    var live = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "eye.fill")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(accent)
                .symbolEffect(.pulse, isActive: live && !reduceMotion)
                .accessibilityHidden(true)
            text
                .font(Typeface.label(.footnote))
                .foregroundStyle(live ? Palette.ink : Palette.inkSoft)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(minHeight: 20)
        .animation(Motion.fade, value: live)
        .accessibilityElement(children: .combine)
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
                .font(Typeface.label(.caption))
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
        Text(name).font(Typeface.display(.title)).foregroundStyle(Palette.ink)
            .lineLimit(1)
            .accessibilityHidden(true)
    }
}

// MARK: - Drawing the marks

/// The overlay's drawing, from flat values (`ShowMeMarks`): the player's-view fingertips (`PlayerNeck`'s, in 3D), the
/// capo, the open strings' rings and the muted strings' crosses over the nut, the fret numbers down the bass side and
/// the string numbers past the last fret. Every mark is in the lesson's accent, as on the chart beside it.
enum ShowMeDrawing {
    static func draw(_ context: inout GraphicsContext, _ marks: ShowMeMarks, accent: Color, scale: CGFloat) {
        if let bar = marks.capo { capo(&context, bar) }
        for ring in marks.opens { open(&context, ring, accent: accent) }
        for ring in marks.mutes { mute(&context, ring) }
        for label in marks.frets { fretNumber(&context, label, accent: accent, scale: scale) }
        for label in marks.strings { stringNumber(&context, label, accent: accent, scale: scale) }
        for finger in marks.fingers { press(&context, finger, accent: accent) }
    }

    /// A capo across the strings: a padded bar on its shadow.
    private static func capo(_ context: inout GraphicsContext, _ bar: ShowMeMarks.Bar) {
        var line = Path()
        line.move(to: bar.from)
        line.addLine(to: bar.to)
        context.stroke(line.offsetBy(dx: 1.5, dy: bar.width * 0.4), with: .color(.black.opacity(0.4)),
                       style: StrokeStyle(lineWidth: bar.width, lineCap: .round))
        context.stroke(line, with: .color(NeckFinish.capo), style: StrokeStyle(lineWidth: bar.width, lineCap: .round))
        context.stroke(line.offsetBy(dx: 0, dy: -bar.width * 0.22), with: .color(.white.opacity(0.12)),
                       style: StrokeStyle(lineWidth: max(1, bar.width * 0.2), lineCap: .round))
    }

    /// An open string: a ring in the accent over the nut with a soft glow, brighter while it rings.
    private static func open(_ context: inout GraphicsContext, _ ring: ShowMeMarks.Ring, accent: Color) {
        let r = max(4, ring.radius)
        let alpha = Double(ring.alpha)
        var light = context
        light.blendMode = .plusLighter
        let halo = r * (ring.lit ? 3.4 : 2.6)
        let strength = (ring.lit ? 0.55 : 0.3) * alpha
        context.fill(circle(ring.point, r + 2), with: .color(Palette.stageRaised.opacity(0.85 * alpha)))
        light.fill(circle(ring.point, halo), with: .radialGradient(Gradient(colors: [accent.opacity(strength), accent.opacity(0)]),
                                                                  center: ring.point, startRadius: 0, endRadius: halo))
        let stroke = ring.lit ? accent.mix(with: .white, by: 0.35) : accent
        context.stroke(circle(ring.point, r), with: .color(stroke.opacity(alpha)), lineWidth: 2)
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
        var tone = Palette.inkSoft
        if label.faint { tone = Palette.inkFaint.opacity(0.6) }
        if label.lit { tone = accent }
        let text = Text(verbatim: "\(label.value)").font(DiagramType.font(11, scale: scale)).foregroundStyle(tone)
        context.draw(text, at: label.point)
    }

    /// One fingertip, or a finger laid across several strings: coming down it is bigger and higher, its shadow wide and
    /// soft on the board; pressing, the shadow tightens under it, it squashes a touch and a ring runs out across the
    /// board. A soft pad in the accent, shaded from its top to where it meets the string, with its finger number.
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
        // A soft light around the pad.
        var light = context
        light.blendMode = .plusLighter
        for point in finger.end == nil ? [finger.tip] : [finger.tip, end] {
            let halo = r * 2.2
            light.fill(circle(point, halo), with: .radialGradient(Gradient(colors: [accent.opacity(0.2 * alpha), accent.opacity(0)]),
                                                                  center: point, startRadius: 0, endRadius: halo))
        }
        let pad = padPath(from: finger.tip, to: end, radius: r)
        let bounds = pad.boundingRect
        let face = Gradient(colors: [accent.mix(with: .white, by: 0.14).opacity(alpha), accent.opacity(alpha), accent.mix(with: .black, by: 0.2).opacity(alpha)])
        context.fill(pad, with: .linearGradient(face, startPoint: CGPoint(x: bounds.midX, y: bounds.minY), endPoint: CGPoint(x: bounds.midX, y: bounds.maxY)))
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
