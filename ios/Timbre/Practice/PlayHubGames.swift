import SwiftUI
import TimbreCore

// The Play hub's ear games as live cards: each game idles in a small preview of itself (Pitch Sniper's scope,
// the ear trainer's interval staircase) beside its best score, its level and today's challenge with the XP it
// pays, all read from saved progress. One timeline per card, paused off screen, still under Reduce Motion.

// MARK: - Liveness

extension View {
    /// Keeps `visible` true only while this view is on screen: inside its scroll view's visible bounds and not
    /// covered by a pushed screen or another tab. Live previews pause their timelines on it.
    func liveWhileVisible(_ visible: Binding<Bool>) -> some View {
        modifier(LiveWhileVisible(visible: visible))
    }
}

private struct LiveWhileVisible: ViewModifier {
    @Binding var visible: Bool
    /// Inside the scroll view's visible bounds (true outside a scroll view).
    @State private var inView = true
    /// Between appearing and disappearing (a pushed screen or another tab hides it).
    @State private var shown = false

    func body(content: Content) -> some View {
        content
            .onGeometryChange(for: Bool.self) { proxy in
                guard let viewport = proxy.bounds(of: .scrollView) else { return true }
                return viewport.intersects(CGRect(origin: .zero, size: proxy.size))
            } action: { value in
                inView = value
                visible = shown && value
            }
            .onAppear { shown = true; visible = inView }
            .onDisappear { shown = false; visible = false }
    }
}

// MARK: - Stats

/// Today's challenge on a game card: the day's quest for that game when there is one (with the quest's XP, as
/// its row says), else the game's everyday goal and the XP it pays anyway, counted from today's saved progress.
struct GameChallenge {
    let title: Text
    let xp: Int
    let done: Int
    let total: Int
    /// The game whose card this is: its leaderboard chip, and Pitch Sniper's challenge to a friend.
    var game: PlayGame? = nil
    var complete: Bool { done >= total }
    var fraction: Double { Double(min(done, total)) / Double(max(1, total)) }

    /// Today's saved count for a quest kind: it counts every day, whether or not it is one of today's quests.
    @MainActor private static func today(_ kind: Quest.Kind, in store: AppStore) -> Int {
        let progress = store.progress
        guard progress.questDay == Quests.dayKey(Date()) else { return 0 }
        return max(0, progress.questProgress[kind.rawValue] ?? 0)
    }

    /// A won round (or today's bullseye quest).
    @MainActor static func sniper(_ store: AppStore) -> GameChallenge {
        if let quest = store.quests.first(where: { $0.kind == .sniperWin || $0.kind == .bullseyes }) {
            let count = store.questCounter(quest)
            let title = quest.kind == .sniperWin ? Text("Win a round") : Text("Hit \(quest.target) bullseyes")
            return GameChallenge(title: title, xp: quest.xp, done: count.done, total: count.total, game: .sniper)
        }
        return GameChallenge(title: Text("Win a round"), xp: XPReward.sniperWin, done: min(1, today(.sniperWin, in: store)), total: 1,
                             game: .sniper)
    }

    /// Ten right answers, a full round's worth (or today's ear quest).
    @MainActor static func ear(_ store: AppStore) -> GameChallenge {
        if let quest = store.quests.first(where: { $0.kind == .earCorrect }) {
            let count = store.questCounter(quest)
            return GameChallenge(title: Text("Get \(quest.target) right"), xp: quest.xp, done: count.done, total: count.total, game: .ear)
        }
        let round = 10
        return GameChallenge(title: Text("Get \(round) right"), xp: round * XPReward.earCorrect,
                             done: min(round, today(.earCorrect, in: store)), total: round, game: .ear)
    }
}

/// Pitch Sniper's level, from lifetime bullseyes: level 2 at the first, then further apart.
enum SniperRank {
    static let floors = [0, 1, 6, 15, 30, 50, 80, 120, 175, 250, 350, 500]
    static func level(bullseyes: Int) -> Int {
        (floors.lastIndex { $0 <= max(0, bullseyes) } ?? 0) + 1
    }
}

