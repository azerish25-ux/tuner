import QuartzCore
import SwiftUI
import TimbreCore

/// The iPad tuner's second pane: the pitch over the last ten seconds against the lock band, and how each string of
/// this instrument drifts between sessions (Progress' String health, read-only, the string being tuned in mint).
/// In landscape it is a column of its own between the readout and the controls, centred in its height; in portrait
/// the two cards stand side by side under the string rail. A phone never shows it (`TuneArrangement.showsPane`).
struct TuneSidePane: View {
    /// Landscape: the cards stacked in a column. Portrait: side by side, as tall as each other.
    let column: Bool

    var body: some View {
        // One container that changes shape, so the trace keeps its last seconds when the iPad turns.
        let layout = column ? AnyLayout(VStackLayout(spacing: 14)) : AnyLayout(HStackLayout(alignment: .top, spacing: 12))
        layout {
            TunerTraceCard(traceHeight: column ? 150 : 92, fill: !column)
            TuneStringHealthCard(fill: !column)
        }
        .fixedSize(horizontal: false, vertical: !column)
        .frame(maxHeight: column ? CGFloat.infinity : nil)
        .padding(.vertical, column ? 12 : 0)
    }
}

// MARK: - Pitch trace

/// The tuner's pitch over the last ten seconds, newest at the right: the lock band across the middle (lit behind
/// each lock), the line mint inside it, amber close and coral far, as the readout colours its digits.
private struct TunerTraceCard: View {
    let traceHeight: CGFloat
    /// Portrait: the card stretches to the height of the one beside it, the trace taking the extra.
    let fill: Bool
    @EnvironmentObject private var store: AppStore
    @EnvironmentObject private var audio: AudioService
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var recorder = TunerTraceRecorder()
    @State private var visible = true

    var body: some View {
        let listening = audio.running
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Eyebrow("Pitch")
                Spacer(minLength: 8)
                Text("\(Int(TunerTraceArt.window)) s").font(.caption).foregroundStyle(Palette.inkSoft).monospacedDigit()
            }
            trace(listening: listening)
                .frame(minHeight: traceHeight, maxHeight: fill ? CGFloat.infinity : traceHeight)
                .overlay {
                    if !listening { restingHint }
                }
        }
        .frame(maxHeight: fill ? CGFloat.infinity : nil, alignment: .topLeading)
        .stillCard()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("Your pitch relative to the target"))
        .accessibilityValue(listening ? Text("Listening…") : Text("Tap Listen to start"))
    }

    /// Every frame while listening and on screen (15 a second under Reduce Motion, as the drone's trace); still otherwise.
    private func trace(listening: Bool) -> some View {
        let live = listening && visible
        return TimelineView(.animation(minimumInterval: reduceMotion ? 1.0 / 15 : nil, paused: !live)) { _ in
            let now = CACurrentMediaTime()
            let reading = store.live.reading
            let heard = live && !store.live.preserved ? reading.cents : nil
            let _ = recorder.record(heard, key: traceKey, locked: reading.inTune, at: now)
            let samples = recorder.samples
            let band = Palette.tuningBand
            Canvas { context, size in
                TunerTraceArt.draw(&context, size: size, samples: samples, now: now, band: band, listening: listening)
            }
        }
        .liveWhileVisible($visible)
        .accessibilityHidden(true)
    }

    /// The string (or, in Chromatic, the note) being tuned: the line breaks when it changes.
    private var traceKey: Int {
        store.referenceMode ? 1000 + store.activeMidi : store.activeCourse.index
    }

    private var restingHint: some View {
        Text("Tap Listen to start")
            .font(.footnote.weight(.semibold)).foregroundStyle(Palette.inkSoft)
            .lineLimit(2).multilineTextAlignment(.center)
            .padding(.horizontal, 12).padding(.vertical, 6)
            .background(Capsule().fill(Palette.stageRaised.opacity(0.88)))
            .accessibilityHidden(true)
    }
}

/// One point of the trace.
private struct TunerTraceSample {
    let time: TimeInterval
    /// Smoothed cents from the target; nil is a gap (silence).
    let cents: Double?
    /// The string or note being tuned.
    let key: Int
    /// The tracker held the lock here.
    let locked: Bool
}

/// The last ten seconds of the tuner's pitch, smoothed as the readout smooths it. High-rate state in plain
/// properties: the trace reads them each frame, nothing is published.
private final class TunerTraceRecorder {
    private(set) var samples: [TunerTraceSample] = []
    private var filter = ReadoutMotion.makeFilter()
    private var lastKey: Int?
    private var lastTime: TimeInterval = 0

