import SwiftUI
import TimbreCore

/// The end of a lesson: stars land one by one, XP counts up, then the next lesson is one tap away. Two stars or
/// more (or a finished song) put a Share pill for its poster under the tiles from the first frame; a streak
/// milestone takes the screen with its own celebration, and its card waits below.
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
    /// The reminder was just switched on here: the row stays, showing the time it is set for.
    @State private var reminderOn = false
    @State private var askingReminder = false
    /// A streak milestone (3, 7, 30, 100 days) this lesson reached: celebrated full screen and its card offered here,
    /// not in the app-wide overlay.
    @State private var milestone: Int?
    /// The milestone's share card comes in after the stars, the rewards and its celebration.
    @State private var shareShown = false
    /// The milestone's full-screen celebration, over the results until Continue.
    @State private var celebrating: Int?
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
        .overlay {
            if let days = celebrating {
                StreakCelebration(days: days) { withAnimation(.easeOut(duration: 0.3)) { celebrating = nil } }
                    .transition(.opacity)
            }
        }
    }

    /// Stars, headline, the reminder row (until asked once), the tiles, "New best" and Share, the level bar, rewards,
    /// then the milestone's card: on a phone everything down to the level bar fits above the pinned buttons.
    private var content: some View {
        VStack(spacing: 16) {
            ZStack {
                SparkBurst(trigger: burst, color: Palette.amber).frame(width: 320, height: 320)
                HStack(alignment: .bottom, spacing: 14) {
                    ForEach(0..<3, id: \.self) { i in star(i) }
                }
            }
            .frame(height: 136)
            VStack(spacing: 8) {
                Text(headline).font(Typeface.display(36)).tracking(-0.8).foregroundStyle(Palette.ink)
                Text(lesson.title.localized).font(.headline).foregroundStyle(Palette.inkSoft)
                if practice { PracticeModeTag().padding(.top, 4) }
            }
            .opacity(appeared ? 1 : 0).offset(y: appeared ? 0 : 12)
            if offerReminder {
                reminderRow
                    .opacity(appeared ? 1 : 0)
                    .transition(.scale(scale: 0.95).combined(with: .opacity))
            }
            HStack(spacing: 12) {
                tile(symbol: "sparkles", tint: accent, value: Text("+\(xp)"), label: Text("XP"))
                tile(symbol: "scope", tint: Palette.amber, value: Text("\(accuracyPercent)%"), label: Text("accuracy"))
                tile(symbol: "flame.fill", tint: Palette.flame, value: Text("\(store.streak.current)"), label: Text("day streak"))
            }
            .padding(.horizontal, 20)
            .opacity(appeared ? 1 : 0)
            if newBest || sharesResult { bestAndShare }
            if let barLevel { levelBar(barLevel).padding(.horizontal, 20).transition(.opacity) }
            if let reward, badgesShown > 0 { earned(reward) }
            if shareShown && hasShareCards { shareCards.transition(.move(edge: .bottom).combined(with: .opacity)) }
        }
        .padding(.top, 8).padding(.bottom, 16)
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

    // MARK: Share

    private var isSong: Bool { lesson.kind == .song }
    private var newBest: Bool { improved && result.stars == 3 }
    /// Two or three stars (not in practice mode) or any finished song.
    private var sharesResult: Bool { isSong || (result.stars >= 2 && !practice) }
    /// Only the milestone's card waits below; the result's poster is the Share pill up top.
    private var hasShareCards: Bool { milestone != nil }

    /// "New best" with Share right under it, in the first frame: the poster renders as the screen opens, so the
    /// pill is live before the stars have finished landing.
    private var bestAndShare: some View {
        VStack(spacing: 10) {
            if newBest {
                Label("New best on this lesson", systemImage: "arrow.up.circle.fill").font(.subheadline.weight(.semibold)).foregroundStyle(accent)
            }
            if sharesResult { resultShare.accessibilityIdentifier("lesson.share") }
        }
        .opacity(appeared ? 1 : 0)
    }

    /// The milestone's card, once its celebration has been seen.
    private var shareCards: some View {
        VStack(spacing: 8) {
            if let milestone {
                ShareCardRow(title: Text("\(milestone)-day streak"), detail: StreakShareCard.titleText(milestone),
                             preview: "Practice streak", tint: Palette.flame) {
                    StreakShareCard(days: milestone)
                }
                .accessibilityIdentifier("lesson.share.streak")
            }
        }
        .padding(.horizontal, 20)
    }

    /// The song's poster (its title leads) or the lesson's (the headline leads).
    @ViewBuilder private var resultShare: some View {
        let courseTitle = course.title.localized
        let title = lesson.title.localized
        if isSong {
            SharePill(preview: "Timbre", tint: accent) {
                LessonShareCard(course: courseTitle, title: title, headline: nil, stars: result.stars, accuracy: accuracyPercent, accent: accent, song: true,
                                streak: store.streak.current)
            }
        } else {
            SharePill(preview: headline, tint: accent) {
                LessonShareCard(course: courseTitle, title: title, headline: headline, stars: result.stars, accuracy: accuracyPercent, accent: accent, song: false,
                                streak: store.streak.current)
            }
        }
    }

    // MARK: Reminder

    /// Until the reminder has been offered once: one row, above the tiles and clear of the pinned buttons, with
    /// the time inline ("Remind me · 7 PM", the plan's time). Where the words don't fit beside the pill (long
    /// languages, large type) the pill moves under them. On, it stays as a confirmation; × asks no more.
    private var reminderRow: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 8) {
                reminderIcon
                reminderTitle.lineLimit(1)
                Spacer(minLength: 4)
                reminderPill
                reminderClose
            }
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 8) {
                    reminderIcon
                    reminderTitle.fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 4)
                    reminderClose
                }
                reminderPill
            }
        }
        .padding(.leading, 10).padding(.trailing, reminderOn ? 10 : 4).padding(.vertical, 8)
        .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(Palette.stageRaised))
        .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).strokeBorder(accent.opacity(0.22), lineWidth: 1))
        .padding(.horizontal, 20)
    }

    private var reminderIcon: some View {
        Image(systemName: reminderOn ? "bell.badge.fill" : "bell.fill")
            .font(.system(size: 14, weight: .semibold)).foregroundStyle(accent)
            .frame(width: 30, height: 30).background(Circle().fill(accent.opacity(0.14)))
            .contentTransition(.symbolEffect(.replace))
            .accessibilityHidden(true)
    }

    private var reminderTitle: Text {
        Text(reminderOn ? LocalizedStringKey("Daily practice reminder") : LocalizedStringKey("Make it a habit"))
            .font(Typeface.label(14))
            .foregroundStyle(Palette.ink)
    }

    @ViewBuilder private var reminderClose: some View {
        if !reminderOn {
            Button {
                UserDefaults.standard.set(true, forKey: PracticeReminder.askedKey)
                withAnimation(Motion.settle) { offerReminder = false }
            } label: {
                Image(systemName: "xmark").font(.footnote.weight(.bold)).foregroundStyle(Palette.inkFaint)
                    .frame(width: 28, height: 36).contentShape(Rectangle())
            }
            .accessibilityLabel("Not now")
        }
    }

    /// "Remind me · 7 PM" in the accent; once on, "✓ 7 PM" in an outline.
    private var reminderPill: some View {
        let time = Self.reminderTime
        return Button(action: enableReminder) {
            HStack(spacing: 5) {
                if askingReminder {
                    ProgressView().controlSize(.mini).tint(Palette.onAccent)
                } else if reminderOn {
                    Image(systemName: "checkmark").font(.system(size: 11, weight: .heavy)).transition(.scale.combined(with: .opacity))
                } else {
                    Text("Remind me")
                    Text(verbatim: "·").opacity(0.6)
                }
                Text(time, format: Self.timeFormat)
            }
            .font(Typeface.label(13)).lineLimit(1)
            .foregroundStyle(reminderOn ? accent : Palette.onAccent)
            .padding(.horizontal, 12).frame(minHeight: 36)
            .background(Capsule().fill(reminderOn ? AnyShapeStyle(accent.opacity(0.12)) : AnyShapeStyle(accent)))
            .overlay(Capsule().strokeBorder(accent.opacity(reminderOn ? 0.45 : 0), lineWidth: 1))
            .fixedSize()
            .contentShape(Capsule())
        }
        .buttonStyle(PressScaleStyle())
        .disabled(askingReminder || reminderOn)
        .animation(Motion.quick, value: reminderOn)
        .accessibilityLabel(Text("Remind me") + Text(verbatim: ", ") + Text(time, format: Self.timeFormat))
        .accessibilityAddTraits(reminderOn ? .isSelected : [])
        .accessibilityIdentifier("lesson.reminder")
    }

    /// Today at the reminder's time: the one chosen on the plan or in Settings, 7 pm by default.
    private static var reminderTime: Date {
        let minutes = PracticeReminder.minutes
        return Calendar.current.date(bySettingHour: minutes / 60, minute: minutes % 60, second: 0, of: Date()) ?? Date()
    }

    /// "7 PM" on the hour, "7:30 PM" otherwise (24-hour where the locale uses it).
    private static var timeFormat: Date.FormatStyle {
        let hour = Date.FormatStyle.dateTime.hour()
        return PracticeReminder.minutes % 60 == 0 ? hour : hour.minute()
    }

    /// Asks for notifications (once) and plans the reminders through `PracticeReminder`; a refusal hides the row.
    private func enableReminder() {
        Haptics.shared.selection()
        UserDefaults.standard.set(true, forKey: PracticeReminder.askedKey)
        askingReminder = true
        Task { @MainActor in
            let on = await PracticeReminder.enable(at: PracticeReminder.minutes)
            askingReminder = false
            if on {
                Haptics.shared.lock()
                withAnimation(Motion.pluck) { reminderOn = true }
            } else {
                withAnimation(Motion.settle) { offerReminder = false }
            }
        }
    }

    private func star(_ i: Int) -> some View {
        let earned = i < result.stars
        let shown = i < shownStars
        let size: CGFloat = i == 1 ? 90 : 68
        return Image(systemName: "star.fill")
            .font(.system(size: size, weight: .bold))
            .foregroundStyle(earned && shown ? AnyShapeStyle(LinearGradient(colors: [Color(hex: 0xFFE29A), Color(hex: 0xF0A93B)], startPoint: .top, endPoint: .bottom)) : AnyShapeStyle(Color.white.opacity(0.08)))
            .shadow(color: earned && shown ? Color(hex: 0xF0A93B).opacity(0.6) : .clear, radius: 18)
            .scaleEffect(shown ? 1 : 0.3)
            .rotationEffect(.degrees(shown ? 0 : -40))
            .offset(y: i == 1 ? -12 : 0)
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
        // A streak milestone takes the whole screen once the results have landed; its share card waits below.
        if let milestone {
            try? await Task.sleep(for: .milliseconds(reduceMotion ? 100 : 600))
            withAnimation(.easeOut(duration: 0.35)) { celebrating = milestone }
        }
        guard hasShareCards else { return }
        try? await Task.sleep(for: .milliseconds(reduceMotion ? 60 : 280))
        withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) { shareShown = true }
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

