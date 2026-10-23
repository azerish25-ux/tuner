import SwiftUI
import TimbreCore

/// 2D stage built on the studio render. Used when real-time 3D is unavailable or turned
/// off, and for instruments whose 3D model is still to come. With rig data it draws the
/// live string (drifting strobe ripple, frozen in tune) and a glowing peg on the render.
struct StudioStage: View {
    let imageName: String
    let rig: InstrumentRig?
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
                if let rig {
                    TimelineView(.animation(paused: reduceMotion)) { timeline in
                        Canvas { context, _ in draw(&context, rig: rig, side: side, origin: origin, date: timeline.date) }
                    }
                    .allowsHitTesting(false)
                    ForEach(rig.strings, id: \.anchor) { string in
                        if let peg = rig.card("\(string.anchor).peg") {
                            Circle().fill(Color.white.opacity(0.001))
                                .frame(width: 44, height: 44)
                                .position(x: origin.x + peg.x * side, y: origin.y + peg.y * side)
                                .onTapGesture { onSelect(string.anchor) }
                                .accessibilityHidden(true)
                        }
                    }
                }
            }
        }
    }

    private func draw(_ context: inout GraphicsContext, rig: InstrumentRig, side: CGFloat, origin: CGPoint, date: Date) {
        let state = input()
        let now = date.timeIntervalSinceReferenceDate
        let (smoothed, phase, e, g) = motion.step(state, now: now)
        guard let anchor = state.activeAnchor ?? rig.strings.first?.anchor,
              let a = rig.card("\(anchor).saddle"), let b = rig.card("\(anchor).nut") else { return }
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
        let color = Palette.pitch(smoothed, locked: state.locked)
        // The string only lights up while it rings (or holds the in-tune glow); a silent string stays the render's own.
        let presence = max(g, min(1, e * 2.5))
        if state.listening, presence > 0.02 {
            context.stroke(path, with: .color(color.opacity((0.25 + 0.35 * g) * presence)), style: StrokeStyle(lineWidth: 7 + 10 * g, lineCap: .round))
            context.stroke(path, with: .color(Color.white.opacity(0.85 * presence)), style: StrokeStyle(lineWidth: 1.4 + g, lineCap: .round))
        }
        if let peg = rig.card("\(anchor).peg") {
            let center = CGPoint(x: origin.x + peg.x * side, y: origin.y + peg.y * side)
            let pulse = 14 + 6 * sin(now * 3)
            let ring = Path(ellipseIn: CGRect(x: center.x - pulse, y: center.y - pulse, width: pulse * 2, height: pulse * 2))
            context.stroke(ring, with: .color(color.opacity(0.75)), lineWidth: 2)
            context.fill(Path(ellipseIn: CGRect(x: center.x - 4, y: center.y - 4, width: 8, height: 8)), with: .color(color))
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