    func record(_ cents: Double?, key: Int, locked: Bool, at now: TimeInterval) {
        // At most one point a frame, however often the view is drawn.
        guard now - lastTime >= 1.0 / 90 || now < lastTime else { return }
        lastTime = now
        trim(now)
        guard let cents, cents.isFinite else {
            filter.reset()
            if let last = samples.last, last.cents != nil {
                samples.append(TunerTraceSample(time: now, cents: nil, key: last.key, locked: false))
            }
            return
        }
        if key != lastKey {
            filter.reset()
            lastKey = key
        }
        let smoothed = filter.filter(max(-60, min(60, cents)), at: now)
        samples.append(TunerTraceSample(time: now, cents: smoothed, key: key, locked: locked))
    }

    private func trim(_ now: TimeInterval) {
        let cutoff = now - TunerTraceArt.window - 0.5
        if let first = samples.firstIndex(where: { $0.time >= cutoff }) {
            if first > 0 { samples.removeFirst(first) }
        } else {
            samples.removeAll()
        }
    }
}

/// Drawn as the drone's sing-along trace (`DroneTraceArt`), on the tuner's own terms: ±50¢ on a scale that opens up
/// near the target (so the band reads at every Precision), the band the tracker locks in (`Palette.tuningBand`)
/// and the tuner's three-colour rule.
private enum TunerTraceArt {
    /// Seconds of trace on screen.
    static let window = 10.0
    static let range = 50.0

    static func draw(_ context: inout GraphicsContext, size: CGSize, samples: [TunerTraceSample], now: TimeInterval,
                     band: Double, listening: Bool) {
        let left: CGFloat = 34
        let head = size.width - 10
        let top: CGFloat = 8
        let bottom = size.height - 8
        let mid = (top + bottom) / 2
        let half = max(1, (bottom - top) / 2)
        let lock = max(0.5, band)
        let near = Palette.nearCents
        func y(_ cents: Double) -> CGFloat {
            let clamped = max(-range, min(range, cents))
            let magnitude = pow(abs(clamped) / range, 0.6)
            return mid - CGFloat(clamped < 0 ? -magnitude : magnitude) * half
        }
        func x(_ time: TimeInterval) -> CGFloat { head - CGFloat((now - time) / window) * (head - left) }

        // Where amber gives way to coral, labelled; sharp is up.
        for cents in [-near, near] {
            var line = Path()
            line.move(to: CGPoint(x: left, y: y(cents)))
            line.addLine(to: CGPoint(x: head, y: y(cents)))
            context.stroke(line, with: .color(.white.opacity(0.06)), lineWidth: 1)
        }
        let scale = Font.system(size: 11, weight: .medium).monospacedDigit()
        let nearLabel = Int(near.rounded())
        context.draw(Text(verbatim: "+\(nearLabel)").font(scale).foregroundStyle(Palette.inkFaint),
                     at: CGPoint(x: left - 6, y: y(near)), anchor: .trailing)
        context.draw(Text(verbatim: "−\(nearLabel)").font(scale).foregroundStyle(Palette.inkFaint),
                     at: CGPoint(x: left - 6, y: y(-near)), anchor: .trailing)
        context.draw(Text(verbatim: "±\(Int(lock.rounded()))¢").font(scale).foregroundStyle(Palette.mint),
                     at: CGPoint(x: left - 6, y: mid), anchor: .trailing)

        // The lock band, lit behind every stretch the tracker held the lock.
        let bandRect = CGRect(x: left, y: y(lock), width: head - left, height: max(2, y(-lock) - y(lock)))
        context.fill(Path(bandRect), with: .color(Palette.mint.opacity(0.08)))
        if listening {
            for run in lockedRuns(samples, from: now - window) {
                let from = x(run.lowerBound), to = x(run.upperBound)
                let lit = CGRect(x: from, y: bandRect.minY, width: max(2, to - from), height: bandRect.height)
                context.fill(Path(lit), with: .color(Palette.mint.opacity(0.24)))
            }
        }
        for edgeY in [bandRect.minY, bandRect.maxY] {
            var edge = Path()
            edge.move(to: CGPoint(x: left, y: edgeY))
            edge.addLine(to: CGPoint(x: head, y: edgeY))
            context.stroke(edge, with: .color(Palette.mint.opacity(0.4)), style: StrokeStyle(lineWidth: 1, dash: [3, 3]))
        }
        var center = Path()
        center.move(to: CGPoint(x: left, y: mid))
        center.addLine(to: CGPoint(x: head, y: mid))
        context.stroke(center, with: .color(Palette.mint.opacity(0.35)), lineWidth: 1)

        guard listening else {
            ghost(&context, left: left, head: head, y: y)
            return
        }

        // The line, coloured by the readout's rule; it breaks at silences and when the string changes.
        var inBand = Path(), close = Path(), far = Path()
        var previous: TunerTraceSample?
        for sample in samples {
            if let earlier = previous, let a = earlier.cents, let b = sample.cents, earlier.key == sample.key,
               sample.time - earlier.time < 0.25, sample.time >= now - window - 0.25 {
                let from = CGPoint(x: x(earlier.time), y: y(a))
                let to = CGPoint(x: x(sample.time), y: y(b))
                let worst = max(abs(a), abs(b)).rounded()
                if worst <= lock {
                    inBand.move(to: from); inBand.addLine(to: to)
                } else if worst <= near {
                    close.move(to: from); close.addLine(to: to)
                } else {
                    far.move(to: from); far.addLine(to: to)
                }
            }
            previous = sample
        }
        var plot = context
        plot.clip(to: Path(CGRect(x: left, y: 0, width: size.width - left, height: size.height)))
        var glow = plot
        glow.addFilter(.blur(radius: 3))
        glow.stroke(inBand, with: .color(Palette.mint.opacity(0.5)), style: StrokeStyle(lineWidth: 6, lineCap: .round))
        let stroke = StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round)
        plot.stroke(far, with: .color(Palette.coral), style: stroke)
        plot.stroke(close, with: .color(Palette.amber), style: stroke)
        plot.stroke(inBand, with: .color(Palette.mint), style: stroke)

