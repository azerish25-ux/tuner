import SwiftUI
import TimbreCore

/// How each activity of the daily set looks and reads.
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
        }
    }

    var detail: String {
        switch self {
        case .tune: return String(localized: "every string to a still point")
        case .ear: return String(localized: "ten questions")
        case .chord: return String(localized: "learn one new shape")
        case .scale: return String(localized: "one position, slowly")
        case .rhythm: return String(localized: "steady at a comfortable tempo")
        case .voice: return String(localized: "a comfortable range")
        case .drone: return String(localized: "hold notes against a tonic")
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
        }
    }

    var tint: Color {
        switch self {
        case .tune: return Palette.amber
        case .ear: return Palette.mint
        case .chord, .scale: return Palette.violet
        case .rhythm: return Palette.coral
        case .voice, .drone: return Palette.sky
        }
    }

    /// Chords, scales and the drone are Pro tools: a free player's tap opens the paywall.
    var needsPro: Bool { [.chord, .scale, .drone].contains(self) }
}

/// Minutes as the locale writes them ("4 min", "4 Min.").
private func minutesText(_ minutes: Int) -> Text {
    Text(Duration.seconds(max(0, minutes) * 60), format: .units(allowed: [.minutes], width: .abbreviated))
}

// MARK: - Ring

/// The daily set as a ring: one arc per activity, as long as its minutes, filling in once it is done.
/// With `open`, each arc is a button for its activity (the card's rows carry the same actions for VoiceOver).
struct DailySetRing: View {
    let activities: [DailyActivity]
    let done: Set<DailyActivity.Kind>
    var lineWidth: CGFloat = 10
    /// Space between arcs as a share of the circle, room for the round caps plus a hairline of air.
    var gap = 0.05
    var open: ((DailyActivity.Kind) -> Void)? = nil

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
        let arc = arcView(activity, from: from, to: to, lit: done.contains(activity.kind))
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
        return ZStack {
            Circle().inset(by: lineWidth / 2).trim(from: from, to: to)
                .stroke(tint.opacity(0.18), style: style)
            Circle().inset(by: lineWidth / 2).trim(from: from, to: lit ? to : from)
                .stroke(tint, style: style)
                .opacity(lit ? 1 : 0)
                .shadow(color: tint.opacity(lit ? 0.55 : 0), radius: lineWidth * 0.6)
        }
        .rotationEffect(.degrees(-90))
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

/// Today's practice set at the top of the Play hub: about ten minutes of activities as arcs of a ring and
/// as rows beside it, each opening its tool, each ticking off as it is done. Finishing the set pays a bonus
/// (the toast announces it) and the card celebrates once: a burst of sparks, a chime, a gold ring.
struct DailySetCard: View {
    @EnvironmentObject private var store: AppStore
    @EnvironmentObject private var commerce: CommerceService
    let open: (DailyActivity.Kind) -> Void
    /// The day the completion was last celebrated here, so the burst plays once.
    @AppStorage("daily.celebrated") private var celebratedDay = ""
    @State private var visible = false
    @State private var burst = 0
    @State private var pop = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let activities = store.dailySet
        let done = Set(activities.map(\.kind).filter { store.dailyDone($0) })
        let complete = store.dailySetComplete
        VStack(alignment: .leading, spacing: 14) {
            header(activities, done: done, complete: complete)
            HStack(alignment: .center, spacing: 16) {
                ring(activities, done: done, complete: complete)
                VStack(spacing: 2) {
                    ForEach(activities) { activity in row(activity, done: done.contains(activity.kind)) }
                }
            }
        }
        .stillCard(cornerRadius: 24, padding: 16, tint: complete ? Palette.amber : Palette.mint)
        .onAppear { visible = true; celebrateIfNeeded(complete) }
        .onDisappear { visible = false }
        .onChange(of: complete) { _, now in if visible { celebrateIfNeeded(now) } }
    }

