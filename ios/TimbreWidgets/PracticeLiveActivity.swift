import ActivityKit
import SwiftUI
import WidgetKit

private typealias SessionState = PracticeActivityAttributes.ContentState

/// The practice session as a Live Activity: the Lock Screen banner, the Dynamic Island (compact, minimal, expanded)
/// and the Apple Watch Smart Stack. Studio Noir: the dark stage, mint for what is running, amber for the downbeat,
/// the flame for the streak. The session clock counts on its own from `since` (`Text(timerInterval:)`): the app
/// updates the activity only when something changes, at most once a second.
/// Tapping it opens Timbre where the player left it (no URL, so a lesson or the metronome stays on screen).
struct PracticeLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: PracticeActivityAttributes.self) { context in
            SessionBanner(state: context.state, stale: context.isStale)
                .activityBackgroundTint(Palette.stage.opacity(0.94))
                .activitySystemActionForegroundColor(Palette.mint)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    SessionGlyph(state: context.state, stale: context.isStale, size: 44).padding(.leading, 4)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    IslandClock(state: context.state, stale: context.isStale).padding(.trailing, 4)
                }
                DynamicIslandExpandedRegion(.center) {
                    SessionHeading(state: context.state)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    IslandDetail(state: context.state)
                }
            } compactLeading: {
                CompactLeading(state: context.state, stale: context.isStale)
            } compactTrailing: {
                CompactTrailing(state: context.state, stale: context.isStale)
            } minimal: {
                MinimalMark(state: context.state)
            }
            .keylineTint(Palette.mint)
        }
        .supplementalActivityFamilies([.small])
    }
}

// MARK: - Reading the state

private extension PracticeActivityAttributes.ContentState {
    var heading: LocalizedStringKey {
        switch mode {
        case .metronome: return "Metronome"
        case .drone: return "Drone"
        case .practice: return "Practicing"
        case .done: return "Session complete"
        }
    }

    var glyph: String {
        switch mode {
        case .metronome: return "metronome.fill"
        case .drone: return "waveform.path"
        case .practice: return symbol
        case .done: return "checkmark"
        }
    }
}

// MARK: - Lock Screen and Smart Stack

private struct SessionBanner: View {
    @Environment(\.activityFamily) private var family
    let state: SessionState
    let stale: Bool

    var body: some View {
        if family == .small {
            SmallStack(state: state, stale: stale)
        } else {
            banner
        }
    }

    private var banner: some View {
        HStack(alignment: .center, spacing: 14) {
            SessionGlyph(state: state, stale: stale, size: 52)
            VStack(alignment: .leading, spacing: 5) {
                SessionHeading(state: state)
                PrimaryLine(state: state, size: 26)
                if state.mode == .metronome { BeatDots(levels: state.beatLevels, size: 8) }
            }
            Spacer(minLength: 8)
            VStack(alignment: .trailing, spacing: 8) {
                SessionClock(state: state, stale: stale)
                    .font(Typeface.number(24, relativeTo: .title2))
                    .foregroundStyle(stale ? Palette.inkFaint : Palette.ink)
                    .multilineTextAlignment(.trailing)
                    .frame(maxWidth: 110, alignment: .trailing)
                StreakMark(streak: state.streak, long: true)
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 16)
        .accessibilityElement(children: .combine)
    }
}

/// Apple Watch Smart Stack: the glyph, what runs and its one number.
private struct SmallStack: View {
    let state: SessionState
    let stale: Bool

    var body: some View {
        HStack(spacing: 8) {
            SessionGlyph(state: state, stale: stale, size: 30)
            VStack(alignment: .leading, spacing: 1) {
                SessionHeading(state: state)
                value.font(Typeface.display(18, relativeTo: .headline)).foregroundStyle(Palette.ink).lineLimit(1).minimumScaleFactor(0.7)
            }
            Spacer(minLength: 0)
        }
        .padding(10)
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder private var value: some View {
        switch state.mode {
        case .metronome: Text(verbatim: "♩ \(state.bpm) · \(state.meter)")
        case .drone: Text(verbatim: state.drone)
        case .practice, .done: SessionClock(state: state, stale: stale)
        }
    }
}

// MARK: - Dynamic Island

private struct CompactLeading: View {
    let state: SessionState
    let stale: Bool

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: state.glyph)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(stale ? Palette.inkFaint : Palette.mint)
            // The beat dot: the bar's downbeat colour, so the click reads at a glance.
            if state.mode == .metronome && !stale {
                Circle().fill(Palette.amber).frame(width: 6, height: 6)
            }
        }
        .padding(.leading, 2)
        .accessibilityLabel(Text(state.heading))
    }
}

