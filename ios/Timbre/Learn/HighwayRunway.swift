import QuartzCore
import SwiftUI
import TimbreCore

/// Fretted play-along as a runway down a fretboard: a lane per string, the lowest string on the left in both views
/// (`StringOrder.upright`), as the chord chart and the player's-view neck (`PlayerNeck`) stand their strings, so a
/// shape learned on either comes down the runway the same way round; mirrored, the lowest on the right, for a
/// left-hander (`mirrored`, never the text in it). Under Differentiate Without Colour every other string is dashed.
/// The lanes lie over dark rosewood whose fret wires and inlays scroll toward you out of the fog, two bars or more of
/// them in view. Each lane ends in a target ring carrying its string's number, the outer two named underneath
/// ("Thinnest", "Thickest"). Notes ride their lane as big glossy gems in the string's colour, the fret over the
/// note name and the finger to use on a white tag at the corner (on a violin's or cello's fingerboard, the finger
/// itself, "0" open, with a tag only when it reaches low or high or the hand shifts position), each gem carrying its
/// string's number in its top corner so a lane never depends on its colour alone, long ones trailing a sustain tail.
/// A hit bursts on the hit line, and a perfect one lights its whole lane white-gold and sends a burst racing both
/// ways along the line. Its verdict pops over the line ("Perfect", "Good", "Early", "Late", "Missed"). The board warms
/// through colour tiers with the combo multiplier (the HUD's flame at ×2, gold at ×3, white-gold at ×4), each new
/// tier rolling up the board from the hit line.
struct HighwayRunway: View {
    let notes: [TimedNote]
    let secondsPerBeat: Double
    let elapsed: Double
    let grades: [Int: PlayAlongJudge.Grade]
    let hitTimes: [Int: CFTimeInterval]
    let now: CFTimeInterval
    let strings: Int
    /// Names the outer lanes under their numbers ("Thinnest (1)", "Thickest (6)"), whichever side they are on.
    var edges: StringEdges?
    /// Beats in a bar: the bar lines are the heavier fret wires, with an inlay in each bar.
    var beatsPerBar = 4
    /// The combo multiplier (1…4): the hit line and the board's binding warm up as it climbs.
    var heat = 1
    /// Reduce Motion: a hit lights its target without bursts, beams or sparks.
    var calm = false
    /// A left-hander's runway: the lowest string on the right.
    var mirrored = false
    /// Seconds early (negative) or late of each note played, for the "Early" and "Late" pops.
    var offsets: [Int: Double] = [:]
    /// When the multiplier last stepped up (on the `now` clock): the new tier's colour rolls up the board.
    var tierUp: CFTimeInterval?
    /// A violin's or cello's fingerboard: gems carry the finger, never a fret.
    var fingerboard: Fingerboard?
    /// The string numbers and edge names grow with Dynamic Type from the 11 pt floor (`DiagramType`).
    @ScaledMetric(relativeTo: .caption2) private var typeScale: CGFloat = 1
    @Environment(\.accessibilityDifferentiateWithoutColor) private var differentiate

    /// Seconds of music in view ahead of the hit line: two bars (eight beats at least, twelve at most), never
    /// under 2.8 s on a fast tune, so three or four notes are on the board whatever the tempo.
    static func lookahead(secondsPerBeat: Double, beatsPerBar: Int) -> Double {
        let beats = min(12, max(8, 2 * max(1, beatsPerBar)))
        return max(2.8, Double(beats) * max(0.05, secondsPerBeat))
    }
    private var lookahead: Double { Self.lookahead(secondsPerBeat: secondsPerBeat, beatsPerBar: beatsPerBar) }

    /// The white-gold of a perfect note.
    static let perfectGold = Color(hex: 0xFFE7A3)
    /// Depth of the board's near edge, past the hit line (the bottom of the stage).
    private static let near = -0.15
    /// Notes this long (in beats) and longer trail a sustain tail.
    private static let sustainBeats = 1.5
    /// A gem's width as a share of its lane, and its height at the hit line (points).
    private static let gemWidth: CGFloat = 0.96
    private static let gemHeight: CGFloat = 56
    /// Gems this far scaled down (toward the horizon) drop the note name under the fret, and the finger tag.
    private static let nameScale: CGFloat = 0.5
    /// How long a perfect note's lane stays lit, and its burst runs along the hit line.
    private static let perfectFlash = 0.45

    /// The strings' colours, string 1 first: sky, blue, pink, lime, violet, ice. None is a verdict's (mint, amber and
    /// coral say how a note went); neighbouring strings stay far apart under every colour-vision deficiency, and the
    /// ice of the sixth stands clear of the third's pink under deuteranopia. Six lanes can't all differ by colour under
    /// protanopia, so every gem carries its string's number too.
    private static let palette: [Color] = [Palette.sky, Color(hex: 0x6E8BFF), Color(hex: 0xFF7AD0), Palette.lime,
                                           Palette.violet, Color(hex: 0xB8F0FF)]
    static func color(string: Int, of count: Int) -> Color {
        let index = count <= 1 ? 0 : Int((Double(string - 1) / Double(count - 1) * Double(palette.count - 1)).rounded())
        return palette[min(palette.count - 1, max(0, index))]
    }

    // The fixed shades, made once rather than on every frame.
    private static let sky = Gradient(colors: [Color(hex: 0x14161B), Palette.stageDeep])
    private static let haze = Gradient(colors: [Color(hex: 0x2B3442).opacity(0.6), Color(hex: 0x2B3442).opacity(0)])
    private static let wood = Gradient(colors: [Color(hex: 0x16100D), Color(hex: 0x3B2A1F)])
    private static let roll = Gradient(colors: [Color.black.opacity(0.4), Color.black.opacity(0), Color.black.opacity(0), Color.black.opacity(0.4)])
    private static let fog = Gradient(colors: [Color(hex: 0x0C0E12).opacity(0.95), Color(hex: 0x0C0E12).opacity(0.45), Color(hex: 0x0C0E12).opacity(0)])
    private static let vignette = Gradient(colors: [Color.black.opacity(0.45), Color.black.opacity(0)])
    private static let wireMetal = Color(hex: 0xC9CED6)
    private static let bone = Color(hex: 0xEDE3CF)
    private static let hitLine = Color(hex: 0xFFF4DE)

    var body: some View {
        let scale = typeScale
        let dashed = differentiate
        Canvas { context, size in draw(&context, size: size, scale: scale, dashed: dashed) }
            .accessibilityHidden(true)
    }

    /// The runway's perspective: depth 0 is the hit line, 1 the horizon, negative past the line toward you.
    private struct Lanes {
        let width: CGFloat
        let hitY: CGFloat
        let horizonY: CGFloat
        let gap: CGFloat
        let strings: Int
        let order: StringOrder

