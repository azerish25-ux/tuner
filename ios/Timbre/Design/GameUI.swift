import SwiftUI
import TimbreCore
import UIKit

/// The streak: its stage lamp (lit once today counts), the day count and any banked freezes, in one capsule that is
/// the same on every tab; it taps through to Progress. Today's set is drawn on its own cards (Learn, Practice) and
/// spoken here as the chip's value, never drawn as a ring that would change the chip's shape from tab to tab.
/// The capsule is at least 36 pt and grows with its text; the target is at least 44 pt. Like a bar item it stops
/// growing at AX1 and offers the Large Content Viewer.
struct StreakChip: View {
    @EnvironmentObject private var store: AppStore
    /// Whether VoiceOver hears Today's progress with the streak. Nil decides by tab: not on Practice or Learn, whose
    /// Today cards say it.
    var showsToday: Bool? = nil
    var action: () -> Void = {}
    /// The capsule's side inset, growing with the count's text.
    @ScaledMetric(relativeTo: .subheadline) private var inset: CGFloat = 12
    /// The lamp beside the count, growing with it.
    @ScaledMetric(relativeTo: .footnote) private var lampSize: CGFloat = 16
    @Environment(\.legibilityWeight) private var legibility
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let _ = legibility
        let streak = store.streak
        let today = showsToday ?? (store.selectedTab != .practice && store.selectedTab != .learn)
        let activities = today ? store.dailySet : []
        let done = activities.filter { store.dailyDone($0.kind) }.count
        Button(action: action) {
            HStack(spacing: 5) {
                // A new day on the count: the lamp swells once (it holds its size under Reduce Motion).
                Glyph(.lamp, size: lampSize, tint: streak.practicedToday ? Palette.flame : Palette.inkFaint)
                    .phaseAnimator([1.0, 1.18], trigger: streak.current) { lamp, scale in
                        lamp.scaleEffect(CGFloat(reduceMotion ? 1 : scale), anchor: .bottom)
                    } animation: { _ in Motion.pop }
                Text("\(streak.current)").font(Typeface.label(.footnote)).foregroundStyle(Palette.flameInk).monospacedDigit()
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
            .padding(.horizontal, inset)
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
        .accessibilityValue(value(done: done, total: activities.count))
        .accessibilityIdentifier("streak.chip")
    }

    /// "Today: 1 of 3" where Today isn't on screen, and the banked freezes.
    private func value(done: Int, total: Int) -> Text {
        var parts: [Text] = []
        if total > 0 { parts.append(Text("Today") + Text(verbatim: ": ") + Text("\(done) of \(total)")) }
        if store.streakFreezes > 0 { parts.append(Text("\(store.streakFreezes) streak freezes")) }
        guard let first = parts.first else { return Text(verbatim: "") }
        return parts.dropFirst().reduce(first) { (line: Text, part: Text) -> Text in line + Text(verbatim: ", ") + part }
    }
}

/// The level, drawn one way everywhere: a ring that fills with XP toward the next level around "LV 5" on one line, at
/// any size (the header's 36 pt ring, the Practice hub's large one). VoiceOver says "Level 5" and the XP. The ring is a
/// fixed-size graphic: its type stops growing at xxxLarge, and as a button its target is at least 44 pt.
struct LevelRing: View {
    @EnvironmentObject private var store: AppStore
    var size: CGFloat = 36
    var action: (() -> Void)?
    @Environment(\.legibilityWeight) private var legibility

