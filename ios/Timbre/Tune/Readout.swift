import SwiftUI
import TimbreCore

extension Palette {
    /// The lock band in cents (Settings › Tuning › Precision). AppStore keeps it equal to the tracker's band,
    /// so every tuner colour, meter zone and peg cue agrees with where a string can actually lock.
    static var tuningBand = InTuneRule.bandCents
    /// The tuner's one colour rule, for every live cue (readout digits, meter needle, string chip, status line,
    /// strobe, stage): mint inside the tracker's own lock band, amber out to 20 cents, coral beyond.
    static func tuning(_ cents: Double?, locked: Bool) -> Color { pitch(cents, locked: locked, band: tuningBand) }
}

/// Sharp, flat or in tune as a symbol (▲ ▼ ✓), so with Differentiate Without Colour a pitch never reads
/// by colour alone. Judged by the colour rule: the whole cents shown against the lock band.
enum PitchMark: Equatable {
    case sharp, flat, inTune

    init?(shown: Int?, locked: Bool) {
        if locked { self = .inTune; return }
        guard let shown else { return nil }
        if Double(abs(shown)) <= Palette.tuningBand { self = .inTune } else { self = shown > 0 ? .sharp : .flat }
    }

    var symbol: String {
        switch self {
        case .sharp: return "arrowtriangle.up.fill"
        case .flat: return "arrowtriangle.down.fill"
        case .inTune: return "checkmark"
        }
    }

    /// The symbol in a fixed square (empty with no pitch), so the text beside it never shifts.
    @MainActor static func image(_ mark: PitchMark?, size: CGFloat) -> some View {
        Image(systemName: mark?.symbol ?? "checkmark")
            .font(.system(size: size, weight: .heavy))
            .opacity(mark == nil ? 0 : 1)
            .frame(width: size + 3, height: size + 3)
            .accessibilityHidden(true)
    }
}

/// Per-frame smoothing for the readout. A class so frame updates never invalidate views.
/// The needle and strobe move every frame; the numbers (`shown`, `shownHertz`) hold steady enough to read.
final class ReadoutMotion {
    /// The smoothing every tuner view uses, so the stage, chip and readout agree on the same value.
    static func makeFilter() -> OneEuroFilter { OneEuroFilter(minCutoff: 1.4, beta: 0.025) }
    /// The numbers refresh about ten times a second…
    static let displayInterval = 0.1
    /// …and a whole cent moves only once the pitch is half a cent past the rounding edge (±0.5¢ hysteresis),
    /// so a pitch sitting between two values never flickers.
    static let displayHysteresis = 0.5
    private var filter = ReadoutMotion.makeFilter()
    private var strobe = StrobePhase(bandsPerSecondPerCent: 0.09)
    private var last: Double = 0
    private var lastDisplay: Double = 0
    private(set) var cents: Double?
    private(set) var phase: Double = 0
    /// Whole cents as every number on the tuner shows them (digits, status line, chip colour); nil with no pitch.
    private(set) var shown: Int?
    /// The hertz beside the cents, sampled with them.
    private(set) var shownHertz: Double?

    /// - Parameters:
    ///   - hertz: the measured frequency, shown when the pitch is beyond the smoothed range.
    ///   - target: the target frequency; the hertz shown follows the smoothed cents against it.
    func step(_ raw: Double?, locked: Bool, now: Double, hertz: Double? = nil, target: Double? = nil) {
        let dt = last == 0 ? 1.0 / 60 : min(0.1, max(0, now - last))
        last = now
        if let raw { cents = filter.filter(max(-60, min(60, raw)), at: now) } else { filter.reset(); cents = nil }
        phase = strobe.advance(cents: locked ? 0 : cents, dt: dt)
        updateShown(raw: raw, hertz: hertz, target: target, now: now)
    }

    private func updateShown(raw: Double?, hertz: Double?, target: Double?, now: Double) {
        guard let cents else { shown = nil; shownHertz = nil; return }
        // The first value after silence shows at once; then at most every `displayInterval`.
        guard shown == nil || now - lastDisplay >= Self.displayInterval || now < lastDisplay else { return }
        lastDisplay = now
        if let current = shown, abs(cents - Double(current)) < 0.5 + Self.displayHysteresis {
            // Still within reach of the number on screen: keep it.
        } else {
            shown = Int(cents.rounded())
        }
        if let target, target > 0, let raw, abs(raw) < 59.5 {
            shownHertz = target * pow(2, cents / 1200)
        } else {
            shownHertz = hertz
        }
    }
}