        init(size: CGSize, strings: Int, order: StringOrder) {
            width = size.width
            hitY = size.height - 58
            horizonY = 16
            self.strings = max(1, strings)
            self.order = order
            gap = (size.width - 36) / CGFloat(max(1, strings))
        }

        func depth(_ d: Double) -> CGFloat { CGFloat(d / (abs(d) + 0.55) * 1.55) }
        func y(_ d: Double) -> CGFloat { hitY - (hitY - horizonY) * depth(d) }
        func scale(_ d: Double) -> CGFloat { 1 - 0.8 * depth(max(-0.3, d)) }
        /// Lane centre of a string: the lane its row takes, counted from the left.
        func x(_ string: Int, _ d: Double) -> CGFloat { laneX(order.row(ofString: string, count: strings), d) }
        func laneX(_ row: Int, _ d: Double) -> CGFloat {
            let lane = CGFloat(row) - CGFloat(strings - 1) / 2
            return width / 2 + lane * gap * scale(d)
        }
        /// The strings in the outer lanes.
        var leftString: Int { order.string(atRow: 0, count: strings) }
        var rightString: Int { order.string(atRow: strings - 1, count: strings) }
        func left(_ d: Double) -> CGFloat { laneX(0, d) - gap * 0.5 * scale(d) }
        func right(_ d: Double) -> CGFloat { laneX(strings - 1, d) + gap * 0.5 * scale(d) }
        /// A point across the board at a depth: 0 its left edge, 1 its right.
        func across(_ u: CGFloat, _ d: Double) -> CGPoint { CGPoint(x: left(d) + (right(d) - left(d)) * u, y: y(d)) }
        /// How clearly something at depth `d` shows through the fog toward the horizon.
        func clarity(_ d: Double) -> Double { d < 0.55 ? 1 : max(0.15, 1 - (d - 0.55) / 0.45 * 0.85) }
    }

    private func draw(_ context: inout GraphicsContext, size: CGSize, scale: CGFloat, dashed: Bool) {
        let g = Lanes(size: size, strings: strings, order: mirrored ? .tab : StringOrder.upright)
        drawBoard(&context, g, size: size)
        drawTierWave(&context, g)
        drawFrets(&context, g)
        drawLanes(&context, g, dashed: dashed)
        drawFog(&context, g, size: size)
        drawTargets(&context, g, scale: scale)
        // Far notes first, so near ones draw on top. Colours and labels are made once a frame, not once a gem.
        let shades = (1...max(1, strings)).map { Shade(Self.color(string: $0, of: strings)) }
        var labels = GemLabels()
        for i in notes.indices.reversed() { drawNote(&context, g, index: i, shades: shades, labels: &labels) }
        drawHits(&context, g)
        drawVignette(&context, size: size)
        drawPops(&context, g, size: size)
        drawLabels(&context, g, scale: scale)
    }

    // MARK: Board

    /// Sky with a glow at the vanishing point, and the fretboard: rosewood with its grain running toward you
    /// (so it never needs to scroll), rolled darker at the edges, and bone binding that warms with the multiplier.
    private func drawBoard(_ context: inout GraphicsContext, _ g: Lanes, size: CGSize) {
        context.fill(Path(CGRect(origin: .zero, size: size)), with: .linearGradient(Self.sky, startPoint: .zero, endPoint: CGPoint(x: 0, y: size.height)))
        let vanish = CGPoint(x: size.width / 2, y: g.horizonY)
        let haze = size.width * 0.6
        context.fill(circle(vanish, haze), with: .radialGradient(Self.haze, center: vanish, startRadius: 0, endRadius: haze))
        var board = Path()
        board.move(to: CGPoint(x: g.left(1), y: g.horizonY))
        board.addLine(to: CGPoint(x: g.right(1), y: g.horizonY))
        board.addLine(to: CGPoint(x: g.right(Self.near), y: g.y(Self.near)))
        board.addLine(to: CGPoint(x: g.left(Self.near), y: g.y(Self.near)))
        board.closeSubpath()
        context.fill(board, with: .linearGradient(Self.wood, startPoint: CGPoint(x: 0, y: g.horizonY), endPoint: CGPoint(x: 0, y: g.hitY)))
        var grain = context
        grain.clip(to: board)
        for i in 0..<22 {
            let u = CGFloat((Double(i) + 0.15 + 0.7 * CanvasNoise.value(i + 300)) / 22)
            let mid = g.across(u, 0.3)
            var line = Path()
            line.move(to: g.across(u, 1))
            line.addQuadCurve(to: g.across(u, Self.near), control: CGPoint(x: mid.x + CGFloat(CanvasNoise.value(i + 340) - 0.5) * 10, y: mid.y))
            let tone: Color = i % 3 == 0 ? Color.white.opacity(0.03) : Color.black.opacity(0.18 + 0.15 * CanvasNoise.value(i + 380))
            grain.stroke(line, with: .color(tone), lineWidth: 0.7 + 1.6 * CGFloat(CanvasNoise.value(i + 420)))
        }
        grain.fill(board, with: .linearGradient(Self.roll, startPoint: CGPoint(x: g.left(0), y: 0), endPoint: CGPoint(x: g.right(0), y: 0)))
        if let tier = tierTint {
            // The combo's tier warms the wood from the hit line up, and the glow at the vanishing point with it.
            var glow = context
            glow.blendMode = .plusLighter
            glow.fill(board, with: .linearGradient(Gradient(colors: [tier.opacity(0), tier.opacity(tierStrength)]),
                                                   startPoint: CGPoint(x: 0, y: g.y(0.75)), endPoint: CGPoint(x: 0, y: g.y(Self.near))))
            glow.fill(circle(vanish, haze * 0.7), with: .radialGradient(Gradient(colors: [tier.opacity(tierStrength * 0.9), tier.opacity(0)]),
                                                                       center: vanish, startRadius: 0, endRadius: haze * 0.7))
        }
        var binding = Path()
        binding.move(to: CGPoint(x: g.left(1), y: g.horizonY))
        binding.addLine(to: CGPoint(x: g.left(Self.near), y: g.y(Self.near)))
        binding.move(to: CGPoint(x: g.right(1), y: g.horizonY))
        binding.addLine(to: CGPoint(x: g.right(Self.near), y: g.y(Self.near)))
        let edge = heatTint
        if heat >= 2 { context.stroke(binding, with: .color(edge.opacity(0.08 * Double(heat))), lineWidth: 7) }
        context.stroke(binding, with: .linearGradient(Gradient(colors: [edge.opacity(0.05), edge.opacity(heat >= 2 ? 0.65 : 0.35)]),
                                                      startPoint: CGPoint(x: 0, y: g.horizonY), endPoint: CGPoint(x: 0, y: g.hitY)), lineWidth: 1.6)
    }

