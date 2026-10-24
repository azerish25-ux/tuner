import SwiftUI
import TimbreCore

/// A run of 3, 7, 30 or 100 days, full screen: the flame catches with a burst, the count rolls over to the new
/// number, the last seven days light one by one, and a poster is ready to share. Lesson results show it for a
/// milestone a lesson reached; `StreakMilestoneOverlay` shows the others. It waits for Continue.
struct StreakCelebration: View {
    let days: Int
    let onDone: () -> Void
    @State private var shownDays: Int
    @State private var lit = 0
    @State private var flameIn = false
    @State private var wordsIn = false
    @State private var burst = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(days: Int, onDone: @escaping () -> Void) {
        self.days = days
        self.onDone = onDone
        _shownDays = State(initialValue: max(0, days - 1))
    }

    var body: some View {
        ZStack {
            backdrop
            // Fills the screen when it fits (Continue at the foot); scrolls on short screens and in landscape.
            GeometryReader { proxy in
                let compact = proxy.size.height < 700
                ScrollView {
                    VStack(spacing: 0) {
                        Spacer(minLength: 16)
                        hero(compact: compact)
                        Spacer(minLength: 20)
                        weekRow
                        Spacer(minLength: 20)
                        actions
                    }
                    .padding(.horizontal, Metrics.gutter)
                    .padding(.bottom, 12)
                    .frame(maxWidth: 520)
                    .frame(maxWidth: .infinity, minHeight: proxy.size.height)
                }
                .scrollBounceBehavior(.basedOnSize)
                .scrollIndicators(.hidden)
                .scrollClipDisabled()
            }
        }
        .task { await play() }
        .accessibilityAddTraits(.isModal)
    }

    // MARK: Stage

    private var backdrop: some View {
        ZStack {
            Palette.stage
            RadialGradient(colors: [Palette.flame.opacity(0.28), .clear], center: UnitPoint(x: 0.5, y: 0.34), startRadius: 8, endRadius: 420)
            RadialGradient(colors: [.clear, Palette.stageDeep.opacity(0.9)], center: .center, startRadius: 260, endRadius: 760)
            if !reduceMotion { EmberField().opacity(flameIn ? 1 : 0) }
        }
        .ignoresSafeArea()
        // Swallows taps: the screen closes with Continue only.
        .contentShape(Rectangle())
        .onTapGesture {}
    }

