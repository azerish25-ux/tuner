import SwiftUI
import TimbreCore

/// All strings in tune: a burst of light, a chord of haptics and a card to share.
struct CelebrationOverlay: View {
    @EnvironmentObject private var store: AppStore
    @State private var visible = false
    @State private var started = Date()
    @State private var card: Image?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.displayScale) private var displayScale
    @Environment(\.locale) private var locale
    @Environment(\.layoutDirection) private var layoutDirection

    var body: some View {
        ZStack {
            if visible {
                Color.black.opacity(0.35).ignoresSafeArea().onTapGesture { dismiss() }
                if !reduceMotion { Burst(started: started).allowsHitTesting(false) }
                VStack(spacing: 14) {
                    Image(systemName: "checkmark").font(.system(size: 26, weight: .heavy)).foregroundStyle(Palette.onAccent)
                        .frame(width: 64, height: 64)
                        .background(Circle().fill(Palette.mint))
                        .shadow(color: Palette.mint.opacity(0.6), radius: 24)
                        .symbolEffect(.bounce, value: visible)
                    Text("All strings in tune").font(Typeface.display(30)).tracking(-0.6).foregroundStyle(Palette.ink).multilineTextAlignment(.center)
                    Text("\(store.instrumentDisplayName) · \(store.tuning.name.localized)").font(.subheadline).foregroundStyle(Palette.inkSoft)
                    HStack(spacing: 6) {
                        ForEach(Array(store.courses.enumerated()), id: \.offset) { _, course in
                            let note = NoteReadout.split(TargetLabelFormatter.splitCue(store.courseLabel(course)).main)
                            (Text(note.name).font(Typeface.label(13)) + Text(note.octave).font(Typeface.label(9)))
                                .foregroundStyle(Palette.mint)
                                .frame(minWidth: 30, minHeight: 30)
                                .background(Circle().fill(Palette.mint.opacity(0.12)))
                        }
                    }
                    .accessibilityHidden(true)
                    HStack(spacing: 10) {
                        if let seconds = store.lastTuneSeconds, seconds > 0 {
                            Label("\(seconds) s", systemImage: "stopwatch.fill").foregroundStyle(Palette.ink)
                        }
                        Label("+\(XPReward.fullTune) XP", systemImage: "sparkles").foregroundStyle(Palette.mint)
                        if store.streak.current > 0 {
                            Label("\(store.streak.current)-day streak", systemImage: "flame.fill").foregroundStyle(Color(hex: 0xFFD3A8))
                        }
                    }
                    .font(Typeface.label(13))
                    HStack(spacing: 12) {
                        // The card renders once the burst has landed; until then Share rests, dimmed, where it will be.
                        if let card {
                            ShareLink(item: card, preview: SharePreview("In tune with Timbre", image: card)) {
                                Label("Share", systemImage: "square.and.arrow.up")
                            }
                            .buttonStyle(BrassButtonStyle())
                        } else {
                            Button {} label: { Label("Share", systemImage: "square.and.arrow.up") }
                                .buttonStyle(BrassButtonStyle())
                                .disabled(true)
                                .opacity(0.5)
                        }
                        Button("Done") { dismiss() }.buttonStyle(BrassButtonStyle(prominent: false))
                    }
                    .animation(.easeOut(duration: 0.25), value: card == nil)
                    .padding(.top, 6)
                    // Tuned up: the natural moment to play something.
                    if let course = store.curriculum.courses.first(where: { $0.instrument == store.instrument.id }), let next = store.learn.nextLesson(in: course) {
                        Button {
                            dismiss()
                            UserDefaults.standard.set(course.id, forKey: "learn.course")
                            store.selectedTab = .learn
                        } label: {
                            Label("Ready to play: \(next.title.localized)", systemImage: "graduationcap.fill")
                                .font(.subheadline.weight(.semibold)).foregroundStyle(Palette.mint).lineLimit(1)
                        }
                        .padding(.top, 2)
                        .accessibilityIdentifier("celebration.lesson")
                    }
                }
                .padding(26)
                .stillCard(cornerRadius: 30, padding: 22)
                .padding(.horizontal, 28)
                .transition(.scale(scale: 0.92).combined(with: .opacity))
                .accessibilityAddTraits(.isModal)
            }
        }
        .animation(Motion.pluck, value: visible)
        .onChange(of: store.celebrate) { _, _ in
            let start = Date()
            started = start
            card = nil
            visible = true
            // Rendering the card holds the main thread for a few frames: after the entrance, never under it.
            Task { @MainActor in
                try? await Task.sleep(for: ShareCardRenderer.entrance)
                guard visible, started == start else { return }
                renderCard()
            }
            Task { try? await Task.sleep(for: .seconds(6)); if visible { dismiss() } }
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
        .animation(.easeOut(duration: 0.3), value: days)
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

private struct Burst: View {
    let started: Date
    /// The ring and most sparks; the rest are amber.
    var tint: Color = Palette.mint
    private struct Spark { let angle, speed, size, hue: Double }
    private static let sparks: [Spark] = {
        var g = SystemRandom(seed: 5)
        return (0..<90).map { _ in Spark(angle: g.next() * 2 * .pi, speed: 120 + 320 * g.next(), size: 1.5 + 3.5 * g.next(), hue: g.next()) }
    }()
    var body: some View {
        TimelineView(.animation) { timeline in
            Canvas { context, size in
                let t = timeline.date.timeIntervalSince(started)
                guard t < 2.4 else { return }
                let center = CGPoint(x: size.width / 2, y: size.height * 0.42)
                let ring = 40 + t * 380
                context.stroke(Path(ellipseIn: CGRect(x: center.x - ring, y: center.y - ring, width: ring * 2, height: ring * 2)),
                               with: .color(tint.opacity(max(0, 0.5 - t * 0.3))), lineWidth: 2)
                for spark in Self.sparks {
                    let d = spark.speed * t * (1 - t / 4)
                    let p = CGPoint(x: center.x + cos(spark.angle) * d, y: center.y + sin(spark.angle) * d + 60 * t * t)
                    let alpha = max(0, 1 - t / 2.2)
                    let color = spark.hue > 0.6 ? Palette.amber : tint
                    context.fill(Path(ellipseIn: CGRect(x: p.x - spark.size, y: p.y - spark.size, width: spark.size * 2, height: spark.size * 2)), with: .color(color.opacity(alpha)))
                }
            }
        }
        .ignoresSafeArea()
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
        .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(Palette.stageRaised))
        .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).strokeBorder(tint.opacity(0.25), lineWidth: 1))
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

    init(glow: Color = Color(hex: 0xFFC48C), signature: Bool = false, @ViewBuilder tag: () -> Tag, @ViewBuilder content: () -> Content) {
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
            Rectangle().fill(Color.white.opacity(0.12)).frame(height: 1)
            HStack(spacing: 6) {
                Image(systemName: "tuningfork").font(.system(size: 11, weight: .bold)).foregroundStyle(Palette.mint)
                Text("In tune with Timbre").font(Typeface.label(11)).tracking(0.4).foregroundStyle(Palette.inkSoft)
            }
            .fixedSize()
            Rectangle().fill(Color.white.opacity(0.12)).frame(height: 1)
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
            if streak > 1 { Label("\(streak)-day streak", systemImage: "flame.fill").font(Typeface.label(12)).foregroundStyle(Color(hex: 0xFFD3A8)) }
        } content: {
            if let name = modelID.flatMap({ ModelLibrary.hasCard($0) ? ModelLibrary.cardImageName($0) : nil }) ?? photo {
                Image(name).resizable().scaledToFit().frame(height: 300).shadow(color: .black.opacity(0.65), radius: 24, y: 14)
                    .background(Ellipse().fill(RadialGradient(colors: [Color(hex: 0xFFC48C).opacity(0.25), .clear], center: .center, startRadius: 2, endRadius: 160)).frame(width: 300, height: 40).offset(y: 150))
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
    /// "Flawless" or "Great work" for a lesson; nil for a song, whose title leads.
    let headline: LocalizedStringKey?
    let stars: Int
    let accuracy: Int
    let accent: Color
    let song: Bool
    /// The streak beside the accuracy (from two days on).
    var streak = 0

    private static let gold = Color(hex: 0xF0A93B)
    private static let starFill = LinearGradient(colors: [Color(hex: 0xFFE29A), Color(hex: 0xF0A93B)], startPoint: .top, endPoint: .bottom)

    var body: some View {
        ShareCardFrame(glow: accent, signature: true) {
            Text(course.uppercased()).font(Typeface.label(12)).tracking(1.6).foregroundStyle(accent).lineLimit(1)
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
            Text("\(streak)-day streak").font(Typeface.label(14)).foregroundStyle(Color(hex: 0xFFD3A8))
                .lineLimit(1).minimumScaleFactor(0.7)
        }
        .padding(.horizontal, 14).frame(height: 34)
        .background(Capsule().fill(Palette.flame.opacity(0.12)))
        .padding(.top, 2)
    }

    private var hero: some View {
        ZStack {
            Circle()
                .fill(RadialGradient(colors: [Self.gold.opacity(0.26), .clear], center: .center, startRadius: 4, endRadius: 140))
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
                Image(systemName: "star.fill")
                    .font(.system(size: (i == 1 ? 86 : 64) * scale, weight: .bold))
                    .foregroundStyle(earned ? AnyShapeStyle(Self.starFill) : AnyShapeStyle(Color.white.opacity(0.08)))
                    .shadow(color: earned ? Self.gold.opacity(0.55) : .clear, radius: 16)
                    .offset(y: i == 1 ? -12 * scale : 0)
            }
        }
    }

    @ViewBuilder private var words: some View {
        if let headline {
            Text(headline).font(Typeface.display(52)).tracking(-1.2).foregroundStyle(Palette.ink)
            Text(title).font(.headline).foregroundStyle(Palette.inkSoft).multilineTextAlignment(.center)
        } else {
            Text(title).font(Typeface.display(40)).tracking(-0.8).foregroundStyle(Palette.ink)
                .multilineTextAlignment(.center).lineLimit(3).fixedSize(horizontal: false, vertical: true)
            Text("\(stars) of 3 stars").font(.headline).foregroundStyle(Palette.inkSoft)
        }
    }

    private var accuracyChip: some View {
        HStack(spacing: 6) {
            Image(systemName: "scope").font(.system(size: 13, weight: .bold)).foregroundStyle(Palette.amber)
            Text("\(accuracy)%").font(Typeface.label(15)).foregroundStyle(Palette.ink)
            Text("accuracy").font(Typeface.label(14)).foregroundStyle(Palette.inkSoft)
        }
        .padding(.horizontal, 14).frame(height: 34)
        .background(Capsule().fill(Palette.amber.opacity(0.12)))
        .padding(.top, 2)
    }
}

/// A streak milestone (7, 30, 100 days): the flame, the number of days and the badge it earns.
struct StreakShareCard: View {
    let days: Int

    /// The badge that goes with the milestone ("Perfect week", "Month of music", "Hundred days").
    static func title(_ days: Int) -> String? { Achievements.all.first { $0.id == "streak_\(days)" }?.title }
    static func titleText(_ days: Int) -> Text { title(days).map { Text(LocalizedStringKey($0)) } ?? Text("Practice streak") }

    var body: some View {
        ShareCardFrame(glow: Palette.flame, signature: true) {
            Self.titleText(days).font(Typeface.label(12)).tracking(1.2).foregroundStyle(Color(hex: 0xFFD3A8)).lineLimit(1)
        } content: {
            ZStack {
                Circle()
                    .fill(RadialGradient(colors: [Palette.flame.opacity(0.34), .clear], center: .center, startRadius: 4, endRadius: 140))
                    .frame(width: 280, height: 280)
                StreakFlame(size: 150, animated: false)
            }
            .frame(height: 190)
            Text(days, format: .number).font(Typeface.number(92)).foregroundStyle(Palette.ink)
            Text("day streak").font(Typeface.label(18)).tracking(0.6).foregroundStyle(Palette.inkSoft)
            embers
        }
    }

    /// A week of embers, one lit for each day of the run (all seven from a week on).
    private var embers: some View {
        HStack(spacing: 8) {
            ForEach(0..<7, id: \.self) { index in
                let lit = index < min(days, 7)
                Circle().fill(lit ? Palette.flame : Color.white.opacity(0.12)).frame(width: 11, height: 11)
                    .shadow(color: lit ? Palette.flame.opacity(0.6) : .clear, radius: 6)
            }
        }
        .padding(.top, 4)
        .accessibilityHidden(true)
    }
}
