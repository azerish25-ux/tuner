import QuartzCore
import SwiftUI
import TimbreCore

// The Practice hub's tools, alive: each idles in a small working picture of itself. The metronome swings at the player's
// tempo (on the click itself while it runs), the drone ripples with the tanpura's pluck cycle (the drone's own clock
// while it plays), a chord box strums the chord last opened in the Chords tool (a I–V–vi–IV until there is one) in
// this tuning, the Scales tool's box runs up and down note by note, a string rings in its second mode round the
// 12th-fret node, and a voice traces the current exercise.
// Two sizes: a glyph on the phone's tiles (`PlayToolGlyph`) and a preview across the iPad's (`PlayToolPreview`), with
// the line under its name (`PlayToolCaption`). One timeline per glyph or tile, paused off screen, one still frame
// under Reduce Motion.

/// A tool's mark on its tile: its live glyph, or the tool's symbol for anything without one.
struct PlayToolGlyph: View {
    let route: PracticeRoute
    let symbol: String
    @State private var visible = false

    var body: some View {
        Group {
            switch route {
            case .metronome: PendulumGlyph(live: visible)
            case .drone: DroneRippleGlyph(live: visible)
            case .chords: ChordBoxPreview(live: visible, compact: true)
            case .scales: ScaleRunPreview(live: visible, compact: true)
            case .intonation: HarmonicNodePreview(live: visible, compact: true)
            case .voice: VoiceTracePreview(live: visible, compact: true)
            default:
                Image(systemName: symbol).font(.system(size: 18, weight: .medium)).foregroundStyle(Palette.ink)
            }
        }
        .frame(width: 30, height: 30)
        .liveWhileVisible($visible)
        .accessibilityHidden(true)
    }
}

/// A tool's live preview across its iPad tile: the metronome swinging at the last tempo, the drone's dial plucking
/// round its tonic, the chord boxes, the scale's box, the harmonic's node and the voice's trace, drawn at the size
/// the tile gives it.
struct PlayToolPreview: View {
    let route: PracticeRoute
    @State private var visible = false

    var body: some View {
        Group {
            switch route {
            case .metronome: MetronomePreview(live: visible)
            case .drone: DroneDialPreview(live: visible)
            case .chords: ChordBoxPreview(live: visible, compact: false)
            case .scales: ScaleRunPreview(live: visible, compact: false)
            case .intonation: HarmonicNodePreview(live: visible, compact: false)
            case .voice: VoiceTracePreview(live: visible, compact: false)
            default: Color.clear
            }
        }
        .liveWhileVisible($visible)
        .accessibilityHidden(true)
    }

    /// The light behind each tool's preview on its tile, so a grid of six doesn't read as one colour.
    static func tint(_ route: PracticeRoute) -> Color {
        switch route {
        case .drone, .chords: return Palette.orchid
        case .voice: return Palette.sky
        case .intonation: return Palette.violet
        default: return Palette.mint
        }
    }
}

/// Under a tool's name on its iPad tile: what its preview is showing (the tempo, the drone's tonic and voice, the
/// chords, the scale, the voice level).
struct PlayToolCaption: View {
    let route: PracticeRoute
    @EnvironmentObject private var store: AppStore

    var body: some View {
        caption
            .font(.caption)
            .foregroundStyle(Palette.inkSoft)
            .lineLimit(2)
            .minimumScaleFactor(0.85)
            .fixedSize(horizontal: false, vertical: true)
    }

    private var caption: Text {
        switch route {
        case .metronome:
            return Text("\(store.bpm) BPM")
        case .drone:
            let tonic = NoteGlyphs.text(VoiceNoteName.name(store.droneMidi, notation: store.settings.notation), size: 12, weight: .regular)
            let voice = store.droneVoice == .pure ? Text("Pure") : Text("Tanpura")
            return tonic + Text(verbatim: " · ") + voice
        case .voice:
            return Text("Level \(store.voiceLevel)")
        case .chords:
            // The chord last opened in the tool ("C♯m"), or the four the preview strums without one.
            let names = ChordPreviewSet.chords(for: OpenStrings(store).midi, last: store.settings.lastChord).map(\.name)
            return NoteGlyphs.text(names.joined(separator: " · "), size: 12, weight: .regular)
        case .scales:
            let scale = ScalePreviewBox.scale
            let root = Spelling.name(Spelling.scale(root: ScalePreviewBox.root, intervals: scale.intervals).root)
            return NoteGlyphs.text(root + " ", size: 12, weight: .regular) + Text(LocalizedStringKey(scale.name))
        case .intonation:
            return Text("Intonation checks at the 12th fret")
        default:
            return Text(verbatim: "")
        }
    }
}

// MARK: - Metronome

/// A little metronome: its arm swings through the centre on every beat at the saved tempo, with a light at its
/// foot on each tick. While the metronome runs it follows the click as it is heard.
struct PendulumGlyph: View {
    var live = true
    @EnvironmentObject private var store: AppStore
    @EnvironmentObject private var audio: AudioService
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let bpm = Double(min(300, max(30, store.bpm)))
        let running = audio.metronomeRunning
        TimelineView(.animation(minimumInterval: 1.0 / 30, paused: !live || reduceMotion)) { _ in
            let origin = running ? (audio.metronomeOrigin() ?? 0) : 0
            let beats = reduceMotion ? 0.32 : (CACurrentMediaTime() - origin) * bpm / 60
            Canvas { context, size in
                PendulumGlyphArt.draw(&context, size: size, beats: beats, running: running)
            }
        }
    }
}

