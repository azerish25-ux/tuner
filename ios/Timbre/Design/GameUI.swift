import SwiftUI
import TimbreCore
import UIKit

/// Flame and day count; taps through to Progress. Around the flame, Today's ring: any activity of it keeps
/// the streak (the flame lights), finishing them all closes the ring.
/// The capsule is at least 36 pt and grows with its text; the target is at least 44 pt. Like a bar item it stops
/// growing at AX1 and offers the Large Content Viewer.
struct StreakChip: View {
    @EnvironmentObject private var store: AppStore
    /// Draws Today's ring around the flame. Nil decides by tab: not on Play or Learn, whose Today cards show it.
    var showsToday: Bool? = nil
    var action: () -> Void = {}
    /// Today's lesson follows Learn's course; reading it here redraws the ring when that changes.
    @AppStorage("learn.course") private var learnCourseId = "guitar"
    /// The capsule's side inset, growing with the count's text.
    @ScaledMetric(relativeTo: .subheadline) private var inset: CGFloat = 12

    var body: some View {
        let streak = store.streak
        let today = showsToday ?? (store.selectedTab != .practice && store.selectedTab != .learn)
        let activities = today ? store.dailySet : []
        let done = Set(activities.map(\.kind).filter { store.dailyDone($0) })
        Button(action: action) {
            HStack(spacing: 5) {
                flame(lit: streak.practicedToday, bounce: streak.current, ring: activities, done: done)
                Text("\(streak.current)").font(Typeface.label(14, relativeTo: .subheadline)).foregroundStyle(Palette.flameInk).monospacedDigit()
                if store.streakFreezes > 0 {
                    // Banked streak freezes, one flake each.
                    HStack(spacing: 1) {
                        ForEach(0..<store.streakFreezes, id: \.self) { _ in
                            Image(systemName: "snowflake").font(.caption2.weight(.bold)).foregroundStyle(Palette.frost)
                                .symbolEffect(.bounce, value: store.streakPulse)
                        }
                    }
                    .transition(.scale.combined(with: .opacity))
                }
            }
            .padding(.leading, activities.isEmpty ? inset : inset / 2).padding(.trailing, inset)
            .padding(.vertical, 4)
            .frame(minHeight: 36)
            .background(Capsule().fill(Palette.flame.opacity(0.10)))
            .overlay(Capsule().strokeBorder(Palette.flame.opacity(0.35), lineWidth: 1))
            .frame(minHeight: Metrics.minTarget)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .dynamicTypeSize(...DynamicTypeSize.accessibility1)
        .accessibilityShowsLargeContentViewer()
        .accessibilityLabel(Text("\(streak.current)-day streak"))
        .accessibilityValue(value(done: done.count, total: activities.count))
        .accessibilityIdentifier("streak.chip")
    }

    /// The flame, lit once today counts; with Today's activities, inside their ring.
    @ViewBuilder private func flame(lit: Bool, bounce: Int, ring: [DailyActivity], done: Set<DailyActivity.Kind>) -> some View {
        let icon = Image(systemName: "flame.fill").font(.system(size: ring.isEmpty ? 13 : 11, weight: .semibold))
            .foregroundStyle(lit ? Palette.flame : Palette.inkFaint)
            .symbolEffect(.bounce, value: bounce)
        if ring.isEmpty {
            icon
        } else {
            ZStack {
                DailySetRing(activities: ring, done: done, lineWidth: 2.5, gap: 0.08)
                icon
            }
            .frame(width: 26, height: 26)
        }
    }

    /// "Today: 1 of 3" while the ring shows, and the banked freezes.
    private func value(done: Int, total: Int) -> Text {
        var parts: [Text] = []
        if total > 0 { parts.append(Text("Today") + Text(verbatim: ": ") + Text("\(done) of \(total)")) }
        if store.streakFreezes > 0 { parts.append(Text("\(store.streakFreezes) streak freezes")) }
        guard let first = parts.first else { return Text(verbatim: "") }
        return parts.dropFirst().reduce(first) { (line: Text, part: Text) -> Text in line + Text(verbatim: ", ") + part }
    }
}

/// The streak's flame, alive: a warm halo, the gradient body and a white-hot core that sway and flicker out of
/// step. Still under Reduce Motion, and when `animated` is off (share cards rendered to an image).
struct StreakFlame: View {
    var size: CGFloat = 120
    var lit = true
    var animated = true
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Group {
            if animated && !reduceMotion {
                TimelineView(.animation(minimumInterval: 1 / 60)) { timeline in
                    flame(timeline.date.timeIntervalSinceReferenceDate)
                }
            } else {
                flame(0)
            }
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }

