import QuartzCore
import SwiftUI
import TimbreCore

// Live glyphs for the Play hub's tools: the metronome ticks at the player's tempo (on the click itself while it
// runs) and the drone ripples with the tanpura's pluck cycle (the drone's own clock while it plays). One timeline
// per glyph, paused off screen, still under Reduce Motion.

/// A tool's mark on its tile: a live glyph for the metronome and the drone, the tool's symbol for the rest.
struct PlayToolGlyph: View {
    let route: PracticeRoute
    let symbol: String
    @State private var visible = false

    var body: some View {
        Group {
            switch route {
            case .metronome: PendulumGlyph(live: visible)
            case .drone: DroneRippleGlyph(live: visible)
            default:
                Image(systemName: symbol).font(.system(size: 18, weight: .medium)).foregroundStyle(Palette.ink)
            }
        }
        .frame(width: 30, height: 30)
        .liveWhileVisible($visible)
        .accessibilityHidden(true)
    }
}

/// A little metronome: its arm swings through the centre on every beat at the saved tempo, with a light at its
/// foot on each tick. While the metronome runs it follows the click as it is heard.
struct PendulumGlyph: View {
    var live = true
    @EnvironmentObject private var store: AppStore
    @EnvironmentObject private var audio: AudioService
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let bpm = Double(min(300, max(30, store.bpm)))
        let running = audio.metronomeRunning
        TimelineView(.animation(minimumInterval: 1.0 / 30, paused: !live || reduceMotion)) { _ in
            let origin = running ? (audio.metronomeOrigin() ?? 0) : 0
            let beats = reduceMotion ? 0.32 : (CACurrentMediaTime() - origin) * bpm / 60
            Canvas { context, size in
                PendulumGlyphArt.draw(&context, size: size, beats: beats, running: running)
            }
        }
    }
}

enum PendulumGlyphArt {
    /// Drawn on a 30 × 30 grid, scaled to fit.
    static func draw(_ context: inout GraphicsContext, size: CGSize, beats: Double, running: Bool) {
        let scale = min(size.width, size.height) / 30
        context.translateBy(x: (size.width - 30 * scale) / 2, y: (size.height - 30 * scale) / 2)
        context.scaleBy(x: scale, y: scale)
        // The case: a tapering body on a base.
        var body = Path()
        body.move(to: CGPoint(x: 12, y: 2.5))
        body.addLine(to: CGPoint(x: 18, y: 2.5))
        body.addLine(to: CGPoint(x: 25, y: 27.5))
        body.addLine(to: CGPoint(x: 5, y: 27.5))
        body.closeSubpath()
        context.fill(body, with: .color(.white.opacity(0.04)))
        context.stroke(body, with: .color(Palette.ink.opacity(0.75)), style: StrokeStyle(lineWidth: 1.4, lineJoin: .round))

        let fraction = beats - floor(beats)
        let flash = max(0, 1 - fraction * 3.5)
        let angle = sin(beats * Double.pi) * 0.42
        let pivot = CGPoint(x: 15, y: 24)
        let tip = CGPoint(x: pivot.x + CGFloat(sin(angle)) * 21, y: pivot.y - CGFloat(cos(angle)) * 21)
        var arm = Path()
        arm.move(to: pivot)
        arm.addLine(to: tip)
        context.stroke(arm, with: .color(Palette.mint), style: StrokeStyle(lineWidth: 1.6, lineCap: .round))
        // The sliding weight on the arm.
        let weight = CGPoint(x: pivot.x + CGFloat(sin(angle)) * 14, y: pivot.y - CGFloat(cos(angle)) * 14)
        context.fill(Path(ellipseIn: CGRect(x: weight.x - 2.4, y: weight.y - 2.4, width: 4.8, height: 4.8)), with: .color(Palette.ink))
        // The tick light at the foot.
        let glow = CGFloat(3 + 4 * flash)
        context.fill(Path(ellipseIn: CGRect(x: pivot.x - glow, y: pivot.y - glow, width: glow * 2, height: glow * 2)),
                     with: .radialGradient(Gradient(colors: [Palette.mint.opacity((running ? 0.75 : 0.5) * flash), .clear]),
                                           center: pivot, startRadius: 0, endRadius: glow))
        context.fill(Path(ellipseIn: CGRect(x: pivot.x - 1.8, y: pivot.y - 1.8, width: 3.6, height: 3.6)),
                     with: .color(Palette.mint.opacity(0.55 + 0.45 * flash)))
    }
}

/// The drone's ripple: a ring leaves the centre each time a string is plucked, in the tanpura's cycle (on the
/// drone's own plucks while it plays), and the centre glows as they ring.
struct DroneRippleGlyph: View {
    var live = true
    @EnvironmentObject private var audio: AudioService
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let running = audio.droneRunning
        TimelineView(.animation(minimumInterval: 1.0 / 30, paused: !live || reduceMotion)) { _ in
            let now = CACurrentMediaTime()
            let elapsed = reduceMotion ? 3.3 : now - (running ? (audio.droneOrigin() ?? 0) : 0)
            Canvas { context, size in
                DroneRippleArt.draw(&context, size: size, elapsed: elapsed, running: running)
            }
        }
    }
}

enum DroneRippleArt {
    static func draw(_ context: inout GraphicsContext, size: CGSize, elapsed: Double, running: Bool) {
        let c = CGPoint(x: size.width / 2, y: size.height / 2)
        let reach = min(size.width, size.height) / 2 - 1
        var resonance = 0.0
        for string in 0..<DroneCycle.strings {
            guard let age = DroneCycle.age(of: string, elapsed: elapsed) else { continue }
            resonance += DroneCycle.envelope(age: age) * (string == 3 ? 0.4 : 0.3)
            let life = 1.5
            guard age < life else { continue }
            let f = age / life
            let radius = 4 + CGFloat(f) * (reach - 4)
            let alpha = (1 - f) * (running ? 0.85 : 0.6)
            context.stroke(Path(ellipseIn: CGRect(x: c.x - radius, y: c.y - radius, width: radius * 2, height: radius * 2)),
                           with: .color(Palette.mint.opacity(alpha)), lineWidth: string == 3 ? 1.6 : 1.1)
        }
        let core: CGFloat = 4.2
        let glow = core * CGFloat(2 + 1.5 * min(1, resonance))
        context.fill(Path(ellipseIn: CGRect(x: c.x - glow, y: c.y - glow, width: glow * 2, height: glow * 2)),
                     with: .radialGradient(Gradient(colors: [Palette.mint.opacity(0.5 * min(1, resonance + 0.2)), .clear]),
                                           center: c, startRadius: 0, endRadius: glow))
        context.fill(Path(ellipseIn: CGRect(x: c.x - core, y: c.y - core, width: core * 2, height: core * 2)), with: .color(Palette.mint))
    }
}
