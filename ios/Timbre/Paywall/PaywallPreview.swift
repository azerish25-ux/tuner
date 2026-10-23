import SwiftUI
import TimbreCore

/// The paywall's live preview: a mini play-along runway in the string colours, gems gliding down to the hit
/// line and bursting there while the combo climbs, beside the learner's own instrument (or course emblem).
/// Drawn, not filmed: one Canvas on the display clock. With Reduce Motion it holds a single frame mid-song.
struct PaywallPreview: View {
    let artwork: CourseArtwork
    let accent: Color
    /// The instrument's strings (pairs count once): one lane each.
    let lanes: Int
    let height: CGFloat
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// The instrument (or emblem) on the left; the runway keeps this much free on both sides.
    private var artSize: CGFloat { min(height * 0.92, 88) }

    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 60, paused: reduceMotion)) { timeline in
            let time = reduceMotion ? PreviewRunway.still : timeline.date.timeIntervalSinceReferenceDate
            ZStack(alignment: .bottomLeading) {
                Canvas { context, size in
                    PreviewRunway(lanes: max(1, lanes), accent: accent, side: artSize + 6, time: time).draw(&context, size: size)
                }
                art(time)
            }
        }
        .frame(height: height)
        .frame(maxWidth: .infinity)
        .accessibilityHidden(true)
    }

    /// Leaning in the light and swaying a little, as on the plan screen.
    private func art(_ time: Double) -> some View {
        let sway = reduceMotion ? 0 : sin(time * 0.9)
        return CourseHeroArt(artwork: artwork, accent: accent, size: artSize, lean: -12 + sway * 2)
            .offset(x: -2, y: CGFloat(sway) * 3 - 4)
    }
}

/// The preview's tune and its drawing. `d` is how far a note still has to travel, in lookaheads: 1 at the
/// horizon, 0 on the hit line. Every note is hit: a demo plays clean.
private struct PreviewRunway {
    let lanes: Int
    let accent: Color
    /// Room kept free on each side: the instrument on the left, the combo on the right.
    let side: CGFloat
    let time: Double

    struct Note {
        let beat: Double
        /// Across the strings, 0 lowest (left) to 1 highest (right).
        let place: Double
        let length: Double
    }

    static let secondsPerBeat = 0.4
    static let beatsPerLoop = 16.0
    static let lookahead = 2.0
    static let burst = 0.5
    /// The combo builds over two loops, then the tune starts over.
    static let loopsPerRound = 2.0

    /// A little riff: single notes, two chords (beats 4 and 12) and two held notes.
    static let tune: [Note] = [
        Note(beat: 0, place: 0, length: 1), Note(beat: 1, place: 0.4, length: 0.5), Note(beat: 1.5, place: 0.6, length: 0.5),
        Note(beat: 2, place: 1, length: 1), Note(beat: 3, place: 0.6, length: 1),
        Note(beat: 4, place: 0.2, length: 1.5), Note(beat: 4, place: 0.8, length: 1.5),
        Note(beat: 6, place: 0.4, length: 0.5), Note(beat: 6.5, place: 0.6, length: 0.5), Note(beat: 7, place: 1, length: 0.5),
        Note(beat: 7.5, place: 0.8, length: 0.5), Note(beat: 8, place: 0, length: 2),
        Note(beat: 10, place: 0.4, length: 1), Note(beat: 11, place: 0.8, length: 1),
        Note(beat: 12, place: 0.2, length: 1.5), Note(beat: 12, place: 0.6, length: 1.5),
        Note(beat: 14, place: 1, length: 0.5), Note(beat: 14.5, place: 0.6, length: 0.5), Note(beat: 15, place: 0.4, length: 1),
    ]

    /// Reduce Motion's frame: just after the chord on beat 4 of the second loop, both bursts in the air.
    static var still: Double { (beatsPerLoop + 4.15) * secondsPerBeat }

    /// Lowest string warm, highest cool, as on the play-along runway.
    static func color(lane: Int, of lanes: Int) -> Color {
        let palette: [Color] = [Palette.coral, Palette.amber, Color(hex: 0xFFE066), Palette.mint, Palette.sky, Palette.violet]
        let index = lanes <= 1 ? 2 : Int((Double(lane) / Double(lanes - 1) * Double(palette.count - 1)).rounded())
        return palette[min(palette.count - 1, max(0, index))]
    }

    private func lane(_ note: Note) -> Int { Int((note.place * Double(lanes - 1)).rounded()) }