    private static let bodyFill = LinearGradient(colors: [Color(hex: 0xFFE29A), Palette.flame, Color(hex: 0xE2542C)], startPoint: .top, endPoint: .bottom)
    private static let coreFill = LinearGradient(colors: [.white, Color(hex: 0xFFE29A)], startPoint: .top, endPoint: .bottom)
    private static let unlitFill = LinearGradient(colors: [Palette.inkFaint, Palette.line], startPoint: .top, endPoint: .bottom)

    private func flame(_ t: Double) -> some View {
        let sway = sin(t * 2.3) * 3 + sin(t * 5.1) * 1.2
        let stretch = 1 + 0.035 * sin(t * 6.7) + 0.02 * sin(t * 11.3)
        let pulse = 1 + 0.06 * sin(t * 8.9 + 1)
        return ZStack {
            Circle()
                .fill(RadialGradient(colors: [Palette.flame.opacity(lit ? 0.42 : 0.08), .clear], center: .center, startRadius: 2, endRadius: size * 0.62))
                .frame(width: size * 1.5, height: size * 1.5)
                .scaleEffect(pulse)
            Image(systemName: "flame.fill").font(.system(size: size * 0.78, weight: .bold))
                .foregroundStyle(lit ? Self.bodyFill : Self.unlitFill)
                .scaleEffect(x: 1, y: stretch, anchor: .bottom)
                .rotationEffect(.degrees(sway), anchor: .bottom)
                .shadow(color: Palette.flame.opacity(lit ? 0.6 : 0), radius: size * 0.16)
            if lit {
                Image(systemName: "flame.fill").font(.system(size: size * 0.34, weight: .bold))
                    .foregroundStyle(Self.coreFill)
                    .opacity(0.9)
                    .scaleEffect(x: 1, y: pulse, anchor: .bottom)
                    .rotationEffect(.degrees(-sway * 0.6), anchor: .bottom)
                    .offset(y: size * 0.17)
            }
        }
    }
}

/// Level number inside a ring that fills with XP toward the next level, captioned "LV" on mid-size rings and
/// "LEVEL" on the large one, so the number always says what it counts. Under 44 pt there is no room for a caption
/// over the number, so the header ring sets the two on one line, "LV 5" (VoiceOver says "Level 5"). The ring is a
/// fixed-size graphic: its type stops growing at xxxLarge, and as a button its target is at least 44 pt.
struct LevelRing: View {
    @EnvironmentObject private var store: AppStore
    var size: CGFloat = 36
    var action: (() -> Void)?
    private var large: Bool { size >= 50 }
    private var captioned: Bool { size >= Metrics.minTarget }
    var body: some View {
        let xp = store.progress.xp
        let level = store.level
        let ring = ZStack {
            Circle().stroke(.white.opacity(0.12), lineWidth: size * 0.09)
            Circle().trim(from: 0, to: max(0.02, level.progress(xp)))
                .stroke(Palette.mint, style: StrokeStyle(lineWidth: size * 0.09, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(Motion.settle, value: xp)
            label(level.number)
                .frame(maxWidth: size * (captioned ? 0.66 : 0.74))
                .offset(y: captioned ? size * 0.015 : 0)
        }
        .frame(width: size, height: size)
        .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("Level \(level.number), \(xp - level.floor) of \(level.next - level.floor) XP"))
        if let action {
            Button(action: action) {
                ring.frame(minWidth: Metrics.minTarget, minHeight: Metrics.minTarget).contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityShowsLargeContentViewer()
            .accessibilityIdentifier("level.ring")
        } else { ring }
    }

    /// "LEVEL" over the number in a large ring, "LV" over it in a medium one; in a small one (the tab headers') the
    /// two share a line, "LV 5", so the ring reads as a level rather than a bare count.
    @ViewBuilder private func label(_ number: Int) -> some View {
        if captioned {
            VStack(spacing: large ? 1 : -1) {
                caption
                Text("\(number)").font(Typeface.label(size * (large ? 0.34 : 0.33))).foregroundStyle(Palette.ink)
                    .contentTransition(.numericText())
                    .lineLimit(1).minimumScaleFactor(0.5)
            }
        } else {
            (Text("LV").font(Typeface.label(size * 0.24)).tracking(0.3).foregroundStyle(Palette.mint)
                + Text(verbatim: " ")
                + Text("\(number)").font(Typeface.label(size * 0.36)).foregroundStyle(Palette.ink))
                .contentTransition(.numericText())
                .lineLimit(1).minimumScaleFactor(0.5)
        }
    }

    private var caption: some View {
        Text(large ? LocalizedStringKey("LEVEL") : LocalizedStringKey("LV"))
            .font(.system(size: max(6.5, size * (large ? 0.13 : 0.19)), weight: .heavy))
            .tracking(large ? 1 : 0.4)
            .foregroundStyle(Palette.mint)
            .lineLimit(1).minimumScaleFactor(0.6)
    }
}

/// Thin progress bar used by quests and levels.
struct ProgressLine: View {
    let value: Double
    var color: Color = Palette.mint
    var height: CGFloat = 6
    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule().fill(.white.opacity(0.10))
                Capsule().fill(color).frame(width: max(height, proxy.size.width * max(0, min(1, value))))
                    .opacity(value > 0 ? 1 : 0)
            }
        }
        .frame(height: height)
        .animation(Motion.settle, value: value)
        .accessibilityHidden(true)
    }
}

