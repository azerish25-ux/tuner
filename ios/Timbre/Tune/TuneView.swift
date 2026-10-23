import AVFoundation
import Metal
import StoreKit
import SwiftUI
import TimbreCore

struct TuneView: View {
    @EnvironmentObject private var store: AppStore
    @EnvironmentObject private var audio: AudioService
    @Environment(\.requestReview) private var requestReview
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// Settings › Strobe precision: a strobe band in place of the needle meter.
    @AppStorage(TuneView.strobeKey) private var strobeView = false
    static let strobeKey = "tune.strobe"
    @State private var motion = ReadoutMotion()
    @State private var failed3D: String?
    @State private var ready3D: String?
    private static let supports3D = MTLCreateSystemDefaultDevice() != nil

    var body: some View {
        ZStack {
            StageBackground()
            PitchAura().allowsHitTesting(false)
            GeometryReader { proxy in
                // Landscape and large iPad windows: the stage takes the left, tuning controls the right.
                let wide = proxy.size.width > proxy.size.height * 1.15
                VStack(spacing: 0) {
                    header
                    if wide {
                        HStack(spacing: 20) {
                            stage.frame(maxWidth: .infinity, maxHeight: .infinity)
                            VStack(spacing: 0) {
                                Spacer(minLength: 0)
                                tuningPanel
                                Spacer(minLength: 0)
                            }
                            .frame(width: min(560, proxy.size.width * 0.44))
                        }
                    } else {
                        stage.frame(maxHeight: .infinity)
                        tuningPanel.frame(maxWidth: 680)
                    }
                }
                .frame(width: proxy.size.width, height: proxy.size.height)
            }
            CelebrationOverlay()
        }
        .onAppear { autoListen() }
        .onChange(of: scenePhase) { _, phase in if phase == .active && store.selectedTab == .tune { autoListen() } }
        .onChange(of: store.requestReviewNow) { _, now in
            if now { requestReview(); store.requestReviewNow = false }
        }
        .task(id: "\(store.tuning.id) \(store.settings.referencePitchHz) \(store.settings.temperamentId)") {
            SoundFX.shared.prepareLocks(store.courses.map { store.target(for: $0) })
        }
        .onChange(of: store.lockedCourses) { old, new in
            // A string just locked: a soft bell at its own pitch (an octave up when it's low).
            guard let index = new.subtracting(old).first, let course = store.courses.first(where: { $0.index == index }) else { return }
            store.autoQuietUntil = ProcessInfo.processInfo.systemUptime + 1.2
            SoundFX.shared.playLock(frequency: store.target(for: course))
        }
        .sheet(isPresented: $store.showInstrumentPicker) { InstrumentPicker().presentationDetents([.large]).presentationBackground(Palette.stage) }
    }

