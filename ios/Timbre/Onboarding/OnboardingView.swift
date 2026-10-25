import AVFoundation
import SwiftUI
import TimbreCore
import UIKit

/// Onboarding's pages, in order. Not every player sees every one (`OnboardingView.segments`): the hand question needs
/// an instrument, the first tune needs the microphone, the reminder card follows a locked first tune while iOS has
/// never asked for notifications, and the first chord is for beginners whose first tune locked.
private enum OnboardingPage: Int, CaseIterable {
    case welcome, experience, goal, hand, microphone, firstTune, reminder, firstChord, plan

    /// The page as the funnel names it (`onboarding_step`).
    var name: String {
        switch self {
        case .welcome: return "welcome"
        case .experience: return "experience"
        case .goal: return "goal"
        case .hand: return "hand"
        case .microphone: return "microphone"
        case .firstTune: return "first_tune"
        case .reminder: return "reminder"
        case .firstChord: return "first_chord"
        case .plan: return "plan"
        }
    }
}

/// One answer to an onboarding question: its id (what is saved), its words and its glyph.
private struct Answer: Identifiable {
    enum Glyph {
        case symbol(String)
        /// Signal bars filled to `value` (0…1): how long they have played.
        case bars(Double)
        /// The symbol mirrored (the left hand).
        case mirrored(String)
    }

    let id: String
    let title: LocalizedStringKey
    let glyph: Glyph
}

