import SwiftUI
import TimbreCore

// MARK: - Ringing

/// How the strings on the strum screen ring: while it waits for a strum, a pick sweeps across them every few
/// seconds (the hint) and each rings as it passes; when a strum is heard, every string at once, lowest first a few
/// milliseconds apart, the way a real strum spreads. Times are seconds since the reference date.
struct StrumRing: Equatable {
    /// The hint plays (no strum read yet, listening, motion allowed).
    var hint: Bool
    var hintStart: Double
    /// The latest strum's attack.
    var attackAt: Double?
    /// Something is ringing: the canvases redraw every frame only then.
    var active: Bool

    /// Nothing ringing (the zoomed lane rings from the live input instead).
    static let still = StrumRing(hint: false, hintStart: 0, attackAt: nil, active: false)

    /// One hint: a pause, then the sweep.
    static let cycle = 3.2
    /// The hint's pick crosses the strings between these seconds of the cycle.
    static let sweepStart = 0.5
    static let sweepLength = 0.55
    /// A real strum reaches each next string this much later.
    static let spread = 0.014

    /// When the hint's pick reaches the string at `position` of `count`, in seconds into the cycle.
    static func hintHit(_ position: Int, of count: Int) -> Double {
        sweepStart + sweepLength * (Double(position) + 0.5) / Double(max(1, count))
    }

    /// How far (points) the string at `position` swings at `now`.
    func swing(at now: Double, position: Int, of count: Int) -> Double {
        var swing = 0.0
        if let attackAt {
            let since = now - attackAt - Double(position) * Self.spread
            if since > 0 { swing = 7 * exp(-since * 2.8) }
        }
        if hint, now >= hintStart {
            let into = (now - hintStart).truncatingRemainder(dividingBy: Self.cycle)
            let since = into - Self.hintHit(position, of: count)
            if since > 0 { swing = max(swing, 4 * exp(-since * 3.4)) }
        }
        return swing
    }
}

/// Where a meter puts its cents: ±50¢ over the track's height, sharp up, with room at the ends for the bead.
enum StrumScale {
    static let inset: CGFloat = 13
    static func unit(_ height: CGFloat) -> CGFloat { max(0.5, (height / 2 - inset) / 50) }
    static func y(_ cents: Double?, height: CGFloat) -> CGFloat {
        height / 2 - CGFloat(max(-50, min(50, cents ?? 0))) * unit(height)
    }
}

// MARK: - Colour

/// Colour on the strum screen says one thing, status: mint inside the lock band, amber outside it, quiet ink
/// before a string is heard. The lanes and strings themselves are neutral steel, and which string is which reads
/// from its label chip (its number and note), never from a colour, so an in-tune low E is never drawn red.
enum StrumTone {
    /// The strings: plain steel, as on the instrument.
    static let steel = Color(hex: 0xC9CED6)

    /// Whole cents against the lock band: mint inside it (or once locked), amber outside, faint with no pitch.
    static func status(_ shown: Int?, band: Double, locked: Bool = false) -> Color {
        if locked { return Palette.mint }
        guard let shown else { return Palette.inkFaint }
        return Double(abs(shown)) <= band ? Palette.mint : Palette.amber
    }

    static func status(_ meter: StrumBoard.Meter, band: Double) -> Color { status(meter.shown, band: band) }
}

// MARK: - Column (regular sizes)