enum PendulumGlyphArt {
    /// Drawn on a 30 × 30 grid, scaled to fit.
    static func draw(_ context: inout GraphicsContext, size: CGSize, beats: Double, running: Bool) {
        let scale = min(size.width, size.height) / 30
        context.translateBy(x: (size.width - 30 * scale) / 2, y: (size.height - 30 * scale) / 2)
        context.scaleBy(x: scale, y: scale)
        // The case: a tapering body on a base.
        var body = Path()
        body.move(to: CGPoint(x: 12, y: 2.5))
        body.addLine(to: CGPoint(x: 18, y: 2.5))
        body.addLine(to: CGPoint(x: 25, y: 27.5))
        body.addLine(to: CGPoint(x: 5, y: 27.5))
        body.closeSubpath()
        context.fill(body, with: .color(.white.opacity(0.04)))
        context.stroke(body, with: .color(Palette.ink.opacity(0.75)), style: StrokeStyle(lineWidth: 1.4, lineJoin: .round))

        let fraction = beats - floor(beats)
        let flash = max(0, 1 - fraction * 3.5)
        let angle = sin(beats * Double.pi) * 0.42
        let pivot = CGPoint(x: 15, y: 24)
        let tip = CGPoint(x: pivot.x + CGFloat(sin(angle)) * 21, y: pivot.y - CGFloat(cos(angle)) * 21)
        var arm = Path()
        arm.move(to: pivot)
        arm.addLine(to: tip)
        context.stroke(arm, with: .color(Palette.mint), style: StrokeStyle(lineWidth: 1.6, lineCap: .round))
        // The sliding weight on the arm.
        let weight = CGPoint(x: pivot.x + CGFloat(sin(angle)) * 14, y: pivot.y - CGFloat(cos(angle)) * 14)
        context.fill(Path(ellipseIn: CGRect(x: weight.x - 2.4, y: weight.y - 2.4, width: 4.8, height: 4.8)), with: .color(Palette.ink))
        // The tick light at the foot.
        let glow = CGFloat(3 + 4 * flash)
        context.fill(Path(ellipseIn: CGRect(x: pivot.x - glow, y: pivot.y - glow, width: glow * 2, height: glow * 2)),
                     with: .radialGradient(Gradient(colors: [Palette.mint.opacity((running ? 0.75 : 0.5) * flash), .clear]),
                                           center: pivot, startRadius: 0, endRadius: glow))
        context.fill(Path(ellipseIn: CGRect(x: pivot.x - 1.8, y: pivot.y - 1.8, width: 3.6, height: 3.6)),
                     with: .color(Palette.mint.opacity(0.55 + 0.45 * flash)))
    }
}

/// The metronome on its iPad tile: the same swing drawn large and fine, a click of sound leaving its foot on every
/// beat (gold on the first of each bar of four).
struct MetronomePreview: View {
    var live = true
    @EnvironmentObject private var store: AppStore
    @EnvironmentObject private var audio: AudioService
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let bpm = Double(min(300, max(30, store.bpm)))
        let running = audio.metronomeRunning
        TimelineView(.animation(minimumInterval: 1.0 / 30, paused: !live || reduceMotion)) { _ in
            let origin = running ? (audio.metronomeOrigin() ?? 0) : 0
            let beats = reduceMotion ? 0.32 : (CACurrentMediaTime() - origin) * bpm / 60
            Canvas { context, size in
                MetronomePreviewArt.draw(&context, size: size, beats: beats, running: running)
            }
        }
    }
}

enum MetronomePreviewArt {
    static func draw(_ context: inout GraphicsContext, size: CGSize, beats: Double, running: Bool) {
        let h = max(24, min(size.height - 4, size.width * 0.9))
        let cx = size.width / 2
        let baseY = size.height / 2 + h / 2
        let topY = baseY - h
        let halfBase = h * 0.34
        let halfTop = h * 0.1
        let pivot = CGPoint(x: cx, y: baseY - h * 0.17)
        let fraction = beats - floor(beats)
        let flash = max(0, 1 - fraction * 3.5)
        let downbeat = ((Int(floor(beats)) % 4) + 4) % 4 == 0
        let accent = downbeat ? Palette.ink : Palette.mint

        // The click: an arc either side, leaving the foot on the beat.
        let start = halfBase * 0.8
        let reach = max(start + 4, size.width / 2 - 3)
        let radius = start + CGFloat(fraction) * (reach - start)
        let alpha = (1 - fraction) * (running ? 0.75 : 0.5)
        for side in [0.0, Double.pi] {
            var arc = Path()
            arc.addArc(center: pivot, radius: radius, startAngle: .radians(side - 0.42), endAngle: .radians(side + 0.42), clockwise: false)
            context.stroke(arc, with: .color(accent.opacity(alpha)), style: StrokeStyle(lineWidth: 1.6, lineCap: .round))
        }

        // The case and the tempo scale behind the arm.
        var shell = Path()
        shell.move(to: CGPoint(x: cx - halfTop, y: topY))
        shell.addLine(to: CGPoint(x: cx + halfTop, y: topY))
        shell.addLine(to: CGPoint(x: cx + halfBase, y: baseY))
        shell.addLine(to: CGPoint(x: cx - halfBase, y: baseY))
        shell.closeSubpath()
        context.fill(shell, with: .linearGradient(Gradient(colors: [Color.white.opacity(0.07), Color.white.opacity(0.02)]),
                                                  startPoint: CGPoint(x: cx, y: topY), endPoint: CGPoint(x: cx, y: baseY)))
        context.stroke(shell, with: .color(Palette.ink.opacity(0.55)), style: StrokeStyle(lineWidth: 1.3, lineJoin: .round))
        var marks = Path()
        for i in 0..<6 {
            let y = pivot.y - h * 0.22 - CGFloat(i) * h * 0.09
            marks.move(to: CGPoint(x: cx - 3, y: y))
            marks.addLine(to: CGPoint(x: cx + 3, y: y))
        }
        context.stroke(marks, with: .color(.white.opacity(0.14)), lineWidth: 1)

        // The arm and its weight.
        let angle = sin(beats * Double.pi) * 0.42
        let length = h * 0.74
        let tip = CGPoint(x: pivot.x + CGFloat(sin(angle)) * length, y: pivot.y - CGFloat(cos(angle)) * length)
        var arm = Path()
        arm.move(to: pivot)
        arm.addLine(to: tip)
        context.stroke(arm, with: .color(Palette.mint), style: StrokeStyle(lineWidth: 2, lineCap: .round))
        let weight = CGPoint(x: pivot.x + CGFloat(sin(angle)) * length * 0.62, y: pivot.y - CGFloat(cos(angle)) * length * 0.62)
        let w = max(3, h * 0.05)
        context.fill(Path(roundedRect: CGRect(x: weight.x - w, y: weight.y - w * 0.75, width: w * 2, height: w * 1.5), cornerRadius: 1.5),
                     with: .color(Palette.ink))

        // The light at the foot, on every tick.
        let glow = CGFloat(5 + 9 * flash)
        context.fill(BullseyeArt.circle(pivot, glow),
                     with: .radialGradient(Gradient(colors: [accent.opacity((running ? 0.8 : 0.55) * flash), .clear]),
                                           center: pivot, startRadius: 0, endRadius: glow))
        context.fill(BullseyeArt.circle(pivot, 2.6), with: .color(accent.opacity(0.6 + 0.4 * flash)))
    }
}

// MARK: - Drone

