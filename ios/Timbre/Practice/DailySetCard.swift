import SwiftUI
import TimbreCore

/// How each activity of Today looks and reads.
extension DailyActivity.Kind {
    var title: LocalizedStringKey {
        switch self {
        case .tune: return "Tune up"
        case .ear: return "Ear training"
        case .chord: return "Chord of the day"
        case .scale: return "Scale workout"
        case .rhythm: return "Rhythm"
        case .voice: return "Voice warm-up"
        case .drone: return "Intonation over a drone"
        case .lesson: return "Next lesson"
        case .review: return "Review"
        }
    }

    /// The name on a Today row: one line beside the minutes, so the drone goes by the tool's name.
    var rowTitle: LocalizedStringKey { self == .drone ? "Drone" : title }

    var detail: String {
        switch self {
        case .tune: return String(localized: "every string to a still point")
        case .ear: return String(localized: "ten questions")
        case .chord: return String(localized: "learn one new shape")
        case .scale: return String(localized: "one position, slowly")
        case .rhythm: return String(localized: "steady at a comfortable tempo")
        case .voice: return String(localized: "a comfortable range")
        case .drone: return String(localized: "hold notes against a tonic")
        case .lesson, .review: return String(localized: "Learn")
        }
    }

    var symbol: String {
        switch self {
        case .tune: return "tuningfork"
        case .ear: return "ear"
        case .chord: return "hand.raised.fingers.spread"
        case .scale: return "point.3.connected.trianglepath.dotted"
        case .rhythm: return "metronome"
        case .voice: return "music.mic"
        case .drone: return "waveform.path"
        case .lesson: return "graduationcap"
        case .review: return "arrow.clockwise"
        }
    }

    /// Violet is learning (as on Learn's quests and badges); a set never puts two arcs of one colour side by side.
    var tint: Color {
        switch self {
        case .tune: return Palette.amber
        case .ear, .review: return Palette.mint
        case .chord, .scale, .voice, .drone: return Palette.sky
        case .rhythm: return Palette.coral
        case .lesson: return Palette.violet
        }
    }

    /// Scales and the drone are Pro tools: a free player's tap opens the paywall. Chords is free (its open shapes and
    /// Check, `FreeTier`).
    var needsPro: Bool { [.scale, .drone].contains(self) }
}

/// Minutes as the locale writes them ("4 min", "4 Min.").
private func minutesText(_ minutes: Int) -> Text {
    Text(Duration.seconds(max(0, minutes) * 60), format: .units(allowed: [.minutes], width: .abbreviated))
}

// MARK: - Ring

/// Today as a ring: one arc per activity, as long as its minutes, filling in once it is done. The same ring
/// sits on the Play hub, on Learn and around the streak flame. With Differentiate Without Color an open
/// activity is a dotted track and a done one carries a check, so the two differ by shape as well as by light.
/// With `open`, each arc is a button for its activity (the card's rows carry the same actions for VoiceOver).
struct DailySetRing: View {
    let activities: [DailyActivity]
    let done: Set<DailyActivity.Kind>
    var lineWidth: CGFloat = 10
    /// Space between arcs as a share of the circle, room for the round caps plus a hairline of air.
    var gap = 0.05
    var open: ((DailyActivity.Kind) -> Void)? = nil
    @Environment(\.accessibilityDifferentiateWithoutColor) private var noColor

    /// Each activity's share of the circle (0…1), less the gap between arcs.
    private var spans: [(from: Double, to: Double)] {
        let total = Double(max(1, activities.reduce(0) { $0 + max(1, $1.minutes) }))
        let space = activities.count > 1 ? gap : 0
        var start = 0.0
        return activities.map { activity in
            let length = Double(max(1, activity.minutes)) / total
            defer { start += length }
            let from = start + space / 2
            return (from: from, to: max(from + 0.004, start + length - space / 2))
        }
    }

    var body: some View {
        let spans = self.spans
        ZStack {
            ForEach(Array(activities.enumerated()), id: \.element.id) { index, activity in
                segment(activity, from: spans[index].from, to: spans[index].to)
            }
        }
        .animation(Motion.settle, value: done)
        .accessibilityHidden(true)
    }

    @ViewBuilder private func segment(_ activity: DailyActivity, from: Double, to: Double) -> some View {
        let lit = done.contains(activity.kind)
        let arc = ZStack {
            arcView(activity, from: from, to: to, lit: lit)
            if noColor && lit && lineWidth >= 8 { check(at: (from + to) / 2) }
        }
        if let open {
            Button { open(activity.kind) } label: { arc }
                .buttonStyle(PressScaleStyle())
                .contentShape(RingSector(from: from, to: to, thickness: lineWidth))
        } else {
            arc
        }
    }

