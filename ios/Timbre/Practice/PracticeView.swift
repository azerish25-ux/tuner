import SwiftUI
import TimbreCore

enum PracticeRoute: Hashable { case metronome, ear, chords, scales, drone, voice, intonation, sniper }

/// Play: today's practice set, your level, today's quests, ear games and practice tools.
struct PracticeView: View {
    @EnvironmentObject private var store: AppStore
    @EnvironmentObject private var commerce: CommerceService
    @State private var path: [PracticeRoute] = []

    /// German capitalises every noun, so the instrument name keeps its capital there.
    static func inSentence(_ name: String) -> String {
        Locale.current.language.languageCode == .german ? name : name.lowercased()
    }

    var body: some View {
        NavigationStack(path: $path) {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    HStack(alignment: .center) {
                        Text("Play").font(Typeface.display(30)).tracking(-0.6).foregroundStyle(Palette.ink)
                            .accessibilityAddTraits(.isHeader)
                        Spacer()
                        StreakChip { store.selectedTab = .journey }
                    }
                    DailySetCard { open($0) }
                    levelCard
                    questSection
                    gamesSection
                    toolsSection
                }
                .padding(.horizontal, Metrics.gutter).padding(.vertical, 12)
            }
            .stageTopShade()
            .background(StageBackground(motes: false))
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
                Text(LocalizedStringKey(level.name)).font(Typeface.display(17)).foregroundStyle(Palette.ink)
                ProgressLine(value: level.progress(xp))
                Text("\(xp - level.floor) / \(level.next - level.floor) XP · next: \(Text(LocalizedStringKey(next.name)))").font(.caption).foregroundStyle(Palette.inkSoft)
            }
        }
        .stillCard(cornerRadius: 24, padding: 16, tint: Palette.mint)
        .accessibilityElement(children: .combine)
    }

    private var questSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text("Today’s quests").font(Typeface.display(17)).foregroundStyle(Palette.ink).accessibilityAddTraits(.isHeader)
                Spacer()
                Text("resets in \(hoursToMidnight) h").font(.caption).foregroundStyle(Palette.inkSoft)
            }
            ForEach(store.quests) { quest in
                // The one saved counter (AppStore.questCounter): tuning counts today's strings, like the tuner's quest line.
                let count = store.questCounter(quest)
                Button { open(quest) } label: { HubQuestRow(quest: quest, done: count.done, total: count.total, claimed: store.questProgress(quest) >= quest.target) }
                    .buttonStyle(PressScaleStyle())
                    .accessibilityIdentifier("quest.\(quest.id)")
            }
        }
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

    private var gamesSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Ear games").font(Typeface.display(17)).foregroundStyle(Palette.ink).accessibilityAddTraits(.isHeader)
            HStack(spacing: 12) {
                gameCard(.sniper, title: "Pitch Sniper", detail: (store.progress.stats["sniperBest"]).map { "Best \($0.formatted())" } ?? String(localized: "Hit the note dead center"), tint: Palette.mint, symbol: "scope")
                gameCard(.ear, title: "Ear trainer", detail: String(localized: "Pitch, intervals, chords"), tint: Palette.amber, symbol: "ear")
            }
        }
    }

    private func gameCard(_ route: PracticeRoute, title: LocalizedStringKey, detail: String, tint: Color, symbol: String) -> some View {
        Button { path.append(route) } label: {
            ZStack(alignment: .bottomLeading) {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(RadialGradient(colors: [tint.opacity(0.22), Palette.stageRaised], center: UnitPoint(x: 0.75, y: 0.2), startRadius: 0, endRadius: 150))
                Image(systemName: symbol).font(.system(size: 46, weight: .light)).foregroundStyle(tint)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing).padding(16)
                    .symbolEffect(.pulse, options: .repeating.speed(0.4))
                VStack(alignment: .leading, spacing: 3) {
                    Text(title).font(Typeface.display(16)).foregroundStyle(Palette.ink)
                    Text(detail).font(.caption).foregroundStyle(Palette.inkSoft).lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(14)
            }
            .frame(height: 150)
            .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).strokeBorder(.white.opacity(0.06), lineWidth: 1))
            .contentShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("practice.\(route)")
    }

    /// Three equal columns, built eagerly (not lazily) so every tool exists for VoiceOver and UI tests
    /// even while it is scrolled below the Today card.
    private var toolsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Tools").font(Typeface.display(17)).foregroundStyle(Palette.ink).accessibilityAddTraits(.isHeader)
            VStack(spacing: 10) {
                HStack(spacing: 10) {
                    tool(.metronome, "metronome", "Metronome", pro: false)
                    tool(.drone, "waveform.path", "Drone", pro: true)
                    tool(.voice, "music.mic", "Voice", pro: false)
                }
                if fretted {
                    HStack(spacing: 10) {
                        tool(.chords, "hand.raised.fingers.spread", "Chords", pro: true)
                        tool(.scales, "point.3.connected.trianglepath.dotted", "Scales", pro: true)
                        tool(.intonation, "ruler", "Intonation", pro: true)
                    }
                }
            }
        }
    }

    private func tool(_ route: PracticeRoute, _ symbol: String, _ title: LocalizedStringKey, pro: Bool) -> some View {
        Button {
            if pro && !commerce.isPro { store.presentPaywall("practice.\(route)") } else { path.append(route) }
        } label: {
            VStack(spacing: 6) {
                Image(systemName: symbol).font(.system(size: 18, weight: .medium)).foregroundStyle(Palette.ink)
                Text(title).font(.caption.weight(.semibold)).foregroundStyle(Palette.ink).lineLimit(1).minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity, minHeight: 66)
            .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Palette.stageRaised))
            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(.white.opacity(0.06), lineWidth: 1))
            .overlay(alignment: .topTrailing) { if pro && !commerce.isPro { ProBadge().scaleEffect(0.8).padding(4) } }
            .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("practice.\(route)")
    }

    /// Opens a daily-set activity in its tool (the paywall for a Pro tool on a free plan).
    private func open(_ kind: DailyActivity.Kind) {
        if kind.needsPro && !commerce.isPro { store.presentPaywall("daily.\(kind.rawValue)"); return }
        switch kind {
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
            Circle().trim(from: 0, to: max(0.001, progress)).stroke(Palette.brass, style: StrokeStyle(lineWidth: 5, lineCap: .round)).rotationEffect(.degrees(-90))
            Text("\(Int((progress * 100).rounded()))%").font(Typeface.number(11)).foregroundStyle(Palette.inkSoft)
        }
        .animation(Motion.settle, value: progress)
        .accessibilityElement().accessibilityLabel(Text("\(Int((progress * 100).rounded())) percent done"))
    }
}