    /// Bone at ×1–2, gold at ×3, white-gold at ×4: warmth, never the amber that says a note was early or late.
    private var heatTint: Color {
        switch heat {
        case 4...: return Self.perfectGold
        case 3: return Palette.starGold
        default: return Self.bone
        }
    }

    /// The board's colour tier: none at ×1, then the HUD dial's colour (flame ×2, amber ×3, white-gold ×4).
    private var tierTint: Color? { heat >= 2 ? ComboBadge.tint(heat) : nil }
    /// How strongly the tier tints the board, stronger each step.
    private var tierStrength: Double {
        switch heat {
        case 4...: return 0.2
        case 3: return 0.15
        default: return 0.1
        }
    }

    /// A tier just reached: a band of its colour rolls from the hit line up to the horizon, and the binding flares.
    private func drawTierWave(_ context: inout GraphicsContext, _ g: Lanes) {
        guard !calm, let tierUp, let tier = tierTint else { return }
        let age = now - tierUp
        let life = 0.8
        guard age >= 0, age < life else { return }
        let p = age / life
        let eased = 1 - pow(1 - p, 2)
        let front = Self.near + (1 - Self.near) * eased
        let back = max(Self.near, front - 0.18)
        var band = Path()
        band.move(to: CGPoint(x: g.left(back), y: g.y(back)))
        band.addLine(to: CGPoint(x: g.right(back), y: g.y(back)))
        band.addLine(to: CGPoint(x: g.right(front), y: g.y(front)))
        band.addLine(to: CGPoint(x: g.left(front), y: g.y(front)))
        band.closeSubpath()
        var light = context
        light.blendMode = .plusLighter
        light.fill(band, with: .linearGradient(Gradient(colors: [tier.opacity(0), tier.opacity(0.5 * (1 - p))]),
                                               startPoint: CGPoint(x: 0, y: g.y(back)), endPoint: CGPoint(x: 0, y: g.y(front))))
        var sides = Path()
        sides.move(to: CGPoint(x: g.left(1), y: g.horizonY))
        sides.addLine(to: CGPoint(x: g.left(Self.near), y: g.y(Self.near)))
        sides.move(to: CGPoint(x: g.right(1), y: g.horizonY))
        sides.addLine(to: CGPoint(x: g.right(Self.near), y: g.y(Self.near)))
        light.stroke(sides, with: .color(tier.opacity(0.7 * (1 - p))), lineWidth: 4)
    }

    /// Fret wires scrolling toward you, one per beat with the bar lines heavier, and a pearl inlay mid-bar.
    private func drawFrets(_ context: inout GraphicsContext, _ g: Lanes) {
        let spb = max(0.05, secondsPerBeat)
        let meter = max(1, beatsPerBar)
        let ahead = lookahead
        let firstBeat = Int((elapsed / spb).rounded(.down))
        let lastBeat = firstBeat + Int(ahead / spb) + 1
        for beat in firstBeat...lastBeat {
            let d = (Double(beat) * spb - elapsed) / ahead
            guard d > -0.1, d < 1 else { continue }
            let bar = ((beat % meter) + meter) % meter == 0
            let sc = g.scale(d), clear = g.clarity(d)
            var wire = Path()
            wire.move(to: CGPoint(x: g.left(d), y: g.y(d)))
            wire.addLine(to: CGPoint(x: g.right(d), y: g.y(d)))
            let w: CGFloat = (bar ? 3.2 : 1.6) * sc
            context.stroke(wire.offsetBy(dx: 0, dy: w * 0.8), with: .color(.black.opacity(0.45 * clear)), lineWidth: w)
            context.stroke(wire, with: .color(Self.wireMetal.opacity((bar ? 0.42 : 0.2) * clear)), lineWidth: w)
            context.stroke(wire.offsetBy(dx: 0, dy: -w * 0.25), with: .color(.white.opacity((bar ? 0.35 : 0.15) * clear)), lineWidth: max(0.5, w * 0.35))
        }
        let barSeconds = Double(meter) * spb
        let firstBar = Int((elapsed / barSeconds).rounded(.down)) - 1
        let lastBar = firstBar + Int(ahead / barSeconds) + 2
        for bar in firstBar...lastBar {
            let d = ((Double(bar) + 0.5) * barSeconds - elapsed) / ahead
            guard d > -0.1, d < 1 else { continue }
            let sc = g.scale(d), clear = g.clarity(d)
            let c = CGPoint(x: g.width / 2, y: g.y(d))
            let rx = 7 * sc, ry = 4.2 * sc
            let pearl = Path(ellipseIn: CGRect(x: c.x - rx, y: c.y - ry, width: rx * 2, height: ry * 2))
            let shine = Gradient(colors: [Color.white.opacity(0.42 * clear), Color(hex: 0xB9D3DC).opacity(0.16 * clear)])
            context.fill(pearl, with: .radialGradient(shine, center: CGPoint(x: c.x - rx * 0.3, y: c.y - ry * 0.3), startRadius: 0, endRadius: rx))
        }
    }

    /// The strings, a lane each: a coloured glow under a metal core, brighter toward you, flaring for a moment
    /// when one of its notes is hit; a perfect note lights the whole lane white-gold, horizon to hit line. The low
    /// strings are the thicker ones. `dashed` (Differentiate Without Colour) draws every even string's core dashed,
    /// so neighbouring lanes differ by more than their colour.
    private func drawLanes(_ context: inout GraphicsContext, _ g: Lanes, dashed: Bool) {
        var light = context
        light.blendMode = .plusLighter
        for s in 1...g.strings {
            let tint = Self.color(string: s, of: strings)
            let gauge = g.strings > 1 ? CGFloat(s - 1) / CGFloat(g.strings - 1) : 0.5
            let half = 0.8 + gauge * 1.1
            let state = target(string: s)
            let lit = state.flash
            let from = CGPoint(x: 0, y: g.horizonY), to = CGPoint(x: 0, y: g.hitY)
            context.fill(lane(g, string: s, half: half * 5 + CGFloat(lit) * 10),
                         with: .linearGradient(Gradient(colors: [tint.opacity(0.02), tint.opacity(0.16 + 0.3 * lit)]), startPoint: from, endPoint: to))
            let core = GraphicsContext.Shading.linearGradient(Gradient(colors: [tint.opacity(0.15), tint.mix(with: .white, by: 0.35).opacity(0.9)]),
                                                              startPoint: from, endPoint: to)
            if dashed && s % 2 == 0 {
                var line = Path()
                line.move(to: CGPoint(x: g.x(s, 1), y: g.horizonY))
                line.addLine(to: CGPoint(x: g.x(s, Self.near), y: g.y(Self.near)))
                context.stroke(line, with: core, style: StrokeStyle(lineWidth: max(2.5, half * 2.2), lineCap: .butt, dash: [9, 7]))
            } else {
                context.fill(lane(g, string: s, half: half), with: core)
            }
            let flash = state.perfect
            guard flash > 0, !calm else { continue }
            // Perfect: the lane flashes white-gold its whole length, brightest at the line, and its core burns white.
            light.fill(lane(g, string: s, half: g.gap * 0.42),
                       with: .linearGradient(Gradient(colors: [Self.perfectGold.opacity(0.08 * flash), Self.perfectGold.opacity(0.42 * flash)]),
                                             startPoint: from, endPoint: to))
            light.fill(lane(g, string: s, half: half + 1.5), with: .color(Color.white.opacity(0.75 * flash)))
        }
    }

