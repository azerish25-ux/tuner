import SwiftUI

/// A burst of sparks for right answers and hit notes. Place it behind text: it is decoration.
struct SparkBurst: View {
    private func draw(_ context: inout GraphicsContext, size: CGSize, t: Double) {
        guard t < 0.9 else { return }
        let center = CGPoint(x: size.width / 2, y: size.height / 2)
        let fade = 1 - t / 0.9
        // Sparks and ring leave from `startFraction` of the half-size, and travel `reach` (160 pt by default).
        let origin = Double(min(size.width, size.height) / 2 * startFraction)
        let scale = Double((reach ?? 160) / 160)
        for i in 0..<22 {
            let angle: Double = Double(i) / 22 * 2 * .pi + Double(trigger) * 0.37
            let speed: Double = (90 + Double((i * 37) % 60)) * scale
            let d: Double = origin + speed * t * (1 - t / 1.8)
            let p = CGPoint(x: center.x + CGFloat(cos(angle) * d), y: center.y + CGFloat(sin(angle) * d))
            let r = CGFloat(3.2 * fade)
            let tint: Color = i % 3 == 0 ? Palette.amber : color
            context.fill(Path(ellipseIn: CGRect(x: p.x - r, y: p.y - r, width: r * 2, height: r * 2)), with: .color(tint.opacity(fade)))
        }
        guard ring else { return }
        let radius = CGFloat(origin + (20 + 160 * t) * scale)
        let ringRect = CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2)
        context.stroke(Path(ellipseIn: ringRect), with: .color(color.opacity(max(0, 0.5 - t * 0.6))), lineWidth: 2)
    }

    let trigger: Int
    var color: Color = Palette.mint
    /// How far sparks and the ring travel (160 pt when nil).
    var reach: CGFloat?
    /// Where they start: 0 the centre, 1 the edge of the frame (a shockwave leaving a ring or a card).
    var startFraction: CGFloat = 0
    /// The expanding ring; off where it would cross nearby text.
    var ring = true
    @State private var started = Date.distantPast
    /// A burst is in the air: the timeline only runs for its 0.9 s, so an idle burst (most of the time, on most
    /// screens) costs nothing and doesn't hold the display at its full rate.
    @State private var live = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        TimelineView(.animation(paused: reduceMotion || !live)) { timeline in
            let t = timeline.date.timeIntervalSince(started)
            Canvas { context, size in draw(&context, size: size, t: t) }
        }
        .allowsHitTesting(false)
        .onChange(of: trigger) { _, _ in
            let launched = Date()
            started = launched
            live = true
            Task { @MainActor in
                try? await Task.sleep(for: .seconds(0.95))
                // A later burst keeps the timeline running for its own 0.9 s.
                if started == launched { live = false }
            }
        }
        .accessibilityHidden(true)
    }
}
