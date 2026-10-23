import SwiftUI
import TimbreCore

/// Flame and day count; taps through to Progress.
struct StreakChip: View {
    @EnvironmentObject private var store: AppStore
    var action: () -> Void = {}
    var body: some View {
        let streak = store.streak
        Button(action: action) {
            HStack(spacing: 5) {
                Image(systemName: "flame.fill").font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(streak.practicedToday ? Palette.flame : Palette.inkFaint)
                    .symbolEffect(.bounce, value: streak.current)
                Text("\(streak.current)").font(Typeface.label(14)).foregroundStyle(Color(hex: 0xFFD3A8)).monospacedDigit()
                if store.streakFreezes > 0 {
                    // Banked streak freezes, one flake each.
                    HStack(spacing: 1) {
                        ForEach(0..<store.streakFreezes, id: \.self) { _ in
                            Image(systemName: "snowflake").font(.system(size: 10, weight: .bold)).foregroundStyle(Color(hex: 0x9FD8FF))
                                .symbolEffect(.bounce, value: store.streakPulse)
                        }
                    }
                    .transition(.scale.combined(with: .opacity))
                }
            }
            .padding(.horizontal, 12).frame(height: 36)
            .background(Capsule().fill(Palette.flame.opacity(0.10)))
            .overlay(Capsule().strokeBorder(Palette.flame.opacity(0.35), lineWidth: 1))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text("\(streak.current)-day streak"))
        .accessibilityValue(store.streakFreezes > 0 ? Text("\(store.streakFreezes) streak freezes") : Text(""))
        .accessibilityIdentifier("streak.chip")
    }
}

/// Level number inside a ring that fills with XP toward the next level.
struct LevelRing: View {
    @EnvironmentObject private var store: AppStore
    var size: CGFloat = 36
    var action: (() -> Void)?
    var body: some View {
        let xp = store.progress.xp
        let level = store.level
        let ring = ZStack {
            Circle().stroke(.white.opacity(0.12), lineWidth: size * 0.09)
            Circle().trim(from: 0, to: max(0.02, level.progress(xp)))
                .stroke(Palette.mint, style: StrokeStyle(lineWidth: size * 0.09, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(Motion.settle, value: xp)
            Text("\(level.number)").font(Typeface.label(size * 0.37)).foregroundStyle(Palette.ink)
                .contentTransition(.numericText())
        }
        .frame(width: size, height: size)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("Level \(level.number), \(xp - level.floor) of \(level.next - level.floor) XP"))
        if let action {
            Button(action: action) { ring }.buttonStyle(.plain).accessibilityIdentifier("level.ring")
        } else { ring }
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

/// One daily quest: icon, title, a bar with its count ("3 / 10") and the XP it pays.
struct QuestRow: View {
    @EnvironmentObject private var store: AppStore
    let quest: Quest
    var body: some View {
        let progress = store.questProgress(quest)
        let done = progress >= quest.target
        HStack(spacing: 12) {
            Image(systemName: done ? "checkmark" : quest.symbol).font(.system(size: 15, weight: .semibold))
                .foregroundStyle(done ? Palette.onAccent : quest.tint)
                .frame(width: 34, height: 34)
                .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(done ? AnyShapeStyle(Palette.mint) : AnyShapeStyle(quest.tint.opacity(0.14))))
            VStack(alignment: .leading, spacing: 7) {
                Text(quest.title).font(.subheadline.weight(.semibold)).foregroundStyle(done ? Palette.inkSoft : Palette.ink)
                    .strikethrough(done, color: Palette.inkFaint)
                    .fixedSize(horizontal: false, vertical: true)
                HStack(spacing: 10) {
                    ProgressLine(value: Double(progress) / Double(max(1, quest.target)), color: done ? Palette.mint : quest.tint, height: 5)
                    Text("\(progress) / \(quest.target)").font(Typeface.number(12)).foregroundStyle(done ? Palette.mint : Palette.inkSoft)
                        .contentTransition(.numericText())
                        .fixedSize()
                }
            }
            reward(done)
        }
        .padding(.horizontal, 14).padding(.vertical, 12)
        .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Palette.stageRaised))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(.white.opacity(0.06), lineWidth: 1))
        .accessibilityElement(children: .combine)
        .accessibilityValue(Text(done ? "Done" : "\(progress) of \(quest.target)"))
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

/// Round medal: coloured when earned; a dashed lock when not, ringed with the progress toward its goal.
struct AchievementMedal: View {
    let achievement: Achievement
    let earned: Bool
    var size: CGFloat = 56
    /// 0…1 toward the goal for a locked medal; nil (or 0) draws no ring.
    var progress: Double? = nil
    var body: some View {
        ZStack {
            if earned {
                Circle().fill(RadialGradient(colors: [Color(hex: 0x8BF7D2), Palette.mintDeep], center: UnitPoint(x: 0.35, y: 0.3), startRadius: 0, endRadius: size * 0.7))
                    .shadow(color: Palette.mint.opacity(0.35), radius: 12)
                Image(systemName: achievement.symbol).font(.system(size: size * 0.36, weight: .bold)).foregroundStyle(Palette.onAccent)
            } else {
                Circle().strokeBorder(.white.opacity(0.2), style: StrokeStyle(lineWidth: 1.5, dash: [4, 4]))
                if let progress, progress > 0 {
                    Circle().inset(by: 1.5).trim(from: 0, to: CGFloat(min(1, max(0.03, progress))))
                        .stroke(Palette.mint, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                        .shadow(color: Palette.mint.opacity(0.45), radius: 4)
                }
                Image(systemName: "lock.fill").font(.system(size: size * 0.26)).foregroundStyle(Palette.inkFaint)
            }
        }
        .frame(width: size, height: size)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(LocalizedStringKey(achievement.title)))
        .accessibilityValue(Text(earned ? "Earned" : LocalizedStringKey(achievement.detail)))
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

/// XP, quest, badge, level-up and streak announcements: a black pill that grows out of the Dynamic Island,
/// one banner at a time from a queue. It stays inside the status-bar band, so it never covers a screen's
/// header; without a Dynamic Island it drops in just below the status bar. Reduce Motion fades it in place.
/// It never takes taps; VoiceOver hears each banner as an announcement.
struct RewardToast: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var queue: [RewardBanner] = []
    @State private var current: RewardBanner?
    @State private var open = false
    @State private var presenting = false

    var body: some View {
        GeometryReader { proxy in
            let layout = PillLayout(width: proxy.size.width, top: proxy.safeAreaInsets.top)
            if let current {
                pill(current, layout: layout)
                    .position(x: proxy.size.width / 2, y: layout.centerY)
            }
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .onChange(of: store.rewardPulse) { _, _ in
            if let reward = store.lastReward { enqueue(Self.banners(for: reward)) }
        }
        .onChange(of: store.streakPulse) { _, _ in
            if let notice = store.streakNotice { enqueue([Self.banner(for: notice)]) }
        }
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
            withAnimation(reduceMotion ? .easeOut(duration: 0.2) : Motion.island) { open = true }
            try? await Task.sleep(for: .seconds(queue.count > 1 ? next.seconds * 0.8 : next.seconds))
            withAnimation(reduceMotion ? .easeIn(duration: 0.2) : .spring(response: 0.34, dampingFraction: 1)) { open = false }
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
        for a in reward.achievementsEarned {
            list.append(RewardBanner(symbol: a.symbol, title: Text(LocalizedStringKey(a.title)), detail: Text("Achievement unlocked"), tone: .gold, seconds: 2.6,
                                     announcement: NSLocalizedString(a.title, comment: "") + ", " + String(localized: "Achievement unlocked", bundle: TimbreLocalization.bundle)))
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
                .animation(.easeOut(duration: 0.2).delay(open && !reduceMotion ? 0.1 : 0), value: open)
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
            HStack(spacing: 10) {
                icon(banner, size: compact ? 24 : 30)
                words(banner)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 9)
            .frame(width: layout.size(compact: compact, grown: true).width)
        }
    }

    private func words(_ banner: RewardBanner) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            banner.title.font(Typeface.label(13))
                .foregroundStyle(banner.detail == nil ? Palette.mint : Palette.ink)
                .lineLimit(1).minimumScaleFactor(0.7)
            if let detail = banner.detail {
                detail.font(.system(size: 11)).foregroundStyle(Palette.inkSoft)
                    .lineLimit(2).minimumScaleFactor(0.8)
            }
        }
    }

