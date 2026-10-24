import QuartzCore
import SwiftUI
import TimbreCore

/// The tanpura's pluck pattern exactly as `DroneRenderer` plays it: the first string (Pa, or Ma), Sa, Sa, then
/// low Sa, one every 1.05 s, then a rest of two intervals before the first comes round again (5.25 s a cycle).
/// Strings are numbered in that order. Keep in step with DroneRenderer's `pluckInterval` and envelope.
enum DroneCycle {
    static let strings = 4
    static let interval = 1.05
    static let period = interval * 5

    /// Seconds since `string` was last plucked, `elapsed` seconds after the drone started; nil before its first pluck.
    static func age(of string: Int, elapsed: Double) -> Double? {
        let first = Double(string) * interval
        guard elapsed >= first else { return nil }
        return (elapsed - first).truncatingRemainder(dividingBy: period)
    }

    /// The renderer's own envelope: an 8 ms attack, then a 3.2 s decay.
    static func envelope(age: Double) -> Double { min(1, age / 0.008) * exp(-age / 3.2) }

    /// The drone fades in over 0.4 s.
    static func fadeIn(elapsed: Double) -> Double { min(1, max(0, elapsed / 0.4)) }
}

/// How each string sounds at one moment: how loudly it rings (0…1, the audio's own envelope) and how long ago it
/// was plucked.
struct TanpuraMoment {
    var ring: [Double] = [0, 0, 0, 0]
    var age: [Double?] = [nil, nil, nil, nil]
    /// Seconds since the drone started (the steady shimmer of the pure voice).
    var elapsed = 0.0
    var fade = 0.0
    var pure = false
    var still = false

    /// The gourd's glow: the strings ringing together.
    var resonance: Double { min(1, ring.enumerated().reduce(0.0) { $0 + $1.element * ($1.offset == 3 ? 0.45 : 0.32) }) }
}

/// The drone's hero: a tanpura seen from the front. Four strings, Pa (or Ma), Sa, Sa and low Sa, run down the
/// neck to the bridge on the gourd and are plucked in turn exactly when the drone plucks them (the audio's own
/// clock), each shimmering as it rings and settling as it fades, a ripple leaving the gourd with every pluck.
/// The gourd is a dial of the twelve tonics, turned so the chosen one rests at the bottom, with its name and
/// Sa's frequency inside. Reduce Motion: the strings stay straight and only light as they sound.
struct TanpuraHero: View {
    let tonicPc: Int
    /// The tonic with its octave ("D3"), and the note names the dial is written in.
    let tonicName: String
    let notation: String
    let saHz: Double
    /// Pa (a fifth below Sa) on the first string, else Ma (a fourth).
    let fifth: Bool
    let pure: Bool
    let running: Bool
    /// The drone's clock: when it was first heard, on the CACurrentMediaTime clock (nil until its first buffer
    /// plays). Without one (a preview with no drone behind it) the strings keep their own time.
    let clock: (() -> TimeInterval?)?

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var visible = true
    @State private var localStart = CACurrentMediaTime()
    /// The dial's turn in semitones, counted on rather than wrapped, so a change takes the short way round.
    @State private var turn: Double

    init(tonicPc: Int, tonicName: String, notation: String = "english", saHz: Double, fifth: Bool, pure: Bool, running: Bool, clock: (() -> TimeInterval?)? = nil) {
        self.tonicPc = tonicPc
        self.tonicName = tonicName
        self.notation = notation
        self.saHz = saHz
        self.fifth = fifth
        self.pure = pure
        self.running = running
        self.clock = clock
        _turn = State(initialValue: Double(tonicPc))
    }

