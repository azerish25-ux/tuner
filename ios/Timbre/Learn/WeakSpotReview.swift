import SwiftUI
import TimbreCore

// MARK: - Reviews

/// Two reviews play in the usual `LessonPlayer`, earn XP like any lesson and never change what is unlocked:
/// - Spaced review (`SpacedReview`, TimbreCore): what slipped in a lesson comes back the next day, then at growing
///   intervals until it sticks. When something in a course is due, its review is a three-minute session of it
///   (topped up with the weakest items), offered in Today, on the path and from "Practice weak spots".
/// - The weak-spot review, built from the notes and chords that went badly in recent lessons, offered on the path
///   every few lessons (`LearnProgress.reviewDue`) when nothing is due.
extension AppStore {
    /// The course's review lesson: the spaced review when something is due, else the weak-spot review; nil when
    /// there is nothing to review.
    func weakSpotReview(in course: LearnCourse) -> Lesson? {
        spacedReview(in: course)
            ?? WeakSpotReview.lesson(for: course, progress: learn, text: .app, strings: course.stringCount, strums: course.strums)
    }

    /// The path offers a review: something is due, or a few lessons finished since the last one and something to review.
    func reviewDue(in course: LearnCourse) -> Bool { reviewDueCount(in: course) > 0 || learn.reviewDue(in: course) }

    // MARK: Spaced review

    /// The schedule: the saved deck, or (until the first lesson saves one) a deck seeded from Learn's weak spots.
    var reviewDeck: ReviewDeck {
        if let deck = settings.spacedReview { return deck }
        let curriculum = self.curriculum
        return ReviewDeck.seeded(from: learn.weakSpots) { lessonId in curriculum.lesson(id: lessonId)?.course.id }
    }

    /// Items of a course due today or earlier.
    func reviewDueCount(in course: LearnCourse) -> Int { reviewDeck.dueCount(in: course.id) }

    /// Items due in Learn's course, Today's course (the badge on Today's review row).
    var dailyReviewDueCount: Int {
        guard let course = learnCourse else { return 0 }
        return reviewDueCount(in: course)
    }

    /// The items a course's spaced review would ask for now, in order.
    func spacedReviewItems(in course: LearnCourse) -> [ReviewItem] { reviewDeck.session(in: course.id).map(\.item) }

    /// About three minutes of what is due in the course; nil when nothing is.
    func spacedReview(in course: LearnCourse) -> Lesson? {
        let deck = reviewDeck
        guard deck.dueCount(in: course.id) > 0 else { return nil }
        return SpacedReview.lesson(courseId: course.id, cards: deck.session(in: course.id), text: .spaced,
                                   strings: course.stringCount, strums: course.strums)
    }

    /// Today's review: the review of Learn's course (Today follows it), when there is one.
    var dailyReviewSession: ReviewSession? {
        guard let course = learnCourse, let lesson = weakSpotReview(in: course) else { return nil }
        return ReviewSession(course: course, lesson: lesson)
    }
}

extension ReviewText {
    /// The review's words, localized in the app's strings (the curriculum's own text lives in Learn.strings).
    static var app: ReviewText {
        ReviewText(title: LearnText(String(localized: "Weak-spot review")),
                   intro: LearnText(String(localized: "A few notes and chords slipped in recent lessons. Take them slowly, then in time.")),
                   notesHint: LearnText(String(localized: "The notes that slipped")),
                   alongTitle: LearnText(String(localized: "Now in time")))
    }

    /// The spaced review's words.
    static var spaced: ReviewText {
        ReviewText(title: LearnText(String(localized: "Review")),
                   intro: LearnText(String(localized: "What slipped in recent lessons, back just before you’d forget it.")),
                   notesHint: LearnText(String(localized: "The notes that slipped")),
                   alongTitle: LearnText(String(localized: "Now in time")))
    }
}

// MARK: - Opening a review

/// A review opened over the screen that offered it (the Play hub's Today card).
struct ReviewSession: Identifiable {
    let course: LearnCourse
    let lesson: Lesson
    var id: String { lesson.id }
}