        // The head: where the pitch is now.
        if let last = samples.last, let cents = last.cents, now - last.time < 0.3 {
            let p = CGPoint(x: x(last.time), y: y(cents))
            let tint = Palette.pitch(cents, locked: last.locked, band: lock)
            plot.fill(Path(ellipseIn: CGRect(x: p.x - 12, y: p.y - 12, width: 24, height: 24)),
                      with: .radialGradient(Gradient(colors: [tint.opacity(0.45), .clear]), center: p, startRadius: 0, endRadius: 12))
            plot.fill(Path(ellipseIn: CGRect(x: p.x - 4.5, y: p.y - 4.5, width: 9, height: 9)), with: .color(tint))
        }
    }

    /// The stretches (in time, from `start` on) where the tracker held the lock.
    private static func lockedRuns(_ samples: [TunerTraceSample], from start: TimeInterval) -> [ClosedRange<TimeInterval>] {
        var runs: [ClosedRange<TimeInterval>] = []
        var runStart: TimeInterval?
        var runEnd: TimeInterval = 0
        for sample in samples {
            if sample.locked && sample.cents != nil {
                if runStart == nil { runStart = sample.time }
                runEnd = sample.time
            } else if let begun = runStart {
                let lower = max(begun, start)
                runs.append(lower...max(lower, runEnd))
                runStart = nil
            }
        }
        if let begun = runStart {
            let lower = max(begun, start)
            runs.append(lower...max(lower, runEnd))
        }
        return runs
    }

    /// Before listening: a faint sketch of a string coming up from flat and settling in the band.
    private static func ghost(_ context: inout GraphicsContext, left: CGFloat, head: CGFloat, y: (Double) -> CGFloat) {
        var path = Path()
        let steps = 48
        for i in 0...steps {
            let f = Double(i) / Double(steps)
            let settle = exp(-f * 4.5)
            let cents = -30 * settle * cos(f * 9) + 1.2 * sin(f * 31) * (1 - settle)
            let point = CGPoint(x: left + (head - left) * CGFloat(f), y: y(cents))
            if i == 0 { path.move(to: point) } else { path.addLine(to: point) }
        }
        context.stroke(path, with: .color(Palette.inkFaint.opacity(0.35)), style: StrokeStyle(lineWidth: 2, lineCap: .round, dash: [2, 5]))
    }
}

// MARK: - String health

/// Progress' String health, read-only: each string's drift in cents a day against the 4¢ restring line, what it
/// means in a sentence, and when the strings went on. The string being tuned now is named in mint.
private struct TuneStringHealthCard: View {
    /// Portrait: the card stretches to the height of the one beside it.
    let fill: Bool
    @EnvironmentObject private var store: AppStore
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var grown = false

