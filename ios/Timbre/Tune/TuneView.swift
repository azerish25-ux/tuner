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
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.locale) private var locale
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
                let arrangement = TuneArrangement(size: proxy.size, regular: regularWindow)
                let pane = TuneArrangement.showsPane(arrangement, size: proxy.size, regularWidth: horizontalSizeClass == .regular,
                                                     largeType: dynamicTypeSize.isAccessibilitySize)
                let scale = TuneArrangement.readout(arrangement, size: proxy.size, regular: regularWindow, pane: pane,
                                                    largeType: dynamicTypeSize.isAccessibilitySize)
                VStack(spacing: 0) {
                    header
                    // One layout that changes shape rather than two branches: the stage keeps its identity when the
                    // window turns or resizes, so the 3D instrument carries on instead of being rebuilt, losing its
                    // loaded model and showing the studio stand-in (or nothing) while it loads again.
                    arrangement.layout {
                        stage(controls: arrangement != .columns)
                            // The iPad's landscape columns: the instrument keeps a gutter off the screen's leading edge, so
                            // the whole-headstock close-up never presses its buttons against it.
                            .padding(.leading, arrangement == .columns ? TuneArrangement.stageLead : 0)
                            .frame(width: arrangement == .columns ? TuneArrangement.stageWidth(in: proxy.size.width, pane: pane) : nil)
                            .frame(maxWidth: arrangement == .beside ? CGFloat.infinity : nil, maxHeight: .infinity)
                        panel(arrangement, width: proxy.size.width, scale: scale)
                        if pane { sidePane(arrangement, width: proxy.size.width, scale: scale) }
                        if arrangement == .columns { controlRail }
                    }
                }
                .frame(width: proxy.size.width, height: proxy.size.height)
            }
            CelebrationOverlay()
        }
        .onAppear {
            // The tuner's feel, every reading: the detents and lock, or with Tune by feel the beat (Design/Haptics.swift).
            store.onTunerFrame = { frame in Haptics.shared.feel(frame) }
            autoListen()
        }
        .onChange(of: store.settings.tuneByFeel, initial: true) { _, on in Haptics.shared.byFeel = on }
        .onChange(of: scenePhase) { _, phase in if phase == .active && store.selectedTab == .tune { autoListen() } }
        .onChange(of: store.requestReviewNow) { _, now in
            if now { requestReview(); store.requestReviewNow = false }
        }
        .task(id: "\(store.tuning.id) \(store.settings.referencePitchHz) \(store.settings.temperamentId)") {
            let strings = store.courses.map { store.target(for: $0) }
            SoundFX.shared.prepareLocks(strings)
            SoundFX.shared.prepareTuned(strings)
        }
        .onChange(of: store.lockedCourses) { old, new in
            // A string just locked: a soft bell at its own pitch (an octave up when it's low).
            guard let index = new.subtracting(old).first, let course = store.courses.first(where: { $0.index == index }) else { return }
            // The last string: the instrument's own open strings, rolled with their bells and strummed, instead of
            // one more bell. Automatic detection stays put while they ring.
            if store.allCoursesLocked {
                let strings = store.courses.map { store.target(for: $0) }
                store.autoQuietUntil = ProcessInfo.processInfo.systemUptime + SoundSynth.tunedBloom(count: strings.count) + 2
                SoundFX.shared.playTuned(frequencies: strings)
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
        // The instrument browser: a sheet on a phone, a full page of its own on iPad (Instruments/InstrumentsView.swift).
        .instrumentPicker(isPresented: $store.showInstrumentPicker)
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
        let note = store.targetName
        announcer.step(note: note, spoken: NoteNames.spoken(note, locale: locale, system: store.settings.notation), shown: shown,
                       locked: reading.inTune, now: ProcessInfo.processInfo.systemUptime)
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
            // The cluster every tab shares (streak and level, both to Progress), then the tuner's own settings:
            // 44 pt targets throughout. The simple tuner keeps only the settings.
            HStack(spacing: 2) {
                if !store.settings.simpleTuner { HeaderControls() }
                IconButton(symbol: "slider.horizontal.3", size: .compact, label: "Settings") { store.showSettings = true }
                    .accessibilityIdentifier("settings.open")
            }
        }
        .padding(.horizontal, Metrics.gutter).padding(.top, 6)
    }

    /// A window of iPad size (regular width and height; never a phone): the larger readout.
    private var regularWindow: Bool { horizontalSizeClass == .regular && verticalSizeClass == .regular }

    /// The iPad, in any window (Split View and Slide Over too): the close-up frames the whole headstock, centred, so no
    /// button or tip is ever cut by the stage's edge. A phone keeps its tighter close-up, leaning toward the peg.
    private var wholeHeadstock: Bool { UIDevice.current.userInterfaceIdiom == .pad }

    /// - Parameter controls: Strum and listening stand on the stage's trailing edge (the whole-headstock close-up keeps
    ///   clear of them).
    private func stageInput(controls: Bool) -> StageInput {
        // On a paired course the cue rings the one peg being tuned.
        let peg = store.referenceMode ? nil : Optional(CourseGrouping.position(of: store.activeCourse, in: store.courses))
        // The 3D camera (and the 2D studio or photo stage, as far as its picture allows) holds the headstock close-up,
        // with the peg ring and its turn arrow, whenever a string is being tuned, listening or paused alike: the peg
        // to turn is the tuner's hero. It pulls back to the whole instrument only for the all-strings celebration
        // (Reduce Motion cuts rather than glides). On an iPad the close-up shows the whole headstock, centred
        // across the stage.
        return StageInput(cents: store.live.reading.cents, level: store.live.level, locked: store.live.reading.inTune,
                          listening: audio.running, activeAnchor: store.activeAnchor, focus: !store.referenceMode && !showWhole,
                          note: store.targetName, pegIndex: peg, wholeHeadstock: wholeHeadstock,
                          controlsReserve: controls ? Self.controlsReserve : 0)
    }

    /// The width the side controls take on the stage's trailing edge: the 52 pt orb, the gutter and a gap.
    static let controlsReserve: CGFloat = 76

    /// Nothing drives the stage (not listening, no reading held): its animations settle, then stop redrawing.
    private var resting: Bool { !audio.running && !store.live.preserved }

    /// - Parameter controls: Strum and listening stand on the stage's trailing edge (in the iPad's landscape columns
    ///   they have a rail of their own instead). The bar under the stage stands on it in every arrangement.
    @ViewBuilder private func stage(controls: Bool) -> some View {
        let resting = self.resting
        let input: () -> StageInput = { self.stageInput(controls: controls) }
        ZStack(alignment: .top) {
            if store.referenceMode {
                // The note name lives in the readout below; the strobe dial stays clear of the side controls (their whole
                // reserve, the orb's breathing halo included, either side so the dial stays centred over the readout).
                // A tap on its note wheel holds that note (Manual).
                let settings = store.settings
                ChromaticStage(input: input, midi: store.activeMidi + settings.transposition - settings.capo,
                               notation: settings.notation, resting: resting,
                               onPick: { store.chooseReferenceNote($0 - settings.transposition + settings.capo) })
                    .padding(.top, 8).padding(.bottom, 4).padding(.horizontal, controls ? Self.controlsReserve : 20)
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
                                        card: card, input: input, onSelect: { selectPeg($0) }, resting: resting)
                                .padding(.horizontal, 16)
                                .transition(.opacity)
                        }
                        InstrumentStage(modelID: modelID, input: input, onSelect: { selectPeg($0) },
                                        onFailure: { failed3D = modelID },
                                        onReady: { withAnimation(Motion.reveal) { ready3D = modelID } },
                                        revealClose: card?.head != nil, resting: resting)
                    }
                } else if ModelLibrary.hasCard(modelID) {
                    StudioStage(imageName: ModelLibrary.cardImageName(modelID), card: rig.flatMap(StageCard.init(rig:)), input: input,
                                onSelect: { selectPeg($0) }, resting: resting)
                        .padding(.horizontal, 16)
                } else if let photo = store.photo {
                    StudioStage(imageName: photo.asset, card: ModelLibrary.photoCard(photo.asset), input: input,
                                onSelect: { selectPeg($0) }, resting: resting).padding(28)
                }
            } else if let photo = store.photo {
                StudioStage(imageName: photo.asset, card: ModelLibrary.photoCard(photo.asset), input: input,
                            onSelect: { selectPeg($0) }, resting: resting).padding(28)
            }
        }
        // Pictures of instruments stay as they are under Smart Invert.
        .accessibilityIgnoresInvertColors()
        // The bar under the stage has a strip of its own, so it never covers the nut and strings the lock runs down.
        .padding(.bottom, Self.stageBarClearance)
        .overlay { stageControls(rail: controls) }
        // A container element keeps its children's own identifiers (stage.debug).
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("tune.stage")
    }

    /// The readout, quest line and string rail, placed for the arrangement: under the stage, beside it in a
    /// column (a phone on its side), or as the iPad's middle column, centred between the instrument and the controls.
    /// The readout's size and width come from `TuneArrangement.readout`: the phone's everywhere but an iPad-sized
    /// window, where the note and meter grow to fill the column.
    @ViewBuilder private func panel(_ arrangement: TuneArrangement, width: CGFloat, scale: ReadoutScale) -> some View {
        switch arrangement {
        case .stacked:
            tuningPanel(scale).frame(maxWidth: scale.width)
        case .beside:
            VStack(spacing: 0) {
                Spacer(minLength: 0)
                tuningPanel(scale)
                Spacer(minLength: 0)
            }
            .frame(width: min(560, width * 0.44))
        case .columns:
            VStack(spacing: 0) {
                Spacer(minLength: 0)
                tuningPanel(scale).frame(maxWidth: scale.width)
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity)
        }
    }

    /// iPad (`TuneArrangement.showsPane`): the pitch over the last ten seconds and String health (TuneSidePane.swift).
    /// In landscape a column of its own between the readout and the control rail, so the readout stays centred in
    /// its column with the right of the screen put to use; in portrait a row under the string rail, which takes
    /// the height the headstock had spare and lifts the readout to the middle of the screen.
    private func sidePane(_ arrangement: TuneArrangement, width: CGFloat, scale: ReadoutScale) -> some View {
        let column = arrangement == .columns
        return TuneSidePane(column: column)
            .frame(width: column ? TuneArrangement.paneWidth(in: width) : nil)
            // In portrait as wide as the readout above it.
            .frame(maxWidth: column ? nil : scale.width)
            .padding(.leading, column ? 4 : Metrics.gutter)
            .padding(.trailing, column ? 0 : Metrics.gutter)
            .padding(.bottom, column ? 0 : 14)
    }

    /// The iPad's landscape columns: the side controls as a rail of their own on the trailing edge, where a phone
    /// has them, beside the readout rather than floating over the middle of the stage. A clear gutter on each side
    /// (wider than the listening orb's breathing halo) keeps them off the side pane's cards.
    private var controlRail: some View {
        sideControls
            .padding(.horizontal, TuneArrangement.railGap)
            .frame(maxHeight: .infinity)
    }

    private func readout(_ scale: ReadoutScale) -> some View {
        // Whether the stage's peg asks for the string, read once per update rather than every frame.
        let calls = stageCallsString
        // Every frame while a pitch can move it; at rest (not listening, nothing held) the readout has no pitch and
        // nothing to animate, so it draws once and stops instead of redrawing at the display rate.
        return TimelineView(.animation(minimumInterval: nil, paused: resting)) { timeline in
            let reading = store.live.reading
            let heard = audio.running || store.live.preserved
            let now = timeline.date.timeIntervalSinceReferenceDate
            let _ = motion.step(heard ? reading.cents : nil, locked: reading.inTune, now: now,
                                hertz: reading.frequency, target: store.targetHz)
            let shown = motion.shown
            // The one "in tune" flag: the readout's badge shows from it and the line below goes quiet from it, so
            // exactly one "In tune" is ever on screen (a paused reading's line still says it is paused).
            let locked = reading.inTune
            let badgeSaysIt = locked && !store.live.preserved
            // A gap of a few frames in the pitch holds the numbers rather than blinking to the target.
            let printed = heard ? motion.printed(target: store.targetHz, now: now) : nil
            // The stage's peg label has the call to play ("Play G3") while nothing is heard: said once, there.
            let quiet = badgeSaysIt || (calls && waitingForString(reading))
            VStack(spacing: scale.large ? 18 : 14) {
                NoteReadout(note: store.targetName, shown: printed?.shown, hertz: printed?.hertz, target: store.targetHz,
                            locked: locked, size: scale.note)
                meter(locked: locked, shown: shown, scale: scale)
                statusText(statusLine(reading, shown: shown), color: statusColor(reading, shown: shown), quiet: quiet,
                           hidden: badgeSaysIt, large: scale.large)
            }
        }
        .padding(.bottom, 4)
    }

    /// The line under the meter: the same steady whole cents and colour rule as the digits above, changing in place
    /// (no rolling digits), so the two never disagree. `quiet` when another surface says it (the readout's In tune
    /// badge, the peg's "Play G3"): the line then shows nothing and keeps its height, and VoiceOver still hears the
    /// call to play (the stage is hidden from it). `hidden` while the badge's value carries "In tune" for VoiceOver.
    private func statusText(_ words: String, color: Color, quiet: Bool, hidden: Bool, large: Bool) -> some View {
        let font: Font = large ? Font.callout.weight(.semibold) : Font.footnote.weight(.semibold)
        return Text(verbatim: quiet ? " " : words).font(font)
            .foregroundStyle(color)
            .monospacedDigit()
            // The words swap in one frame; only the fade is animated, so two lines never blend into one.
            .contentTransition(.identity)
            .opacity(quiet ? 0 : 1)
            .animation(Motion.quick, value: quiet)
            .accessibilityLabel(Text(verbatim: words))
            .accessibilityHidden(hidden)
            .accessibilityIdentifier("tune.status")
    }

    /// Listening with nothing heard: the moment the status would ask for the string ("Play G3", `AppStore.statusText`).
    private func waitingForString(_ reading: TuningReading) -> Bool {
        audio.running && !store.live.preserved && reading.cents == nil && reading.status == "noSignal"
    }

    /// Whether the stage carries the call to play the string ("Play G3" beside its ringed peg) while nothing is heard,
    /// so the status line can leave the words to it: the 3D headstock once its model is on stage and framed close
    /// (its rig has the string), or a studio render or photograph with that string's peg on it (the 3D model's
    /// stand-in while it loads included). Chromatic, the whole-instrument shot and pictures without the peg keep
    /// the words in the status line.
    private var stageCallsString: Bool {
        guard !store.referenceMode, let anchor = store.activeAnchor else { return false }
        let photo = store.photo?.asset
        guard let modelID = store.modelID else { return ModelLibrary.photoCard(photo)?.point("\(anchor).peg") != nil }
        let rig = ModelLibrary.rig(modelID)
        if Self.supports3D && store.settings.stageMode != "studio" && failed3D != modelID && ready3D == modelID {
            return !showWhole && rig?.string(anchor) != nil
        }
        let card = ModelLibrary.hasCard(modelID) ? rig.flatMap(StageCard.init(rig:)) : ModelLibrary.photoCard(photo)
        return card?.point("\(anchor).peg") != nil
    }

    /// The needle meter, or with Strobe precision on, a strobe band that drifts with the error and stands still in tune.
    /// In an iPad's column the meter spans the readout (`ReadoutScale.meterInset`) and stands a little taller. Chromatic
    /// shows none: its strobe dial on the stage is the meter, and a second one under the note would say it twice.
    @ViewBuilder private func meter(locked: Bool, shown: Int?, scale: ReadoutScale) -> some View {
        if store.referenceMode {
            EmptyView()
        } else if strobeView {
            StrobeBand(cents: shown.map { Double($0) }, phase: reduceMotion ? 0 : motion.phase, locked: locked, active: motion.cents != nil)
                .frame(height: scale.large ? 32 : 26).padding(.vertical, 6).padding(.horizontal, scale.meterInset)
        } else {
            RibbonMeter(cents: motion.cents, shown: shown, phase: motion.phase, locked: locked)
                .frame(height: scale.meterHeight).padding(.horizontal, scale.meterInset)
        }
    }

    /// The status under the meter reads the readout's own whole cents against the tracker's lock band:
    /// "Hold it…" inside the band, "Tighten"/"Loosen" outside it, "In tune" once the tracker locks
    /// (then the readout's badge says it, and `statusText` leaves the line blank, holding its height). The cents
    /// are the readout's, just above ("−10¢ · 81.92 Hz"), so the line names only the turn.
    private func statusLine(_ reading: TuningReading, shown: Int?) -> String {
        guard audio.running, !store.live.preserved, reading.cents != nil, let shown else { return store.statusText }
        if reading.inTune { return String(localized: "In tune") }
        let amount = abs(shown)
        if Double(amount) <= Palette.tuningBand { return String(localized: "Hold it…") }
        return shown < 0 ? String(localized: "Tighten") : String(localized: "Loosen")
    }

    private func statusColor(_ reading: TuningReading, shown: Int?) -> Color {
        guard audio.running, !store.live.preserved, reading.cents != nil, let shown else { return contrast == .increased ? Palette.ink : Palette.inkSoft }
        return Palette.tuning(Double(shown), locked: reading.inTune)
    }

    private func tuningPanel(_ scale: ReadoutScale) -> some View {
        VStack(spacing: 6) {
            readout(scale)
            // In Chromatic: a free player's Pro instrument from onboarding, its strings and its stage in Pro. The simple
            // tuner has no quest line.
            if store.referenceMode { ChromaticStandInHint() } else if !store.settings.simpleTuner { questLine }
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
            // "Quest" is a side goal; "Today" is the three-activity set.
            Text("Quest · tune every string").foregroundStyle(contrast == .increased ? Palette.ink : Palette.inkSoft)
                .font(.caption).lineLimit(1).minimumScaleFactor(0.8)
            // Strings, not chips: a mandolin's four ×2 chips count as 8. Reads "3 of 6".
            Text.fraction(done, total).font(.caption.weight(.bold)).foregroundStyle(Palette.ink).monospacedDigit()
                .fixedSize()
            Spacer(minLength: 8)
            if let quest {
                Text(store.questProgress(quest) >= quest.target ? "Done" : "+\(quest.xp) XP").font(Typeface.label(12)).foregroundStyle(Palette.mint)
            }
        }
        .padding(.horizontal, Metrics.gutter + 2)
        .accessibilityElement(children: .combine)
    }

    /// Strum to tune and listening, stacked beside the instrument (in the iPad's landscape columns, on their own rail),
    /// each captioned the same way. AUTO | MANUAL and the reference tone carry their words on the bar under the stage.
    private var sideControls: some View {
        VStack(spacing: 14) {
            StrumToggle { strumOpen = true }.strumTuneTip()  // TipKit coach mark, Tips/TimbreTips.swift
            ListenOrb(captioned: true)
        }
    }

    /// The strip under the stage that the bar stands in: the bar (44), a gap above it and its margin below.
    static let stageBarClearance: CGFloat = 54

    /// The controls standing on the stage: the bar in its strip under it (AUTO | MANUAL and the reference tone) and,
    /// when `rail`, Strum and listening on the stage's trailing edge, centred in the height above the bar.
    private func stageControls(rail: Bool) -> some View {
        VStack(spacing: 4) {
            if rail {
                // The gutter clear of the orb's frame, which holds its breathing halo: nothing reaches the edge.
                sideControls
                    .padding(.trailing, Metrics.gutter)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .trailing)
            } else {
                Spacer(minLength: 0)
            }
            stageBar.padding(.horizontal, 12).padding(.bottom, 6)
        }
    }

    /// AUTO | MANUAL and the reference tone, on glass under the stage (TunerControls.swift).
    private var stageBar: some View {
        TunerStageBar(automatic: store.automatic, chromatic: store.referenceMode, listening: audio.running,
                      tonePlaying: audio.tonePlaying,
                      setAutomatic: { store.automatic = $0 },
                      toggleTone: { store.toggleTone() })
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
                .stageControlDisc(active: active)
        }
        .buttonStyle(PressScaleStyle())
    }
}