/// Presents a review full screen in the lesson player. A lesson its results open next (the coach's replay, one
/// more review) follows once this one has gone.
private struct ReviewSessionCover: ViewModifier {
    @Binding var session: ReviewSession?
    @EnvironmentObject var store: AppStore

    func body(content: Content) -> some View {
        content.fullScreenCover(item: $session) { item in
            LessonPlayer(course: item.course, lesson: item.lesson) { next in
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) { open(next, in: item.course) }
            }
            .environmentObject(store)
        }
    }

    private func open(_ lesson: Lesson, in course: LearnCourse) {
        guard store.canPlay(lesson) else { store.presentPaywall("lesson", lesson: lesson); return }
        session = ReviewSession(course: course, lesson: lesson)
    }
}

extension View {
    /// Plays `session` full screen while it is set (Today's review on the Play hub).
    func reviewSessionCover(_ session: Binding<ReviewSession?>) -> some View {
        modifier(ReviewSessionCover(session: session))
    }
}

// MARK: - The path's review stop

/// The path's review stop: what's in it as chips, how many items are due, and a tap to start. Shows only when a
/// review is due, unless `always` (a "Practice weak spots" shelf).
struct WeakSpotReviewCard: View {
    let course: LearnCourse
    var always = false
    let onStart: (Lesson) -> Void
    @EnvironmentObject private var store: AppStore

    var body: some View {
        if always || store.reviewDue(in: course), let lesson = store.weakSpotReview(in: course) {
            card(lesson, spaced: SpacedReview.isSession(lesson.id))
        }
    }

    private func card(_ lesson: Lesson, spaced: Bool) -> some View {
        let tint = spaced ? Palette.mint : Palette.amber
        let shape = RoundedRectangle(cornerRadius: Metrics.corner, style: .continuous)
        return Button { Haptics.shared.selection(); onStart(lesson) } label: {
            HStack(spacing: 14) {
                IconOrb(symbol: spaced ? "arrow.clockwise" : "scope", tint: tint, size: 48)
                VStack(alignment: .leading, spacing: 6) {
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text(spaced ? LocalizedStringKey("Review") : LocalizedStringKey("Weak-spot review"))
                            .font(Typeface.cardTitle).foregroundStyle(Palette.ink)
                        if spaced { ReviewDueBadge(count: store.reviewDueCount(in: course)) }
                    }
                    if spaced {
                        ReviewItemChips(items: store.spacedReviewItems(in: course))
                    } else {
                        WeakSpotChips(spots: store.learn.weakSpots(in: course))
                    }
                    Text("\(lesson.minutes) min · +\(lesson.xp) XP").font(.subheadline).foregroundStyle(Palette.inkSoft)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right").font(.system(size: 14, weight: .bold)).foregroundStyle(Palette.inkFaint)
            }
            .padding(Metrics.cardPadding)
            .background(shape.fill(Palette.stageRaised).overlay(LinearGradient(colors: [tint.opacity(0.14), .clear], startPoint: .leading, endPoint: .trailing).clipShape(shape)))
            .overlay(shape.strokeBorder(tint.opacity(0.35), lineWidth: 1))
            .contentShape(shape)
        }
        .buttonStyle(PressScaleStyle())
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("learn.review")
    }
}

/// How many review items are due ("6 due"): a small mint pill beside a review's name. Nothing when none are.
struct ReviewDueBadge: View {
    let count: Int
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        if count > 0 {
            Text("\(count) due")
                .font(Typeface.label(12)).foregroundStyle(Palette.onAccent)
                .lineLimit(1)
                .padding(.horizontal, 7).padding(.vertical, 2)
                .background(Capsule().fill(Palette.mint))
                .fixedSize()
                .contentTransition(.numericText(value: Double(count)))
                .adaptiveAnimation(Motion.pop, value: count)
                .transition(.adaptive(.scale(scale: 0.6).combined(with: .opacity), reduceMotion: reduceMotion))
        }
    }
}