    private func hero(compact: Bool) -> some View {
        VStack(spacing: 6) {
            ZStack {
                SparkBurst(trigger: burst, color: Palette.flame, reach: compact ? 170 : 220).frame(width: 340, height: 340)
                StreakFlame(size: compact ? 128 : 168, lit: flameIn)
                    .scaleEffect(flameIn ? 1 : 0.35)
                    .opacity(flameIn ? 1 : 0)
            }
            .frame(height: compact ? 158 : 210)
            Text(shownDays, format: .number)
                .font(Typeface.hero(compact ? 84 : 104)).foregroundStyle(Palette.ink)
                .contentTransition(.numericText(value: Double(shownDays)))
                .shadow(color: Palette.flame.opacity(0.35), radius: 18)
                .heroNumeral()
            Text("day streak").font(Typeface.display(24, relativeTo: .title2)).tracking(-0.3).foregroundStyle(Palette.ink)
            // The milestone's name as the app's display eyebrow, in a pill of the flame's light.
            Eyebrow(StreakShareCard.titleText(days), color: Palette.flameInk, style: .display)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 12).padding(.vertical, 6).frame(minHeight: 28)
                .background(Capsule().fill(Palette.flame.opacity(0.14)))
                .overlay(Capsule().strokeBorder(Palette.flame.opacity(0.35), lineWidth: 1))
                .padding(.top, 8)
                .opacity(wordsIn ? 1 : 0).offset(y: wordsIn || reduceMotion ? 0 : 10)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("\(days)-day streak"))
        .accessibilityValue(StreakShareCard.titleText(days))
        .accessibilityAddTraits(.isHeader)
    }

    // MARK: The last seven days

    /// One flame a day for the last week, today on the right; the run's days light in order.
    private var weekRow: some View {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let run = min(days, 7)
        return HStack(spacing: 6) {
            ForEach(0..<7, id: \.self) { index in
                let date = calendar.date(byAdding: .day, value: index - 6, to: today) ?? today
                let position = index - (7 - run)
                dayFlame(date: date, on: position >= 0 && position < lit, today: index == 6)
            }
        }
        .padding(.horizontal, 12).padding(.vertical, 14)
        .background(RoundedRectangle(cornerRadius: Metrics.corner, style: .continuous).fill(Palette.stageRaised.opacity(0.85)))
        .overlay(RoundedRectangle(cornerRadius: Metrics.corner, style: .continuous).strokeBorder(Palette.flame.opacity(0.22), lineWidth: 1))
        .opacity(wordsIn ? 1 : 0)
        .accessibilityHidden(true)
    }

    private func dayFlame(date: Date, on: Bool, today: Bool) -> some View {
        VStack(spacing: 7) {
            Image(systemName: "flame.fill").font(.system(size: 15, weight: .bold))
                .foregroundStyle(on ? Palette.onAccent : Palette.inkFaint.opacity(0.6))
                .frame(width: 36, height: 36)
                .background(Circle().fill(on ? AnyShapeStyle(Palette.flame) : AnyShapeStyle(Color.white.opacity(0.06))))
                .shadow(color: on ? Palette.flame.opacity(0.55) : .clear, radius: 8)
                .scaleEffect(on ? 1 : 0.86)
            Text(date, format: .dateTime.weekday(.narrow))
                .font(Typeface.label(11)).foregroundStyle(today ? Palette.ink : Palette.inkSoft)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: Actions

    private var actions: some View {
        VStack(spacing: 10) {
            Button(action: onDone) { Text("Continue") }
                .buttonStyle(PrimaryButtonStyle())
                .accessibilityIdentifier("streak.done")
            ShareCardButton(preview: "Practice streak") { StreakShareCard(days: days) }
                .buttonStyle(SecondaryButtonStyle())
                .accessibilityIdentifier("streak.share")
        }
        .opacity(wordsIn ? 1 : 0)
    }

    // MARK: Timeline

    private func play() async {
        Haptics.shared.done()
        SoundFX.shared.play(.levelUp)
        AccessibilityNotification.Announcement(String(localized: "\(days)-day streak", bundle: TimbreLocalization.bundle)).post()
        withMotion(Motion.reward, reduceMotion: reduceMotion) { flameIn = true }
        if !reduceMotion { burst += 1 }
        try? await Task.sleep(for: .milliseconds(reduceMotion ? 60 : 420))
        withMotion(Motion.reward, reduceMotion: reduceMotion) { shownDays = days }
        // The words fade in (kept under Reduce Motion), rising a little only with motion on.
        withAnimation(Motion.fade.delay(reduceMotion ? 0 : 0.15)) { wordsIn = true }
        try? await Task.sleep(for: .milliseconds(reduceMotion ? 0 : 320))
        for step in 0..<min(max(days, 0), 7) {
            try? await Task.sleep(for: .milliseconds(reduceMotion ? 0 : 110))
            withMotion(Motion.pop, reduceMotion: reduceMotion) { lit = step + 1 }
            if !reduceMotion { Haptics.shared.selection() }
        }
    }
}

/// Embers rising through the dark behind the flame, swaying as they go and fading at both ends.
private struct EmberField: View {
    private struct Ember { let x, speed, size, phase: Double }
    private static let embers: [Ember] = {
        var g = SystemRandom(seed: 23)
        return (0..<44).map { _ in Ember(x: g.next(), speed: 0.04 + 0.1 * g.next(), size: 1.2 + 2.4 * g.next(), phase: g.next()) }
    }()

    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 30)) { timeline in
            Canvas { context, size in
                let t = timeline.date.timeIntervalSinceReferenceDate
                for ember in Self.embers {
                    let progress = (ember.phase + t * ember.speed).truncatingRemainder(dividingBy: 1)
                    let y = Double(size.height) * (1.04 - progress * 1.1)
                    let x = ember.x * Double(size.width) + sin(t * 1.3 + ember.phase * 12) * 14
                    let r = ember.size * (1 - progress * 0.45)
                    let alpha = sin(progress * .pi) * 0.75
                    let rect = CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2)
                    let tint = ember.phase > 0.7 ? Color(hex: 0xFFE29A) : Palette.flame
                    context.fill(Path(ellipseIn: rect), with: .color(tint.opacity(alpha)))
                }
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}
