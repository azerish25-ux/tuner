import SwiftUI
import TimbreCore

/// The last seven days, today included: minutes played each day, lessons finished, the closest tune and the streak.
struct WeekRecap: Equatable {
    struct Day: Equatable {
        let date: Date
        let minutes: Int
        let played: Bool
    }

    /// Oldest first; the last is today.
    let days: [Day]
    let minutes: Int
    let lessons: Int
    /// The closest tuning session's average distance from the target, in cents; nil without one this week.
    let bestCents: Double?
    let streak: Int

    init(records: [PracticeRecord], streak: StreakSummary, now: Date = Date(), calendar: Calendar = .current) {
        let today = calendar.startOfDay(for: now)
        let start = calendar.date(byAdding: .day, value: -6, to: today) ?? today
        let week = records.filter { $0.date >= start && $0.date <= now }
        let byDay = Dictionary(grouping: week, by: { calendar.startOfDay(for: $0.date) })
        days = (0..<7).map { offset in
            let date = calendar.date(byAdding: .day, value: offset, to: start) ?? start
            let ms = byDay[date]?.compactMap(\.durationMs).reduce(0, +) ?? 0
            return Day(date: date, minutes: Int((Double(ms) / 60_000).rounded()), played: byDay[date] != nil)
        }
        minutes = Int((Double(week.compactMap(\.durationMs).reduce(0, +)) / 60_000).rounded())
        lessons = week.filter { $0.kind == "lesson" }.count
        bestCents = week.filter { $0.kind == "tuning" }.compactMap(\.meanAbsoluteCents).min()
        self.streak = streak.current
    }

    var first: Date { days.first?.date ?? Date() }
    var last: Date { days.last?.date ?? Date() }
    var isEmpty: Bool { !days.contains(where: \.played) }

    /// "±0.6¢": how far from the target, either way; a dash without a reading.
    static func centsText(_ value: Double?) -> Text {
        guard let value else { return Text(verbatim: "—") }
        return Text(verbatim: "±") + Text(value, format: .number.precision(.fractionLength(1))) + Text(verbatim: "¢")
    }

    /// "Oct 17 – 23".
    var rangeText: Text {
        Text(first ..< max(last, first.addingTimeInterval(1)), format: .interval.month(.abbreviated).day())
    }
}

/// Progress's "Your week": the minutes (one bar a day, today marked), then the closest tune, the lessons and
/// the streak, with a poster of it to share. With Game Center friends (the player's yes), a line under the figures and
/// on the poster says where the streak stands among theirs (Services/GameCenterSocial.swift).
struct WeekRecapCard: View {
    let recap: WeekRecap
    @EnvironmentObject private var store: AppStore
    @ObservedObject private var center = GameCenter.shared
    @State private var poster: Image?
    @Environment(\.displayScale) private var displayScale
    @Environment(\.locale) private var locale
    @Environment(\.layoutDirection) private var layoutDirection
    @Environment(\.dynamicTypeSize) private var typeSize

