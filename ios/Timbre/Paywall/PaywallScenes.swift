import SwiftUI
import TimbreCore

// MARK: - What the hero shows

/// A tool the paywall was opened from, pictured in the hero in place of the instrument and its runway.
enum PaywallTool: Equatable {
    /// The Tanpura drone, as the Drone screen draws it: four strings (Pa, or Ma without `fifth`, then three Sa)
    /// plucked in turn in the drone's rhythm over the gourd, which names the tonic.
    case drone(tonic: String, fifth: Bool)
    /// Pitch Sniper's scope, as on the Play tab, also the picture of the tuner's ±1¢ precision: the game's rings at
    /// 50, 20 and 5 cents and a pitch homing in on the bullseye.
    case scope
    /// The ear trainer's interval staircase, as on the Play tab: a note climbing the major scale, each interval to
    /// the root named as it lands.
    case staircase
    /// The metronome: a pendulum at the person's tempo, the bar's beats lighting in turn.
    case beat(bpm: Int, beats: Int)
}

/// The paywall's hero: the person's plan (onboarding, and Pro from Settings: their instrument, the sleeve of the first
/// song the plan reaches and the road there), the instrument with its strings running on as a play-along runway
/// (lessons, songs, instruments), or the scene of the tool that opened the paywall.
enum PaywallHero {
    case plan(PaywallPlanScene)
    case runway(PaywallFigure, lanes: Int)
    case tool(PaywallTool)

    /// Below this height the hero steps aside for the Pro pill alone. A tool's scene still reads smaller than the
    /// runway, which needs the instrument, the lanes, the combo and the pill one above another; the plan needs its
    /// picture, its road and the pill.
    var minHeight: CGFloat {
        switch self {
        case .plan: return 140
        case .runway: return 98
        case .tool: return 84
        }
    }

    /// The person's plan, rather than a runway or a tool.
    var isPlan: Bool {
        if case .plan = self { return true }
        return false
    }

    /// Nothing under the close button's corner redraws every frame, so glass there needn't resample each frame: the
    /// plan's picture (its turning record stands clear of the corner). The runway and the tools draw on a Canvas that
    /// spans the width.
    var isStill: Bool { isPlan }
}

/// What the plan's hero shows, all from the person's plan (`PaywallPlan`): their instrument as the app pictures it,
/// the sleeve of the first song the plan reaches (as the Songs shelf draws it), and the road to it.
struct PaywallPlanScene {
    /// A stop on the road: today, the first song, the next unit.
    struct Stop: Identifiable {
        enum Kind { case today, song, unit }
        let id: String
        /// 1 is today.
        let day: Int
        /// The song's or the unit's name; nil for a bare "Today".
        let title: String?
        let kind: Kind
    }

    /// The studio render (standing upright in a square) or the photograph (already leaning); nil without an instrument.
    let instrument: (name: String, render: Bool)?
    let sleeve: CoverArt
    /// The course's colour, for the light behind the picture.
    let accent: Color
    /// In day order, two or three.
    let stops: [Stop]
}

// MARK: - The scenes

/// A tool's scene at one moment, drawn in the hero's Canvas on a floor above the Pro pill. Everything stays inside
/// the middle of the width (48 points clear of each side), so nothing reaches under the close button. With Reduce
/// Motion the hero holds the frame at `still(_:)`: the scene mid-action, with nothing moving.
@MainActor
struct ToolScene {
    let tool: PaywallTool
    /// Seconds since the scene appeared.
    let elapsed: Double
    let calm: Bool
    /// The pill at the bottom centre: the scene stands on the floor above it.
    let pill: CGSize

    /// Reduce Motion's frame: Pa ringing as the first Sa sounds (the strings lit, not swinging), a pitch in the
    /// bullseye with its hold a third full, the note resting on the fifth, a beat just struck.
    static func still(_ tool: PaywallTool) -> Double {
        switch tool {
        case .drone: return 1.05
        case .scope: return 2.34
        case .staircase: return 1.64
        case .beat(let bpm, _): return secondsPerBeat(bpm) * 2 + 0.08
        }
    }

    func draw(_ context: inout GraphicsContext, size: CGSize) {
        context.clip(to: Path(CGRect(origin: .zero, size: size)))
        let floor = max(30, size.height - pill.height - 8)
        switch tool {
        case .drone(let tonic, let fifth): drawTanpura(context, size: size, floor: floor, tonic: tonic, fifth: fifth)
        case .scope: drawScope(context, size: size, floor: floor)
        case .staircase: drawStaircase(context, size: size, floor: floor)
        case .beat(let bpm, let beats): drawBeat(context, size: size, floor: floor, bpm: bpm, beats: beats)
        }
    }
}

// MARK: Shared

extension ToolScene {
    private static func circle(_ center: CGPoint, _ radius: CGFloat) -> Path {
        Path(ellipseIn: CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2))
    }

    /// A soft pool of light.
    private func pool(_ context: GraphicsContext, at center: CGPoint, radius: CGFloat, color: Color, strength: Double) {
        let light = Gradient(colors: [color.opacity(strength), color.opacity(0)])
        context.fill(Self.circle(center, radius), with: .radialGradient(light, center: center, startRadius: 0, endRadius: radius))
    }

    /// Small fixed-size type in the scene (11 points, the type floor): note names, intervals, cents.
    private func caption(_ context: GraphicsContext, _ text: String, at point: CGPoint, color: Color, anchor: UnitPoint = .center) {
        let resolved = context.resolve(Text(verbatim: text).font(.system(size: 11, weight: .semibold, design: .rounded)).foregroundStyle(color))
        context.draw(resolved, at: point, anchor: anchor)
    }
}

