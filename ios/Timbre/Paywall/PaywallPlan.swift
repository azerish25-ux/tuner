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

/// The person's plan as the paywall tells it: three outcomes, led by what they just tried to open and then their goal
/// and course (in onboarding, the plan's own and then every instrument and every ear game and tool); what the plan
/// reaches next on its pace of one lesson a day (Today's set holds one lesson): the first song it gets to, and the units
/// after today's whose names don't just repeat today's lesson; and the songs for the hero's rail. A paywall opened
/// from a tool starts the track with that tool instead (`Focus`).
struct PaywallPlan {
    /// One promise of Pro, said as a result. Every outcome on every paywall wears the same kind of icon: an SF Symbol
    /// in its colour on a tinted disc (`IconOrb`, the app's feature icon), as the plan track's nodes are drawn.
    struct Outcome: Identifiable {
        /// What the outcome promises ("drone", "song", "daily"…): the same promise is never listed twice.
        let id: String
        let text: Text
        let symbol: String
        let tint: Color
    }

    struct Milestone: Identifiable {
        /// A song to play ("Play “Ode to Joy”", the song's name without its lesson's subtitle), a unit to start, by
        /// its name, or the next step with the tool that opened the paywall ("Drone + intonation check").
        enum Kind { case song, unit, focus }
        let day: Int
        let title: String
        var kind = Kind.unit
        /// The node's symbol for a tool's step.
        var symbol: String? = nil
        var id: Int { day }
    }

    /// The tool that opened the paywall, as the trial track tells it: Today starts it, day 2 takes it further.
    struct Focus {
        /// Under "Everything unlocked" on Today ("Tanpura").
        let today: String
        /// Day 2 ("Drone + intonation check").
        let next: String
        /// Day 2's node.
        let symbol: String
    }

    /// A song on the plan hero's rail, its sleeve as the Songs shelf draws it.
    struct RailSong: Identifiable {
        let id: String
        /// The song by its name ("Greensleeves", not "Greensleeves: the chords"), for VoiceOver.
        let title: String
        let art: CoverArt
    }