/// The drone's ripple: a ring leaves the centre each time a string is plucked, in the tanpura's cycle (on the
/// drone's own plucks while it plays), and the centre glows as they ring.
struct DroneRippleGlyph: View {
    var live = true
    @EnvironmentObject private var audio: AudioService
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let running = audio.droneRunning
        TimelineView(.animation(minimumInterval: 1.0 / 30, paused: !live || reduceMotion)) { _ in
            let now = CACurrentMediaTime()
            let elapsed = reduceMotion ? 3.3 : now - (running ? (audio.droneOrigin() ?? 0) : 0)
            Canvas { context, size in
                DroneRippleArt.draw(&context, size: size, elapsed: elapsed, running: running)
            }
        }
    }
}

enum DroneRippleArt {
    static func draw(_ context: inout GraphicsContext, size: CGSize, elapsed: Double, running: Bool) {
        let c = CGPoint(x: size.width / 2, y: size.height / 2)
        let reach = min(size.width, size.height) / 2 - 1
        var resonance = 0.0
        for string in 0..<DroneCycle.strings {
            guard let age = DroneCycle.age(of: string, elapsed: elapsed) else { continue }
            resonance += DroneCycle.envelope(age: age) * (string == 3 ? 0.4 : 0.3)
            let life = 1.5
            guard age < life else { continue }
            let f = age / life
            let radius = 4 + CGFloat(f) * (reach - 4)
            let alpha = (1 - f) * (running ? 0.85 : 0.6)
            context.stroke(Path(ellipseIn: CGRect(x: c.x - radius, y: c.y - radius, width: radius * 2, height: radius * 2)),
                           with: .color(Palette.mint.opacity(alpha)), lineWidth: string == 3 ? 1.6 : 1.1)
        }
        let core: CGFloat = 4.2
        let glow = core * CGFloat(2 + 1.5 * min(1, resonance))
        context.fill(Path(ellipseIn: CGRect(x: c.x - glow, y: c.y - glow, width: glow * 2, height: glow * 2)),
                     with: .radialGradient(Gradient(colors: [Palette.mint.opacity(0.5 * min(1, resonance + 0.2)), .clear]),
                                           center: c, startRadius: 0, endRadius: glow))
        context.fill(Path(ellipseIn: CGRect(x: c.x - core, y: c.y - core, width: core * 2, height: core * 2)), with: .color(Palette.mint))
    }
}

/// The drone on its iPad tile: the tanpura's gourd as a dial with the tonic inside, its four strings plucked in the
/// tanpura's cycle (on the drone's own clock while it plays), each lighting and shimmering as it sounds, a ripple
/// leaving the gourd with every pluck.
struct DroneDialPreview: View {
    var live = true
    @EnvironmentObject private var store: AppStore
    @EnvironmentObject private var audio: AudioService
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let running = audio.droneRunning
        let pure = store.droneVoice == .pure
        let tonic = VoiceNoteName.pitchClass(store.droneMidi, notation: store.settings.notation)
        TimelineView(.animation(minimumInterval: 1.0 / 30, paused: !live || reduceMotion)) { _ in
            let now = CACurrentMediaTime()
            let elapsed = reduceMotion ? 3.3 : now - (running ? (audio.droneOrigin() ?? now) : 0)
            Canvas { context, size in
                DroneDialArt.draw(&context, size: size, elapsed: elapsed, running: running, pure: pure, tonic: tonic)
            }
        }
    }
}

enum DroneDialArt {
    private static let shimmer: [Double] = [10.5, 12.5, 12.9, 7.5]

    static func draw(_ context: inout GraphicsContext, size: CGSize, elapsed: Double, running: Bool, pure: Bool, tonic: String) {
        let c = CGPoint(x: size.width / 2, y: size.height / 2)
        let r = max(12, min(size.width, size.height) / 2 - 14)
        var moment = TanpuraMoment()
        moment.pure = pure
        moment.elapsed = elapsed
        moment.fade = 1
        for string in 0..<DroneCycle.strings {
            if pure {
                moment.ring[string] = string == 2 ? 0 : 0.55
                moment.age[string] = string == 2 ? nil : elapsed
            } else if let age = DroneCycle.age(of: string, elapsed: elapsed) {
                moment.ring[string] = DroneCycle.envelope(age: age)
                moment.age[string] = age
            }
        }
        let resonance = moment.resonance
        let lift = running ? 1.0 : 0.65

        // The room it fills, and a ripple leaving the gourd with each pluck.
        context.fill(BullseyeArt.circle(c, r * 1.55),
                     with: .radialGradient(Gradient(colors: [Palette.orchid.opacity((0.07 + 0.14 * resonance) * lift), .clear]),
                                           center: c, startRadius: r * 0.5, endRadius: r * 1.55))
        if !pure {
            for string in 0..<DroneCycle.strings {
                guard let age = moment.age[string], age < 1.4 else { continue }
                let f = age / 1.4
                context.stroke(BullseyeArt.circle(c, r + 2 + CGFloat(f) * 12), with: .color(Palette.mint.opacity(0.5 * (1 - f) * lift)),
                               lineWidth: string == 3 ? 1.5 : 1.1)
            }
        }

        // The gourd and its dial: twelve ticks, the tonic's at the bottom.
        let wood = Gradient(colors: [Color(hex: 0x30261C), Color(hex: 0x1A1511), Palette.stageRaised])
        context.fill(BullseyeArt.circle(c, r), with: .radialGradient(wood, center: CGPoint(x: c.x - r * 0.3, y: c.y - r * 0.35),
                                                                         startRadius: 0, endRadius: r * 1.35))
        context.fill(BullseyeArt.circle(c, r), with: .radialGradient(Gradient(colors: [Palette.mint.opacity(0.12 * resonance), .clear]),
                                                                         center: c, startRadius: 0, endRadius: r))
        context.stroke(BullseyeArt.circle(c, r), with: .color(Palette.accentNeutral.opacity(0.32)), lineWidth: 1.2)
        var ticks = Path()
        for i in 0..<12 where i != 6 {
            let a = Double(i) * Double.pi / 6
            ticks.move(to: CGPoint(x: c.x + (r - 5) * CGFloat(sin(a)), y: c.y - (r - 5) * CGFloat(cos(a))))
            ticks.addLine(to: CGPoint(x: c.x + (r - 2) * CGFloat(sin(a)), y: c.y - (r - 2) * CGFloat(cos(a))))
        }
        context.stroke(ticks, with: .color(.white.opacity(0.22)), style: StrokeStyle(lineWidth: 1, lineCap: .round))
        var marker = Path()
        marker.move(to: CGPoint(x: c.x, y: c.y + r - 8))
        marker.addLine(to: CGPoint(x: c.x, y: c.y + r - 1))
        context.stroke(marker, with: .color(Palette.mint), style: StrokeStyle(lineWidth: 2, lineCap: .round))

        // The strings over the gourd's top to its bridge.
        let top = c.y - r * 0.84
        let bridge = c.y - r * 0.16
        let spread = r * 0.14
        for string in 0..<DroneCycle.strings {
            strand(&context, string: string, x: c.x + (CGFloat(string) - 1.5) * spread, top: top, bottom: bridge, r: r, moment: moment)
        }
        let bar = CGRect(x: c.x - spread * 1.5 - 5, y: bridge - 1, width: spread * 3 + 10, height: 4)
        context.fill(Path(roundedRect: bar, cornerRadius: 2), with: .color(Color(hex: 0xE3D8C4).opacity(0.85)))

        // The tonic.
        let points = max(11, r * 0.42)
        let name = NoteGlyphs.text(tonic, size: points * 0.7).font(Typeface.display(points)).foregroundStyle(Palette.ink)
        context.draw(name, at: CGPoint(x: c.x, y: c.y + r * 0.36))
    }

