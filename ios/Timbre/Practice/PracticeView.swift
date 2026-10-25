import SwiftUI
import TimbreCore

enum PracticeRoute: Hashable { case metronome, ear, chords, scales, drone, voice, intonation, sniper }

/// Practice: Today (the day's one session), your level, the quests Today doesn't already cover, ear games and tools.
struct PracticeView: View {
    @EnvironmentObject private var store: AppStore
    @EnvironmentObject private var commerce: CommerceService
    @Environment(\.horizontalSizeClass) private var sizeClass
    @Environment(\.dynamicTypeSize) private var typeSize
    @State private var path: [PracticeRoute] = []
    /// Today's review, open over the hub.
    @State private var review: ReviewSession?

    /// German capitalises every noun, so the instrument name keeps its capital there.
    static func inSentence(_ name: String) -> String {
        Locale.current.language.languageCode == .german ? name : name.lowercased()
    }

    var body: some View {
        NavigationStack(path: $path) {
            hub
                .onAppear(perform: consumePendingRoute)
                .onChange(of: store.pendingPracticeRoute) { _, _ in consumePendingRoute() }
                .navigationDestination(for: PracticeRoute.self) { route in
                    Group {
                        switch route {
                        case .metronome: MetronomeView()
                        case .ear: EarTrainingView()
                        case .chords: ChordsView(mode: .chords)
                        case .scales: ChordsView(mode: .scales)
                        case .drone: DroneView()
                        case .voice: VoiceView()
                        case .intonation: IntonationView()
                        case .sniper: PitchSniperView()
                        }
                    }
                    .toolbar(.hidden, for: .tabBar)
                }
        }
        .reviewSessionCover($review)
    }

    /// A phone (or any compact width) gets one column; an iPad's regular width a grid of cards (`CardColumns`).
    @ViewBuilder private var hub: some View {
        if sizeClass == .regular {
            GeometryReader { proxy in
                let columns = CardColumns(width: proxy.size.width - 2 * Metrics.gutter)
                scroller {
                    if columns.count > 1 { wideHub(columns, height: proxy.size.height) } else { compactHub }
                }
            }
        } else {
            scroller { compactHub }
        }
    }

