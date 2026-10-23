import AVFoundation
import SwiftUI
import TimbreCore

// MARK: - Microphone and practice mode

/// Whether a lesson can hear the instrument at all. Without it (permission refused, or the microphone
/// failed to start), an instrument's rhythm steps fall back to tapping the screen: practice mode.
enum LessonMicrophone {
    @MainActor static func unavailable(_ audio: AudioService) -> Bool {
        #if DEBUG
        // Screenshot and UI-test runs feed a demo pitch instead of the microphone.
        if ProcessInfo.processInfo.environment["TIMBRE_DEMO_PITCH"] == "1" { return false }
        #endif
        return audio.permissionDenied || AVAudioApplication.shared.recordPermission == .denied
    }

    /// The microphone may be used without asking: steps that only listen as a bonus (a chord played back
    /// after a demonstration) never raise the permission prompt.
    @MainActor static var granted: Bool {
        #if DEBUG
        if ProcessInfo.processInfo.environment["TIMBRE_DEMO_PITCH"] == "1" { return true }
        #endif
        return AVAudioApplication.shared.recordPermission == .granted
    }
}

/// Marks a rhythm passed by tapping the screen because the microphone couldn't hear the instrument.
struct PracticeModeTag: View {
    var body: some View {
        Label("Practice mode", systemImage: "hand.tap.fill")
            .font(Typeface.label(12))
            .foregroundStyle(Palette.amber)
            .lineLimit(1)
            .padding(.horizontal, 10).padding(.vertical, 5)
            .background(Capsule().fill(Palette.amber.opacity(0.14)))
            .overlay(Capsule().strokeBorder(Palette.amber.opacity(0.35), lineWidth: 1))
            .accessibilityElement(children: .combine)
    }
}

/// A score's colour by grade: 90 % and up mint, 70 % and up gold, lower coral.
enum ScoreTint {
    static func color(_ score: Double) -> Color {
        let percent = (score * 100).rounded()
        if percent >= 90 { return Palette.mint }
        return percent >= 70 ? Palette.amber : Palette.coral
    }
}

// MARK: - Strum sweep

/// A pick sweeping the strings on every stroke of a rhythm pattern, in time with the beat: down strokes
/// run from the thickest string (top, named "Thickest") to the thinnest, up strokes back, and each string shimmers as the
/// pick crosses it. `.pluck` plucks the lowest string on each hit; `.tap` pulses a pad for courses
/// without an instrument. With no time (Reduce Motion) it holds still, showing the first stroke.
struct StrumSweep: View {
    enum Style { case strum, pluck, tap }

    let pattern: [Double]
    var beatsPerBar = 4
    var strings = 6
    var style: Style = .strum
    var accent: Color = Palette.mint
    let secondsPerBeat: Double
    /// Seconds since the first beat (negative while counting in); nil draws it at rest.
    let time: Double?
    /// Bars the strokes run for; nil repeats the bar forever.
    var bars: Int?
    /// Names the top and bottom strings in words ("Thickest (6)" over the top, "Thinnest (1)" under the bottom).
    var edges: StringEdges?

    private struct Stroke {
        let time: Double
        let down: Bool
    }

    private struct PickState {
        /// 0 above the thickest string, 1 below the thinnest.
        var position: Double
        var touching: Bool
        var down: Bool
        /// 0…1: how far the pick is lifted off the strings on its way back.
        var lift: Double
    }

    var body: some View {
        Canvas { context, size in
            if style == .tap { drawPad(&context, size: size) } else { drawStrings(&context, size: size) }
        }
        .accessibilityHidden(true)
    }

    private var barSeconds: Double { Double(max(1, beatsPerBar)) * secondsPerBeat }
    /// How long a stroke takes to cross the strings; the pick passes the middle string on the beat.
    private var sweepSeconds: Double { min(0.22, max(0.08, secondsPerBeat * 0.42)) }

    /// Strokes from the bar before to the bar after `t`, in time order.
    private func strokes(near t: Double) -> [Stroke] {
        guard barSeconds > 0 else { return [] }
        let current = Int((t / barSeconds).rounded(.down))
        var out: [Stroke] = []
        for bar in (current - 1)...(current + 1) {
            if let bars, bar < 0 || bar >= bars { continue }
            let start = Double(bar) * barSeconds
            for hit in pattern {
                out.append(Stroke(time: start + hit * secondsPerBeat, down: hit.truncatingRemainder(dividingBy: 1) == 0))
            }
        }
        return out.sorted { $0.time < $1.time }
    }

