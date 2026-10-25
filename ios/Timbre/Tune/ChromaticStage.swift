import SwiftUI
import TimbreCore

/// Chromatic mode's stage: a lit strobe disc in a precision instrument's dial, after the Peterson strobes.
///
/// - **The disc**: four bands of slots (12, 24, 48 and 96, each an octave finer than the one inside it) cut in one
///   disc and lit from behind. It turns with the pitch error, clockwise when sharp and anticlockwise when flat: a cent
///   off it creeps, far off it races and blurs, and in tune it stands dead still.
/// - **The needle arc** around the disc: ±50 cents, the tracker's own lock band in mint, ♭ and ♯ at its ends.
/// - **The note wheel** outside that: the twelve notes, turning to bring the note heard (or held) under the index at
///   the top. A tap on a note holds it (Manual); VoiceOver adjusts it a semitone at a time.
///
/// Colour follows the tuner's one rule (mint in the lock band, amber to 20 cents, coral beyond). With Reduce Motion
/// the disc holds still and unlit (a still strobe reads as in tune) until the lock, the wheel steps instead of turning,
/// and the needle alone reads the pitch.
struct ChromaticStage: View {
    let input: () -> StageInput
    /// The note heard or held, as a MIDI number in the player's transposition (the readout's note).
    let midi: Int
    /// Settings › Note names: how the wheel spells its notes.
    let notation: String
    /// The host isn't listening and holds no reading: with no pitch the disc stands still, so it draws once
    /// and stops redrawing until the host listens again.
    let resting: Bool
    /// Holds a note (a MIDI number in the same transposition as `midi`): a tap on the wheel, or VoiceOver.
    let onPick: ((Int) -> Void)?
    @State private var motion = ReadoutMotion()
    /// The moment the pitch locks, for the ring of light it sends across the disc.
    @State private var flash = LockFlash()
    /// The wheel's turn in degrees, unwound: it always takes the short way round to the next note.
    @State private var wheel: Double
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorSchemeContrast) private var contrast

    init(input: @escaping () -> StageInput, midi: Int, notation: String = "english", resting: Bool = false,
         onPick: ((Int) -> Void)? = nil) {
        self.input = input
        self.midi = midi
        self.notation = notation
        self.resting = resting
        self.onPick = onPick
        _wheel = State(initialValue: Self.wheelAngle(for: midi))
    }

    var body: some View {
        GeometryReader { proxy in
            let side = min(proxy.size.width, proxy.size.height)
            ZStack {
                StrobeDialFace(strong: contrast == .increased, band: Palette.tuningBand)
                noteWheel(side: side)
                live
                StrobeDialGlass().allowsHitTesting(false)
            }
            .frame(width: side, height: side)
            .contentShape(Circle())
            .onTapGesture(coordinateSpace: .local) { location in pick(at: location, side: side) }
            .position(x: proxy.size.width / 2, y: proxy.size.height / 2)
        }
        .onChange(of: midi) { _, new in turnWheel(to: new) }
        // The readout below speaks the pitch; the dial speaks only the note it holds, which VoiceOver can step.
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("Note"))
        .accessibilityValue(Text(verbatim: PitchMath.noteName(midi: midi, notation: notation)))
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment: onPick?(midi + 1)
            case .decrement: onPick?(midi - 1)
            @unknown default: break
            }
        }
        .accessibilityHidden(onPick == nil)
    }

    // MARK: The disc and needle, every frame

    private var live: some View {
        TimelineView(.animation(minimumInterval: reduceMotion ? 0.1 : nil, paused: resting)) { timeline in
            let state = input()
            let now = timeline.date.timeIntervalSinceReferenceDate
            let _ = motion.step(state.listening ? state.cents : nil, locked: state.locked, now: now)
            let shock = flash.step(locked: state.listening && state.locked, key: "chromatic", now: now, duration: StrobeRipple.shock)
            let reading = StrobeReading(motion: motion, input: state, still: reduceMotion)
            let effects = ShaderFX.allowed(reduceMotion: reduceMotion)
            ZStack {
                Canvas { context, size in StrobeDisc.draw(reading, in: &context, size: size) }
                    // The lamp blooms through the slots and smears them as the disc races (Shaders.metal); the lock
                    // sends a ring of light out across the dial.
                    .strobeLamp(spin: reading.smear, glow: reading.glow, enabled: effects)
                    .strobeRipple(phase: motion.phase, depth: 0, shock: shock, enabled: effects)
                Canvas { context, size in StrobeNeedle.draw(reading, in: &context, size: size) }
            }
        }
    }

    // MARK: The note wheel

    private func noteWheel(side: CGFloat) -> some View {
        let radius = side / 2 * StrobeDialFace.wheelRadius
        let active = PitchMath.pitchClass(midi: midi)
        return ZStack {
            ForEach(0..<12, id: \.self) { pitchClass in
                wheelTick(pitchClass, radius: side / 2 * 0.94, side: side)
                wheelLabel(pitchClass, active: pitchClass == active, radius: radius, side: side)
            }
        }
        .frame(width: side, height: side)
        .rotationEffect(.degrees(wheel))
        .dynamicTypeSize(.large)
    }

    /// One note on the wheel, kept upright as the wheel turns: bright under the index, fading round the back.
    private func wheelLabel(_ pitchClass: Int, active: Bool, radius: CGFloat, side: CGFloat) -> some View {
        let angle = Double(pitchClass) * 30
        let away = Self.degreesFromTop(angle + wheel)
        let faded = max(0.22, 0.8 - away / 170)
        let strong = contrast == .increased
        return Text(verbatim: Self.wheelName(pitchClass, notation: notation))
            .font(Typeface.label(max(9, side * 0.042), relativeTo: .caption))
            .foregroundStyle(active ? Palette.ink : (strong ? Palette.inkSoft : Palette.inkFaint))
            .lineLimit(1)
            .fixedSize()
            .scaleEffect(active ? 1.32 : 1)
            .opacity(active ? 1 : faded)
            .shadow(color: active ? Palette.ink.opacity(0.35) : .clear, radius: 6)
            .animation(reduceMotion ? nil : Motion.settle, value: active)
            .rotationEffect(.degrees(-(angle + wheel)))
            .offset(y: -radius)
            .rotationEffect(.degrees(angle))
    }

    /// The mark between two notes, turning with the wheel.
    private func wheelTick(_ pitchClass: Int, radius: CGFloat, side: CGFloat) -> some View {
        Capsule()
            .fill(Palette.inkFaint.opacity(0.45))
            .frame(width: 1.2, height: max(3, side * 0.014))
            .offset(y: -radius)
            .rotationEffect(.degrees(Double(pitchClass) * 30 + 15))
    }

    private func turnWheel(to midi: Int) {
        var delta = (Self.wheelAngle(for: midi) - wheel).truncatingRemainder(dividingBy: 360)
        if delta > 180 { delta -= 360 } else if delta < -180 { delta += 360 }
        guard delta != 0 else { return }
        if reduceMotion {
            wheel += delta
        } else {
            withAnimation(Motion.settle) { wheel += delta }
        }
    }

    /// A tap on the wheel holds that note, in the octave nearest the one heard.
    private func pick(at location: CGPoint, side: CGFloat) {
        guard let onPick, side > 0 else { return }
        let dx = Double(location.x - side / 2), dy = Double(location.y - side / 2)
        let distance = (dx * dx + dy * dy).squareRoot() / Double(side / 2)
        guard distance > 0.78, distance < 1.04 else { return }
        // Clockwise from the top, where the wheel puts each note at its pitch class × 30° plus its turn.
        let bearing = atan2(dx, -dy) * 180 / Double.pi
        let slot = Int(((bearing - wheel) / 30).rounded())
        let pitchClass = ((slot % 12) + 12) % 12
        var step = ((pitchClass - PitchMath.pitchClass(midi: midi)) % 12 + 12) % 12
        if step > 6 { step -= 12 }
        Haptics.shared.selection()
        onPick(midi + step)
    }

    /// The wheel's turn that brings `midi`'s note under the index at the top.
    static func wheelAngle(for midi: Int) -> Double { -Double(PitchMath.pitchClass(midi: midi)) * 30 }

    /// How far round from the top an angle (degrees, clockwise) lies: 0…180.
    static func degreesFromTop(_ degrees: Double) -> Double {
        let turned = abs(degrees.truncatingRemainder(dividingBy: 360))
        return min(turned, 360 - turned)
    }

    /// A pitch class as the wheel prints it, in the player's note names, with ♯ for #.
    static func wheelName(_ pitchClass: Int, notation: String) -> String {
        // Middle C's octave is 4: one digit to drop.
        let full = PitchMath.noteName(midi: 60 + pitchClass, notation: notation)
        return String(full.dropLast()).replacingOccurrences(of: "#", with: "♯")
    }
}

