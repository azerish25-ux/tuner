import SwiftUI
import TimbreCore

/// All strings in tune, as a finale in three beats. The camera pulls back to the whole instrument (`TuneView`) while
/// the instrument's own open strings roll low to high, each with its bell, and strum together (`SoundFX.playTuned`,
/// the rail's chips lighting in step). Only then does the card rise: the strings standing still, the tuning, the time
/// and the share card, with a harmonic burst. It closes itself after a few seconds.
struct CelebrationOverlay: View {
    @EnvironmentObject private var store: AppStore
    @State private var visible = false
    @State private var started = Date()
    @State private var card: Image?
    @State private var burst = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.displayScale) private var displayScale
    @Environment(\.locale) private var locale
    @Environment(\.layoutDirection) private var layoutDirection

    /// How long the card stays once it has risen.
    static let holds = 6.0

    /// The card waits for the pull-back and the strings' roll (`SoundSynth.tunedBloom`); under Reduce Motion the
    /// camera cuts, so it waits for the roll alone.
    static func entranceDelay(strings: Int, reduceMotion: Bool) -> Double {
        let roll = SoundSynth.tunedBloom(count: strings)
        return reduceMotion ? roll + 0.2 : max(0.9, roll) + 0.45
    }

    var body: some View {
        ZStack {
            if visible {
                Color.black.opacity(0.35).ignoresSafeArea().onTapGesture { dismiss() }
                SparkBurst(trigger: burst, color: Palette.mint, reach: 190)
                    .frame(width: 420, height: 420)
                    .allowsHitTesting(false)
                cardView
            }
        }
        .adaptiveAnimation(Motion.pluck, value: visible)
        .onChange(of: store.celebrate) { _, _ in present() }
    }

    private var cardView: some View {
        VStack(spacing: 14) {
            StillStrings(count: store.courses.count)
                .frame(width: 92, height: 56)
                .accessibilityHidden(true)
            Text("All strings in tune").font(Typeface.display(30)).tracking(-0.6).foregroundStyle(Palette.ink).multilineTextAlignment(.center)
            Text("\(store.instrumentDisplayName) · \(store.tuning.name.localized)").font(.subheadline).foregroundStyle(Palette.inkSoft)
            noteRow
            HStack(spacing: 10) {
                if let seconds = store.lastTuneSeconds, seconds > 0 {
                    Label("\(seconds) s", systemImage: "stopwatch.fill").foregroundStyle(Palette.ink)
                }
                // The simple tuner keeps to the tuning: no XP or streak.
                if !store.settings.simpleTuner {
                    Label("+\(XPReward.fullTune) XP", systemImage: "sparkles").foregroundStyle(Palette.mint)
                    if store.streak.current > 0 {
                        Label("\(store.streak.current)-day streak", systemImage: "flame.fill").foregroundStyle(Palette.flameInk)
                    }
                }
            }
            .font(Typeface.label(13))
            shareRow
            nextLesson
        }
        // A hero card: the hero radius, the card inset with a little extra air around the moment.
        .padding(.horizontal, Metrics.proseInset).padding(.vertical, 12)
        .stillCard(cornerRadius: Metrics.cornerHero)
        .padding(.horizontal, Metrics.gutter + Metrics.proseInset)
        .transition(.adaptive(.scale(scale: 0.92).combined(with: .opacity).combined(with: .offset(y: 24)), reduceMotion: reduceMotion))
        .accessibilityAddTraits(.isModal)
    }

    /// The strings just tuned, low to high, as chips (music-spatial: left to right in every language).
    private var noteRow: some View {
        HStack(spacing: 6) {
            ForEach(Array(store.courses.enumerated()), id: \.offset) { _, course in
                let note = NoteReadout.split(TargetLabelFormatter.splitCue(store.courseLabel(course)).main)
                (Text(note.name).font(Typeface.label(13)) + Text(note.octave).font(Typeface.label(9)))
                    .foregroundStyle(Palette.mint)
                    .frame(minWidth: 30, minHeight: 30)
                    .background(Circle().fill(Palette.mint.opacity(0.12)))
            }
        }
        .environment(\.layoutDirection, .leftToRight)
        .accessibilityHidden(true)
    }

    private var shareRow: some View {
        HStack(spacing: 12) {
            // The card renders once the card has risen; until then Share rests where it will be, in the primary
            // button's disabled look.
            if let card {
                ShareLink(item: card, preview: SharePreview("In tune with Timbre", image: card)) {
                    Label("Share", systemImage: "square.and.arrow.up")
                }
                .buttonStyle(PrimaryButtonStyle())
            } else {
                Button {} label: { Label("Share", systemImage: "square.and.arrow.up") }
                    .buttonStyle(PrimaryButtonStyle())
                    .disabled(true)
            }
            Button("Done") { dismiss() }.buttonStyle(SecondaryButtonStyle())
        }
        .animation(Motion.fade, value: card == nil)
        .padding(.top, 6)
    }

    /// Tuned up: the natural moment to play something.
    @ViewBuilder private var nextLesson: some View {
        if let course = store.curriculum.courses.first(where: { $0.instrument == store.instrument.id }), let next = store.learn.nextLesson(in: course) {
            Button {
                dismiss()
                UserDefaults.standard.set(course.id, forKey: "learn.course")
                store.selectedTab = .learn
            } label: {
                Label("Ready to play: \(next.title.localized)", systemImage: "graduationcap.fill")
                    .font(.subheadline.weight(.semibold)).foregroundStyle(Palette.mint).lineLimit(1)
                    .tapTarget()
            }
            .padding(.top, 2)
            .accessibilityIdentifier("celebration.lesson")
        }
    }

    /// The finale's beats: the card waits for the pull-back and the roll, rises with its burst, renders its share
    /// card once it has settled, and closes itself after `holds` seconds.
    private func present() {
        let start = Date()
        started = start
        card = nil
        visible = false
        let delay = Self.entranceDelay(strings: store.courses.count, reduceMotion: reduceMotion)
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(delay))
            guard started == start else { return }
            visible = true
            if !reduceMotion { burst += 1 }
            // Rendering the card holds the main thread for a few frames: after the entrance, never under it.
            try? await Task.sleep(for: ShareCardRenderer.entrance)
            guard visible, started == start else { return }
            renderCard()
            try? await Task.sleep(for: .seconds(Self.holds))
            if visible, started == start { dismiss() }
        }
    }

    private func dismiss() { visible = false }

    private func renderCard() {
        let tune = TuneShareCard(instrument: store.instrumentDisplayName, tuning: store.tuning.name.localized,
                                 notes: store.courses.map { TargetLabelFormatter.splitCue(store.courseLabel($0)).main },
                                 modelID: store.modelID, photo: store.photo?.asset, streak: store.streak.current, seconds: store.lastTuneSeconds)
        card = ShareCardRenderer.image(tune, scale: displayScale, locale: locale, direction: layoutDirection)
    }
}

