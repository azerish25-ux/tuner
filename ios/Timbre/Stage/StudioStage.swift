import SwiftUI
import TimbreCore

/// Points on a 2D picture (studio render or photograph) that the 2D stage animates, normalised
/// to the square the picture is fitted into: "<anchor>.nut", "<anchor>.saddle" (a string's
/// speaking length) and "<anchor>.peg" (where the player tunes it).
struct StageCard: Sendable {
    let anchors: [String]
    let points: [String: CGPoint]
    /// The headstock: the box around every peg and nut point, when the picture has one compact enough to frame
    /// close (harps, zithers, kalimbas and winds have none, and their pictures stay whole).
    let head: CGRect?
    /// Each string's turn sign (+1: clockwise tightens): from its 3D rig, or for a photograph from photo-turns.json
    /// (the side of the head each key sits on in the picture). A string without one shows no turn arrow rather than
    /// a guessed one.
    var turns: [String: Int] = [:]
    /// Strings tuned by a slide (wind joints) rather than a peg.
    var slides: Set<String> = []
    func point(_ key: String) -> CGPoint? { points[key] }
    func hasString(_ anchor: String) -> Bool { points["\(anchor).nut"] != nil && points["\(anchor).saddle"] != nil }

    init(points: [String: [Double]]) {
        var map: [String: CGPoint] = [:]
        for (key, value) in points where value.count == 2 { map[key] = CGPoint(x: value[0], y: value[1]) }
        self.points = map
        var seen: [String] = []
        for key in points.keys.sorted() {
            let anchor = String(key.split(separator: ".").first ?? "")
            if !anchor.isEmpty, !seen.contains(anchor) { seen.append(anchor) }
        }
        anchors = seen
        head = Self.headBox(map)
    }

    private static func headBox(_ points: [String: CGPoint]) -> CGRect? {
        guard points.keys.contains(where: { $0.hasSuffix(".nut") }) else { return nil }
        let head = points.filter { $0.key.hasSuffix(".peg") || $0.key.hasSuffix(".nut") }.map(\.value)
        guard let first = head.first else { return nil }
        var minX = first.x, maxX = first.x, minY = first.y, maxY = first.y
        for p in head {
            minX = min(minX, p.x); maxX = max(maxX, p.x)
            minY = min(minY, p.y); maxY = max(maxY, p.y)
        }
        guard maxX - minX <= 0.36, maxY - minY <= 0.36 else { return nil }
        return CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
    }

    /// A studio render's points; strings without geometry (wind slides) keep only the tuning point.
    init?(rig: InstrumentRig) {
        guard let card = rig.card2D else { return nil }
        var points = card
        for string in rig.strings where string.radius <= 0 {
            points["\(string.anchor).nut"] = nil; points["\(string.anchor).saddle"] = nil
        }
        self.init(points: points)
        for string in rig.strings where turns[string.anchor] == nil {
            turns[string.anchor] = string.tighten
            if string.slides { slides.insert(string.anchor) }
        }
    }

    /// The headstock's centre line: the mean x of the nut points (of the pegs when there are none).
    var centerX: CGFloat {
        let nuts = points.filter { $0.key.hasSuffix(".nut") }.map(\.value.x)
        let xs = nuts.isEmpty ? points.filter { $0.key.hasSuffix(".peg") }.map(\.value.x) : nuts
        return xs.isEmpty ? 0.5 : xs.reduce(0, +) / CGFloat(xs.count)
    }
}

