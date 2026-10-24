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

/// The person's plan as the paywall tells it: three outcomes, led by what they just tried to open and then
/// their goal and course, and the first milestones of the course, as the onboarding plan screen lists them
/// (the first lesson, then the units after it), placed on the plan's pace of one lesson a day (Today's set
/// holds one lesson).
struct PaywallPlan {
    enum Art {
        case course(LearnCourse)
        case glyph(CourseGlyph, Color)
        /// A catalogue instrument's render or photograph.
        case instrument(String)
        case symbol(String, Color)
    }

    struct Outcome: Identifiable {
        /// What the outcome promises ("drone", "song", "daily"…): the same promise is never listed twice.
        let id: String
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
    /// Today's lesson, the plan's first.
    let firstLesson: String?
    /// The first day of each unit after today's that the plan reaches within the horizon, up to two.
    let milestones: [Milestone]

    var accent: Color { course.map { Palette.accent($0.accent) } ?? Palette.mint }

    /// Onboarding's answers when given (the plan screen's own helpers), else what is saved: the goal, the
    /// course Learn shows, its next lesson and the daily minutes. `reason` is what opened the paywall
    /// (`AppStore.paywallReason`); nil for onboarding and the generic upsell.
    @MainActor static func make(store: AppStore, answers: PaywallAnswers?, horizon: Int, reason: String?) -> PaywallPlan {
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
        let planned = plannedOutcomes(goal: goal, course: course, songDay: songDay, minutes: minutes, instrumentId: instrumentId, store: store)
        return PaywallPlan(course: course,
                           outcomes: merged(reasonOutcomes(reason, course: course, instrumentId: instrumentId, store: store), planned),
                           firstLesson: start?.title.localized,
                           milestones: plannedMilestones(course: course, start: start, horizon: horizon))
    }

    /// What was tapped first, then the plan's own outcomes, three in all and each promise once.
    private static func merged(_ lead: [Outcome], _ planned: [Outcome]) -> [Outcome] {
        var list: [Outcome] = []
        for outcome in lead + planned where !list.contains(where: { $0.id == outcome.id }) {
            list.append(outcome)
        }
        return Array(list.prefix(3))
    }

    /// The first day of each unit after today's, up to two within the horizon.
    private static func plannedMilestones(course: LearnCourse?, start: Lesson?, horizon: Int) -> [Milestone] {
        guard let course, let start, let first = course.lessons.firstIndex(where: { $0.id == start.id }),
              let startUnit = course.units.firstIndex(where: { unit in unit.lessons.contains { $0.id == start.id } }) else { return [] }
        var list: [Milestone] = []
        var opening = 0
        for (number, unit) in course.units.enumerated() {
            let unitStart = opening
            opening += unit.lessons.count
            guard number > startUnit else { continue }
            let day = unitStart - first + 1
            guard day <= horizon, list.count < 2 else { break }
            list.append(Milestone(day: day, title: unit.title.localized))
        }
        return list
    }

    // MARK: Outcomes

    /// A course's own art when the catalogue has it, else its emblem.
    @MainActor private static func own(_ id: String, _ glyph: CourseGlyph, _ accent: Color, store: AppStore) -> Art {
        store.curriculum.course(id: id).map { Art.course($0) } ?? .glyph(glyph, accent)
    }

    /// The outcomes that answer what was tapped: the tool, instrument or lesson itself first, then its family.
    /// Empty for onboarding, the generic upsell and anything unknown, which lead with the plan.
    @MainActor private static func reasonOutcomes(_ reason: String?, course: LearnCourse?, instrumentId: String?, store: AppStore) -> [Outcome] {
        guard let reason else { return [] }
        let tools = Outcome(id: "tools", text: Text("Every ear game and practice tool"), art: own("ear", .ear, Palette.violet, store: store))
        let kit = Outcome(id: "kit", text: Text("Chords, scales, intonation and drone"), art: .glyph(.notes, Palette.amber))
        let custom = Outcome(id: "custom", text: Text("Unlimited custom tunings and string health"), art: .symbol("slider.horizontal.3", Palette.sky))
        let tapped = store.paywallInstrumentId ?? instrumentId
        let tune = Outcome(id: "tune", text: Text("In tune in seconds, on any instrument"),
                           art: tapped.map { Art.instrument($0) } ?? .glyph(.note, Palette.mint))
        switch reason {
        case "lesson":
            return [lessonsOutcome(store.paywallLessonId.flatMap { store.curriculum.lesson(id: $0)?.course } ?? course, store: store)]
        case "instrument", "tuning":
            return [tune, custom]
        case "custom_tuning":
            return [Outcome(id: "insights", text: Text("Custom tunings, string health and accuracy insights"), art: .symbol("slider.horizontal.3", Palette.sky)), tune]
        case "precision":
            return [Outcome(id: "strobe", text: Text("Strobe precision"), art: .symbol("scope", Palette.mint)), tune]
        case "temperament":
            return [Outcome(id: "temperaments", text: temperaments, art: .symbol("slider.horizontal.3", Palette.violet)), custom]
        case "capo", "transpose":
            return [Outcome(id: "capo", text: Text("Capo and transposition"), art: .symbol("arrow.up.arrow.down", Palette.sky)), custom]
        case "journey":
            return [Outcome(id: "trends", text: Text("Accuracy trends and milestones, measured on device"), art: .symbol("chart.line.uptrend.xyaxis", Palette.mint))]
        case "voice":
            return [Outcome(id: "range", text: Text("Range test and exercises"), art: own("voice", .voice, Palette.mint, store: store)), tools]
        default:
            break
        }
        if reason.hasSuffix("drone") {
            return [Outcome(id: "drone", text: Text("Intonation over a drone"), art: .symbol("waveform.path", Palette.sky)), tools]
        }
        if reason.hasSuffix("chords") || reason.hasSuffix("chord") {
            return [Outcome(id: "chords", text: Text("Every shape, any tuning"), art: .symbol("hand.raised.fingers.spread", Palette.sky)), kit]
        }
        if reason.hasSuffix("scales") || reason.hasSuffix("scale") {
            return [Outcome(id: "scales", text: Text("Fretboard maps"), art: .symbol("point.3.connected.trianglepath.dotted", Palette.sky)), kit]
        }
        if reason.hasSuffix("intonation") {
            return [Outcome(id: "intonation", text: Text("Intonation checks at the 12th fret"), art: .symbol("ruler", Palette.sky)), kit]
        }
        if reason.hasPrefix("ear.") {
            return [Outcome(id: "ear", text: Text("Name intervals and chords by ear"), art: own("ear", .ear, Palette.violet, store: store)),
                    Outcome(id: "drills", text: Text("Pitch, intervals, chords"), art: .glyph(.notes, Palette.amber))]
        }
        if reason.hasPrefix("metronome.") {
            return [Outcome(id: "meter", text: Text("Accents, odd meters, tap"), art: own("rhythm", .metronome, Palette.coral, store: store)), kit]
        }
        if reason.hasPrefix("practice.") || reason.hasPrefix("daily.") {
            return [kit, tools]
        }
        return []
    }

