import SwiftUI
import TimbreCore

/// What the peg of the string being tuned asks for: turn it (which way), push or pull a slide,
/// leave it (inside the lock band or no pitch), or nothing more to do (locked).
enum PegTurn: Equatable {
    case none, locked, clockwise, counterclockwise, pushIn, pullOut

    /// - Parameter tighten: the rig's turn sign (+1: clockwise tightens, as the stage shows the peg);
    ///   nil when the picture has no rig, so no arrow is guessed.
    static func from(cents: Double?, locked: Bool, listening: Bool, tighten: Int?, slides: Bool) -> PegTurn {
        guard listening, let cents else { return .none }
        if locked { return .locked }
        guard abs(cents.rounded()) > Palette.tuningBand else { return .none }
        let tightening = cents < 0
        if slides { return tightening ? .pushIn : .pullOut }
        guard let tighten else { return .none }
        return (tightening ? 1 : -1) * tighten > 0 ? .clockwise : .counterclockwise
    }

    var symbol: String? {
        switch self {
        case .none: return nil
        case .locked: return "checkmark"
        case .clockwise: return "arrow.clockwise"
        case .counterclockwise: return "arrow.counterclockwise"
        case .pushIn: return "arrow.down.right.and.arrow.up.left"
        case .pullOut: return "arrow.up.left.and.arrow.down.right"
        }
    }

    /// The arrow's swing in degrees at `now`: a small nudge in the turn direction (none with Reduce Motion).
    func nudge(at now: Double, reduceMotion: Bool) -> Double {
        guard !reduceMotion else { return 0 }
        let sign: Double = self == .clockwise ? 1 : (self == .counterclockwise ? -1 : 0)
        return sign * 16 * max(0, sin(now * 4))
    }
}

/// The note of the string being tuned and its turn cue, in a small capsule beside the peg ("D3 ↻"). Listening
/// with nothing heard yet (`prompt`), it asks for the string instead, as the status line does ("Play G3").
struct PegLabel: View {
    let note: String
    let turn: PegTurn
    let color: Color
    var prompt = false
    var nudge: Double = 0

    var body: some View {
        let parts = NoteReadout.split(note)
        HStack(spacing: 5) {
            if prompt {
                Text("Play \(note)").font(Typeface.label(.footnote))
            } else {
                Text(parts.name).font(Typeface.label(.body)) + Text(parts.octave).font(Typeface.label(.caption))
            }
            if let symbol = turn.symbol {
                // The turn is the peg's, seen on screen: its arrow never mirrors for a right-to-left language.
                Image(systemName: symbol).font(.system(size: 12, weight: .bold))
                    .rotationEffect(.degrees(nudge))
                    .environment(\.layoutDirection, .leftToRight)
            }
        }
        .foregroundStyle(color)
        .padding(.horizontal, 10).padding(.vertical, 6)
        .background(Capsule().fill(Palette.stage.opacity(0.82)))
        .overlay(Capsule().strokeBorder(color.opacity(0.55), lineWidth: 1))
        .fixedSize(horizontal: false, vertical: true)
    }

}

/// Measures the cue in its actual language and text size before choosing a side of the peg.
/// When neither side has room, it sits above or below the peg inside the stage's clear area.
struct PegLabelPlacement: Layout {
    let point: CGPoint
    let preferred: CGFloat
    let gap: CGFloat
    var controlsOnLeft = false

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        proposal.replacingUnspecifiedDimensions()
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        guard let label = subviews.first else { return }
        let available = max(1, bounds.width - 64 - 16)
        let measured = label.sizeThatFits(ProposedViewSize(width: available, height: nil))
        let frame = Self.frame(label: measured, point: point, preferred: preferred, gap: gap,
                               size: bounds.size, controlsOnLeft: controlsOnLeft)
        label.place(at: CGPoint(x: bounds.minX + frame.minX, y: bounds.minY + frame.minY), anchor: .topLeading,
                    proposal: ProposedViewSize(width: frame.width, height: frame.height))
    }

    static func frame(label: CGSize, point: CGPoint, preferred: CGFloat, gap: CGFloat,
                      size: CGSize, controlsOnLeft: Bool) -> CGRect {
        let left: CGFloat = 8 + (controlsOnLeft ? 64 : 0)
        let right = max(left, size.width - 8 - (controlsOnLeft ? 0 : 64))
        let width = min(label.width, max(0, right - left))
        let leftX = point.x - gap - width
        let rightX = point.x + gap
        let preferredX = preferred > 0 ? rightX : leftX
        let oppositeX = preferred > 0 ? leftX : rightX
        let besideX = preferredX >= left && preferredX + width <= right ? preferredX : oppositeX
        let fitsBeside = besideX >= left && besideX + width <= right
        let proposedX = fitsBeside ? besideX : point.x - width / 2
        let above = point.y - gap - label.height
        let proposedY = fitsBeside ? point.y - label.height / 2 : (above >= 8 ? above : point.y + gap)
        return CGRect(x: min(max(left, proposedX), max(left, right - width)),
                      y: min(max(8, proposedY), max(8, size.height - 8 - label.height)),
                      width: width, height: label.height)
    }
}