/// A string's meter: the ±50¢ scale with a steel string down its middle, the bead where the strum heard it (hollow,
/// with an "≈ estimate" badge, when approximate) pulled toward the target line, the turn it needs on top (↑ tune up
/// when flat, ↓ down when sharp, ✓ in tune) and its label chip and cents below. Bead, turn, chip and cents carry
/// the status colour; nothing else is coloured. A string not heard stays dim, marked "Not heard"; the string to
/// tune first is framed in amber. One element for VoiceOver.
struct StrumMeterColumn: View {
    let meter: StrumBoard.Meter
    /// Left-to-right place on screen: the sweep, the strum's spread and the beads' landing follow it.
    let position: Int
    let count: Int
    let band: Double
    let focus: Bool
    let waiting: Bool
    let ring: StrumRing
    /// Ticks once per strum read (the turn arrow's bounce).
    let pulse: Int
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorSchemeContrast) private var contrast

    private var strong: Bool { contrast == .increased }
    private var inTune: Bool { meter.inTune(band: band) }
    private var dim: Bool { !waiting && !meter.heard }
    private var tone: Color { StrumTone.status(meter, band: band) }
    /// Lanes too narrow for the string number and the estimate's word (more than seven strings on a phone).
    private var narrow: Bool { count > 7 }

    var body: some View {
        VStack(spacing: 8) {
            StrumTurnBadge(shown: meter.shown, band: band, pulse: pulse)
            track
            label
        }
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity)
        .background { halo }
        .opacity(dim ? 0.5 : 1)
        .animation(Motion.quick, value: dim)
        .animation(Motion.adaptive(Motion.settle, reduceMotion: reduceMotion), value: focus)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(StrumWords.name(meter))
        .accessibilityValue(StrumWords.state(meter, band: band, waiting: waiting))
        .accessibilityAddTraits(focus ? .isSelected : [])
    }

    /// Beads land one after another, low string first, like the strum that played them.
    private var landing: Animation {
        reduceMotion ? Motion.reduced : Motion.pluck.delay(Double(position) * 0.035)
    }

    private var track: some View {
        GeometryReader { proxy in
            let size = proxy.size
            let centre = size.height / 2
            let y = StrumScale.y(meter.cents, height: size.height)
            ZStack {
                StrumStringTrack(gauge: meter.gauge, lit: !dim, inTune: inTune, band: band,
                                 ring: ring, position: position, count: count, strong: strong)
                tension(from: centre, to: y, width: size.width)
                bead.position(x: size.width / 2, y: y)
                    .animation(landing, value: meter.cents)
                if dim { notHeard.position(x: size.width / 2, y: centre) }
            }
        }
        .frame(minHeight: 120)
    }

    /// The pull from the bead to the target line, in amber, while a string is out.
    private func tension(from centre: CGFloat, to y: CGFloat, width: CGFloat) -> some View {
        let out = meter.heard && !inTune
        return Capsule()
            .fill(LinearGradient(colors: [Palette.amber.opacity(0.05), Palette.amber.opacity(0.55)],
                                 startPoint: y > centre ? .top : .bottom, endPoint: y > centre ? .bottom : .top))
            .frame(width: 4, height: max(0, abs(y - centre)))
            .position(x: width / 2, y: (centre + y) / 2)
            .opacity(out ? 1 : 0)
            .animation(landing, value: meter.cents)
            .allowsHitTesting(false)
    }

    private var bead: some View {
        ZStack {
            if meter.approximate {
                // Hollow: read from a peak another string's overtone shares.
                Circle().fill(Palette.stage)
                Circle().strokeBorder(tone, lineWidth: 2.5)
            } else {
                Circle().fill(tone)
                Circle().fill(LinearGradient(colors: [.white.opacity(0.5), .clear], startPoint: .top, endPoint: .center))
            }
            Circle().strokeBorder(Palette.mint, lineWidth: 2).padding(-4).opacity(inTune ? 1 : 0)
        }
        .frame(width: 18, height: 18)
        .shadow(color: tone.opacity(0.6), radius: inTune ? 10 : 6)
        .opacity(meter.heard ? 1 : 0)
        .scaleEffect(meter.heard ? 1 : 0.4)
        .animation(landing, value: meter.heard)
        .animation(Motion.quick, value: inTune)
    }

    private var notHeard: some View {
        Text("Not heard")
            .font(Typeface.badge)
            .foregroundStyle(strong ? Palette.ink : Palette.inkSoft)
            .lineLimit(1)
            .fixedSize()
            .padding(.horizontal, 6).padding(.vertical, 3)
            .background(Capsule().fill(Palette.stage.opacity(0.9)))
            .rotationEffect(.degrees(-90))
            .transition(.opacity)
    }

    /// The chip names the string; the cents and, for an approximate reading, the "≈ estimate" badge follow. The
    /// badge keeps its place when hidden, so every lane's numbers line up.
    private var label: some View {
        VStack(spacing: 5) {
            StrumLaneChip(meter: meter, tone: meter.heard ? tone : nil, focus: focus, compact: narrow)
            Text(verbatim: StrumWords.cents(meter))
                .font(Typeface.number(12, relativeTo: .caption))
                .foregroundStyle(meter.heard ? tone : Palette.inkFaint)
                .contentTransition(.numericText(value: meter.cents ?? 0))
                .animation(landing, value: meter.cents)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            StrumEstimateBadge(compact: narrow)
                .opacity(meter.heard && meter.approximate ? 1 : 0)
                .scaleEffect(meter.heard && meter.approximate ? 1 : 0.8)
                .animation(landing, value: meter.heard && meter.approximate)
        }
        .padding(.horizontal, 2)
    }

    /// The string to tune first: a soft amber frame (it is always one that is off).
    @ViewBuilder private var halo: some View {
        if focus {
            let shape = RoundedRectangle(cornerRadius: Metrics.cornerTile, style: .continuous)
            shape.fill(Palette.amber.opacity(0.07))
                .overlay(shape.strokeBorder(Palette.amber.opacity(strong ? 0.9 : 0.4), lineWidth: 1))
                .padding(.horizontal, 2)
                .transition(.opacity)
        }
    }
}

