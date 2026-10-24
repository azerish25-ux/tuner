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

// MARK: - Column (regular sizes)

/// A string's meter: the ±50¢ scale with the string running down its middle in the string's colour, the bead where
/// the strum heard it (hollow when approximate) pulled toward the target line, the turn it needs on top (↑ tune up
/// when flat, ↓ down when sharp, ✓ in tune) and its note and cents below. A string not heard stays dim, marked
/// "Not heard"; the string to tune first is framed. One element for VoiceOver.
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

    var body: some View {
        VStack(spacing: 8) {
            StrumTurnBadge(meter: meter, band: band, pulse: pulse)
            track
            label
        }
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity)
        .background { halo }
        .opacity(dim ? 0.5 : 1)
        .animation(Motion.quick, value: dim)
        .animation(reduceMotion ? .easeInOut(duration: 0.2) : Motion.settle, value: focus)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(StrumWords.name(meter))
        .accessibilityValue(StrumWords.state(meter, band: band, waiting: waiting))
        .accessibilityAddTraits(focus ? .isSelected : [])
    }

    /// Beads land one after another, low string first, like the strum that played them.
    private var landing: Animation {
        reduceMotion ? .easeOut(duration: 0.2) : Motion.pluck.delay(Double(position) * 0.035)
    }

    private var track: some View {
        GeometryReader { proxy in
            let size = proxy.size
            let centre = size.height / 2
            let y = StrumScale.y(meter.cents, height: size.height)
            ZStack {
                StrumStringTrack(color: meter.color, gauge: meter.gauge, lit: !dim, inTune: inTune, band: band,
                                 ring: ring, position: position, count: count, strong: strong)
                tension(from: centre, to: y, width: size.width)
                bead.position(x: size.width / 2, y: y)
                    .animation(landing, value: meter.cents)
                if dim { notHeard.position(x: size.width / 2, y: centre) }
            }
        }
        .frame(minHeight: 120)
    }

    /// The pull from the bead to the target line, in the tuner's colour rule, while a string is out.
    private func tension(from centre: CGFloat, to y: CGFloat, width: CGFloat) -> some View {
        let out = meter.heard && !inTune
        let tone = Palette.tuning(meter.shown.map { Double($0) }, locked: false)
        return Capsule()
            .fill(LinearGradient(colors: [tone.opacity(0.05), tone.opacity(0.55)],
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
                Circle().strokeBorder(meter.color, lineWidth: 2.5)
            } else {
                Circle().fill(meter.color)
                Circle().fill(LinearGradient(colors: [.white.opacity(0.5), .clear], startPoint: .top, endPoint: .center))
            }
            Circle().strokeBorder(Palette.mint, lineWidth: 2).padding(-4).opacity(inTune ? 1 : 0)
        }
        .frame(width: 18, height: 18)
        .shadow(color: (inTune ? Palette.mint : meter.color).opacity(0.6), radius: inTune ? 10 : 6)
        .opacity(meter.heard ? 1 : 0)
        .scaleEffect(meter.heard ? 1 : 0.4)
        .animation(landing, value: meter.heard)
        .animation(Motion.quick, value: inTune)
    }

    private var notHeard: some View {
        Text("Not heard")
            .font(Typeface.label(10, relativeTo: .caption2))
            .foregroundStyle(strong ? Palette.ink : Palette.inkSoft)
            .lineLimit(1)
            .fixedSize()
            .padding(.horizontal, 6).padding(.vertical, 3)
            .background(Capsule().fill(Palette.stage.opacity(0.9)))
            .rotationEffect(.degrees(-90))
            .transition(.opacity)
    }

    private var label: some View {
        VStack(spacing: 2) {
            HStack(alignment: .firstTextBaseline, spacing: 1) {
                Text(verbatim: meter.name).font(Typeface.label(16, relativeTo: .headline)).foregroundStyle(Palette.ink)
                Text(verbatim: meter.cue).font(Typeface.label(10, relativeTo: .caption2))
                    .foregroundStyle(strong ? Palette.inkSoft : meter.color.opacity(0.85))
            }
            Text(verbatim: meter.count > 1 ? "×\(meter.count)" : " ")
                .font(Typeface.label(9, relativeTo: .caption2)).foregroundStyle(Palette.inkSoft)
            Text(verbatim: StrumWords.cents(meter))
                .font(Typeface.number(12, relativeTo: .caption))
                .foregroundStyle(meter.heard ? Palette.tuning(meter.shown.map { Double($0) }, locked: false) : Palette.inkFaint)
                .contentTransition(.numericText(value: meter.cents ?? 0))
                .animation(landing, value: meter.cents)
        }
        .lineLimit(1)
        .minimumScaleFactor(0.6)
        .padding(.horizontal, 2)
    }

    /// The string to tune first: a soft frame in the colour of its offset.
    @ViewBuilder private var halo: some View {
        if focus {
            let tone = Palette.tuning(meter.shown.map { Double($0) }, locked: false)
            let shape = RoundedRectangle(cornerRadius: 14, style: .continuous)
            shape.fill(tone.opacity(0.08))
                .overlay(shape.strokeBorder(tone.opacity(strong ? 0.9 : 0.45), lineWidth: 1))
                .padding(.horizontal, 2)
                .transition(.opacity)
        }
    }
}

