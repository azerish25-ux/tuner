import Combine
import SwiftUI
import TimbreCore
import UIKit

/// The instrument browser lives in the tuner's picker sheet (`showInstrumentPicker`), not in a tab.
enum AppTab: Hashable { case tune, learn, songs, practice, journey }

/// App state and actions. High-rate readings live in `live` so they never invalidate
/// views that observe this object.
@MainActor
final class AppStore: ObservableObject {
    let catalog: Catalog
    let audio = AudioService()
    let commerce = CommerceService()
    let live = LiveReading()
    private let persistence: LocalStore
    @Published private(set) var settings: UserSettings
    @Published private(set) var records: [PracticeRecord] {
        didSet { recordsRevision &+= 1 }
    }
    /// Moves on whenever `records` changes, so the streak is counted again (`streak`).
    private var recordsRevision = 0
    private var streakCache = StreakCache()
    @Published var selectedTab: AppTab = .tune
    @Published var showPaywall = false
    @Published var showSettings = false
    @Published var showInstrumentPicker = false
    @Published var error: String?
    @Published var referenceMode = false
    @Published private(set) var referenceMidi = 69
    @Published var selectedCourse = 0
    @Published var automatic = true
    @Published private(set) var lockedCourses: Set<Int> = []
    @Published private(set) var celebrate = 0
    @Published var requestReviewNow = false
    @Published var paywallReason: String?
    /// The locked lesson or instrument that opened the paywall, when one did: the paywall names it.
    @Published private(set) var paywallLessonId: String?
    @Published private(set) var paywallInstrumentId: String?
    /// A practice screen to open on the Practice tab (Siri, Shortcuts, deep links).
    @Published var pendingPracticeRoute: PracticeRoute?
    /// A lesson for the Learn tab to open (onboarding's placed first lesson); LearnView opens it and clears it.
    @Published var pendingLessonId: String?
    /// While true, readings target the octave and never count as tuning sessions.
    @Published var intonationMode = false
    /// Ear games set their own target; readings then never count as tuning.
    @Published var gameTargetHz: Double?
    #if DEBUG
    /// Demo pitch only (UI tests, App Preview): while set, the demo stays silent until this says the next
    /// note is due, then plays it in tune — a play-along played on time rather than a slow drift.
    var demoNoteDue: (() -> Bool)?
    #endif
    private var measuringTuning: Bool { !intonationMode && gameTargetHz == nil }
    /// The tuner's feel: called with every tuner reading (`TunerFrame`), about 60 a second while the tuner listens.
    /// `TunerFrame.standardFeel` (the cent detents and the lock) until a replacement is installed, as tune by feel's
    /// haptic beating will be: `store.onTunerFrame = { frame in … }` from main-actor code, capturing the store weakly.
    var onTunerFrame: @MainActor (TunerFrame) -> Void = TunerFrame.standardFeel
    /// The latest XP / quest / badge result, for the reward toast; `rewardPulse` ticks on each.
    @Published private(set) var lastReward: ProgressUpdate?
    @Published private(set) var rewardPulse = 0
    /// A streak freeze was just earned or spent; the reward toast announces it, `streakPulse` ticks on each.
    enum StreakNotice: Equatable { case earned, saved(days: Int) }
    @Published private(set) var streakNotice: StreakNotice?
    @Published private(set) var streakPulse = 0
    // Voice
    @Published var voiceLevel = 1 {
        didSet { if voiceLevel != oldValue && !updateSettings({ $0.selectedVoiceLevel = voiceLevel }) { voiceLevel = oldValue } }
    }
    @Published var voiceRoot = 57
    @Published private(set) var voiceRunning = false
    @Published private(set) var countdown = 0
    @Published private(set) var voiceResult: VoiceResult?
    @Published private(set) var voiceSaveFailed = false
    private let tracker = TuningTracker()
    private let voiceStability = StabilityTracker()
    private var attempt: VoiceAttempt?
    private var pendingVoiceRecord: PracticeRecord?
    private var voiceTask: Task<Void, Never>?
    private var sessionStarted: Date?
    private var sessionStartedUptime: TimeInterval?
    private var sessionCount = 0
    private var stableCount = 0
    private var totalError = 0.0
    private var lastAutoIndex: Int?
    /// Automatic string detection pauses until then (while the lock bell rings).
    var autoQuietUntil: TimeInterval = 0
    private var autoHits = 0
    private var lastTaps: [TimeInterval] = []
    private var voiceStarted: TimeInterval = 0
    private var practiceStarted: [String: TimeInterval] = [:]
    /// Courses whose first reading this session has gone into the string-health log.
    private var sampledCourses: Set<Int> = []
    private var subscriptions: Set<AnyCancellable> = []
    /// The coalesced settings write (`updateSettings`), while one is waiting.
    private var settingsWrite: Task<Void, Never>?
    private var widgetRepublishQueued = false
    /// What the widget library was last built from (`publishWidgetLibrary`).
    private var widgetLibraryInputs: WidgetLibraryInputs?