// MARK: - Card

/// A game on the Play hub: its name, best score and level, and today's challenge with its XP on the left; the
/// game idling on the right, lit by the game's colour.
struct PlayGameCard<Preview: View>: View {
    let title: LocalizedStringKey
    let stats: Text
    let challenge: GameChallenge
    let tint: Color
    /// The live preview; its argument says whether it may move (on screen).
    @ViewBuilder let preview: (Bool) -> Preview
    @State private var visible = false
    @EnvironmentObject private var store: AppStore
    @ObservedObject private var center = GameCenter.shared

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 24, style: .continuous)
        // The preview rides behind the words at the card's full height, on the side the words leave free.
        return info
            .padding(.trailing, Self.previewWidth)
            .frame(maxWidth: .infinity, minHeight: 158, alignment: .leading)
            .background(alignment: .trailing) {
                preview(visible)
                    .frame(width: Self.previewWidth)
                    .accessibilityHidden(true)
            }
            .background {
                ZStack {
                    shape.fill(Palette.stageRaised)
                    shape.fill(RadialGradient(colors: [tint.opacity(0.2), .clear], center: UnitPoint(x: 0.84, y: 0.45), startRadius: 0, endRadius: 180))
                }
            }
            .overlay(shape.strokeBorder(tint.opacity(0.16), lineWidth: 1))
            // The leaderboard and a challenge to a friend sit in the preview's top corner, clear of the words.
            .overlay(alignment: .topTrailing) {
                if let game = challenge.game { GameCardCorner(game: game) }
            }
            .clipShape(shape)
            .contentShape(shape)
            .liveWhileVisible($visible)
            // The games are where Game Center belongs: it signs in (quietly) the first time they show.
            .onAppear { GameCenter.shared.activate(store) }
    }

    private static var previewWidth: CGFloat { 148 }

    private var info: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title).font(Typeface.display(19)).foregroundStyle(Palette.ink)
                .lineLimit(1).minimumScaleFactor(0.75)
            stats.font(.caption).foregroundStyle(Palette.inkSoft)
                .lineLimit(1).minimumScaleFactor(0.75)
            if challenge.game == .sniper, let friend = center.challenge {
                FriendTargetLine(challenge: friend)
            }
            Spacer(minLength: 12)
            ChallengeChip(challenge: challenge)
        }
        .padding(.leading, 16).padding(.trailing, 4).padding(.vertical, 16)
        .accessibilityElement(children: .combine)
    }
}

/// A friend's challenge on the Pitch Sniper card: "Beat 1,650" until a game passes it, then "1,650 beaten".
private struct FriendTargetLine: View {
    let challenge: SniperChallenge

    var body: some View {
        let beaten = challenge.beaten
        HStack(spacing: 5) {
            Image(systemName: beaten ? "checkmark.circle.fill" : "flag.checkered")
                .font(.system(size: 10, weight: .bold))
                .accessibilityHidden(true)
            if beaten {
                Text("\(challenge.target) beaten")
            } else {
                Text("Beat \(challenge.target)")
            }
        }
        .font(Typeface.label(12))
        .foregroundStyle(beaten ? Palette.mint : Palette.amber)
        .lineLimit(1).minimumScaleFactor(0.8)
        .padding(.top, 2)
        .transition(.opacity.combined(with: .scale(scale: 0.9, anchor: .leading)))
    }
}

/// The game card's corner: Pitch Sniper's "Challenge" once there is a best to send (the best on a card, with a link that
/// opens the game with it to beat), and the game's Game Center leaderboard once Game Center is on and has the board,
/// with this week's rank on Pitch Sniper's.
private struct GameCardCorner: View {
    let game: PlayGame
    @EnvironmentObject private var store: AppStore
    @ObservedObject private var center = GameCenter.shared