    private func icon(_ banner: RewardBanner, size: CGFloat) -> some View {
        Image(systemName: banner.symbol).font(.system(size: size * 0.46, weight: .bold))
            .foregroundStyle(banner.tone == .mint ? Palette.onAccent : Color(hex: 0x1B1206))
            .frame(width: size, height: size)
            .background(Circle().fill(Self.fill(banner.tone)))
            .symbolEffect(.bounce, value: open)
    }

    private static func fill(_ tone: RewardBanner.Tone) -> AnyShapeStyle {
        switch tone {
        case .gold: return AnyShapeStyle(Palette.proGold)
        case .mint: return AnyShapeStyle(Palette.mint)
        case .frost: return AnyShapeStyle(Color(hex: 0x9FD8FF))
        }
    }
}

/// Where the reward pill sits. Phones with a Dynamic Island have a status band of 54 pt or more, with the
/// island (about 126 × 37 pt) near its top; the pill grows from the island and stays inside the band.
private struct PillLayout {
    let width: CGFloat
    let top: CGFloat
    static let islandWidth: CGFloat = 126
    static let islandHeight: CGFloat = 37
    var island: Bool { top >= 51 && width < 500 }
    /// The island's top edge: about 11 pt below the screen top on a 59 pt band, 14 pt on a 62 pt band.
    var islandTop: CGFloat { max(10, min(14, top - 48)) }
    /// The camera cutout plus a little air.
    var cutout: CGFloat { Self.islandWidth + 6 }
    var centerY: CGFloat { island ? islandTop + Self.islandHeight / 2 : top + 6 + 24 }
    func side(compact: Bool) -> CGFloat { compact ? 64 : min(136, (width - 16 - cutout) / 2) }
    func size(compact: Bool, grown: Bool) -> CGSize {
        if island {
            guard grown else { return CGSize(width: Self.islandWidth, height: Self.islandHeight) }
            // Taller than the island but still inside the status band (its bottom stays above `top`).
            let height = compact ? Self.islandHeight : min(46, 2 * (top - 3 - centerY))
            return CGSize(width: cutout + 2 * side(compact: compact), height: height)
        }
        return CGSize(width: compact ? 150 : min(width - 32, 360), height: compact ? 40 : 52)
    }
}