    private func autoListen() {
        guard store.settings.onboardingCompleted == true, !audio.running, store.canListen,
              AVAudioApplication.shared.recordPermission == .granted else { return }
        store.startListening()
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 8) {
            Button { store.showInstrumentPicker = true } label: {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(store.instrumentDisplayName).font(.title3.weight(.semibold)).foregroundStyle(Palette.ink).lineLimit(1)
                        Image(systemName: "chevron.down").font(.caption.weight(.bold)).foregroundStyle(Palette.inkSoft)
                    }
                    Group {
                        if store.referenceMode { Text("Any note · A4 \(Int(store.settings.referencePitchHz)) Hz") }
                        else { Text("\(store.tuning.name.localized) · A4 \(Int(store.settings.referencePitchHz)) Hz") }
                    }
                    .font(.footnote).foregroundStyle(Palette.inkSoft).lineLimit(1)
                }
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("tune.instrument")
            Spacer(minLength: 4)
            StreakChip { store.selectedTab = .journey }
            LevelRing(size: 36) { store.selectedTab = .journey }
            Button { store.showSettings = true } label: {
                Image(systemName: "slider.horizontal.3").font(.subheadline.weight(.semibold)).foregroundStyle(Palette.ink)
                    .frame(width: 36, height: 36)
                    .background(Circle().fill(.white.opacity(0.04)))
                    .overlay(Circle().strokeBorder(.white.opacity(0.12), lineWidth: 1))
            }
            .buttonStyle(.plain)
            .accessibilityLabel(Text("Settings")).accessibilityIdentifier("settings.open")
        }
        .padding(.horizontal, Metrics.gutter).padding(.top, 6)
    }

    private func stageInput() -> StageInput {
        StageInput(cents: store.live.reading.cents, level: store.live.level, locked: store.live.reading.inTune,
                   listening: audio.running, activeAnchor: store.activeAnchor, focus: audio.running && !store.referenceMode,
                   note: store.targetName)
    }

    @ViewBuilder private var stage: some View {
        ZStack(alignment: .top) {
            if store.referenceMode {
                // The note name lives in the readout below; the strobe ring stays clear of the side buttons.
                ChromaticStage(input: stageInput, note: "").padding(.vertical, 20).padding(.horizontal, 64)
            } else if let modelID = store.modelID {
                let rig = ModelLibrary.rig(modelID)
                if Self.supports3D && store.settings.stageMode != "studio" && failed3D != modelID {
                    ZStack {
                        // The studio render holds the stage while the 3D model loads, then cross-fades out.
                        if ready3D != modelID {
                            StudioStage(imageName: ModelLibrary.hasCard(modelID) ? ModelLibrary.cardImageName(modelID) : (store.photo?.asset ?? ""), card: nil, input: stageInput)
                                .padding(.horizontal, 16)
                                .transition(.opacity)
                        }
                        InstrumentStage(modelID: modelID, input: stageInput, onSelect: { store.chooseAnchor($0) },
                                        onFailure: { failed3D = modelID },
                                        onReady: { withAnimation(.easeInOut(duration: 0.6)) { ready3D = modelID } })
                    }
                } else if ModelLibrary.hasCard(modelID) {
                    StudioStage(imageName: ModelLibrary.cardImageName(modelID), card: rig.flatMap(StageCard.init(rig:)), input: stageInput) { store.chooseAnchor($0) }
                        .padding(.horizontal, 16)
                } else if let photo = store.photo {
                    StudioStage(imageName: photo.asset, card: ModelLibrary.photoCard(photo.asset), input: stageInput) { store.chooseAnchor($0) }.padding(28)
                }
            } else if let photo = store.photo {
                StudioStage(imageName: photo.asset, card: ModelLibrary.photoCard(photo.asset), input: stageInput) { store.chooseAnchor($0) }.padding(28)
            }
        }
        .overlay(alignment: .trailing) { sideControls.padding(.trailing, 14) }
        // A container element keeps its children's own identifiers (stage.debug).
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("tune.stage")
    }

    private var readout: some View {
        TimelineView(.animation) { timeline in
            let reading = store.live.reading
            let heard = audio.running || store.live.preserved
            let _ = motion.step(heard ? reading.cents : nil, locked: reading.inTune, now: timeline.date.timeIntervalSinceReferenceDate,
                                hertz: reading.frequency, target: store.targetHz)
            let shown = motion.shown
            VStack(spacing: 14) {
                NoteReadout(note: store.targetName, shown: shown, hertz: motion.shownHertz, target: store.targetHz, locked: reading.inTune)
                meter(locked: reading.inTune, shown: shown)
                // The same steady whole cents and colour rule as the digits above, changing in place
                // (no rolling digits), so the two never disagree.
                Text(statusLine(reading, shown: shown)).font(.footnote.weight(.semibold))
                    .foregroundStyle(statusColor(reading, shown: shown))
                    .monospacedDigit()
                    .accessibilityIdentifier("tune.status")
            }
        }
        .padding(.bottom, 4)
    }

    /// The needle meter, or with Strobe precision on, a strobe band that drifts with the error and stands still in tune.
    @ViewBuilder private func meter(locked: Bool, shown: Int?) -> some View {
        if strobeView {
            StrobeBand(cents: shown.map { Double($0) }, phase: reduceMotion ? 0 : motion.phase, locked: locked, active: motion.cents != nil)
                .frame(height: 26).padding(.vertical, 6).padding(.horizontal, 32)
        } else {
            RibbonMeter(cents: motion.cents, shown: shown, phase: motion.phase, locked: locked)
                .frame(height: 38).padding(.horizontal, 32)
        }
    }

    /// The status under the meter reads the readout's own whole cents against the tracker's lock band:
    /// "Hold it…" inside the band, "Tighten"/"Loosen" outside it, "In tune" once the tracker locks.
    private func statusLine(_ reading: TuningReading, shown: Int?) -> String {
        guard audio.running, !store.live.preserved, reading.cents != nil, let shown else { return store.statusText }
        if reading.inTune { return String(localized: "In tune") }
        let amount = abs(shown)
        if Double(amount) <= Palette.tuningBand { return String(localized: "Hold it…") }
        return shown < 0 ? String(localized: "Tighten · \(amount)¢ flat") : String(localized: "Loosen · \(amount)¢ sharp")
    }

    private func statusColor(_ reading: TuningReading, shown: Int?) -> Color {
        guard audio.running, !store.live.preserved, reading.cents != nil, let shown else { return Palette.inkSoft }
        return Palette.tuning(Double(shown), locked: reading.inTune)
    }

    private var tuningPanel: some View {
        VStack(spacing: 6) {
            readout
            if !store.referenceMode { questLine }
            StringRail(motion: motion).opacity(store.referenceMode ? 0 : 1).frame(height: store.referenceMode ? 8 : nil)
        }
        .padding(.bottom, 8)
    }

    /// Today's tuning quest: every string of this instrument, with its XP.
    private var questLine: some View {
        let quest = store.quests.first { $0.kind == .tuneAll }
        let counter = quest.map { Quests.counter(for: $0, progress: store.questProgress($0), lockedStrings: store.lockedCourses.count, strings: store.courses.count) }
        let done = counter?.done ?? min(store.lockedCourses.count, store.courses.count), total = counter?.total ?? store.courses.count
        return HStack {
            (Text("Daily quest · tune all \(total) ").foregroundStyle(Palette.inkSoft) + Text("\(done) / \(total)").foregroundStyle(Palette.ink).bold())
                .font(.caption)
            Spacer()
            if let quest {
                Text(store.questProgress(quest) >= quest.target ? "Done" : "+\(quest.xp) XP").font(Typeface.label(12)).foregroundStyle(Palette.mint)
            }
        }
        .padding(.horizontal, Metrics.gutter + 2)
        .accessibilityElement(children: .combine)
    }

    /// Hear the target, automatic string detection and listening, stacked beside the instrument.
    private var sideControls: some View {
        VStack(spacing: 12) {
            StageControl(symbol: audio.tonePlaying ? "speaker.slash.fill" : "speaker.wave.2.fill", active: audio.tonePlaying) { store.toggleTone() }
                .accessibilityLabel(Text(audio.tonePlaying ? "Stop reference tone" : "Play reference tone"))
                .accessibilityIdentifier("tune.tone")
            StageControl(symbol: store.automatic ? "wand.and.stars" : "hand.tap", active: store.automatic) { store.automatic.toggle(); Haptics.shared.selection() }
                .accessibilityLabel(Text(store.automatic ? "Automatic string detection on" : "Manual string selection"))
                .accessibilityIdentifier("tune.auto")
            ListenOrb()
        }
    }
}