struct OnboardingView: View {
    @EnvironmentObject private var store: AppStore
    /// Observed so the Pro badges on the instrument chips go when a restore unlocks everything.
    @EnvironmentObject private var commerce: CommerceService
    /// An instrument a link chose (an instrument's Custom Product Page): the welcome screen selects it.
    @ObservedObject private var link = OnboardingLink.shared
    @State private var page = OnboardingPage.welcome
    @State private var instrumentID: String? = "guitar.acoustic.6"
    /// An instrument a link chose that isn't one of the usual chips: it gets a chip of its own, first.
    @State private var linkedID: String?
    /// The welcome screen shows every instrument in rows, after "more".
    @State private var allInstruments = false
    /// Unanswered until the player picks; Continue waits for an answer. A beginner's goal starts on "Play my first songs".
    @State private var level: String?
    @State private var goal: String?
    /// The hand question's answer (`UserSettings.handedness`).
    @State private var hand = Handedness.right
    @State private var showPaywall = false
    @State private var restoring = false
    @State private var restoreMessage: String?
    /// The plan's commitment: minutes a day and the reminder time (the reminder card or "Remind me" turns it on).
    @State private var dailyMinutes = 10
    @State private var reminderTime = ReminderTime.initial
    @State private var reminderOn = false
    /// The placement check is up, and the answer it started from once it has run.
    @State private var checking = false
    @State private var checkedFrom: String?
    /// The first tune locked: the streak has begun, so the reminder card and the first chord may follow it.
    @State private var tuned = false
    /// iOS has never asked for notifications and nothing has offered the reminder yet: the card may ask.
    @State private var reminderAskable = false
    /// The first chord was played before this onboarding (it ran before): it isn't offered again.
    @State private var chordBefore = false
    @State private var chordPlayed = false
    /// The welcome has played Timbre's motif (once, as it first appears).
    @State private var welcomed = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        ZStack {
            StageBackground()
            VStack(spacing: 0) {
                progressBar
                pageView
                    .transition(.adaptive(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity),
                                                      removal: .move(edge: .leading).combined(with: .opacity)),
                                          reduceMotion: reduceMotion))
                    .id(page)
                    .frame(maxHeight: .infinity)
            }
        }
        .animation(Motion.adaptive(Motion.page, reduceMotion: reduceMotion), value: page)
        .fullScreenCover(isPresented: $showPaywall, onDismiss: finish) {
            PaywallView(context: .onboarding, answers: PaywallAnswers(instrumentId: instrumentID, level: level ?? "beginner", goal: goal ?? "tune", minutes: dailyMinutes))
                .environmentObject(store).environmentObject(store.commerce)
        }
        .onAppear {
            Analytics.start()
            hand = store.settings.handedness
            chordBefore = store.settings.firstChordDone
            logStep(page)
        }
        .onChange(of: page) { _, next in logStep(next) }
        .onReceive(link.$instrumentID) { id in takeLink(id) }
        .task { reminderAskable = await ReminderAskStep.canAsk() }
    }

    @ViewBuilder private var pageView: some View {
        switch page {
        case .welcome: welcome
        case .experience: experience
        case .goal: goals
        case .hand: handPage
        case .microphone: microphone
        case .firstTune: firstTune
        case .reminder: reminderPage
        case .firstChord: firstChord
        case .plan: plan
        }
    }

    // MARK: Progress

    /// The pages this player's path holds (the welcome and the reminder card aside), each a segment of the bar.
    private var segments: [OnboardingPage] {
        var pages: [OnboardingPage] = [.experience, .goal]
        if asksHand { pages.append(.hand) }
        pages.append(.microphone)
        if firstTuneSetup != nil { pages.append(.firstTune) }
        if chordPlanned { pages.append(.firstChord) }
        pages.append(.plan)
        return pages
    }

    private var progressBar: some View {
        let pages = segments
        let done = pages.filter { $0.rawValue <= page.rawValue }.count
        return HStack(spacing: 6) {
            ForEach(pages, id: \.self) { segment in
                Capsule().fill(segment.rawValue <= page.rawValue ? Palette.mint : Palette.line).frame(height: 4)
            }
        }
        .padding(.horizontal, Metrics.gutter).padding(.top, 12)
        .opacity(page == .welcome ? 0 : 1)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("Step \(max(1, done)) of \(pages.count)"))
        .accessibilityHidden(page == .welcome)
    }

    private func logStep(_ step: OnboardingPage) {
        Analytics.log("onboarding_step", ["step": step.name, "index": String(step.rawValue)])
    }

    // MARK: Flow

    private func go(_ next: OnboardingPage) {
        Haptics.shared.selection()
        page = next
    }

    /// Every instrument has strings to hold: "Voice or other" skips the hand question.
    private var asksHand: Bool { instrumentID != nil }

    private var firstTuneSetup: FirstTuneSetup? { FirstTuneSetup.make(store: store, instrumentID: instrumentID) }

    /// A beginner (just starting, or a few months in) plays a first chord after the first tune, once ever.
    private var chordPlanned: Bool {
        guard level == "beginner" || level == "novice", !chordBefore else { return false }
        return FirstChordSetup.make(store: store, instrumentID: instrumentID) != nil
    }

    private func afterExperience() {
        // Beginners came to play: their goal starts on songs (they can choose another).
        if goal == nil, instrumentID != nil, level == "beginner" || level == "novice" { goal = "songs" }
        go(.goal)
    }

    private func afterGoal() { go(asksHand ? .hand : .microphone) }

    private func afterHand() {
        let answer = hand
        store.updateSettings { $0.handedness = answer }
        go(.microphone)
    }

    /// After the microphone question: the first tune when Timbre can hear the instrument, then the plan.
    /// "Not now", a denial, or "Voice or other" go straight to the plan.
    private func afterMicrophone() {
        if FirstTuneSetup.canListen, firstTuneSetup != nil { go(.firstTune) } else { go(.plan) }
    }

    /// A locked string started the streak: the reminder card (when it may ask), then a beginner's first chord.
    private func afterFirstTune(_ locked: Bool) {
        tuned = locked
        if locked && reminderAskable { page = .reminder } else { afterReminder() }
    }

    private func afterReminder() {
        page = tuned && chordPlanned ? .firstChord : .plan
    }

    /// Pro members skip the offer.
    private func startPlan() {
        if store.commerce.isPro { finish() } else { showPaywall = true }
    }

    /// After the paywall (or the plan, for Pro members): onboarding closes onto Learn with the plan's first lesson opening.
    private func finish() {
        let instrument = instrumentID.flatMap { store.catalog.instrument(id: $0) }
        let answeredLevel = level ?? "beginner"
        let answeredGoal = goal ?? "tune"
        // Chromatic first: it selects the Tune tab, and completing onboarding then hands over to Learn.
        if instrumentID == nil { store.selectReference() }
        store.completeOnboarding(instrument: instrument, level: answeredLevel, goal: answeredGoal, minutes: dailyMinutes)
        Analytics.log("onboarding_complete", ["instrument": instrumentID ?? "chromatic", "goal": answeredGoal, "level": answeredLevel,
                                              "minutes": String(dailyMinutes), "reminder": reminderOn ? "on" : "off",
                                              "placement_check": checkedFrom == nil ? "no" : "yes", "hand": asksHand ? hand.rawValue : "none",
                                              "first_tune": tuned ? "locked" : "no", "first_chord": chordPlayed ? "played" : "no"])
    }

    /// A link's instrument, chosen on the welcome screen (later pages keep the player's own choice).
    private func takeLink(_ id: String?) {
        guard let id else { return }
        link.consume()
        guard page == .welcome, store.catalog.instrument(id: id) != nil else { return }
        if !baseChoices.contains(where: { $0.id == id }) { linkedID = id }
        withMotion(Motion.pluck, reduceMotion: reduceMotion) { instrumentID = id }
    }

    // MARK: Welcome

    /// Spotlit instrument, the promise, and the instrument picker in one screen.
    private var welcome: some View {
        VStack(alignment: .leading, spacing: 0) {
            ZStack(alignment: .top) {
                Spotlight().fill(LinearGradient(colors: [Palette.spotlight.opacity(0.16), Palette.spotlight.opacity(0.03)], startPoint: .top, endPoint: .bottom))
                    .blur(radius: 6)
                    .ignoresSafeArea(edges: .top)
                Text("TIMBRE").font(Typeface.label(15)).tracking(9).foregroundStyle(Palette.amber).padding(.top, 34)
                    .frame(maxWidth: .infinity)
                Ellipse().fill(RadialGradient(colors: [Palette.spotlight.opacity(0.22), .clear], center: .center, startRadius: 2, endRadius: 170))
                    .frame(width: 320, height: 46).frame(maxHeight: .infinity, alignment: .bottom).padding(.bottom, 6)
                ZStack {
                    Image(heroImage(selectedChoice)).resizable().interpolation(.high).scaledToFit()
                        .id(instrumentID ?? "voice")
                        .transition(.adaptive(.asymmetric(insertion: .scale(scale: 0.92).combined(with: .opacity), removal: .opacity),
                                              reduceMotion: reduceMotion))
                }
                .shadow(color: .black.opacity(0.65), radius: 26, y: 18)
                .floating(rest: -13, raised: -9, rise: 6)
                .padding(.top, 70).padding(.bottom, 26)
                .frame(maxWidth: .infinity)
                .accessibilityHidden(true)
            }
            .frame(maxHeight: .infinity)
            VStack(alignment: .leading, spacing: 12) {
                // Two lines at the usual sizes (shrinking a little on a narrow phone); as many as it needs at the
                // accessibility sizes.
                Text("Tune in seconds.\nThen learn to play.").font(Typeface.display(40)).tracking(-1).foregroundStyle(Palette.ink)
                    .lineLimit(typeSize.isAccessibilitySize ? nil : 2).minimumScaleFactor(0.75)
                    .fixedSize(horizontal: false, vertical: true).accessibilityAddTraits(.isHeader)
                Text("Timbre listens and tells you exactly how you did.")
                    .font(.body).foregroundStyle(Palette.inkSoft).fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, Metrics.gutter)
            instrumentPicker
                .padding(.top, 18)
            Button("Get started") { go(.experience) }.buttonStyle(PrimaryButtonStyle()).padding(.horizontal, Metrics.gutter).padding(.top, 22)
                .accessibilityIdentifier("onboarding.start")
            restoreButton
                .padding(.horizontal, Metrics.gutter).padding(.top, 10).padding(.bottom, 4)
            if let restoreMessage {
                Text(restoreMessage).font(.caption).foregroundStyle(Palette.inkSoft).multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity).padding(.horizontal, Metrics.gutter + Metrics.proseInset).padding(.bottom, 6)
            }
        }
        .onAppear(perform: playWelcome)
    }

    /// Timbre's motif as the welcome first appears, once, after a beat so it lands with the spotlit instrument
    /// (`SoundFX` stays silent when sounds are off).
    private func playWelcome() {
        guard !welcomed else { return }
        welcomed = true
        let sounds = SoundFX.shared
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(450))
            guard page == .welcome else { return }
            sounds.play(.motif)
        }
    }

    /// "I already have Timbre Pro": the quieter bordered action under "Get started".
    private var restoreButton: some View {
        Button {
            restoring = true
            restoreMessage = nil
            Task {
                await store.commerce.restore()
                restoring = false
                if store.commerce.isPro { go(.experience) } else { restoreMessage = store.commerce.error }
            }
        } label: {
            if restoring { ProgressView().tint(Palette.ink) } else { Text("I already have Timbre Pro") }
        }
        .buttonStyle(SecondaryButtonStyle())
        .disabled(restoring)
        .accessibilityIdentifier("onboarding.restore")
    }

    // MARK: Instruments

    /// The instrument chips, none ever cut at the screen's edge: as many as fit whole on one line, then a
    /// "more" chip that opens every instrument in rows (the art above gives up the room). Where not even two fit (the
    /// largest text sizes) they scroll on one line instead, fading where they run under the edge.
    @ViewBuilder private var instrumentPicker: some View {
        if allInstruments {
            ChipFlow(spacing: 8, rowSpacing: 0) {
                ForEach(choices) { choice in instrumentChip(choice) }
            }
            .padding(.horizontal, Metrics.gutter)
            .transition(.opacity)
        } else {
            ViewThatFits(in: .horizontal) {
                chipLine(choices.count)
                chipLine(6)
                chipLine(5)
                chipLine(4)
                chipLine(3)
                chipLine(2)
                scrollingChips
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .transition(.opacity)
        }
    }

    /// The first `count` chips whole on one line, and the "more" chip when some are left.
    private func chipLine(_ count: Int) -> some View {
        HStack(spacing: 8) {
            ForEach(Array(choices.prefix(count))) { choice in instrumentChip(choice) }
            if count < choices.count { moreChip }
        }
        .padding(.horizontal, Metrics.gutter)
    }

    /// Every chip on one line that scrolls, for text too large to fit two: the edge fade dissolves a chip passing
    /// under either edge over the gutter and a chip's worth inside it.
    private var scrollingChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(choices) { choice in instrumentChip(choice) }
            }
            .padding(.horizontal, Metrics.gutter)
        }
        .edgeFade(width: Metrics.gutter + 40)
    }

    /// The app's chip: graphite with a control edge, the chosen one a pill of light (36 pt, a 44 pt target).
    private func instrumentChip(_ choice: Choice) -> some View {
        let selected = instrumentID == choice.id
        return Button {
            withMotion(Motion.pluck, reduceMotion: reduceMotion) { instrumentID = choice.id }
            Haptics.shared.selection()
        } label: {
            HStack(spacing: 7) {
                choice.title.lineLimit(1)
                // Tuned in Chromatic on the free plan; its own stage is Pro.
                if needsPro(choice) { ProBadge() }
            }
        }
        .buttonStyle(ChipButtonStyle(selected: selected))
        .accessibilityAddTraits(selected ? .isSelected : [])
        .accessibilityIdentifier("onboarding.instrument.\(choice.id ?? "voice")")
    }

    /// Opens every instrument in rows: a chip with an ellipsis, so it fits where a word would not.
    private var moreChip: some View {
        Button {
            withMotion(Motion.settle, reduceMotion: reduceMotion) { allInstruments = true }
            Haptics.shared.selection()
        } label: {
            Image(systemName: "ellipsis").fontWeight(.bold)
        }
        .buttonStyle(ChipButtonStyle(selected: false))
        .accessibilityLabel(Text("More instruments"))
        .accessibilityIdentifier("onboarding.instrument.more")
    }

    private var selectedChoice: Choice { choices.first { $0.id == instrumentID } ?? choices[0] }

    /// A Pro instrument for a free player (`AccessPolicy`): the welcome chip wears the Pro badge.
    private func needsPro(_ choice: Choice) -> Bool {
        guard let id = choice.id, let instrument = store.catalog.instrument(id: id) else { return false }
        return !AccessPolicy.canTune(instrument: instrument, pro: commerce.isPro)
    }

    /// The studio render when the instrument has an artist model, otherwise its photograph.
    private func heroImage(_ choice: Choice) -> String {
        let photo = choice.photo ?? "01_guitar_acoustic_guitar"
        if let model = ModelLibrary.modelID(forPhoto: photo), ModelLibrary.hasCard(model) { return ModelLibrary.cardImageName(model) }
        return photo
    }

    private struct Choice: Identifiable { let id: String?; let title: Text; let photo: String? }

    /// The usual chips, and first, an instrument a link chose that isn't among them.
    private var choices: [Choice] {
        var list = baseChoices
        if let linkedID, let instrument = store.catalog.instrument(id: linkedID) {
            let photo = store.catalog.photo(instrumentId: linkedID)
            let name = photo.map { NSLocalizedString("timbre_photo_" + $0.asset, bundle: .main, value: $0.label, comment: "") } ?? instrument.name.localized
            list.insert(Choice(id: linkedID, title: Text(verbatim: name), photo: photo?.asset), at: 0)
        }
        return list
    }

    private var baseChoices: [Choice] {
        [Choice(id: "guitar.acoustic.6", title: Text("Guitar"), photo: "01_guitar_acoustic_guitar"),
         Choice(id: "bass.electric.4", title: Text("Bass"), photo: "06_bass_4_string_p_bass"),
         Choice(id: "ukulele.soprano.4", title: Text("Ukulele"), photo: "10_ukulele_soprano_ukulele"),
         Choice(id: "violin.standard.4", title: Text("Violin"), photo: "17_bowed_strings_violin"),
         Choice(id: "cello.standard.4", title: Text("Cello"), photo: "19_bowed_strings_cello"),
         Choice(id: "mandolin.standard.8", title: Text("Mandolin"), photo: "13_mandolin_mandolin"),
         Choice(id: "banjo.five.5", title: Text("Banjo"), photo: "22_folk_world_strings_banjo_5_string"),
         Choice(id: nil, title: Text("Voice or other"), photo: nil)]
    }

    // MARK: Questions

    /// Each answer starts the course at its own unit (`CoursePlacement`): unit 1, after the basics, the mid-course
    /// chords and songs, the barre and lead units, and past them. The bars fill with the years.
    private var levelAnswers: [Answer] {
        [Answer(id: "beginner", title: "Just starting", glyph: .bars(0)),
         Answer(id: "novice", title: "A few months", glyph: .bars(0.25)),
         Answer(id: "intermediate", title: "A few years", glyph: .bars(0.5)),
         Answer(id: "advanced", title: "Many years", glyph: .bars(0.75)),
         Answer(id: "pro", title: "I play professionally", glyph: .bars(1))]
    }

    /// "Play my first songs" leads for anyone with an instrument: the intent the plan, the first chord and the paywall
    /// are built around.
    private var goalAnswers: [Answer] {
        let songs = Answer(id: "songs", title: "Play my first songs", glyph: .symbol("music.note.list"))
        let rest = [Answer(id: "tune", title: "Tune fast and precisely", glyph: .symbol("tuningfork")),
                    Answer(id: "practice", title: "Practice every day", glyph: .symbol("calendar")),
                    Answer(id: "ear", title: "Train my ear", glyph: .symbol("ear")),
                    Answer(id: "voice", title: "Sing in tune", glyph: .symbol("music.mic")),
                    Answer(id: "rhythm", title: "Keep better time", glyph: .symbol("metronome"))]
        return instrumentID == nil ? rest : [songs] + rest
    }

    /// Right, left, and (not for bowed instruments) a right-handed instrument played left-handed, strung upside down.
    private var handAnswers: [Answer] {
        var list = [Answer(id: Handedness.right.rawValue, title: "Right-handed", glyph: .symbol("hand.raised")),
                    Answer(id: Handedness.left.rawValue, title: "Left-handed", glyph: .mirrored("hand.raised"))]
        let bowed = ["violin", "cello"].contains(LearnCourse.fretKind(of: instrumentID) ?? "")
        if !bowed {
            list.append(Answer(id: Handedness.leftUpsideDown.rawValue, title: "Left-handed, strung upside down", glyph: .symbol("arrow.up.arrow.down")))
        }
        return list
    }

    private var experience: some View {
        questionPage("How long have you been playing?", "Exercises start where you are.", enabled: level != nil, onContinue: afterExperience) {
            answerList(levelAnswers, selection: $level)
        }
    }

    private var goals: some View {
        questionPage("What matters most?", "Your Today plan is built around it.", enabled: goal != nil, onContinue: afterGoal) {
            answerList(goalAnswers, selection: $goal)
        }
    }

    private var handPage: some View {
        let selection = Binding<String?>(get: { hand.rawValue }, set: { id in
            if let value = id.flatMap(Handedness.init(rawValue:)) { hand = value }
        })
        return questionPage("Which hand do you play with?", "Necks, chord charts and the stage follow your hand.", enabled: true,
                            onContinue: afterHand) {
            answerList(handAnswers, selection: selection)
        }
    }

    /// A question over its answers, the answers centred in the room left under it, and Continue in the dock. Where
    /// they don't fit (large text, a small phone) the page scrolls above the dock instead.
    private func questionPage<Content: View>(_ title: LocalizedStringKey, _ detail: LocalizedStringKey, enabled: Bool,
                                             onContinue: @escaping () -> Void, @ViewBuilder answers: () -> Content) -> some View {
        let list = answers()
        return ViewThatFits(in: .vertical) {
            questionStack(title, detail, list, spread: true)
            ScrollView {
                questionStack(title, detail, list, spread: false)
            }
            .scrollBounceBehavior(.basedOnSize)
        }
        .onboardingDock { continueButton(enabled: enabled, action: onContinue) }
    }

    private func questionStack<Content: View>(_ title: LocalizedStringKey, _ detail: LocalizedStringKey, _ answers: Content,
                                              spread: Bool) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            question(title, detail)
            if spread { Spacer(minLength: 18) } else { Color.clear.frame(height: 18) }
            answers
            if spread { Spacer(minLength: 18) }
        }
        .padding(.horizontal, Metrics.gutter).padding(.top, 18).padding(.bottom, 8)
        .frame(maxWidth: .infinity, maxHeight: spread ? CGFloat.infinity : nil, alignment: .topLeading)
    }

    private func question(_ title: LocalizedStringKey, _ detail: LocalizedStringKey) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(Typeface.display(32)).tracking(-0.6).foregroundStyle(Palette.ink).fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)
            Text(detail).font(.subheadline).foregroundStyle(Palette.inkSoft)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.top, 8)
    }

    private func answerList(_ items: [Answer], selection: Binding<String?>) -> some View {
        VStack(spacing: 10) {
            ForEach(items) { item in answerRow(item, selection: selection) }
        }
    }

    /// An answer: its glyph, its words and a check, the chosen one washed in mint.
    private func answerRow(_ item: Answer, selection: Binding<String?>) -> some View {
        let selected = selection.wrappedValue == item.id
        let row = RoundedRectangle(cornerRadius: Metrics.cornerTile, style: .continuous)
        return Button {
            withMotion(Motion.pluck, reduceMotion: reduceMotion) { selection.wrappedValue = item.id }
            Haptics.shared.selection()
        } label: {
            HStack(spacing: 14) {
                AnswerGlyph(glyph: item.glyph, selected: selected)
                Text(item.title).font(.headline).foregroundStyle(Palette.ink)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 8)
                Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(selected ? Palette.mint : Palette.inkFaint)
                    .contentTransition(.symbolEffect(.replace))
                    .accessibilityHidden(true)
            }
            .padding(.horizontal, 16).padding(.vertical, 14)
            .frame(minHeight: 56)
            .background(row.fill(selected ? Palette.mint.opacity(0.14) : Palette.stageRaised.opacity(0.8)))
            .overlay(row.strokeBorder(selected ? Palette.mint : Palette.controlLine, lineWidth: 1))
            .contentShape(row)
        }
        .buttonStyle(PressScaleStyle())
        .accessibilityAddTraits(selected ? .isSelected : [])
        .accessibilityIdentifier("onboarding.option.\(item.id)")
    }

    /// Continue waits, neutral and clearly inactive but readable (the primary button's disabled look), until a
    /// question is answered.
    private func continueButton(enabled: Bool, action: @escaping () -> Void) -> some View {
        Button("Continue", action: action)
            .buttonStyle(PrimaryButtonStyle())
            .disabled(!enabled)
            .animation(Motion.quick, value: enabled)
            .accessibilityIdentifier("onboarding.continue")
    }

    // MARK: Microphone

    private var microphone: some View {
        VStack(spacing: 22) {
            Spacer()
            ZStack {
                ForEach(0..<3, id: \.self) { ring in
                    Circle().strokeBorder(Palette.mint.opacity(0.3 - Double(ring) * 0.08), lineWidth: 1.5).frame(width: 130 + CGFloat(ring) * 60, height: 130 + CGFloat(ring) * 60)
                }
                Image(systemName: "mic.fill").font(.system(size: 54)).foregroundStyle(Palette.mint)
            }
            .frame(height: 260)
            .accessibilityHidden(true)
            Text("Timbre listens\nto your instrument").font(Typeface.display(34)).tracking(-0.6).multilineTextAlignment(.center).foregroundStyle(Palette.ink)
                .accessibilityAddTraits(.isHeader)
            Text("Pitch is measured on your iPhone. Recordings are never saved or uploaded.").multilineTextAlignment(.center).foregroundStyle(Palette.inkSoft)
                .padding(.horizontal, Metrics.gutter + Metrics.proseInset)
            Spacer()
            Button("Allow microphone") {
                Task {
                    let granted = await AVAudioApplication.requestRecordPermission()
                    Analytics.log("mic_permission", ["granted": granted ? "1" : "0", "asked": "1"])
                    afterMicrophone()
                }
            }
            .buttonStyle(PrimaryButtonStyle()).padding(.horizontal, Metrics.gutter)
            .accessibilityIdentifier("onboarding.microphone")
            Button {
                Analytics.log("mic_permission", ["granted": "0", "asked": "0"])
                afterMicrophone()
            } label: {
                Text("Not now").font(.subheadline)
                    .padding(.horizontal, 24)
            }
            .buttonStyle(TextLinkStyle(tint: Palette.inkSoft))
            .padding(.bottom, 4)
        }
    }

    // MARK: First tune, reminder, first chord

    /// "Pluck your thickest string" on the live stage; locking it (or Skip) leads on.
    @ViewBuilder private var firstTune: some View {
        if let setup = firstTuneSetup {
            FirstTuneStep(setup: setup) { locked in afterFirstTune(locked) }
        } else {
            plan
        }
    }

    private var reminderPage: some View {
        ReminderAskStep(streak: store.streak.current, time: $reminderTime) { on in
            reminderOn = on
            afterReminder()
        }
    }

    @ViewBuilder private var firstChord: some View {
        if let setup = FirstChordSetup.make(store: store, instrumentID: instrumentID) {
            FirstChordStep(setup: setup) { played in
                chordPlayed = played
                go(.plan)
            }
        } else {
            plan
        }
    }

    // MARK: Plan

    /// The plan from the answers: the course, where the placement starts, the goal and the next milestones.
    @ViewBuilder private var plan: some View {
        let instrument = instrumentID.flatMap { store.catalog.instrument(id: $0)?.id }
        let answeredGoal = goal ?? "tune"
        let goalAnswer = goalAnswers.first { $0.id == answeredGoal }
        if let course = store.onboardingCourse(instrumentId: instrument, goal: answeredGoal) {
            let answered = level ?? "beginner"
            // The same placement the paywall's "Today" and the lesson Learn opens use (`AppStore.onboardingProgress`).
            let progress = store.onboardingProgress(level: answered, instrumentId: instrument, goal: answeredGoal)
            let start = progress.nextLesson(in: course)
            let checkSteps = placementCheckSteps(course)
            PlanStep(course: course, start: start, goal: goalAnswer, artwork: CourseArtwork.of(course, catalog: store.catalog),
                     check: checkSteps == nil ? nil : (checkedFrom == nil ? PlanCheck.offer : PlanCheck.done),
                     minutes: $dailyMinutes, reminder: $reminderTime, reminderOn: $reminderOn,
                     onCheck: { checking = true }, onStart: { startPlan() })
                .fullScreenCover(isPresented: $checking) {
                    if let checkSteps {
                        PlacementCheckView(course: course, steps: checkSteps, level: answered) { checked in finishCheck(from: answered, to: checked) }
                            .environmentObject(store)
                    }
                }
        } else {
            Color.clear
                .onboardingDock {
                    Button("Start my plan") { startPlan() }.buttonStyle(PrimaryButtonStyle())
                        .accessibilityIdentifier("onboarding.plan.start")
                }
        }
    }

    /// The 45-second placement check, for players who said a few years or more, when Timbre can hear them and the
    /// plan's course has chords to change between (`PlacementCheck.steps`). Still shown, as done, once it has run.
    private func placementCheckSteps(_ course: LearnCourse) -> [LessonStep]? {
        guard let level, PlacementCheck.offered(level: level) || checkedFrom != nil, FirstTuneSetup.canListen else { return nil }
        return PlacementCheck.steps(in: course)
    }

    /// The check's answer replaces the experience answer: the plan, the paywall and Learn all follow it.
    /// Closed early (nil), nothing changes and the plan still offers it.
    private func finishCheck(from answered: String, to checked: String?) {
        checking = false
        guard let checked else { return }
        checkedFrom = answered
        guard checked != answered else { return }
        withMotion(Motion.settle, reduceMotion: reduceMotion) { level = checked }
    }
}