    /// A lane's strip from the horizon to the near edge, `half` either side of its centre at the hit line.
    private func lane(_ g: Lanes, string s: Int, half: CGFloat) -> Path {
        let far = half * g.scale(1), close = half * g.scale(Self.near)
        var p = Path()
        p.move(to: CGPoint(x: g.x(s, 1) - far, y: g.horizonY))
        p.addLine(to: CGPoint(x: g.x(s, 1) + far, y: g.horizonY))
        p.addLine(to: CGPoint(x: g.x(s, Self.near) + close, y: g.y(Self.near)))
        p.addLine(to: CGPoint(x: g.x(s, Self.near) - close, y: g.y(Self.near)))
        p.closeSubpath()
        return p
    }

    /// Depth fog over the far end of the board: notes rise out of it.
    private func drawFog(_ context: inout GraphicsContext, _ g: Lanes, size: CGSize) {
        let end = g.y(0.5)
        context.fill(Path(CGRect(x: 0, y: 0, width: size.width, height: end)),
                     with: .linearGradient(Self.fog, startPoint: CGPoint(x: 0, y: g.horizonY), endPoint: CGPoint(x: 0, y: end)))
    }

    // MARK: Hit line

    private struct TargetState {
        /// 1 → 0 over the moment after one of the string's notes is hit.
        var flash = 0.0
        /// 1 → 0 over the moment after one of its notes is hit perfectly: the lane's white-gold flash.
        var perfect = 0.0
        /// One of its notes was just missed.
        var missed = false
        /// 0 → 1 as its next note closes in on the line.
        var approach = 0.0
    }

    private func target(string s: Int) -> TargetState {
        var state = TargetState()
        for i in notes.indices where notes[i].at?.string == s {
            if let grade = grades[i] {
                guard let time = hitTimes[i] else { continue }
                let age = now - time
                guard age >= 0 else { continue }
                if grade == .perfect, age < Self.perfectFlash {
                    let f = 1 - age / Self.perfectFlash
                    state.perfect = max(state.perfect, f * f)
                }
                guard age < 0.35 else { continue }
                if grade == .miss { state.missed = true } else { state.flash = max(state.flash, 1 - age / 0.35) }
            } else {
                // Fills over the last 0.45 s before its note, whatever the tempo.
                let due = notes[i].beat * secondsPerBeat - elapsed
                if due > -0.15, due < 0.45 { state.approach = max(state.approach, 1 - max(0, due) / 0.45) }
            }
        }
        return state
    }

    /// A target ring's radius: sized to the gems, within its lane.
    private static func targetRadius(_ g: Lanes) -> CGFloat { min(21, g.gap * 0.38) }

    /// The hit line across the board and a target ring per string, its number inside: recessed, filling as a note
    /// comes in, flashing in the string's colour on a hit (coral on a miss).
    private func drawTargets(_ context: inout GraphicsContext, _ g: Lanes, scale: CGFloat) {
        let from = g.left(0) - 6, to = g.right(0) + 6
        let line = heat >= 3 ? heatTint : Self.hitLine
        let band = CGRect(x: from, y: g.hitY - 13, width: to - from, height: 26)
        context.fill(Path(roundedRect: band, cornerRadius: 13),
                     with: .linearGradient(Gradient(colors: [line.opacity(0), line.opacity(0.1 + 0.04 * Double(heat)), line.opacity(0)]),
                                           startPoint: CGPoint(x: 0, y: band.minY), endPoint: CGPoint(x: 0, y: band.maxY)))
        context.fill(Path(roundedRect: CGRect(x: from, y: g.hitY - 1.5, width: to - from, height: 3), cornerRadius: 1.5), with: .color(line.opacity(0.75)))
        let radius = Self.targetRadius(g)
        for s in 1...g.strings {
            let state = target(string: s)
            let tint = state.missed ? Palette.danger : Self.color(string: s, of: strings)
            let center = CGPoint(x: g.x(s, 0), y: g.hitY)
            let r = radius * (1 + (calm ? 0 : CGFloat(state.flash) * 0.2))
            context.fill(circle(center, radius + 3), with: .color(.black.opacity(0.5)))
            let fill = Gradient(colors: [tint.opacity(0.08 + 0.35 * state.approach + 0.5 * state.flash), tint.opacity(0.04 + 0.2 * state.flash)])
            context.fill(circle(center, r), with: .radialGradient(fill, center: center, startRadius: 0, endRadius: r))
            context.stroke(circle(center, r), with: .color(tint.opacity(0.75 + 0.25 * max(state.approach, state.flash))), lineWidth: 2.5)
            var shine = Path()
            shine.addRelativeArc(center: center, radius: max(1, r - 3.5), startAngle: .degrees(205), delta: .degrees(130))
            context.stroke(shine, with: .color(.white.opacity(0.28)), style: StrokeStyle(lineWidth: 1.5, lineCap: .round))
            // The string's number, in its colour, brightening as its note closes in.
            let lift = max(state.approach, state.flash)
            let number = Text(verbatim: "\(s)").font(DiagramType.font(13, weight: .heavy, scale: scale))
                .foregroundStyle(tint.mix(with: .white, by: 0.55 + 0.35 * lift).opacity(0.75 + 0.25 * lift))
            context.draw(number, at: center)
        }
    }

    // MARK: Notes

    /// A string's colours for its gems and tails, mixed once a frame rather than once a gem.
    private struct Shade {
        let tint: Color
        /// The edge a gem stands on, the bevel inside its rim, its face's light and shadow; the same for a gem
        /// flashing white on a hit.
        let edge, bevel, light, dark: Color
        let hitFace, hitBevel, hitLight, hitDark: Color
        /// The finger tag's rim and number, and a sustain tail's edge.
        let tagRim, tagInk, tailEdge: Color

        init(_ tint: Color) {
            self.tint = tint
            edge = tint.mix(with: .black, by: 0.5)
            bevel = tint.mix(with: .black, by: 0.3)
            light = tint.mix(with: .white, by: 0.35)
            dark = tint.mix(with: .black, by: 0.18)
            let hit = tint.mix(with: .white, by: 0.7)
            hitFace = hit
            hitBevel = hit.mix(with: .black, by: 0.3)
            hitLight = hit.mix(with: .white, by: 0.35)
            hitDark = hit.mix(with: .black, by: 0.18)
            tagRim = bevel
            tagInk = tint.mix(with: .black, by: 0.62)
            tailEdge = tint.mix(with: .black, by: 0.45)
        }
    }