    var body: some View {
        let best = game == .sniper ? store.progress.stats["sniperBest"] ?? 0 : 0
        let board = center.leaderboard(for: game)
        HStack(spacing: 6) {
            if best > 0 { ChallengeShareButton(score: best) }
            if board != nil { leaderboardButton }
        }
        .padding(10)
        .animation(Motion.settle, value: board)
    }

    private var rank: Int? { game == .sniper ? center.weeklyRank : nil }

    private var leaderboardButton: some View {
        Button {
            Haptics.shared.selection()
            center.showLeaderboard(game)
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "trophy.fill").font(.system(size: 11, weight: .bold))
                if let rank { Text(verbatim: "#\(rank)").font(Typeface.label(11)).monospacedDigit() }
            }
            .foregroundStyle(Palette.amber)
            .padding(.horizontal, 9)
            .frame(minWidth: 32, minHeight: 32)
            .background(Capsule().fill(Palette.stage.opacity(0.78)))
            .overlay(Capsule().strokeBorder(Palette.amber.opacity(0.32), lineWidth: 1))
            .contentShape(Capsule().inset(by: -6))
        }
        .buttonStyle(PressScaleStyle())
        .transition(.scale(scale: 0.6).combined(with: .opacity))
        .accessibilityLabel(Text("Leaderboard"))
        .accessibilityValue(rank.map { Text("Rank \($0) this week") } ?? Text(verbatim: ""))
        .accessibilityIdentifier("practice.\(game.rawValue).leaderboard")
    }
}

/// "Challenge": the best score as a "Beat my score" card for the share sheet, sent with the link that opens Pitch
/// Sniper with it to beat. The card is drawn a moment after the hub settles, again only when the best changes.
private struct ChallengeShareButton: View {
    let score: Int
    @State private var card: Image?
    @Environment(\.displayScale) private var displayScale
    @Environment(\.locale) private var locale
    @Environment(\.layoutDirection) private var layoutDirection

    var body: some View {
        Group {
            if let card {
                ShareLink(item: card, subject: Text("Beat my score"), message: Text(verbatim: SniperChallenge.message(score: score)),
                          preview: SharePreview("Beat my score", image: card)) { label }
                    .buttonStyle(PressScaleStyle())
            } else {
                label.opacity(0.45)
            }
        }
        .accessibilityLabel(Text("Challenge a friend"))
        .accessibilityIdentifier("practice.sniper.challenge")
        .task(id: score) {
            try? await Task.sleep(for: ShareCardRenderer.entrance)
            guard !Task.isCancelled else { return }
            card = ShareCardRenderer.image(SniperChallengeCard(score: score), scale: displayScale, locale: locale, direction: layoutDirection)
        }
    }

    private var label: some View {
        Image(systemName: "paperplane.fill").font(.system(size: 11, weight: .bold))
            .foregroundStyle(Palette.mint)
            .frame(width: 32, height: 32)
            .background(Circle().fill(Palette.stage.opacity(0.78)))
            .overlay(Circle().strokeBorder(Palette.mint.opacity(0.32), lineWidth: 1))
            .contentShape(Circle().inset(by: -6))
    }
}

// MARK: - Challenges

/// "Beat my score": a Pitch Sniper best as a poster for the share sheet: the scope with a pitch held in the bullseye,
/// the score in gold under it. Only the score, never a name.
struct SniperChallengeCard: View {
    let score: Int

    var body: some View {
        ShareCardFrame(glow: Palette.mint, signature: true) {
            Label("Pitch Sniper", systemImage: "scope").font(Typeface.label(12)).foregroundStyle(Palette.mint)
        } content: {
            Canvas { context, size in
                SniperScopeArt.draw(&context, size: size, t: SniperScopeArt.stillTime)
            }
            .frame(width: 210, height: 210)
            VStack(spacing: 2) {
                Text("Beat my score").font(Typeface.display(34)).tracking(-0.8).foregroundStyle(Palette.ink)
                Text(score, format: .number).font(Typeface.number(64)).foregroundStyle(Palette.amber)
                    .shadow(color: Palette.amber.opacity(0.35), radius: 16)
            }
            Text("Play the note. Hold the bullseye.").font(.headline).foregroundStyle(Palette.inkSoft)
        }
    }
}