    private func header(_ activities: [DailyActivity], done: Set<DailyActivity.Kind>, complete: Bool) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text("Today").font(Typeface.display(17)).foregroundStyle(Palette.ink).accessibilityAddTraits(.isHeader)
            minutesText(activities.reduce(0) { $0 + $1.minutes }).font(.caption).foregroundStyle(Palette.inkSoft)
            Spacer()
            if complete {
                Label { Text("Done") } icon: { Image(systemName: "flame.fill") }
                    .font(Typeface.label(12)).foregroundStyle(Palette.amber)
            } else {
                Text("\(done.count) of \(activities.count)").font(.caption).foregroundStyle(Palette.inkSoft)
                    .contentTransition(.numericText())
            }
        }
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
            }
            .allowsHitTesting(false)
            .accessibilityHidden(true)
        } else {
            VStack(spacing: 0) {
                Text(verbatim: "\(done.count)/\(activities.count)").font(Typeface.number(22)).foregroundStyle(Palette.ink)
                    .contentTransition(.numericText())
                minutesText(activities.filter { !done.contains($0.kind) }.reduce(0) { $0 + $1.minutes })
                    .font(.caption2).foregroundStyle(Palette.inkSoft)
            }
            .allowsHitTesting(false)
            .accessibilityHidden(true)
        }
    }

    private func row(_ activity: DailyActivity, done: Bool) -> some View {
        let kind = activity.kind
        let locked = kind.needsPro && !commerce.isPro
        return Button { open(kind) } label: {
            HStack(spacing: 10) {
                Image(systemName: done ? "checkmark" : kind.symbol).font(.system(size: 11, weight: .bold))
                    .foregroundStyle(done ? Palette.onAccent : kind.tint)
                    .frame(width: 26, height: 26)
                    .background(Circle().fill(done ? AnyShapeStyle(kind.tint) : AnyShapeStyle(kind.tint.opacity(0.14))))
                    .contentTransition(.symbolEffect(.replace))
                Text(kind.title).font(.subheadline.weight(.semibold))
                    .foregroundStyle(done ? Palette.inkSoft : Palette.ink)
                    .strikethrough(done, color: Palette.inkFaint)
                    .lineLimit(2).minimumScaleFactor(0.85)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 4)
                if locked {
                    ProBadge().scaleEffect(0.8)
                } else {
                    minutesText(activity.minutes).font(Typeface.number(12)).foregroundStyle(done ? Palette.mint : Palette.inkSoft)
                }
            }
            .frame(minHeight: 32)
            .contentShape(Rectangle())
        }
        .buttonStyle(PressScaleStyle())
        .accessibilityElement(children: .combine)
        .accessibilityHint(Text(kind.detail))
        .accessibilityValue(done ? Text("Done") : Text(""))
        .accessibilityIdentifier("daily.\(kind.rawValue)")
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

// MARK: - Compact card (Learn)

/// The daily set in one line, for the Learn tab's header area: a small ring, "Today", how much is done
/// and how many minutes are left. Taps through to the Play hub (or `action`).
struct DailySetCompactCard: View {
    @EnvironmentObject private var store: AppStore
    var action: (() -> Void)? = nil

    var body: some View {
        let activities = store.dailySet
        let done = Set(activities.map(\.kind).filter { store.dailyDone($0) })
        let complete = store.dailySetComplete
        let left = activities.filter { !done.contains($0.kind) }.reduce(0) { $0 + $1.minutes }
        Button {
            if let action { action() } else { store.selectedTab = .practice }
            Haptics.shared.selection()
        } label: {
            HStack(spacing: 12) {
                ZStack {
                    DailySetRing(activities: activities, done: done, lineWidth: 5, gap: 0.08)
                    if complete {
                        Image(systemName: "checkmark").font(.system(size: 13, weight: .heavy)).foregroundStyle(Palette.amber)
                    } else {
                        Text(verbatim: "\(done.count)").font(Typeface.number(13)).foregroundStyle(Palette.ink)
                    }
                }
                .frame(width: 40, height: 40)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Today").font(Typeface.display(15)).foregroundStyle(Palette.ink)
                    Group {
                        if complete {
                            Text("Done")
                        } else {
                            Text("\(done.count) of \(activities.count)") + Text(verbatim: " · ") + minutesText(left)
                        }
                    }
                    .font(.caption).foregroundStyle(complete ? Palette.amber : Palette.inkSoft)
                }
                Spacer(minLength: 8)
                Image(systemName: "chevron.right").font(.footnote.weight(.bold)).foregroundStyle(Palette.inkFaint)
            }
            .stillCard(cornerRadius: 18, padding: 12, tint: complete ? Palette.amber : nil)
        }
        .buttonStyle(PressScaleStyle())
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
        .accessibilityIdentifier("daily.compact")
    }
}
