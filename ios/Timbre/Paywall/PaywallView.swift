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
    /// The plan tapped; nil keeps the year (or the first plan offered).
    @State private var selectedID: String?
    /// This paywall's arm of a running test (`RemoteConfig`), fixed while it is open.
    @State private var variant = RemoteConfig.PaywallVariant.control
    /// `paywall_view` is logged once per paywall shown.
    @State private var viewLogged = false
    @State private var appeared = false
    /// Notifications are off for Timbre: no reminder can arrive, so none is promised.
    @State private var remindersBlocked = false
    /// The plan track draws itself in from Today.
    @State private var trackDrawn = false
    /// "What's in Timbre Pro" is open: the Free and Pro table shows under it.
    @State private var detailsOpen = false
    /// The table's Free and Pro columns grow with the text.
    @ScaledMetric(relativeTo: .caption) private var cellWidth: CGFloat = 50
    /// The columns stop growing past xxxLarge (their numbers shrink to fit), so the labels keep the width.
    private var tableCell: CGFloat { min(cellWidth, 72) }
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
    /// The App Store's own offer to make if this paywall is turned down for the second time (`PaywallWinBack.swift`),
    /// and whether it is on screen.
    @State private var exitOffer: ExitOffer?
    @State private var exitOfferShown = false
    /// The App Store's offer-code sheet ("Redeem code").
    @State private var redeeming = false
    /// The chosen plan's glass (iOS 26) flows from card to card as the choice moves.
    @Namespace private var planGlass
    /// The yearly card's height and whether it is under the finger: its tag, drawn over the glass group, follows it.
    @State private var annualHeight: CGFloat = 64
    @State private var annualPressed = false
    /// Room at the top of the yearly card for the lower half of its tag (the tag stops growing at xxxLarge).
    @ScaledMetric(relativeTo: .caption2) private var tagRoom: CGFloat = 11

    /// The plans on offer: the year and the month, and the lifetime unlock everywhere but onboarding (unless its test
    /// arm brings it back, or the storefront has nothing else).
    private var offered: [Product] {
        let subscriptions = [commerce.annual, commerce.monthly].compactMap { $0 }
        guard let lifetime = commerce.lifetime, showsLifetime || subscriptions.isEmpty else { return subscriptions }
        return subscriptions + [lifetime]
    }

    private var showsLifetime: Bool { context == .standard || variant.onboardingLifetime == true }

    /// The plan chosen: the yearly one unless the storefront left it out.
    private var selected: Product? { offered.first { $0.id == selectedID } ?? offered.first }

    private func isAnnual(_ product: Product) -> Bool { product.id == commerce.annual?.id }

    private func isLifetime(_ product: Product) -> Bool { product.id == commerce.lifetime?.id }

    /// Works both as a presented sheet (dismiss) and as the root overlay (the store flag).
    private func close() {
        if context == .standard { store.showPaywall = false }
        dismiss()
    }

    /// The person turned the paywall down (the close button, or "Continue with the free tuner"). The second time any
    /// paywall is turned down (onboarding's is the first), the App Store's own offer for them is made, once, if there is
    /// one; otherwise, and every other time, the paywall closes.
    private func decline() {
        Analytics.log("paywall_close", ["reason": analyticsReason, "variant": variant.id])
        let due = PaywallDeclines.offerDue
        PaywallDeclines.record()
        guard due, let offer = exitOffer, !commerce.isPro else { close(); return }
        PaywallDeclines.markOffered()
        withMotion(Motion.settle, reduceMotion: reduceMotion) { exitOfferShown = true }
        Analytics.log("exit_offer_shown", ["kind": offer.kind.rawValue, "reason": analyticsReason])
    }

    /// Looks up the exit offer while the person reads, only when the next decline would make it.
    private func prepareExitOffer() async {
        guard PaywallDeclines.offerDue, !commerce.isPro, exitOffer == nil else { return }
        exitOffer = await commerce.exitOffer()
    }

    private func acceptExitOffer(_ offer: ExitOffer) {
        var properties = purchaseProperties(offer.product, trial: offer.offer.paymentMode == .freeTrial)
        properties["offer"] = offer.kind.rawValue
        properties["offer_price"] = "\(offer.offer.price)"
        Analytics.log("purchase_start", properties)
        Task {
            guard await commerce.purchase(offer.product, options: offer.options) else { return }
            Analytics.log("purchase", properties)
            // As with the yearly trial, notification permission is asked only once the free days have started.
            if let days = offer.freeDays, days >= 3 { await TrialReminder.schedule(afterDays: days) }
        }
    }

    private var analyticsReason: String { context == .onboarding ? "onboarding" : (store.paywallReason ?? "unknown") }

    /// What a purchase event carries: the plan, why the paywall opened, its test arm, whether a free trial starts, and
    /// the price in the storefront's currency, as StoreKit gave it.
    private func purchaseProperties(_ product: Product, trial: Bool) -> [String: String] {
        ["product": product.id, "reason": analyticsReason, "variant": variant.id, "trial": trial ? "1" : "0",
         "price": "\(product.price)", "currency": product.priceFormatStyle.currencyCode]
    }

    /// The paywall is on screen: its arm is fixed, and it is counted once.
    private func didAppear() {
        appeared = true
        guard !viewLogged else { return }
        viewLogged = true
        variant = RemoteConfig.shared.paywallVariant
        Analytics.log("paywall_view", ["reason": analyticsReason, "variant": variant.id])
    }

    var body: some View {
        let plan = PaywallPlan.make(store: store, answers: answers, horizon: planHorizon, reason: context == .standard ? store.paywallReason : nil)
        let pitch = self.pitch(plan)
        let hero = self.hero(pitch, plan: plan)
        let layout = self.fold(pitch, plan: plan, hero: hero)
        ZStack(alignment: .topTrailing) {
            Palette.stage.ignoresSafeArea()
            RadialGradient(colors: [Palette.spotlight.opacity(0.16), .clear], center: UnitPoint(x: 0.5, y: 0.12), startRadius: 10, endRadius: 320)
                .ignoresSafeArea()
            // The height between the safe-area edges; the scroll content starts at the top one.
            Color.clear
                .onGeometryChange(for: CGFloat.self) { proxy in proxy.size.height } action: { height in containerHeight = height }
                .accessibilityHidden(true)
            ScrollView {
                content(pitch, plan: plan, hero: hero, layout: layout)
            }
            .scrollIndicators(.hidden)
            .scrollBounceBehavior(.basedOnSize)
            // Pinned and opaque: the fine print scrolls under a short fade, never through the button.
            .safeAreaInset(edge: .bottom, spacing: 0) {
                bottomBar.onGeometryChange(for: CGFloat.self) { proxy in proxy.size.height } action: { height in barHeight = height }
            }
            closeButton
            if exitOfferShown, let offer = exitOffer {
                ExitOfferCard(offer: offer, purchasing: commerce.purchasing != nil,
                              accept: { acceptExitOffer(offer) },
                              decline: {
                                  Analytics.log("exit_offer_declined", ["kind": offer.kind.rawValue, "reason": analyticsReason])
                                  close()
                              })
                    .transition(.opacity)
                    .zIndex(2)
            }
        }
        .preferredColorScheme(.dark)
        // Drawn over the tabs as an overlay: VoiceOver stays inside it, as it would in a presented sheet.
        .accessibilityElement(children: .contain)
        .accessibilityAddTraits(.isModal)
        .offerCodeRedemption(isPresented: $redeeming) { result in
            // The redeemed code arrives as a transaction too; checking now unlocks without waiting for it.
            if case .success = result { Task { await commerce.refreshEntitlements() } }
            Analytics.log("offer_code_closed", ["reason": analyticsReason])
        }
        .task {
            await commerce.load()
            await prepareExitOffer()
        }
        .task { remindersBlocked = await TrialReminder.isBlocked() }
        .onAppear(perform: didAppear)
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

    /// Headline (with its proof line and top inset), plans and trust row, and the plan track: what must show.
    private func essentials(_ plan: PaywallPlan) -> CGFloat {
        headerHeight + Self.headerTop + offerHeight + trackReserve(plan)
    }

    /// The Pro pill on its own row, when there is no hero for it to stand in.
    private static let pillRow: CGFloat = 40
    private static let previewTop: CGFloat = 6
    private static let headerTop: CGFloat = 12
    private static let outcomesTop: CGFloat = 10
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
    /// minimum, then its growth up to `PaywallHero.maxHeight`). When not even the pill fits, the page scrolls anyway
    /// and everything stays in reading order above the fine print. A locked lesson's card replaces the hero.
    /// On a 6.1-inch iPhone, onboarding's plan keeps its rail, headline, proof line, three outcomes, plans and trial
    /// track above the pinned purchase button.
    private func fold(_ pitch: Pitch, plan: PaywallPlan, hero: PaywallHero) -> Fold {
        var left = viewport - essentials(plan)
        guard left >= Self.pillRow else { return Fold() }
        var result = Fold()
        result.outcomes = left - Self.pillRow >= Self.outcomesTop + outcomesHeight
        if result.outcomes { left -= Self.outcomesTop + outcomesHeight }
        let heroFloor = Self.previewTop + hero.minHeight
        // Onboarding's hero, and the plan's anywhere, take the room before "What's in Pro" (which waits below the fold
        // unless room is left): the rail is the plan's own songs, and a taller stage keeps its runway and hit line
        // well below the close button.
        if (context == .onboarding || hero.isPlan) && pitch.lesson == nil && left >= heroFloor {
            result.preview = hero.minHeight + min(left - heroFloor, hero.maxHeight - hero.minHeight)
            left -= Self.previewTop + result.preview
            result.details = result.outcomes && left >= Self.detailsTop + detailsHeight
            return result
        }
        result.details = result.outcomes && left - Self.pillRow >= Self.detailsTop + detailsHeight
        if result.details { left -= Self.detailsTop + detailsHeight }
        if pitch.lesson == nil && left >= heroFloor {
            let growth = min(left - heroFloor, hero.maxHeight - hero.minHeight)
            result.preview = hero.minHeight + growth
        }
        return result
    }

    /// Days the milestones may reach: the free trial's, else two weeks.
    private var planHorizon: Int { commerce.annual.map { trialDays($0) } ?? 14 }

    private func content(_ pitch: Pitch, plan: PaywallPlan, hero: PaywallHero, layout: Fold) -> some View {
        let steps = trackSteps(plan)
        let trial = showsTrial
        let outcomes = shownOutcomes(plan, hero: hero, pitch: pitch)
        return VStack(spacing: 0) {
            VStack(spacing: 0) {
                if layout.preview > 0 {
                    preview(hero, plan: plan, height: layout.preview).padding(.top, Self.previewTop)
                } else {
                    PaywallProPill().padding(.top, 14)
                }
                // Under the plan's rail, whose sleeves are gone before its first line: it always sits on the plain stage.
                header(pitch, proof: context == .onboarding || hero.isPlan)
                    .onGeometryChange(for: CGFloat.self) { proxy in proxy.size.height } action: { height in headerHeight = height }
                    .padding(.top, layout.preview > 0 ? Self.headerTop : 10)
                if layout.outcomes {
                    outcomeList(outcomes).padding(.top, Self.outcomesTop)
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
            belowFold(outcomes, layout: layout)
            redeemLink.padding(.top, 24)
            finePrint.padding(.top, 8)
        }
        .padding(.horizontal, 20).padding(.bottom, 12)
        .frame(maxWidth: 520)
        .frame(maxWidth: .infinity)
    }

    /// The outcomes and "What's in Pro", or just "What's in Pro", when they did not fit above the fold.
    @ViewBuilder private func belowFold(_ outcomes: [PaywallPlan.Outcome], layout: Fold) -> some View {
        if !layout.outcomes {
            VStack(spacing: Self.detailsTop) {
                outcomeList(outcomes)
                proDetails
            }
            .padding(.top, 28)
        } else if !layout.details {
            proDetails.padding(.top, 28)
        }
    }

    /// The plan's outcomes, three at most, less the first song when the headline or the plan's hero already promises
    /// it (the rail shows the songs, and the track names the first one's day), so the same promise isn't made twice.
    private func shownOutcomes(_ plan: PaywallPlan, hero: PaywallHero, pitch: Pitch) -> [PaywallPlan.Outcome] {
        let outcomes = hero.isPlan || pitch.promisesSong ? plan.outcomes.filter { $0.id != "song" } : plan.outcomes
        return Array(outcomes.prefix(3))
    }

    /// The sheet's close button: a solid 44 pt disc, so it reads over any hero (the runway and the tools' scenes move
    /// under its corner), in a 44 pt target.
    private var closeButton: some View {
        IconButton(symbol: "xmark", size: .regular, label: "Close") { decline() }
            .accessibilityIdentifier("paywall.close")
            .padding(.trailing, 10).padding(.top, 4)
    }

    // MARK: Pitch

    /// What the paywall leads with: the person's plan, or what they just tried to open. The outcomes under the
    /// headline follow the same reason (`PaywallPlan`), so the headline stands alone.
    private struct Pitch {
        var headline: Text
        var lesson: LockedLesson? = nil
        /// The instrument to stand in the hero instead of the person's own.
        var instrumentAsset: String? = nil
        /// The headline promises the first song this week (the outcomes then leave it out).
        var promisesSong = false
    }

    private struct LockedLesson {
        let course: LearnCourse
        let unitNumber: Int
        let unitTitle: String
        let lesson: Lesson
    }

    private func pitch(_ plan: PaywallPlan) -> Pitch {
        let generic = Pitch(headline: Text("Unlock your full plan"))
        // Onboarding comes straight from the plan (and, for a beginner, their first chord): it sells the first song
        // when the plan reaches one this week, unless the player came for the tuner or the test arm keeps the plan's
        // headline.
        if context == .onboarding {
            guard variant.headline != "plan", answers?.goal != "tune", let day = plan.songDay, day <= 7 else { return generic }
            return Pitch(headline: Text("Play your first song this week"), promisesSong: true)
        }
        guard let reason = store.paywallReason else { return generic }
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

    /// "Tune your mandolin, and 59 more instruments", with that instrument in the spotlight.
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

    /// One scene across the full width with the Timbre Pro pill under it: the plan (a rail of the songs it plays,
    /// drifting above the headline); the instrument they just tried to open with its strings running on as a
    /// play-along runway; or the scene of the tool that opened the paywall.
    private func preview(_ hero: PaywallHero, plan: PaywallPlan, height: CGFloat) -> some View {
        PaywallPreview(hero: hero, accent: plan.accent, height: height)
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared || reduceMotion ? 0 : 12)
            .animation(Motion.hero, value: appeared)
    }

    /// The tool's own scene when a tool opened the paywall; the plan itself for onboarding and Pro from Settings;
    /// else the instrument and its runway (lessons, songs, instruments).
    private func hero(_ pitch: Pitch, plan: PaywallPlan) -> PaywallHero {
        if let tool = heroTool { return .tool(tool) }
        if let scene = planScene(pitch, plan: plan) { return .plan(scene) }
        let figure = heroFigure(pitch, plan: plan)
        return .runway(figure.figure, lanes: lanes(figure.instrumentId))
    }

    /// Onboarding's paywall and Pro from Settings (or the plain upsell) sell the plan: a rail of the sleeves of the
    /// songs it plays, three Originals and then its next song (`PaywallPlan.rail`), all real songs from the catalogue.
    /// Nil when the plan reaches no song (a course without any) or the rail would be too short to drift.
    private func planScene(_ pitch: Pitch, plan: PaywallPlan) -> PaywallPlanScene? {
        let reason = store.paywallReason
        let planned = context == .onboarding || reason == nil || reason == "settings"
        guard planned, pitch.lesson == nil, pitch.instrumentAsset == nil, plan.rail.count >= 3 else { return nil }
        return PaywallPlanScene(songs: plan.rail, accent: plan.accent)
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

    /// The headline, then (`proof`: onboarding and the plan's hero) the catalogue Pro opens, counted, and the rating
    /// once it is worth showing; or a locked lesson's card.
    private func header(_ pitch: Pitch, proof: Bool) -> some View {
        VStack(spacing: 0) {
            pitch.headline.font(Typeface.display(26)).tracking(-0.6)
                .multilineTextAlignment(.center).foregroundStyle(Palette.ink)
                // Never cut short: at the accessibility sizes it takes the lines it needs (the page scrolls).
                .lineLimit(typeSize.isAccessibilitySize ? nil : 3).minimumScaleFactor(0.8)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)
            if proof && pitch.lesson == nil {
                proofLine.padding(.top, 4)
                if let rating = RemoteConfig.shared.ratingLine { ratingLine(rating).padding(.top, 2) }
            }
            if let lesson = pitch.lesson { lessonCard(lesson).padding(.top, 14) }
        }
        .frame(maxWidth: .infinity)
    }

    /// "518 lessons · 140+ songs · 60 instruments": what Pro opens, counted from the curriculum and the catalog as they
    /// ship (the Free and Pro table counts the same lessons), never a number written down here. Lessons are the ones
    /// that teach (`Curriculum.lessonCount`, songbooks aside); songs count by title, so a song taught in two lessons
    /// or arranged for two instruments counts once, rounded down to the ten as the listing says them.
    private var proofLine: some View {
        let titles = Set(store.curriculum.courses.flatMap(\.lessons).filter { $0.kind == .song }.map(\.title.defaultValue))
        let songs = Self.roundedCount(titles.count)
        return Text("\(store.curriculum.lessonCount) lessons · \(songs) songs · \(store.catalog.instruments.count) instruments")
            .font(.footnote.weight(.semibold)).monospacedDigit()
            .foregroundStyle(Palette.inkSoft)
            .multilineTextAlignment(.center)
            // One line in English; a longer translation, or a larger size, wraps rather than shrinking away.
            .lineLimit(typeSize.isAccessibilitySize ? nil : 2).minimumScaleFactor(0.9)
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityIdentifier("paywall.proof")
    }

    /// A count as the store listing says it: exact under 20, else down to the ten with a plus ("120+" for 124).
    static func roundedCount(_ count: Int) -> String {
        guard count >= 20 else { return count.formatted() }
        let tens = count / 10 * 10
        return tens == count ? count.formatted() : "\(tens.formatted())+"
    }

    /// "4.8★ · 312 ratings": the App Store rating, switched on remotely and only past the bar (`RemoteConfig.RatingLine`).
    private func ratingLine(_ rating: RemoteConfig.RatingLine) -> some View {
        Text("\(rating.stars, format: .number.precision(.fractionLength(1)))★ · \(rating.count) ratings")
            .font(.footnote.weight(.semibold)).monospacedDigit()
            .foregroundStyle(Palette.amber)
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityIdentifier("paywall.rating")
    }

    /// The locked lesson: its unit, title and length, behind a gold lock.
    private func lessonCard(_ locked: LockedLesson) -> some View {
        let accent = Palette.accent(locked.course.accent)
        let shape = RoundedRectangle(cornerRadius: Metrics.cornerTile, style: .continuous)
        return HStack(spacing: 14) {
            lessonArt(locked.course, accent: accent)
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Image(systemName: locked.course.symbol).font(.caption2.weight(.bold)).foregroundStyle(accent)
                        .accessibilityHidden(true)
                    Eyebrow(Text("UNIT \(locked.unitNumber)"), color: accent, style: .display)
                }
                Text(locked.lesson.title.localized).font(.headline).foregroundStyle(Palette.ink)
                    .lineLimit(typeSize.isAccessibilitySize ? nil : 2).fixedSize(horizontal: false, vertical: true)
                Text("\(locked.lesson.minutes) min · +\(locked.lesson.xp) XP").font(.caption).foregroundStyle(Palette.inkSoft)
                    .fixedSize(horizontal: false, vertical: true)
            }
            // Ahead of the spacer, or the title would wrap at half the card's width.
            .layoutPriority(1)
            Spacer(minLength: 8)
            Image(systemName: "lock.fill").font(.system(size: 13, weight: .bold)).foregroundStyle(Palette.onGold)
                .frame(width: 30, height: 30)
                .background(Circle().fill(Palette.proGold))
                .accessibilityHidden(true)
        }
        .padding(Metrics.tilePadding)
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
            Glyph(course.symbol, size: Glyph.lead, tint: accent)
                .frame(width: 40, height: 58)
        }
    }

    // MARK: Outcomes

    /// The outcomes' icons, the size of the plan track's nodes.
    private static let benefitArt: CGFloat = 24

    /// Three results for the person's goal; they slide in one after another. Every outcome wears one tint: a bare
    /// glyph in mint (`Glyph`), the width of the plan track's nodes, never a disc or a colour of its own.
    private func outcomeList(_ outcomes: [PaywallPlan.Outcome]) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(Array(outcomes.enumerated()), id: \.element.id) { index, outcome in
                HStack(spacing: 10) {
                    outcomeGlyph(outcome)
                    // One line in English; longer translations wrap rather than truncate, and at the accessibility
                    // sizes it takes the lines it needs.
                    outcome.text.font(.subheadline.weight(.medium)).foregroundStyle(Palette.ink)
                        .lineLimit(typeSize.isAccessibilitySize ? nil : 2).minimumScaleFactor(0.85)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .opacity(appeared ? 1 : 0)
                .offset(x: appeared || reduceMotion ? 0 : -10)
                .animation(Motion.page.delay(0.12 + Double(index) * 0.09), value: appeared)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 6)
        .onGeometryChange(for: CGFloat.self) { proxy in proxy.size.height } action: { height in outcomesHeight = height }
    }

    @ViewBuilder private func outcomeGlyph(_ outcome: PaywallPlan.Outcome) -> some View {
        if let drawn = outcome.drawn {
            Glyph(drawn, size: Self.benefitArt, tint: Palette.mint)
        } else {
            Glyph(outcome.symbol, size: Self.benefitArt, tint: Palette.mint)
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
                Text("What’s in Timbre Pro")
                Image(systemName: "chevron.down").font(.system(size: 10, weight: .bold))
                    .rotationEffect(.degrees(detailsOpen ? 180 : 0))
                    .accessibilityHidden(true)
            }
            .font(.caption.weight(.semibold))
            .foregroundStyle(Palette.mint)
            .lineLimit(typeSize.isAccessibilitySize ? 2 : 1).minimumScaleFactor(0.8)
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
        withMotion(Motion.settle, reduceMotion: reduceMotion) { detailsOpen.toggle() }
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

    /// Free against Pro as the app enforces it: instruments and lessons by `AccessPolicy` (the instruments a free player
    /// tunes, or, once every standard tuning is free, the other tunings; free lessons), the tools by their own locks (the
    /// metronome's basics and Pitch Sniper are free; interval and chord ear drills, the Pro tools, strobe,
    /// temperaments and custom tunings are Pro).
    private var proRows: [ProRow] {
        let instruments = store.catalog.instruments
        let lessons = store.curriculum.courses.flatMap(\.lessons)
        let tuning = standardTuningsFree
            ? ProRow(id: "tunings", label: Text("Alternate tunings for every instrument"), free: .excluded, pro: .included)
            : ProRow(id: "instruments", label: Text("Instruments to tune"),
                     free: .count(instruments.filter { AccessPolicy.canTune(instrument: $0, pro: false) }.count), pro: .count(instruments.count))
        return [
            tuning,
            ProRow(id: "lessons", label: Text("Lessons in \(store.curriculum.courses.count) courses"),
                   free: .count(lessons.filter(\.free).count), pro: .count(lessons.count)),
            ProRow(id: "free", label: Text("Metronome and Bullseye"), free: .included, pro: .included),
            ProRow(id: "ear", label: Text("Name intervals and chords by ear"), free: .excluded, pro: .included),
            ProRow(id: "tools", label: Text("Chords, scales, intonation and drone"), free: .excluded, pro: .included),
            ProRow(id: "precision", label: Text("Strobe, temperaments and custom tunings"), free: .excluded, pro: .included),
            // Your songs (`YourSongsPolicy`): three charts free; Apple Music listening is free on both plans, so it has no row.
            ProRow(id: "yoursongs", label: Text("Your own song charts"), free: .count(YourSongsPolicy.freeChartLimit), pro: .included),
            ProRow(id: "yoursongs.tools", label: Text("Slow down, loop and find chords in your recordings"), free: .excluded, pro: .included),
        ]
    }

    /// The table: a header, six rows on hairlines, the Pro column on a gold wash; the free chromatic tuner under it.
    private var proTable: some View {
        let shape = RoundedRectangle(cornerRadius: Metrics.cornerTile, style: .continuous)
        return VStack(alignment: .leading, spacing: 8) {
            VStack(spacing: 0) {
                HStack(spacing: 0) {
                    Spacer(minLength: 0)
                    Text("Free").font(.caption.weight(.semibold)).foregroundStyle(Palette.inkSoft)
                        .lineLimit(1).minimumScaleFactor(0.7)
                        .frame(width: tableCell)
                    ProBadge().frame(width: tableCell)
                }
                .padding(.vertical, 8)
                .accessibilityHidden(true)
                ForEach(proRows) { row in
                    Hairline()
                    proRow(row)
                }
            }
            .padding(.horizontal, 12).padding(.bottom, 2)
            .background(alignment: .trailing) {
                // Inset 4 pt in the tile, so its corners follow the tile's.
                RoundedRectangle(cornerRadius: Metrics.cornerTile - 4, style: .continuous).fill(Color(hex: 0xFFD08A).opacity(0.07))
                    .frame(width: tableCell)
                    .padding(.trailing, 12).padding(.vertical, 4)
            }
            .background(shape.fill(Palette.stageRaised))
            .overlay(shape.strokeBorder(Palette.hairline, lineWidth: 1))
            Text("The chromatic tuner stays free for any instrument.")
                .font(.caption2).foregroundStyle(Palette.inkFaint)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 4)
        }
        .accessibilityIdentifier("paywall.table")
    }

    /// The label beside its Free and Pro cells; at the accessibility sizes the label takes the full width and the
    /// cells sit under it, in their columns, so no word is broken across lines.
    private func proRow(_ row: ProRow) -> some View {
        Group {
            if typeSize.isAccessibilitySize {
                VStack(spacing: 0) {
                    proLabel(row.label).padding(.top, 8)
                    HStack(spacing: 0) {
                        Spacer(minLength: 0)
                        proCells(row)
                    }
                    .padding(.vertical, 6)
                }
            } else {
                HStack(spacing: 0) {
                    proLabel(row.label).padding(.vertical, 8)
                    proCells(row)
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(row.label)
        .accessibilityValue(Text("Free: \(spoken(row.free)), Pro: \(spoken(row.pro))"))
    }

    private func proLabel(_ label: Text) -> some View {
        label.font(.footnote).foregroundStyle(Palette.ink)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func proCells(_ row: ProRow) -> some View {
        HStack(spacing: 0) {
            proCell(row.free, pro: false).frame(width: tableCell)
            proCell(row.pro, pro: true).frame(width: tableCell)
        }
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

    /// The plans, the trust line under them and, for a plan the family can share, that it can.
    private var offer: some View {
        VStack(spacing: 0) {
            // Room above the first row for its tag.
            plans.padding(.top, 14).animation(Motion.settle, value: commerce.products.isEmpty)
            trustRow.padding(.top, 10)
            if selected?.isFamilyShareable == true { familyLine.padding(.top, 4) }
        }
    }

    /// Family Sharing, when App Store Connect turns it on for the chosen plan (StoreKit says so; nothing is assumed).
    private var familyLine: some View {
        HStack(spacing: 6) {
            trustIcon("person.2.fill")
            Text("Share with up to 5 family members")
        }
        .modifier(TrustLine())
        .accessibilityIdentifier("paywall.family")
    }

    @ViewBuilder private var plans: some View {
        if commerce.products.isEmpty {
            if commerce.loading {
                planSkeleton
            } else {
                VStack(spacing: 10) {
                    Text(commerce.error ?? String(localized: "Plans are loading.")).font(.subheadline).foregroundStyle(Palette.inkSoft).multilineTextAlignment(.center)
                    Button("Try again") { Task { await commerce.load() } }.buttonStyle(SecondaryButtonStyle())
                }
            }
        } else {
            // The cards' first arrangement in which every card fits (`PlanFace`), the same for all three: the saving
            // beside the name, else under the price, else everything stacked (the largest text sizes, long
            // translations). The yearly card's tag is drawn over the glass group, outside it: inside, the chosen
            // plan's glass covered its lower half.
            ViewThatFits(in: .horizontal) {
                planGroup(.inline)
                if commerce.annual != nil && annualSaving != nil { planGroup(.savingUnderPrice) }
                planGroup(.stacked)
            }
            .overlay(alignment: .top) {
                if let annual = commerce.annual { annualTagLayer(annualTag(annual)).zIndex(1) }
            }
            .transition(.opacity)
        }
    }

    /// One glass group: the chosen plan's glass flows to the next card as the choice moves.
    private func planGroup(_ arrangement: PlanFace.Arrangement) -> some View {
        TimbreGlassGroup(spacing: 8) {
            VStack(spacing: 8) {
                if let annual = commerce.annual {
                    planRow(annual, title: "Yearly", detail: perWeek(annual), saving: annualSaving, anchor: annualAnchor,
                            tag: annualTag(annual), arrangement: arrangement)
                        .onGeometryChange(for: CGFloat.self) { proxy in proxy.size.height } action: { height in annualHeight = height }
                }
                if let monthly = commerce.monthly {
                    planRow(monthly, title: "Monthly", detail: String(localized: "Cancel anytime"), saving: nil, arrangement: arrangement)
                }
                // A third option, quieter than the two subscriptions, so it doesn't compete with the year. Onboarding's
                // paywall leaves it out: a first-time buyer chooses between the trial year and the month.
                if let lifetime = commerce.lifetime, offered.contains(where: { $0.id == lifetime.id }) {
                    planRow(lifetime, title: "Lifetime", detail: String(localized: "Pay once"), saving: nil, quiet: true,
                            arrangement: arrangement)
                }
            }
        }
    }

    /// "14 days free" centred on the yearly card's top edge, in mint, in a frame the size of that card (the first in
    /// the group), so it gives under the finger with the card. Above the glass group, never inside it.
    private func annualTagLayer(_ text: String) -> some View {
        Color.clear
            .frame(height: annualHeight)
            .overlay(alignment: .topTrailing) {
                Badge(Text(verbatim: text), style: .solid(Palette.mint))
                    .shadow(color: Palette.stage.opacity(0.5), radius: 4, y: 1)
                    .padding(.trailing, 14)
                    .alignmentGuide(.top) { dimensions in dimensions[VerticalAlignment.center] }
            }
            .scaleEffect(annualPressed ? 0.97 : 1)
            .animation(Motion.quick, value: annualPressed)
            .allowsHitTesting(false)
            // The yearly card says it (its accessibility value).
            .accessibilityHidden(true)
    }

    /// The stage's spinner, holding the plans' place while StoreKit answers, so nothing jumps when they arrive.
    private var planSkeleton: some View {
        StageSpinner("Plans are loading.")
            .frame(maxWidth: .infinity)
            .frame(height: showsLifetime ? Self.plansHeight : Self.subscriptionPlansHeight)
    }

    /// The three plan cards at the default text size (the yearly one with its tag's room, the quieter lifetime one)
    /// and the gaps between them; without the lifetime card, the two subscriptions.
    private static let plansHeight: CGFloat = 60 + 56 + 48 + 2 * 8
    private static let subscriptionPlansHeight: CGFloat = 60 + 56 + 8

    /// The yearly price as a week of it ("$0.67 a week"): the product's own price over 52, in the storefront's currency.
    private func perWeek(_ product: Product) -> String {
        String(localized: "\((product.price / 52).formatted(product.priceFormatStyle)) a week")
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
        withAnimation(reduceMotion ? Motion.quick : Motion.morph) { selectedID = product.id }
        Haptics.shared.selection()
    }

    /// A plan card: the check, then its face (`PlanFace`) in the group's arrangement. The name is never broken across
    /// lines. A tagged card (the yearly one) keeps room at its top for the tag over its edge.
    private func planRow(_ product: Product, title: LocalizedStringKey, detail: String, saving: Int?, anchor: String? = nil,
                         tag: String? = nil, quiet: Bool = false, arrangement: PlanFace.Arrangement) -> some View {
        let isSelected = selected?.id == product.id
        let shape = RoundedRectangle(cornerRadius: Metrics.cornerTile, style: .continuous)
        let face = PlanFace(title: title, detail: detail, price: product.displayPrice, saving: saving, anchor: anchor,
                            selected: isSelected, quiet: quiet)
        let inset: CGFloat = quiet ? 7 : 9
        // Stacked, the check stands on the name's line; otherwise centred on the card.
        let rowAlignment: VerticalAlignment = arrangement == .stacked ? .firstTextBaseline : .center
        return Button { select(product) } label: {
            HStack(alignment: rowAlignment, spacing: 12) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(isSelected ? Palette.mint : Palette.inkFaint)
                    .contentTransition(.symbolEffect(.replace))
                    .accessibilityHidden(true)
                face.arranged(arrangement)
            }
            .padding(.horizontal, 14)
            .padding(.top, tag == nil ? inset : max(inset, min(tagRoom, 18)))
            .padding(.bottom, inset)
            .modifier(PlanPlate(selected: isSelected, quiet: quiet, glass: planGlass))
            .contentShape(shape)
        }
        .buttonStyle(PlanPressStyle(pressed: tag == nil ? nil : $annualPressed))
        .accessibilityElement(children: .combine)
        .accessibilityValue(Text(verbatim: tag ?? ""))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityIdentifier("paywall.plan.\(product.id)")
    }

    /// Under the plans. With a free trial selected (and a reminder that can arrive): how easy it is to stop, and when
    /// we'll remind them, "Cancel in 2 taps · We remind you on day 12" (Settings › Manage subscription opens the App
    /// Store's own sheet). Otherwise what Pro never asks of them.
    @ViewBuilder private var trustRow: some View {
        if showsTrial && !remindersBlocked, let product = selected {
            trialTrust(reminder: max(1, trialDays(product) - 2))
        } else {
            plainTrust
        }
    }

    /// One line where it fits; at the largest sizes (or in a longer language) the reminder goes under the rest,
    /// wrapping as it needs, never cut short.
    private func trialTrust(reminder: Int) -> some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 6) {
                trustIcon("bell.badge.fill")
                Text("Cancel in 2 taps")
                separator
                Text("We remind you on day \(reminder)")
            }
            .lineLimit(1)
            VStack(spacing: 2) {
                HStack(spacing: 6) {
                    trustIcon("bell.badge.fill")
                    Text("Cancel in 2 taps")
                }
                Text("We remind you on day \(reminder)")
            }
            .fixedSize(horizontal: false, vertical: true)
        }
        .modifier(TrustLine())
        .accessibilityIdentifier("paywall.trust")
    }

    /// As the trial's line: one line where it fits, else the plan's promise under the rest.
    private var plainTrust: some View {
        let promise: LocalizedStringKey = selected.map(isLifetime) == true ? "Pay once, keep forever" : "Cancel anytime"
        return ViewThatFits(in: .horizontal) {
            HStack(spacing: 6) {
                trustIcon("lock.shield.fill")
                Text("No ads")
                separator
                Text("No account")
                separator
                Text(promise)
            }
            .lineLimit(1)
            VStack(spacing: 2) {
                HStack(spacing: 6) {
                    trustIcon("lock.shield.fill")
                    Text("No ads")
                    separator
                    Text("No account")
                }
                Text(promise)
            }
            .fixedSize(horizontal: false, vertical: true)
        }
        .modifier(TrustLine())
    }

    private func trustIcon(_ symbol: String) -> some View {
        Image(systemName: symbol).foregroundStyle(Palette.mint).accessibilityHidden(true)
    }

    private var separator: some View {
        Text(verbatim: "·").foregroundStyle(Palette.inkFaint).accessibilityHidden(true)
    }

    // MARK: Track

    /// The selected plan has a free trial: only then does the track promise a reminder and a charge.
    private var showsTrial: Bool { selected.map(isAnnual) == true && commerce.trialLabel != nil }

    /// The yearly plan has a free trial for this person.
    private var trialOffered: Bool { commerce.annual != nil && commerce.trialLabel != nil }

    private struct TrackStep: Identifiable {
        enum Kind { case today, milestone, song, reminder, billing }
        let id: String
        let kind: Kind
        /// The day it falls on (Today is day 1): where it sits along the track.
        let day: Int
        let title: Text
        /// Under the node. Today's is the first lesson (or the tool that opened the paywall), under "Everything unlocked".
        let detail: Text?
        /// The node's symbol, for a tool's step; else the kind's.
        var symbol: String? = nil
    }

    /// The plan and the free trial on one track. Today unlocks everything and starts the first lesson; the next
    /// thing the plan brings before the reminder follows (its first song, else a unit it starts, never a repeat of
    /// today's lesson). A paywall opened from a tool starts that tool today and takes it further on day 2 ("Drone +
    /// intonation check": `PaywallPlan.Focus`). Only when the selected plan has a free trial come the reminder (when
    /// notifications can reach the person) and the first charge, at the product's own trial length and price.
    /// Without a trial the plan's milestones fill the track; without those there is no track.
    private func trackSteps(_ plan: PaywallPlan) -> [TrackStep] {
        let today = TrackStep(id: "today", kind: .today, day: 1, title: Text("Today"), detail: plan.today.map { Text(verbatim: $0) })
        guard showsTrial, let product = selected else {
            guard !plan.milestones.isEmpty else { return [] }
            return [today] + plan.milestones.map { milestoneStep($0) }
        }
        let days = trialDays(product)
        let reminder = max(1, days - 2)
        var steps = [today]
        let next = remindersBlocked ? days : reminder
        let ahead = plan.milestones.filter { $0.day > 1 && $0.day < next }
        let chosen = ahead.first(where: { $0.kind == .focus }) ?? ahead.first(where: { $0.kind == .song }) ?? ahead.last
        if let milestone = chosen { steps.append(milestoneStep(milestone)) }
        if !remindersBlocked {
            steps.append(TrackStep(id: "reminder", kind: .reminder, day: reminder, title: Text("Day \(reminder)"),
                                   detail: Text(verbatim: String(localized: "We remind you"))))
        }
        let price = String(localized: "\(product.displayPrice)/year")
        steps.append(TrackStep(id: "billing", kind: .billing, day: days, title: Text("Day \(days)"), detail: Text(verbatim: price)))
        return steps
    }

    /// "Day 2 · Play “Greensleeves”" (the song by its name, not its lesson's), a unit by its name, or the tool's next
    /// step ("Day 2 · Drone + intonation check") on the tool's own symbol.
    private func milestoneStep(_ milestone: PaywallPlan.Milestone) -> TrackStep {
        let day = Text("Day \(milestone.day)")
        let id = "day\(milestone.day)"
        switch milestone.kind {
        case .song:
            let play = String(localized: "Play “\(milestone.title)”")
            return TrackStep(id: id, kind: .song, day: milestone.day, title: day, detail: Text(verbatim: play))
        case .unit:
            return TrackStep(id: id, kind: .milestone, day: milestone.day, title: day, detail: Text(verbatim: milestone.title))
        case .focus:
            return TrackStep(id: id, kind: .milestone, day: milestone.day, title: day, detail: Text(verbatim: milestone.title),
                             symbol: milestone.symbol)
        }
    }

    /// Where each step sits along the track, 0 (Today) to 1 (the last day), in proportion to its day, so the gap
    /// between nodes is the time between them. Neighbours keep at least a sixth of the track apart (day 1 and day 2
    /// would otherwise touch); the track then scales back to fit.
    private static func trackPositions(_ steps: [TrackStep]) -> [CGFloat] {
        guard steps.count > 1, let first = steps.first?.day, let last = steps.last?.day, last > first else {
            return steps.indices.map { CGFloat($0) / CGFloat(max(1, steps.count - 1)) }
        }
        let span = CGFloat(last - first)
        var positions = steps.map { CGFloat($0.day - first) / span }
        let gap: CGFloat = 1 / 6
        for index in positions.indices.dropFirst() { positions[index] = max(positions[index], positions[index - 1] + gap) }
        if let end = positions.last, end > 1 { positions = positions.map { $0 / end } }
        return positions
    }

    /// Days on top, nodes on a line, what happens under each, each step at its day's place along the line (the words
    /// centred under their node, the first and last held to the ends). Without notifications the track says how to
    /// cancel instead of promising a reminder.
    private func planTrack(_ steps: [TrackStep]) -> some View {
        let positions = Self.trackPositions(steps)
        let last = steps.count - 1
        let days = selected.map { trialDays($0) } ?? 14
        let cancelNote = showsTrial && remindersBlocked
        return VStack(spacing: 5) {
            if typeSize.isAccessibilitySize {
                trackRows(steps)
            } else {
                TrackSpread(positions: positions, words: true) {
                    ForEach(Array(steps.enumerated()), id: \.element.id) { index, step in
                        step.title.font(Typeface.label(12)).foregroundStyle(trackTint(step.kind, title: true))
                            .lineLimit(1).minimumScaleFactor(0.8)
                            .frame(maxWidth: .infinity, alignment: Self.edge(index, last))
                    }
                }
                trackLine(steps, positions: positions)
                TrackSpread(positions: positions, words: true) {
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
                    trackNode(step.kind, symbol: step.symbol)
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

    /// The nodes on a line from Today to the last step, each at its day's place; the line draws itself in and each
    /// node pops as it passes.
    private func trackLine(_ steps: [TrackStep], positions: [CGFloat]) -> some View {
        let drawn = trackDrawn || reduceMotion
        return TrackSpread(positions: positions, words: false) {
            ForEach(Array(steps.enumerated()), id: \.element.id) { index, step in
                trackNode(step.kind, symbol: step.symbol)
                    .scaleEffect(drawn ? 1 : 0.6)
                    .opacity(drawn ? 1 : 0.3)
                    .animation(reduceMotion ? nil : Motion.pluck.delay(0.25 + Double(index) * 0.22), value: trackDrawn)
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

    /// A step's node: its kind's symbol, or the tool's own on a tool's step ("waveform.path" for the drone).
    private func trackNode(_ kind: TrackStep.Kind, symbol custom: String? = nil) -> some View {
        let symbol: String
        switch kind {
        case .today: symbol = "lock.open.fill"
        case .milestone: symbol = custom ?? "flag.fill"
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
        if isAnnual(selected), let trial = commerce.trialLabel { return String(localized: "Start \(trial)") }
        if isLifetime(selected) { return String(localized: "Unlock for \(selected.displayPrice)") }
        return String(localized: "Subscribe for \(selected.displayPrice)")
    }

    /// What happens after the purchase, in one line next to the button.
    private var terms: String? {
        guard let selected else { return nil }
        if isAnnual(selected) {
            guard commerce.trialLabel != nil else { return String(localized: "\(selected.displayPrice) a year, renews automatically.") }
            return String(localized: "Free for \(trialDays(selected)) days, then \(selected.displayPrice) a year.")
        }
        if selected.id == commerce.monthly?.id { return String(localized: "\(selected.displayPrice) a month, renews automatically.") }
        return String(localized: "One payment. Yours to keep, no subscription.")
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
                // The price after the trial is never cut short (Guideline 3.1.2): at the accessibility sizes, and in
                // longer languages, the bar grows to fit it.
                Text(terms).font(.footnote).foregroundStyle(Palette.inkSoft).multilineTextAlignment(.center)
                    .lineLimit(typeSize.isAccessibilitySize ? nil : 3)
                    .minimumScaleFactor(typeSize.isAccessibilitySize ? 1 : 0.9)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 8)
            }
            if context == .onboarding {
                Button { decline() } label: {
                    Text("Continue with the free tuner").font(.subheadline.weight(.semibold))
                        .padding(.horizontal, 12)
                }
                .buttonStyle(TextLinkStyle(tint: Palette.inkSoft))
                .padding(.top, 4)
                .accessibilityIdentifier("paywall.free")
            }
            links.padding(.top, 2)
        }
    }

    /// The main action, on mint glass (iOS 26). While the App Store's sheet is up it folds into a bead with a spinner,
    /// and opens back out to its title if the purchase is cancelled.
    private var purchaseButton: some View {
        let purchasing = commerce.purchasing != nil
        return TimbreGlassGroup {
            Button { purchase() } label: {
                if purchasing {
                    ProgressView().tint(Palette.onAccent)
                } else {
                    // One line at the usual sizes; two at the accessibility sizes rather than an unreadable shrink.
                    // The font is the button style's (`Typeface.button`), as on every primary action.
                    Text(ctaTitle)
                        .lineLimit(typeSize.isAccessibilitySize ? 2 : 1)
                        .minimumScaleFactor(typeSize.isAccessibilitySize ? 0.9 : 0.7)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.vertical, typeSize.isAccessibilitySize ? 6 : 0)
                }
            }
            // Busy, it stays mint while its spinner turns (Reduce Motion doesn't fold it into a bead).
            .buttonStyle(GlassActionButtonStyle(collapsed: purchasing && !reduceMotion, busy: purchasing))
            .disabled(selected == nil || purchasing || commerce.pending)
            .accessibilityIdentifier("paywall.purchase")
        }
    }

    private func purchase() {
        guard let selected else { return }
        let wasTrial = isAnnual(selected) && commerce.trialLabel != nil
        let days = trialDays(selected)
        let properties = purchaseProperties(selected, trial: wasTrial)
        Analytics.log("purchase_start", properties)
        Task {
            if await commerce.purchase(selected) {
                Analytics.log("purchase", properties)
                // Notification permission is asked here, after the trial has started, never before.
                if wasTrial { await TrialReminder.schedule(afterDays: days) }
            }
        }
    }

    /// "Restore purchases · Terms · Privacy", text links (`TextLinkStyle`: underlined with Button Shapes, 44 pt
    /// targets). "Restore purchases" as Settings words it; where the row can't hold it (a long translation at a large
    /// size), "Restore", read as "Restore purchases".
    private var links: some View {
        ViewThatFits(in: .horizontal) {
            linkRow(restore: "Restore purchases")
            linkRow(restore: "Restore")
        }
        .font(.footnote.weight(.semibold))
    }

    private func linkRow(restore: LocalizedStringKey) -> some View {
        HStack(spacing: 0) {
            Button { Task { await commerce.restore() } } label: { linkLabel(restore) }
                .buttonStyle(TextLinkStyle(tint: Palette.inkSoft))
                .disabled(commerce.loading)
                .accessibilityLabel(Text("Restore purchases"))
            separator
            Link(destination: AppLinks.terms) { linkLabel("Terms") }
                .buttonStyle(TextLinkStyle(tint: Palette.inkSoft))
            separator
            Link(destination: AppLinks.privacy) { linkLabel("Privacy") }
                .buttonStyle(TextLinkStyle(tint: Palette.inkSoft))
        }
    }

    private func linkLabel(_ title: LocalizedStringKey) -> some View {
        Text(title).padding(.horizontal, 8).frame(minWidth: Metrics.minTarget)
    }

    /// "Have an offer code? Redeem code": the App Store's own redemption sheet (codes are set up in App Store Connect).
    private var redeemLink: some View {
        Button {
            redeeming = true
            Analytics.log("offer_code_opened", ["reason": analyticsReason])
        } label: {
            (Text("Have an offer code?").foregroundStyle(Palette.inkFaint) + Text(verbatim: " ") + Text("Redeem code").foregroundStyle(Palette.mint))
                .font(.footnote.weight(.semibold))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 12)
        }
        .buttonStyle(TextLinkStyle())
        .disabled(commerce.purchasing != nil)
        .accessibilityIdentifier("paywall.redeem")
    }

    /// The renewal terms, and what stays free as `AccessPolicy` has it today.
    private var finePrint: some View {
        Group {
            if standardTuningsFree {
                Text("Subscriptions renew automatically until cancelled in Settings › Apple Account › Subscriptions. Cancel at least a day before renewal to avoid the next charge. Every instrument’s standard tuning stays free.")
            } else {
                Text("Subscriptions renew automatically until cancelled in Settings › Apple Account › Subscriptions. Cancel at least a day before renewal to avoid the next charge. The tuner for guitar, bass, ukulele, violin and cello stays free.")
            }
        }
        .font(.caption2).foregroundStyle(Palette.inkFaint).multilineTextAlignment(.center)
        .fixedSize(horizontal: false, vertical: true)
    }

    /// Every instrument's standard tuning is free on the free plan (`AccessPolicy`).
    private var standardTuningsFree: Bool {
        store.catalog.instruments.allSatisfy { instrument in
            guard let tuning = store.catalog.tuning(id: instrument.defaultTuningId) else { return true }
            return AccessPolicy.canUse(tuning: tuning, of: instrument, pro: false)
        }
    }
}

/// A plan card's face. Unchosen: graphite with a control's edge. Chosen: a mint border over mint-washed Liquid Glass (iOS 26),
/// one glass shape named in the plans' group, so choosing another plan moves it there as liquid rather than switching
/// two cards; before iOS 26 a mint wash with a soft mint glow, as it always was.
/// Quiet (Lifetime), unchosen, it is a shade darker than the subscriptions; chosen, it takes the same glass.
private struct PlanPlate: ViewModifier {
    let selected: Bool
    var quiet = false
    let glass: Namespace.ID

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: Metrics.cornerTile, style: .continuous)
        let id: String? = selected ? "paywall.plan.selected" : nil
        return content
            .background {
                if !selected { shape.fill(Palette.stageRaised.opacity(quiet ? 0.45 : 1)) }
            }
            // An unchosen plan is a control: its edge is `controlLine`, which holds 3:1 with Increase Contrast.
            .overlay(shape.strokeBorder(selected ? Palette.mint : Palette.controlLine, lineWidth: selected ? 2 : 1))
            .timbreGlass(Palette.mint.opacity(0.22), isOn: selected, in: shape) {
                ZStack {
                    shape.fill(Palette.mint.opacity(0.08))
                    shape.strokeBorder(Palette.mint, lineWidth: 2)
                        .shadow(color: Palette.mint.opacity(0.16), radius: 14, y: 4)
                }
            }
            .timbreGlassID(id, in: glass)
    }
}

/// `PressScaleStyle` that also tells `pressed` while the finger is down: the yearly card's tag, drawn over the glass
/// group rather than in the card, gives with it.
private struct PlanPressStyle: ButtonStyle {
    var pressed: Binding<Bool>?

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(Motion.quick, value: configuration.isPressed)
            .onChange(of: configuration.isPressed) { _, isPressed in pressed?.wrappedValue = isPressed }
    }
}

