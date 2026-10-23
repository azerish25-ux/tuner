import SwiftUI
import TimbreCore

extension Palette {
    /// The tuner's one colour rule, for every live cue (readout digits, meter needle, string chip, status line,
    /// strobe, stage): mint inside the tracker's own lock band, amber out to 20 cents, coral beyond.
    static func tuning(_ cents: Double?, locked: Bool) -> Color { pitch(cents, locked: locked, band: InTuneRule.bandCents) }
}

/// Per-frame smoothing for the readout. A class so frame updates never invalidate views.
final class ReadoutMotion {
    /// The smoothing every tuner view uses, so the stage, chip and readout agree on the same value.
    static func makeFilter() -> OneEuroFilter { OneEuroFilter(minCutoff: 1.4, beta: 0.025) }
    private var filter = ReadoutMotion.makeFilter()
    private var strobe = StrobePhase(bandsPerSecondPerCent: 0.09)
    private var last: Double = 0
    private(set) var cents: Double?
    private(set) var phase: Double = 0
    /// The smoothed cents as every readout shows them: whole cents.
    var shown: Int? { cents.map { Int($0.rounded()) } }
    func step(_ raw: Double?, locked: Bool, now: Double) {
        let dt = last == 0 ? 1.0 / 60 : min(0.1, max(0, now - last))
        last = now
        if let raw { cents = filter.filter(max(-60, min(60, raw)), at: now) } else { filter.reset(); cents = nil }
        phase = strobe.advance(cents: locked ? 0 : cents, dt: dt)
    }
}

/// ±50 cent ribbon: fine ticks, the lock zone and a glowing needle. Track, zone and needle follow the
/// tuner's colour rule: mint inside the lock band, amber to 20 cents, coral beyond.
/// A faint strobe shimmer runs along the ribbon while the pitch is off, and stands still in tune.
struct RibbonMeter: View {
    let cents: Double?
    let phase: Double
    let locked: Bool
    var body: some View {
        Canvas { context, size in
            let mid = size.width / 2, baseline = size.height / 2
            let span = size.width / 2
            let scale = (span - 2) / 50
            let band = CGFloat(InTuneRule.bandCents) * scale
            let track = Path(CGRect(x: 0, y: baseline - 1, width: size.width, height: 2))
            context.fill(track, with: .linearGradient(Self.track(width: size.width, scale: scale), startPoint: .zero, endPoint: CGPoint(x: size.width, y: 0)))
            if let cents, !locked {
                // Strobe: dots drifting with the pitch error.
                let step: CGFloat = 14
                let offset = CGFloat(phase.truncatingRemainder(dividingBy: 1)) * step
                let dots = Palette.tuning(cents, locked: false)
                for i in stride(from: -step, through: size.width + step, by: step) {
                    let x = i + offset
                    let fade = 1 - min(1, abs(x - mid) / span)
                    context.fill(Path(ellipseIn: CGRect(x: x - 1.5, y: baseline - 1.5, width: 3, height: 3)), with: .color(dots.opacity(0.5 * fade * min(1, abs(cents) / 6))))
                }
            }
            for value in stride(from: -50, through: 50, by: 10) where value != 0 {
                let x = mid + CGFloat(value) * scale
                let major = value % 50 == 0 || value % 20 == 0
                context.fill(Path(CGRect(x: x - 0.5, y: baseline - (major ? 7 : 5), width: 1, height: major ? 14 : 10)), with: .color(Palette.inkFaint.opacity(0.7)))
            }
            // The lock zone is exactly the band the tracker locks in.
            let zone = CGRect(x: mid - band, y: baseline - 13, width: band * 2, height: 26)
            context.fill(Path(roundedRect: zone, cornerRadius: 7), with: .color(Palette.mint.opacity(locked ? 0.25 : 0.12)))
            context.stroke(Path(roundedRect: zone, cornerRadius: 7), with: .color(Palette.mint.opacity(locked ? 1 : 0.5)), lineWidth: 1)
            guard let cents else { return }
            let x = locked ? mid : mid + CGFloat(max(-50, min(50, cents))) * scale
            let color = Palette.tuning(cents, locked: locked)
            context.fill(Path(ellipseIn: CGRect(x: x - 18, y: baseline - 18, width: 36, height: 36)), with: .radialGradient(Gradient(colors: [color.opacity(0.6), .clear]), center: CGPoint(x: x, y: baseline), startRadius: 0, endRadius: 18))
            context.fill(Path(roundedRect: CGRect(x: x - 2, y: 0, width: 4, height: size.height), cornerRadius: 2), with: .color(color))
        }
        .accessibilityHidden(true)
    }