    private var statsLayout: AnyLayout {
        typeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 10))
            : AnyLayout(HStackLayout(spacing: 6))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header
            HStack(alignment: .bottom, spacing: 12) {
                minutesBlock
                Spacer(minLength: 8)
                WeekBars(days: recap.days, height: 52, barWidth: 14)
                    .frame(maxWidth: 210)
                    .accessibilityHidden(true)
            }
            Hairline()
            // Three across; one per row at the accessibility sizes, where three would truncate.
            statsLayout {
                WeekStat(symbol: "scope", tint: Palette.amber, value: WeekRecap.centsText(recap.bestCents), label: Text("best tune-up"))
                WeekStat(symbol: "graduationcap.fill", tint: Palette.violet, value: Text(recap.lessons, format: .number), label: Text("lessons"))
                WeekStat(symbol: "flame.fill", tint: Palette.flame, value: Text(recap.streak, format: .number), label: Text("day streak"))
            }
            if friends != nil || center.friendsAccess == .ask { WeekFriendsRow(standing: friends) }
            // A member can pass a month of Pro on, once the owner has set up the offer code.
            if store.isPro { FriendOfferLink(screen: "week") }
        }
        .stillCard(tint: Palette.mint)
        .animation(Motion.fade, value: friends)
        .task(id: WeekPoster(recap: recap, friends: friends)) {
            poster = ShareCardRenderer.image(WeekShareCard(recap: recap, friends: friends), scale: displayScale, locale: locale,
                                             direction: layoutDirection)
        }
        // The streak's place among friends is read here (Game Center signs in quietly, as on the Practice tab's games).
        .task {
            GameCenter.shared.activate(store)
            GameCenter.shared.refreshFriends()
        }
    }

    /// Where the streak stands among Game Center friends on a streak; nil without them (or without the player's yes).
    private var friends: FriendStreak? {
        FriendStreak(mine: recap.streak, friends: center.friendStreaks)
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                CardTitle("Your week")
                recap.rangeText.font(.caption).foregroundStyle(Palette.inkSoft)
            }
            Spacer(minLength: 8)
            shareButton
        }
    }

    private var minutesBlock: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(recap.minutes, format: .number)
                .font(Typeface.hero(40)).foregroundStyle(Palette.ink)
                .contentTransition(.numericText(value: Double(recap.minutes)))
                .heroNumeral(minimumScale: 0.6)
            Text("minutes").font(.caption).foregroundStyle(Palette.inkSoft)
        }
        .fixedSize(horizontal: false, vertical: true)
        .accessibilityElement(children: .combine)
    }

    /// A 36 pt pill in a 44 pt target.
    private var shareLabel: some View {
        Label("Share", systemImage: "square.and.arrow.up")
            .font(Typeface.label(13)).foregroundStyle(Palette.mint)
            .padding(.horizontal, 12).frame(minHeight: 36)
            .background(Capsule().fill(Palette.mint.opacity(0.12)))
            .overlay(Capsule().strokeBorder(Palette.mint.opacity(0.35), lineWidth: 1))
            .fixedSize()
            .frame(minHeight: Metrics.minTarget)
            .contentShape(Rectangle())
    }

    /// The poster goes with a link that opens Timbre, or its App Store page for a friend without it.
    @ViewBuilder private var shareButton: some View {
        if let poster {
            ShareLink(item: poster, message: ShareDestination.message(), preview: SharePreview("Your week", image: poster)) { shareLabel }
                .buttonStyle(PressScaleStyle())
                .accessibilityIdentifier("journey.week.share")
        } else {
            shareLabel.opacity(0.5).accessibilityHidden(true)
        }
    }
}

/// One small figure of the week: icon, value and what it counts.
private struct WeekStat: View {
    let symbol: String
    let tint: Color
    let value: Text
    let label: Text

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: symbol).font(.system(size: 13, weight: .semibold)).foregroundStyle(tint)
                .frame(width: 18).accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 0) {
                value.font(Typeface.number(16)).foregroundStyle(Palette.ink).lineLimit(1).minimumScaleFactor(0.7)
                label.font(.caption).foregroundStyle(Palette.inkSoft).lineLimit(1).minimumScaleFactor(0.75)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}

/// Seven bars of minutes, each over its weekday's initial; today's initial is mint with a dot under it.
/// A day played without timed practice still shows a stub.
struct WeekBars: View {
    let days: [WeekRecap.Day]
    var height: CGFloat = 52
    var barWidth: CGFloat = 14
    /// The weekday initials: 12 pt in soft ink, legible on the card's mint wash (10 pt faint ink fell under 4.5:1 there).
    var labelSize: CGFloat = 12

    private static let barFill = LinearGradient(colors: [Palette.mint, Palette.mintDeep], startPoint: .top, endPoint: .bottom)