    private func pick(at t: Double, _ strokes: [Stroke]) -> PickState {
        let half = sweepSeconds / 2
        if let stroke = strokes.first(where: { abs(t - $0.time) <= half }) {
            let f = (t - (stroke.time - half)) / sweepSeconds
            return PickState(position: stroke.down ? f : 1 - f, touching: true, down: stroke.down, lift: 0)
        }
        let previous = strokes.last { $0.time + half < t }
        let next = strokes.first { $0.time - half > t }
        if let previous, let next {
            let from = previous.time + half, to = next.time - half
            let u = to > from ? min(1, max(0, (t - from) / (to - from))) : 1
            let eased = u * u * (3 - 2 * u)
            let a: Double = previous.down ? 1 : 0
            let b: Double = next.down ? 0 : 1
            return PickState(position: a + (b - a) * eased, touching: false, down: next.down, lift: a == b ? 0 : sin(.pi * u))
        }
        if let previous { return PickState(position: previous.down ? 1 : 0, touching: false, down: previous.down, lift: 0) }
        if let next { return PickState(position: next.down ? 0 : 1, touching: false, down: next.down, lift: 0) }
        return PickState(position: 0, touching: false, down: true, lift: 0)
    }

    /// When the pick (or the plucking finger) last set string `index` ringing, at or before `t`.
    private func lastExcitation(of index: Int, share: Double, at t: Double, _ strokes: [Stroke]) -> Double? {
        var latest: Double?
        for stroke in strokes {
            let time: Double
            if style == .pluck {
                guard index == 0 else { return nil }
                time = stroke.time
            } else {
                let start = stroke.time - sweepSeconds / 2
                time = start + (stroke.down ? share : 1 - share) * sweepSeconds
            }
            if time <= t { latest = time }
        }
        return latest
    }

    // MARK: Strings and pick

    private func drawStrings(_ context: inout GraphicsContext, size: CGSize) {
        let count = max(1, strings)
        let band = min(size.height * 0.6, CGFloat(count) * (count <= 4 ? 36 : 30))
        let gap = count > 1 ? band / CGFloat(count - 1) : 0
        let top = (size.height - band) / 2
        let reach = max(8, min(26, top - 6))
        let above = top - reach, below = top + band + reach
        let pickX = size.width * 0.62
        let moving = time != nil
        let t = time ?? 0
        let nearby = moving ? strokes(near: t) : []
        let state = moving ? pick(at: t, nearby) : PickState(position: 0, touching: false, down: pattern.first.map { $0.truncatingRemainder(dividingBy: 1) == 0 } ?? true, lift: 0)

        if style == .strum {
            let radius = min(band * 0.5 + 20, size.width * 0.26, size.height / 2 - 8)
            drawSoundHole(&context, center: CGPoint(x: max(radius + 10, size.width * 0.3), y: size.height / 2), radius: max(10, radius))
        }
        drawFlash(&context, size: size, t: t, nearby: nearby, moving: moving)

        for index in 0..<count {
            let y = top + CGFloat(index) * gap
            let share = Double((y - above) / max(1, below - above))
            let crossed = moving ? lastExcitation(of: index, share: share, at: t, nearby) : nil
            let amplitude = crossed.map { CGFloat(5 * exp(-(t - $0) * 4.5)) } ?? 0
            drawString(&context, index: index, of: count, y: y, width: size.width, amplitude: amplitude, t: t)
        }
        drawEdgeNames(&context, size: size, top: top, bottom: top + band, count: count)

        if style == .pluck {
            drawFinger(&context, x: pickX, stringY: top, t: t, nearby: nearby, moving: moving)
            return
        }
        drawTrail(&context, x: pickX, above: above, below: below, t: t, nearby: nearby, moving: moving, state: state)
        var y = above + (below - above) * CGFloat(state.position)
        if moving, t < 0 {
            // Counting in: the pick bobs on each click, ready to go.
            let beat = t / secondsPerBeat
            y -= CGFloat(6 * exp(-(beat - beat.rounded(.down)) * 8))
        }
        let x = pickX + CGFloat(state.lift) * 24
        let alpha = state.touching || !moving ? 1 : 0.75 - 0.3 * state.lift
        drawPick(&context, center: CGPoint(x: x, y: y), down: state.down, scale: state.touching ? 1 : 0.9, alpha: alpha)
    }

    /// The top string's name just above it and the bottom string's just below, at the right end, clear of
    /// the pick (which crosses at 62 % of the width) and the numbers on the left.
    private func drawEdgeNames(_ context: inout GraphicsContext, size: CGSize, top: CGFloat, bottom: CGFloat, count: Int) {
        guard let edges, count >= 2, top >= 22 else { return }
        let x = size.width - 4
        if let name = edges.canvasLabel(count) { context.draw(name, at: CGPoint(x: x, y: top - 14), anchor: .trailing) }
        if let name = edges.canvasLabel(1) { context.draw(name, at: CGPoint(x: x, y: bottom + 14), anchor: .trailing) }
    }