// MARK: - Label chip and badges

/// A string's name on its lane: the number players call it by (1 the thinnest) in a small ring, then its note and
/// octave as the tuner's string rail writes them, and "×2" for a unison pair. The chip's ring takes the lane's
/// status: mint in tune, amber when off (filled for the string to tune first), quiet before it is heard.
struct StrumLaneChip: View {
    let meter: StrumBoard.Meter
    /// The status colour; nil before the string is heard.
    let tone: Color?
    var focus = false
    /// Narrow lanes: the note alone.
    var compact = false
    /// The note's point size (the zoomed lane's chip is larger).
    var size: CGFloat = 16
    @Environment(\.colorSchemeContrast) private var contrast

    private var strong: Bool { contrast == .increased }

    var body: some View {
        let ring = tone.map { $0.opacity(focus || strong ? 0.9 : 0.45) } ?? Color.white.opacity(strong ? 0.45 : 0.12)
        let fill = tone.map { $0.opacity(focus ? 0.16 : 0.06) } ?? Color.white.opacity(0.03)
        HStack(spacing: max(3, size * 0.22)) {
            if let number = meter.number, !compact { numberMark(number) }
            note
        }
        .lineLimit(1)
        .minimumScaleFactor(0.6)
        .padding(.horizontal, compact ? 4 : size * 0.42)
        .padding(.vertical, size * 0.28)
        .background(Capsule().fill(fill))
        .overlay(Capsule().strokeBorder(ring, lineWidth: focus ? 1.5 : 1))
        .animation(Motion.quick, value: focus)
    }

    private var note: some View {
        HStack(alignment: .firstTextBaseline, spacing: 1) {
            Text(verbatim: meter.name)
                .font(Typeface.label(size, relativeTo: .headline))
                .foregroundStyle(Palette.ink)
            Text(verbatim: meter.cue)
                .font(Typeface.label(max(10, size * 0.62), relativeTo: .caption2))
                .foregroundStyle(tone ?? (strong ? Palette.inkSoft : Palette.inkFaint))
            if meter.count > 1 && !compact {
                Text(verbatim: "×\(meter.count)")
                    .font(Typeface.label(max(9, size * 0.56), relativeTo: .caption2))
                    .foregroundStyle(strong ? Palette.ink : Palette.inkSoft)
                    .padding(.leading, 2)
            }
        }
    }