/// The turn a string needs, over its meter: ↑ tune up (flat), ↓ tune down (sharp), ✓ in tune; nothing before
/// it is heard. It bounces once as each strum lands.
private struct StrumTurnBadge: View {
    let meter: StrumBoard.Meter
    let band: Double
    let pulse: Int
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            if let shown = meter.shown {
                if Double(abs(shown)) <= band {
                    Image(systemName: "checkmark")
                        .font(.system(size: 10, weight: .heavy))
                        .foregroundStyle(Palette.onAccent)
                        .frame(width: 22, height: 22)
                        .background(Circle().fill(Palette.mint))
                        .shadow(color: Palette.mint.opacity(0.5), radius: 6)
                        .transition(.scale(scale: 0.4).combined(with: .opacity))
                } else {
                    arrow(up: shown < 0, tone: Palette.tuning(Double(shown), locked: false))
                        .transition(.scale(scale: 0.4).combined(with: .opacity))
                }
            }
        }
        .frame(height: 24)
        .animation(reduceMotion ? .easeInOut(duration: 0.2) : Motion.pluck, value: meter.shown)
        .accessibilityHidden(true)
    }

    private func arrow(up: Bool, tone: Color) -> some View {
        Image(systemName: up ? "arrow.up" : "arrow.down")
            .font(.system(size: 11, weight: .heavy))
            .foregroundStyle(tone)
            .frame(width: 22, height: 22)
            .background(Circle().fill(tone.opacity(0.16)))
            .overlay(Circle().strokeBorder(tone.opacity(0.6), lineWidth: 1))
            .symbolEffect(.bounce, value: reduceMotion ? 0 : pulse)
    }
}