    private func drawSoundHole(_ context: inout GraphicsContext, center: CGPoint, radius: CGFloat) {
        let hole = Path(ellipseIn: CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2))
        context.fill(hole, with: .radialGradient(Gradient(colors: [Color.black.opacity(0.6), Color.black.opacity(0.2)]), center: center, startRadius: 0, endRadius: radius))
        let ring = radius + 6
        context.stroke(Path(ellipseIn: CGRect(x: center.x - ring, y: center.y - ring, width: ring * 2, height: ring * 2)), with: .color(accent.opacity(0.16)), lineWidth: 4)
    }

    /// A soft glow over the strings right after each stroke lands.
    private func drawFlash(_ context: inout GraphicsContext, size: CGSize, t: Double, nearby: [Stroke], moving: Bool) {
        guard moving, let last = nearby.last(where: { $0.time <= t }) else { return }
        let age = t - last.time
        guard age < 0.4 else { return }
        let center = CGPoint(x: size.width * 0.62, y: size.height / 2)
        let radius = min(size.width, size.height) * 0.55
        let glow = Gradient(colors: [accent.opacity(0.26 * (1 - age / 0.4)), .clear])
        context.fill(Path(ellipseIn: CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2)),
                     with: .radialGradient(glow, center: center, startRadius: 0, endRadius: radius))
    }

    /// One string, thicker toward the bass, bowing in a standing wave while it rings.
    private func drawString(_ context: inout GraphicsContext, index: Int, of count: Int, y: CGFloat, width: CGFloat, amplitude: CGFloat, t: Double) {
        let gauge = count > 1 ? CGFloat(count - 1 - index) / CGFloat(count - 1) : 0.5
        let thickness = 1 + gauge * 2.6
        let wound = count >= 4 && gauge > 0.45
        let base = wound ? Color(hex: 0xCDB892) : Color(hex: 0xE4DFD6)
        let tint = base.mix(with: accent, by: Double(min(1, amplitude / 3.5)))
        // The string's number at the left edge (the thickest, on top, is the highest number), so this
        // player's-eye view never reads as upside down next to the tab-style neck diagrams.
        let number = Text("\(count - index)").font(.system(size: 10, weight: .bold, design: .rounded))
            .foregroundStyle(amplitude > 0.5 ? accent : Palette.inkSoft.opacity(0.85))
        context.draw(number, at: CGPoint(x: 8, y: y))
        let left: CGFloat = 20, right = width - 4
        var path = Path()
        path.move(to: CGPoint(x: left, y: y))
        if amplitude > 0.2 {
            let wobble = amplitude * CGFloat(sin(t * 2 * .pi * 9 + Double(index)))
            let segments = 28
            for k in 1...segments {
                let u = CGFloat(k) / CGFloat(segments)
                path.addLine(to: CGPoint(x: left + (right - left) * u, y: y + wobble * sin(.pi * u)))
            }
            context.stroke(path, with: .color(accent.opacity(Double(min(1, amplitude / 5)) * 0.35)), style: StrokeStyle(lineWidth: thickness + 6, lineCap: .round))
        } else {
            path.addLine(to: CGPoint(x: right, y: y))
        }
        context.stroke(path, with: .color(tint.opacity(0.92)), style: StrokeStyle(lineWidth: thickness, lineCap: .round))
    }

    /// The sweep itself: a streak from where the stroke began to the pick, fading once it lands.
    private func drawTrail(_ context: inout GraphicsContext, x: CGFloat, above: CGFloat, below: CGFloat, t: Double, nearby: [Stroke], moving: Bool, state: PickState) {
        let half = sweepSeconds / 2
        let from: CGFloat, to: CGFloat, fade: Double
        if moving {
            guard let stroke = nearby.last(where: { $0.time - half <= t }) else { return }
            let end = stroke.time + half
            fade = t <= end ? 1 : max(0, 1 - (t - end) / 0.28)
            guard fade > 0 else { return }
            from = stroke.down ? above : below
            let landed: CGFloat = stroke.down ? below : above
            to = t <= end ? above + (below - above) * CGFloat(state.position) : landed
        } else {
            fade = 0.5
            from = state.down ? above : below
            to = state.down ? below : above
        }
        guard abs(to - from) > 1 else { return }
        let rect = CGRect(x: x - 13, y: min(from, to), width: 26, height: abs(to - from))
        let shade = Gradient(colors: [accent.opacity(0), accent.opacity(0.45 * fade)])
        context.fill(Path(roundedRect: rect, cornerRadius: 13), with: .linearGradient(shade, startPoint: CGPoint(x: x, y: from), endPoint: CGPoint(x: x, y: to)))
    }

    /// A guitar pick, tip first in the direction of the stroke.
    private func drawPick(_ context: inout GraphicsContext, center: CGPoint, down: Bool, scale: CGFloat, alpha: Double) {
        let w = 28 * scale, h = 32 * scale
        let s: CGFloat = down ? 1 : -1
        var shape = Path()
        let tip = CGPoint(x: center.x, y: center.y + s * h / 2)
        shape.move(to: tip)
        shape.addQuadCurve(to: CGPoint(x: center.x - w / 2, y: center.y - s * h * 0.3), control: CGPoint(x: center.x - w * 0.5, y: center.y + s * h * 0.12))
        shape.addQuadCurve(to: CGPoint(x: center.x + w / 2, y: center.y - s * h * 0.3), control: CGPoint(x: center.x, y: center.y - s * h * 0.8))
        shape.addQuadCurve(to: tip, control: CGPoint(x: center.x + w * 0.5, y: center.y + s * h * 0.12))
        shape.closeSubpath()
        let halo = h * 0.9
        context.fill(Path(ellipseIn: CGRect(x: center.x - halo, y: center.y - halo, width: halo * 2, height: halo * 2)),
                     with: .radialGradient(Gradient(colors: [accent.opacity(0.35 * alpha), .clear]), center: center, startRadius: 0, endRadius: halo))
        let shine = Gradient(colors: [accent.mix(with: .white, by: 0.35).opacity(alpha), accent.opacity(alpha)])
        context.fill(shape, with: .linearGradient(shine, startPoint: CGPoint(x: center.x, y: center.y - h / 2), endPoint: CGPoint(x: center.x, y: center.y + h / 2)))
        context.stroke(shape, with: .color(.white.opacity(0.35 * alpha)), lineWidth: 1)
    }

    /// Plucked instruments: a fingertip dips onto the lowest string on each hit.
    private func drawFinger(_ context: inout GraphicsContext, x: CGFloat, stringY: CGFloat, t: Double, nearby: [Stroke], moving: Bool) {
        let nearest = nearby.min { abs($0.time - t) < abs($1.time - t) }
        let bump = moving ? nearest.map { exp(-pow(($0.time - t) / 0.07, 2)) } ?? 0 : 0
        let center = CGPoint(x: x, y: stringY - 20 + CGFloat(bump) * 15)
        let halo: CGFloat = 22
        context.fill(Path(ellipseIn: CGRect(x: center.x - halo, y: center.y - halo, width: halo * 2, height: halo * 2)),
                     with: .radialGradient(Gradient(colors: [accent.opacity(0.2 + 0.3 * bump), .clear]), center: center, startRadius: 0, endRadius: halo))
        let r: CGFloat = 10
        context.fill(Path(ellipseIn: CGRect(x: center.x - r, y: center.y - r, width: r * 2, height: r * 2)), with: .color(accent))
        context.stroke(Path(ellipseIn: CGRect(x: center.x - r, y: center.y - r, width: r * 2, height: r * 2)), with: .color(.white.opacity(0.35)), lineWidth: 1)
    }

    // MARK: Tap pad

    private func drawPad(_ context: inout GraphicsContext, size: CGSize) {
        let center = CGPoint(x: size.width / 2, y: size.height / 2)
        let radius = min(size.width, size.height) * 0.27
        let t = time ?? 0
        let nearby = time == nil ? [] : strokes(near: t)
        for stroke in nearby where stroke.time <= t && t - stroke.time < 0.7 {
            let a = (t - stroke.time) / 0.7
            let r = radius + CGFloat(a) * radius * 0.9
            context.stroke(circle(center, r), with: .color(accent.opacity(0.5 * (1 - a))), lineWidth: 2)
        }
        let age = nearby.last(where: { $0.time <= t }).map { t - $0.time } ?? 10
        let hit = exp(-age * 9)
        let r = radius * CGFloat(1 - 0.06 * hit)
        context.fill(circle(center, r + 14), with: .radialGradient(Gradient(colors: [accent.opacity(0.18 + 0.2 * hit), .clear]), center: center, startRadius: r * 0.5, endRadius: r + 14))
        context.fill(circle(center, r), with: .color(accent.opacity(0.12 + 0.18 * hit)))
        context.stroke(circle(center, r), with: .color(accent), lineWidth: 3)
        let glyph = Text(Image(systemName: "hand.tap.fill")).font(.system(size: r * 0.48, weight: .semibold)).foregroundStyle(accent)
        context.draw(glyph, at: center)
    }

    private func circle(_ center: CGPoint, _ radius: CGFloat) -> Path {
        Path(ellipseIn: CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2))
    }
}
