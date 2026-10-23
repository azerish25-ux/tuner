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
    /// Unanswered until the player picks; Continue waits for an answer.
    @State private var level: String?
    @State private var goal: String?
    @State private var showPaywall = false
    @State private var restoring = false
    @State private var restoreMessage: String?
    @State private var floating = false
    /// The plan's commitment: minutes a day and the reminder time ("Remind me" turns it on there).
    @State private var dailyMinutes = 10
    @State private var reminderTime = PlanCommitment.defaultTime
    @State private var reminderOn = false
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
                .padding(.horizontal, 28).padding(.top, 12)
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
                .transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity), removal: .move(edge: .leading).combined(with: .opacity)))
                .id(step)
                .frame(maxHeight: .infinity)
            }
        }
        .animation(Motion.settle, value: step)
        .fullScreenCover(isPresented: $showPaywall, onDismiss: finish) {
            PaywallView(context: .onboarding).environmentObject(store).environmentObject(store.commerce)
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
                                              "minutes": String(dailyMinutes), "reminder": reminderOn ? "on" : "off"])
    }

    /// Spotlit instrument, the promise, and the instrument picker in one screen.
    private var welcome: some View {
        VStack(alignment: .leading, spacing: 0) {
            ZStack(alignment: .top) {
                Spotlight().fill(LinearGradient(colors: [Color(hex: 0xFFC48C).opacity(0.16), Color(hex: 0xFFC48C).opacity(0.03)], startPoint: .top, endPoint: .bottom))
                    .blur(radius: 6)
                    .ignoresSafeArea(edges: .top)
                Text("TIMBRE").font(Typeface.label(15)).tracking(9).foregroundStyle(Palette.amber).padding(.top, 34)
                    .frame(maxWidth: .infinity)
                Ellipse().fill(RadialGradient(colors: [Color(hex: 0xFFC48C).opacity(0.22), .clear], center: .center, startRadius: 2, endRadius: 170))
                    .frame(width: 320, height: 46).frame(maxHeight: .infinity, alignment: .bottom).padding(.bottom, 6)
                Image(heroImage(selectedChoice)).resizable().interpolation(.high).scaledToFit()
                    .id(instrumentID ?? "voice")
                    .transition(.asymmetric(insertion: .scale(scale: 0.92).combined(with: .opacity), removal: .opacity))
                    .shadow(color: .black.opacity(0.65), radius: 26, y: 18)
                    .rotationEffect(.degrees(floating ? -9 : -13))
                    .offset(y: floating ? -6 : 6)
                    .padding(.top, 70).padding(.bottom, 26)
                    .frame(maxWidth: .infinity)
                    .accessibilityHidden(true)
            }
            .frame(maxHeight: .infinity)
            VStack(alignment: .leading, spacing: 12) {
                Text("Tune until it\nstands still.").font(Typeface.display(40)).tracking(-1).foregroundStyle(Palette.ink)
                    .fixedSize(horizontal: false, vertical: true).accessibilityAddTraits(.isHeader)
                Text("A precision tuner, hundreds of lessons that listen as you play, and a daily quest to keep you going.")
                    .font(.body).foregroundStyle(Palette.inkSoft).fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 28)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(choices) { choice in
                        let selected = instrumentID == choice.id
                        Button {
                            withAnimation(Motion.pluck) { instrumentID = choice.id }
                            Haptics.shared.selection()
                        } label: {
                            HStack(spacing: 7) {
                                Text(choice.title).font(.subheadline.weight(.semibold))
                                    .foregroundStyle(selected ? Color(hex: 0xC9FFEC) : Palette.ink)
                                // Tuned in Chromatic on the free plan; its own stage is Pro.
                                if needsPro(choice) { ProBadge() }
                            }
                            .padding(.horizontal, 18).frame(height: 44)
                            .background(Capsule().fill(selected ? Palette.mint.opacity(0.10) : Palette.stageRaised))
                            .overlay(Capsule().strokeBorder(selected ? Palette.mint : Palette.line, lineWidth: selected ? 1.5 : 1))
                        }
                        .buttonStyle(PressScaleStyle())
                        .accessibilityAddTraits(selected ? .isSelected : [])
                        .accessibilityIdentifier("onboarding.instrument.\(choice.id ?? "voice")")
                    }
                }
                .padding(.horizontal, 28)
            }
            .padding(.top, 18)
            Button("Get started") { next() }.buttonStyle(BrassButtonStyle()).padding(.horizontal, 22).padding(.top, 22)
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
                    .frame(maxWidth: .infinity).padding(.horizontal, 28).padding(.bottom, 6)
            }
        }
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 3.2).repeatForever(autoreverses: true)) { floating = true }
        }
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
        [("beginner", "Just starting", "leaf.fill"), ("intermediate", "A few years", "music.note"), ("advanced", "Many years", "star.fill"), ("pro", "I play professionally", "crown.fill")]
    }

    private var goalOptions: [(String, LocalizedStringKey, String)] {
        [("tune", "Tune fast and precisely", "tuningfork"), ("practice", "Practice every day", "calendar"), ("ear", "Train my ear", "ear.fill"), ("voice", "Sing in tune", "music.mic"), ("rhythm", "Keep better time", "metronome.fill")]
    }

    private func options(_ items: [(String, LocalizedStringKey, String)], selection: Binding<String?>) -> some View {
        VStack(spacing: 10) {
            ForEach(items, id: \.0) { item in
                let selected = selection.wrappedValue == item.0
                Button {
                    withAnimation(Motion.pluck) { selection.wrappedValue = item.0 }
                    Haptics.shared.selection()
                } label: {
                    HStack(spacing: 14) {
                        IconOrb(symbol: item.2, size: 40)
                        Text(item.1).font(.headline).foregroundStyle(Palette.ink)
                        Spacer()
                        Image(systemName: selected ? "checkmark.circle.fill" : "circle").foregroundStyle(selected ? Palette.brass : Palette.inkFaint)
                            .contentTransition(.symbolEffect(.replace))
                    }
                    .padding(14)
                    .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(selected ? Palette.brass.opacity(0.14) : Palette.stageRaised.opacity(0.8)))
                    .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).strokeBorder(selected ? Palette.brass : Palette.line, lineWidth: 1))
                    .contentShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                }
                .buttonStyle(PressScaleStyle())
                .accessibilityAddTraits(selected ? .isSelected : [])
                .accessibilityIdentifier("onboarding.option.\(item.0)")
            }
        }
    }

    /// Continue waits, neutral and clearly inactive but readable, until a question is answered.
    private func continueButton(enabled: Bool) -> some View {
        Button("Continue") { next() }
            .buttonStyle(ContinueButtonStyle(enabled: enabled))
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
        .padding(.horizontal, 24).padding(.vertical, 18)
    }

    private var goals: some View {
        VStack(alignment: .leading, spacing: 18) {
            question("What matters most?", "Your daily set is built around it.")
            options(goalOptions, selection: $goal)
            Spacer()
            continueButton(enabled: goal != nil)
        }
        .padding(.horizontal, 24).padding(.vertical, 18)
    }

    private var microphone: some View {
        VStack(spacing: 22) {
            Spacer()
            ZStack {
                ForEach(0..<3, id: \.self) { ring in
                    Circle().strokeBorder(Palette.brass.opacity(0.3 - Double(ring) * 0.08), lineWidth: 1.5).frame(width: 130 + CGFloat(ring) * 60, height: 130 + CGFloat(ring) * 60)
                }
                Image(systemName: "mic.fill").font(.system(size: 54)).foregroundStyle(Palette.brass)
            }
            .frame(height: 260)
            Text("Timbre listens\nto your instrument").font(Typeface.display(34)).tracking(-0.6).multilineTextAlignment(.center).foregroundStyle(Palette.ink)
            Text("Pitch is measured on your iPhone. Recordings are never saved or uploaded.").multilineTextAlignment(.center).foregroundStyle(Palette.inkSoft).padding(.horizontal, 30)
            Spacer()
            Button("Allow microphone") {
                Task {
                    _ = await AVAudioApplication.requestRecordPermission()
                    afterMicrophone()
                }
            }
            .buttonStyle(BrassButtonStyle()).padding(.horizontal, 28)
            .accessibilityIdentifier("onboarding.microphone")
            Button("Not now") { afterMicrophone() }.font(.subheadline).foregroundStyle(Palette.inkSoft).padding(.bottom, 14)
        }
    }

    /// The plan from the answers: the course, where the placement starts, the goal and the next milestones.
    @ViewBuilder private var plan: some View {
        let instrument = instrumentID.flatMap { store.catalog.instrument(id: $0)?.id }
        let answeredGoal = goal ?? "tune"
        let goalOption = goalOptions.first { $0.0 == answeredGoal }
        if let course = store.onboardingCourse(instrumentId: instrument, goal: answeredGoal) {
            let progress = store.onboardingProgress(level: level ?? "beginner", instrumentId: instrument, goal: answeredGoal)
            let start = progress.nextLesson(in: course)
            PlanStep(course: course, start: start, goal: goalOption, artwork: CourseArtwork.of(course, catalog: store.catalog),
                     minutes: $dailyMinutes, reminder: $reminderTime, reminderOn: $reminderOn, onStart: { startPlan() })
        } else {
            VStack {
                Spacer()
                Button("Start my plan") { startPlan() }.buttonStyle(BrassButtonStyle()).padding(.horizontal, 24).padding(.bottom, 14)
                    .accessibilityIdentifier("onboarding.plan.start")
            }
        }
    }

    private func question(_ title: LocalizedStringKey, _ detail: LocalizedStringKey) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(Typeface.display(32)).tracking(-0.6).foregroundStyle(Palette.ink).fixedSize(horizontal: false, vertical: true)
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
    @Binding var minutes: Int
    @Binding var reminder: Date
    @Binding var reminderOn: Bool
    let onStart: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var shown = false
    @State private var floating = false

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
                    PlanCommitment(goal: goal, minutes: $minutes, reminder: $reminder, reminderOn: $reminderOn)
                        .planReveal(shown, 2, reduceMotion)
                    if !milestones.isEmpty { milestoneList }
                }
                .padding(.horizontal, 24).padding(.top, 18).padding(.bottom, 16)
            }
            .scrollBounceBehavior(.basedOnSize)
            Button("Start my plan") { Haptics.shared.selection(); onStart() }
                .buttonStyle(BrassButtonStyle())
                .padding(.horizontal, 24).padding(.top, 8).padding(.bottom, 14)
                .planReveal(shown, 7, reduceMotion)
                .accessibilityIdentifier("onboarding.plan.start")
        }
        .onAppear {
            shown = true
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 3.2).repeatForever(autoreverses: true)) { floating = true }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Your plan").font(Typeface.display(34)).tracking(-0.6).foregroundStyle(Palette.ink)
                .accessibilityAddTraits(.isHeader)
            Text(course.subtitle.localized).font(.subheadline).foregroundStyle(Palette.inkSoft)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.top, 8)
    }

    private var courseCard: some View {
        HStack(alignment: .center, spacing: 0) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    CourseArt(course: course, size: 20)
                    Text(course.title.localized.uppercased()).font(Typeface.label(12)).tracking(1.2).lineLimit(1)
                }
                .foregroundStyle(accent)
                Text("First lesson").font(.subheadline).foregroundStyle(Palette.inkSoft).padding(.top, 6)
                if let start {
                    Text(start.title.localized).font(Typeface.display(24)).tracking(-0.4).foregroundStyle(Palette.ink)
                        .lineLimit(3).fixedSize(horizontal: false, vertical: true)
                }
                if let startUnit {
                    Text("UNIT \(startUnit + 1) · \(course.units[startUnit].title.localized.uppercased())")
                        .font(Typeface.label(11)).tracking(1.1).foregroundStyle(Palette.inkSoft).lineLimit(1)
                }
            }
            Spacer(minLength: 8)
            art
        }
        .padding(20)
        .frame(maxWidth: .infinity, minHeight: 170, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(LinearGradient(colors: [accent.opacity(0.26), Palette.stageRaised], startPoint: .topLeading, endPoint: .bottomTrailing))
        )
        .overlay(RoundedRectangle(cornerRadius: 28, style: .continuous).strokeBorder(accent.opacity(0.35), lineWidth: 1))
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder private var art: some View {
        switch artwork {
        case .instrument(let name, _):
            Image(name).resizable().interpolation(.high).scaledToFit().frame(width: 96, height: 150)
                .rotationEffect(.degrees(floating ? -9 : -13))
                .offset(y: floating ? -4 : 4)
                .shadow(color: .black.opacity(0.6), radius: 16, y: 10)
                .padding(.trailing, -6)
                .accessibilityHidden(true)
        case .emblem(let glyph):
            CourseEmblemTile(glyph: glyph, accent: accent, size: 80)
                .rotationEffect(.degrees(floating ? -5 : -9))
                .shadow(color: accent.opacity(0.45), radius: 18)
                .scaleEffect(floating ? 1.03 : 0.97)
                .padding(.trailing, 4)
        }
    }

    private var milestoneList: some View {
        VStack(alignment: .leading, spacing: 12) {
            Eyebrow("Milestones", color: accent).planReveal(shown, 3, reduceMotion)
            VStack(alignment: .leading, spacing: 0) {
                ForEach(Array(milestones.enumerated()), id: \.element) { position, index in
                    milestoneRow(index, last: position == milestones.count - 1)
                        .planReveal(shown, 4 + position, reduceMotion)
                }
            }
        }
        .padding(.top, 6)
    }

    private func milestoneRow(_ index: Int, last: Bool) -> some View {
        let unit = course.units[index]
        return HStack(alignment: .top, spacing: 14) {
            ZStack {
                Circle().fill(Palette.stage)
                Circle().strokeBorder(accent, lineWidth: 2)
                if last { Image(systemName: "flag.fill").font(.system(size: 9, weight: .bold)).foregroundStyle(accent) }
            }
            .frame(width: 22, height: 22)
            VStack(alignment: .leading, spacing: 3) {
                Text("UNIT \(index + 1) · \(unit.title.localized.uppercased())")
                    .font(Typeface.label(11)).tracking(1.1).foregroundStyle(accent).lineLimit(1)
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
    @Namespace private var pill

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
                Rectangle().fill(Palette.line).frame(height: 1).accessibilityHidden(true)
            }
            minutesRow
            reminderRow
        }
        .stillCard(padding: 14)
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

    /// "Daily practice" and the three lengths (one picker, so its pill can slide; the words wrap if they must).
    private var minutesRow: some View {
        HStack(spacing: 10) {
            rowIcon("timer", tint: Palette.amber)
            Text("Daily practice").font(.subheadline.weight(.semibold)).foregroundStyle(Palette.ink)
                .lineLimit(2).minimumScaleFactor(0.85)
            Spacer(minLength: 6)
            minutePicker
        }
    }

    /// A segmented capsule; the mint pill slides to the chosen length.
    private var minutePicker: some View {
        HStack(spacing: 2) {
            ForEach(Self.choices, id: \.self) { value in minuteChip(value) }
        }
        .padding(3)
        .background(Capsule().fill(Palette.surface))
        .overlay(Capsule().strokeBorder(Palette.line, lineWidth: 1))
        .fixedSize()
    }

    private func minuteChip(_ value: Int) -> some View {
        let selected = minutes == value
        return Button {
            withAnimation(Motion.pluck) { minutes = value }
            Haptics.shared.selection()
        } label: {
            Text(Duration.seconds(value * 60), format: .units(allowed: [.minutes], width: .abbreviated))
                .font(Typeface.label(13)).monospacedDigit()
                .foregroundStyle(selected ? Palette.onAccent : Palette.inkSoft)
                .padding(.horizontal, 11).frame(minHeight: 36)
                .background {
                    if selected { Capsule().fill(Palette.mint).matchedGeometryEffect(id: "minutes", in: pill) }
                }
                .contentShape(Capsule())
        }
        .buttonStyle(PressScaleStyle())
        .accessibilityAddTraits(selected ? .isSelected : [])
        .accessibilityIdentifier("onboarding.minutes.\(value)")
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
            .contentShape(Capsule())
            .fixedSize()
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

/// The mint primary button once enabled; before that a graphite capsule with grey text
/// (about 4.8:1 against its fill), so it reads as waiting rather than as a dim green button.
private struct ContinueButtonStyle: ButtonStyle {
    let enabled: Bool
    @ViewBuilder func makeBody(configuration: Configuration) -> some View {
        if enabled {
            BrassButtonStyle().makeBody(configuration: configuration)
        } else {
            configuration.label
                .font(.headline)
                .foregroundStyle(Palette.inkFaint)
                .frame(maxWidth: .infinity, minHeight: 54)
                .padding(.horizontal, 18)
                .background(Capsule().fill(Palette.surface))
                .overlay(Capsule().strokeBorder(Palette.line, lineWidth: 1))
        }
    }
}

private extension View {
    /// Plan rows fade and rise in one after another; with Reduce Motion they only fade.
    func planReveal(_ shown: Bool, _ order: Int, _ reduceMotion: Bool) -> some View {
        let rise = Animation.spring(response: 0.62, dampingFraction: 0.86).delay(0.08 + Double(order) * 0.11)
        return opacity(shown ? 1 : 0)
            .offset(y: shown || reduceMotion ? 0 : 18)
            .animation(reduceMotion ? Animation.easeOut(duration: 0.3) : rise, value: shown)
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