    /// One string: steel (bronze for low Sa), lit mint while it sounds, swinging after its pluck.
    private static func strand(_ context: inout GraphicsContext, string: Int, x: CGFloat, top: CGFloat, bottom: CGFloat, r: CGFloat,
                               moment: TanpuraMoment) {
        let lit = moment.ring[string]
        var amplitude: CGFloat = 0
        var wave = 0.0
        if let age = moment.age[string] {
            let decay = moment.pure ? 0.25 : 0.7 * exp(-age / 0.5) + 0.3 * exp(-age / 3.2)
            amplitude = r * 0.07 * CGFloat(decay)
            wave = cos(2 * Double.pi * shimmer[string] * age + Double(string))
        }
        var path = Path()
        for i in 0...12 {
            let s = Double(i) / 12
            let y = top + (bottom - top) * CGFloat(s)
            let point = CGPoint(x: x + amplitude * CGFloat(sin(Double.pi * s) * wave), y: y)
            if i == 0 { path.move(to: point) } else { path.addLine(to: point) }
        }
        let gauge: CGFloat = string == 3 ? 1.4 : 1
        let base = string == 3 ? Color(hex: 0xD49C5E) : Color(hex: 0xC9CED6)
        context.stroke(path, with: .color(base.opacity(0.5 + 0.4 * lit)), lineWidth: gauge)
        if lit > 0.02 {
            context.stroke(path, with: .color(Palette.mint.opacity(0.8 * lit)), lineWidth: gauge)
        }
    }
}

// MARK: - Chords

/// The chord boxes the Chords preview strums: the chord last opened in the Chords tool (`UserSettings.lastChord`) on
/// its own, or, until there is one (or when this tuning has no shape for it), a I–V–vi–IV in C (C, G, Am, F). Each is
/// the Chords tool's first shape for it in this tuning, named in the player's note names. Worked out once per tuning
/// and chord.
@MainActor
enum ChordPreviewSet {
    private static var cache: [String: [ChordPreviewArt.Chord]] = [:]
    private static let progression: [(root: Int, formula: String)] = [(0, "maj"), (7, "maj"), (9, "min"), (5, "maj")]

    static func chords(for openMidi: [Int], last: UserSettings.ChordChoice? = nil) -> [ChordPreviewArt.Chord] {
        let chosen = last?.resolved
        let chosenKey = chosen.map { "\($0.root):\($0.formula.id)" } ?? "-"
        let key = openMidi.map(String.init).joined(separator: ",") + "|" + Spelling.system + "|" + chosenKey
        if let known = cache[key] { return known }
        var result: [ChordPreviewArt.Chord] = []
        if !openMidi.isEmpty {
            if let chosen, let picked = Self.make(root: chosen.root, formula: chosen.formula, openMidi: openMidi) {
                result = [picked]
            } else {
                for step in progression {
                    if let chord = Self.make(root: step.root, formula: ChordFormula.byId(step.formula), openMidi: openMidi) {
                        result.append(chord)
                    }
                }
            }
        }
        cache[key] = result
        return result
    }

    /// The Chords tool's first shape for the chord in this tuning, named as the tool spells it; nil when it has none.
    private static func make(root: Int, formula: ChordFormula, openMidi: [Int]) -> ChordPreviewArt.Chord? {
        guard let shape = ChordLibrary.voicings(root: root, formula: formula, openMidi: openMidi, limit: 1).first else { return nil }
        let name = Spelling.name(Spelling.chord(root: root, intervals: formula.intervals).root) + formula.suffix
        return ChordPreviewArt.Chord(name: name, frets: shape.frets)
    }
}

/// A chord box strummed: low to high a glint crosses the strings, each lighting and swinging as it is passed, the
/// root's dot in gold; then the next chord of the four (the chord last opened in the tool, strummed again).
struct ChordBoxPreview: View {
    var live = true
    var compact = false
    @EnvironmentObject private var store: AppStore
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let midi = OpenStrings(store).midi
        let chords = ChordPreviewSet.chords(for: midi, last: store.settings.lastChord)
        let strings = max(4, min(8, midi.count))
        TimelineView(.animation(minimumInterval: 1.0 / 30, paused: !live || reduceMotion)) { timeline in
            let t = reduceMotion ? ChordPreviewArt.stillTime : timeline.date.timeIntervalSinceReferenceDate
            Canvas { context, size in
                ChordPreviewArt.draw(&context, size: size, t: t, chords: chords, strings: strings, compact: compact)
            }
        }
    }
}

enum ChordPreviewArt {
    struct Chord: Equatable {
        let name: String
        let frets: [Int?]
        /// The lowest string sounding: the root, on every shape the Chords tool suggests.
        var bass: Int? { frets.firstIndex { $0 != nil } }
    }

    /// Seconds each chord holds.
    static let hold = 2.6
    /// Reduce Motion's frame: the first chord just strummed.
    static let stillTime = 0.95

