import SwiftUI
import TimbreCore

/// A run of 3, 7, 30 or 100 days, full screen, in the app's own picture of practice: the stage. A stage lamp comes on
/// over the count (brighter the longer the run), its beam falls on the number as it rolls over to the new day, and the
/// lighting rig below lights one lamp for each day of the last week. A poster is ready to share. Lesson results show
/// it for a milestone a lesson reached; `StreakMilestoneOverlay` shows the others. It waits for Continue.
struct StreakCelebration: View {
    let days: Int
    let onDone: () -> Void
    @State private var shownDays: Int
    @State private var lit = 0
    /// The lamp's light, 0 (off) to its brightness for this run.
    @State private var lamp = 0.0
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
                        LightingRig(days: days, lit: lit)
                            .opacity(wordsIn ? 1 : 0)
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
            RadialGradient(colors: [Palette.flame.opacity(0.22 * lamp), .clear], center: UnitPoint(x: 0.5, y: 0.3), startRadius: 8, endRadius: 420)
            RadialGradient(colors: [.clear, Palette.stageDeep.opacity(0.9)], center: .center, startRadius: 260, endRadius: 760)
        }
        .ignoresSafeArea()
        // Swallows taps: the screen closes with Continue only.
        .contentShape(Rectangle())
        .onTapGesture {}
    }

    private func hero(compact: Bool) -> some View {
        let lampSize: CGFloat = compact ? 112 : 140
        return VStack(spacing: 6) {
            ZStack {
                SparkBurst(trigger: burst, color: Palette.flame, reach: compact ? 150 : 190).frame(width: 340, height: 340)
                StageLamp(level: lamp, size: lampSize)
            }
            .frame(height: lampSize + 8)
            Text(shownDays, format: .number)
                .font(Typeface.hero(compact ? 84 : 104)).foregroundStyle(Palette.ink)
                .contentTransition(.numericText(value: Double(shownDays)))
                .shadow(color: Palette.spotlight.opacity(0.3 * lamp), radius: 18)
                .heroNumeral()
            Text("day streak").font(Typeface.display(.title3)).tracking(-0.3).foregroundStyle(Palette.ink)
            // The milestone's name as the app's display eyebrow, in a pill of the lamp's light.
            Eyebrow(StreakShareCard.titleText(days), color: Palette.flameInk, style: .display)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 12).padding(.vertical, 6).frame(minHeight: 28)
                .background(Capsule().fill(Palette.flame.opacity(0.14)))
                .overlay(Capsule().strokeBorder(Palette.flame.opacity(0.35), lineWidth: 1))
                .padding(.top, 8)
                .opacity(wordsIn ? 1 : 0).offset(y: wordsIn || reduceMotion ? 0 : 10)
        }
        // The lamp's beam falls from its lens over the number and the words.
        .background(alignment: .top) {
            LampBeam(level: lamp, moving: !reduceMotion)
                .frame(width: 320, height: compact ? 330 : 400)
                .offset(y: lampSize / 2)
                .allowsHitTesting(false)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("\(days)-day streak"))
        .accessibilityValue(StreakShareCard.titleText(days))
        .accessibilityAddTraits(.isHeader)
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

    /// The lamp warms up with the streak's own cue (a chord swelling as the light does), the count rolls over, then
    /// the rig lights day by day. Under Reduce Motion the light only fades up and nothing moves.
    private func play() async {
        Haptics.shared.done()
        SoundFX.shared.play(.streak)
        AccessibilityNotification.Announcement(String(localized: "\(days)-day streak", bundle: TimbreLocalization.bundle)).post()
        withAnimation(.easeOut(duration: reduceMotion ? 0.3 : 0.9)) { lamp = StageLamp.brightness(days: days) }
        if !reduceMotion { burst += 1 }
        try? await Task.sleep(for: .milliseconds(reduceMotion ? 60 : 420))
        withMotion(Motion.reward, reduceMotion: reduceMotion) { shownDays = days }
        // The words fade in (kept under Reduce Motion), rising a little only with motion on.
        withAnimation(Motion.fade.delay(reduceMotion ? 0 : 0.15)) { wordsIn = true }
        try? await Task.sleep(for: .milliseconds(reduceMotion ? 0 : 320))
        for step in 0..<min(max(days, 0), 7) {
            try? await Task.sleep(for: .milliseconds(reduceMotion ? 0 : 130))
            withAnimation(reduceMotion ? Motion.fade : .easeOut(duration: 0.35)) { lit = step + 1 }
            if !reduceMotion { Haptics.shared.selection() }
        }
    }
}

// MARK: - The lamp

/// A stage lamp seen from the front: a dark housing round a Fresnel lens (its rings catching the light), glowing warm
/// from `level` 0 (off) to 1, with a halo spilling past the housing. Animatable, so the light fades up.
struct StageLamp: View, Animatable {
    var level: Double
    var size: CGFloat

    var animatableData: Double {
        get { level }
        set { level = newValue }
    }

    /// How bright the lamp burns for a run: warm at 3 days, full at 100.
    static func brightness(days: Int) -> Double {
        min(1, 0.7 + 0.15 * log10(Double(max(1, days))))
    }

