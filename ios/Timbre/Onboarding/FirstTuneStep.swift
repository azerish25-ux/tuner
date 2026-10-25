import AVFoundation
import CoreHaptics
import Metal
import Observation
import SwiftUI
import TimbreCore
import UIKit

/// What the first tune needs: the chosen instrument's thickest string, as the tuner shows it.
struct FirstTuneSetup {
    let instrument: Instrument
    /// The instrument's default tuning, whose courses the tuning quest counts.
    let tuning: Tuning
    let course: Course
    /// The string's note as the tuner names it ("E2").
    let note: String
    let hz: Double
    let name: String
    let photoAsset: String?
    let modelID: String?
    /// A higher string rings the same letter (the guitar's two Es): the lock says "Low E".
    let low: Bool

    /// What the lock says, as a fact: "Low E, dead on.", or "G, dead on." where no other string shares the letter.
    var fact: Text {
        let letter = String(note.prefix { !$0.isNumber && $0 != "-" })
        return low ? Text("Low \(letter), dead on.") : Text("\(letter), dead on.")
    }

    /// Nil for "Voice or other", or an instrument without strings to pluck.
    @MainActor static func make(store: AppStore, instrumentID: String?) -> FirstTuneSetup? {
        guard let id = instrumentID, let instrument = store.catalog.instrument(id: id),
              let tuning = store.catalog.tuning(id: instrument.defaultTuningId),
              let course = tuning.courses.min(by: { $0.targetMidi < $1.targetMidi }) else { return nil }
        let photo = store.catalog.photo(instrumentId: id)
        let name = photo.map { NSLocalizedString("timbre_photo_" + $0.asset, bundle: .main, value: $0.label, comment: "") } ?? instrument.name.localized
        let low = tuning.courses.contains { $0.targetMidi > course.targetMidi && ($0.targetMidi - course.targetMidi) % 12 == 0 }
        return FirstTuneSetup(instrument: instrument, tuning: tuning, course: course,
                              note: TargetLabelFormatter.splitCue(store.courseLabel(course)).main,
                              hz: store.target(for: course), name: name,
                              photoAsset: photo?.asset, modelID: ModelLibrary.modelID(forPhoto: photo?.asset), low: low)
    }

    /// The step only runs when Timbre can hear: the microphone is allowed (or, in a debug build, the demo pitch plays
    /// the string). "Not now" or a denial skips it rather than asking again.
    static var canListen: Bool {
        #if DEBUG
        if ProcessInfo.processInfo.environment["TIMBRE_DEMO_PITCH"] == "1" { return true }
        #endif
        return AVAudioApplication.shared.recordPermission == .granted
    }
}

/// The locked first string, saved as the tuner saves a session (`AppStore.recordFirstTune`).
struct FirstTuneResult {
    let instrumentId: String
    let tuningId: String
    /// The locked course and every course of the tuning, for the tuning quest.
    let course: Int
    let courses: [Int]
    let started: Date
    let readings: Int
    let stableReadings: Int
    let meanAbsoluteCents: Double?
    let durationMs: Int
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
    /// The session as the tuner counts one: when it began, readings, steady readings and their error.
    @ObservationIgnored private var started = Date()
    @ObservationIgnored private var startedUptime: TimeInterval = 0
    @ObservationIgnored private var readings = 0
    @ObservationIgnored private var stableReadings = 0
    @ObservationIgnored private var totalError = 0.0

    func begin(target: Double) {
        self.target = target
        tracker.reset()
        if !listening { started = Date(); startedUptime = ProcessInfo.processInfo.systemUptime }
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
        if let cents = next.cents, next.frequency != nil {
            readings += 1
            if next.stable { stableReadings += 1; totalError += abs(cents) }
        }
        Haptics.shared.detent(cents: next.stable ? next.cents : nil)
        if next.inTune { lockedIn = true }
    }

    /// The locked string as a tuning session for `AppStore.recordFirstTune`.
    func result(_ setup: FirstTuneSetup) -> FirstTuneResult {
        let count = max(1, readings)
        let steady = min(count, max(1, stableReadings))
        let mean = stableReadings > 0 ? totalError / Double(stableReadings) : abs(reading.cents ?? 0)
        let duration = max(0, Int((ProcessInfo.processInfo.systemUptime - startedUptime) * 1000))
        return FirstTuneResult(instrumentId: setup.instrument.id, tuningId: setup.tuning.id, course: setup.course.index,
                               courses: setup.tuning.courses.map(\.index), started: started, readings: count, stableReadings: steady,
                               meanAbsoluteCents: mean.isFinite ? mean : nil, durationMs: duration)
    }
}

