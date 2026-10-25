#if DEBUG
import SwiftUI
import TimbreCore

/// App Store screenshot scenes, debug builds only. `TIMBRE_SCENE=<name>` (with `TIMBRE_DEMO_PITCH=1`) puts the app
/// straight into one hero moment through its own code paths: the tuner's tracker really locks, the lesson's judge
/// really hears each string. The UI tests (TimbreUITests `test11StoreTunerLock`, `test12StoreChord`,
/// `test14StoreSongPerform`, `test15StoreShowMe`) then capture what the listing's caption promises without racing the
/// demo pitch's clock.
///
/// Hooks, a line or two each: `Bootstrap.load` calls `start`, `AppStore.startListening` asks `steadyPitch`,
/// `LessonPlayer` asks `lessonStart` (init) and `holds` (advance), `SongPerformStep` asks `performBeat` and
/// `stillScore`, `ShowMeStage` carries `ShowMeProbe` and the explanation's card `ShowMeHostProbe`.
///
/// - `tune-locked` (frame #1): the demo pitch plays the selected string steadily in tune, so each string locks after
///   the tracker's 0.65 s hold. The two lowest strings lock first (✓ on their chips), then the third locks and stays
///   locked: solid chip, the In tune badge, its peg ringed and ticked on the 3D headstock. A stalled main thread only
///   delays a lock (the hold starts again), so the scene waits for each one rather than for a time.
/// - `show-me` (frame #3): the same lesson opens on its first step, E minor explained on its card. It is the chord's
///   first appearance in the course, so the 3D model takes the card by itself once it has settled and the
///   demonstration plays there: the fingertips land in finger order, then the chord rings across every string. (The
///   test asks with "Show me" when the model doesn't come by itself, and again for each replay it needs.)
/// - `lesson-chord` (frame #4): the first guitar lesson with a chord ("Your first chord: E minor") opens on its chord
///   step with the day's tune check done. The demo pitch plays the chord string by string, every string lights, and
///   the step stays on "Every string rings" instead of moving on.
/// - `song-perform` (frame #2): Kite Weather, the Originals' song of the day, opens on its performance (the final
///   take over the band, on the fretboard runway with its words) and starts the take by itself a moment later, at
///   `performBar`: the second half of the first chorus. Every note before that bar is judged as the demo pitch plays
///   them, on time, so the combo, the score and the ribbon stand where a clean take would; from there the demo pitch
///   plays each note on time, so the run keeps growing while the hook line ("It's kite weather…") lights up.
enum DemoScene: String {
    case tuneLocked = "tune-locked"
    case lessonChord = "lesson-chord"
    case songPerform = "song-perform"
    case showMe = "show-me"

    static let current: DemoScene? = ProcessInfo.processInfo.environment["TIMBRE_SCENE"].flatMap(DemoScene.init(rawValue:))

    /// The tuner's demo pitch plays the selected string in tune at once, with no six-second drift.
    static var steadyPitch: Bool { current == .tuneLocked }

    /// Starts the scene once the store is ready (`Bootstrap.load`, before the first frame).
    @MainActor static func start(_ store: AppStore) {
        switch current {
        case .tuneLocked?:
            Task { @MainActor in await DemoScene.lockStrings(store) }
        case .lessonChord?, .showMe?:
            // Learn opens it out of its Continue card, as it opens onboarding's first lesson.
            guard let lesson = DemoScene.chordLesson(store) else { return }
            store.pendingLessonId = lesson.id
            store.selectedTab = .learn
        case .songPerform?:
            DemoScene.openSong(store)
        case nil:
            break
        }
    }

    // MARK: Lessons

    /// The run `LessonPlayer` opens `lesson` with: in `lesson-chord`, at its first chord step; in `show-me`, at the step
    /// that explains that chord on its card; in `song-perform`, at the song's last step, its performance (nil otherwise).
    static func lessonStart(_ lesson: Lesson) -> LessonRun? {
        let start: Int?
        switch current {
        case .lessonChord?: start = lesson.steps.firstIndex(where: DemoScene.isChord)
        case .showMe?: start = lesson.steps.firstIndex(where: DemoScene.explainsChord)
        case .songPerform? where lesson.id == performSongId: start = lesson.steps.isEmpty ? nil : lesson.steps.count - 1
        default: start = nil
        }
        guard let index = start else { return nil }
        var run = LessonRun(lesson: lesson)
        for _ in 0..<index { run.complete(score: nil) }
        return run
    }