/// An answer's glyph, the app's bare `Glyph` at a card's leading size: soft ink, mint once chosen. The years' signal
/// bars fill to their value, drawn at the same size and weight.
private struct AnswerGlyph: View {
    let glyph: Answer.Glyph
    let selected: Bool

    private var tint: Color { selected ? Palette.mint : Palette.inkSoft }

    @ViewBuilder var body: some View {
        switch glyph {
        case .symbol(let name):
            Glyph(name, size: Glyph.lead, tint: tint)
        case .mirrored(let name):
            Glyph(name, size: Glyph.lead, tint: tint).scaleEffect(x: -1, y: 1)
        case .bars(let value):
            Image(systemName: "cellularbars", variableValue: value)
                .font(.system(size: Glyph.lead * 0.78, weight: .regular))
                .foregroundStyle(tint)
                .frame(width: Glyph.lead, height: Glyph.lead)
                .accessibilityHidden(true)
        }
    }
}

/// The practice reminder's time of day, as onboarding's pickers hold it.
enum ReminderTime {
    /// Today at the reminder's time: 7 pm unless one was chosen before.
    static var initial: Date {
        let minutes = PracticeReminder.minutes
        return Calendar.current.date(bySettingHour: minutes / 60, minute: minutes % 60, second: 0, of: Date()) ?? Date()
    }