/// One frame of the chromatic dial: what the disc, the needle and the hub show.
struct StrobeReading {
    /// A pitch is heard (listening, with a reading).
    let heard: Bool
    let locked: Bool
    /// The smoothed cents, for the needle (0 once locked).
    let cents: Double
    /// The tuner's colour for the pitch, judged on the whole cents the readout shows.
    let tone: Color
    /// The disc's turn, in radians.
    let turn: Double
    /// 0…1: how bright the lamp burns, with the input level.
    let lamp: Double
    /// The disc is lit (with Reduce Motion, only on the lock).
    let lit: Bool
    /// How far the disc turns in a glance, in radians, for the lamp's smear.
    let smear: Double

    init(motion: ReadoutMotion, input: StageInput, still: Bool) {
        let heard = input.listening && motion.cents != nil
        let locked = heard && input.locked
        let cents = locked ? 0 : (motion.cents ?? 0)
        self.heard = heard
        self.locked = locked
        self.cents = cents
        let judged: Double? = motion.shown.map { Double($0) } ?? motion.cents
        tone = heard ? Palette.tuning(judged, locked: locked) : Palette.inkFaint
        turn = still ? 0 : motion.phase * StrobeDisc.turnPerCycle
        lamp = heard ? max(0, min(1, (input.level + 60) / 45)) : 0
        lit = heard && (!still || locked)
        let speed = abs(max(-50, min(50, cents))) * ReadoutMotion.strobeRate * StrobeDisc.turnPerCycle
        smear = still || !heard ? 0 : speed * StrobeDisc.glance
    }

