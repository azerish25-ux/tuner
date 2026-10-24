#if DEBUG
import SwiftUI
import TimbreCore

/// App Store screenshot scenes, debug builds only. `TIMBRE_SCENE=<name>` (with `TIMBRE_DEMO_PITCH=1`) puts the app
/// straight into one hero moment through its own code paths: the tuner's tracker really locks, the lesson's judge
/// really hears each string. The UI tests (TimbreUITests `test11StoreTunerLock`, `test12StoreChord`) then capture what
/// the listing's caption promises without racing the demo pitch's clock.
///
/// Hooks, a line or two each: `Bootstrap.load` calls `start`, `AppStore.startListening` asks `steadyPitch`,
/// `LessonPlayer` asks `lessonStart` (init) and `holds` (advance).
///
/// - `tune-locked` (frame #1): the demo pitch plays the selected string steadily in tune, so each string locks after
///   the tracker's 0.65 s hold. The two lowest strings lock first (✓ on their chips), then the third locks and stays
///   locked: solid chip, the In tune badge, its peg ringed and ticked on the 3D headstock. A stalled main thread only
///   delays a lock (the hold starts again), so the scene waits for each one rather than for a time.
/// - `lesson-chord` (frame #3): the first guitar lesson with a chord ("Your first chord: E minor") opens on its chord
///   step with the day's tune check done. The demo pitch plays the chord string by string, every string lights, and
///   the step stays on "Every string rings" instead of moving on.
enum DemoScene: String {
    case tuneLocked = "tune-locked"
    case lessonChord = "lesson-chord"

    static let current: DemoScene? = ProcessInfo.processInfo.environment["TIMBRE_SCENE"].flatMap(DemoScene.init(rawValue:))

    /// The tuner's demo pitch plays the selected string in tune at once, with no six-second drift.
    static var steadyPitch: Bool { current == .tuneLocked }

    /// Starts the scene once the store is ready (`Bootstrap.load`, before the first frame).
    @MainActor static func start(_ store: AppStore) {
        switch current {
        case .tuneLocked?:
            Task { @MainActor in await DemoScene.lockStrings(store) }
        case .lessonChord?:
            // Learn opens it out of its Continue card, as it opens onboarding's first lesson.
            guard let lesson = DemoScene.chordLesson(store) else { return }
            store.pendingLessonId = lesson.id
            store.selectedTab = .learn
        case nil:
            break
        }
    }

    // MARK: Lessons

    /// The run `LessonPlayer` opens `lesson` with: in `lesson-chord`, at its first chord step (nil otherwise).
    static func lessonStart(_ lesson: Lesson) -> LessonRun? {
        guard current == .lessonChord, let index = lesson.steps.firstIndex(where: DemoScene.isChord) else { return nil }
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

    @MainActor private static func chordLesson(_ store: AppStore) -> Lesson? {
        store.curriculum.course(id: "guitar")?.lessons.first { lesson in lesson.steps.contains(where: DemoScene.isChord) }
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
#endif
