import Charts
import SwiftUI
import TimbreCore

/// Progress: streak, level and accuracy, the practice calendar, string health, achievements, history.
struct JourneyView: View {
    @EnvironmentObject private var store: AppStore
    @EnvironmentObject private var commerce: CommerceService
    @State private var confirmRestring = false
    /// The string-health bars grow from the baseline once.
    @State private var driftShown = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

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
                driftChart(drift, anchors: anchors, labels: labels)
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
                DriftThresholdLine().stroke(Palette.amber.opacity(0.4), style: StrokeStyle(lineWidth: 1, dash: [3, 4]))
                    .frame(height: 1).offset(y: -threshold)
            }
            .overlay(alignment: .bottom) { Rectangle().fill(.white.opacity(0.16)).frame(height: 1) }
            HStack(spacing: 0) {
                ForEach(anchors, id: \.self) { anchor in
                    let bad = abs(drift.first { $0.anchor == anchor }?.centsPerDay ?? 0) >= 4
                    Text(labels[anchor] ?? anchor).font(.caption2.weight(bad ? .bold : .medium))
                        .foregroundStyle(bad ? Color(hex: 0xFFC977) : Palette.inkSoft)
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
        let tint = bad ? Palette.amber : Palette.mint
        let bar = rate == nil ? 0 : max(4, height * CGFloat(min(1, magnitude / peak)))
        let top = UnevenRoundedRectangle(topLeadingRadius: 5, topTrailingRadius: 5, style: .continuous)
        return VStack(spacing: 5) {
            Text(verbatim: rate.map(Self.signed) ?? "–").font(Typeface.number(10))
                .foregroundStyle(bad ? Color(hex: 0xFFC977) : Palette.inkFaint)
            ZStack(alignment: .bottom) {
                top.fill(.white.opacity(0.05)).frame(height: height)
                top.fill(LinearGradient(colors: [tint, tint.opacity(bad ? 0.7 : 0.45)], startPoint: .top, endPoint: .bottom))
                    .frame(height: driftShown ? bar : 0)
                    .shadow(color: bad ? tint.opacity(0.45) : .clear, radius: 6)
            }
            .frame(width: 16)
        }
    }

    /// Whole cents a day with a sign: "−7" goes flat, "+2" goes sharp.
    private static func signed(_ rate: Double) -> String {
        let n = Int(rate.rounded())
        if n == 0 { return 0.formatted() }
        return (n > 0 ? "+" : "−") + abs(n).formatted()
    }

    private var achievements: some View {
        let badges = badgeProgress
        let earnedCount = badges.filter(\.earned).count
        return VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                Text("Achievements").font(Typeface.display(16)).foregroundStyle(Palette.ink)
                Spacer()
                Text("\(earnedCount) of \(Achievements.all.count)").font(.caption).foregroundStyle(Palette.inkSoft)
            }
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 92), spacing: 10, alignment: .top)], spacing: 16) {
                ForEach(badges) { badge in badgeCell(badge) }
            }
        }
        .stillCard()
    }

    /// Earned first, then the locked ones closest to their goal.
    private var badgeProgress: [BadgeProgress] {
        let state = store.progress
        let earned = Set(state.achievements)
        let streakBest = store.streak.best
        let custom = store.settings.customTunings?.count ?? 0
        var all: [BadgeProgress] = []
        for (index, a) in Achievements.all.enumerated() {
            let value = a.value(state, streakBest: streakBest, customTunings: custom)
            all.append(BadgeProgress(achievement: a, earned: earned.contains(a.id), value: value, order: index))
        }
        return all.sorted(by: BadgeProgress.precedes)
    }

    private func badgeCell(_ badge: BadgeProgress) -> some View {
        let a = badge.achievement
        let shown = min(badge.value, a.goal)
        return VStack(spacing: 6) {
            AchievementMedal(achievement: a, earned: badge.earned, progress: badge.earned ? nil : badge.fraction)
            Text(LocalizedStringKey(a.title)).font(.caption.weight(.semibold))
                .foregroundStyle(badge.earned ? Palette.ink : Palette.inkSoft)
                .multilineTextAlignment(.center)
                .lineLimit(2, reservesSpace: true)
            if !badge.earned {
                Text(verbatim: "\(shown.formatted()) / \(a.goal.formatted())").font(Typeface.number(11))
                    .foregroundStyle(shown > 0 ? Palette.mint : Palette.inkFaint)
                    .lineLimit(1).minimumScaleFactor(0.8)
            }
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(LocalizedStringKey(a.title)))
        .accessibilityValue(badge.earned ? Text("Earned") : Text(LocalizedStringKey(a.detail)) + Text(verbatim: ", ") + Text("\(shown) of \(a.goal)"))
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

    /// Pro teaser: the badge sits by the title so the pitch gets the full width and wraps instead of truncating.
    private var lockedInsights: some View {
        Button { store.presentPaywall("journey") } label: {
            HStack(spacing: 14) {
                IconOrb(symbol: "chart.xyaxis.line", tint: Palette.mint)
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
                Image(systemName: "chevron.right").font(.footnote.weight(.bold)).foregroundStyle(Palette.inkFaint)
                    .accessibilityHidden(true)
            }
            .contentShape(Rectangle())
            .stillCard(tint: Palette.amber)
        }
        .buttonStyle(PressScaleStyle())
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

/// An achievement with its live metric, for the grid.
private struct BadgeProgress: Identifiable {
    let achievement: Achievement
    let earned: Bool
    let value: Int
    /// Position in `Achievements.all`, to keep ties stable.
    let order: Int
    var id: String { achievement.id }
    var fraction: Double { min(1, Double(max(0, value)) / Double(max(1, achievement.goal))) }

    static func precedes(_ lhs: BadgeProgress, _ rhs: BadgeProgress) -> Bool {
        if lhs.earned != rhs.earned { return lhs.earned }
        if !lhs.earned && lhs.fraction != rhs.fraction { return lhs.fraction > rhs.fraction }
        return lhs.order < rhs.order
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
