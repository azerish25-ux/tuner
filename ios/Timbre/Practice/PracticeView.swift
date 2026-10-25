import SwiftUI
import TimbreCore

enum PracticeRoute: Hashable { case metronome, ear, chords, scales, drone, voice, intonation, sniper }

/// Play: Today (the day's one session), your level, the quests Today doesn't already cover, ear games and tools.
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
        TabHeader(title: "Play", showsToday: false)
    }

    private var sideQuests: [Quest] { DailySet.sideQuests(store.quests, beside: store.dailySet) }

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

    /// iPad: a dashboard. Landscape (three columns): Today, your level and the day's quests share the top row at one
    /// height; under them the ear games stand as tall tiles side by side, the tools beside them as a grid of the same
    /// height. Portrait (two columns): Today beside the level, the quests two by two, the games side by side, then the
    /// tools as a grid of large tiles. The games' previews grow with the window's height (`gameStage`), so the hub
    /// reaches the fold instead of stopping halfway down it.
    private func wideHub(_ columns: CardColumns, height: CGFloat) -> some View {
        let three = columns.count >= 3
        let quests = sideQuests
        let stage = gameStage(three: three, quests: quests.count, height: height)
        return VStack(alignment: .leading, spacing: 26) {
            header
            if three {
                HStack(alignment: .top, spacing: CardColumns.spacing) {
                    DailySetCard { open($0) }
                        .frame(width: columns.unit)
                    levelTile
                        .frame(width: quests.isEmpty ? columns.span(2) : columns.unit)
                    if !quests.isEmpty {
                        questSection(quests)
                            .frame(width: columns.unit)
                            .frame(maxHeight: .infinity, alignment: .top)
                    }
                }
                .fixedSize(horizontal: false, vertical: true)
                HStack(alignment: .top, spacing: CardColumns.spacing) {
                    gamesRow(width: columns.span(2), stage: stage)
                    toolsPanel(columns: fretted ? 2 : 1, tileHeight: 92)
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
                if !quests.isEmpty { questGrid(quests) }
                gamesRow(width: columns.span(2), stage: stage)
                toolsPanel(columns: 3, tileHeight: 116)
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

    /// iPad: the level as a tile as tall as Today beside it: the ring large, the level's name, how far to the next
    /// one, and the bar along its foot.
    private var levelTile: some View {
        let xp = store.progress.xp
        let level = store.level
        let next = Progression.level(for: level.next)
        return VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center, spacing: 16) {
                LevelRing(size: 92)
                VStack(alignment: .leading, spacing: 6) {
                    Text(LocalizedStringKey(level.name)).font(Typeface.display(22)).foregroundStyle(Palette.ink)
                        .lineLimit(2).minimumScaleFactor(0.8)
                    Text("\(xp - level.floor) / \(level.next - level.floor) XP · next: \(Text(LocalizedStringKey(next.name)))")
                        .font(.subheadline).foregroundStyle(Palette.inkSoft)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Spacer(minLength: 0)
            ProgressLine(value: level.progress(xp), height: 8)
        }
        .frame(maxHeight: .infinity, alignment: .topLeading)
        .stillCard(tint: Palette.mint)
        .accessibilityElement(children: .combine)
    }

    /// iPad, two columns: the day's quests two by two (a last one alone takes the width).
    private func questGrid(_ quests: [Quest]) -> some View {
        let pairs = stride(from: 0, to: quests.count, by: 2).map { Array(quests[$0..<min($0 + 2, quests.count)]) }
        return VStack(alignment: .leading, spacing: 10) {
            questHeader
            ForEach(pairs.indices, id: \.self) { index in
                HStack(alignment: .top, spacing: CardColumns.spacing) {
                    ForEach(pairs[index]) { quest in questButton(quest) }
                }
            }
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
    /// more (beside the games in landscape, the rows share the games' height). Built eagerly, like the phone's rows.
    /// At the accessibility sizes, the phone's single column of rows.
    private func toolsPanel(columns: Int, tileHeight: CGFloat) -> some View {
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
                            ForEach(rows[index]) { tool in toolTile(tool, minHeight: tileHeight) }
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
    /// the line (wrapping freely), PRO on a free plan and a chevron.
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
                if locked { ProBadge() }
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

    /// One of the Play hub's tools, as the iPad grid shows it.
    private struct Tool: Identifiable {
        let route: PracticeRoute
        let symbol: String
        let title: LocalizedStringKey
        let pro: Bool
        var id: PracticeRoute { route }
    }

    /// The same tools as the phone's rows, in the same order (the fretted ones only on a fretted instrument).
    private var tools: [Tool] {
        var list = [Tool(route: .metronome, symbol: "metronome", title: "Metronome", pro: false),
                    Tool(route: .drone, symbol: "waveform.path", title: "Drone", pro: true),
                    Tool(route: .voice, symbol: "music.mic", title: "Voice", pro: false)]
        if fretted {
            list += [Tool(route: .chords, symbol: "hand.raised.fingers.spread", title: "Chords", pro: true),
                     Tool(route: .scales, symbol: "point.3.connected.trianglepath.dotted", title: "Scales", pro: true),
                     Tool(route: .intonation, symbol: "ruler", title: "Intonation", pro: true)]
        }
        return list
    }

    /// A large tool tile: the live glyph in its well at the top, the name at the foot, PRO in the corner on a free plan.
    private func toolTile(_ tool: Tool, minHeight: CGFloat) -> some View {
        let locked = tool.pro && !commerce.isPro
        let shape = RoundedRectangle(cornerRadius: Metrics.cornerTile, style: .continuous)
        return Button { openTool(tool.route, pro: tool.pro) } label: {
            VStack(alignment: .leading, spacing: 10) {
                PlayToolGlyph(route: tool.route, symbol: tool.symbol)
                    .frame(width: 44, height: 44)
                    .background(RoundedRectangle(cornerRadius: Metrics.cornerChip, style: .continuous).fill(.white.opacity(0.06)))
                Spacer(minLength: 0)
                Text(tool.title).font(.subheadline.weight(.semibold)).foregroundStyle(Palette.ink)
                    .lineLimit(1).minimumScaleFactor(0.8)
            }
            .padding(14)
            .frame(maxWidth: .infinity, minHeight: minHeight, maxHeight: .infinity, alignment: .topLeading)
            .background(shape.fill(Palette.stageRaised))
            .overlay(shape.strokeBorder(Palette.hairline, lineWidth: 1))
            .overlay(alignment: .topTrailing) { if locked { ProBadge().padding(10) } }
            .contentShape(shape)
        }
        .buttonStyle(PressScaleStyle())
        .accessibilityIdentifier("practice.\(tool.route)")
    }

    @ViewBuilder private var firstTools: some View {
        tool(.metronome, "metronome", "Metronome", pro: false)
        tool(.drone, "waveform.path", "Drone", pro: true)
        tool(.voice, "music.mic", "Voice", pro: false)
    }

    @ViewBuilder private var frettedTools: some View {
        tool(.chords, "hand.raised.fingers.spread", "Chords", pro: true)
        tool(.scales, "point.3.connected.trianglepath.dotted", "Scales", pro: true)
        tool(.intonation, "ruler", "Intonation", pro: true)
    }

    private func tool(_ route: PracticeRoute, _ symbol: String, _ title: LocalizedStringKey, pro: Bool) -> some View {
        let shape = RoundedRectangle(cornerRadius: Metrics.cornerTile, style: .continuous)
        return Button { openTool(route, pro: pro) } label: {
            VStack(spacing: 6) {
                // The metronome ticks and the drone ripples, live; the other tools keep their symbol.
                PlayToolGlyph(route: route, symbol: symbol)
                Text(title).font(.caption.weight(.semibold)).foregroundStyle(Palette.ink).lineLimit(1).minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity, minHeight: 74)
            .background(shape.fill(Palette.stageRaised))
            .overlay(shape.strokeBorder(Palette.hairline, lineWidth: 1))
            .overlay(alignment: .topTrailing) { if pro && !commerce.isPro { ProBadge().padding(5) } }
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