    /// The lamp's bloom: full on the lock, otherwise with the input level; none while unlit.
    var glow: Double {
        guard lit else { return 0 }
        return locked ? 1 : 0.45 + 0.4 * lamp
    }
}

/// The slotted disc, turning (`ChromaticStage`). Sizes are fractions of the dial's radius.
enum StrobeDisc {
    /// Outside in: each band's radius and its lit slots round the disc, half as many as the band outside it.
    static let bands: [(radius: CGFloat, slots: Int)] = [(0.548, 96), (0.455, 48), (0.362, 24), (0.269, 12)]
    static let bandWidth: CGFloat = 0.066
    /// The disc's well, which the bands sit in.
    static let well: CGFloat = 0.61
    /// The disc turns a twelfth for each cycle of the strobe phase: a whole number of slots in every band, so a phase
    /// that wraps from 1 back to 0 never jumps. A cent off, it creeps 2.7° a second; 50 cents off, 135°.
    static let turnPerCycle = 2 * Double.pi / 12
    /// The eye's exposure for the lamp's smear, in seconds.
    static let glance = 1.0 / 24

    static func draw(_ reading: StrobeReading, in context: inout GraphicsContext, size: CGSize) {
        let radius = min(size.width, size.height) / 2
        let center = CGPoint(x: size.width / 2, y: size.height / 2)
        if reading.lit {
            // The lamp behind the disc.
            let r = radius * well
            let lamp = Gradient(colors: [reading.tone.opacity(0.08 + 0.14 * reading.lamp), reading.tone.opacity(0.05), .clear])
            context.fill(Path(ellipseIn: CGRect(x: center.x - r, y: center.y - r, width: r * 2, height: r * 2)),
                         with: .radialGradient(lamp, center: center, startRadius: radius * 0.2, endRadius: r))
        }
        for (index, band) in bands.enumerated() {
            drawBand(index: index, radius: radius * band.radius, slots: band.slots, width: radius * bandWidth,
                     center: center, reading: reading, in: &context)
        }
    }