/// Pitch Sniper's header while a friend's challenge stands: "Beat 1,650" in amber, mint and ticked once this game passes it.
struct SniperChallengeTarget: View {
    /// This game's score so far.
    let score: Int
    @ObservedObject private var center = GameCenter.shared

    var body: some View {
        if let challenge = center.challenge {
            let passed = score > challenge.target
            HStack(spacing: 4) {
                Image(systemName: passed ? "checkmark" : "flag.checkered").font(.system(size: 9, weight: .heavy))
                    .accessibilityHidden(true)
                if passed {
                    Text("\(challenge.target) beaten")
                } else {
                    Text("Beat \(challenge.target)")
                }
            }
            .font(Typeface.label(11))
            .foregroundStyle(passed ? Palette.mint : Palette.amber)
            .lineLimit(1).minimumScaleFactor(0.8)
            .contentTransition(.opacity)
            .animation(Motion.quick, value: passed)
        }
    }
}

/// Under Pitch Sniper's result while a friend's challenge stands: "You beat 1,650" and "Send it back" (this game's score
/// as the next challenge), or how many points it fell short by.
struct SniperChallengeResult: View {
    /// The finished game's score.
    let score: Int
    @ObservedObject private var center = GameCenter.shared
    @State private var card: Image?
    @Environment(\.displayScale) private var displayScale
    @Environment(\.locale) private var locale
    @Environment(\.layoutDirection) private var layoutDirection

    var body: some View {
        if let challenge = center.challenge {
            Group {
                if score > challenge.target {
                    beaten(challenge.target)
                } else {
                    Text("\(challenge.target - score + 1) more to beat \(challenge.target)")
                        .font(.footnote.weight(.semibold)).foregroundStyle(Palette.amber)
                }
            }
            .task(id: score) {
                guard score > challenge.target else { return }
                try? await Task.sleep(for: ShareCardRenderer.entrance)
                guard !Task.isCancelled else { return }
                card = ShareCardRenderer.image(SniperChallengeCard(score: score), scale: displayScale, locale: locale, direction: layoutDirection)
            }
        }
    }

    private func beaten(_ target: Int) -> some View {
        VStack(spacing: 10) {
            Label { Text("You beat \(target)") } icon: { Image(systemName: "flag.checkered") }
                .font(Typeface.label(16)).foregroundStyle(Palette.mint)
            if let card {
                ShareLink(item: card, subject: Text("Beat my score"), message: Text(verbatim: SniperChallenge.message(score: score)),
                          preview: SharePreview("Beat my score", image: card)) {
                    Label("Send it back", systemImage: "paperplane.fill")
                        .font(Typeface.label(14)).foregroundStyle(Palette.onAccent)
                        .padding(.horizontal, 16).frame(minHeight: 40)
                        .background(Capsule().fill(Palette.mint))
                }
                .buttonStyle(PressScaleStyle())
                .accessibilityIdentifier("sniper.challenge.reply")
                .transition(.opacity.combined(with: .scale(scale: 0.9)))
            }
        }
        .animation(Motion.settle, value: card != nil)
    }
}

/// "Today’s challenge", then its goal, a ring of today's progress toward it and the XP it pays (ticked once done).
private struct ChallengeChip: View {
    let challenge: GameChallenge

