import SwiftUI
import TimbreCore

/// The last string, zoomed in. Once a strum reads every other string in tune (5 of 6 on a guitar), that string's
/// lane grows into a single-string fine-tune on the strum screen itself (`StrumTuneView` shares the lane's
/// geometry with this one): the polyphonic reading stands aside and the tuner follows this string alone, smoothed
/// as the main readout is. The bead rides a larger ±50¢ scale with its cents beside it and the turn it needs
/// above, the steel string rings with the sound, and when the tuner locks the string (`onLock`) the lane blooms
/// mint and hands over to the whole-instrument celebration. One element for VoiceOver.
struct StrumFinaleLane: View {
    let meter: StrumBoard.Meter
    let band: Double
    /// Every string of the lane has locked since it zoomed in: the bead rests on the line, mint.
    let done: Bool
    /// The tuner just locked the string being tuned (its course index).
    let onLock: (Int) -> Void
    @EnvironmentObject private var store: AppStore
    @EnvironmentObject private var audio: AudioService
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorSchemeContrast) private var contrast
    /// The tuner's own smoothing, so these cents move as the main readout's do.
    @State private var motion = ReadoutMotion()

    private var strong: Bool { contrast == .increased }

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 60, paused: done)) { timeline in
            let reading = store.live.reading
            let heard = audio.running && !store.live.preserved && reading.cents != nil
            let _ = motion.step(heard ? reading.cents : nil, locked: reading.inTune, now: timeline.date.timeIntervalSinceReferenceDate)
            let locked = done || (heard && reading.inTune)
            let shown: Int? = heard && !done ? motion.shown : nil
            let bead: Double? = done ? 0 : (heard ? motion.cents : nil)
            lane(shown: shown, bead: bead, locked: locked, swing: swing(heard: heard))
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(StrumWords.name(meter))
                .accessibilityValue(Text(verbatim: StrumWords.live(shown, locked: locked, band: band)))
                .accessibilityAddTraits(.updatesFrequently)
        }
        .onChange(of: store.live.reading.inTune) { was, now in
            // The tuner's lock is the rising edge of its in-tune reading (`AppStore.accept`).
            if now && !was && !done { onLock(store.selectedCourse) }
        }
    }

    /// The string rings with the sound while it is heard: wider the louder it is. Still once locked.
    private func swing(heard: Bool) -> Double {
        guard heard, !done, !reduceMotion else { return 0 }
        let level = max(0, min(1, (store.live.level + 60) / 45))
        return 1.5 + 4.5 * level
    }

    private func lane(shown: Int?, bead: Double?, locked: Bool, swing: Double) -> some View {
        let tone = StrumTone.status(shown, band: band, locked: locked)
        let quiet = shown == nil && !locked
        let shape = RoundedRectangle(cornerRadius: Metrics.cornerHero, style: .continuous)
        return VStack(spacing: 12) {
            StrumTurnBadge(shown: shown, band: band, pulse: 0, size: 30, locked: locked)
            scale(shown: shown, bead: bead, locked: locked, swing: swing, tone: tone)
            StrumLaneChip(meter: meter, tone: quiet ? nil : tone, focus: !locked && !quiet, size: 24)
            Text(verbatim: StrumWords.live(shown, locked: locked, band: band))
                .font(.headline)
                .foregroundStyle(quiet ? (strong ? Palette.ink : Palette.inkSoft) : tone)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .padding(.vertical, 18)
        .padding(.horizontal, 14)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background {
            shape.fill(Palette.stageRaised.opacity(0.7))
                .overlay(shape.fill(LinearGradient(colors: [tone.opacity(locked ? 0.18 : 0.07), .clear],
                                                   startPoint: .top, endPoint: .center)))
        }
        .overlay(shape.strokeBorder(quiet ? Color.white.opacity(strong ? 0.3 : 0.08) : tone.opacity(locked || strong ? 0.75 : 0.35),
                                    lineWidth: locked ? 1.5 : 1))
        .shadow(color: Palette.mint.opacity(locked ? 0.28 : 0), radius: 24)
        .animation(Motion.adaptive(Motion.pluck, reduceMotion: reduceMotion), value: locked)
    }

    private func scale(shown: Int?, bead: Double?, locked: Bool, swing: Double, tone: Color) -> some View {
        GeometryReader { proxy in
            let size = proxy.size
            let mid = size.width / 2, centre = size.height / 2
            let y = locked ? centre : StrumScale.y(bead, height: size.height)
            let out = shown.map { Double(abs($0)) > band } ?? false
            ZStack {
                StrumStringTrack(gauge: meter.gauge, lit: true, inTune: locked, band: band, ring: .still,
                                 position: 0, count: 1, strong: strong, steady: swing, magnify: 2.2)
                pull(from: centre, to: y)
                    .position(x: mid, y: (centre + y) / 2)
                    .opacity(out && !locked ? 1 : 0)
                if !reduceMotion { bloom.position(x: mid, y: centre) }
                beadView(tone: tone, shown: shown, locked: locked)
                    .position(x: mid, y: y)
                    .opacity(bead == nil && !locked ? 0 : 1)
                    .animation(Motion.quick, value: bead == nil)
            }
        }
        .frame(minHeight: 180)
    }

    /// The pull from the bead to the target line, in amber, while the string is out.
    private func pull(from centre: CGFloat, to y: CGFloat) -> some View {
        Capsule()
            .fill(LinearGradient(colors: [Palette.amber.opacity(0.05), Palette.amber.opacity(0.55)],
                                 startPoint: y > centre ? .top : .bottom, endPoint: y > centre ? .bottom : .top))
            .frame(width: 6, height: max(0, abs(y - centre)))
            .allowsHitTesting(false)
    }

    /// The bead, with its cents tagged beside it (after it in reading order) until the string locks.
    private func beadView(tone: Color, shown: Int?, locked: Bool) -> some View {
        Circle().fill(tone)
            .overlay(Circle().fill(LinearGradient(colors: [.white.opacity(0.5), .clear], startPoint: .top, endPoint: .center)))
            .overlay(Circle().strokeBorder(Palette.mint, lineWidth: 2.5).padding(-6).opacity(locked ? 1 : 0))
            .frame(width: 30, height: 30)
            .shadow(color: tone.opacity(0.7), radius: locked ? 18 : 10)
            .scaleEffect(locked && !reduceMotion ? 1.12 : 1)
            .overlay(alignment: .trailing) {
                Text(verbatim: NoteReadout.signed(shown))
                    .font(Typeface.number(.title3))
                    .foregroundStyle(tone)
                    .fixedSize()
                    .alignmentGuide(.trailing) { d in d[.leading] - 16 }
                    .opacity(shown == nil || locked ? 0 : 1)
            }
    }

    /// A ring that leaves the target line once as the string locks.
    private var bloom: some View {
        Circle()
            .strokeBorder(Palette.mint, lineWidth: 2)
            .frame(width: 34, height: 34)
            .keyframeAnimator(initialValue: StrumBloom(), trigger: done) { content, value in
                content
                    .scaleEffect(value.scale)
                    .opacity(value.opacity)
            } keyframes: { _ in
                KeyframeTrack(\.scale) {
                    CubicKeyframe(3.4, duration: 0.8)
                }
                KeyframeTrack(\.opacity) {
                    LinearKeyframe(0.9, duration: 0.06)
                    CubicKeyframe(0, duration: 0.74)
                }
            }
            .allowsHitTesting(false)
    }
}

/// The lock bloom's ring: still and invisible until it plays.
private struct StrumBloom {
    var scale = 1.0
    var opacity = 0.0
}

/// A string the strum read in tune, waiting above the zoomed lane: its ✓ over its chip, both in mint. Each shares
/// its lane's geometry, so the lanes shrink into this row as the last one zooms.
struct StrumTunedChip: View {
    let meter: StrumBoard.Meter
    var compact = false

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: "checkmark")
                .font(.system(size: 9, weight: .heavy))
                .foregroundStyle(Palette.onAccent)
                .frame(width: 18, height: 18)
                .background(Circle().fill(Palette.mint))
                .shadow(color: Palette.mint.opacity(0.45), radius: 5)
            StrumLaneChip(meter: meter, tone: Palette.mint, compact: compact, size: 14)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(StrumWords.name(meter))
        .accessibilityValue(Text("In tune"))
    }
}
