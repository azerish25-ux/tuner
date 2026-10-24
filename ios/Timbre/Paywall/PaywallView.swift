import StoreKit
import SwiftUI
import TimbreCore
import UIKit
import UserNotifications

struct PaywallView: View {
    enum Context { case onboarding, standard }
    var context: Context = .standard
    /// Onboarding's answers, not saved yet while the paywall shows: the outcomes and milestones follow the plan
    /// the plan screen just built. Without them the saved goal, course and daily minutes are used.
    var answers: PaywallAnswers? = nil
    @EnvironmentObject private var store: AppStore
    @EnvironmentObject private var commerce: CommerceService
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var typeSize
    @Environment(\.locale) private var locale
    @State private var selectedID = TimbreProduct.annual
    @State private var appeared = false
    /// Notifications are off for Timbre: no reminder can arrive, so none is promised.
    @State private var remindersBlocked = false
    /// The plan track draws itself in from Today.
    @State private var trackDrawn = false
    /// "What's in Pro" is open: the Free and Pro table shows under it.
    @State private var detailsOpen = false
    /// The table's Free and Pro columns grow with the text.
    @ScaledMetric(relativeTo: .caption) private var cellWidth: CGFloat = 50
    // Measured layout. The headline, the plans, the whole plan track and the button show without scrolling;
    // the outcomes, "What's in Pro" and the hero fill what is left, in that order, and what does not fit
    // waits just below the fold. Nothing rests under the pinned bar.
    @State private var containerHeight: CGFloat = 0
    @State private var barHeight: CGFloat = 0
    @State private var headerHeight: CGFloat = 34
    @State private var outcomesHeight: CGFloat = 92
    /// "What's in Pro" closed: the table opens below what is measured, so opening it never reshuffles the fold.
    @State private var detailsHeight: CGFloat = 16
    @State private var offerHeight: CGFloat = 230
    /// The track with the free trial on it, and the plan's own track (no trial selected), each as last measured.
    @State private var trialTrackHeight: CGFloat = 96
    @State private var planTrackHeight: CGFloat = 92

    /// The yearly plan unless the storefront left it out.
    private var selected: Product? { commerce.products.first { $0.id == selectedID } ?? commerce.products.first }

    /// Works both as a presented sheet (dismiss) and as the root overlay (the store flag).
    private func close() {
        if context == .standard { store.showPaywall = false }
        dismiss()
    }

    var body: some View {
        let pitch = self.pitch
        let plan = PaywallPlan.make(store: store, answers: answers, horizon: planHorizon, reason: context == .standard ? store.paywallReason : nil)
        ZStack(alignment: .topTrailing) {
            Palette.stage.ignoresSafeArea()
            RadialGradient(colors: [Color(hex: 0xFFC48C).opacity(0.16), .clear], center: UnitPoint(x: 0.5, y: 0.12), startRadius: 10, endRadius: 320)
                .ignoresSafeArea()
            // The height between the safe-area edges; the scroll content starts at the top one.
            Color.clear
                .onGeometryChange(for: CGFloat.self) { proxy in proxy.size.height } action: { height in containerHeight = height }
                .accessibilityHidden(true)
            ScrollView {
                content(pitch, plan: plan)
            }
            .scrollIndicators(.hidden)
            .scrollBounceBehavior(.basedOnSize)
            // Pinned and opaque: the fine print scrolls under a short fade, never through the button.
            .safeAreaInset(edge: .bottom, spacing: 0) {
                bottomBar.onGeometryChange(for: CGFloat.self) { proxy in proxy.size.height } action: { height in barHeight = height }
            }
            closeButton
        }
        .preferredColorScheme(.dark)
        .task { await commerce.load() }
        .task { remindersBlocked = await TrialReminder.isBlocked() }
        .onAppear { appeared = true }
        .onChange(of: scenePhase) { _, phase in
            // The person may have switched notifications on or off in Settings meanwhile.
            guard phase == .active else { return }
            Task { remindersBlocked = await TrialReminder.isBlocked() }
        }
        .onChange(of: commerce.isPro) { _, pro in if pro { close() } }
    }

    // MARK: Layout

    /// Visible height above the pinned bar.
    private var viewport: CGFloat { containerHeight > 0 ? max(0, containerHeight - barHeight) : 600 }

    /// The track's room. While a trial is on offer (or may be, while the plans load) the trial's track keeps its
    /// place, so choosing Monthly never resizes the hero under the finger; otherwise the plan's own track.
    private func trackReserve(_ plan: PaywallPlan) -> CGFloat {
        let trial = commerce.products.isEmpty || trialOffered ? trialTrackHeight : 0
        return max(trial, plan.milestones.isEmpty ? 0 : planTrackHeight)
    }

    /// Headline (with its top inset), plans and trust row, and the plan track: what must show.
    private func essentials(_ plan: PaywallPlan) -> CGFloat { headerHeight + Self.headerTop + offerHeight + trackReserve(plan) }

    /// The Pro pill on its own row, when there is no hero for it to stand in.
    private static let pillRow: CGFloat = 40
    private static let previewTop: CGFloat = 6
    /// The hero grows to this; below its own minimum (`PaywallHero.minHeight`) it steps aside for the pill alone.
    private static let previewMax: CGFloat = 236
    private static let headerTop: CGFloat = 12
    private static let outcomesTop: CGFloat = 12
    private static let detailsTop: CGFloat = 6
    private static let trackTop: CGFloat = 14

    /// Where each part of the pitch goes: above the fold when it fits, else just below it.
    private struct Fold {
        /// 0: no hero, the Pro pill stands on its own row.
        var preview: CGFloat = 0
        var outcomes = true
        /// "What's in Pro", under the outcomes.
        var details = true
    }

    /// The room beside the essentials goes to the outcomes, then "What's in Pro" under them, then the hero (its
    /// minimum, then its growth). When not even the pill fits, the page scrolls anyway and everything stays in
    /// reading order above the fine print. A locked lesson's card replaces the hero.
    private func fold(_ pitch: Pitch, plan: PaywallPlan, hero: PaywallHero) -> Fold {
        var left = viewport - essentials(plan)
        guard left >= Self.pillRow else { return Fold() }
        var result = Fold()
        result.outcomes = left - Self.pillRow >= Self.outcomesTop + outcomesHeight
        if result.outcomes { left -= Self.outcomesTop + outcomesHeight }
        result.details = result.outcomes && left - Self.pillRow >= Self.detailsTop + detailsHeight
        if result.details { left -= Self.detailsTop + detailsHeight }
        let heroFloor = Self.previewTop + hero.minHeight
        if pitch.lesson == nil && left >= heroFloor {
            let growth = min(left - heroFloor, Self.previewMax - hero.minHeight)
            result.preview = hero.minHeight + growth
        }
        return result
    }

    /// Days the milestones may reach: the free trial's, else two weeks.
    private var planHorizon: Int { commerce.annual.map { trialDays($0) } ?? 14 }