/// 2D stage on a studio render or photograph. Used when real-time 3D is unavailable or turned
/// off, and for instruments without a 3D model. With card points it draws the live string along its
/// own saddle and nut (see `StringDrawing`) and a glowing ring on the peg, which checks off in tune,
/// with the note and turn cue beside it. When the host asks for focus, the picture dollies in to its
/// headstock as the 3D stage does (`StageFrame`). Colours follow the tuner's rule; Reduce Motion cuts
/// the dolly and stills the pulse and the ripple while the colours keep following the pitch.
struct StudioStage: View {
    let imageName: String
    let card: StageCard?
    let input: () -> StageInput
    var onSelect: (String) -> Void = { _ in }
    /// The host isn't listening and holds no reading: once the dolly, the string's glow and the ring have settled,
    /// the stage stops redrawing (and its ring stops pulsing) until something changes.
    var resting = false
    @State private var motion = Motion2D()
    /// A change at rest (a new picture or string, the close-up, the window's size, listening stopping) still moves:
    /// the stage keeps drawing for `StageSettle.window` before it holds still.
    @State private var settling = true
    /// The moment the string locks, for its shimmer.
    @State private var flash = LockFlash()
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        GeometryReader { geometry in
            let size = geometry.size
            if let card {
                // Read only at rest (the reading doesn't change then), so a live pitch never re-runs this closure.
                let key: String? = resting ? StageSettle.key(input(), picture: imageName, size: size) : nil
                let still = resting && !settling
                // Every frame while anything moves: the dolly moves the picture, its rings and its tap targets together.
                TimelineView(.animation(minimumInterval: reduceMotion ? 0.1 : nil, paused: still)) { timeline in
                    live(card: card, size: size, date: timeline.date, idle: still)
                }
                .task(id: key) {
                    settling = true
                    guard key != nil else { return }
                    try? await Task.sleep(for: StageSettle.window)
                    if !Task.isCancelled { settling = false }
                }
            } else {
                picture(StageFrame.whole(in: size))
            }
        }
    }

    private func picture(_ frame: StageFrame) -> some View {
        Image(imageName).resizable().interpolation(.high).scaledToFit()
            .frame(width: frame.side, height: frame.side)
            .shadow(color: .black.opacity(0.55), radius: 30, y: 18)
            .position(x: frame.origin.x + frame.side / 2, y: frame.origin.y + frame.side / 2)
    }

    /// - Parameter idle: the stage has settled at rest and this is its last frame until something changes: the
    ///   peg's ring is drawn still rather than frozen mid-pulse.
    @ViewBuilder private func live(card: StageCard, size: CGSize, date: Date, idle: Bool = false) -> some View {
        let state = input()
        let key = shownAnchor(card, state).map { shownKey(card, state, anchor: $0) }
        let frame = motion.frame(picture: imageName, head: card.head, peg: key.flatMap { card.point("\($0).peg") },
                                 focus: state.focus, size: size, now: date.timeIntervalSinceReferenceDate, still: reduceMotion,
                                 centred: state.wholeHeadstock)
        ZStack {
            ZStack {
                picture(frame)
                Canvas { context, _ in draw(&context, card: card, frame: frame, date: date, idle: idle) }
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
            }
            // A zoomed picture melts into the screen at the stage's edges, as the 3D stage does.
            .mask { StageFeather(close: frame.close) }
            lockShimmer(card: card, key: key, state: state, frame: frame, date: date)
            pegLabel(card: card, frame: frame, size: size, date: date)
                .allowsHitTesting(false)
                .accessibilityHidden(true)
            pegTargets(card: card, frame: frame, size: size)
        }
    }

    /// The lock shimmer (`LockShimmer`) as the string being tuned locks: from its peg along the string, from the nut
    /// down, and across the head. The picture has no post, so the string's light starts at the peg.
    @ViewBuilder private func lockShimmer(card: StageCard, key: String?, state: StageInput, frame: StageFrame, date: Date) -> some View {
        let shimmer = flash.step(locked: state.listening && state.locked, key: key ?? "-", now: date.timeIntervalSinceReferenceDate,
                                 duration: LockShimmer.duration)
        if let shimmer, let key, ShaderFX.allowed(reduceMotion: reduceMotion), let peg = card.point("\(key).peg") {
            let nut = card.point("\(key).nut").map { frame.point($0) } ?? frame.point(peg)
            let saddle = card.point("\(key).saddle").map { frame.point($0) } ?? nut
            let head = card.head.map { CGRect(origin: frame.point($0.origin), size: CGSize(width: $0.width * frame.side, height: $0.height * frame.side)) }
            LockShimmer(peg: frame.point(peg), post: frame.point(peg), nut: nut, saddle: saddle, head: head, elapsed: shimmer)
        }
    }

    /// A 44-point tap target on every peg on screen (a close-up leaves some of them off it).
    private func pegTargets(card: StageCard, frame: StageFrame, size: CGSize) -> some View {
        let bounds = CGRect(origin: .zero, size: size)
        return ForEach(card.anchors, id: \.self) { anchor in
            if let peg = card.point("\(anchor).peg"), bounds.contains(frame.point(peg)) {
                Circle().fill(Color.white.opacity(0.001))
                    .frame(width: 44, height: 44)
                    .position(frame.point(peg))
                    .onTapGesture { onSelect(anchor) }
                    .accessibilityHidden(true)
            }
        }
    }

    /// The string the stage shows: the active one if the picture has it (a fifth string on a
    /// four-string photo gets no overlay), else the first.
    private func shownAnchor(_ card: StageCard, _ state: StageInput) -> String? {
        if let active = state.activeAnchor { return card.anchors.contains(active) ? active : nil }
        return card.anchors.first
    }

    /// The card points of the string being tuned: on a paired course whose card names each string
    /// ("c4a", "c4b"), that string's own; otherwise the anchor's.
    private func shownKey(_ card: StageCard, _ state: StageInput, anchor: String) -> String {
        guard state.activeAnchor == anchor, let peg = state.pegIndex, let letter = CourseGrouping.pegLetter(peg),
              card.anchors.contains(anchor + letter) else { return anchor }
        return anchor + letter
    }

    /// The note and turn cue beside the peg, on the side away from the headstock's centre line. Listening with
    /// nothing heard yet, it asks for the string ("Play G3").
    @ViewBuilder private func pegLabel(card: StageCard, frame: StageFrame, size: CGSize, date: Date) -> some View {
        let state = input()
        if let anchor = shownAnchor(card, state), let peg = card.point("\(shownKey(card, state, anchor: anchor)).peg") {
            let center = frame.point(peg)
            let cents = state.listening ? motion.cents : nil
            let calling = state.listening && state.cents == nil && !state.locked
            let turn = PegTurn.from(cents: cents, locked: state.locked, listening: state.listening,
                                    tighten: card.turns[anchor], slides: card.slides.contains(anchor))
            let gap: CGFloat = 30 + 4 * frame.close
            let side = PegLabel.side(for: center, preferred: peg.x < card.centerX ? -1 : 1, gap: gap, in: size,
                                     width: calling ? PegLabel.callWidth : 60)
            PegLabel(note: state.note, turn: turn, color: Palette.tuning(cents, locked: state.locked), prompt: calling,
                     nudge: turn.nudge(at: date.timeIntervalSinceReferenceDate, reduceMotion: reduceMotion))
                .placedBeside(center, side: side, gap: gap)
        }
    }

    private func draw(_ context: inout GraphicsContext, card: StageCard, frame: StageFrame, date: Date, idle: Bool) {
        let state = input()
        let now = date.timeIntervalSinceReferenceDate
        let (smoothed, phase, e, g) = motion.step(state, now: now)
        guard let anchor = shownAnchor(card, state) else { return }
        let key = shownKey(card, state, anchor: anchor)
        let still = reduceMotion || idle
        let color = Palette.tuning(smoothed, locked: state.locked)
        if let a = card.point("\(key).saddle"), let b = card.point("\(key).nut") {
            let p0 = frame.point(a)
            let p1 = frame.point(b)
            // The string only lights up while it rings (or holds the in-tune glow); a silent string stays the picture's own.
            let presence = max(g, min(1, e * 2.5))
            if state.listening, presence > 0.02 {
                StringDrawing.draw(&context, from: p0, to: p1, color: color, energy: e, glow: g, phase: phase, presence: presence, time: now, still: still)
            }
        }
        if let peg = card.point("\(key).peg") {
            let center = frame.point(peg)
            let pulse = 15 + 4 * Double(frame.close) + (still ? 0 : 5 * sin(now * 3) * (1 - g))
            let halo = pulse + 10
            context.fill(Path(ellipseIn: CGRect(x: center.x - halo, y: center.y - halo, width: halo * 2, height: halo * 2)), with: .color(color.opacity(0.10 + 0.12 * g)))
            context.stroke(Path(ellipseIn: CGRect(x: center.x - pulse, y: center.y - pulse, width: pulse * 2, height: pulse * 2)), with: .color(color.opacity(0.85)), lineWidth: 2)
            // Listening, nothing heard yet: a ring swells out of the peg and fades, the call to play it.
            if state.listening && state.cents == nil && !state.locked && !still {
                PegRing.drawCall(&context, at: center, radius: CGFloat(pulse), color: color, now: now)
            }
            if g > 0.05 {
                var check = Path()
                check.move(to: CGPoint(x: center.x - 6, y: center.y + 0.5))
                check.addLine(to: CGPoint(x: center.x - 1.5, y: center.y + 5))
                check.addLine(to: CGPoint(x: center.x + 7, y: center.y - 5))
                context.stroke(check, with: .color(color.opacity(g)), style: StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))
            } else {
                context.fill(Path(ellipseIn: CGRect(x: center.x - 4, y: center.y - 4, width: 8, height: 8)), with: .color(color))
            }
        }
    }
}