// MARK: Tanpura

extension ToolScene {
    /// The Drone screen's pluck pattern, as the drone plays it: Pa, Sa, Sa, then the lower Sa, one every 1.05 s,
    /// then a rest of two before Pa comes round again.
    private static let pluckInterval = 1.05
    private static let pluckCycle = 5.25
    private static let steel = Color(hex: 0xC9CED6)
    private static let bronze = Color(hex: 0xD49C5E)
    private static let ivory = Color(hex: 0xEFE6D6)
    /// How fast each string seems to shimmer, as on the Drone screen (the lower Sa slowest).
    private static let shimmer: [Double] = [10.5, 12.5, 12.9, 7.5]

    /// Seconds since string `index` (0 Pa … 3 the lower Sa) was last plucked; nil before its first pluck.
    private func pluckAge(_ index: Int) -> Double? {
        let since = elapsed - Double(index) * Self.pluckInterval
        guard since >= 0 else { return nil }
        return since.truncatingRemainder(dividingBy: Self.pluckCycle)
    }

    /// How loudly a string rings: the drone's own envelope, a 3.2 s decay.
    private func ring(_ index: Int) -> Double {
        pluckAge(index).map { exp(-$0 / 3.2) } ?? 0
    }

    /// The Drone screen's tanpura, sized for the hero: the neck coming down out of the dark to the gourd, the
    /// strings plucked in turn in the drone's own rhythm, each shimmering in mint as it rings and settling as it
    /// fades, a ripple leaving the gourd with every pluck, the gourd glowing as they ring together. The tonic's
    /// name sits in the gourd, marked at the bottom of its dial.
    private func drawTanpura(_ context: GraphicsContext, size: CGSize, floor: CGFloat, tonic: String, fifth: Bool) {
        let cx = size.width / 2
        let radius = max(16, min(50, floor * 0.29))
        let gourd = CGPoint(x: cx, y: floor - radius - 7)
        let named = floor >= 118
        let nutY: CGFloat = named ? 24 : 5
        let bridgeY = gourd.y - radius * 0.34
        let nutGap = max(4.5, min(9, radius * 0.2))
        let bridgeGap = max(5.5, min(12, radius * 0.26))
        let rings = (0..<4).map { ring($0) }
        let resonance = min(1, rings.enumerated().reduce(0.0) { $0 + $1.element * ($1.offset == 3 ? 0.45 : 0.32) })
        pool(context, at: CGPoint(x: cx, y: gourd.y - floor * 0.25), radius: min(size.width * 0.38, 160), color: Palette.spotlight, strength: 0.12)
        drawNeck(context, cx: cx, nutY: nutY, gourd: gourd, radius: radius, nutGap: nutGap, bridgeGap: bridgeGap)
        drawGourd(context, gourd: gourd, radius: radius, resonance: resonance, tonic: tonic)
        let bridgeWidth = bridgeGap * 3 + 14
        let bridge = CGRect(x: cx - bridgeWidth / 2, y: bridgeY - 1, width: bridgeWidth, height: 5)
        context.fill(Path(roundedRect: bridge.offsetBy(dx: 0, dy: 2), cornerRadius: 2.5), with: .color(Color.black.opacity(0.4)))
        context.fill(Path(roundedRect: bridge, cornerRadius: 2.5),
                     with: .linearGradient(Gradient(colors: [Self.ivory, Color(hex: 0xB9AB93)]), startPoint: CGPoint(x: bridge.midX, y: bridge.minY), endPoint: CGPoint(x: bridge.midX, y: bridge.maxY)))
        for index in 0..<4 {
            let offset = CGFloat(index) - 1.5
            let nut = CGPoint(x: cx + offset * nutGap, y: nutY)
            let foot = CGPoint(x: cx + offset * bridgeGap, y: bridgeY)
            drawString(context, index: index, nut: nut, foot: foot, ring: rings[index])
        }
        if named { drawSargam(context, names: [fifth ? "Pa" : "Ma", "Sa", "Sa", "Sa"], cx: cx, nutY: nutY, nutGap: nutGap, rings: rings) }
    }