extension Quest {
    var title: LocalizedStringKey {
        switch kind {
        case .tuneAll: return "Tune every string"
        case .holdInTune: return "Lock \(target) strings in tune"
        case .sniperWin: return "Win a round of Pitch Sniper"
        case .bullseyes: return "Hit \(target) bullseyes"
        case .practiceMinutes: return "Practice for \(target) minutes"
        case .earCorrect: return "Get \(target) ear questions right"
        case .lessons: return "Finish \(target) lessons"
        }
    }
    var symbol: String {
        switch kind {
        case .tuneAll, .holdInTune: return "tuningfork"
        case .sniperWin, .bullseyes: return "scope"
        case .practiceMinutes: return "clock"
        case .earCorrect: return "ear"
        case .lessons: return "graduationcap"
        }
    }
    var tint: Color { [.tuneAll, .holdInTune].contains(kind) ? Palette.amber : kind == .practiceMinutes ? Palette.inkSoft : kind == .lessons ? Palette.violet : Palette.mint }
}

/// One daily quest: icon, title, a bar with its count ("3 / 10", the tuning quest in strings) and the XP it pays.
/// The Play hub's quest rows are this row too (`HubQuestRow` is gone).
struct QuestRow: View {
    @EnvironmentObject private var store: AppStore
    let quest: Quest
    /// The counter to show when the caller already has it; nil reads the one saved counter
    /// (`AppStore.questCounter`: the tuning quest counts today's strings, as the tuner's quest line does).
    var count: (done: Int, total: Int)? = nil
    var body: some View {
        let counter = count ?? store.questCounter(quest)
        let progress = counter.done, target = counter.total
        let done = store.questProgress(quest) >= quest.target
        let tile = RoundedRectangle(cornerRadius: Metrics.cornerTile, style: .continuous)
        HStack(spacing: 12) {
            Image(systemName: done ? "checkmark" : quest.symbol).font(.system(size: 15, weight: .semibold))
                .foregroundStyle(done ? Palette.onAccent : quest.tint)
                .frame(width: 34, height: 34)
                .background(RoundedRectangle(cornerRadius: Metrics.cornerChip, style: .continuous).fill(done ? AnyShapeStyle(Palette.mint) : AnyShapeStyle(quest.tint.opacity(0.14))))
            VStack(alignment: .leading, spacing: 7) {
                Text(quest.title).font(.subheadline.weight(.semibold)).foregroundStyle(done ? Palette.inkSoft : Palette.ink)
                    .strikethrough(done, color: Palette.inkFaint)
                    .fixedSize(horizontal: false, vertical: true)
                HStack(spacing: 10) {
                    ProgressLine(value: Double(progress) / Double(max(1, target)), color: done ? Palette.mint : quest.tint, height: 5)
                    Text.fraction(progress, target).font(Typeface.number(12)).foregroundStyle(done ? Palette.mint : Palette.inkSoft)
                        .contentTransition(.numericText())
                        .fixedSize()
                        // The row's value says it ("3 of 10").
                        .accessibilityHidden(true)
                }
            }
            reward(done)
        }
        .padding(.horizontal, 14).padding(.vertical, 12)
        .background(tile.fill(Palette.stageRaised))
        .overlay(tile.strokeBorder(Palette.hairline, lineWidth: 1))
        .animation(Motion.settle, value: progress)
        .accessibilityElement(children: .combine)
        .accessibilityValue(Text(done ? "Done" : "\(progress) of \(target)"))
    }