    /// The finished step stays on screen (its finished state is the picture) instead of handing over to the next.
    static func holds(_ step: LessonStep?) -> Bool {
        guard current == .lessonChord, let step else { return false }
        return DemoScene.isChord(step)
    }

    private static func isChord(_ step: LessonStep) -> Bool {
        if case .playChord = step { return true }
        return false
    }

    /// An explanation with a chord on its card (where "Show me" plays the chord on the 3D model).
    private static func explainsChord(_ step: LessonStep) -> Bool {
        if case let .explain(_, _, visual) = step, case .chord = visual { return true }
        return false
    }

    @MainActor private static func chordLesson(_ store: AppStore) -> Lesson? {
        store.curriculum.course(id: "guitar")?.lessons.first { lesson in lesson.steps.contains(where: DemoScene.isChord) }
    }

    // MARK: A song, performed

    /// Kite Weather (Originals), the song of the day: a full arrangement with words, played on the fretboard runway.
    static let performSongId = "orig-kite-weather"
    /// The bar the take starts at (0-based, as the arrangement counts them): the second half of the first chorus
    /// (bars 12–19), "let it climb, let it go", a bar before the hook line ("It's kite weather, kite weather") comes
    /// round again. The 68 notes before it are already played clean.
    static let performBar = 15
    /// How long after the performance opens the take starts: past the zoom that brings the song in, and past the UI
    /// test's last look for the lesson (a query stalls the main thread; a note heard late would break the run).
    static let performDelay: Duration = .seconds(3)

    /// In `song-perform`, the beat of `lesson`'s performance its take starts at (nil otherwise: the player taps Perform).
    static func performBeat(_ lesson: Lesson, beatsPerBar: Int) -> Double? {
        guard current == .songPerform, lesson.id == performSongId else { return nil }
        return Double(performBar * max(1, beatsPerBar))
    }

    /// In `song-perform` the take's score changes in place rather than rolling its digits: it changes with every note,
    /// several times a second, so a rolling score is mid-roll in almost any picture ("27,?00", review 14).
    static var stillScore: Bool { current == .songPerform }

    /// Learn opens the song (as a Siri or Spotlight link opens one), then goes back to the player's own course once
    /// the song is on screen, so later runs in the same simulator still open Learn on guitar.
    @MainActor private static func openSong(_ store: AppStore) {
        guard let found = store.curriculum.lesson(id: performSongId) else { return }
        let own = UserDefaults.standard.string(forKey: "learn.course") ?? "guitar"
        store.pendingLessonId = found.lesson.id
        store.selectedTab = .learn
        guard own != found.course.id else { return }
        Task { @MainActor in
            for _ in 0..<50 where store.pendingLessonId != nil { try? await Task.sleep(for: .milliseconds(100)) }
            // Past Learn's own wait for covering screens, so the switch happens behind the open song.
            try? await Task.sleep(for: .milliseconds(2500))
            guard UserDefaults.standard.string(forKey: "learn.course") == found.course.id else { return }
            UserDefaults.standard.set(own, forKey: "learn.course")
        }
    }

    // MARK: Tuner

    /// Locks the two lowest strings one after the other, then selects the third, which locks and holds.
    @MainActor private static func lockStrings(_ store: AppStore) async {
        // The tuner is up by now; it starts listening as it appears when the microphone is allowed.
        try? await Task.sleep(for: .seconds(1.5))
        store.selectedTab = .tune
        store.startListening()
        let courses = store.courses
        guard courses.count >= 3 else { return }
        for course in courses.prefix(2) {
            await lock(course, store)
            // Its bell rings and its chip settles with the ✓ before the next string takes over.
            try? await Task.sleep(for: .seconds(1))
        }
        select(courses[2], store)
    }

    /// Selects a string and waits until the tracker has locked it (at most a minute: a UI-test query stalls the main
    /// thread, and a gap of more than 150 ms in the readings starts the hold again).
    @MainActor private static func lock(_ course: Course, _ store: AppStore) async {
        select(course, store)
        for _ in 0..<600 where !store.lockedCourses.contains(course.index) {
            try? await Task.sleep(for: .milliseconds(100))
        }
    }

    @MainActor private static func select(_ course: Course, _ store: AppStore) {
        store.chooseCourse(course.index)
        // Choosing a string by hand turns automatic detection off; the scene keeps the default (on).
        store.automatic = true
    }
}

// MARK: - Show me