    private static func drawBand(index: Int, radius r: CGFloat, slots: Int, width: CGFloat, center: CGPoint,
                                 reading: StrobeReading, in context: inout GraphicsContext) {
        let fade = 1 - 0.1 * Double(index)
        if reading.lit {
            // The lamp's light along the band's track, glimpsed between the slots.
            let track = Path(ellipseIn: CGRect(x: center.x - r, y: center.y - r, width: r * 2, height: r * 2))
            context.stroke(track, with: .color(reading.tone.opacity((0.04 + 0.03 * reading.lamp) * fade)), lineWidth: width)
        }
        // Lit slots and dark bars of equal width, every slot an arc stroked across the band with square ends, so its
        // edges run straight out from the centre.
        let period = 2 * Double.pi / Double(slots)
        let start = -Double.pi / 2 + reading.turn
        var path = Path()
        for k in 0..<slots {
            let a = start + Double(k) * period
            path.move(to: CGPoint(x: center.x + r * CGFloat(cos(a)), y: center.y + r * CGFloat(sin(a))))
            path.addArc(center: center, radius: r, startAngle: .radians(a), endAngle: .radians(a + period / 2), clockwise: false)
        }
        let ink: Color
        if reading.lit {
            ink = reading.tone.opacity((reading.locked ? 0.95 : 0.5 + 0.3 * reading.lamp) * fade)
        } else {
            ink = Palette.inkFaint.opacity(0.17 * fade)
        }
        context.stroke(path, with: .color(ink), style: StrokeStyle(lineWidth: width, lineCap: .butt))
    }
}

/// The needle over the arc and the disc's hub, drawn every frame above the turning disc (`ChromaticStage`).
enum StrobeNeedle {
    /// The arc spans ±50 cents over 60° either side of the top.
    static let span = Double.pi / 3
    /// The needle runs between these fractions of the dial's radius, across the arc's ticks.
    static let inner: CGFloat = 0.625
    static let outer: CGFloat = 0.78
    static let hub: CGFloat = 0.2

    /// The angle (radians, clockwise from three o'clock as a canvas draws) of `cents` on the arc.
    static func angle(cents: Double) -> Double { -Double.pi / 2 + max(-50, min(50, cents)) / 50 * span }

    static func point(_ angle: Double, _ radius: CGFloat, from center: CGPoint) -> CGPoint {
        CGPoint(x: center.x + radius * CGFloat(cos(angle)), y: center.y + radius * CGFloat(sin(angle)))
    }

    static func draw(_ reading: StrobeReading, in context: inout GraphicsContext, size: CGSize) {
        let radius = min(size.width, size.height) / 2
        let center = CGPoint(x: size.width / 2, y: size.height / 2)
        if reading.locked {
            // The lock zone lights.
            let band = max(Palette.tuningBand, 1.5)
            var zone = Path()
            zone.addArc(center: center, radius: radius * 0.7, startAngle: .radians(angle(cents: -band)),
                        endAngle: .radians(angle(cents: band)), clockwise: false)
            context.stroke(zone, with: .color(Palette.mint.opacity(0.4)), style: StrokeStyle(lineWidth: radius * 0.11, lineCap: .butt))
        }
        drawNeedle(reading, center: center, radius: radius, in: &context)
        drawHub(reading, center: center, radius: radius, in: &context)
    }