    /// The neck in dark wood, fading in from the top edge, and the nut under the strings' names.
    private func drawNeck(_ context: GraphicsContext, cx: CGFloat, nutY: CGFloat, gourd: CGPoint, radius: CGFloat, nutGap: CGFloat, bridgeGap: CGFloat) {
        let upper = nutGap * 1.5 + 7
        let lower = bridgeGap * 1.5 + 9
        let join = gourd.y - radius * 0.6
        var neck = Path()
        neck.move(to: CGPoint(x: cx - upper, y: 0))
        neck.addLine(to: CGPoint(x: cx + upper, y: 0))
        neck.addLine(to: CGPoint(x: cx + lower, y: join))
        neck.addLine(to: CGPoint(x: cx - lower, y: join))
        neck.closeSubpath()
        // Out of the dark at the top edge.
        var wood = context
        let solid = min(0.95, max(12, nutY + 4) / max(1, join))
        let reveal = Gradient(stops: [Gradient.Stop(color: .clear, location: 0), Gradient.Stop(color: .black, location: solid)])
        wood.clipToLayer { mask in
            mask.fill(Path(CGRect(x: cx - upper - 2, y: 0, width: upper * 2 + 4, height: join + 2)),
                      with: .linearGradient(reveal, startPoint: .zero, endPoint: CGPoint(x: 0, y: join)))
        }
        let across = Gradient(colors: [Color(hex: 0x0E0C0A), Color(hex: 0x1D1814), Color(hex: 0x0E0C0A)])
        wood.fill(neck, with: .linearGradient(across, startPoint: CGPoint(x: cx - upper, y: 0), endPoint: CGPoint(x: cx + upper, y: 0)))
        wood.stroke(neck, with: .color(Color.white.opacity(0.05)), lineWidth: 1)
        guard nutY > 8 else { return }
        let nut = CGRect(x: cx - upper + 3, y: nutY - 2, width: (upper - 3) * 2, height: 3)
        context.fill(Path(roundedRect: nut, cornerRadius: 1.5), with: .color(Color(hex: 0xE3D8C4).opacity(0.7)))
    }

    /// The gourd: a mint aura swelling as the strings ring, a ripple off it with each pluck, dark wood with an
    /// amber rim and a ring of inlay, the dial's ticks round it with the tonic marked at the bottom, and the
    /// tonic's name under the bridge when there is room.
    private func drawGourd(_ context: GraphicsContext, gourd: CGPoint, radius: CGFloat, resonance: Double, tonic: String) {
        let aura = radius * (1.5 + 0.12 * CGFloat(resonance))
        context.fill(Self.circle(gourd, aura), with: .radialGradient(Gradient(colors: [Palette.mint.opacity(0.07 + 0.18 * resonance), Palette.mint.opacity(0)]),
                                                                    center: gourd, startRadius: radius * 0.6, endRadius: aura))
        if !calm {
            for index in 0..<4 {
                guard let age = pluckAge(index), age < 1.3 else { continue }
                let f = age / 1.3
                context.stroke(Self.circle(gourd, radius + 4 + CGFloat(f) * 30), with: .color(Palette.mint.opacity(0.34 * (1 - f))), lineWidth: 1.5)
            }
        }
        let wood = Gradient(colors: [Color(hex: 0x30261C), Color(hex: 0x1A1511), Palette.stageRaised])
        let light = CGPoint(x: gourd.x - radius * 0.3, y: gourd.y - radius * 0.35)
        context.fill(Self.circle(gourd, radius), with: .radialGradient(wood, center: light, startRadius: 0, endRadius: radius * 1.35))
        context.fill(Self.circle(gourd, radius), with: .radialGradient(Gradient(colors: [Palette.mint.opacity(0.12 * resonance), Palette.mint.opacity(0)]),
                                                                      center: gourd, startRadius: 0, endRadius: radius))
        context.stroke(Self.circle(gourd, radius), with: .color(Palette.amber.opacity(0.28)), lineWidth: 1.5)
        var inlay = Path()
        for dot in 0..<32 {
            let angle = Double(dot) / 32 * 2 * Double.pi
            let point = CGPoint(x: gourd.x + radius * 0.9 * CGFloat(cos(angle)), y: gourd.y + radius * 0.9 * CGFloat(sin(angle)))
            inlay.addEllipse(in: CGRect(x: point.x - 0.8, y: point.y - 0.8, width: 1.6, height: 1.6))
        }
        context.fill(inlay, with: .color(Palette.amber.opacity(0.2)))
        var ticks = Path()
        for tick in 0..<12 where tick != 6 {
            let angle = Double(tick) * Double.pi / 6
            let along = CGPoint(x: CGFloat(sin(angle)), y: -CGFloat(cos(angle)))
            ticks.move(to: CGPoint(x: gourd.x + (radius + 3) * along.x, y: gourd.y + (radius + 3) * along.y))
            ticks.addLine(to: CGPoint(x: gourd.x + (radius + 6) * along.x, y: gourd.y + (radius + 6) * along.y))
        }
        context.stroke(ticks, with: .color(Color.white.opacity(0.18)), style: StrokeStyle(lineWidth: 1, lineCap: .round))
        var marker = Path()
        marker.move(to: CGPoint(x: gourd.x, y: gourd.y + radius + 3))
        marker.addLine(to: CGPoint(x: gourd.x, y: gourd.y + radius + 7))
        context.stroke(marker, with: .color(Palette.mint), style: StrokeStyle(lineWidth: 2, lineCap: .round))
        guard radius >= 26 else { return }
        let name = context.resolve(Text(verbatim: tonic).font(.custom("Sora-SemiBold", fixedSize: max(13, radius * 0.42))).foregroundStyle(Palette.ink))
        context.draw(name, at: CGPoint(x: gourd.x, y: gourd.y + radius * 0.3), anchor: .center)
    }