/// Round 44-point control floating over the stage.
struct StageControl: View {
    let symbol: String
    var active = false
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            Image(systemName: symbol).font(.system(size: 16, weight: .semibold))
                .foregroundStyle(active ? Palette.mint : Palette.ink)
                .frame(width: 44, height: 44)
                .background(Circle().fill(active ? Palette.mint.opacity(0.12) : .white.opacity(0.05)))
                .overlay(Circle().strokeBorder(active ? Palette.mint.opacity(0.45) : .white.opacity(0.12), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }
}

/// Listening on and off: mint when listening, its halo breathing with the input level.
struct ListenOrb: View {
    @EnvironmentObject private var store: AppStore
    @EnvironmentObject private var audio: AudioService
    var body: some View {
        let level = audio.running ? max(0, min(1, (store.live.level + 60) / 45)) : 0
        Button { store.toggleListening(); Haptics.shared.selection() } label: {
            ZStack {
                Circle().fill(Palette.mint.opacity(0.2)).frame(width: 52, height: 52).scaleEffect(1 + level * 0.35).opacity(audio.running ? 1 : 0)
                Circle().fill(audio.running ? AnyShapeStyle(Palette.mint) : AnyShapeStyle(Color.white.opacity(0.05)))
                    .frame(width: 44, height: 44)
                    .overlay(Circle().strokeBorder(audio.running ? .clear : .white.opacity(0.12), lineWidth: 1))
                Image(systemName: audio.running ? "pause.fill" : "mic.fill").font(.system(size: 16, weight: .bold))
                    .foregroundStyle(audio.running ? Palette.onAccent : Palette.ink)
            }
            .frame(width: 52, height: 52)
            .animation(.easeOut(duration: 0.12), value: level)
            .animation(Motion.pluck, value: audio.running)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(audio.running ? "Pause listening" : "Listen"))
        .accessibilityIdentifier("listenButton")
    }
}

/// Warm or cool light behind the stage that follows the pitch.
struct PitchAura: View {
    @EnvironmentObject private var store: AppStore
    var body: some View {
        let reading = store.live.reading
        let color = Palette.tuning(reading.cents, locked: reading.inTune)
        RadialGradient(colors: [color.opacity(reading.cents == nil ? 0 : (reading.inTune ? 0.28 : 0.14)), .clear], center: UnitPoint(x: 0.5, y: 0.42), startRadius: 20, endRadius: 360)
            .ignoresSafeArea()
            .animation(.easeOut(duration: 0.35), value: reading.inTune)
    }
}