/// ±50 cent ribbon: fine ticks, the lock zone and a glowing needle. Track, zone and needle follow the
/// tuner's colour rule: mint inside the lock band, amber to 20 cents, coral beyond.
/// A faint strobe shimmer runs along the ribbon while the pitch is off, and stands still in tune.
struct RibbonMeter: View {
    let cents: Double?
    /// The whole cents the readout shows, for the needle's colour (so needle and digits never disagree).
    var shown: Int?
    let phase: Double
    let locked: Bool
    @Environment(\.colorSchemeContrast) private var contrast
    var body: some View {
        // Increase Contrast: brighter ticks and a solid lock-zone outline.
        let strong = contrast == .increased
        Canvas { context, size in
            let mid = size.width / 2, baseline = size.height / 2
            let span = size.width / 2
            let scale = (span - 2) / 50
            let band = CGFloat(Palette.tuningBand) * scale
            let track = Path(CGRect(x: 0, y: baseline - 1, width: size.width, height: 2))
            context.fill(track, with: .linearGradient(Self.track(width: size.width, scale: scale), startPoint: .zero, endPoint: CGPoint(x: size.width, y: 0)))
            let tone = Palette.tuning(shown.map { Double($0) } ?? cents, locked: locked)
            if let cents, !locked {
                // Strobe: dots drifting with the pitch error.
                let step: CGFloat = 14
                let offset = CGFloat(phase.truncatingRemainder(dividingBy: 1)) * step
                for i in stride(from: -step, through: size.width + step, by: step) {
                    let x = i + offset
                    let fade = 1 - min(1, abs(x - mid) / span)
                    context.fill(Path(ellipseIn: CGRect(x: x - 1.5, y: baseline - 1.5, width: 3, height: 3)), with: .color(tone.opacity(0.5 * fade * min(1, abs(cents) / 6))))
                }
            }
            for value in stride(from: -50, through: 50, by: 10) where value != 0 {
                let x = mid + CGFloat(value) * scale
                let major = value % 50 == 0 || value % 20 == 0
                context.fill(Path(CGRect(x: x - 0.5, y: baseline - (major ? 7 : 5), width: 1, height: major ? 14 : 10)), with: .color(strong ? Palette.inkSoft : Palette.inkFaint.opacity(0.7)))
            }
            // The lock zone is exactly the band the tracker locks in (it narrows with Precision).
            let zone = CGRect(x: mid - max(band, 3), y: baseline - 13, width: max(band, 3) * 2, height: 26)
            let radius = min(7, zone.width / 2)
            context.fill(Path(roundedRect: zone, cornerRadius: radius), with: .color(Palette.mint.opacity(locked ? 0.25 : 0.12)))
            context.stroke(Path(roundedRect: zone, cornerRadius: radius), with: .color(Palette.mint.opacity(locked || strong ? 1 : 0.5)), lineWidth: strong ? 1.5 : 1)
            guard let cents else { return }
            let x = locked ? mid : mid + CGFloat(max(-50, min(50, cents))) * scale
            context.fill(Path(ellipseIn: CGRect(x: x - 18, y: baseline - 18, width: 36, height: 36)), with: .radialGradient(Gradient(colors: [tone.opacity(0.6), .clear]), center: CGPoint(x: x, y: baseline), startRadius: 0, endRadius: 18))
            context.fill(Path(roundedRect: CGRect(x: x - 2, y: 0, width: 4, height: size.height), cornerRadius: 2), with: .color(tone))
        }
        .accessibilityHidden(true)
    }