    /// A string from the nut to the bridge: steel, the lower Sa bronze. Plucked, it shimmers (its first mode and a
    /// touch of its second, the jawari's buzz), sweeping a faint lens and glowing mint while it rings.
    private func drawString(_ context: GraphicsContext, index: Int, nut: CGPoint, foot: CGPoint, ring: Double) {
        let age = pluckAge(index) ?? 0
        let heavy = index == 3
        let peak: CGFloat = heavy ? 4.5 : 3.6
        let decay = 0.72 * exp(-age / 0.55) + 0.28 * exp(-age / 3.2)
        let swing = calm || ring == 0 ? 0 : peak * CGFloat(decay)
        let first = cos(2 * Double.pi * Self.shimmer[index] * age + Double(index))
        let second = sin(2 * Double.pi * Self.shimmer[index] * 2.1 * age)
        let segments = swing > 0 ? 20 : 1
        func point(_ s: Double, _ shift: Double) -> CGPoint {
            let u = CGFloat(s)
            return CGPoint(x: nut.x + (foot.x - nut.x) * u + swing * CGFloat(shift), y: nut.y + (foot.y - nut.y) * u)
        }
        if swing > 0.3 {
            var lens = Path()
            lens.move(to: nut)
            for step in 1...20 { lens.addLine(to: point(Double(step) / 20, -sin(Double.pi * Double(step) / 20) * 1.15)) }
            for step in stride(from: 19, through: 0, by: -1) { lens.addLine(to: point(Double(step) / 20, sin(Double.pi * Double(step) / 20) * 1.15)) }
            lens.closeSubpath()
            context.fill(lens, with: .color(Palette.mint.opacity(0.1 * min(1, ring * 1.4))))
        }
        var string = Path()
        string.move(to: nut)
        for step in 1...segments {
            let s = Double(step) / Double(segments)
            string.addLine(to: point(s, sin(Double.pi * s) * first + 0.3 * sin(2 * Double.pi * s) * second))
        }
        let gauge: CGFloat = heavy ? 1.9 : 1.15
        if ring > 0.02 {
            var glow = context
            glow.addFilter(.blur(radius: 3))
            glow.stroke(string, with: .color(Palette.mint.opacity(0.6 * ring)), lineWidth: gauge + 3.5)
        }
        let base = heavy ? Self.bronze : Self.steel
        context.stroke(string, with: .color(base.opacity(0.55 + 0.45 * ring)), style: StrokeStyle(lineWidth: gauge, lineCap: .round, lineJoin: .round))
        if ring > 0.02 {
            context.stroke(string, with: .color(Palette.mint.opacity(0.75 * ring)), style: StrokeStyle(lineWidth: gauge, lineCap: .round, lineJoin: .round))
        }
        // A spark where the finger leaves the string, just after the pluck.
        if !calm, ring > 0, age < 0.22 {
            let f = age / 0.22
            let spark = point(0.78, 0)
            let reach = 3 + CGFloat(f) * 10
            let flash = Gradient(colors: [Color.white.opacity(0.8 * (1 - f)), Palette.mint.opacity(0.4 * (1 - f)), Color.clear])
            context.fill(Self.circle(spark, reach), with: .radialGradient(flash, center: spark, startRadius: 0, endRadius: reach))
        }
    }

    /// Pa (or Ma), Sa, Sa, Sa over the nut, left to right as the tanpura is played, each lit mint while it sounds;
    /// a dot under the first and the last marks the lower octave, as sargam writes it.
    private func drawSargam(_ context: GraphicsContext, names: [String], cx: CGFloat, nutY: CGFloat, nutGap: CGFloat, rings: [Double]) {
        let spacing = max(17, nutGap)
        for (index, name) in names.enumerated() {
            let x = cx + (CGFloat(index) - 1.5) * spacing
            let lit = rings[index] > 0.45
            let color = lit ? Palette.mint : Palette.inkSoft
            caption(context, name, at: CGPoint(x: x, y: nutY - 15), color: color)
            if index == 0 || index == 3 {
                context.fill(Self.circle(CGPoint(x: x, y: nutY - 6), 1.2), with: .color(color.opacity(0.8)))
            }
        }
    }
}

// MARK: Scope

extension ToolScene {
    /// One shot: in from the edge, held in the bullseye, scored. Each comes in from a new side.
    private static let scopeRound = 3.6
    /// The game's own rings, as shares of the scope: 50, 20 and 5 cents out from the bullseye.
    private static let scopeRings: [(cents: Double, share: CGFloat)] = [(50, 1), (20, 0.71), (5, 0.4)]

    /// How far from the centre a pitch `cents` off sits, as a share of the scope, between the game's rings.
    private static func scopeDistance(_ cents: Double) -> CGFloat {
        let off = min(50, abs(cents))
        if off <= 5 { return CGFloat(off / 5) * 0.4 }
        if off <= 20 { return 0.4 + CGFloat((off - 5) / 15) * 0.31 }
        return 0.71 + CGFloat((off - 20) / 30) * 0.29
    }

    /// Pitch Sniper's scope, as on the Play tab: a dark lens with the game's cents rings and crosshairs, a radar
    /// sweep going round, and a pitch homing in shot after shot, its cents beside it.
    private func drawScope(_ context: GraphicsContext, size: CGSize, floor: CGFloat) {
        let radius = max(22, min(floor / 2 - 7, size.width / 2 - 56, 100))
        let center = CGPoint(x: size.width / 2, y: floor - radius - 7)
        pool(context, at: center, radius: radius * 1.5, color: Palette.mint, strength: 0.13)
        drawReticle(context, center: center, radius: radius)
        let sweep = calm ? -0.9 : elapsed * 1.7
        drawSweep(context, center: center, radius: radius, angle: sweep)
        drawTarget(context, center: center, radius: radius, sweep: sweep)
    }