    var body: some View {
        Canvas { context, canvas in
            let center = CGPoint(x: canvas.width / 2, y: canvas.height / 2)
            let r = min(canvas.width, canvas.height) / 2
            let light = max(0, min(1, level))
            func disc(_ radius: CGFloat) -> Path {
                Path(ellipseIn: CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2))
            }
            // The halo, past the housing.
            context.fill(disc(r), with: .radialGradient(
                Gradient(colors: [Palette.spotlight.opacity(0.5 * light), Palette.flame.opacity(0.22 * light), .clear]),
                center: center, startRadius: r * 0.45, endRadius: r))
            // The housing and its rim.
            let housing = r * 0.64
            context.fill(disc(housing), with: .color(Color(hex: 0x15171B)))
            context.stroke(disc(housing), with: .color(Color.white.opacity(0.16)), lineWidth: max(1, r * 0.025))
            // The lens, lit from within, brightest a little above its centre.
            let lens = housing * 0.84
            let core = CGPoint(x: center.x - lens * 0.12, y: center.y - lens * 0.16)
            context.fill(disc(lens), with: .radialGradient(
                Gradient(colors: [Color.white.opacity(0.06 + 0.9 * light), Palette.spotlight.opacity(0.05 + 0.85 * light),
                                  Palette.flame.opacity(0.04 + 0.7 * light)]),
                center: core, startRadius: 0, endRadius: lens * 1.1))
            // The Fresnel rings.
            for ring in 1...4 {
                context.stroke(disc(lens * CGFloat(ring) / 5), with: .color(Color.white.opacity(0.08 + 0.14 * light)), lineWidth: 1)
            }
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}

/// The lamp's beam: a soft cone of warm light widening downward from the lens, a few motes drifting through it.
private struct LampBeam: View, Animatable {
    var level: Double
    /// Motes drift (off under Reduce Motion: the beam is still).
    var moving: Bool

    var animatableData: Double {
        get { level }
        set { level = newValue }
    }

    private struct Mote { let x, speed, size, phase: Double }
    private static let motes: [Mote] = {
        var g = SystemRandom(seed: 23)
        return (0..<26).map { _ in Mote(x: g.next(), speed: 0.015 + 0.03 * g.next(), size: 0.8 + 1.6 * g.next(), phase: g.next()) }
    }()

    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 30, paused: !moving || level < 0.05)) { timeline in
            Canvas { context, size in
                let light = max(0, min(1, level))
                guard light > 0.01 else { return }
                let top = size.width * 0.14
                var cone = Path()
                cone.move(to: CGPoint(x: size.width / 2 - top, y: 0))
                cone.addLine(to: CGPoint(x: size.width / 2 + top, y: 0))
                cone.addLine(to: CGPoint(x: size.width, y: size.height))
                cone.addLine(to: CGPoint(x: 0, y: size.height))
                cone.closeSubpath()
                context.fill(cone, with: .linearGradient(
                    Gradient(colors: [Palette.spotlight.opacity(0.26 * light), Palette.flame.opacity(0.08 * light), .clear]),
                    startPoint: .zero, endPoint: CGPoint(x: 0, y: size.height)))
                guard moving else { return }
                let t = timeline.date.timeIntervalSinceReferenceDate
                for mote in Self.motes {
                    let progress = (mote.phase + t * mote.speed).truncatingRemainder(dividingBy: 1)
                    let y = Double(size.height) * progress
                    // Inside the cone at that depth.
                    let half = Double(top) + (Double(size.width) / 2 - Double(top)) * progress
                    let x = Double(size.width) / 2 + (mote.x * 2 - 1) * half * 0.85 + sin(t * 0.7 + mote.phase * 9) * 6
                    let alpha = sin(progress * .pi) * 0.55 * light
                    let rect = CGRect(x: x - mote.size, y: y - mote.size, width: mote.size * 2, height: mote.size * 2)
                    context.fill(Path(ellipseIn: rect), with: .color(Palette.spotlight.opacity(alpha)))
                }
            }
        }
        .accessibilityHidden(true)
    }
}

/// The last seven days as a lighting rig: a truss with a lamp hanging for each day, today on the right; the run's
/// days light in order.
struct LightingRig: View {
    let days: Int
    /// How many of the run's days have lit so far.
    let lit: Int

    var body: some View {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let run = min(days, 7)
        return VStack(spacing: 0) {
            Capsule().fill(Color.white.opacity(0.14)).frame(height: 3).padding(.horizontal, 10)
            HStack(spacing: 6) {
                ForEach(0..<7, id: \.self) { index in
                    let date = calendar.date(byAdding: .day, value: index - 6, to: today) ?? today
                    let position = index - (7 - run)
                    hangingLamp(date: date, on: position >= 0 && position < lit, today: index == 6)
                }
            }
        }
        .padding(.horizontal, 12).padding(.top, 10).padding(.bottom, 14)
        .background(RoundedRectangle(cornerRadius: Metrics.corner, style: .continuous).fill(Palette.stageRaised.opacity(0.85)))
        .overlay(RoundedRectangle(cornerRadius: Metrics.corner, style: .continuous).strokeBorder(Palette.flame.opacity(0.22), lineWidth: 1))
        // Music-spatial: the week runs left to right, today last, in every language.
        .environment(\.layoutDirection, .leftToRight)
        .accessibilityHidden(true)
    }

    private func hangingLamp(date: Date, on: Bool, today: Bool) -> some View {
        VStack(spacing: 4) {
            Rectangle().fill(Color.white.opacity(0.14)).frame(width: 1.5, height: 8)
            StageLamp(level: on ? 1 : 0, size: 40)
                .shadow(color: on ? Palette.flame.opacity(0.45) : .clear, radius: 8)
            Text(date, format: .dateTime.weekday(.narrow))
                .font(Typeface.label(12)).foregroundStyle(today ? Palette.ink : Palette.inkSoft)
        }
        .frame(maxWidth: .infinity)
    }
}