/// "Share" as a pill in the accent: a small tilted copy of the poster beside the word, so it says what it shares.
/// The poster renders as the pill appears (no wait for the rest of the screen); until then the pill rests dimmed.
/// Used on the lesson results and on a play-along take of 90 % or more.
struct SharePill<Card: View>: View {
    let preview: LocalizedStringKey
    let tint: Color
    let card: Card
    @State private var image: Image?
    @Environment(\.displayScale) private var displayScale
    @Environment(\.locale) private var locale
    @Environment(\.layoutDirection) private var layoutDirection

    init(preview: LocalizedStringKey, tint: Color = Palette.mint, @ViewBuilder card: () -> Card) {
        self.preview = preview
        self.tint = tint
        self.card = card()
    }

    var body: some View {
        Group {
            if let image {
                ShareLink(item: image, preview: SharePreview(preview, image: image)) { face(image) }
                    .buttonStyle(PressScaleStyle())
            } else {
                face(nil).opacity(0.55)
            }
        }
        .task {
            if image == nil { image = ShareCardRenderer.image(card, scale: displayScale, locale: locale, direction: layoutDirection) }
        }
    }

    private func face(_ poster: Image?) -> some View {
        HStack(spacing: 8) {
            thumbnail(poster)
            Image(systemName: "square.and.arrow.up").font(.system(size: 13, weight: .bold)).accessibilityHidden(true)
            Text("Share")
        }
        .font(Typeface.label(14))
        .foregroundStyle(tint)
        .padding(.leading, 9).padding(.trailing, 16)
        .frame(minHeight: 40)
        .background(Capsule().fill(tint.opacity(0.14)))
        .overlay(Capsule().strokeBorder(tint.opacity(0.4), lineWidth: 1))
        .fixedSize()
        .contentShape(Capsule())
    }

    private func thumbnail(_ poster: Image?) -> some View {
        let shape = RoundedRectangle(cornerRadius: 4, style: .continuous)
        return ZStack {
            if let poster { poster.resizable().scaledToFill() } else { Palette.surface }
        }
        .frame(width: 20, height: 27)
        .clipShape(shape)
        .overlay(shape.strokeBorder(.white.opacity(0.18), lineWidth: 0.5))
        .rotationEffect(.degrees(-8))
        .shadow(color: .black.opacity(0.45), radius: 3, y: 2)
        .accessibilityHidden(true)
    }
}
