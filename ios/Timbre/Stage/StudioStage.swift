import SwiftUI
import TimbreCore

/// Points on a 2D picture (studio render or photograph) that the 2D stage animates, normalised
/// to the square the picture is fitted into: "<anchor>.nut", "<anchor>.saddle" (a string's
/// speaking length) and "<anchor>.peg" (where the player tunes it).
struct StageCard: Sendable {
    let anchors: [String]
    let points: [String: CGPoint]
    /// Each string's turn sign from its 3D rig (+1: clockwise tightens); empty for photographs,
    /// which then show no turn arrow rather than a guessed one.
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
/// with the note and turn cue beside it. Colours follow the tuner's rule; Reduce Motion stills the
/// pulse and the ripple while the colours keep following the pitch.
struct StudioStage: View {
    let imageName: String
    let card: StageCard?
    let input: () -> StageInput
    var onSelect: (String) -> Void = { _ in }
    @State private var motion = Motion2D()
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        GeometryReader { geometry in
            let side = min(geometry.size.width, geometry.size.height)
            let size = geometry.size
            let origin = CGPoint(x: (geometry.size.width - side) / 2, y: (geometry.size.height - side) / 2)
            ZStack {
                Image(imageName).resizable().interpolation(.high).scaledToFit()
                    .frame(width: side, height: side)
                    .shadow(color: .black.opacity(0.55), radius: 30, y: 18)
                    .position(x: geometry.size.width / 2, y: geometry.size.height / 2)
                if let card {
                    TimelineView(.animation(minimumInterval: reduceMotion ? 0.1 : nil)) { timeline in
                        ZStack {
                            Canvas { context, _ in draw(&context, card: card, side: side, origin: origin, date: timeline.date) }
                            pegLabel(card: card, square: side, origin: origin, size: size, date: timeline.date)
                        }
                    }
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
                    ForEach(card.anchors, id: \.self) { anchor in
                        if let peg = card.point("\(anchor).peg") {
                            Circle().fill(Color.white.opacity(0.001))
                                .frame(width: 44, height: 44)
                                .position(x: origin.x + peg.x * side, y: origin.y + peg.y * side)
                                .onTapGesture { onSelect(anchor) }
                                .accessibilityHidden(true)
                        }
                    }
                }
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

    /// The note and turn cue beside the peg, on the side away from the headstock's centre line.
    @ViewBuilder private func pegLabel(card: StageCard, square: CGFloat, origin: CGPoint, size: CGSize, date: Date) -> some View {
        let state = input()
        if let anchor = shownAnchor(card, state), let peg = card.point("\(shownKey(card, state, anchor: anchor)).peg") {
            let center = CGPoint(x: origin.x + peg.x * square, y: origin.y + peg.y * square)
            let cents = state.listening ? motion.cents : nil
            let turn = PegTurn.from(cents: cents, locked: state.locked, listening: state.listening,
                                    tighten: card.turns[anchor], slides: card.slides.contains(anchor))
            let gap: CGFloat = 30
            let side = PegLabel.side(for: center, preferred: peg.x < card.centerX ? -1 : 1, gap: gap, in: size)
            PegLabel(note: state.note, turn: turn, color: Palette.tuning(cents, locked: state.locked),
                     nudge: turn.nudge(at: date.timeIntervalSinceReferenceDate, reduceMotion: reduceMotion))
                .placedBeside(center, side: side, gap: gap)
        }
    }

    private func draw(_ context: inout GraphicsContext, card: StageCard, side: CGFloat, origin: CGPoint, date: Date) {
        let state = input()
        let now = date.timeIntervalSinceReferenceDate
        let (smoothed, phase, e, g) = motion.step(state, now: now)
        guard let anchor = shownAnchor(card, state) else { return }
        let key = shownKey(card, state, anchor: anchor)
        let still = reduceMotion
        let color = Palette.tuning(smoothed, locked: state.locked)
        if let a = card.point("\(key).saddle"), let b = card.point("\(key).nut") {
            let p0 = CGPoint(x: origin.x + a.x * side, y: origin.y + a.y * side)
            let p1 = CGPoint(x: origin.x + b.x * side, y: origin.y + b.y * side)
            // The string only lights up while it rings (or holds the in-tune glow); a silent string stays the picture's own.
            let presence = max(g, min(1, e * 2.5))
            if state.listening, presence > 0.02 {
                StringDrawing.draw(&context, from: p0, to: p1, color: color, energy: e, glow: g, phase: phase, presence: presence, time: now, still: still)
            }
        }
        if let peg = card.point("\(key).peg") {
            let center = CGPoint(x: origin.x + peg.x * side, y: origin.y + peg.y * side)
            let pulse = 15 + (still ? 0 : 5 * sin(now * 3) * (1 - g))
            let halo = pulse + 10
            context.fill(Path(ellipseIn: CGRect(x: center.x - halo, y: center.y - halo, width: halo * 2, height: halo * 2)), with: .color(color.opacity(0.10 + 0.12 * g)))
            context.stroke(Path(ellipseIn: CGRect(x: center.x - pulse, y: center.y - pulse, width: pulse * 2, height: pulse * 2)), with: .color(color.opacity(0.85)), lineWidth: 2)
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
}
