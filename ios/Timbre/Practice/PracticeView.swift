import SwiftUI
import TimbreCore

enum PracticeRoute: Hashable { case metronome, ear, chords, scales, drone, voice, intonation, sniper }

/// Play: your level, today's quests, ear games and practice tools.
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
                    levelCard
                    questSection
                    gamesSection
                    toolsSection
                }
                .padding(.horizontal, Metrics.gutter).padding(.vertical, 12)
            }
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
            ZStack {
                LevelRing(size: 62)
                Text("LEVEL").font(.system(size: 8, weight: .bold)).tracking(1).foregroundStyle(Palette.mint).offset(y: -15)
            }
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
                Button { open(quest) } label: { QuestRow(quest: quest) }
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
                    Text(detail).font(.caption).foregroundStyle(Palette.inkSoft).lineLimit(1)
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

    private var toolsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Tools").font(Typeface.display(17)).foregroundStyle(Palette.ink).accessibilityAddTraits(.isHeader)
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                tool(.metronome, "metronome", "Metronome", pro: false)
                tool(.drone, "waveform.path", "Drone", pro: true)
                tool(.voice, "music.mic", "Voice", pro: false)
                if fretted {
                    tool(.chords, "hand.raised.fingers.spread", "Chords", pro: true)
                    tool(.scales, "point.3.connected.trianglepath.dotted", "Scales", pro: true)
                    tool(.intonation, "ruler", "Intonation", pro: true)
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

    private func needsPro(_ kind: DailyActivity.Kind) -> Bool { [.chord, .scale, .drone].contains(kind) }

    private func open(_ kind: DailyActivity.Kind) {
        if needsPro(kind) && !commerce.isPro { store.presentPaywall("daily.\(kind.rawValue)"); return }
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

    private func title(_ kind: DailyActivity.Kind) -> LocalizedStringKey {
        switch kind {
        case .tune: return "Tune up"
        case .ear: return "Ear training"
        case .chord: return "Chord of the day"
        case .scale: return "Scale workout"
        case .rhythm: return "Rhythm"
        case .voice: return "Voice warm-up"
        case .drone: return "Intonation over a drone"
        }
    }

    private func detail(_ kind: DailyActivity.Kind) -> String {
        switch kind {
        case .tune: return String(localized: "every string to a still point")
        case .ear: return String(localized: "ten questions")
        case .chord: return String(localized: "learn one new shape")
        case .scale: return String(localized: "one position, slowly")
        case .rhythm: return String(localized: "steady at a comfortable tempo")
        case .voice: return String(localized: "a comfortable range")
        case .drone: return String(localized: "hold notes against a tonic")
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
