import SwiftUI
import TimbreCore

// MARK: - A finished take

/// One take of a song's final step, as the finale and the poster show it.
struct SongTake: Equatable {
    /// 0…1, as the play-along judges it (perfect 1, good 0.8, late or early 0.5, missed 0).
    var accuracy: Double
    /// Points with the combo multiplier; nil for a strummed take.
    var points: Int?
    var bestCombo: Int?
    /// Each note's grade in play order (empty for a strummed take).
    var grades: [PlayAlongJudge.Grade]
    var judgments: [PlayAlongJudge.Judgment]
    var notes: Int
    var tempo: Int
    /// Played at the lesson's tempo (a slower take tops the lesson out at two stars).
    var full: Bool

    var percent: Int { Int((accuracy * 100).rounded()) }

    func count(_ grade: PlayAlongJudge.Grade) -> Int { grades.reduce(0) { $0 + ($1 == grade ? 1 : 0) } }

    /// White-gold perfect, the course colour good, amber late or early, coral missed (as on the play-along's ribbon).
    static func color(_ grade: PlayAlongJudge.Grade, accent: Color) -> Color {
        switch grade {
        case .perfect: return Color(hex: 0xFFE7A3)
        case .good: return accent
        case .ok: return Palette.amber
        case .miss: return Palette.danger
        }
    }
}

// MARK: - The finale