/// When a stage at rest may stop redrawing (`StudioStage.resting`, `StagePegCue.resting`): only once everything a
/// change set moving has come to rest.
enum StageSettle {
    /// Long enough for the dolly (about a second and a half), the glide to another peg and a fading glow to finish.
    static let window: Duration = .seconds(2.5)

    /// What, changing at rest, sets the stage moving again: the picture or model, the close-up, the string and peg
    /// being tuned, and the stage's size.
    static func key(_ state: StageInput, picture: String, size: CGSize) -> String {
        "\(picture)|\(state.focus)|\(state.activeAnchor ?? "-")|\(state.pegIndex ?? -1)|\(Int(size.width))x\(Int(size.height))"
    }
}

/// Where a 2D stage draws its picture: the square the picture is fitted into, `side` points wide with its top-left
/// corner at `origin`, and how far the close-up has come (0 the whole picture, 1 the headstock).
struct StageFrame {
    var side: CGFloat
    var origin: CGPoint
    var close: CGFloat = 0

    /// A card point (normalised to the square) in the stage's points.
    func point(_ p: CGPoint) -> CGPoint { CGPoint(x: origin.x + p.x * side, y: origin.y + p.y * side) }

    /// Close-up clearances in points, as on the 3D stage: the pegs stay this far below the top (room for the ring),
    /// the nut this far above the bottom, and the head centres in the room left of the side controls.
    static let pegClearance: CGFloat = 48
    static let nutClearance: CGFloat = 30
    static let controlsInset: CGFloat = 26
    /// Studio renders and photographs turn soft past about twice their fitted size.
    static let maxZoom: CGFloat = 2
    /// The wood above the top pegs, as a share of the head box (pegs to nut): a centred close-up keeps it in frame.
    static let tipShare: CGFloat = 0.35