    /// The colour rule laid out along the track, with hard edges where the colour changes.
    private static func track(width: CGFloat, scale: CGFloat) -> Gradient {
        let unit = width > 0 ? scale / width : 0
        func at(_ cents: Double) -> CGFloat { min(1, max(0, 0.5 + CGFloat(cents) * unit)) }
        let band = Palette.tuningBand, near = Palette.nearCents
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
    @Environment(\.colorSchemeContrast) private var contrast
    var body: some View {
        let outline = contrast == .increased ? Palette.inkSoft : Palette.line
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
            Capsule().strokeBorder(outline, lineWidth: 1)
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
            let band = CGFloat(Palette.tuningBand) / 50 * span
            let zone = CGRect(x: mid - band, y: baseline - 9, width: band * 2, height: 18)
            context.fill(Path(roundedRect: zone, cornerRadius: min(9, band)), with: .color(Palette.locked.opacity(locked ? 0.22 : 0.08)))
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
/// The numbers sit in fixed-width monospaced columns and change in place (no rolling digits), at the
/// steady rate `ReadoutMotion` gives them, so the row never shifts. Cents use the ¢ sign in every language.
struct NoteReadout: View {
    let note: String
    /// Whole cents as the tuner shows them (`ReadoutMotion.shown`); nil with no pitch.
    let shown: Int?
    let hertz: Double?
    let target: Double
    let locked: Bool
    var compact = false
    @Environment(\.colorSchemeContrast) private var contrast
    @Environment(\.accessibilityDifferentiateWithoutColor) private var withoutColor
    private var strong: Bool { contrast == .increased }
    var body: some View {
        let parts = Self.split(note)
        VStack(spacing: compact ? 2 : 6) {
            HStack(alignment: .lastTextBaseline, spacing: 3) {
                Text(parts.name).font(Typeface.note(compact ? 84 : 112, relativeTo: .largeTitle)).tracking(compact ? -3 : -5)
                    .foregroundStyle(locked ? Color(hex: 0xEFFFF8) : Palette.ink)
                    .contentTransition(.numericText())
                    .minimumScaleFactor(0.6).lineLimit(1)
                Text(parts.octave).font(Typeface.displayLight(30)).foregroundStyle(octaveColor)
            }
            .shadow(color: locked ? Palette.mint.opacity(0.6) : .clear, radius: 26)
            Group {
                if locked { lockedBadge } else { centsRow }
            }
            .transition(.opacity.combined(with: .scale(scale: 0.96)))
            .animation(Motion.quick, value: locked)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("Target \(note)"))
        .accessibilityValue(Text(Self.spoken(shown, locked: locked)))
        // VoiceOver reads the live value when it needs it rather than on every change.
        .accessibilityAddTraits(.updatesFrequently)
    }

    private var octaveColor: Color {
        if locked { return Palette.mint.opacity(strong ? 1 : 0.8) }
        return strong ? Palette.inkSoft : Palette.inkFaint
    }

    private var lockedBadge: some View {
        Label {
            Text("In tune") + Text(verbatim: " · \(abs(shown ?? 0))¢")
        } icon: { Image(systemName: "checkmark") }
        .font(.subheadline.weight(.semibold)).foregroundStyle(Palette.mint)
        .monospacedDigit()
        .padding(.horizontal, 12).padding(.vertical, 6)
        .background(Capsule().fill(Palette.mint.opacity(0.12)))
        .overlay(Capsule().strokeBorder(Palette.mint.opacity(strong ? 0.9 : 0.4), lineWidth: strong ? 1.5 : 1))
    }

    /// "−11¢ · 81.99 Hz": each number in its own fixed column, so the separator never moves.
    /// With Differentiate Without Colour a symbol leads the cents (▲ sharp, ▼ flat, ✓ in the lock band).
    private var centsRow: some View {
        HStack(spacing: 10) {
            HStack(spacing: 5) {
                if withoutColor { PitchMark.image(PitchMark(shown: shown, locked: false), size: 11) }
                Self.column(Self.signed(shown), placeholder: "−00¢", alignment: .trailing)
            }
            .foregroundStyle(Palette.tuning(shown.map { Double($0) }, locked: false))
            Circle().fill(strong ? Palette.inkSoft : Palette.inkFaint).frame(width: 3, height: 3)
            Self.column(Self.hertzText(hertz ?? target), placeholder: Self.hertzPlaceholder(target), alignment: .leading)
                .foregroundStyle(strong ? Palette.ink : Palette.inkSoft)
        }
        .font(Typeface.number(15))
    }

    /// A number in a column as wide as its widest value, so it changes in place.
    private static func column(_ text: String, placeholder: String, alignment: Alignment) -> some View {
        ZStack(alignment: alignment) {
            Text(verbatim: placeholder).hidden()
            Text(verbatim: text)
        }
        .lineLimit(1)
        .fixedSize()
    }

    /// "−7¢", "+3¢", "0¢"; an em dash with no pitch.
    static func signed(_ shown: Int?) -> String {
        guard let shown else { return "—" }
        let sign = shown < 0 ? "−" : (shown > 0 ? "+" : "")
        return "\(sign)\(abs(shown))¢"
    }

    static func hertzText(_ hertz: Double) -> String { String(format: "%.2f Hz", hertz) }

    /// As many digits as the target needs (with room for a sharp reading), e.g. "000.00 Hz" for 146.83 Hz.
    static func hertzPlaceholder(_ target: Double) -> String {
        let digits = max(1, String(Int(max(1, target * 1.07))).count)
        return String(repeating: "0", count: digits) + ".00 Hz"
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