    private func content(_ pitch: Pitch, plan: PaywallPlan) -> some View {
        let hero = self.hero(pitch, plan: plan)
        let layout = fold(pitch, plan: plan, hero: hero)
        let steps = trackSteps(plan)
        let trial = showsTrial
        return VStack(spacing: 0) {
            VStack(spacing: 0) {
                if layout.preview > 0 {
                    preview(hero, plan: plan, height: layout.preview).padding(.top, Self.previewTop)
                } else {
                    PaywallProPill().padding(.top, 14)
                }
                header(pitch)
                    .onGeometryChange(for: CGFloat.self) { proxy in proxy.size.height } action: { height in headerHeight = height }
                    .padding(.top, layout.preview > 0 ? Self.headerTop : 10)
                if layout.outcomes {
                    outcomeList(plan).padding(.top, Self.outcomesTop)
                    if layout.details { proDetails.padding(.top, Self.detailsTop) }
                }
                offer
                    .onGeometryChange(for: CGFloat.self) { proxy in proxy.size.height } action: { height in offerHeight = height }
                // Today, the plan's first days and, with a free trial, its reminder and first charge: one track.
                if !steps.isEmpty {
                    planTrack(steps).padding(.top, Self.trackTop)
                        .onGeometryChange(for: CGFloat.self) { proxy in proxy.size.height } action: { height in
                            if trial { trialTrackHeight = height } else { planTrackHeight = height }
                        }
                        .transition(.opacity)
                }
            }
            // Everything that sells rests above the bar; the rest waits below the fold, past its fade.
            .frame(minHeight: viewport, alignment: .top)
            belowFold(plan, layout: layout)
            finePrint.padding(.top, 32)
        }
        .padding(.horizontal, 20).padding(.bottom, 12)
        .frame(maxWidth: 520)
        .frame(maxWidth: .infinity)
    }

    /// The outcomes and "What's in Pro", or just "What's in Pro", when they did not fit above the fold.
    @ViewBuilder private func belowFold(_ plan: PaywallPlan, layout: Fold) -> some View {
        if !layout.outcomes {
            VStack(spacing: Self.detailsTop) {
                outcomeList(plan)
                proDetails
            }
            .padding(.top, 28)
        } else if !layout.details {
            proDetails.padding(.top, 28)
        }
    }

    private var closeButton: some View {
        Button { close() } label: {
            Image(systemName: "xmark").font(.body.weight(.bold)).foregroundStyle(Palette.ink)
                .frame(width: 44, height: 44).background(Circle().fill(Palette.surface))
        }
        .padding(.trailing, 18).padding(.top, 8)
        .accessibilityLabel("Close").accessibilityIdentifier("paywall.close")
    }

    // MARK: Pitch

    /// What the paywall leads with: the person's plan, or what they just tried to open. The outcomes under the
    /// headline follow the same reason (`PaywallPlan`), so the headline stands alone.
    private struct Pitch {
        var headline: Text
        var lesson: LockedLesson? = nil
        /// The instrument to stand in the hero instead of the person's own.
        var instrumentAsset: String? = nil
    }

    private struct LockedLesson {
        let course: LearnCourse
        let unitNumber: Int
        let unitTitle: String
        let lesson: Lesson
    }

    private var pitch: Pitch {
        // Onboarding comes straight from "Start my plan"; the outcomes below tell what the plan brings.
        let generic = Pitch(headline: Text("Unlock your full plan"))
        guard context == .standard, let reason = store.paywallReason else { return generic }
        switch reason {
        case "lesson":
            guard let locked = lockedLesson else { return generic }
            return Pitch(headline: Text("Keep going: \(locked.unitTitle)"), lesson: locked)
        case "instrument", "tuning":
            return instrumentPitch
        case "journey":
            return Pitch(headline: Text("See yourself improve"))
        case "custom_tuning":
            return Pitch(headline: Text("Unlimited custom tunings and string health"))
        case "temperament", "capo", "transpose":
            return Pitch(headline: Text("Temperaments, custom tunings and written pitch"))
        case "voice":
            return Pitch(headline: Text("Sing in tune"))
        default:
            break
        }
        // One line: the outcomes under it already promise every practice tool.
        if reason.hasSuffix("drone") { return Pitch(headline: Text("Unlock the Tanpura drone")) }
        if reason.hasPrefix("ear.") { return Pitch(headline: Text("Every ear game and practice tool")) }
        if reason.hasPrefix("metronome.") { return Pitch(headline: Text("Keep better time")) }
        if reason.hasPrefix("practice.") || reason.hasPrefix("daily.") {
            return Pitch(headline: Text("Every instrument.\nEvery practice tool."))
        }
        return generic
    }

    /// "Tune your cello, and 59 more instruments", with that instrument in the spotlight.
    private var instrumentPitch: Pitch {
        let others = max(0, store.catalog.instruments.count - 1)
        guard let instrument = store.paywallInstrumentId.flatMap({ store.catalog.instrument(id: $0) }) else {
            return Pitch(headline: Text("Tune all \(others + 1) instruments"))
        }
        let photo = store.catalog.photo(instrumentId: instrument.id)
        let name = photo.map { NSLocalizedString("timbre_photo_" + $0.asset, bundle: .main, value: $0.label, comment: "") } ?? instrument.name.localized
        return Pitch(headline: Text("Tune your \(midSentence(name)), and \(others) more instruments"), instrumentAsset: photo?.asset)
    }

    /// An instrument's name inside an English sentence ("your cello"): its capital goes, unless the name opens on a
    /// proper word or a note letter ("Greek bouzouki", "B-flat clarinet"). Other languages keep the name as it is.
    private func midSentence(_ name: String) -> String {
        guard locale.language.languageCode == .english, let word = name.split(separator: " ").first else { return name }
        let proper: Set<String> = ["Greek", "Irish", "Arabic", "French", "Renaissance", "Appalachian", "Mexican"]
        let head = word.split(separator: "-").first ?? word
        guard !proper.contains(String(word)), head.count > 1, !word.dropFirst().contains(where: \.isUppercase) else { return name }
        return name.prefix(1).lowercased() + String(name.dropFirst())
    }

    /// The lesson that opened the paywall; without one, the first lesson Pro opens from where
    /// the learner stands in the course on screen.
    private var lockedLesson: LockedLesson? {
        let curriculum = store.curriculum
        if let id = store.paywallLessonId, let found = curriculum.lesson(id: id) { return locked(found.lesson, in: found.course) }
        let courseId = UserDefaults.standard.string(forKey: "learn.course") ?? store.learn.lastCourseId ?? "guitar"
        guard let course = curriculum.course(id: courseId) ?? curriculum.courses.first else { return nil }
        let lessons = course.lessons
        let from = store.learn.nextLesson(in: course).flatMap { next in lessons.firstIndex { $0.id == next.id } } ?? 0
        let lesson = lessons[from...].first { !store.canPlay($0) } ?? lessons.first { !store.canPlay($0) }
        return lesson.flatMap { locked($0, in: course) }
    }

    private func locked(_ lesson: Lesson, in course: LearnCourse) -> LockedLesson? {
        guard let unit = course.units.firstIndex(where: { unit in unit.lessons.contains { $0.id == lesson.id } }) else { return nil }
        return LockedLesson(course: course, unitNumber: unit + 1, unitTitle: course.units[unit].title.localized, lesson: lesson)
    }

    // MARK: Hero