    /// The string number in a small ring, as chord charts and tab write it.
    private func numberMark(_ number: Int) -> some View {
        let side = max(15, size * 1.05)
        return Text(verbatim: "\(number)")
            .font(Typeface.label(max(9, size * 0.58), relativeTo: .caption2))
            .foregroundStyle(strong ? Palette.ink : Palette.inkSoft)
            .padding(.horizontal, 3)
            .frame(minWidth: side, minHeight: side)
            .background(Capsule().fill(Color.white.opacity(0.06)))
            .overlay(Capsule().strokeBorder(Color.white.opacity(strong ? 0.5 : 0.2), lineWidth: 1))
    }
}

/// "≈ estimate": the reading came from a peak another string's overtone shares (B3 under the low E's third
/// harmonic), good to a few cents; fine-tuning the string alone settles it. Its dashed edge matches the hollow
/// bead. Narrow lanes show the sign alone. Set at the badge size (12 pt, the smallest on the type scale) and growing
/// with the text size as far as its lane allows. Decorative: the lane's VoiceOver value says "estimate".
struct StrumEstimateBadge: View {
    var compact = false
    @Environment(\.colorSchemeContrast) private var contrast

    var body: some View {
        let strong = contrast == .increased
        Group {
            if compact {
                Text(verbatim: "≈")
            } else {
                // A long localized label must not become an unreadable ellipsis in a six-string lane.
                // Use the existing compact symbol when the complete label cannot fit; VoiceOver
                // still reads the lane's full localized estimate description.
                ViewThatFits(in: .horizontal) {
                    Text("≈ estimate").fixedSize(horizontal: true, vertical: false)
                    Text(verbatim: "≈")
                }
            }
        }
        .font(Typeface.badge)
        .foregroundStyle(strong ? Palette.ink : Palette.inkSoft)
        .lineLimit(1)
        .minimumScaleFactor(0.75)
        .padding(.horizontal, 5).padding(.vertical, 2)
        .background(Capsule().fill(Color.white.opacity(0.05)))
        .overlay(Capsule().strokeBorder(Color.white.opacity(strong ? 0.55 : 0.22), style: StrokeStyle(lineWidth: 1, dash: [2.5, 2])))
        .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
        .accessibilityHidden(true)
    }
}

/// The turn a string needs, over its meter: ↑ tune up (flat), ↓ tune down (sharp), ✓ in tune; nothing before
/// it is heard. It bounces once as each strum lands.
struct StrumTurnBadge: View {
    let shown: Int?
    let band: Double
    let pulse: Int
    var size: CGFloat = 22
    /// The tuner has locked the string (the zoomed lane): ✓ whatever the cents.
    var locked = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// 0 nothing, 1 in tune, 2 tune up, 3 tune down: the badge animates only when this changes.
    private var state: Int {
        if locked { return 1 }
        guard let shown else { return 0 }
        if Double(abs(shown)) <= band { return 1 }
        return shown < 0 ? 2 : 3
    }

    var body: some View {
        ZStack {
            switch state {
            case 1:
                Image(systemName: "checkmark")
                    .font(.system(size: size * 0.46, weight: .heavy))
                    .foregroundStyle(Palette.onAccent)
                    .frame(width: size, height: size)
                    .background(Circle().fill(Palette.mint))
                    .shadow(color: Palette.mint.opacity(0.5), radius: size * 0.27)
                    .transition(.scale(scale: 0.4).combined(with: .opacity))
            case 2, 3:
                arrow(up: state == 2)
                    .transition(.scale(scale: 0.4).combined(with: .opacity))
            default:
                EmptyView()
            }
        }
        .frame(height: size + 2)
        .animation(Motion.adaptive(Motion.pluck, reduceMotion: reduceMotion), value: state)
        .accessibilityHidden(true)
    }

    private func arrow(up: Bool) -> some View {
        Image(systemName: up ? "arrow.up" : "arrow.down")
            .font(.system(size: size * 0.5, weight: .heavy))
            .foregroundStyle(Palette.amber)
            .frame(width: size, height: size)
            .background(Circle().fill(Palette.amber.opacity(0.16)))
            .overlay(Circle().strokeBorder(Palette.amber.opacity(0.6), lineWidth: 1))
            .symbolEffect(.bounce, value: reduceMotion ? 0 : pulse)
    }
}