    private func drawReticle(_ context: GraphicsContext, center: CGPoint, radius: CGFloat) {
        context.fill(Self.circle(center, radius), with: .color(Color.black.opacity(0.3)))
        let tints = [Color.white.opacity(0.11), Color.white.opacity(0.09), Palette.amber.opacity(0.45)]
        for (ring, tint) in zip(Self.scopeRings, tints) {
            context.stroke(Self.circle(center, radius * ring.share), with: .color(tint), lineWidth: 1)
        }
        var hairs = Path()
        for (dx, dy) in [(CGFloat(0), CGFloat(-1)), (0, 1), (-1, 0), (1, 0)] {
            hairs.move(to: CGPoint(x: center.x + dx * radius * 1.06, y: center.y + dy * radius * 1.06))
            hairs.addLine(to: CGPoint(x: center.x + dx * radius * 0.8, y: center.y + dy * radius * 0.8))
        }
        context.stroke(hairs, with: .color(Color.white.opacity(0.2)), lineWidth: 1)
        guard radius >= 80 else { return }
        // Each ring's cents, just inside it on the lower right, once the scope is large enough to keep them apart.
        for ring in Self.scopeRings {
            let r = radius * ring.share
            caption(context, "\(Int(ring.cents))¢", at: CGPoint(x: center.x + r * 0.7, y: center.y + r * 0.7), color: Palette.inkFaint, anchor: .bottomTrailing)
        }
    }

    /// The radar sweep: a wedge fading behind its leading edge.
    private func drawSweep(_ context: GraphicsContext, center: CGPoint, radius: CGFloat, angle: Double) {
        let pieces = 12, span = 0.95
        for piece in 0..<pieces {
            let from = angle - span * Double(piece + 1) / Double(pieces)
            let to = angle - span * Double(piece) / Double(pieces)
            var wedge = Path()
            wedge.move(to: center)
            wedge.addArc(center: center, radius: radius, startAngle: .radians(from), endAngle: .radians(to), clockwise: false)
            wedge.closeSubpath()
            context.fill(wedge, with: .color(Palette.mint.opacity(0.15 * (1 - Double(piece) / Double(pieces)))))
        }
        let end = CGPoint(x: center.x + CGFloat(cos(angle)) * radius, y: center.y + CGFloat(sin(angle)) * radius)
        var edge = Path()
        edge.move(to: center)
        edge.addLine(to: end)
        context.stroke(edge, with: .linearGradient(Gradient(colors: [Palette.mint.opacity(0), Palette.mint.opacity(0.75)]), startPoint: center, endPoint: end), lineWidth: 1.5)
    }

    /// One shot: a pitch spirals in from out of tune (amber, its cents beside it, a blip as the sweep passes),
    /// turns mint inside 5 cents, holds while the ring round the bullseye fills, and scores with a burst.
    private func drawTarget(_ context: GraphicsContext, center: CGPoint, radius: CGFloat, sweep: Double) {
        let round = Self.scopeRound
        let index = (elapsed / round).rounded(.down)
        let p = (elapsed - index * round) / round
        let start = index.truncatingRemainder(dividingBy: 97) * 2.399963
        let approach = 0.55, holdEnd = 0.82
        var cents = 0.4
        var hold = 0.0
        var angle = start + 1.1
        var alpha = 1.0
        var flash = 0.0
        if p < approach {
            let f = p / approach
            cents = 0.6 + 47 * pow(1 - f, 3)
            angle = start + 1.1 * f + 0.25 * sin(f * 7)
            alpha = min(1, f * 6)
        } else if p < holdEnd {
            cents = 0.6 + (calm ? 0 : 0.4 * sin(elapsed * 9))
            hold = (p - approach) / (holdEnd - approach)
            angle = start + 1.1 + (calm ? 0 : elapsed * 2)
        } else {
            let f = (p - holdEnd) / (1 - holdEnd)
            flash = 1 - f
            alpha = max(0, 1 - f * 2.5)
        }
        let bull = max(5, radius * 0.15)
        context.fill(Self.circle(center, bull), with: .color(Palette.mint.opacity(0.16 + 0.25 * hold + 0.4 * flash)))
        context.stroke(Self.circle(center, bull), with: .color(Palette.mint), lineWidth: 1.5)
        if hold > 0 {
            var arc = Path()
            arc.addArc(center: center, radius: bull + 6, startAngle: .degrees(-90), endAngle: .degrees(-90 + 360 * hold), clockwise: false)
            context.stroke(arc, with: .color(Palette.mint), style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
        }
        if flash > 0 { drawBullseye(context, center: center, bull: bull, radius: radius, fade: flash) }
        guard alpha > 0 else { return }
        let distance = radius * Self.scopeDistance(cents)
        let dot = CGPoint(x: center.x + CGFloat(cos(angle)) * distance, y: center.y + CGFloat(sin(angle)) * distance)
        let inside = cents <= 5
        let tint = inside ? Palette.mint : Palette.amber
        let gap = abs((sweep - angle).remainder(dividingBy: 2 * Double.pi))
        let blip = distance > radius * 0.08 ? max(0, 1 - gap / 0.7) : 0
        let halo = max(10, radius * 0.17) * CGFloat(1 + 0.45 * blip)
        pool(context, at: dot, radius: halo, color: tint, strength: (0.55 + 0.3 * blip) * alpha)
        context.fill(Self.circle(dot, max(4, radius * 0.06)), with: .color(tint.opacity(alpha)))
        guard radius >= 44, p < approach, alpha > 0.5 else { return }
        // Flat sits left of the centre, sharp right, as in the game.
        let value = Int(cents.rounded())
        let label = value == 0 ? "0¢" : (cos(angle) < 0 ? "−\(value)¢" : "+\(value)¢")
        caption(context, label, at: CGPoint(x: dot.x + 9, y: dot.y - 7), color: tint, anchor: .bottomLeading)
    }

    /// The score: a ring and six sparks off the bullseye.
    private func drawBullseye(_ context: GraphicsContext, center: CGPoint, bull: CGFloat, radius: CGFloat, fade: Double) {
        let ring = bull + CGFloat(1 - fade) * radius * 0.7
        context.stroke(Self.circle(center, ring), with: .color(Palette.mint.opacity(0.8 * fade)), lineWidth: 2)
        guard !calm else { return }
        let spark = Palette.mint.mix(with: .white, by: 0.4).opacity(fade)
        for index in 0..<6 {
            let angle = Double(index) * Double.pi / 3 + 0.3
            let inner = ring + 2, outer = ring + 4 + CGFloat(fade) * 5
            let along = CGPoint(x: CGFloat(cos(angle)), y: CGFloat(sin(angle)))
            var path = Path()
            path.move(to: CGPoint(x: center.x + inner * along.x, y: center.y + inner * along.y))
            path.addLine(to: CGPoint(x: center.x + outer * along.x, y: center.y + outer * along.y))
            context.stroke(path, with: .color(spark), style: StrokeStyle(lineWidth: 1.4, lineCap: .round))
        }
    }
}

// MARK: Staircase

extension ToolScene {
    /// The major scale from the root, as on the Play tab's ear trainer: unison, major second … octave.
    private static let scale = [0, 2, 4, 5, 7, 9, 11, 12]
    private static let stairHop = 0.42
    private static let stairRest = 1.2
    private static var stairClimb: Double { Double(scale.count - 1) * stairHop }
    private static var stairCycle: Double { stairClimb + stairRest }