    var body: some View {
        let complete = challenge.complete
        VStack(alignment: .leading, spacing: 5) {
            Text("Today’s challenge").font(Typeface.eyebrow).tracking(1.2).textCase(.uppercase)
                .foregroundStyle(complete ? Palette.mint : Palette.amber)
                .lineLimit(1).minimumScaleFactor(0.7)
            HStack(spacing: 8) {
                ring(complete: complete)
                challenge.title.font(.footnote.weight(.semibold))
                    .foregroundStyle(complete ? Palette.inkSoft : Palette.ink)
                    .strikethrough(complete, color: Palette.inkFaint)
                    .lineLimit(2).minimumScaleFactor(0.85)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                xp(complete: complete)
            }
            .padding(.leading, 8).padding(.trailing, 6).padding(.vertical, 7)
            .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(.white.opacity(0.05)))
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(.white.opacity(0.07), lineWidth: 1))
        }
        .accessibilityElement(children: .combine)
        .accessibilityValue(Text("\(min(challenge.done, challenge.total)) of \(challenge.total)"))
    }

    private func ring(complete: Bool) -> some View {
        ZStack {
            Circle().stroke(.white.opacity(0.12), lineWidth: 2.5)
            Circle().trim(from: 0, to: max(0.001, challenge.fraction))
                .stroke(Palette.mint, style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .opacity(challenge.fraction > 0 ? 1 : 0)
            if complete {
                Image(systemName: "checkmark").font(.system(size: 8, weight: .heavy)).foregroundStyle(Palette.mint)
            }
        }
        .frame(width: 18, height: 18)
        .animation(Motion.settle, value: challenge.fraction)
        .accessibilityHidden(true)
    }

    private func xp(complete: Bool) -> some View {
        HStack(spacing: 2) {
            if complete { Image(systemName: "checkmark").font(.system(size: 8, weight: .heavy)) }
            Text("+\(challenge.xp) XP")
        }
        .font(Typeface.label(11)).foregroundStyle(Palette.mint.opacity(complete ? 0.7 : 1))
        .padding(.horizontal, 7).padding(.vertical, 4)
        .background(Capsule().fill(Palette.mint.opacity(0.12)))
        .overlay(Capsule().strokeBorder(Palette.mint.opacity(0.25), lineWidth: 1))
        .fixedSize()
    }
}

// MARK: - Pitch Sniper preview

/// Pitch Sniper idling: the scope's cents rings under a slow radar sweep, a pitch dot drifting in from the edge,
/// settling in the bullseye while the hold arc fills, a flash as it scores; then another from a new angle.
struct SniperScopePreview: View {
    var live = true
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30, paused: !live || reduceMotion)) { timeline in
            let t = reduceMotion ? SniperScopeArt.stillTime : timeline.date.timeIntervalSinceReferenceDate
            Canvas { context, size in
                SniperScopeArt.draw(&context, size: size, t: t)
            }
        }
        .accessibilityHidden(true)
    }
}

enum SniperScopeArt {
    /// One shot: in from the edge, held in the bullseye, scored.
    static let period = 5.2
    /// Reduce Motion's frame: the dot in the bullseye with its hold arc a third full.
    static let stillTime = period * 0.63