/// The 3D stage's peg cue: a pulsing ring on the peg being turned (on a pair, the string's own peg), projected
/// from the rig every frame, with the note and turn arrow beside it once the camera frames the headstock.
struct StagePegCue: View {
    let controller: StageController
    let input: () -> StageInput
    let reduceMotion: Bool
    /// The host isn't listening and holds no reading: once the camera has settled on the close-up, the cue stops
    /// tracking every frame (nothing moves the peg then) and its ring stops pulsing, until something changes.
    var resting = false
    /// The model is on stage (the cue appears with it and follows the camera's dolly in).
    var loaded = true
    @State private var settling = true
    /// The moment the string locks, for its shimmer.
    @State private var flash = LockFlash()

    var body: some View {
        GeometryReader { geometry in
            // Read only at rest, so a live pitch never re-runs this closure. The whole-instrument shot breathes, so it
            // never rests.
            let state: StageInput? = resting ? input() : nil
            let key: String? = state.flatMap { $0.focus && loaded ? StageSettle.key($0, picture: controller.wanted ?? "", size: geometry.size) : nil }
            let still = key != nil && !settling
            // Every frame while anything moves, even with Reduce Motion: it tracks the peg, and only the pulse is decorative.
            TimelineView(.animation(minimumInterval: nil, paused: still)) { timeline in
                cue(size: geometry.size, now: timeline.date.timeIntervalSinceReferenceDate, idle: still)
            }
            .task(id: key) {
                settling = true
                guard key != nil else { return }
                try? await Task.sleep(for: StageSettle.window)
                if !Task.isCancelled { settling = false }
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    @ViewBuilder private func cue(size: CGSize, now: Double, idle: Bool = false) -> some View {
        let state = input()
        if let marker = controller.pegMarker(in: size), let lead = marker.points.first {
            let cents = state.listening ? controller.smoothedCents : nil
            let color = Palette.tuning(cents, locked: state.locked)
            let turn = PegTurn.from(cents: cents, locked: state.locked, listening: state.listening, tighten: marker.tighten, slides: marker.slides)
            // Listening with nothing heard yet: the label asks for the string and a ring swells out of the peg.
            let calling = state.listening && cents == nil && !state.locked
            let close = Double(max(0, min(1, marker.closeUp)))
            let pulse = reduceMotion || idle || state.locked ? 0 : 2.5 * sin(now * 3)
            let radius = CGFloat(12 + 10 * close + pulse)
            let gap = radius + 10
            let shimmer = flash.step(locked: state.listening && state.locked, key: "\(state.activeAnchor ?? "-")|\(state.pegIndex ?? -1)",
                                     now: now, duration: LockShimmer.duration)
            ZStack {
                // The lock: light leaves the peg, sweeps the headstock and runs down the string (under the ring and label).
                if let shimmer, ShaderFX.allowed(reduceMotion: reduceMotion), let path = controller.lockPath(in: size) {
                    LockShimmer(peg: path.peg, post: path.post, nut: path.nut, saddle: path.saddle, head: path.head, elapsed: shimmer)
                }
                Canvas { context, _ in
                    for point in marker.points {
                        PegRing.draw(&context, at: point, radius: radius, color: color, glow: state.locked ? 1 : 0)
                        if calling && !reduceMotion { PegRing.drawCall(&context, at: point, radius: radius, color: color, now: now) }
                    }
                }
                .opacity(0.55 + 0.45 * close)
                PegLabelPlacement(point: lead, preferred: marker.side, gap: gap, controlsOnLeft: state.rightToLeft) {
                    PegLabel(note: state.note, turn: turn, color: color, prompt: calling, nudge: turn.nudge(at: now, reduceMotion: reduceMotion))
                        .environment(\.layoutDirection, state.rightToLeft ? .rightToLeft : .leftToRight)
                }
                .frame(width: size.width, height: size.height)
                .opacity(close)
            }
        }
    }
}

/// A ring around a peg with a soft halo; brighter once the string locks.
enum PegRing {
    static func draw(_ context: inout GraphicsContext, at center: CGPoint, radius: CGFloat, color: Color, glow: Double) {
        let halo = radius + 9
        context.fill(Path(ellipseIn: CGRect(x: center.x - halo, y: center.y - halo, width: halo * 2, height: halo * 2)),
                     with: .color(color.opacity(0.10 + 0.12 * glow)))
        context.stroke(Path(ellipseIn: CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2)),
                       with: .color(color.opacity(0.9)), lineWidth: 2)
    }

    /// The call to play the string: a ring that swells out of the peg's ring and fades, every 1.6 seconds.
    /// Callers skip it with Reduce Motion.
    static func drawCall(_ context: inout GraphicsContext, at center: CGPoint, radius: CGFloat, color: Color, now: Double) {
        let t = (now / 1.6).truncatingRemainder(dividingBy: 1)
        let r = radius + 4 + CGFloat(t) * 18
        context.stroke(Path(ellipseIn: CGRect(x: center.x - r, y: center.y - r, width: r * 2, height: r * 2)),
                       with: .color(color.opacity(0.6 * (1 - t) * (1 - t))), lineWidth: 1.5)
    }
}