/// The trust line's type and colour, centred, read as one.
private struct TrustLine: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(.caption.weight(.medium))
            .foregroundStyle(Palette.inkSoft)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
            .accessibilityElement(children: .combine)
    }
}

/// A plan card's text beside its check: the name, what it comes to (a week of the year's price), the price and, for the
/// year, the saving and the year at the monthly price struck through beside the price. `PaywallView.plans` shows the cards in the first
/// arrangement that fits them all: the saving beside the name, else under the price, else all stacked. The name is
/// never broken across lines (it once hyphenated "Year-ly" beside the saving). Quiet (Lifetime): smaller type in
/// softer ink until chosen, a third option that doesn't compete with the two subscriptions.
@MainActor
private struct PlanFace {
    enum Arrangement { case inline, savingUnderPrice, stacked }

    let title: LocalizedStringKey
    let detail: String
    let price: String
    let saving: Int?
    let anchor: String?
    let selected: Bool
    let quiet: Bool

    @ViewBuilder func arranged(_ arrangement: Arrangement) -> some View {
        switch arrangement {
        case .inline:
            // Both columns at their full width (the arrangement is only shown when they fit), so the stack never
            // splits the room with the spacer and squeezes the name or shrinks the price; the spacer takes the rest.
            HStack(spacing: 0) {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 8) {
                        name(fixed: true)
                        if let saving { savingChip(saving) }
                    }
                    detailText(wraps: false)
                }
                .fixedSize(horizontal: true, vertical: false)
                .layoutPriority(1)
                Spacer(minLength: 12)
                prices(withSaving: false)
                    .fixedSize(horizontal: true, vertical: false)
            }
        case .savingUnderPrice:
            HStack(spacing: 0) {
                VStack(alignment: .leading, spacing: 2) {
                    name(fixed: true)
                    detailText(wraps: false)
                }
                .fixedSize(horizontal: true, vertical: false)
                .layoutPriority(1)
                Spacer(minLength: 12)
                prices(withSaving: true)
                    .fixedSize(horizontal: true, vertical: false)
            }
        case .stacked:
            VStack(alignment: .leading, spacing: 3) {
                name(fixed: false)
                if let saving { savingChip(saving) }
                detailText(wraps: true)
                pricePair.padding(.top, 2)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    /// One line, always: at its full size beside the rest, shrinking a little when stacked.
    private func name(fixed: Bool) -> some View {
        Text(title)
            .font(quiet ? Font.subheadline.weight(.semibold) : Font.headline)
            .foregroundStyle(quiet && !selected ? Palette.inkSoft : Palette.ink)
            .lineLimit(1)
            .minimumScaleFactor(fixed ? 1 : 0.6)
            .fixedSize(horizontal: fixed, vertical: false)
    }

    private func detailText(wraps: Bool) -> some View {
        Text(verbatim: detail)
            .font(quiet ? Font.caption : Font.footnote)
            .foregroundStyle(selected ? Palette.mint : Palette.inkSoft)
            .lineLimit(wraps ? nil : 1)
            .minimumScaleFactor(wraps ? 1 : 0.8)
            .fixedSize(horizontal: false, vertical: wraps)
    }

    private var priceText: some View {
        Text(verbatim: price)
            .font(Typeface.number(quiet ? 16 : 19))
            .foregroundStyle(quiet && !selected ? Palette.inkSoft : Palette.ink)
            .lineLimit(1).minimumScaleFactor(0.7)
    }

    private func prices(withSaving: Bool) -> some View {
        VStack(alignment: .trailing, spacing: 0) {
            pricePair
            if withSaving, let saving { savingChip(saving).padding(.top, 3) }
        }
    }

    /// The price, and for the year the year at the monthly price struck through beside it, on one baseline.
    private var pricePair: some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            if let anchor { anchorPrice(anchor) }
            priceText
        }
    }

    /// The year at the monthly price, struck through beside the yearly price; VoiceOver says what it is.
    private func anchorPrice(_ anchor: String) -> some View {
        Text(verbatim: anchor).strikethrough(true, color: Palette.inkFaint)
            .font(Typeface.number(12)).foregroundStyle(Palette.inkFaint)
            .lineLimit(1).minimumScaleFactor(0.7)
            .accessibilityLabel(Text("\(anchor) if paid monthly"))
    }

    /// "Save 58%", in Pro gold.
    private func savingChip(_ percent: Int) -> some View {
        Badge(Text(verbatim: String(localized: "Save \(percent)%")), style: .pro)
    }
}