    /// Minutes after midnight.
    static func minutes(of date: Date) -> Int {
        let time = Calendar.current.dateComponents([.hour, .minute], from: date)
        return (time.hour ?? 19) * 60 + (time.minute ?? 0)
    }
}

/// An onboarding page's main action, pinned to the foot of the page. The page above keeps clear of it (the inset
/// reserves its height, at every text size) and passes under its short fade, so no row ever rests under the button.
struct OnboardingDock<Content: View>: View {
    private let content: Content

    init(@ViewBuilder content: () -> Content) { self.content = content() }

    var body: some View {
        VStack(spacing: 0) {
            LinearGradient(colors: [Palette.stage.opacity(0), Palette.stage.opacity(0.9)], startPoint: .top, endPoint: .bottom)
                .frame(height: 18)
                .allowsHitTesting(false)
                .accessibilityHidden(true)
            content
                .padding(.horizontal, Metrics.gutter).padding(.top, 4).padding(.bottom, 12)
                .frame(maxWidth: .infinity)
                .background(Palette.stage.opacity(0.9))
        }
    }
}

extension View {
    /// Pins `content` (the page's main action) in an `OnboardingDock` at the page's foot.
    func onboardingDock<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        let dock = OnboardingDock(content: content)
        return safeAreaInset(edge: .bottom, spacing: 0) { dock }
    }
}