    var body: some View {
        let drift = store.stringDrift
        let restrung = store.progress.restrung[store.instrument.id]
        let advice = StringHealth.needsRestring(drift, restrung: restrung)
        let labels = stringLabels
        let anchors = store.courses.compactMap(\.anchorId).reduce(into: [String]()) { if !$0.contains($1) { $0.append($1) } }
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Eyebrow("String health")
                Spacer(minLength: 8)
                if advice {
                    Text("Restring soon").font(.caption.weight(.semibold)).foregroundStyle(Palette.amber)
                }
            }
            summary(drift, labels: labels)
            if !anchors.isEmpty {
                chart(drift, anchors: anchors, labels: labels)
            }
            if let restrung {
                Text("Restrung \(restrung.formatted(.relative(presentation: .named)))")
                    .font(.caption).foregroundStyle(Palette.inkSoft)
            }
        }
        .frame(maxHeight: fill ? CGFloat.infinity : nil, alignment: .topLeading)
        .stillCard(tint: advice ? Palette.amber : nil)
        .accessibilityElement(children: .combine)
    }

    /// The same sentences as on Progress.
    private func summary(_ drift: [StringDrift], labels: [String: String]) -> some View {
        Group {
            if let worst = drift.first, abs(worst.centsPerDay) >= 1 {
                Text("Your \(labels[worst.anchor] ?? worst.anchor) string drifts \(worst.centsPerDay < 0 ? String(localized: "flat") : String(localized: "sharp")) about \(Int(abs(worst.centsPerDay).rounded()))¢ a day.")
            } else if !drift.isEmpty {
                Text("Your strings are holding their pitch well.")
            } else {
                Text("Tune on a few different days and Timbre learns how each string drifts.")
            }
        }
        .font(.footnote).foregroundStyle(Palette.inkSoft)
        .fixedSize(horizontal: false, vertical: true)
    }

    /// Each string's name as the tuner labels it ("G"), by its anchor id.
    private var stringLabels: [String: String] {
        Dictionary(store.courses.compactMap { c in c.anchorId.map { ($0, NoteReadout.split(TargetLabelFormatter.splitCue(store.courseLabel(c)).main).name) } },
                   uniquingKeysWith: { a, _ in a })
    }

    /// Drift per string as bars on a shared baseline, signed ¢/day above each, the restring line dashed across.
    /// Strings with no drift yet stand as empty slots, so the card always names every string.
    private func chart(_ drift: [StringDrift], anchors: [String], labels: [String: String]) -> some View {
        let peak = max(6, drift.map { abs($0.centsPerDay) }.max() ?? 6)
        let height: CGFloat = 44
        let threshold = height * CGFloat(StringHealth.restringCentsPerDay / peak)
        let active = store.referenceMode ? nil : store.activeCourse.anchorId
        return VStack(spacing: 5) {
            HStack(alignment: .bottom, spacing: 0) {
                ForEach(anchors, id: \.self) { anchor in
                    bar(drift.first { $0.anchor == anchor }?.centsPerDay, peak: peak, height: height)
                        .frame(maxWidth: .infinity)
                }
            }
            .overlay(alignment: .bottom) {
                RestringRule().stroke(Palette.amber.opacity(0.4), style: StrokeStyle(lineWidth: 1, dash: [3, 4]))
                    .frame(height: 1).offset(y: -threshold)
            }
            .overlay(alignment: .bottom) { Hairline() }
            HStack(spacing: 0) {
                ForEach(anchors, id: \.self) { anchor in
                    let bad = abs(drift.first { $0.anchor == anchor }?.centsPerDay ?? 0) >= StringHealth.restringCentsPerDay
                    let current = anchor == active
                    NoteGlyphs.text(labels[anchor] ?? anchor, size: 11)
                        .font(.caption2.weight(bad || current ? .bold : .medium))
                        .foregroundStyle(bad ? Palette.amber : (current ? Palette.mint : Palette.inkSoft))
                        .lineLimit(1).minimumScaleFactor(0.7)
                        .frame(maxWidth: .infinity)
                }
            }
        }
        .padding(.top, 2)
        .accessibilityHidden(true)
        .onAppear { withAnimation(reduceMotion ? nil : Motion.settle.delay(0.15)) { grown = true } }
    }

    private func bar(_ rate: Double?, peak: Double, height: CGFloat) -> some View {
        let magnitude = abs(rate ?? 0)
        let bad = magnitude >= StringHealth.restringCentsPerDay
        let tint = bad ? Palette.amber : Palette.mint
        let length = rate == nil ? 0 : max(4, height * CGFloat(min(1, magnitude / peak)))
        let top = UnevenRoundedRectangle(topLeadingRadius: 4, topTrailingRadius: 4, style: .continuous)
        return VStack(spacing: 4) {
            Text(verbatim: rate.map(Self.signed) ?? "–").font(Typeface.number(.caption))
                .foregroundStyle(bad ? Palette.amber : Palette.inkFaint)
                .lineLimit(1).minimumScaleFactor(0.7)
            ZStack(alignment: .bottom) {
                top.fill(.white.opacity(0.05)).frame(height: height)
                top.fill(LinearGradient(colors: [tint, tint.opacity(bad ? 0.7 : 0.45)], startPoint: .top, endPoint: .bottom))
                    .frame(height: grown ? length : 0)
            }
            .frame(width: 14)
        }
    }

    /// Whole cents a day with a sign: "−7" goes flat, "+2" goes sharp.
    private static func signed(_ rate: Double) -> String {
        let n = Int(rate.rounded())
        if n == 0 { return 0.formatted() }
        return (n > 0 ? "+" : "−") + abs(n).formatted()
    }
}

/// A horizontal line through the middle of its frame (the dashed restring line).
private struct RestringRule: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.midY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
        return path
    }
}