    let course: LearnCourse?
    /// The person's instrument: onboarding's answer, else the one they tune (or the Pro one they chose and tune
    /// in Chromatic until Pro opens it). Nil when they sing, or tune by ear in Chromatic with none chosen.
    let instrumentId: String?
    let outcomes: [Outcome]
    /// What Today starts, under "Everything unlocked": the plan's first lesson, or the tool that opened the paywall.
    let today: String?
    /// Up to two days ahead within the horizon, in order: the first song the plan reaches, and the first unit
    /// after today's whose name doesn't echo today's lesson. Opened from a tool: that tool's next step on day 2,
    /// then the plan's first milestone after it.
    let milestones: [Milestone]
    /// The day the plan reaches its first song (today's lesson, when that is a song), however far off, at one lesson
    /// a day (1: today); nil when it reaches none.
    let songDay: Int?
    /// The hero's rail (`railSongs`): three Originals, the plan's next song, then the songs it reaches; eight at most.
    /// Empty when the plan reaches no song.
    let rail: [RailSong]

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
            instrumentId = store.chromaticStandIn?.id ?? (store.referenceMode ? nil : store.instrument.id)
            course = store.learnCourse
            start = course.flatMap { store.learn.nextLesson(in: $0) }
            minutes = store.dailyMinutes
        }
        let lessons = course?.lessons ?? []
        let first = start.flatMap { lesson in lessons.firstIndex { $0.id == lesson.id } }
        // One lesson a day from the first one: the day the plan reaches its first song.
        let songIndex = first.flatMap { from in lessons[from...].firstIndex { $0.kind == .song } }
        let songDay = first.flatMap { from in songIndex.map { $0 - from + 1 } }
        let planned = plannedOutcomes(goal: goal, course: course, songDay: songDay, minutes: minutes, store: store)
        let outcomes: [Outcome]
        if answers != nil {
            // Onboarding's plan screen has just set the daily minutes, so they aren't promised again: the plan's own
            // outcomes, then every instrument and every ear game and tool, so the paywall never sells with one line.
            // Four at most, as the plan's hero takes the first song's out (`PaywallView.shownOutcomes`) and three show.
            let kept = planned.filter { $0.id != "daily" }
            outcomes = merged(kept, breadthOutcomes(goal: goal, store: store), limit: 4)
        } else {
            outcomes = merged(reasonOutcomes(reason, course: course, store: store), planned)
        }
        let milestones = plannedMilestones(course: course, start: start, horizon: horizon)
        // A tool's paywall sells the tool on the track too: Today opens it and day 2 takes it further ("Drone +
        // intonation check", not the plan's "E minor" and "Ode to Joy"); the plan's own milestones follow.
        let tool: Focus? = answers == nil ? Self.focus(reason, store: store) : nil
        var track = milestones
        if let tool, horizon >= 2 {
            let step = Milestone(day: 2, title: tool.next, kind: .focus, symbol: tool.symbol)
            track = [step] + Array(milestones.filter { $0.day > 2 }.prefix(1))
        }
        return PaywallPlan(course: course,
                           instrumentId: instrumentId,
                           outcomes: outcomes,
                           today: tool?.today ?? start?.title.localized,
                           milestones: track,
                           songDay: songDay,
                           rail: railSongs(course: course, from: first, store: store))
    }

    // MARK: A tool's track

    /// What Today and day 2 say on a paywall opened from a tool (the reasons `AppStore.presentPaywall` is given:
    /// "drone", "practice.<tool>", "daily.<activity>", "ear.<drill>", "metronome.<feature>", "precision", "temperament",
    /// "capo", "transpose", "custom_tuning", "instrument", "tuning", "voice", "your_songs…"). Nil for a lesson, Progress
    /// ("journey"), Settings and anything unknown: those tell the plan.
    @MainActor private static func focus(_ reason: String?, store: AppStore) -> Focus? {
        guard let reason else { return nil }
        switch reason {
        case "instrument", "tuning":
            return Focus(today: String(localized: "Tune all \(store.catalog.instruments.count) instruments"),
                         next: String(localized: "String health"), symbol: "tuningfork")
        case "custom_tuning":
            return Focus(today: String(localized: "New tuning"), next: String(localized: "String health"), symbol: "slider.horizontal.3")
        case "precision":
            return Focus(today: String(localized: "Strobe precision"), next: String(localized: "String health"), symbol: "scope")
        case "temperament":
            return Focus(today: String(localized: "Temperament"), next: String(localized: "Strobe precision"), symbol: "scope")
        case "capo", "transpose":
            return Focus(today: String(localized: "Capo and transposition"), next: String(localized: "Every shape, any tuning"),
                         symbol: "hand.raised.fingers.spread")
        default:
            break
        }
        if reason.hasSuffix("drone") {
            return Focus(today: String(localized: "Tanpura"), next: String(localized: "Drone + intonation check"), symbol: "waveform.path")
        }
        if reason.hasSuffix("intonation") {
            return Focus(today: String(localized: "Intonation"), next: String(localized: "Intonation over a drone"), symbol: "ruler")
        }
        if reason.hasPrefix("ear.") || reason == "practice.ear" || reason == "daily.ear" {
            // The drill that was tapped first, then the other.
            if reason.lowercased().contains("chord") {
                return Focus(today: String(localized: "Name the chord"), next: String(localized: "Name the interval"), symbol: "ear")
            }
            return Focus(today: String(localized: "Name the interval"), next: String(localized: "Name the chord"), symbol: "ear")
        }
        if reason.hasSuffix("chords") || reason.hasSuffix("chord") {
            return Focus(today: String(localized: "Chord of the day"), next: String(localized: "Chord changes in time"),
                         symbol: "hand.raised.fingers.spread")
        }
        if reason.hasSuffix("scales") || reason.hasSuffix("scale") {
            return Focus(today: String(localized: "Scale workout"), next: String(localized: "Scales across the neck"),
                         symbol: "point.3.connected.trianglepath.dotted")
        }
        if reason.hasPrefix("metronome.") || reason == "practice.metronome" || reason == "daily.rhythm" {
            return Focus(today: String(localized: "Speed trainer"), next: String(localized: "Accents + subdivisions"), symbol: "metronome")
        }
        if reason.contains("sniper") {
            return Focus(today: String(localized: "Strobe precision"), next: String(localized: "String health"), symbol: "scope")
        }
        if reason == "voice" || reason == "practice.voice" || reason == "daily.voice" {
            return Focus(today: String(localized: "Range test"), next: String(localized: "Sing in tune"), symbol: "music.mic")
        }
        if reason.hasPrefix("your_songs") {
            return Focus(today: String(localized: "Your own song charts"), next: String(localized: "Loop + slow down"), symbol: "waveform")
        }
        return nil
    }

    // MARK: The rail

    /// The hero's rail, the modern catalogue first: three Originals played on the plan's instrument (the first in their
    /// course, which open free), then the plan's next song, then the other songs it reaches (the folk and classical
    /// tunes of its course), the Standards and the other collections on the same instrument, the rest of the Originals
    /// and the songs of the units placement skipped; when those make fewer than six, the other collections. An
    /// instrument without Originals of its own leads with its next song. Each tune shows once ("Greensleeves: the
    /// chords" and "… the melody" are one sleeve), each motif once and no two neighbours of one motif family while the
    /// songs allow it. Nursery rhymes and campfire rounds (`SongOfTheDay.isCampfireOrKids`) come last, the plan's next
    /// song too when it is one, so the rail looks like an adult's catalogue. Eight at most; empty when the plan reaches
    /// no song. Picked by catalogue (`SongOfTheDay.isOriginals`, path order), never by title.
    @MainActor private static func railSongs(course: LearnCourse?, from first: Int?, store: AppStore) -> [RailSong] {
        guard let course, let first, first < course.lessons.count else { return [] }
        let lessons = course.lessons
        let ahead = lessons[first...].filter { $0.kind == .song }
        guard let next = ahead.first else { return [] }
        let skipped = lessons[..<first].filter { $0.kind == .song }
        let collections = store.curriculum.courses.filter { $0.id != course.id && isCollection($0) }
            .sorted { shelfRank($0) < shelfRank($1) }
        let sameInstrument = { (shelf: LearnCourse) -> Bool in course.instrument != nil && shelf.instrument == course.instrument }
        let originals = collections.filter { sameInstrument($0) && SongOfTheDay.isOriginals($0) }
            .flatMap { RailCandidate.songs(of: $0) }
        var later: [RailCandidate] = ahead.dropFirst().map { RailCandidate(lesson: $0, course: course) }
        for shelf in collections where sameInstrument(shelf) && !SongOfTheDay.isOriginals(shelf) { later += RailCandidate.songs(of: shelf) }
        later += originals
        later += skipped.map { RailCandidate(lesson: $0, course: course) }
        var fallback: [RailCandidate] = []
        for shelf in collections where !sameInstrument(shelf) { fallback += RailCandidate.songs(of: shelf) }

        var rail: [RailSong] = []
        var tunes = Set<String>()
        var motifs = Set<CoverArt.Motif>()
        func add(_ lesson: Lesson, _ art: CoverArt) {
            rail.append(RailSong(id: lesson.id, title: CoverArt.mainTitle(lesson.title.localized), art: art))
            tunes.insert(tuneKey(lesson))
            motifs.insert(art.motif)
        }
        // A new grown-up tune with a new motif, in another family than its neighbour's.
        func fits(_ lesson: Lesson, _ art: CoverArt) -> Bool {
            !tunes.contains(tuneKey(lesson)) && !isKids(lesson) && !motifs.contains(art.motif)
                && rail.last?.art.motif.family != art.motif.family
        }
        let nextArt = CoverArt.of(next, in: course)
        let nextLeads = !isKids(next)
        // Three Originals; the third in another motif family than the next song that stands beside it.
        for song in originals where rail.count < 3 {
            let art = CoverArt.of(song.lesson, in: song.course)
            guard fits(song.lesson, art) else { continue }
            if rail.count == 2 && nextLeads && art.motif.family == nextArt.motif.family { continue }
            add(song.lesson, art)
        }
        // The plan's next song, whatever its motif: it is the plan's own.
        if nextLeads { add(next, nextArt) }
        for song in later where rail.count < 8 {
            let art = CoverArt.of(song.lesson, in: song.course)
            if fits(song.lesson, art) { add(song.lesson, art) }
        }
        // Six at least where the catalogue has them: any grown-up tune not on the rail yet, then the children's.
        for kids in [false, true] {
            for song in later + fallback where rail.count < 6 && isKids(song.lesson) == kids && !tunes.contains(tuneKey(song.lesson)) {
                add(song.lesson, CoverArt.of(song.lesson, in: song.course))
            }
        }
        // A children's tune the plan plays next still shows, last.
        if !nextLeads && rail.count < 8 && !tunes.contains(tuneKey(next)) { add(next, nextArt) }
        return rail
    }

    /// A nursery rhyme, children's song or campfire round, by its English title.
    private static func isKids(_ lesson: Lesson) -> Bool { SongOfTheDay.isCampfireOrKids(lesson.title.defaultValue) }

    /// A song that may go on the rail, with the course its sleeve is numbered in.
    private struct RailCandidate {
        let lesson: Lesson
        let course: LearnCourse

        /// A course's songs in path order.
        static func songs(of course: LearnCourse) -> [RailCandidate] {
            course.lessons.filter { $0.kind == .song }.map { RailCandidate(lesson: $0, course: course) }
        }
    }

    /// A tune's key (`SongOfTheDay.tuneKey`), so a song's versions and parts are one tune.
    private static func tuneKey(_ lesson: Lesson) -> String { SongOfTheDay.tuneKey(lesson.title.defaultValue) }

    /// A course that is mostly songs (Songs, Standards, Originals), as the Songs tab counts them.
    private static func isCollection(_ course: LearnCourse) -> Bool {
        let songs = course.lessons.filter { $0.kind == .song }.count
        return songs > 0 && songs * 2 >= course.lessons.count
    }

    /// The adult repertoire first: 0 the Originals, 1 the Standards, 2 the other collections.
    private static func shelfRank(_ course: LearnCourse) -> Int {
        if SongOfTheDay.isOriginals(course) { return 0 }
        return SongOfTheDay.isStandards(course) ? 1 : 2
    }

    /// What was tapped first, then the plan's own outcomes, `limit` in all and each promise once.
    private static func merged(_ lead: [Outcome], _ planned: [Outcome], limit: Int = 3) -> [Outcome] {
        var list: [Outcome] = []
        for outcome in lead + planned where !list.contains(where: { $0.id == outcome.id }) {
            list.append(outcome)
        }
        return Array(list.prefix(limit))
    }

    /// The first song after today's lesson and the units after today's, within the horizon: up to two, in order,
    /// the song always among them. A unit named like today's lesson ("Your first chord: E minor", then "First
    /// chords") would only say the same thing twice, so it is left out.
    private static func plannedMilestones(course: LearnCourse?, start: Lesson?, horizon: Int) -> [Milestone] {
        guard let course, let start, let first = course.lessons.firstIndex(where: { $0.id == start.id }),
              let startUnit = course.units.firstIndex(where: { unit in unit.lessons.contains { $0.id == start.id } }) else { return [] }
        let today = keywords(start.title.localized)
        var units: [Milestone] = []
        var opening = 0
        for (number, unit) in course.units.enumerated() {
            let unitStart = opening
            opening += unit.lessons.count
            guard number > startUnit else { continue }
            let day = unitStart - first + 1
            guard day <= horizon else { break }
            let title = unit.title.localized
            if keywords(title).isDisjoint(with: today) { units.append(Milestone(day: day, title: title)) }
        }
        let lessons = course.lessons
        let songIndex = lessons.indices.first { $0 > first && lessons[$0].kind == .song }
        guard let index = songIndex, index - first + 1 <= horizon else { return Array(units.prefix(2)) }
        // The song by its name, not its lesson's: "Greensleeves", not "Greensleeves: the chords".
        let song = Milestone(day: index - first + 1, title: CoverArt.mainTitle(lessons[index].title.localized), kind: .song)
        let unit = units.first { $0.day != song.day }
        return ([song] + (unit.map { [$0] } ?? [])).sorted { $0.day < $1.day }
    }

    /// The words of a title that carry its meaning, lowercased and without a plural "s": "Your first chord: E minor"
    /// gives first, chord, minor. Short words ("a", "on", "E") are left out.
    private static func keywords(_ title: String) -> Set<String> {
        let words = title.lowercased().split { !$0.isLetter && !$0.isNumber }
        var set = Set<String>()
        for word in words where word.count >= 4 && word != "your" && word != "with" && word != "from" {
            set.insert(word.count > 4 && word.hasSuffix("s") ? String(word.dropLast()) : String(word))
        }
        return set
    }

    // MARK: Outcomes

    /// The outcomes that answer what was tapped: the tool, instrument or lesson itself first, then its family.
    /// Empty for onboarding, the generic upsell and anything unknown, which lead with the plan.
    @MainActor private static func reasonOutcomes(_ reason: String?, course: LearnCourse?, store: AppStore) -> [Outcome] {
        guard let reason else { return [] }
        let tools = Outcome(id: "tools", text: Text("Every ear game and practice tool"), symbol: "ear", tint: Palette.violet)
        let kit = Outcome(id: "kit", text: Text("Chords, scales, intonation and drone"), symbol: "music.note.list", tint: Palette.amber)
        let custom = Outcome(id: "custom", text: Text("Unlimited custom tunings and string health"), symbol: "slider.horizontal.3", tint: Palette.sky)
        let tune = Outcome(id: "tune", text: Text("In tune in seconds, on any instrument"), symbol: "tuningfork", tint: Palette.mint)
        switch reason {
        case "lesson":
            return [lessonsOutcome(store.paywallLessonId.flatMap { store.curriculum.lesson(id: $0)?.course } ?? course, store: store)]
        case "instrument", "tuning":
            return [tune, custom]
        case "custom_tuning":
            return [Outcome(id: "insights", text: Text("Custom tunings, string health and accuracy insights"), symbol: "slider.horizontal.3", tint: Palette.sky),
                    tune]
        case "precision":
            return [Outcome(id: "strobe", text: Text("Strobe precision"), symbol: "scope", tint: Palette.sky), tune]
        case "temperament":
            return [Outcome(id: "temperaments", text: temperaments, symbol: "pianokeys", tint: Palette.violet), custom]
        case "capo", "transpose":
            return [Outcome(id: "capo", text: Text("Capo and transposition"), symbol: "arrow.up.arrow.down", tint: Palette.violet), custom]
        case "journey":
            return [Outcome(id: "trends", text: Text("Accuracy trends and milestones, measured on device"), symbol: "chart.line.uptrend.xyaxis",
                            tint: Palette.mint)]
        case "voice":
            return [Outcome(id: "range", text: Text("Range test and exercises"), symbol: "music.mic", tint: Palette.mint), tools]
        default:
            break
        }
        if reason.hasSuffix("drone") {
            return [Outcome(id: "drone", text: Text("Intonation over a drone"), symbol: "waveform.path", tint: Palette.sky), tools]
        }
        if reason.hasSuffix("chords") || reason.hasSuffix("chord") {
            return [Outcome(id: "chords", text: Text("Every shape, any tuning"), symbol: "hand.raised.fingers.spread", tint: Palette.sky), kit]
        }
        if reason.hasSuffix("scales") || reason.hasSuffix("scale") {
            return [Outcome(id: "scales", text: Text("Fretboard maps"), symbol: "point.3.connected.trianglepath.dotted", tint: Palette.sky), kit]
        }
        if reason.hasSuffix("intonation") {
            return [Outcome(id: "intonation", text: Text("Intonation checks at the 12th fret"), symbol: "ruler", tint: Palette.sky), kit]
        }
        if reason.hasPrefix("ear.") {
            return [Outcome(id: "ear", text: Text("Name intervals and chords by ear"), symbol: "ear", tint: Palette.violet),
                    Outcome(id: "drills", text: Text("Pitch, intervals, chords"), symbol: "music.note.list", tint: Palette.amber)]
        }
        if reason.hasPrefix("metronome.") {
            return [Outcome(id: "meter", text: Text("Accents, odd meters, tap"), symbol: "metronome", tint: Palette.coral), kit]
        }
        if reason.hasPrefix("practice.") || reason.hasPrefix("daily.") {
            return [kit, tools]
        }
        return []
    }

    /// "Guitar lessons that listen as you play" for a played course (the Songs course too), with the course's own
    /// symbol ("guitars") where it names the instrument, else a mortarboard; the whole catalogue otherwise.
    @MainActor private static func lessonsOutcome(_ course: LearnCourse?, store: AppStore) -> Outcome {
        if let played = course, let instrument = played.instrument, instrument != "voice" {
            let instrumentCourse = store.curriculum.courses.first { $0.instrument == instrument } ?? played
            let generic: Set<String> = ["music.note", "music.note.list", "music.quarternote.3"]
            let symbol = generic.contains(instrumentCourse.symbol) ? "graduationcap.fill" : instrumentCourse.symbol
            return Outcome(id: "lessons", text: Text("\(instrumentCourse.title.localized) lessons that listen as you play"),
                           symbol: symbol, tint: Palette.accent(instrumentCourse.accent))
        }
        return Outcome(id: "catalog", text: Text("\(store.curriculum.lessonCount) lessons across \(store.curriculum.courses.count) courses"),
                       symbol: "graduationcap.fill", tint: Palette.sky)
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
                                                   store: AppStore) -> [Outcome] {
        let daily = Outcome(id: "daily", text: Text("\(minutes) minutes a day, planned for you"), symbol: "flame.fill", tint: Palette.flame)
        switch goal {
        case "ear":
            return [Outcome(id: "ear", text: Text("Name intervals and chords by ear"), symbol: "ear", tint: Palette.violet),
                    Outcome(id: "tools", text: Text("Every ear game and practice tool"), symbol: "music.note.list", tint: Palette.amber),
                    daily]
        case "voice":
            return [Outcome(id: "sing", text: Text("Sing in tune"), symbol: "music.mic", tint: Palette.mint),
                    Outcome(id: "range", text: Text("Range test and exercises"), symbol: "waveform", tint: Palette.violet),
                    daily]
        case "rhythm":
            return [Outcome(id: "time", text: Text("Keep better time"), symbol: "metronome", tint: Palette.coral),
                    Outcome(id: "meter", text: Text("Accents, odd meters, tap"), symbol: "music.quarternote.3", tint: Palette.amber),
                    daily]
        case "tune":
            return [Outcome(id: "tune", text: Text("In tune in seconds, on any instrument"), symbol: "tuningfork", tint: Palette.mint),
                    Outcome(id: "custom", text: Text("Unlimited custom tunings and string health"), symbol: "slider.horizontal.3", tint: Palette.sky),
                    daily]
        default:
            // Practice: a song soon (when the plan reaches one) and lessons on their own instrument; a course without
            // one (theory) keeps the tools.
            if let played = course, let instrument = played.instrument, instrument != "voice" {
                guard let songDay else { return [lessonsOutcome(played, store: store), daily] }
                let song = songDay <= 7 ? Text("Play your first song this week") : Text("Play your first song")
                return [Outcome(id: "song", text: song, symbol: "music.quarternote.3", tint: Palette.amber),
                        lessonsOutcome(played, store: store),
                        daily]
            }
            return [Outcome(id: "tools", text: Text("Every ear game and practice tool"), symbol: "ear", tint: Palette.violet),
                    lessonsOutcome(course, store: store),
                    daily]
        }
    }

    /// What Timbre Pro opens beyond the plan, for onboarding's paywall: every instrument the tuner knows ("Tune all 60
    /// instruments") and every ear game and practice tool. A singer, an ear player and a drummer read the tools first.
    /// Their ids are the promises they share with the plan's own ("tune", "tools"), so a goal that already makes one
    /// keeps its own wording.
    @MainActor private static func breadthOutcomes(goal: String, store: AppStore) -> [Outcome] {
        let count = store.catalog.instruments.count
        // Sky, so it never stands mint beside a guitar plan's mint lessons.
        let instruments = Outcome(id: "tune", text: Text("Tune all \(count) instruments"), symbol: "tuningfork", tint: Palette.sky)
        // A singer's plan already shows a waveform and a microphone: their tools wear the metronome.
        let tools = goal == "voice"
            ? Outcome(id: "tools", text: Text("Every ear game and practice tool"), symbol: "metronome", tint: Palette.coral)
            : Outcome(id: "tools", text: Text("Every ear game and practice tool"), symbol: "ear", tint: Palette.violet)
        switch goal {
        case "voice", "ear", "rhythm": return [tools, instruments]
        default: return [instruments, tools]
        }
    }
}