/// The end of a song's final take: the stars the lesson will record land one by one over a burst, then the score,
/// how the take went note by note, and its poster, story-sized (9:16), one tap from the share sheet. Continue
/// hands the step on; Perform again plays the song again (and a weak take at full tempo offers the slower one).
struct SongFinaleView: View {
    let take: SongTake
    let lesson: Lesson
    let course: LearnCourse
    let accent: Color
    /// The lesson's stars if it ends with this take.
    let stars: Int
    /// The best take's score this visit, when it beats this one (it is the one that counts).
    var best: Int?
    /// Offered after a weak take at full tempo: the same song at 75 %.
    var slower: (() -> Void)?
    var slowerTempo: Int?
    let again: () -> Void
    let proceed: () -> Void
    @EnvironmentObject private var store: AppStore
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.displayScale) private var displayScale
    @Environment(\.locale) private var locale
    @Environment(\.layoutDirection) private var layoutDirection
    @State private var shownStars = 0
    @State private var burst = 0
    @State private var appeared = false
    @State private var poster: Image?

    private var art: CoverArt { CoverArt.of(lesson, in: course) }
    private var title: String { CoverArt.mainTitle(lesson.title.localized) }
    private var tint: Color { take.percent >= 90 ? Palette.mint : Palette.amber }
    /// Under half the take landed: another go comes first.
    private var retryFirst: Bool { take.percent < 50 }

    private var verdict: LocalizedStringKey {
        if take.percent >= 98 { return "Flawless" }
        if take.percent >= 90 { return "Great work" }
        return retryFirst ? "Just warming up" : "Keep going"
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 16) {
                    starRow
                    words
                    numbers.opacity(appeared ? 1 : 0)
                    if !take.judgments.isEmpty {
                        HighwayTimingStrip(count: take.notes, judgments: take.judgments, accent: accent, calm: reduceMotion)
                            .padding(.horizontal, 20)
                            .opacity(appeared ? 1 : 0)
                    }
                    shareRow.opacity(appeared ? 1 : 0)
                }
                .padding(.top, 8).padding(.bottom, 16)
            }
            .scrollBounceBehavior(.basedOnSize)
            .scrollIndicators(.hidden)
            buttons
        }
        .task { await reveal() }
    }

    // MARK: Pieces

    private var starRow: some View {
        ZStack {
            SparkBurst(trigger: burst, color: accent).frame(width: 300, height: 300)
            HStack(alignment: .bottom, spacing: 12) {
                ForEach(0..<3, id: \.self) { index in star(index) }
            }
        }
        .frame(height: 120)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("\(stars) of 3 stars"))
    }

    private func star(_ index: Int) -> some View {
        let earned = index < stars
        let shown = index < shownStars
        let fill = LinearGradient(colors: [Color(hex: 0xFFE29A), Color(hex: 0xF0A93B)], startPoint: .top, endPoint: .bottom)
        return Image(systemName: "star.fill")
            .font(.system(size: index == 1 ? 78 : 58, weight: .bold))
            .foregroundStyle(earned && shown ? AnyShapeStyle(fill) : AnyShapeStyle(Color.white.opacity(0.08)))
            .shadow(color: earned && shown ? Color(hex: 0xF0A93B).opacity(0.6) : .clear, radius: 16)
            .scaleEffect(shown ? 1 : 0.3)
            .rotationEffect(.degrees(shown ? 0 : -40))
            .offset(y: index == 1 ? -10 : 0)
    }

    private var words: some View {
        VStack(spacing: 4) {
            Text(verdict).font(Typeface.label(15)).foregroundStyle(tint)
            Text("\(take.percent)%").font(Typeface.note(64)).foregroundStyle(tint)
                .contentTransition(.numericText(value: Double(take.percent)))
                .minimumScaleFactor(0.7)
            Text(verbatim: title).font(.headline).foregroundStyle(Palette.inkSoft).lineLimit(1)
            if let best, best > take.percent {
                Label("Best take \(best)%", systemImage: "crown.fill").font(Typeface.label(13)).foregroundStyle(Palette.amber)
                    .padding(.top, 4)
            }
        }
        .multilineTextAlignment(.center)
        .padding(.horizontal, 20)
        .accessibilityElement(children: .combine)
    }

    /// Points, best combo and the tempo it was played at; then the grades counted.
    private var numbers: some View {
        VStack(spacing: 12) {
            HStack(spacing: 10) {
                if let points = take.points { tile(Text(points, format: .number), label: "Score", symbol: "sparkles", tint: accent) }
                if let combo = take.bestCombo, combo > 1 { tile(Text("×\(combo)"), label: "Best combo", symbol: "flame.fill", tint: Palette.flame) }
                tile(Text("\(take.tempo)"), label: "BPM", symbol: take.full ? "metronome.fill" : "tortoise.fill", tint: take.full ? Palette.amber : Palette.inkSoft)
            }
            .padding(.horizontal, 20)
            if !take.grades.isEmpty {
                HStack(spacing: 18) {
                    stat("Perfect", take.count(.perfect), SongTake.color(.perfect, accent: accent))
                    stat("Good", take.count(.good), SongTake.color(.good, accent: accent))
                    stat("Late/early", take.count(.ok), SongTake.color(.ok, accent: accent))
                    stat("Missed", take.count(.miss), SongTake.color(.miss, accent: accent))
                }
            }
        }
    }

    private func tile(_ value: Text, label: LocalizedStringKey, symbol: String, tint: Color) -> some View {
        VStack(spacing: 3) {
            Image(systemName: symbol).font(.system(size: 14, weight: .semibold)).foregroundStyle(tint)
            value.font(Typeface.number(20)).foregroundStyle(Palette.ink).lineLimit(1).minimumScaleFactor(0.6)
            Text(label).font(.caption).foregroundStyle(Palette.inkSoft).lineLimit(1).minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity).padding(.vertical, 12)
        .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Palette.stageRaised))
        .accessibilityElement(children: .combine)
    }

    private func stat(_ label: LocalizedStringKey, _ value: Int, _ color: Color) -> some View {
        VStack(spacing: 2) {
            Text("\(value)").font(Typeface.number(18)).foregroundStyle(color)
            Text(label).font(.caption).foregroundStyle(Palette.inkSoft)
        }
        .accessibilityElement(children: .combine)
    }

    /// The poster, tilted beside Share, rendered once the stars have landed.
    private var shareRow: some View {
        HStack(spacing: 16) {
            posterThumb
            VStack(alignment: .leading, spacing: 8) {
                Text("Your take, story-sized").font(Typeface.label(15)).foregroundStyle(Palette.ink)
                    .fixedSize(horizontal: false, vertical: true)
                if let poster {
                    ShareLink(item: poster, preview: SharePreview(title, image: poster)) { shareLabel }
                        .buttonStyle(PressScaleStyle())
                        .accessibilityIdentifier("song.share")
                } else {
                    shareLabel.opacity(0.5)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 22, style: .continuous).fill(Palette.stageRaised))
        .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).strokeBorder(accent.opacity(0.25), lineWidth: 1))
        .padding(.horizontal, 20)
    }

    private var posterThumb: some View {
        let shape = RoundedRectangle(cornerRadius: 8, style: .continuous)
        return ZStack {
            if let poster { poster.resizable().scaledToFill() } else { Palette.surface }
        }
        .frame(width: 63, height: 112)
        .clipShape(shape)
        .overlay(shape.strokeBorder(.white.opacity(0.14), lineWidth: 1))
        .rotationEffect(.degrees(-6))
        .shadow(color: .black.opacity(0.5), radius: 10, y: 5)
        .padding(.leading, 4)
        .accessibilityHidden(true)
    }

    private var shareLabel: some View {
        Label("Share", systemImage: "square.and.arrow.up")
            .font(Typeface.label(14)).foregroundStyle(Palette.onAccent)
            .padding(.horizontal, 16).frame(minHeight: 40)
            .background(Capsule().fill(accent))
            .fixedSize()
    }

    private var buttons: some View {
        VStack(spacing: 6) {
            if let slower, let slowerTempo {
                Button(action: slower) { Label("Try it at \(slowerTempo) BPM", systemImage: "tortoise.fill") }
                    .font(Typeface.label(14)).foregroundStyle(accent)
                    .frame(minHeight: 36)
                    .accessibilityIdentifier("song.slower")
            }
            HStack(spacing: 10) {
                finaleButton("Perform again", primary: retryFirst, action: again)
                    .accessibilityIdentifier("song.again")
                finaleButton("Continue", primary: !retryFirst, action: proceed)
                    .accessibilityIdentifier("lesson.continue")
            }
            .padding(.horizontal, 20).padding(.bottom, 12)
        }
        .padding(.top, 6)
    }

    private func finaleButton(_ title: LocalizedStringKey, primary: Bool, action: @escaping () -> Void) -> some View {
        let shape = RoundedRectangle(cornerRadius: 18, style: .continuous)
        return Button(action: action) {
            Text(title)
                .font(Typeface.label(primary ? 18 : 16))
                .foregroundStyle(primary ? Palette.onAccent : Palette.ink)
                .lineLimit(1).minimumScaleFactor(0.75)
                .frame(maxWidth: .infinity, minHeight: 56)
                .background(shape.fill(primary ? AnyShapeStyle(accent) : AnyShapeStyle(Palette.stageRaised)))
                .contentShape(shape)
        }
        .buttonStyle(PressScaleStyle())
    }

    // MARK: Reveal

    /// The stars land first; the poster (a 1080 × 1920 render on the main thread) is drawn only once they have
    /// and the burst has settled, so the take → finale transition and the stars never hitch on it (QA M11). Share
    /// waits, dimmed, the moment it takes.
    private func reveal() async {
        withAnimation(.easeOut(duration: 0.45)) { appeared = true }
        for index in 0..<3 {
            try? await Task.sleep(for: .milliseconds(reduceMotion ? 80 : 340))
            guard !Task.isCancelled else { return }
            withAnimation(reduceMotion ? .easeOut(duration: 0.15) : .spring(response: 0.45, dampingFraction: 0.55)) { shownStars = index + 1 }
            if index < stars { SoundFX.shared.play(.star); Haptics.shared.lock(); burst += 1 }
        }
        try? await Task.sleep(for: .milliseconds(reduceMotion ? 120 : 520))
        guard !Task.isCancelled, poster == nil else { return }
        let image = ShareCardRenderer.image(storyCard, scale: displayScale, locale: locale, direction: layoutDirection)
        withAnimation(reduceMotion ? nil : .easeOut(duration: 0.3)) { poster = image }
    }

    private var storyCard: SongStoryCard {
        SongStoryCard(art: art, title: title, course: course.title.localized, stars: stars, take: take, accent: accent,
                      streak: store.streak.current)
    }
}

