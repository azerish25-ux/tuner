import SwiftUI
import TimbreCore

/// The end of a lesson: stars land one by one, XP counts up, then the next lesson is one tap away.
struct LessonResults: View {
    let course: LearnCourse
    let lesson: Lesson
    let result: LessonResult
    let improved: Bool
    /// What finishing the lesson earned (XP, level-up, badges, quests); nil if it could not be saved.
    let reward: ProgressUpdate?
    let accent: Color
    /// A rhythm was tapped instead of played (no microphone): the stars stop at one, and it says why.
    var practice = false
    let next: Lesson?
    let onContinue: () -> Void
    let onNext: (Lesson) -> Void
    @EnvironmentObject private var store: AppStore
    @State private var shownStars = 0
    @State private var xp = 0
    @State private var burst = 0
    @State private var appeared = false
    /// The level bar: fills from the XP before the lesson to after it, rolling over on a level-up.
    @State private var barLevel: Level?
    @State private var barValue = 0.0
    @State private var leveled = false
    @State private var badgesShown = 0
    @State private var offerReminder = !UserDefaults.standard.bool(forKey: PracticeReminder.askedKey) && !UserDefaults.standard.bool(forKey: PracticeReminder.enabledKey)
    /// A streak milestone (7, 30, 100 days) this lesson reached: its card is offered here, not in the app-wide overlay.
    @State private var milestone: Int?
    /// The share cards (three stars, a finished song, a milestone) come in after the stars and rewards.
    @State private var shareShown = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.requestReview) private var requestReview

    private static let gold = Color(hex: 0xF0A93B)

    /// "Flawless" only for a clean run (98 % or better); three stars from 90 % read "Great work".
    private var headline: LocalizedStringKey {
        if result.stars == 3 && result.accuracy >= 0.98 { return "Flawless" }
        return result.stars >= 2 ? "Great work" : "Lesson complete"
    }

    private var accuracyPercent: Int { Int((result.accuracy * 100).rounded()) }

    var body: some View {
        // The content scrolls inside its own frame: nothing slides under the buttons.
        VStack(spacing: 0) {
            ScrollView { content }.scrollBounceBehavior(.basedOnSize).scrollIndicators(.hidden)
                // Content that continues below the fold fades out instead of being cut at the buttons.
                .mask {
                    VStack(spacing: 0) {
                        Color.black
                        LinearGradient(colors: [.black, .clear], startPoint: .top, endPoint: .bottom).frame(height: 28)
                    }
                }
            buttons
        }
        .task { await reveal() }
    }

    private var content: some View {
        VStack(spacing: 24) {
            ZStack {
                SparkBurst(trigger: burst, color: Palette.amber).frame(width: 320, height: 320)
                HStack(alignment: .bottom, spacing: 14) {
                    ForEach(0..<3, id: \.self) { i in star(i) }
                }
            }
            .frame(height: 150)
            VStack(spacing: 8) {
                Text(headline).font(Typeface.display(36)).tracking(-0.8).foregroundStyle(Palette.ink)
                Text(lesson.title.localized).font(.headline).foregroundStyle(Palette.inkSoft)
                if practice { PracticeModeTag().padding(.top, 4) }
            }
            .opacity(appeared ? 1 : 0).offset(y: appeared ? 0 : 12)
            HStack(spacing: 12) {
                tile(symbol: "sparkles", tint: accent, value: Text("+\(xp)"), label: Text("XP"))
                tile(symbol: "scope", tint: Palette.amber, value: Text("\(accuracyPercent)%"), label: Text("accuracy"))
                tile(symbol: "flame.fill", tint: Palette.flame, value: Text("\(store.streak.current)"), label: Text("day streak"))
            }
            .padding(.horizontal, 20)
            .opacity(appeared ? 1 : 0)
            if improved && result.stars == 3 {
                Label("New best on this lesson", systemImage: "arrow.up.circle.fill").font(.subheadline.weight(.semibold)).foregroundStyle(accent)
            }
            if let barLevel { levelBar(barLevel).padding(.horizontal, 20).transition(.opacity) }
            if let reward, badgesShown > 0 { earned(reward) }
            if shareShown && hasShareCards { shareCards.transition(.move(edge: .bottom).combined(with: .opacity)) }
            if offerReminder && appeared { reminderCard.transition(.move(edge: .bottom).combined(with: .opacity)) }
        }
        .padding(.top, 26).padding(.bottom, 16)
    }

    /// StepButton carries its own 12 pt below; Done sits right under it.
    private var buttons: some View {
        VStack(spacing: 0) {
            if let next, store.canPlay(next) {
                StepButton(title: "Next lesson", accent: accent) { onNext(next) }
                    .accessibilityIdentifier("lesson.next")
            }
            if !LearnProgress.isReview(lesson.id) {
                PracticeWeakSpotsButton(course: course) { onNext($0) }.padding(.vertical, 4)
            }
            Button { onContinue() } label: {
                Text("Done").font(Typeface.label(17)).foregroundStyle(Palette.ink).frame(maxWidth: .infinity, minHeight: 52)
            }
            .accessibilityIdentifier("lesson.done")
            .padding(.horizontal, 20)
        }
        .padding(.top, 8).padding(.bottom, 8)
    }

    /// Level N and a bar that fills with this lesson's XP; on a level-up it fills, bursts and rolls over.
    private func levelBar(_ level: Level) -> some View {
        HStack(spacing: 12) {
            ZStack {
                Circle().fill(leveled ? AnyShapeStyle(Palette.proGold) : AnyShapeStyle(Palette.mint.opacity(0.16)))
                Text("\(level.number)").font(Typeface.label(17)).foregroundStyle(leveled ? Color(hex: 0x1B1206) : Palette.ink)
                    .contentTransition(.numericText())
            }
            .frame(width: 40, height: 40)
            .scaleEffect(leveled ? 1.12 : 1)
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("Level \(level.number)").font(Typeface.label(15)).foregroundStyle(leveled ? Self.gold : Palette.ink)
                    if leveled { Image(systemName: "arrow.up.circle.fill").font(.subheadline.weight(.bold)).foregroundStyle(Self.gold).transition(.scale.combined(with: .opacity)) }
                    Text(LocalizedStringKey(level.name)).font(.footnote).foregroundStyle(Palette.inkSoft).lineLimit(1)
                    Spacer(minLength: 0)
                }
                ProgressLine(value: barValue, color: leveled ? Self.gold : Palette.mint, height: 8)
            }
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(Palette.stageRaised))
        .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).strokeBorder(leveled ? Self.gold.opacity(0.6) : .clear, lineWidth: 1.5))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("Level \(level.number)"))
    }

    /// Badges and quests this lesson completed, popping in one by one.
    private func earned(_ reward: ProgressUpdate) -> some View {
        VStack(spacing: 8) {
            ForEach(Array(reward.achievementsEarned.enumerated()), id: \.element.id) { index, badge in
                if index < badgesShown {
                    rewardRow(symbol: badge.symbol, title: Text(LocalizedStringKey(badge.title)), detail: Text("Achievement unlocked"), gold: true)
                }
            }
            ForEach(Array(reward.questsCompleted.enumerated()), id: \.element.id) { index, quest in
                if reward.achievementsEarned.count + index < badgesShown {
                    rewardRow(symbol: "checkmark", title: Text(quest.title), detail: Text("Quest complete · +\(quest.xp) XP"), gold: false)
                }
            }
            // This lesson finished Today's set: its bonus lands here too (the toast would be hidden behind this screen).
            if reward.dailySetCompleted && reward.achievementsEarned.count + reward.questsCompleted.count < badgesShown {
                rewardRow(symbol: "sun.max.fill", title: Text("Daily set complete"), detail: Text("+\(XPReward.dailySet) XP"), gold: true)
            }
        }
        .padding(.horizontal, 20)
    }

    private func rewardRow(symbol: String, title: Text, detail: Text, gold: Bool) -> some View {
        HStack(spacing: 12) {
            Image(systemName: symbol).font(.system(size: 16, weight: .bold)).foregroundStyle(gold ? Color(hex: 0x1B1206) : Palette.onAccent)
                .frame(width: 36, height: 36)
                .background(Circle().fill(gold ? AnyShapeStyle(Palette.proGold) : AnyShapeStyle(Palette.mint)))
                .shadow(color: (gold ? Self.gold : Palette.mint).opacity(0.5), radius: 10)
            VStack(alignment: .leading, spacing: 1) {
                title.font(.subheadline.weight(.semibold)).foregroundStyle(Palette.ink)
                detail.font(.caption).foregroundStyle(Palette.inkSoft)
            }
            Spacer(minLength: 0)
        }
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Palette.stageRaised))
        .transition(.scale(scale: 0.6).combined(with: .opacity))
        .accessibilityElement(children: .combine)
    }

    // MARK: Share cards

    private var isSong: Bool { lesson.kind == .song }
    /// Three stars (not in practice mode) or any finished song.
    private var sharesResult: Bool { isSong || (result.stars == 3 && !practice) }
    private var hasShareCards: Bool { sharesResult || milestone != nil }

    /// A card for the moment, ready to share: the milestone, then the song or the three stars.
    private var shareCards: some View {
        VStack(spacing: 8) {
            if let milestone {
                ShareCardRow(title: Text("\(milestone)-day streak"), detail: StreakShareCard.titleText(milestone),
                             preview: "Practice streak", tint: Palette.flame) {
                    StreakShareCard(days: milestone)
                }
                .accessibilityIdentifier("lesson.share.streak")
            }
            if sharesResult { resultShare.accessibilityIdentifier("lesson.share") }
        }
        .padding(.horizontal, 20)
    }

    @ViewBuilder private var resultShare: some View {
        let courseTitle = course.title.localized
        let title = lesson.title.localized
        if isSong {
            ShareCardRow(title: Text(title), detail: Text("\(result.stars) of 3 stars"), preview: "Timbre", tint: accent) {
                LessonShareCard(course: courseTitle, title: title, headline: nil, stars: result.stars, accuracy: accuracyPercent, accent: accent, song: true)
            }
        } else {
            ShareCardRow(title: Text(headline), detail: Text(title), preview: headline, tint: accent) {
                LessonShareCard(course: courseTitle, title: title, headline: headline, stars: result.stars, accuracy: accuracyPercent, accent: accent, song: false)
            }
        }
    }

    /// After the first lesson: one tap to make practice a daily habit.
    private var reminderCard: some View {
        // The words get the card's full width (no orphan wraps); the button sits under them.
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "bell.badge.fill").font(.title3).foregroundStyle(accent)
                .frame(width: 44, height: 44).background(Circle().fill(accent.opacity(0.14)))
            VStack(alignment: .leading, spacing: 10) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Make it a habit").font(Typeface.label(15)).foregroundStyle(Palette.ink)
                        .fixedSize(horizontal: false, vertical: true)
                    Text("A reminder each evening at 7 pm.").font(.footnote).foregroundStyle(Palette.inkSoft)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Button("Remind me") {
                    UserDefaults.standard.set(true, forKey: PracticeReminder.askedKey)
                    Task { await PracticeReminder.enable(at: PracticeReminder.minutes); withAnimation { offerReminder = false } }
                }
                .font(Typeface.label(14)).foregroundStyle(Palette.onAccent).lineLimit(1).fixedSize()
                .padding(.horizontal, 16).frame(height: 36).background(Capsule().fill(accent))
                .accessibilityIdentifier("lesson.reminder")
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, 2)
            Button { UserDefaults.standard.set(true, forKey: PracticeReminder.askedKey); withAnimation { offerReminder = false } } label: {
                Image(systemName: "xmark").font(.footnote.weight(.bold)).foregroundStyle(Palette.inkFaint).frame(width: 32, height: 32)
                    .contentShape(Rectangle())
            }
            .accessibilityLabel("Not now")
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(Palette.stageRaised))
        .padding(.horizontal, 20)
    }

    private func star(_ i: Int) -> some View {
        let earned = i < result.stars
        let shown = i < shownStars
        let size: CGFloat = i == 1 ? 96 : 72
        return Image(systemName: "star.fill")
            .font(.system(size: size, weight: .bold))
            .foregroundStyle(earned && shown ? AnyShapeStyle(LinearGradient(colors: [Color(hex: 0xFFE29A), Color(hex: 0xF0A93B)], startPoint: .top, endPoint: .bottom)) : AnyShapeStyle(Color.white.opacity(0.08)))
            .shadow(color: earned && shown ? Color(hex: 0xF0A93B).opacity(0.6) : .clear, radius: 18)
            .scaleEffect(shown ? 1 : 0.3)
            .rotationEffect(.degrees(shown ? 0 : -40))
            .offset(y: i == 1 ? -14 : 0)
            .accessibilityHidden(true)
    }

    private func tile(symbol: String, tint: Color, value: Text, label: Text) -> some View {
        VStack(spacing: 4) {
            Image(systemName: symbol).font(.system(size: 15, weight: .semibold)).foregroundStyle(tint)
            value.font(Typeface.number(24)).foregroundStyle(Palette.ink).contentTransition(.numericText())
            label.font(.caption).foregroundStyle(Palette.inkSoft)
        }
        .frame(maxWidth: .infinity).padding(.vertical, 14)
        .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(Palette.stageRaised))
        .accessibilityElement(children: .combine)
    }

    private func reveal() async {
        // Claimed at once, so the app-wide milestone overlay doesn't also show it behind this screen.
        if milestone == nil { milestone = store.takeStreakMilestone() }
        withAnimation(.easeOut(duration: 0.5)) { appeared = true }
        for i in 0..<3 {
            try? await Task.sleep(for: .milliseconds(reduceMotion ? 80 : 380))
            withAnimation(.spring(response: 0.45, dampingFraction: 0.55)) { shownStars = i + 1 }
            if i < result.stars { SoundFX.shared.play(.star); Haptics.shared.lock(); burst += 1 }
        }
        // Ask for a rating right after a flawless lesson, a couple of times in the app's life.
        if result.stars == 3, [2, 10].contains(store.progress.stats["lessons"] ?? 0) {
            try? await Task.sleep(for: .seconds(1.5))
            requestReview()
        }
        let steps = 20
        for s in 1...steps {
            try? await Task.sleep(for: .milliseconds(30))
            withAnimation(.linear(duration: 0.03)) { xp = result.xp * s / steps }
        }
        await fillLevelBar()
        if let reward {
            for i in 0..<(reward.achievementsEarned.count + reward.questsCompleted.count + (reward.dailySetCompleted ? 1 : 0)) {
                try? await Task.sleep(for: .milliseconds(reduceMotion ? 60 : 320))
                withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) { badgesShown = i + 1 }
                if i < reward.achievementsEarned.count { SoundFX.shared.play(.star); Haptics.shared.lock() }
            }
        }
        guard hasShareCards else { return }
        try? await Task.sleep(for: .milliseconds(reduceMotion ? 60 : 280))
        withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) { shareShown = true }
        if milestone != nil { SoundFX.shared.play(.levelUp); Haptics.shared.done() }
    }

    private func fillLevelBar() async {
        guard let reward else { return }
        let after = store.progress.xp
        let before = max(0, after - reward.xpGained)
        let start = Progression.level(for: before)
        barValue = start.progress(before)
        withAnimation(.easeOut(duration: 0.3)) { barLevel = start }
        try? await Task.sleep(for: .milliseconds(250))
        if let next = reward.levelUp {
            withAnimation(.easeInOut(duration: 0.6)) { barValue = 1 }
            try? await Task.sleep(for: .milliseconds(650))
            SoundFX.shared.play(.levelUp); Haptics.shared.done(); burst += 1
            withAnimation(.spring(response: 0.45, dampingFraction: 0.55)) { barLevel = next; leveled = true; barValue = 0 }
            try? await Task.sleep(for: .milliseconds(200))
            withAnimation(.easeOut(duration: 0.5)) { barValue = next.progress(after) }
        } else {
            withAnimation(.easeOut(duration: 0.7)) { barValue = start.progress(after) }
            try? await Task.sleep(for: .milliseconds(700))
        }
    }
}