    static func whole(in size: CGSize) -> StageFrame {
        let side = max(0, min(size.width, size.height))
        return StageFrame(side: side, origin: CGPoint(x: (size.width - side) / 2, y: (size.height - side) / 2))
    }

    /// `framing` of the way from the whole picture to its headstock close-up, zoomed toward `aim` (a card point).
    /// The close-up zooms as far as the head fits (at most `maxZoom`) and lifts the head to just under the top
    /// clearance, so the neck runs down the stage below it (the 3D close-up's layout), keeping the nut clear of the
    /// bottom. On the way the picture zooms about one fixed point: the aim travels to its spot in step with the
    /// zoom, which grows geometrically (an even apparent dolly). `centred` (the iPad, `StageInput.wholeHeadstock`):
    /// the head centres across the stage, and the wood above its pegs stays clear of the feathered top.
    static func closeUp(in size: CGSize, head: CGRect, aim: CGPoint, framing: Double, centred: Bool = false) -> StageFrame {
        let base = Self.whole(in: size)
        let f = CGFloat(max(0, min(1, framing)))
        guard f > 0.0005, base.side > 1 else { return base }
        let tipRoom = centred ? head.height * tipShare : 0
        let edge = 0.06 * size.height + 10
        var fitV = (size.height - pegClearance - nutClearance) / max(head.height * base.side, 1)
        if centred { fitV = min(fitV, (size.height - edge - nutClearance) / max((head.height + tipRoom) * base.side, 1)) }
        let fitH = (size.width - 160) / max(head.width * base.side, 1)
        let zoom = min(maxZoom, fitV, fitH)
        guard zoom > 1.05 else { return base }
        let full = base.side * zoom
        var lowest = pegClearance - (head.minY - aim.y) * full
        if centred { lowest = max(lowest, edge - (head.minY - tipRoom - aim.y) * full) }
        let highest = size.height - nutClearance - (head.maxY - aim.y) * full
        let spot = CGPoint(x: size.width / 2 - (centred ? 0 : controlsInset), y: min(lowest + 16, max(lowest, highest)))
        let current = CGFloat(pow(Double(zoom), Double(f)))
        let progress = (current - 1) / (zoom - 1)
        let start = base.point(aim)
        let at = CGPoint(x: start.x + (spot.x - start.x) * progress, y: start.y + (spot.y - start.y) * progress)
        let side = base.side * current
        return StageFrame(side: side, origin: CGPoint(x: at.x - aim.x * side, y: at.y - aim.y * side), close: f)
    }
}