    private struct Gem { let lane: Int; let d: Double }
    private struct Burst { let lane: Int; let age: Double; let chord: Bool }
    private struct Tail { let lane: Int; let from: Double; let to: Double }

    func draw(_ context: inout GraphicsContext, size: CGSize) {
        let hitY = size.height - 30
        let road = Road(size: size, lanes: lanes, hitY: hitY, horizonY: 4, width: min(300, max(110, size.width - 2 * side)))
        let (gems, bursts, tails) = notesInView()
        drawRoad(context, road)
        for tail in tails { drawTail(context, road, tail) }
        drawTargets(context, road, bursts)
        for gem in gems.sorted(by: { $0.d > $1.d }) { drawGem(context, road, gem) }
        for burst in bursts { drawBurst(context, road, burst) }
        if let perfect = bursts.filter(\.chord).map(\.age).min() { drawPerfect(context, road, age: perfect) }
        if side >= 64 { drawCombo(context, size: size, pulse: bursts.map(\.age).min()) }
    }

    /// Notes from the loop before to the loop after: on their way, bursting, or holding a tail on the line.
    private func notesInView() -> ([Gem], [Burst], [Tail]) {
        let spb = Self.secondsPerBeat
        let loop = Self.beatsPerLoop * spb
        let current = Int((time / loop).rounded(.down))
        var gems: [Gem] = [], bursts: [Burst] = [], tails: [Tail] = []
        for index in (current - 1)...(current + 1) {
            let start = Double(index) * loop
            for note in Self.tune {
                let at = start + note.beat * spb
                let d = (at - time) / Self.lookahead
                let end = (at + note.length * spb - time) / Self.lookahead
                guard d < 1.05 else { continue }
                if d >= 0 {
                    gems.append(Gem(lane: lane(note), d: d))
                } else if time - at < Self.burst {
                    let chord = Self.tune.filter { $0.beat == note.beat }.count > 1
                    bursts.append(Burst(lane: lane(note), age: time - at, chord: chord))
                }
                if note.length >= 0.9, end > 0 { tails.append(Tail(lane: lane(note), from: max(0, d), to: min(1, end))) }
            }
        }
        return (gems, bursts, tails)
    }

    private func drawRoad(_ context: GraphicsContext, _ road: Road) {
        let size = road.size
        // The accent's glow pooling on the hit line.
        let glow = CGRect(x: road.center - road.width * 0.7, y: road.hitY - 40, width: road.width * 1.4, height: 80)
        context.fill(Path(ellipseIn: glow), with: .radialGradient(Gradient(colors: [accent.opacity(0.22), accent.opacity(0)]),
                                                                center: CGPoint(x: road.center, y: road.hitY), startRadius: 0, endRadius: road.width * 0.7))
        var floor = Path()
        floor.move(to: CGPoint(x: road.edge(-1, 1), y: road.horizonY))
        floor.addLine(to: CGPoint(x: road.edge(1, 1), y: road.horizonY))
        floor.addLine(to: CGPoint(x: road.edge(1, road.floorDepth), y: size.height))
        floor.addLine(to: CGPoint(x: road.edge(-1, road.floorDepth), y: size.height))
        floor.closeSubpath()
        let ground = Gradient(colors: [Color(hex: 0x1C1F26).opacity(0), Color(hex: 0x1C1F26).opacity(0.85)])
        context.fill(floor, with: .linearGradient(ground, startPoint: CGPoint(x: 0, y: road.horizonY), endPoint: CGPoint(x: 0, y: size.height)))
        // Beat rungs rolling toward you, the bar line brighter.
        let spb = Self.secondsPerBeat
        let firstBeat = Int((time / spb).rounded(.down))
        for beat in firstBeat...(firstBeat + Int(Self.lookahead / spb) + 1) {
            let d = (Double(beat) * spb - time) / Self.lookahead
            guard d > 0, d < 1 else { continue }
            let depth = road.depth(d)
            var rung = Path()
            rung.move(to: CGPoint(x: road.edge(-1, depth), y: road.y(depth)))
            rung.addLine(to: CGPoint(x: road.edge(1, depth), y: road.y(depth)))
            context.stroke(rung, with: .color(.white.opacity(beat % 4 == 0 ? 0.13 : 0.05)), lineWidth: 1)
        }
        // String lanes.
        for lane in 0..<lanes {
            var line = Path()
            line.move(to: CGPoint(x: road.x(lane, 1), y: road.horizonY))
            line.addLine(to: CGPoint(x: road.x(lane, road.floorDepth), y: size.height))
            let tint = Self.color(lane: lane, of: lanes)
            context.stroke(line, with: .linearGradient(Gradient(colors: [tint.opacity(0.04), tint.opacity(0.42)]),
                                                       startPoint: CGPoint(x: 0, y: road.horizonY), endPoint: CGPoint(x: 0, y: road.hitY)), lineWidth: 1.2)
        }
    }

