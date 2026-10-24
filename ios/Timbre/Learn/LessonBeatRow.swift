import SwiftUI
import TimbreCore

/// How one stroke of a rhythm step went: its grade and how far off it was in seconds (negative early). A miss
/// carries the nearest stroke heard outside the window, if there was one; nil when nothing was heard.
struct BeatCall: Equatable {
    let grade: PlayAlongJudge.Grade
    let offset: Double?
}

/// The rhythm step's beat lane: one bar on a track, the counts under it, each stroke called as the playhead passes.
///
/// On a strummed instrument the lane shows what the strumming hand really does. Every eighth is a slot, counted
/// "1 & 2 & 3 & 4 &": the pattern's strokes are chips with their arrow (down on the beat in the accent, up on the
/// "and" in amber), and the strokes the hand makes without touching the strings are faint ghosts, because the hand
/// never stops: it swings down on every beat and up on every "and" whether it strikes or not. A pick rides the lane
/// as the playhead, tracing that swing as a wave through the strings' line (down through it on a beat, up through it
/// on an "and"), tip first along its path with a fading trail. Before the take it waits raised over beat 1. Down is
/// down the screen everywhere a strum is drawn: here, on the strum stage (`StrumSweep`, always the player's view,
/// thickest string on top) and in the words ("Strum down").
/// Elsewhere (taps, plucks) the strokes are dots and the playhead is a bar.
///
/// Each stroke is called as it passes, mint on the beat, amber when loose, red when missed, and a loose or missed
/// stroke says why under its count ("120 ms late", "Missed"); each one swells as the playhead reaches it.
/// Explanations and quizzes draw the same lane without the calls (`RhythmBar`).
struct LessonBeatRow: View {
    let pattern: [Double]
    var beatsPerBar = 4
    var accent: Color = Palette.mint
    /// 0…1 through the bar, nil when not playing.
    var playhead: Double?
    /// The bar's judged strokes, by index in `pattern`.
    var calls: [Int: BeatCall] = [:]
    /// Strums: down strokes on the beat, up strokes between beats, and the pick riding the lane.
    var arrows = false
    /// Room under the counts for each stroke's call; off where nothing is judged (explanations, quizzes).
    var callRows = true
    /// With no playhead, the pick waits over beat 1 (before Start, counting in); off once the take is done.
    var restingPick = true
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Off-beat strokes put their reasons on a second line, so neighbours' words never collide.
    private var hasOffbeats: Bool { pattern.contains { $0.truncatingRemainder(dividingBy: 1) != 0 } }
    /// The track with its strokes and the counts under it.
    private static let laneHeight: CGFloat = 88
    private static let countsY: CGFloat = 78
    private static let firstCallY: CGFloat = 99
    private static let secondCallY: CGFloat = 115
    private var height: CGFloat { Self.laneHeight + (callRows ? (hasOffbeats ? 36 : 20) : 0) }