    private func arcView(_ activity: DailyActivity, from: Double, to: Double, lit: Bool) -> some View {
        let tint = activity.kind.tint
        let style = StrokeStyle(lineWidth: lineWidth, lineCap: .round)
        // Without colour, the open track is a row of dots rather than a dim band.
        let dotted = StrokeStyle(lineWidth: lineWidth * 0.6, lineCap: .round, dash: [0.01, lineWidth * 1.2])
        return ZStack {
            Circle().inset(by: lineWidth / 2).trim(from: from, to: to)
                .stroke(tint.opacity(noColor ? 0.55 : 0.18), style: noColor && !lit ? dotted : style)
            Circle().inset(by: lineWidth / 2).trim(from: from, to: lit ? to : from)
                .stroke(tint, style: style)
                .opacity(lit ? 1 : 0)
                .shadow(color: tint.opacity(lit ? 0.55 : 0), radius: lineWidth * 0.6)
        }
        .rotationEffect(.degrees(-90))
    }

    /// A check on a done arc, at `position` (0…1 from 12 o'clock, clockwise).
    private func check(at position: Double) -> some View {
        GeometryReader { proxy in
            let radius = min(proxy.size.width, proxy.size.height) / 2 - lineWidth / 2
            let angle = position * 2 * Double.pi - Double.pi / 2
            Image(systemName: "checkmark").font(.system(size: lineWidth * 0.72, weight: .black))
                .foregroundStyle(Palette.onAccent)
                .position(x: proxy.size.width / 2 + radius * CGFloat(cos(angle)), y: proxy.size.height / 2 + radius * CGFloat(sin(angle)))
        }
        .allowsHitTesting(false)
    }
}

/// The tappable band of one arc: an annular sector a little wider than the stroke, starting at 12 o'clock.
private struct RingSector: Shape {
    let from: Double
    let to: Double
    let thickness: CGFloat
    func path(in rect: CGRect) -> Path {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let outer = min(rect.width, rect.height) / 2 + 6
        let inner = max(0, outer - thickness - 14)
        let start = Angle.degrees(from * 360 - 90), end = Angle.degrees(to * 360 - 90)
        var path = Path()
        path.addArc(center: center, radius: outer, startAngle: start, endAngle: end, clockwise: false)
        path.addArc(center: center, radius: inner, startAngle: end, endAngle: start, clockwise: true)
        path.closeSubpath()
        return path
    }
}

// MARK: - Play hub card

/// Today at the top of the Play hub: the day's one session (the next lesson, then two tool reps) as arcs of a
/// ring and as rows beside it, each opening its lesson or tool and ticking off as it is done. Each fact shows
/// once: how many are done and the minutes left sit in the ring, the set's bonus in the header, and a daily
/// quest for the same practice rides on its row as an XP side goal. Finishing the set pays the bonus (the toast
/// announces it) and the card celebrates once: a burst of sparks, a chime, a gold ring.
struct DailySetCard: View {
    @EnvironmentObject private var store: AppStore
    @EnvironmentObject private var commerce: CommerceService
    let open: (DailyActivity.Kind) -> Void
    /// The day the completion was last celebrated here, so the burst plays once.
    @AppStorage("daily.celebrated") private var celebratedDay = ""
    /// The lesson rep follows Learn's course; reading it here redraws the card when that changes.
    @AppStorage("learn.course") private var learnCourseId = "guitar"
    @State private var visible = false
    @State private var burst = 0
    @State private var pop = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var typeSize
    /// One row's height: a name line and the line under it, so every row matches the lesson row.
    @ScaledMetric(relativeTo: .subheadline) private var rowHeight: CGFloat = 40