/// The instrument's strings, thick to thin, ringing as the card arrives and settling straight: the moment a tuned
/// string stands still, as a glyph. Still under Reduce Motion.
private struct StillStrings: View {
    let count: Int
    @State private var appeared = Date()
    @State private var ringing = true
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private static let ring = 1.2

    var body: some View {
        TimelineView(.animation(paused: !ringing || reduceMotion)) { timeline in
            let t = timeline.date.timeIntervalSince(appeared)
            let swing = ringing && !reduceMotion && t < Self.ring ? exp(-t / 0.3) * cos(2 * .pi * 6 * t) : 0
            Canvas { context, size in draw(&context, size: size, swing: swing) }
        }
        .task {
            appeared = Date()
            try? await Task.sleep(for: .seconds(Self.ring))
            ringing = false
        }
    }

    private func draw(_ context: inout GraphicsContext, size: CGSize, swing: Double) {
        let strings = max(1, min(12, count))
        let gap = size.width / CGFloat(strings + 1)
        for index in 0..<strings {
            let x = gap * CGFloat(index + 1)
            // Each string swings at its own rate (a higher one a little faster), in its fundamental's shape.
            let amount = CGFloat(swing) * gap * 0.32 * (index % 2 == 0 ? 1 : -1)
            var path = Path()
            path.move(to: CGPoint(x: x, y: 0))
            for step in 1...16 {
                let y = size.height * CGFloat(step) / 16
                let bow = amount * CGFloat(sin(Double(step) / 16 * .pi))
                path.addLine(to: CGPoint(x: x + bow, y: y))
            }
            let width = 2.6 - 1.4 * CGFloat(index) / CGFloat(max(1, strings - 1))
            context.stroke(path, with: .color(Palette.mint), style: StrokeStyle(lineWidth: width, lineCap: .round))
        }
        // The nut and the bridge the strings run between.
        for y in [CGFloat(0), size.height] {
            let bar = CGRect(x: gap * 0.5, y: y - 1.5, width: size.width - gap, height: 3)
            context.fill(Path(roundedRect: bar, cornerRadius: 1.5), with: .color(Palette.ink.opacity(0.35)))
        }
    }
}