    var body: some View {
        Canvas { context, size in draw(&context, size: size) }
            .frame(height: height)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text("Rhythm pattern"))
            .accessibilityValue(spokenCalls)
    }

    // MARK: Geometry

    /// Where the bar runs across the canvas: beat `b` (0 up to the bar's length) at `x(b)`, the strings' line at `mid`.
    private struct Lane {
        let left: CGFloat
        let width: CGFloat
        let meter: Int
        let mid: CGFloat
        var beatWidth: CGFloat { width / CGFloat(meter) }
        func x(_ beat: Double) -> CGFloat { left + width * CGFloat(beat) / CGFloat(meter) }
    }

    /// Where the up stroke falls in each beat: halfway (straight eighths), or the pattern's own "and" when every
    /// off-beat stroke shares one (a swung 0.667).
    private var upFraction: Double {
        var fractions = Set<Int>()
        for hit in pattern {
            let fraction = hit - hit.rounded(.down)
            if fraction > 0.01 { fractions.insert(Int((fraction * 1000).rounded())) }
        }
        guard fractions.count == 1, let only = fractions.first, only > 200, only < 800 else { return 0.5 }
        return Double(only) / 1000
    }

    /// Every beat gets its "and" when the bar is four beats or fewer or the pattern plays between beats; a long bar
    /// of plain beats (6/8 counted in eighths) shows just its beats.
    private var showsAnds: Bool { beatsPerBar <= 4 || hasOffbeats }

    /// The slots a strumming hand passes through, as beats into the bar: down on each beat, up on each "and".
    private func slots(up: Double) -> [(beat: Double, down: Bool)] {
        var out: [(beat: Double, down: Bool)] = []
        for k in 0..<max(1, beatsPerBar) {
            out.append((beat: Double(k), down: true))
            if showsAnds { out.append((beat: Double(k) + up, down: false)) }
        }
        return out
    }

    private func isStruck(_ beat: Double) -> Bool { pattern.contains { abs($0 - beat) < 0.02 } }

    /// The hand's swing reads the pattern only when every stroke sits on a slot (triplets don't: they keep the
    /// plain lane, arrows on the dots).
    private func swings(up: Double) -> Bool {
        guard arrows else { return false }
        let grid = slots(up: up)
        return pattern.allSatisfy { hit in grid.contains { abs($0.beat - hit) < 0.02 } }
    }

    /// The hand's swing at beat `b` (0 on the strings' line, 1 its lowest point, -1 its highest) and its slope per
    /// beat: it crosses the line going down on each beat and going up on each "and" (at `up` into the beat).
    private static func swing(_ b: Double, up: Double) -> (y: Double, slope: Double) {
        let phase = b - b.rounded(.down)
        if phase < up {
            let a = Double.pi * phase / up
            return (sin(a), cos(a) * .pi / up)
        }
        let a = Double.pi * (phase - up) / (1 - up)
        return (-sin(a), -cos(a) * .pi / (1 - up))
    }

    // MARK: Drawing

    private func draw(_ context: inout GraphicsContext, size: CGSize) {
        let meter = max(1, beatsPerBar)
        // Inset by the largest stroke with its strike glow (25) at the start, a little less past the bar's end.
        let lane = Lane(left: 30, width: max(1, size.width - 50), meter: meter, mid: 38)
        let up = upFraction
        let swinging = swings(up: up)
        // The wave's height: past a stroke's chip, less where the slots crowd together.
        let amplitude = min(16, lane.beatWidth * 0.36)
        drawTrack(&context, lane)
        drawCounts(&context, lane, up: up, ands: swinging && showsAnds)
        if swinging {
            drawWave(&context, lane, up: up, amplitude: amplitude)
            for slot in slots(up: up) where !isStruck(slot.beat) {
                drawGhost(&context, at: CGPoint(x: lane.x(slot.beat), y: lane.mid), down: slot.down)
            }
            // Over the ghosts (the hand passes through air there), under the strokes (it strikes them).
            drawPickPass(&context, lane, up: up, amplitude: amplitude)
        }
        drawStrokes(&context, lane, size: size)
        if !swinging, let playhead {
            let x = lane.x(playhead * Double(meter))
            context.fill(Path(roundedRect: CGRect(x: x - 1.5, y: lane.mid - 22, width: 3, height: 44), cornerRadius: 1.5), with: .color(Palette.ink))
        }
    }

    /// A soft track for the bar, the strings' line along it and a tick on every beat.
    private func drawTrack(_ context: inout GraphicsContext, _ lane: Lane) {
        let track = Path(roundedRect: CGRect(x: lane.left - 22, y: lane.mid - 26, width: lane.width + 36, height: 52), cornerRadius: 26)
        context.fill(track, with: .color(.white.opacity(0.035)))
        context.stroke(track, with: .color(.white.opacity(0.07)), lineWidth: 1)
        context.fill(Path(roundedRect: CGRect(x: lane.left - 8, y: lane.mid - 1, width: lane.width + 14, height: 2), cornerRadius: 1), with: .color(Palette.line))
        for beat in 0..<lane.meter {
            let x = lane.x(Double(beat))
            context.fill(Path(CGRect(x: x - 0.5, y: lane.mid - 16, width: 1, height: 32)), with: .color(Palette.inkFaint.opacity(0.35)))
        }
    }

    /// The counts under the lane: each beat's number, and its "&" where the hand swings up.
    private func drawCounts(_ context: inout GraphicsContext, _ lane: Lane, up: Double, ands: Bool) {
        for beat in 0..<lane.meter {
            context.draw(Text("\(beat + 1)").font(Typeface.label(13)).foregroundStyle(Palette.inkSoft), at: CGPoint(x: lane.x(Double(beat)), y: Self.countsY))
            if ands {
                context.draw(Text(verbatim: "&").font(Typeface.label(12)).foregroundStyle(Palette.inkFaint),
                             at: CGPoint(x: lane.x(Double(beat) + up), y: Self.countsY))
            }
        }
    }

    /// The hand's path through the bar, faint: down through the line on every beat, up through it on every "and".
    private func drawWave(_ context: inout GraphicsContext, _ lane: Lane, up: Double, amplitude: CGFloat) {
        let path = wavePath(lane, from: 0, to: Double(lane.meter), up: up, amplitude: amplitude)
        context.stroke(path, with: .color(.white.opacity(0.1)), style: StrokeStyle(lineWidth: 1.5, lineCap: .round, dash: [2, 4]))
    }

    private func wavePath(_ lane: Lane, from: Double, to: Double, up: Double, amplitude: CGFloat) -> Path {
        var path = Path()
        let steps = max(2, Int(((to - from) * 28).rounded(.up)))
        for i in 0...steps {
            let b = from + (to - from) * Double(i) / Double(steps)
            let point = CGPoint(x: lane.x(b), y: lane.mid + amplitude * CGFloat(Self.swing(b, up: up).y))
            if i == 0 { path.move(to: point) } else { path.addLine(to: point) }
        }
        return path
    }

    /// The pick riding the lane as the playhead, on the hand's wave, tip first along its path with a fading trail
    /// behind it. With no playhead it waits raised over beat 1, ready to come down.
    private func drawPickPass(_ context: inout GraphicsContext, _ lane: Lane, up: Double, amplitude: CGFloat) {
        guard let playhead else {
            if restingPick { drawPick(&context, at: CGPoint(x: lane.x(0) - 4, y: lane.mid - amplitude - 3), angle: .pi * 0.38) }
            return
        }
        let b = min(Double(lane.meter), max(0, playhead * Double(lane.meter)))
        let wave = Self.swing(b, up: up)
        let point = CGPoint(x: lane.x(b), y: lane.mid + amplitude * CGFloat(wave.y))
        if !reduceMotion && b > 0.02 {
            let from = max(0, b - 0.6)
            let trail = wavePath(lane, from: from, to: b, up: up, amplitude: amplitude)
            let shade = Gradient(colors: [accent.opacity(0), accent.opacity(0.8)])
            context.stroke(trail, with: .linearGradient(shade, startPoint: CGPoint(x: lane.x(from), y: lane.mid), endPoint: point),
                           style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
        }
        let angle = atan2(Double(amplitude) * wave.slope, Double(lane.beatWidth))
        drawPick(&context, at: point, angle: CGFloat(angle))
    }

    /// A pick, its tip along `angle` (radians from pointing right, clockwise on screen): bone white with a rim and a
    /// glow in the accent, so it reads over the lane and the chips.
    private func drawPick(_ context: inout GraphicsContext, at center: CGPoint, angle: CGFloat) {
        let h: CGFloat = 22, w: CGFloat = 19
        var shape = Path()
        shape.move(to: CGPoint(x: h / 2, y: 0))
        shape.addQuadCurve(to: CGPoint(x: -h * 0.3, y: -w / 2), control: CGPoint(x: h * 0.12, y: -w * 0.5))
        shape.addQuadCurve(to: CGPoint(x: -h * 0.3, y: w / 2), control: CGPoint(x: -h * 0.8, y: 0))
        shape.addQuadCurve(to: CGPoint(x: h / 2, y: 0), control: CGPoint(x: h * 0.12, y: w * 0.5))
        shape.closeSubpath()
        let placed = shape.applying(CGAffineTransform(rotationAngle: angle).concatenating(CGAffineTransform(translationX: center.x, y: center.y)))
        let halo: CGFloat = 18
        context.fill(circle(center, halo), with: .radialGradient(Gradient(colors: [accent.opacity(0.4), .clear]), center: center, startRadius: 0, endRadius: halo))
        context.fill(placed.offsetBy(dx: 0, dy: 1.5), with: .color(.black.opacity(0.35)))
        let bounds = placed.boundingRect
        context.fill(placed, with: .linearGradient(Gradient(colors: [Palette.ink, Color(hex: 0xCFC7B8)]),
                                                   startPoint: CGPoint(x: bounds.midX, y: bounds.minY), endPoint: CGPoint(x: bounds.midX, y: bounds.maxY)))
        context.stroke(placed, with: .color(accent.opacity(0.7)), lineWidth: 1.2)
    }

    /// A stroke the hand makes without touching the strings: a faint dashed ring with its arrow.
    private func drawGhost(_ context: inout GraphicsContext, at center: CGPoint, down: Bool) {
        let r: CGFloat = down ? 8 : 7
        let ring = circle(center, r)
        context.fill(ring, with: .color(Palette.stage.opacity(0.85)))
        context.stroke(ring, with: .color(Palette.inkFaint.opacity(0.5)), style: StrokeStyle(lineWidth: 1.2, dash: [2.2, 2]))
        let arrow = Text(Image(systemName: down ? "arrow.down" : "arrow.up")).font(.system(size: r * 1.05, weight: .bold))
            .foregroundStyle(Palette.inkFaint.opacity(0.8))
        context.draw(arrow, at: center)
    }

    /// The pattern's strokes: a chip each (with its arrow on a strummed instrument), swelling as the playhead
    /// reaches it, and the call under its count once judged.
    private func drawStrokes(_ context: inout GraphicsContext, _ lane: Lane, size: CGSize) {
        for (i, hit) in pattern.enumerated() {
            let center = CGPoint(x: lane.x(hit), y: lane.mid)
            let onBeat = hit.truncatingRemainder(dividingBy: 1) == 0
            let call = calls[i]
            let color = tint(call, onBeat: onBeat)
            // Each stroke swells and sends out a ring as the playhead reaches it, in time with the pick.
            let strike = reduceMotion ? 0 : BeatStrike.amount(playhead: playhead, at: hit / Double(lane.meter))
            let r: CGFloat = (onBeat ? 11 : 9) * (1 + 0.22 * CGFloat(strike))
            BeatStrike.draw(&context, at: center, radius: r, color: color, strike: strike)
            context.fill(circle(center, r + 4), with: .color(color.opacity(call == nil ? 0.18 : 0.3)))
            context.fill(circle(center, r), with: .color(color))
            if arrows {
                let arrow = Text(Image(systemName: onBeat ? "arrow.down" : "arrow.up")).font(.system(size: r * 1.15, weight: .black)).foregroundStyle(Palette.onAccent)
                context.draw(arrow, at: center)
            }
            if callRows, let call, let words = reason(call) {
                // Under the counts; kept inside the row at the ends.
                let y = onBeat || !hasOffbeats ? Self.firstCallY : Self.secondCallY
                let labelX = min(max(center.x, 40), size.width - 40)
                context.draw(words.font(Typeface.label(11)).foregroundStyle(color), at: CGPoint(x: labelX, y: y))
            }
        }
    }

    private func circle(_ center: CGPoint, _ radius: CGFloat) -> Path {
        Path(ellipseIn: CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2))
    }

    // MARK: Calls

    /// Upcoming strokes as in the explanations (down strokes mint, up strokes amber); called ones by their grade.
    private func tint(_ call: BeatCall?, onBeat: Bool) -> Color {
        guard let grade = call?.grade else { return onBeat ? accent : Palette.amber }
        switch grade {
        case .perfect, .good: return accent
        case .ok: return Palette.amber
        case .miss: return Palette.danger
        }
    }

    /// Why a stroke was loose or missed, nil for a clean one.
    private func reason(_ call: BeatCall) -> Text? {
        switch call.grade {
        case .perfect, .good:
            return nil
        case .ok, .miss:
            guard let offset = call.offset else { return call.grade == .miss ? Text("Missed") : nil }
            let ms = Self.milliseconds(offset)
            return offset < 0 ? Text("\(ms) ms early") : Text("\(ms) ms late")
        }
    }

    /// To the nearest 10 ms: closer than that is noise in the reading.
    private static func milliseconds(_ offset: Double) -> Int { Int((abs(offset) * 100).rounded()) * 10 }

    /// For VoiceOver: each called stroke of the bar, in order.
    private var spokenCalls: String {
        pattern.indices.compactMap { i -> String? in
            guard let call = calls[i] else { return nil }
            switch call.grade {
            case .perfect: return String(localized: "Perfect")
            case .good: return String(localized: "Good")
            case .ok, .miss:
                guard let offset = call.offset else { return call.grade == .miss ? String(localized: "Missed") : String(localized: "Good") }
                let ms = Self.milliseconds(offset)
                return offset < 0 ? String(localized: "\(ms) ms early") : String(localized: "\(ms) ms late")
            }
        }
        .joined(separator: ", ")
    }
}
