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

/// Repeatable pseudo-random values in 0..<1 for canvas texture (wood grain): the same on every frame, nothing stored.
enum CanvasNoise {
    static func value(_ i: Int) -> Double {
        let v = sin(Double(i) * 12.9898 + 78.233) * 43_758.5453
        return v - v.rounded(.down)
    }
}

// MARK: - Strum sweep

/// A pick sweeping the strings on every stroke of a rhythm pattern, in time with the beat: down strokes
/// run from the thickest string (top, named "Thickest") to the thinnest, up strokes back, and each string shimmers as the
/// pick crosses it. The strings run over a strip of the instrument's top, from the sound hole to the bridge;
/// given the height (300 pt), a stroke rail above them brings each stroke in to the pick. `.pluck` plucks the
/// lowest string on each hit; `.tap` pulses a pad for courses without an instrument. With no time (Reduce
/// Motion) it holds still, showing the first stroke.
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

    /// Height the stroke rail takes over the strings; it only shows when the sweep is given `railMinHeight`.
    private static let railSpace: CGFloat = 58
    private static let railMinHeight: CGFloat = 300

    private func drawStrings(_ context: inout GraphicsContext, size: CGSize) {
        let rail = size.height >= Self.railMinHeight
        let railSpace = rail ? Self.railSpace : 0
        let area = CGRect(x: 0, y: railSpace, width: size.width, height: size.height - railSpace)
        let count = max(1, strings)
        let band = min(area.height * 0.6, CGFloat(count) * (count <= 4 ? 40 : 32))
        let gap = count > 1 ? band / CGFloat(count - 1) : 0
        let top = area.minY + (area.height - band) / 2
        let reach = max(8, min(26, top - area.minY - 6))
        let above = top - reach, below = top + band + reach
        let pickX = size.width * 0.62
        // The strings run from the neck end on the left to the bridge's saddle on the right.
        let bridgeX = size.width - 22
        let moving = time != nil
        let t = time ?? 0
        let nearby = moving ? strokes(near: t) : []
        let state = moving ? pick(at: t, nearby) : PickState(position: 0, touching: false, down: pattern.first.map { $0.truncatingRemainder(dividingBy: 1) == 0 } ?? true, lift: 0)

        drawSoundboard(&context, size: size, from: above - 12, to: below + 12)
        if style == .strum {
            let radius = min(band * 0.5 + 20, size.width * 0.26, area.height / 2 - 8)
            // Far enough in that the rosette clears the string numbers at the left edge.
            drawSoundHole(&context, center: CGPoint(x: max(radius + 24, size.width * 0.3), y: area.midY), radius: max(10, radius))
        }
        drawBridge(&context, x: bridgeX, top: top, gap: gap, count: count)
        if rail { drawRail(&context, size: size, pickX: pickX, guideTo: above - 12, t: t, moving: moving) }
        drawFlash(&context, center: CGPoint(x: pickX, y: area.midY), size: size, t: t, nearby: nearby, moving: moving)

        for index in 0..<count {
            let y = top + CGFloat(index) * gap
            let share = Double((y - above) / max(1, below - above))
            let crossed = moving ? lastExcitation(of: index, share: share, at: t, nearby) : nil
            let amplitude = crossed.map { CGFloat(5 * exp(-(t - $0) * 4.5)) } ?? 0
            drawString(&context, index: index, of: count, y: y, right: bridgeX, amplitude: amplitude, t: t)
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

    /// A strip of the instrument's top under the strings: dark tonewood with its grain, a sheen across the
    /// middle and a hairline of binding at the edge.
    private func drawSoundboard(_ context: inout GraphicsContext, size: CGSize, from top: CGFloat, to bottom: CGFloat) {
        let rect = CGRect(x: 0, y: top, width: size.width, height: max(1, bottom - top))
        let board = Path(roundedRect: rect, cornerRadius: 18)
        context.fill(board, with: .linearGradient(Self.wood, startPoint: CGPoint(x: 0, y: rect.minY), endPoint: CGPoint(x: 0, y: rect.maxY)))
        var grain = context
        grain.clip(to: board)
        for i in 0..<16 {
            let n = CanvasNoise.value(i)
            let y = rect.minY + rect.height * CGFloat((Double(i) + 0.2 + 0.6 * n) / 16)
            var line = Path()
            line.move(to: CGPoint(x: rect.minX, y: y))
            line.addCurve(to: CGPoint(x: rect.maxX, y: y + CGFloat(CanvasNoise.value(i + 40) - 0.5) * 6),
                          control1: CGPoint(x: rect.width * 0.33, y: y + CGFloat(CanvasNoise.value(i + 20) - 0.5) * 9),
                          control2: CGPoint(x: rect.width * 0.7, y: y - CGFloat(CanvasNoise.value(i + 60) - 0.5) * 9))
            let tone: Color = i % 4 == 0 ? Color.white.opacity(0.035) : Color.black.opacity(0.16 + 0.14 * n)
            grain.stroke(line, with: .color(tone), lineWidth: 0.6 + 1.5 * CGFloat(CanvasNoise.value(i + 80)))
        }
        grain.fill(board, with: .linearGradient(Self.sheen, startPoint: CGPoint(x: 0, y: rect.minY), endPoint: CGPoint(x: 0, y: rect.maxY)))
        context.stroke(board, with: .color(Self.bone.opacity(0.1)), lineWidth: 1)
    }

    /// Bone: saddle, pins and binding.
    private static let bone = Color(hex: 0xEDE3CF)
    private static let wood = Gradient(colors: [Color(hex: 0x2A2019), Color(hex: 0x1B1410)])
    private static let sheen = Gradient(colors: [Color.black.opacity(0.3), Color.white.opacity(0.03), Color.black.opacity(0.3)])

    /// The sound hole with its rosette: binding rings around a band of inlay that catches the accent.
    private func drawSoundHole(_ context: inout GraphicsContext, center: CGPoint, radius: CGFloat) {
        context.fill(circle(center, radius), with: .radialGradient(Gradient(colors: [Color.black.opacity(0.9), Color.black.opacity(0.6)]), center: center, startRadius: 0, endRadius: radius))
        context.stroke(circle(center, radius + 3), with: .color(Self.bone.opacity(0.22)), lineWidth: 1)
        context.stroke(circle(center, radius + 8), with: .color(accent.opacity(0.24)), style: StrokeStyle(lineWidth: 5, dash: [2, 2.5]))
        context.stroke(circle(center, radius + 13), with: .color(Self.bone.opacity(0.15)), lineWidth: 1)
    }

    /// The bridge the strings run to: a dark body, a bone saddle and a pin behind each string.
    private func drawBridge(_ context: inout GraphicsContext, x: CGFloat, top: CGFloat, gap: CGFloat, count: Int) {
        let bottom = top + gap * CGFloat(max(0, count - 1))
        let bridge = Path(roundedRect: CGRect(x: x - 8, y: top - 8, width: 20, height: bottom - top + 16), cornerRadius: 6)
        context.fill(bridge, with: .color(Color(hex: 0x120D0A)))
        context.stroke(bridge, with: .color(.white.opacity(0.06)), lineWidth: 1)
        context.fill(Path(roundedRect: CGRect(x: x - 1.5, y: top - 5, width: 3, height: bottom - top + 10), cornerRadius: 1.5), with: .color(Self.bone.opacity(0.85)))
        for index in 0..<count {
            context.fill(circle(CGPoint(x: x + 7, y: top + CGFloat(index) * gap), 2.4), with: .color(Self.bone.opacity(0.5)))
        }
    }

    /// The stroke rail over the strings: the pattern's strokes ride in from the right and land on the marker
    /// above the pick as it plays them, then drift on to the left and fade; ticks mark the beats, taller on the
    /// bar. With no time it holds the first strokes still, waiting just past the marker.
    private func drawRail(_ context: inout GraphicsContext, size: CGSize, pickX: CGFloat, guideTo: CGFloat, t: Double, moving: Bool) {
        let y: CGFloat = 26
        let track = CGRect(x: 8, y: y - 19, width: size.width - 16, height: 38)
        let shape = Path(roundedRect: track, cornerRadius: 19)
        context.fill(shape, with: .color(.white.opacity(0.035)))
        context.stroke(shape, with: .color(.white.opacity(0.08)), lineWidth: 1)
        let perBeat: CGFloat = 54
        let spb = max(0.05, secondsPerBeat)
        let beatNow = (moving ? t : -0.4 * spb) / spb
        let behind = Double((pickX - track.minX) / perBeat), ahead = Double((track.maxX - pickX) / perBeat)
        let meter = max(1, beatsPerBar)

        let firstBeat = Int((beatNow - behind).rounded(.down)), lastBeat = Int((beatNow + ahead).rounded(.up))
        if lastBeat >= firstBeat {
            for beat in firstBeat...lastBeat {
                let x = pickX + CGFloat(Double(beat) - beatNow) * perBeat
                guard x > track.minX + 6, x < track.maxX - 6 else { continue }
                let bar = ((beat % meter) + meter) % meter == 0
                let h: CGFloat = bar ? 22 : 10
                context.fill(Path(roundedRect: CGRect(x: x - 0.75, y: y - h / 2, width: 1.5, height: h), cornerRadius: 0.75),
                             with: .color(.white.opacity(bar ? 0.16 : 0.07)))
            }
        }

        // The marker over the pick, and a dotted guide down to the strings.
        var guide = Path()
        guide.move(to: CGPoint(x: pickX, y: track.maxY + 3))
        guide.addLine(to: CGPoint(x: pickX, y: max(track.maxY + 3, guideTo)))
        context.stroke(guide, with: .color(accent.opacity(0.25)), style: StrokeStyle(lineWidth: 1, lineCap: .round, dash: [2, 4]))
        let halo = CGRect(x: pickX - 18, y: track.minY, width: 36, height: track.height)
        let haloShade = Gradient(colors: [accent.opacity(0), accent.opacity(0.16), accent.opacity(0)])
        context.fill(Path(roundedRect: halo, cornerRadius: 12), with: .linearGradient(haloShade, startPoint: CGPoint(x: halo.minX, y: y), endPoint: CGPoint(x: halo.maxX, y: y)))
        context.fill(Path(roundedRect: CGRect(x: pickX - 1.5, y: track.minY - 3, width: 3, height: track.height + 6), cornerRadius: 1.5), with: .color(accent))

        guard !pattern.isEmpty else { return }
        let firstBar = Int(((beatNow - behind) / Double(meter)).rounded(.down))
        let lastBar = Int(((beatNow + ahead) / Double(meter)).rounded(.down))
        guard lastBar >= firstBar else { return }
        let fadeSpan = Double(max(1, pickX - track.minX - 10))
        for bar in firstBar...lastBar {
            if let bars, bar < 0 || bar >= bars { continue }
            for hit in pattern {
                let beat = Double(bar * meter) + hit
                let x = pickX + CGFloat(beat - beatNow) * perBeat
                guard x > track.minX + 10, x < track.maxX - 10 else { continue }
                let age = (beatNow - beat) * spb
                // Fading in at the right end, out toward the left.
                let alpha = age < 0 ? min(1, Double(track.maxX - 10 - x) / 28) : max(0, 1 - Double(pickX - x) / fadeSpan)
                drawRailStroke(&context, center: CGPoint(x: x, y: y), down: hit.truncatingRemainder(dividingBy: 1) == 0,
                               age: moving ? age : -1, alpha: alpha)
            }
        }
    }

    /// One stroke on the rail: an outlined arrow (a dot when plucking) on its way, filled once played, with a
    /// pop and a ring as it lands on the marker.
    private func drawRailStroke(_ context: inout GraphicsContext, center: CGPoint, down: Bool, age: Double, alpha: Double) {
        guard alpha > 0.01 else { return }
        let played = age >= 0
        let landing = played && age < 0.3 ? 1 - age / 0.3 : 0
        if landing > 0 {
            context.stroke(circle(center, 12 + CGFloat(1 - landing) * 16), with: .color(accent.opacity(0.7 * landing * alpha)), lineWidth: 2)
        }
        let chip = circle(center, 12 * (1 + 0.3 * CGFloat(landing)))
        if played {
            context.fill(chip, with: .color(accent.mix(with: .white, by: 0.5 * landing).opacity((0.35 + 0.65 * landing) * alpha)))
        } else {
            context.fill(chip, with: .color(accent.opacity(0.14 * alpha)))
            context.stroke(chip, with: .color(accent.opacity(0.85 * alpha)), lineWidth: 1.5)
        }
        // Dark on the bright landing, light on the faded chips it leaves behind.
        let ink: Color = played ? (landing > 0.2 ? Palette.onAccent : Palette.ink) : accent
        if style == .pluck {
            context.fill(circle(center, 3.5), with: .color(ink.opacity(alpha)))
        } else {
            context.stroke(arrow(center, down: down), with: .color(ink.opacity(alpha)), style: StrokeStyle(lineWidth: 2.2, lineCap: .round, lineJoin: .round))
        }
    }

    /// A short arrow pointing the way of the stroke.
    private func arrow(_ c: CGPoint, down: Bool) -> Path {
        let s: CGFloat = down ? 1 : -1
        var p = Path()
        p.move(to: CGPoint(x: c.x, y: c.y - s * 5.5))
        p.addLine(to: CGPoint(x: c.x, y: c.y + s * 5))
        p.move(to: CGPoint(x: c.x - 4.5, y: c.y + s * 0.8))
        p.addLine(to: CGPoint(x: c.x, y: c.y + s * 5.3))
        p.addLine(to: CGPoint(x: c.x + 4.5, y: c.y + s * 0.8))
        return p
    }

    /// A soft glow over the strings right after each stroke lands, and a ring leaving the pick.
    private func drawFlash(_ context: inout GraphicsContext, center: CGPoint, size: CGSize, t: Double, nearby: [Stroke], moving: Bool) {
        guard moving, let last = nearby.last(where: { $0.time <= t }) else { return }
        let age = t - last.time
        guard age < 0.4 else { return }
        let fade = 1 - age / 0.4
        let radius = min(size.width, size.height) * 0.55
        let glow = Gradient(colors: [accent.opacity(0.26 * fade), .clear])
        context.fill(circle(center, radius), with: .radialGradient(glow, center: center, startRadius: 0, endRadius: radius))
        context.stroke(circle(center, 18 + CGFloat(age / 0.4) * 46), with: .color(accent.mix(with: .white, by: 0.4).opacity(0.55 * fade)), lineWidth: 0.5 + 2 * CGFloat(fade))
    }

    /// One string, thicker toward the bass, bowing in a standing wave while it rings: a shadow on the top under
    /// it, the winding on the wound strings and a thin highlight along it.
    private func drawString(_ context: inout GraphicsContext, index: Int, of count: Int, y: CGFloat, right: CGFloat, amplitude: CGFloat, t: Double) {
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
        let left: CGFloat = 20
        var path = Path()
        path.move(to: CGPoint(x: left, y: y))
        if amplitude > 0.2 {
            let wobble = amplitude * CGFloat(sin(t * 2 * .pi * 9 + Double(index)))
            let segments = 28
            for k in 1...segments {
                let u = CGFloat(k) / CGFloat(segments)
                path.addLine(to: CGPoint(x: left + (right - left) * u, y: y + wobble * sin(.pi * u)))
            }
        } else {
            path.addLine(to: CGPoint(x: right, y: y))
        }
        context.stroke(path.offsetBy(dx: 0, dy: 2.5), with: .color(.black.opacity(0.35)), style: StrokeStyle(lineWidth: thickness, lineCap: .round))
        if amplitude > 0.2 {
            context.stroke(path, with: .color(accent.opacity(Double(min(1, amplitude / 5)) * 0.35)), style: StrokeStyle(lineWidth: thickness + 6, lineCap: .round))
        }
        context.stroke(path, with: .color(tint.opacity(0.92)), style: StrokeStyle(lineWidth: thickness, lineCap: .round))
        if wound {
            context.stroke(path, with: .color(.black.opacity(0.22)), style: StrokeStyle(lineWidth: thickness, dash: [1, 1.5]))
        }
        context.stroke(path.offsetBy(dx: 0, dy: -thickness * 0.25), with: .color(.white.opacity(0.22)), style: StrokeStyle(lineWidth: max(0.5, thickness * 0.3), lineCap: .round))
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