/// A compact "Practice weak spots" button (for the results screen): shows whenever there is something to review.
struct PracticeWeakSpotsButton: View {
    let course: LearnCourse
    var accent: Color = Palette.amber
    let onStart: (Lesson) -> Void
    @EnvironmentObject private var store: AppStore

    var body: some View {
        if let lesson = store.weakSpotReview(in: course) {
            Button { Haptics.shared.selection(); onStart(lesson) } label: {
                Label("Practice weak spots", systemImage: "scope")
                    .font(Typeface.label(15)).foregroundStyle(accent)
                    .padding(.horizontal, 18).frame(minHeight: 44)
                    .background(Capsule().fill(accent.opacity(0.12)))
                    .overlay(Capsule().strokeBorder(accent.opacity(0.35), lineWidth: 1))
                    .contentShape(Capsule())
            }
            .buttonStyle(PressScaleStyle())
            .accessibilityIdentifier("results.weakspots")
        }
    }
}

/// The first few weak spots by name ("G3", "Em"), with a count of the rest.
struct WeakSpotChips: View {
    let spots: [WeakSpot]
    private let shown = 4

    var body: some View {
        HStack(spacing: 6) {
            ForEach(Array(spots.prefix(shown).enumerated()), id: \.offset) { _, spot in
                Text(Self.name(spot.item)).font(Typeface.label(12)).foregroundStyle(Palette.amber)
                    .padding(.horizontal, 8).padding(.vertical, 3)
                    .background(Capsule().fill(Palette.amber.opacity(0.14)))
            }
            if spots.count > shown {
                Text(verbatim: "+\(spots.count - shown)").font(Typeface.label(12)).foregroundStyle(Palette.inkSoft)
            }
        }
        .lineLimit(1)
    }

    static func name(_ item: PracticeItem) -> String {
        switch item {
        case let .note(midi, _): return NoteName.name(midi)
        case let .chord(spec): return spec.name
        }
    }
}

/// A spaced review's first few items: notes and chords by name ("G3", "Em"), a change as "G→C", rhythms and
/// questions by symbol; a count of the rest.
struct ReviewItemChips: View {
    let items: [ReviewItem]
    private let shown = 4

    var body: some View {
        HStack(spacing: 6) {
            ForEach(Array(items.prefix(shown).enumerated()), id: \.offset) { _, item in chip(item) }
            if items.count > shown {
                Text(verbatim: "+\(items.count - shown)").font(Typeface.label(12)).foregroundStyle(Palette.inkSoft)
            }
        }
        .lineLimit(1)
    }

    @ViewBuilder private func chip(_ item: ReviewItem) -> some View {
        Group {
            if let name = Self.name(item) {
                Text(verbatim: name)
            } else {
                Image(systemName: Self.symbol(item.kind)).accessibilityLabel(Self.label(item.kind))
            }
        }
        .font(Typeface.label(12)).foregroundStyle(Palette.mint)
        .padding(.horizontal, 8).padding(.vertical, 3)
        .background(Capsule().fill(Palette.mint.opacity(0.14)))
    }

    /// A note's or chord's name, a change's two chords; nil for the kinds shown by symbol.
    static func name(_ item: ReviewItem) -> String? {
        switch item {
        case let .note(midi, _): return NoteName.name(midi)
        case let .chord(spec): return spec.name
        case let .change(from, to): return from.name + "→" + to.name
        case .rhythm, .question: return nil
        }
    }

    static func symbol(_ kind: ReviewItem.Kind) -> String {
        switch kind {
        case .note: return "music.note"
        case .chord: return "hand.raised.fingers.spread"
        case .change: return "arrow.left.arrow.right"
        case .rhythm: return "metronome"
        case .interval: return "ear"
        case .quiz: return "questionmark"
        }
    }

    static func label(_ kind: ReviewItem.Kind) -> Text {
        switch kind {
        case .rhythm: return Text("Rhythm")
        case .interval: return Text("Ear training")
        case .quiz: return Text("Quiz")
        case .note, .chord, .change: return Text("Review")
        }
    }
}