    static func draw(_ context: inout GraphicsContext, size: CGSize, t: Double) {
        let c = CGPoint(x: size.width / 2, y: size.height / 2)
        let r = max(12, min(size.width, size.height) / 2 - 8)
        let bull = r * 0.15
        context.fill(circle(c, r * 1.2), with: .radialGradient(Gradient(colors: [Palette.mint.opacity(0.13), .clear]),
                                                                center: c, startRadius: 0, endRadius: r * 1.2))
        // 50, 20 and 5 cents out from the bullseye: the game's own rings.
        context.stroke(circle(c, r), with: .color(.white.opacity(0.11)), lineWidth: 1)
        context.stroke(circle(c, r * 0.71), with: .color(.white.opacity(0.09)), lineWidth: 1)
        context.stroke(circle(c, r * 0.4), with: .color(Palette.amber.opacity(0.45)), lineWidth: 1)
        for (dx, dy) in [(0.0, -1.0), (0.0, 1.0), (-1.0, 0.0), (1.0, 0.0)] {
            var tick = Path()
            tick.move(to: CGPoint(x: c.x + CGFloat(dx) * r * 1.06, y: c.y + CGFloat(dy) * r * 1.06))
            tick.addLine(to: CGPoint(x: c.x + CGFloat(dx) * r * 0.8, y: c.y + CGFloat(dy) * r * 0.8))
            context.stroke(tick, with: .color(.white.opacity(0.2)), lineWidth: 1)
        }

        let sweepAngle = t * 1.7
        sweep(&context, center: c, radius: r, angle: sweepAngle)

        let shot = shotState(t: t)
        let p = CGPoint(x: c.x + CGFloat(cos(shot.angle) * shot.distance) * r, y: c.y + CGFloat(sin(shot.angle) * shot.distance) * r)
        let inside = shot.distance * Double(r) <= Double(bull)
        context.fill(circle(c, bull), with: .color(Palette.mint.opacity(0.16 + 0.4 * shot.flash)))
        context.stroke(circle(c, bull), with: .color(Palette.mint), lineWidth: 1.5)
        if shot.flash > 0 {
            let radius = bull + CGFloat(1 - shot.flash) * r * 0.7
            context.stroke(circle(c, radius), with: .color(Palette.mint.opacity(0.8 * shot.flash)), lineWidth: 2)
        }
        if shot.hold > 0 {
            var arc = Path()
            arc.addArc(center: c, radius: bull + 6, startAngle: .degrees(-90), endAngle: .degrees(-90 + 360 * shot.hold), clockwise: false)
            context.stroke(arc, with: .color(Palette.mint), style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
        }
        guard shot.alpha > 0 else { return }
        // A blip as the sweep passes over the dot.
        let gap = abs((sweepAngle - shot.angle).remainder(dividingBy: 2 * Double.pi))
        let blip = shot.distance > 0.08 ? max(0, 1 - gap / 0.7) : 0
        let tint = inside ? Palette.mint : Palette.amber
        let halo = CGFloat(15 + 7 * blip)
        context.fill(circle(p, halo), with: .radialGradient(Gradient(colors: [tint.opacity((0.55 + 0.3 * blip) * shot.alpha), .clear]),
                                                            center: p, startRadius: 0, endRadius: halo))
        context.fill(circle(p, 5.5), with: .color(tint.opacity(shot.alpha)))
    }

    /// Where the dot is in its shot: distance from the centre (share of the outer ring), angle, the hold arc,
    /// the score flash and how visible it is.
    private struct Shot {
        var distance = 0.0
        var angle = 0.0
        var hold = 0.0
        var flash = 0.0
        var alpha = 1.0
    }

    private static func shotState(t: Double) -> Shot {
        let index = floor(t / period)
        let u = (t - index * period) / period
        // Each shot comes in from a new side (the golden angle apart).
        let start = index.truncatingRemainder(dividingBy: 97) * 2.399963
        let approach = 0.55, holdEnd = 0.8
        var shot = Shot()
        if u < approach {
            let f = u / approach
            let eased = 1 - pow(1 - f, 3)
            shot.distance = max(0, 0.9 * (1 - eased) + 0.05 * sin(f * 9) * (1 - f))
            shot.angle = start + 1.1 * f + 0.25 * sin(f * 7)
            shot.alpha = min(1, f * 6)
        } else if u < holdEnd {
            shot.distance = 0.02 + 0.02 * sin(t * 9)
            shot.angle = start + 1.1 + t * 2
            shot.hold = (u - approach) / (holdEnd - approach)
        } else {
            let f = (u - holdEnd) / (1 - holdEnd)
            shot.flash = 1 - f
            shot.alpha = max(0, 1 - f * 2.5)
            shot.angle = start + 1.1
        }
        return shot
    }

    /// The radar sweep: a wedge that fades behind its leading edge.
    private static func sweep(_ context: inout GraphicsContext, center c: CGPoint, radius r: CGFloat, angle: Double) {
        let steps = 12, span = 0.95
        for i in 0..<steps {
            let from = angle - span * Double(i + 1) / Double(steps)
            let to = angle - span * Double(i) / Double(steps)
            var wedge = Path()
            wedge.move(to: c)
            wedge.addArc(center: c, radius: r, startAngle: .radians(from), endAngle: .radians(to), clockwise: false)
            wedge.closeSubpath()
            context.fill(wedge, with: .color(Palette.mint.opacity(0.15 * (1 - Double(i) / Double(steps)))))
        }
        let end = CGPoint(x: c.x + CGFloat(cos(angle)) * r, y: c.y + CGFloat(sin(angle)) * r)
        var edge = Path()
        edge.move(to: c)
        edge.addLine(to: end)
        context.stroke(edge, with: .linearGradient(Gradient(colors: [Palette.mint.opacity(0), Palette.mint.opacity(0.75)]), startPoint: c, endPoint: end), lineWidth: 1.5)
    }

    static func circle(_ center: CGPoint, _ radius: CGFloat) -> Path {
        Path(ellipseIn: CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2))
    }
}

