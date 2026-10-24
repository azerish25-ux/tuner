import SwiftUI
import TimbreCore

/// How one stroke of a rhythm step went: its grade and how far off it was in seconds (negative early). A miss
/// carries the nearest stroke heard outside the window, if there was one; nil when nothing was heard.
struct BeatCall: Equatable {
    let grade: PlayAlongJudge.Grade
    let offset: Double?
}

/// The rhythm step's beat row: one bar's strokes on a line with the beat numbers under it and the playhead
/// sweeping through. Each stroke is called as it passes, mint on the beat, amber when loose, red when missed,
/// and a loose or missed stroke says why under its number ("120 ms late", "Missed"); each one swells as the
/// playhead reaches it. Drawn like `RhythmBar`, which explanations keep.
struct LessonBeatRow: View {
    let pattern: [Double]
    var beatsPerBar = 4
    var accent: Color = Palette.mint
    /// 0…1 through the bar, nil when not playing.
    var playhead: Double?
    /// The bar's judged strokes, by index in `pattern`.
    var calls: [Int: BeatCall] = [:]
    /// Strums: down arrows on the beat, up arrows between beats.
    var arrows = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Off-beat strokes put their reasons on a second line, so neighbours' words never collide.
    private var hasOffbeats: Bool { pattern.contains { $0.truncatingRemainder(dividingBy: 1) != 0 } }
    private var height: CGFloat { 86 + (hasOffbeats ? 38 : 22) }

    var body: some View {
        Canvas { context, size in draw(&context, size: size) }
            .frame(height: height)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text("Rhythm pattern"))
            .accessibilityValue(spokenCalls)
    }

    private func draw(_ context: inout GraphicsContext, size: CGSize) {
        // Inset by the largest dot and its halo (15) plus air, so the first stroke isn't clipped.
        let left: CGFloat = 22, right = size.width - 14
        let width = right - left
        let mid: CGFloat = 35
        let meter = max(1, beatsPerBar)
        context.fill(Path(roundedRect: CGRect(x: left, y: mid - 1, width: width, height: 2), cornerRadius: 1), with: .color(Palette.line))
        for beat in 0..<meter {
            let x = left + width * CGFloat(beat) / CGFloat(meter)
            context.fill(Path(CGRect(x: x - 0.5, y: mid - 14, width: 1, height: 28)), with: .color(Palette.inkFaint.opacity(0.5)))
            context.draw(Text("\(beat + 1)").font(Typeface.label(13)).foregroundStyle(Palette.inkSoft), at: CGPoint(x: x, y: 76))
        }
        for (i, hit) in pattern.enumerated() {
            let x = left + width * CGFloat(hit) / CGFloat(meter)
            let onBeat = hit.truncatingRemainder(dividingBy: 1) == 0
            let call = calls[i]
            let color = tint(call, onBeat: onBeat)
            // Each stroke swells and sends out a ring as the playhead reaches it, in time with the pick.
            let strike = reduceMotion ? 0 : BeatStrike.amount(playhead: playhead, at: hit / Double(meter))
            let r: CGFloat = (onBeat ? 11 : 8) * (1 + 0.22 * CGFloat(strike))
            BeatStrike.draw(&context, at: CGPoint(x: x, y: mid), radius: r, color: color, strike: strike)
            let halo = r + 4
            context.fill(Path(ellipseIn: CGRect(x: x - halo, y: mid - halo, width: halo * 2, height: halo * 2)), with: .color(color.opacity(call == nil ? 0.18 : 0.3)))
            context.fill(Path(ellipseIn: CGRect(x: x - r, y: mid - r, width: r * 2, height: r * 2)), with: .color(color))
            if arrows {
                let arrow = Text(Image(systemName: onBeat ? "arrow.down" : "arrow.up")).font(.system(size: r * 1.15, weight: .black)).foregroundStyle(Palette.onAccent)
                context.draw(arrow, at: CGPoint(x: x, y: mid))
            }
            if let call, let words = reason(call) {
                // Under the beat numbers; kept inside the row at the ends.
                let y: CGFloat = onBeat || !hasOffbeats ? 97 : 114
                let labelX = min(max(x, 40), size.width - 40)
                context.draw(words.font(Typeface.label(11)).foregroundStyle(color), at: CGPoint(x: labelX, y: y))
            }
        }
        if let playhead {
            let x = left + width * CGFloat(playhead)
            context.fill(Path(roundedRect: CGRect(x: x - 1.5, y: mid - 22, width: 3, height: 44), cornerRadius: 1.5), with: .color(Palette.ink))
        }
    }

    /// Upcoming strokes as in the explanations (down strokes mint, up strokes amber); called ones by their grade.
    private func tint(_ call: BeatCall?, onBeat: Bool) -> Color {
        guard let grade = call?.grade else { return onBeat ? accent : Palette.amber }
        switch grade {
        case .perfect, .good: return accent
        case .ok: return Palette.amber
        case .miss: return Palette.danger
        }
    }

    /// Why a stroke was loose or missed, nil for a clean one.
    private func reason(_ call: BeatCall) -> Text? {
        switch call.grade {
        case .perfect, .good:
            return nil
        case .ok, .miss:
            guard let offset = call.offset else { return call.grade == .miss ? Text("Missed") : nil }
            let ms = Self.milliseconds(offset)
            return offset < 0 ? Text("\(ms) ms early") : Text("\(ms) ms late")
        }
    }

    /// To the nearest 10 ms: closer than that is noise in the reading.
    private static func milliseconds(_ offset: Double) -> Int { Int((abs(offset) * 100).rounded()) * 10 }

    /// For VoiceOver: each called stroke of the bar, in order.
    private var spokenCalls: String {
        pattern.indices.compactMap { i -> String? in
            guard let call = calls[i] else { return nil }
            switch call.grade {
            case .perfect: return String(localized: "Perfect")
            case .good: return String(localized: "Good")
            case .ok, .miss:
                guard let offset = call.offset else { return call.grade == .miss ? String(localized: "Missed") : String(localized: "Good") }
                let ms = Self.milliseconds(offset)
                return offset < 0 ? String(localized: "\(ms) ms early") : String(localized: "\(ms) ms late")
            }
        }
        .joined(separator: ", ")
    }
}
