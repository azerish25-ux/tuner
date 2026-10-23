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
            }
            .padding(.horizontal, 12).frame(height: 36)
            .background(Capsule().fill(Palette.flame.opacity(0.10)))
            .overlay(Capsule().strokeBorder(Palette.flame.opacity(0.35), lineWidth: 1))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text("\(streak.current)-day streak"))
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
            VStack(alignment: .leading, spacing: 6) {
                Text(quest.title).font(.subheadline.weight(.semibold)).foregroundStyle(done ? Palette.inkSoft : Palette.ink)
                    .strikethrough(done, color: Palette.inkFaint)
                ProgressLine(value: Double(progress) / Double(quest.target), color: done ? Palette.mint : quest.tint, height: 4)
            }
            Text(done ? "Done" : "+\(quest.xp) XP").font(Typeface.label(12)).foregroundStyle(Palette.mint)
        }
        .padding(.horizontal, 14).padding(.vertical, 12)
        .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Palette.stageRaised))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(.white.opacity(0.06), lineWidth: 1))
        .accessibilityElement(children: .combine)
        .accessibilityValue(Text(done ? "Done" : "\(progress) of \(quest.target)"))
    }
}

/// Round medal: coloured when earned, a dashed lock when not.
struct AchievementMedal: View {
    let achievement: Achievement
    let earned: Bool
    var size: CGFloat = 56
    var body: some View {
        ZStack {
            if earned {
                Circle().fill(RadialGradient(colors: [Color(hex: 0x8BF7D2), Palette.mintDeep], center: UnitPoint(x: 0.35, y: 0.3), startRadius: 0, endRadius: size * 0.7))
                    .shadow(color: Palette.mint.opacity(0.35), radius: 12)
                Image(systemName: achievement.symbol).font(.system(size: size * 0.36, weight: .bold)).foregroundStyle(Palette.onAccent)
            } else {
                Circle().strokeBorder(.white.opacity(0.2), style: StrokeStyle(lineWidth: 1.5, dash: [4, 4]))
                Image(systemName: "lock.fill").font(.system(size: size * 0.26)).foregroundStyle(Palette.inkFaint)
            }
        }
        .frame(width: size, height: size)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(LocalizedStringKey(achievement.title)))
        .accessibilityValue(Text(earned ? "Earned" : LocalizedStringKey(achievement.detail)))
    }
}

/// XP, quest, badge and level-up announcements: a pill that rises from the top and fades.
struct RewardToast: View {
    @EnvironmentObject private var store: AppStore
    @State private var shown: ProgressUpdate?
    @State private var token = 0
    var body: some View {
        VStack(spacing: 8) {
            if let shown {
                if let level = shown.levelUp {
                    banner(symbol: "star.fill", title: Text("Level \(level.number)"), detail: Text(LocalizedStringKey(level.name)), gold: true)
                }
                ForEach(shown.achievementsEarned) { a in
                    banner(symbol: a.symbol, title: Text(LocalizedStringKey(a.title)), detail: Text("Achievement unlocked"), gold: true)
                }
                ForEach(shown.questsCompleted) { q in
                    banner(symbol: "checkmark", title: Text(q.title), detail: Text("Quest complete · +\(q.xp) XP"), gold: false)
                }
                if shown.levelUp == nil && shown.achievementsEarned.isEmpty && shown.questsCompleted.isEmpty && shown.xpGained > 0 {
                    Text("+\(shown.xpGained) XP").font(Typeface.label(13)).foregroundStyle(Palette.onAccent)
                        .padding(.horizontal, 12).padding(.vertical, 6)
                        .background(Capsule().fill(Palette.mint))
                        .shadow(color: Palette.mint.opacity(0.5), radius: 12)
                }
            }
        }
        .padding(.top, 6)
        .transition(.move(edge: .top).combined(with: .opacity))
        .allowsHitTesting(false)
        .onChange(of: store.rewardPulse) { _, _ in
            guard let reward = store.lastReward else { return }
            token += 1
            let mine = token
            withAnimation(Motion.pluck) { shown = reward }
            let long = reward.levelUp != nil || !reward.achievementsEarned.isEmpty || !reward.questsCompleted.isEmpty
            Task { @MainActor in
                try? await Task.sleep(for: .seconds(long ? 2.6 : 1.2))
                if mine == token { withAnimation(.easeOut(duration: 0.3)) { shown = nil } }
            }
        }
        .accessibilityElement(children: .combine)
    }

    private func banner(symbol: String, title: Text, detail: Text, gold: Bool) -> some View {
        HStack(spacing: 10) {
            Image(systemName: symbol).font(.system(size: 15, weight: .bold)).foregroundStyle(gold ? Color(hex: 0x1B1206) : Palette.onAccent)
                .frame(width: 32, height: 32)
                .background(Circle().fill(gold ? AnyShapeStyle(Palette.proGold) : AnyShapeStyle(Palette.mint)))
            VStack(alignment: .leading, spacing: 1) {
                title.font(.subheadline.weight(.semibold)).foregroundStyle(Palette.ink)
                detail.font(.caption).foregroundStyle(Palette.inkSoft)
            }
            Spacer(minLength: 0)
        }
        .padding(10)
        .frame(maxWidth: 340)
        .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Palette.surface))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(.white.opacity(0.1), lineWidth: 1))
        .shadow(color: .black.opacity(0.5), radius: 20, y: 8)
    }
}
