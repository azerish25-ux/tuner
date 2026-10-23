import StoreKit
import SwiftUI
import TimbreCore
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
    @State private var selectedID = TimbreProduct.annual
    @State private var appeared = false
    /// Notifications are off for Timbre: no reminder can arrive, so none is promised.
    @State private var remindersBlocked = false
    /// The trial track draws itself in from Today.
    @State private var trackDrawn = false
    // Measured layout. The plans, the whole trial timeline and the button show without scrolling; the
    // outcomes, the preview, the milestones and the counts line fill what is left, in that order, and what
    // does not fit waits just below the fold. Nothing rests under the pinned bar.
    @State private var containerHeight: CGFloat = 0
    @State private var barHeight: CGFloat = 0
    @State private var headerHeight: CGFloat = 66
    @State private var outcomesHeight: CGFloat = 92
    @State private var milestonesHeight: CGFloat = 46
    @State private var countsHeight: CGFloat = 16
    @State private var offerHeight: CGFloat = 230
    @State private var timelineHeight: CGFloat = 78

    /// The yearly plan unless the storefront left it out.
    private var selected: Product? { commerce.products.first { $0.id == selectedID } ?? commerce.products.first }

    /// Works both as a presented sheet (dismiss) and as the root overlay (the store flag).
    private func close() {
        if context == .standard { store.showPaywall = false }
        dismiss()
    }

    var body: some View {
        let pitch = self.pitch
        let plan = PaywallPlan.make(store: store, answers: answers, horizon: planHorizon)
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

    /// A trial is on offer (or may be, while the plans load), so its timeline keeps its place:
    /// choosing Monthly then never resizes the hero under the finger.
    private var reservesTimeline: Bool { commerce.products.isEmpty || (commerce.annual != nil && commerce.trialLabel != nil) }

    /// Headline (with its top inset), plans and trust row, and the trial timeline: what must show.
    private var essentials: CGFloat { headerHeight + 16 + offerHeight + (reservesTimeline ? timelineHeight : 0) }

    /// The Pro pill on its own row, when there is no preview for it to stand on.
    private static let pillRow: CGFloat = 40
    private static let previewTop: CGFloat = 6
    /// Below this the preview steps aside for the pill alone; above it, it grows to `previewMax`.
    private static let previewMin: CGFloat = 84
    private static let previewMax: CGFloat = 156
    private static let outcomesTop: CGFloat = 12
    private static let countsTop: CGFloat = 6
    private static let milestonesTop: CGFloat = 12

    /// Where each part of the pitch goes: above the fold when it fits, else just below it.
    private struct Fold {
        /// 0: no preview, the Pro pill stands on its own row.
        var preview: CGFloat = 0
        var outcomes = true
        var counts = true
        var milestones = true
    }

    /// The room beside the essentials goes to the outcomes, then the preview's minimum, the milestones, the
    /// preview's growth and the counts line. When not even the pill fits, the page scrolls anyway and
    /// everything stays in reading order above the fine print. A locked lesson's card replaces the preview.
    private func fold(_ pitch: Pitch, plan: PaywallPlan) -> Fold {
        var left = viewport - essentials
        guard left >= Self.pillRow else { return Fold() }
        var result = Fold()
        result.outcomes = left - Self.pillRow >= Self.outcomesTop + outcomesHeight
        if result.outcomes { left -= Self.outcomesTop + outcomesHeight }
        let previewFloor = Self.previewTop + Self.previewMin
        let previews = pitch.lesson == nil && left >= previewFloor
        left -= previews ? previewFloor : Self.pillRow
        result.milestones = !plan.milestones.isEmpty && left >= Self.milestonesTop + milestonesHeight
        if result.milestones { left -= Self.milestonesTop + milestonesHeight }
        if previews {
            let growth = max(0, min(left, Self.previewMax - Self.previewMin))
            result.preview = Self.previewMin + growth
            left -= growth
        }
        result.counts = result.outcomes && left >= Self.countsTop + countsHeight
        return result
    }

    /// Days the milestones may reach: the free trial's, else two weeks.
    private var planHorizon: Int { commerce.annual.map { trialDays($0) } ?? 14 }

    private func content(_ pitch: Pitch, plan: PaywallPlan) -> some View {
        let layout = fold(pitch, plan: plan)
        return VStack(spacing: 0) {
            VStack(spacing: 0) {
                if layout.preview > 0 {
                    preview(pitch, plan: plan, height: layout.preview)
                        .overlay(alignment: .bottom) { proPill.offset(y: 6) }
                        .padding(.top, Self.previewTop)
                } else {
                    proPill.padding(.top, 14)
                }
                header(pitch)
                    .onGeometryChange(for: CGFloat.self) { proxy in proxy.size.height } action: { height in headerHeight = height }
                    .padding(.top, layout.preview > 0 ? 16 : 10)
                if layout.outcomes {
                    outcomeList(plan).padding(.top, Self.outcomesTop)
                    if layout.counts { countsLine.padding(.top, Self.countsTop) }
                }
                offer
                    .onGeometryChange(for: CGFloat.self) { proxy in proxy.size.height } action: { height in offerHeight = height }
                // The plan's first days, right above the trial's: what you reach while it is free.
                if layout.milestones, !plan.milestones.isEmpty {
                    milestoneStrip(plan).padding(.top, Self.milestonesTop)
                }
                if showsTrialTimeline, let annual = commerce.annual {
                    trialTimeline(annual).padding(.top, 14)
                        .onGeometryChange(for: CGFloat.self) { proxy in proxy.size.height } action: { height in timelineHeight = height }
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

    /// What did not fit above the fold: the milestones first, then the outcomes with their counts line.
    /// A counts line that alone found no room is left out.
    @ViewBuilder private func belowFold(_ plan: PaywallPlan, layout: Fold) -> some View {
        let milestones = !layout.milestones && !plan.milestones.isEmpty
        if milestones || !layout.outcomes {
            VStack(spacing: 20) {
                if milestones { milestoneStrip(plan) }
                if !layout.outcomes {
                    VStack(spacing: Self.countsTop) {
                        outcomeList(plan)
                        countsLine
                    }
                }
            }
            .padding(.top, 28)
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

    /// What the paywall leads with: the person's plan, or what they just tried to open.
    private struct Pitch {
        var headline: Text
        var subhead: Text? = nil
        var lesson: LockedLesson? = nil
        /// The instrument to stand beside the preview's runway instead of the course's own.
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
            return Pitch(headline: Text("See yourself improve"), subhead: Text("Accuracy trends and milestones, measured on device"))
        case "custom_tuning":
            return Pitch(headline: Text("Unlimited custom tunings and string health"))
        case "temperament", "capo", "transpose":
            return Pitch(headline: Text("Temperaments, custom tunings and written pitch"))
        case "voice":
            return Pitch(headline: Text("Sing in tune"), subhead: Text("Range test and exercises"))
        default:
            break
        }
        if reason.hasSuffix("drone") { return Pitch(headline: Text("Unlock the Tanpura drone and every practice tool")) }
        if reason.hasPrefix("ear.") { return Pitch(headline: Text("Every ear game and practice tool"), subhead: Text("Pitch, intervals, chords")) }
        if reason.hasPrefix("metronome.") {
            return Pitch(headline: Text("Every instrument.\nEvery practice tool."), subhead: Text("Accents, odd meters, tap"))
        }
        if reason.hasPrefix("practice.") || reason.hasPrefix("daily.") {
            return Pitch(headline: Text("Every instrument.\nEvery practice tool."), subhead: Text("Chords, scales, intonation and drone"))
        }
        return generic
    }

    /// "Cello and 59 more on their own stage", with that instrument in the spotlight.
    private var instrumentPitch: Pitch {
        guard let instrument = store.paywallInstrumentId.flatMap({ store.catalog.instrument(id: $0) }) else {
            return Pitch(headline: Text("All sixty instruments in 3D"))
        }
        let photo = store.catalog.photo(instrumentId: instrument.id)
        let name = photo.map { NSLocalizedString("timbre_photo_" + $0.asset, bundle: .main, value: $0.label, comment: "") } ?? instrument.name.localized
        let others = max(0, store.catalog.instruments.count - 1)
        return Pitch(headline: Text("\(name) and \(others) more on their own stage"), instrumentAsset: photo?.asset)
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

    // MARK: Preview

    /// A few seconds of a play-along, looping: the person's instrument (or the one they just tried to open)
    /// beside a runway with one lane per string.
    private func preview(_ pitch: Pitch, plan: PaywallPlan, height: CGFloat) -> some View {
        let artwork: CourseArtwork
        let instrumentId: String?
        if let asset = pitch.instrumentAsset {
            artwork = .instrument(name: card(asset), render: true)
            instrumentId = store.paywallInstrumentId
        } else {
            artwork = plan.course.map { CourseArtwork.of($0, catalog: store.catalog) } ?? .emblem(.note)
            instrumentId = plan.course?.instrument
        }
        return PaywallPreview(artwork: artwork, accent: plan.accent, lanes: lanes(instrumentId), height: height)
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared || reduceMotion ? 0 : 12)
            .animation(.spring(response: 0.9, dampingFraction: 0.85), value: appeared)
    }

    /// One runway lane per string of the instrument's standard tuning (paired strings count once), four otherwise.
    private func lanes(_ instrumentId: String?) -> Int {
        guard let id = instrumentId, let instrument = store.catalog.instrument(id: id),
              let tuning = store.catalog.tuning(id: instrument.defaultTuningId) else { return 4 }
        return min(7, max(3, tuning.coursesByAnchor.count))
    }

    /// Studio render when the instrument has one, otherwise its photograph.
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
            if let subhead = pitch.subhead {
                subhead.font(.subheadline).foregroundStyle(Palette.inkSoft).multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 6)
            }
            if let lesson = pitch.lesson { lessonCard(lesson).padding(.top, 14) }
        }
        .frame(maxWidth: .infinity)
    }

    private var proPill: some View {
        Text("TIMBRE PRO").font(Typeface.label(12)).tracking(2.2).foregroundStyle(Color(hex: 0x1B1206))
            .padding(.horizontal, 14).padding(.vertical, 5)
            .background(Capsule().fill(Palette.proGold))
            .shadow(color: Color(hex: 0xE39A3B).opacity(0.35), radius: 10, y: 3)
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

    /// What Pro holds in all, small, under the outcomes (lined up with their text) when there is room.
    private var countsLine: some View {
        Text("\(store.curriculum.lessonCount) lessons across \(store.curriculum.courses.count) courses")
            .font(.caption).foregroundStyle(Palette.inkFaint)
            .lineLimit(2).fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.leading, 6 + Self.benefitArt + 10)
            .onGeometryChange(for: CGFloat.self) { proxy in proxy.size.height } action: { height in countsHeight = height }
    }

    // MARK: Milestones

    /// The plan's first days beside the trial's: today's lesson and the units the plan reaches while the
    /// trial is free, after the course's own art.
    private func milestoneStrip(_ plan: PaywallPlan) -> some View {
        HStack(alignment: .top, spacing: 10) {
            if let course = plan.course { CourseArt(course: course, size: 28) }
            HStack(alignment: .top, spacing: 8) {
                ForEach(Array(plan.milestones.enumerated()), id: \.element.id) { index, milestone in
                    milestoneColumn(milestone, first: index == 0)
                        .opacity(appeared ? 1 : 0)
                        .offset(y: appeared || reduceMotion ? 0 : 6)
                        .animation(.spring(response: 0.6, dampingFraction: 0.85).delay(0.3 + Double(index) * 0.12), value: appeared)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 2)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(milestonesSpoken(plan.milestones))
        .onGeometryChange(for: CGFloat.self) { proxy in proxy.size.height } action: { height in milestonesHeight = height }
    }

    private func milestoneColumn(_ milestone: PaywallPlan.Milestone, first: Bool) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 4) {
                Image(systemName: first ? "play.fill" : "flag.fill").font(.system(size: 8, weight: .bold))
                milestoneDay(milestone.day).font(Typeface.label(11)).lineLimit(1)
            }
            .foregroundStyle(Palette.amber)
            Text(milestone.title).font(.caption).foregroundStyle(Palette.ink)
                .lineLimit(2).minimumScaleFactor(0.85)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func milestoneDay(_ day: Int) -> Text { day == 1 ? Text("Today") : Text("Day \(day)") }

    /// "Your plan. Today: Three notes on string 2. Day 7: First chords. …"
    private func milestonesSpoken(_ milestones: [PaywallPlan.Milestone]) -> Text {
        milestones.reduce(Text("Your plan") + Text(verbatim: ". ")) { (label: Text, milestone: PaywallPlan.Milestone) -> Text in
            label + milestoneDay(milestone.day) + Text(verbatim: ": \(milestone.title). ")
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
                    planRow(annual, title: "Yearly", detail: perMonth(annual), tag: annualTag(annual), saving: annualSaving)
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

    private func select(_ product: Product) {
        guard selected?.id != product.id else { return }
        withAnimation(Motion.quick) { selectedID = product.id }
        Haptics.shared.selection()
    }

    private func planRow(_ product: Product, title: LocalizedStringKey, detail: String, tag: String?, saving: Int?) -> some View {
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
                Text(product.displayPrice).font(Typeface.number(19)).foregroundStyle(Palette.ink)
                    .lineLimit(1).minimumScaleFactor(0.7)
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

    // MARK: Trial

    private var showsTrialTimeline: Bool { selected?.id == TimbreProduct.annual && commerce.trialLabel != nil }

    private struct TrialStep {
        let symbol: String
        let title: Text
        let detail: Text
    }

    /// The reminder step only appears when notifications can reach the person.
    private func trialSteps(_ annual: Product, days: Int) -> [TrialStep] {
        var steps = [TrialStep(symbol: "lock.open.fill", title: Text("Today"), detail: Text("Everything unlocked"))]
        if !remindersBlocked { steps.append(TrialStep(symbol: "bell.fill", title: Text("Day \(max(1, days - 2))"), detail: Text("We remind you"))) }
        steps.append(TrialStep(symbol: "creditcard.fill", title: Text("Day \(days)"), detail: Text("\(annual.displayPrice)/year")))
        return steps
    }

    /// No surprises, in one compact strip: what happens on which day of the free trial.
    /// Without notifications the strip says how to cancel instead of promising a reminder.
    private func trialTimeline(_ annual: Product) -> some View {
        let days = trialDays(annual)
        let steps = trialSteps(annual, days: days)
        let last = steps.count - 1
        return VStack(spacing: 6) {
            HStack(spacing: 6) {
                ForEach(steps.indices, id: \.self) { index in
                    steps[index].title.font(Typeface.label(12)).foregroundStyle(index == 0 ? Palette.mint : Palette.ink)
                        .lineLimit(1).minimumScaleFactor(0.8)
                        .frame(maxWidth: .infinity, alignment: Self.edge(index, last))
                }
            }
            trialTrack(steps)
            HStack(alignment: .top, spacing: 6) {
                ForEach(steps.indices, id: \.self) { index in
                    steps[index].detail.font(.caption).foregroundStyle(Palette.inkSoft)
                        .multilineTextAlignment(Self.textEdge(index, last))
                        .lineLimit(2).minimumScaleFactor(0.85)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: Self.edge(index, last))
                }
            }
            if remindersBlocked {
                Text("Cancel anytime in Settings before day \(days).")
                    .font(.footnote).foregroundStyle(Palette.inkSoft).multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 2)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(trialSpoken(steps))
        .onAppear { withAnimation(reduceMotion ? nil : Animation.easeOut(duration: 0.9).delay(0.25)) { trackDrawn = true } }
        .onDisappear { trackDrawn = false }
    }

    /// Nodes on a line from Today to the first charge; the line draws itself in and each node pops as it passes.
    private func trialTrack(_ steps: [TrialStep]) -> some View {
        let drawn = trackDrawn || reduceMotion
        return HStack(spacing: 0) {
            ForEach(steps.indices, id: \.self) { index in
                if index > 0 { Spacer(minLength: 12) }
                trialNode(steps[index].symbol, first: index == 0)
                    .scaleEffect(drawn ? 1 : 0.6)
                    .opacity(drawn ? 1 : 0.3)
                    .animation(reduceMotion ? nil : Motion.pluck.delay(0.25 + Double(index) * 0.28), value: trackDrawn)
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

    private func trialNode(_ symbol: String, first: Bool) -> some View {
        Image(systemName: symbol).font(.system(size: 10, weight: .bold))
            .foregroundStyle(first ? Palette.onAccent : Palette.mint)
            .frame(width: 24, height: 24)
            .background(Circle().fill(first ? AnyShapeStyle(Palette.mint) : AnyShapeStyle(Palette.stageRaised)))
            .overlay(Circle().strokeBorder(Palette.mint.opacity(first ? 0 : 0.45), lineWidth: 1))
            .shadow(color: Palette.mint.opacity(first ? 0.45 : 0), radius: 8)
    }

    /// "Today: Everything unlocked. Day 12: We remind you. …" in reading order.
    private func trialSpoken(_ steps: [TrialStep]) -> Text {
        steps.reduce(Text(verbatim: "")) { (label: Text, step: TrialStep) -> Text in
            label + step.title + Text(verbatim: ": ") + step.detail + Text(verbatim: ". ")
        }
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