/// "Your plan": the course card with the first lesson after placement, the goal with the daily commitment
/// (minutes a day, a reminder), and the first lessons of the next units as milestones. Rows rise in one after another.
private struct PlanStep: View {
    let course: LearnCourse
    let start: Lesson?
    let goal: Answer?
    /// The course's art, as on the Learn tab: the instrument's render or photograph, or the course emblem.
    let artwork: CourseArtwork
    /// The 45-second placement check: on offer, done, or not for this player (nil).
    let check: PlanCheck?
    @Binding var minutes: Int
    @Binding var reminder: Date
    @Binding var reminderOn: Bool
    let onCheck: () -> Void
    let onStart: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var shown = false

    private var accent: Color { Palette.accent(course.accent) }

    private var startUnit: Int? {
        guard let start else { return nil }
        return course.units.firstIndex { unit in unit.lessons.contains { $0.id == start.id } }
    }

    /// Up to three units after the starting one.
    private var milestones: [Int] {
        let from = (startUnit ?? 0) + 1
        return Array((from..<max(from, course.units.count)).prefix(3))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header.planReveal(shown, 0, reduceMotion)
                courseCard.planReveal(shown, 1, reduceMotion)
                if let check { checkRow(check).planReveal(shown, 2, reduceMotion) }
                PlanCommitment(goal: goal, minutes: $minutes, reminder: $reminder, reminderOn: $reminderOn)
                    .planReveal(shown, 2, reduceMotion)
                if !milestones.isEmpty { milestoneList }
            }
            .padding(.horizontal, Metrics.gutter).padding(.top, 18).padding(.bottom, 16)
        }
        .scrollBounceBehavior(.basedOnSize)
        // Pinned in the dock, which reserves its height: the goal card and the milestones scroll clear of it.
        .onboardingDock {
            Button("Start my plan") { Haptics.shared.selection(); onStart() }
                .buttonStyle(PrimaryButtonStyle())
                .planReveal(shown, 7, reduceMotion)
                .accessibilityIdentifier("onboarding.plan.start")
        }
        // The rows rise in on their own scoped animation (`planReveal`); the art floats on its own phase animator.
        // Nothing here starts a repeating `withAnimation`, which caught the first layout pass and kept the header
        // and the lesson title sliding over their subtitles.
        .onAppear { shown = true }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Your plan").font(Typeface.display(34)).tracking(-0.6).foregroundStyle(Palette.ink)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)
            subtitle.font(.subheadline).foregroundStyle(Palette.inkSoft)
                .fixedSize(horizontal: false, vertical: true)
                .contentTransition(.opacity)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 8)
    }

    /// Placed players read the placement as a head start: the unit they start at (the course card under it names the
    /// lesson) and that what they know is skipped. Beginners read the course. What Timbre Pro opens is left to the
    /// paywall's Free and Pro table, one screen on, so the plan never shows a lock.
    @ViewBuilder private var subtitle: some View {
        if let startUnit, startUnit > 0 {
            Text("You start at Unit \(startUnit + 1) — skip what you already know.")
        } else {
            Text(course.subtitle.localized)
        }
    }

    /// "Not sure? Take a 45-second check", or, once it has run, that the first lesson follows how they played.
    private func checkRow(_ state: PlanCheck) -> some View {
        Button(action: onCheck) {
            HStack(spacing: 14) {
                Glyph(state == .done ? "checkmark.seal" : "gauge.with.dots.needle.67percent", size: Glyph.lead, tint: accent)
                VStack(alignment: .leading, spacing: 2) {
                    checkTitle(state).font(.headline).foregroundStyle(Palette.ink)
                        .fixedSize(horizontal: false, vertical: true)
                    checkDetail(state).font(.subheadline).foregroundStyle(Palette.inkSoft)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 8)
                if state == .offer {
                    Image(systemName: "chevron.right").font(.system(size: 14, weight: .bold)).foregroundStyle(Palette.inkFaint)
                        .accessibilityHidden(true)
                }
            }
            .stillCard(tint: accent)
        }
        .buttonStyle(PressScaleStyle())
        .disabled(state == .done)
        .accessibilityIdentifier("onboarding.plan.check")
    }

    @ViewBuilder private func checkTitle(_ state: PlanCheck) -> some View {
        if state == .done {
            Text("Placement checked")
        } else {
            // The same key, shown with non-breaking hyphens (U+2011) so "45-second" never splits across lines.
            Text(verbatim: String(localized: "Not sure? Take a 45-second check").replacingOccurrences(of: "-", with: "\u{2011}"))
        }
    }

    @ViewBuilder private func checkDetail(_ state: PlanCheck) -> some View {
        if state == .done { Text("Your first lesson follows how you played.") } else { Text("Change between three chords, then strum.") }
    }

    private var courseCard: some View {
        HStack(alignment: .center, spacing: 0) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    CourseArt(course: course, size: 20)
                    Eyebrow(Text(course.title.localized), color: accent, style: .display).lineLimit(1)
                }
                .foregroundStyle(accent)
                Text("First lesson").font(.subheadline).foregroundStyle(Palette.inkSoft).padding(.top, 6)
                if let start {
                    Text(start.title.localized).font(Typeface.display(24)).tracking(-0.4).foregroundStyle(Palette.ink)
                        .lineLimit(3).fixedSize(horizontal: false, vertical: true)
                        .contentTransition(.opacity)
                }
                if let startUnit {
                    Eyebrow(Text("Unit \(startUnit + 1) · \(course.units[startUnit].title.localized)"), color: Palette.inkSoft, style: .display)
                        .lineLimit(2).fixedSize(horizontal: false, vertical: true)
                        .contentTransition(.opacity)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Spacer(minLength: 8)
            art
        }
        .padding(20)
        .frame(maxWidth: .infinity, minHeight: 170, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: Metrics.cornerHero, style: .continuous)
                .fill(LinearGradient(colors: [accent.opacity(0.26), Palette.stageRaised], startPoint: .topLeading, endPoint: .bottomTrailing))
        )
        .overlay(RoundedRectangle(cornerRadius: Metrics.cornerHero, style: .continuous).strokeBorder(accent.opacity(0.35), lineWidth: 1))
        // A placement check that moves the start swaps the lesson in place: the check's answer arrives in
        // `withAnimation`, and the title and unit cross-fade. No implicit animation sits on the card, so nothing
        // else that changes it (its first layout included) is ever animated.
        .accessibilityElement(children: .combine)
    }

    /// The art floats: a slow sway and rise, scoped to the art (a geometry effect, never its layout).
    @ViewBuilder private var art: some View {
        switch artwork {
        case .instrument(let name, _):
            Image(name).resizable().interpolation(.high).scaledToFit().frame(width: 96, height: 150)
                .floating(rest: -13, raised: -9, rise: 4)
                .shadow(color: .black.opacity(0.6), radius: 16, y: 10)
                .padding(.trailing, -6)
                .accessibilityHidden(true)
        case .emblem(let glyph):
            CourseEmblemTile(glyph: glyph, accent: accent, size: 80)
                .floating(rest: -9, raised: -5, rise: 0, breathe: 0.03)
                .shadow(color: accent.opacity(0.45), radius: 18)
                .padding(.trailing, 4)
        }
    }

    private var milestoneList: some View {
        VStack(alignment: .leading, spacing: 12) {
            Eyebrow("Milestones", color: accent, style: .display).planReveal(shown, 3, reduceMotion)
            VStack(alignment: .leading, spacing: 0) {
                ForEach(Array(milestones.enumerated()), id: \.element) { position, index in
                    milestoneRow(index, last: position == milestones.count - 1, order: 4 + position)
                        .planReveal(shown, 4 + position, reduceMotion)
                }
            }
        }
        .padding(.top, 6)
    }

    private func milestoneRow(_ index: Int, last: Bool, order: Int) -> some View {
        let unit = course.units[index]
        return HStack(alignment: .top, spacing: 14) {
            ZStack {
                Circle().fill(Palette.stage)
                Circle().strokeBorder(accent, lineWidth: 2)
                if last { Image(systemName: "flag.fill").font(.system(size: 9, weight: .bold)).foregroundStyle(accent) }
            }
            .frame(width: 22, height: 22)
            VStack(alignment: .leading, spacing: 3) {
                Eyebrow(Text("Unit \(index + 1) · \(unit.title.localized)"), color: accent, style: .display).lineLimit(1)
                Text(unit.lessons.first?.title.localized ?? unit.title.localized)
                    .font(.body.weight(.semibold)).foregroundStyle(Palette.ink)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.top, 2)
            .padding(.bottom, last ? 0 : 22)
            Spacer(minLength: 0)
        }
        .background(alignment: .topLeading) {
            // The path to the next milestone draws itself downwards.
            if !last {
                Capsule().fill(accent.opacity(0.35)).frame(width: 2)
                    .padding(.top, 26).padding(.bottom, 2)
                    .offset(x: 10)
                    .scaleEffect(x: 1, y: shown ? 1 : 0, anchor: .top)
                    .animation(reduceMotion ? nil : Animation.easeOut(duration: 0.6).delay(0.2 + Double(order) * 0.11), value: shown)
            }
        }
        .accessibilityElement(children: .combine)
    }
}

