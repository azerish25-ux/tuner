import AVFoundation
import Metal
import Observation
import SwiftUI
import TimbreCore
import UIKit

/// What the first tune needs: the chosen instrument's thickest string, as the tuner shows it.
struct FirstTuneSetup {
    let instrument: Instrument
    let course: Course
    /// The string's note as the tuner names it ("E2").
    let note: String
    let hz: Double
    let name: String
    let photoAsset: String?
    let modelID: String?

    /// Nil for "Voice or other", or an instrument without strings to pluck.
    @MainActor static func make(store: AppStore, instrumentID: String?) -> FirstTuneSetup? {
        guard let id = instrumentID, let instrument = store.catalog.instrument(id: id),
              let tuning = store.catalog.tuning(id: instrument.defaultTuningId),
              let course = tuning.courses.min(by: { $0.targetMidi < $1.targetMidi }) else { return nil }
        let photo = store.catalog.photo(instrumentId: id)
        let name = photo.map { NSLocalizedString("timbre_photo_" + $0.asset, bundle: .main, value: $0.label, comment: "") } ?? instrument.name.localized
        return FirstTuneSetup(instrument: instrument, course: course,
                              note: TargetLabelFormatter.splitCue(store.courseLabel(course)).main,
                              hz: store.target(for: course), name: name,
                              photoAsset: photo?.asset, modelID: ModelLibrary.modelID(forPhoto: photo?.asset))
    }

    /// The step only runs when Timbre can hear: the microphone is allowed (or the UI-test demo pitch plays).
    /// "Not now" or a denial skips it rather than asking again.
    static var canListen: Bool {
        #if DEBUG
        if ProcessInfo.processInfo.environment["TIMBRE_DEMO_PITCH"] == "1" { return true }
        #endif
        return AVAudioApplication.shared.recordPermission == .granted
    }
}

/// Readings for the first tune, kept apart from the view so only the stage and readout redraw with them.
@Observable
@MainActor
final class FirstTuneModel {
    private(set) var reading = TuningReading(frequency: nil, cents: nil, stable: false, inTune: false, status: "noSignal")
    private(set) var level: Double = -120
    private(set) var listening = false
    /// Set once, when the string locks; the reading freezes there.
    private(set) var lockedIn = false
    private let tracker = TuningTracker()
    @ObservationIgnored private var target: Double = 440

    func begin(target: Double) {
        self.target = target
        tracker.reset()
        listening = true
    }

    func accept(_ hz: Double?, level: Double) {
        guard listening, !lockedIn else { return }
        self.level = level
        let now = Int(ProcessInfo.processInfo.systemUptime * 1000)
        // Another string far from this one reads as "let it ring", not as a needle pinned at the edge.
        let near = hz.flatMap { abs(PitchMath.cents(target: target, measured: $0)) <= 300 ? $0 : nil }
        var next = tracker.accept(frequency: near, confidence: near == nil ? 0 : 1, target: target, timestampMs: now)
        if near == nil && level > -60 { next = TuningReading(frequency: nil, cents: nil, stable: false, inTune: false, status: "uncertain") }
        reading = next
        Haptics.shared.detent(cents: next.stable ? next.cents : nil)
        if next.inTune { lockedIn = true }
    }
}

/// Onboarding's first win: "Pluck your thickest string" on the tuner's own live stage. The stage and
/// readout follow the microphone (note, cents, which way to turn); when the string locks there is a
/// burst, a haptic chord and "In tune", then the plan. Skip is always there.
struct FirstTuneStep: View {
    let setup: FirstTuneSetup
    /// Called once: true when the string locked, false when skipped.
    let onDone: (Bool) -> Void
    @EnvironmentObject private var store: AppStore
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var model = FirstTuneModel()
    @State private var motion = ReadoutMotion()
    @State private var owner = UUID()
    @State private var burstStart: Date? = nil
    @State private var finished = false
    @State private var failed3D: String? = nil
    @State private var ready3D: String? = nil
    private static let supports3D = MTLCreateSystemDefaultDevice() != nil

    var body: some View {
        ZStack {
            FirstTuneAura(model: model)
            VStack(spacing: 0) {
                header
                ZStack {
                    stage
                    if let burstStart, !reduceMotion { FirstTuneBurst(started: burstStart).allowsHitTesting(false) }
                }
                .frame(maxHeight: .infinity)
                readout
                skipButton
            }
        }
        .onAppear(perform: start)
        .onDisappear { store.stopLessonListening(owner: owner) }
        .onChange(of: model.lockedIn) { _, locked in if locked { lockIn() } }
        .onChange(of: scenePhase) { _, phase in
            // The microphone stops in the background; pick the string up again on return.
            if phase == .active && !model.lockedIn && !finished { listen() }
        }
    }