    var body: some View {
        GeometryReader { proxy in
            let layout = TanpuraLayout(size: proxy.size)
            ZStack {
                strings(layout)
                dial(layout)
                center(layout)
            }
        }
        .liveWhileVisible($visible)
        .onChange(of: tonicPc) { _, next in
            let shown = ((Int(turn.rounded()) % 12) + 12) % 12
            var delta = next - shown
            if delta > 6 { delta -= 12 } else if delta < -6 { delta += 12 }
            turn += Double(delta)
        }
        .onChange(of: running) { _, now in if now { localStart = CACurrentMediaTime() } }
    }

    private func strings(_ layout: TanpuraLayout) -> some View {
        let still = reduceMotion
        let names = [fifth ? "Pa" : "Ma", "Sa", "Sa", "Sa"]
        return TimelineView(.animation(minimumInterval: still ? 0.1 : nil, paused: !running || !visible)) { _ in
            let moment = self.moment(still: still)
            Canvas { context, _ in
                TanpuraArt.draw(&context, layout: layout, moment: moment, names: names)
            }
        }
    }

    private func moment(still: Bool) -> TanpuraMoment {
        var moment = TanpuraMoment()
        moment.pure = pure
        moment.still = still
        guard running else { return moment }
        let elapsed: Double
        if let clock {
            // Until the drone's first buffer plays, its strings are still at rest.
            elapsed = clock().map { CACurrentMediaTime() - $0 } ?? 0
        } else {
            elapsed = CACurrentMediaTime() - localStart
        }
        moment.elapsed = elapsed
        moment.fade = DroneCycle.fadeIn(elapsed: elapsed)
        for string in 0..<DroneCycle.strings {
            if pure {
                // The pure voice holds Pa (or Ma), Sa and low Sa steadily; the second Sa is silent.
                moment.ring[string] = string == 2 ? 0 : 0.6 * moment.fade
                moment.age[string] = string == 2 ? nil : elapsed
            } else if let age = DroneCycle.age(of: string, elapsed: elapsed) {
                moment.ring[string] = DroneCycle.envelope(age: age) * moment.fade
                moment.age[string] = age
            }
        }
        return moment
    }

    /// The twelve tonics round the gourd, the chosen one at the bottom; the one under the strings stays hidden.
    private func dial(_ layout: TanpuraLayout) -> some View {
        let anchor = UnitPoint(x: layout.center.x / max(1, layout.size.width), y: layout.center.y / max(1, layout.size.height))
        return ZStack {
            ForEach(0..<12, id: \.self) { pc in
                dialLabel(pc)
                    .rotationEffect(.degrees(-turn * 30))
                    .position(layout.dialPoint(pc))
            }
        }
        .frame(width: layout.size.width, height: layout.size.height)
        .rotationEffect(.degrees(turn * 30), anchor: anchor)
        .animation(reduceMotion ? nil : Motion.settle, value: turn)
        .accessibilityHidden(true)
    }

    private func dialLabel(_ pc: Int) -> some View {
        let step = ((pc - tonicPc) % 12 + 12) % 12
        let selected = step == 0
        let firstString = step == (fifth ? 7 : 5)
        let name = VoiceNoteName.pitchClass(pc, notation: notation)
        return Text(verbatim: name)
            .font(selected ? Typeface.label(13, relativeTo: .caption2) : .system(size: 11, weight: .medium))
            .foregroundStyle(selected ? Palette.mint : (firstString ? Palette.inkSoft : Palette.inkFaint))
            .fixedSize()
            .dynamicTypeSize(...DynamicTypeSize.large)
            .opacity(step == 6 ? 0 : 1)
            .animation(Motion.quick, value: step)
    }

