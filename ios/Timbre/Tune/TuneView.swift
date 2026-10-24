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
    @Environment(\.accessibilityVoiceOverEnabled) private var voiceOver
    @Environment(\.colorSchemeContrast) private var contrast
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    /// Settings › Strobe precision: a strobe band in place of the needle meter.
    @AppStorage(TuneView.strobeKey) private var strobeView = false
    static let strobeKey = "tune.strobe"
    @State private var motion = ReadoutMotion()
    @State private var announcer = TunerAnnouncer()
    @State private var failed3D: String?
    @State private var ready3D: String?
    /// Every string has locked: the camera pulls back to the whole instrument for the celebration. Choosing a
    /// string (by tap or by playing it) or starting a new round brings the headstock close-up straight back.
    @State private var showWhole = false
    /// Strum to tune is open (`StrumTuneView`).
    @State private var strumOpen = false
    private static let supports3D = MTLCreateSystemDefaultDevice() != nil
    #if DEBUG
    /// UI-test probe (TIMBRE_DEBUG_STATE=1), see `stageProbe`.
    private static let probe = ProcessInfo.processInfo.environment["TIMBRE_DEBUG_STATE"] == "1"
    /// When listening last started, in seconds since 1970 (0 while not listening): the demo pitch's cycles count from it.
    @State private var listeningSince: Double = 0
    #endif

    var body: some View {
        ZStack {
            StageBackground()
            PitchAura().allowsHitTesting(false)
            GeometryReader { proxy in
                let arrangement = TuneArrangement(size: proxy.size, regular: horizontalSizeClass == .regular && verticalSizeClass == .regular)
                VStack(spacing: 0) {
                    header
                    // One layout that changes shape rather than two branches: the stage keeps its identity when the
                    // window turns or resizes, so the 3D instrument carries on instead of being rebuilt, losing its
                    // loaded model and showing the studio stand-in (or nothing) while it loads again.
                    arrangement.layout {
                        stage(controls: arrangement != .columns)
                            .frame(width: arrangement == .columns ? TuneArrangement.stageWidth(in: proxy.size.width) : nil)
                            .frame(maxWidth: arrangement == .beside ? CGFloat.infinity : nil, maxHeight: .infinity)
                        panel(arrangement, width: proxy.size.width)
                        if arrangement == .columns { controlRail }
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
            // The last string: a resolving chord for the whole instrument instead of one more bell.
            if store.allCoursesLocked {
                store.autoQuietUntil = ProcessInfo.processInfo.systemUptime + 2.6
                SoundFX.shared.play(.tuned)
            } else {
                store.autoQuietUntil = ProcessInfo.processInfo.systemUptime + 1.2
                SoundFX.shared.playLock(frequency: store.target(for: course))
                advanceInPair(after: index)
            }
        }
        // VoiceOver: the note and cents spoken while a pitch is held, "In tune" on the lock.
        .task(id: voiceOver) {
            guard voiceOver else { return }
            while !Task.isCancelled {
                announce()
                try? await Task.sleep(for: .milliseconds(200))
            }
        }
        .onChange(of: store.allCoursesLocked) { _, all in showWhole = all }
        .onChange(of: store.selectedCourse) { _, _ in showWhole = false }
        // A page sheet on iPad: tall enough for the tunings, filters and the shelf of cards in full (a form sheet cut
        // the cards in half); a phone's sheet is unchanged.
        .sheet(isPresented: $store.showInstrumentPicker) {
            InstrumentPicker().presentationDetents([.large]).presentationSizing(.page).presentationBackground(Palette.stage)
        }
        .fullScreenCover(isPresented: $strumOpen) { StrumTuneView().environmentObject(store).environmentObject(audio) }
        #if DEBUG
        .overlay(alignment: .bottomLeading) { if Self.probe { stageProbe } }
        .onChange(of: audio.running, initial: true) { _, running in listeningSince = running ? Date().timeIntervalSince1970 : 0 }
        #endif
    }

    #if DEBUG
    /// For XCUITest only: which stage is up ("3d" once the model has replaced its studio render, "loading" before,
    /// "2d" for the studio and photo stages) and when listening started. Drawn in clear ink and never touched, so it
    /// stays out of every screenshot while its label stays readable.
    private var stageProbe: some View {
        Text(verbatim: "stage=\(stageState) listening=\(String(format: "%.3f", listeningSince))")
            .font(.system(size: 9, design: .monospaced))
            .foregroundStyle(Color.clear)
            .allowsHitTesting(false)
            .accessibilityIdentifier("stage.state")
    }

    private var stageState: String {
        guard !store.referenceMode, let modelID = store.modelID,
              Self.supports3D, store.settings.stageMode != "studio", failed3D != modelID else { return "2d" }
        return ready3D == modelID ? "3d" : "loading"
    }
    #endif

    /// One string of a pair just locked: once its bell has rung, the tuner moves on to the other string
    /// (same chip, its own peg), in automatic and manual detection alike.
    private func advanceInPair(after index: Int) {
        let store = self.store
        guard store.activeCourse.index == index,
              let group = CourseGrouping.groups(store.courses).first(where: { $0.contains(index) }),
              let partner = group.partner(after: index, locked: store.lockedCourses) else { return }
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(1.2))
            guard store.activeCourse.index == index, !store.referenceMode, !store.lockedCourses.contains(partner.index),
                  store.courses.contains(where: { $0.index == partner.index }) else { return }
            let automatic = store.automatic
            store.chooseCourse(partner.index)
            store.automatic = automatic
        }
    }

    /// A peg tapped on the stage: a course's anchor ("c4") tunes its next unlocked string, one peg of a pair ("c4b") that string.
    private func selectPeg(_ name: String) {
        let courses = store.courses
        guard let course = CourseGrouping.course(forPeg: name, in: courses) else { return }
        if course.anchorId == name, let group = CourseGrouping.groups(courses).first(where: { $0.contains(course.index) }) {
            store.chooseCourse(group.nextToTune(store.lockedCourses).index)
        } else {
            store.chooseCourse(course.index)
        }
    }

    /// Feeds the VoiceOver announcer what the readout shows, while the tuner is the screen in front.
    private func announce() {
        let front = store.selectedTab == .tune && !store.showSettings && !store.showInstrumentPicker && !store.showPaywall
        let reading = store.live.reading
        let heard = front && audio.running && !store.live.preserved && reading.cents != nil
        let shown = heard ? (motion.shown ?? reading.cents.map { Int($0.rounded()) }) : nil
        announcer.step(note: store.targetName, shown: shown, locked: reading.inTune, now: ProcessInfo.processInfo.systemUptime)
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
        // On a paired course the cue rings the one peg being tuned.
        let peg = store.referenceMode ? nil : Optional(CourseGrouping.position(of: store.activeCourse, in: store.courses))
        // The 3D camera (and the 2D studio or photo stage, as far as its picture allows) holds the headstock close-up,
        // with the peg ring and its turn arrow, whenever a string is being tuned, listening or paused alike: the peg
        // to turn is the tuner's hero. It pulls back to the whole instrument only for the all-strings celebration
        // (Reduce Motion cuts rather than glides).
        return StageInput(cents: store.live.reading.cents, level: store.live.level, locked: store.live.reading.inTune,
                          listening: audio.running, activeAnchor: store.activeAnchor, focus: !store.referenceMode && !showWhole,
                          note: store.targetName, pegIndex: peg)
    }

    /// Nothing drives the stage (not listening, no reading held): its animations settle, then stop redrawing.
    private var resting: Bool { !audio.running && !store.live.preserved }

    /// - Parameter controls: the side controls stand on the stage's trailing edge (in the iPad's landscape columns
    ///   they have a rail of their own instead).
    @ViewBuilder private func stage(controls: Bool) -> some View {
        let resting = self.resting
        ZStack(alignment: .top) {
            if store.referenceMode {
                // The note name lives in the readout below; the strobe ring stays clear of the side buttons.
                ChromaticStage(input: stageInput, note: "", resting: resting).padding(.vertical, 20).padding(.horizontal, 64)
            } else if let modelID = store.modelID {
                let rig = ModelLibrary.rig(modelID)
                if Self.supports3D && store.settings.stageMode != "studio" && failed3D != modelID {
                    let rendered = ModelLibrary.hasCard(modelID)
                    let card = rendered ? rig.flatMap(StageCard.init(rig:)) : ModelLibrary.photoCard(store.photo?.asset)
                    ZStack {
                        // The studio render holds the stage while the 3D model loads, then cross-fades out. It
                        // already rings the peg to turn and dollies in to the headstock, so a slow load never leaves
                        // the tuner on a wide shot without its cue; the model then picks the dolly up where it got to.
                        if ready3D != modelID {
                            StudioStage(imageName: rendered ? ModelLibrary.cardImageName(modelID) : (store.photo?.asset ?? ""),
                                        card: card, input: stageInput, onSelect: { selectPeg($0) }, resting: resting)
                                .padding(.horizontal, 16)
                                .transition(.opacity)
                        }
                        InstrumentStage(modelID: modelID, input: stageInput, onSelect: { selectPeg($0) },
                                        onFailure: { failed3D = modelID },
                                        onReady: { withAnimation(.easeInOut(duration: 0.6)) { ready3D = modelID } },
                                        revealClose: card?.head != nil, resting: resting)
                    }
                } else if ModelLibrary.hasCard(modelID) {
                    StudioStage(imageName: ModelLibrary.cardImageName(modelID), card: rig.flatMap(StageCard.init(rig:)), input: stageInput,
                                onSelect: { selectPeg($0) }, resting: resting)
                        .padding(.horizontal, 16)
                } else if let photo = store.photo {
                    StudioStage(imageName: photo.asset, card: ModelLibrary.photoCard(photo.asset), input: stageInput,
                                onSelect: { selectPeg($0) }, resting: resting).padding(28)
                }
            } else if let photo = store.photo {
                StudioStage(imageName: photo.asset, card: ModelLibrary.photoCard(photo.asset), input: stageInput,
                            onSelect: { selectPeg($0) }, resting: resting).padding(28)
            }
        }
        .overlay(alignment: .trailing) {
            if controls { sideControls.padding(.trailing, 14) }
        }
        // A container element keeps its children's own identifiers (stage.debug).
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("tune.stage")
    }

    /// The readout, quest line and string rail, placed for the arrangement: under the stage, beside it in a
    /// column (a phone on its side), or as the iPad's middle column, centred between the instrument and the controls.
    @ViewBuilder private func panel(_ arrangement: TuneArrangement, width: CGFloat) -> some View {
        switch arrangement {
        case .stacked:
            tuningPanel.frame(maxWidth: 680)
        case .beside:
            VStack(spacing: 0) {
                Spacer(minLength: 0)
                tuningPanel
                Spacer(minLength: 0)
            }
            .frame(width: min(560, width * 0.44))
        case .columns:
            VStack(spacing: 0) {
                Spacer(minLength: 0)
                tuningPanel.frame(maxWidth: 560)
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity)
        }
    }

    /// The iPad's landscape columns: the side controls as a rail of their own on the trailing edge, where a phone
    /// has them, beside the readout rather than floating over the middle of the stage.
    private var controlRail: some View {
        sideControls
            .padding(.leading, 6).padding(.trailing, 18)
            .frame(maxHeight: .infinity)
    }

    private var readout: some View {
        // Every frame while a pitch can move it; at rest (not listening, nothing held) the readout has no pitch and
        // nothing to animate, so it draws once and stops instead of redrawing at the display rate.
        TimelineView(.animation(minimumInterval: nil, paused: resting)) { timeline in
            let reading = store.live.reading
            let heard = audio.running || store.live.preserved
            let _ = motion.step(heard ? reading.cents : nil, locked: reading.inTune, now: timeline.date.timeIntervalSinceReferenceDate,
                                hertz: reading.frequency, target: store.targetHz)
            let shown = motion.shown
            // Once locked, the readout's "In tune" badge says it; the line below keeps its height but goes quiet.
            let badgeSaysIt = reading.inTune && audio.running && !store.live.preserved
            VStack(spacing: 14) {
                NoteReadout(note: store.targetName, shown: shown, hertz: motion.shownHertz, target: store.targetHz, locked: reading.inTune)
                meter(locked: reading.inTune, shown: shown)
                // The same steady whole cents and colour rule as the digits above, changing in place
                // (no rolling digits), so the two never disagree.
                Text(statusLine(reading, shown: shown)).font(.footnote.weight(.semibold))
                    .foregroundStyle(statusColor(reading, shown: shown))
                    .monospacedDigit()
                    // The words swap in one frame; only the fade is animated, so two lines never blend into one.
                    .contentTransition(.identity)
                    .opacity(badgeSaysIt ? 0 : 1)
                    .animation(Motion.quick, value: badgeSaysIt)
                    .accessibilityHidden(badgeSaysIt)
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
    /// "Hold it…" inside the band, "Tighten"/"Loosen" outside it, "In tune" once the tracker locks
    /// (then the readout's badge says it, and this line stays blank, holding its height).
    private func statusLine(_ reading: TuningReading, shown: Int?) -> String {
        guard audio.running, !store.live.preserved, reading.cents != nil, let shown else { return store.statusText }
        if reading.inTune { return String(localized: "In tune") }
        let amount = abs(shown)
        if Double(amount) <= Palette.tuningBand { return String(localized: "Hold it…") }
        return shown < 0 ? String(localized: "Tighten · \(amount)¢ flat") : String(localized: "Loosen · \(amount)¢ sharp")
    }

    private func statusColor(_ reading: TuningReading, shown: Int?) -> Color {
        guard audio.running, !store.live.preserved, reading.cents != nil, let shown else { return contrast == .increased ? Palette.ink : Palette.inkSoft }
        return Palette.tuning(Double(shown), locked: reading.inTune)
    }

    private var tuningPanel: some View {
        VStack(spacing: 6) {
            readout
            // In Chromatic: a free player's Pro instrument from onboarding, its strings and its stage in Pro.
            if !store.referenceMode { questLine } else { ChromaticStandInHint() }
            StringRail(motion: motion).opacity(store.referenceMode ? 0 : 1).frame(height: store.referenceMode ? 8 : nil)
        }
        .padding(.bottom, 8)
    }

    /// Today's tuning quest: every string of this instrument, with its XP.
    private var questLine: some View {
        let quest = store.quests.first { $0.kind == .tuneAll }
        let counter = quest.map { store.questCounter($0) }
        let done = counter?.done ?? min(store.lockedCourses.count, store.courses.count), total = counter?.total ?? store.courses.count
        return HStack(alignment: .firstTextBaseline, spacing: 6) {
            Text("Daily quest · every string").foregroundStyle(contrast == .increased ? Palette.ink : Palette.inkSoft)
                .font(.caption).lineLimit(1).minimumScaleFactor(0.8)
            // Strings, not chips: a mandolin's four ×2 chips count as 8.
            Text(verbatim: "\(done) / \(total)").font(.caption.weight(.bold)).foregroundStyle(Palette.ink).monospacedDigit()
                .fixedSize()
                .accessibilityLabel(Text("\(done) of \(total)"))
            Spacer(minLength: 8)
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
            StrumToggle { strumOpen = true }.strumTuneTip()  // TipKit coach mark, Tips/TimbreTips.swift
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

/// How the tuner places its stage, readout and controls for the window it has, chosen by shape and size class
/// (never by device), so a phone, an iPad, Split View and Stage Manager windows each get the one that fits.
enum TuneArrangement: Equatable {
    /// Portrait: the stage over the readout and string rail, the controls on the stage's trailing edge.
    case stacked
    /// A short wide window (a phone on its side): the stage beside the readout, the controls on the stage.
    case beside
    /// A wide window at regular width and height (iPad landscape): the instrument, then the readout and string
    /// rail in the middle column, then a rail of controls on the trailing edge.
    case columns

    init(size: CGSize, regular: Bool) {
        guard size.width > size.height * 1.15 else { self = .stacked; return }
        self = regular && size.width >= 900 ? .columns : .beside
    }

    /// The same container in every arrangement, so the children (the stage first) keep their identity.
    var layout: AnyLayout {
        switch self {
        case .stacked: return AnyLayout(VStackLayout(spacing: 0))
        case .beside: return AnyLayout(HStackLayout(spacing: 20))
        case .columns: return AnyLayout(HStackLayout(spacing: 0))
        }
    }

    /// The instrument's column: enough for the headstock close-up with its peg label either side, the rest of the
    /// width going to the readout.
    static func stageWidth(in width: CGFloat) -> CGFloat { min(640, max(420, width * 0.42)) }
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