    var body: some View {
        let peak = max(10, days.map(\.minutes).max() ?? 0)
        return HStack(alignment: .bottom, spacing: 0) {
            ForEach(Array(days.enumerated()), id: \.offset) { index, day in
                column(day, peak: peak, today: index == days.count - 1)
                    .frame(maxWidth: .infinity)
            }
        }
    }

    private func column(_ day: WeekRecap.Day, peak: Int, today: Bool) -> some View {
        let share = min(1, max(0.16, Double(day.minutes) / Double(peak)))
        return VStack(spacing: 5) {
            ZStack(alignment: .bottom) {
                Capsule().fill(Color.white.opacity(0.06)).frame(width: barWidth, height: height)
                if day.played {
                    Capsule().fill(Self.barFill)
                        .frame(width: barWidth, height: max(barWidth, height * CGFloat(share)))
                        .shadow(color: today ? Palette.mint.opacity(0.55) : .clear, radius: 8)
                }
            }
            Text(day.date, format: .dateTime.weekday(.narrow))
                .font(Typeface.label(labelSize)).foregroundStyle(today ? Palette.mint : Palette.inkSoft)
            Circle().fill(today ? Palette.mint : .clear).frame(width: 4, height: 4)
        }
    }
}

/// What the week's poster is drawn from: it is drawn again when either changes.
private struct WeekPoster: Equatable {
    let recap: WeekRecap
    let friends: FriendStreak?
}

/// The week as a poster: the dates, "Your week", the minutes large over the seven bars, and three figures; with Game
/// Center friends, the streak's place among theirs under them (counts only, no names).
struct WeekShareCard: View {
    let recap: WeekRecap
    var friends: FriendStreak? = nil

    var body: some View {
        ShareCardFrame(glow: Palette.mint, signature: true) {
            recap.rangeText.font(Typeface.label(12)).tracking(1.2).foregroundStyle(Palette.mint).lineLimit(1)
        } content: {
            Text("Your week").font(Typeface.display(44)).tracking(-1).foregroundStyle(Palette.ink)
                .padding(.top, 8)
            VStack(spacing: 0) {
                Text(recap.minutes, format: .number).font(Typeface.number(96)).foregroundStyle(Palette.ink)
                    .shadow(color: Palette.mint.opacity(0.35), radius: 20)
                Text("minutes").font(Typeface.label(18)).tracking(0.6).foregroundStyle(Palette.inkSoft)
            }
            WeekBars(days: recap.days, height: 96, barWidth: 26, labelSize: 13)
                .padding(.horizontal, 6).padding(.top, 4)
            HStack(spacing: 10) {
                tile("scope", Palette.amber, WeekRecap.centsText(recap.bestCents), Text("best tune-up"))
                tile("graduationcap.fill", Palette.violet, Text(recap.lessons, format: .number), Text("lessons"))
                tile("flame.fill", Palette.flame, Text(recap.streak, format: .number), Text("day streak"))
            }
            .padding(.top, 4)
            if let friends { FriendStreakLine(standing: friends, size: 15) }
        }
    }

    private func tile(_ symbol: String, _ tint: Color, _ value: Text, _ label: Text) -> some View {
        let shape = RoundedRectangle(cornerRadius: Metrics.cornerTile, style: .continuous)
        return VStack(spacing: 5) {
            Image(systemName: symbol).font(.system(size: 14, weight: .bold)).foregroundStyle(tint)
            value.font(Typeface.number(22)).foregroundStyle(Palette.ink).lineLimit(1).minimumScaleFactor(0.6)
            label.font(Typeface.label(12)).foregroundStyle(Palette.inkSoft).lineLimit(1).minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity).padding(.vertical, 14)
        .background(shape.fill(Color.white.opacity(0.05)))
        .overlay(shape.strokeBorder(Color.white.opacity(0.08), lineWidth: 1))
    }
}