/// The plan's daily commitment, in the goal's card: minutes a day (5, 10 or 15) and a reminder time.
/// "Remind me" asks for notifications right there; a refusal just leaves the reminder off.
private struct PlanCommitment: View {
    let goal: Answer?
    @Binding var minutes: Int
    @Binding var reminder: Date
    @Binding var reminderOn: Bool
    @State private var asking = false

    static let choices = [5, 10, 15]

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            if let goal {
                goalRow(goal)
                Hairline()
            }
            minutesRow
            reminderRow
        }
        .stillCard()
    }

    private func goalRow(_ goal: Answer) -> some View {
        HStack(spacing: 14) {
            AnswerGlyph(glyph: goal.glyph, selected: false)
            VStack(alignment: .leading, spacing: 2) {
                Text("Your goal").font(.caption).foregroundStyle(Palette.inkSoft)
                Text(goal.title).font(.headline).foregroundStyle(Palette.ink)
            }
            Spacer(minLength: 0)
        }
        .accessibilityElement(children: .combine)
    }

    // MARK: Minutes a day

    /// "Daily practice" on one line, the three lengths under it across the card (one picker, so its pill can
    /// slide): side by side, the label had to wrap beside the picker on a phone.
    private var minutesRow: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                rowIcon("timer", tint: Palette.amber)
                Text("Daily practice").font(.subheadline.weight(.semibold)).foregroundStyle(Palette.ink)
                    .lineLimit(1).minimumScaleFactor(0.8)
            }
            .accessibilityElement(children: .combine)
            minutePicker
        }
    }

    /// The app's segmented pill as wide as the card, three equal segments; the chosen length is the chips' pill of
    /// light and slides to the next choice.
    private var minutePicker: some View {
        SegmentedPill(options: Self.choices, selection: $minutes, identifier: { "onboarding.minutes.\($0)" }) { value in
            Text(Duration.seconds(value * 60), format: .units(allowed: [.minutes], width: .abbreviated))
                .font(Typeface.label(14)).monospacedDigit()
        }
    }

    // MARK: Reminder

    /// The time and "Remind me"; under each other when the type is large.
    private var reminderRow: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 10) {
                reminderTime
                Spacer(minLength: 6)
                remindButton
            }
            VStack(alignment: .leading, spacing: 10) {
                reminderTime
                remindButton
            }
        }
        .onChange(of: reminder) { _, time in
            // A new time while the reminder is on re-plans it (permission is already there).
            guard reminderOn else { return }
            Task { await PracticeReminder.enable(at: ReminderTime.minutes(of: time)) }
        }
    }

    private var reminderTime: some View {
        HStack(spacing: 10) {
            rowIcon(reminderOn ? "bell.badge.fill" : "bell.fill", tint: reminderOn ? Palette.mint : Palette.amber)
            DatePicker("Daily practice reminder", selection: $reminder, displayedComponents: .hourAndMinute)
                .labelsHidden()
                .datePickerStyle(.compact)
                .tint(Palette.mint)
                .fixedSize()
                .accessibilityIdentifier("onboarding.reminder.time")
        }
    }

    private var remindButton: some View {
        Button(action: toggleReminder) {
            HStack(spacing: 6) {
                if asking {
                    ProgressView().controlSize(.small).tint(Palette.mint)
                } else if reminderOn {
                    Image(systemName: "checkmark").font(.system(size: 12, weight: .heavy)).transition(.scale.combined(with: .opacity))
                }
                Text("Remind me").lineLimit(1)
            }
            .font(Typeface.label(14))
            .foregroundStyle(reminderOn ? Palette.onAccent : Palette.mint)
            .padding(.horizontal, 14).frame(minHeight: 38)
            .background(Capsule().fill(reminderOn ? AnyShapeStyle(Palette.mint) : AnyShapeStyle(Palette.mint.opacity(0.12))))
            .overlay(Capsule().strokeBorder(Palette.mint.opacity(reminderOn ? 0 : 0.45), lineWidth: 1))
            .fixedSize()
            // The capsule stays 38 pt; the finger gets 44.
            .tapTarget()
        }
        .buttonStyle(PressScaleStyle())
        .disabled(asking)
        .animation(Motion.quick, value: reminderOn)
        .accessibilityAddTraits(reminderOn ? .isSelected : [])
        .accessibilityIdentifier("onboarding.reminder")
    }

    private func rowIcon(_ symbol: String, tint: Color) -> some View {
        Image(systemName: symbol).font(.system(size: 15, weight: .semibold)).foregroundStyle(tint)
            .frame(width: 22)
            .contentTransition(.symbolEffect(.replace))
            .accessibilityHidden(true)
    }

    /// On: asks for notifications (once) and plans the reminders at the chosen time; a refusal leaves it off.
    /// Off again: the reminders are removed.
    private func toggleReminder() {
        Haptics.shared.selection()
        if reminderOn {
            PracticeReminder.disable()
            reminderOn = false
            return
        }
        // Asked here, so the first lesson's results won't offer the reminder again.
        UserDefaults.standard.set(true, forKey: PracticeReminder.askedKey)
        asking = true
        Task { @MainActor in
            let on = await PracticeReminder.enable(at: ReminderTime.minutes(of: reminder))
            asking = false
            withAnimation(Motion.pluck) { reminderOn = on }
            if on { Haptics.shared.lock() }
        }
    }
}

