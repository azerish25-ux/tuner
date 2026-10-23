import Charts
import SwiftUI
import TimbreCore

/// Progress: streak, level and accuracy, the practice calendar, string health, achievements, history.
struct JourneyView: View {
    @EnvironmentObject private var store: AppStore
    @EnvironmentObject private var commerce: CommerceService
    @State private var confirmRestring = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("Progress").font(Typeface.display(30)).tracking(-0.6).foregroundStyle(Palette.ink).accessibilityAddTraits(.isHeader)
                    stats
                    calendar
                    stringHealth
                    if commerce.isPro { accuracy } else { lockedInsights }
                    achievements
                    recent
                }
                .padding(.horizontal, Metrics.gutter).padding(.vertical, 12)
            }
            .background(StageBackground(motes: false))
        }
    }

    private var stats: some View {
        let streak = store.streak
        let level = store.level
        let recent = tuningSessions.suffix(10).compactMap(\.meanAbsoluteCents)
        let average = recent.isEmpty ? nil : recent.reduce(0, +) / Double(recent.count)
        return HStack(spacing: 10) {
            stat("flame.fill", Palette.flame, Text("\(streak.current)"), Text("day streak"))
            stat("star", Palette.mint, Text("\(level.number)"), Text(LocalizedStringKey(level.name)))
            stat("scope", Palette.amber, Text(average.map { String(format: "%.1f¢", $0) } ?? "—"), Text("avg accuracy"))
        }
    }

    private func stat(_ symbol: String, _ tint: Color, _ value: Text, _ label: Text) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Image(systemName: symbol).font(.system(size: 15, weight: .semibold)).foregroundStyle(tint)
            value.font(Typeface.number(22)).foregroundStyle(Palette.ink).lineLimit(1).minimumScaleFactor(0.7)
            label.font(.caption).foregroundStyle(Palette.inkSoft).lineLimit(1).minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .stillCard(cornerRadius: 18, padding: 12)
        .accessibilityElement(children: .combine)
    }

    /// Last five weeks, one tile per day: brighter for more practice; today is outlined until you play.
    private var calendar: some View {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        let days = store.streak.activeDays
        let minutesByDay = Dictionary(grouping: store.records, by: { cal.startOfDay(for: $0.date) }).mapValues { $0.compactMap(\.durationMs).reduce(0, +) / 60000 }
        let start = cal.date(byAdding: .day, value: -34, to: today)!
        let active = (0..<35).filter { days.contains(cal.date(byAdding: .day, value: $0, to: start)!) }.count
        return VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text("Last five weeks").font(Typeface.display(16)).foregroundStyle(Palette.ink)
                Spacer()
                Text("\(active) of 35 days").font(.caption).foregroundStyle(Palette.inkSoft)
            }
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
                                RoundedRectangle(cornerRadius: 7, style: .continuous).strokeBorder(Palette.amber.opacity(0.7), style: StrokeStyle(lineWidth: 1.5, dash: [3, 3]))
                            }
                        }
                }
            }
        }
        .stillCard()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("Practiced on \(active) of the last 35 days"))
    }

    /// How each string of this instrument drifts between sessions, and when to restring.
    private var stringHealth: some View {
        let drift = store.stringDrift
        let restrung = store.progress.restrung[store.instrument.id]
        let advice = StringHealth.needsRestring(drift, restrung: restrung)
        let anchors = store.courses.compactMap(\.anchorId).reduce(into: [String]()) { if !$0.contains($1) { $0.append($1) } }
        let worst = drift.first
        let labels = Dictionary(store.courses.compactMap { c in c.anchorId.map { ($0, NoteReadout.split(TargetLabelFormatter.splitCue(store.courseLabel(c)).main).name) } }, uniquingKeysWith: { a, _ in a })
        return VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text("String health").font(Typeface.display(16)).foregroundStyle(Palette.ink)
                Spacer()
                if advice { Text("Restring soon").font(.caption.weight(.semibold)).foregroundStyle(Color(hex: 0xFFC977)) }
            }
            Group {
                if let worst, abs(worst.centsPerDay) >= 1 {
                    Text("Your \(labels[worst.anchor] ?? worst.anchor) string drifts \(worst.centsPerDay < 0 ? String(localized: "flat") : String(localized: "sharp")) about \(Int(abs(worst.centsPerDay).rounded())) cents a day.")
                } else if !drift.isEmpty {
                    Text("Your strings are holding their pitch well.")
                } else {
                    Text("Tune on a few different days and Timbre learns how each string drifts.")
                }
            }
            .font(.subheadline).foregroundStyle(Palette.inkSoft).fixedSize(horizontal: false, vertical: true)
            if !drift.isEmpty {
                let peak = max(4, drift.map { abs($0.centsPerDay) }.max() ?? 4)
                HStack(alignment: .bottom, spacing: 10) {
                    ForEach(anchors, id: \.self) { anchor in
                        let rate = drift.first { $0.anchor == anchor }?.centsPerDay ?? 0
                        let bad = abs(rate) >= 4
                        VStack(spacing: 4) {
                            RoundedRectangle(cornerRadius: 4).fill(bad ? Palette.amber : Palette.mint.opacity(0.6))
                                .frame(height: max(6, 40 * abs(rate) / peak))
                            Text(labels[anchor] ?? anchor).font(.caption2.weight(bad ? .bold : .regular)).foregroundStyle(bad ? Color(hex: 0xFFC977) : Palette.inkSoft)
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
                .frame(height: 58, alignment: .bottom)
                .accessibilityHidden(true)
            }
            Button { confirmRestring = true } label: {
                Label(restrung.map { String(localized: "Restrung \($0.formatted(.relative(presentation: .named)))") } ?? String(localized: "I just restrung"), systemImage: "arrow.triangle.2.circlepath")
                    .font(.footnote.weight(.semibold)).foregroundStyle(Palette.mint)
            }
            .buttonStyle(.plain)
            .confirmationDialog("Mark new strings on \(store.instrumentDisplayName)?", isPresented: $confirmRestring, titleVisibility: .visible) {
                Button("I just restrung") { store.markRestrung() }
            }
            .accessibilityIdentifier("journey.restrung")
        }
        .stillCard(tint: advice ? Palette.amber : nil)
    }

    private var achievements: some View {
        let state = store.progress
        let earned = Set(state.achievements)
        return VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text("Achievements").font(Typeface.display(16)).foregroundStyle(Palette.ink)
                Spacer()
                Text("\(earned.count) of \(Achievements.all.count)").font(.caption).foregroundStyle(Palette.inkSoft)
            }
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 92), spacing: 10)], spacing: 14) {
                ForEach(Achievements.all.sorted { earned.contains($0.id) && !earned.contains($1.id) }) { a in
                    VStack(spacing: 6) {
                        AchievementMedal(achievement: a, earned: earned.contains(a.id))
                        Text(LocalizedStringKey(a.title)).font(.caption.weight(.semibold)).foregroundStyle(earned.contains(a.id) ? Palette.ink : Palette.inkFaint)
                            .multilineTextAlignment(.center).lineLimit(2)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .stillCard()
    }

    private var tuningSessions: [PracticeRecord] {
        store.records.filter { $0.kind == "tuning" && $0.meanAbsoluteCents != nil }.sorted { $0.date < $1.date }.suffix(40).map { $0 }
    }

    private var accuracy: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Tuning accuracy").font(Typeface.display(16)).foregroundStyle(Palette.ink)
            if tuningSessions.count < 2 {
                Text("Tune a few times to see how close you land.").font(.subheadline).foregroundStyle(Palette.inkSoft)
            } else {
                Chart(tuningSessions) { record in
                    LineMark(x: .value("Date", record.date), y: .value("Cents", record.meanAbsoluteCents ?? 0))
                        .interpolationMethod(.catmullRom).foregroundStyle(Palette.mint)
                    PointMark(x: .value("Date", record.date), y: .value("Cents", record.meanAbsoluteCents ?? 0)).foregroundStyle(Palette.mint)
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

    private var recent: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Recent").font(Typeface.display(16)).foregroundStyle(Palette.ink)
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
                    } else if record.kind == "lesson" {
                        Text(String(repeating: "★", count: max(1, min(3, record.stableCount)))).font(.footnote).foregroundStyle(Palette.amber)
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
        case "lesson": return "graduationcap.fill"
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
        case "lesson": return store.curriculum.course(id: String(record.instrumentId.dropFirst("learn.".count)))?.title.localized ?? String(localized: "Lesson")
        case "ear": return String(localized: "Ear training")
        case "rhythm": return String(localized: "Metronome")
        case "drone": return String(localized: "Drone")
        case "chord": return String(localized: "Chords")
        case "scale": return String(localized: "Scales")
        default: return store.catalog.instrument(id: record.instrumentId)?.name.localized ?? String(localized: "Chromatic tuning")
        }
    }
}
