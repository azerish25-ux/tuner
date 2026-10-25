import AVFoundation
import SwiftUI
import TimbreCore

// MARK: - Microphone and practice mode

/// Whether a lesson can hear the instrument at all. Without it (permission refused, or the microphone
/// failed to start), an instrument's rhythm steps fall back to tapping the screen: practice mode.
enum LessonMicrophone {
    /// Screenshot and UI-test runs (TIMBRE_DEMO_PITCH=1, debug builds only) feed a demo pitch instead of the
    /// microphone. It has a pitch but no strokes, so rhythm steps play the strums themselves (`RhythmStep`).
    static var demo: Bool {
        #if DEBUG
        return ProcessInfo.processInfo.environment["TIMBRE_DEMO_PITCH"] == "1"
        #else
        return false
        #endif
    }

    @MainActor static func unavailable(_ audio: AudioService) -> Bool {
        if demo { return false }
        return audio.permissionDenied || AVAudioApplication.shared.recordPermission == .denied
    }

    /// The microphone may be used without asking: steps that only listen as a bonus (a chord played back
    /// after a demonstration) never raise the permission prompt.
    @MainActor static var granted: Bool {
        if demo { return true }
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
/// run from the thickest string to the thinnest, up strokes back, and each string shimmers as the pick crosses it.
/// The strings lie as every other neck in the app does (`ChordPicture`, Settings › String order): in the Chart view,
/// the default, string 1 on top as tab writes it, so a down stroke climbs the screen from the thickest string at the
/// bottom; in Player view the thickest on top, as you look down at the instrument while you play, so it falls down
/// the screen. Either way a key over the strings reads "↓ 6 → 1": the beat row's ↓ is a down strum, from the thickest
/// string to string 1. Each string is numbered and the outer two are named ("Thinnest (1)", "Thickest (6)"), and the
/// pick's tip, its lane's chevrons and its trail all point the way it travels on screen.
/// The strings run over the instrument's top, from the sound hole to the bridge; the wood fills the whole frame and
/// the strings spread to fill its height (up to a comfortable spacing), so a tall stage is all guitar, never bare.
/// What comes next is the beat row's job (`RhythmBar`, `LessonBeatRow`), so the sweep draws only the stroke
/// itself. `.pluck` plucks the lowest string on each hit; `.tap` pulses a pad for courses without an instrument.
/// With no time (Reduce Motion) it holds still, showing the first stroke.
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
    /// Names the top and bottom strings in words ("Thinnest (1)" over the top in the Chart view, "Thickest (6)" under
    /// the bottom; the other way round in Player view).
    var edges: StringEdges?
    /// Which string lies on top: the app's one picture choice, as on every other neck.
    @AppStorage(StringOrder.storageKey) private var stringOrder: StringOrder = .tab
    /// The string numbers and names grow with Dynamic Type from the 11 pt floor (`DiagramType`).
    @ScaledMetric(relativeTo: .caption2) private var typeScale: CGFloat = 1

    private struct Stroke {
        let time: Double
        let down: Bool
    }

    private struct PickState {
        /// 0 on the thickest string's side of the strings, 1 past the thinnest (whichever way up they are drawn).
        var position: Double
        var touching: Bool
        var down: Bool
        /// 0…1: how far the pick is lifted off the strings on its way back.
        var lift: Double
    }

    /// Where the strings sit on the stage and which way up they lie.
    private struct Frame {
        /// The pick's travel from just outside the top string to just outside the bottom one.
        let above: CGFloat
        let below: CGFloat
        /// The thickest string is the top one (mirror order).
        let thickOnTop: Bool

        /// The pick's y for a `PickState.position`.
        func y(_ position: Double) -> CGFloat {
            let p = CGFloat(position)
            return thickOnTop ? above + (below - above) * p : below - (below - above) * p
        }
        /// How far a string at `y` lies from the thickest side (0…1), so the pick reaches it on time either way up.
        func share(_ y: CGFloat) -> Double {
            let u = Double((y - above) / max(1, below - above))
            return thickOnTop ? u : 1 - u
        }
        /// The edge a stroke starts from: the thickest side for a down stroke.
        func start(down: Bool) -> CGFloat { down == thickOnTop ? above : below }
        /// A stroke travels down the screen: a down stroke when the thickest string is on top, an up stroke otherwise.
        func fallsOnScreen(down: Bool) -> Bool { down == thickOnTop }
    }

    var body: some View {
        let order = stringOrder
        let scale = typeScale
        Canvas { context, size in
            if style == .tap { drawPad(&context, size: size) } else { drawStrings(&context, size: size, order: order, scale: scale) }
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

    /// When the pick (or the plucking finger, on the lowest string) last set string `number` of `count` ringing, at or
    /// before `t`. `share`: how far across the strings it lies from the thickest side.
    private func lastExcitation(ofString number: Int, count: Int, share: Double, at t: Double, _ strokes: [Stroke]) -> Double? {
        var latest: Double?
        for stroke in strokes {
            let time: Double
            if style == .pluck {
                guard number == count else { return nil }
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

    /// The widest the strings spread (a tall stage centres them on more wood rather than spacing them further).
    private static func widestGap(_ count: Int) -> CGFloat { count <= 4 ? 72 : 56 }
    /// Past the pick's reach above the top string and below the bottom one: room for the pick itself at the end of
    /// its stroke (up to 22 pt from its centre on a big stage, a little more as it bobs counting in) and some wood.
    private static let pickClear: CGFloat = 26

    private func drawStrings(_ context: inout GraphicsContext, size: CGSize, order: StringOrder, scale: CGFloat) {
        let area = CGRect(origin: .zero, size: size)
        let count = max(1, strings)
        // The strings fill the stage: the pick's reach and the pick itself aside, every string gets an even share of
        // the height, up to a comfortable spread.
        let reach = max(10, min(30, size.height * 0.08))
        let room = max(0, size.height - 2 * (reach + Self.pickClear))
        // A small stage (an explanation's card on a short phone) keeps the strings at least 60 % of its height.
        let band = count > 1 ? min(Self.widestGap(count) * CGFloat(count - 1), max(room, size.height * 0.6)) : 0
        let gap = count > 1 ? band / CGFloat(count - 1) : 0
        let top = area.midY - band / 2
        // The pick, its lane and the finger grow a little with the strings on a big stage.
        let grow = min(1.35, max(1, gap / 36))
        let frame = Frame(above: top - reach, below: top + band + reach, thickOnTop: !order.thinnestOnTop)
        let pickX = size.width * 0.62
        // The strings run from the neck end on the left to the bridge's saddle on the right.
        let bridgeX = size.width - 22
        let moving = time != nil
        let t = time ?? 0
        let nearby = moving ? strokes(near: t) : []
        let state = moving ? pick(at: t, nearby) : PickState(position: 0, touching: false, down: pattern.first.map { $0.truncatingRemainder(dividingBy: 1) == 0 } ?? true, lift: 0)

        // The wood fills the whole stage, edge to edge.
        drawSoundboard(&context, size: size, from: 0, to: size.height)
        if style == .strum {
            let radius = min(band * 0.5 + 20, size.width * 0.26, area.height / 2 - 8)
            // Far enough in that the rosette clears the string numbers at the left edge.
            drawSoundHole(&context, center: CGPoint(x: max(radius + 24, size.width * 0.3), y: area.midY), radius: max(10, radius))
        }
        drawBridge(&context, x: bridgeX, top: top, gap: gap, count: count)
        drawFlash(&context, center: CGPoint(x: pickX, y: area.midY), size: size, t: t, nearby: nearby, moving: moving)
        if style == .strum {
            drawLane(&context, x: pickX, above: frame.above, below: frame.below, falling: frame.fallsOnScreen(down: state.down), width: 26 * grow)
        }

        for row in 0..<count {
            let y = top + CGFloat(row) * gap
            let number = order.string(atRow: row, count: count)
            let crossed = moving ? lastExcitation(ofString: number, count: count, share: frame.share(y), at: t, nearby) : nil
            let amplitude = crossed.map { CGFloat(5 * exp(-(t - $0) * 4.5)) } ?? 0
            drawString(&context, number: number, of: count, y: y, right: bridgeX, amplitude: amplitude, t: t, scale: scale)
        }
        drawEdgeNames(&context, size: size, top: top, bottom: top + band, count: count, order: order, scale: scale)
        drawStrokeKey(&context, top: top, count: count, scale: scale)

        if style == .pluck {
            // The lowest string, wherever the order puts it; the fingertip comes at it from outside the strings.
            let lowest = top + CGFloat(order.row(ofString: count, count: count)) * gap
            drawFinger(&context, x: pickX, stringY: lowest, fromAbove: frame.thickOnTop, t: t, nearby: nearby, moving: moving, grow: grow)
            return
        }
        var y = frame.y(state.position)
        drawTrail(&context, x: pickX, frame: frame, pickY: y, t: t, nearby: nearby, moving: moving, state: state, width: 26 * grow)
        if moving, t < 0, bars != nil {
            // Counting in: the pick bobs on each click, away from the strings, ready to go (a loop just turns on
            // through the bar before).
            let beat = t / secondsPerBeat
            let away: CGFloat = y < (frame.above + frame.below) / 2 ? -1 : 1
            y += away * CGFloat(6 * exp(-(beat - beat.rounded(.down)) * 8))
        }
        let x = pickX + CGFloat(state.lift) * 24 * grow
        let alpha = state.touching || !moving ? 1 : 0.75 - 0.3 * state.lift
        drawPick(&context, center: CGPoint(x: x, y: y), pointsDown: frame.fallsOnScreen(down: state.down), scale: (state.touching ? 1 : 0.9) * grow, alpha: alpha)
    }

    /// The top string's name just above it and the bottom string's just below, at the right end, clear of
    /// the pick (which crosses at 62 % of the width) and the numbers on the left.
    private func drawEdgeNames(_ context: inout GraphicsContext, size: CGSize, top: CGFloat, bottom: CGFloat, count: Int,
                               order: StringOrder, scale: CGFloat) {
        guard let edges, count >= 2, top >= 22 else { return }
        let x = size.width - 4
        let points = DiagramType.size(DiagramType.floor, scale: scale)
        let lift = 8 + points * 0.55
        if let name = edges.canvasLabel(order.string(atRow: 0, count: count), size: points) {
            context.draw(name, at: CGPoint(x: x, y: top - lift), anchor: .trailing)
        }
        if let name = edges.canvasLabel(order.string(atRow: count - 1, count: count), size: points) {
            context.draw(name, at: CGPoint(x: x, y: bottom + lift), anchor: .trailing)
        }
    }

    /// The strum's key over the strings' top-left corner, level with the top string's name and on a dark plate (it can
    /// sit over the rosette): "↓ 6 → 1", the beat row's down arrow in the accent, then the strings a down strum crosses
    /// from first to last. In the Chart view that is up the screen (string 1 is on top, as in tab), so the arrow on
    /// the beat row never reads as the way the pick moves here. Strums only: a plucking finger has no direction.
    private func drawStrokeKey(_ context: inout GraphicsContext, top: CGFloat, count: Int, scale: CGFloat) {
        guard style == .strum, count >= 2 else { return }
        let points = DiagramType.size(DiagramType.floor, scale: scale)
        let arrow = Text(Image(systemName: "arrow.down")).foregroundStyle(accent)
        let crossing = Text(verbatim: " \(count) → 1").foregroundStyle(Palette.inkSoft)
        let text = (arrow + crossing).font(DiagramType.font(points, weight: .bold))
        let resolved = context.resolve(text)
        let size = resolved.measure(in: CGSize(width: 200, height: 40))
        let y = top - 10 - points * 0.55
        let plate = CGRect(x: 2, y: y - size.height / 2 - 2, width: size.width + 12, height: size.height + 4)
        guard plate.minY >= 2 else { return }
        context.fill(Path(roundedRect: plate, cornerRadius: plate.height / 2), with: .color(Palette.stageDeep.opacity(0.75)))
        context.draw(resolved, at: CGPoint(x: plate.minX + 6, y: y), anchor: .leading)
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

    /// String `number` (1 the thinnest), thicker toward the bass, bowing in a standing wave while it rings: a shadow
    /// on the top under it, the winding on the wound strings and a thin highlight along it.
    private func drawString(_ context: inout GraphicsContext, number: Int, of count: Int, y: CGFloat, right: CGFloat, amplitude: CGFloat,
                            t: Double, scale: CGFloat) {
        let gauge = count > 1 ? CGFloat(number - 1) / CGFloat(count - 1) : 0.5
        let thickness = 1 + gauge * 2.6
        let wound = count >= 4 && gauge > 0.45
        let base = wound ? Color(hex: 0xCDB892) : Color(hex: 0xE4DFD6)
        let tint = base.mix(with: accent, by: Double(min(1, amplitude / 3.5)))
        // The string's number at the left edge, as beside the nut on the fretboards, lit while it rings.
        let label = Text("\(number)").font(DiagramType.font(11, scale: scale))
            .foregroundStyle(amplitude > 0.5 ? accent : Palette.inkSoft.opacity(0.85))
        context.draw(label, at: CGPoint(x: 8, y: y))
        let left: CGFloat = 20
        var path = Path()
        path.move(to: CGPoint(x: left, y: y))
        if amplitude > 0.2 {
            let wobble = amplitude * CGFloat(sin(t * 2 * .pi * 9 + Double(number)))
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

    /// The pick's path across the strings, faint under them: a lane with chevrons pointing the way the next stroke
    /// goes on screen (`falling`: down the screen), so even a still frame shows where and which way the pick sweeps.
    private func drawLane(_ context: inout GraphicsContext, x: CGFloat, above: CGFloat, below: CGFloat, falling: Bool, width: CGFloat) {
        guard below - above > 30 else { return }
        let lane = CGRect(x: x - width / 2, y: above, width: width, height: below - above)
        context.fill(Path(roundedRect: lane, cornerRadius: width / 2), with: .color(accent.opacity(0.07)))
        context.stroke(Path(roundedRect: lane, cornerRadius: width / 2), with: .color(accent.opacity(0.12)), lineWidth: 1)
        let s: CGFloat = falling ? 1 : -1
        for k in 0..<3 {
            let y = above + (below - above) * (0.3 + 0.2 * CGFloat(k))
            var chevron = Path()
            chevron.move(to: CGPoint(x: x - 5, y: y - 3 * s))
            chevron.addLine(to: CGPoint(x: x, y: y + 2 * s))
            chevron.addLine(to: CGPoint(x: x + 5, y: y - 3 * s))
            context.stroke(chevron, with: .color(accent.opacity(0.3)), style: StrokeStyle(lineWidth: 1.6, lineCap: .round, lineJoin: .round))
        }
    }

    /// The sweep itself: a streak from where the stroke began (the thickest side for a down stroke) to the pick at
    /// `pickY`, fading once it lands.
    private func drawTrail(_ context: inout GraphicsContext, x: CGFloat, frame: Frame, pickY: CGFloat, t: Double, nearby: [Stroke],
                           moving: Bool, state: PickState, width: CGFloat) {
        let half = sweepSeconds / 2
        let from: CGFloat, to: CGFloat, fade: Double
        if moving {
            guard let stroke = nearby.last(where: { $0.time - half <= t }) else { return }
            let end = stroke.time + half
            fade = t <= end ? 1 : max(0, 1 - (t - end) / 0.28)
            guard fade > 0 else { return }
            from = frame.start(down: stroke.down)
            let landed = frame.start(down: !stroke.down)
            to = t <= end ? pickY : landed
        } else {
            fade = 0.5
            from = frame.start(down: state.down)
            to = frame.start(down: !state.down)
        }
        guard abs(to - from) > 1 else { return }
        let rect = CGRect(x: x - width / 2, y: min(from, to), width: width, height: abs(to - from))
        let shade = Gradient(colors: [accent.opacity(0), accent.opacity(0.45 * fade)])
        context.fill(Path(roundedRect: rect, cornerRadius: width / 2), with: .linearGradient(shade, startPoint: CGPoint(x: x, y: from), endPoint: CGPoint(x: x, y: to)))
    }

    /// A guitar pick, tip first in the direction of the stroke on screen (`pointsDown`: down the screen).
    private func drawPick(_ context: inout GraphicsContext, center: CGPoint, pointsDown: Bool, scale: CGFloat, alpha: Double) {
        let w = 28 * scale, h = 32 * scale
        let s: CGFloat = pointsDown ? 1 : -1
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

    /// Plucked instruments: a fingertip dips onto the lowest string on each hit, from outside the strings (from
    /// above when that string is on top, from below when it's at the bottom).
    private func drawFinger(_ context: inout GraphicsContext, x: CGFloat, stringY: CGFloat, fromAbove: Bool, t: Double, nearby: [Stroke], moving: Bool,
                            grow: CGFloat) {
        let nearest = nearby.min { abs($0.time - t) < abs($1.time - t) }
        let bump = moving ? nearest.map { exp(-pow(($0.time - t) / 0.07, 2)) } ?? 0 : 0
        let side: CGFloat = fromAbove ? -1 : 1
        let center = CGPoint(x: x, y: stringY + side * (20 - CGFloat(bump) * 15) * grow)
        let halo: CGFloat = 22 * grow
        context.fill(Path(ellipseIn: CGRect(x: center.x - halo, y: center.y - halo, width: halo * 2, height: halo * 2)),
                     with: .radialGradient(Gradient(colors: [accent.opacity(0.2 + 0.3 * bump), .clear]), center: center, startRadius: 0, endRadius: halo))
        let r: CGFloat = 10 * grow
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
