import SwiftUI

/// The reward star, Timbre's own: a five-point star strung from one string, its five runs crossing inside it like a
/// knot over a gold body. It lands ringing (each run trembles like a plucked string, alternate runs in opposite
/// phase) and comes to rest, the app's "it stands still" moment in miniature. Unearned, it is the bare string in faint
/// ink. Drawn still with no `landed` date (share cards), and still under Reduce Motion. Decoration: the screen that
/// shows the stars says "2 of 3 stars" for VoiceOver.
struct RewardStar: View {
    let earned: Bool
    /// When it landed, for its ring; nil draws it at rest.
    var landed: Date? = nil
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var ringing = false

    /// How long a landed star rings.
    static let ringDuration = 1.1

    var body: some View {
        TimelineView(.animation(paused: !ringing)) { timeline in
            let elapsed = landed.map { timeline.date.timeIntervalSince($0) } ?? Self.ringDuration
            let swing = ringing && !reduceMotion ? Self.swing(elapsed) : 0
            Canvas { context, size in
                StarStrings.draw(&context, size: size, earned: earned, swing: swing)
            }
        }
        .task(id: landed) {
            guard landed != nil, earned else {
                ringing = false
                return
            }
            ringing = true
            try? await Task.sleep(for: .seconds(Self.ringDuration))
            guard !Task.isCancelled else { return }
            ringing = false
        }
        .accessibilityHidden(true)
    }

    /// The runs' swing, as a share of the star's radius: struck at the landing, a few quick cycles, then still.
    private static func swing(_ t: Double) -> Double {
        guard t >= 0, t < ringDuration else { return 0 }
        return 0.075 * exp(-t / 0.26) * cos(2 * .pi * 7 * t)
    }
}

/// The geometry of `RewardStar`: a regular five-point star centred in its frame (the shape's own box, so a row of
/// them lines up), its body filled and its pentagram stroked as one string.
enum StarStrings {
    /// The star's light gold string and the two golds of its body (`Palette.starFill`).
    static let string = Color(hex: 0xFFE7A8)
    static let bodyTop = Color(hex: 0xFFE29A)

    static func draw(_ context: inout GraphicsContext, size: CGSize, earned: Bool, swing: Double) {
        let geometry = frame(size)
        let line = geometry.radius * 0.11
        if earned {
            let body = outline(geometry)
            let shading = GraphicsContext.Shading.linearGradient(
                Gradient(colors: [bodyTop, Palette.starGold]),
                startPoint: CGPoint(x: geometry.center.x, y: geometry.center.y - geometry.radius),
                endPoint: CGPoint(x: geometry.center.x, y: geometry.center.y + geometry.radius * 0.81))
            context.fill(body, with: shading)
        } else {
            context.fill(outline(geometry), with: .color(Color.white.opacity(0.05)))
        }
        let strings = pentagram(geometry, swing: swing)
        let style = StrokeStyle(lineWidth: earned ? line : line * 0.8, lineCap: .round, lineJoin: .round)
        context.stroke(strings, with: .color(earned ? string.opacity(0.95) : Color.white.opacity(0.16)), style: style)
    }

    /// The star's centre and outer radius: as large as the frame allows with room for the string's width, the
    /// shape's box (1.902 r wide, 1.809 r tall) centred in the frame.
    static func frame(_ size: CGSize) -> (center: CGPoint, radius: CGFloat) {
        let radius = min(size.width / 1.902, size.height / 1.809) * 0.9
        let center = CGPoint(x: size.width / 2, y: size.height / 2 + radius * 0.0955)
        return (center, radius)
    }

    /// Tip `index` (0 at the top, then clockwise) at `radius` from the centre.
    private static func tip(_ index: Int, _ geometry: (center: CGPoint, radius: CGFloat), scale: CGFloat = 1) -> CGPoint {
        let angle = (-90 + 72 * Double(index)) * .pi / 180
        return CGPoint(x: geometry.center.x + geometry.radius * scale * CGFloat(cos(angle)),
                       y: geometry.center.y + geometry.radius * scale * CGFloat(sin(angle)))
    }

    /// The star's body: five tips and the five corners between them, where the string's runs cross.
    static func outline(_ geometry: (center: CGPoint, radius: CGFloat)) -> Path {
        var path = Path()
        for corner in 0..<10 {
            let angle = (-90 + 36 * Double(corner)) * .pi / 180
            let r = corner % 2 == 0 ? geometry.radius : geometry.radius * 0.382
            let point = CGPoint(x: geometry.center.x + r * CGFloat(cos(angle)), y: geometry.center.y + r * CGFloat(sin(angle)))
            if corner == 0 { path.move(to: point) } else { path.addLine(to: point) }
        }
        path.closeSubpath()
        return path
    }

    /// The string: tip to every other tip and back to the first, each run bowed by `swing` (a share of the radius)
    /// in the shape of a string's fundamental, still at both ends.
    static func pentagram(_ geometry: (center: CGPoint, radius: CGFloat), swing: Double) -> Path {
        var path = Path()
        let order = [0, 2, 4, 1, 3, 0]
        let samples = swing == 0 ? 1 : 14
        path.move(to: tip(order[0], geometry))
        for run in 0..<5 {
            let from = tip(order[run], geometry)
            let to = tip(order[run + 1], geometry)
            let dx = to.x - from.x, dy = to.y - from.y
            let length = max(0.001, sqrt(dx * dx + dy * dy))
            let normal = CGPoint(x: -dy / length, y: dx / length)
            let bow = CGFloat(swing) * geometry.radius * (run % 2 == 0 ? 1 : -1)
            for step in 1...samples {
                let s = CGFloat(step) / CGFloat(samples)
                let offset = bow * CGFloat(sin(Double(s) * .pi))
                path.addLine(to: CGPoint(x: from.x + dx * s + normal.x * offset, y: from.y + dy * s + normal.y * offset))
            }
        }
        path.closeSubpath()
        return path
    }
}