    // MARK: Pieces

    private var header: some View {
        // Locked: the readout's badge says "In tune"; the title cheers instead of repeating it.
        let title: LocalizedStringKey = model.lockedIn ? "Great work" : "Pluck your thickest string"
        return VStack(alignment: .leading, spacing: 6) {
            Text(title).font(Typeface.display(32)).tracking(-0.6)
                .foregroundStyle(model.lockedIn ? Palette.mint : Palette.ink)
                .fixedSize(horizontal: false, vertical: true)
                .contentTransition(.opacity)
                .animation(Motion.quick, value: model.lockedIn)
                .accessibilityAddTraits(.isHeader)
                .accessibilityIdentifier("onboarding.firsttune")
            Text(verbatim: "\(setup.note) · \(setup.name)").font(.subheadline).foregroundStyle(Palette.inkSoft)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 24).padding(.top, 18)
    }

    /// The same stage the Tune tab draws: the 3D instrument (its studio render while it loads), else the 2D one.
    @ViewBuilder private var stage: some View {
        if let modelID = setup.modelID {
            if Self.supports3D && store.settings.stageMode != "studio" && failed3D != modelID {
                ZStack {
                    if ready3D != modelID {
                        StudioStage(imageName: ModelLibrary.hasCard(modelID) ? ModelLibrary.cardImageName(modelID) : (setup.photoAsset ?? ""), card: nil, input: stageInput)
                            .padding(.horizontal, 16)
                            .transition(.opacity)
                    }
                    InstrumentStage(modelID: modelID, input: stageInput,
                                    onFailure: { failed3D = modelID },
                                    onReady: { withAnimation(.easeInOut(duration: 0.6)) { ready3D = modelID } })
                }
            } else if ModelLibrary.hasCard(modelID) {
                StudioStage(imageName: ModelLibrary.cardImageName(modelID), card: ModelLibrary.rig(modelID).flatMap(StageCard.init(rig:)), input: stageInput)
                    .padding(.horizontal, 16)
            } else if let asset = setup.photoAsset {
                StudioStage(imageName: asset, card: ModelLibrary.photoCard(asset), input: stageInput).padding(28)
            }
        } else if let asset = setup.photoAsset {
            StudioStage(imageName: asset, card: ModelLibrary.photoCard(asset), input: stageInput).padding(28)
        }
    }

    private func stageInput() -> StageInput {
        let reading = model.reading
        return StageInput(cents: reading.cents, level: model.level, locked: reading.inTune || model.lockedIn, listening: model.listening,
                          activeAnchor: setup.course.anchorId, focus: model.listening, note: setup.note)
    }

    /// The tuner's readout: big note, cents and hertz, the ribbon, and what to do in words.
    private var readout: some View {
        TimelineView(.animation) { timeline in
            let reading = model.reading
            let locked = reading.inTune || model.lockedIn
            let _ = motion.step(model.listening ? reading.cents : nil, locked: locked, now: timeline.date.timeIntervalSinceReferenceDate,
                                hertz: reading.frequency, target: setup.hz)
            let shown = motion.shown
            VStack(spacing: 12) {
                NoteReadout(note: setup.note, shown: shown, hertz: motion.shownHertz, target: setup.hz, locked: locked, compact: true)
                RibbonMeter(cents: motion.cents, shown: shown, phase: motion.phase, locked: locked)
                    .frame(height: 34).padding(.horizontal, 32)
                // Once locked the badge above says "In tune"; the line keeps its height but goes quiet.
                Text(statusLine(reading, shown: shown, locked: locked))
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(statusColor(reading, shown: shown, locked: locked))
                    .monospacedDigit()
                    .opacity(locked ? 0 : 1)
                    .animation(Motion.quick, value: locked)
                    .accessibilityHidden(locked)
                    .accessibilityIdentifier("onboarding.firsttune.status")
            }
        }
        .padding(.bottom, 4)
    }

    private func statusLine(_ reading: TuningReading, shown: Int?, locked: Bool) -> String {
        if locked { return String(localized: "In tune") }
        switch reading.status {
        case "settling": return String(localized: "Hold it…")
        case "uncertain": return String(localized: "Let the string ring")
        case "flat", "sharp":
            let amount = max(1, abs(shown ?? Int((reading.cents ?? 0).rounded())))
            return reading.status == "flat" ? String(localized: "Tighten · \(amount)¢ flat") : String(localized: "Loosen · \(amount)¢ sharp")
        default: return String(localized: "Pluck the string")
        }
    }