/// The stage's frame: its edges feathered so the picture (or the 3D render) melts into the screen. Whole (`close`
/// 0), it reaches past the stage and clips nothing, not even the picture's shadow; it closes in as the dolly does.
struct StageFeather: View {
    let close: CGFloat

    var body: some View {
        let edge: [Gradient.Stop] = [.init(color: .clear, location: 0), .init(color: .black, location: 0.06),
                                     .init(color: .black, location: 0.94), .init(color: .clear, location: 1)]
        LinearGradient(stops: edge, startPoint: .top, endPoint: .bottom)
            .mask(LinearGradient(stops: edge, startPoint: .leading, endPoint: .trailing))
            .padding(-56 * CGFloat(pow(Double(1 - max(0, min(1, close))), 4)))
    }
}

/// The live string on a 2D picture, drawn along the string's own saddle and nut points: a thin bright core,
/// the soft blur of its swing (widest mid-string, as a real vibrating string looks), and strobe dashes that
/// travel along it with the pitch error and stand still in tune. Locked, it glows as a lit string.
enum StringDrawing {
    static func draw(_ context: inout GraphicsContext, from p0: CGPoint, to p1: CGPoint, color: Color,
                     energy e: Double, glow g: Double, phase: Double, presence: Double, time now: Double, still: Bool) {
        let dx = p1.x - p0.x, dy = p1.y - p0.y
        let length = max(1, sqrt(dx * dx + dy * dy))
        let normal = CGPoint(x: -dy / length, y: dx / length)
        // Half-width of the swing in points: a few points at most, calming as the string locks.
        let swing: Double = still ? 0 : (0.5 + 2.6 * e) * (1 - 0.85 * g)
        let segments = 40
        func point(_ u: Double, _ offset: Double) -> CGPoint {
            CGPoint(x: p0.x + dx * u + normal.x * offset, y: p0.y + dy * u + normal.y * offset)
        }
        if swing > 0.2 {
            // The blur of the swing: a lens between the string's two extremes.
            var lens = Path()
            for i in 0...segments {
                let u = Double(i) / Double(segments)
                let p = point(u, swing * sin(.pi * u))
                if i == 0 { lens.move(to: p) } else { lens.addLine(to: p) }
            }
            for i in stride(from: segments, through: 0, by: -1) {
                let u = Double(i) / Double(segments)
                lens.addLine(to: point(u, -swing * sin(.pi * u)))
            }
            lens.closeSubpath()
            context.fill(lens, with: .color(color.opacity(0.22 * presence)))
        }
        // The core at this instant: the fundamental's shape, swinging inside the lens.
        let instant = swing * 0.8 * sin(2 * .pi * 6.5 * now)
        var core = Path()
        for i in 0...segments {
            let u = Double(i) / Double(segments)
            let p = point(u, instant * sin(.pi * u))
            if i == 0 { core.move(to: p) } else { core.addLine(to: p) }
        }
        if g > 0.02 {
            context.stroke(core, with: .color(color.opacity(0.35 * g * presence)), style: StrokeStyle(lineWidth: 3 + 4 * g, lineCap: .round))
        }
        context.stroke(core, with: .color(Color.white.opacity(0.8 * presence)), style: StrokeStyle(lineWidth: 1.2 + 0.6 * g, lineCap: .round))
        // Strobe dashes: drift toward the headstock when sharp, toward the bridge when flat, still in tune
        // (and with Reduce Motion, where the colour alone follows the pitch).
        let period: CGFloat = 14
        let dashes = StrokeStyle(lineWidth: 2, lineCap: .round, dash: [4, period - 4], dashPhase: still ? 0 : -CGFloat(phase) * period)
        context.stroke(core, with: .color(color.opacity(0.9 * presence * (1 - 0.6 * g))), style: dashes)
    }
}