/// A run of 3, 7, 30 or 100 days, reached by practice saved outside a lesson (lesson results show their own):
/// the full-screen `StreakCelebration`, with its poster to share. It waits for Continue.
struct StreakMilestoneOverlay: View {
    @EnvironmentObject private var store: AppStore
    @State private var days: Int?

    var body: some View {
        ZStack {
            if let days {
                StreakCelebration(days: days) { self.days = nil }
                    .transition(.opacity)
            }
        }
        .animation(Motion.fade, value: days)
        .onChange(of: store.streakMilestone) { _, milestone in
            guard milestone != nil else { return }
            Task { @MainActor in
                // A lesson's results claim theirs straight away; this shows only what is still waiting.
                try? await Task.sleep(for: .seconds(1.2))
                guard days == nil, let reached = store.takeStreakMilestone() else { return }
                days = reached
            }
        }
    }
}

// MARK: - Share cards

/// Renders a share card to an image for `ShareLink`, at the screen's scale and in the app's language and direction.
/// Rendering holds the main thread for a few frames, so the reward screens start it after their entrance.
enum ShareCardRenderer {
    /// How long a reward moment's entrance runs before its card may render.
    static let entrance: Duration = .milliseconds(900)

    @MainActor static func image(_ card: some View, scale: CGFloat, locale: Locale, direction: LayoutDirection) -> Image? {
        let renderer = ImageRenderer(content: card.environment(\.locale, locale).environment(\.layoutDirection, direction))
        renderer.scale = scale
        return renderer.uiImage.map { Image(uiImage: $0) }
    }
}

/// "Share" for a card: rendered once when it appears, then handed to the share sheet. Style it like a button.
struct ShareCardButton<Card: View>: View {
    let preview: LocalizedStringKey
    let card: Card
    @State private var image: Image?
    @Environment(\.displayScale) private var displayScale
    @Environment(\.locale) private var locale
    @Environment(\.layoutDirection) private var layoutDirection

    init(preview: LocalizedStringKey, @ViewBuilder card: () -> Card) {
        self.preview = preview
        self.card = card()
    }

    var body: some View {
        Group {
            if let image {
                ShareLink(item: image, preview: SharePreview(preview, image: image)) { label }
            } else {
                Button {} label: { label }.disabled(true)
            }
        }
        .task {
            guard image == nil else { return }
            try? await Task.sleep(for: ShareCardRenderer.entrance)
            guard !Task.isCancelled, image == nil else { return }
            image = ShareCardRenderer.image(card, scale: displayScale, locale: locale, direction: layoutDirection)
        }
    }

    private var label: some View { Label("Share", systemImage: "square.and.arrow.up") }
}