    private static func drawNeedle(_ reading: StrobeReading, center: CGPoint, radius: CGFloat, in context: inout GraphicsContext) {
        // At rest the needle parks at zero, unlit.
        let a = angle(cents: reading.cents)
        let tip = point(a, radius * outer, from: center)
        var line = Path()
        line.move(to: point(a, radius * inner, from: center))
        line.addLine(to: tip)
        // Weights grow with the dial (an iPad's is twice a phone's).
        let core = max(2.5, radius * 0.017)
        if reading.heard {
            let halo = max(14, radius * 0.1)
            context.stroke(line, with: .color(reading.tone.opacity(0.26)), style: StrokeStyle(lineWidth: core * 3.5, lineCap: .round))
            context.fill(Path(ellipseIn: CGRect(x: tip.x - halo, y: tip.y - halo, width: halo * 2, height: halo * 2)),
                         with: .radialGradient(Gradient(colors: [reading.tone.opacity(0.55), .clear]), center: tip, startRadius: 0, endRadius: halo))
        }
        let ink: Color = reading.heard ? reading.tone : Palette.inkFaint.opacity(0.55)
        context.stroke(line, with: .color(ink), style: StrokeStyle(lineWidth: core, lineCap: .round))
        let dot = core * 1.2
        context.fill(Path(ellipseIn: CGRect(x: tip.x - dot, y: tip.y - dot, width: dot * 2, height: dot * 2)), with: .color(ink))
    }

    private static func drawHub(_ reading: StrobeReading, center: CGPoint, radius: CGFloat, in context: inout GraphicsContext) {
        let r = radius * hub
        let cap = Path(ellipseIn: CGRect(x: center.x - r, y: center.y - r, width: r * 2, height: r * 2))
        let metal = Gradient(colors: [Color(hex: 0x2A2E35), Palette.stageRaised, Palette.stageDeep])
        let light = CGPoint(x: center.x - r * 0.35, y: center.y - r * 0.45)
        context.fill(cap, with: .radialGradient(metal, center: light, startRadius: 0, endRadius: r * 1.5))
        context.stroke(cap, with: .color(.white.opacity(0.13)), lineWidth: 1)
        let ring = r * 0.68
        context.stroke(Path(ellipseIn: CGRect(x: center.x - ring, y: center.y - ring, width: ring * 2, height: ring * 2)),
                       with: .color(.white.opacity(0.05)), lineWidth: 1)
        // The lamp's pilot light: the pitch's colour while heard, glowing on the lock.
        if reading.lit {
            let halo = r * (reading.locked ? 0.9 : 0.55)
            context.fill(Path(ellipseIn: CGRect(x: center.x - halo, y: center.y - halo, width: halo * 2, height: halo * 2)),
                         with: .radialGradient(Gradient(colors: [reading.tone.opacity(reading.locked ? 0.6 : 0.35), .clear]),
                                               center: center, startRadius: 0, endRadius: halo))
        }
        let led = max(2.5, r * 0.16)
        let ledInk: Color = reading.heard ? reading.tone : Palette.inkFaint.opacity(0.4)
        context.fill(Path(ellipseIn: CGRect(x: center.x - led, y: center.y - led, width: led * 2, height: led * 2)), with: .color(ledInk))
    }
}

/// The dial's still face, drawn once: the bezel, the note wheel's track, the needle's arc with its cents ticks,
/// colour track, lock zone and ♭ ♯, and the disc's well.
struct StrobeDialFace: View {
    /// Increase Contrast: brighter ticks and outlines.
    let strong: Bool
    /// The tracker's lock band in cents (Settings › Precision), which the lock zone spans.
    let band: Double

    /// Where the note names sit, as a fraction of the dial's radius; the wheel's track runs from 0.8 to 0.955.
    static let wheelRadius: CGFloat = 0.8775