    /// When the note lands on step `index` within the climb (the first step is where it starts).
    private static func landing(_ index: Int) -> Double {
        index == 0 ? 0 : (Double(index - 1) + 0.7) * stairHop
    }

    /// The ear trainer's interval staircase, as on the Play tab: the major scale as steps from the root (half steps
    /// rise half as far), a note hopping up it, each step lighting as it lands, its interval to the root drawn as
    /// an arc and named over the note; it rests on the octave, fades, and climbs again.
    private func drawStaircase(_ context: GraphicsContext, size: CGSize, floor: CGFloat) {
        let count = Self.scale.count
        let width = min(size.width - 96, 320)
        let left = (size.width - width) / 2
        let tread = width / CGFloat(count)
        let ball = max(4.5, min(7, tread * 0.17))
        let named = floor >= 80
        let rise = max(16, floor - (named ? 34 : 14) - ball * 2 - 8)
        let local = calm ? elapsed : elapsed.truncatingRemainder(dividingBy: Self.stairCycle)
        let resting = Self.stairClimb + Self.stairRest * 0.7
        let fade = calm || local <= resting ? 1 : max(0, 1 - (local - resting) / (Self.stairRest * 0.3))
        let tops = (0..<count).map { floor - 8 - CGFloat(Self.scale[$0]) / 12 * rise }
        let centers = (0..<count).map { left + tread * (CGFloat($0) + 0.5) }
        pool(context, at: CGPoint(x: size.width / 2, y: floor * 0.6), radius: min(size.width * 0.4, 170), color: Palette.amber, strength: 0.12)
        for index in 0..<count {
            let since = local - Self.landing(index)
            let lit = since >= 0 ? max(0.22, exp(-since / 0.55)) * fade : 0
            let rect = CGRect(x: centers[index] - tread / 2 + 1.5, y: tops[index], width: tread - 3, height: max(4, floor - tops[index]))
            drawStep(context, rect: rect, lit: lit)
        }
        var ground = Path()
        ground.move(to: CGPoint(x: left, y: floor))
        ground.addLine(to: CGPoint(x: left + width, y: floor))
        context.stroke(ground, with: .color(Color.white.opacity(0.07)), lineWidth: 1)
        // The note: hopping step to step, or resting on the octave before it starts again.
        var current = count - 1
        var note = CGPoint(x: centers[current], y: tops[current] - ball - 1)
        if local < Self.stairClimb {
            let from = min(count - 2, Int(local / Self.stairHop))
            let air = min(1, (local - Double(from) * Self.stairHop) / Self.stairHop / 0.7)
            let eased = air * air * (3 - 2 * air)
            let a = CGPoint(x: centers[from], y: tops[from] - ball - 1)
            let b = CGPoint(x: centers[from + 1], y: tops[from + 1] - ball - 1)
            note = CGPoint(x: a.x + (b.x - a.x) * CGFloat(eased), y: a.y + (b.y - a.y) * CGFloat(air) - 16 * CGFloat(sin(Double.pi * air)))
            current = air >= 1 ? from + 1 : from
        }
        drawInterval(context, root: CGPoint(x: centers[0], y: tops[0] - ball - 1), note: note, fade: fade)
        drawNote(context, at: note, ball: ball, since: local - Self.landing(current), fade: fade)
        guard named else { return }
        let name = context.resolve(Text(verbatim: Intervals.short[Self.scale[current]])
            .font(.custom("Sora-SemiBold", fixedSize: 13)).foregroundStyle(Palette.amber.opacity(fade)))
        context.draw(name, at: CGPoint(x: note.x, y: max(9, note.y - ball - 13)), anchor: .center)
    }

