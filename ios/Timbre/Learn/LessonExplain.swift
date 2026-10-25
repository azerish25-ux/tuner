import SwiftUI
import TimbreCore

// MARK: - Explain

/// An explanation: the lesson's picture on a card, then the words, with "Hear it" beside Continue in the bar at the
/// bottom. A picture of notes is a demonstration that plays once as the step appears (with Reduce Motion or VoiceOver
/// it waits for "Hear it"): a chord's fingers land in finger order, each string lighting as its note sounds, then the
/// chord rings across them (on the chord chart, or on the player's-view neck where the strings shimmer as they ring:
/// the switch on the card, the app's one picture choice, which also turns every neck and the strum stage); a neck's
/// dots drop in note by note, each string lit as it sounds; a staff or
/// a keyboard lights each note as it sounds; a rhythm's strokes sound as the pick sweeps the strings in time with the
/// beat row.
/// "Hear it" plays it again. The card takes the room the words leave and its picture grows to fill it.
///
/// "Show me", under a chord, notes on the neck or a strum, plays the same demonstration on the course instrument's 3D
/// model in place of the picture (`ShowMeStage`): the fingertips land on the model's own frets, each string shimmering as
/// it sounds, or a pick sweeps the strings in the pattern's rhythm. The switch where the picture's own sits ("3D" and
/// the chart or the player's view by name) brings the picture back. Without a model, with Reduce Motion or in Low
/// Power Mode the picture stays alone.
/// It is the teacher: the first time a chord or a strum pattern appears in the course, the model takes the card by
/// itself once it has settled and the demonstration plays there instead of on the picture (`ShowMe.firstTime`). Under
/// the button a line says what to watch (`ShowMeCaption`); after a chord's demonstration it hands over to "Your turn".
struct ExplainStep: View {
    let title: LearnText
    let text: LearnText
    let visual: LessonVisual
    let course: LearnCourse
    let accent: Color
    let done: (Double?) -> Void
    /// The card and the words rise in as the step appears. Off for a lesson's first screen, which arrives inside the
    /// zoom out of the tapped card: a reveal started under that zoom could be cut off part-way and leave the step
    /// at about 30 % opacity (bug 64), so there the step is simply there and the zoom is its entrance.
    var entrance = true
    @EnvironmentObject private var store: AppStore
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityVoiceOverEnabled) private var voiceOver
    @Environment(\.scenePhase) private var scenePhase
    @State private var shown = false
    @State private var sounding = false
    /// Height of the title and text, to know how much room is left under them.
    @State private var wordsHeight: CGFloat = 0
    /// Chord cards are a demonstration: the fingers land in order while each note sounds, the chord rings,
    /// then it's the learner's turn to play it back (heard by the microphone when it's already allowed).
    @State private var demo = Demo.idle
    @State private var demoReplay = 0
    @State private var demoTask: Task<Void, Never>?
    /// The chord's strings lit in the demonstration (lowest string first): each finger's as its note sounds, then
    /// every string as the chord rings across them.
    @State private var lit: Set<Int> = []
    /// When the demonstration's first finger lands: the player's view presses its fingertips on this clock, so each
    /// meets its note (the chart keeps its own, started the same way).
    @State private var chordLandStart: Date?
    /// The chord chart (the default) or the player's view: the switch on the card, the app's one picture choice.
    @AppStorage(ChordPicture.storageKey) private var chordView: ChordPicture = .chart
    /// When the neck's first dot lands (nil: still, every dot in place).
    @State private var neckStart: Date?
    /// The staff or keyboard note sounding now, while the notes play one by one.
    @State private var playingIndex: Int?
    /// Beat 1 of the rhythm loop: the demonstration's strokes sound on its clock, so they meet the pick.
    @State private var rhythmOrigin = Date()
    @State private var owner = UUID()
    @State private var matchedFrames = 0
    @State private var burst = 0
    /// "Show me": the demonstration plays on the instrument's 3D model in place of the picture.
    @State private var showMe = false
    /// The model is in place (the picture gives way to it then).
    @State private var showMeReady = false
    /// The model couldn't be shown: the picture stays, and "Show me" goes.
    @State private var showMeFailed = false
    /// The first-time demonstration is on its way to the model (it plays there, not on the picture); `firstTask`
    /// brings the model in once the card has settled, or gives up on it.
    @State private var firstShowing = false
    @State private var firstTask: Task<Void, Never>?

    enum Demo { case idle, showing, yourTurn, heard }
    /// Seconds between fingers in the chord demonstration (the diagram's landing step and the notes' spacing).
    private static let demoStep = 0.45
    /// Seconds between the neck's dots, and between a staff's or a keyboard's notes: an easy melody pace.
    private static let noteStep = 0.42
    /// A diagram card grows into the room under the words up to this height (taller screens keep the rest).
    private static let diagramCardLimit: CGFloat = 600
    /// The rhythm loop's tempo, its strokes and their sound.
    private static let rhythmBPM = 76.0

    /// The demonstration plays by itself as the step appears; with Reduce Motion or VoiceOver it waits for "Hear it".
    private var autoPlays: Bool { !reduceMotion && !voiceOver }

    /// The card and the words are in place: once revealed, or from the start without an entrance.
    private var revealed: Bool { shown || !entrance }

    var body: some View {
        VStack(spacing: 0) {
            GeometryReader { proxy in
                let base = Self.heroHeight(proxy.size.height)
                let spare = spareRoom(proxy.size.height, hero: base)
                let cardHeight = heroHeight(base: base, spare: spare)
                // Inside the card: the gutters and the card's padding (18 a side) aside.
                let inner = CGSize(width: max(0, proxy.size.width - 2 * Metrics.gutter - 36), height: max(0, cardHeight - 36))
                ScrollView {
                    VStack(alignment: .leading, spacing: 22) {
                        hero(height: cardHeight, inner: inner)
                            .scaleEffect(revealed ? 1 : 0.94).opacity(revealed ? 1 : 0)
                        words
                            .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { wordsHeight = $0 }
                            .offset(y: revealed ? 0 : 18).opacity(revealed ? 1 : 0)
                        if base + spare - cardHeight >= 150 {
                            // Only on very tall screens, past the card's limit: the course's instrument or motif.
                            LessonBackdrop(course: course, accent: accent)
                                .frame(height: base + spare - cardHeight - 22)
                                .opacity(revealed ? 0.85 : 0)
                        }
                    }
                    .padding(.horizontal, Metrics.gutter).padding(.top, 18).padding(.bottom, 12)
                }
                .scrollBounceBehavior(.basedOnSize)
            }
            actionBar
        }
        .onAppear {
            if entrance {
                withAnimation(Motion.adaptive(Motion.page, reduceMotion: reduceMotion).delay(0.05)) { shown = true }
            } else {
                shown = true
            }
            let first = playsFirstOnModel
            if first {
                showFirstOnModel()
            } else if autoPlays {
                play(replay: false)
            }
            // The step's 3D model loads quietly once the card has settled, so "Show me" is immediate (once per lesson);
            // at once when it is coming by itself.
            if let model = showMeModel { ModelCache.shared.prefetch(model, after: first ? 0.2 : 1.2) }
        }
        .onDisappear { demoTask?.cancel(); firstTask?.cancel(); store.stopLessonListening(owner: owner) }
        // The picture choice changing elsewhere (Settings) brings the picture back.
        .onChange(of: chordView) { _, _ in setShowMe(false) }
        // Leaving the app stops the demonstration where it is; "Hear it" plays it again.
        .onChange(of: scenePhase) { _, phase in
            guard phase == .background, sounding else { return }
            demoTask?.cancel()
            sounding = false
            lit = []
            playingIndex = nil
            neckStart = nil
            if demo == .showing { demo = .idle }
        }
    }

    /// Every explanation gets the same generous picture area, so short steps don't leave the lower half bare.
    private static func heroHeight(_ available: CGFloat) -> CGFloat { min(360, max(220, available * 0.46)) }

    /// What the hero and the words leave empty above the bar (paddings 18 + 12, spacing 22).
    private func spareRoom(_ available: CGFloat, hero: CGFloat) -> CGFloat {
        guard wordsHeight > 0 else { return 0 }
        return max(0, available - hero - wordsHeight - 22 - 30)
    }

    /// The picture takes the room the words leave: all of it for the backdrop, a strum and the instrument
    /// photo; diagrams (neck, chord, staff, keyboard) up to a card's limit.
    private func heroHeight(base: CGFloat, spare: CGFloat) -> CGFloat {
        switch visual {
        case .none, .rhythm, .instrument: return base + spare
        default: return max(base, min(base + spare, Self.diagramCardLimit))
        }
    }

    /// The stroke drawn over a rhythm: a pick on strummed instruments, a plucking finger on the others, a tap pad without one.
    private var sweepStyle: StrumSweep.Style {
        guard course.fretKind != nil else { return .tap }
        return course.strums ? .strum : .pluck
    }

    private var words: some View {
        VStack(alignment: .leading, spacing: 10) {
            StepTitle(Text(title.localized))
            Text(text.localized).font(.title3).foregroundStyle(Palette.inkSoft).lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: The bar

    /// "Hear it" (when the picture sounds) beside Continue, pinned to the bottom.
    private var actionBar: some View {
        LessonActionBar {
            if hearable {
                HearItButton(accent: accent, sounding: sounding) {
                    // Asked for before the model came in: the picture plays it, and the model waits for "Show me".
                    if firstShowing && !showMe { cancelFirst() }
                    play(replay: true)
                }
            }
            StepButton(title: "Continue", accent: accent, inset: false) { Haptics.shared.selection(); leave(); done(nil) }
        }
    }

    /// Continue: the demonstration stops now, not when the step's slide-out ends (`onDisappear`). The next step
    /// opens the microphone as it slides in; a note the demonstration sounded meanwhile would close it again
    /// (`playTones` pauses capture), and a chord's "your turn" would take it over, leaving that step deaf.
    private func leave() {
        demoTask?.cancel()
        demoTask = nil
        firstTask?.cancel()
        store.stopLessonListening(owner: owner)
    }

    /// The picture has something to play.
    private var hearable: Bool {
        switch visual {
        case .chord, .staff, .keyboard, .rhythm: return true
        case .fretboard: return neckMidis.contains { $0 != nil }
        default: return false
        }
    }

    /// Plays the demonstration: once by itself as the step appears, again from "Hear it" (`replay`). `lead` holds the
    /// first note back (the 3D stage's glide in); a strum then starts its loop afresh.
    private func play(replay: Bool, lead: Double? = nil) {
        switch visual {
        case let .chord(spec): runDemo(spec, replay: replay, lead: lead)
        case .fretboard: playNeck(replay: replay, lead: lead)
        case let .staff(midi, _): playNotes(midi, lead: replay ? 0 : 0.45)
        case let .keyboard(midi): playNotes(midi.sorted(), lead: replay ? 0 : 0.45)
        case let .rhythm(pattern, beatsPerBar): playRhythm(pattern, beatsPerBar: beatsPerBar, replay: replay && lead == nil)
        default: break
        }
    }

    // MARK: The card

    /// The lesson's picture on a card, or (without one) the course instrument or motif on the stage.
    @ViewBuilder private func hero(height: CGFloat, inner: CGSize) -> some View {
        if visual == .none {
            LessonBackdrop(course: course, accent: accent).frame(height: height)
        } else {
            VStack(spacing: 10) {
                picture(CGSize(width: inner.width, height: max(0, inner.height - turnRow)))
                footer
            }
            .frame(maxWidth: .infinity, minHeight: max(0, height - 36))
            .padding(18)
            .background(card)
            .overlay(RoundedRectangle(cornerRadius: Metrics.cornerHero, style: .continuous).strokeBorder(Palette.hairline, lineWidth: 1))
        }
    }

    /// The rows under the picture, with their gaps: "Show me" over its line (what to watch, then a chord's "your
    /// turn"), or a chord's "your turn" alone.
    private var turnRow: CGFloat {
        if showMeModel != nil { return Metrics.minTarget + 6 + Self.teacherLine + 10 }
        if case .chord = visual { return 30 }
        return 0
    }

    /// The height of the line under "Show me".
    private static let teacherLine: CGFloat = 20

    /// The picture, as big as `room` (inside the card) allows.
    @ViewBuilder private func picture(_ room: CGSize) -> some View {
        switch visual {
        case let .rhythm(pattern, beatsPerBar):
            // The stroke sweeps above the pattern in time with its playhead, filling the card (on the 3D model, shown).
            ZStack {
                if !threeD {
                    RhythmLoop(pattern: pattern, beatsPerBar: beatsPerBar, accent: accent, arrows: course.strums, bpm: Self.rhythmBPM,
                               sweep: sweepStyle, strings: max(1, course.stringCount), edges: StringEdges.of(course), origin: rhythmOrigin)
                        .transition(.opacity)
                }
                if showMe, let model = showMeModel {
                    ShowMeRhythm(modelID: model, strings: max(1, course.stringCount),
                                 strum: ShowMeStrum(pattern: pattern, beatsPerBar: beatsPerBar, bpm: Self.rhythmBPM, origin: rhythmOrigin),
                                 accent: accent, arrows: course.strums, edges: StringEdges.of(course),
                                 onReady: { showMeAppeared() }, onFailure: { showMeUnavailable() })
                }
            }
            .frame(height: max(180, room.height))
        case let .chord(spec):
            chordBox(spec, room: room)
        case let .fretboard(strings, dots, frets, start):
            neck(strings: strings, dots: dots, frets: frets, start: start, room: room)
        case let .staff(midi, clef):
            staffPicture(midi, clef: clef, room: room)
        case let .keyboard(midi):
            keysPicture(midi.sorted(), room: room)
        case let .instrument(part):
            InstrumentPartView(part: part, instrumentId: course.instrument, accent: accent, height: max(260, room.height))
        default:
            LessonVisualView(visual: visual, accent: accent, instrumentId: course.instrument)
        }
    }

    private var card: some View {
        let shape = RoundedRectangle(cornerRadius: Metrics.cornerHero, style: .continuous)
        return shape.fill(Palette.stageRaised)
            .overlay(RadialGradient(colors: [accent.opacity(0.12), .clear], center: .top, startRadius: 4, endRadius: 260).clipShape(shape))
    }

    /// One note in the course instrument's voice.
    private func sound(_ midi: Int, ms: Int = 380) {
        store.audio.playTones([PitchMath.frequency(midi: Double(midi), reference: store.settings.referencePitchHz)],
                              together: false, noteMs: ms, gapMs: 0)
    }

    // MARK: Show me: the demonstration on the instrument, in 3D

    /// The course instrument's 3D model when this picture can be demonstrated on it (a chord or notes on its neck, a
    /// strum on a strummed instrument) and the stage may run now (not with Reduce Motion, in Low Power Mode or hot).
    private var showMeModel: String? {
        guard !showMeFailed, demonstrable else { return nil }
        return ShowMe.model(for: course, catalog: store.catalog, reduceMotion: reduceMotion)
    }

    private var demonstrable: Bool {
        switch visual {
        case let .chord(spec): return spec.frets.count == course.stringCount
        case let .fretboard(strings, dots, _, _): return strings == course.stringCount && !dots.isEmpty
        case .rhythm: return sweepStyle == .strum
        default: return false
        }
    }

    /// The model has taken the picture's place (the picture comes back should the stage stop being allowed meanwhile,
    /// in Low Power Mode say).
    private var threeD: Bool { showMe && showMeReady && showMeModel != nil }

    private var showMeBinding: Binding<Bool> {
        Binding(get: { showMe }, set: { on in setShowMe(on) })
    }

    /// Under the picture: "Show me" (under notes or a strum in 3D, the switch back to the picture beside it; a chord's
    /// sits in its header), and under it the teacher's line: what to watch, then after a chord's demonstration the
    /// learner's cue to play it back in the same place.
    @ViewBuilder private var footer: some View {
        if showMeModel != nil {
            VStack(spacing: 6) {
                showMeControls
                teacherLine
            }
            .frame(maxWidth: .infinity)
            .animation(Motion.adaptive(Motion.settle, reduceMotion: reduceMotion), value: showMe)
        } else if case .chord = visual {
            yourTurn
        }
    }

    /// "Show me"; under notes or a strum, the switch back to the picture beside it while the model shows.
    @ViewBuilder private var showMeControls: some View {
        if case .chord = visual {
            showMeButton
                .frame(maxWidth: .infinity, minHeight: Metrics.minTarget)
        } else {
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 10) { neckFooterContent }
                VStack(spacing: 6) { neckFooterContent }
            }
            .frame(maxWidth: .infinity, minHeight: Metrics.minTarget)
        }
    }

    /// Under notes or a strum: the switch back to the picture while the model shows, and "Show me".
    @ViewBuilder private var neckFooterContent: some View {
        if showMe {
            ShowMeToggle(on: showMeBinding, accent: accent, label: "Neck view")
                .transition(.opacity)
        }
        showMeButton
    }

    /// The line under "Show me": what to watch (lit while the model plays it), handing over to a chord's "your turn"
    /// once its demonstration is over. One line, always there, so the card never grows.
    private var teacherLine: some View {
        ZStack {
            if cueShown, case .chord = visual {
                turnCue(compact: false)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .transition(.opacity)
            } else if let caption {
                ShowMeCaption(text: caption, accent: accent, live: threeD && sounding)
                    .transition(.opacity)
            }
        }
        .frame(maxWidth: .infinity, minHeight: Self.teacherLine)
        .animation(Motion.adaptive(Motion.settle, reduceMotion: reduceMotion), value: cueShown)
    }

    /// What to watch in this picture's demonstration.
    private var caption: Text? {
        switch visual {
        case let .chord(spec): return ShowMe.caption(for: spec)
        case .fretboard: return ShowMe.notesCaption
        case let .rhythm(pattern, beatsPerBar): return ShowMe.caption(pattern: pattern, beatsPerBar: beatsPerBar)
        default: return nil
        }
    }

    private var showMeButton: some View {
        ShowMeButton(accent: accent, loading: showMe && !showMeReady, showing: threeD, invite: !showMe && !firstShowing) {
            setShowMe(true)
        }
    }

    /// "Show me" puts the instrument on the card (the demonstration plays once it is in place) or, already there, plays
    /// it again; the switch back shows the picture where the demonstration left it. `tapped` is false when the step
    /// brings the model in by itself (the first time), without a tap's haptic.
    private func setShowMe(_ on: Bool, tapped: Bool = true) {
        guard on else {
            guard showMe else { return }
            withMotion(Motion.reveal, reduceMotion: reduceMotion) {
                showMe = false
                showMeReady = false
            }
            return
        }
        if tapped {
            Haptics.shared.selection()
            // Asked for: the first-time wait for the model is over (it is coming now anyway).
            firstTask?.cancel()
            firstShowing = false
        }
        if showMe {
            if showMeReady { play(replay: true) }
            return
        }
        // The picture's demonstration stops; the model's starts as it arrives.
        demoTask?.cancel()
        store.stopLessonListening(owner: owner)
        sounding = false
        lit = []
        playingIndex = nil
        neckStart = nil
        if demo == .showing { demo = .idle }
        showMeReady = false
        showMe = true
    }

    /// The model is in place: it takes over from the picture and the demonstration plays on it, once the camera has
    /// glided in.
    private func showMeAppeared() {
        guard showMe, !showMeReady else { return }
        withAnimation(Motion.reveal) { showMeReady = true }
        firstTask?.cancel()
        firstShowing = false
        remember()
        play(replay: true, lead: ShowMe.lead)
    }

    /// The model couldn't be shown: the picture stays, without "Show me". A first-time demonstration plays on the
    /// picture instead, as it would have without a model.
    private func showMeUnavailable() {
        let wasFirst = firstShowing
        firstTask?.cancel()
        firstShowing = false
        showMeFailed = true
        showMe = false
        showMeReady = false
        if wasFirst && autoPlays { play(replay: true) }
    }

    // MARK: Show me, the first time

    /// What this picture teaches as the course remembers it (`ShowMeKey`): a chord's shape or a strum's pattern. Notes
    /// on the neck are always new, so they wait for "Show me".
    private var demoKey: String? {
        switch visual {
        case let .chord(spec): return ShowMeKey.chord(spec)
        case let .rhythm(pattern, beatsPerBar): return ShowMeKey.strum(pattern: pattern, beatsPerBar: beatsPerBar)
        default: return nil
        }
    }

    /// The first time this chord or strum appears in the course, its demonstration plays by itself on the model rather
    /// than on the picture (when the demonstration plays by itself at all: not with Reduce Motion or VoiceOver).
    private var playsFirstOnModel: Bool {
        guard autoPlays, showMeModel != nil, let key = demoKey else { return false }
        return ShowMe.firstTime(key, course: course, settings: store.settings)
    }

    /// Brings the model in once the card has settled; should it not be in place in `ShowMe.patience`, the picture plays
    /// the demonstration instead and the model waits for "Show me".
    private func showFirstOnModel() {
        firstShowing = true
        firstTask?.cancel()
        firstTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(ShowMe.settle))
            guard !Task.isCancelled, firstShowing else { return }
            if !showMe { setShowMe(true, tapped: false) }
            try? await Task.sleep(for: .seconds(ShowMe.patience))
            guard !Task.isCancelled, firstShowing, !showMeReady else { return }
            cancelFirst()
            setShowMe(false)
            play(replay: true)
        }
    }

    /// The first-time demonstration won't come by itself after all.
    private func cancelFirst() {
        firstTask?.cancel()
        firstTask = nil
        firstShowing = false
    }

    /// The course has now shown this chord or strum on the model: from here on it waits for "Show me".
    private func remember() {
        guard let key = demoKey, !store.settings.hasShownDemo(key, in: course.id) else { return }
        store.updateSettings { $0.markDemoShown(key, in: course.id) }
    }

    // MARK: Chord: the fingers land, the strings ring, your turn

    /// The chord as big as the card allows, under its name and the switch between the chart and the player's view.
    /// The chart's fingers land in finger order on the demonstration's clock, its frets numbered; the player's view
    /// presses its fingertips in the same order on the same clock, fading the muted strings and lighting the open
    /// ones. Either way each string lights (and on the neck shimmers) as it sounds. Both take the same room, so the
    /// card holds still as they flip.
    private func chordBox(_ spec: ChordSpec, room: CGSize) -> some View {
        let fit = ChordDiagram.fit(spec, room: room, minWidth: 220)
        let edges = StringEdges.of(instrumentId: course.instrument, strings: spec.frets.count)
        let player = chordView == .player
        return VStack(spacing: 8) {
            chordHeader(spec)
            ZStack {
                if !threeD {
                    chordPicture(spec, fit: fit, edges: edges, player: player)
                        .transition(.opacity)
                }
                if showMe, let model = showMeModel {
                    // The same demonstration on the instrument: the same clock, the same strings lit.
                    ShowMeStage(modelID: model, strings: spec.frets.count, fretless: course.fretless, shot: .fretting(ShowMeShape(chord: spec)),
                                accent: accent, ringing: lit, landStart: chordLandStart, landingStep: Self.demoStep, edges: edges,
                                label: Text("\(spec.name) chord"), value: ChordWords.shape(spec),
                                onReady: { showMeAppeared() }, onFailure: { showMeUnavailable() })
                }
            }
            .frame(width: fit.width, height: ChordDiagram.boxHeight(spec, width: fit.width, stretch: fit.stretch, named: edges != nil))
        }
        .frame(maxWidth: fit.width)
        // Played back right: sparks from behind the box, on a canvas of their own size.
        .background { SparkBurst(trigger: burst, color: accent, startFraction: 0.45).frame(width: fit.width * 1.55, height: fit.width * 1.55) }
    }

    /// The chord's name over the switch between the chart and the player's view; in 3D, over the switch back to it.
    @ViewBuilder private func chordHeader(_ spec: ChordSpec) -> some View {
        if showMe && showMeModel != nil {
            ShowMeCardHeader(name: spec.name, on: showMeBinding, accent: accent)
        } else {
            ChordCardHeader(name: spec.name, accent: accent)
        }
    }

    /// The chart or the player's view, flipping between them in the same room.
    private func chordPicture(_ spec: ChordSpec, fit: (width: CGFloat, stretch: CGFloat), edges: StringEdges?, player: Bool) -> some View {
        ZStack {
            if player {
                PlayerNeck(chord: spec, accent: accent, ringing: lit, landStart: chordLandStart, landingStep: Self.demoStep, edges: edges)
                    .transition(ChordFlip.transition(toPlayer: true, reduceMotion: reduceMotion))
            } else {
                ChordDiagram(chord: spec, accent: accent, showName: false, ringing: lit, landing: landsFingers, landingOrder: .fingers,
                             landingStep: Self.demoStep, replay: demoReplay, edges: edges, fretNumbers: true, stretch: fit.stretch)
                    .transition(ChordFlip.transition(toPlayer: false, reduceMotion: reduceMotion))
            }
        }
        .animation(Motion.adaptive(Motion.settle, reduceMotion: reduceMotion), value: player)
    }

    /// The fingers land as the demonstration plays: from the start when it plays by itself, else from the first
    /// "Hear it" (until then, and with Reduce Motion, every finger sits in place).
    private var landsFingers: Bool { !reduceMotion && (autoPlays || demoReplay > 0) }

    /// The demonstration is over: it's the learner's turn (or they've played it back).
    private var cueShown: Bool { demo == .yourTurn || demo == .heard }

    /// After the demonstration: the learner's cue to play it back, then a tick when the microphone hears it.
    /// Its row is always there, so the card doesn't grow when it appears.
    private var yourTurn: some View {
        turnCue(compact: false)
            .frame(minHeight: 20)
            .opacity(cueShown ? 1 : 0)
            .animation(Motion.settle, value: demo)
            .accessibilityHidden(!cueShown)
    }

    /// The cue's words with their glyph; `compact` keeps the glyph alone (its words still read by VoiceOver).
    @ViewBuilder private func turnCue(compact: Bool) -> some View {
        Group {
            if demo == .heard {
                if compact {
                    Label("Nice — that’s right.", systemImage: "checkmark.seal.fill").labelStyle(.iconOnly).foregroundStyle(accent)
                } else {
                    Label("Nice — that’s right.", systemImage: "checkmark.seal.fill").foregroundStyle(accent)
                }
            } else {
                if compact {
                    Label("Your turn — play it back", systemImage: "hand.point.up.left.fill").labelStyle(.iconOnly).foregroundStyle(Palette.ink)
                } else {
                    Label("Your turn — play it back", systemImage: "hand.point.up.left.fill").foregroundStyle(Palette.ink)
                }
            }
        }
        .font(Typeface.label(14))
        .multilineTextAlignment(.center)
    }

    /// Fingers land one by one (finger 1 first), each string lighting as its finger's note sounds, then the chord
    /// rings across every string, low to high; `replay` lands them again (the Hear it button).
    private func runDemo(_ chord: ChordSpec, replay: Bool, lead delay: Double? = nil) {
        demoTask?.cancel()
        store.stopLessonListening(owner: owner)
        if replay { demoReplay += 1 }
        demo = .showing
        lit = []
        sounding = true
        // The diagram starts landing 0.25 s after it appears, 0.05 s after a replay (the 3D stage once it has glided in).
        let lead = delay ?? (replay ? 0.05 : 0.25)
        chordLandStart = Date().addingTimeInterval(lead)
        let notes = demoNotes(chord)
        let strings = chord.frets.indices.filter { chord.frets[$0] >= 0 }
        demoTask = Task { @MainActor in
            // One clock for the whole demonstration, so each note meets its finger.
            let clock = ContinuousClock()
            let start = clock.now
            for note in notes {
                try? await clock.sleep(until: start + .seconds(lead + Double(note.rank) * Self.demoStep))
                guard !Task.isCancelled else { return }
                sound(note.midi)
                lit = [note.string]
            }
            let ringAt = lead + Double((notes.last?.rank ?? -1) + 1) * Self.demoStep
            try? await clock.sleep(until: start + .seconds(ringAt))
            guard !Task.isCancelled else { return }
            strum(chord)
            lit = []
            // The strum crosses the strings low to high, lighting each as it goes.
            for (k, string) in strings.enumerated() {
                try? await clock.sleep(until: start + .seconds(ringAt + Double(k) * 0.04))
                guard !Task.isCancelled else { return }
                lit.insert(string)
            }
            try? await clock.sleep(until: start + .seconds(ringAt + 1.5))
            guard !Task.isCancelled else { return }
            lit = []
            try? await clock.sleep(until: start + .seconds(ringAt + 1.8))
            guard !Task.isCancelled else { return }
            sounding = false
            demo = .yourTurn
            listenForPlayback(chord)
        }
    }

    /// Each landing's note (the lowest string a finger holds) and that string, in landing order.
    private func demoNotes(_ chord: ChordSpec) -> [(rank: Int, midi: Int, string: Int)] {
        ShowMe.demoNotes(chord, open: ChordStep.openStrings(course))
    }

    /// The learner plays the chord back: three matching readings in a row count. Only when the microphone
    /// is already allowed; the chord step that follows is where it's required.
    private func listenForPlayback(_ chord: ChordSpec) {
        guard LessonMicrophone.granted, let target = ChordTarget(root: chord.root, formulaId: chord.quality) else { return }
        matchedFrames = 0
        let analyzer = LessonAnalyzer(chords: true, target: target, onChord: { _, matched in
            guard demo == .yourTurn else { return }
            matchedFrames = matched ? matchedFrames + 1 : 0
            guard matchedFrames >= 3 else { return }
            demo = .heard
            burst += 1
            SoundFX.shared.play(.correct); Haptics.shared.lock()
            store.stopLessonListening(owner: owner)
        })
        store.startLessonListening(owner: owner, analyzer: analyzer) { _, _ in }
    }

    /// Sounds the chord as shaped on the course instrument (as the Chords tool does); a plain triad when the course has none.
    private func strum(_ chord: ChordSpec) {
        let open = ChordStep.openStrings(course)
        var midis = chord.frets.enumerated().compactMap { i, fret -> Int? in fret >= 0 && i < open.count ? open[i] + fret : nil }
        if midis.isEmpty, let target = ChordTarget(root: chord.root, formulaId: chord.quality) {
            midis = target.quality.intervals.map { 48 + target.root + $0 }
        }
        guard !midis.isEmpty else { return }
        let reference = store.settings.referencePitchHz
        store.audio.playTones(midis.map { PitchMath.frequency(midi: Double($0), reference: reference) }, together: true, noteMs: 1500)
        Haptics.shared.selection()
    }

    // MARK: Neck: the dots drop in, note by note

    /// Each dot's note on the course instrument, in `dots` order; nil when the tuning isn't known.
    private var neckMidis: [Int?] {
        guard case let .fretboard(strings, dots, _, _) = visual else { return [] }
        let open = ChordStep.openStrings(course)
        return dots.map { dot in
            guard open.count == strings, dot.string >= 1, dot.string <= strings else { return nil }
            return open[strings - dot.string] + dot.fret
        }
    }

    /// The order the dots land and sound in: lowest note first (as the tune climbs), as written when unknown.
    private var neckOrder: [Int] {
        let midis = neckMidis
        return midis.indices.sorted { a, b in (midis[a] ?? a, a) < (midis[b] ?? b, b) }
    }

    /// The neck as tall as the card allows, its frets numbered, the dots dropping in on their notes' clock and
    /// each one's string lit while its note sounds. With Reduce Motion the dots stay in place and only the strings light.
    private func neck(strings: Int, dots: [Fretting], frets: Int, start: Int, room: CGSize) -> some View {
        let numbered = !course.fretless
        let rowHeight = FretboardDiagram.rowHeight(filling: room, strings: strings, frets: frets, start: start, named: strings >= 2, numbered: numbered)
        let order = neckOrder
        let edges = StringEdges.of(instrumentId: course.instrument, strings: strings)
        return ZStack {
            if !threeD {
                TimelineView(.animation(minimumInterval: 1 / 60, paused: neckStart == nil)) { timeline in
                    let state = neckState(at: timeline.date, order: order, dots: dots)
                    FretboardDiagram(strings: strings, dots: dots, frets: frets, accent: accent, start: start, activeString: state.active,
                                     fretless: course.fretless, rowHeight: rowHeight, edges: edges, landing: state.landing, fretNumbers: numbered)
                }
                .transition(.opacity)
            }
            if showMe, let model = showMeModel {
                // The dots land on the instrument's own frets, on the same clock, each string ringing as its note sounds.
                ShowMeStage(modelID: model, strings: strings, fretless: course.fretless,
                            shot: .fretting(ShowMeShape(dots: dots, strings: strings, order: order, start: start)),
                            accent: accent, landStart: neckStart, landingStep: Self.noteStep, edges: edges,
                            label: Text("Notes on the neck"), value: ShowMe.words(dots: order.compactMap { dots[safe: $0] }),
                            onReady: { showMeAppeared() }, onFailure: { showMeUnavailable() })
                    .frame(height: max(160, room.height))
            }
        }
    }

    /// How far each dot has landed and which string sounds, `date` into the demonstration.
    private func neckState(at date: Date, order: [Int], dots: [Fretting]) -> (landing: [Double]?, active: Int?) {
        guard let neckStart else { return (nil, nil) }
        let elapsed = date.timeIntervalSince(neckStart)
        var rank = Array(repeating: 0, count: dots.count)
        for (position, index) in order.enumerated() where dots.indices.contains(index) { rank[index] = position }
        let landing: [Double]? = reduceMotion ? nil : dots.indices.map { LessonSpring.value(elapsed - Double(rank[$0]) * Self.noteStep) }
        let current = elapsed >= 0 ? Int(elapsed / Self.noteStep) : -1
        let active: Int? = order.indices.contains(current) ? dots[safe: order[current]]?.string : nil
        return (landing, active)
    }

    /// The dots drop in one by one, each as its note sounds; `replay` starts at once (the Hear it button).
    private func playNeck(replay: Bool, lead delay: Double? = nil) {
        demoTask?.cancel()
        let lead = delay ?? (replay ? 0.05 : 0.3)
        let midis = neckMidis
        let order = neckOrder
        neckStart = Date().addingTimeInterval(lead)
        sounding = true
        demoTask = Task { @MainActor in
            // One clock for the whole demonstration, so each note meets its dot.
            let clock = ContinuousClock()
            let start = clock.now
            for (position, index) in order.enumerated() {
                try? await clock.sleep(until: start + .seconds(lead + Double(position) * Self.noteStep))
                guard !Task.isCancelled else { return }
                if let midi = midis[safe: index] ?? nil { sound(midi) }
            }
            try? await clock.sleep(until: start + .seconds(lead + Double(order.count) * Self.noteStep + 0.4))
            guard !Task.isCancelled else { return }
            neckStart = nil
            sounding = false
        }
    }

    // MARK: Staff and keyboard: each note lights as it sounds

    /// What shares a staff's card when there's room: the notes on the course's neck (fretted and bowed courses,
    /// when every note has a place on it) or on a keyboard (the others).
    private enum Partner { case neck([Fretting]), keys, alone }

    private func partner(for midi: [Int]) -> Partner {
        guard course.fretKind != nil else { return .keys }
        let spots = midi.compactMap { course.fretting(for: $0) }
        return !spots.isEmpty && spots.count == midi.count ? .neck(spots) : .alone
    }

    /// The staff as big as the card allows; with room for two, the same notes again where they're played, under it.
    @ViewBuilder private func staffPicture(_ midi: [Int], clef: String, room: CGSize) -> some View {
        let half = (room.height - 18) / 2
        let shared = half >= 110 ? partner(for: midi) : .alone
        switch shared {
        case let .neck(spots):
            VStack(spacing: 18) {
                staff(midi, clef: clef, height: half)
                notesNeck(spots, room: CGSize(width: room.width, height: half))
            }
        case .keys:
            VStack(spacing: 18) {
                staff(midi, clef: clef, height: half)
                KeyboardView(highlighted: keysLit(midi), accent: accent, height: min(150, half))
            }
        case .alone:
            staff(midi, clef: clef, height: room.height)
        }
    }

    private func staff(_ midi: [Int], clef: String, height: CGFloat) -> some View {
        StaffView(notes: midi, clef: clef, accent: accent, activeIndex: playingIndex, lineGap: StaffView.lineGap(filling: height))
    }

    /// The keys as long as the card allows (up to 170 pt); with room for two, the notes on a staff over them.
    @ViewBuilder private func keysPicture(_ notes: [Int], room: CGSize) -> some View {
        let half = (room.height - 18) / 2
        if half >= 110 {
            VStack(spacing: 18) {
                staff(notes, clef: Self.clef(for: notes), height: half)
                KeyboardView(highlighted: keysLit(notes), accent: accent, height: min(170, half))
            }
        } else {
            KeyboardView(highlighted: keysLit(notes), accent: accent, height: min(170, max(110, room.height)))
        }
    }

    /// Low notes read in bass clef.
    private static func clef(for notes: [Int]) -> String {
        guard !notes.isEmpty else { return "treble" }
        return Double(notes.reduce(0, +)) / Double(notes.count) < 57 ? "bass" : "treble"
    }

    /// The staff's notes on the course's neck: while they play, each dot appears as its note sounds, its string lit.
    private func notesNeck(_ spots: [Fretting], room: CGSize) -> some View {
        let strings = course.stringCount
        let frets = min(12, max(4, (spots.map(\.fret).max() ?? 0) + 1))
        let numbered = !course.fretless
        let rowHeight = FretboardDiagram.rowHeight(filling: room, strings: strings, frets: frets, start: 1, named: strings >= 2, numbered: numbered)
        let landing: [Double]? = playingIndex.map { now in spots.indices.map { Double($0 <= now ? 1 : 0) } }
        let active = playingIndex.flatMap { spots[safe: $0]?.string }
        return FretboardDiagram(strings: strings, dots: spots, frets: frets, accent: accent, activeString: active, fretless: course.fretless,
                                rowHeight: rowHeight, edges: StringEdges.of(course), landing: landing, fretNumbers: numbered)
    }

    /// The keys of `played` (in the order they play): the one sounding now while they play, all of them otherwise.
    private func keysLit(_ played: [Int]) -> Set<Int> {
        guard let playingIndex, played.indices.contains(playingIndex) else { return Set(played) }
        return [played[playingIndex]]
    }

    /// The notes one by one, each lit as it sounds; two to four notes (an interval, a chord) then ring together.
    /// `lead` lets the card settle first.
    private func playNotes(_ midi: [Int], lead: Double) {
        demoTask?.cancel()
        sounding = true
        demoTask = Task { @MainActor in
            if lead > 0 {
                try? await Task.sleep(for: .seconds(lead))
                guard !Task.isCancelled else { return }
            }
            for (index, note) in midi.enumerated() {
                playingIndex = index
                sound(note, ms: 400)
                try? await Task.sleep(for: .seconds(Self.noteStep + 0.06))
                guard !Task.isCancelled else { return }
            }
            playingIndex = nil
            if (2...4).contains(midi.count) {
                let reference = store.settings.referencePitchHz
                store.audio.playTones(midi.map { PitchMath.frequency(midi: Double($0), reference: reference) }, together: true, noteMs: 1200)
                try? await Task.sleep(for: .milliseconds(1300))
                guard !Task.isCancelled else { return }
            }
            sounding = false
        }
    }

    // MARK: Rhythm: the strokes sound as the pick sweeps

    /// Two bars of the pattern, each stroke sounding as the pick crosses the strings (a strum of the instrument's
    /// first open chord, its higher strings on an up stroke; the lowest string plucked; a click without an
    /// instrument). As the step appears the loop lines its beat 1 up with the first stroke; a replay joins the
    /// loop at its next stroke, so the pick never jumps.
    private func playRhythm(_ pattern: [Double], beatsPerBar: Int, replay: Bool) {
        demoTask?.cancel()
        guard !pattern.isEmpty else { return }
        let spb = 60 / Self.rhythmBPM
        let bar = Double(max(1, beatsPerBar)) * spb
        let from: Double
        if replay {
            from = Date().timeIntervalSince(rhythmOrigin) + 0.15
        } else {
            // The loop is already turning as the card arrives; beat 1 lands once the card has settled.
            rhythmOrigin = Date().addingTimeInterval(0.8)
            from = 0
        }
        let hits = pattern.sorted()
        let firstBar = Int((from / bar).rounded(.down))
        var strokes: [(at: Double, down: Bool)] = []
        for index in firstBar...(firstBar + 2) {
            for hit in hits {
                let at = Double(index) * bar + hit * spb
                if at >= from - 0.0001 { strokes.append((at: at, down: hit.truncatingRemainder(dividingBy: 1) == 0)) }
            }
        }
        let run = Array(strokes.prefix(hits.count * 2))
        let origin = rhythmOrigin
        // A strum sounds as the pick reaches the first string, a little before it passes the middle on the beat.
        let early = sweepStyle == .strum ? 0.09 : 0.02
        sounding = true
        demoTask = Task { @MainActor in
            for stroke in run {
                let wait = origin.addingTimeInterval(stroke.at - early).timeIntervalSinceNow
                if wait > 0 { try? await Task.sleep(for: .seconds(wait)) }
                guard !Task.isCancelled else { return }
                playStroke(down: stroke.down)
            }
            try? await Task.sleep(for: .seconds(0.8))
            guard !Task.isCancelled else { return }
            sounding = false
        }
    }

    private func playStroke(down: Bool) {
        let reference = store.settings.referencePitchHz
        switch sweepStyle {
        case .tap:
            SoundFX.shared.play(down ? .accent : .click)
        case .pluck:
            guard let low = ChordStep.openStrings(course).min() else { return }
            store.audio.playTones([PitchMath.frequency(midi: Double(low), reference: reference)], together: false, noteMs: 420, gapMs: 0)
        case .strum:
            let chord = strumChord
            let notes = down ? chord : Array(chord.sorted().suffix(3))
            guard !notes.isEmpty else { return }
            store.audio.playTones(notes.map { PitchMath.frequency(midi: Double($0), reference: reference) }, together: true, noteMs: down ? 520 : 320)
        }
    }

    /// What the strum demonstration rings, lowest string first: each strummed instrument's first open chord
    /// (E minor on guitar, C on ukulele, G on mandolin, the open G of a banjo).
    private var strumChord: [Int] {
        let open = ChordStep.openStrings(course)
        let shape: [Int]
        switch course.fretKind {
        case "guitar": shape = [0, 2, 2, 0, 0, 0]
        case "ukulele": shape = [0, 0, 0, 3]
        case "mandolin": shape = [0, 0, 2, 3]
        default: shape = Array(repeating: 0, count: open.count)
        }
        return zip(open, shape).map { $0 + $1 }
    }
}

/// A damped spring from 0 to 1 (response 0.35 s, a slight overshoot), for things that land: 0 before `t` reaches 0.
enum LessonSpring {
    static func value(_ t: Double) -> Double {
        guard t > 0 else { return 0 }
        let omega = 2 * Double.pi / 0.35, zeta = 0.62
        let damped = omega * (1 - zeta * zeta).squareRoot()
        return 1 - exp(-zeta * omega * t) * (cos(damped * t) + zeta * omega / damped * sin(damped * t))
    }
}
