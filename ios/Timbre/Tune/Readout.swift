import SwiftUI
import TimbreCore

/// Per-frame smoothing for the readout. A class so frame updates never invalidate views.
final class ReadoutMotion {
    private var filter = OneEuroFilter(minCutoff: 1.4, beta: 0.025)
    private var strobe = StrobePhase(bandsPerSecondPerCent: 0.09)
    private var last: Double = 0
    private(set) var cents: Double?
    private(set) var phase: Double = 0
    func step(_ raw: Double?, locked: Bool, now: Double) {
        let dt = last == 0 ? 1.0 / 60 : min(0.1, max(0, now - last))
        last = now
        if let raw { cents = filter.filter(max(-60, min(60, raw)), at: now) } else { filter.reset(); cents = nil }
        phase = strobe.advance(cents: locked ? 0 : cents, dt: dt)
    }
}

/// Strobe band: segments drift left when flat, right when sharp, and stand still in tune.
struct StrobeBand: View {
    let cents: Double?
    let phase: Double
    let locked: Bool
    let active: Bool
    var body: some View {
        Canvas { context, size in
            let color = Palette.pitch(cents, locked: locked)
            let count = 28
            let width = size.width / CGFloat(count)
            let offset = CGFloat(phase) * width * 2
            let shape = RoundedRectangle(cornerRadius: size.height / 2, style: .continuous).path(in: CGRect(origin: .zero, size: size))
            context.clip(to: shape)
            context.fill(shape, with: .color(Palette.stageRaised))
            guard active else { return }
            for i in -2...(count + 2) {
                let x = CGFloat(i) * width * 2 + offset - width
                let rect = CGRect(x: x, y: 0, width: width, height: size.height)
                let center = Double(abs(rect.midX - size.width / 2) / (size.width / 2))
                context.fill(Path(rect), with: .color(color.opacity((locked ? 0.95 : 0.7) * (1 - 0.55 * center))))
            }
            let gloss = Gradient(colors: [.white.opacity(0.22), .clear, .black.opacity(0.25)])
            context.fill(shape, with: .linearGradient(gloss, startPoint: .zero, endPoint: CGPoint(x: 0, y: size.height)))
        }
        .overlay {
            Capsule().strokeBorder(Palette.line, lineWidth: 1)
        }
        .overlay(alignment: .center) {
            Rectangle().fill(Palette.ink.opacity(0.9)).frame(width: 2).padding(.vertical, -6)
        }
        .accessibilityHidden(true)
    }
}

/// ±50 cent scale with a smoothed glowing marker and a green zone.
struct CentsScale: View {
    let cents: Double?
    let locked: Bool
    var body: some View {
        Canvas { context, size in
            let mid = size.width / 2
            let span = size.width / 2 - 10
            let baseline = size.height / 2
            let zone = CGRect(x: mid - span * 0.1, y: baseline - 9, width: span * 0.2, height: 18)
            context.fill(Path(roundedRect: zone, cornerRadius: 9), with: .color(Palette.locked.opacity(locked ? 0.22 : 0.08)))
            for value in stride(from: -50, through: 50, by: 5) {
                let x = mid + CGFloat(value) / 50 * span
                let major = value % 25 == 0
                var tick = Path()
                tick.move(to: CGPoint(x: x, y: baseline - (major ? 8 : 4)))
                tick.addLine(to: CGPoint(x: x, y: baseline + (major ? 8 : 4)))
                context.stroke(tick, with: .color(value == 0 ? Palette.ink : Palette.inkFaint.opacity(major ? 0.9 : 0.55)), lineWidth: value == 0 ? 2 : 1)
            }
            guard let cents else { return }
            let x = mid + CGFloat(max(-50, min(50, cents))) / 50 * span
            let color = Palette.pitch(cents, locked: locked)
            let glow = CGRect(x: x - 16, y: baseline - 16, width: 32, height: 32)
            context.fill(Path(ellipseIn: glow), with: .radialGradient(Gradient(colors: [color.opacity(0.55), .clear]), center: CGPoint(x: x, y: baseline), startRadius: 0, endRadius: 16))
            context.fill(Path(roundedRect: CGRect(x: x - 2, y: baseline - 13, width: 4, height: 26), cornerRadius: 2), with: .color(color))
        }
        .accessibilityHidden(true)
    }
}

/// Note name in the display serif with its octave set small, plus cents and hertz.
struct NoteReadout: View {
    let note: String
    let cents: Double?
    let hertz: Double?
    let target: Double
    let locked: Bool
    var body: some View {
        let parts = Self.split(note)
        VStack(spacing: 2) {
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(parts.name).font(Typeface.display(92, relativeTo: .largeTitle)).foregroundStyle(locked ? Palette.locked : Palette.ink)
                    .contentTransition(.numericText())
                Text(parts.octave).font(Typeface.display(34)).foregroundStyle(Palette.inkSoft)
            }
            .shadow(color: locked ? Palette.locked.opacity(0.55) : .clear, radius: 22)
            HStack(spacing: 14) {
                Text(cents.map { String(format: "%+.1f¢", $0) } ?? "—").font(Typeface.number(17)).foregroundStyle(Palette.pitch(cents, locked: locked))
                    .monospacedDigit()
                Text(String(format: "%.2f Hz", hertz ?? target)).font(Typeface.number(13)).foregroundStyle(Palette.inkFaint).monospacedDigit()
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("Target \(note)"))
        .accessibilityValue(Text(Self.spoken(cents)))
    }
    static func spoken(_ cents: Double?) -> String {
        guard let cents else { return String(localized: "No pitch") }
        if abs(cents) < 2 { return String(localized: "In tune") }
        let amount = Int(abs(cents).rounded())
        return cents < 0 ? String(localized: "\(amount) cents flat") : String(localized: "\(amount) cents sharp")
    }
    static func split(_ note: String) -> (name: String, octave: String) {
        let digits = note.reversed().prefix { $0.isNumber || $0 == "-" }
        let octave = String(digits.reversed())
        let name = String(note.dropLast(octave.count))
        return (name.isEmpty ? note : name, name.isEmpty ? "" : octave)
    }
}