    var body: some View {
        let activities = store.dailySet
        let done = Set(activities.map(\.kind).filter { store.dailyDone($0) })
        let complete = store.dailySetComplete
        VStack(alignment: .leading, spacing: 14) {
            header(complete: complete)
            // At the accessibility sizes the rows need the card's full width: the ring moves above them.
            if typeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: 14) {
                    ring(activities, done: done, complete: complete)
                        .frame(maxWidth: .infinity)
                    rows(activities, done: done)
                }
            } else {
                HStack(alignment: .center, spacing: 16) {
                    ring(activities, done: done, complete: complete)
                    rows(activities, done: done)
                }
            }
        }
        .stillCard(tint: complete ? Palette.amber : Palette.mint)
        .onAppear { visible = true; celebrateIfNeeded(complete) }
        .onDisappear { visible = false }
        .onChange(of: complete) { _, now in if visible { celebrateIfNeeded(now) } }
    }

    private func rows(_ activities: [DailyActivity], done: Set<DailyActivity.Kind>) -> some View {
        let quests = store.quests
        return VStack(spacing: 2) {
            ForEach(activities) { activity in
                row(activity, done: done.contains(activity.kind), quest: DailySet.quest(for: activity.kind, in: quests))
            }
        }
    }

    private func header(complete: Bool) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            CardTitle("Today")
            Spacer()
            if complete {
                Label { Text("Done") } icon: { Image(systemName: "flame.fill") }
                    .font(Typeface.label(12)).foregroundStyle(Palette.amber)
            } else {
                bonus
            }
        }
    }

    /// What finishing the whole set pays.
    private var bonus: some View {
        HStack(spacing: 4) {
            Image(systemName: "sun.max.fill").font(.system(size: 10, weight: .bold)).accessibilityHidden(true)
            Text("+\(XPReward.dailySet) XP")
        }
        .font(Typeface.label(12)).foregroundStyle(Palette.amber)
        .padding(.horizontal, 9).padding(.vertical, 4)
        .background(Capsule().fill(Palette.amber.opacity(0.12)))
        .overlay(Capsule().strokeBorder(Palette.amber.opacity(0.3), lineWidth: 1))
        .fixedSize()
        .accessibilityElement(children: .combine)
    }

    private func ring(_ activities: [DailyActivity], done: Set<DailyActivity.Kind>, complete: Bool) -> some View {
        // Every layer is sized explicitly: the ring must stay 112 pt whatever its siblings measure.
        ZStack {
            Circle().fill(RadialGradient(colors: [Palette.amber.opacity(complete ? 0.28 : 0), .clear], center: .center, startRadius: 10, endRadius: 70))
                .frame(width: 112, height: 112)
                .scaleEffect(1.25)
            DailySetRing(activities: activities, done: done, lineWidth: 11, open: open)
                .frame(width: 112, height: 112)
            center(activities, done: done, complete: complete)
        }
        .frame(width: 112, height: 112)
        .overlay {
            if !reduceMotion {
                SparkBurst(trigger: burst, color: Palette.amber)
                    .frame(width: 240, height: 240)
                    .allowsHitTesting(false)
            }
        }
        .scaleEffect(pop ? 1.06 : 1)
    }

    @ViewBuilder private func center(_ activities: [DailyActivity], done: Set<DailyActivity.Kind>, complete: Bool) -> some View {
        if complete {
            VStack(spacing: 2) {
                Image(systemName: "checkmark").font(.system(size: 26, weight: .heavy)).foregroundStyle(Palette.amber)
                    .symbolEffect(.bounce, value: burst)
                HStack(spacing: 3) {
                    Image(systemName: "flame.fill").font(.system(size: 10, weight: .bold))
                    Text("\(store.streak.current)").font(Typeface.number(12))
                }
                .foregroundStyle(Palette.flame)
                .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
            }
            .allowsHitTesting(false)
            .accessibilityHidden(true)
        } else {
            // The ring is a fixed 112 pt with a 90 pt hole: its words shrink to fit rather than grow past it
            // (VoiceOver and the rows carry the same facts at any size). "9 min left", not "9 min": the rows beside
            // it give each activity's own minutes, so the ring says these are what remain.
            let left = minutesLeft(activities.filter { !done.contains($0.kind) }.reduce(0) { $0 + $1.minutes })
            VStack(spacing: 0) {
                Text.fraction(done.count, activities.count).font(Typeface.hero(22)).foregroundStyle(Palette.ink)
                    .contentTransition(.numericText())
                    .heroNumeral(cap: .xxxLarge)
                left
                    .font(.caption).foregroundStyle(Palette.inkSoft)
                    .lineLimit(1).minimumScaleFactor(0.7)
            }
            .frame(maxWidth: 80)
            .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
            .allowsHitTesting(false)
            // The count and minutes left, read once for the whole card.
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text("\(done.count) of \(activities.count)"))
            .accessibilityValue(left)
        }
    }

    /// What is left of the set's time, as the ring reads it: "9 min left".
    private func minutesLeft(_ minutes: Int) -> Text {
        Text("\(minutesText(minutes)) left")
    }

    private func row(_ activity: DailyActivity, done: Bool, quest: Quest?) -> some View {
        let kind = activity.kind
        return Button { open(kind) } label: {
            HStack(spacing: 10) {
                rowIcon(kind, done: done)
                // The quest riding on the row shows its XP beside the name when the line has room (it nearly
                // always does); only at large text sizes does it move to the end of the line below.
                ViewThatFits(in: .horizontal) {
                    rowText(activity, done: done, quest: quest, xpBesideName: true)
                    rowText(activity, done: done, quest: quest, xpBesideName: false)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            // Every row is as tall as one with a line under its name, so the three sit evenly beside the ring
            // whether or not they carry a lesson title.
            .frame(minHeight: rowHeight)
            .contentShape(Rectangle())
        }
        .buttonStyle(PressScaleStyle())
        .accessibilityElement(children: .combine)
        .accessibilityHint(Text(kind.detail))
        .accessibilityValue(rowValue(done: done, quest: quest))
        .accessibilityIdentifier("daily.\(kind.rawValue)")
    }

    /// The name and minutes on one line (with the quest's XP beside the name when `xpBesideName`), and under
    /// them the lesson's title for the lesson rep (with the XP at the end of that line otherwise).
    private func rowText(_ activity: DailyActivity, done: Bool, quest: Quest?, xpBesideName: Bool) -> some View {
        let kind = activity.kind
        let locked = kind.needsPro && !commerce.isPro
        let lesson = kind == .lesson ? store.dailyLesson : nil
        let belowXP = xpBesideName ? nil : quest
        return VStack(alignment: .leading, spacing: 2) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                rowTitle(kind, done: done)
                if kind == .review && !done { ReviewDueBadge(count: store.dailyReviewDueCount) }  // spaced review (Learn/WeakSpotReview.swift)
                if xpBesideName, let quest { xpTag(quest) }
                Spacer(minLength: 4)
                if locked {
                    ProBadge()
                } else {
                    minutesText(activity.minutes).font(Typeface.number(13)).foregroundStyle(done ? Palette.mint : Palette.inkSoft)
                        .lineLimit(1).fixedSize()
                }
            }
            if lesson != nil || belowXP != nil {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    if let lesson {
                        // Takes the line's width without asking for it, so a long title never decides where the XP goes.
                        Text(lesson.title.localized).font(.footnote).foregroundStyle(Palette.inkSoft).lineLimit(1)
                            .frame(minWidth: 0, idealWidth: 0, maxWidth: .infinity, alignment: .leading)
                    } else {
                        Spacer(minLength: 0)
                    }
                    if let belowXP { xpTag(belowXP) }
                }
            }
        }
    }

    /// The kind's symbol, or a check once done (so done reads by shape, not only by fill).
    private func rowIcon(_ kind: DailyActivity.Kind, done: Bool) -> some View {
        Image(systemName: done ? "checkmark" : kind.symbol).font(.system(size: 11, weight: .bold))
            .foregroundStyle(done ? Palette.onAccent : kind.tint)
            .frame(width: 26, height: 26)
            .background(Circle().fill(done ? AnyShapeStyle(kind.tint) : AnyShapeStyle(kind.tint.opacity(0.14))))
            .contentTransition(.symbolEffect(.replace))
    }

    /// One line: a short name keeps its size, a long one (or a large text size) shrinks a little before it truncates.
    private func rowTitle(_ kind: DailyActivity.Kind, done: Bool) -> some View {
        Text(kind == .lesson && done ? LocalizedStringKey("Lesson") : kind.rowTitle).font(.subheadline.weight(.semibold))
            .foregroundStyle(done ? Palette.inkSoft : Palette.ink)
            .strikethrough(done, color: Palette.inkFaint)
            .lineLimit(1).minimumScaleFactor(0.8)
            .layoutPriority(1)
    }

    /// The quest's XP as a small pill that fills as the quest does (its progress bar and its reward in one),
    /// ticked once it has paid today. 12 pt like every other XP pill: at 10 it was the hardest text on the card to read.
    private func xpTag(_ quest: Quest) -> some View {
        let count = store.questCounter(quest)
        let claimed = store.questProgress(quest) >= quest.target
        let progress = claimed ? 1 : min(1, Double(count.done) / Double(max(1, count.total)))
        return HStack(spacing: 2) {
            if claimed { Image(systemName: "checkmark").font(.system(size: 9, weight: .heavy)) }
            Text("+\(quest.xp) XP")
        }
        .font(Typeface.label(12)).foregroundStyle(Palette.mint.opacity(claimed ? 0.8 : 1))
        .padding(.horizontal, 7).padding(.vertical, 2)
        .background { QuestPillFill(progress: progress) }
        .fixedSize()
    }

    /// "Done", and the riding quest with its count ("Get 10 ear questions right: 3 of 10").
    private func rowValue(done: Bool, quest: Quest?) -> Text {
        let state = done ? Text("Done") : Text(verbatim: "")
        guard let quest else { return state }
        let count = store.questCounter(quest)
        let side = Text(quest.title) + Text(verbatim: ": ") + Text("\(count.done) of \(count.total)")
        return done ? state + Text(verbatim: ", ") + side : side
    }

    /// Plays the completion once a day, when the card is on screen: sparks, a chime, a haptic, a little pop.
    private func celebrateIfNeeded(_ complete: Bool) {
        guard complete, celebratedDay != store.todayKey else { return }
        celebratedDay = store.todayKey
        let still = reduceMotion
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(350))
            burst += 1
            SoundFX.shared.play(.complete)
            Haptics.shared.done()
            guard !still else { return }
            withAnimation(Motion.pluck) { pop = true }
            try? await Task.sleep(for: .milliseconds(220))
            withAnimation(Motion.settle) { pop = false }
        }
    }
}