/// A share card in a list (lesson results): a tilted thumbnail of the card, two lines and "Share".
struct ShareCardRow<Card: View>: View {
    let title: Text
    let detail: Text
    let preview: LocalizedStringKey
    let tint: Color
    let card: Card
    @State private var image: Image?
    @Environment(\.displayScale) private var displayScale
    @Environment(\.locale) private var locale
    @Environment(\.layoutDirection) private var layoutDirection

    init(title: Text, detail: Text, preview: LocalizedStringKey, tint: Color = Palette.mint, @ViewBuilder card: () -> Card) {
        self.title = title
        self.detail = detail
        self.preview = preview
        self.tint = tint
        self.card = card()
    }

    var body: some View {
        HStack(spacing: 14) {
            thumbnail
            VStack(alignment: .leading, spacing: 2) {
                title.font(.subheadline.weight(.semibold)).foregroundStyle(Palette.ink).lineLimit(1)
                detail.font(.caption).foregroundStyle(Palette.inkSoft).lineLimit(2)
            }
            Spacer(minLength: 8)
            shareButton
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: Metrics.cornerTile, style: .continuous).fill(Palette.stageRaised))
        .overlay(RoundedRectangle(cornerRadius: Metrics.cornerTile, style: .continuous).strokeBorder(tint.opacity(0.25), lineWidth: 1))
        .task {
            guard image == nil else { return }
            try? await Task.sleep(for: ShareCardRenderer.entrance)
            guard !Task.isCancelled, image == nil else { return }
            image = ShareCardRenderer.image(card, scale: displayScale, locale: locale, direction: layoutDirection)
        }
    }

    private var thumbnail: some View {
        let shape = RoundedRectangle(cornerRadius: 8, style: .continuous)
        return ZStack {
            if let image { image.resizable().scaledToFill() } else { Palette.surface }
        }
        .frame(width: 50, height: 66)
        .clipShape(shape)
        .overlay(shape.strokeBorder(.white.opacity(0.12), lineWidth: 1))
        .rotationEffect(.degrees(-5))
        .shadow(color: .black.opacity(0.5), radius: 8, y: 4)
        .padding(.leading, 4)
        .accessibilityHidden(true)
    }

    private var shareLabel: some View {
        Label("Share", systemImage: "square.and.arrow.up")
            .font(Typeface.label(14)).foregroundStyle(Palette.onAccent)
            .padding(.horizontal, 14).frame(minHeight: 38)
            .background(Capsule().fill(tint))
            .fixedSize()
    }

    @ViewBuilder private var shareButton: some View {
        if let image {
            ShareLink(item: image, preview: SharePreview(preview, image: image)) { shareLabel }
                .buttonStyle(PressScaleStyle())
        } else {
            shareLabel.opacity(0.5)
        }
    }
}

/// The Studio Noir frame every share card uses: the dark stage under a warm light, TIMBRE across the top
/// beside an optional tag, and the moment beneath. 400 pt wide. Only the achievement, never personal data.
/// With `signature`, a poster's sign-off closes it: hairlines either side of the tuning fork and "In tune with Timbre".
struct ShareCardFrame<Tag: View, Content: View>: View {
    let glow: Color
    let signature: Bool
    let tag: Tag
    let content: Content