// MARK: - Track

/// The meter's scale and its string. Ticks every 10¢ either side of the string, the lock band (Settings ›
/// Precision) in mint around the target line, and the string itself in steel, its width by gauge (wound strings
/// show their winding), swinging as `ring` says. Decorative: the column speaks for it.
struct StrumStringTrack: View {
    let gauge: Double
    let lit: Bool
    let inTune: Bool
    let band: Double
    let ring: StrumRing
    let position: Int
    let count: Int
    let strong: Bool
    /// The zoomed lane: a string ringing on its own, this many points either way (nil: as `ring` says).
    var steady: Double? = nil
    /// The zoomed lane draws its scale, lock band and string larger, with the ±10, ±20 and ±50 marks named.
    var magnify: CGFloat = 1
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let still = reduceMotion || (steady.map { $0 < 0.05 } ?? !ring.active)
        TimelineView(.animation(minimumInterval: 1.0 / 60, paused: still)) { timeline in
            Canvas { context, size in
                let now = timeline.date.timeIntervalSinceReferenceDate
                scale(&context, size: size)
                let swing = reduceMotion ? 0 : (steady ?? ring.swing(at: now, position: position, of: count))
                string(&context, size: size, now: now, swing: swing)
            }
        }
        .accessibilityHidden(true)
    }

    private func scale(_ context: inout GraphicsContext, size: CGSize) {
        let mid = size.width / 2, centre = size.height / 2
        let unit = StrumScale.unit(size.height)
        let zoneWidth = min(22 * magnify, size.width - 4)
        let tick = strong ? Palette.inkSoft : Palette.inkFaint.opacity(0.55)
        if size.width >= 34 {
            for value in stride(from: -50, through: 50, by: 10) where value != 0 {
                let y = centre - CGFloat(value) * unit
                let length: CGFloat = (value % 50 == 0 ? 7 : 4) * magnify
                let gap = zoneWidth / 2 + 3
                context.fill(Path(CGRect(x: mid - gap - length, y: y - 0.5, width: length, height: 1)), with: .color(tick))
                context.fill(Path(CGRect(x: mid + gap, y: y - 0.5, width: length, height: 1)), with: .color(tick))
                if magnify > 1.5 && [10, 20, 50].contains(abs(value)) {
                    let name = (value > 0 ? "+" : "−") + "\(abs(value))"
                    context.draw(Text(verbatim: name).font(Typeface.number(.caption)).foregroundStyle(tick),
                                 at: CGPoint(x: mid - gap - length - 5, y: y), anchor: .trailing)
                }
            }
        }
        // The lock band: exactly where the tuner would lock.
        let half = max(3, CGFloat(band) * unit)
        let zone = CGRect(x: mid - zoneWidth / 2, y: centre - half, width: zoneWidth, height: half * 2)
        let radius = min(6 * magnify, half)
        context.fill(Path(roundedRect: zone, cornerRadius: radius), with: .color(Palette.mint.opacity(inTune ? 0.28 : 0.1)))
        context.stroke(Path(roundedRect: zone, cornerRadius: radius),
                       with: .color(Palette.mint.opacity(inTune || strong ? 0.95 : 0.45)), lineWidth: 1)
        // The target line.
        let line = min(28 * magnify, size.width - 2)
        context.fill(Path(CGRect(x: mid - line / 2, y: centre - 0.75, width: line, height: 1.5)), with: .color(Palette.ink.opacity(0.75)))
    }

    private func string(_ context: inout GraphicsContext, size: CGSize, now: Double, swing: Double) {
        let mid = size.width / 2
        let width = CGFloat(1.1 + 1.9 * gauge) * (1 + (magnify - 1) * 0.5)
        var path = Path()
        if swing < 0.05 {
            path.move(to: CGPoint(x: mid, y: 0))
            path.addLine(to: CGPoint(x: mid, y: size.height))
        } else {
            // A standing wave: thick strings swing slower. Only the shape is drawn, never a real frequency.
            let wobble = sin(2 * Double.pi * (13 - 5 * gauge) * now + Double(position) * 1.7)
            let steps = 28
            for step in 0...steps {
                let along = Double(step) / Double(steps)
                let point = CGPoint(x: mid + CGFloat(swing * sin(Double.pi * along) * wobble), y: size.height * CGFloat(along))
                if step == 0 { path.move(to: point) } else { path.addLine(to: point) }
            }
            // The blur of a string in motion.
            context.stroke(path, with: .color(StrumTone.steel.opacity(0.18 * min(1, swing / 4))), lineWidth: width + 6)
        }
        context.stroke(path, with: .color(StrumTone.steel.opacity(lit ? 0.85 : 0.35)), style: StrokeStyle(lineWidth: width, lineCap: .round))
        // Wound strings: the winding catches the light in fine bands.
        if gauge >= 0.45 && width >= 2.4 {
            context.stroke(path, with: .color(Color.black.opacity(lit ? 0.3 : 0.15)),
                           style: StrokeStyle(lineWidth: width, lineCap: .butt, dash: [0.9, 1.4]))
        }
    }
}