private struct CompactTrailing: View {
    let state: SessionState
    let stale: Bool

    var body: some View {
        Group {
            switch state.mode {
            case .metronome:
                Text(verbatim: "\(state.bpm)").font(Typeface.number(15))
            case .drone:
                Text(verbatim: state.drone).font(Typeface.display(15))
            case .practice, .done:
                SessionClock(state: state, stale: stale)
                    .font(Typeface.number(14))
                    .multilineTextAlignment(.trailing)
                    .frame(width: 50, alignment: .trailing)
            }
        }
        .foregroundStyle(stale ? Palette.inkFaint : Palette.mint)
        .lineLimit(1)
        .minimumScaleFactor(0.6)
        .padding(.trailing, 2)
    }
}

private struct MinimalMark: View {
    let state: SessionState

    var body: some View {
        Group {
            switch state.mode {
            case .metronome:
                Text(verbatim: "\(state.bpm)").font(Typeface.number(12))
            case .drone:
                Text(verbatim: state.drone).font(Typeface.display(13))
            case .practice, .done:
                Image(systemName: state.glyph).font(.system(size: 13, weight: .semibold))
            }
        }
        .foregroundStyle(Palette.mint)
        .lineLimit(1)
        .minimumScaleFactor(0.6)
        .accessibilityLabel(Text(state.heading))
    }
}

private struct IslandClock: View {
    let state: SessionState
    let stale: Bool

    var body: some View {
        VStack(alignment: .trailing, spacing: 4) {
            SessionClock(state: state, stale: stale)
                .font(Typeface.number(20, relativeTo: .title3))
                .foregroundStyle(stale ? Palette.inkFaint : Palette.ink)
                .multilineTextAlignment(.trailing)
                .frame(maxWidth: 90, alignment: .trailing)
            StreakMark(streak: state.streak)
        }
    }
}

private struct IslandDetail: View {
    let state: SessionState

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            PrimaryLine(state: state, size: 24)
            Spacer(minLength: 8)
            if state.mode == .metronome { BeatDots(levels: state.beatLevels, size: 8) }
        }
        .padding(.horizontal, 6)
        .padding(.top, 2)
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Pieces

/// The mode's symbol in a mint ring; the metronome wears the beat dot, a finished session fills mint.
private struct SessionGlyph: View {
    let state: SessionState
    let stale: Bool
    var size: CGFloat = 44

    private var done: Bool { state.mode == .done }
    private var fill: Color { done ? Palette.mint : Palette.mint.opacity(0.14) }
    private var ink: Color {
        if done { return Palette.onAccent }
        return stale ? Palette.inkFaint : Palette.mint
    }

    var body: some View {
        ZStack {
            Circle().fill(fill)
            Circle().strokeBorder(Palette.mint.opacity(stale ? 0.2 : 0.55), lineWidth: 1.5)
            Image(systemName: state.glyph)
                .font(.system(size: size * 0.4, weight: .semibold))
                .foregroundStyle(ink)
        }
        .frame(width: size, height: size)
        .overlay(alignment: .topTrailing) {
            if state.mode == .metronome && !stale {
                Circle().fill(Palette.amber)
                    .frame(width: size * 0.22, height: size * 0.22)
                    .overlay(Circle().stroke(Palette.stage, lineWidth: 2))
            }
        }
        .accessibilityHidden(true)
    }
}

private struct SessionHeading: View {
    let state: SessionState

    var body: some View {
        Text(state.heading)
            .font(Typeface.eyebrow)
            .textCase(.uppercase)
            .tracking(1)
            .foregroundStyle(Palette.mint)
            .lineLimit(1)
    }
}