    var body: some View {
        Canvas { context, size in
            let radius = min(size.width, size.height) / 2
            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            drawRings(center: center, radius: radius, in: &context)
            drawScale(center: center, radius: radius, in: &context)
        }
        .accessibilityHidden(true)
    }

    private func circle(_ center: CGPoint, _ r: CGFloat) -> Path {
        Path(ellipseIn: CGRect(x: center.x - r, y: center.y - r, width: r * 2, height: r * 2))
    }

    private func drawRings(center: CGPoint, radius: CGFloat, in context: inout GraphicsContext) {
        // The bezel: brushed metal, lit from above.
        let bezel = Gradient(colors: [.white.opacity(0.16), .white.opacity(0.05), .white.opacity(0.1)])
        context.fill(circle(center, radius * 0.995), with: .linearGradient(bezel, startPoint: CGPoint(x: center.x, y: center.y - radius),
                                                                           endPoint: CGPoint(x: center.x, y: center.y + radius)))
        // The wheel's track, the arc's ring and the disc's well, each a step darker toward the centre.
        context.fill(circle(center, radius * 0.955), with: .color(Palette.stageRaised))
        context.stroke(circle(center, radius * 0.955), with: .color(.black.opacity(0.6)), lineWidth: 1)
        context.fill(circle(center, radius * 0.8), with: .color(Palette.stage))
        context.stroke(circle(center, radius * 0.8), with: .color(.white.opacity(strong ? 0.2 : 0.08)), lineWidth: 1)
        context.fill(circle(center, radius * StrobeDisc.well), with: .color(Palette.stageDeep))
        context.stroke(circle(center, radius * StrobeDisc.well), with: .color(.white.opacity(strong ? 0.2 : 0.09)), lineWidth: 1)
        context.stroke(circle(center, radius * 0.995), with: .color(.white.opacity(strong ? 0.3 : 0.16)), lineWidth: 1)
    }

    private func drawScale(center: CGPoint, radius: CGFloat, in context: inout GraphicsContext) {
        let tick = strong ? Palette.inkSoft : Palette.inkFaint
        // Hairlines grow with the dial (an iPad's is twice a phone's).
        let hair = max(1, radius * 0.007)
        // Round the bottom, where the arc doesn't reach: a fine dotted track.
        for bearing in stride(from: 76.0, through: 284.0, by: 6.0) {
            // Clockwise from the top, as a canvas angle (from three o'clock).
            let a = (bearing - 90) * Double.pi / 180
            let p = StrobeNeedle.point(a, radius * 0.7, from: center)
            let dot = hair * 0.7
            context.fill(Path(ellipseIn: CGRect(x: p.x - dot, y: p.y - dot, width: dot * 2, height: dot * 2)), with: .color(tick.opacity(0.35)))
        }
        // The colour rule along the arc, hard-edged where it changes.
        let near = Palette.nearCents
        let zone = max(band, 1.5)
        let spans: [(from: Double, to: Double, color: Color)] = [
            (-50, -near, Palette.coral.opacity(0.5)), (-near, -zone, Palette.amber.opacity(0.55)),
            (-zone, zone, Palette.mint.opacity(0.9)), (zone, near, Palette.amber.opacity(0.55)), (near, 50, Palette.coral.opacity(0.5))]
        for span in spans where span.to > span.from {
            var arc = Path()
            arc.addArc(center: center, radius: radius * 0.64, startAngle: .radians(StrobeNeedle.angle(cents: span.from)),
                       endAngle: .radians(StrobeNeedle.angle(cents: span.to)), clockwise: false)
            context.stroke(arc, with: .color(span.color), style: StrokeStyle(lineWidth: hair * 2.5, lineCap: .butt))
        }
        // The lock zone: exactly the band the tracker locks in.
        var lock = Path()
        lock.addArc(center: center, radius: radius * 0.7, startAngle: .radians(StrobeNeedle.angle(cents: -zone)),
                    endAngle: .radians(StrobeNeedle.angle(cents: zone)), clockwise: false)
        context.stroke(lock, with: .color(Palette.mint.opacity(0.1)), style: StrokeStyle(lineWidth: radius * 0.11, lineCap: .butt))
        for edge in [-zone, zone] {
            let a = StrobeNeedle.angle(cents: edge)
            var line = Path()
            line.move(to: StrobeNeedle.point(a, radius * 0.645, from: center))
            line.addLine(to: StrobeNeedle.point(a, radius * 0.755, from: center))
            context.stroke(line, with: .color(Palette.mint.opacity(strong ? 0.9 : 0.5)), lineWidth: hair)
        }
        // Ticks every 5 cents, longer every 10, zero in full ink.
        for cents in stride(from: -50, through: 50, by: 5) {
            let a = StrobeNeedle.angle(cents: Double(cents))
            let major = cents % 10 == 0
            var line = Path()
            line.move(to: StrobeNeedle.point(a, radius * (major ? 0.665 : 0.69), from: center))
            line.addLine(to: StrobeNeedle.point(a, radius * 0.745, from: center))
            let ink: Color = cents == 0 ? Palette.ink : tick.opacity(major ? 0.9 : 0.5)
            context.stroke(line, with: .color(ink), lineWidth: cents == 0 ? hair * 2 : hair)
        }
        // Flat and sharp at the arc's ends.
        let glyph = Font.system(size: max(10, radius * 0.085), weight: .semibold)
        let color = strong ? Palette.ink : Palette.inkSoft
        context.draw(Text(verbatim: "♭").font(glyph).foregroundStyle(color),
                     at: StrobeNeedle.point(-Double.pi / 2 - 1.2, radius * 0.7, from: center))
        context.draw(Text(verbatim: "♯").font(glyph).foregroundStyle(color),
                     at: StrobeNeedle.point(-Double.pi / 2 + 1.2, radius * 0.7, from: center))
    }
}

