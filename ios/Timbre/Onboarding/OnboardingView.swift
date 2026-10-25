import AVFoundation
import SwiftUI
import TimbreCore
import UIKit

struct OnboardingView: View {
    @EnvironmentObject private var store: AppStore
    /// Observed so the Pro badges on the instrument chips go when a restore unlocks everything.
    @EnvironmentObject private var commerce: CommerceService
    @State private var step = 0
    @State private var instrumentID: String? = "guitar.acoustic.6"
    /// The welcome screen shows every instrument in rows, after "more".
    @State private var allInstruments = false
    /// Unanswered until the player picks; Continue waits for an answer.
    @State private var level: String?
    @State private var goal: String?
    @State private var showPaywall = false
    @State private var restoring = false
    @State private var restoreMessage: String?
    /// The plan's commitment: minutes a day and the reminder time ("Remind me" turns it on there).
    @State private var dailyMinutes = 10
    @State private var reminderTime = PlanCommitment.defaultTime
    @State private var reminderOn = false
    /// The placement check is up, and the answer it started from once it has run.
    @State private var checking = false
    @State private var checkedFrom: String?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// Welcome, experience, goal, microphone, first tune, plan.
    private let steps = 6

    var body: some View {
        ZStack {
            StageBackground()
            VStack(spacing: 0) {
                HStack(spacing: 6) {
                    ForEach(0..<steps, id: \.self) { index in
                        Capsule().fill(index <= step ? Palette.mint : Palette.line).frame(height: 4)
                    }
                }
                .padding(.horizontal, Metrics.gutter).padding(.top, 12)
                .opacity(step == 0 ? 0 : 1)
                Group {
                    switch step {
                    case 0: welcome
                    case 1: experience
                    case 2: goals
                    case 3: microphone
                    case 4: firstTune
                    default: plan
                    }
                }
                .transition(.adaptive(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity),
                                                  removal: .move(edge: .leading).combined(with: .opacity)),
                                      reduceMotion: reduceMotion))
                .id(step)
                .frame(maxHeight: .infinity)
            }
        }
        .animation(Motion.adaptive(Motion.page, reduceMotion: reduceMotion), value: step)
        .fullScreenCover(isPresented: $showPaywall, onDismiss: finish) {
            PaywallView(context: .onboarding, answers: PaywallAnswers(instrumentId: instrumentID, level: level ?? "beginner", goal: goal ?? "tune", minutes: dailyMinutes))
                .environmentObject(store).environmentObject(store.commerce)
        }
    }

    private func next() { Haptics.shared.selection(); step += 1 }

    /// After the microphone question: the first tune when Timbre can hear the instrument, then the plan.
    /// "Not now", a denial, or "Voice or other" go straight to the plan.
    private func afterMicrophone() {
        if FirstTuneSetup.canListen, FirstTuneSetup.make(store: store, instrumentID: instrumentID) != nil {
            next()
        } else {
            Haptics.shared.selection()
            step = Self.planStep
        }
    }

    private static let planStep = 5

    /// "Pluck your thickest string" on the live stage; locking it (or Skip) leads to the plan.
    @ViewBuilder private var firstTune: some View {
        if let setup = FirstTuneSetup.make(store: store, instrumentID: instrumentID) {
            FirstTuneStep(setup: setup) { _ in step = Self.planStep }
        } else {
            plan
        }
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
                                              "placement_check": checkedFrom == nil ? "no" : "yes"])
    }

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
                Text("Tune until it\nstands still.").font(Typeface.display(40)).tracking(-1).foregroundStyle(Palette.ink)
                    .fixedSize(horizontal: false, vertical: true).accessibilityAddTraits(.isHeader)
                // "Today" is the daily three-activity set everywhere; "quest" means a side goal.
                Text("A precision tuner, hundreds of lessons that listen as you play, and a Today plan to keep you going.")
                    .font(.body).foregroundStyle(Palette.inkSoft).fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, Metrics.gutter)
            instrumentPicker
                .padding(.top, 18)
            Button("Get started") { next() }.buttonStyle(PrimaryButtonStyle()).padding(.horizontal, Metrics.gutter).padding(.top, 22)
                .accessibilityIdentifier("onboarding.start")
            Button {
                restoring = true
                restoreMessage = nil
                Task {
                    await store.commerce.restore()
                    restoring = false
                    if store.commerce.isPro { next() } else { restoreMessage = store.commerce.error }
                }
            } label: {
                if restoring { ProgressView().tint(Palette.inkSoft) } else { Text("I already have Timbre Pro").underline() }
            }
            .font(.footnote).foregroundStyle(Palette.inkSoft).frame(maxWidth: .infinity).frame(height: 44).padding(.bottom, 4)
            .disabled(restoring)
            .accessibilityIdentifier("onboarding.restore")
            if let restoreMessage {
                Text(restoreMessage).font(.caption).foregroundStyle(Palette.inkSoft).multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity).padding(.horizontal, Metrics.gutter + Metrics.proseInset).padding(.bottom, 6)
            }
        }
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
                Text(choice.title).lineLimit(1)
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

    /// A Pro instrument for a free player (`AccessPolicy`): the welcome chip wears the Pro badge. Of the chips, that is
    /// mandolin and banjo; guitar, bass, ukulele, violin and cello tune free.
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

    private struct Choice: Identifiable { let id: String?; let title: LocalizedStringKey; let photo: String?; let symbol: String? }
    private var choices: [Choice] {
        [Choice(id: "guitar.acoustic.6", title: "Guitar", photo: "01_guitar_acoustic_guitar", symbol: nil),
         Choice(id: "bass.electric.4", title: "Bass", photo: "06_bass_4_string_p_bass", symbol: nil),
         Choice(id: "ukulele.soprano.4", title: "Ukulele", photo: "10_ukulele_soprano_ukulele", symbol: nil),
         Choice(id: "violin.standard.4", title: "Violin", photo: "17_bowed_strings_violin", symbol: nil),
         Choice(id: "cello.standard.4", title: "Cello", photo: "19_bowed_strings_cello", symbol: nil),
         Choice(id: "mandolin.standard.8", title: "Mandolin", photo: "13_mandolin_mandolin", symbol: nil),
         Choice(id: "banjo.five.5", title: "Banjo", photo: "22_folk_world_strings_banjo_5_string", symbol: nil),
         Choice(id: nil, title: "Voice or other", photo: nil, symbol: "dot.radiowaves.left.and.right")]
    }

    private var levelOptions: [(String, LocalizedStringKey, String)] {
        // Each answer starts the course at its own unit (`CoursePlacement`): unit 1, after the basics, the mid-course
        // chords and songs, the barre and lead units, and past them.
        [("beginner", "Just starting", "leaf.fill"), ("novice", "A few months", "music.note"), ("intermediate", "A few years", "music.quarternote.3"),
         ("advanced", "Many years", "star.fill"), ("pro", "I play professionally", "crown.fill")]
    }

    private var goalOptions: [(String, LocalizedStringKey, String)] {
        [("tune", "Tune fast and precisely", "tuningfork"), ("practice", "Practice every day", "calendar"), ("ear", "Train my ear", "ear.fill"), ("voice", "Sing in tune", "music.mic"), ("rhythm", "Keep better time", "metronome.fill")]
    }

    private func options(_ items: [(String, LocalizedStringKey, String)], selection: Binding<String?>) -> some View {
        VStack(spacing: 10) {
            ForEach(items, id: \.0) { item in
                let selected = selection.wrappedValue == item.0
                let row = RoundedRectangle(cornerRadius: Metrics.cornerTile, style: .continuous)
                Button {
                    withAnimation(Motion.pluck) { selection.wrappedValue = item.0 }
                    Haptics.shared.selection()
                } label: {
                    HStack(spacing: 14) {
                        IconOrb(symbol: item.2, size: 40)
                        Text(item.1).font(.headline).foregroundStyle(Palette.ink)
                        Spacer()
                        Image(systemName: selected ? "checkmark.circle.fill" : "circle").foregroundStyle(selected ? Palette.mint : Palette.inkFaint)
                            .contentTransition(.symbolEffect(.replace))
                    }
                    .padding(14)
                    .background(row.fill(selected ? Palette.mint.opacity(0.14) : Palette.stageRaised.opacity(0.8)))
                    .overlay(row.strokeBorder(selected ? Palette.mint : Palette.controlLine, lineWidth: 1))
                    .contentShape(row)
                }
                .buttonStyle(PressScaleStyle())
                .accessibilityAddTraits(selected ? .isSelected : [])
                .accessibilityIdentifier("onboarding.option.\(item.0)")
            }
        }
    }

    /// Continue waits, neutral and clearly inactive but readable (the primary button's disabled look), until a
    /// question is answered.
    private func continueButton(enabled: Bool) -> some View {
        Button("Continue") { next() }
            .buttonStyle(PrimaryButtonStyle())
            .disabled(!enabled)
            .animation(Motion.quick, value: enabled)
            .accessibilityIdentifier("onboarding.continue")
    }

    private var experience: some View {
        VStack(alignment: .leading, spacing: 18) {
            question("How long have you been playing?", "Exercises start where you are.")
            options(levelOptions, selection: $level)
            Spacer()
            continueButton(enabled: level != nil)
        }
        .padding(.horizontal, Metrics.gutter).padding(.vertical, 18)
    }

    private var goals: some View {
        VStack(alignment: .leading, spacing: 18) {
            question("What matters most?", "Your Today plan is built around it.")
            options(goalOptions, selection: $goal)
            Spacer()
            continueButton(enabled: goal != nil)
        }
        .padding(.horizontal, Metrics.gutter).padding(.vertical, 18)
    }

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
            Text("Timbre listens\nto your instrument").font(Typeface.display(34)).tracking(-0.6).multilineTextAlignment(.center).foregroundStyle(Palette.ink)
            Text("Pitch is measured on your iPhone. Recordings are never saved or uploaded.").multilineTextAlignment(.center).foregroundStyle(Palette.inkSoft)
                .padding(.horizontal, Metrics.gutter + Metrics.proseInset)
            Spacer()
            Button("Allow microphone") {
                Task {
                    _ = await AVAudioApplication.requestRecordPermission()
                    afterMicrophone()
                }
            }
            .buttonStyle(PrimaryButtonStyle()).padding(.horizontal, Metrics.gutter)
            .accessibilityIdentifier("onboarding.microphone")
            Button { afterMicrophone() } label: {
                Text("Not now").font(.subheadline).foregroundStyle(Palette.inkSoft)
                    .frame(maxWidth: .infinity, minHeight: Metrics.minTarget).contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .padding(.bottom, 4)
        }
    }

    /// The plan from the answers: the course, where the placement starts, the goal and the next milestones.
    @ViewBuilder private var plan: some View {
        let instrument = instrumentID.flatMap { store.catalog.instrument(id: $0)?.id }
        let answeredGoal = goal ?? "tune"
        let goalOption = goalOptions.first { $0.0 == answeredGoal }
        if let course = store.onboardingCourse(instrumentId: instrument, goal: answeredGoal) {
            let answered = level ?? "beginner"
            // The same placement the paywall's "Today" and the lesson Learn opens use (`AppStore.onboardingProgress`).
            let progress = store.onboardingProgress(level: answered, instrumentId: instrument, goal: answeredGoal)
            let start = progress.nextLesson(in: course)
            let checkSteps = placementCheckSteps(course)
            PlanStep(course: course, start: start, goal: goalOption, artwork: CourseArtwork.of(course, catalog: store.catalog),
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
            VStack {
                Spacer()
                Button("Start my plan") { startPlan() }.buttonStyle(PrimaryButtonStyle()).padding(.horizontal, Metrics.gutter).padding(.bottom, 14)
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

    private func question(_ title: LocalizedStringKey, _ detail: LocalizedStringKey) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(Typeface.display(32)).tracking(-0.6).foregroundStyle(Palette.ink).fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)
            Text(detail).font(.subheadline).foregroundStyle(Palette.inkSoft)
        }
        .padding(.top, 8)
    }
}

