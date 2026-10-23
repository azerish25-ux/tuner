import SwiftUI
import TimbreCore

enum PracticeRoute: Hashable { case metronome, ear, chords, scales, drone, voice }

struct PracticeView: View {
    @EnvironmentObject private var store: AppStore
    @EnvironmentObject private var commerce: CommerceService
    @State private var path: [PracticeRoute] = []

    var body: some View {
        NavigationStack(path: $path) {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    ScreenTitle(title: "Practice", subtitle: "Ten minutes a day, built around \(store.instrumentDisplayName.lowercased()).")
                    streakCard
                    dailyCard
                    Eyebrow("Tools")
                    LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                        tool(.metronome, "metronome.fill", "Metronome", "Accents, odd meters, tap", Palette.brass, pro: false)
                        tool(.ear, "ear.fill", "Ear training", "Pitch, intervals, chords", Palette.flat, pro: false)
                        if fretted {
                            tool(.chords, "hand.raised.fingers.spread.fill", "Chords", "Every shape, any tuning", Palette.ember, pro: true)
                            tool(.scales, "point.3.connected.trianglepath.dotted", "Scales", "Fretboard maps", Palette.sharp, pro: true)
                        }
                        tool(.drone, "waveform.path", "Drone", "Tanpura and pure tones", Palette.locked, pro: true)
                        tool(.voice, "music.mic", "Voice", "Range test and exercises", Palette.success, pro: false)
                    }
                }
                .padding(.horizontal, Metrics.gutter).padding(.vertical, 12)
            }
            .background(StageBackground(motes: false))
            .onAppear(perform: consumePendingRoute)
            .onChange(of: store.pendingPracticeRoute) { _, _ in consumePendingRoute() }
            .navigationDestination(for: PracticeRoute.self) { route in
                switch route {
                case .metronome: MetronomeView()
                case .ear: EarTrainingView()
                case .chords: ChordsView(mode: .chords)
                case .scales: ChordsView(mode: .scales)
                case .drone: DroneView()
                case .voice: VoiceView()
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

    private var streakCard: some View {
        let streak = store.streak
        return HStack(spacing: 16) {
            ZStack {
                Circle().fill(Palette.ember.opacity(0.16)).frame(width: 62, height: 62)
                Image(systemName: "flame.fill").font(.system(size: 28)).foregroundStyle(streak.practicedToday ? Palette.ember : Palette.inkFaint)
                    .symbolEffect(.bounce, value: streak.current)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text("\(streak.current)-day streak").font(Typeface.display(28)).foregroundStyle(Palette.ink)
                Text(streak.practicedToday ? "Practised today. Best run \(streak.best) days." : "Practise today to keep it alive.").font(.subheadline).foregroundStyle(Palette.inkSoft)
            }
            Spacer()
        }
        .stillCard()
        .accessibilityElement(children: .combine)
    }

    private var dailyCard: some View {
        let set = store.dailySet
        let done = set.filter { store.dailyDone($0.kind) }.count
        return VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Eyebrow("Today's set")
                    Text("\(set.reduce(0) { $0 + $1.minutes }) minutes").font(Typeface.display(26)).foregroundStyle(Palette.ink)
                }
                Spacer()
                ProgressRing(progress: set.isEmpty ? 0 : Double(done) / Double(set.count)).frame(width: 46, height: 46)
            }
            ForEach(set) { activity in
                Button { open(activity.kind) } label: {
                    HStack(spacing: 12) {
                        Image(systemName: store.dailyDone(activity.kind) ? "checkmark.circle.fill" : "circle").font(.title3)
                            .foregroundStyle(store.dailyDone(activity.kind) ? Palette.success : Palette.inkFaint)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(title(activity.kind)).font(.headline).foregroundStyle(Palette.ink)
                            Text("\(activity.minutes) min · \(detail(activity.kind))").font(.caption).foregroundStyle(Palette.inkSoft)
                        }
                        Spacer()
                        if needsPro(activity.kind) && !commerce.isPro { ProBadge() } else { Image(systemName: "chevron.right").font(.caption.weight(.bold)).foregroundStyle(Palette.inkFaint) }
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("daily.\(activity.kind.rawValue)")
            }
        }
        .stillCard()
    }

    private func tool(_ route: PracticeRoute, _ symbol: String, _ title: LocalizedStringKey, _ detail: LocalizedStringKey, _ tint: Color, pro: Bool) -> some View {
        Button {
            if pro && !commerce.isPro { store.presentPaywall("practice.\(route)") } else { path.append(route) }
        } label: {
            VStack(alignment: .leading, spacing: 12) {
                HStack { IconOrb(symbol: symbol, tint: tint); Spacer(); if pro && !commerce.isPro { ProBadge() } }
                VStack(alignment: .leading, spacing: 3) {
                    Text(title).font(.headline).foregroundStyle(Palette.ink)
                    Text(detail).font(.caption).foregroundStyle(Palette.inkSoft).lineLimit(2)
                }
            }
            .frame(maxWidth: .infinity, minHeight: 118, alignment: .topLeading)
            .stillCard(cornerRadius: 22, padding: 14)
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
