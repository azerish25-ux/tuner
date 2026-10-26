import Charts
import SwiftUI
import TimbreCore

/// Progress: streak, level and accuracy, the coach, the week in review, the practice calendar, string health,
/// achievements, history. Calm mode (`UserSettings.calmMode`) shows the time played in place of the streak and the
/// level, and the coach and the week leave the streak out.
struct JourneyView: View {
    @EnvironmentObject private var store: AppStore
    @EnvironmentObject private var commerce: CommerceService
    /// A lesson the coach opened (the weak-spot drill, or a lesson to replay), zooming out of its card.
    @State private var coachLesson: CoachLesson?
    @Namespace private var zoom
    @State private var confirmRestring = false
    /// The string-health bars grow from the baseline once.
    @State private var driftShown = false
    /// Every badge or only the first rows (the latest earned beside the goals closest to done).
    @State private var allBadges = false
    /// The badge grid's width, for its column count.
    @State private var badgeGridWidth: CGFloat = 0
    /// The badge whose details are showing.
    @State private var openBadge: String?
    /// Badges earned since the last visit: their medals catch the light once.
    @State private var shining: Set<String> = []
    /// Ids of the earned badges already shown here (comma-separated).
    @AppStorage("journey.badgesSeen") private var badgesSeen = ""
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.horizontalSizeClass) private var sizeClass

    var body: some View {
        NavigationStack {
            board
                .fullScreenCover(item: $coachLesson) { item in
                    LessonPlayer(course: item.course, lesson: item.lesson) { next in
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) { openCoachLesson(item.course, next) }
                    }
                    .environmentObject(store)
                    .navigationTransition(.zoom(sourceID: Self.coachSource, in: zoom))
                }
        }
    }

    // MARK: Layout

    /// A phone (or any compact width) gets one column; an iPad's regular width two columns of cards (`CardColumns`).
    @ViewBuilder private var board: some View {
        if sizeClass == .regular {
            GeometryReader { proxy in
                let columns = CardColumns(width: proxy.size.width - 2 * Metrics.gutter)
                scroller {
                    if columns.count > 1 { wideBoard(columns) } else { compactBoard }
                }
            }
        } else {
            scroller { compactBoard }
        }
    }

    /// The tab's scroll view. Its top shade comes in once content slides under the status bar (and, on iPad, the
    /// tab bar), so a heading never runs under the clock.
    private func scroller<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        ScrollView {
            // The foot clears the floating tab bar by a little rather than touching it (RootView fades what scrolls under it).
            content()
                .padding(.horizontal, Metrics.gutter).padding(.top, 12).padding(.bottom, 28)
        }
        .stageTopShade()
        .background(StageBackground(motes: false))
    }

    /// The tab's title. No streak or level controls beside it: this is the screen they lead to.
    private var title: some View {
        ScreenTitle(title: "Progress")
    }

    @ViewBuilder private var insights: some View {
        if commerce.isPro { accuracy } else { lockedInsights }
    }

    private var compactBoard: some View {
        VStack(alignment: .leading, spacing: 20) {
            title
            stats()
            coach
            weekCard
            calendar
            stringHealth
            insights
            achievements
            recent
        }
    }

    /// iPad: the figures in one summary bar across the top (not phone tiles stretched across the width), the cards in
    /// columns of a phone's proportions so no calendar row or bar chart is stretched across the screen, and the badges
    /// across the foot,
    /// where the width shows more of them per row. Recent closes the last column and stops level with the others
    /// (`BalancedColumns`), showing as many sessions as fit, rather than running on beside an empty stretch.
    private func wideBoard(_ columns: CardColumns) -> some View {
        VStack(alignment: .leading, spacing: 20) {
            title
            statBar
            BalancedColumns(width: columns.unit) {
                if columns.count >= 3 {
                    column {
                        coach
                        weekCard
                    }
                    column {
                        calendar
                        stringHealth
                    }
                    column {
                        insights
                        fittedRecent
                    }
                } else {
                    column {
                        coach
                        weekCard
                        calendar
                    }
                    column {
                        stringHealth
                        insights
                        fittedRecent
                    }
                }
            }
            achievements
        }
    }

    /// One column of cards, as wide as `BalancedColumns` makes it.
    private func column<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 20) { content() }
            .frame(maxWidth: .infinity, alignment: .topLeading)
    }

    /// iPad: Recent with as many sessions as the column has room for beside the others (twelve at most, two at least),
    /// its card reaching down to where they end.
    private var fittedRecent: some View {
        // One session at a time, so the card ends less than a row short of the columns beside it.
        ViewThatFits(in: .vertical) {
            recentList(limit: 12).stillCard()
            recentList(limit: 10).stillCard()
            recentList(limit: 9).stillCard()
            recentList(limit: 8).stillCard()
            recentList(limit: 7).stillCard()
            recentList(limit: 6).stillCard()
            recentList(limit: 5).stillCard()
            recentList(limit: 4).stillCard()
            recentList(limit: 3).stillCard()
            recentList(limit: 2).stillCard()
        }
    }

    // MARK: Coach

    private static let coachSource = "journey.coach"

    /// What the coach makes of everything Progress shows: string drift, what slipped in the course Learn shows,
    /// the streak and Today, the week, and the timing of lessons played in the last hours.
    private var coachNotes: [CoachNote] {
        let course = store.learnCourse
        let today = store.dailySet.map { Coach.TodayStep(activity: $0, done: store.dailyDone($0.kind)) }
        let streak = store.streak
        let context = Coach.JourneyContext(records: store.records, streakDays: streak.current, practicedToday: streak.practicedToday,
                                           drift: store.stringDrift, restrung: store.progress.restrung[store.instrument.id],
                                           course: course, learn: store.learn,
                                           canReview: course.map { store.weakSpotReview(in: $0) != nil } ?? false,
                                           today: today, takes: CoachTakes.shared.takes(since: Date().addingTimeInterval(-12 * 3600)))
        let notes = Coach.journeyNotes(context)
        guard store.settings.calmMode else { return notes }
        // Calm mode: no nudge about keeping the streak alive.
        return notes.filter { note in
            if case .streak = note.fact { return false }
            return true
        }
    }

    private var coachVoice: CoachVoice {
        let labels = stringLabels
        let curriculum = store.curriculum
        let drill = store.learnCourse.flatMap { store.weakSpotReview(in: $0) }?.minutes ?? 4
        return CoachVoice(stringName: { labels[$0] ?? $0 },
                          lessonTitle: { curriculum.lesson(id: $0)?.lesson.title.localized },
                          drillMinutes: drill)
    }

    private var coach: some View {
        CoachPanel(notes: coachNotes, voice: coachVoice) { action in performCoach(action) }
            .matchedTransitionSource(id: Self.coachSource, in: zoom)
    }

    /// Lessons and the drill open here, out of the card; the metronome, the tuner and Today on their tabs.
    private func performCoach(_ action: CoachAction) {
        Haptics.shared.selection()
        CoachRoute.log(action, screen: "progress")
        switch action {
        case let .review(courseId):
            guard let course = store.curriculum.course(id: courseId), let review = store.weakSpotReview(in: course) else { return }
            openCoachLesson(course, review)
        case let .lesson(id):
            guard let found = store.curriculum.lesson(id: id) else { return }
            openCoachLesson(found.course, found.lesson)
        default:
            CoachRoute.open(action, store: store)
        }
    }

    private func openCoachLesson(_ course: LearnCourse, _ lesson: Lesson) {
        guard store.canPlay(lesson) else { store.presentPaywall("lesson", lesson: lesson); return }
        coachLesson = CoachLesson(course: course, lesson: lesson)
    }

    /// Streak, level and how close tune-ups land: three tiles across, stacked one per row at the accessibility sizes
    /// (`StatTileRow`), so "day streak" and the level's name never truncate.
    /// The third is a distance in cents, so it says "cents off" rather than "accuracy" (a percentage everywhere else),
    /// with the unit spelled out ("Average ¢ off" made the caption read like a formula).
    /// Calm mode: this week's minutes and the cents off, with no streak or level.
    @ViewBuilder private func stats() -> some View {
        let level = store.level
        if store.settings.calmMode {
            StatTileRow {
                StatTile(symbol: "clock", tint: Palette.accentNeutral, value: Text(weekMinutes, format: .number), label: "minutes this week")
                StatTile(symbol: "scope", tint: Palette.inkSoft, value: WeekRecap.centsText(averageCents), label: "Avg. cents off")
            }
        } else {
            StatTileRow {
                StatTile(value: Text("\(store.streak.current)"), label: Text("day streak")) {
                    Glyph(.lamp, size: 18, tint: Palette.flame)
                }
                StatTile(value: levelValue(level.number), label: Text(LocalizedStringKey(level.name))) {
                    LevelArc(progress: level.progress(store.progress.xp), size: 18)
                }
                .accessibilityLabel(Text("Level \(level.number)") + Text(verbatim: ", ") + Text(LocalizedStringKey(level.name)))
                StatTile(symbol: "scope", tint: Palette.inkSoft, value: WeekRecap.centsText(averageCents), label: "Avg. cents off")
            }
        }
    }

    /// iPad: the same figures in one bar across the board, each centred in its share.
    private var statBar: some View {
        let level = store.level
        let cents = StatBar.Figure(id: "cents", symbol: "scope", tint: Palette.inkSoft, value: WeekRecap.centsText(averageCents), label: Text("Avg. cents off"))
        if store.settings.calmMode {
            return StatBar([
                StatBar.Figure(id: "minutes", symbol: "clock", tint: Palette.accentNeutral, value: Text(weekMinutes, format: .number), label: Text("minutes this week")),
                cents,
            ])
        }
        return StatBar([
            StatBar.Figure(id: "streak", value: Text("\(store.streak.current)"), label: Text("day streak")) {
                Glyph(.lamp, size: Glyph.lead, tint: Palette.flame)
            },
            StatBar.Figure(id: "level", value: levelValue(level.number), label: Text(LocalizedStringKey(level.name)),
                           spoken: Text("Level \(level.number)") + Text(verbatim: ", ") + Text(LocalizedStringKey(level.name))) {
                LevelArc(progress: level.progress(store.progress.xp), size: Glyph.lead)
            },
            cents,
        ])
    }

    /// Minutes played in the last seven days (as "Your week" counts them).
    private var weekMinutes: Int { WeekRecap(records: store.records, streak: store.streak).minutes }

    /// The mean distance of the last ten tune-ups, in cents; nil before there are any.
    private var averageCents: Double? {
        let recent = tuningSessions.suffix(10).compactMap(\.meanAbsoluteCents)
        return recent.isEmpty ? nil : recent.reduce(0, +) / Double(recent.count)
    }

    /// "LV 5": the level reads as a level, not a count (the mark the level ring carries).
    private func levelValue(_ number: Int) -> Text {
        Text("LV").font(Typeface.label(.footnote)).foregroundStyle(Palette.mint) + Text(verbatim: " ") + Text(number, format: .number)
    }

    /// The last seven days with a poster to share; hidden until there is practice in them.
    @ViewBuilder private var weekCard: some View {
        let recap = WeekRecap(records: store.records, streak: store.streak)
        if !recap.isEmpty { WeekRecapCard(recap: recap) }
    }

    /// Last five weeks, one tile per day under its weekday's initial: brighter for more practice. Today is the
    /// last tile (its initial mint with a dot), outlined dashed until you play and ringed once you have.
    private var calendar: some View {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        let days = store.streak.activeDays
        let minutesByDay = Dictionary(grouping: store.records, by: { cal.startOfDay(for: $0.date) }).mapValues { $0.compactMap(\.durationMs).reduce(0, +) / 60000 }
        let start = cal.date(byAdding: .day, value: -34, to: today)!
        let active = (0..<35).filter { days.contains(cal.date(byAdding: .day, value: $0, to: start)!) }.count
        return VStack(alignment: .leading, spacing: 12) {
            JourneyCardHeading("Last five weeks") {
                Text("\(active) of 35 days").font(.caption).foregroundStyle(Palette.inkSoft)
            }
            weekdayHeader(start: start)
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 7), spacing: 6) {
                ForEach(0..<35, id: \.self) { offset in
                    let date = cal.date(byAdding: .day, value: offset, to: start)!
                    let played = days.contains(date)
                    let minutes = minutesByDay[date] ?? 0
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .fill(played ? Palette.mint.opacity(min(1, 0.35 + Double(minutes) / 15)) : .white.opacity(0.06))
                        .frame(height: 26)
                        .overlay {
                            if date == today && !played {
                                RoundedRectangle(cornerRadius: 7, style: .continuous).strokeBorder(Palette.controlLine, style: StrokeStyle(lineWidth: 1.5, dash: [3, 3]))
                            } else if date == today {
                                RoundedRectangle(cornerRadius: 7, style: .continuous).strokeBorder(Palette.ink.opacity(0.9), lineWidth: 2)
                            }
                        }
                }
            }
        }
        .stillCard()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("Practiced on \(active) of the last 35 days"))
    }

    /// The calendar's column heads: each weekday's initial, the last column today's (mint, with a dot).
    private func weekdayHeader(start: Date) -> some View {
        HStack(spacing: 6) {
            ForEach(0..<7, id: \.self) { column in
                let date = Calendar.current.date(byAdding: .day, value: column, to: start) ?? start
                let today = column == 6
                VStack(spacing: 3) {
                    Text(date, format: .dateTime.weekday(.narrow))
                        .font(Typeface.label(.caption)).foregroundStyle(today ? Palette.mint : Palette.inkSoft)
                    Circle().fill(today ? Palette.mint : .clear).frame(width: 4, height: 4)
                }
                .frame(maxWidth: .infinity)
            }
        }
        .accessibilityHidden(true)
    }

    /// How each string of this instrument drifts between sessions, and when to restring.
    private var stringHealth: some View {
        let drift = store.stringDrift
        let restrung = store.progress.restrung[store.instrument.id]
        let advice = StringHealth.needsRestring(drift, restrung: restrung)
        let anchors = store.courses.compactMap(\.anchorId).reduce(into: [String]()) { if !$0.contains($1) { $0.append($1) } }
        let worst = drift.first
        let labels = stringLabels
        return VStack(alignment: .leading, spacing: 10) {
            JourneyCardHeading("String health") {
                if advice { Text("Restring soon").font(.caption.weight(.semibold)).foregroundStyle(Palette.adjust) }
            }
            Group {
                if let worst, abs(worst.centsPerDay) >= 1, coachSaysDrift(of: worst.anchor) {
                    // The coach card already says it, with its tune-up: here the chart speaks for itself.
                    Text("Each string’s drift, in cents a day.")
                } else if let worst, abs(worst.centsPerDay) >= 1 {
                    // ¢, as the coach above it says it ("drifts 7¢ flat a day").
                    Text("Your \(labels[worst.anchor] ?? worst.anchor) string drifts \(worst.centsPerDay < 0 ? String(localized: "flat") : String(localized: "sharp")) about \(Int(abs(worst.centsPerDay).rounded()))¢ a day.")
                } else if !drift.isEmpty {
                    Text("Your strings are holding their pitch well.")
                } else {
                    Text("Tune on a few different days and Timbre learns how each string drifts.")
                }
            }
            .font(.subheadline).foregroundStyle(Palette.inkSoft).fixedSize(horizontal: false, vertical: true)
            if !drift.isEmpty {
                driftChart(drift, anchors: anchors, labels: labels)
            }
            Button { confirmRestring = true } label: {
                Label(restrung.map { String(localized: "Restrung \($0.formatted(.relative(presentation: .named)))") } ?? String(localized: "I just restrung"), systemImage: "arrow.triangle.2.circlepath")
                    .font(.footnote.weight(.semibold))
            }
            // A text link (underlined with Button Shapes on), in a 44 pt target.
            .buttonStyle(TextLinkStyle())
            .confirmationDialog("Mark new strings on \(store.instrumentDisplayName)?", isPresented: $confirmRestring, titleVisibility: .visible) {
                Button("I just restrung") { store.markRestrung() }
            }
            .accessibilityIdentifier("journey.restrung")
        }
        .stillCard(tint: advice ? Palette.adjust : nil)
    }

    /// Whether the coach is telling how this string drifts (its tip on this screen), so String health doesn't print
    /// the same sentence under it.
    private func coachSaysDrift(of anchor: String) -> Bool {
        coachNotes.contains { note in
            if case let .drift(drifting, _) = note.fact { return drifting == anchor }
            return false
        }
    }

    /// Each string's name as the tuner labels it ("G"), by its anchor id.
    private var stringLabels: [String: String] {
        Dictionary(store.courses.compactMap { c in c.anchorId.map { ($0, NoteReadout.split(TargetLabelFormatter.splitCue(store.courseLabel(c)).main).name) } },
                   uniquingKeysWith: { a, _ in a })
    }

    /// Drift per string as bars of one width on a shared baseline, signed ¢/day above each,
    /// with a dashed line at the 4 ¢/day restring threshold.
    private func driftChart(_ drift: [StringDrift], anchors: [String], labels: [String: String]) -> some View {
        let peak = max(6, drift.map { abs($0.centsPerDay) }.max() ?? 6)
        let height: CGFloat = 56
        let threshold = height * CGFloat(4 / peak)
        return VStack(spacing: 6) {
            HStack(alignment: .bottom, spacing: 0) {
                ForEach(anchors, id: \.self) { anchor in
                    driftBar(drift.first { $0.anchor == anchor }?.centsPerDay, peak: peak, height: height)
                        .frame(maxWidth: .infinity)
                }
            }
            .overlay(alignment: .bottom) {
                DriftThresholdLine().stroke(Palette.adjust.opacity(0.4), style: StrokeStyle(lineWidth: 1, dash: [3, 4]))
                    .frame(height: 1).offset(y: -threshold)
            }
            .overlay(alignment: .bottom) { Hairline() }
            HStack(spacing: 0) {
                ForEach(anchors, id: \.self) { anchor in
                    let bad = abs(drift.first { $0.anchor == anchor }?.centsPerDay ?? 0) >= 4
                    Text(labels[anchor] ?? anchor).font(.caption.weight(bad ? .bold : .medium))
                        .foregroundStyle(bad ? Palette.adjust : Palette.inkSoft)
                        .lineLimit(1).minimumScaleFactor(0.7)
                        .frame(maxWidth: .infinity)
                }
            }
        }
        .padding(.top, 4)
        .accessibilityHidden(true)
        .onAppear { withAnimation(reduceMotion ? nil : Motion.settle.delay(0.15)) { driftShown = true } }
    }

    private func driftBar(_ rate: Double?, peak: Double, height: CGFloat) -> some View {
        let magnitude = abs(rate ?? 0)
        let bad = magnitude >= 4
        let tint = bad ? Palette.adjust : Palette.mint
        let bar = rate == nil ? 0 : max(4, height * CGFloat(min(1, magnitude / peak)))
        let top = UnevenRoundedRectangle(topLeadingRadius: 5, topTrailingRadius: 5, style: .continuous)
        return VStack(spacing: 5) {
            Group {
                if let rate {
                    Text(verbatim: Self.signed(rate)).font(Typeface.number(.caption))
                } else {
                    // The one placeholder for a value not measured yet, as everywhere in the app.
                    Text("Not yet").font(.caption2)
                }
            }
            .foregroundStyle(bad ? Palette.adjust : Palette.inkSoft)
            .lineLimit(1).minimumScaleFactor(0.6)
            ZStack(alignment: .bottom) {
                top.fill(.white.opacity(0.05)).frame(height: height)
                top.fill(LinearGradient(colors: [tint, tint.opacity(bad ? 0.7 : 0.45)], startPoint: .top, endPoint: .bottom))
                    .frame(height: driftShown ? bar : 0)
            }
            .frame(width: 16)
        }
    }

    /// Whole cents a day with a sign and the unit, as the line above the chart says it: "−7¢" goes flat, "+2¢" sharp
    /// (a bare "−7" over a bar didn't say what it counted).
    private static func signed(_ rate: Double) -> String {
        let n = Int(rate.rounded())
        if n == 0 { return 0.formatted() + "¢" }
        return (n > 0 ? "+" : "−") + abs(n).formatted() + "¢"
    }

    /// Rows of badges shown before "Show all".
    private static let collapsedRows = 3
    /// The narrowest a badge cell gets, and the space between cells.
    private static let badgeCellWidth: CGFloat = 92
    private static let badgeSpacing: CGFloat = 10

    /// As many columns as cells of `badgeCellWidth` fit (three on a phone).
    private var badgeColumns: Int {
        max(3, Int((badgeGridWidth + Self.badgeSpacing) / (Self.badgeCellWidth + Self.badgeSpacing)))
    }

    private var achievements: some View {
        let columns = badgeColumns
        let collapsed = columns * Self.collapsedRows
        let badges = badgeProgress(collapsed: collapsed, columns: columns)
        let earnedCount = badges.filter(\.earned).count
        let shown = allBadges ? badges : Array(badges.prefix(collapsed))
        return VStack(alignment: .leading, spacing: 14) {
            JourneyCardHeading("Achievements") {
                // The same counter as under each medal ("3 / 10"), read "9 of 42".
                Text.fraction(earnedCount, Achievements.all.count).font(.caption).foregroundStyle(Palette.inkSoft)
            }
            badgeGrid(shown, columns: columns)
                .onGeometryChange(for: CGFloat.self) { proxy in proxy.size.width } action: { width in badgeGridWidth = width }
            if badges.count > collapsed {
                Button {
                    withMotion(Motion.settle, reduceMotion: reduceMotion) { allBadges.toggle() }
                    Haptics.shared.selection()
                } label: {
                    HStack(spacing: 6) {
                        Text(allBadges ? LocalizedStringKey("Show fewer") : LocalizedStringKey("Show all"))
                        Image(systemName: "chevron.down").rotationEffect(.degrees(allBadges ? 180 : 0))
                    }
                    .font(.footnote.weight(.semibold))
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(TextLinkStyle())
                .accessibilityIdentifier("journey.badges.more")
            }
        }
        .stillCard()
        .onAppear(perform: noteNewBadges)
    }

    /// Earned badges not seen here before shine once; from now on they count as seen.
    private func noteNewBadges() {
        let earned = store.progress.achievements
        let seen = Set(badgesSeen.split(separator: ",").map(String.init))
        shining = Set(earned).subtracting(seen)
        badgesSeen = earned.joined(separator: ",")
    }

    /// Rows of equal-width cells, each row as tall as its tallest cell with every status line at the row's foot:
    /// a title that wraps to two lines moves its row's counters down together, and a row whose titles all fit
    /// on one line has no empty line before them.
    private func badgeGrid(_ badges: [BadgeProgress], columns: Int) -> some View {
        let rows = stride(from: 0, to: badges.count, by: columns).map { Array(badges[$0..<min($0 + columns, badges.count)]) }
        return VStack(spacing: 18) {
            ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                HStack(alignment: .top, spacing: Self.badgeSpacing) {
                    ForEach(row) { badge in badgeCell(badge) }
                    // A short last row keeps the columns' width.
                    ForEach(row.count..<columns, id: \.self) { _ in
                        Color.clear.frame(height: 0).frame(maxWidth: .infinity)
                    }
                }
                .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    /// The first rows pair the latest earned badges (one row) with the locked ones closest to their goal, so the
    /// next goals show before "Show all"; after them the other earned badges, latest first, then the other locked
    /// ones, closest first. With few locked badges left, more earned ones fill the first rows (and the other way round).
    private func badgeProgress(collapsed: Int, columns: Int) -> [BadgeProgress] {
        let state = store.progress
        // Earned ids are appended as they are earned, so a later position is a more recent badge.
        let earnedAt = Dictionary(state.achievements.enumerated().map { ($0.element, $0.offset) }, uniquingKeysWith: { first, _ in first })
        let streakBest = store.streak.best
        let custom = store.settings.customTunings?.count ?? 0
        let metrics = store.badgeMetrics
        var all: [BadgeProgress] = []
        for (index, a) in Achievements.all.enumerated() {
            let value = a.value(state, streakBest: streakBest, customTunings: custom, metrics: metrics)
            all.append(BadgeProgress(achievement: a, earnedAt: earnedAt[a.id], value: value, order: index))
        }
        let earned = all.filter(\.earned).sorted(by: BadgeProgress.later)
        let locked = all.filter { !$0.earned }.sorted(by: BadgeProgress.closer)
        let latest = min(earned.count, max(columns, collapsed - locked.count))
        let closest = min(locked.count, max(0, collapsed - latest))
        var ordered = Array(earned.prefix(latest))
        ordered += locked.prefix(closest)
        ordered += earned.dropFirst(latest)
        ordered += locked.dropFirst(closest)
        return ordered
    }

    /// Instrument artwork for a course badge (the course's instrument cut-out), nil for the others.
    private func badgeImage(_ achievement: Achievement) -> String? {
        guard let courseId = Achievements.courseId(of: achievement),
              let instrument = store.curriculum.course(id: courseId)?.instrument else { return nil }
        return store.catalog.photo(instrumentId: instrument)?.asset
    }

    /// Medal, the title (one line, or two when it needs them) and one line of status ("Earned" or "38 / 50") at
    /// the cell's foot, which stretches to its row's height so the counters line up across the row.
    /// Tapping shows what the badge asks for.
    private func badgeCell(_ badge: BadgeProgress) -> some View {
        let a = badge.achievement
        let shown = min(badge.value, a.goal)
        return Button {
            openBadge = a.id
            Haptics.shared.selection()
        } label: {
            VStack(spacing: 0) {
                AchievementMedal(achievement: a, earned: badge.earned, size: 58, progress: badge.earned ? nil : badge.fraction,
                                 image: badgeImage(a), shine: shining.contains(a.id))
                    .padding(.bottom, 8)
                Text(LocalizedStringKey(a.title)).font(.caption.weight(.semibold))
                    .foregroundStyle(badge.earned ? Palette.ink : Palette.inkSoft)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.85)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 6)
                status(badge, shown: shown)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .contentShape(Rectangle())
        }
        .buttonStyle(PressScaleStyle())
        .popover(isPresented: Binding(get: { openBadge == a.id }, set: { if !$0 && openBadge == a.id { openBadge = nil } })) {
            badgeDetail(badge, shown: shown)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(LocalizedStringKey(a.title)))
        .accessibilityValue(badge.earned ? Text("Earned") : Text(LocalizedStringKey(a.detail)) + Text(verbatim: ", ") + Text("\(shown) of \(a.goal)"))
        .accessibilityAddTraits(.isButton)
        .accessibilityIdentifier("badge.\(a.id)")
    }

    /// One line under every medal: the tier's colour once earned, the count toward the goal while locked.
    @ViewBuilder private func status(_ badge: BadgeProgress, shown: Int) -> some View {
        if badge.earned {
            Text("Earned").font(Typeface.label(.caption)).foregroundStyle(badge.achievement.tier.ink)
                .lineLimit(1).minimumScaleFactor(0.8)
        } else {
            Text.fraction(shown, badge.achievement.goal).font(Typeface.number(.caption))
                .foregroundStyle(shown > 0 ? Palette.ink : Palette.inkSoft)
                .lineLimit(1).minimumScaleFactor(0.8)
        }
    }

    /// The popover: what the badge asks for and how far along it is.
    private func badgeDetail(_ badge: BadgeProgress, shown: Int) -> some View {
        let a = badge.achievement
        return HStack(alignment: .center, spacing: 14) {
            AchievementMedal(achievement: a, earned: badge.earned, size: 48, progress: badge.earned ? nil : badge.fraction, image: badgeImage(a))
            VStack(alignment: .leading, spacing: 5) {
                Text(LocalizedStringKey(a.title)).font(.headline).foregroundStyle(Palette.ink)
                Text(LocalizedStringKey(a.detail)).font(.subheadline).foregroundStyle(Palette.inkSoft)
                    .fixedSize(horizontal: false, vertical: true)
                if badge.earned {
                    Text("Earned").font(Typeface.label(.caption)).foregroundStyle(a.tier.ink)
                } else {
                    HStack(spacing: 8) {
                        ProgressLine(value: badge.fraction, color: Palette.mint, height: 5).frame(width: 110)
                        Text.fraction(shown, a.goal).font(Typeface.number(.caption)).foregroundStyle(Palette.inkSoft)
                    }
                }
            }
        }
        .padding(16)
        .frame(maxWidth: 320, alignment: .leading)
        .presentationCompactAdaptation(.popover)
        .presentationBackground(Palette.surface)
        .environment(\.colorScheme, .dark)
    }

    private var tuningSessions: [PracticeRecord] {
        store.records.filter { $0.kind == "tuning" && $0.meanAbsoluteCents != nil }.sorted { $0.date < $1.date }.suffix(40).map { $0 }
    }

    private var accuracy: some View {
        VStack(alignment: .leading, spacing: 10) {
            CardTitle("Tuning accuracy").accessibilityIdentifier("journey.accuracy")
            if tuningSessions.count < 2 {
                Text("Tune a few times to see how close you land.").font(.subheadline).foregroundStyle(Palette.inkSoft)
            } else {
                Chart(tuningSessions) { record in
                    LineMark(x: .value("Date", record.date), y: .value("Cents", record.meanAbsoluteCents ?? 0))
                        .interpolationMethod(.catmullRom).foregroundStyle(Palette.mint)
                    PointMark(x: .value("Date", record.date), y: .value("Cents", record.meanAbsoluteCents ?? 0)).foregroundStyle(Palette.mint)
                }
                .chartYAxisLabel("Avg. cents off")
                .frame(height: 160)
                Text("Lower is closer. Measured on stable readings only.").font(.caption).foregroundStyle(Palette.inkSoft)
            }
        }
        .stillCard()
    }

    /// Pro teaser: the badge sits by the title so the pitch gets the full width and wraps instead of truncating.
    private var lockedInsights: some View {
        Button { store.presentPaywall("journey") } label: {
            HStack(spacing: 14) {
                Glyph("chart.xyaxis.line", size: Glyph.lead, tint: Palette.mint)
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text("Accuracy over time").font(.headline).foregroundStyle(Palette.ink)
                            .fixedSize(horizontal: false, vertical: true)
                        ProBadge()
                    }
                    Text("See how close you land, session after session, with Timbre Pro.")
                        .font(.subheadline).foregroundStyle(Palette.inkSoft)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 4)
                Image(systemName: "chevron.forward").font(.footnote.weight(.bold)).foregroundStyle(Palette.inkFaint)
                    .accessibilityHidden(true)
            }
            .contentShape(Rectangle())
            .stillCard()
        }
        .buttonStyle(PressScaleStyle())
        .accessibilityIdentifier("journey.accuracy.locked")
    }

    private var recent: some View {
        recentList(limit: 12).stillCard()
    }

    /// The latest `limit` sessions under their heading. A `Spacer` at the foot lets the iPad's card reach down to the
    /// columns beside it; on a phone it takes no room.
    private func recentList(limit: Int) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            JourneyCardHeading("Recent") {
                if !store.records.isEmpty { Text("\(store.records.count) sessions").font(.caption).foregroundStyle(Palette.inkSoft) }
            }
            if store.records.isEmpty {
                Text("Your sessions appear here after your first tune-up.").font(.subheadline).foregroundStyle(Palette.inkSoft)
            }
            ForEach(store.records.prefix(limit)) { record in
                HStack(spacing: 12) {
                    Glyph(symbol(record))
                    VStack(alignment: .leading, spacing: 2) {
                        Text(title(record)).font(.subheadline.weight(.semibold)).foregroundStyle(Palette.ink)
                        Text(record.date, format: .dateTime.month(.abbreviated).day().hour().minute()).font(.caption).foregroundStyle(Palette.inkSoft)
                    }
                    Spacer()
                    if let cents = record.meanAbsoluteCents, record.kind == "tuning" {
                        // "±0.6¢", as the cents-off tile above writes it (and in the locale's decimals).
                        WeekRecap.centsText(cents).font(Typeface.number(.footnote)).foregroundStyle(Palette.inkSoft)
                    } else if record.kind == "lesson" {
                        Text(verbatim: String(repeating: "★", count: max(1, min(3, record.stableCount)))).font(.footnote).foregroundStyle(Palette.starGold)
                    } else if record.kind == "ear", record.count > 0 {
                        Text.fraction(record.stableCount, record.count).font(Typeface.number(.footnote)).foregroundStyle(Palette.inkSoft)
                    } else if let accuracy = record.voiceResult?.accuracy {
                        Text("\(accuracy)%").font(Typeface.number(.footnote)).foregroundStyle(Palette.inkSoft)
                    }
                }
                .padding(.vertical, 4)
            }
            Spacer(minLength: 0)
        }
    }

    private func symbol(_ record: PracticeRecord) -> String {
        switch record.kind {
        case "voice": return "music.mic"
        case "lesson": return "graduationcap"
        case "ear": return "ear"
        case "rhythm": return "metronome"
        case "drone": return "waveform.path"
        case "chord", "scale": return "hand.raised.fingers.spread"
        default: return "tuningfork"
        }
    }

    private func title(_ record: PracticeRecord) -> String {
        switch record.kind {
        case "voice": return String(localized: "Voice practice")
        case "lesson": return store.curriculum.course(id: String(record.instrumentId.dropFirst("learn.".count)))?.title.localized ?? String(localized: "Lesson")
        case "ear": return String(localized: "Ear training")
        case "rhythm": return String(localized: "Metronome")
        case "drone": return String(localized: "Drone")
        case "chord": return String(localized: "Chords")
        case "scale": return String(localized: "Scales")
        default: return instrumentName(record) ?? String(localized: "Chromatic tuning")
        }
    }

    /// The instrument a session tuned, named the way the tuner and the picker name it: by its pictured variant
    /// ("Acoustic guitar", "5-string bass"), not the catalogue's umbrella name ("Acoustic / electric guitar").
    /// The current instrument keeps the picture chosen for it, as in the tuner's header.
    private func instrumentName(_ record: PracticeRecord) -> String? {
        guard let instrument = store.catalog.instrument(id: record.instrumentId) else { return nil }
        let preferred = record.instrumentId == store.instrument.id ? store.settings.selectedPhotoAsset : nil
        guard let photo = store.catalog.photo(instrumentId: record.instrumentId, tuningId: record.tuningId, preferredAsset: preferred) else {
            return instrument.name.localized
        }
        return NSLocalizedString("timbre_photo_" + photo.asset, bundle: .main, value: photo.label, comment: "")
    }
}