    static func draw(_ context: inout GraphicsContext, size: CGSize, t: Double, chords: [Chord], strings: Int, compact: Bool) {
        let cycle = max(0, t)
        let turn = floor(cycle / hold)
        let local = cycle - turn * hold
        let chord: Chord? = chords.isEmpty ? nil : chords[Int(turn.truncatingRemainder(dividingBy: Double(chords.count)))]
        let count = max(2, chord?.frets.count ?? strings)
        // Changing chords, the shape fades out and the next fades in; one chord stays put and is strummed again.
        let fade: Double = max(0, min(1, min(local / 0.3, (hold - local) / 0.25)))
        let presence: Double = chords.count == 1 ? 1 : fade

        // The box: room above for the name and the open and muted marks; four frets.
        let nameRoom: CGFloat = compact ? 0 : 22
        let markRoom: CGFloat = compact ? 3 : 11
        let boxH = max(16, size.height - nameRoom - markRoom - 2)
        let fretH = boxH / 4
        let gap = min(fretH * 1.05, (size.width - 8) / CGFloat(count - 1))
        let boxW = gap * CGFloat(count - 1)
        let left = (size.width - boxW) / 2
        let top = nameRoom + markRoom
        let fretted = chord?.frets.compactMap { $0 }.filter { $0 > 0 } ?? []
        let base = (fretted.max() ?? 0) > 4 ? (fretted.min() ?? 1) : 1

        var grid = Path()
        for i in 0...4 {
            let y = top + CGFloat(i) * fretH
            grid.move(to: CGPoint(x: left, y: y))
            grid.addLine(to: CGPoint(x: left + boxW, y: y))
        }
        context.stroke(grid, with: .color(.white.opacity(0.18)), lineWidth: compact ? 0.8 : 1)
        if base == 1 {
            var nut = Path()
            nut.move(to: CGPoint(x: left - 0.5, y: top))
            nut.addLine(to: CGPoint(x: left + boxW + 0.5, y: top))
            context.stroke(nut, with: .color(Palette.ink.opacity(0.8)), style: StrokeStyle(lineWidth: compact ? 2 : 3, lineCap: .round))
        } else if !compact {
            let label = Text(verbatim: "\(base)fr").font(.system(size: 9, weight: .semibold, design: .rounded)).foregroundStyle(Palette.inkFaint)
            context.draw(label, at: CGPoint(x: left - 5, y: top + fretH / 2), anchor: .trailing)
        }

        // The strum: a glint crossing low to high, each string lighting and swinging as it is passed.
        let strumAt = 0.4
        let perString = 0.06
        for s in 0..<count {
            let x = left + CGFloat(s) * gap
            let sounding = chord.map { s < $0.frets.count && $0.frets[s] != nil } ?? false
            let since = local - strumAt - Double(s) * perString
            let lit = sounding && since >= 0 ? exp(-since / 0.8) : 0
            let swing = CGFloat(lit) * (compact ? 0.8 : 2.2) * CGFloat(sin(since * 70))
            var line = Path()
            line.move(to: CGPoint(x: x, y: top))
            line.addQuadCurve(to: CGPoint(x: x, y: top + boxH), control: CGPoint(x: x + swing, y: top + boxH / 2))
            let thin: CGFloat = compact ? 0.7 : 1.0
            let extra: CGFloat = compact ? 0.4 : 0.8
            let gauge = thin + extra * CGFloat(count - 1 - s) / CGFloat(count - 1)
            context.stroke(line, with: .color(Palette.ink.opacity(0.42)), lineWidth: gauge)
            if lit > 0.02 {
                context.stroke(line, with: .color(Palette.mint.opacity(0.85 * lit)), lineWidth: gauge + 0.4)
            }
            if let chord, s < chord.frets.count {
                mark(&context, chord: chord, string: s, x: x, top: top, fretH: fretH, gap: gap, base: base, markRoom: markRoom,
                     presence: presence, lit: lit, compact: compact)
            }
        }
        let sweep = (local - strumAt + 0.08) / (Double(count) * perString + 0.16)
        if !compact && sweep > 0 && sweep < 1 {
            let gx = left - gap * 0.5 + CGFloat(sweep) * (boxW + gap)
            let band = CGRect(x: gx - gap * 0.6, y: top, width: gap * 1.2, height: boxH)
            context.fill(Path(band), with: .linearGradient(Gradient(colors: [.clear, Color.white.opacity(0.16), .clear]),
                                                           startPoint: CGPoint(x: band.minX, y: 0), endPoint: CGPoint(x: band.maxX, y: 0)))
        }
        if !compact, let chord {
            let name = NoteGlyphs.text(chord.name, size: 15).font(Typeface.display(15)).foregroundStyle(Palette.ink.opacity(presence))
            context.draw(name, at: CGPoint(x: size.width / 2, y: nameRoom / 2))
        }
    }

    /// A string's mark: a dot on its fret (the root's gold), a ring over the nut when open, a cross when muted.
    private static func mark(_ context: inout GraphicsContext, chord: Chord, string s: Int, x: CGFloat, top: CGFloat, fretH: CGFloat,
                             gap: CGFloat, base: Int, markRoom: CGFloat, presence: Double, lit: Double, compact: Bool) {
        let isRoot = s == chord.bass
        let tint = isRoot ? Palette.starGold : Palette.mint
        let markY = top - markRoom / 2 - (compact ? 0.5 : 1)
        guard let fret = chord.frets[s] else {
            guard !compact else { return }
            let d: CGFloat = 2.6
            var cross = Path()
            cross.move(to: CGPoint(x: x - d, y: markY - d))
            cross.addLine(to: CGPoint(x: x + d, y: markY + d))
            cross.move(to: CGPoint(x: x + d, y: markY - d))
            cross.addLine(to: CGPoint(x: x - d, y: markY + d))
            context.stroke(cross, with: .color(Palette.inkFaint.opacity(presence)), lineWidth: 1.2)
            return
        }
        if fret == 0 {
            let radius: CGFloat = compact ? 1.1 : 3
            context.stroke(BullseyeArt.circle(CGPoint(x: x, y: markY), radius),
                           with: .color((lit > 0.05 ? tint : Palette.ink.opacity(0.6)).opacity(presence)), lineWidth: compact ? 0.7 : 1.2)
            return
        }
        let row = fret - base
        guard row >= 0, row < 4 else { return }
        let center = CGPoint(x: x, y: top + (CGFloat(row) + 0.5) * fretH)
        let full = max(compact ? 1.7 : 3, min(gap, fretH) * 0.36)
        let radius = full * CGFloat(0.6 + 0.4 * presence)
        if !compact && lit > 0.05 {
            context.fill(BullseyeArt.circle(center, full * 2.6),
                         with: .radialGradient(Gradient(colors: [tint.opacity(0.5 * lit * presence), .clear]),
                                               center: center, startRadius: 0, endRadius: full * 2.6))
        }
        context.fill(BullseyeArt.circle(center, radius), with: .color(tint.opacity(presence)))
    }
}

// MARK: - Scales

