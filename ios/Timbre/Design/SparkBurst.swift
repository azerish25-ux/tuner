import SwiftUI

/// The reward burst: a string's harmonics made visible. Rings leave the centre and land at a quarter, a third, a half
/// and the whole of their reach (the nodes of a vibrating string), each ring trembling in its own mode (2, 3, 4 and 5
/// lobes) and coming to rest as it lands, its nodes holding still the whole time, then the set fades. The tuner's
/// language (a string that vibrates, then stands still) used for every right answer, star and milestone.
/// Place it behind text: it is decoration. Under Reduce Motion the rings appear already landed and only fade.
struct SparkBurst: View {
    let trigger: Int
    var color: Color = Palette.mint
    /// How far the rings travel: the outer ring lands this far out (160 pt when nil).
    var reach: CGFloat?
    /// Where they start: 0 the centre, 1 the edge of the frame (a shockwave leaving a ring or a card).
    var startFraction: CGFloat = 0
    /// The outer ring; off where it would cross nearby text (the inner rings and every ring's nodes stay).
    var ring = true
    @State private var started = Date.distantPast
    /// A burst is in the air: the timeline only runs for its moment, so an idle burst (most of the time, on most
    /// screens) costs nothing and doesn't hold the display at its full rate.
    @State private var live = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// How long a burst lasts.
    static let duration = 0.95

    /// Where each ring lands, as a share of the reach, and the mode it trembles in.
    private static let harmonics: [(share: Double, lobes: Int)] = [(0.25, 5), (1.0 / 3, 4), (0.5, 3), (1, 2)]

    var body: some View {
        TimelineView(.animation(paused: !live)) { timeline in
            let t = timeline.date.timeIntervalSince(started)
            Canvas { context, size in draw(&context, size: size, t: t) }
        }
        .allowsHitTesting(false)
        .onChange(of: trigger) { _, _ in
            let launched = Date()
            started = launched
            live = true
            Task { @MainActor in
                try? await Task.sleep(for: .seconds(Self.duration + 0.05))
                // A later burst keeps the timeline running for its own moment.
                if started == launched { live = false }
            }
        }
        .accessibilityHidden(true)
    }

    private func draw(_ context: inout GraphicsContext, size: CGSize, t: Double) {
        guard t >= 0, t < Self.duration else { return }
        let center = CGPoint(x: size.width / 2, y: size.height / 2)
        let origin = Double(min(size.width, size.height) / 2 * startFraction)
        let span = Double(reach ?? 160)
        let still = reduceMotion
        // The set fades over its second half; landed and still under Reduce Motion, it only fades.
        let fade = still ? max(0, 1 - t / Self.duration) : min(1, max(0, (Self.duration - t) / (Self.duration * 0.55)))
        let turn = Double(trigger) * 0.37
        for (index, harmonic) in Self.harmonics.enumerated() {
            let outer = index == Self.harmonics.count - 1
            // Each ring sets off a moment after the one inside it.
            let local = max(0, t - Double(index) * 0.035)
            let travel = still ? 1 : Self.landing(local / 0.42)
            let radius = origin + span * harmonic.share * travel
            guard radius > 1 else { continue }
            let swing = still ? 0 : Self.tremble(local) * span * 0.035 * (1 + harmonic.share)
            // The outer ring in the burst's colour, the inner ones alternating with the rewards' gold.
            let tint: Color = outer || index % 2 == 0 ? color : Palette.starGold
            if ring || !outer {
                let path = Self.ringPath(center: center, radius: radius, lobes: harmonic.lobes, amplitude: swing,
                                         phase: local, turn: turn)
                context.stroke(path, with: .color(tint.opacity(0.75 * fade)), lineWidth: outer ? 2 : 1.5)
            }
            drawNodes(&context, center: center, radius: radius, lobes: harmonic.lobes, turn: turn,
                      tint: tint, alpha: fade, size: outer ? 2.6 : 2)
        }
    }

    /// The nodes of a ring's mode: the points that never move while the ring trembles, lit as small beads.
    private func drawNodes(_ context: inout GraphicsContext, center: CGPoint, radius: Double, lobes: Int, turn: Double,
                           tint: Color, alpha: Double, size: Double) {
        let count = 2 * lobes
        for node in 0..<count {
            let angle = Double(node) * .pi / Double(lobes) + turn
            let point = CGPoint(x: center.x + CGFloat(cos(angle) * radius), y: center.y + CGFloat(sin(angle) * radius))
            let r = CGFloat(size)
            context.fill(Path(ellipseIn: CGRect(x: point.x - r, y: point.y - r, width: r * 2, height: r * 2)),
                         with: .color(tint.opacity(alpha)))
        }
    }

    /// A ring trembling in `lobes` lobes: its radius swings by `amplitude` between the nodes, at about nine cycles a
    /// second, while the nodes (where the sine crosses zero) hold still.
    private static func ringPath(center: CGPoint, radius: Double, lobes: Int, amplitude: Double, phase: Double, turn: Double) -> Path {
        var path = Path()
        let steps = 96
        let swing = cos(2 * .pi * 9 * phase)
        for step in 0...steps {
            let angle = Double(step) / Double(steps) * 2 * .pi
            let r = radius + amplitude * swing * sin(Double(lobes) * (angle - turn))
            let point = CGPoint(x: center.x + CGFloat(cos(angle) * r), y: center.y + CGFloat(sin(angle) * r))
            if step == 0 { path.move(to: point) } else { path.addLine(to: point) }
        }
        path.closeSubpath()
        return path
    }

    /// 0 → 1, fast at first, with a small overshoot that settles, as a string's swing does (x: 0 at launch, about
    /// 1 as it lands).
    private static func landing(_ x: Double) -> Double {
        let p = max(0, x)
        return 1 - exp(-6 * p) * cos(5 * p)
    }

    /// How hard a ring trembles: struck at launch, gone by the time it has landed and held a beat.
    private static func tremble(_ t: Double) -> Double { exp(-t / 0.22) }
}
