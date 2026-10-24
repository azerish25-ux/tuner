import QuartzCore
import SwiftUI
import TimbreCore
import UIKit

/// Ten seconds of tapping along with a click measure how late this route's sound reaches the ears
/// (Bluetooth can add a quarter of a second). The result is saved per kind of route (speaker, wired,
/// Bluetooth), and play-alongs and strum steps time their notes from the moment the click is heard.
/// Nothing on screen marks the beat: the taps have to follow the sound, not the picture.
struct LatencyCalibrationSheet: View {
    let accent: Color
    @EnvironmentObject private var store: AppStore
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var phase = Phase.ready
    @State private var taps: [Double] = []
    @State private var startedAt: CFTimeInterval = 0
    @State private var route = AudioService.currentRoute()
    @State private var result: Double?
    @State private var pulse = 0
    @State private var run: Task<Void, Never>?

    enum Phase { case ready, running, done, failed }
    /// Slow enough that a quarter-second Bluetooth lag still pairs each tap with its own click.
    static let bpm = 80
    static let seconds = 10.0

    var body: some View {
        VStack(spacing: 18) {
            header
            routeChip
            Spacer(minLength: 8)
            pad
            Spacer(minLength: 8)
            message
                .frame(minHeight: 64)
            controls
        }
        .padding(.top, 18)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Palette.stage.ignoresSafeArea())
        .presentationDragIndicator(.visible)
        .preferredColorScheme(.dark)
        .onAppear { store.audio.refreshRoute(); route = store.audio.route }
        .onDisappear { stop() }
    }

    // MARK: Pieces

    private var header: some View {
        HStack {
            Text("Calibrate timing").font(Typeface.display(24)).foregroundStyle(Palette.ink).accessibilityAddTraits(.isHeader)
            Spacer()
            Button { dismiss() } label: {
                Image(systemName: "xmark").font(.system(size: 15, weight: .bold)).foregroundStyle(Palette.inkSoft)
                    .frame(width: 44, height: 44).contentShape(Rectangle())
            }
            .accessibilityLabel(Text("Close"))
            .accessibilityIdentifier("calibrate.close")
        }
        .padding(.horizontal, 22)
    }

    /// Which route this measures, and what it holds now.
    private var routeChip: some View {
        HStack(spacing: 8) {
            Image(systemName: routeSymbol)
            Text(routeName)
            if let saved = AudioService.calibratedLatency(for: route) {
                Text(verbatim: "·").foregroundStyle(Palette.inkFaint)
                Text(milliseconds(saved), format: .measurement(width: .abbreviated, usage: .asProvided)).monospacedDigit()
            }
        }
        .font(Typeface.label(14))
        .foregroundStyle(Palette.inkSoft)
        .padding(.horizontal, 14).padding(.vertical, 8)
        .background(Capsule().fill(Palette.stageRaised))
        .overlay(Capsule().strokeBorder(Palette.line, lineWidth: 1))
        .accessibilityElement(children: .combine)
    }

    private var routeSymbol: String {
        switch route {
        case .speaker: return "speaker.wave.2.fill"
        case .wired: return "headphones"
        case .bluetooth: return "dot.radiowaves.left.and.right"
        }
    }

    private var routeName: LocalizedStringKey {
        switch route {
        case .speaker: return "Speaker"
        case .wired: return "Wired headphones"
        case .bluetooth: return "Bluetooth"
        }
    }

    /// The pad: a ring fills over the ten seconds; each tap squeezes it a little.
    private var pad: some View {
        ZStack {
            Circle().stroke(.white.opacity(0.08), lineWidth: 6)
            TimelineView(.animation(paused: phase != .running)) { _ in
                Circle().trim(from: 0, to: progress)
                    .stroke(accent, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .shadow(color: accent.opacity(0.5), radius: 10)
            }
            Circle().fill(accent.opacity(phase == .running ? 0.16 : 0.10))
                .overlay(Circle().strokeBorder(accent.opacity(0.6), lineWidth: 2))
                .padding(18)
                .scaleEffect(reduceMotion || pulse % 2 == 0 ? 1 : 0.95)
                .animation(.spring(response: 0.18, dampingFraction: 0.5), value: pulse)
            Image(systemName: "hand.tap.fill").font(.system(size: 46, weight: .semibold)).foregroundStyle(accent)
                .accessibilityHidden(true)
            TimedTapPad { time in tapped(at: time) }
                .disabled(phase != .running)
        }
        .frame(width: 240, height: 240)
        .accessibilityIdentifier("calibrate.pad")
    }

    private var progress: CGFloat {
        switch phase {
        case .ready: return 0
        case .running: return CGFloat(min(1, max(0, (CACurrentMediaTime() - startedAt) / Self.seconds)))
        case .done, .failed: return 1
        }
    }

    @ViewBuilder private var message: some View {
        switch phase {
        case .ready, .running:
            Text("Tap the pad with every click, for 10 seconds.")
                .font(.body).foregroundStyle(Palette.inkSoft).multilineTextAlignment(.center)
                .padding(.horizontal, 30)
        case .done:
            if let result {
                Text(milliseconds(result), format: .measurement(width: .abbreviated, usage: .asProvided))
                    .font(Typeface.note(44)).foregroundStyle(accent).monospacedDigit()
                    .transition(.scale(scale: 0.8).combined(with: .opacity))
            }
        case .failed:
            Text("Those taps were too uneven. Try again.")
                .font(.body.weight(.semibold)).foregroundStyle(Palette.amber).multilineTextAlignment(.center)
                .padding(.horizontal, 30)
        }
    }

    @ViewBuilder private var controls: some View {
        switch phase {
        case .ready:
            StepButton(title: "Start", accent: accent) { start() }
        case .running:
            // The pad is the button now; the row keeps its place.
            StepButton(title: "Start", accent: accent, enabled: false) {}.opacity(0).accessibilityHidden(true)
        case .done:
            HStack(spacing: 10) {
                Button("Try again") { start() }.font(Typeface.label(16)).foregroundStyle(Palette.ink)
                    .frame(maxWidth: .infinity, minHeight: 56)
                    .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Palette.stageRaised))
                StepButton(title: "Done", accent: accent) { dismiss() }
                    .padding(.horizontal, -20).frame(maxWidth: .infinity)
            }
            .padding(.horizontal, 20)
        case .failed:
            StepButton(title: "Try again", accent: accent) { start() }
        }
    }

    private func milliseconds(_ seconds: Double) -> Measurement<UnitDuration> {
        Measurement(value: (seconds * 1000).rounded(), unit: .milliseconds)
    }

    // MARK: Flow

    private func start() {
        run?.cancel()
        taps = []; result = nil
        store.audio.refreshRoute()
        route = store.audio.route
        store.audio.setMetronome(bpm: Self.bpm, beats: 4, subdivision: 1, accents: true)
        startedAt = CACurrentMediaTime()
        withAnimation(Motion.quick) { phase = .running }
        run = Task { @MainActor in
            try? await Task.sleep(for: .seconds(Self.seconds))
            guard !Task.isCancelled else { return }
            finish()
        }
    }

    private func tapped(at time: TimeInterval) {
        guard phase == .running else { return }
        taps.append(time)
        pulse += 1
        Haptics.shared.selection()
    }

    private func finish() {
        // Read before stopping: the click's clock goes with the metronome.
        let origin = store.audio.metronomeRenderOrigin()
        store.audio.stopMetronome()
        let sameRoute = AudioService.currentRoute() == route
        guard sameRoute, let origin,
              let delay = LatencyCalibration.estimate(taps: taps, firstClick: origin, secondsPerBeat: 60 / Double(Self.bpm)) else {
            withAnimation(Motion.settle) { phase = .failed }
            Haptics.shared.selection()
            return
        }
        store.audio.saveCalibration(delay, for: route)
        withAnimation(Motion.settle) { result = delay; phase = .done }
        Haptics.shared.done()
    }

    private func stop() {
        run?.cancel()
        if phase == .running { store.audio.stopMetronome() }
    }
}

/// Reports each touch-down at the moment the screen registered it (`UITouch.timestamp`, on the same
/// clock as `CACurrentMediaTime`), not when SwiftUI's gesture system gets round to it.
struct TimedTapPad: UIViewRepresentable {
    let onTap: (TimeInterval) -> Void

    func makeUIView(context: Context) -> PadView {
        let view = PadView()
        view.onTap = onTap
        return view
    }

    func updateUIView(_ view: PadView, context: Context) { view.onTap = onTap }

    final class PadView: UIView {
        var onTap: ((TimeInterval) -> Void)?

        override init(frame: CGRect) {
            super.init(frame: frame)
            backgroundColor = .clear
            isMultipleTouchEnabled = true
            // VoiceOver passes taps straight through, so the timing still counts.
            isAccessibilityElement = true
            accessibilityTraits = [.allowsDirectInteraction]
            accessibilityLabel = String(localized: "Tap")
        }

        required init?(coder: NSCoder) { super.init(coder: coder) }

        override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
            super.touchesBegan(touches, with: event)
            for touch in touches { onTap?(touch.timestamp) }
        }
    }
}