/// Onboarding's first win: "Pluck your thickest string" on the tuner's own live stage. The stage and
/// readout follow the microphone (note, cents, which way to turn), and VoiceOver hears them as on the tuner; when the
/// string locks there is a burst, a haptic chord and the fact ("Low E, dead on."), and the lock is saved like a tuner
/// session (streak, XP, "First in tune"), shown in chips where Skip was. Skip is always there until the lock.
struct FirstTuneStep: View {
    let setup: FirstTuneSetup
    /// Called once: true when the string locked, false when skipped.
    let onDone: (Bool) -> Void
    @EnvironmentObject private var store: AppStore
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityVoiceOverEnabled) private var voiceOver
    @State private var model = FirstTuneModel()
    @State private var motion = ReadoutMotion()
    /// VoiceOver's note and cents while the string is held, and "In tune" on the lock, as the tuner speaks them.
    @State private var announcer = TunerAnnouncer()
    @State private var owner = UUID()
    @State private var burstStart: Date? = nil
    @State private var finished = false
    @State private var failed3D: String? = nil
    @State private var ready3D: String? = nil
    /// What the lock earned (it counts like a string locked on the tuner), shown where Skip was.
    @State private var reward: ProgressUpdate? = nil
    @State private var streakDays = 0
    @State private var rewardsShown = false
    /// After the lock: Tune by feel is offered, with a three-second feel of it (`FeelOffer`), on a phone that can.
    @State private var feelOffered = false
    private static let supports3D = MTLCreateSystemDefaultDevice() != nil

    var body: some View {
        ZStack {
            FirstTuneAura(model: model)
            VStack(spacing: 0) {
                // The header and readout are measured first and keep their full height; the stage takes what's left,
                // so a two-line title never runs over the note line under it.
                header
                    .fixedSize(horizontal: false, vertical: true)
                    .layoutPriority(1)
                ZStack {
                    stage
                    if let burstStart, !reduceMotion { FirstTuneBurst(started: burstStart).allowsHitTesting(false) }
                }
                .frame(maxHeight: .infinity)
                readout
                    .layoutPriority(1)
                ZStack {
                    skipButton
                    if rewardsShown {
                        rewards.transition(.adaptive(.scale(scale: 0.85).combined(with: .opacity), reduceMotion: reduceMotion))
                    }
                }
                .adaptiveAnimation(Motion.pluck, value: rewardsShown)
                if feelOffered {
                    FeelOffer { on in finishFeelOffer(on) }
                        .padding(.horizontal, Metrics.gutter).padding(.bottom, 10)
                        .transition(.adaptive(.move(edge: .bottom).combined(with: .opacity), reduceMotion: reduceMotion))
                }
            }
            .adaptiveAnimation(Motion.settle, value: feelOffered)
        }
        .onAppear(perform: start)
        .onDisappear { store.stopLessonListening(owner: owner) }
        .onChange(of: model.lockedIn) { _, locked in if locked { lockIn() } }
        .onChange(of: scenePhase) { _, phase in
            // The microphone stops in the background; pick the string up again on return.
            if phase == .active && !model.lockedIn && !finished { listen() }
        }
        .task(id: voiceOver) {
            guard voiceOver else { return }
            while !Task.isCancelled {
                announce()
                try? await Task.sleep(for: .milliseconds(200))
            }
        }
    }

    /// Feeds the announcer what the readout shows; on the lock, the lock.
    private func announce() {
        let reading = model.reading
        let locked = model.lockedIn
        let heard = model.listening && (locked || reading.cents != nil)
        let shown: Int? = locked ? 0 : (motion.shown ?? reading.cents.map { Int($0.rounded()) })
        announcer.step(note: setup.note, shown: heard ? shown : nil, locked: locked, now: ProcessInfo.processInfo.systemUptime)
    }

    // MARK: Pieces

    private var header: some View {
        // Locked: the readout's badge says "In tune"; the title says what was done ("Low E, dead on."). A hidden copy
        // of both titles and the line under them keeps the block as tall as the longer one, so the stage below never
        // moves. The shown title cross-fades, and the note line rides up under the fact instead of keeping the second
        // line of "Pluck your thickest string" as a gap; the room left over falls between the block and the stage.
        let locked = model.lockedIn
        return ZStack(alignment: .topLeading) {
            VStack(alignment: .leading, spacing: 6) {
                ZStack(alignment: .topLeading) {
                    title(Text("Pluck your thickest string"), color: Palette.ink)
                    title(setup.fact, color: Palette.mint)
                }
                noteLine
            }
            .hidden()
            .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 6) {
                shownTitle(locked: locked)
                noteLine
            }
            .adaptiveAnimation(Motion.settle, value: locked)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, Metrics.gutter).padding(.top, 18)
    }

    /// The title on screen, cross-fading in place when the string locks.
    private func shownTitle(locked: Bool) -> some View {
        ZStack(alignment: .topLeading) {
            if locked {
                title(setup.fact, color: Palette.mint).transition(.opacity)
            } else {
                title(Text("Pluck your thickest string"), color: Palette.ink).transition(.opacity)
            }
        }
        .animation(Motion.fade, value: locked)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(locked ? setup.fact : Text("Pluck your thickest string"))
        .accessibilityAddTraits(.isHeader)
        .accessibilityIdentifier("onboarding.firsttune")
    }

    /// The string and the instrument ("E2 · Acoustic guitar").
    private var noteLine: some View {
        Text(verbatim: "\(setup.note) · \(setup.name)").font(.subheadline).foregroundStyle(Palette.inkSoft)
    }

    private func title(_ text: Text, color: Color) -> some View {
        text.font(Typeface.stepTitle).tracking(-0.6)
            .foregroundStyle(color)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
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
                                    onReady: { withAnimation(Motion.reveal) { ready3D = modelID } })
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
            Text("Skip").font(.subheadline.weight(.semibold))
                .padding(.horizontal, 24)
        }
        .buttonStyle(TextLinkStyle(tint: Palette.inkSoft))
        .opacity(model.lockedIn ? 0 : 1)
        .disabled(model.lockedIn)
        .padding(.bottom, 10)
        .accessibilityIdentifier("onboarding.firsttune.skip")
    }

    /// The badge, the XP and day one of the streak, in one row (two when they don't fit).
    private var rewards: some View {
        let badge = reward?.achievementsEarned.first
        let xp = reward?.xpGained ?? 0
        return ViewThatFits(in: .horizontal) {
            HStack(spacing: 8) {
                if let badge { badgeChip(badge) }
                xpAndStreak(xp)
            }
            VStack(spacing: 8) {
                if let badge { badgeChip(badge) }
                HStack(spacing: 8) { xpAndStreak(xp) }
            }
        }
        .padding(.horizontal, Metrics.gutter).padding(.bottom, 10)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("onboarding.firsttune.reward")
    }

    @ViewBuilder private func xpAndStreak(_ xp: Int) -> some View {
        if xp > 0 { rewardChip(symbol: "sparkles", tint: Palette.mint, text: Text("+\(xp) XP")) }
        if streakDays > 0 { rewardChip(symbol: "flame.fill", tint: Palette.flame, text: Text("\(streakDays)-day streak")) }
    }

    private func badgeChip(_ badge: Achievement) -> some View {
        rewardChip(symbol: badge.symbol, tint: Palette.starGold, text: Text(LocalizedStringKey(badge.title)))
    }

    private func rewardChip(symbol: String, tint: Color, text: Text) -> some View {
        HStack(spacing: 6) {
            Image(systemName: symbol).font(.system(size: 12, weight: .bold)).foregroundStyle(tint)
            text.font(Typeface.label(.footnote)).foregroundStyle(Palette.ink).lineLimit(1)
        }
        .padding(.horizontal, 12).frame(minHeight: 34)
        .background(Capsule().fill(tint.opacity(0.14)))
        .overlay(Capsule().strokeBorder(tint.opacity(0.4), lineWidth: 1))
        .fixedSize()
    }

    // MARK: Flow

    private func start() {
        guard !finished else { return }
        model.begin(target: setup.hz)
        SoundFX.shared.prepareLocks([setup.hz])
        listen()
    }

    private func listen() {
        // The demo pitch of a debug build follows the game target; the microphone ignores it.
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
        Analytics.log("onboarding_first_tune", ["result": "locked", "instrument": setup.instrument.id])
        // It counts: today's practice (the streak starts), the string's XP and the "First in tune" badge.
        reward = store.recordFirstTune(model.result(setup))
        streakDays = store.streak.current
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(220))
            Haptics.shared.done()
            SoundFX.shared.play(.star)
            rewardsShown = reward != nil || streakDays > 0
            try? await Task.sleep(for: .milliseconds(rewardsShown ? 2300 : 1700))
            // The string just went still in the hand too: the moment to offer the feel of it. It waits for an answer.
            if FeelOffer.available(store.settings) {
                feelOffered = true
                Analytics.log("feel_offer", ["result": "shown"])
            } else {
                finish(locked: true)
            }
        }
    }

    /// The feel offer answered: on (the setting is saved and the tuner beats from now on) or not now; then onward.
    private func finishFeelOffer(_ on: Bool) {
        if on { store.updateSettings { $0.tuneByFeel = true } }
        Analytics.log("feel_offer", ["result": on ? "on" : "later"])
        finish(locked: true)
    }

    private func finish(locked: Bool) {
        guard !finished else { return }
        finished = true
        store.stopLessonListening(owner: owner)
        if !locked { Analytics.log("onboarding_first_tune", ["result": "skipped", "instrument": setup.instrument.id]) }
        onDone(locked)
    }
}