/// "Your plan": the course card with the first lesson after placement, the goal with the daily commitment
/// (minutes a day, a reminder), and the first lessons of the next units as milestones. Rows rise in one after another.
private struct PlanStep: View {
    let course: LearnCourse
    let start: Lesson?
    let goal: (String, LocalizedStringKey, String)?
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
        VStack(spacing: 0) {
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
            Button("Start my plan") { Haptics.shared.selection(); onStart() }
                .buttonStyle(PrimaryButtonStyle())
                .padding(.horizontal, Metrics.gutter).padding(.top, 8).padding(.bottom, 14)
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

    /// Placed players read the placement as a head start, after a skip-ahead mark in the course's colour: the unit
    /// they start at (the course card under it names the lesson) and that what they know is skipped. Beginners read
    /// the course. What Timbre Pro opens is left to the paywall's Free and Pro table, one screen on, so the plan never
    /// shows a lock.
    @ViewBuilder private var subtitle: some View {
        if let startUnit, startUnit > 0 {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Image(systemName: "forward.fill").font(.caption.weight(.bold)).foregroundStyle(accent)
                    .accessibilityHidden(true)
                Text("You start at Unit \(startUnit + 1) — skip what you already know.")
            }
        } else {
            Text(course.subtitle.localized)
        }
    }