/// A lesson opened from the coach card.
private struct CoachLesson: Identifiable {
    let course: LearnCourse
    let lesson: Lesson
    var id: String { lesson.id }
}

/// An achievement with its live metric, for the grid.
private struct BadgeProgress: Identifiable {
    let achievement: Achievement
    /// Position in the earned list (later is more recent); nil while locked.
    let earnedAt: Int?
    let value: Int
    /// Position in `Achievements.all`, to keep ties stable.
    let order: Int
    var id: String { achievement.id }
    var earned: Bool { earnedAt != nil }
    var fraction: Double { min(1, Double(max(0, value)) / Double(max(1, achievement.goal))) }

    /// Earned badges: the most recent first.
    static func later(_ lhs: BadgeProgress, _ rhs: BadgeProgress) -> Bool {
        let left = lhs.earnedAt ?? -1, right = rhs.earnedAt ?? -1
        return left != right ? left > right : lhs.order < rhs.order
    }

    /// Locked badges: the closest to its goal first.
    static func closer(_ lhs: BadgeProgress, _ rhs: BadgeProgress) -> Bool {
        lhs.fraction != rhs.fraction ? lhs.fraction > rhs.fraction : lhs.order < rhs.order
    }
}

/// A card's title (`CardTitle`: a heading for VoiceOver's rotor) with a count or a note on its baseline at the
/// trailing edge; at the accessibility sizes the note moves under the title so neither is squeezed.
private struct JourneyCardHeading<Trailing: View>: View {
    private let title: LocalizedStringKey
    private let trailing: Trailing
    @Environment(\.dynamicTypeSize) private var typeSize

    init(_ title: LocalizedStringKey, @ViewBuilder trailing: () -> Trailing) {
        self.title = title
        self.trailing = trailing()
    }

    var body: some View {
        let layout = typeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 4))
            : AnyLayout(HStackLayout(alignment: .firstTextBaseline, spacing: 8))
        layout {
            CardTitle(title)
                .frame(maxWidth: .infinity, alignment: .leading)
            trailing
        }
    }
}

/// A horizontal hairline through the middle of its frame (for dashed guides).
private struct DriftThresholdLine: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.midY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
        return path
    }
}