    /// The colour rule laid out along the track, with hard edges where the colour changes.
    private static func track(width: CGFloat, scale: CGFloat) -> Gradient {
        let unit = width > 0 ? scale / width : 0
        func at(_ cents: Double) -> CGFloat { min(1, max(0, 0.5 + CGFloat(cents) * unit)) }
        let band = InTuneRule.bandCents, near = Palette.nearCents
        let coral = Palette.coral.opacity(0.45), amber = Palette.amber.opacity(0.5), mint = Palette.mint.opacity(0.9)
        return Gradient(stops: [
            .init(color: Palette.coral.opacity(0), location: 0), .init(color: coral, location: at(-40)),
            .init(color: coral, location: at(-near)), .init(color: amber, location: at(-near)),
            .init(color: amber, location: at(-band)), .init(color: mint, location: at(-band)),
            .init(color: mint, location: at(band)), .init(color: amber, location: at(band)),
            .init(color: amber, location: at(near)), .init(color: coral, location: at(near)),
            .init(color: coral, location: at(40)), .init(color: Palette.coral.opacity(0), location: 1)])
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
            let color = Palette.tuning(cents, locked: locked)
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
            let band = CGFloat(InTuneRule.bandCents) / 50 * span
            let zone = CGRect(x: mid - band, y: baseline - 9, width: band * 2, height: 18)
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
            let color = Palette.tuning(cents, locked: locked)
            let glow = CGRect(x: x - 16, y: baseline - 16, width: 32, height: 32)
            context.fill(Path(ellipseIn: glow), with: .radialGradient(Gradient(colors: [color.opacity(0.55), .clear]), center: CGPoint(x: x, y: baseline), startRadius: 0, endRadius: 16))
            context.fill(Path(roundedRect: CGRect(x: x - 2, y: baseline - 13, width: 4, height: 26), cornerRadius: 2), with: .color(color))
        }
        .accessibilityHidden(true)
    }
}

/// The big note (octave set small and light), then cents and hertz; mint and glowing when in tune.
/// Cents are whole numbers that roll (numeric transition) rather than cross-fade, so two values never show at once.
struct NoteReadout: View {
    let note: String
    let cents: Double?
    let hertz: Double?
    let target: Double
    let locked: Bool
    var compact = false
    var body: some View {
        let parts = Self.split(note)
        let shown = cents.map { Int($0.rounded()) }
        VStack(spacing: compact ? 2 : 6) {
            HStack(alignment: .lastTextBaseline, spacing: 3) {
                Text(parts.name).font(Typeface.note(compact ? 84 : 112, relativeTo: .largeTitle)).tracking(compact ? -3 : -5)
                    .foregroundStyle(locked ? Color(hex: 0xEFFFF8) : Palette.ink)
                    .contentTransition(.numericText())
                    .minimumScaleFactor(0.6).lineLimit(1)
                Text(parts.octave).font(Typeface.displayLight(30)).foregroundStyle(locked ? Palette.mint.opacity(0.8) : Palette.inkFaint)
            }
            .shadow(color: locked ? Palette.mint.opacity(0.6) : .clear, radius: 26)
            Group {
                if locked { lockedBadge(shown) } else { centsRow(shown) }
            }
            .transition(.opacity.combined(with: .scale(scale: 0.96)))
            .animation(Motion.quick, value: locked)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("Target \(note)"))
        .accessibilityValue(Text(Self.spoken(shown, locked: locked)))
    }

    private func lockedBadge(_ shown: Int?) -> some View {
        let amount = abs(shown ?? 0)
        return Label {
            Text("In tune · \(String(amount)) cents")
                .contentTransition(.numericText(value: Double(amount)))
                .animation(Motion.quick, value: amount)
        } icon: { Image(systemName: "checkmark") }
        .font(.subheadline.weight(.semibold)).foregroundStyle(Palette.mint)
        .padding(.horizontal, 12).padding(.vertical, 6)
        .background(Capsule().fill(Palette.mint.opacity(0.12)))
        .overlay(Capsule().strokeBorder(Palette.mint.opacity(0.4), lineWidth: 1))
    }

    private func centsRow(_ shown: Int?) -> some View {
        HStack(spacing: 10) {
            Text(verbatim: Self.signed(shown))
                .font(Typeface.number(15)).foregroundStyle(Palette.tuning(shown.map { Double($0) }, locked: false))
                .contentTransition(.numericText(value: Double(shown ?? 0)))
                .animation(Motion.quick, value: shown)
            Circle().fill(Palette.inkFaint).frame(width: 3, height: 3)
            Text(String(format: "%.2f Hz", hertz ?? target)).font(Typeface.number(15)).foregroundStyle(Palette.inkSoft)
        }
    }

    /// "−7 cents", "+3 cents", "0 cents"; an em dash with no pitch.
    static func signed(_ shown: Int?) -> String {
        guard let shown else { return "—" }
        let sign = shown < 0 ? "−" : (shown > 0 ? "+" : "")
        return "\(sign)\(abs(shown)) cents"
    }

    static func spoken(_ cents: Double?) -> String {
        guard let cents else { return String(localized: "No pitch") }
        if abs(cents) < 2 { return String(localized: "In tune") }
        let amount = Int(abs(cents).rounded())
        return cents < 0 ? String(localized: "\(amount) cents flat") : String(localized: "\(amount) cents sharp")
    }

    /// VoiceOver for the tuner readout: the same whole cents the screen shows; "In tune" once locked.
    static func spoken(_ shown: Int?, locked: Bool) -> String {
        guard let shown else { return String(localized: "No pitch") }
        if locked || shown == 0 { return String(localized: "In tune") }
        let amount = abs(shown)
        return shown < 0 ? String(localized: "\(amount) cents flat") : String(localized: "\(amount) cents sharp")
    }

    static func split(_ note: String) -> (name: String, octave: String) {
        let digits = note.reversed().prefix { $0.isNumber || $0 == "-" }
        let octave = String(digits.reversed())
        let name = String(note.dropLast(octave.count))
        return (name.isEmpty ? note : name, name.isEmpty ? "" : octave)
    }
}