    init(directory: URL? = nil) throws {
        // The curriculum decodes on a background queue while the catalog and the saved state load here; the launch
        // waits only for whatever of it is left (none when it was awaited before the store was made).
        CurriculumStore.shared.preload()
        catalog = try Catalog()
        let storageDirectory = directory ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("Timbre", isDirectory: true)
        persistence = try LocalStore(directory: storageDirectory)
        settings = persistence.settings; records = persistence.records
        curriculum = CurriculumStore.shared.curriculum
        #if DEBUG
        if let failure = CurriculumStore.shared.failure { assertionFailure("curriculum.json did not decode: \(failure)") }
        #endif
        voiceLevel = settings.selectedVoiceLevel ?? 1
        TimbreLocalization.language = settings.language
        // Note names follow the app language until the player picks a system (German reads B natural as H).
        settings.applyNotationDefault(systemLanguage: Locale.preferredLanguages.first)
        NoteNames.active = settings.notation
        tracker.confidenceThreshold = settings.confidenceThreshold
        applyPrecision()
        Haptics.shared.enabled = settings.hapticsEnabled
        // Settings › Share anonymous usage data, from the saved choice (on until the player chooses).
        Analytics.setSharing(settings.sharesUsage)
        // App opens, sessions, MetricKit, Apple Ads attribution and the remote settings start only once the player's
        // sharing choice is known, so an opt-out stops the attribution request too.
        Analytics.start()
        audio.onReading = { [weak self] hz, confidence, level in self?.accept(hz, confidence: confidence, level: level) }
        // Reference tones, "Hear it" and chord buttons sound like the selected instrument (a lesson's own course instrument while it is open).
        audio.instrumentVoice = { [weak self] in self.map { InstrumentVoice(instrument: $0.instrument) } ?? .guitar }
        publishWidgets()
        LiveActivityController.shared.attach(self)  // Lock Screen / Dynamic Island while the metronome, drone, tuner or a lesson runs
        // The widgets' song access follows Pro, which is unknown until StoreKit answers: once it does (and whenever Pro
        // changes) they are published again, so a paying player's songs never stay marked PRO or locked.
        // Today's plan is pinned against Pro too (a Pro tool gives way once Pro has lapsed).
        commerce.$entitlementResolved.combineLatest(commerce.$isPro)
            .dropFirst()
            .sink { [weak self] _ in self?.republishWidgetsSoon(); self?.pinDailyPlanSoon() }
            .store(in: &subscriptions)
        commerce.$entitlementResolved.combineLatest(commerce.$isPro)
            .sink { [weak self] resolved, pro in self?.noteProStatus(resolved: resolved, pro: pro) }
            .store(in: &subscriptions)
        // A rhythm session the Metronome tool opened ends when the tool's click does, however it stops (a lesson
        // taking the click over, or an interruption, included), so its minutes reach the streak and history; a click
        // that comes back after an interruption starts a new one.
        audio.$metronomeOwnedByTool.dropFirst().removeDuplicates()
            .sink { [weak self] owned in
                guard let self else { return }
                if owned {
                    if self.practiceStarted[DailyActivity.Kind.rhythm.rawValue] == nil { self.beginPractice(DailyActivity.Kind.rhythm.rawValue) }
                } else {
                    self.finishToolRhythmSoon()
                }
            }
            .store(in: &subscriptions)
        // A new day (the app left open past midnight, or brought back the next morning) pins the new day's plan.
        NotificationCenter.default.publisher(for: .NSCalendarDayChanged)
            .merge(with: NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification))
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.pinDailyPlanSoon() }
            .store(in: &subscriptions)
    }

    /// Published values change after their publisher fires: the widgets are rebuilt on the next turn, once.
    private func republishWidgetsSoon() {
        guard !widgetRepublishQueued else { return }
        widgetRepublishQueued = true
        Task { @MainActor [weak self] in
            guard let self else { return }
            self.widgetRepublishQueued = false
            self.publishWidgets()
        }
    }

    /// What Pro was the last time StoreKit answered, on this device (`noteProStatus`).
    private static let proKnownKey = "analytics.proActive"

    /// `pro_active` is logged when Pro turns on against what this device last knew, not on every launch of a
    /// subscriber; a lapse is remembered so the next activation counts again.
    private func noteProStatus(resolved: Bool, pro: Bool) {
        guard resolved else { return }
        let defaults = UserDefaults.standard
        let known = defaults.object(forKey: Self.proKnownKey) as? Bool
        guard known != pro else { return }
        defaults.set(pro, forKey: Self.proKnownKey)
        if pro { Analytics.log("pro_active") }
    }

    private func finishToolRhythmSoon() {
        Task { @MainActor [weak self] in
            guard let self, !self.audio.metronomeOwnedByTool, self.practiceStarted[DailyActivity.Kind.rhythm.rawValue] != nil else { return }
            self.finishPractice(.rhythm)
        }
    }

    /// What the widget library (Quick tune's instruments, Next song's shelves) is built from.
    private struct WidgetLibraryInputs: Equatable {
        let language: String
        let notation: String
        let pro: Bool
        let learn: LearnProgress
        let level: Int
        let day: Int
    }

    /// Rebuilds the widget library only when something it shows can have changed, and never before the entitlements
    /// are known (until then every Pro song would read as locked).
    private func publishWidgetLibrary() {
        guard commerce.entitlementResolved else { return }
        let inputs = WidgetLibraryInputs(language: TimbreLocalization.language, notation: settings.notation, pro: isPro, learn: learn,
                                         level: level.number, day: Calendar.current.ordinality(of: .day, in: .era, for: Date()) ?? 0)
        guard inputs != widgetLibraryInputs else { return }
        widgetLibraryInputs = inputs
        WidgetLibrary.publish(self)  // Quick tune's instruments and Next song's shelves (Intents/WidgetLibraryPublisher.swift)
    }

    /// Keeps the home-screen widgets in step with practice history.
    func publishWidgets() {
        let calendar = Calendar.current
        let summary = streak
        let today = calendar.startOfDay(for: Date())
        let days = Set(records.map { calendar.startOfDay(for: $0.date) })
        let week = (0..<7).reversed().map { offset in calendar.date(byAdding: .day, value: -offset, to: today).map(days.contains) ?? false }
        let course = curriculum.course(id: UserDefaults.standard.string(forKey: "learn.course") ?? "guitar")
        let lesson = course.flatMap { course in
            learn.nextLesson(in: course).map {
                WidgetSnapshot.NextLesson(course: course.title.localized, symbol: course.symbol, accent: course.accent, title: $0.title.localized,
                                          minutes: $0.minutes, xp: $0.xp, done: learn.finishedCount(in: course), total: course.lessons.count)
            }
        }
        publishWidgetLibrary()
        WidgetSnapshot.write(WidgetSnapshot(streak: summary.current, best: summary.best, practicedToday: summary.practicedToday,
                                            week: week, instrument: instrumentDisplayName, updated: Date(), lesson: lesson))
        WatchBridge.shared.publish(self)  // Apple Watch: streak, Today, quest and complication (Services/WatchBridge.swift)
        PracticeReminder.update(.init(streak: summary.current, practicedToday: summary.practicedToday, nextLesson: lesson?.title,
                                      minutesByDay: PracticeReminder.minutesByDay(records),
                                      reviewDue: course.flatMap { reviewDeck.nextDue(in: $0.id) }))
    }

    // MARK: Derived state

    var isPro: Bool { commerce.isPro }
    var demonstratedLevels: Set<Int> { persistence.demonstratedLevels }
    /// How the saved state was recovered on opening (`LocalStore.recovery`), for the launch notice.
    var storageRecovery: LocalStore.Recovery? { persistence.recovery }
    var instrument: Instrument { catalog.instrument(id: settings.selectedInstrumentId) ?? catalog.instruments[0] }
    var tuning: Tuning {
        let id = settings.lastTuningIds[instrument.id] ?? instrument.defaultTuningId
        if let custom = customTunings.first(where: { $0.id == id }) { return custom }
        if let remembered = catalog.tuning(id: id), remembered.instrumentId == instrument.id { return remembered }
        return catalog.tuning(id: instrument.defaultTuningId)!
    }
    var tunings: [Tuning] { catalog.tunings.filter { $0.instrumentId == instrument.id } + customTunings }
    /// The player's own tunings for the current instrument, built on its default tuning.
    var customTunings: [Tuning] {
        guard let base = catalog.tuning(id: instrument.defaultTuningId) else { return [] }
        return (settings.customTunings ?? []).filter { $0.instrumentId == instrument.id }.map { $0.tuning(base: base) }
    }
    func customTuning(id: String) -> CustomTuning? { settings.customTunings?.first { $0.id == id } }
    func saveCustomTuning(_ custom: CustomTuning) {
        guard FreeTier.canSaveCustomTuning(id: custom.id, saved: settings.customTunings ?? [], pro: isPro) else {
            presentPaywall("custom_tuning"); return
        }
        endTuningSession()
        guard updateSettings({ settings in
            var list = settings.customTunings ?? []
            if let index = list.firstIndex(where: { $0.id == custom.id }) { list[index] = custom } else { list.append(custom) }
            settings.customTunings = list
            settings.lastTuningIds[custom.instrumentId] = custom.id
        }) else { return }
        resetTuningMeasurements()
        selectedCourse = courses.first?.index ?? 0
        Analytics.log("custom_tuning_saved", ["instrument": custom.instrumentId, "strings": String(custom.midis.count)])
    }
    func deleteCustomTuning(id: String) {
        endTuningSession()
        updateSettings { settings in
            settings.customTunings?.removeAll { $0.id == id }
            for (instrument, tuning) in settings.lastTuningIds where tuning == id { settings.lastTuningIds[instrument] = nil }
        }
        resetTuningMeasurements()
        selectedCourse = courses.first?.index ?? 0
    }
    var courses: [Course] { tuning.courses.sorted { $0.index < $1.index } }
    var activeCourse: Course { courses.first(where: { $0.index == selectedCourse }) ?? courses[0] }
    var activeMidi: Int { referenceMode ? referenceMidi : activeCourse.targetMidi }
    var targetHz: Double {
        if let gameTargetHz { return gameTargetHz }
        let base = Temperament.byId(settings.temperamentId).frequency(midi: activeMidi, reference: settings.referencePitchHz, letterName: referenceMode ? nil : activeCourse.label)
        // The intonation check compares the 12th-fret harmonic and fretted note: one octave up.
        return intonationMode ? base * 2 : base
    }
    var targetName: String { referenceMode ? PitchMath.noteName(midi: activeMidi + settings.transposition - settings.capo, notation: settings.notation) : TargetLabelFormatter.splitCue(courseLabel(activeCourse)).main }
    func courseLabel(_ course: Course) -> String { TargetLabelFormatter.display(label: course.label, midi: course.targetMidi, notation: settings.notation, transposition: settings.transposition, capo: settings.capo) }
    var photo: InstrumentPhoto? { catalog.photo(instrumentId: instrument.id, tuningId: tuning.id, preferredAsset: settings.selectedPhotoAsset) }
    var modelID: String? { referenceMode ? nil : ModelLibrary.modelID(forPhoto: photo?.asset) }
    var instrumentDisplayName: String {
        if referenceMode {
            // "Chromatic / reference pitch" in every locale: the header keeps the first half.
            let name = catalog.referenceMode?.name.localized ?? String(localized: "Chromatic")
            return name.components(separatedBy: " / ").first ?? name
        }
        return photo.map { NSLocalizedString("timbre_photo_" + $0.asset, bundle: .main, value: $0.label, comment: "") } ?? instrument.name.localized
    }
    var activeAnchor: String? { referenceMode ? nil : activeCourse.anchorId }
    var allCoursesLocked: Bool { !courses.isEmpty && Set(courses.map(\.index)).isSubset(of: lockedCourses) }
    var voiceExercise: VoiceExercise { VoiceExercise(level: voiceLevel, rootMidi: voiceRoot) }
    var voiceTargetMidi: Int { voiceExercise.note(at: live.voiceElapsed) }
    /// Counted once and kept until the records, the frozen days or the day change.
    var streak: StreakSummary {
        streakCache.summary(records: records, revision: recordsRevision, frozen: progress.frozenDays ?? [])
    }
    var streakFreezes: Int { progress.streakFreezes ?? 0 }

    /// Unlocks achievements whose goals are already met (launch and foreground), announcing them like any other reward.
    func syncAchievements() {
        var state = progress
        let summary = streak
        let earned = state.awardAchievements(streakBest: summary.best, customTunings: settings.customTunings?.count ?? 0,
                                             metrics: achievementMetrics(minutes: summary.totalMinutes))
        guard !earned.isEmpty, updateSettings({ $0.progress = state }) else { return }
        publishReward(ProgressUpdate(achievementsEarned: earned))
        Haptics.shared.done()
    }

    /// Spends banked freezes on days missed since the last practice. Runs at launch and whenever the app comes forward.
    func applyStreakFreezes() {
        var state = progress
        let frozen = Set(state.frozenDays ?? [])
        let cover = StreakFreeze.daysToCover(records: records, frozen: frozen, available: state.streakFreezes ?? 0)
        guard !cover.isEmpty else { return }
        state.streakFreezes = (state.streakFreezes ?? 0) - cover.count
        state.frozenDays = Array(frozen.union(cover).sorted().suffix(366))
        guard updateSettings({ $0.progress = state }) else { return }
        streakNotice = .saved(days: cover.count); streakPulse += 1
        Analytics.log("streak_freeze_used", ["days": String(cover.count)])
        publishWidgets()
    }

    /// Every seventh day of a run banks a freeze (up to two).
    private func awardStreakFreezeIfEarned() {
        var state = progress
        let today = Quests.dayKey(Date())
        guard StreakFreeze.earnsFreeze(summary: streak, banked: state.streakFreezes ?? 0, lastAwardDay: state.freezeAwardDay, todayKey: today) else { return }
        state.streakFreezes = (state.streakFreezes ?? 0) + 1
        state.freezeAwardDay = today
        guard updateSettings({ $0.progress = state }) else { return }
        streakNotice = .earned; streakPulse += 1
        Analytics.log("streak_freeze_earned")
    }
    var recentInstrumentIds: [String] {
        let available = Set(catalog.instruments.map(\.id))
        var seen = Set<String>()
        let used = records.compactMap { record -> String? in
            guard available.contains(record.instrumentId), seen.insert(record.instrumentId).inserted else { return nil }
            return record.instrumentId
        }
        return Array((used.isEmpty ? settings.recentInstrumentIds.filter { available.contains($0) } : used).prefix(8))
    }
    func canTune(_ instrument: Instrument) -> Bool { AccessPolicy.canTune(instrument: instrument, pro: isPro) }

    var statusText: String {
        if live.preserved { return String(localized: "Paused · last reading") }
        if !audio.running { return String(localized: "Tap to listen") }
        switch live.reading.status {
        case "inTune": return String(localized: "In tune")
        case "flat": return String(localized: "Tighten · \(Int(abs(live.reading.cents ?? 0).rounded()))¢ flat")
        case "sharp": return String(localized: "Loosen · \(Int(abs(live.reading.cents ?? 0).rounded()))¢ sharp")
        case "settling": return String(localized: "Hold it…")
        case "uncertain": return String(localized: "Let the string ring")
        default: return String(localized: "Play \(targetName)")
        }
    }

    // MARK: Settings

    /// Settings › Precision: the tracker's lock band, and the band every tuner colour, meter and peg cue draws.
    private func applyPrecision() {
        tracker.bandCents = settings.precision.bandCents
        Palette.tuningBand = settings.precision.bandCents
    }

    /// Applies a settings change at once and saves it shortly after: a burst of changes (a finished lesson's stars, XP,
    /// quests and Today; the metronome's controls) costs one write, off the moment it happens. Invalid settings are
    /// refused here and now; whatever is waiting is written when the app leaves the foreground (`flushSettings`), and
    /// any practice record saved in the meantime carries it too.
    @discardableResult func updateSettings(_ mutation: (inout UserSettings) -> Void) -> Bool {
        let previous = settings
        var next = settings; mutation(&next)
        guard next != previous else { return true }
        do {
            try persistence.stageSettings(next); settings = persistence.settings
            scheduleSettingsWrite()
            TimbreLocalization.language = settings.language
            NoteNames.active = settings.notation
            Haptics.shared.enabled = settings.hapticsEnabled
            if previous.sharesUsage != settings.sharesUsage { Analytics.setSharing(settings.sharesUsage) }
            tracker.confidenceThreshold = settings.confidenceThreshold
            applyPrecision()
            // Only a change that affects listening restarts the microphone; output keeps playing.
            let listeningChanged = previous.referencePitchHz != settings.referencePitchHz || previous.temperamentId != settings.temperamentId
                || previous.micSensitivity != settings.micSensitivity || previous.confidenceThreshold != settings.confidenceThreshold
                || previous.analysisWindowOverride != settings.analysisWindowOverride
            if listeningChanged {
                tracker.reset(); live.clear()
                if audio.running { audio.stopCapture(); startListening() }
            }
            if Self.shapesToday(previous, settings) { pinDailyPlanSoon() }
            return true
        } catch {
            self.error = String(localized: "Settings could not be saved: \(error.localizedDescription)")
            return false
        }
    }

    private func scheduleSettingsWrite() {
        guard settingsWrite == nil else { return }
        settingsWrite = Task { @MainActor [weak self] in
            do { try await Task.sleep(for: .milliseconds(400)) } catch { return }
            self?.flushSettings()
        }
    }

    /// Writes settings changes still waiting (the app leaving the foreground; tests before reopening the store).
    func flushSettings() {
        settingsWrite?.cancel(); settingsWrite = nil
        guard persistence.hasUnsavedChanges else { return }
        do { try persistence.flush() } catch {
            self.error = String(localized: "Settings could not be saved: \(error.localizedDescription)")
        }
    }

    /// Minutes a day the player committed to on onboarding's plan (5, 10 or 15).
    static let dailyMinutesKey = "plan.dailyMinutes"
    var dailyMinutes: Int { UserDefaults.standard.object(forKey: Self.dailyMinutesKey) as? Int ?? 10 }

    /// Ends onboarding: the instrument, the placement and the daily commitment are saved, then Learn opens
    /// the plan's first lesson (`pendingLessonId`) rather than leaving the player on the tuner.
    func completeOnboarding(instrument: Instrument?, level: String, goal: String, minutes: Int = 10) {
        // Every instrument tunes free in its standard tuning (`AccessPolicy.canTune`): the chosen one takes the stage.
        if let instrument, canTune(instrument) {
            _ = selectInstrument(instrument, photo: catalog.photo(instrumentId: instrument.id)?.asset)
        }
        // "How long have you been playing?" places the learner: earlier units open, none counted as finished.
        let placed = onboardingProgress(level: level, instrumentId: instrument?.id, goal: goal)
        let placementChanged = placed != learn
        updateSettings {
            $0.onboardingCompleted = true; $0.playerLevel = level; $0.goal = goal
            // Today's plan follows the instrument and goal just chosen (onboarding run again included).
            $0.dailyPlan = nil
            if placementChanged { $0.learn = placed }
            if let id = instrument?.id {
                $0.recentInstrumentIds = Array(([id] + $0.recentInstrumentIds.filter { $0 != id }).prefix(LocalStore.recentInstrumentLimit))
            }
        }
        UserDefaults.standard.set(minutes, forKey: Self.dailyMinutesKey)
        // Learn opens on the course for the instrument (or the goal) chosen in onboarding, with its first lesson open.
        if let course = onboardingCourse(instrumentId: instrument?.id, goal: goal) {
            UserDefaults.standard.set(course.id, forKey: "learn.course")
            if let lesson = firstLesson(in: course) {
                pendingLessonId = lesson.id
                selectedTab = .learn
            }
        }
        publishWidgets()
    }

    /// The lesson onboarding hands to Learn: the placed first lesson (the plan card's "First lesson"; on the free plan
    /// it opens as the placement pass), else the first lesson still to play that this player can open (nil leaves
    /// Learn on the course without opening one).
    private func firstLesson(in course: LearnCourse) -> Lesson? {
        if let next = learn.nextLesson(in: course), canPlay(next) { return next }
        return course.lessons.first { canPlay($0) && !learn.isFinished($0.id) && learn.isUnlocked($0, in: course) }
    }

    /// Onboarding's first tune counts like a string locked on the tuner: a tuning record (today starts the streak and
    /// ticks the daily set's tune-up) and the lock's progress event (XP, the tuning quest, "First in tune").
    /// Onboarding covers the reward toast, so the step shows what was earned itself.
    @discardableResult
    func recordFirstTune(_ tune: FirstTuneResult) -> ProgressUpdate? {
        save(PracticeRecord(date: tune.started, instrumentId: tune.instrumentId, tuningId: tune.tuningId, kind: "tuning",
                            count: tune.readings, stableCount: min(tune.stableReadings, tune.readings),
                            meanAbsoluteCents: tune.meanAbsoluteCents, durationMs: tune.durationMs))
        markDaily(.tune)
        return recordProgress(.stringTuned(instrumentId: tune.instrumentId, all: false, course: tune.course, courses: tune.courses,
                                           precise: settings.precision == .pro), toast: false)
    }

    /// The course onboarding's plan leads to: the goal's own course (ear, voice, rhythm), else the instrument's, else theory.
    func onboardingCourse(instrumentId: String?, goal: String) -> LearnCourse? {
        let byGoal = ["ear": "ear", "voice": "voice", "rhythm": "rhythm"][goal]
        let id = byGoal ?? instrumentId.flatMap { instrument in curriculum.courses.first { $0.instrument == instrument }?.id }
        return id.flatMap { curriculum.course(id: $0) } ?? curriculum.course(id: "theory")
    }

    /// Learn progress with the experience answer applied as a placement in the plan's course and the instrument's own course.
    func onboardingProgress(level: String, instrumentId: String?, goal: String) -> LearnProgress {
        var progress = learn
        let own = instrumentId.flatMap { instrument in curriculum.courses.first { $0.instrument == instrument } }
        for course in [onboardingCourse(instrumentId: instrumentId, goal: goal), own].compactMap({ $0 }) {
            progress.place(level: level, in: course)
        }
        return progress
    }

    func open(_ destination: IntentRouter.Destination) {
        Analytics.log("shortcut", ["destination": destination.rawValue])
        switch destination {
        case .tune: selectedTab = .tune
        case .metronome: selectedTab = .practice; pendingPracticeRoute = .metronome
        case .ear: selectedTab = .practice; pendingPracticeRoute = .ear
        case .daily: selectedTab = .practice
        case .learn: selectedTab = .learn
        }
    }

    /// Opens the paywall; its impression is logged by the paywall itself when it shows.
    func presentPaywall(_ reason: String, lesson: Lesson? = nil, instrument: Instrument? = nil) {
        paywallReason = reason; paywallLessonId = lesson?.id; paywallInstrumentId = instrument?.id
        showPaywall = true
    }

    // MARK: Instrument selection

    @discardableResult func selectInstrument(_ instrument: Instrument, photo: String? = nil, tuning: Tuning? = nil) -> Bool {
        guard canTune(instrument) else { presentPaywall("instrument", instrument: instrument); return false }
        if let tuning, tuning.instrumentId != instrument.id { return false }
        if let tuning, !AccessPolicy.canUse(tuning: tuning, of: instrument, pro: isPro) { presentPaywall("tuning", instrument: instrument); return false }
        endTuningSession()
        let saved = updateSettings {
            $0.selectedInstrumentId = instrument.id; $0.selectedPhotoAsset = photo
            if let tuning { $0.lastTuningIds[instrument.id] = tuning.id }
            $0.recentInstrumentIds = Array(([instrument.id] + $0.recentInstrumentIds.filter { $0 != instrument.id }).prefix(8))
        }
        guard saved else { return false }
        resetTuningMeasurements(); referenceMode = false
        selectedCourse = courses.first?.index ?? 0
        selectedTab = .tune
        Analytics.log("instrument_selected", ["id": instrument.id])
        return true
    }

    func selectTuning(_ tuning: Tuning) {
        guard tuning.instrumentId == instrument.id else { return }
        guard AccessPolicy.canUse(tuning: tuning, of: instrument, pro: isPro) else { presentPaywall("tuning", instrument: instrument); return }
        endTuningSession()
        guard updateSettings({ $0.lastTuningIds[instrument.id] = tuning.id }) else { return }
        resetTuningMeasurements()
        selectedCourse = courses.first?.index ?? 0
    }

    func selectReference() { endTuningSession(); resetTuningMeasurements(); referenceMode = true; automatic = true; selectedTab = .tune }

    func chooseReferenceNote(_ midi: Int) {
        referenceMidi = min(119, max(12, midi)); automatic = false
        tracker.reset(); live.clear(); audio.stopTone()
    }

    func chooseCourse(_ index: Int) {
        selectedCourse = index; automatic = false
        tracker.reset(); live.clear(); audio.stopTone()
        Haptics.shared.selection()
    }

    func chooseAnchor(_ anchor: String) {
        if let course = courses.first(where: { $0.anchorId == anchor }) { chooseCourse(course.index) }
    }

    // MARK: Listening

    var canListen: Bool { referenceMode || AccessPolicy.canUse(tuning: tuning, of: instrument, pro: isPro) }

    func startListening() {
        guard !audio.running else { return }
        guard canListen else { presentPaywall("instrument", instrument: instrument); return }
        tracker.reset(); live.clear()
        if sessionStarted == nil { sessionStarted = Date(); sessionStartedUptime = ProcessInfo.processInfo.systemUptime }
        #if DEBUG
        if ProcessInfo.processInfo.environment["TIMBRE_DEMO_PITCH"] == "1" {
            // A store scene (Root/DemoScenes.swift) holds the string in tune; otherwise it drifts in every six seconds.
            audio.startDemo(target: { [weak self] in self?.targetHz ?? 440 }, cued: { DemoScene.steadyPitch })
            return
        }
        #endif
        let scale = settings.referencePitchHz / 440
        let margin = pow(2.0, 2.0 / 12.0)
        let targets = referenceMode ? [25.0, 4500.0] : courses.map { target(for: $0) }
        let low = min(referenceMode ? 25 : instrument.minFrequencyHz * scale, targets.min() ?? 25) / margin
        let high = max(referenceMode ? 4500 : instrument.maxFrequencyHz * scale, targets.max() ?? 4500) * margin
        Task { await audio.start(minimum: low, maximum: high, micSensitivity: microphoneGain, analysisWindowOverride: settings.analysisWindowOverride, confidenceThreshold: settings.confidenceThreshold) }
    }

    func toggleListening() { audio.running ? pauseListening() : startListening() }

    func pauseListening() {
        let last = live.reading.frequency != nil ? live.reading : nil
        audio.stopCapture(); tracker.reset()
        if let last { live.reading = last; live.preserved = true }
        endTuningSession()
    }

    func toggleTone() {
        if audio.tonePlaying { audio.stopTone(); tracker.reset() }
        else {
            guard canListen else { presentPaywall("instrument", instrument: instrument); return }
            tracker.reset()
            audio.playTone(targetHz)
        }
    }

    private var microphoneGain: Double { pow(10, Double(settings.micSensitivity - 60) / 40) }
    private func resetTuningMeasurements() { sessionCount = 0; stableCount = 0; totalError = 0; sessionStarted = nil; sessionStartedUptime = nil; autoHits = 0; lastAutoIndex = nil; lockedCourses = []; sampledCourses = [] }
    func target(for course: Course) -> Double { Temperament.byId(settings.temperamentId).frequency(midi: course.targetMidi, reference: settings.referencePitchHz, letterName: course.label) }

    func accept(_ hz: Double?, confidence: Double, level: Double) {
        if let lessonListener {
            lessonListener(confidence.isFinite && confidence >= settings.confidenceThreshold ? hz : nil, level)
            return
        }
        live.preserved = false
        live.level = level
        live.updatedAt = ProcessInfo.processInfo.systemUptime
        let now = Int(ProcessInfo.processInfo.systemUptime * 1000)
        if hz == nil || confidence < settings.confidenceThreshold { autoHits = 0; lastAutoIndex = nil }
        if voiceRunning {
            guard countdown == 0, let attempt else { return }
            let elapsed = Int((ProcessInfo.processInfo.systemUptime - voiceStarted) * 1000)
            guard elapsed < voiceExercise.durationMs else { return }
            let acceptedHz = confidence.isFinite && confidence >= settings.confidenceThreshold ? hz : nil
            let stable = voiceStability.update(acceptedHz)
            attempt.accept(frequency: acceptedHz, stable: stable, elapsedMs: elapsed)
            live.voiceLiveHoldMs = attempt.liveHoldMs
            let target = PitchMath.frequency(midi: Double(voiceExercise.note(at: elapsed)), reference: settings.referencePitchHz)
            live.reading = tracker.accept(frequency: hz, confidence: confidence, target: target, timestampMs: now)
            live.trace.append(acceptedHz.map { PitchMath.cents(target: target, measured: $0) })
            if live.trace.count > 600 { live.trace.removeFirst(live.trace.count - 600) }
            return
        }
        // The lock bell (played at a string's pitch) must not pull automatic detection onto another string.
        if automatic, !referenceMode, gameTargetHz == nil, ProcessInfo.processInfo.systemUptime >= autoQuietUntil, let hz, confidence >= settings.confidenceThreshold {
            let nearest = courses.min { abs(log(hz / target(for: $0))) < abs(log(hz / target(for: $1))) }
            // Unison partners (a mandolin's pair) tie: stay on the string being tuned, so a pair's second string gets its turn.
            let active = activeCourse
            let best = nearest.map { $0.targetMidi == active.targetMidi && $0.anchorId == active.anchorId ? active : $0 }
            if let best {
                if lastAutoIndex == best.index { autoHits += 1 } else { autoHits = 1; lastAutoIndex = best.index }
                if autoHits >= 3 && selectedCourse != best.index { selectedCourse = best.index; tracker.reset() }
            }
        }
        if referenceMode, automatic, let hz, hz > 0, confidence >= settings.confidenceThreshold {
            let midi = min(119, max(12, Int(PitchMath.midi(frequency: hz, reference: settings.referencePitchHz).rounded())))
            if midi != referenceMidi { referenceMidi = midi }
        }
        let wasInTune = live.reading.inTune
        let tunedTo = targetHz
        var reading = tracker.accept(frequency: hz, confidence: confidence, target: tunedTo, timestampMs: now)
        if hz == nil && level > -60 && !audio.tonePlaying { reading = TuningReading(frequency: nil, cents: nil, stable: false, inTune: false, status: "uncertain") }
        live.reading = reading
        // The feel (today: the cent detents and the lock) comes first, ahead of the lock's rewards.
        onTunerFrame(TunerFrame(reading: reading, targetHz: tunedTo, level: level, enteredTune: reading.inTune && !wasInTune,
                                measuring: measuringTuning, time: live.updatedAt))
        if !referenceMode, measuringTuning, reading.stable, let cents = reading.cents, abs(cents) <= 100,
           !sampledCourses.contains(activeCourse.index), let anchor = activeCourse.anchorId {
            sampledCourses.insert(activeCourse.index)
            var state = progress
            state.sample(StringSample(instrumentId: instrument.id, anchor: anchor, date: Date(), cents: cents))
            updateSettings { $0.progress = state }
        }
        if reading.inTune && !wasInTune && measuringTuning && !referenceMode {
            let before = allCoursesLocked
            let fresh = lockedCourses.insert(activeCourse.index).inserted
            let completed = !before && allCoursesLocked
            if completed { completedFullTune() }
            if fresh {
                // The course goes into today's saved list too, so the tuning quest keeps its count after this session ends.
                recordProgress(.stringTuned(instrumentId: instrument.id, all: completed, course: activeCourse.index,
                                            courses: courses.map(\.index), precise: settings.precision == .pro))
            }
        }
        if measuringTuning, let cents = reading.cents, reading.frequency != nil {
            sessionCount += 1
            if reading.stable { stableCount += 1; totalError += abs(cents) }
        }
    }

    /// Seconds from the first reading to the last string locking, for the celebration and share card.
    private(set) var lastTuneSeconds: Int?

    private func completedFullTune() {
        lastTuneSeconds = sessionStartedUptime.map { Int((ProcessInfo.processInfo.systemUptime - $0).rounded()) }
        celebrate += 1
        Haptics.shared.done()
        let count = (settings.fullTunes ?? 0) + 1
        updateSettings { $0.fullTunes = count }
        if count == 3 || count == 12 { requestReviewNow = true }
        Analytics.log("full_tune", ["instrument": instrument.id, "count": String(count)])
    }

    /// Sessions save themselves when listening stops: no "finish" button.
    func endTuningSession() {
        defer { resetTuningMeasurements() }
        guard sessionCount >= 3, let startedUptime = sessionStartedUptime else { return }
        let duration = max(0, Int((ProcessInfo.processInfo.systemUptime - startedUptime) * 1000))
        guard duration >= 4000 else { return }
        let record = PracticeRecord(date: sessionStarted ?? Date(), instrumentId: referenceMode ? "reference.chromatic" : instrument.id, tuningId: referenceMode ? nil : tuning.id, kind: "tuning", count: sessionCount, stableCount: stableCount, meanAbsoluteCents: stableCount > 0 ? totalError / Double(stableCount) : nil, durationMs: duration)
        save(record)
        markDaily(.tune)
    }

    func save(_ record: PracticeRecord) {
        let before = streak.current
        do { try persistence.append(record); records = persistence.records; awardStreakFreezeIfEarned(); noteStreakMilestone(from: before, record: record); publishWidgets() }
        catch { self.error = String(localized: "Practice could not be saved: \(error.localizedDescription)") }
    }

    /// Runs worth a full-screen celebration and a share card: reaching one shows it (lesson results, else `StreakMilestoneOverlay`).
    static let streakMilestones = [3, 7, 30, 100]
    /// The milestone today's practice just reached, until a screen shows it (`takeStreakMilestone`).
    @Published private(set) var streakMilestone: Int?

    /// Only practice saved today reaches a milestone (history written for an earlier day never does).
    private func noteStreakMilestone(from before: Int, record: PracticeRecord) {
        guard Calendar.current.isDateInToday(record.date) else { return }
        let now = streak.current
        if let reached = Self.streakMilestones.last(where: { before < $0 && $0 <= now }) { streakMilestone = reached }
    }

    /// Hands the waiting milestone to the screen that will show it, once.
    func takeStreakMilestone() -> Int? {
        guard let milestone = streakMilestone else { return nil }
        streakMilestone = nil
        return milestone
    }

    // MARK: Practice tracking

    func beginPractice(_ kind: String) { practiceStarted[kind] = ProcessInfo.processInfo.systemUptime }

    /// Records a finished practice activity (ear training, chords, rhythm, drone) for streaks and history.
    func finishPractice(_ kind: DailyActivity.Kind, questions: Int = 0, correct: Int = 0) {
        let started = practiceStarted.removeValue(forKey: kind.rawValue)
        let duration = started.map { Int((ProcessInfo.processInfo.systemUptime - $0) * 1000) } ?? 0
        guard duration >= 10_000 || questions > 0 else { return }
        save(PracticeRecord(instrumentId: "practice.\(kind.rawValue)", kind: kind.rawValue, count: questions, stableCount: min(correct, questions), durationMs: duration))
        markDaily(kind)
        if kind == .ear {
            for _ in 0..<min(correct, questions) { recordProgress(.earCorrect, announce: false) }
            if questions > 0 { recordProgress(.earRound(questions: questions, correct: correct), announce: false) }
        }
        recordProgress(.practiceMinutes(max(1, duration / 60_000)))
    }

    // MARK: Learn

    /// The app's one decoded curriculum (`CurriculumStore.shared`), the copy Spotlight and the band read too.
    let curriculum: Curriculum
    var learn: LearnProgress { settings.learn ?? LearnProgress() }
    /// While a lesson listens, raw readings (Hz when confident, level dBFS) go here instead of the tuner.
    var lessonListener: ((Double?, Double) -> Void)?

    /// Free lessons, every lesson with Pro, and on the free plan the placement pass (`AccessPolicy.canPlay`).
    func canPlay(_ lesson: Lesson) -> Bool {
        AccessPolicy.canPlay(lesson, pro: isPro, progress: learn, courses: curriculum.courses)
    }

    /// The step that owns the lesson microphone; a step leaving must not stop the one that just arrived.
    private var lessonOwner: UUID?

    /// Opens the microphone for a lesson over a pitch range; the demo pitch (UI tests) follows `gameTargetHz`.
    func startLessonListening(owner: UUID, lowHz: Double = 60, highHz: Double = 1400, analyzer: LessonAnalyzer? = nil, listener: @escaping (Double?, Double) -> Void) {
        lessonOwner = owner
        lessonListener = listener
        audio.frames.set(analyzer.map { analyzer in { samples, rate in analyzer.feed(samples, rate: rate) } })
        guard !audio.running else { return }
        #if DEBUG
        if ProcessInfo.processInfo.environment["TIMBRE_DEMO_PITCH"] == "1" {
            audio.startDemo(target: { [weak self] in
                guard let self else { return nil }
                if let due = self.demoNoteDue, !due() { return nil }
                return self.gameTargetHz ?? 440
            }, cued: { [weak self] in self?.demoNoteDue != nil })
            return
        }
        #endif
        Task { await audio.start(minimum: lowHz, maximum: highHz, micSensitivity: microphoneGain, analysisWindowOverride: settings.analysisWindowOverride, confidenceThreshold: settings.confidenceThreshold) }
    }

    /// Stops the lesson microphone; with an owner, only if that step still owns it.
    func stopLessonListening(owner: UUID? = nil) {
        if let owner, owner != lessonOwner { return }
        lessonOwner = nil
        lessonListener = nil
        audio.frames.set(nil)
        gameTargetHz = nil
        if audio.running { audio.stopCapture() }
        tracker.reset(); live.clear()
    }

    /// Saves a finished lesson: stars, XP, quests and badges, and a practice record for the streak; returns what was
    /// earned so the results screen can show it. `credits`: what the lesson's steps said about chord changes, rhythms
    /// and questions (`SpacedReview.credits`), for spaced review alongside the result's note and chord scores.
    @discardableResult
    func finishLesson(_ result: LessonResult, courseId: String, credits: [ReviewCredit] = []) -> ProgressUpdate? {
        // Today's lesson rep, read before this lesson moves the course on.
        let todayRep = dailyRep(forLesson: result.lessonId)
        var learn = self.learn
        learn.record(result, courseId: courseId)
        // Spaced review: what slipped joins the schedule, what came back is spaced out (Learn/WeakSpotReview.swift).
        var deck = reviewDeck
        deck.record(ReviewCredit.from(result.items) + credits, courseId: courseId)
        guard updateSettings({ $0.learn = learn; $0.spacedReview = deck }) else { return nil }
        // count = stars possible, stableCount = stars earned (records require stableCount <= count).
        save(PracticeRecord(instrumentId: "learn.\(courseId)", kind: "lesson", count: 3, stableCount: result.stars, durationMs: result.minutes * 60_000))
        Analytics.log("lesson_done", ["lesson": result.lessonId, "stars": String(result.stars)])
        // The results screen celebrates level-ups and badges itself; the toast would sit hidden behind it.
        var update = recordProgress(.lessonCompleted(stars: result.stars, xp: result.xp), toast: false)
        // Ticks off today's lesson rep; when that finishes the set, its bonus joins this lesson's rewards
        // (`dailySetCompleted`) for the results screen, and the Today card celebrates it on the next visit.
        if let todayRep, let bonus = markDaily(todayRep, toast: false) { update = update.map { $0.merged(with: bonus) } ?? bonus }
        return update
    }

    // MARK: Progress (XP, quests, badges, string health)

    var progress: ProgressState { settings.progress ?? ProgressState() }
    var level: Level { Progression.level(for: progress.xp) }
    var quests: [Quest] { Quests.daily(for: Date()) }
    func questProgress(_ quest: Quest) -> Int { progress.todayProgress(quest) }
    /// The one counter every quest display shows (Play hub, tuner quest line): the tuning quest counts this
    /// instrument's strings locked today, saved with the progress, so a pause or a tab switch never resets it.
    func questCounter(_ quest: Quest) -> (done: Int, total: Int) {
        Quests.counter(for: quest, state: progress, instrumentId: referenceMode ? nil : instrument.id,
                       courses: referenceMode ? [] : courses.map(\.index))
    }
    var stringDrift: [StringDrift] { StringHealth.drift(progress.stringSamples, instrumentId: instrument.id, since: progress.restrung[instrument.id]) }

    /// Badge values derived outside ProgressState: Learn progress (courses, units, songs) and total practice minutes.
    func achievementMetrics(minutes: Int) -> [String: Int] {
        var metrics = Achievements.learnMetrics(learn, curriculum: curriculum)
        metrics["minutes"] = minutes
        return metrics
    }
    var badgeMetrics: [String: Int] { achievementMetrics(minutes: streak.totalMinutes) }

    /// Applies an event to the saved progress; announces XP, quests, badges and level-ups.
    @discardableResult
    func recordProgress(_ event: ProgressEvent, announce: Bool = true, toast: Bool = true) -> ProgressUpdate? {
        var state = progress
        let summary = streak
        let update = state.record(event, streakBest: summary.best, customTunings: settings.customTunings?.count ?? 0,
                                  metrics: achievementMetrics(minutes: summary.totalMinutes))
        guard updateSettings({ $0.progress = state }) else { return nil }
        if toast, update.levelUp != nil || !update.achievementsEarned.isEmpty || update.dailySetCompleted { Haptics.shared.done() }
        if toast, announce || update.levelUp != nil || !update.questsCompleted.isEmpty || !update.achievementsEarned.isEmpty || update.dailySetCompleted {
            publishReward(update)
        }
        for quest in update.questsCompleted { Analytics.log("quest_done", ["quest": quest.id]) }
        if let level = update.levelUp { Analytics.log("level_up", ["level": String(level.number)]) }
        if update.dailySetCompleted { Analytics.log("daily_set_done") }
        GameCenter.shared.recorded(event)  // Pitch Sniper games to the leaderboards and a friend's challenge (Services/GameCenter.swift)
        return update
    }

    /// Hands a reward to the toast. Rewards recorded by one action (a finished ear round records several events)
    /// merge into one announcement, so a quest or the daily set is never overwritten by the "+XP" that follows it.
    private var rewardBatchOpen = false
    private func publishReward(_ update: ProgressUpdate) {
        if rewardBatchOpen, let pending = lastReward { lastReward = pending.merged(with: update) } else { lastReward = update }
        rewardPulse += 1
        guard !rewardBatchOpen else { return }
        rewardBatchOpen = true
        Task { @MainActor [weak self] in self?.rewardBatchOpen = false }
    }

    func markRestrung() {
        var state = progress
        state.restrung[instrument.id] = Date()
        updateSettings { $0.progress = state }
    }

    private static let dayFormatter: DateFormatter = {
        let f = DateFormatter(); f.calendar = Calendar(identifier: .gregorian); f.dateFormat = "yyyy-MM-dd"; return f
    }()
    var todayKey: String { Self.dayFormatter.string(from: Date()) }
    func dailyDone(_ kind: DailyActivity.Kind) -> Bool { settings.dailyDone?[todayKey]?.contains(kind.rawValue) ?? false }
    /// Ticks off an activity of Today; returns the set's bonus when this was its last one.
    @discardableResult
    func markDaily(_ kind: DailyActivity.Kind, toast: Bool = true) -> ProgressUpdate? {
        guard !dailyDone(kind) else { return nil }
        let key = todayKey
        updateSettings { settings in
            var done = settings.dailyDone ?? [:]
            done[key, default: []].append(kind.rawValue)
            if done.count > 45 { for old in done.keys.sorted().dropLast(45) { done.removeValue(forKey: old) } }
            settings.dailyDone = done
        }
        // The last activity of the set pays its bonus, once a day (each activity already saved a practice record,
        // so the day counts for the streak); the toast and the Play hub's Today card celebrate it.
        return dailySetComplete ? recordProgress(.dailySetCompleted, toast: toast) : nil
    }
    /// Today, the day's one session: the next lesson of the learner's course, a review when one is due, then two
    /// tool reps, about as long as the player's daily commitment. On the free plan no Pro tool is picked, so it can
    /// always be finished. The tool reps are pinned for the day once worked out (`pinDailyPlan`): switching the
    /// tuner's instrument, or going Pro, never reshuffles a plan the player has seen. They change on a new day, or
    /// when one can no longer be played (a Pro tool after Pro lapsed). Reading it changes nothing.
    var dailySet: [DailyActivity] { dailySet(at: Date()) }

    private func dailySet(at now: Date) -> [DailyActivity] {
        let day = Self.dayFormatter.string(from: now)
        let pinned = settings.dailyPlan?[day]?.compactMap { DailyActivity.Kind(rawValue: $0) }
        let done = Set((settings.dailyDone?[day] ?? []).compactMap { DailyActivity.Kind(rawValue: $0) })
        return DailySet.activities(instrument: instrument, goal: settings.goal, pro: isPro, lessonMinutes: dailyLesson?.minutes,
                                   reviewMinutes: dailyReviewMinutes, target: dailyMinutes, pinned: pinned, done: done, date: now)
    }

    /// Saves today's tool reps as the day's plan (`UserSettings.dailyPlan`), once it is the player's own: after
    /// onboarding (their instrument and goal) and once StoreKit has said whether they have Pro (before that a Pro
    /// player's plan reads as a free one). Runs after whatever can change the set (settings, Pro, a new day), never
    /// while views draw (`pinDailyPlanSoon`).
    func pinDailyPlan() {
        guard settings.onboardingCompleted == true, commerce.entitlementResolved else { return }
        let now = Date()
        let day = Self.dayFormatter.string(from: now)
        let pinned = settings.dailyPlan?[day]?.compactMap { DailyActivity.Kind(rawValue: $0) }
        let tools = DailySet.toolReps(in: dailySet(at: now))
        guard tools != pinned else { return }
        updateSettings { $0.dailyPlan = [day: tools.map(\.rawValue)] }
    }

    /// A change to what Today's set is worked out from: the instrument, the goal, onboarding, Learn, the reviews, what
    /// is done and the pinned plan.
    private static func shapesToday(_ before: UserSettings, _ after: UserSettings) -> Bool {
        before.selectedInstrumentId != after.selectedInstrumentId || before.goal != after.goal
            || before.onboardingCompleted != after.onboardingCompleted || before.learn != after.learn
            || before.spacedReview != after.spacedReview || before.dailyDone != after.dailyDone || before.dailyPlan != after.dailyPlan
    }

    private var dailyPinQueued = false

    /// `pinDailyPlan` on the next turn, once however many changes ask for it in this one.
    private func pinDailyPlanSoon() {
        guard !dailyPinQueued else { return }
        dailyPinQueued = true
        Task { @MainActor [weak self] in
            guard let self else { return }
            self.dailyPinQueued = false
            self.pinDailyPlan()
        }
    }

    /// The course Learn shows (its Continue card plays that course's next lesson).
    var learnCourse: LearnCourse? {
        curriculum.course(id: UserDefaults.standard.string(forKey: "learn.course") ?? "guitar") ?? curriculum.courses.first
    }

    /// Today's lesson: once one is done, the lesson finished; before that, the course's next lesson, if this
    /// player can open it (a locked lesson leaves the slot to a tool rep instead).
    var dailyLesson: Lesson? {
        if dailyDone(.lesson), let id = learn.lastLessonId, let finished = curriculum.lesson(id: id) { return finished.lesson }
        guard let course = learnCourse, let next = learn.nextLesson(in: course), canPlay(next) else { return nil }
        return next
    }

    /// Minutes of today's review rep, when Learn has a review due.
    /// Spaced review puts one in whenever something is due; once done, it keeps its place on the ring for the day.
    var dailyReviewMinutes: Int? {
        if dailyDone(.review) { return SpacedReview.sessionMinutes }
        guard let course = learnCourse, reviewDue(in: course), let review = weakSpotReview(in: course) else { return nil }
        return review.minutes
    }

    /// The rep a finished lesson completes: a review lesson ticks off a due review, any other lesson (a replay or
    /// another course included) ticks off the lesson; nil when today's set has no such rep left open.
    private func dailyRep(forLesson id: String) -> DailyActivity.Kind? {
        let open = Set(dailySet.map(\.kind).filter { !dailyDone($0) })
        if LearnProgress.isReview(id) || curriculum.lesson(id: id)?.lesson.kind == .review, open.contains(.review) { return .review }
        return open.contains(.lesson) ? .lesson : nil
    }

    /// Opens today's lesson in Learn (Learn alone once it's done).
    func openDailyLesson() {
        if !dailyDone(.lesson), let lesson = dailyLesson { pendingLessonId = lesson.id }
        selectedTab = .learn
        Haptics.shared.selection()
    }
    /// Every activity of today's set done.
    var dailySetComplete: Bool {
        let set = dailySet
        return !set.isEmpty && set.allSatisfy { dailyDone($0.kind) }
    }

    // MARK: Voice

    func startVoice() {
        let freeLevel = voiceLevel == 7
        guard isPro || freeLevel else { presentPaywall("voice"); return }
        if pendingVoiceRecord != nil { retryVoiceSave(); return }
        stopActivity(); voiceResult = nil; live.trace = []; tracker.reset(); voiceStability.reset(); live.voiceLiveHoldMs = 0
        voiceRunning = true; countdown = 3
        let exercise = voiceExercise
        voiceTask = Task { [weak self] in
            guard let self else { return }
            self.audio.playTone(PitchMath.frequency(midi: Double(exercise.rootMidi), reference: self.settings.referencePitchHz), voice: .voice)
            try? await Task.sleep(for: .seconds(1))
            guard !Task.isCancelled else { return }
            self.audio.stopTone()
            let voiceTargets = exercise.notes.map { PitchMath.frequency(midi: Double($0), reference: self.settings.referencePitchHz) }
            let low = min(65, (voiceTargets.min() ?? 65) / 1.1225)
            let high = max(1100, (voiceTargets.max() ?? 1100) * 1.1225)
            await self.audio.start(minimum: low, maximum: high, micSensitivity: self.microphoneGain, analysisWindowOverride: self.settings.analysisWindowOverride, confidenceThreshold: self.settings.confidenceThreshold)
            guard !Task.isCancelled else { return }
            guard self.audio.running else { self.voiceRunning = false; self.countdown = 0; return }
            for value in [2, 1] {
                self.countdown = value
                try? await Task.sleep(for: .seconds(1))
                guard !Task.isCancelled else { return }
            }
            self.attempt = VoiceAttempt(exercise: exercise, referenceHz: self.settings.referencePitchHz)
            self.voiceStarted = ProcessInfo.processInfo.systemUptime
            self.live.voiceElapsed = 0; self.countdown = 0
            while !Task.isCancelled {
                let elapsed = Int((ProcessInfo.processInfo.systemUptime - self.voiceStarted) * 1000)
                self.live.voiceElapsed = min(elapsed, exercise.durationMs - 1)
                if elapsed >= exercise.durationMs { self.finishVoice(); return }
                try? await Task.sleep(for: .milliseconds(33))
            }
        }
    }

    func finishVoice() {
        voiceTask?.cancel(); voiceTask = nil
        audio.stopCapture(); voiceRunning = false; countdown = 0; live.clear()
        guard let attempt else { return }
        let result = attempt.finish(); voiceResult = result
        let record = PracticeRecord(instrumentId: "voice", tuningId: attempt.exercise.id, kind: "voice", count: result.readingCount, stableCount: result.stableReadingCount, meanAbsoluteCents: result.meanAbsoluteCentsError, voiceResult: result, durationMs: min(attempt.exercise.durationMs, max(0, Int((ProcessInfo.processInfo.systemUptime - voiceStarted) * 1000))))
        pendingVoiceRecord = record
        retryVoiceSave()
        markDaily(.voice)
    }

    func retryVoiceSave() {
        guard let record = pendingVoiceRecord else { return }
        do { try persistence.append(record); records = persistence.records; attempt = nil; pendingVoiceRecord = nil; voiceSaveFailed = false }
        catch { voiceSaveFailed = true; self.error = String(localized: "Voice result could not be saved: \(error.localizedDescription)") }
    }

    func cancelVoice() {
        guard voiceRunning || voiceTask != nil else { return }
        voiceTask?.cancel(); voiceTask = nil; attempt = nil; voiceRunning = false; countdown = 0; live.voiceLiveHoldMs = 0
        audio.stopCapture(); tracker.reset(); voiceStability.reset()
    }

    /// Stops listening and voice practice. Metronome and drone are left alone.
    func stopActivity() {
        cancelVoice()
        if audio.running { pauseListening() }
        live.preserved = false
    }

    func clearHistory() {
        do {
            try persistence.clearHistory(); records = persistence.records
            pendingVoiceRecord = nil; voiceSaveFailed = false; voiceResult = nil
            stopActivity(); resetTuningMeasurements()
        } catch { self.error = String(localized: "History could not be cleared: \(error.localizedDescription)") }
    }

    // MARK: Metronome and drone

    var bpm: Int { settings.metronomeBpm ?? 96 }
    var beats: Int { settings.metronomeBeats ?? 4 }
    var subdivision: Int { settings.metronomeSubdivision ?? 1 }
    var metronomeSound: MetronomeRenderer.Sound { MetronomeRenderer.Sound(rawValue: settings.metronomeSound ?? "click") ?? .click }
    var beatLevels: [Int] {
        if let levels = settings.metronomeBeatLevels, levels.count == beats { return levels }
        return (0..<beats).map { $0 == 0 ? 2 : 1 }
    }

    func setMetronome(bpm: Int? = nil, beats: Int? = nil, subdivision: Int? = nil, sound: MetronomeRenderer.Sound? = nil, levels: [Int]? = nil) {
        updateSettings { s in
            if let bpm { s.metronomeBpm = min(300, max(30, bpm)) }
            if let beats { s.metronomeBeats = min(12, max(1, beats)); if s.metronomeBeatLevels?.count != beats { s.metronomeBeatLevels = nil } }
            if let subdivision { s.metronomeSubdivision = min(4, max(1, subdivision)) }
            if let sound { s.metronomeSound = sound.rawValue }
            if let levels { s.metronomeBeatLevels = levels }
        }
        // Only the tool's own click follows its settings; a lesson's click keeps the tempo its take counts in.
        if audio.metronomeRunning && audio.metronomeOwnedByTool { applyMetronome() }
    }

    func cycleBeatLevel(_ beat: Int) {
        var levels = beatLevels
        guard levels.indices.contains(beat) else { return }
        levels[beat] = (levels[beat] + 2) % 3
        setMetronome(levels: levels)
        Haptics.shared.selection()
    }

    func toggleMetronome() {
        if audio.metronomeRunning { audio.stopMetronome(); finishPractice(.rhythm) }
        else { beginPractice(DailyActivity.Kind.rhythm.rawValue); applyMetronome() }
    }

    func applyMetronome() {
        // The tool's click: a tempo or meter change keeps its phase, and it plays on in the background.
        audio.setMetronome(bpm: bpm, beats: beats, subdivision: subdivision, accents: true, beatLevels: beatLevels, sound: metronomeSound, tool: true)
        LiveActivityController.shared.metronomeChanged()
    }

    func tapTempo() {
        let now = ProcessInfo.processInfo.systemUptime
        if lastTaps.last.map({ now - $0 > 2 }) == true { lastTaps = [] }
        lastTaps.append(now); lastTaps = Array(lastTaps.suffix(6))
        if lastTaps.count > 1 { setMetronome(bpm: Int((60 * Double(lastTaps.count - 1) / (now - lastTaps[0])).rounded())) }
        Haptics.shared.selection()
    }

    var droneMidi: Int { settings.droneMidi ?? 50 }
    var droneVoice: DroneRenderer.Voice { DroneRenderer.Voice(rawValue: settings.droneVoice ?? "tanpura") ?? .tanpura }

    func toggleDrone() {
        guard isPro else { presentPaywall("drone"); return }
        if audio.droneRunning { audio.stopDrone(); finishPractice(.drone) }
        else { beginPractice(DailyActivity.Kind.drone.rawValue); applyDrone() }
    }

    func applyDrone() {
        audio.setDrone(tonic: PitchMath.frequency(midi: Double(droneMidi), reference: settings.referencePitchHz), voice: droneVoice, fifth: true)
    }

    func setDrone(midi: Int? = nil, voice: DroneRenderer.Voice? = nil) {
        updateSettings { s in
            if let midi { s.droneMidi = min(72, max(36, midi)) }
            if let voice { s.droneVoice = voice.rawValue }
        }
        if audio.droneRunning { applyDrone() }
    }
}