    /// The last card ends a little clear of the floating tab bar rather than touching its edge (RootView fades what
    /// scrolls under the bar).
    private func scroller<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        ScrollView {
            content()
                .padding(.horizontal, Metrics.gutter).padding(.top, 12).padding(.bottom, 28)
        }
        .stageTopShade()
        .background(StageBackground(motes: false))
    }

    /// The tab's title with the shared streak chip and level ring. Today's ring is the card right below, so the chip
    /// shows just the streak.
    private var header: some View {
        TabHeader(title: "Practice", showsToday: false)
    }

    private var sideQuests: [Quest] { GameChallenge.listed(DailySet.sideQuests(store.quests, beside: store.dailySet)) }

    private var compactHub: some View {
        VStack(alignment: .leading, spacing: 22) {
            header
            DailySetCard { open($0) }
            levelCard
            let sideQuests = self.sideQuests
            if !sideQuests.isEmpty { questSection(sideQuests) }
            gamesSection
            toolsSection
        }
    }

    /// iPad: a dashboard. Landscape (three columns): Today, your level (with your week along its foot) and the day's
    /// quests share the top row at one height, the badge closest to its goal filling the quests' column when one quest
    /// or none is left; under them the ear games stand as tall tiles side by side, the tools beside them as a grid of
    /// the same height. Portrait (two columns): Today beside the level, the quests two by two (the next badge beside a
    /// last one alone), the games side by side, then the tools as a grid of large tiles. The games' previews grow with
    /// the window's height (`gameStage`), so the hub reaches the fold instead of stopping halfway down it.
    private func wideHub(_ columns: CardColumns, height: CGFloat) -> some View {
        let three = columns.count >= 3
        let quests = sideQuests
        let badge = nextBadge
        let stage = gameStage(three: three, quests: quests.count, height: height)
        return VStack(alignment: .leading, spacing: 26) {
            header
            if three {
                let side = !quests.isEmpty || badge != nil
                HStack(alignment: .top, spacing: CardColumns.spacing) {
                    DailySetCard { open($0) }
                        .frame(width: columns.unit)
                    levelTile
                        .frame(width: side ? columns.unit : columns.span(2))
                    if side {
                        sideColumn(quests, badge: badge)
                            .frame(width: columns.unit)
                            .frame(maxHeight: .infinity, alignment: .top)
                    }
                }
                .fixedSize(horizontal: false, vertical: true)
                HStack(alignment: .top, spacing: CardColumns.spacing) {
                    gamesRow(width: columns.span(2), stage: stage)
                    toolsPanel(columns: fretted ? 2 : 1, tileHeight: 92, sideBySide: !fretted)
                        .frame(width: columns.unit)
                }
                .fixedSize(horizontal: false, vertical: true)
            } else {
                HStack(alignment: .top, spacing: CardColumns.spacing) {
                    DailySetCard { open($0) }
                        .frame(width: columns.unit)
                    levelTile
                        .frame(width: columns.unit)
                }
                .fixedSize(horizontal: false, vertical: true)
                if !quests.isEmpty { questGrid(quests, badge: badge) }
                gamesRow(width: columns.span(2), stage: stage)
                toolsPanel(columns: 3, tileHeight: 116, sideBySide: true)
            }
        }
    }

    /// The ear games' preview height on iPad: what the window has left under the rest of the hub (its header, Today's
    /// row, the section titles, the cards' words; in portrait the quests and the tools too), so the hub ends near the
    /// fold. Never under 180 points (the window scrolls a little instead) nor over 300.
    private func gameStage(three: Bool, quests: Int, height: CGFloat) -> CGFloat {
        let questRows = quests == 0 ? 0 : (quests + 1) / 2
        let rest: CGFloat = three ? 520 : 800 + (questRows == 0 ? 0 : 50 + 74 * CGFloat(questRows))
        return min(300, max(180, height - rest))
    }

    /// iPad: the level as a tile as tall as Today beside it: the ring large, the level's name, how far to the next one
    /// over its bar, and your week along its foot (`weekStrip`), so the tile is full rather than half empty.
    private var levelTile: some View {
        let xp = store.progress.xp
        let level = store.level
        let next = Progression.level(for: level.next)
        return VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .center, spacing: 16) {
                LevelRing(size: 84)
                VStack(alignment: .leading, spacing: 6) {
                    Text(LocalizedStringKey(level.name)).font(Typeface.display(22)).foregroundStyle(Palette.ink)
                        .lineLimit(2).minimumScaleFactor(0.8)
                    Text("\(xp - level.floor) / \(level.next - level.floor) XP · next: \(Text(LocalizedStringKey(next.name)))")
                        .font(.subheadline).foregroundStyle(Palette.inkSoft)
                        .fixedSize(horizontal: false, vertical: true)
                    ProgressLine(value: level.progress(xp), height: 6)
                        .padding(.top, 4)
                }
            }
            Spacer(minLength: 0)
            weekStrip
        }
        .frame(maxHeight: .infinity, alignment: .topLeading)
        .stillCard(tint: Palette.mint)
        .accessibilityElement(children: .combine)
    }

    /// The level tile's foot: the last seven days as Progress's "Your week" draws them (a bar a day, today marked)
    /// beside the minutes they add up to.
    private var weekStrip: some View {
        let recap = WeekRecap(records: store.records, streak: store.streak)
        return HStack(alignment: .bottom, spacing: 16) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Your week").font(.caption).foregroundStyle(Palette.inkSoft)
                Text(Duration.seconds(max(0, recap.minutes) * 60), format: .units(allowed: [.minutes], width: .abbreviated))
                    .font(Typeface.number(17)).foregroundStyle(Palette.ink)
                    .lineLimit(1).minimumScaleFactor(0.8)
            }
            .padding(.bottom, 9)
            Spacer(minLength: 8)
            WeekBars(days: recap.days, height: 22, barWidth: 10, labelSize: 11)
                .frame(maxWidth: 210)
                .accessibilityHidden(true)
        }
    }

    /// iPad, two columns: the day's quests two by two; a last one alone shares its row with the next badge (or takes
    /// the width when every badge is earned).
    private func questGrid(_ quests: [Quest], badge: NextBadge?) -> some View {
        let pairs = stride(from: 0, to: quests.count, by: 2).map { Array(quests[$0..<min($0 + 2, quests.count)]) }
        let beside = quests.count % 2 == 1 ? badge : nil
        return VStack(alignment: .leading, spacing: 10) {
            questHeader
            ForEach(pairs.indices, id: \.self) { index in
                HStack(alignment: .top, spacing: CardColumns.spacing) {
                    ForEach(pairs[index]) { quest in questButton(quest) }
                    if index == pairs.count - 1, let beside { nextBadgeRow(beside) }
                }
                .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    /// iPad landscape, the top row's third column: the quests Today and the game cards don't already show and, when
    /// one or none is left, the badge closest to its goal under them, filling the column to Today's height.
    @ViewBuilder private func sideColumn(_ quests: [Quest], badge: NextBadge?) -> some View {
        if quests.isEmpty, let badge {
            nextBadgeCard(badge)
        } else {
            VStack(alignment: .leading, spacing: 10) {
                questHeader
                ForEach(quests) { quest in questButton(quest) }
                if quests.count == 1, let badge {
                    nextBadgeRow(badge)
                        .frame(maxHeight: .infinity)
                }
            }
        }
    }

    // MARK: Next badge (iPad)

    /// The badge closest to its goal among those not earned yet (Progress's badge grid opens on the same ones).
    private struct NextBadge {
        let achievement: Achievement
        let value: Int
        /// Asset name of the instrument cut-out a course badge wears.
        let image: String?
        var shown: Int { min(max(0, value), achievement.goal) }
        var fraction: Double { Double(shown) / Double(max(1, achievement.goal)) }
    }

    /// Nil once every badge is earned. Ties go to the badge listed first, as on Progress.
    private var nextBadge: NextBadge? {
        let state = store.progress
        let earned = Set(state.achievements)
        let streakBest = store.streak.best
        let custom = store.settings.customTunings?.count ?? 0
        let metrics = store.badgeMetrics
        var best: (achievement: Achievement, value: Int, fraction: Double)?
        for achievement in Achievements.all where !earned.contains(achievement.id) {
            let value = achievement.value(state, streakBest: streakBest, customTunings: custom, metrics: metrics)
            let fraction = min(1, Double(max(0, value)) / Double(max(1, achievement.goal)))
            if let current = best, current.fraction >= fraction { continue }
            best = (achievement, value, fraction)
        }
        guard let best else { return nil }
        return NextBadge(achievement: best.achievement, value: best.value, image: badgeImage(best.achievement))
    }

    /// Instrument artwork for a course badge (the course's instrument cut-out), nil for the others.
    private func badgeImage(_ achievement: Achievement) -> String? {
        guard let courseId = Achievements.courseId(of: achievement),
              let instrument = store.curriculum.course(id: courseId)?.instrument else { return nil }
        return store.catalog.photo(instrumentId: instrument)?.asset
    }

    /// The next badge as a card of its own (landscape, the quests' column with none left): the medal with its arc,
    /// its name and what it asks, the count, and the bar along the foot. A tap opens Progress, where the badges live.
    private func nextBadgeCard(_ badge: NextBadge) -> some View {
        let achievement = badge.achievement
        let tint = achievement.category.tint
        return Button(action: openBadges) {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    CardTitle("Next badge")
                    Spacer(minLength: 8)
                    Text.fraction(badge.shown, achievement.goal).font(Typeface.number(13)).foregroundStyle(tint)
                }
                HStack(alignment: .center, spacing: 16) {
                    AchievementMedal(achievement: achievement, earned: false, size: 72, progress: badge.fraction, image: badge.image)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(LocalizedStringKey(achievement.title)).font(Typeface.display(18)).foregroundStyle(Palette.ink)
                            .lineLimit(2).minimumScaleFactor(0.85)
                        Text(LocalizedStringKey(achievement.detail)).font(.subheadline).foregroundStyle(Palette.inkSoft)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                Spacer(minLength: 0)
                ProgressLine(value: badge.fraction, color: tint, height: 6)
            }
            .frame(maxHeight: .infinity, alignment: .topLeading)
            .stillCard(tint: tint)
        }
        .buttonStyle(PressScaleStyle())
        .modifier(NextBadgeAccessibility(badge: badge))
    }

    /// The next badge as a row in a quest's shape (beside or under a quest): the medal, its name over the bar and the
    /// count, and "Next badge" where a quest has its XP.
    private func nextBadgeRow(_ badge: NextBadge) -> some View {
        let achievement = badge.achievement
        let tint = achievement.category.tint
        let tile = RoundedRectangle(cornerRadius: Metrics.cornerTile, style: .continuous)
        return Button(action: openBadges) {
            HStack(spacing: 12) {
                AchievementMedal(achievement: achievement, earned: false, size: 40, progress: badge.fraction, image: badge.image)
                VStack(alignment: .leading, spacing: 7) {
                    Text(LocalizedStringKey(achievement.title)).font(.subheadline.weight(.semibold)).foregroundStyle(Palette.ink)
                        .fixedSize(horizontal: false, vertical: true)
                    HStack(spacing: 10) {
                        ProgressLine(value: badge.fraction, color: tint, height: 5)
                        Text.fraction(badge.shown, achievement.goal).font(Typeface.number(12)).foregroundStyle(Palette.inkSoft)
                            .fixedSize()
                    }
                }
                Text("Next badge").font(Typeface.label(12)).foregroundStyle(achievement.tier.ink)
                    .lineLimit(1)
                    .padding(.horizontal, 9).padding(.vertical, 5)
                    .background(Capsule().fill(achievement.tier.ink.opacity(0.12)))
                    .overlay(Capsule().strokeBorder(achievement.tier.ink.opacity(0.3), lineWidth: 1))
                    .fixedSize()
            }
            .padding(.horizontal, 14).padding(.vertical, 12)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            .background(tile.fill(Palette.stageRaised))
            .overlay(tile.strokeBorder(Palette.hairline, lineWidth: 1))
            .contentShape(tile)
        }
        .buttonStyle(PressScaleStyle())
        .modifier(NextBadgeAccessibility(badge: badge))
    }

    /// The badges live on Progress.
    private func openBadges() {
        Haptics.shared.selection()
        store.selectedTab = .journey
    }

    /// The next badge read as one element: "Next badge, Golden ear", then what it asks and the count.
    private struct NextBadgeAccessibility: ViewModifier {
        let badge: NextBadge

        func body(content: Content) -> some View {
            let achievement = badge.achievement
            return content
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(Text("Next badge") + Text(verbatim: ", ") + Text(LocalizedStringKey(achievement.title)))
                .accessibilityValue(Text(LocalizedStringKey(achievement.detail)) + Text(verbatim: ", ")
                                    + Text("\(badge.shown) of \(achievement.goal)"))
                .accessibilityAddTraits(.isButton)
                .accessibilityIdentifier("practice.nextBadge")
        }
    }

    private func consumePendingRoute() {
        guard let route = store.pendingPracticeRoute else { return }
        store.pendingPracticeRoute = nil
        path = [route]
    }

    private var fretted: Bool { store.instrument.anchorType == "MACHINE_HEAD" || ["guitar", "ukulele", "mandolin"].contains(store.instrument.familyId) }

    private var levelCard: some View {
        let xp = store.progress.xp
        let level = store.level
        let next = Progression.level(for: level.next)
        return HStack(spacing: 14) {
            LevelRing(size: 62)
            VStack(alignment: .leading, spacing: 6) {
                Text(LocalizedStringKey(level.name)).font(Typeface.cardTitle).foregroundStyle(Palette.ink)
                    .fixedSize(horizontal: false, vertical: true)
                ProgressLine(value: level.progress(xp))
                Text("\(xp - level.floor) / \(level.next - level.floor) XP · next: \(Text(LocalizedStringKey(next.name)))").font(.footnote).foregroundStyle(Palette.inkSoft)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .stillCard(tint: Palette.mint)
        .accessibilityElement(children: .combine)
    }

    /// The daily quests Today doesn't cover; the rest ride on Today's rows as XP side goals.
    private func questSection(_ quests: [Quest]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            questHeader
            ForEach(quests) { quest in questButton(quest) }
        }
    }

    private var questHeader: some View {
        SectionHeader("Today’s quests") {
            Text("resets in \(hoursToMidnight) h").font(.caption).foregroundStyle(Palette.inkSoft)
        }
    }

    /// The shared quest row: it reads the one saved counter itself (AppStore.questCounter), so the tuning quest
    /// counts today's strings, like the tuner's quest line.
    private func questButton(_ quest: Quest) -> some View {
        Button { open(quest) } label: { QuestRow(quest: quest) }
            .buttonStyle(PressScaleStyle())
            .accessibilityIdentifier("quest.\(quest.id)")
    }

    private var hoursToMidnight: Int {
        let calendar = Calendar.current
        let end = calendar.startOfDay(for: Date()).addingTimeInterval(86_400)
        return max(1, Int((end.timeIntervalSinceNow / 3600).rounded(.up)))
    }

    private func open(_ quest: Quest) {
        switch quest.kind {
        case .tuneAll, .holdInTune: store.selectedTab = .tune
        case .sniperWin, .bullseyes: path.append(.sniper)
        case .earCorrect: path.append(.ear)
        case .practiceMinutes: path.append(.metronome)
        case .lessons: store.selectedTab = .learn
        }
    }

    /// The ear games as live cards: each idles in a preview of itself beside its best, its level and today's challenge.
    private var gamesSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionTitle("Ear games")
            sniperCard()
            earCard()
        }
    }

    /// iPad: the two ear games side by side as tall tiles, `width` across, each game idling `stage` points tall across
    /// the top of its card; the two cards share one height.
    private func gamesRow(width: CGFloat, stage: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionTitle("Ear games")
            HStack(alignment: .top, spacing: CardColumns.spacing) {
                sniperCard(stage: stage)
                earCard(stage: stage)
            }
            .fixedSize(horizontal: false, vertical: true)
        }
        .frame(width: width)
    }

    private func sectionTitle(_ title: LocalizedStringKey) -> some View {
        SectionHeader(title)
    }

    /// `stage`: the tall iPad card's preview height; nil for the phone's card.
    private func sniperCard(stage: CGFloat? = nil) -> some View {
        let stats = store.progress.stats
        let best = stats["sniperBest"] ?? 0
        let sniperLevel = SniperRank.level(bullseyes: stats["bullseyes"] ?? 0)
        let sniperStats = statsLine(best > 0 ? Text("Best \(best)") : nil, level: sniperLevel)
        return gameCard(.sniper, title: "Bullseye", stats: sniperStats, challenge: .sniper(store), tint: Palette.mint, stage: stage) { live in
            SniperScopePreview(live: live)
        }
    }

    private func earCard(stage: CGFloat? = nil) -> some View {
        let earLevel = (EarDrill.allCases.map { store.settings.earLevels?[$0.rawValue] ?? 0 }.max() ?? 0) + 1
        let correct = store.progress.stats["earCorrect"] ?? 0
        let earStats = statsLine(Text("\(correct) correct"), level: earLevel)
        return gameCard(.ear, title: "Ear training", stats: earStats, challenge: .ear(store), tint: Palette.amber, stage: stage) { live in
            IntervalStairsPreview(live: live)
        }
    }

    /// "Best 1840 · Level 3": the game's score, when it has one, then its level.
    private func statsLine(_ score: Text?, level: Int) -> Text {
        let levelText = Text("Level \(level)")
        guard let score else { return levelText }
        return score + Text(verbatim: " · ") + levelText
    }

    private func gameCard<Preview: View>(_ route: PracticeRoute, title: LocalizedStringKey, stats: Text, challenge: GameChallenge, tint: Color,
                                         stage: CGFloat?, @ViewBuilder preview: @escaping (Bool) -> Preview) -> some View {
        Button { path.append(route) } label: {
            PlayGameCard(title: title, stats: stats, challenge: challenge, tint: tint, heroHeight: stage, preview: preview)
        }
        .buttonStyle(PressScaleStyle())
        .accessibilityIdentifier("practice.\(route)")
    }

    /// Three equal columns, built eagerly (not lazily) so every tool exists for VoiceOver and UI tests
    /// even while it is scrolled below the Today card. At the accessibility sizes, one full-width row per tool,
    /// so no name is cut short.
    private var toolsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionTitle("Tools")
            if typeSize.isAccessibilitySize {
                toolList
            } else {
                VStack(spacing: 10) {
                    HStack(spacing: 10) { firstTools }
                    if fretted {
                        HStack(spacing: 10) { frettedTools }
                    }
                }
            }
        }
    }

    /// iPad: the tools as large tiles, `columns` to a row, at least `tileHeight` tall and taller when the panel is given
    /// more (beside the games in landscape, the rows share the games' height). Each tile runs a live preview of its
    /// tool (`PlayToolPreview`): beside its name on a wide, short tile (`sideBySide`), above it on a squarer one.
    /// Built eagerly, like the phone's rows. At the accessibility sizes, the phone's single column of rows.
    private func toolsPanel(columns: Int, tileHeight: CGFloat, sideBySide: Bool) -> some View {
        let all = tools
        let count = max(1, columns)
        let rows = stride(from: 0, to: all.count, by: count).map { Array(all[$0..<min($0 + count, all.count)]) }
        return VStack(alignment: .leading, spacing: 10) {
            sectionTitle("Tools")
            if typeSize.isAccessibilitySize {
                toolList
            } else {
                VStack(spacing: 10) {
                    ForEach(rows.indices, id: \.self) { index in
                        HStack(spacing: 10) {
                            ForEach(rows[index]) { tool in toolTile(tool, minHeight: tileHeight, sideBySide: sideBySide) }
                            // A short last row keeps the columns' width.
                            ForEach(rows[index].count..<count, id: \.self) { _ in
                                Color.clear.frame(maxWidth: .infinity)
                            }
                        }
                    }
                }
            }
        }
        .frame(maxHeight: .infinity, alignment: .top)
    }

    /// The tools one per row, as `FeatureRow` lays out a row: the live glyph in its well, the name taking the rest of
    /// the line (wrapping freely), a lock on a Pro tool on the free plan, and a chevron.
    private var toolList: some View {
        VStack(spacing: 10) {
            ForEach(tools) { tool in toolRow(tool) }
        }
    }

    private func toolRow(_ tool: Tool) -> some View {
        let locked = tool.pro && !commerce.isPro
        return Button { openTool(tool.route, pro: tool.pro) } label: {
            HStack(spacing: 14) {
                PlayToolGlyph(route: tool.route, symbol: tool.symbol)
                    .frame(width: 44, height: 44)
                    .background(RoundedRectangle(cornerRadius: Metrics.cornerChip, style: .continuous).fill(.white.opacity(0.06)))
                Text(tool.title).font(.headline).foregroundStyle(Palette.ink)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                if locked { ProLock(size: 22) }
                Image(systemName: "chevron.right").font(.footnote.weight(.bold)).foregroundStyle(Palette.inkFaint)
                    .accessibilityHidden(true)
            }
            .stillCard(cornerRadius: Metrics.cornerTile, padding: Metrics.tilePadding)
        }
        .buttonStyle(PressScaleStyle())
        .accessibilityIdentifier("practice.\(tool.route)")
    }

    /// A tool's tap: the tool, or the paywall for a Pro tool on a free plan.
    private func openTool(_ route: PracticeRoute, pro: Bool) {
        if pro && !commerce.isPro { store.presentPaywall("practice.\(route)") } else { path.append(route) }
    }

    /// One of the Practice hub's tools, as the iPad grid shows it.
    private struct Tool: Identifiable {
        let route: PracticeRoute
        let symbol: String
        let title: LocalizedStringKey
        let pro: Bool
        var id: PracticeRoute { route }
    }

    /// The same tools as the phone's rows, in the same order (the fretted ones only on a fretted instrument). Chords is
    /// free (its open-position shapes and Check; barre shapes are Pro inside it, `FreeTier`); the drone, scales and
    /// intonation are Pro.
    private var tools: [Tool] {
        var list = [Tool(route: .metronome, symbol: "metronome", title: "Metronome", pro: false),
                    Tool(route: .drone, symbol: "waveform.path", title: "Drone", pro: true),
                    Tool(route: .voice, symbol: "music.mic", title: "Voice", pro: false)]
        if fretted {
            list += [Tool(route: .chords, symbol: "hand.raised.fingers.spread", title: "Chords", pro: false),
                     Tool(route: .scales, symbol: "point.3.connected.trianglepath.dotted", title: "Scales", pro: true),
                     Tool(route: .intonation, symbol: "ruler", title: "Intonation", pro: true)]
        }
        return list
    }

    /// A large tool tile: the tool working in miniature (the metronome swinging at the last tempo, the drone's dial,
    /// the chord boxes, the scale's box, the harmonic's node, a voice's trace), its name and what the preview shows
    /// under it, a lock beside the words on a free plan so it never sits on the preview. Lit faintly in the tool's colour.
    private func toolTile(_ tool: Tool, minHeight: CGFloat, sideBySide: Bool) -> some View {
        let locked = tool.pro && !commerce.isPro
        let shape = RoundedRectangle(cornerRadius: Metrics.cornerTile, style: .continuous)
        let tint = PlayToolPreview.tint(tool.route)
        let light = sideBySide ? UnitPoint(x: 0.75, y: 0.5) : UnitPoint(x: 0.5, y: 0.4)
        return Button { openTool(tool.route, pro: tool.pro) } label: {
            toolTileFace(tool, locked: locked, sideBySide: sideBySide)
                .padding(14)
                .frame(maxWidth: .infinity, minHeight: minHeight, maxHeight: .infinity, alignment: .topLeading)
                .background {
                    ZStack {
                        shape.fill(Palette.stageRaised)
                        shape.fill(RadialGradient(colors: [tint.opacity(0.13), .clear], center: light, startRadius: 0, endRadius: 160))
                    }
                }
                .overlay(shape.strokeBorder(Palette.hairline, lineWidth: 1))
                .contentShape(shape)
        }
        .buttonStyle(PressScaleStyle())
        .accessibilityIdentifier("practice.\(tool.route)")
    }

    /// The tile's face: the words on the left and the preview on the right of a wide tile; the preview over the words
    /// on a squarer one.
    @ViewBuilder private func toolTileFace(_ tool: Tool, locked: Bool, sideBySide: Bool) -> some View {
        if sideBySide {
            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    if locked { ProLock(size: 22) }
                    Spacer(minLength: 0)
                    toolTileWords(tool)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                PlayToolPreview(route: tool.route)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        } else {
            VStack(alignment: .leading, spacing: 10) {
                PlayToolPreview(route: tool.route)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                HStack(alignment: .bottom, spacing: 8) {
                    toolTileWords(tool)
                    Spacer(minLength: 0)
                    if locked { ProLock(size: 22) }
                }
            }
        }
    }

    /// The tool's name and, under it, what its preview is showing ("96 BPM", "D3 · Tanpura").
    private func toolTileWords(_ tool: Tool) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(tool.title).font(.subheadline.weight(.semibold)).foregroundStyle(Palette.ink)
                .lineLimit(1).minimumScaleFactor(0.8)
            PlayToolCaption(route: tool.route)
        }
    }

    @ViewBuilder private var firstTools: some View {
        tool(.metronome, "metronome", "Metronome", pro: false)
        tool(.drone, "waveform.path", "Drone", pro: true)
        tool(.voice, "music.mic", "Voice", pro: false)
    }

    @ViewBuilder private var frettedTools: some View {
        tool(.chords, "hand.raised.fingers.spread", "Chords", pro: false)
        tool(.scales, "point.3.connected.trianglepath.dotted", "Scales", pro: true)
        tool(.intonation, "ruler", "Intonation", pro: true)
    }

    private func tool(_ route: PracticeRoute, _ symbol: String, _ title: LocalizedStringKey, pro: Bool) -> some View {
        let shape = RoundedRectangle(cornerRadius: Metrics.cornerTile, style: .continuous)
        return Button { openTool(route, pro: pro) } label: {
            VStack(spacing: 6) {
                // Every tool live in miniature: the metronome ticks, the drone ripples, a chord strums, a scale runs,
                // a harmonic rings and a voice traces (PlayHubTools.swift).
                PlayToolGlyph(route: route, symbol: symbol)
                Text(title).font(.caption.weight(.semibold)).foregroundStyle(Palette.ink).lineLimit(1).minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity, minHeight: 74)
            .background(shape.fill(Palette.stageRaised))
            .overlay(shape.strokeBorder(Palette.hairline, lineWidth: 1))
            .overlay(alignment: .topTrailing) { if pro && !commerce.isPro { ProLock(size: 20).padding(5) } }
            .contentShape(shape)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("practice.\(route)")
    }

    /// Opens an activity of Today: the lesson in Learn, a tool here (the paywall for a Pro tool on a free plan).
    private func open(_ kind: DailyActivity.Kind) {
        if kind.needsPro && !commerce.isPro { store.presentPaywall("daily.\(kind.rawValue)"); return }
        switch kind {
        case .lesson: store.openDailyLesson()
        // Today's review plays right here, over the hub (Learn/WeakSpotReview.swift); with none left, Learn.
        case .review:
            if let session = store.dailyReviewSession { Haptics.shared.selection(); review = session } else { store.selectedTab = .learn }
        case .tune: store.selectedTab = .tune
        case .ear: path.append(.ear)
        case .chord: path.append(.chords)
        case .scale: path.append(.scales)
        case .rhythm: path.append(.metronome)
        case .voice: path.append(.voice)
        case .drone: path.append(.drone)
        }
    }
}

struct ProgressRing: View {
    let progress: Double
    var body: some View {
        ZStack {
            Circle().stroke(Palette.line, lineWidth: 5)
            Circle().trim(from: 0, to: max(0.001, progress)).stroke(Palette.mint, style: StrokeStyle(lineWidth: 5, lineCap: .round)).rotationEffect(.degrees(-90))
            Text("\(Int((progress * 100).rounded()))%").font(Typeface.number(11)).foregroundStyle(Palette.inkSoft)
        }
        .animation(Motion.settle, value: progress)
        .accessibilityElement().accessibilityLabel(Text("\(Int((progress * 100).rounded())) percent done"))
    }
}