    /// The tonic and Sa's frequency inside the gourd, under the bridge.
    private func center(_ layout: TanpuraLayout) -> some View {
        VStack(spacing: 1) {
            Text(verbatim: tonicName).font(Typeface.display(min(46, layout.radius * 0.48)))
                .foregroundStyle(Palette.ink)
                .contentTransition(.numericText())
                .lineLimit(1).minimumScaleFactor(0.6)
            Text(verbatim: String(format: "Sa = %.1f Hz", saHz)).font(Typeface.number(12, relativeTo: .caption))
                .foregroundStyle(Palette.inkSoft)
                .lineLimit(1).minimumScaleFactor(0.7)
        }
        .frame(width: layout.radius * 1.5)
        .dynamicTypeSize(...DynamicTypeSize.xxLarge)
        .position(x: layout.center.x, y: layout.center.y + layout.radius * 0.2)
        .animation(Motion.quick, value: tonicName)
        .accessibilityHidden(true)
    }
}

/// Where everything sits: the gourd low in the frame with room for the dial's labels round it, the neck above,
/// the strings from the nut (under their names) to the bridge, spreading a little toward the bridge.
struct TanpuraLayout {
    let size: CGSize
    let center: CGPoint
    let radius: CGFloat
    let nutY: CGFloat
    let bridgeY: CGFloat
    let spreadNut: CGFloat
    let spreadBridge: CGFloat

    init(size: CGSize) {
        self.size = size
        let r = max(44, min((size.height - 74) / 2, size.width * 0.27, 96))
        radius = r
        center = CGPoint(x: size.width / 2, y: size.height - r - 22)
        nutY = 28
        bridgeY = center.y - r * 0.42
        spreadBridge = r * 0.25
        spreadNut = r * 0.25 * 0.78
    }

    var labelRadius: CGFloat { radius + 16 }

    /// A string's x at height `y`.
    func x(_ string: Int, at y: CGFloat) -> CGFloat {
        let f = max(0, min(1, (y - nutY) / max(1, bridgeY - nutY)))
        return center.x + (CGFloat(string) - 1.5) * (spreadNut + (spreadBridge - spreadNut) * f)
    }

    /// A tonic's place on the dial before it turns: C at the bottom, rising clockwise toward the top. The dial
    /// turns by the chosen tonic so that one comes to rest at the bottom.
    func dialPoint(_ pc: Int) -> CGPoint {
        let angle = (180 - Double(pc) * 30) * Double.pi / 180
        return CGPoint(x: center.x + labelRadius * CGFloat(sin(angle)), y: center.y - labelRadius * CGFloat(cos(angle)))
    }
}

enum TanpuraArt {
    /// Gauge, colour and how fast each string seems to shimmer (Hz on screen).
    private static let gauges: [CGFloat] = [1.3, 1.1, 1.1, 2.1]
    private static let steel = Color(hex: 0xC9CED6)
    private static let bronze = Color(hex: 0xD49C5E)
    private static let shimmer: [Double] = [10.5, 12.5, 12.9, 7.5]
    /// Mandra (lower-octave) strings carry a dot under their names.
    private static let lowOctave = [true, false, false, true]

    static func draw(_ context: inout GraphicsContext, layout: TanpuraLayout, moment: TanpuraMoment, names: [String]) {
        neck(&context, layout: layout)
        gourd(&context, layout: layout, moment: moment)
        bridge(&context, layout: layout)
        var paths: [Path] = []
        var amplitudes: [CGFloat] = []
        for string in 0..<DroneCycle.strings {
            let strength = Self.amplitude(string, moment: moment)
            amplitudes.append(strength)
            paths.append(Self.path(string, layout: layout, moment: moment, amplitude: strength))
        }
        // The blur of motion: the envelope a vibrating string sweeps, faint.
        for string in 0..<DroneCycle.strings where amplitudes[string] > 0.3 {
            context.fill(lens(string, layout: layout, amplitude: amplitudes[string] * 1.15),
                         with: .color(Palette.mint.opacity(0.1 * min(1, moment.ring[string] * 1.4))))
        }
        // One soft glow layer for every sounding string.
        if moment.resonance > 0.02 {
            var glow = context
            glow.addFilter(.blur(radius: 4))
            glow.drawLayer { layer in
                for string in 0..<DroneCycle.strings where moment.ring[string] > 0.02 {
                    layer.stroke(paths[string], with: .color(Palette.mint.opacity(0.6 * moment.ring[string])), lineWidth: gauges[string] + 4)
                }
            }
        }
        for string in 0..<DroneCycle.strings {
            let base = string == 3 ? bronze : steel
            context.stroke(paths[string], with: .color(base.opacity(0.55 + 0.45 * moment.ring[string])),
                           style: StrokeStyle(lineWidth: gauges[string], lineCap: .round, lineJoin: .round))
            if moment.ring[string] > 0.02 {
                context.stroke(paths[string], with: .color(Palette.mint.opacity(0.75 * moment.ring[string])),
                               style: StrokeStyle(lineWidth: gauges[string], lineCap: .round, lineJoin: .round))
            }
            pluckSpark(&context, string, layout: layout, moment: moment)
        }
        beads(&context, layout: layout)
        labels(&context, layout: layout, moment: moment, names: names)
    }

