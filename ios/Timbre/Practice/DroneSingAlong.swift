import QuartzCore
import SwiftUI
import TimbreCore

/// The twelve swaras as just intervals above Sa: the ratios a drone's own overtones ring true with (Pa a pure 3:2,
/// Ga a pure 5:4), in cents, with their names (komal ♭, tivra ♯).
enum Swara {
    static let cents: [Double] = [0, 111.73, 203.91, 315.64, 386.31, 498.04, 590.22, 701.96, 813.69, 884.36, 1017.6, 1088.27]
    static let names = ["Sa", "Re♭", "Re", "Ga♭", "Ga", "Ma", "Ma♯", "Pa", "Dha♭", "Dha", "Ni♭", "Ni"]
    static let ratios = ["1:1", "16:15", "9:8", "6:5", "5:4", "4:3", "45:32", "3:2", "8:5", "5:3", "9:5", "15:8"]

    /// The swara nearest `hz` in any octave of Sa, and how far from it in cents (negative: flat).
    static func nearest(_ hz: Double, sa: Double) -> (degree: Int, cents: Double) {
        let fromSa = 1200 * log2(hz / sa)
        let folded = fromSa - 1200 * floor(fromSa / 1200)
        var degree = 0
        var error = folded
        for (index, target) in cents.enumerated() where abs(folded - target) < abs(error) {
            degree = index
            error = folded - target
        }
        // Just under the next Sa.
        if abs(folded - 1200) < abs(error) { degree = 0; error = folded - 1200 }
        return (degree, error)
    }
}

/// The player's pitch against the drone, read through the tuner's own pitch pipeline (the store's lesson
/// microphone): each reading is placed against the nearest swara, kept for the trace, and timed while it stays
/// inside ±5¢ of it. High-rate state lives in plain properties the trace reads each frame; only what the words
/// show (the swara, whole cents, whole seconds held) is published.
@MainActor
final class DroneSingAlong: ObservableObject {
    struct Sample {
        let time: TimeInterval
        /// Cents from the swara (smoothed); nil is a gap (silence).
        let cents: Double?
        let degree: Int
    }

    static let band = 5.0
    /// Seconds of trace on screen; holding inside the band end to end is the goal.
    static let window = 8.0
    static let goal = 8

    @Published private(set) var degree: Int?
    @Published private(set) var shownCents: Int?
    @Published private(set) var held = 0
    @Published private(set) var best = 0
    /// Ticks each time a hold reaches the goal.
    @Published private(set) var reached = 0

    private(set) var samples: [Sample] = []
    /// When the current hold inside the band began.
    private(set) var holdStart: TimeInterval?
    private var holdDegree: Int?
    private var lastInBand: TimeInterval = 0
    private var lastHeard: TimeInterval = 0
    private var smoothed: Double?
    private var paid = false

    /// One reading (Hz when the detector is confident, else nil) against Sa.
    func accept(_ hz: Double?, sa: Double, at now: TimeInterval = CACurrentMediaTime()) {
        trim(now)
        guard let hz, hz.isFinite, hz > 0, sa.isFinite, sa > 0 else { silence(now); return }
        let reading = Swara.nearest(hz, sa: sa)
        if reading.degree == degree, let previous = smoothed, now - lastHeard < 0.25 {
            smoothed = previous + 0.35 * (reading.cents - previous)
        } else {
            smoothed = reading.cents
        }
        let cents = smoothed ?? reading.cents
        lastHeard = now
        samples.append(Sample(time: now, cents: cents, degree: reading.degree))
        if degree != reading.degree { degree = reading.degree }
        let whole = Int(cents.rounded())
        if shownCents != whole { shownCents = whole }
        if abs(cents) <= Self.band {
            if holdStart == nil || holdDegree != reading.degree { holdStart = now; holdDegree = reading.degree; paid = false }
            lastInBand = now
        } else if now - lastInBand > 0.3 {
            holdStart = nil
        }
        updateHeld(now)
    }

    /// Clears the trace and the hold (a new tonic, the microphone off); the best hold stays for the visit.
    func reset() {
        samples = []
        holdStart = nil; holdDegree = nil; smoothed = nil; paid = false
        if degree != nil { degree = nil }
        if shownCents != nil { shownCents = nil }
        if held != 0 { held = 0 }
    }