// MARK: - Ear trainer preview

/// The ear trainer idling: a major scale as a staircase of intervals from the root (half steps rise half as far),
/// a note hopping up it one step at a time, its interval to the root drawn as an arc and named (P1 … P8).
struct IntervalStairsPreview: View {
    var live = true
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30, paused: !live || reduceMotion)) { timeline in
            let t = reduceMotion ? IntervalStairsArt.stillTime : timeline.date.timeIntervalSinceReferenceDate
            Canvas { context, size in
                IntervalStairsArt.draw(&context, size: size, t: t)
            }
        }
        .accessibilityHidden(true)
    }
}

enum IntervalStairsArt {
    /// The major scale from the root: unison, major second … octave.
    static let semitones = [0, 2, 4, 5, 7, 9, 11, 12]
    static let hop = 0.42
    static let rest = 1.2
    static var climb: Double { Double(semitones.count - 1) * hop }
    static var period: Double { climb + rest }
    /// Reduce Motion's frame: the note resting on the fifth.
    static let stillTime = hop * 3.9

    private struct Layout {
        let inset: CGFloat
        let stepWidth: CGFloat
        let floorY: CGFloat
        let rise: CGFloat
        func centerX(_ i: Int) -> CGFloat { inset + stepWidth * (CGFloat(i) + 0.5) }
        func top(_ i: Int) -> CGFloat { floorY - 8 - CGFloat(IntervalStairsArt.semitones[i]) / 12 * rise }
    }