/// For XCUITest only (TIMBRE_DEBUG_STATE=1), over every "Show me" stage (`ShowMeStage`): whether the model is on the
/// card, since when the renderer has drawn it there, and when the demonstration's last fingertip lands, so
/// `test15StoreShowMe` keeps its picture only when it was taken with the 3D model showing (the card's picture gone),
/// drawn for longer than the cross-fade, every fingertip down and the chord ringing. Reads
/// "showme=<3d|picture|loading> landed=<epoch s, 0 before a demonstration> ringing=<strings lit> live=<epoch s of the
/// first frame drawn with the model on the card, 0 before> frames=<frames drawn since> now=<the app's clock>
/// diag=<model, load state, host state, frames, framing, cache>". "3d" needs the stage ready *and* the host showing it
/// (the state that takes the picture away), "picture" is a ready stage the host hasn't shown, "loading" the rest; the
/// free-text `diag` comes last, for the test's log. Re-read five times a second (the controller's counters change
/// without SwiftUI hearing of it). Drawn in clear ink and never touched, like the tuner's `stage.state`, so it stays
/// out of every screenshot.
struct ShowMeProbe: View {
    let modelID: String
    let shown: Bool
    let ready: Bool
    let revealed: Bool
    let attached: Bool
    let controller: ShowMeController
    let shot: ShowMeShot
    let landStart: Date?
    let landingStep: Double
    let ringing: Int

    private static let enabled = ProcessInfo.processInfo.environment["TIMBRE_DEBUG_STATE"] == "1"

    @ViewBuilder var body: some View {
        if Self.enabled {
            TimelineView(.periodic(from: .now, by: 0.2)) { context in
                Text(verbatim: label(at: context.date))
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundStyle(Color.clear)
                    .allowsHitTesting(false)
                    .accessibilityIdentifier("showme.state")
            }
        }
    }

    private func label(at now: Date) -> String {
        let stage = shown ? "3d" : (ready ? "picture" : "loading")
        let live = controller.liveSince?.timeIntervalSince1970 ?? 0
        let head = "showme=\(stage) landed=\(Self.seconds(landed)) ringing=\(ringing) live=\(Self.seconds(live)) "
            + "frames=\(controller.shownFrames) now=\(Self.seconds(now.timeIntervalSince1970))"
        let host = "model=\(modelID) ready=\(ready ? 1 : 0) revealed=\(revealed ? 1 : 0) attached=\(attached ? 1 : 0)"
        return head + " diag=" + host + " " + controller.diagnostics + " cache=\(ModelCache.shared.describe(modelID))"
    }

    private static func seconds(_ value: Double) -> String { String(format: "%.3f", value) }

    /// When the last fingertip lands, in seconds since 1970 (0: no demonstration under way).
    private var landed: Double {
        guard let landStart else { return 0 }
        var fingers = 1
        if case let .fretting(shape) = shot { fingers = max(1, shape.landingCount) }
        return landStart.addingTimeInterval(Double(fingers - 1) * landingStep).timeIntervalSince1970
    }
}

/// For XCUITest only (TIMBRE_DEBUG_STATE=1), on a lesson card whose picture can play in 3D (LessonExplain): the card's
/// own side of "Show me", the state that swaps its picture for the model, so a test that finds no stage (or a stage the
/// card never showed) can say why. Reads "card showMe=<0|1> ready=<0|1> threeD=<0|1> failed=<0|1> first=<0|1>
/// model=<id|none> problem=<why the last stage gave up, or none>". Drawn in clear ink and never touched.
struct ShowMeHostProbe: View {
    let showMe: Bool
    let ready: Bool
    let threeD: Bool
    let failed: Bool
    let first: Bool
    let model: String?

    private static let enabled = ProcessInfo.processInfo.environment["TIMBRE_DEBUG_STATE"] == "1"

    @ViewBuilder var body: some View {
        if Self.enabled {
            Text(verbatim: "card showMe=\(flag(showMe)) ready=\(flag(ready)) threeD=\(flag(threeD)) failed=\(flag(failed)) "
                 + "first=\(flag(first)) model=\(model ?? "none") problem=\(ShowMe.lastProblem ?? "none")")
                .font(.system(size: 9, design: .monospaced))
                .foregroundStyle(Color.clear)
                .allowsHitTesting(false)
                .accessibilityIdentifier("showme.host")
        }
    }

    private func flag(_ value: Bool) -> String { value ? "1" : "0" }
}
#endif