    /// One scene across the full width, looping, with the Timbre Pro pill under it: the person's instrument (or the
    /// one they just tried to open) with its strings running on as a play-along runway, a lane per string, and the
    /// combo; or the scene of the tool that opened the paywall.
    private func preview(_ hero: PaywallHero, plan: PaywallPlan, height: CGFloat) -> some View {
        PaywallPreview(hero: hero, accent: plan.accent, height: height)
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared || reduceMotion ? 0 : 12)
            .animation(.spring(response: 0.9, dampingFraction: 0.85), value: appeared)
    }

    /// The tool's own scene when a tool opened the paywall, else the instrument and its runway (lessons, songs,
    /// instruments and the plan).
    private func hero(_ pitch: Pitch, plan: PaywallPlan) -> PaywallHero {
        if let tool = heroTool { return .tool(tool) }
        let figure = heroFigure(pitch, plan: plan)
        return .runway(figure.figure, lanes: lanes(figure.instrumentId))
    }

    /// The tool that opened the paywall: the drone (the Tanpura), an ear game (the interval staircase), Pitch
    /// Sniper or the tuner's precision (the scope), the metronome (its beat). Onboarding's ear and rhythm goals
    /// show their tool too; every other plan keeps the instrument.
    private var heroTool: PaywallTool? {
        guard context == .standard else {
            switch answers?.goal {
            case "ear": return .staircase
            case "rhythm": return .beat(bpm: store.bpm, beats: store.beats)
            default: return nil
            }
        }
        guard let reason = store.paywallReason else { return nil }
        if reason.hasSuffix("drone") {
            // As the Drone screen names them: the tonic in the player's note names, Pa or Ma on the first string.
            let fifth = UserDefaults.standard.string(forKey: "drone.firstString") != "ma"
            return .drone(tonic: VoiceNoteName.name(store.droneMidi, notation: store.settings.notation), fifth: fifth)
        }
        if reason.hasPrefix("ear.") || reason == "daily.ear" { return .staircase }
        if reason.contains("sniper") || reason == "precision" { return .scope }
        if reason.hasPrefix("metronome.") || reason == "daily.rhythm" { return .beat(bpm: store.bpm, beats: store.beats) }
        return nil
    }

    /// The instrument they just tried to open, else their own (onboarding's answer, or the one they tune), as the
    /// app pictures it; else the course's instrument; without one (singing), the course's emblem.
    private func heroFigure(_ pitch: Pitch, plan: PaywallPlan) -> (figure: PaywallFigure, instrumentId: String?) {
        if let asset = pitch.instrumentAsset { return (PaywallFigure.instrument(asset: asset), store.paywallInstrumentId) }
        for id in [plan.instrumentId, plan.course?.instrument].compactMap({ $0 }) {
            if let asset = photoAsset(id) { return (PaywallFigure.instrument(asset: asset), id) }
        }
        if let course = plan.course, case .emblem(let glyph) = CourseArtwork.of(course, catalog: store.catalog) {
            return (PaywallFigure.emblem(glyph), nil)
        }
        return (PaywallFigure.emblem(.note), nil)
    }

    /// The photograph the tuner shows: the variant the person picked for the instrument they tune, else the first.
    private func photoAsset(_ instrumentId: String) -> String? {
        if instrumentId == store.instrument.id, let asset = store.photo?.asset { return asset }
        return store.catalog.photo(instrumentId: instrumentId)?.asset
    }

    /// One runway lane per string of the instrument's standard tuning (paired strings count once), four otherwise.
    private func lanes(_ instrumentId: String?) -> Int {
        guard let id = instrumentId, let instrument = store.catalog.instrument(id: id),
              let tuning = store.catalog.tuning(id: instrument.defaultTuningId) else { return 4 }
        return min(7, max(3, tuning.coursesByAnchor.count))
    }

    /// Studio render when the instrument has one, otherwise its photograph (the locked lesson's card).
    private func card(_ asset: String) -> String {
        if let model = ModelLibrary.modelID(forPhoto: asset), ModelLibrary.hasCard(model) { return ModelLibrary.cardImageName(model) }
        return store.catalog.photos.first { $0.asset == asset }?.thumbnail ?? asset
    }

    // MARK: Header

    private func header(_ pitch: Pitch) -> some View {
        VStack(spacing: 0) {
            pitch.headline.font(Typeface.display(26)).tracking(-0.6)
                .multilineTextAlignment(.center).foregroundStyle(Palette.ink)
                .lineLimit(3).minimumScaleFactor(0.8)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)
            if let lesson = pitch.lesson { lessonCard(lesson).padding(.top, 14) }
        }
        .frame(maxWidth: .infinity)
    }

    /// The locked lesson: its unit, title and length, behind a gold lock.
    private func lessonCard(_ locked: LockedLesson) -> some View {
        let accent = Palette.accent(locked.course.accent)
        let shape = RoundedRectangle(cornerRadius: 20, style: .continuous)
        return HStack(spacing: 14) {
            lessonArt(locked.course, accent: accent)
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Image(systemName: locked.course.symbol).font(.system(size: 10, weight: .bold)).accessibilityHidden(true)
                    Text("UNIT \(locked.unitNumber)").font(Typeface.label(11)).tracking(1.1)
                }
                .foregroundStyle(accent)
                Text(locked.lesson.title.localized).font(.headline).foregroundStyle(Palette.ink)
                    .lineLimit(2).fixedSize(horizontal: false, vertical: true)
                Text("\(locked.lesson.minutes) min · +\(locked.lesson.xp) XP").font(.caption).foregroundStyle(Palette.inkSoft)
            }
            Spacer(minLength: 8)
            Image(systemName: "lock.fill").font(.system(size: 13, weight: .bold)).foregroundStyle(Color(hex: 0x1B1206))
                .frame(width: 30, height: 30)
                .background(Circle().fill(Palette.proGold))
                .accessibilityHidden(true)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(shape.fill(LinearGradient(colors: [accent.opacity(0.22), Palette.stageRaised], startPoint: .topLeading, endPoint: .bottomTrailing)))
        .overlay(shape.strokeBorder(accent.opacity(0.35), lineWidth: 1))
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("paywall.lesson")
    }

    @ViewBuilder private func lessonArt(_ course: LearnCourse, accent: Color) -> some View {
        if let asset = course.instrument.flatMap({ store.catalog.photo(instrumentId: $0)?.asset }) {
            Image(card(asset)).resizable().interpolation(.high).scaledToFit()
                .frame(width: 40, height: 58)
                .rotationEffect(.degrees(-10))
                .shadow(color: .black.opacity(0.55), radius: 8, y: 5)
                .accessibilityHidden(true)
        } else {
            IconOrb(symbol: course.symbol, tint: accent, size: 44)
        }
    }

    // MARK: Outcomes

    private static let benefitArt: CGFloat = 26

    /// Three results for the person's goal, each with its own art; they slide in one after another.
    private func outcomeList(_ plan: PaywallPlan) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            ForEach(Array(plan.outcomes.enumerated()), id: \.element.id) { index, outcome in
                HStack(spacing: 10) {
                    outcomeArt(outcome.art)
                        .frame(width: Self.benefitArt, height: Self.benefitArt)
                        .accessibilityHidden(true)
                    // One line in English; longer translations wrap rather than truncate.
                    outcome.text.font(.subheadline.weight(.medium)).foregroundStyle(Palette.ink)
                        .lineLimit(2).minimumScaleFactor(0.85).fixedSize(horizontal: false, vertical: true)
                }
                .opacity(appeared ? 1 : 0)
                .offset(x: appeared || reduceMotion ? 0 : -10)
                .animation(.spring(response: 0.6, dampingFraction: 0.85).delay(0.12 + Double(index) * 0.09), value: appeared)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 6)
        .onGeometryChange(for: CGFloat.self) { proxy in proxy.size.height } action: { height in outcomesHeight = height }
    }

    @ViewBuilder private func outcomeArt(_ art: PaywallPlan.Art) -> some View {
        switch art {
        case .course(let course):
            CourseArt(course: course, size: Self.benefitArt)
        case .glyph(let glyph, let accent):
            CourseEmblemTile(glyph: glyph, accent: accent, size: Self.benefitArt)
        case .instrument(let id):
            if let image = CourseArtwork.instrumentImage(id, catalog: store.catalog) {
                InstrumentTile(image: image.name, render: image.render, accent: Palette.mint, size: Self.benefitArt)
            } else {
                CourseEmblemTile(glyph: .note, accent: Palette.mint, size: Self.benefitArt)
            }
        case .symbol(let symbol, let accent):
            SymbolTile(symbol: symbol, accent: accent, size: Self.benefitArt)
        }
    }

    // MARK: What's in Pro

    /// "What's in Pro" under the outcomes, lined up with their text; it opens the Free and Pro table in place.
    private var proDetails: some View {
        VStack(alignment: .leading, spacing: 10) {
            detailsToggle
                .onGeometryChange(for: CGFloat.self) { proxy in proxy.size.height } action: { height in detailsHeight = height }
            if detailsOpen {
                proTable
                    .transition(reduceMotion ? AnyTransition.opacity
                                : AnyTransition.asymmetric(insertion: .opacity.combined(with: .scale(scale: 0.97, anchor: .top)), removal: .opacity))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var detailsToggle: some View {
        Button(action: toggleDetails) {
            HStack(spacing: 5) {
                Text("What’s in Pro")
                Image(systemName: "chevron.down").font(.system(size: 10, weight: .bold))
                    .rotationEffect(.degrees(detailsOpen ? 180 : 0))
                    .accessibilityHidden(true)
            }
            .font(.caption.weight(.semibold))
            .foregroundStyle(Palette.mint)
            .lineLimit(1).minimumScaleFactor(0.8)
            // A full-size target without taking more room in the fold.
            .padding(.vertical, 12).padding(.trailing, 16)
            .contentShape(Rectangle())
            .padding(.vertical, -12).padding(.trailing, -16)
        }
        .buttonStyle(.plain)
        .padding(.leading, 6 + Self.benefitArt + 10)
        .accessibilityValue(detailsOpen ? Text("Expanded") : Text("Collapsed"))
        .accessibilityIdentifier("paywall.details")
    }

    private func toggleDetails() {
        withAnimation(reduceMotion ? Animation.easeOut(duration: 0.2) : Motion.settle) { detailsOpen.toggle() }
        Haptics.shared.selection()
        if detailsOpen { Analytics.log("paywall_details", ["reason": context == .onboarding ? "onboarding" : (store.paywallReason ?? "unknown")]) }
    }

    /// A row of the table: what it is, and what Free and Pro each give.
    private struct ProRow: Identifiable {
        enum Cell { case count(Int), included, excluded }
        let id: String
        let label: Text
        let free: Cell
        let pro: Cell
    }

    /// Free against Pro as the app enforces it: instruments and lessons by `AccessPolicy` (free instruments, free
    /// lessons), the tools by their own locks (the metronome's basics and Pitch Sniper are free; interval and chord
    /// ear drills, the Pro tools, strobe, temperaments and custom tunings are Pro).
    private var proRows: [ProRow] {
        let instruments = store.catalog.instruments
        let lessons = store.curriculum.courses.flatMap(\.lessons)
        return [
            ProRow(id: "instruments", label: Text("Instruments to tune"),
                   free: .count(instruments.filter(\.isFree).count), pro: .count(instruments.count)),
            ProRow(id: "lessons", label: Text("Lessons in \(store.curriculum.courses.count) courses"),
                   free: .count(lessons.filter(\.free).count), pro: .count(lessons.count)),
            ProRow(id: "free", label: Text("Metronome and Pitch Sniper"), free: .included, pro: .included),
            ProRow(id: "ear", label: Text("Name intervals and chords by ear"), free: .excluded, pro: .included),
            ProRow(id: "tools", label: Text("Chords, scales, intonation and drone"), free: .excluded, pro: .included),
            ProRow(id: "precision", label: Text("Strobe, temperaments and custom tunings"), free: .excluded, pro: .included),
        ]
    }

    /// The table: a header, six rows on hairlines, the Pro column on a gold wash; the free chromatic tuner under it.
    private var proTable: some View {
        let shape = RoundedRectangle(cornerRadius: 16, style: .continuous)
        return VStack(alignment: .leading, spacing: 8) {
            VStack(spacing: 0) {
                HStack(spacing: 0) {
                    Spacer(minLength: 0)
                    Text("Free").font(.caption.weight(.semibold)).foregroundStyle(Palette.inkSoft)
                        .lineLimit(1).minimumScaleFactor(0.7)
                        .frame(width: cellWidth)
                    ProBadge().frame(width: cellWidth)
                }
                .padding(.vertical, 8)
                .accessibilityHidden(true)
                ForEach(proRows) { row in
                    Rectangle().fill(Palette.line).frame(height: 1).accessibilityHidden(true)
                    proRow(row)
                }
            }
            .padding(.horizontal, 12).padding(.bottom, 2)
            .background(alignment: .trailing) {
                RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Color(hex: 0xFFD08A).opacity(0.07))
                    .frame(width: cellWidth)
                    .padding(.trailing, 12).padding(.vertical, 4)
            }
            .background(shape.fill(Palette.stageRaised))
            .overlay(shape.strokeBorder(Palette.line, lineWidth: 1))
            Text("The chromatic tuner stays free for any instrument.")
                .font(.caption2).foregroundStyle(Palette.inkFaint)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 4)
        }
        .accessibilityIdentifier("paywall.table")
    }

    private func proRow(_ row: ProRow) -> some View {
        HStack(spacing: 0) {
            row.label.font(.footnote).foregroundStyle(Palette.ink)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 8)
            proCell(row.free, pro: false).frame(width: cellWidth)
            proCell(row.pro, pro: true).frame(width: cellWidth)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(row.label)
        .accessibilityValue(Text("Free: \(spoken(row.free)), Pro: \(spoken(row.pro))"))
    }

    @ViewBuilder private func proCell(_ cell: ProRow.Cell, pro: Bool) -> some View {
        switch cell {
        case .count(let value):
            Text(value, format: .number).font(Typeface.number(14)).foregroundStyle(pro ? Palette.ink : Palette.inkSoft)
                .lineLimit(1).minimumScaleFactor(0.7)
        case .included:
            Image(systemName: "checkmark").font(.system(size: 12, weight: .heavy)).foregroundStyle(pro ? Palette.mint : Palette.inkSoft)
        case .excluded:
            Image(systemName: "minus").font(.system(size: 12, weight: .bold)).foregroundStyle(Palette.inkFaint)
        }
    }

    private func spoken(_ cell: ProRow.Cell) -> Text {
        switch cell {
        case .count(let value): return Text(value, format: .number)
        case .included: return Text("Included")
        case .excluded: return Text("Not included")
        }
    }

    // MARK: Plans

    /// The plans and the trust line under them.
    private var offer: some View {
        VStack(spacing: 0) {
            // Room above the first row for its tag.
            plans.padding(.top, 14).animation(Motion.settle, value: commerce.products.isEmpty)
            trustRow.padding(.top, 10)
        }
    }

    @ViewBuilder private var plans: some View {
        if commerce.products.isEmpty {
            if commerce.loading {
                planSkeleton
            } else {
                VStack(spacing: 10) {
                    Text(commerce.error ?? String(localized: "Plans are loading.")).font(.subheadline).foregroundStyle(Palette.inkSoft).multilineTextAlignment(.center)
                    Button("Try again") { Task { await commerce.load() } }.buttonStyle(BrassButtonStyle(prominent: false))
                }
            }
        } else {
            VStack(spacing: 8) {
                if let annual = commerce.annual {
                    planRow(annual, title: "Yearly", detail: perMonth(annual), tag: annualTag(annual), saving: annualSaving, anchor: annualAnchor)
                }
                if let monthly = commerce.monthly {
                    planRow(monthly, title: "Monthly", detail: String(localized: "cancel anytime"), tag: nil, saving: nil)
                }
                if let lifetime = commerce.lifetime {
                    planRow(lifetime, title: "Lifetime", detail: String(localized: "pay once"), tag: nil, saving: nil)
                }
            }
            .transition(.opacity)
        }
    }

    /// Holds the plans' place while StoreKit answers, so nothing jumps when they arrive.
    private var planSkeleton: some View {
        VStack(spacing: 8) {
            ForEach(0..<3, id: \.self) { _ in
                RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Palette.stageRaised).frame(height: 58)
            }
        }
        .overlay { ProgressView().tint(Palette.mint) }
    }

    private func perMonth(_ product: Product) -> String {
        String(localized: "\((product.price / 12).formatted(product.priceFormatStyle)) a month")
    }

    private func annualTag(_ annual: Product) -> String {
        commerce.trialLabel != nil ? String(localized: "\(trialDays(annual)) days free") : String(localized: "Best value")
    }

    /// Whole percent the yearly plan saves against twelve monthly payments, rounded down.
    /// Nil without a monthly plan or when the saving is under 10%.
    private var annualSaving: Int? {
        guard let annual = commerce.annual, let monthly = commerce.monthly, monthly.price > 0 else { return nil }
        let twelveMonths = monthly.price * 12
        var percent = (twelveMonths - annual.price) / twelveMonths * 100
        var whole = Decimal()
        NSDecimalRound(&whole, &percent, 0, .down)
        let value = NSDecimalNumber(decimal: whole).intValue
        return value >= 10 ? value : nil
    }

    /// The year at the monthly price, struck through over the yearly price: twelve of the storefront's own monthly
    /// payments in its own currency, never a made-up figure. Shown only beside the saving it backs up.
    private var annualAnchor: String? {
        guard annualSaving != nil, let monthly = commerce.monthly else { return nil }
        return (monthly.price * 12).formatted(monthly.priceFormatStyle)
    }

    private func select(_ product: Product) {
        guard selected?.id != product.id else { return }
        withAnimation(Motion.quick) { selectedID = product.id }
        Haptics.shared.selection()
    }

    private func planRow(_ product: Product, title: LocalizedStringKey, detail: String, tag: String?, saving: Int?, anchor: String? = nil) -> some View {
        let isSelected = selected?.id == product.id
        let shape = RoundedRectangle(cornerRadius: 18, style: .continuous)
        return Button { select(product) } label: {
            HStack(spacing: 12) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(isSelected ? Palette.mint : Palette.inkFaint)
                    .contentTransition(.symbolEffect(.replace))
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 8) {
                        Text(title).font(.headline).foregroundStyle(Palette.ink)
                        if let saving { saveChip(saving) }
                    }
                    Text(detail).font(.footnote).foregroundStyle(isSelected ? Palette.mint : Palette.inkSoft)
                        .lineLimit(1).minimumScaleFactor(0.8)
                }
                Spacer(minLength: 8)
                VStack(alignment: .trailing, spacing: 0) {
                    if let anchor { anchorPrice(anchor) }
                    Text(product.displayPrice).font(Typeface.number(19)).foregroundStyle(Palette.ink)
                        .lineLimit(1).minimumScaleFactor(0.7)
                }
            }
            .padding(.horizontal, 14).padding(.vertical, 9)
            .background(shape.fill(isSelected ? Palette.mint.opacity(0.08) : Palette.stageRaised))
            .overlay(shape.strokeBorder(isSelected ? Palette.mint : Palette.line, lineWidth: isSelected ? 2 : 1))
            .overlay(alignment: .topTrailing) {
                if let tag { planTag(tag) }
            }
            .shadow(color: Palette.mint.opacity(isSelected ? 0.16 : 0), radius: 14, y: 4)
            .contentShape(shape)
        }
        .buttonStyle(PressScaleStyle())
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityIdentifier("paywall.plan.\(product.id)")
    }

    /// "$83.88", struck through, over the yearly price; VoiceOver says what it is.
    private func anchorPrice(_ anchor: String) -> some View {
        Text(verbatim: anchor).strikethrough(true, color: Palette.inkFaint)
            .font(Typeface.number(12)).foregroundStyle(Palette.inkFaint)
            .lineLimit(1).minimumScaleFactor(0.7)
            .accessibilityLabel(Text("\(anchor) if paid monthly"))
    }

    private func planTag(_ text: String) -> some View {
        Text(text.uppercased()).font(.system(size: 10, weight: .heavy)).tracking(0.6).foregroundStyle(Palette.onAccent)
            .padding(.horizontal, 9).padding(.vertical, 4)
            .background(Capsule().fill(Palette.mint))
            .offset(x: -14, y: -11)
    }

    private func saveChip(_ percent: Int) -> some View {
        Text(String(localized: "Save \(percent)%").uppercased())
            .font(.system(size: 10, weight: .heavy)).tracking(0.5).foregroundStyle(Palette.onAccent)
            .padding(.horizontal, 7).padding(.vertical, 3)
            .background(Capsule().fill(Palette.proGold))
            .lineLimit(1).fixedSize()
    }

    private var trustRow: some View {
        let promise: LocalizedStringKey = selected?.id == TimbreProduct.lifetime ? "Pay once, keep forever" : "Cancel anytime"
        return HStack(spacing: 6) {
            Image(systemName: "lock.shield.fill").foregroundStyle(Palette.mint).accessibilityHidden(true)
            Text("No ads")
            separator
            Text("No account")
            separator
            Text(promise)
        }
        .font(.caption.weight(.medium))
        .foregroundStyle(Palette.inkSoft)
        .lineLimit(1)
        .minimumScaleFactor(0.75)
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
    }

    private var separator: some View {
        Text(verbatim: "·").foregroundStyle(Palette.inkFaint).accessibilityHidden(true)
    }

    // MARK: Track

    /// The selected plan has a free trial: only then does the track promise a reminder and a charge.
    private var showsTrial: Bool { selected?.id == TimbreProduct.annual && commerce.trialLabel != nil }

    /// The yearly plan has a free trial for this person.
    private var trialOffered: Bool { commerce.annual != nil && commerce.trialLabel != nil }

    private struct TrackStep: Identifiable {
        enum Kind { case today, milestone, song, reminder, billing }
        let id: String
        let kind: Kind
        let title: Text
        /// Under the node. Today's is the first lesson, under "Everything unlocked".
        let detail: Text?
        /// What sizes the column: the detail as shown (Today: "Everything unlocked").
        let plain: String
    }

    /// The plan and the free trial on one track. Today unlocks everything and starts the first lesson; the next
    /// thing the plan brings before the reminder follows (its first song, else a unit it starts, never a repeat of
    /// today's lesson). Only when the selected plan has a free trial come the reminder (when notifications can
    /// reach the person) and the first charge, at the product's own trial length and price. Without a trial the
    /// plan's milestones fill the track; without those there is no track.
    private func trackSteps(_ plan: PaywallPlan) -> [TrackStep] {
        let today = TrackStep(id: "today", kind: .today, title: Text("Today"), detail: plan.firstLesson.map { Text(verbatim: $0) },
                              plain: String(localized: "Everything unlocked"))
        guard showsTrial, let product = selected else {
            guard !plan.milestones.isEmpty else { return [] }
            return [today] + plan.milestones.map { milestoneStep($0) }
        }
        let days = trialDays(product)
        let reminder = max(1, days - 2)
        var steps = [today]
        let next = remindersBlocked ? days : reminder
        let ahead = plan.milestones.filter { $0.day > 1 && $0.day < next }
        if let milestone = ahead.first(where: { $0.kind == .song }) ?? ahead.last { steps.append(milestoneStep(milestone)) }
        if !remindersBlocked {
            let remind = String(localized: "We remind you")
            steps.append(TrackStep(id: "reminder", kind: .reminder, title: Text("Day \(reminder)"), detail: Text(verbatim: remind), plain: remind))
        }
        let price = String(localized: "\(product.displayPrice)/year")
        steps.append(TrackStep(id: "billing", kind: .billing, title: Text("Day \(days)"), detail: Text(verbatim: price), plain: price))
        return steps
    }

    /// "Day 2 · Play “Greensleeves”" (the song by its name, not its lesson's), or a unit by its name.
    private func milestoneStep(_ milestone: PaywallPlan.Milestone) -> TrackStep {
        let day = Text("Day \(milestone.day)")
        switch milestone.kind {
        case .song:
            let play = String(localized: "Play “\(milestone.title)”")
            return TrackStep(id: "day\(milestone.day)", kind: .song, title: day, detail: Text(verbatim: play), plain: play)
        case .unit:
            return TrackStep(id: "day\(milestone.day)", kind: .milestone, title: day, detail: Text(verbatim: milestone.title), plain: milestone.title)
        }
    }

    /// The narrowest each column of the track may get, at the caption size its text uses: a milestone, a song
    /// and the reminder fit two lines without a word split across them; Today and the price keep their one line
    /// with little shrinking. `TrackColumns` widens a column to its minimum from those with room to spare.
    private func trackMinimums(_ steps: [TrackStep]) -> [CGFloat] {
        let traits = UITraitCollection(preferredContentSizeCategory: Self.sizeCategory(typeSize))
        let font = UIFont.preferredFont(forTextStyle: .caption1, compatibleWith: traits)
        return steps.map { step in
            switch step.kind {
            case .today, .billing: return Self.textWidth(step.plain, font: font) * 0.8
            case .milestone, .song, .reminder: return Self.twoLineWidth(step.plain, font: font) + 2
            }
        }
    }

    private static func textWidth(_ text: String, font: UIFont) -> CGFloat {
        ceil((text as NSString).size(withAttributes: [.font: font]).width)
    }

    /// The narrowest width that sets `text` on two lines without splitting a word: its best break between words.
    private static func twoLineWidth(_ text: String, font: UIFont) -> CGFloat {
        let words = text.split(whereSeparator: \.isWhitespace).map(String.init)
        guard words.count > 1 else { return textWidth(text, font: font) }
        var best = CGFloat.greatestFiniteMagnitude
        for split in 1..<words.count {
            let first = words[..<split].joined(separator: " ")
            let rest = words[split...].joined(separator: " ")
            best = min(best, max(textWidth(first, font: font), textWidth(rest, font: font)))
        }
        return best
    }

    /// The UIKit size category for the environment's text size, to measure as SwiftUI will draw.
    private static func sizeCategory(_ size: DynamicTypeSize) -> UIContentSizeCategory {
        switch size {
        case .xSmall: return .extraSmall
        case .small: return .small
        case .medium: return .medium
        case .large: return .large
        case .xLarge: return .extraLarge
        case .xxLarge: return .extraExtraLarge
        case .xxxLarge: return .extraExtraExtraLarge
        case .accessibility1: return .accessibilityMedium
        case .accessibility2: return .accessibilityLarge
        case .accessibility3: return .accessibilityExtraLarge
        case .accessibility4: return .accessibilityExtraExtraLarge
        case .accessibility5: return .accessibilityExtraExtraExtraLarge
        @unknown default: return .large
        }
    }

    /// Days on top, nodes on a line, what happens under each. Today's column is wider: it holds the first lesson.
    /// Without notifications the track says how to cancel instead of promising a reminder.
    private func planTrack(_ steps: [TrackStep]) -> some View {
        let lead: CGFloat = steps.count >= 4 ? 0.4 : (steps.count == 3 ? 0.42 : 0.5)
        let last = steps.count - 1
        let days = selected.map { trialDays($0) } ?? 14
        let cancelNote = showsTrial && remindersBlocked
        let minimums = typeSize.isAccessibilitySize ? [] : trackMinimums(steps)
        return VStack(spacing: 5) {
            if typeSize.isAccessibilitySize {
                trackRows(steps)
            } else {
                TrackColumns(lead: lead, minimums: minimums) {
                    ForEach(Array(steps.enumerated()), id: \.element.id) { index, step in
                        step.title.font(Typeface.label(12)).foregroundStyle(trackTint(step.kind, title: true))
                            .lineLimit(1).minimumScaleFactor(0.8)
                            .frame(maxWidth: .infinity, alignment: Self.edge(index, last))
                    }
                }
                trackLine(steps, lead: lead, minimums: minimums)
                TrackColumns(lead: lead, minimums: minimums) {
                    ForEach(Array(steps.enumerated()), id: \.element.id) { index, step in
                        trackDetail(step)
                            .multilineTextAlignment(Self.textEdge(index, last))
                            .frame(maxWidth: .infinity, alignment: Self.edge(index, last))
                    }
                }
                .padding(.top, 1)
            }
            if cancelNote {
                Text("Cancel anytime in Settings before day \(days).")
                    .font(.footnote).foregroundStyle(Palette.inkSoft).multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 2)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(trackSpoken(steps, cancelNote: cancelNote, days: days))
        .onAppear { withAnimation(reduceMotion ? nil : Animation.easeOut(duration: 0.9).delay(0.25)) { trackDrawn = true } }
        .onDisappear { trackDrawn = false }
    }

    /// Today: "Everything unlocked" over the first lesson, a line each at the usual text sizes (VoiceOver reads
    /// the whole title). The price stays on one line. The others keep two lines, so the track keeps its height.
    @ViewBuilder private func trackDetail(_ step: TrackStep) -> some View {
        switch step.kind {
        case .today:
            VStack(alignment: .leading, spacing: 1) {
                Text("Everything unlocked").foregroundStyle(Palette.ink)
                    .lineLimit(1).minimumScaleFactor(0.75)
                if let lesson = step.detail {
                    (Text(Image(systemName: "play.fill")).font(.system(size: 8, weight: .bold)).foregroundStyle(Palette.amber) + Text(verbatim: " ") + lesson)
                        .foregroundStyle(Palette.inkSoft)
                        .lineLimit(typeSize > .large ? 2 : 1).minimumScaleFactor(0.75)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .font(.caption)
        case .billing:
            (step.detail ?? Text(verbatim: "")).font(.caption).foregroundStyle(Palette.inkSoft)
                .lineLimit(1).minimumScaleFactor(0.7)
        case .milestone, .song:
            // Two lines at most, like the reminder's; the column is wide enough that no word splits across them.
            (step.detail ?? Text(verbatim: "")).font(.caption).foregroundStyle(Palette.inkSoft)
                .lineLimit(2).minimumScaleFactor(0.8)
        case .reminder:
            (step.detail ?? Text(verbatim: "")).font(.caption).foregroundStyle(Palette.inkSoft)
                .lineLimit(2, reservesSpace: true).minimumScaleFactor(0.85)
        }
    }

    /// At the accessibility text sizes the track stands as a list, a row per day, so nothing is cut short.
    private func trackRows(_ steps: [TrackStep]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(steps) { step in
                HStack(alignment: .top, spacing: 12) {
                    trackNode(step.kind)
                    VStack(alignment: .leading, spacing: 2) {
                        step.title.font(Typeface.label(12)).foregroundStyle(trackTint(step.kind, title: true))
                        if step.kind == .today { Text("Everything unlocked").font(.caption).foregroundStyle(Palette.ink) }
                        if let detail = step.detail { detail.font(.caption).foregroundStyle(Palette.inkSoft) }
                    }
                    .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// Mint for today and the trial's days, amber for the plan's milestones (titles of the trial's days in ink).
    private func trackTint(_ kind: TrackStep.Kind, title: Bool) -> Color {
        switch kind {
        case .today: return Palette.mint
        case .milestone, .song: return Palette.amber
        case .reminder, .billing: return title ? Palette.ink : Palette.mint
        }
    }

    /// The nodes on a line from Today to the last step; the line draws itself in and each node pops as it passes.
    private func trackLine(_ steps: [TrackStep], lead: CGFloat, minimums: [CGFloat]) -> some View {
        let drawn = trackDrawn || reduceMotion
        let last = steps.count - 1
        return TrackColumns(lead: lead, minimums: minimums) {
            ForEach(Array(steps.enumerated()), id: \.element.id) { index, step in
                trackNode(step.kind)
                    .scaleEffect(drawn ? 1 : 0.6)
                    .opacity(drawn ? 1 : 0.3)
                    .animation(reduceMotion ? nil : Motion.pluck.delay(0.25 + Double(index) * 0.22), value: trackDrawn)
                    .frame(maxWidth: .infinity, alignment: Self.edge(index, last))
            }
        }
        .background {
            ZStack(alignment: .leading) {
                Capsule().fill(Palette.mint.opacity(0.16))
                Capsule().fill(LinearGradient(colors: [Palette.mint, Palette.mint.opacity(0.3)], startPoint: .leading, endPoint: .trailing))
                    .scaleEffect(x: drawn ? 1 : 0.001, anchor: .leading)
            }
            .frame(height: 2)
            .padding(.horizontal, 12)
        }
    }

    private func trackNode(_ kind: TrackStep.Kind) -> some View {
        let symbol: String
        switch kind {
        case .today: symbol = "lock.open.fill"
        case .milestone: symbol = "flag.fill"
        case .song: symbol = "music.note"
        case .reminder: symbol = "bell.fill"
        case .billing: symbol = "creditcard.fill"
        }
        let first = kind == .today
        let tint = trackTint(kind, title: false)
        return Image(systemName: symbol).font(.system(size: 10, weight: .bold))
            .foregroundStyle(first ? Palette.onAccent : tint)
            .frame(width: 24, height: 24)
            .background(Circle().fill(first ? AnyShapeStyle(Palette.mint) : AnyShapeStyle(Palette.stageRaised)))
            .overlay(Circle().strokeBorder(tint.opacity(first ? 0 : 0.45), lineWidth: 1))
            .shadow(color: Palette.mint.opacity(first ? 0.45 : 0), radius: 8)
    }

    /// "Today: Everything unlocked, Three notes on string 2. Day 6: Play “Ode to Joy”. Day 12: We remind you. …" in reading order.
    private func trackSpoken(_ steps: [TrackStep], cancelNote: Bool, days: Int) -> Text {
        var label = Text(verbatim: "")
        for step in steps {
            label = label + step.title + Text(verbatim: ": ")
            if step.kind == .today {
                label = label + Text("Everything unlocked")
                if let lesson = step.detail { label = label + Text(verbatim: ", ") + lesson }
            } else if let detail = step.detail {
                label = label + detail
            }
            label = label + Text(verbatim: ". ")
        }
        if cancelNote { label = label + Text("Cancel anytime in Settings before day \(days).") }
        return label
    }

    private static func edge(_ index: Int, _ last: Int) -> Alignment {
        index == 0 ? .leading : (index == last ? .trailing : .center)
    }

    private static func textEdge(_ index: Int, _ last: Int) -> TextAlignment {
        index == 0 ? .leading : (index == last ? .trailing : .center)
    }

    private func trialDays(_ product: Product) -> Int {
        guard let period = product.subscription?.introductoryOffer?.period else { return 14 }
        switch period.unit {
        case .day: return period.value
        case .week: return period.value * 7
        case .month: return period.value * 30
        default: return 14
        }
    }

    // MARK: Bottom bar

    private var bottomBar: some View {
        VStack(spacing: 0) {
            LinearGradient(colors: [Palette.stage.opacity(0), Palette.stage], startPoint: .top, endPoint: .bottom)
                .frame(height: 24)
                .allowsHitTesting(false)
                .accessibilityHidden(true)
            cta
                .padding(.horizontal, 20).padding(.top, 4).padding(.bottom, 4)
                .frame(maxWidth: 520)
                .frame(maxWidth: .infinity)
                .background(Palette.stage, ignoresSafeAreaEdges: .bottom)
        }
        // The pinned bar must leave room to scroll the plans at the largest text sizes.
        .dynamicTypeSize(...DynamicTypeSize.accessibility1)
    }

    private var ctaTitle: String {
        guard let selected else { return String(localized: "Continue") }
        if selected.id == TimbreProduct.annual, let trial = commerce.trialLabel { return String(localized: "Start \(trial)") }
        if selected.id == TimbreProduct.lifetime { return String(localized: "Unlock for \(selected.displayPrice)") }
        return String(localized: "Subscribe for \(selected.displayPrice)")
    }

    /// What happens after the purchase, in one line next to the button.
    private var terms: String? {
        guard let selected else { return nil }
        switch selected.id {
        case TimbreProduct.annual where commerce.trialLabel != nil:
            return String(localized: "Free for \(trialDays(selected)) days, then \(selected.displayPrice) a year.")
        case TimbreProduct.annual: return String(localized: "\(selected.displayPrice) a year, renews automatically.")
        case TimbreProduct.monthly: return String(localized: "\(selected.displayPrice) a month, renews automatically.")
        default: return String(localized: "One payment. Yours to keep, no subscription.")
        }
    }

    private var cta: some View {
        VStack(spacing: 0) {
            purchaseButton
            if commerce.pending {
                Text("Waiting for approval. Access unlocks when the App Store confirms.").font(.caption).foregroundStyle(Palette.inkSoft)
                    .multilineTextAlignment(.center).padding(.top, 8)
            }
            if let error = commerce.error, !commerce.products.isEmpty {
                Text(error).font(.caption).foregroundStyle(Palette.danger).multilineTextAlignment(.center).padding(.top, 8)
                    .accessibilityIdentifier("commerceError")
            }
            if let terms {
                Text(terms).font(.footnote).foregroundStyle(Palette.inkSoft).multilineTextAlignment(.center)
                    .lineLimit(2).minimumScaleFactor(0.85)
                    .padding(.top, 8)
            }
            if context == .onboarding {
                Button { close() } label: {
                    Text("Continue with the free tuner").font(.subheadline.weight(.semibold)).foregroundStyle(Palette.inkSoft)
                        .padding(.horizontal, 12).padding(.vertical, 6).contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .padding(.top, 4)
                .accessibilityIdentifier("paywall.free")
            }
            links.padding(.top, 2)
        }
    }

    private var purchaseButton: some View {
        Button { purchase() } label: {
            if commerce.purchasing != nil {
                ProgressView().tint(Palette.onAccent)
            } else {
                Text(ctaTitle).font(Typeface.label(18)).lineLimit(1).minimumScaleFactor(0.7)
            }
        }
        .buttonStyle(BrassButtonStyle())
        .disabled(selected == nil || commerce.purchasing != nil || commerce.pending)
        .accessibilityIdentifier("paywall.purchase")
    }

    private func purchase() {
        guard let selected else { return }
        let wasTrial = selected.id == TimbreProduct.annual && commerce.trialLabel != nil
        let days = trialDays(selected)
        let reason = context == .onboarding ? "onboarding" : (store.paywallReason ?? "unknown")
        Task {
            if await commerce.purchase(selected) {
                Analytics.log("purchase", ["product": selected.id, "reason": reason])
                // Notification permission is asked here, after the trial has started, never before.
                if wasTrial { await TrialReminder.schedule(afterDays: days) }
            }
        }
    }

    private var links: some View {
        HStack(spacing: 0) {
            Button { Task { await commerce.restore() } } label: { linkLabel("Restore") }
                .buttonStyle(.plain)
                .disabled(commerce.loading)
            separator
            Link(destination: URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!) { linkLabel("Terms") }
            separator
            Link(destination: URL(string: "https://azerish25-ux.github.io/tuner/privacy.html")!) { linkLabel("Privacy") }
        }
        .font(.footnote.weight(.semibold))
    }

    private func linkLabel(_ title: LocalizedStringKey) -> some View {
        Text(title).foregroundStyle(Palette.inkSoft)
            .padding(.horizontal, 8).padding(.vertical, 6)
            .contentShape(Rectangle())
    }

    private var finePrint: some View {
        Text("Subscriptions renew automatically until cancelled in Settings › Apple Account › Subscriptions. Cancel at least a day before renewal to avoid the next charge. The tuner for guitar, bass and ukulele stays free.")
            .font(.caption2).foregroundStyle(Palette.inkFaint).multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
    }
}

/// A symbol on an accent tile, styled like the course emblems, for outcomes that are not a course.
private struct SymbolTile: View {
    let symbol: String
    let accent: Color
    var size: CGFloat = 26

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: size * 0.27, style: .continuous)
        Image(systemName: symbol)
            .font(.system(size: size * 0.46, weight: .bold))
            .foregroundStyle(Palette.onAccent.opacity(0.92))
            .frame(width: size, height: size)
            .background(shape.fill(LinearGradient(colors: [accent.mix(with: .white, by: 0.2), accent, accent.mix(with: .black, by: 0.2)],
                                                  startPoint: .topLeading, endPoint: .bottomTrailing)))
            .overlay(shape.fill(LinearGradient(colors: [.white.opacity(0.24), .white.opacity(0)], startPoint: .top, endPoint: .center)))
            .overlay(shape.strokeBorder(.white.opacity(0.28), lineWidth: 0.5))
            .accessibilityHidden(true)
    }
}

/// The plan track's columns: the first takes `lead` of the width (Today, with the first lesson under it), the
/// others share the rest equally. The titles, the nodes and the details each use one, so they line up. A column
/// narrower than its minimum (a song name on two lines, the price on one) takes the room it needs from the columns
/// with some to spare, in proportion to what they spare; none claims more than two fifths of the track.
private struct TrackColumns: Layout {
    var lead: CGFloat
    /// Each column's narrowest, in points; empty for the plain shares.
    var minimums: [CGFloat] = []
    var spacing: CGFloat = 8

    private func widths(_ total: CGFloat, count: Int) -> [CGFloat] {
        guard count > 1 else { return [total] }
        let room = max(0, total - spacing * CGFloat(count - 1))
        let first = room * lead
        var columns = [first] + Array(repeating: (room - first) / CGFloat(count - 1), count: count - 1)
        guard minimums.count == count else { return columns }
        let floors = minimums.map { min($0, room * 0.4) }
        let short = zip(columns, floors).reduce(CGFloat(0)) { sum, pair in sum + max(0, pair.1 - pair.0) }
        guard short > 0 else { return columns }
        let spare = zip(columns, floors).map { pair in max(0, pair.0 - pair.1) }
        let spareTotal = spare.reduce(0, +)
        let share = spareTotal > 0 ? min(1, short / spareTotal) : 0
        for index in columns.indices {
            columns[index] = max(floors[index], columns[index] - spare[index] * share)
        }
        // Not enough to spare: everything gives way alike, and the text shrinks a little.
        let sum = columns.reduce(0, +)
        return sum > room ? columns.map { $0 * room / sum } : columns
    }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.replacingUnspecifiedDimensions().width
        let columns = widths(width, count: subviews.count)
        var height: CGFloat = 0
        for (subview, column) in zip(subviews, columns) {
            height = max(height, subview.sizeThatFits(ProposedViewSize(width: column, height: nil)).height)
        }
        return CGSize(width: width, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let columns = widths(bounds.width, count: subviews.count)
        var x = bounds.minX
        for (subview, column) in zip(subviews, columns) {
            subview.place(at: CGPoint(x: x, y: bounds.minY), anchor: .topLeading, proposal: ProposedViewSize(width: column, height: nil))
            x += column + spacing
        }
    }
}

/// Local reminder two days before a free trial converts. The paywall promises it only when it can arrive.
enum TrialReminder {
    /// True when notifications are turned off for Timbre, so a reminder would never be shown.
    static func isBlocked() async -> Bool {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        return settings.authorizationStatus == .denied
    }

    /// Called right after a successful trial purchase. A first-time user is asked for permission here.
    static func schedule(afterDays days: Int) async {
        let center = UNUserNotificationCenter.current()
        let status = await center.notificationSettings().authorizationStatus
        switch status {
        case .denied:
            return
        case .notDetermined:
            guard (try? await center.requestAuthorization(options: [.alert, .sound])) == true else { return }
        default:
            break
        }
        let content = UNMutableNotificationContent()
        content.title = String(localized: "Your Timbre Pro trial ends soon")
        content.body = String(localized: "It renews in two days. Keep tuning, or cancel anytime in Settings.")
        let seconds = max(3600, TimeInterval(days - 2) * 86400)
        let request = UNNotificationRequest(identifier: "timbre.trial.reminder", content: content, trigger: UNTimeIntervalNotificationTrigger(timeInterval: seconds, repeats: false))
        try? await center.add(request)
    }
}