// MARK: - Strum to tune

extension AppStore {
    /// Strum to tune reads plucked and bowed strings (not keys, winds or percussion) with 3 to 12 strings, on an
    /// instrument this player may tune (the tuner's own rule), never in Chromatic.
    var canStrumTune: Bool {
        guard !referenceMode, canTune(instrument),
              ["guitar", "ukulele", "mandolin", "bowed_strings", "folk_world_strings"].contains(instrument.familyId) else { return false }
        let strings = courses
        return (3...12).contains(strings.count) && strings.allSatisfy { $0.anchorId != nil }
    }

    /// Each string's open pitch in `courses` order, as `PolyTuner` takes them.
    var strumTargets: [Double] { courses.map { target(for: $0) } }

    /// Strum mode opens: the polyphonic tuner takes the microphone's raw frames (delivered on the analysis queue)
    /// and the single-string tuner stands aside, as it does for a lesson: readings only move the input level, so
    /// nothing locks, rings or changes string while the player strums. Listening starts if it was off. A lesson
    /// that owns the microphone keeps it.
    func beginStrum(frames handler: @escaping @Sendable ([Float], Double) -> Void) {
        guard lessonOwner == nil else { return }
        lessonListener = { [weak self] _, level in self?.live.level = level }
        audio.frames.set(handler)
        tracker.reset(); live.clear()
        startListening()
    }