    // MARK: Body

    private static func neck(_ context: inout GraphicsContext, layout: TanpuraLayout) {
        let top = layout.spreadNut * 1.5 + 7
        let low = layout.spreadBridge * 1.5 + 9
        let joinY = layout.center.y - layout.radius * 0.6
        var neck = Path()
        neck.move(to: CGPoint(x: layout.center.x - top, y: 0))
        neck.addLine(to: CGPoint(x: layout.center.x + top, y: 0))
        neck.addLine(to: CGPoint(x: layout.center.x + low, y: joinY))
        neck.addLine(to: CGPoint(x: layout.center.x - low, y: joinY))
        neck.closeSubpath()
        context.fill(neck, with: .linearGradient(Gradient(colors: [Color(hex: 0x0E0C0A), Color(hex: 0x1D1814), Color(hex: 0x0E0C0A)]),
                                                 startPoint: CGPoint(x: layout.center.x - top, y: 0), endPoint: CGPoint(x: layout.center.x + top, y: 0)))
        context.stroke(neck, with: .color(.white.opacity(0.05)), lineWidth: 1)
        // The nut, under the strings' names.
        let nut = CGRect(x: layout.center.x - top + 3, y: layout.nutY - 2, width: (top - 3) * 2, height: 3)
        context.fill(Path(roundedRect: nut, cornerRadius: 1.5), with: .color(Color(hex: 0xE3D8C4).opacity(0.7)))
    }