/// The plan track's rows laid out along the track, each step at its day's place (`positions`, 0 to 1 between the
/// centres of the end nodes, `inset` in from the edges). Nodes sit exactly there. Words are centred under their
/// node, the first and last held to the ends, each at most two fifths of the track wide (they wrap first), and pushed
/// apart just enough never to touch; when they can't all fit, they share the track in proportion and shrink a little.
private struct TrackSpread: Layout {
    var positions: [CGFloat]
    /// Words (true) or nodes (false).
    var words: Bool
    var inset: CGFloat = 12
    var spacing: CGFloat = 6

    private struct Slot {
        var x: CGFloat
        var width: CGFloat
    }

    private func anchor(_ index: Int, width: CGFloat) -> CGFloat {
        let position = index < positions.count ? positions[index] : 0
        return inset + position * max(0, width - 2 * inset)
    }

    private func slots(_ subviews: Subviews, width: CGFloat) -> [Slot] {
        let count = subviews.count
        guard count > 0 else { return [] }
        guard words else {
            return subviews.indices.map { index in
                let size = subviews[index].sizeThatFits(.unspecified).width
                return Slot(x: anchor(index, width: width) - size / 2, width: size)
            }
        }
        var widths = subviews.map { min(width * 0.4, $0.sizeThatFits(.unspecified).width) }
        let room = max(0, width - spacing * CGFloat(count - 1))
        let total = widths.reduce(0, +)
        if total > room, total > 0 { widths = widths.map { $0 * room / total } }
        var xs: [CGFloat] = widths.indices.map { index in
            if index == 0 { return 0 }
            if index == count - 1 { return width - widths[index] }
            return anchor(index, width: width) - widths[index] / 2
        }
        // Apart from the left, then held inside the right end, then apart from the right.
        for index in xs.indices.dropFirst() { xs[index] = max(xs[index], xs[index - 1] + widths[index - 1] + spacing) }
        xs[count - 1] = min(xs[count - 1], width - widths[count - 1])
        for index in xs.indices.dropLast().reversed() { xs[index] = min(xs[index], xs[index + 1] - spacing - widths[index]) }
        xs[0] = max(0, xs[0])
        return xs.indices.map { Slot(x: xs[$0], width: widths[$0]) }
    }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.replacingUnspecifiedDimensions().width
        var height: CGFloat = 0
        for (subview, slot) in zip(subviews, slots(subviews, width: width)) {
            height = max(height, subview.sizeThatFits(ProposedViewSize(width: slot.width, height: nil)).height)
        }
        return CGSize(width: width, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        for (subview, slot) in zip(subviews, slots(subviews, width: bounds.width)) {
            subview.place(at: CGPoint(x: bounds.minX + slot.x, y: bounds.minY), anchor: .topLeading,
                          proposal: ProposedViewSize(width: slot.width, height: nil))
        }
    }
}