    private func statusColor(_ reading: TuningReading, shown: Int?, locked: Bool) -> Color {
        if locked { return Palette.mint }
        guard reading.cents != nil, let shown else { return Palette.inkSoft }
        return Palette.tuning(Double(shown), locked: false)
    }

    private var skipButton: some View {
        Button { finish(locked: false) } label: {
            Text("Skip").font(.subheadline.weight(.semibold)).foregroundStyle(Palette.inkSoft)
                .padding(.horizontal, 24).frame(minHeight: 44).contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .opacity(model.lockedIn ? 0 : 1)
        .disabled(model.lockedIn)
        .padding(.bottom, 10)
        .accessibilityIdentifier("onboarding.firsttune.skip")
    }

    // MARK: Flow

    private func start() {
        guard !finished else { return }
        model.begin(target: setup.hz)
        SoundFX.shared.prepareLocks([setup.hz])
        listen()
    }

    private func listen() {
        // The UI-test demo pitch follows the game target; the microphone ignores it.
        store.gameTargetHz = setup.hz
        let model = self.model
        let low = max(25, min(setup.instrument.minFrequencyHz, setup.hz) / 1.12)
        let high = min(4500, max(setup.instrument.maxFrequencyHz, setup.hz * 2) * 1.12)
        store.startLessonListening(owner: owner, lowHz: low, highHz: high) { hz, level in model.accept(hz, level: level) }
    }

    /// Locked: the microphone closes, the stage holds its glow, then the plan.
    private func lockIn() {
        guard !finished else { return }
        store.stopLessonListening(owner: owner)
        Haptics.shared.lock()
        // The tuner's own lock bell, at the pitch of the string just tuned.
        SoundFX.shared.playLock(frequency: setup.hz)
        burstStart = Date()
        UIAccessibility.post(notification: .announcement, argument: String(localized: "In tune"))
        Analytics.log("onboarding_first_tune", ["result": "locked", "instrument": setup.instrument.id])
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(220))
            Haptics.shared.done()
            SoundFX.shared.play(.star)
            try? await Task.sleep(for: .milliseconds(1700))
            finish(locked: true)
        }
    }

    private func finish(locked: Bool) {
        guard !finished else { return }
        finished = true
        store.stopLessonListening(owner: owner)
        if !locked { Analytics.log("onboarding_first_tune", ["result": "skipped", "instrument": setup.instrument.id]) }
        onDone(locked)
    }
}

/// Warm or cool light behind the stage that follows the pitch, brightest once in tune.
private struct FirstTuneAura: View {
    let model: FirstTuneModel
    var body: some View {
        let reading = model.reading
        let locked = reading.inTune || model.lockedIn
        let color = Palette.tuning(reading.cents, locked: locked)
        RadialGradient(colors: [color.opacity(reading.cents == nil && !locked ? 0 : (locked ? 0.3 : 0.14)), .clear],
                       center: UnitPoint(x: 0.5, y: 0.42), startRadius: 20, endRadius: 360)
            .ignoresSafeArea()
            .animation(.easeOut(duration: 0.35), value: locked)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }
}

/// The lock: a ring of light and sparks from the stage.
private struct FirstTuneBurst: View {
    let started: Date
    private struct Spark { let angle, speed, size, hue: Double }
    private static let sparks: [Spark] = {
        var g = SystemRandom(seed: 7)
        return (0..<72).map { _ in Spark(angle: g.next() * 2 * .pi, speed: 110 + 260 * g.next(), size: 1.5 + 3 * g.next(), hue: g.next()) }
    }()

    var body: some View {
        TimelineView(.animation) { timeline in
            Canvas { context, size in
                let t = timeline.date.timeIntervalSince(started)
                guard t < 2.2 else { return }
                let center = CGPoint(x: size.width / 2, y: size.height * 0.42)
                let ring = 30 + t * 340
                context.stroke(Path(ellipseIn: CGRect(x: center.x - ring, y: center.y - ring, width: ring * 2, height: ring * 2)),
                               with: .color(Palette.mint.opacity(max(0, 0.55 - t * 0.35))), lineWidth: 2)
                for spark in Self.sparks {
                    let d = spark.speed * t * (1 - t / 4)
                    let p = CGPoint(x: center.x + cos(spark.angle) * d, y: center.y + sin(spark.angle) * d + 50 * t * t)
                    let alpha = max(0, 1 - t / 2)
                    let color = spark.hue > 0.65 ? Palette.amber : Palette.mint
                    context.fill(Path(ellipseIn: CGRect(x: p.x - spark.size, y: p.y - spark.size, width: spark.size * 2, height: spark.size * 2)),
                                 with: .color(color.opacity(alpha)))
                }
            }
        }
        .accessibilityHidden(true)
    }
}