    /// The gems' labels (fret or finger figures, note names, finger tags, a fingerboard's marks, string numbers), each
    /// laid out once a frame at a fixed size and scaled with its gem, instead of a new font size for every gem on every
    /// frame.
    private struct GemLabels {
        private var frets: [Int: GraphicsContext.ResolvedText] = [:]
        private var names: [Int: GraphicsContext.ResolvedText] = [:]
        private var fingers: [Int: GraphicsContext.ResolvedText] = [:]
        private var marks: [String: GraphicsContext.ResolvedText] = [:]
        private var strings: [Int: GraphicsContext.ResolvedText] = [:]

        /// The sizes the labels are laid out at: their size on a gem at the hit line.
        static let fretSize: CGFloat = 25
        static let nameSize: CGFloat = 13
        static let fingerSize: CGFloat = 14
        static let stringSize: CGFloat = 11

        mutating func mark(_ mark: String, in context: GraphicsContext) -> GraphicsContext.ResolvedText {
            if let known = marks[mark] { return known }
            let text = context.resolve(Text(verbatim: mark).font(.system(size: Self.fingerSize, weight: .heavy, design: .rounded)))
            marks[mark] = text
            return text
        }

        mutating func string(_ string: Int, in context: GraphicsContext) -> GraphicsContext.ResolvedText {
            if let known = strings[string] { return known }
            let text = context.resolve(Text(verbatim: "\(string)").font(.system(size: Self.stringSize, weight: .heavy, design: .rounded)))
            strings[string] = text
            return text
        }

        mutating func fret(_ fret: Int, in context: GraphicsContext) -> GraphicsContext.ResolvedText {
            if let known = frets[fret] { return known }
            let text = context.resolve(Text(verbatim: "\(fret)").font(.system(size: Self.fretSize, weight: .heavy, design: .rounded)))
            frets[fret] = text
            return text
        }

        mutating func name(_ midi: Int, in context: GraphicsContext) -> GraphicsContext.ResolvedText {
            let pitchClass = ((midi % 12) + 12) % 12
            if let known = names[pitchClass] { return known }
            let text = context.resolve(Text(verbatim: NoteName.pitchClass(midi)).font(.system(size: Self.nameSize, weight: .bold, design: .rounded)))
            names[pitchClass] = text
            return text
        }

        mutating func finger(_ finger: Int, in context: GraphicsContext) -> GraphicsContext.ResolvedText {
            if let known = fingers[finger] { return known }
            let text = context.resolve(Text(verbatim: "\(finger)").font(.system(size: Self.fingerSize, weight: .heavy, design: .rounded)))
            fingers[finger] = text
            return text
        }
    }

    /// A resolved label in `color`, centred on `point` and drawn at `scale` of its laid-out size (on a copy of the
    /// context, which draws to the same canvas).
    private func drawLabel(_ context: GraphicsContext, _ text: GraphicsContext.ResolvedText, color: Color, at point: CGPoint, scale: CGFloat) {
        var label = text
        label.shading = .color(color)
        var placed = context
        placed.translateBy(x: point.x, y: point.y)
        placed.scaleBy(x: scale, y: scale)
        placed.draw(label, at: .zero, anchor: .center)
    }

    private func drawNote(_ context: inout GraphicsContext, _ g: Lanes, index i: Int, shades: [Shade], labels: inout GemLabels) {
        let note = notes[i]
        guard let at = note.at else { return }
        let ahead = lookahead
        let start = (note.beat * secondsPerBeat - elapsed) / ahead
        let end = ((note.beat + note.beats) * secondsPerBeat - elapsed) / ahead
        guard start < 1.05, end > -0.25 else { return }
        let grade = grades[i]
        let age = min(1, hitTimes[i].map { now - $0 } ?? 0)
        let shade = shades.indices.contains(at.string - 1) ? shades[at.string - 1] : Shade(Self.color(string: at.string, of: strings))
        if note.beats >= Self.sustainBeats {
            // It stops a little short of where the note ends, so a run of long notes still reads as separate notes.
            let gap = 0.2 * secondsPerBeat / ahead
            drawTail(&context, g, string: at.string, start: start, end: end - gap, shade: shade, grade: grade)
        }
        let gem = Gem(string: at.string, place: gemPlace(at), midi: note.midi, start: start, grade: grade, age: age)
        drawGem(&context, g, gem, shade: shade, labels: &labels)
    }

    /// What a gem says about where it is played: its big figure and the tag at its corner.
    private struct GemPlace {
        /// The fret, or on a fingerboard the finger ("0" open).
        let figure: Int
        /// The finger to fret it with (a fretted neck), on a white tag.
        let finger: Int?
        /// A fingerboard's mark on that tag instead: "↓" low, "↑" high, or the position.
        let mark: String?
    }

    /// One note's gem as it stands this frame: its string and place, its note, how far up the board it is (0 the hit
    /// line), how it went and how long ago it was judged.
    private struct Gem {
        let string: Int
        let place: GemPlace
        let midi: Int
        let start: Double
        let grade: PlayAlongJudge.Grade?
        /// Seconds since it was judged, at most 1 (0 while it waits).
        let age: Double
    }

    private func gemPlace(_ at: Fretting) -> GemPlace {
        guard let fingerboard else { return GemPlace(figure: at.fret, finger: at.fret > 0 ? at.finger : nil, mark: nil) }
        let place = FingerPlace(at, on: fingerboard)
        return GemPlace(figure: place.finger, finger: nil, mark: place.mark)
    }

