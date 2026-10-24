import SwiftUI
import TimbreCore

/// The word that pops over the hit line as a note is judged: "Perfect" in white-gold, "Good" in its lane's
/// colour, "Early" or "Late" in amber, "Missed" in coral. It springs up past full size, rises off the line and
/// fades; with Reduce Motion it fades where it lands. Drawn into the runway's Canvas from nothing but the time
/// since the note was judged, so it costs a word or two per frame.
enum HighwayPop {
    static let lifetime = 0.75

    static func word(_ grade: PlayAlongJudge.Grade, offset: Double?) -> Text {
        switch grade {
        case .perfect: return Text("Perfect")
        case .good: return Text("Good")
        case .ok: return (offset ?? 0) < 0 ? Text("Early") : Text("Late")
        case .miss: return Text("Missed")
        }
    }

    static func color(_ grade: PlayAlongJudge.Grade, lane: Color) -> Color {
        switch grade {
        case .perfect: return HighwayRunway.perfectGold
        case .good: return lane.mix(with: .white, by: 0.35)
        case .ok: return Palette.amber
        case .miss: return Palette.danger
        }
    }

    /// One pop, `age` seconds after its note was judged, rising from `base` and kept whole inside `bounds`.
    static func draw(_ context: inout GraphicsContext, grade: PlayAlongJudge.Grade, offset: Double?, lane: Color,
                     at base: CGPoint, age: Double, bounds: CGRect, calm: Bool) {
        guard age >= 0, age < lifetime else { return }
        let size: CGFloat = grade == .perfect ? 21 : grade == .miss ? 14 : 17
        let text = word(grade, offset: offset).font(.system(size: size, weight: .heavy, design: .rounded)).italic()
        let face = context.resolve(text.foregroundStyle(color(grade, lane: lane)))
        let shade = context.resolve(text.foregroundStyle(Color.black.opacity(0.65)))
        let measured = face.measure(in: CGSize(width: bounds.width, height: 80))

        // 0.5 → 1.25 in the first 0.12 s, settling to 1 by 0.24 s.
        var scale: CGFloat = 1
        if !calm {
            if age < 0.12 { scale = 0.5 + 0.75 * CGFloat(age / 0.12) }
            else if age < 0.24 { scale = 1.25 - 0.25 * CGFloat((age - 0.12) / 0.12) }
        }
        let rise: CGFloat = calm ? 0 : 26 * CGFloat(1 - pow(1 - min(1, age / lifetime), 2))
        let fadeFrom = lifetime - 0.25
        let fade = age < fadeFrom ? 1 : max(0, (lifetime - age) / 0.25)
        // Whole on the stage even over the outer lanes, at its biggest.
        let half = measured.width * 1.25 / 2 + 4
        let x = min(max(base.x, bounds.minX + half), bounds.maxX - half)

        var c = context
        c.opacity = fade
        c.translateBy(x: x, y: base.y - rise)
        c.scaleBy(x: scale, y: scale)
        if grade == .perfect && !calm {
            var glow = c
            glow.addFilter(.blur(radius: 7))
            glow.opacity = fade * 0.9
            glow.draw(face, at: .zero)
        }
        c.draw(shade, at: CGPoint(x: 0, y: 1.5))
        c.draw(face, at: .zero)
    }
}
