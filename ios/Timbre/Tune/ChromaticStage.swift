import SwiftUI
import TimbreCore

/// Chromatic mode: a strobe disc. Its rings turn in proportion to the pitch error
/// (inner ring = fundamental, outer rings = finer views) and stop when in tune. The rings show finer
/// detail than the digits, but their colour follows the tuner's one rule (mint in the lock band, amber, coral).
/// With Reduce Motion the rings hold still and only the colour follows the pitch.
struct ChromaticStage: View {
    let input: () -> StageInput
    let note: String
    /// The host isn't listening and holds no reading: with no pitch the rings stand still, so the disc draws once
    /// and stops redrawing until the host listens again.
    var resting = false
    @State private var motion = ReadoutMotion()
    /// The moment the pitch locks, for the ring of light it sends across the disc.
    @State private var flash = LockFlash()
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var body: some View {
        TimelineView(.animation(minimumInterval: reduceMotion ? 0.1 : nil, paused: resting)) { timeline in
            let state = input()
            let now = timeline.date.timeIntervalSinceReferenceDate
            let _ = motion.step(state.listening ? state.cents : nil, locked: state.locked, now: now)
            let shock = flash.step(locked: state.listening && state.locked, key: "chromatic", now: now, duration: StrobeRipple.shock)
            // The disc ripples as deep as the pitch is far off (full at 20¢), and stands still in tune.
            let depth = state.listening && !state.locked ? min(1, abs(motion.cents ?? 0) / 20) : 0
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
                if state.locked {
                    context.fill(Path(ellipseIn: CGRect(x: center.x - side * 0.3, y: center.y - side * 0.3, width: side * 0.6, height: side * 0.6)),
                                 with: .radialGradient(Gradient(colors: [Palette.locked.opacity(0.28), .clear]), center: center, startRadius: 0, endRadius: side * 0.3))
                }
            }
            // The rings as a liquid surface (Shaders.metal): ripples out when sharp, in when flat, a ring of light on the lock.
            .strobeRipple(phase: motion.phase, depth: depth, shock: shock, enabled: ShaderFX.allowed(reduceMotion: reduceMotion))
        }
        .overlay {
            // The reference tick stays still over the rippling rings.
            Canvas { context, size in
                let side = min(size.width, size.height) * 0.86
                let tick = Path(roundedRect: CGRect(x: size.width / 2 - 2, y: size.height / 2 - side * 0.56, width: 4, height: side * 0.06), cornerRadius: 2)
                context.fill(tick, with: .color(Palette.ink))
            }
        }
        .overlay {
            Text(NoteReadout.split(note).name).font(Typeface.display(64)).foregroundStyle(Palette.inkSoft.opacity(0.35))
        }
        .accessibilityHidden(true)
    }
}