    /// "Guitar lessons that listen as you play" for a played course (the Songs course too); the whole catalogue otherwise.
    @MainActor private static func lessonsOutcome(_ course: LearnCourse?, store: AppStore) -> Outcome {
        if let played = course, let instrument = played.instrument, instrument != "voice" {
            let instrumentCourse = store.curriculum.courses.first { $0.instrument == instrument } ?? played
            return Outcome(id: "lessons", text: Text("\(instrumentCourse.title.localized) lessons that listen as you play"), art: .course(instrumentCourse))
        }
        return Outcome(id: "catalog", text: Text("\(store.curriculum.lessonCount) lessons across \(store.curriculum.courses.count) courses"),
                       art: course.map { Art.course($0) } ?? .glyph(.clef, Palette.sky))
    }

    /// "Just, Meantone and Werckmeister", in the locale's own list style.
    private static var temperaments: Text {
        let names = [Temperament.just, Temperament.meantone, Temperament.werckmeister].map { temperament in
            NSLocalizedString("timbre_bench_temperament_" + temperament.id, bundle: .main, value: temperament.name, comment: "")
        }
        return Text(verbatim: names.formatted(.list(type: .and)))
    }

    /// What Pro does for this goal, said as results. The daily minutes close every set.
    @MainActor private static func plannedOutcomes(goal: String, course: LearnCourse?, songDay: Int?, minutes: Int,
                                                   instrumentId: String?, store: AppStore) -> [Outcome] {
        let daily = Outcome(id: "daily", text: Text("\(minutes) minutes a day, planned for you"), art: .symbol("flame.fill", Palette.flame))
        switch goal {
        case "ear":
            return [Outcome(id: "ear", text: Text("Name intervals and chords by ear"), art: own("ear", .ear, Palette.violet, store: store)),
                    Outcome(id: "tools", text: Text("Every ear game and practice tool"), art: .glyph(.notes, Palette.amber)),
                    daily]
        case "voice":
            return [Outcome(id: "sing", text: Text("Sing in tune"), art: own("voice", .voice, Palette.mint, store: store)),
                    Outcome(id: "range", text: Text("Range test and exercises"), art: .glyph(.ear, Palette.violet)),
                    daily]
        case "rhythm":
            return [Outcome(id: "time", text: Text("Keep better time"), art: own("rhythm", .metronome, Palette.coral, store: store)),
                    Outcome(id: "meter", text: Text("Accents, odd meters, tap"), art: .glyph(.notes, Palette.amber)),
                    daily]
        case "tune":
            return [Outcome(id: "tune", text: Text("In tune in seconds, on any instrument"), art: instrumentId.map { Art.instrument($0) } ?? .glyph(.note, Palette.mint)),
                    Outcome(id: "custom", text: Text("Unlimited custom tunings and string health"), art: .symbol("slider.horizontal.3", Palette.sky)),
                    daily]
        default:
            // Practice: a song soon and lessons on their own instrument; a course without one (theory) keeps the tools.
            if let played = course, let instrument = played.instrument, instrument != "voice" {
                let song = (songDay ?? .max) <= 7 ? Text("Play your first song this week") : Text("Play your first song")
                return [Outcome(id: "song", text: song, art: .glyph(.notes, Palette.amber)),
                        lessonsOutcome(played, store: store),
                        daily]
            }
            return [Outcome(id: "tools", text: Text("Every ear game and practice tool"), art: own("ear", .ear, Palette.violet, store: store)),
                    lessonsOutcome(course, store: store),
                    daily]
        }
    }
}
