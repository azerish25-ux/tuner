import SwiftUI
import TimbreCore

/// Onboarding's answers before they are saved (`AppStore.completeOnboarding` runs after the paywall closes),
/// so the paywall can tell the plan the plan screen just built.
struct PaywallAnswers: Equatable {
    var instrumentId: String?
    var level: String
    var goal: String
    var minutes: Int
}

/// The person's plan as the paywall tells it: three outcomes for their goal and course, and the first
/// milestones of the course, as the onboarding plan screen lists them (the first lesson, then the units
/// after it), placed on the plan's pace of one lesson a day (Today's set holds one lesson).
struct PaywallPlan {
    enum Art {
        case course(LearnCourse)
        case glyph(CourseGlyph, Color)
        /// A catalogue instrument's render or photograph.
        case instrument(String)
        case symbol(String, Color)
    }

    struct Outcome: Identifiable {
        let id: Int
        let text: Text
        let art: Art
    }

    struct Milestone: Identifiable {
        let day: Int
        let title: String
        var id: Int { day }
    }

    let course: LearnCourse?
    let outcomes: [Outcome]
    /// Day 1 and the units reached within `horizon` days; empty when there is less than that to show.
    let milestones: [Milestone]

    var accent: Color { course.map { Palette.accent($0.accent) } ?? Palette.mint }

    /// Onboarding's answers when given (the plan screen's own helpers), else what is saved: the goal, the
    /// course Learn shows, its next lesson and the daily minutes.
    @MainActor static func make(store: AppStore, answers: PaywallAnswers?, horizon: Int) -> PaywallPlan {
        let goal: String
        let instrumentId: String?
        let course: LearnCourse?
        let start: Lesson?
        let minutes: Int
        if let answers {
            let instrument = answers.instrumentId.flatMap { store.catalog.instrument(id: $0)?.id }
            goal = answers.goal
            instrumentId = instrument
            course = store.onboardingCourse(instrumentId: instrument, goal: answers.goal)
            let progress = store.onboardingProgress(level: answers.level, instrumentId: instrument, goal: answers.goal)
            start = course.flatMap { progress.nextLesson(in: $0) }
            minutes = answers.minutes
        } else {
            goal = store.settings.goal ?? "practice"
            instrumentId = store.instrument.id
            course = store.learnCourse
            start = course.flatMap { store.learn.nextLesson(in: $0) }
            minutes = store.dailyMinutes
        }
        let lessons = course?.lessons ?? []
        let first = start.flatMap { lesson in lessons.firstIndex { $0.id == lesson.id } }
        // One lesson a day from the first one: the day the plan reaches its first song.
        let songDay = first.flatMap { from in lessons[from...].firstIndex { $0.kind == .song }.map { $0 - from + 1 } }
        return PaywallPlan(course: course,
                           outcomes: plannedOutcomes(goal: goal, course: course, songDay: songDay, minutes: minutes, instrumentId: instrumentId, store: store),
                           milestones: plannedMilestones(course: course, start: start, horizon: horizon))
    }

    /// "Today: the first lesson", then the first day of each following unit, up to three within the horizon.
    private static func plannedMilestones(course: LearnCourse?, start: Lesson?, horizon: Int) -> [Milestone] {
        guard let course, let start, let first = course.lessons.firstIndex(where: { $0.id == start.id }),
              let startUnit = course.units.firstIndex(where: { unit in unit.lessons.contains { $0.id == start.id } }) else { return [] }
        var list = [Milestone(day: 1, title: start.title.localized)]
        var opening = 0
        for (number, unit) in course.units.enumerated() {
            let unitStart = opening
            opening += unit.lessons.count
            guard number > startUnit else { continue }
            let day = unitStart - first + 1
            guard day <= horizon, list.count < 3 else { break }
            list.append(Milestone(day: day, title: unit.title.localized))
        }
        return list.count > 1 ? list : []
    }

    /// What Pro does for this goal, said as results. The daily minutes close every set.
    @MainActor private static func plannedOutcomes(goal: String, course: LearnCourse?, songDay: Int?, minutes: Int,
                                            instrumentId: String?, store: AppStore) -> [Outcome] {
        let daily = Outcome(id: 2, text: Text("\(minutes) minutes a day, planned for you"), art: .symbol("flame.fill", Palette.flame))
        func own(_ id: String, _ glyph: CourseGlyph, _ accent: Color) -> Art {
            store.curriculum.course(id: id).map { Art.course($0) } ?? .glyph(glyph, accent)
        }
        switch goal {
        case "ear":
            return [Outcome(id: 0, text: Text("Name intervals and chords by ear"), art: own("ear", .ear, Palette.violet)),
                    Outcome(id: 1, text: Text("Every ear game and practice tool"), art: .glyph(.notes, Palette.amber)),
                    daily]
        case "voice":
            return [Outcome(id: 0, text: Text("Sing in tune"), art: own("voice", .voice, Palette.mint)),
                    Outcome(id: 1, text: Text("Range test and exercises"), art: .glyph(.ear, Palette.violet)),
                    daily]
        case "rhythm":
            return [Outcome(id: 0, text: Text("Keep better time"), art: own("rhythm", .metronome, Palette.coral)),
                    Outcome(id: 1, text: Text("Accents, odd meters, tap"), art: .glyph(.notes, Palette.amber)),
                    daily]
        case "tune":
            return [Outcome(id: 0, text: Text("In tune in seconds, on any instrument"), art: instrumentId.map { Art.instrument($0) } ?? .glyph(.note, Palette.mint)),
                    Outcome(id: 1, text: Text("Unlimited custom tunings and string health"), art: .symbol("slider.horizontal.3", Palette.sky)),
                    daily]
        default:
            // Practice: a song soon and lessons on their own instrument; a course without one (theory) keeps the tools.
            if let played = course, let instrument = played.instrument, instrument != "voice" {
                let song = (songDay ?? .max) <= 7 ? Text("Play your first song this week") : Text("Play your first song")
                // "Guitar lessons…", also from the Songs or Originals course (played on the guitar too).
                let instrumentCourse = store.curriculum.courses.first { $0.instrument == instrument } ?? played
                return [Outcome(id: 0, text: song, art: .glyph(.notes, Palette.amber)),
                        Outcome(id: 1, text: Text("\(instrumentCourse.title.localized) lessons that listen as you play"), art: .course(instrumentCourse)),
                        daily]
            }
            let lessons = Text("\(store.curriculum.lessonCount) lessons across \(store.curriculum.courses.count) courses")
            return [Outcome(id: 0, text: Text("Every ear game and practice tool"), art: own("ear", .ear, Palette.violet)),
                    Outcome(id: 1, text: lessons, art: course.map { Art.course($0) } ?? .glyph(.clef, Palette.sky)),
                    daily]
        }
    }
}