    private static func gourd(_ context: inout GraphicsContext, layout: TanpuraLayout, moment: TanpuraMoment) {
        let c = layout.center, r = layout.radius
        let resonance = moment.resonance
        // The room it fills: a mint glow that swells as the strings ring.
        let aura = r * (1.45 + 0.1 * CGFloat(resonance))
        context.fill(circle(c, aura), with: .radialGradient(Gradient(colors: [Palette.mint.opacity(0.06 + 0.16 * resonance), .clear]),
                                                            center: c, startRadius: r * 0.6, endRadius: aura))
        // A ripple leaves the gourd with each pluck.
        if !moment.still {
            for string in 0..<DroneCycle.strings {
                guard let age = moment.age[string], !moment.pure, age < 1.3 else { continue }
                let f = age / 1.3
                context.stroke(circle(c, r + 4 + CGFloat(f) * 30), with: .color(Palette.mint.opacity(0.32 * (1 - f) * moment.fade)), lineWidth: 1.5)
            }
        }
        let wood = Gradient(colors: [Color(hex: 0x30261C), Color(hex: 0x1A1511), Palette.stageRaised])
        context.fill(circle(c, r), with: .radialGradient(wood, center: CGPoint(x: c.x - r * 0.3, y: c.y - r * 0.35), startRadius: 0, endRadius: r * 1.35))
        context.fill(circle(c, r), with: .radialGradient(Gradient(colors: [Palette.mint.opacity(0.1 * resonance), .clear]),
                                                         center: c, startRadius: 0, endRadius: r))
        context.stroke(circle(c, r), with: .color(Palette.amber.opacity(0.26)), lineWidth: 1.5)
        context.stroke(circle(c, r * 0.86), with: .color(.white.opacity(0.05)), lineWidth: 1)
        // The inlay: a ring of small dots, filled as one path.
        var inlay = Path()
        for i in 0..<40 {
            let angle = Double(i) / 40 * 2 * Double.pi
            let p = CGPoint(x: c.x + r * 0.93 * CGFloat(cos(angle)), y: c.y + r * 0.93 * CGFloat(sin(angle)))
            inlay.addEllipse(in: CGRect(x: p.x - 0.9, y: p.y - 0.9, width: 1.8, height: 1.8))
        }
        context.fill(inlay, with: .color(Palette.amber.opacity(0.18)))
        // The dial's ticks, the bottom one (the tonic) marked.
        var ticks = Path()
        for i in 0..<12 where i != 6 {
            let angle = Double(i) * Double.pi / 6
            ticks.move(to: CGPoint(x: c.x + (r + 3) * CGFloat(sin(angle)), y: c.y - (r + 3) * CGFloat(cos(angle))))
            ticks.addLine(to: CGPoint(x: c.x + (r + 6) * CGFloat(sin(angle)), y: c.y - (r + 6) * CGFloat(cos(angle))))
        }
        context.stroke(ticks, with: .color(.white.opacity(0.18)), style: StrokeStyle(lineWidth: 1, lineCap: .round))
        var marker = Path()
        marker.move(to: CGPoint(x: c.x, y: c.y + r + 3))
        marker.addLine(to: CGPoint(x: c.x, y: c.y + r + 7))
        context.stroke(marker, with: .color(Palette.mint), style: StrokeStyle(lineWidth: 2, lineCap: .round))
    }

    private static func bridge(_ context: inout GraphicsContext, layout: TanpuraLayout) {
        let width = layout.spreadBridge * 3 + 20
        let rect = CGRect(x: layout.center.x - width / 2, y: layout.bridgeY - 1, width: width, height: 7)
        context.fill(Path(roundedRect: rect.offsetBy(dx: 0, dy: 2.5), cornerRadius: 3), with: .color(.black.opacity(0.4)))
        context.fill(Path(roundedRect: rect, cornerRadius: 3), with: .linearGradient(Gradient(colors: [Color(hex: 0xEFE6D6), Color(hex: 0xB9AB93)]),
                                                                                     startPoint: CGPoint(x: rect.midX, y: rect.minY), endPoint: CGPoint(x: rect.midX, y: rect.maxY)))
    }

    /// The beads (manka) that fine-tune each string, just above the bridge.
    private static func beads(_ context: inout GraphicsContext, layout: TanpuraLayout) {
        let y = layout.bridgeY - min(16, (layout.bridgeY - layout.nutY) * 0.18)
        for string in 0..<DroneCycle.strings {
            let x = layout.x(string, at: y)
            let bead = CGRect(x: x - 2.6, y: y - 3.4, width: 5.2, height: 6.8)
            context.fill(Path(ellipseIn: bead), with: .color(Color(hex: 0xE3D8C4).opacity(0.85)))
        }
    }

    // MARK: Strings

    /// How far a string swings: a strong, quickly settling shimmer after the pluck and a faint one while it rings.
    private static func amplitude(_ string: Int, moment: TanpuraMoment) -> CGFloat {
        guard !moment.still, let age = moment.age[string], moment.ring[string] > 0 else { return 0 }
        let peak: CGFloat = string == 3 ? 5.5 : 4.5
        if moment.pure { return peak * 0.22 * CGFloat(moment.fade) }
        let decay = 0.72 * exp(-age / 0.55) + 0.28 * exp(-age / 3.2)
        return peak * CGFloat(decay * moment.fade)
    }