    private func silence(_ now: TimeInterval) {
        if let last = samples.last, last.cents != nil { samples.append(Sample(time: now, cents: nil, degree: last.degree)) }
        if now - lastInBand > 0.3 { holdStart = nil }
        if now - lastHeard > 0.4 {
            smoothed = nil
            if degree != nil { degree = nil }
            if shownCents != nil { shownCents = nil }
        }
        updateHeld(now)
    }

    private func updateHeld(_ now: TimeInterval) {
        let seconds = holdStart.map { Int(now - $0) } ?? 0
        if seconds != held { held = seconds }
        if seconds > best { best = seconds }
        if seconds >= Self.goal && !paid {
            paid = true
            reached += 1
            Haptics.shared.done()
        }
    }

    private func trim(_ now: TimeInterval) {
        let cutoff = now - Self.window - 0.5
        if let first = samples.firstIndex(where: { $0.time >= cutoff }), first > 0 {
            samples.removeFirst(first)
        } else if let last = samples.last, last.time < cutoff {
            samples.removeAll()
        }
    }
}

// MARK: - Card

/// Sing or play against the drone: the swara you are on and how far from it, your pitch drawn over the last
/// eight seconds against a ±5¢ band, and how long you have held inside it.
struct DroneSingAlongCard: View {
    @ObservedObject var model: DroneSingAlong
    /// The microphone is on for this screen.
    let listening: Bool
    let tonicPc: Int
    let notation: String
    let headphones: Bool
    let permissionDenied: Bool
    /// The drone is playing but the microphone is off (it starts with the drone only when already allowed): the
    /// Listen pill's microphone pulses to say singing along is one tap away.
    var invite = false
    let toggle: () -> Void
    @State private var visible = true
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header
            readout
            trace
            holdRow
        }
        .stillCard(tint: model.held >= DroneSingAlong.goal ? Palette.amber : nil)
        .animation(Motion.settle, value: model.held >= DroneSingAlong.goal)
    }

    private var header: some View {
        HStack(spacing: 8) {
            Eyebrow("Pitch")
            if listening && !headphones {
                // On the speaker the microphone hears the drone too (the footnote below says so).
                Image(systemName: "headphones").font(.caption.weight(.bold)).foregroundStyle(Palette.amber)
                    .symbolEffect(.pulse, options: .repeating, isActive: !reduceMotion)
                    .accessibilityLabel(Text("Sing or play long notes against the drone. Headphones keep it out of the microphone."))
            }
            Spacer()
            Button(action: toggle) {
                // A 36 pt pill in a 44 pt target.
                Label(listening ? "Pause" : "Listen", systemImage: listening ? "pause.fill" : "mic.fill")
                    .symbolEffect(.pulse, options: .repeating, isActive: invite && !listening && !reduceMotion)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(listening ? Palette.ink : Palette.onAccent)
                    .padding(.horizontal, 14).frame(minHeight: 36)
                    .background(Capsule().fill(listening ? AnyShapeStyle(Palette.surface) : AnyShapeStyle(Palette.mint)))
                    .overlay(Capsule().strokeBorder(listening ? Palette.controlLine : .clear, lineWidth: 1))
                    .tapTarget()
            }
            .buttonStyle(PressScaleStyle())
            .accessibilityIdentifier("drone.listen")
        }
    }

    @ViewBuilder private var readout: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            if listening, let degree = model.degree, let cents = model.shownCents {
                NoteGlyphs.text(Swara.names[degree], size: 30).font(Typeface.display(30)).foregroundStyle(Palette.ink)
                NoteGlyphs.text(noteName(degree) + " · " + Swara.ratios[degree], size: 12, weight: .medium).font(Typeface.number(12)).foregroundStyle(Palette.inkSoft)
                    .lineLimit(1)
                Spacer(minLength: 8)
                Text(verbatim: centsText(cents)).font(Typeface.number(24)).foregroundStyle(Palette.pitch(Double(cents), locked: false, band: DroneSingAlong.band))
                    .contentTransition(.numericText())
            } else if permissionDenied {
                Text("Microphone access is off. Turn it on in Settings to tune.").font(.footnote).foregroundStyle(Palette.amber)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
            } else {
                // The microphone's status, set as every practice tool sets it.
                Text(listening ? "Listening…" : "Tap Listen to start").font(.subheadline.weight(.semibold)).foregroundStyle(Palette.inkSoft)
                Spacer(minLength: 0)
            }
        }
        .frame(minHeight: 38)
        .accessibilityElement(children: .combine)
        .accessibilityValue(Text(verbatim: NoteReadout.spoken(listening ? model.shownCents : nil, locked: false)))
    }

    private var trace: some View {
        let live = listening && visible
        return TimelineView(.animation(minimumInterval: reduceMotion ? 1.0 / 15 : nil, paused: !live)) { _ in
            let now = CACurrentMediaTime()
            let samples = model.samples
            let holdStart = model.holdStart
            Canvas { context, size in
                DroneTraceArt.draw(&context, size: size, samples: samples, now: now, holdStart: holdStart, listening: listening)
            }
        }
        .frame(height: 128)
        .liveWhileVisible($visible)
        .accessibilityHidden(true)
    }

    private var holdRow: some View {
        let reached = model.held >= DroneSingAlong.goal
        let progress = Double(min(model.held, DroneSingAlong.goal)) / Double(DroneSingAlong.goal)
        return HStack(spacing: 10) {
            ZStack {
                Circle().stroke(.white.opacity(0.1), lineWidth: 3)
                Circle().trim(from: 0, to: max(0.001, progress))
                    .stroke(reached ? Palette.amber : Palette.mint, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .opacity(progress > 0 ? 1 : 0)
                if reached {
                    Image(systemName: "checkmark").font(.system(size: 10, weight: .heavy)).foregroundStyle(Palette.amber)
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .frame(width: 26, height: 26)
            .animation(Motion.fade, value: model.held)
            .symbolEffect(.bounce, value: model.reached)
            Text("Held \(model.held) s").font(Typeface.label(14)).foregroundStyle(reached ? Palette.amber : (model.held > 0 ? Palette.mint : Palette.inkSoft))
                .contentTransition(.numericText())
            Spacer(minLength: 8)
            if model.best > 0 {
                Text("Best \(model.best) s").font(.caption).foregroundStyle(Palette.inkSoft)
                    .contentTransition(.numericText())
            }
        }
        .accessibilityElement(children: .combine)
    }

    private func noteName(_ degree: Int) -> String {
        VoiceNoteName.pitchClass(tonicPc + degree, notation: notation)
    }

    private func centsText(_ cents: Int) -> String {
        cents > 0 ? "+\(cents)¢" : cents < 0 ? "−\(abs(cents))¢" : "0¢"
    }
}

// MARK: - Trace

/// The last eight seconds of pitch, newest at the right: ±25¢ around the nearest swara, the ±5¢ band across the
/// middle, mint inside it and amber outside, and the band lit behind the current hold (gold once it fills).
enum DroneTraceArt {
    static let range = 25.0

    static func draw(_ context: inout GraphicsContext, size: CGSize, samples: [DroneSingAlong.Sample], now: TimeInterval,
                     holdStart: TimeInterval?, listening: Bool) {
        let left: CGFloat = 34
        let head = size.width - 12
        let top: CGFloat = 8, bottom = size.height - 8
        let mid = (top + bottom) / 2
        let half = (bottom - top) / 2
        let window = DroneSingAlong.window
        func y(_ cents: Double) -> CGFloat { mid - CGFloat(max(-range * 1.1, min(range * 1.1, cents)) / range) * half }
        func x(_ time: TimeInterval) -> CGFloat { head - CGFloat((now - time) / window) * (head - left) }

        // Grid and scale.
        for cents in [-20.0, -10.0, 10.0, 20.0] {
            var line = Path()
            line.move(to: CGPoint(x: left, y: y(cents)))
            line.addLine(to: CGPoint(x: head, y: y(cents)))
            context.stroke(line, with: .color(.white.opacity(0.05)), lineWidth: 1)
        }
        let scale = Font.system(size: 11, weight: .medium).monospacedDigit()
        context.draw(Text(verbatim: "+20").font(scale).foregroundStyle(Palette.inkFaint), at: CGPoint(x: left - 6, y: y(20)), anchor: .trailing)
        context.draw(Text(verbatim: "−20").font(scale).foregroundStyle(Palette.inkFaint), at: CGPoint(x: left - 6, y: y(-20)), anchor: .trailing)
        context.draw(Text(verbatim: "±5¢").font(scale).foregroundStyle(Palette.mint), at: CGPoint(x: left - 6, y: mid), anchor: .trailing)

        // The band, and the stretch of it held so far (from the hold's start, or eight seconds back).
        let bandRect = CGRect(x: left, y: y(DroneSingAlong.band), width: head - left, height: y(-DroneSingAlong.band) - y(DroneSingAlong.band))
        context.fill(Path(bandRect), with: .color(Palette.mint.opacity(0.08)))
        var held = 0.0
        if let holdStart, listening {
            held = now - holdStart
            let from = x(max(holdStart, now - window))
            let heldRect = CGRect(x: from, y: bandRect.minY, width: max(0, head - from), height: bandRect.height)
            let tint = held >= Double(DroneSingAlong.goal) ? Palette.amber : Palette.mint
            context.fill(Path(heldRect), with: .linearGradient(Gradient(colors: [tint.opacity(0.06), tint.opacity(0.26)]),
                                                               startPoint: CGPoint(x: heldRect.minX, y: 0), endPoint: CGPoint(x: heldRect.maxX, y: 0)))
        }
        let edgeTint = held >= Double(DroneSingAlong.goal) ? Palette.amber : Palette.mint
        for edgeY in [bandRect.minY, bandRect.maxY] {
            var edge = Path()
            edge.move(to: CGPoint(x: left, y: edgeY))
            edge.addLine(to: CGPoint(x: head, y: edgeY))
            context.stroke(edge, with: .color(edgeTint.opacity(0.4)), style: StrokeStyle(lineWidth: 1, dash: [3, 3]))
        }
        var center = Path()
        center.move(to: CGPoint(x: left, y: mid))
        center.addLine(to: CGPoint(x: head, y: mid))
        context.stroke(center, with: .color(Palette.mint.opacity(0.35)), lineWidth: 1)

        guard listening else {
            ghost(&context, left: left, head: head, y: y)
            return
        }

        // The trace: mint inside the band, amber outside; it breaks at silences and when the swara changes.
        var inside = Path(), outside = Path()
        var previous: DroneSingAlong.Sample?
        for sample in samples {
            if let earlier = previous, let a = earlier.cents, let b = sample.cents, earlier.degree == sample.degree,
               sample.time - earlier.time < 0.2, sample.time >= now - window - 0.2 {
                let from = CGPoint(x: x(earlier.time), y: y(a)), to = CGPoint(x: x(sample.time), y: y(b))
                if abs(a) <= DroneSingAlong.band && abs(b) <= DroneSingAlong.band {
                    inside.move(to: from); inside.addLine(to: to)
                } else {
                    outside.move(to: from); outside.addLine(to: to)
                }
            }
            previous = sample
        }
        var plot = context
        plot.clip(to: Path(CGRect(x: left, y: 0, width: size.width - left, height: size.height)))
        var glow = plot
        glow.addFilter(.blur(radius: 3))
        glow.stroke(inside, with: .color(Palette.mint.opacity(0.5)), style: StrokeStyle(lineWidth: 6, lineCap: .round))
        plot.stroke(outside, with: .color(Palette.amber), style: StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))
        plot.stroke(inside, with: .color(Palette.mint), style: StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))

        // The head: where the pitch is now.
        if let last = samples.last, let cents = last.cents, now - last.time < 0.3 {
            let p = CGPoint(x: x(last.time), y: y(cents))
            let tint = abs(cents) <= DroneSingAlong.band ? Palette.mint : Palette.amber
            plot.fill(Path(ellipseIn: CGRect(x: p.x - 12, y: p.y - 12, width: 24, height: 24)),
                      with: .radialGradient(Gradient(colors: [tint.opacity(0.45), .clear]), center: p, startRadius: 0, endRadius: 12))
            plot.fill(Path(ellipseIn: CGRect(x: p.x - 4.5, y: p.y - 4.5, width: 9, height: 9)), with: .color(tint))
        }
    }

    /// Before listening: a faint sketch of a note wandering in and settling inside the band.
    private static func ghost(_ context: inout GraphicsContext, left: CGFloat, head: CGFloat, y: (Double) -> CGFloat) {
        var path = Path()
        let steps = 48
        for i in 0...steps {
            let f = Double(i) / Double(steps)
            let settle = exp(-f * 4.5)
            let cents = 18 * settle * cos(f * 13) + 1.2 * sin(f * 31) * (1 - settle)
            let point = CGPoint(x: left + (head - left) * CGFloat(f), y: y(cents))
            if i == 0 { path.move(to: point) } else { path.addLine(to: point) }
        }
        context.stroke(path, with: .color(Palette.inkFaint.opacity(0.35)), style: StrokeStyle(lineWidth: 2, lineCap: .round, dash: [2, 5]))
    }
}