    /// A step in amber glass, its top edge brighter once the note has reached it and flashing as it lands.
    private func drawStep(_ context: GraphicsContext, rect: CGRect, lit: Double) {
        let glass = Gradient(colors: [Palette.amber.opacity(0.1 + 0.32 * lit), Palette.amber.opacity(0.02)])
        context.fill(Path(roundedRect: rect, cornerRadius: 4),
                     with: .linearGradient(glass, startPoint: CGPoint(x: rect.midX, y: rect.minY), endPoint: CGPoint(x: rect.midX, y: rect.maxY)))
        var edge = Path()
        edge.move(to: CGPoint(x: rect.minX + 2, y: rect.minY))
        edge.addLine(to: CGPoint(x: rect.maxX - 2, y: rect.minY))
        context.stroke(edge, with: .color(Palette.amber.opacity(0.3 + 0.6 * lit)), style: StrokeStyle(lineWidth: 2, lineCap: .round))
    }

    /// The interval to the root: a dashed arc from the first step to the note, the root marked.
    private func drawInterval(_ context: GraphicsContext, root: CGPoint, note: CGPoint, fade: Double) {
        if note.x > root.x + 2 {
            var arc = Path()
            arc.move(to: root)
            arc.addQuadCurve(to: note, control: CGPoint(x: (root.x + note.x) / 2, y: max(4, min(root.y, note.y) - 24)))
            context.stroke(arc, with: .color(Palette.amber.opacity(0.45 * fade)), style: StrokeStyle(lineWidth: 1.5, lineCap: .round, dash: [3, 4]))
        }
        context.fill(Self.circle(root, 3), with: .color(Palette.amber.opacity(0.6 * fade)))
    }

    /// The note: an amber bead with a highlight, ringing where it lands.
    private func drawNote(_ context: GraphicsContext, at point: CGPoint, ball: CGFloat, since: Double, fade: Double) {
        if !calm, since >= 0, since < 0.45 {
            let progress = since / 0.45
            context.stroke(Self.circle(point, ball + CGFloat(progress) * 14), with: .color(Palette.amber.opacity(0.7 * (1 - progress) * fade)), lineWidth: 1.5)
        }
        pool(context, at: point, radius: ball * 2.7, color: Palette.amber, strength: 0.55 * fade)
        context.fill(Self.circle(point, ball), with: .color(Palette.amber.opacity(fade)))
        context.fill(Self.circle(CGPoint(x: point.x - ball * 0.27, y: point.y - ball * 0.27), ball * 0.36), with: .color(Color.white.opacity(0.8 * fade)))
    }
}

// MARK: Beat

extension ToolScene {
    /// The person's tempo, within what reads as a swing.
    static func secondsPerBeat(_ bpm: Int) -> Double { 60 / Double(min(220, max(30, bpm))) }

    /// A metronome: a graphite pyramid with its tempo scale, the pendulum swinging to an end on every beat at the
    /// person's tempo, each beat ringing out from the end of the swing and lighting its pip on the case's foot
    /// (the downbeat in amber), the tempo beside it.
    private func drawBeat(_ context: GraphicsContext, size: CGSize, floor: CGFloat, bpm: Int, beats: Int) {
        let spb = Self.secondsPerBeat(bpm)
        let cx = size.width / 2
        let height = floor * 0.8
        let base = max(46, min(124, floor * 0.64))
        let pivot = CGPoint(x: cx, y: floor - height * 0.2)
        let arm = height * (floor < 90 ? 0.88 : 0.96)
        let beat = (elapsed / spb).rounded(.down)
        let since = elapsed - beat * spb
        let bar = max(2, min(8, beats))
        let count = Int(beat) % bar
        let tint = count == 0 ? Palette.amber : Palette.mint
        let swing = 24 * Double.pi / 180
        pool(context, at: CGPoint(x: cx, y: floor * 0.45), radius: min(size.width * 0.38, 160), color: Palette.coral, strength: 0.14)
        let shadow = Gradient(colors: [Color.black.opacity(0.55), Color.black.opacity(0)])
        let foot = CGPoint(x: cx, y: floor)
        context.fill(Path(ellipseIn: CGRect(x: cx - base * 0.62, y: floor - 4, width: base * 1.24, height: 8)),
                     with: .radialGradient(shadow, center: foot, startRadius: 0, endRadius: base * 0.62))
        drawCase(context, cx: cx, floor: floor, top: floor - height, base: base, pivot: pivot)
        drawPips(context, cx: cx, y: floor - height * 0.08, width: base * 0.78, bar: bar, current: count, flash: calm ? 0.6 : max(0, 1 - since / 0.3))
        // Each beat rings out from where the swing turned.
        let turned = swing * cos(Double.pi * beat)
        let end = CGPoint(x: pivot.x + arm * CGFloat(sin(turned)), y: pivot.y - arm * CGFloat(cos(turned)))
        if calm {
            context.stroke(Self.circle(end, 9), with: .color(tint.opacity(0.4)), lineWidth: 1.4)
        } else if since < 0.4 {
            let progress = since / 0.4
            context.stroke(Self.circle(end, 4 + CGFloat(progress) * 18), with: .color(tint.opacity(0.7 * (1 - progress))), lineWidth: 1.4)
        }
        if !calm {
            for ghost in 1...3 {
                let earlier = swing * cos(Double.pi * (elapsed - Double(ghost) * 0.022) / spb)
                drawPendulum(context, pivot: pivot, arm: arm, angle: earlier, alpha: 0.16 / Double(ghost), solid: false)
            }
        }
        drawPendulum(context, pivot: pivot, arm: arm, angle: swing * cos(Double.pi * elapsed / spb), alpha: 1, solid: true)
        let label = cx - base / 2 - 12
        guard floor >= 100, label >= 60 else { return }
        let tempo = context.resolve(Text(verbatim: "♩ = \(bpm)").font(.system(size: 13, weight: .semibold, design: .rounded)).foregroundStyle(Palette.inkSoft))
        context.draw(tempo, at: CGPoint(x: label, y: floor - height * 0.3), anchor: .trailing)
    }