/// The meter's scale and its string. Ticks every 10¢ either side of the string, the lock band (Settings ›
/// Precision) in mint around the target line, and the string itself, its width by gauge, swinging as `ring` says.
/// Decorative: the column speaks for it.
private struct StrumStringTrack: View {
    let color: Color
    let gauge: Double
    let lit: Bool
    let inTune: Bool
    let band: Double
    let ring: StrumRing
    let position: Int
    let count: Int
    let strong: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 60, paused: reduceMotion || !ring.active)) { timeline in
            Canvas { context, size in
                let now = timeline.date.timeIntervalSinceReferenceDate
                scale(&context, size: size)
                string(&context, size: size, now: now, swing: reduceMotion ? 0 : ring.swing(at: now, position: position, of: count))
            }
        }
        .accessibilityHidden(true)
    }

    private func scale(_ context: inout GraphicsContext, size: CGSize) {
        let mid = size.width / 2, centre = size.height / 2
        let unit = StrumScale.unit(size.height)
        let zoneWidth = min(22, size.width - 4)
        if size.width >= 34 {
            let tick = strong ? Palette.inkSoft : Palette.inkFaint.opacity(0.55)
            for value in stride(from: -50, through: 50, by: 10) where value != 0 {
                let y = centre - CGFloat(value) * unit
                let length: CGFloat = value % 50 == 0 ? 7 : 4
                let gap = zoneWidth / 2 + 3
                context.fill(Path(CGRect(x: mid - gap - length, y: y - 0.5, width: length, height: 1)), with: .color(tick))
                context.fill(Path(CGRect(x: mid + gap, y: y - 0.5, width: length, height: 1)), with: .color(tick))
            }
        }
        // The lock band: exactly where the tuner would lock.
        let half = max(3, CGFloat(band) * unit)
        let zone = CGRect(x: mid - zoneWidth / 2, y: centre - half, width: zoneWidth, height: half * 2)
        let radius = min(6, half)
        context.fill(Path(roundedRect: zone, cornerRadius: radius), with: .color(Palette.mint.opacity(inTune ? 0.28 : 0.1)))
        context.stroke(Path(roundedRect: zone, cornerRadius: radius),
                       with: .color(Palette.mint.opacity(inTune || strong ? 0.95 : 0.45)), lineWidth: 1)
        // The target line.
        let line = min(28, size.width - 2)
        context.fill(Path(CGRect(x: mid - line / 2, y: centre - 0.75, width: line, height: 1.5)), with: .color(Palette.ink.opacity(0.75)))
    }

    private func string(_ context: inout GraphicsContext, size: CGSize, now: Double, swing: Double) {
        let mid = size.width / 2
        let width = CGFloat(1.1 + 1.9 * gauge)
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
            context.stroke(path, with: .color(color.opacity(0.22 * min(1, swing / 4))), lineWidth: width + 6)
        }
        context.stroke(path, with: .color(color.opacity(lit ? 0.95 : 0.4)), style: StrokeStyle(lineWidth: width, lineCap: .round))
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
                context.stroke(trail, with: .linearGradient(Gradient(colors: [Palette.amber.opacity(0), Palette.amber.opacity(0.35 * alpha)]),
                                                            startPoint: CGPoint(x: x - 46, y: y + 12), endPoint: CGPoint(x: x - 6, y: y + 1)),
                               style: StrokeStyle(lineWidth: 3, lineCap: .round))
                var pick = context
                pick.translateBy(x: x, y: y)
                pick.rotate(by: .degrees(-28))
                pick.opacity = alpha
                pick.fill(Self.pick, with: .linearGradient(Gradient(colors: [Color(hex: 0xFFD08A), Palette.amber]),
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
/// note and its cents and turn on top, a horizontal scale (flat left, sharp right) beneath. One element for VoiceOver.
struct StrumMeterRow: View {
    let meter: StrumBoard.Meter
    let band: Double
    let focus: Bool
    let waiting: Bool
    let pulse: Int
    @Environment(\.colorSchemeContrast) private var contrast

    var body: some View {
        let inTune = meter.inTune(band: band)
        let tone = Palette.tuning(meter.shown.map { Double($0) }, locked: false)
        let shape = RoundedRectangle(cornerRadius: 18, style: .continuous)
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Circle().fill(meter.color).frame(width: 10, height: 10)
                Text(verbatim: meter.count > 1 ? "\(meter.note) ×\(meter.count)" : meter.note)
                    .font(Typeface.label(18, relativeTo: .headline)).foregroundStyle(Palette.ink)
                Spacer(minLength: 8)
                if waiting {
                    EmptyView()
                } else if meter.heard {
                    Text(verbatim: inTune ? String(localized: "In tune") : StrumWords.turn(meter))
                        .font(.body.weight(.semibold)).foregroundStyle(inTune ? Palette.mint : tone)
                        .multilineTextAlignment(.trailing)
                } else {
                    Text("Not heard").font(.body).foregroundStyle(Palette.inkSoft)
                }
            }
            StrumRowScale(meter: meter, band: band).frame(height: 30)
        }
        .padding(14)
        .background(shape.fill(Palette.stageRaised))
        .overlay(shape.strokeBorder(focus ? tone.opacity(0.7) : Color.white.opacity(contrast == .increased ? 0.3 : 0.06), lineWidth: 1))
        .opacity(!waiting && !meter.heard ? 0.6 : 1)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(StrumWords.name(meter))
        .accessibilityValue(StrumWords.state(meter, band: band, waiting: waiting))
        .accessibilityAddTraits(focus ? .isSelected : [])
    }
}

/// The row's ±50¢ scale: the string across it in its colour, the lock band in mint, the bead where it was heard.
private struct StrumRowScale: View {
    let meter: StrumBoard.Meter
    let band: Double

    var body: some View {
        Canvas { context, size in
            let mid = size.width / 2, centre = size.height / 2
            let unit = max(0.5, (size.width / 2 - 12) / 50)
            context.fill(Path(CGRect(x: 0, y: centre - 1, width: size.width, height: 2)), with: .color(meter.color.opacity(meter.heard ? 0.8 : 0.35)))
            let half = max(3, CGFloat(band) * unit)
            let zone = CGRect(x: mid - half, y: centre - 11, width: half * 2, height: 22)
            context.fill(Path(roundedRect: zone, cornerRadius: min(6, half)), with: .color(Palette.mint.opacity(meter.inTune(band: band) ? 0.28 : 0.1)))
            context.stroke(Path(roundedRect: zone, cornerRadius: min(6, half)), with: .color(Palette.mint.opacity(0.6)), lineWidth: 1)
            context.fill(Path(CGRect(x: mid - 0.75, y: centre - 13, width: 1.5, height: 26)), with: .color(Palette.ink.opacity(0.75)))
            guard let cents = meter.cents else { return }
            let x = mid + CGFloat(max(-50, min(50, cents))) * unit
            let dot = CGRect(x: x - 9, y: centre - 9, width: 18, height: 18)
            if meter.approximate {
                context.fill(Path(ellipseIn: dot), with: .color(Palette.stageRaised))
                context.stroke(Path(ellipseIn: dot.insetBy(dx: 1.25, dy: 1.25)), with: .color(meter.color), lineWidth: 2.5)
            } else {
                context.fill(Path(ellipseIn: dot), with: .color(meter.color))
            }
        }
        .accessibilityHidden(true)
    }
}
