import Charts
import SwiftUI
import TimbreCore

/// Progress as a trophy room: streak, a twelve-week heat map, accuracy over time, milestones.
struct JourneyView: View {
    @EnvironmentObject private var store: AppStore
    @EnvironmentObject private var commerce: CommerceService

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    ScreenTitle(title: "Journey", subtitle: "Every tune-up and practice session, measured on your device.")
                    hero
                    heatmap
                    if commerce.isPro { accuracy } else { lockedInsights }
                    milestones
                    recent
                }
                .padding(.horizontal, Metrics.gutter).padding(.vertical, 12)
            }
            .background(StageBackground(motes: false))
        }
    }

    private var hero: some View {
        let streak = store.streak
        return HStack(spacing: 0) {
            stat("\(streak.current)", "day streak", "flame.fill", Palette.ember)
            Divider().frame(height: 50).overlay(Palette.line)
            stat("\(streak.best)", "best run", "trophy.fill", Palette.brass)
            Divider().frame(height: 50).overlay(Palette.line)
            stat("\(streak.totalMinutes)", "minutes", "clock.fill", Palette.flat)
        }
        .stillCard(padding: 14)
    }

    private func stat(_ value: String, _ label: LocalizedStringKey, _ symbol: String, _ tint: Color) -> some View {
        VStack(spacing: 4) {
            Image(systemName: symbol).foregroundStyle(tint)
            Text(value).font(Typeface.display(34)).foregroundStyle(Palette.ink)
            Text(label).font(.caption).foregroundStyle(Palette.inkSoft)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
    }

    private var heatmap: some View {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let weeks = 12
        let days = store.streak.activeDays
        let minutesByDay = Dictionary(grouping: store.records, by: { calendar.startOfDay(for: $0.date) }).mapValues { $0.compactMap(\.durationMs).reduce(0, +) / 60000 }
        let start = calendar.date(byAdding: .day, value: -(weeks * 7 - 1), to: today)!
        return VStack(alignment: .leading, spacing: 10) {
            Eyebrow("Last twelve weeks")
            HStack(alignment: .top, spacing: 4) {
                ForEach(0..<weeks, id: \.self) { week in
                    VStack(spacing: 4) {
                        ForEach(0..<7, id: \.self) { day in
                            let date = calendar.date(byAdding: .day, value: week * 7 + day, to: start)!
                            let minutes = minutesByDay[date] ?? 0
                            let active = days.contains(date)
                            RoundedRectangle(cornerRadius: 4, style: .continuous)
                                .fill(active ? Palette.brass.opacity(min(1, 0.35 + Double(minutes) / 20)) : Palette.stageRaised)
                                .overlay(RoundedRectangle(cornerRadius: 4).strokeBorder(date == today ? Palette.ink.opacity(0.6) : .clear, lineWidth: 1))
                                .aspectRatio(1, contentMode: .fit)
                        }
                    }
                }
            }
        }
        .stillCard()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("Practised on \(days.count) days in the last twelve weeks"))
    }

    private var tuningSessions: [PracticeRecord] {
        store.records.filter { $0.kind == "tuning" && $0.meanAbsoluteCents != nil }.sorted { $0.date < $1.date }.suffix(40).map { $0 }
    }

    private var accuracy: some View {
        VStack(alignment: .leading, spacing: 10) {
            Eyebrow("Tuning accuracy")
            if tuningSessions.count < 2 {
                Text("Tune a few times to see how close you land.").font(.subheadline).foregroundStyle(Palette.inkSoft)
            } else {
                Chart(tuningSessions) { record in
                    LineMark(x: .value("Date", record.date), y: .value("Cents", record.meanAbsoluteCents ?? 0))
                        .interpolationMethod(.catmullRom).foregroundStyle(Palette.brass)
                    PointMark(x: .value("Date", record.date), y: .value("Cents", record.meanAbsoluteCents ?? 0)).foregroundStyle(Palette.brass)
                }
                .chartYAxisLabel("Average ¢ off")
                .frame(height: 160)
                Text("Lower is closer. Measured on stable readings only.").font(.caption).foregroundStyle(Palette.inkFaint)
            }
        }
        .stillCard()
    }

    private var lockedInsights: some View {
        Button { store.presentPaywall("journey") } label: {
            FeatureRow(symbol: "chart.xyaxis.line", title: "Accuracy over time", detail: "See how close you land, session after session, with Timbre Pro.") { ProBadge() }
                .stillCard()
        }
        .buttonStyle(.plain)
    }

    private struct Milestone: Identifiable { let id: String; let symbol: String; let title: LocalizedStringKey; let earned: Bool }
    private var milestoneList: [Milestone] {
        let tunes = store.settings.fullTunes ?? 0
        let streak = store.streak
        let ear = store.records.filter { $0.kind == "ear" }.count
        return [
            Milestone(id: "first", symbol: "tuningfork", title: "First full tune", earned: tunes >= 1),
            Milestone(id: "ten", symbol: "10.circle.fill", title: "Ten full tunes", earned: tunes >= 10),
            Milestone(id: "week", symbol: "flame.fill", title: "Seven-day streak", earned: streak.best >= 7),
            Milestone(id: "month", symbol: "calendar", title: "Thirty-day streak", earned: streak.best >= 30),
            Milestone(id: "ear", symbol: "ear.fill", title: "Ten ear sessions", earned: ear >= 10),
            Milestone(id: "voice", symbol: "music.mic", title: "Range measured", earned: store.records.contains { $0.tuningId?.hasPrefix("voice.range") == true || $0.tuningId == VoiceExercise(level: 7).id }),
        ]
    }

    private var milestones: some View {
        VStack(alignment: .leading, spacing: 12) {
            Eyebrow("Milestones")
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 96), spacing: 10)], spacing: 10) {
                ForEach(milestoneList) { m in
                    VStack(spacing: 8) {
                        Image(systemName: m.symbol).font(.title2).foregroundStyle(m.earned ? Palette.brass : Palette.inkFaint)
                            .frame(width: 52, height: 52)
                            .background(Circle().fill(m.earned ? Palette.brass.opacity(0.16) : Palette.stageRaised))
                        Text(m.title).font(.caption.weight(.semibold)).foregroundStyle(m.earned ? Palette.ink : Palette.inkFaint).multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .opacity(m.earned ? 1 : 0.7)
                    .accessibilityElement(children: .combine)
                    .accessibilityValue(m.earned ? Text("Earned") : Text("Not yet"))
                }
            }
        }
        .stillCard()
    }

    private var recent: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Eyebrow("Recent")
                Spacer()
                if !store.records.isEmpty { Text("\(store.records.count) sessions").font(.caption).foregroundStyle(Palette.inkFaint) }
            }
            if store.records.isEmpty {
                Text("Your sessions appear here after your first tune-up.").font(.subheadline).foregroundStyle(Palette.inkSoft)
            }
            ForEach(store.records.prefix(12)) { record in
                HStack(spacing: 12) {
                    Image(systemName: symbol(record)).foregroundStyle(Palette.brass).frame(width: 26)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(title(record)).font(.subheadline.weight(.semibold)).foregroundStyle(Palette.ink)
                        Text(record.date, format: .dateTime.month(.abbreviated).day().hour().minute()).font(.caption).foregroundStyle(Palette.inkFaint)
                    }
                    Spacer()
                    if let cents = record.meanAbsoluteCents, record.kind == "tuning" {
                        Text(String(format: "%.1f¢", cents)).font(Typeface.number(13)).foregroundStyle(Palette.inkSoft)
                    } else if record.kind == "ear", record.count > 0 {
                        Text("\(record.stableCount)/\(record.count)").font(Typeface.number(13)).foregroundStyle(Palette.inkSoft)
                    } else if let accuracy = record.voiceResult?.accuracy {
                        Text("\(accuracy)%").font(Typeface.number(13)).foregroundStyle(Palette.inkSoft)
                    }
                }
                .padding(.vertical, 4)
            }
        }
        .stillCard()
    }

    private func symbol(_ record: PracticeRecord) -> String {
        switch record.kind {
        case "voice": return "music.mic"
        case "ear": return "ear.fill"
        case "rhythm": return "metronome.fill"
        case "drone": return "waveform.path"
        case "chord", "scale": return "hand.raised.fingers.spread.fill"
        default: return "tuningfork"
        }
    }

    private func title(_ record: PracticeRecord) -> String {
        switch record.kind {
        case "voice": return String(localized: "Voice practice")
        case "ear": return String(localized: "Ear training")
        case "rhythm": return String(localized: "Metronome")
        case "drone": return String(localized: "Drone")
        case "chord": return String(localized: "Chords")
        case "scale": return String(localized: "Scales")
        default: return store.catalog.instrument(id: record.instrumentId)?.name.localized ?? String(localized: "Chromatic tuning")
        }
    }
}