    /// Strum mode closes: the frames stop and the tuner has the microphone back, still listening.
    func endStrum() {
        guard lessonOwner == nil else { return }
        audio.frames.set(nil)
        lessonListener = nil
        tracker.reset(); live.clear()
    }

    /// A strum read every string inside the lock band: the strings count as locked, as if tuned one by one (the
    /// tuner's lock handler rings the resolving chord), and the full tune is celebrated (`celebrate`), rewarded and
    /// saved for today like one tuned string by string. False when every string had already locked this session.
    @discardableResult
    func completeStrumTune(meanCents: Double) -> Bool {
        guard !referenceMode, measuringTuning, canStrumTune else { return false }
        let all = courses.map(\.index)
        let fresh = all.filter { !lockedCourses.contains($0) }
        guard !fresh.isEmpty else { return false }
        lockedCourses.formUnion(fresh)
        completedFullTune()
        for (offset, index) in fresh.enumerated() {
            recordProgress(.stringTuned(instrumentId: instrument.id, all: offset == fresh.count - 1, course: index,
                                        courses: all, precise: settings.precision == .pro))
        }
        // A session long enough to save itself (`endTuningSession`) already covers today's practice.
        if sessionCount < 3 {
            let duration = sessionStartedUptime.map { Int(max(0, ProcessInfo.processInfo.systemUptime - $0) * 1000) }
            save(PracticeRecord(date: sessionStarted ?? Date(), instrumentId: instrument.id, tuningId: tuning.id, kind: "tuning",
                                count: all.count, stableCount: all.count,
                                meanAbsoluteCents: meanCents.isFinite ? max(0, meanCents) : nil, durationMs: duration))
            // That record covers the session so far: the tuner starts a new one from here (the strings stay locked), so
            // `endTuningSession` never counts these minutes a second time.
            let locked = lockedCourses, sampled = sampledCourses
            resetTuningMeasurements()
            lockedCourses = locked; sampledCourses = sampled
            if audio.running { sessionStarted = Date(); sessionStartedUptime = ProcessInfo.processInfo.systemUptime }
        }
        markDaily(.tune)
        Analytics.log("strum_tune", ["instrument": instrument.id, "strings": String(all.count)])
        return true
    }
}
