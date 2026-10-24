import Charts
import SwiftUI
import TimbreCore

/// Progress: streak, level and accuracy, the week in review, the practice calendar, string health, achievements, history.
struct JourneyView: View {
    @EnvironmentObject private var store: AppStore
    @EnvironmentObject private var commerce: CommerceService
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

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("Progress").font(Typeface.display(30)).tracking(-0.6).foregroundStyle(Palette.ink).accessibilityAddTraits(.isHeader)
                    stats
                    weekCard
                    calendar
                    stringHealth
                    if commerce.isPro { accuracy } else { lockedInsights }
                    achievements
                    recent
                }
                .padding(.horizontal, Metrics.gutter).padding(.vertical, 12)
            }
            .stageTopShade()
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
            stat("star", Palette.mint, levelValue(level.number), Text(LocalizedStringKey(level.name)))
                .accessibilityLabel(Text("Level \(level.number)") + Text(verbatim: ", ") + Text(LocalizedStringKey(level.name)))
            stat("scope", Palette.amber, WeekRecap.centsText(average), Text("avg accuracy"))
        }
    }

    /// "LV 5": the level reads as a level, not a count (the caption the level rings use).
    private func levelValue(_ number: Int) -> Text {
        Text("LV").font(Typeface.label(13)).foregroundStyle(Palette.mint) + Text(verbatim: " ") + Text(number, format: .number)
    }

    /// The last seven days with a poster to share; hidden until there is practice in them.
    @ViewBuilder private var weekCard: some View {
        let recap = WeekRecap(records: store.records, streak: store.streak)
        if !recap.isEmpty { WeekRecapCard(recap: recap) }
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
            HStack(alignment: .firstTextBaseline) {
                Text("Last five weeks").font(Typeface.display(16)).foregroundStyle(Palette.ink)
                Spacer()
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
                                RoundedRectangle(cornerRadius: 7, style: .continuous).strokeBorder(Palette.amber.opacity(0.7), style: StrokeStyle(lineWidth: 1.5, dash: [3, 3]))
                            } else if date == today {
                                RoundedRectangle(cornerRadius: 7, style: .continuous).strokeBorder(Palette.ink.opacity(0.9), lineWidth: 2)
                                    .shadow(color: Palette.mint.opacity(0.6), radius: 6)
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
                        .font(Typeface.label(11)).foregroundStyle(today ? Palette.mint : Palette.inkFaint)
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
            HStack(alignment: .firstTextBaseline) {
                Text("Achievements").font(Typeface.display(16)).foregroundStyle(Palette.ink)
                Spacer()
                Text("\(earnedCount) of \(Achievements.all.count)").font(.caption).foregroundStyle(Palette.inkSoft)
            }
            badgeGrid(shown, columns: columns)
                .onGeometryChange(for: CGFloat.self) { proxy in proxy.size.width } action: { width in badgeGridWidth = width }
            if badges.count > collapsed {
                Button {
                    withAnimation(Motion.settle) { allBadges.toggle() }
                    Haptics.shared.selection()
                } label: {
                    HStack(spacing: 6) {
                        Text(allBadges ? LocalizedStringKey("Show fewer") : LocalizedStringKey("Show all"))
                        Image(systemName: "chevron.down").rotationEffect(.degrees(allBadges ? 180 : 0))
                    }
                    .font(.footnote.weight(.semibold)).foregroundStyle(Palette.mint)
                    .frame(maxWidth: .infinity, minHeight: 36)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
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
            Text("Earned").font(Typeface.label(11)).foregroundStyle(badge.achievement.tier.ink)
                .lineLimit(1).minimumScaleFactor(0.8)
        } else {
            Text(verbatim: "\(shown.formatted()) / \(badge.achievement.goal.formatted())").font(Typeface.number(11))
                .foregroundStyle(shown > 0 ? badge.achievement.category.tint : Palette.inkFaint)
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
                    Text("Earned").font(Typeface.label(12)).foregroundStyle(a.tier.ink)
                } else {
                    HStack(spacing: 8) {
                        ProgressLine(value: badge.fraction, color: a.category.tint, height: 5).frame(width: 110)
                        Text(verbatim: "\(shown.formatted()) / \(a.goal.formatted())").font(Typeface.number(12)).foregroundStyle(Palette.inkSoft)
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

/// A horizontal hairline through the middle of its frame (for dashed guides).
private struct DriftThresholdLine: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.midY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
        return path
    }
}