/// Tune by feel, offered once the first string has locked: "Want to feel it?", a three-second feel of it (a string
/// coming into tune, the beat slowing to stillness, `Haptics.feelTest`), and the choice to turn it on. Offered only on a
/// phone that can play it, with haptics on and Tune by feel still off; it never turns itself on.
private struct FeelOffer: View {
    /// Called once: true when the player turned it on.
    let onDone: (Bool) -> Void
    @State private var feeling = false
    @State private var felt = false

    static func available(_ settings: UserSettings) -> Bool {
        CHHapticEngine.capabilitiesForHardware().supportsHaptics && settings.hapticsEnabled && !settings.tuneByFeel
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                Glyph("hand.tap", size: Glyph.lead, tint: Palette.mint)
                VStack(alignment: .leading, spacing: 3) {
                    Text("Want to feel it?").font(.headline).foregroundStyle(Palette.ink)
                        .accessibilityAddTraits(.isHeader)
                    Text("Tune by feel: your iPhone pulses slower as the string comes in, and goes still in tune.")
                        .font(.subheadline).foregroundStyle(Palette.inkSoft)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 10) { feelButton; onButton }
                VStack(spacing: 8) { feelButton; onButton }
            }
            Button { onDone(false) } label: {
                Text("Not now").font(.subheadline.weight(.semibold)).padding(.horizontal, 12)
            }
            .buttonStyle(TextLinkStyle(tint: Palette.inkSoft))
            .frame(maxWidth: .infinity)
            .accessibilityIdentifier("onboarding.feel.later")
        }
        .stillCard()
        .accessibilityElement(children: .contain)
    }

    /// Plays the feel: about three seconds of a string beating its way into tune, then the lock.
    private var feelButton: some View {
        Button {
            guard !feeling else { return }
            feeling = true
            Haptics.shared.feelTest()
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(3_400))
                feeling = false
                felt = true
            }
        } label: {
            Label(felt ? "Feel it again" : "Feel it", systemImage: "iphone.radiowaves.left.and.right")
        }
        .buttonStyle(SecondaryButtonStyle())
        .disabled(feeling)
        .accessibilityHint(Text("Plays three seconds of the feel on your iPhone"))
        .accessibilityIdentifier("onboarding.feel.try")
    }

    private var onButton: some View {
        Button("Turn it on") {
            Haptics.shared.selection()
            onDone(true)
        }
        .buttonStyle(PrimaryButtonStyle())
        .accessibilityIdentifier("onboarding.feel.on")
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
            .animation(Motion.fade, value: locked)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }
}

/// Onboarding's wins (the first tune's lock, the first chord): a ring of light and sparks from the stage.
struct FirstTuneBurst: View {
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
                    let color = spark.hue > 0.65 ? Palette.starGold : Palette.mint
                    context.fill(Path(ellipseIn: CGRect(x: p.x - spark.size, y: p.y - spark.size, width: spark.size * 2, height: spark.size * 2)),
                                 with: .color(color.opacity(alpha)))
                }
            }
        }
        .accessibilityHidden(true)
    }
}