/// What runs: "♩ 96 4/4" (with the drone's note when it sounds too), the drone's tonic, or the lesson or instrument.
private struct PrimaryLine: View {
    let state: SessionState
    var size: CGFloat = 26

    var body: some View {
        switch state.mode {
        case .metronome:
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(verbatim: "♩ \(state.bpm)").font(Typeface.display(size, relativeTo: .title)).foregroundStyle(Palette.ink)
                Text(verbatim: state.meter).font(Typeface.number(size * 0.55)).foregroundStyle(Palette.inkSoft)
                if !state.drone.isEmpty { DroneChip(note: state.drone) }
            }
            .lineLimit(1)
            .minimumScaleFactor(0.7)
        case .drone:
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(verbatim: state.drone).font(Typeface.display(size, relativeTo: .title)).foregroundStyle(Palette.ink)
                Text("Tonic").font(Typeface.label(size * 0.5)).foregroundStyle(Palette.inkSoft)
            }
            .lineLimit(1)
            .minimumScaleFactor(0.7)
        case .practice, .done:
            Text(verbatim: state.detail)
                .font(Typeface.display(size * 0.68, relativeTo: .headline))
                .foregroundStyle(Palette.ink)
                .lineLimit(2)
                .minimumScaleFactor(0.8)
        }
    }
}

private struct DroneChip: View {
    let note: String

    var body: some View {
        HStack(spacing: 3) {
            Image(systemName: "waveform.path")
            Text(verbatim: note)
        }
        .font(Typeface.label(11))
        .foregroundStyle(Palette.mint)
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(Capsule().fill(Palette.mint.opacity(0.14)))
    }
}

/// The bar as the metronome's meter card shows it: amber accents, mint beats, silent beats dim.
private struct BeatDots: View {
    let levels: [Int]
    var size: CGFloat = 8

    var body: some View {
        HStack(spacing: size * 0.7) {
            ForEach(Array(levels.enumerated()), id: \.offset) { _, level in
                Circle()
                    .fill(Self.color(level))
                    .frame(width: Self.diameter(level, size), height: Self.diameter(level, size))
            }
        }
        .frame(height: size * 1.3)
        .accessibilityHidden(true)
    }

    private static func color(_ level: Int) -> Color {
        switch level {
        case 2: return Palette.amber
        case 1: return Palette.mint
        default: return Palette.line
        }
    }

    private static func diameter(_ level: Int, _ size: CGFloat) -> CGFloat { level == 2 ? size * 1.3 : size }
}

/// The session clock: counting up from `since` (drawn by the system, no updates), frozen once the session is done,
/// a pause mark once the app has been away too long to vouch for it.
private struct SessionClock: View {
    let state: SessionState
    let stale: Bool

    var body: some View {
        if state.mode == .done {
            Text(verbatim: Self.format(state.seconds))
        } else if stale {
            Image(systemName: "pause.fill")
        } else {
            Text(timerInterval: state.since...state.since.addingTimeInterval(12 * 3600), countsDown: false)
                .monospacedDigit()
        }
    }

    static func format(_ seconds: Int) -> String {
        let pattern: Duration.TimeFormatStyle.Pattern = seconds >= 3600 ? .hourMinuteSecond : .minuteSecond
        return Duration.seconds(seconds).formatted(.time(pattern: pattern))
    }
}

/// The flame and the run: "12" in the island, "12-day streak" on the Lock Screen; nothing before a run starts.
private struct StreakMark: View {
    let streak: Int
    var long = false

    var body: some View {
        if streak > 0 {
            HStack(spacing: 3) {
                Image(systemName: "flame.fill").foregroundStyle(Palette.flame)
                if long {
                    Text("\(streak)-day streak")
                } else {
                    Text(verbatim: "\(streak)")
                }
            }
            .font(Typeface.label(12))
            .foregroundStyle(Palette.ink)
            .lineLimit(1)
            .minimumScaleFactor(0.7)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text("\(streak)-day streak"))
        }
    }
}
