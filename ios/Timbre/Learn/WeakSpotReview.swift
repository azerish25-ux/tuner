import SwiftUI
import TimbreCore

// MARK: - Weak-spot reviews

/// A review lesson built on the fly from the notes and chords that went badly in recent lessons. It is
/// offered on the path every few lessons (`reviewDue`) and from "Practice weak spots"; it plays in the
/// usual `LessonPlayer`, earns XP like any lesson and never changes what is unlocked.
extension AppStore {
    /// The course's review lesson; nil when there is nothing to review.
    func weakSpotReview(in course: LearnCourse) -> Lesson? {
        WeakSpotReview.lesson(for: course, progress: learn, text: .app, strings: course.stringCount, strums: course.strums)
    }

    /// The path offers a review: a few lessons finished since the last one, and something to review.
    func reviewDue(in course: LearnCourse) -> Bool { learn.reviewDue(in: course) }
}

extension ReviewText {
    /// The review's words, localized in the app's strings (the curriculum's own text lives in Learn.strings).
    static var app: ReviewText {
        ReviewText(title: LearnText(String(localized: "Weak-spot review")),
                   intro: LearnText(String(localized: "A few notes and chords slipped in recent lessons. Take them slowly, then in time.")),
                   notesHint: LearnText(String(localized: "The notes that slipped")),
                   alongTitle: LearnText(String(localized: "Now in time")))
    }
}

/// The path's review stop: what's in it (the weak notes and chords as chips) and a tap to start.
/// Shows only when a review is due, unless `always` (a "Practice weak spots" shelf).
struct WeakSpotReviewCard: View {
    let course: LearnCourse
    var always = false
    let onStart: (Lesson) -> Void
    @EnvironmentObject private var store: AppStore

    var body: some View {
        if always || store.reviewDue(in: course), let lesson = store.weakSpotReview(in: course) {
            let shape = RoundedRectangle(cornerRadius: Metrics.corner, style: .continuous)
            Button { Haptics.shared.selection(); onStart(lesson) } label: {
                HStack(spacing: 14) {
                    IconOrb(symbol: "scope", tint: Palette.amber, size: 48)
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Weak-spot review").font(Typeface.cardTitle).foregroundStyle(Palette.ink)
                        WeakSpotChips(spots: store.learn.weakSpots(in: course))
                        Text("\(lesson.minutes) min · +\(lesson.xp) XP").font(.subheadline).foregroundStyle(Palette.inkSoft)
                    }
                    Spacer(minLength: 0)
                    Image(systemName: "chevron.right").font(.system(size: 14, weight: .bold)).foregroundStyle(Palette.inkFaint)
                }
                .padding(Metrics.cardPadding)
                .background(shape.fill(Palette.stageRaised).overlay(LinearGradient(colors: [Palette.amber.opacity(0.14), .clear], startPoint: .leading, endPoint: .trailing).clipShape(shape)))
                .overlay(shape.strokeBorder(Palette.amber.opacity(0.35), lineWidth: 1))
                .contentShape(shape)
            }
            .buttonStyle(PressScaleStyle())
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("learn.review")
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