/// The plan's placement check row: on offer, or done.
private enum PlanCheck { case offer, done }

private extension View {
    /// Plan rows fade and rise in one after another; with Reduce Motion they only fade. The animation is scoped
    /// to the fade and the rise, so a row's own layout settling at the same moment is never animated with it.
    func planReveal(_ shown: Bool, _ order: Int, _ reduceMotion: Bool) -> some View {
        let rise = Motion.page.delay(0.08 + Double(order) * 0.11)
        return animation(reduceMotion ? Motion.fade : rise) { content in
            content
                .opacity(shown ? 1 : 0)
                .offset(y: shown || reduceMotion ? 0 : 18)
        }
    }

    /// A slow float for hero art: it sways between two tilts and rises and sinks a little (and, for an emblem,
    /// breathes). It loops on its own phase animator and moves only by geometry effects, so it can never leak into
    /// the layout around it. Still, at rest, with Reduce Motion.
    func floating(rest: Double, raised: Double, rise: CGFloat, breathe: CGFloat = 0) -> some View {
        modifier(Floating(rest: rest, raised: raised, rise: rise, breathe: breathe))
    }
}

private struct Floating: ViewModifier {
    let rest: Double
    let raised: Double
    let rise: CGFloat
    let breathe: CGFloat
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @ViewBuilder func body(content: Content) -> some View {
        if reduceMotion {
            content
                .rotationEffect(.degrees(rest))
                .offset(y: rise)
                .scaleEffect(1 - breathe)
        } else {
            content.phaseAnimator([false, true]) { view, up in
                view
                    .rotationEffect(.degrees(up ? raised : rest))
                    .offset(y: up ? -rise : rise)
                    .scaleEffect(up ? 1 + breathe : 1 - breathe)
            } animation: { _ in
                Animation.easeInOut(duration: 3.2)
            }
        }
    }
}