/// What the Scales preview runs: the scale the tool opens on (C minor pentatonic), its first position in this tuning;
/// on a tuning without positions, the guitar's first pentatonic box on as many strings.
struct ScalePreviewBox: Equatable {
    let strings: Int
    let low: Int
    let high: Int
    /// The box's notes, lowest first.
    let spots: [NeckSpot]
    let roots: Set<NeckSpot>

    static let root = 0
    static var scale: ScaleFormula { ScaleFormula.all.first { $0.id == "pent_minor" } ?? ScaleFormula.all[0] }

    @MainActor static func make(openMidi: [Int]) -> ScalePreviewBox {
        if let position = ScalePositions.positions(root: root, scale: scale, openMidi: openMidi).first {
            let roots = position.spots.filter { spot in
                spot.string < openMidi.count && ((openMidi[spot.string] + spot.fret) % 12 + 12) % 12 == root
            }
            return ScalePreviewBox(strings: openMidi.count, low: position.frets.lowerBound, high: position.frets.upperBound,
                                   spots: position.spots, roots: Set(roots))
        }
        // The minor pentatonic's first box on six strings (A minor at the 5th fret), its top strings on fewer.
        let pattern = [[0, 3], [0, 2], [0, 2], [0, 2], [0, 3], [0, 3]]
        let rootSpots: Set<[Int]> = [[0, 0], [2, 2], [5, 0]]
        let count = min(6, max(4, openMidi.count))
        var spots: [NeckSpot] = []
        var roots: Set<NeckSpot> = []
        for string in 0..<count {
            let row = string + 6 - count
            for offset in pattern[row] {
                let spot = NeckSpot(string: string, fret: 5 + offset)
                spots.append(spot)
                if rootSpots.contains([row, offset]) { roots.insert(spot) }
            }
        }
        return ScalePreviewBox(strings: count, low: 5, high: 8, spots: spots, roots: roots)
    }
}

/// A scale's box on a short stretch of neck, run up and back down note by note: the note sounding lit, the last few
/// ringed behind it, the roots in gold.
struct ScaleRunPreview: View {
    var live = true
    var compact = false
    @EnvironmentObject private var store: AppStore
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let box = ScalePreviewBox.make(openMidi: OpenStrings(store).midi)
        TimelineView(.animation(minimumInterval: 1.0 / 30, paused: !live || reduceMotion)) { timeline in
            let t = reduceMotion ? ScaleRunArt.stillTime : timeline.date.timeIntervalSinceReferenceDate
            Canvas { context, size in
                ScaleRunArt.draw(&context, size: size, t: t, box: box, compact: compact)
            }
        }
    }
}

enum ScaleRunArt {
    static let step = 0.24
    static let rest = 0.9
    /// Reduce Motion's frame: a few notes into the run.
    static let stillTime = step * 3.4

    static func draw(_ context: inout GraphicsContext, size: CGSize, t: Double, box: ScalePreviewBox, compact: Bool) {
        let rows = max(2, box.strings)
        let first = max(1, box.low)
        let last = max(first + 3, box.high)
        let columns = last - first + 1
        let labelRoom: CGFloat = compact ? 0 : 14
        let slot = (size.height - labelRoom) / CGFloat(rows)
        let colW = min((size.width - (compact ? 2 : 12)) / CGFloat(columns), slot * 1.7)
        let boardW = colW * CGFloat(columns)
        let left = (size.width - boardW) / 2
        func x(_ fret: Int) -> CGFloat { left + (CGFloat(fret - first) + 0.5) * colW }
        // String 1, the thinnest, on top, as the Scales tool draws the neck by default.
        func y(_ string: Int) -> CGFloat { (CGFloat(rows - 1 - string) + 0.5) * slot }

        let board = CGRect(x: left, y: slot * 0.15, width: boardW, height: slot * (CGFloat(rows) - 0.3))
        context.fill(Path(roundedRect: board, cornerRadius: compact ? 2 : 5),
                     with: .linearGradient(Gradient(colors: [Color(hex: 0x30200F), Color(hex: 0x22150C)]),
                                           startPoint: CGPoint(x: 0, y: board.minY), endPoint: CGPoint(x: 0, y: board.maxY)))
        var wires = Path()
        for k in 0...columns {
            let wx = left + CGFloat(k) * colW
            wires.move(to: CGPoint(x: wx, y: board.minY))
            wires.addLine(to: CGPoint(x: wx, y: board.maxY))
        }
        context.stroke(wires, with: .color(Color(hex: 0xC9C2B6).opacity(0.45)), lineWidth: compact ? 0.6 : 1)
        for string in 0..<rows {
            var line = Path()
            line.move(to: CGPoint(x: board.minX, y: y(string)))
            line.addLine(to: CGPoint(x: board.maxX, y: y(string)))
            let thin: CGFloat = compact ? 0.5 : 0.8
            let extra: CGFloat = compact ? 0.5 : 1.2
            let gauge = thin + extra * CGFloat(rows - 1 - string) / CGFloat(rows - 1)
            context.stroke(line, with: .color(Color(hex: 0xD8CFC2).opacity(0.6)), lineWidth: gauge)
        }

        // The run: up the box and back down, then a breath.
        let spots = box.spots
        var sequence = Array(spots.indices)
        if spots.count > 2 { sequence += Array(spots.indices.dropFirst().dropLast().reversed()) }
        let period = Double(sequence.count) * step + rest
        let u = max(0, t).truncatingRemainder(dividingBy: max(0.1, period))
        let position = Int(u / step)
        let current: Int? = position < sequence.count ? sequence[position] : nil
        var trail: [Int: Int] = [:]
        if current != nil {
            for back in 1...3 where position - back >= 0 { trail[sequence[position - back]] = back }
        }

        let radius = max(compact ? 1.5 : 3, min(slot, colW) * 0.34)
        for (index, spot) in spots.enumerated() {
            let center = CGPoint(x: x(spot.fret), y: y(spot.string))
            let tint = box.roots.contains(spot) ? Palette.starGold : Palette.mint
            if index == current {
                if !compact {
                    context.fill(BullseyeArt.circle(center, radius * 3),
                                 with: .radialGradient(Gradient(colors: [tint.opacity(0.55), .clear]), center: center, startRadius: 0, endRadius: radius * 3))
                }
                let lit = BullseyeArt.circle(center, radius + (compact ? 0.8 : 1.5))
                context.fill(lit, with: .color(tint))
                context.stroke(lit, with: .color(Palette.ink), lineWidth: compact ? 0.8 : 1.5)
            } else {
                context.fill(BullseyeArt.circle(center, radius), with: .color(tint.opacity(compact ? 0.85 : 0.72)))
                if let back = trail[index], !compact {
                    context.stroke(BullseyeArt.circle(center, radius + 2.5), with: .color(Palette.ink.opacity(0.5 * (1 - Double(back) / 4))), lineWidth: 1.2)
                }
            }
        }
        if !compact {
            let label = Text(verbatim: "\(first)").font(.system(size: 10, weight: .semibold, design: .rounded)).foregroundStyle(Palette.inkFaint)
            context.draw(label, at: CGPoint(x: x(first), y: size.height - labelRoom / 2))
        }
    }
}