// MARK: - The poster

/// A finished take as a 9:16 poster for stories (360 × 640 pt, 1080 × 1920 px at 3×): the song's sleeve in its own
/// light with its record, the title, the stars, the score, the take note by note as a ribbon, and the sign-off.
/// Only the achievement, never personal data. Drawn still (no live effects), for `ImageRenderer`.
struct SongStoryCard: View {
    let art: CoverArt
    let title: String
    let course: String
    let stars: Int
    let take: SongTake
    let accent: Color
    var streak = 0

    private static let gold = Color(hex: 0xF0A93B)
    private static let starFill = LinearGradient(colors: [Color(hex: 0xFFE29A), Color(hex: 0xF0A93B)], startPoint: .top, endPoint: .bottom)

    var body: some View {
        VStack(spacing: 0) {
            topRow
            Spacer(minLength: 12)
            sleeve
            Spacer(minLength: 18)
            Text(course.uppercased()).font(Typeface.label(12)).tracking(1.8).foregroundStyle(accent).lineLimit(1)
            Text(verbatim: title).font(Typeface.display(34)).tracking(-0.8).foregroundStyle(Palette.ink)
                .multilineTextAlignment(.center).lineLimit(2).minimumScaleFactor(0.6)
                .padding(.top, 6)
            starRow.padding(.top, 14)
            score.padding(.top, 10)
            if !take.grades.isEmpty { ribbon.padding(.top, 16) }
            Spacer(minLength: 12)
            signature
        }
        .padding(.horizontal, 28).padding(.vertical, 30)
        .frame(width: 360, height: 640)
        .background { backdrop }
        .environment(\.colorScheme, .dark)
    }