    /// The hit line and a target ring per string; a ring lights up as its note lands, the line flashes.
    private func drawTargets(_ context: GraphicsContext, _ road: Road, _ bursts: [Burst]) {
        let flash = bursts.map { max(0, 1 - $0.age / 0.3) }.max() ?? 0
        let bar = CGRect(x: road.edge(-1, 0) - 6, y: road.hitY - 1.5, width: road.width + 12, height: 3)
        context.drawLayer { layer in
            layer.addFilter(.blur(radius: 5))
            layer.fill(Path(roundedRect: bar.insetBy(dx: 0, dy: -2), cornerRadius: 3), with: .color(accent.opacity(0.35 + 0.45 * flash)))
        }
        context.fill(Path(roundedRect: bar, cornerRadius: 1.5), with: .color(.white.opacity(0.22 + 0.4 * flash)))
        let radius = min(road.gap * 0.3, 11)
        for lane in 0..<lanes {
            let tint = Self.color(lane: lane, of: lanes)
            let lit = bursts.contains { $0.lane == lane && $0.age < 0.18 }
            let r = lit ? radius * 1.2 : radius
            let ring = CGRect(x: road.x(lane, 0) - r, y: road.hitY - r, width: r * 2, height: r * 2)
            context.fill(Path(ellipseIn: ring), with: .color(tint.opacity(lit ? 0.5 : 0.1)))
            context.stroke(Path(ellipseIn: ring), with: .color(tint.opacity(0.85)), lineWidth: 1.5)
        }
    }

    private func drawTail(_ context: GraphicsContext, _ road: Road, _ tail: Tail) {
        guard tail.to > tail.from else { return }
        let a = road.depth(tail.from), b = road.depth(tail.to)
        let wa = 2.6 * road.scale(a), wb = 2.6 * road.scale(b)
        var path = Path()
        path.move(to: CGPoint(x: road.x(tail.lane, a) - wa, y: road.y(a)))
        path.addLine(to: CGPoint(x: road.x(tail.lane, b) - wb, y: road.y(b)))
        path.addLine(to: CGPoint(x: road.x(tail.lane, b) + wb, y: road.y(b)))
        path.addLine(to: CGPoint(x: road.x(tail.lane, a) + wa, y: road.y(a)))
        path.closeSubpath()
        context.fill(path, with: .color(Self.color(lane: tail.lane, of: lanes).opacity(0.45)))
    }

    /// A glossy gem, growing as it nears; it fades in at the horizon.
    private func drawGem(_ context: GraphicsContext, _ road: Road, _ gem: Gem) {
        let depth = road.depth(gem.d), scale = road.scale(depth)
        let width = road.gap * 0.72 * scale, height = max(4, min(road.gap * 0.42, 14) * scale)
        let rect = CGRect(x: road.x(gem.lane, depth) - width / 2, y: road.y(depth) - height / 2, width: width, height: height)
        let alpha = gem.d > 0.8 ? max(0, (1.05 - gem.d) / 0.25) : 1
        let tint = Self.color(lane: gem.lane, of: lanes)
        let shape = Path(roundedRect: rect, cornerRadius: height * 0.4)
        let shine = Gradient(colors: [tint.mix(with: .white, by: 0.35).opacity(alpha), tint.opacity(alpha)])
        context.fill(shape, with: .linearGradient(shine, startPoint: CGPoint(x: rect.midX, y: rect.minY), endPoint: CGPoint(x: rect.midX, y: rect.maxY)))
        context.stroke(shape, with: .color(.white.opacity(0.35 * alpha)), lineWidth: 0.8)
    }