/// The hint's pick: it sweeps low to high across the strings, reaching each just as `StrumRing.hintHit` sets it
/// ringing. Mirrored for right-to-left layouts along with the meters.
struct StrumPickSweep: View {
    let ring: StrumRing

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 60, paused: !ring.hint)) { timeline in
            Canvas { context, size in
                let now = timeline.date.timeIntervalSinceReferenceDate
                guard ring.hint, now >= ring.hintStart else { return }
                let into = (now - ring.hintStart).truncatingRemainder(dividingBy: StrumRing.cycle)
                let progress = (into - StrumRing.sweepStart) / StrumRing.sweepLength
                let alpha = min(1, max(0, min((progress + 0.25) / 0.3, (1.25 - progress) / 0.3)))
                guard alpha > 0 else { return }
                let x = size.width * CGFloat(progress)
                let y = size.height * 0.6 - CGFloat(progress) * 30
                // A short trail, then the pick, tipped into the strum.
                var trail = Path()
                trail.move(to: CGPoint(x: x - 46, y: y + 12))
                trail.addLine(to: CGPoint(x: x - 6, y: y + 1))
                // The pick is warm stage light, not the amber that means a string is out.
                context.stroke(trail, with: .linearGradient(Gradient(colors: [Palette.spotlight.opacity(0), Palette.spotlight.opacity(0.35 * alpha)]),
                                                            startPoint: CGPoint(x: x - 46, y: y + 12), endPoint: CGPoint(x: x - 6, y: y + 1)),
                               style: StrokeStyle(lineWidth: 3, lineCap: .round))
                var pick = context
                pick.translateBy(x: x, y: y)
                pick.rotate(by: .degrees(-28))
                pick.opacity = alpha
                pick.fill(Self.pick, with: .linearGradient(Gradient(colors: [Color(hex: 0xFFD08A), Palette.spotlight]),
                                                          startPoint: CGPoint(x: 0, y: -10), endPoint: CGPoint(x: 0, y: 11)))
                pick.stroke(Self.pick, with: .color(.white.opacity(0.35)), lineWidth: 0.8)
            }
        }
        .flipsForRightToLeftLayoutDirection(true)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    /// A guitar pick, tip down, centred on the origin.
    private static let pick: Path = {
        var path = Path()
        path.move(to: CGPoint(x: 0, y: 11))
        path.addCurve(to: CGPoint(x: -8.5, y: -5), control1: CGPoint(x: -3, y: 7), control2: CGPoint(x: -9.5, y: 1))
        path.addCurve(to: CGPoint(x: 8.5, y: -5), control1: CGPoint(x: -6.5, y: -12), control2: CGPoint(x: 6.5, y: -12))
        path.addCurve(to: CGPoint(x: 0, y: 11), control1: CGPoint(x: 9.5, y: 1), control2: CGPoint(x: 3, y: 7))
        path.closeSubpath()
        return path
    }()
}