    /// The sleeve's colours as a still mesh of light across the top (cheaper to render than a blur of the sleeve, and
    /// smooth at 3×), darkening toward the sign-off. Overlays only, so the poster keeps its 9:16 frame.
    private var backdrop: some View {
        Palette.stage
            .overlay(art.far.opacity(0.55))
            .overlay(alignment: .top) {
                CoverMesh(art: art, animated: false)
                    .frame(width: 360, height: 460)
                    .opacity(0.7)
                    .mask(LinearGradient(colors: [.black, .black, .black.opacity(0)], startPoint: .top, endPoint: .bottom))
            }
            .overlay(LinearGradient(colors: [.clear, Palette.stage.opacity(0.75), Palette.stage], startPoint: .center, endPoint: .bottom))
            .overlay(RadialGradient(colors: [.clear, Palette.stageDeep.opacity(0.85)], center: .center, startRadius: 220, endRadius: 520))
            .clipped()
    }

    private var topRow: some View {
        HStack {
            Text("TIMBRE").font(Typeface.label(13)).tracking(6).foregroundStyle(Palette.amber)
            Spacer(minLength: 12)
            HStack(spacing: 6) {
                Circle().fill(Palette.danger).frame(width: 7, height: 7)
                Text("Live take").font(Typeface.label(11)).tracking(1.2).textCase(.uppercase).foregroundStyle(Palette.ink)
            }
            .padding(.horizontal, 10).frame(height: 26)
            .background(Capsule().fill(.black.opacity(0.4)))
            .overlay(Capsule().strokeBorder(.white.opacity(0.14), lineWidth: 1))
        }
    }

    /// The sleeve with its record half out, the label in the song's colour.
    private var sleeve: some View {
        let side: CGFloat = 200
        return SongCover(art: art, corner: 10)
            .frame(width: side, height: side)
            .shadow(color: .black.opacity(0.6), radius: 22, y: 14)
            .background(alignment: .trailing) {
                ZStack {
                    Circle().fill(Color(hex: 0x0B0C0E))
                    Circle().strokeBorder(.white.opacity(0.08), lineWidth: side * 0.2).padding(side * 0.12)
                    Circle().strokeBorder(.white.opacity(0.14), lineWidth: 1)
                    Circle().fill(art.primary).frame(width: side * 0.3, height: side * 0.3)
                    Circle().fill(.black).frame(width: side * 0.04, height: side * 0.04)
                }
                .frame(width: side * 0.92, height: side * 0.92)
                .offset(x: side * 0.3)
            }
            .offset(x: -side * 0.15)
    }