    /// A ring and sparks flying off the target, in the string's colour.
    private func drawBurst(_ context: GraphicsContext, _ road: Road, _ burst: Burst) {
        let progress = burst.age / Self.burst
        let fade = 1 - progress
        let tint = Self.color(lane: burst.lane, of: lanes)
        let center = CGPoint(x: road.x(burst.lane, 0), y: road.hitY)
        let base = min(road.gap * 0.3, 11)
        let flash = base * 1.4
        context.fill(Path(ellipseIn: CGRect(x: center.x - flash, y: center.y - flash, width: flash * 2, height: flash * 2)),
                     with: .color(tint.opacity(0.45 * fade * fade)))
        let r = base + CGFloat(progress) * road.gap * 0.9
        context.stroke(Path(ellipseIn: CGRect(x: center.x - r, y: center.y - r, width: r * 2, height: r * 2)),
                       with: .color(tint.opacity(fade)), lineWidth: 0.6 + 1.6 * fade)
        for spark in 0..<6 {
            let angle = (Double(spark) * 60 + Double(burst.lane) * 17) * .pi / 180
            let inner = base + CGFloat(progress) * road.gap * 0.5, outer = inner + 3 + CGFloat(fade) * 4
            var path = Path()
            path.move(to: CGPoint(x: center.x + inner * CGFloat(cos(angle)), y: center.y + inner * CGFloat(sin(angle))))
            path.addLine(to: CGPoint(x: center.x + outer * CGFloat(cos(angle)), y: center.y + outer * CGFloat(sin(angle))))
            context.stroke(path, with: .color(tint.mix(with: .white, by: 0.4).opacity(fade)), style: StrokeStyle(lineWidth: 1.4, lineCap: .round))
        }
    }

    /// "Perfect" rising off the line after a chord.
    private func drawPerfect(_ context: GraphicsContext, _ road: Road, age: Double) {
        let fade = max(0, 1 - age / Self.burst)
        let y = road.hitY - min(road.gap * 0.3, 11) - 10 - CGFloat(age) * 18
        context.drawLayer { layer in
            layer.opacity = fade
            layer.addFilter(.shadow(color: accent.opacity(0.9), radius: 6))
            layer.draw(Text("Perfect").font(.system(size: 12, weight: .heavy, design: .rounded)).foregroundStyle(Palette.ink),
                       at: CGPoint(x: road.center, y: y))
        }
    }

    /// The combo multiplier at the right with four pips filling toward the next step; it pulses on each hit.
    private func drawCombo(_ context: GraphicsContext, size: CGSize, pulse: Double?) {
        let spb = Self.secondsPerBeat
        let loop = Self.beatsPerLoop * spb
        let round = loop * Self.loopsPerRound
        let elapsed = time - (time / round).rounded(.down) * round
        var hits = 0
        for index in 0..<Int(Self.loopsPerRound) {
            hits += Self.tune.filter { Double(index) * loop + $0.beat * spb <= elapsed }.count
        }
        let multiplier = min(4, 1 + hits / 4)
        let filled = multiplier == 4 ? 4 : hits % 4
        let x = size.width - side / 2, y = size.height - 24
        let swell = 1 + 0.18 * max(0, 1 - (pulse ?? 1) / 0.15)
        context.draw(Text("Combo ×\(multiplier)").font(.system(size: 11 * swell, weight: .heavy, design: .rounded)).foregroundStyle(Palette.amber),
                     at: CGPoint(x: x, y: y))
        for pip in 0..<4 {
            let rect = CGRect(x: x - 23 + CGFloat(pip) * 12, y: y + 10, width: 10, height: 3)
            context.fill(Path(roundedRect: rect, cornerRadius: 1.5), with: .color(pip < filled ? Palette.amber : Color.white.opacity(0.14)))
        }
    }
}

/// The runway in perspective. Depth runs 1 at the horizon to 0 on the hit line (negative below it); lanes
/// are straight lines that converge toward the horizon.
private struct Road {
    let size: CGSize
    let lanes: Int
    let hitY: CGFloat
    let horizonY: CGFloat
    /// Width on the hit line.
    let width: CGFloat

    var span: CGFloat { max(1, hitY - horizonY) }
    var gap: CGFloat { width / CGFloat(max(1, lanes)) }
    var center: CGFloat { size.width / 2 }
    /// The bottom edge, below the hit line.
    var floorDepth: CGFloat { (hitY - size.height) / span }

    /// Notes speed up as they come closer.
    func depth(_ d: Double) -> CGFloat { CGFloat(d / (abs(d) + 0.55) * 1.55) }
    func y(_ depth: CGFloat) -> CGFloat { hitY - span * depth }
    func scale(_ depth: CGFloat) -> CGFloat { 1 - 0.68 * depth }
    func x(_ lane: Int, _ depth: CGFloat) -> CGFloat {
        center + (CGFloat(lane) - CGFloat(lanes - 1) / 2) * gap * scale(depth)
    }
    /// The runway's left (-1) or right (1) edge.
    func edge(_ side: CGFloat, _ depth: CGFloat) -> CGFloat { center + side * width / 2 * scale(depth) }
}