/// The caption under a stage control ("Strum", "Listen"): Sora 10 on the caption2 curve (`Typeface.badge`), mint while
/// the control is on. It grows up to the first accessibility size, then holds so the column of controls keeps its
/// shape over the instrument; past that a long press shows it large (each control offers the Large Content Viewer).
/// The control's own VoiceOver label carries the words.
struct StageCaption: View {
    let text: Text
    var active = false

    var body: some View {
        text.font(Typeface.badge)
            .foregroundStyle(active ? Palette.mint : Palette.inkSoft)
            .lineLimit(1)
            .fixedSize()
            .dynamicTypeSize(...DynamicTypeSize.accessibility1)
            .accessibilityHidden(true)
    }
}

extension View {
    /// The disc behind a 44 pt stage control: a breath of white with a light rim (brighter with Increase Contrast),
    /// washed mint while the control is on.
    func stageControlDisc(active: Bool = false) -> some View {
        modifier(StageControlDisc(active: active))
    }
}

private struct StageControlDisc: ViewModifier {
    let active: Bool
    @Environment(\.colorSchemeContrast) private var contrast

    func body(content: Content) -> some View {
        let strong = contrast == .increased
        let rim: Color = active ? Palette.mint.opacity(strong ? 0.9 : 0.45) : Color.white.opacity(strong ? 0.4 : 0.12)
        return content
            .background(Circle().fill(active ? Palette.mint.opacity(0.12) : Color.white.opacity(0.05)))
            .overlay(Circle().strokeBorder(rim, lineWidth: 1))
    }
}

