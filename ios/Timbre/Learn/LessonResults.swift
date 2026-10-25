import SwiftUI
import TimbreCore

/// The results' own coordinate space, where the stars report their centre for the burst behind them.
private let resultsSpace = NamedCoordinateSpace.named("lesson.results")

/// The end of a lesson: stars land one by one, XP counts up, then the next lesson is one tap away. Under the tiles
/// the coach says one specific thing about this take (a late chord change, what slipped, the tempo to beat) with
/// its one action. Two stars or more (or a finished song) put a Share pill for its poster under the tiles from the
/// first frame; a streak milestone takes the screen with its own celebration, and its card waits below.
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
    /// When each earned star landed, for its heat glow (`StarHeat`).
    @State private var landed: [Int: Date] = [:]
    /// The result's poster renders once the reveal has settled (after the level bar), never under the stars' landing.
    @State private var shareReady = false
    @State private var xp = 0
    @State private var burst = 0
    /// The stars' centre in the results' coordinate space (`resultsSpace`), where the burst is drawn.
    @State private var starsCenter: CGPoint?
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
    /// The coach's note on this lesson (`Coach.lessonNotes`), worked out as the screen opens; nil: nothing specific.
    @State private var coach: CoachNote?
    @State private var coachDecided = false
    /// It slides in once the stars have landed.
    @State private var coachShown = false
    /// The content runs on below the scroll view's foot: the fade over it shows.
    @State private var moreBelow = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var typeSize
    @Environment(\.requestReview) private var requestReview

    /// The headline leads with what happened, as a teacher would say it: "6 of 6, clean" when the coach counted a
    /// clean run, "Nothing slipped" for any other flawless one (`Coach.isFlawless`, 98 % or better), "92% landed" for
    /// two or three stars, else "Lesson complete". The stars never outrank the lesson's final play-along
    /// (`LessonRun.starCap(finalTake:)`) and the coach goes by the same rules, so the headline never praises a take
    /// the coach then sends you to fix.
    private var headline: LocalizedStringKey {
        if practice { return "Lesson complete" }
        if case .clean(let items)? = shownCoach?.fact, items > 1, Coach.isFlawless(result) { return "\(items) of \(items), clean" }
        if Coach.isFlawless(result) { return "Nothing slipped" }
        return result.stars >= 2 ? "\(accuracyPercent)% landed" : "Lesson complete"
    }

    /// The key of the lesson's music: its stars ring that key's triad.
    private var rewardKey: RewardKey? { RewardKey.of(lesson) }

    private var accuracyPercent: Int { Int((result.accuracy * 100).rounded()) }

    var body: some View {
        // The content scrolls inside its own frame: nothing slides under the buttons.
        VStack(spacing: 0) {
            ScrollView { content }.scrollBounceBehavior(.basedOnSize).scrollIndicators(.hidden)
                // Content that continues below the fold fades out instead of being cut at the buttons. Only then: a
                // screen that ends above them keeps its last row whole, not dimmed for nothing.
                .onScrollGeometryChange(for: Bool.self) { geometry in
                    geometry.contentSize.height - Self.contentFoot - geometry.visibleRect.maxY > 1
                } action: { _, more in
                    moreBelow = more
                }
                .mask { foldFade }
            buttons
        }
        .coordinateSpace(resultsSpace)
        // Behind the content, as it was behind the stars: drawn here rather than in the scroll view, which would
        // clip the rings flat where they cross its top edge.
        .background(alignment: .topLeading) { burstLayer }
        .task { await reveal() }
        .overlay {
            if let days = celebrating {
                StreakCelebration(days: days) { withAnimation(Motion.fade) { celebrating = nil } }
                    .transition(.opacity)
            }
        }
    }

    /// The fade over the bottom of the scroll view, while there is more below.
    private var foldFade: some View {
        VStack(spacing: 0) {
            Color.black
            LinearGradient(colors: [.black, moreBelow ? .clear : .black], startPoint: .top, endPoint: .bottom).frame(height: 28)
        }
        .animation(Motion.fade, value: moreBelow)
    }

    /// The space under the content, inside the scroll view (not counted as "more below").
    private static let contentFoot: CGFloat = 16

    /// Stars, headline, the reminder row (until asked once, one line), the tiles, the coach, "New best" beside Share,
    /// the level bar, rewards two to a row, then the milestone's card. On a 6.1-inch phone everything down to the level
    /// bar, and a row of rewards, fits above the pinned buttons (Done beside Next lesson) with the reminder row showing,
    /// so the fade never sits on them.
    private var content: some View {
        VStack(spacing: 12) {
            HStack(alignment: .bottom, spacing: 14) {
                ForEach(0..<3, id: \.self) { i in star(i) }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 136)
            // The stars are read as one fact: "2 of 3 stars".
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text("\(result.stars) of 3 stars"))
            // Where the burst behind them is drawn (outside the scroll view, so its ring is never cut).
            .onGeometryChange(for: CGPoint.self) { proxy in
                let frame = proxy.frame(in: resultsSpace)
                return CGPoint(x: frame.midX, y: frame.midY)
            } action: { center in
                starsCenter = center
            }
            VStack(spacing: 8) {
                Text(headline).font(Typeface.display(.display)).tracking(-0.8).foregroundStyle(Palette.ink)
                    .multilineTextAlignment(.center)
                    .accessibilityAddTraits(.isHeader)
                Text(lesson.title.localized).font(.headline).foregroundStyle(Palette.inkSoft)
                if practice { PracticeModeTag().padding(.top, 4) }
            }
            .opacity(appeared ? 1 : 0).offset(y: appeared ? 0 : 12)
            if offerReminder {
                reminderRow
                    .opacity(appeared ? 1 : 0)
                    .transition(.scale(scale: 0.95).combined(with: .opacity))
            }
            // Side by side; one per row at the accessibility sizes, so "day streak" never truncates.
            StatTileRow(spacing: 12) {
                StatTile(symbol: "sparkles", tint: accent, value: Text("+\(xp)"), label: Text("XP"), alignment: .center)
                StatTile(symbol: "target", tint: Palette.amber, value: Text("\(accuracyPercent)%"), label: Text("accuracy"), alignment: .center)
                StatTile(symbol: "flame.fill", tint: Palette.flame, value: Text("\(store.streak.current)"), label: Text("day streak"), alignment: .center)
            }
            .padding(.horizontal, Metrics.gutter)
            .opacity(appeared ? 1 : 0)
            if let coach = shownCoach {
                coachCard(coach)
                    .opacity(coachShown ? 1 : 0)
                    .offset(y: coachShown || reduceMotion ? 0 : 14)
            }
            if newBest || sharesResult { bestAndShare }
            if let barLevel { levelBar(barLevel).padding(.horizontal, Metrics.gutter).transition(.opacity) }
            if let reward, badgesShown > 0 { earned(reward) }
            if shareShown && hasShareCards { shareCards.transition(.move(edge: .bottom).combined(with: .opacity)) }
        }
        .padding(.top, 8).padding(.bottom, Self.contentFoot)
    }

    /// Room for the whole burst: its outer ring lands 160 pt from the centre, so nothing is cut at the canvas's edge.
    private static let burstSize: CGFloat = 360

    /// The amber harmonic burst as each star lands (and on a level-up), centred on the stars wherever the content
    /// has scrolled them. It sits outside the scroll view and draws past this view's bounds (into the status bar's
    /// area when the stars are near the top), so it is whole at every text size and on every screen.
    @ViewBuilder private var burstLayer: some View {
        if let starsCenter {
            SparkBurst(trigger: burst, color: Palette.amber)
                .frame(width: Self.burstSize, height: Self.burstSize)
                .position(starsCenter)
        }
    }

    /// Done beside Next lesson, as a step's bar sets its actions (the primary trailing), so the results keep the room
    /// a second full-width button took; stacked, Next lesson first, where the two labels don't fit side by side (long
    /// languages, the largest text sizes). "Practice weak spots" sits over them when there is something to review.
    private var buttons: some View {
        VStack(spacing: 8) {
            if !LearnProgress.isReview(lesson.id) && !coachOffersDrill {
                PracticeWeakSpotsButton(course: course) { onNext($0) }
            }
            if let next, store.canPlay(next) {
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 10) {
                        doneButton.fixedSize(horizontal: true, vertical: false)
                        nextButton(next)
                    }
                    VStack(spacing: 10) {
                        nextButton(next)
                        doneButton
                    }
                }
            } else {
                doneButton
            }
        }
        .padding(.horizontal, Metrics.gutter)
        .padding(.top, 8).padding(.bottom, 8)
    }

    private func nextButton(_ next: Lesson) -> some View {
        StepButton(title: "Next lesson", accent: accent, inset: false) { onNext(next) }
            .accessibilityIdentifier("lesson.next")
    }

    private var doneButton: some View {
        Button { onContinue() } label: { Text("Done") }
            .buttonStyle(SecondaryButtonStyle())
            .accessibilityIdentifier("lesson.done")
    }

    /// Level N and a bar that fills with this lesson's XP; on a level-up it fills, bursts and rolls over.
    private func levelBar(_ level: Level) -> some View {
        HStack(spacing: 12) {
            ZStack {
                Circle().fill(leveled ? AnyShapeStyle(Palette.proGold) : AnyShapeStyle(Palette.mint.opacity(0.16)))
                Text("\(level.number)").font(Typeface.label(17)).foregroundStyle(leveled ? Palette.onGold : Palette.ink)
                    .contentTransition(.numericText())
            }
            .frame(width: 40, height: 40)
            .scaleEffect(leveled ? 1.12 : 1)
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("Level \(level.number)").font(Typeface.label(15)).foregroundStyle(leveled ? Palette.starGold : Palette.ink)
                    if leveled { Image(systemName: "arrow.up.circle.fill").font(.subheadline.weight(.bold)).foregroundStyle(Palette.starGold).transition(.scale.combined(with: .opacity)) }
                    Text(LocalizedStringKey(level.name)).font(.footnote).foregroundStyle(Palette.inkSoft).lineLimit(1)
                    Spacer(minLength: 0)
                }
                ProgressLine(value: barValue, color: leveled ? Palette.starGold : Palette.mint, height: 8)
            }
        }
        .padding(Metrics.tilePadding)
        .background(RoundedRectangle(cornerRadius: Metrics.cornerTile, style: .continuous).fill(Palette.stageRaised))
        .overlay(RoundedRectangle(cornerRadius: Metrics.cornerTile, style: .continuous).strokeBorder(leveled ? Palette.starGold.opacity(0.6) : .clear, lineWidth: 1.5))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("Level \(level.number)"))
    }

    /// One thing the lesson earned: a badge, a quest, Today's set.
    private struct Earned: Identifiable {
        let id: String
        let symbol: String
        let title: Text
        let detail: Text
        let gold: Bool
    }

    /// Everything the lesson earned, in the order it pops in: badges, quests, then Today's set (its bonus lands here
    /// too: the toast would be hidden behind this screen).
    private func earnedItems(_ reward: ProgressUpdate) -> [Earned] {
        var items: [Earned] = []
        for badge in reward.achievementsEarned {
            items.append(Earned(id: "badge." + badge.id, symbol: badge.symbol, title: Text(LocalizedStringKey(badge.title)),
                                detail: Text("Achievement unlocked"), gold: true))
        }
        for quest in reward.questsCompleted {
            items.append(Earned(id: "quest." + quest.id, symbol: "checkmark", title: Text(quest.title),
                                detail: Text("Quest complete · +\(quest.xp) XP"), gold: false))
        }
        if reward.dailySetCompleted {
            items.append(Earned(id: "daily", symbol: "sun.max.fill", title: Text("Today complete"),
                                detail: Text("+\(XPReward.dailySet) XP"), gold: true))
        }
        return items
    }

    /// Badges and quests this lesson completed, popping in one by one: two to a row when there are several (one at
    /// the accessibility sizes), so the usual one or two take a single row under the level bar.
    private func earned(_ reward: ProgressUpdate) -> some View {
        let all = earnedItems(reward)
        let columns = all.count > 1 && !typeSize.isAccessibilitySize ? 2 : 1
        let grid = Array(repeating: GridItem(.flexible(), spacing: 8, alignment: .top), count: columns)
        return LazyVGrid(columns: grid, spacing: 8) {
            ForEach(Array(all.prefix(badgesShown))) { item in rewardRow(item) }
        }
        .padding(.horizontal, Metrics.gutter)
    }

    private func rewardRow(_ item: Earned) -> some View {
        HStack(spacing: 10) {
            Image(systemName: item.symbol).font(.system(size: 14, weight: .bold)).foregroundStyle(item.gold ? Palette.onGold : Palette.onAccent)
                .frame(width: 32, height: 32)
                .background(Circle().fill(item.gold ? AnyShapeStyle(Palette.proGold) : AnyShapeStyle(Palette.mint)))
                .shadow(color: (item.gold ? Palette.starGold : Palette.mint).opacity(0.5), radius: 8)
            VStack(alignment: .leading, spacing: 1) {
                item.title.font(.subheadline.weight(.semibold)).foregroundStyle(Palette.ink)
                    .lineLimit(2).minimumScaleFactor(0.85)
                item.detail.font(.caption).foregroundStyle(Palette.inkSoft)
                    .lineLimit(2).minimumScaleFactor(0.85)
            }
            Spacer(minLength: 0)
        }
        .padding(8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: Metrics.cornerTile, style: .continuous).fill(Palette.stageRaised))
        .transition(.adaptive(.scale(scale: 0.6).combined(with: .opacity), reduceMotion: reduceMotion))
        .accessibilityElement(children: .combine)
    }

    // MARK: Coach

    /// What the coach makes of this lesson: the timing of its takes (heard since it began), how each note and chord
    /// went, and a tempo still to beat. The best note only.
    private func coachNote() -> CoachNote? {
        let since = Date().addingTimeInterval(-Double(result.minutes + 1) * 60)
        let context = Coach.LessonContext(lesson: lesson, courseId: course.id, result: result,
                                          takes: CoachTakes.shared.takes(since: since), tapped: practice,
                                          canReview: store.weakSpotReview(in: course) != nil)
        return Coach.lessonNotes(context).first
    }

    private var coachVoice: CoachVoice {
        let lessons = course.lessons
        return CoachVoice(lessonTitle: { id in lessons.first { $0.id == id }?.title.localized },
                          drillMinutes: store.weakSpotReview(in: course)?.minutes ?? 4)
    }

    /// The note, worked out once (`reveal`) so it holds still while the screen is open; before that, the same note
    /// fresh, so its room and the buttons are right from the first frame.
    private var shownCoach: CoachNote? { coachDecided ? coach : coachNote() }

    /// The coach already offers the weak-spot drill: the button below would say it twice.
    private var coachOffersDrill: Bool {
        guard let action = shownCoach?.action, case .review = action else { return false }
        return true
    }

    /// The note in a card of its own under the tiles: "Coach" over the words, the action as a pill.
    private func coachCard(_ note: CoachNote) -> some View {
        let tint = CoachVoice.tint(note, accent: accent)
        return CoachNoteView(note: note, voice: coachVoice, tint: tint, eyebrow: true, actionId: "lesson.coach.action") { action in
            perform(action)
        }
        .stillCard(padding: Metrics.tilePadding, tint: tint)
        .padding(.horizontal, Metrics.gutter)
        .accessibilityIdentifier("lesson.coach")
    }

    /// The drill and a replay open as the next lesson; the metronome, the tuner and Today close the results first.
    private func perform(_ action: CoachAction) {
        Haptics.shared.selection()
        CoachRoute.log(action, screen: "results")
        switch action {
        case .review:
            if let review = store.weakSpotReview(in: course) { onNext(review) }
        case let .lesson(id):
            if let target = course.lessons.first(where: { $0.id == id }) { onNext(target) }
        default:
            onContinue()
            CoachRoute.open(action, store: store)
        }
    }

    // MARK: Share

    private var isSong: Bool { lesson.kind == .song }
    private var newBest: Bool { improved && result.stars == 3 }
    /// Two or three stars (not in practice mode) or any finished song.
    private var sharesResult: Bool { isSong || (result.stars >= 2 && !practice) }
    /// Only the milestone's card waits below; the result's poster is the Share pill up top.
    private var hasShareCards: Bool { milestone != nil }

    /// "New best" with Share beside it (under it where the two don't fit side by side), in the first frame: the poster
    /// renders as the screen opens, so the pill is live before the stars have finished landing. A song taken at its own
    /// tempo has "Challenge a friend" beside Share.
    private var bestAndShare: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 14) {
                bestLabel
                if sharesResult { shareRow }
            }
            VStack(spacing: 10) {
                bestLabel
                if sharesResult { shareRow }
            }
        }
        .padding(.horizontal, Metrics.gutter)
        .opacity(appeared ? 1 : 0)
    }

    @ViewBuilder private var bestLabel: some View {
        if newBest {
            Label("New best on this lesson", systemImage: "arrow.up.circle.fill").font(.subheadline.weight(.semibold)).foregroundStyle(accent)
                .multilineTextAlignment(.center)
        }
    }

    /// Share, and "Challenge a friend" beside it (under it where the two don't fit side by side).
    @ViewBuilder private var shareRow: some View {
        if let points = challengePoints {
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 10) { sharePill; challengeButton(points) }
                VStack(spacing: 10) { sharePill; challengeButton(points) }
            }
        } else {
            sharePill
        }
    }

    private var sharePill: some View {
        resultShare.accessibilityIdentifier("lesson.share")
    }

    /// The song's best take at its own tempo this time (SongPerform hands it to Game Center); nil for a lesson, a song
    /// that ends on its chords, or only slower takes.
    private var challengePoints: Int? {
        guard isSong, !practice else { return nil }
        return GameCenter.shared.performBest(for: lesson.id)
    }

    /// "Challenge a friend" on the song: Game Center's own challenge where App Store Connect has one for it (a featured
    /// song, iOS 26), else a "Beat my score" card sent with the link that opens the song (Services/GameCenterSocial.swift).
    private func challengeButton(_ points: Int) -> some View {
        let title = CoverArt.mainTitle(lesson.title.localized)
        return ChallengeFriendButton(board: GameCenterIDs.song(forLesson: lesson.id)?.leaderboardID, screen: "results", tint: accent,
                                     message: PerformChallenge.message(points: points, title: title, lesson: lesson.id),
                                     armed: shareReady) {
            SongChallengeCard(title: title, art: CoverArt.of(lesson, in: course), points: points, accent: accent)
        }
        .accessibilityIdentifier("lesson.challenge")
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
        .padding(.horizontal, Metrics.gutter)
    }

    /// The song's poster (its title leads) or the lesson's (the headline leads).
    @ViewBuilder private var resultShare: some View {
        let courseTitle = course.title.localized
        let title = lesson.title.localized
        // The link opens this lesson or song for whoever receives it (a review's id is this player's own: Timbre).
        let route = LearnProgress.isReview(lesson.id) ? nil : DeepLink.lesson(id: lesson.id)
        if isSong {
            SharePill(preview: "Timbre", tint: accent, armed: shareReady, wait: .zero, route: route) {
                LessonShareCard(course: courseTitle, title: title, headline: nil, stars: result.stars, accuracy: accuracyPercent, accent: accent, song: true,
                                streak: store.streak.current)
            }
        } else {
            SharePill(preview: headline, tint: accent, armed: shareReady, wait: .zero, route: route) {
                LessonShareCard(course: courseTitle, title: title, headline: headline, stars: result.stars, accuracy: accuracyPercent, accent: accent, song: false,
                                streak: store.streak.current)
            }
        }
    }

    // MARK: Reminder

    /// Until the reminder has been offered once: one row, above the tiles and clear of the pinned buttons, with
    /// the time inline ("Remind me · 7 PM", the plan's time). One line wherever it fits: on a narrower phone the bell
    /// gives way first; only where the words still don't fit beside the pill (long languages, large type) does the
    /// pill move under them. On, it stays as a confirmation; × asks no more.
    private var reminderRow: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 8) {
                reminderIcon
                reminderTitle.lineLimit(1)
                Spacer(minLength: 4)
                reminderPill
                reminderClose
            }
            HStack(spacing: 8) {
                reminderTitle.lineLimit(1)
                Spacer(minLength: 4)
                reminderPill
                reminderClose
            }
            .padding(.leading, 4)
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 8) {
                    reminderIcon
                    reminderTitle.fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 4)
                    reminderClose
                }
                reminderPill
            }
        }
        // 44 pt controls (the pill's target, the close button) with 4 pt above and below: the row keeps its 52 pt.
        .padding(.leading, 10).padding(.trailing, reminderOn ? 10 : 4).padding(.vertical, 4)
        .background(RoundedRectangle(cornerRadius: Metrics.cornerTile, style: .continuous).fill(Palette.stageRaised))
        .overlay(RoundedRectangle(cornerRadius: Metrics.cornerTile, style: .continuous).strokeBorder(accent.opacity(0.22), lineWidth: 1))
        .padding(.horizontal, Metrics.gutter)
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
            .font(Typeface.label(.footnote))
            .foregroundStyle(Palette.ink)
    }

    /// The app's close button (a 44 pt target), read "Not now".
    @ViewBuilder private var reminderClose: some View {
        if !reminderOn {
            CloseButton(label: "Not now") {
                UserDefaults.standard.set(true, forKey: PracticeReminder.askedKey)
                withAnimation(Motion.settle) { offerReminder = false }
            }
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
            // The pill stays 36 pt; the finger gets 44.
            .frame(minHeight: Metrics.minTarget)
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

    /// A star: its bare string waits in place, and an earned one lands over it, ringing, white-hot and cooling to
    /// gold (`RewardStar`, `StarHeat`). It spins in from small; under Reduce Motion it only fades in.
    private func star(_ i: Int) -> some View {
        let earned = i < result.stars
        let lit = earned && i < shownStars
        let size: CGFloat = i == 1 ? 90 : 68
        return ZStack {
            RewardStar(earned: false)
            if earned {
                RewardStar(earned: true, landed: landed[i])
                    .modifier(StarHeat(landed: landed[i]))
                    .shadow(color: Palette.starGold.opacity(0.6), radius: 18)
                    .opacity(lit ? 1 : 0)
                    .scaleEffect(lit || reduceMotion ? 1 : 0.3)
                    .rotationEffect(.degrees(lit || reduceMotion ? 0 : -40))
            }
        }
        .frame(width: size * 1.05, height: size)
        .offset(y: i == 1 ? -12 : 0)
    }

    private func reveal() async {
        // Claimed at once, so the app-wide milestone overlay doesn't also show it behind this screen.
        if milestone == nil { milestone = store.takeStreakMilestone() }
        // Held from here on; its room was kept from the first frame (it fades in), so nothing below jumps.
        if !coachDecided { coach = coachNote(); coachDecided = true }
        let key = rewardKey
        SoundFX.shared.prepareStars(key)
        withAnimation(Motion.fade) { appeared = true }
        for i in 0..<3 {
            try? await Task.sleep(for: .milliseconds(reduceMotion ? 80 : 380))
            withMotion(Motion.reward, reduceMotion: reduceMotion) { shownStars = i + 1 }
            // Each star rings the next note of the key's triad: 1, 3, 5.
            if i < result.stars { landed[i] = Date(); SoundFX.shared.playStar(i, key: key); Haptics.shared.lock(); burst += 1 }
        }
        if coach != nil {
            try? await Task.sleep(for: .milliseconds(reduceMotion ? 60 : 200))
            // A fade under Reduce Motion, where it doesn't move.
            withAnimation(reduceMotion ? Motion.fade : Motion.page) { coachShown = true }
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
            // A soft tick every other step while the number climbs.
            if result.xp > 0, s % 2 == 0 { SoundFX.shared.play(.xpTick) }
        }
        await fillLevelBar()
        // The lull after the level bar: the poster renders here (a few frames of work), not as the stars land.
        shareReady = true
        if let reward {
            for i in 0..<(reward.achievementsEarned.count + reward.questsCompleted.count + (reward.dailySetCompleted ? 1 : 0)) {
                try? await Task.sleep(for: .milliseconds(reduceMotion ? 60 : 320))
                withMotion(Motion.reward, reduceMotion: reduceMotion) { badgesShown = i + 1 }
                // A badge rings the key's octave over the stars' triad.
                if i < reward.achievementsEarned.count { SoundFX.shared.playStar(3, key: key); Haptics.shared.lock() }
            }
        }
        // A streak milestone takes the whole screen once the results have landed; its share card waits below.
        if let milestone {
            try? await Task.sleep(for: .milliseconds(reduceMotion ? 100 : 600))
            withAnimation(Motion.fade) { celebrating = milestone }
        }
        guard hasShareCards else { return }
        try? await Task.sleep(for: .milliseconds(reduceMotion ? 60 : 280))
        withMotion(Motion.page, reduceMotion: reduceMotion) { shareShown = true }
    }

    private func fillLevelBar() async {
        guard let reward else { return }
        let after = store.progress.xp
        let before = max(0, after - reward.xpGained)
        let start = Progression.level(for: before)
        barValue = start.progress(before)
        withAnimation(Motion.fade) { barLevel = start }
        try? await Task.sleep(for: .milliseconds(250))
        if let next = reward.levelUp {
            withAnimation(Motion.reveal) { barValue = 1 }
            try? await Task.sleep(for: .milliseconds(650))
            SoundFX.shared.play(.levelUp); Haptics.shared.done(); burst += 1
            withMotion(Motion.reward, reduceMotion: reduceMotion) { barLevel = next; leveled = true; barValue = 0 }
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
    /// The poster renders only once armed, and `wait` after that: rendering takes the main thread for a few frames,
    /// so it never runs while a reward moment is still landing.
    let armed: Bool
    let wait: Duration
    /// The `timbre://` route the share's link opens (`ShareDestination`); nil links to Timbre itself.
    let route: URL?
    let card: Card
    @State private var image: Image?
    @Environment(\.displayScale) private var displayScale
    @Environment(\.locale) private var locale
    @Environment(\.layoutDirection) private var layoutDirection

    init(preview: LocalizedStringKey, tint: Color = Palette.mint, armed: Bool = true, wait: Duration = ShareCardRenderer.entrance,
         route: URL? = nil, @ViewBuilder card: () -> Card) {
        self.preview = preview
        self.tint = tint
        self.armed = armed
        self.wait = wait
        self.route = route
        self.card = card()
    }

    var body: some View {
        Group {
            if let image {
                ShareLink(item: image, message: ShareDestination.message(for: route), preview: SharePreview(preview, image: image)) { face(image) }
                    .buttonStyle(PressScaleStyle())
                    .transition(.opacity)
            } else {
                face(nil).opacity(0.55)
            }
        }
        .animation(Motion.fade, value: image == nil)
        .task(id: armed) {
            guard armed, image == nil else { return }
            if wait > .zero { try? await Task.sleep(for: wait) }
            guard !Task.isCancelled, image == nil else { return }
            image = ShareCardRenderer.image(card, scale: displayScale, locale: locale, direction: layoutDirection)
        }
    }

    private func face(_ poster: Image?) -> some View {
        HStack(spacing: 8) {
            thumbnail(poster)
            Image(systemName: "square.and.arrow.up").font(.system(size: 13, weight: .bold)).accessibilityHidden(true)
            Text("Share")
        }
        .font(Typeface.label(.footnote))
        .foregroundStyle(tint)
        .padding(.leading, 9).padding(.trailing, 16)
        .frame(minHeight: Metrics.minTarget)
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