    static func draw(_ context: inout GraphicsContext, size: CGSize, t: Double) {
        let count = semitones.count
        let inset: CGFloat = 10
        let floorY = size.height - 16
        let layout = Layout(inset: inset, stepWidth: (size.width - inset * 2) / CGFloat(count), floorY: floorY, rise: max(24, floorY - 52))
        let u = max(0, t).truncatingRemainder(dividingBy: period)
        let fade = u > climb + rest * 0.7 ? max(0, 1 - (u - climb - rest * 0.7) / (rest * 0.3)) : 1
        let noteR: CGFloat = 5.5

        // The steps, lit as the note lands on them and staying faintly lit behind it.
        for i in 0..<count {
            let since = u - landing(i)
            let lit = since >= 0 ? max(0.22, exp(-since / 0.55)) * fade : 0
            let x = layout.centerX(i) - layout.stepWidth / 2 + 1.5
            let rect = CGRect(x: x, y: layout.top(i), width: layout.stepWidth - 3, height: max(4, floorY - layout.top(i)))
            context.fill(Path(roundedRect: rect, cornerRadius: 4), with: .linearGradient(
                Gradient(colors: [Palette.amber.opacity(0.1 + 0.32 * lit), Palette.amber.opacity(0.02)]),
                startPoint: CGPoint(x: rect.midX, y: rect.minY), endPoint: CGPoint(x: rect.midX, y: rect.maxY)))
            var edge = Path()
            edge.move(to: CGPoint(x: rect.minX + 2, y: rect.minY))
            edge.addLine(to: CGPoint(x: rect.maxX - 2, y: rect.minY))
            context.stroke(edge, with: .color(Palette.amber.opacity(0.3 + 0.6 * lit)), style: StrokeStyle(lineWidth: 2, lineCap: .round))
        }
        var floorLine = Path()
        floorLine.move(to: CGPoint(x: inset, y: floorY))
        floorLine.addLine(to: CGPoint(x: size.width - inset, y: floorY))
        context.stroke(floorLine, with: .color(.white.opacity(0.07)), lineWidth: 1)

        // The note: hopping step to step, or resting at the octave before it starts again.
        let note: CGPoint
        let current: Int
        if u < climb {
            let i = min(count - 2, Int(u / hop))
            let f = (u - Double(i) * hop) / hop
            let air = min(1, f / 0.7)
            let eased = air * air * (3 - 2 * air)
            let from = CGPoint(x: layout.centerX(i), y: layout.top(i) - noteR - 1)
            let to = CGPoint(x: layout.centerX(i + 1), y: layout.top(i + 1) - noteR - 1)
            note = CGPoint(x: from.x + (to.x - from.x) * CGFloat(eased),
                           y: from.y + (to.y - from.y) * CGFloat(air) - 16 * CGFloat(sin(Double.pi * air)))
            current = air >= 1 ? i + 1 : i
        } else {
            current = count - 1
            note = CGPoint(x: layout.centerX(current), y: layout.top(current) - noteR - 1)
        }

        // The interval to the root: an arc from the first step to the note, named.
        let root = CGPoint(x: layout.centerX(0), y: layout.top(0) - noteR - 1)
        if current > 0 || note.x > root.x + 2 {
            var arc = Path()
            arc.move(to: root)
            arc.addQuadCurve(to: note, control: CGPoint(x: (root.x + note.x) / 2, y: min(root.y, note.y) - 24))
            context.stroke(arc, with: .color(Palette.amber.opacity(0.45 * fade)), style: StrokeStyle(lineWidth: 1.5, lineCap: .round, dash: [3, 4]))
        }
        context.fill(SniperScopeArt.circle(root, 3), with: .color(Palette.amber.opacity(0.6 * fade)))

        let since = u - landing(current)
        if since >= 0 && since < 0.45 {
            let ripple = noteR + CGFloat(since / 0.45) * 14
            context.stroke(SniperScopeArt.circle(note, ripple), with: .color(Palette.amber.opacity(0.7 * (1 - since / 0.45) * fade)), lineWidth: 1.5)
        }
        context.fill(SniperScopeArt.circle(note, 15), with: .radialGradient(Gradient(colors: [Palette.amber.opacity(0.55 * fade), .clear]),
                                                                           center: note, startRadius: 0, endRadius: 15))
        context.fill(SniperScopeArt.circle(note, noteR), with: .color(Palette.amber.opacity(fade)))
        context.fill(SniperScopeArt.circle(CGPoint(x: note.x - 1.5, y: note.y - 1.5), 2), with: .color(.white.opacity(0.8 * fade)))

        let name = Intervals.short[semitones[current]]
        let label = Text(verbatim: name).font(Typeface.label(12)).foregroundStyle(Palette.amber.opacity(fade))
        let labelPoint = CGPoint(x: min(size.width - 16, max(16, note.x)), y: max(10, note.y - 20))
        context.draw(label, at: labelPoint, anchor: .center)
    }

    /// When the note lands on step `i` within the cycle (the first step is where it starts).
    private static func landing(_ i: Int) -> Double {
        i == 0 ? 0 : (Double(i - 1) + 0.7) * hop
    }
}