// MARK: - Row (accessibility text sizes)

/// A string's meter as a row, for the largest text sizes where a dozen columns cannot hold their words: the
/// label chip and its turn on top, a horizontal scale (flat left, sharp right) beneath. One element for VoiceOver.
struct StrumMeterRow: View {
    let meter: StrumBoard.Meter
    let band: Double
    let focus: Bool
    let waiting: Bool
    let pulse: Int
    @Environment(\.colorSchemeContrast) private var contrast

    var body: some View {
        let inTune = meter.inTune(band: band)
        let tone = StrumTone.status(meter, band: band)
        let shape = RoundedRectangle(cornerRadius: Metrics.cornerTile, style: .continuous)
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center, spacing: 10) {
                StrumLaneChip(meter: meter, tone: meter.heard ? tone : nil, focus: focus, size: 18)
                Spacer(minLength: 8)
                if waiting {
                    EmptyView()
                } else if meter.heard {
                    Text(verbatim: inTune ? String(localized: "In tune") : StrumWords.turn(meter))
                        .font(.body.weight(.semibold)).foregroundStyle(tone)
                        .multilineTextAlignment(.trailing)
                } else {
                    Text("Not heard").font(.body).foregroundStyle(Palette.inkSoft)
                }
            }
            if meter.heard && meter.approximate { StrumEstimateBadge() }
            StrumRowScale(meter: meter, band: band).frame(height: 30)
        }
        .padding(14)
        .background(shape.fill(Palette.stageRaised))
        .overlay(shape.strokeBorder(focus ? Palette.amber.opacity(0.7) : rim, lineWidth: 1))
        .opacity(!waiting && !meter.heard ? 0.6 : 1)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(StrumWords.name(meter))
        .accessibilityValue(StrumWords.state(meter, band: band, waiting: waiting))
        .accessibilityAddTraits(focus ? .isSelected : [])
    }

    /// A card's hairline; brighter than the token with Increase Contrast, as the lanes' own rims are.
    private var rim: Color { contrast == .increased ? Color.white.opacity(0.3) : Palette.hairline }
}

/// The row's ±50¢ scale: the string across it in steel, the lock band in mint, the bead where it was heard in the
/// status colour (hollow when approximate).
private struct StrumRowScale: View {
    let meter: StrumBoard.Meter
    let band: Double

    var body: some View {
        Canvas { context, size in
            let mid = size.width / 2, centre = size.height / 2
            let unit = max(0.5, (size.width / 2 - 12) / 50)
            context.fill(Path(CGRect(x: 0, y: centre - 1, width: size.width, height: 2)), with: .color(StrumTone.steel.opacity(meter.heard ? 0.7 : 0.3)))
            let half = max(3, CGFloat(band) * unit)
            let zone = CGRect(x: mid - half, y: centre - 11, width: half * 2, height: 22)
            context.fill(Path(roundedRect: zone, cornerRadius: min(6, half)), with: .color(Palette.mint.opacity(meter.inTune(band: band) ? 0.28 : 0.1)))
            context.stroke(Path(roundedRect: zone, cornerRadius: min(6, half)), with: .color(Palette.mint.opacity(0.6)), lineWidth: 1)
            context.fill(Path(CGRect(x: mid - 0.75, y: centre - 13, width: 1.5, height: 26)), with: .color(Palette.ink.opacity(0.75)))
            guard let cents = meter.cents else { return }
            let tone = StrumTone.status(meter, band: band)
            let x = mid + CGFloat(max(-50, min(50, cents))) * unit
            let dot = CGRect(x: x - 9, y: centre - 9, width: 18, height: 18)
            if meter.approximate {
                context.fill(Path(ellipseIn: dot), with: .color(Palette.stageRaised))
                context.stroke(Path(ellipseIn: dot.insetBy(dx: 1.25, dy: 1.25)), with: .color(tone), lineWidth: 2.5)
            } else {
                context.fill(Path(ellipseIn: dot), with: .color(tone))
            }
        }
        .accessibilityHidden(true)
    }
}