/// Animation state for the 2D stage. A plain class so per-frame updates never
/// trigger SwiftUI invalidation.
final class Motion2D {
    private var filter = ReadoutMotion.makeFilter()
    /// The close-up dolly: 0 shows the whole picture, 1 its headstock (a critically damped spring, as on the 3D stage).
    private var framing = 0.0
    private var framingVelocity = 0.0
    /// The card point the close-up zooms toward, easing to the peg being tuned when the string changes.
    private var aim: CGPoint?
    private var framedAt = 0.0
    private var picture = ""
    /// Dolly stiffness (rad/s), the 3D stage's: about a second from the whole picture to the headstock.
    private static let stiffness = 4.2
    private var strobe = StrobePhase(bandsPerSecondPerCent: 0.07)
    private var last: Double = 0
    private var energy = 0.0
    private var glow = 0.0
    /// The last smoothed cents, for the peg label (nil with no pitch).
    private(set) var cents: Double?
    func step(_ state: StageInput, now: Double) -> (Double?, Double, Double, Double) {
        let dt = last == 0 ? 1.0 / 60 : min(0.1, max(0, now - last))
        last = now
        let target = state.listening ? max(0, min(1, (state.level + 58) / 34)) : 0
        energy = max(target, energy * exp(-dt * 1.4))
        glow += ((state.locked ? 1 : 0) - glow) * min(1, dt * (state.locked ? 7 : 2.5))
        let smoothed = state.cents.map { filter.filter(max(-60, min(60, $0)), at: now) }
        if smoothed == nil { filter.reset() }
        cents = state.listening ? smoothed : nil
        let phase = strobe.advance(cents: state.locked ? 0 : smoothed, dt: dt)
        return (smoothed, phase, energy, glow)
    }

    /// Advances the dolly to `now` and says where the picture sits. A new picture starts whole and dollies in
    /// (the 3D stage's dolly, so a 3D model taking over from its placeholder meets it on the way); `still`
    /// (Reduce Motion) cuts straight to the framing. `centred` (an iPad-sized window) aims at the head's centre line
    /// and centres it across the stage (`StageFrame.closeUp`).
    func frame(picture name: String, head: CGRect?, peg: CGPoint?, focus: Bool, size: CGSize, now: Double, still: Bool,
               centred: Bool = false) -> StageFrame {
        if name != picture {
            picture = name
            framing = 0; framingVelocity = 0; aim = nil; framedAt = 0
        }
        let dt = framedAt == 0 ? 0 : min(0.25, max(0, now - framedAt))
        framedAt = now
        guard let head else { return StageFrame.whole(in: size) }
        let goal: Double = focus ? 1 : 0
        if still { framing = goal; framingVelocity = 0 } else { advanceDolly(toward: goal, dt: dt) }
        // Between the head's centre and the peg being tuned, as the 3D close-up aims.
        let center = CGPoint(x: head.midX, y: head.midY)
        let lean: CGFloat = centred ? 0 : 0.35
        let target = peg.map { CGPoint(x: center.x + ($0.x - center.x) * lean, y: center.y + ($0.y - center.y) * 0.35) } ?? center
        if let current = aim, !still {
            let k = CGFloat(min(1, dt * 3))
            aim = CGPoint(x: current.x + (target.x - current.x) * k, y: current.y + (target.y - current.y) * k)
        } else {
            aim = target
        }
        return StageFrame.closeUp(in: size, head: head, aim: aim ?? target, framing: framing, centred: centred)
    }

    private func advanceDolly(toward goal: Double, dt: Double) {
        let omega = Self.stiffness
        var remaining = dt
        while remaining > 0 {
            let h = min(remaining, 1.0 / 120)
            framingVelocity += (omega * omega * (goal - framing) - 2 * omega * framingVelocity) * h
            framing += framingVelocity * h
            remaining -= h
        }
        if framing < 0 || framing > 1 { framing = max(0, min(1, framing)); framingVelocity = 0 }
    }
}