// MARK: - Intonation

/// A string ringing in its second mode, as the intonation check plays it: still at the 12th fret, its node, and
/// swinging either side of it; the node breathing in gold.
struct HarmonicNodePreview: View {
    var live = true
    var compact = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30, paused: !live || reduceMotion)) { timeline in
            let t = reduceMotion ? HarmonicNodeArt.stillTime : timeline.date.timeIntervalSinceReferenceDate
            Canvas { context, size in
                HarmonicNodeArt.draw(&context, size: size, t: t, compact: compact)
            }
        }
    }
}

enum HarmonicNodeArt {
    /// Reduce Motion's frame: the string at the top of its swing.
    static let stillTime = 0.0

    static func draw(_ context: inout GraphicsContext, size: CGSize, t: Double, compact: Bool) {
        let pad: CGFloat = compact ? 1 : 8
        let x0 = pad
        let x1 = size.width - pad
        let length = max(10, x1 - x0)
        let midY = compact ? size.height / 2 : size.height * 0.44
        let amplitude = min(size.height * (compact ? 0.3 : 0.22), length * 0.12)
        func fretX(_ n: Int) -> CGFloat { x0 + length * CGFloat(1 - pow(2, -Double(n) / 12)) }

        if !compact {
            neck(&context, x0: x0, end: fretX(19), midY: midY, amplitude: amplitude, fretX: fretX)
            let saddle = CGRect(x: x1 - 2, y: midY - 6, width: 3, height: 12)
            context.fill(Path(roundedRect: saddle, cornerRadius: 1.5), with: .color(Color(hex: 0xE3D8C4).opacity(0.8)))
        } else {
            var ends = Path()
            ends.move(to: CGPoint(x: x0, y: midY - 4))
            ends.addLine(to: CGPoint(x: x0, y: midY + 4))
            ends.move(to: CGPoint(x: x1, y: midY - 4))
            ends.addLine(to: CGPoint(x: x1, y: midY + 4))
            context.stroke(ends, with: .color(Palette.ink.opacity(0.7)), lineWidth: 1.2)
        }

        // The string's sweep, then the string itself.
        let segments = compact ? 16 : 40
        let swing = CGFloat(cos(2 * Double.pi * 2.4 * t))
        var lens = Path()
        var string = Path()
        for i in 0...segments {
            let s = Double(i) / Double(segments)
            let x = x0 + length * CGFloat(s)
            let shape = CGFloat(sin(2 * Double.pi * s))
            let upper = CGPoint(x: x, y: midY - amplitude * abs(shape))
            let point = CGPoint(x: x, y: midY + amplitude * shape * swing)
            if i == 0 { lens.move(to: upper); string.move(to: point) } else { lens.addLine(to: upper); string.addLine(to: point) }
        }
        for i in (0...segments).reversed() {
            let s = Double(i) / Double(segments)
            lens.addLine(to: CGPoint(x: x0 + length * CGFloat(s), y: midY + amplitude * abs(CGFloat(sin(2 * Double.pi * s)))))
        }
        lens.closeSubpath()
        context.fill(lens, with: .color(Palette.mint.opacity(compact ? 0.18 : 0.12)))
        if !compact {
            context.stroke(string, with: .color(Palette.mint.opacity(0.25)), style: StrokeStyle(lineWidth: 5, lineCap: .round, lineJoin: .round))
        }
        context.stroke(string, with: .color(Palette.mint), style: StrokeStyle(lineWidth: compact ? 1.2 : 1.6, lineCap: .round, lineJoin: .round))

        // The node at the 12th fret.
        let node = CGPoint(x: x0 + length / 2, y: midY)
        let pulse = 0.5 + 0.5 * sin(t * 2 * Double.pi * 0.8)
        let rest: CGFloat = compact ? 3 : 5
        let breathe: CGFloat = compact ? 2 : 5
        let ring = rest + CGFloat(pulse) * breathe
        context.stroke(BullseyeArt.circle(node, ring), with: .color(Palette.accentNeutral.opacity(0.85 - 0.5 * pulse)), lineWidth: compact ? 1 : 1.5)
        context.fill(BullseyeArt.circle(node, compact ? 1.6 : 2.6), with: .color(Palette.accentNeutral))
        guard !compact else { return }
        // A harmonic's diamond over it, the fret's number under it.
        let d: CGFloat = 4
        let tip = CGPoint(x: node.x, y: midY - amplitude - 13)
        var diamond = Path()
        diamond.move(to: CGPoint(x: tip.x, y: tip.y - d))
        diamond.addLine(to: CGPoint(x: tip.x + d, y: tip.y))
        diamond.addLine(to: CGPoint(x: tip.x, y: tip.y + d))
        diamond.addLine(to: CGPoint(x: tip.x - d, y: tip.y))
        diamond.closeSubpath()
        context.fill(diamond, with: .color(Palette.accentNeutral.opacity(0.9)))
        let label = Text(verbatim: "12").font(.system(size: 10, weight: .semibold, design: .rounded)).foregroundStyle(Palette.inkFaint)
        context.draw(label, at: CGPoint(x: node.x, y: midY + amplitude + 14))
    }