    /// "Not sure? Take a 45-second check", or, once it has run, that the first lesson follows how they played.
    private func checkRow(_ state: PlanCheck) -> some View {
        Button(action: onCheck) {
            HStack(spacing: 14) {
                IconOrb(symbol: state == .done ? "checkmark.seal.fill" : "gauge.with.dots.needle.67percent", tint: accent, size: 40)
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
    let goal: (String, LocalizedStringKey, String)?
    @Binding var minutes: Int
    @Binding var reminder: Date
    @Binding var reminderOn: Bool
    @State private var asking = false

    static let choices = [5, 10, 15]

    /// Today at the reminder's time: 7 pm unless one was chosen before.
    static var defaultTime: Date {
        let minutes = PracticeReminder.minutes
        return Calendar.current.date(bySettingHour: minutes / 60, minute: minutes % 60, second: 0, of: Date()) ?? Date()
    }

    static func minutesOfDay(_ date: Date) -> Int {
        let time = Calendar.current.dateComponents([.hour, .minute], from: date)
        return (time.hour ?? 19) * 60 + (time.minute ?? 0)
    }

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

    private func goalRow(_ goal: (String, LocalizedStringKey, String)) -> some View {
        HStack(spacing: 14) {
            IconOrb(symbol: goal.2, tint: Palette.amber, size: 44)
            VStack(alignment: .leading, spacing: 2) {
                Text("Your goal").font(.caption).foregroundStyle(Palette.inkSoft)
                Text(goal.1).font(.headline).foregroundStyle(Palette.ink)
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
            Task { await PracticeReminder.enable(at: Self.minutesOfDay(time)) }
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
            let on = await PracticeReminder.enable(at: Self.minutesOfDay(reminder))
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