/// The XP pill's ground: a faint mint capsule, filled from the leading end as far as the quest has got.
private struct QuestPillFill: View {
    let progress: Double

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule().fill(Palette.mint.opacity(0.1))
                Rectangle().fill(Palette.mint.opacity(0.2))
                    .frame(width: proxy.size.width * CGFloat(max(0, min(1, progress))))
            }
            .clipShape(Capsule())
        }
        .overlay(Capsule().strokeBorder(Palette.mint.opacity(0.28), lineWidth: 1))
        .animation(Motion.settle, value: progress)
        .accessibilityHidden(true)
    }
}

// MARK: - Compact card (Learn)

/// Today in one line, for the Learn tab's header area: the small ring with how many are done, "Today", and
/// what is left. A tap opens the lesson when that is next, otherwise the Play hub (or `action`).
struct DailySetCompactCard: View {
    @EnvironmentObject private var store: AppStore
    var action: (() -> Void)? = nil
    /// The lesson rep follows Learn's course; reading it here redraws the card when that changes.
    @AppStorage("learn.course") private var learnCourseId = "guitar"

    var body: some View {
        let activities = store.dailySet
        let done = Set(activities.map(\.kind).filter { store.dailyDone($0) })
        let complete = store.dailySetComplete
        let left = activities.filter { !done.contains($0.kind) }
        Button {
            if let action { action(); Haptics.shared.selection() } else { openNext(left.first) }
        } label: {
            HStack(spacing: 12) {
                ZStack {
                    DailySetRing(activities: activities, done: done, lineWidth: 5, gap: 0.08)
                    if complete {
                        Image(systemName: "checkmark").font(.system(size: 13, weight: .heavy)).foregroundStyle(Palette.amber)
                    } else {
                        // Inside a 40 pt ring: shrinks to fit rather than growing past it.
                        Text.fraction(done.count, activities.count).font(Typeface.number(10)).foregroundStyle(Palette.ink)
                            .heroNumeral(cap: .xxxLarge, minimumScale: 0.6)
                            .frame(width: 28)
                    }
                }
                .frame(width: 40, height: 40)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(complete ? Text("Done") : Text("\(done.count) of \(activities.count)"))
                VStack(alignment: .leading, spacing: 2) {
                    Text("Today").font(Typeface.display(15)).foregroundStyle(Palette.ink)
                    subtitle(left, complete: complete)
                }
                Spacer(minLength: 8)
                Image(systemName: "chevron.right").font(.footnote.weight(.bold)).foregroundStyle(Palette.inkFaint)
                    .accessibilityHidden(true)
            }
            .stillCard(cornerRadius: Metrics.cornerTile, padding: Metrics.tilePadding, tint: complete ? Palette.amber : nil)
        }
        .buttonStyle(PressScaleStyle())
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
        .accessibilityIdentifier("daily.compact")
    }

    /// "Done", or what is left, in order ("Lesson · Tune up · Ear training"); the lesson itself is named on
    /// Learn's Continue card right below, and the count sits in the ring.
    @ViewBuilder private func subtitle(_ left: [DailyActivity], complete: Bool) -> some View {
        if complete || left.isEmpty {
            Text("Done").font(.caption).foregroundStyle(Palette.amber)
        } else {
            let names = left.map { (activity: DailyActivity) -> Text in activity.kind == .lesson ? Text("Lesson") : Text(activity.kind.title) }
            names.dropFirst().reduce(names[0]) { (line: Text, name: Text) -> Text in line + Text(verbatim: " · ") + name }
                .font(.caption).foregroundStyle(Palette.inkSoft).lineLimit(1)
        }
    }

    private func openNext(_ next: DailyActivity?) {
        if next?.kind == .lesson {
            store.openDailyLesson()
        } else {
            store.selectedTab = .practice
            Haptics.shared.selection()
        }
    }
}