/// Over everything on the dial, drawn once: the reading window over the wheel's top note, the index above it and the
/// glass's highlight across the disc.
struct StrobeDialGlass: View {
    var body: some View {
        Canvas { context, size in
            let radius = min(size.width, size.height) / 2
            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            // The window: a pane of glass over the note under the index.
            let window = CGRect(x: center.x - radius * 0.16, y: center.y - radius * 0.952, width: radius * 0.32, height: radius * 0.148)
            let pane = Path(roundedRect: window, cornerRadius: radius * 0.05, style: .continuous)
            context.fill(pane, with: .linearGradient(Gradient(colors: [.white.opacity(0.1), .white.opacity(0.02)]),
                                                     startPoint: CGPoint(x: window.midX, y: window.minY),
                                                     endPoint: CGPoint(x: window.midX, y: window.maxY)))
            context.stroke(pane, with: .color(.white.opacity(0.2)), lineWidth: 1)
            // The index, cut into the bezel.
            var index = Path()
            index.move(to: CGPoint(x: center.x - radius * 0.04, y: center.y - radius * 0.998))
            index.addLine(to: CGPoint(x: center.x + radius * 0.04, y: center.y - radius * 0.998))
            index.addLine(to: CGPoint(x: center.x, y: center.y - radius * 0.948))
            index.closeSubpath()
            context.fill(index, with: .color(Palette.ink))
            // The glass's highlight, high on the left of the disc.
            let gleam = CGRect(x: center.x - radius * 0.5, y: center.y - radius * 0.56, width: radius * 0.62, height: radius * 0.34)
            context.fill(Path(ellipseIn: gleam), with: .linearGradient(Gradient(colors: [.white.opacity(0.07), .clear]),
                                                                        startPoint: CGPoint(x: gleam.minX, y: gleam.minY),
                                                                        endPoint: CGPoint(x: gleam.midX, y: gleam.maxY)))
        }
        .accessibilityHidden(true)
    }
}