    /// A long note's sustain tail up its lane to where the note ends: a ribbon in the string's colour, edged darker
    /// so it reads apart from the string under it, round at its end, with a bright core. While it rings after a hit,
    /// light runs down the core and it burns down where it meets the line; once missed it greys.
    private func drawTail(_ context: inout GraphicsContext, _ g: Lanes, string s: Int, start: Double, end: Double, shade: Shade, grade: PlayAlongJudge.Grade?) {
        let held = grade != nil && grade != .miss
        let a = held ? max(start, 0) : max(start, Self.near)
        let b = min(end, 1)
        guard b > a else { return }
        let missed = grade == .miss
        let color = missed ? Palette.inkFaint : shade.tint
        let edge = missed ? Self.missedTailEdge : shade.tailEdge
        let strength = missed ? 0.3 : held ? 1.0 : 0.8
        let far = g.clarity(b)
        let half = g.gap * 0.16
        let ya = g.y(a), yb = g.y(b)
        let tail = ribbon(g, string: s, from: a, to: b, half: half)
        let fill = Gradient(colors: [color.opacity(0.9 * strength), color.opacity(0.3 * strength * far)])
        context.fill(tail, with: .linearGradient(fill, startPoint: CGPoint(x: 0, y: ya), endPoint: CGPoint(x: 0, y: yb)))
        context.stroke(tail, with: .color(edge.opacity(0.8 * strength)), lineWidth: 1)
        let cap = CGPoint(x: g.x(s, b), y: yb)
        context.fill(circle(cap, half * g.scale(b)), with: .color(color.opacity(0.3 * strength * far)))
        var core = Path()
        core.move(to: CGPoint(x: g.x(s, a), y: ya))
        core.addLine(to: cap)
        context.stroke(core, with: .color(.white.opacity((held ? 0.85 : 0.45) * strength)), lineWidth: 2.2 * g.scale(a))
        guard held, !calm else { return }
        // Light running down the core toward the line while it rings.
        let phase = CGFloat((now * 70).truncatingRemainder(dividingBy: 18))
        context.stroke(core, with: .color(.white.opacity(0.9)),
                       style: StrokeStyle(lineWidth: 4.5 * g.scale(a), lineCap: .round, dash: [4, 14], dashPhase: phase))
        if start <= 0, end > 0 {
            // Ringing: it burns down where it meets the line.
            let center = CGPoint(x: g.x(s, 0), y: g.hitY)
            let flicker = 16 + 5 * CGFloat(sin(now * 38 + Double(s)))
            let flare = Gradient(colors: [Color.white.opacity(0.85), shade.tint.opacity(0.5), shade.tint.opacity(0)])
            context.fill(circle(center, flicker), with: .radialGradient(flare, center: center, startRadius: 0, endRadius: flicker))
        }
    }

    /// A missed tail's edge (the faint ink, darkened).
    private static let missedTailEdge = Palette.inkFaint.mix(with: .black, by: 0.45)

