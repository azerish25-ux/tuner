import SwiftUI
import TimbreCore

/// Points on a 2D picture (studio render or photograph) that the 2D stage animates, normalised
/// to the square the picture is fitted into: "<anchor>.nut", "<anchor>.saddle" (a string's
/// speaking length) and "<anchor>.peg" (where the player tunes it).
struct StageCard: Sendable {
    let anchors: [String]
    let points: [String: CGPoint]
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
    }
}

/// 2D stage on a studio render or photograph. Used when real-time 3D is unavailable or turned
/// off, and for instruments without a 3D model. With card points it draws the live string
/// (strobe ripple that freezes in tune) and a glowing ring on the peg, which checks off in tune.
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
            let origin = CGPoint(x: (geometry.size.width - side) / 2, y: (geometry.size.height - side) / 2)
            ZStack {
                Image(imageName).resizable().interpolation(.high).scaledToFit()
                    .frame(width: side, height: side)
                    .shadow(color: .black.opacity(0.55), radius: 30, y: 18)
                    .position(x: geometry.size.width / 2, y: geometry.size.height / 2)
                if let card {
                    TimelineView(.animation(paused: reduceMotion)) { timeline in
                        Canvas { context, _ in draw(&context, card: card, side: side, origin: origin, date: timeline.date) }
                    }
                    .allowsHitTesting(false)
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

    private func draw(_ context: inout GraphicsContext, card: StageCard, side: CGFloat, origin: CGPoint, date: Date) {
        let state = input()
        let now = date.timeIntervalSinceReferenceDate
        let (smoothed, phase, e, g) = motion.step(state, now: now)
        guard let anchor = state.activeAnchor.flatMap({ card.anchors.contains($0) ? $0 : nil }) ?? card.anchors.first else { return }
        let color = Palette.pitch(smoothed, locked: state.locked)
        if let a = card.point("\(anchor).saddle"), let b = card.point("\(anchor).nut") {
            let p0 = CGPoint(x: origin.x + a.x * side, y: origin.y + a.y * side)
            let p1 = CGPoint(x: origin.x + b.x * side, y: origin.y + b.y * side)
            let dx = p1.x - p0.x, dy = p1.y - p0.y
            let length = max(1, sqrt(dx * dx + dy * dy))
            let normal = CGPoint(x: -dy / length, y: dx / length)
            let amplitude = (1.2 + 5.5 * e) * (1 - 0.85 * g)
            var path = Path()
            for i in 0...64 {
                let u = Double(i) / 64
                let envelope = sin(.pi * u)
                let standing = sin(2 * .pi * 1.7 * now) * envelope + 0.3 * sin(2 * .pi * u) * sin(2 * .pi * 3.4 * now)
                let ripple = 0.55 * sin(2 * .pi * (u * 7 - phase)) * envelope
                let offset = amplitude * (standing * (1 - g) + ripple)
                let point = CGPoint(x: p0.x + dx * u + normal.x * offset, y: p0.y + dy * u + normal.y * offset)
                if i == 0 { path.move(to: point) } else { path.addLine(to: point) }
            }
            // The string only lights up while it rings (or holds the in-tune glow); a silent string stays the picture's own.
            let presence = max(g, min(1, e * 2.5))
            if state.listening, presence > 0.02 {
                context.stroke(path, with: .color(color.opacity((0.25 + 0.35 * g) * presence)), style: StrokeStyle(lineWidth: 7 + 10 * g, lineCap: .round))
                context.stroke(path, with: .color(Color.white.opacity(0.85 * presence)), style: StrokeStyle(lineWidth: 1.4 + g, lineCap: .round))
            }
        }
        if let peg = card.point("\(anchor).peg") {
            let center = CGPoint(x: origin.x + peg.x * side, y: origin.y + peg.y * side)
            let pulse = 15 + 5 * sin(now * 3) * (1 - g)
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

/// Animation state for the 2D stage. A plain class so per-frame updates never
/// trigger SwiftUI invalidation.
final class Motion2D {
    private var filter = OneEuroFilter(minCutoff: 1.1, beta: 0.02)
    private var strobe = StrobePhase(bandsPerSecondPerCent: 0.07)
    private var last: Double = 0
    private var energy = 0.0
    private var glow = 0.0
    func step(_ state: StageInput, now: Double) -> (Double?, Double, Double, Double) {
        let dt = last == 0 ? 1.0 / 60 : min(0.1, max(0, now - last))
        last = now
        let target = state.listening ? max(0, min(1, (state.level + 58) / 34)) : 0
        energy = max(target, energy * exp(-dt * 1.4))
        glow += ((state.locked ? 1 : 0) - glow) * min(1, dt * (state.locked ? 7 : 2.5))
        let smoothed = state.cents.map { filter.filter(max(-60, min(60, $0)), at: now) }
        if smoothed == nil { filter.reset() }
        let phase = strobe.advance(cents: state.locked ? 0 : smoothed, dt: dt)
        return (smoothed, phase, energy, glow)
    }
}