    /// "+20 XP" in a mint pill while open; "Done" once claimed.
    @ViewBuilder private func reward(_ done: Bool) -> some View {
        if done {
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

extension Achievement.Tier {
    /// The rim's metal, swept around the medal (bronze, silver or gold).
    var metal: [Color] {
        switch self {
        case .bronze: return [Color(hex: 0xF6C08E), Color(hex: 0x9A5A2C), Color(hex: 0xE9A673), Color(hex: 0x6E3B1C), Color(hex: 0xF6C08E)]
        case .silver: return [Color(hex: 0xFFFFFF), Color(hex: 0x8E97A4), Color(hex: 0xE6E9EE), Color(hex: 0x6B7380), Color(hex: 0xFFFFFF)]
        case .gold: return [Color(hex: 0xFFEDB0), Color(hex: 0xC48416), Color(hex: 0xFFD66E), Color(hex: 0x9A6508), Color(hex: 0xFFEDB0)]
        }
    }
    /// The tier as one colour, for text and hairlines.
    var ink: Color {
        switch self {
        case .bronze: return Color(hex: 0xE9A673)
        case .silver: return Color(hex: 0xD3D8DF)
        case .gold: return Color(hex: 0xFFD66E)
        }
    }
}

extension Achievement.Category {
    /// The medal face, lit from the top left: tuning amber, dedication flame, ear mint, lessons violet, courses deep sky.
    var face: (light: Color, deep: Color) {
        switch self {
        case .tuning: return (Color(hex: 0xFFD596), Color(hex: 0xB86E12))
        case .dedication: return (Color(hex: 0xFFBE8F), Color(hex: 0xC2410C))
        case .ear: return (Color(hex: 0x8BF7D2), Palette.mintDeep)
        case .learning: return (Color(hex: 0xCFC5FF), Color(hex: 0x5B47C9))
        case .course: return (Color(hex: 0x4D86AD), Color(hex: 0x0E2234))
        }
    }
    /// The category's accent: progress arcs and labels.
    var tint: Color {
        switch self {
        case .tuning: return Palette.amber
        case .dedication: return Palette.flame
        case .ear: return Palette.mint
        case .learning: return Palette.violet
        case .course: return Palette.sky
        }
    }
}

/// A medal: a metal rim for the tier (bronze, silver, gold) around a face in the category's colour, with the
/// badge's symbol (or an instrument's artwork) embossed on it; a glint sweeps across the first time it is seen.
/// Locked, it is a dark disc with a faint rim, the emblem in grey, a lock pip and the progress toward its goal.
struct AchievementMedal: View {
    let achievement: Achievement
    let earned: Bool
    var size: CGFloat = 56
    /// 0…1 toward the goal for a locked medal; nil (or 0) draws no arc.
    var progress: Double? = nil
    /// Asset name of an instrument cut-out drawn instead of the symbol (course badges).
    var image: String? = nil
    /// Sweeps a glint across an earned medal when it appears (a badge not seen before).
    var shine = false
    @State private var sweep: CGFloat = -1
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var rim: CGFloat { max(3, size * 0.075) }

    var body: some View {
        ZStack {
            if earned { earnedFace } else { lockedFace }
        }
        .frame(width: size, height: size)
        .onAppear(perform: runShine)
        .onChange(of: shine) { _, on in if on { runShine() } }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(LocalizedStringKey(achievement.title)))
        .accessibilityValue(Text(earned ? "Earned" : LocalizedStringKey(achievement.detail)))
    }

    private var earnedFace: some View {
        let face = achievement.category.face
        return ZStack {
            Circle().fill(AngularGradient(colors: achievement.tier.metal, center: .center, angle: .degrees(-35)))
            Circle().inset(by: rim)
                .fill(RadialGradient(colors: [face.light, face.deep], center: UnitPoint(x: 0.32, y: 0.26), startRadius: 0, endRadius: size * 0.62))
            Circle().inset(by: rim).strokeBorder(.black.opacity(0.3), lineWidth: 1)
            emblem(lit: true)
            // Gloss on the upper half of the face.
            Circle().inset(by: rim + 1)
                .fill(LinearGradient(colors: [.white.opacity(0.26), .white.opacity(0)], startPoint: .top, endPoint: .center))
        }
        .overlay { glint }
        .clipShape(Circle())
        .shadow(color: face.deep.opacity(0.55), radius: size * 0.16, y: size * 0.05)
    }

    private var lockedFace: some View {
        let tint = achievement.category.tint
        return ZStack {
            Circle().fill(Color.white.opacity(0.04))
            Circle().strokeBorder(achievement.tier.ink.opacity(0.22), lineWidth: rim * 0.6)
            if let progress, progress > 0 {
                Circle().inset(by: rim * 0.3).trim(from: 0, to: CGFloat(min(1, max(0.03, progress))))
                    .stroke(tint, style: StrokeStyle(lineWidth: rim * 0.6, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .shadow(color: tint.opacity(0.45), radius: 3)
            }
            emblem(lit: false)
            Image(systemName: "lock.fill").font(.system(size: size * 0.13, weight: .bold)).foregroundStyle(Palette.inkSoft)
                .frame(width: size * 0.3, height: size * 0.3)
                .background(Circle().fill(Palette.stage))
                .overlay(Circle().strokeBorder(.white.opacity(0.14), lineWidth: 1))
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
        }
    }

    @ViewBuilder private func emblem(lit: Bool) -> some View {
        if let image {
            Image(image).resizable().scaledToFit()
                .frame(width: size * 0.64, height: size * 0.64)
                .shadow(color: .black.opacity(lit ? 0.45 : 0), radius: 2, y: 1)
                .saturation(lit ? 1 : 0)
                .opacity(lit ? 1 : 0.38)
        } else {
            Image(systemName: achievement.symbol).font(.system(size: size * 0.34, weight: .bold))
                .foregroundStyle(lit ? Color(hex: 0x0A0C10).opacity(0.82) : Palette.inkFaint.opacity(0.7))
                // Embossed: a hairline of light under the cut.
                .shadow(color: .white.opacity(lit ? 0.35 : 0), radius: 0, y: 0.8)
        }
    }

    /// A diagonal band of light that crosses the face once.
    private var glint: some View {
        LinearGradient(colors: [.white.opacity(0), .white.opacity(0.7), .white.opacity(0)], startPoint: .leading, endPoint: .trailing)
            .frame(width: size * 0.32, height: size * 1.6)
            .rotationEffect(.degrees(24))
            .offset(x: sweep * size)
            .blendMode(.plusLighter)
            .allowsHitTesting(false)
    }

    private func runShine() {
        guard shine, earned, !reduceMotion else { return }
        Task { @MainActor in
            sweep = -1
            try? await Task.sleep(for: .milliseconds(380))
            withAnimation(.easeInOut(duration: 1.0)) { sweep = 1 }
        }
    }
}

/// One announcement for the reward pill.
struct RewardBanner: Identifiable {
    enum Tone { case gold, mint, frost }
    let id = UUID()
    let symbol: String
    let title: Text
    /// Nil for the compact "+XP" pill.
    let detail: Text?
    let tone: Tone
    /// How long it stays open.
    let seconds: Double
    /// What VoiceOver announces.
    let announcement: String
    /// XP-only banners merge while they wait in the queue.
    var xp: Int?

    static func experience(_ amount: Int) -> RewardBanner {
        RewardBanner(symbol: "sparkles", title: Text("+\(amount) XP"), detail: nil, tone: .mint, seconds: 1.8,
                     announcement: String(localized: "+\(amount) XP", bundle: TimbreLocalization.bundle), xp: amount)
    }
}

/// XP, quest, badge, daily-set, level-up and streak announcements, one banner at a time from a queue.
/// On a phone with a Dynamic Island it is a black pill that grows out of the island and stays inside the
/// status-bar band, so it never covers a screen's header. Without an island it hangs just below the status
/// bar on the leading side, clear of the header's trailing controls (streak, level, settings); on wide
/// screens it is centred. Reduce Motion fades it in place. It never takes taps; VoiceOver hears each banner.
struct RewardToast: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var queue: [RewardBanner] = []
    @State private var current: RewardBanner?
    @State private var open = false
    @State private var presenting = false

    var body: some View {
        // The status band is read from a reader that keeps the safe area (inside `.ignoresSafeArea()` it reads 0),
        // with the key window's inset as a fallback; the pill is then placed in full-screen coordinates.
        let windowTop = Self.windowTopInset
        GeometryReader { outer in
            let top = max(outer.safeAreaInsets.top, windowTop)
            GeometryReader { proxy in
                let layout = PillLayout(width: proxy.size.width, top: top)
                if let current {
                    placed(current, layout: layout)
                        .frame(width: proxy.size.width, height: proxy.size.height, alignment: layout.docked ? .topLeading : .top)
                }
            }
            .ignoresSafeArea()
        }
        .environment(\.layoutDirection, rightToLeft ? .rightToLeft : .leftToRight)
        .allowsHitTesting(false)
        .onChange(of: store.rewardPulse) { _, _ in
            if let reward = store.lastReward { enqueue(Self.banners(for: reward)) }
        }
        .onChange(of: store.streakPulse) { _, _ in
            if let notice = store.streakNotice { enqueue([Self.banner(for: notice)]) }
        }
    }

    /// The app's own language direction (the toast sits outside the tab view that carries it).
    private var rightToLeft: Bool {
        let language = store.settings.language
        return Locale.Language(identifier: language == "system" ? Locale.current.identifier : language).characterDirection == .rightToLeft
    }

    /// The key window's top safe-area inset: the status band (59–62 pt on phones with a Dynamic Island).
    @MainActor private static var windowTopInset: CGFloat {
        let windows = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.flatMap(\.windows)
        return (windows.first(where: \.isKeyWindow) ?? windows.first)?.safeAreaInsets.top ?? 0
    }

    /// The pill at its spot: centred on the island (or the screen), or docked at the leading gutter.
    private func placed(_ banner: RewardBanner, layout: PillLayout) -> some View {
        let compact = banner.detail == nil
        let size = layout.size(compact: compact, grown: open || reduceMotion)
        return pill(banner, layout: layout)
            .padding(.top, max(0, layout.centerY(compact: compact) - size.height / 2))
            .padding(.leading, layout.docked ? Metrics.gutter : 0)
    }

    // MARK: Queue

    private func enqueue(_ banners: [RewardBanner]) {
        for banner in banners {
            if let amount = banner.xp, let last = queue.last, let waiting = last.xp {
                queue[queue.count - 1] = .experience(waiting + amount)
            } else {
                queue.append(banner)
            }
        }
        if queue.count > 6 { queue.removeFirst(queue.count - 6) }
        guard !presenting else { return }
        presenting = true
        Task { @MainActor in
            await presentQueue()
            presenting = false
        }
    }

    /// Shows the queue one banner at a time: grow out of the island, hold, shrink back in.
    private func presentQueue() async {
        while !queue.isEmpty {
            let next = queue.removeFirst()
            current = next
            open = false
            AccessibilityNotification.Announcement(next.announcement).post()
            // Let the closed pill appear at the island's size, so it can grow from there.
            try? await Task.sleep(for: .milliseconds(30))
            withMotion(Motion.island, reduceMotion: reduceMotion) { open = true }
            try? await Task.sleep(for: .seconds(queue.count > 1 ? next.seconds * 0.8 : next.seconds))
            withMotion(Motion.islandClose, reduceMotion: reduceMotion) { open = false }
            try? await Task.sleep(for: .milliseconds(reduceMotion ? 220 : 360))
            current = nil
            try? await Task.sleep(for: .milliseconds(90))
        }
    }

    private static func banners(for reward: ProgressUpdate) -> [RewardBanner] {
        var list: [RewardBanner] = []
        if let level = reward.levelUp {
            list.append(RewardBanner(symbol: "star.fill", title: Text("Level \(level.number)"), detail: Text(LocalizedStringKey(level.name)), tone: .gold, seconds: 2.6,
                                     announcement: String(localized: "Level \(level.number)", bundle: TimbreLocalization.bundle) + ", " + NSLocalizedString(level.name, comment: "")))
        }
        if reward.dailySetCompleted {
            list.append(RewardBanner(symbol: "sun.max.fill", title: Text("Today complete"), detail: Text("+\(XPReward.dailySet) XP"), tone: .gold, seconds: 2.6,
                                     announcement: String(localized: "Today complete", bundle: TimbreLocalization.bundle)))
        }
        let badges = reward.achievementsEarned
        if badges.count >= 3 {
            // Several at once (a launch catching up on new badges): one banner naming the first two.
            let names = Text(LocalizedStringKey(badges[0].title)) + Text(verbatim: ", ") + Text(LocalizedStringKey(badges[1].title)) + Text(verbatim: " …")
            list.append(RewardBanner(symbol: "rosette", title: Text("\(badges.count) achievements unlocked"), detail: names, tone: .gold, seconds: 2.8,
                                     announcement: String(localized: "\(badges.count) achievements unlocked", bundle: TimbreLocalization.bundle)))
        } else {
            for a in badges {
                list.append(RewardBanner(symbol: a.symbol, title: Text(LocalizedStringKey(a.title)), detail: Text("Achievement unlocked"), tone: .gold, seconds: 2.6,
                                         announcement: NSLocalizedString(a.title, comment: "") + ", " + String(localized: "Achievement unlocked", bundle: TimbreLocalization.bundle)))
            }
        }
        for q in reward.questsCompleted {
            list.append(RewardBanner(symbol: "checkmark", title: Text(q.title), detail: Text("Quest complete · +\(q.xp) XP"), tone: .mint, seconds: 2.2,
                                     announcement: String(localized: "Quest complete · +\(q.xp) XP", bundle: TimbreLocalization.bundle)))
        }
        if list.isEmpty && reward.xpGained > 0 { list.append(.experience(reward.xpGained)) }
        return list
    }

    private static func banner(for notice: AppStore.StreakNotice) -> RewardBanner {
        switch notice {
        case .earned:
            return RewardBanner(symbol: "snowflake", title: Text("Streak freeze earned"), detail: Text("Keeps your streak if you miss a day"), tone: .frost, seconds: 2.4,
                                announcement: String(localized: "Streak freeze earned", bundle: TimbreLocalization.bundle))
        case .saved(let days):
            return RewardBanner(symbol: "snowflake", title: Text("Streak saved"), detail: Text("Streak freezes used: \(days)"), tone: .frost, seconds: 2.4,
                                announcement: String(localized: "Streak saved", bundle: TimbreLocalization.bundle))
        }
    }

    // MARK: Pill

    private func pill(_ banner: RewardBanner, layout: PillLayout) -> some View {
        let compact = banner.detail == nil
        let grown = open || reduceMotion
        let size = layout.size(compact: compact, grown: grown)
        return ZStack {
            Capsule(style: .continuous).fill(layout.island ? Color.black : Palette.surface)
            Capsule(style: .continuous).strokeBorder(.white.opacity(open ? (layout.island ? 0.08 : 0.12) : 0), lineWidth: 1)
            content(banner, layout: layout, compact: compact)
                .opacity(open ? 1 : 0)
                .blur(radius: open || reduceMotion ? 0 : 5)
                .animation(Motion.fade.delay(open && !reduceMotion ? 0.1 : 0), value: open)
        }
        .frame(width: size.width, height: size.height)
        .clipShape(Capsule(style: .continuous))
        .shadow(color: .black.opacity(open ? 0.45 : 0), radius: 16, y: 6)
        // On an island the closed pill is the island itself; elsewhere it fades and drops in.
        .opacity(layout.island && !reduceMotion ? 1 : (open ? 1 : 0))
        .scaleEffect(layout.island || reduceMotion || open ? 1 : 0.86, anchor: .top)
        .offset(y: layout.island || reduceMotion || open ? 0 : -10)
        .dynamicTypeSize(...DynamicTypeSize.large)
        .environment(\.colorScheme, .dark)
        .accessibilityHidden(true)
    }

    @ViewBuilder private func content(_ banner: RewardBanner, layout: PillLayout, compact: Bool) -> some View {
        if layout.island {
            // Icon left of the camera cutout, words right of it.
            HStack(spacing: 0) {
                icon(banner, size: compact ? 22 : 28)
                    .padding(.leading, compact ? 8 : 9)
                    .frame(width: layout.side(compact: compact), alignment: .leading)
                Color.clear.frame(width: layout.cutout)
                words(banner)
                    .padding(.trailing, 12)
                    .frame(width: layout.side(compact: compact), alignment: .leading)
            }
            .frame(width: layout.size(compact: compact, grown: true).width)
        } else {
            HStack(spacing: 8) {
                icon(banner, size: compact ? 24 : 28)
                words(banner)
                Spacer(minLength: 0)
            }
            .padding(.leading, 7).padding(.trailing, 12)
            .frame(width: layout.size(compact: compact, grown: true).width)
        }
    }

    private func words(_ banner: RewardBanner) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            banner.title.font(Typeface.label(13))
                .foregroundStyle(banner.detail == nil ? Palette.mint : Palette.ink)
                .lineLimit(1).minimumScaleFactor(0.7)
            if let detail = banner.detail {
                detail.font(.caption2).foregroundStyle(Palette.inkSoft)
                    .lineLimit(2).minimumScaleFactor(0.75)
            }
        }
    }

    private func icon(_ banner: RewardBanner, size: CGFloat) -> some View {
        Image(systemName: banner.symbol).font(.system(size: size * 0.46, weight: .bold))
            .foregroundStyle(banner.tone == .mint ? Palette.onAccent : Palette.onGold)
            .frame(width: size, height: size)
            .background(Circle().fill(Self.fill(banner.tone)))
            .symbolEffect(.bounce, value: open)
    }

    private static func fill(_ tone: RewardBanner.Tone) -> AnyShapeStyle {
        switch tone {
        case .gold: return AnyShapeStyle(Palette.proGold)
        case .mint: return AnyShapeStyle(Palette.mint)
        case .frost: return AnyShapeStyle(Palette.frost)
        }
    }
}

/// Where the reward pill sits. Phones with a Dynamic Island have a status band of 54 pt or more, with the
/// island (about 126 × 37 pt) near its top; the pill grows from the island and stays inside the band.
/// Other phones (notch or none) dock it under the status bar at the leading gutter, narrow enough to leave the
/// header's trailing controls in view; wide screens (iPad, landscape) centre it under the status bar.
private struct PillLayout {
    let width: CGFloat
    let top: CGFloat
    static let islandWidth: CGFloat = 126
    static let islandHeight: CGFloat = 37
    /// Kept clear on the trailing side: streak chip, level ring and settings button (44 pt targets) with the gutter.
    static let headerControls: CGFloat = 200
    var island: Bool { top >= 51 && width < 500 }
    var docked: Bool { !island && width < 600 }
    /// The island's top edge: about 11 pt below the screen top on a 59 pt band, 14 pt on a 62 pt band.
    var islandTop: CGFloat { max(10, min(14, top - 48)) }
    /// The camera cutout plus a little air.
    var cutout: CGFloat { Self.islandWidth + 6 }
    /// Just below the status bar (a little air when there is none, as in landscape).
    private var belowStatusBar: CGFloat { max(top, 4) + 4 }
    func centerY(compact: Bool) -> CGFloat {
        if island { return islandTop + Self.islandHeight / 2 }
        return belowStatusBar + size(compact: compact, grown: true).height / 2
    }
    func side(compact: Bool) -> CGFloat { compact ? 64 : min(136, (width - 16 - cutout) / 2) }
    func size(compact: Bool, grown: Bool) -> CGSize {
        if island {
            guard grown else { return CGSize(width: Self.islandWidth, height: Self.islandHeight) }
            // Taller than the island but still inside the status band (its bottom stays above `top`).
            let height = compact ? Self.islandHeight : min(46, 2 * (top - 3 - centerY(compact: compact)))
            return CGSize(width: cutout + 2 * side(compact: compact), height: height)
        }
        if docked {
            let room = width - Metrics.gutter - Self.headerControls
            return CGSize(width: compact ? min(150, room) : max(150, min(300, room)), height: compact ? 36 : 52)
        }
        return CGSize(width: compact ? 150 : min(width - 32, 360), height: compact ? 40 : 52)
    }
}