    /// A strip up a string's lane from depth `a` to `b`, `half` either side of its centre at the hit line.
    private func ribbon(_ g: Lanes, string s: Int, from a: Double, to b: Double, half: CGFloat) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: g.x(s, a) - half * g.scale(a), y: g.y(a)))
        p.addLine(to: CGPoint(x: g.x(s, b) - half * g.scale(b), y: g.y(b)))
        p.addLine(to: CGPoint(x: g.x(s, b) + half * g.scale(b), y: g.y(b)))
        p.addLine(to: CGPoint(x: g.x(s, a) + half * g.scale(a), y: g.y(a)))
        p.closeSubpath()
        return p
    }

    /// A note gem: a big glossy tile in its string's colour (nearly its whole lane), the fret (a fingerboard's finger)
    /// over the note's name, its string's number in its top-left corner and the finger to fret it with (a
    /// fingerboard's low, high or position mark) on a white tag at its top-right corner, standing on its own darker
    /// edge with its shadow on the wood, and lighting the board as it nears the line. A hit pops white for an instant
    /// (its burst takes over); a miss runs on past, hollow and coral.
    private func drawGem(_ context: inout GraphicsContext, _ g: Lanes, _ gem: Gem, shade: Shade, labels: inout GemLabels) {
        let s = gem.string, place = gem.place, midi = gem.midi, start = gem.start, grade = gem.grade, age = gem.age
        let fret = place.figure
        let hit = grade != nil && grade != .miss
        if hit && (calm || age > 0.16) { return }
        let d = hit ? 0 : start
        let sc = g.scale(d)
        var w = g.gap * Self.gemWidth * sc
        var h = min(Self.gemHeight, g.gap * 1.02) * sc
        var alpha = (start > 0.85 ? max(0, (1.05 - start) / 0.2) : 1) * g.clarity(d)
        if hit {
            let pop = 1 + CGFloat(age / 0.16) * 0.5
            w *= pop; h *= pop
            alpha = 1 - age / 0.16
        }
        if grade == .miss { alpha = max(0.2, 0.8 - age) }
        guard alpha > 0.01 else { return }
        let center = CGPoint(x: g.x(s, d), y: g.y(d))
        let rect = CGRect(x: center.x - w / 2, y: center.y - h / 2, width: w, height: h)
        let corner = min(w, h) * 0.3
        let face = Path(roundedRect: rect, cornerRadius: corner, style: .continuous)
        let fretScale = max(9 / GemLabels.fretSize, sc)
        if grade == .miss {
            context.fill(face, with: .color(Palette.danger.opacity(0.12 * alpha)))
            context.stroke(face, with: .color(Palette.danger.opacity(0.8 * alpha)), lineWidth: 2)
            drawLabel(context, labels.fret(fret, in: context), color: Palette.danger.opacity(alpha), at: center,
                      scale: max(9 / GemLabels.fretSize, 23 * sc / GemLabels.fretSize))
            return
        }
        if grade == nil, d < 0.35 {
            // Its light on the board as it closes in.
            let reach = w * 1.15
            let glow = Gradient(colors: [shade.tint.opacity(0.4 * (1 - d / 0.35) * alpha), shade.tint.opacity(0)])
            context.fill(circle(center, reach), with: .radialGradient(glow, center: center, startRadius: 0, endRadius: reach))
        }
        // Its shadow on the wood, then the edge it stands on.
        let shadow = rect.offsetBy(dx: 0, dy: 8 * sc).insetBy(dx: w * 0.05, dy: h * 0.05)
        context.fill(Path(roundedRect: shadow, cornerRadius: corner, style: .continuous), with: .color(.black.opacity(0.4 * alpha)))
        context.fill(Path(roundedRect: rect.offsetBy(dx: 0, dy: 5 * sc), cornerRadius: corner, style: .continuous),
                     with: .color(shade.edge.opacity(alpha)))
        let faceTint = hit ? shade.hitFace : shade.tint
        let faceLight = hit ? shade.hitLight : shade.light
        let faceDark = hit ? shade.hitDark : shade.dark
        let faceBevel = hit ? shade.hitBevel : shade.bevel
        let gradient = Gradient(colors: [faceLight.opacity(alpha), faceTint.opacity(alpha), faceDark.opacity(alpha)])
        context.fill(face, with: .linearGradient(gradient, startPoint: CGPoint(x: rect.midX, y: rect.minY), endPoint: CGPoint(x: rect.midX, y: rect.maxY)))
        // A bevel just inside the rim, the gloss over the top, a glint in its corner.
        let bevel = rect.insetBy(dx: 2.5 * sc, dy: 2.5 * sc)
        context.stroke(Path(roundedRect: bevel, cornerRadius: max(0, corner - 2.5 * sc), style: .continuous),
                       with: .color(faceBevel.opacity(0.45 * alpha)), lineWidth: max(0.5, 1.2 * sc))
        let gloss = CGRect(x: rect.minX + 3 * sc, y: rect.minY + 2 * sc, width: max(0, rect.width - 6 * sc), height: rect.height * 0.4)
        context.fill(Path(roundedRect: gloss, cornerRadius: corner * 0.7, style: .continuous),
                     with: .linearGradient(Gradient(colors: [Color.white.opacity(0.5 * alpha), Color.white.opacity(0)]),
                                           startPoint: CGPoint(x: 0, y: gloss.minY), endPoint: CGPoint(x: 0, y: gloss.maxY)))
        context.stroke(face, with: .color(.white.opacity(0.4 * alpha)), lineWidth: 1)
        let glint = CGRect(x: rect.minX + w * 0.12, y: rect.minY + h * 0.11, width: w * 0.16, height: h * 0.09)
        context.fill(Path(ellipseIn: glint), with: .color(.white.opacity(0.65 * alpha)))
        guard !hit else { return }
        // The fret, and under it the note's name once the gem is near enough to read it.
        let ink = Palette.onAccent
        if sc >= Self.nameScale {
            drawLabel(context, labels.fret(fret, in: context), color: ink.opacity(alpha), at: CGPoint(x: center.x, y: center.y - h * 0.12),
                      scale: fretScale)
            drawLabel(context, labels.name(midi, in: context), color: ink.opacity(0.7 * alpha), at: CGPoint(x: center.x, y: center.y + h * 0.29),
                      scale: max(8 / GemLabels.nameSize, sc))
            // The string's number, so the lane reads without its colour.
            drawLabel(context, labels.string(s, in: context), color: ink.opacity(0.62 * alpha),
                      at: CGPoint(x: rect.minX + max(6, w * 0.13), y: rect.minY + max(6, h * 0.2)),
                      scale: max(8 / GemLabels.stringSize, sc))
            if grade == nil {
                let tagPoint = CGPoint(x: rect.maxX - 3 * sc, y: rect.minY + 3 * sc)
                if let mark = place.mark {
                    drawMarkTag(&context, mark, at: tagPoint, scale: sc, shade: shade, alpha: alpha, labels: &labels)
                } else if let finger = place.finger, finger > 0 {
                    drawFingerTag(&context, finger, at: tagPoint, scale: sc, shade: shade, alpha: alpha, labels: &labels)
                }
            }
        } else {
            drawLabel(context, labels.fret(fret, in: context), color: ink.opacity(alpha), at: CGPoint(x: center.x, y: center.y + 0.5 * sc),
                      scale: fretScale)
        }
    }

    /// The finger to fret a note with (1 index … 4 little) on a white tag pinned to the gem's top corner, as the
    /// "Next" row under the stage shows it.
    private func drawFingerTag(_ context: inout GraphicsContext, _ finger: Int, at center: CGPoint, scale sc: CGFloat, shade: Shade, alpha: Double,
                               labels: inout GemLabels) {
        let r = 10.5 * sc
        context.fill(circle(CGPoint(x: center.x, y: center.y + 2 * sc), r), with: .color(.black.opacity(0.35 * alpha)))
        context.fill(circle(center, r), with: .color(Color.white.opacity(0.96 * alpha)))
        context.stroke(circle(center, r), with: .color(shade.tagRim.opacity(alpha)), lineWidth: max(1, 1.6 * sc))
        drawLabel(context, labels.finger(finger, in: context), color: shade.tagInk.opacity(alpha), at: center,
                  scale: max(8 / GemLabels.fingerSize, sc))
    }

    /// A fingerboard's mark on the same white tag: an arrow for a finger reaching low or high in a disc, the position
    /// on a capsule as wide as its words.
    private func drawMarkTag(_ context: inout GraphicsContext, _ mark: String, at corner: CGPoint, scale sc: CGFloat, shade: Shade, alpha: Double,
                             labels: inout GemLabels) {
        let text = labels.mark(mark, in: context)
        let textScale = max(8 / GemLabels.fingerSize, sc)
        let measured = text.measure(in: CGSize(width: 200, height: 40))
        let r = 10.5 * sc
        let width = max(r * 2, measured.width * textScale + 9 * sc)
        // Kept inside the gem's corner however wide the words are.
        let center = CGPoint(x: corner.x - max(0, width / 2 - r), y: corner.y)
        let tag = CGRect(x: center.x - width / 2, y: center.y - r, width: width, height: r * 2)
        let shape = Path(roundedRect: tag, cornerRadius: r)
        context.fill(shape.offsetBy(dx: 0, dy: 2 * sc), with: .color(.black.opacity(0.35 * alpha)))
        context.fill(shape, with: .color(Color.white.opacity(0.96 * alpha)))
        context.stroke(shape, with: .color(shade.tagRim.opacity(alpha)), lineWidth: max(1, 1.6 * sc))
        drawLabel(context, text, color: shade.tagInk.opacity(alpha), at: center, scale: textScale)
    }

    // MARK: Hits

    /// Each hit bursts on the hit line: a beam up its lane, the line lighting up either side (a perfect note lights
    /// all of it), then the burst itself (bigger and white-gold when perfect). Reduce Motion keeps just the target
    /// lighting up.
    private func drawHits(_ context: inout GraphicsContext, _ g: Lanes) {
        guard !calm else { return }
        var light = context
        light.blendMode = .plusLighter
        for i in notes.indices {
            guard let s = notes[i].at?.string, let grade = grades[i], grade != .miss, let time = hitTimes[i] else { continue }
            let age = now - time
            guard age >= 0, age < HitBurst.lifetime else { continue }
            let perfect = grade == .perfect
            let tint = perfect ? Self.perfectGold : Self.color(string: s, of: strings)
            let cx = g.x(s, 0)
            if age < 0.4 {
                let f = 1 - age / 0.4
                let top = 0.45
                let half = g.gap * 0.42
                var beam = Path()
                beam.move(to: CGPoint(x: cx - half, y: g.hitY))
                beam.addLine(to: CGPoint(x: g.x(s, top) - half * g.scale(top), y: g.y(top)))
                beam.addLine(to: CGPoint(x: g.x(s, top) + half * g.scale(top), y: g.y(top)))
                beam.addLine(to: CGPoint(x: cx + half, y: g.hitY))
                beam.closeSubpath()
                light.fill(beam, with: .linearGradient(Gradient(colors: [tint.opacity((perfect ? 0.55 : 0.35) * f), tint.opacity(0)]),
                                                       startPoint: CGPoint(x: 0, y: g.hitY), endPoint: CGPoint(x: 0, y: g.y(top))))
            }
            if perfect, age < 0.28 {
                let f = 1 - age / 0.28
                let from = g.left(0) - 6, to = g.right(0) + 6
                let band = CGRect(x: from, y: g.hitY - 10, width: to - from, height: 20)
                light.fill(Path(roundedRect: band, cornerRadius: 10),
                           with: .linearGradient(Gradient(colors: [tint.opacity(0), tint.opacity(0.4 * f), tint.opacity(0)]),
                                                 startPoint: CGPoint(x: 0, y: band.minY), endPoint: CGPoint(x: 0, y: band.maxY)))
            }
            if perfect { drawLineBurst(&light, g, from: cx, age: age) }
            if age < 0.3 {
                let f = 1 - age / 0.3
                let reach: CGFloat = perfect ? 150 : 100
                let streak = CGRect(x: cx - reach, y: g.hitY - 3, width: reach * 2, height: 6)
                light.fill(Path(roundedRect: streak, cornerRadius: 3),
                           with: .linearGradient(Gradient(colors: [tint.opacity(0), tint.opacity(0.9 * f), tint.opacity(0)]),
                                                 startPoint: CGPoint(x: streak.minX, y: 0), endPoint: CGPoint(x: streak.maxX, y: 0)))
            }
            HitBurst.draw(&light, at: CGPoint(x: cx, y: g.hitY), tint: tint, perfect: perfect, age: age, seed: i, upward: true)
        }
    }

    /// A perfect note's burst along the hit line: a white-gold shock ring opening flat on the board around the
    /// target, and two sparks racing out from it to the ends of the line, each trailing a streak that lights it.
    /// Drawn into an additive context.
    private func drawLineBurst(_ light: inout GraphicsContext, _ g: Lanes, from cx: CGFloat, age: Double) {
        let life = Self.perfectFlash
        guard age >= 0, age < life else { return }
        let p = age / life
        let eased = CGFloat(1 - pow(1 - p, 3))
        let gold = Self.perfectGold
        // The shock ring, lying on the board (flattened by the runway's tilt).
        let radius = 22 + eased * 120
        let ring = CGRect(x: cx - radius, y: g.hitY - radius * 0.28, width: radius * 2, height: radius * 0.56)
        light.stroke(Path(ellipseIn: ring), with: .color(gold.opacity(0.75 * (1 - p))), lineWidth: 1 + 3 * CGFloat(1 - p))
        // Sparks to either end, a touch quicker than the ring.
        let run = min(1, eased * 1.25)
        let ends = [g.left(0) - 6, g.right(0) + 6]
        for end in ends {
            let head = cx + (end - cx) * run
            let fade = 1 - p
            let streak = CGRect(x: min(cx, head), y: g.hitY - 2.5, width: abs(head - cx), height: 5)
            light.fill(Path(roundedRect: streak, cornerRadius: 2.5),
                       with: .linearGradient(Gradient(colors: [gold.opacity(0.15 * fade), gold.opacity(0.85 * fade)]),
                                             startPoint: CGPoint(x: cx, y: 0), endPoint: CGPoint(x: head, y: 0)))
            let glow: CGFloat = 16
            light.fill(circle(CGPoint(x: head, y: g.hitY), glow),
                       with: .radialGradient(Gradient(colors: [Color.white.opacity(0.9 * fade), gold.opacity(0.5 * fade), gold.opacity(0)]),
                                             center: CGPoint(x: head, y: g.hitY), startRadius: 0, endRadius: glow))
        }
    }

    /// Each note's verdict, popping over the hit line where it was judged.
    private func drawPops(_ context: inout GraphicsContext, _ g: Lanes, size: CGSize) {
        let lift = Self.targetRadius(g) + 18
        let bounds = CGRect(x: 8, y: 0, width: size.width - 16, height: size.height)
        for i in notes.indices {
            guard let s = notes[i].at?.string, let grade = grades[i], let time = hitTimes[i] else { continue }
            let age = now - time
            guard age >= 0, age < HighwayPop.lifetime else { continue }
            HighwayPop.draw(&context, grade: grade, offset: offsets[i], lane: Self.color(string: s, of: strings),
                            at: CGPoint(x: g.x(s, 0), y: g.hitY - lift), age: age, bounds: bounds, calm: calm)
        }
    }

    // MARK: Finish

    private func drawVignette(_ context: inout GraphicsContext, size: CGSize) {
        context.fill(Path(CGRect(x: 0, y: 0, width: 36, height: size.height)),
                     with: .linearGradient(Self.vignette, startPoint: .zero, endPoint: CGPoint(x: 36, y: 0)))
        context.fill(Path(CGRect(x: size.width - 36, y: 0, width: 36, height: size.height)),
                     with: .linearGradient(Self.vignette, startPoint: CGPoint(x: size.width, y: 0), endPoint: CGPoint(x: size.width - 36, y: 0)))
    }

    /// The outer lanes named in words under their targets ("Thinnest" and "Thickest": the numbers are in the
    /// rings, so they aren't said twice), each on a dark plate so the strings running under it never cut through
    /// the letters.
    private func drawLabels(_ context: inout GraphicsContext, _ g: Lanes, scale: CGFloat) {
        guard let edges, g.strings >= 2 else { return }
        let plate = Palette.stageDeep.opacity(0.8)
        let points = DiagramType.size(DiagramType.floor, scale: scale)
        let y = g.hitY + Self.targetRadius(g) + 7 + points * 0.6
        func styled(_ word: Text) -> Text { word.font(DiagramType.font(points, weight: .semibold)).foregroundStyle(Palette.inkSoft) }
        // Reading inward from the outer lanes, and always whole on the stage.
        if let word = edges.word(g.leftString) {
            edgeLabel(&context, styled(word), from: g.laneX(0, 0) - 16, leading: true, y: y, width: g.width, plate: plate)
        }
        if let word = edges.word(g.rightString) {
            edgeLabel(&context, styled(word), from: g.laneX(g.strings - 1, 0) + 16, leading: false, y: y, width: g.width, plate: plate)
        }
    }

    /// An edge name on its plate, from `x` (where it starts, or ends when it reads leftward), kept clear of the
    /// stage's sides and rounded corners.
    private func edgeLabel(_ context: inout GraphicsContext, _ text: Text, from x: CGFloat, leading: Bool, y: CGFloat, width: CGFloat, plate: Color) {
        let resolved = context.resolve(text)
        let size = resolved.measure(in: CGSize(width: width / 2, height: 40))
        let inset: CGFloat = 16
        let proposed = leading ? x : x - size.width
        let minX = min(max(proposed, inset), max(inset, width - inset - size.width))
        let rect = CGRect(x: minX - 6, y: y - size.height / 2 - 2, width: size.width + 12, height: size.height + 4)
        context.fill(Path(roundedRect: rect, cornerRadius: rect.height / 2), with: .color(plate))
        context.draw(resolved, at: CGPoint(x: minX, y: y), anchor: .leading)
    }

    private func circle(_ center: CGPoint, _ radius: CGFloat) -> Path {
        Path(ellipseIn: CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2))
    }
}