    init(glow: Color = Palette.spotlight, signature: Bool = false, @ViewBuilder tag: () -> Tag, @ViewBuilder content: () -> Content) {
        self.glow = glow
        self.signature = signature
        self.tag = tag()
        self.content = content()
    }

    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Text("TIMBRE").font(Typeface.label(13)).tracking(6).foregroundStyle(Palette.amber)
                Spacer(minLength: 12)
                tag
            }
            content
            if signature { signatureLine }
        }
        .padding(30)
        .frame(width: 400)
        .background(
            ZStack {
                Palette.stage
                RadialGradient(colors: [glow.opacity(0.16), .clear], center: UnitPoint(x: 0.5, y: 0.3), startRadius: 4, endRadius: 320)
                RadialGradient(colors: [.clear, Palette.stageDeep.opacity(0.8)], center: .center, startRadius: 230, endRadius: 520)
            }
        )
        .environment(\.colorScheme, .dark)
    }

    private var signatureLine: some View {
        HStack(spacing: 10) {
            Hairline()
            HStack(spacing: 6) {
                Image(systemName: "tuningfork").font(.system(size: 11, weight: .bold)).foregroundStyle(Palette.mint)
                Text("In tune with Timbre").font(Typeface.label(11)).tracking(0.4).foregroundStyle(Palette.inkSoft)
            }
            .fixedSize()
            Hairline()
        }
        .padding(.top, 6)
    }
}

/// The shareable "in tune" card.
struct TuneShareCard: View {
    let instrument: String
    let tuning: String
    let notes: [String]
    let modelID: String?
    let photo: String?
    let streak: Int
    var seconds: Int?

    var body: some View {
        ShareCardFrame {
            if streak > 1 { Label("\(streak)-day streak", systemImage: "flame.fill").font(Typeface.label(12)).foregroundStyle(Palette.flameInk) }
        } content: {
            if let name = modelID.flatMap({ ModelLibrary.hasCard($0) ? ModelLibrary.cardImageName($0) : nil }) ?? photo {
                Image(name).resizable().scaledToFit().frame(height: 300).shadow(color: .black.opacity(0.65), radius: 24, y: 14)
                    .background(Ellipse().fill(RadialGradient(colors: [Palette.spotlight.opacity(0.25), .clear], center: .center, startRadius: 2, endRadius: 160)).frame(width: 300, height: 40).offset(y: 150))
            }
            Text("In tune").font(Typeface.display(52)).tracking(-1.2).foregroundStyle(Palette.ink)
            if let seconds, seconds > 0 {
                Text("Every string in \(seconds) seconds").font(Typeface.label(16)).foregroundStyle(Palette.mint)
            }
            Text("\(instrument) · \(tuning)").font(.headline).foregroundStyle(Palette.inkSoft)
            HStack(spacing: 8) {
                ForEach(Array(notes.enumerated()), id: \.offset) { _, note in
                    Text(note).font(Typeface.label(14)).foregroundStyle(Palette.mint)
                        .padding(.horizontal, 10).frame(height: 30)
                        .background(Capsule().fill(Palette.mint.opacity(0.12)))
                }
            }
        }
    }
}

/// Three stars on a lesson, or a finished song: the stars under a gold light, the headline (or the song's
/// title) and the accuracy, with the course named in its accent.
struct LessonShareCard: View {
    let course: String
    let title: String
    /// The results' headline for a lesson ("92% landed"); nil for a song, whose title leads.
    let headline: LocalizedStringKey?
    let stars: Int
    let accuracy: Int
    let accent: Color
    let song: Bool
    /// The streak beside the accuracy (from two days on).
    var streak = 0

    var body: some View {
        ShareCardFrame(glow: accent, signature: true) {
            Eyebrow(Text(course), color: accent, style: .display).lineLimit(1)
        } content: {
            hero
            words
            HStack(spacing: 8) {
                accuracyChip
                if streak > 1 { streakChip }
            }
        }
    }

    private var streakChip: some View {
        HStack(spacing: 6) {
            Image(systemName: "flame.fill").font(.system(size: 13, weight: .bold)).foregroundStyle(Palette.flame)
            Text("\(streak)-day streak").font(Typeface.label(14)).foregroundStyle(Palette.flameInk)
                .lineLimit(1).minimumScaleFactor(0.7)
        }
        .padding(.horizontal, 14).frame(height: 34)
        .background(Capsule().fill(Palette.flame.opacity(0.12)))
        .padding(.top, 2)
    }

