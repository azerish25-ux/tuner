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

/// The note of the string being tuned and its turn cue, in a small capsule beside the peg ("D3 ↻").
struct PegLabel: View {
    let note: String
    let turn: PegTurn
    let color: Color
    var nudge: Double = 0

    var body: some View {
        let parts = NoteReadout.split(note)
        HStack(spacing: 5) {
            Text(parts.name).font(Typeface.label(15)) + Text(parts.octave).font(Typeface.label(10))
            if let symbol = turn.symbol {
                Image(systemName: symbol).font(.system(size: 12, weight: .bold))
                    .rotationEffect(.degrees(nudge))
            }
        }
        .foregroundStyle(color)
        .padding(.horizontal, 10).padding(.vertical, 6)
        .background(Capsule().fill(Palette.stage.opacity(0.82)))
        .overlay(Capsule().strokeBorder(color.opacity(0.55), lineWidth: 1))
        .fixedSize()
    }

    /// Which side of the peg the label goes: `preferred` (away from the headstock), unless the label
    /// (about `width` wide) would run into the screen edge or the side controls and the other side has more room.
    static func side(for point: CGPoint, preferred: CGFloat, gap: CGFloat, in size: CGSize,
                     width: CGFloat = 60, trailingReserve: CGFloat = 64) -> CGFloat {
        let right = size.width - trailingReserve - (point.x + gap)
        let left = point.x - gap - 8
        if preferred > 0 { return right >= width || right >= left ? 1 : -1 }
        return left >= width || left >= right ? -1 : 1
    }
}

extension View {
    /// Places the view `gap` points left (side < 0) or right of `point`, vertically centred on it.
    func placedBeside(_ point: CGPoint, side: CGFloat, gap: CGFloat) -> some View {
        frame(width: 0, height: 0, alignment: side < 0 ? .trailing : .leading)
            .position(x: point.x + side * gap, y: point.y)
    }
}

/// The 3D stage's peg cue: a pulsing ring on the active course's peg (both pegs of a pair), projected
/// from the rig every frame, with the note and turn arrow beside it once the camera frames the headstock.
struct StagePegCue: View {
    let controller: StageController
    let input: () -> StageInput
    let reduceMotion: Bool

    var body: some View {
        GeometryReader { geometry in
            // Runs every frame even with Reduce Motion: it tracks the peg, and only the pulse is decorative.
            TimelineView(.animation) { timeline in
                cue(size: geometry.size, now: timeline.date.timeIntervalSinceReferenceDate)
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    @ViewBuilder private func cue(size: CGSize, now: Double) -> some View {
        let state = input()
        if let marker = controller.pegMarker(in: size), let lead = marker.points.first {
            let cents = state.listening ? controller.smoothedCents : nil
            let color = Palette.tuning(cents, locked: state.locked)
            let turn = PegTurn.from(cents: cents, locked: state.locked, listening: state.listening, tighten: marker.tighten, slides: marker.slides)
            let close = Double(max(0, min(1, marker.closeUp)))
            let pulse = reduceMotion || state.locked ? 0 : 2.5 * sin(now * 3)
            let radius = CGFloat(12 + 10 * close + pulse)
            let gap = radius + 10
            let side = PegLabel.side(for: lead, preferred: marker.side, gap: gap, in: size)
            ZStack {
                Canvas { context, _ in
                    for point in marker.points {
                        PegRing.draw(&context, at: point, radius: radius, color: color, glow: state.locked ? 1 : 0)
                    }
                }
                .opacity(0.55 + 0.45 * close)
                PegLabel(note: state.note, turn: turn, color: color, nudge: turn.nudge(at: now, reduceMotion: reduceMotion))
                    .placedBeside(lead, side: side, gap: gap)
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
}