    /// The string as it is now: its first mode (and a little of its second, the jawari's buzz) between nut and bridge.
    private static func path(_ string: Int, layout: TanpuraLayout, moment: TanpuraMoment, amplitude: CGFloat) -> Path {
        var path = Path()
        let segments = amplitude > 0 ? 24 : 1
        let phaseTime = moment.pure ? moment.elapsed : (moment.age[string] ?? 0)
        let f = shimmer[string]
        let first = cos(2 * Double.pi * f * phaseTime + Double(string))
        let second = sin(2 * Double.pi * f * 2.1 * phaseTime)
        for i in 0...segments {
            let s = Double(i) / Double(segments)
            let y = layout.nutY + (layout.bridgeY - layout.nutY) * CGFloat(s)
            let swing = sin(Double.pi * s) * first + 0.3 * sin(2 * Double.pi * s) * second
            let point = CGPoint(x: layout.x(string, at: y) + amplitude * CGFloat(swing), y: y)
            if i == 0 { path.move(to: point) } else { path.addLine(to: point) }
        }
        return path
    }

    /// The outline a vibrating string sweeps.
    private static func lens(_ string: Int, layout: TanpuraLayout, amplitude: CGFloat) -> Path {
        var path = Path()
        let segments = 16
        for i in 0...segments {
            let s = Double(i) / Double(segments)
            let y = layout.nutY + (layout.bridgeY - layout.nutY) * CGFloat(s)
            let point = CGPoint(x: layout.x(string, at: y) - amplitude * CGFloat(sin(Double.pi * s)), y: y)
            if i == 0 { path.move(to: point) } else { path.addLine(to: point) }
        }
        for i in (0...segments).reversed() {
            let s = Double(i) / Double(segments)
            let y = layout.nutY + (layout.bridgeY - layout.nutY) * CGFloat(s)
            path.addLine(to: CGPoint(x: layout.x(string, at: y) + amplitude * CGFloat(sin(Double.pi * s)), y: y))
        }
        path.closeSubpath()
        return path
    }

    /// A spark where the finger leaves the string, just after the pluck.
    private static func pluckSpark(_ context: inout GraphicsContext, _ string: Int, layout: TanpuraLayout, moment: TanpuraMoment) {
        guard !moment.still, !moment.pure, let age = moment.age[string], age < 0.22 else { return }
        let f = age / 0.22
        let y = layout.nutY + (layout.bridgeY - layout.nutY) * 0.78
        let p = CGPoint(x: layout.x(string, at: y), y: y)
        let radius = 3 + CGFloat(f) * 12
        context.fill(circle(p, radius), with: .radialGradient(Gradient(colors: [Color.white.opacity(0.8 * (1 - f)), Palette.mint.opacity(0.4 * (1 - f)), .clear]),
                                                              center: p, startRadius: 0, endRadius: radius))
    }

    /// Each string's name above the nut, lit while it sounds; a dot under a lower-octave string's name.
    private static func labels(_ context: inout GraphicsContext, layout: TanpuraLayout, moment: TanpuraMoment, names: [String]) {
        let size = max(9, min(11, layout.spreadNut * 0.75))
        for string in 0..<min(names.count, DroneCycle.strings) {
            let x = layout.x(string, at: layout.nutY)
            let lit = min(1, moment.ring[string] * 1.6)
            let color = lit > 0.3 ? Palette.mint : Palette.inkSoft
            let text = Text(verbatim: names[string]).font(.system(size: size, weight: .semibold)).foregroundStyle(color)
            context.draw(text, at: CGPoint(x: x, y: layout.nutY - 15), anchor: .center)
            if lowOctave[string] {
                context.fill(circle(CGPoint(x: x, y: layout.nutY - 6.5), 1.2), with: .color(color.opacity(0.9)))
            }
        }
    }

    private static func circle(_ center: CGPoint, _ radius: CGFloat) -> Path {
        Path(ellipseIn: CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2))
    }
}