    private var hero: some View {
        ZStack {
            Circle()
                .fill(RadialGradient(colors: [Palette.starGold.opacity(0.26), .clear], center: .center, startRadius: 4, endRadius: 140))
                .frame(width: 280, height: 280)
            VStack(spacing: 18) {
                if song { songDisc }
                starRow(scale: song ? 0.72 : 1)
            }
        }
        .frame(height: song ? 230 : 180)
    }

    private var songDisc: some View {
        Image(systemName: "music.quarternote.3").font(.system(size: 30, weight: .bold)).foregroundStyle(Palette.onAccent)
            .frame(width: 76, height: 76)
            .background(Circle().fill(accent))
            .shadow(color: accent.opacity(0.55), radius: 18)
    }

    private func starRow(scale: CGFloat) -> some View {
        HStack(alignment: .bottom, spacing: 12 * scale) {
            ForEach(0..<3, id: \.self) { i in
                let earned = i < stars
                let size = (i == 1 ? 86 : 64) * scale
                RewardStar(earned: earned)
                    .frame(width: size * 1.05, height: size)
                    .shadow(color: earned ? Palette.starGold.opacity(0.55) : .clear, radius: 16)
                    .offset(y: i == 1 ? -12 * scale : 0)
            }
        }
    }

    @ViewBuilder private var words: some View {
        if let headline {
            Text(headline).font(Typeface.display(52)).tracking(-1.2).foregroundStyle(Palette.ink)
                .multilineTextAlignment(.center).lineLimit(2).minimumScaleFactor(0.6)
                .fixedSize(horizontal: false, vertical: true)
            Text(title).font(.headline).foregroundStyle(Palette.inkSoft).multilineTextAlignment(.center)
        } else {
            Text(title).font(Typeface.display(40)).tracking(-0.8).foregroundStyle(Palette.ink)
                .multilineTextAlignment(.center).lineLimit(3).fixedSize(horizontal: false, vertical: true)
            Text("\(stars) of 3 stars").font(.headline).foregroundStyle(Palette.inkSoft)
        }
    }

    private var accuracyChip: some View {
        HStack(spacing: 6) {
            Image(systemName: "target").font(.system(size: 13, weight: .bold)).foregroundStyle(Palette.amber)
            Text("\(accuracy)%").font(Typeface.label(15)).foregroundStyle(Palette.ink)
            Text("accuracy").font(Typeface.label(14)).foregroundStyle(Palette.inkSoft)
        }
        .padding(.horizontal, 14).frame(height: 34)
        .background(Capsule().fill(Palette.amber.opacity(0.12)))
        .padding(.top, 2)
    }
}

/// A streak milestone (7, 30, 100 days): the stage lamp burning over the number of days, the rig of the last week
/// and the badge it earns.
struct StreakShareCard: View {
    let days: Int

    /// The badge that goes with the milestone ("Perfect week", "Month of music", "Hundred days").
    static func title(_ days: Int) -> String? { Achievements.all.first { $0.id == "streak_\(days)" }?.title }
    static func titleText(_ days: Int) -> Text { title(days).map { Text(LocalizedStringKey($0)) } ?? Text("Practice streak") }

    var body: some View {
        ShareCardFrame(glow: Palette.flame, signature: true) {
            Eyebrow(Self.titleText(days), color: Palette.flameInk, style: .display).lineLimit(1)
        } content: {
            ZStack {
                Circle()
                    .fill(RadialGradient(colors: [Palette.flame.opacity(0.3), .clear], center: .center, startRadius: 4, endRadius: 140))
                    .frame(width: 280, height: 280)
                StageLamp(level: StageLamp.brightness(days: days), size: 170)
            }
            .frame(height: 190)
            Text(days, format: .number).font(Typeface.number(92)).foregroundStyle(Palette.ink)
            Text("day streak").font(Typeface.label(18)).tracking(0.6).foregroundStyle(Palette.inkSoft)
            LightingRig(days: days, lit: min(days, 7)).padding(.top, 4)
        }
    }
}