/// A daily quest on the Play hub: icon, title, a bar with its one counter ("4 / 6") and the XP it pays.
/// Drawn like the shared QuestRow, but with the counter handed in, so the tuning quest counts strings
/// the way the tuner does instead of "0 / 1".
private struct HubQuestRow: View {
    let quest: Quest
    let done: Int
    let total: Int
    let claimed: Bool

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: claimed ? "checkmark" : quest.symbol).font(.system(size: 15, weight: .semibold))
                .foregroundStyle(claimed ? Palette.onAccent : quest.tint)
                .frame(width: 34, height: 34)
                .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(claimed ? AnyShapeStyle(Palette.mint) : AnyShapeStyle(quest.tint.opacity(0.14))))
            VStack(alignment: .leading, spacing: 7) {
                Text(quest.title).font(.subheadline.weight(.semibold)).foregroundStyle(claimed ? Palette.inkSoft : Palette.ink)
                    .strikethrough(claimed, color: Palette.inkFaint)
                    .fixedSize(horizontal: false, vertical: true)
                HStack(spacing: 10) {
                    ProgressLine(value: Double(done) / Double(max(1, total)), color: claimed ? Palette.mint : quest.tint, height: 5)
                    Text("\(done) / \(total)").font(Typeface.number(12)).foregroundStyle(claimed ? Palette.mint : Palette.inkSoft)
                        .contentTransition(.numericText())
                        .fixedSize()
                }
            }
            reward
        }
        .padding(.horizontal, 14).padding(.vertical, 12)
        .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Palette.stageRaised))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(.white.opacity(0.06), lineWidth: 1))
        .animation(Motion.settle, value: done)
        .accessibilityElement(children: .combine)
        .accessibilityValue(Text(claimed ? "Done" : "\(done) of \(total)"))
    }

    /// "+20 XP" in a mint pill while open; "Done" once claimed.
    @ViewBuilder private var reward: some View {
        if claimed {
            Text("Done").font(Typeface.label(12)).foregroundStyle(Palette.mint)
        } else {
            Text("+\(quest.xp) XP").font(Typeface.label(12)).foregroundStyle(Palette.mint)
                .padding(.horizontal, 9).padding(.vertical, 5)
                .background(Capsule().fill(Palette.mint.opacity(0.12)))
                .overlay(Capsule().strokeBorder(Palette.mint.opacity(0.25), lineWidth: 1))
                .fixedSize()
        }
    }
}