    /// The case: a graphite pyramid with a coral rim and its tempo scale up the middle.
    private func drawCase(_ context: GraphicsContext, cx: CGFloat, floor: CGFloat, top: CGFloat, base: CGFloat, pivot: CGPoint) {
        let crown = base * 0.34
        var body = Path()
        body.move(to: CGPoint(x: cx - base / 2, y: floor))
        body.addLine(to: CGPoint(x: cx - crown / 2, y: top))
        body.addLine(to: CGPoint(x: cx + crown / 2, y: top))
        body.addLine(to: CGPoint(x: cx + base / 2, y: floor))
        body.closeSubpath()
        let graphite = Gradient(colors: [Color(hex: 0x262930), Color(hex: 0x111317)])
        context.fill(body, with: .linearGradient(graphite, startPoint: CGPoint(x: cx, y: top), endPoint: CGPoint(x: cx, y: floor)))
        context.stroke(body, with: .color(Palette.coral.opacity(0.4)), lineWidth: 1)
        let span = pivot.y - 10 - (top + 8)
        guard span > 20 else { return }
        var scale = Path()
        for tick in 0..<9 {
            let y = pivot.y - 10 - CGFloat(tick) * span / 8
            let half: CGFloat = tick % 2 == 0 ? 4 : 2
            scale.move(to: CGPoint(x: cx - half, y: y))
            scale.addLine(to: CGPoint(x: cx + half, y: y))
        }
        context.stroke(scale, with: .color(Color.white.opacity(0.16)), lineWidth: 1)
    }

    /// The pendulum: its rod and, when solid, the sliding weight across it and the pivot.
    private func drawPendulum(_ context: GraphicsContext, pivot: CGPoint, arm: CGFloat, angle: Double, alpha: Double, solid: Bool) {
        let along = CGPoint(x: CGFloat(sin(angle)), y: -CGFloat(cos(angle)))
        var rod = Path()
        rod.move(to: pivot)
        rod.addLine(to: CGPoint(x: pivot.x + arm * along.x, y: pivot.y + arm * along.y))
        context.stroke(rod, with: .color(Palette.ink.opacity(0.9 * alpha)), style: StrokeStyle(lineWidth: 2.2, lineCap: .round))
        guard solid else { return }
        let width = max(10, min(16, arm * 0.13)), height = width * 0.62
        var weight = context
        weight.translateBy(x: pivot.x + arm * 0.62 * along.x, y: pivot.y + arm * 0.62 * along.y)
        weight.rotate(by: .radians(angle))
        let brass = Gradient(colors: [Palette.coral.mix(with: .white, by: 0.25), Palette.coral.mix(with: .black, by: 0.25)])
        weight.fill(Path(roundedRect: CGRect(x: -width / 2, y: -height / 2, width: width, height: height), cornerRadius: 2.5),
                    with: .linearGradient(brass, startPoint: CGPoint(x: 0, y: -height / 2), endPoint: CGPoint(x: 0, y: height / 2)))
        context.fill(Self.circle(pivot, 3.5), with: .color(Palette.ink.opacity(0.9)))
    }

    /// The bar's beats in a row on the case's foot: the one just played lit, the downbeat in amber.
    private func drawPips(_ context: GraphicsContext, cx: CGFloat, y: CGFloat, width: CGFloat, bar: Int, current: Int, flash: Double) {
        let gap: CGFloat = 4
        let pip = max(3, min(6, (width - gap * CGFloat(bar - 1)) / CGFloat(bar)))
        let total = pip * CGFloat(bar) + gap * CGFloat(bar - 1)
        for index in 0..<bar {
            let center = CGPoint(x: cx - total / 2 + pip / 2 + CGFloat(index) * (pip + gap), y: y)
            let lit = index == current
            let color = lit ? (index == 0 ? Palette.amber : Palette.mint) : Color.white.opacity(0.16)
            if lit { pool(context, at: center, radius: pip * 2.2, color: color, strength: 0.6 * (0.4 + 0.6 * flash)) }
            context.fill(Self.circle(center, pip / 2), with: .color(color))
        }
    }
}