/// A soft cone of light falling from the top edge.
private struct Spotlight: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX - rect.width * 0.09, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.midX + rect.width * 0.09, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.midX + rect.width * 0.32, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.midX - rect.width * 0.32, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

/// Chips in rows, lined up at the leading edge, a chip that wouldn't fit whole starting the next row.
private struct ChipFlow: Layout {
    var spacing: CGFloat = 8
    var rowSpacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let rows = Self.rows(subviews, width: proposal.width ?? .infinity, spacing: spacing)
        let height = rows.reduce(CGFloat(0)) { $0 + $1.height } + rowSpacing * CGFloat(max(0, rows.count - 1))
        return CGSize(width: proposal.width ?? (rows.map(\.width).max() ?? 0), height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var y = bounds.minY
        for row in Self.rows(subviews, width: bounds.width, spacing: spacing) {
            var x = bounds.minX
            for index in row.items {
                let size = subviews[index].sizeThatFits(.unspecified)
                let width = min(size.width, bounds.width)
                subviews[index].place(at: CGPoint(x: x, y: y + (row.height - size.height) / 2),
                                      proposal: ProposedViewSize(width: width, height: size.height))
                x += width + spacing
            }
            y += row.height + rowSpacing
        }
    }

    private struct Row {
        var items: [Int] = []
        var width: CGFloat = 0
        var height: CGFloat = 0
    }

    private static func rows(_ subviews: Subviews, width: CGFloat, spacing: CGFloat) -> [Row] {
        var rows: [Row] = []
        var row = Row()
        for index in subviews.indices {
            let size = subviews[index].sizeThatFits(.unspecified)
            let chip = min(size.width, width)
            if !row.items.isEmpty && row.width + spacing + chip > width {
                rows.append(row)
                row = Row()
            }
            row.width += (row.items.isEmpty ? 0 : spacing) + chip
            row.height = max(row.height, size.height)
            row.items.append(index)
        }
        if !row.items.isEmpty { rows.append(row) }
        return rows
    }
}