    private var starRow: some View {
        HStack(alignment: .bottom, spacing: 10) {
            ForEach(0..<3, id: \.self) { index in
                let earned = index < stars
                Image(systemName: "star.fill")
                    .font(.system(size: index == 1 ? 50 : 38, weight: .bold))
                    .foregroundStyle(earned ? AnyShapeStyle(Self.starFill) : AnyShapeStyle(Color.white.opacity(0.1)))
                    .shadow(color: earned ? Self.gold.opacity(0.55) : .clear, radius: 12)
                    .offset(y: index == 1 ? -8 : 0)
            }
        }
    }

    private var score: some View {
        HStack(alignment: .firstTextBaseline, spacing: 14) {
            VStack(spacing: 0) {
                Text("\(take.percent)%").font(Typeface.note(46)).foregroundStyle(Palette.ink)
                Text("accuracy").font(Typeface.label(12)).foregroundStyle(Palette.inkSoft)
            }
            if let points = take.points {
                Rectangle().fill(.white.opacity(0.14)).frame(width: 1, height: 44)
                VStack(spacing: 0) {
                    Text(points, format: .number).font(Typeface.note(30)).foregroundStyle(Palette.ink)
                    Text("Score").font(Typeface.label(12)).foregroundStyle(Palette.inkSoft)
                }
            }
            if let combo = take.bestCombo, combo > 1 {
                Rectangle().fill(.white.opacity(0.14)).frame(width: 1, height: 44)
                VStack(spacing: 0) {
                    Text("×\(combo)").font(Typeface.note(30)).foregroundStyle(Palette.flame)
                    Text("Best combo").font(Typeface.label(12)).foregroundStyle(Palette.inkSoft)
                }
            }
        }
        .lineLimit(1)
        .minimumScaleFactor(0.6)
    }

    /// The take note by note, in its grades' colours; a whole song's take (two hundred notes and more) folded into
    /// 96 marks end to end, so the poster shows all of it rather than its opening.
    private var ribbon: some View {
        let grades = Self.folded(take.grades, into: 96)
        return HStack(spacing: grades.count > 48 ? 1 : 2) {
            ForEach(Array(grades.enumerated()), id: \.offset) { _, grade in
                Capsule().fill(SongTake.color(grade, accent: accent)).frame(height: grade == .perfect ? 10 : 7)
            }
        }
        .frame(height: 10)
    }

    /// `grades` as at most `count` marks: each a run of neighbouring notes, graded by their average credit.
    static func folded(_ grades: [PlayAlongJudge.Grade], into count: Int) -> [PlayAlongJudge.Grade] {
        guard count > 0, grades.count > count else { return grades }
        return (0..<count).map { index -> PlayAlongJudge.Grade in
            let lower = index * grades.count / count
            let upper = min(grades.count, max(lower + 1, (index + 1) * grades.count / count))
            let run = grades[lower..<upper]
            let credit = run.reduce(0.0) { $0 + PlayAlongJudge.credit($1) } / Double(max(1, run.count))
            if credit >= 0.95 { return .perfect }
            if credit >= 0.7 { return .good }
            return credit >= 0.35 ? .ok : .miss
        }
    }

    private var signature: some View {
        VStack(spacing: 10) {
            if streak > 1 {
                Label("\(streak)-day streak", systemImage: "flame.fill").font(Typeface.label(13)).foregroundStyle(Color(hex: 0xFFD3A8))
            }
            HStack(spacing: 10) {
                Rectangle().fill(Color.white.opacity(0.12)).frame(height: 1)
                HStack(spacing: 6) {
                    Image(systemName: "tuningfork").font(.system(size: 11, weight: .bold)).foregroundStyle(Palette.mint)
                    Text("In tune with Timbre").font(Typeface.label(11)).tracking(0.4).foregroundStyle(Palette.inkSoft)
                }
                .fixedSize()
                Rectangle().fill(Color.white.opacity(0.12)).frame(height: 1)
            }
        }
    }
}