    var body: some View {
        let _ = legibility
        let xp = store.progress.xp
        let level = store.level
        let ring = ZStack {
            Circle().stroke(Palette.line, lineWidth: size * 0.09)
            Circle().trim(from: 0, to: max(0.02, level.progress(xp)))
                .stroke(Palette.mint, style: StrokeStyle(lineWidth: size * 0.09, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(Motion.settle, value: xp)
            LevelMark(number: level.number, size: size)
                .frame(maxWidth: size * 0.74)
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
}

/// "LV 5": the level's one mark, inside its ring or beside a figure, sized to `size` (the ring's diameter).
struct LevelMark: View {
    let number: Int
    var size: CGFloat = 36

    var body: some View {
        (Text("LV").font(Typeface.label(size * 0.24)).tracking(0.3).foregroundStyle(Palette.mint)
            + Text(verbatim: " ")
            + Text("\(number)").font(Typeface.label(size * 0.36)).foregroundStyle(Palette.ink))
            .contentTransition(.numericText())
            .lineLimit(1).minimumScaleFactor(0.5)
    }
}

/// The level's ring on its own, without the mark inside: beside an "LV 5" figure (a stat tile, the stat bar), so the
/// level is drawn as it is in the header, ring and "LV" together.
struct LevelArc: View {
    /// 0…1 toward the next level.
    let progress: Double
    var size: CGFloat = 22
    /// Mint; the rewards' gold for the moment of a level-up (the lesson's results).
    var tint: Color = Palette.mint

    var body: some View {
        ZStack {
            Circle().stroke(Palette.line, lineWidth: size * 0.14)
            Circle().trim(from: 0, to: max(0.02, min(1, progress)))
                .stroke(tint, style: StrokeStyle(lineWidth: size * 0.14, lineCap: .round))
                .rotationEffect(.degrees(-90))
        }
        .padding(size * 0.07)
        .frame(width: size, height: size)
        .accessibilityHidden(true)
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
        case .sniperWin: return "Win a round of Bullseye"
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
    /// One quiet ink for every quest: a quest is not a status, and a row of them shouldn't be a rainbow.
    var tint: Color { Palette.inkSoft }
}

/// One daily quest: its glyph, the title, a bar with its count ("3 / 10", the tuning quest in strings) and the XP it
/// pays. The Practice hub's quest rows are this row too.
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
            Glyph(done ? "checkmark" : quest.symbol, size: Glyph.lead, tint: done ? Palette.mint : quest.tint)
            VStack(alignment: .leading, spacing: 7) {
                Text(quest.title).font(.subheadline.weight(.semibold)).foregroundStyle(done ? Palette.inkSoft : Palette.ink)
                    .strikethrough(done, color: Palette.inkFaint)
                    .fixedSize(horizontal: false, vertical: true)
                HStack(spacing: 10) {
                    ProgressLine(value: Double(progress) / Double(max(1, target)), color: Palette.mint, height: 5)
                    Text.fraction(progress, target).font(Typeface.number(.caption)).foregroundStyle(done ? Palette.mint : Palette.inkSoft)
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

    /// "+20 XP" while open (nothing in Calm mode), "Done" once claimed: words at the row's end, not a pill.
    @ViewBuilder private func reward(_ done: Bool) -> some View {
        if done {
            Text("Done").font(Typeface.label(.caption)).foregroundStyle(Palette.mint)
        } else if !store.settings.calmMode {
            Text("+\(quest.xp) XP").font(Typeface.label(.caption)).foregroundStyle(Palette.inkSoft)
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

extension Achievement {
    /// A streak badge is drawn with the streak's lamp, as every streak is (`TimbreGlyph.lamp`); its stored symbol is the
    /// flame the badge had before, kept for saves and Game Center.
    var drawsLamp: Bool { metric == "streakBest" && symbol.hasPrefix("flame") }

    /// The medal's studio-lit artwork (`artwork`, in the catalog's Medals folder) once it ships; nil until then.
    var artworkImage: UIImage? { UIImage(named: artwork) }
}

/// A badge's glyph at `size` points (about an SF Symbol's height at that font size): the streak's lamp for a streak
/// badge, else its symbol. Ink comes from the foreground style.
struct AchievementGlyph: View {
    let achievement: Achievement
    let size: CGFloat
    var weight: Font.Weight = .bold

    var body: some View {
        if achievement.drawsLamp {
            DrawnGlyph(glyph: .lamp).frame(width: size * 1.1, height: size * 1.1)
        } else {
            Image(systemName: achievement.symbol).font(.system(size: size, weight: weight))
        }
    }
}

extension Achievement.Category {
    /// The medal face, lit from the top left: tuning gold, dedication flame, ear mint, lessons violet, courses deep sky.
    var face: (light: Color, deep: Color) {
        switch self {
        case .tuning: return (Color(hex: 0xFFD596), Color(hex: 0xB86E12))
        case .dedication: return (Color(hex: 0xFFBE8F), Color(hex: 0xC2410C))
        case .ear: return (Color(hex: 0x8BF7D2), Palette.mintDeep)
        case .learning: return (Color(hex: 0xCFC5FF), Color(hex: 0x5B47C9))
        case .course: return (Color(hex: 0x4D86AD), Color(hex: 0x0E2234))
        }
    }
    /// The category's hue: progress arcs and labels (never a status colour).
    var tint: Color {
        switch self {
        case .tuning: return Palette.starGold
        case .dedication: return Palette.flame
        case .ear: return Palette.mint
        case .learning: return Palette.violet
        case .course: return Palette.sky
        }
    }
}

/// A medal: a metal rim for the tier (bronze, silver, gold) around a face in the category's colour, with the
/// badge's glyph (or an instrument's artwork) embossed on it; a glint sweeps across the first time it is seen. Once the
/// medal's own studio-lit artwork ships (`Achievement.artwork`), it fills the face inside the rim instead.
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
        let art = achievement.artworkImage
        return ZStack {
            Circle().fill(AngularGradient(colors: achievement.tier.metal, center: .center, angle: .degrees(-35)))
            if let art {
                artwork(art, lit: true)
            } else {
                Circle().inset(by: rim)
                    .fill(RadialGradient(colors: [face.light, face.deep], center: UnitPoint(x: 0.32, y: 0.26), startRadius: 0, endRadius: size * 0.62))
            }
            Circle().inset(by: rim).strokeBorder(.black.opacity(0.3), lineWidth: 1)
            if art == nil {
                emblem(lit: true)
                // Gloss on the upper half of the face (the artwork is lit in its own studio light).
                Circle().inset(by: rim + 1)
                    .fill(LinearGradient(colors: [.white.opacity(0.26), .white.opacity(0)], startPoint: .top, endPoint: .center))
            }
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
            if let art = achievement.artworkImage {
                artwork(art, lit: false).padding(rim * 0.6)
            } else {
                emblem(lit: false)
            }
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
            AchievementGlyph(achievement: achievement, size: size * 0.34)
                .foregroundStyle(lit ? Color(hex: 0x0A0C10).opacity(0.82) : Palette.inkFaint.opacity(0.7))
                // Embossed: a hairline of light under the cut.
                .shadow(color: .white.opacity(lit ? 0.35 : 0), radius: 0, y: 0.8)
        }
    }

    /// The medal's own artwork inside the rim: full colour once earned, grey and dim while locked.
    private func artwork(_ image: UIImage, lit: Bool) -> some View {
        Image(uiImage: image).resizable().scaledToFill()
            .clipShape(Circle().inset(by: rim))
            .saturation(lit ? 1 : 0)
            .opacity(lit ? 1 : 0.32)
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

/// One announcement for the reward toast.
struct RewardBanner: Identifiable {
    enum Tone { case gold, mint, frost }
    let id = UUID()
    let symbol: String
    /// Drawn in place of `symbol` (a streak badge's lamp).
    var drawn: TimbreGlyph? = nil
    let title: Text
    /// Nil for the compact "+XP" toast.
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

/// XP, quest, badge, daily-set, level-up and streak announcements, one at a time from a queue, as a capsule of the
/// app's glass docked under the screen's header: `safeAreaInsets.top + 8`, at the leading gutter on a phone (narrow
/// enough to leave the header's trailing controls in view), centred on a wide screen. The status bar belongs to the
/// system, so nothing is ever drawn inside its band. Calm mode (`UserSettings.calmMode`) keeps the XP, level, quest and
/// streak announcements back; badges and a finished Today still show, without their XP. Reduce Motion fades it in
/// place. It never takes taps; VoiceOver hears each banner.
struct RewardToast: View {
    /// Where the toast shows. Both dock under the header, outside the status bar; the two names stay so a caller may
    /// pass either.
    enum Placement: Sendable { case automatic, docked }

    @EnvironmentObject private var store: AppStore
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var queue: [RewardBanner] = []
    @State private var current: RewardBanner?
    @State private var open = false
    @State private var presenting = false
    private let placement: Placement

    init(placement: Placement = .automatic) {
        self.placement = placement
    }

    var body: some View {
        // The top inset is read from a reader that keeps the safe area (inside `.ignoresSafeArea()` it reads 0), with the
        // key window's inset as a fallback; the toast is then placed in full-screen coordinates.
        let windowTop = Self.windowTopInset
        let calm = store.settings.calmMode
        GeometryReader { outer in
            let top = max(outer.safeAreaInsets.top, windowTop)
            GeometryReader { proxy in
                let layout = ToastLayout(width: proxy.size.width, top: top, clearsHeaderControls: !calm)
                if let current {
                    toast(current, layout: layout)
                        .padding(.top, layout.y)
                        .padding(.leading, layout.leading ? Metrics.gutter : 0)
                        .frame(width: proxy.size.width, height: proxy.size.height, alignment: layout.leading ? .topLeading : .top)
                }
            }
            .ignoresSafeArea()
        }
        .environment(\.layoutDirection, rightToLeft ? .rightToLeft : .leftToRight)
        .allowsHitTesting(false)
        .onChange(of: store.rewardPulse) { _, _ in
            if let reward = store.lastReward { enqueue(Self.banners(for: reward, calm: store.settings.calmMode)) }
        }
        .onChange(of: store.streakPulse) { _, _ in
            if let notice = store.streakNotice, !store.settings.calmMode { enqueue([Self.banner(for: notice)]) }
        }
    }

    /// The app's own language direction (the toast sits outside the tab view that carries it).
    private var rightToLeft: Bool { TimbreLocalization.isRightToLeft(store.settings.language) }

    /// The key window's top safe-area inset (the status bar's height).
    @MainActor private static var windowTopInset: CGFloat {
        let windows = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.flatMap(\.windows)
        return (windows.first(where: \.isKeyWindow) ?? windows.first)?.safeAreaInsets.top ?? 0
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
        guard !presenting, !queue.isEmpty else { return }
        presenting = true
        Task { @MainActor in
            await presentQueue()
            presenting = false
        }
    }

    /// Shows the queue one banner at a time: drop in, hold, lift away.
    private func presentQueue() async {
        while !queue.isEmpty {
            let next = queue.removeFirst()
            current = next
            open = false
            AccessibilityNotification.Announcement(next.announcement).post()
            // Let the closed toast appear first, so it can drop in from there.
            try? await Task.sleep(for: .milliseconds(30))
            withMotion(Motion.toastIn, reduceMotion: reduceMotion) { open = true }
            try? await Task.sleep(for: .seconds(queue.count > 1 ? next.seconds * 0.8 : next.seconds))
            withMotion(Motion.toastOut, reduceMotion: reduceMotion) { open = false }
            try? await Task.sleep(for: .milliseconds(reduceMotion ? 220 : 360))
            current = nil
            try? await Task.sleep(for: .milliseconds(90))
        }
    }

    /// What a progress update announces. In Calm mode only a badge and a finished Today, with no XP: no levels,
    /// quests or XP counts.
    private static func banners(for reward: ProgressUpdate, calm: Bool) -> [RewardBanner] {
        var list: [RewardBanner] = []
        if let level = reward.levelUp, !calm {
            list.append(RewardBanner(symbol: "star.fill", title: Text("Level \(level.number)"), detail: Text(LocalizedStringKey(level.name)), tone: .gold, seconds: 2.6,
                                     announcement: String(localized: "Level \(level.number)", bundle: TimbreLocalization.bundle) + ", " + NSLocalizedString(level.name, comment: "")))
        }
        if reward.dailySetCompleted {
            list.append(RewardBanner(symbol: "sun.max.fill", title: Text("Today complete"), detail: calm ? nil : Text("+\(XPReward.dailySet) XP"),
                                     tone: .gold, seconds: 2.6, announcement: String(localized: "Today complete", bundle: TimbreLocalization.bundle)))
        }
        let badges = reward.achievementsEarned
        if badges.count >= 3 {
            // Several at once (a launch catching up on new badges): one banner naming the first two.
            let names = Text(LocalizedStringKey(badges[0].title)) + Text(verbatim: ", ") + Text(LocalizedStringKey(badges[1].title)) + Text(verbatim: " …")
            list.append(RewardBanner(symbol: "rosette", title: Text("\(badges.count) achievements unlocked"), detail: names, tone: .gold, seconds: 2.8,
                                     announcement: String(localized: "\(badges.count) achievements unlocked", bundle: TimbreLocalization.bundle)))
        } else {
            for a in badges {
                list.append(RewardBanner(symbol: a.symbol, drawn: a.drawsLamp ? .lamp : nil, title: Text(LocalizedStringKey(a.title)),
                                         detail: Text("Achievement unlocked"), tone: .gold, seconds: 2.6,
                                         announcement: NSLocalizedString(a.title, comment: "") + ", " + String(localized: "Achievement unlocked", bundle: TimbreLocalization.bundle)))
            }
        }
        if !calm {
            for q in reward.questsCompleted {
                list.append(RewardBanner(symbol: "checkmark", title: Text(q.title), detail: Text("Quest complete · +\(q.xp) XP"), tone: .mint, seconds: 2.2,
                                         announcement: String(localized: "Quest complete · +\(q.xp) XP", bundle: TimbreLocalization.bundle)))
            }
            if list.isEmpty && reward.xpGained > 0 { list.append(.experience(reward.xpGained)) }
        }
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

    // MARK: The toast

    /// A capsule of the app's glass (iOS 26; a dark plate before), darkened so its words read over any header.
    private func toast(_ banner: RewardBanner, layout: ToastLayout) -> some View {
        let compact = banner.detail == nil
        let size = layout.size(compact: compact)
        return HStack(spacing: 8) {
            icon(banner, size: compact ? 24 : 28)
            words(banner)
            Spacer(minLength: 0)
        }
        .padding(.leading, compact ? 6 : 7).padding(.trailing, 12)
        .frame(width: size.width, height: size.height)
        .timbreGlass(Palette.stage.opacity(0.55), in: Capsule(style: .continuous))
        .shadow(color: .black.opacity(open ? 0.35 : 0), radius: 14, y: 5)
        .opacity(open ? 1 : 0)
        .scaleEffect(open || reduceMotion ? 1 : 0.9, anchor: .top)
        .offset(y: open || reduceMotion ? 0 : -10)
        .dynamicTypeSize(...DynamicTypeSize.large)
        .environment(\.colorScheme, .dark)
        .accessibilityHidden(true)
    }

    private func words(_ banner: RewardBanner) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            banner.title.font(Typeface.label(.footnote))
                .foregroundStyle(banner.detail == nil ? Palette.mint : Palette.ink)
                .lineLimit(1).minimumScaleFactor(0.7)
            if let detail = banner.detail {
                detail.font(.caption2).foregroundStyle(Palette.inkSoft)
                    .lineLimit(2).minimumScaleFactor(0.75)
            }
        }
    }

    /// The reward's medallion: its glyph in dark ink on the tone's colour.
    private func icon(_ banner: RewardBanner, size: CGFloat) -> some View {
        ZStack {
            if let drawn = banner.drawn {
                DrawnGlyph(glyph: drawn).frame(width: size * 0.56, height: size * 0.56)
            } else {
                Image(systemName: banner.symbol).font(.system(size: size * 0.46, weight: .bold))
                    .symbolEffect(.bounce, value: open)
            }
        }
        .foregroundStyle(banner.tone == .mint ? Palette.onAccent : Palette.onGold)
        .frame(width: size, height: size)
        .background(Circle().fill(Self.fill(banner.tone)))
    }

    private static func fill(_ tone: RewardBanner.Tone) -> AnyShapeStyle {
        switch tone {
        case .gold: return AnyShapeStyle(Palette.proGold)
        case .mint: return AnyShapeStyle(Palette.mint)
        case .frost: return AnyShapeStyle(Palette.frost)
        }
    }
}

/// Where the reward toast sits: 8 pt under the top safe-area edge. On a phone at the leading gutter, narrow enough to
/// leave the header's trailing controls (streak, level, settings) in view; on a wide screen (iPad, landscape) centred.
private struct ToastLayout {
    let width: CGFloat
    /// The top safe-area inset: the status bar's height (0 in landscape, where there is none).
    let top: CGFloat
    /// The header's trailing controls are showing (not in Calm mode), so the toast keeps clear of them.
    let clearsHeaderControls: Bool

    /// Kept clear on the trailing side: streak chip, level ring and settings button (44 pt targets) with the gutter;
    /// in Calm mode only the tuner's settings button.
    private var trailingClearance: CGFloat { clearsHeaderControls ? 200 : 76 }
    /// Docked at the leading gutter (a phone in portrait); centred otherwise.
    var leading: Bool { width < 600 }
    /// The toast's top edge, in full-screen coordinates.
    var y: CGFloat { top + 8 }

    func size(compact: Bool) -> CGSize {
        if leading {
            let room = width - Metrics.gutter - trailingClearance
            return CGSize(width: compact ? min(150, room) : max(150, min(300, room)), height: compact ? 36 : 52)
        }
        return CGSize(width: compact ? 150 : min(width - 32, 360), height: compact ? 40 : 52)
    }
}
