import SwiftUI
import TimbreCore

/// Chromatic mode: a strobe disc. Its rings turn in proportion to the pitch error
/// (inner ring = fundamental, outer rings = finer views) and stop when in tune. The rings show finer
/// detail than the digits, but their colour follows the tuner's one rule (mint in the lock band, amber, coral).
/// With Reduce Motion the rings hold still and only the colour follows the pitch.
struct ChromaticStage: View {
    let input: () -> StageInput
    let note: String
    @State private var motion = ReadoutMotion()
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var body: some View {
        TimelineView(.animation(minimumInterval: reduceMotion ? 0.1 : nil)) { timeline in
            let state = input()
            let _ = motion.step(state.listening ? state.cents : nil, locked: state.locked, now: timeline.date.timeIntervalSinceReferenceDate)
            Canvas { context, size in
                let side = min(size.width, size.height) * 0.86
                let center = CGPoint(x: size.width / 2, y: size.height / 2)
                let color = Palette.tuning(motion.cents, locked: state.locked)
                let rings: [(radius: CGFloat, count: Int, speed: Double)] = [(0.5, 48, 1), (0.43, 36, 0.5), (0.36, 24, 0.25)]
                for (index, ring) in rings.enumerated() {
                    let r = side * ring.radius
                    let width = side * 0.045
                    for segment in 0..<ring.count {
                        let direction: Double = index.isMultiple(of: 2) ? 1 : -1
                        let spin: Double = reduceMotion ? 0 : motion.phase * 2 * Double.pi * ring.speed * direction * 0.25
                        let start: Double = Double(segment) / Double(ring.count) * 2 * Double.pi + spin
                        let end = start + .pi / Double(ring.count)
                        var arc = Path()
                        arc.addArc(center: center, radius: r, startAngle: .radians(start), endAngle: .radians(end), clockwise: false)
                        let lift = 0.5 + 0.5 * cos(start + .pi / 2)
                        context.stroke(arc, with: .color(color.opacity(state.listening ? 0.25 + 0.6 * lift : 0.12)), lineWidth: width)
                    }
                }
                let tick = Path(roundedRect: CGRect(x: center.x - 2, y: center.y - side * 0.56, width: 4, height: side * 0.06), cornerRadius: 2)
                context.fill(tick, with: .color(Palette.ink))
                if state.locked {
                    context.fill(Path(ellipseIn: CGRect(x: center.x - side * 0.3, y: center.y - side * 0.3, width: side * 0.6, height: side * 0.6)),
                                 with: .radialGradient(Gradient(colors: [Palette.locked.opacity(0.28), .clear]), center: center, startRadius: 0, endRadius: side * 0.3))
                }
            }
        }
        .overlay {
            Text(NoteReadout.split(note).name).font(Typeface.display(64)).foregroundStyle(Palette.inkSoft.opacity(0.35))
        }
        .accessibilityHidden(true)
    }
}