/// Listening on and off: mint when listening, its halo breathing with the input level inside the orb's own 52 pt
/// frame. On the stage it is captioned like Strum ("Listen", then "Pause" while it listens); in a header it stands
/// alone. A long press shows it large (Large Content Viewer).
struct ListenOrb: View {
    var captioned = false
    @EnvironmentObject private var store: AppStore
    @EnvironmentObject private var audio: AudioService
    var body: some View {
        let level = audio.running ? max(0, min(1, (store.live.level + 60) / 45)) : 0
        Button { store.toggleListening(); Haptics.shared.selection() } label: {
            // The orb's frame leaves room for its halo; the caption tucks under the disc as Strum's does.
            VStack(spacing: -1) {
                orb(level: level)
                if captioned {
                    StageCaption(text: audio.running ? Text("Pause") : Text("Listen"), active: audio.running)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(audio.running ? "Pause listening" : "Listen"))
        .accessibilityShowsLargeContentViewer {
            Label(audio.running ? "Pause listening" : "Listen", systemImage: audio.running ? "pause.fill" : "mic.fill")
        }
        .accessibilityIdentifier("listenButton")
    }

    private func orb(level: Double) -> some View {
        ZStack {
            // The halo breathes from just outside the disc to the edge of the frame, never past it.
            Circle().fill(Palette.mint.opacity(0.2)).frame(width: 46, height: 46).scaleEffect(1 + level * 0.13).opacity(audio.running ? 1 : 0)
            // At rest the stage controls' disc; listening, solid mint over it.
            Color.clear.frame(width: 44, height: 44).stageControlDisc().opacity(audio.running ? 0 : 1)
            Circle().fill(Palette.mint).frame(width: 44, height: 44).opacity(audio.running ? 1 : 0)
            Image(systemName: audio.running ? "pause.fill" : "mic.fill").font(.system(size: 16, weight: .bold))
                .foregroundStyle(audio.running ? Palette.onAccent : Palette.ink)
        }
        .frame(width: 52, height: 52)
        .animation(.easeOut(duration: 0.12), value: level)
        .animation(Motion.pluck, value: audio.running)
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
    /// rail in the middle column, then (from `paneMinWidth`) the side pane, then a rail of controls on the trailing edge.
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
    /// width going to the readout (and, with `pane`, to the side pane; a little narrower then, so the readout's
    /// column still holds a six-string rail without scrolling at 1180 pt).
    static func stageWidth(in width: CGFloat, pane: Bool = false) -> CGFloat {
        pane ? min(600, max(410, width * 0.35)) : min(640, max(420, width * 0.42))
    }

    /// The side pane's column in landscape.
    static func paneWidth(in width: CGFloat) -> CGFloat { min(340, max(270, width * 0.23)) }

    /// Landscape windows narrower than this keep the two columns (the readout would be squeezed).
    static let paneMinWidth: CGFloat = 1150

    /// The gap either side of the landscape control rail (`TuneView.controlRail`): the rail stays a clear column of its
    /// own beside the side pane.
    static let railGap: CGFloat = 18

    /// The landscape control rail: the 52 pt orb and its gaps (`TuneView.controlRail`).
    static let railWidth: CGFloat = 52 + 2 * railGap

    /// The instrument's gutter off the screen's leading edge in the landscape columns (inside `stageWidth`).
    static let stageLead: CGFloat = Metrics.gutter

    /// How large the readout draws for the window. A phone, a compact or short wide window and the accessibility text
    /// sizes keep the phone's readout (Dynamic Type grows its note there). An iPad-sized window grows the note with
    /// its column, to about 190 pt on a 13-inch iPad in either orientation, and lets the meter span the column; in
    /// portrait the readout, rail and side pane stand wider too.
    static func readout(_ arrangement: TuneArrangement, size: CGSize, regular: Bool, pane: Bool, largeType: Bool) -> ReadoutScale {
        guard regular, !largeType else { return .phone }
        switch arrangement {
        case .beside:
            return .phone
        case .stacked:
            // 190 on a 13-inch iPad, about 145 on an 11-inch, 130 on a mini: the stage keeps the larger share.
            let note = min(190, max(112, min(size.width * 0.184, 112 + (size.height - 940) * 0.25)))
            let width = min(size.width - 2 * Metrics.gutter, max(680, size.width * 0.84))
            return ReadoutScale(note: note.rounded(), width: width, meterInset: 8, meterHeight: 44)
        case .columns:
            // The middle column: what the instrument, the side pane and the control rail leave.
            let column = size.width - stageWidth(in: size.width, pane: pane) - (pane ? paneWidth(in: size.width) + 4 : 0) - railWidth
            let note = min(190, max(112, min(column * 0.38, size.height * 0.21)))
            return ReadoutScale(note: note.rounded(), width: 560, meterInset: 8, meterHeight: 44)
        }
    }

    /// Whether the window has room for the side pane (pitch trace and String health): iPad landscape from 11-inch
    /// up, or a regular-width portrait window tall enough that the stage keeps a good share of the height. Never
    /// a phone, a short window or at the accessibility text sizes (the cards would outgrow their column, or grow
    /// into the stage).
    static func showsPane(_ arrangement: TuneArrangement, size: CGSize, regularWidth: Bool, largeType: Bool) -> Bool {
        guard !largeType else { return false }
        switch arrangement {
        case .columns: return size.width >= paneMinWidth
        case .stacked: return regularWidth && size.width >= 700 && size.height >= 940
        case .beside: return false
        }
    }
}

/// How large the tuner's readout draws and how wide it stands (`TuneArrangement.readout`): the phone's sizes, or an
/// iPad's larger note and full-column meter.
struct ReadoutScale: Equatable {
    /// The note name's size before Dynamic Type (`NoteReadout.size`).
    var note: CGFloat = 112
    /// The widest the readout, quest line and string rail stand (and, in portrait, the side pane under them).
    var width: CGFloat = 680
    /// The meter's inset from each side of the readout.
    var meterInset: CGFloat = 32
    /// The needle meter's height.
    var meterHeight: CGFloat = 38

    static let phone = ReadoutScale()

    /// Larger than the phone's: the gaps and the status line step up with the note.
    var large: Bool { note > 112 }
}

/// Warm or cool light behind the stage that follows the pitch.
struct PitchAura: View {
    @EnvironmentObject private var store: AppStore
    var body: some View {
        let reading = store.live.reading
        let color = Palette.tuning(reading.cents, locked: reading.inTune)
        RadialGradient(colors: [color.opacity(reading.cents == nil ? 0 : (reading.inTune ? 0.28 : 0.14)), .clear], center: UnitPoint(x: 0.5, y: 0.42), startRadius: 20, endRadius: 360)
            .ignoresSafeArea()
            .animation(Motion.fade, value: reading.inTune)
    }
}