    /// The fingerboard under the string to the 19th fret: wires, the nut, the inlays (two at the 12th).
    private static func neck(_ context: inout GraphicsContext, x0: CGFloat, end: CGFloat, midY: CGFloat, amplitude: CGFloat,
                             fretX: (Int) -> CGFloat) {
        let rect = CGRect(x: x0, y: midY - amplitude - 5, width: end - x0, height: (amplitude + 5) * 2)
        context.fill(Path(roundedRect: rect, cornerRadius: 4),
                     with: .linearGradient(Gradient(colors: [Color(hex: 0x30200F).opacity(0.9), Color(hex: 0x22150C).opacity(0.9)]),
                                           startPoint: CGPoint(x: 0, y: rect.minY), endPoint: CGPoint(x: 0, y: rect.maxY)))
        var wires = Path()
        for n in 1...19 {
            let x = fretX(n)
            wires.move(to: CGPoint(x: x, y: rect.minY))
            wires.addLine(to: CGPoint(x: x, y: rect.maxY))
        }
        context.stroke(wires, with: .color(Color(hex: 0xC9C2B6).opacity(0.35)), lineWidth: 0.8)
        for n in [3, 5, 7, 9, 12, 15, 17] {
            let x = (fretX(n - 1) + fretX(n)) / 2
            let ys: [CGFloat] = n == 12 ? [midY - rect.height * 0.3, midY + rect.height * 0.3] : [midY]
            for y in ys { context.fill(BullseyeArt.circle(CGPoint(x: x, y: y), 2), with: .color(.white.opacity(0.12))) }
        }
        var nut = Path()
        nut.move(to: CGPoint(x: x0, y: rect.minY))
        nut.addLine(to: CGPoint(x: x0, y: rect.maxY))
        context.stroke(nut, with: .color(Palette.ink.opacity(0.75)), lineWidth: 3)
    }
}

// MARK: - Voice

/// A voice tracing the current exercise: its notes as bars along a scrolling lane, the sung pitch gliding into each
/// (a little past it, then settling, with a touch of vibrato) and lighting the bar while it is on it.
struct VoiceTracePreview: View {
    var live = true
    var compact = false
    @EnvironmentObject private var store: AppStore
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let notes = VoiceExercise(level: min(8, max(1, store.voiceLevel)), rootMidi: store.voiceRoot).notes
        TimelineView(.animation(minimumInterval: 1.0 / 30, paused: !live || reduceMotion)) { timeline in
            let t = reduceMotion ? VoiceTraceArt.stillTime : timeline.date.timeIntervalSinceReferenceDate
            Canvas { context, size in
                VoiceTraceArt.draw(&context, size: size, t: t, notes: notes, compact: compact)
            }
        }
    }
}

enum VoiceTraceArt {
    /// Seconds each note is sung, and the breath between passes.
    static let slot = 0.85
    static let breath = 0.5
    /// Reduce Motion's frame: settled on a note.
    static let stillTime = 2.15

    /// The sung pitch at `time` (MIDI, fractional) and the note it is aiming for; nil in the breath between passes.
    static func sung(_ time: Double, notes: [Int]) -> (pitch: Double, target: Int)? {
        guard !notes.isEmpty else { return nil }
        let pass = Double(notes.count) * slot + breath
        let u = time - floor(time / pass) * pass
        guard u < Double(notes.count) * slot else { return nil }
        let index = min(notes.count - 1, Int(u / slot))
        let since = u - Double(index) * slot
        let target = notes[index]
        let from = index == 0 ? Double(target) - 1.3 : Double(notes[index - 1])
        let delta = Double(target) - from
        let settle = exp(-since / 0.09)
        let pitch = Double(target) - delta * settle * cos(since * 14) + 0.12 * sin(since * 31) * (1 - settle)
        return (pitch, target)
    }

    static func draw(_ context: inout GraphicsContext, size: CGSize, t: Double, notes: [Int], compact: Bool) {
        guard let low = notes.min(), let high = notes.max() else { return }
        let bottom = Double(low) - 2
        let ceiling = Double(max(high, low + 4)) + 2
        let pad: CGFloat = compact ? 3 : 8
        func y(_ pitch: Double) -> CGFloat {
            size.height - pad - CGFloat((pitch - bottom) / (ceiling - bottom)) * (size.height - pad * 2)
        }
        let window = compact ? 2.2 : 3.4
        let headX = size.width * 0.72
        func x(_ time: Double) -> CGFloat { headX - CGFloat((t - time) / window) * size.width }

        if !compact {
            var lanes = Path()
            var lane = ceil(bottom)
            while lane <= ceiling {
                lanes.move(to: CGPoint(x: 0, y: y(lane)))
                lanes.addLine(to: CGPoint(x: size.width, y: y(lane)))
                lane += 1
            }
            context.stroke(lanes, with: .color(.white.opacity(0.04)), lineWidth: 1)
        }

        // The exercise's notes along the lane, pass after pass; the one being sung brighter.
        let pass = Double(notes.count) * slot + breath
        var index = floor((t - window) / pass)
        let lastPass = floor((t + window) / pass)
        let barH: CGFloat = compact ? 2.5 : 6
        while index <= lastPass {
            for (i, note) in notes.enumerated() {
                let begin = index * pass + Double(i) * slot
                let left = x(begin) + 1
                let right = x(begin + slot) - 1
                guard right > 0, left < size.width else { continue }
                let rect = CGRect(x: left, y: y(Double(note)) - barH / 2, width: max(1, right - left), height: barH)
                let current = t >= begin && t < begin + slot
                context.fill(Path(roundedRect: rect, cornerRadius: barH / 2), with: .color(Palette.sky.opacity(current ? 0.42 : 0.16)))
            }
            index += 1
        }

        // The trace up to now, broken at each breath.
        var trace = Path()
        var drawing = false
        let samples = compact ? 28 : 64
        let span = window * Double(headX / max(1, size.width))
        for k in 0...samples {
            let time = t - span * Double(samples - k) / Double(samples)
            if let sample = sung(time, notes: notes) {
                let point = CGPoint(x: x(time), y: y(sample.pitch))
                if drawing { trace.addLine(to: point) } else { trace.move(to: point); drawing = true }
            } else {
                drawing = false
            }
        }
        if !compact {
            var glow = context
            glow.addFilter(.blur(radius: 3))
            glow.stroke(trace, with: .color(Palette.sky.opacity(0.55)), style: StrokeStyle(lineWidth: 5, lineCap: .round, lineJoin: .round))
        }
        context.stroke(trace, with: .color(Palette.sky), style: StrokeStyle(lineWidth: compact ? 1.4 : 2.2, lineCap: .round, lineJoin: .round))

        // Where the voice is now: mint once it is on the note.
        guard let now = sung(t, notes: notes) else { return }
        let head = CGPoint(x: headX, y: y(now.pitch))
        let tint = abs(now.pitch - Double(now.target)) < 0.3 ? Palette.mint : Palette.sky
        if !compact {
            context.fill(BullseyeArt.circle(head, 12), with: .radialGradient(Gradient(colors: [tint.opacity(0.5), .clear]),
                                                                                center: head, startRadius: 0, endRadius: 12))
        }
        context.fill(BullseyeArt.circle(head, compact ? 2 : 4), with: .color(tint))
    }
}
