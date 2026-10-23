import SwiftUI
import TimbreCore

enum AppTab: Hashable { case tune, practice, instruments, journey }

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
    @Published private(set) var records: [PracticeRecord]
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
    private var autoHits = 0
    private var lastTaps: [TimeInterval] = []
    private var voiceStarted: TimeInterval = 0
    private var practiceStarted: [String: TimeInterval] = [:]

    init(directory: URL? = nil) throws {
        catalog = try Catalog()
        let storageDirectory = directory ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("Timbre", isDirectory: true)
        persistence = try LocalStore(directory: storageDirectory)
        settings = persistence.settings; records = persistence.records
        voiceLevel = settings.selectedVoiceLevel ?? 1
        TimbreLocalization.language = settings.language
        tracker.confidenceThreshold = settings.confidenceThreshold
        Haptics.shared.enabled = settings.hapticsEnabled
        audio.onReading = { [weak self] hz, confidence, level in self?.accept(hz, confidence: confidence, level: level) }
    }

    // MARK: Derived state

    var isPro: Bool { commerce.isPro }
    var demonstratedLevels: Set<Int> { persistence.demonstratedLevels }
    var instrument: Instrument { catalog.instrument(id: settings.selectedInstrumentId) ?? catalog.instruments[0] }
    var tuning: Tuning {
        let id = settings.lastTuningIds[instrument.id] ?? instrument.defaultTuningId
        if let remembered = catalog.tuning(id: id), remembered.instrumentId == instrument.id { return remembered }
        return catalog.tuning(id: instrument.defaultTuningId)!
    }
    var tunings: [Tuning] { catalog.tunings.filter { $0.instrumentId == instrument.id } }
    var courses: [Course] { tuning.courses.sorted { $0.index < $1.index } }
    var activeCourse: Course { courses.first(where: { $0.index == selectedCourse }) ?? courses[0] }
    var activeMidi: Int { referenceMode ? referenceMidi : activeCourse.targetMidi }
    var targetHz: Double {
        Temperament.byId(settings.temperamentId).frequency(midi: activeMidi, reference: settings.referencePitchHz, letterName: referenceMode ? nil : activeCourse.label)
    }
    var targetName: String { referenceMode ? PitchMath.noteName(midi: activeMidi + settings.transposition - settings.capo, notation: settings.notation) : TargetLabelFormatter.splitCue(courseLabel(activeCourse)).main }
    func courseLabel(_ course: Course) -> String { TargetLabelFormatter.display(label: course.label, midi: course.targetMidi, notation: settings.notation, transposition: settings.transposition, capo: settings.capo) }
    var photo: InstrumentPhoto? { catalog.photo(instrumentId: instrument.id, tuningId: tuning.id, preferredAsset: settings.selectedPhotoAsset) }
    var modelID: String? { referenceMode ? nil : ModelLibrary.modelID(forPhoto: photo?.asset) }
    var instrumentDisplayName: String {
        if referenceMode { return catalog.referenceMode?.name.localized ?? String(localized: "Chromatic") }
        return photo.map { NSLocalizedString("timbre_photo_" + $0.asset, bundle: .main, value: $0.label, comment: "") } ?? instrument.name.localized
    }
    var activeAnchor: String? { referenceMode ? nil : activeCourse.anchorId }
    var allCoursesLocked: Bool { !courses.isEmpty && Set(courses.map(\.index)).isSubset(of: lockedCourses) }
    var voiceExercise: VoiceExercise { VoiceExercise(level: voiceLevel, rootMidi: voiceRoot) }
    var voiceTargetMidi: Int { voiceExercise.note(at: live.voiceElapsed) }
    var streak: StreakSummary { Streaks.summary(records: records) }
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

    @discardableResult func updateSettings(_ mutation: (inout UserSettings) -> Void) -> Bool {
        let previous = settings
        var next = settings; mutation(&next)
        do {
            try persistence.saveSettings(next); settings = persistence.settings
            TimbreLocalization.language = settings.language
            Haptics.shared.enabled = settings.hapticsEnabled
            tracker.confidenceThreshold = settings.confidenceThreshold
            // Only a change that affects listening restarts the microphone; output keeps playing.
            let listeningChanged = previous.referencePitchHz != settings.referencePitchHz || previous.temperamentId != settings.temperamentId
                || previous.micSensitivity != settings.micSensitivity || previous.confidenceThreshold != settings.confidenceThreshold
                || previous.analysisWindowOverride != settings.analysisWindowOverride
            if listeningChanged {
                tracker.reset(); live.clear()
                if audio.running { audio.stopCapture(); startListening() }
            }
            return true
        } catch {
            self.error = String(localized: "Settings could not be saved: \(error.localizedDescription)")
            return false
        }
    }

    func completeOnboarding(instrument: Instrument?, level: String, goal: String) {
        if let instrument, canTune(instrument) {
            _ = selectInstrument(instrument, photo: catalog.photo(instrumentId: instrument.id)?.asset)
        }
        updateSettings { $0.onboardingCompleted = true; $0.playerLevel = level; $0.goal = goal; if let id = instrument?.id { $0.recentInstrumentIds = [id] + $0.recentInstrumentIds } }
    }

    func presentPaywall(_ reason: String) { paywallReason = reason; showPaywall = true; Analytics.log("paywall_shown", ["reason": reason]) }

    // MARK: Instrument selection

    @discardableResult func selectInstrument(_ instrument: Instrument, photo: String? = nil, tuning: Tuning? = nil) -> Bool {
        guard canTune(instrument) else { presentPaywall("instrument"); return false }
        if let tuning, tuning.instrumentId != instrument.id { return false }
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
        guard AccessPolicy.canUse(tuning: tuning, of: instrument, pro: isPro) else { presentPaywall("tuning"); return }
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

    var canListen: Bool { referenceMode || canTune(instrument) }

    func startListening() {
        guard !audio.running else { return }
        guard canListen else { presentPaywall("instrument"); return }
        tracker.reset(); live.clear()
        if sessionStarted == nil { sessionStarted = Date(); sessionStartedUptime = ProcessInfo.processInfo.systemUptime }
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
            guard canListen else { presentPaywall("instrument"); return }
            tracker.reset()
            audio.playTone(targetHz)
        }
    }

    private var microphoneGain: Double { pow(10, Double(settings.micSensitivity - 60) / 40) }
    private func resetTuningMeasurements() { sessionCount = 0; stableCount = 0; totalError = 0; sessionStarted = nil; sessionStartedUptime = nil; autoHits = 0; lastAutoIndex = nil; lockedCourses = [] }
    func target(for course: Course) -> Double { Temperament.byId(settings.temperamentId).frequency(midi: course.targetMidi, reference: settings.referencePitchHz, letterName: course.label) }

    func accept(_ hz: Double?, confidence: Double, level: Double) {
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
        if automatic, !referenceMode, let hz, confidence >= settings.confidenceThreshold {
            let best = courses.min { abs(log(hz / target(for: $0))) < abs(log(hz / target(for: $1))) }
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
        var reading = tracker.accept(frequency: hz, confidence: confidence, target: targetHz, timestampMs: now)
        if hz == nil && level > -60 && !audio.tonePlaying { reading = TuningReading(frequency: nil, cents: nil, stable: false, inTune: false, status: "uncertain") }
        live.reading = reading
        Haptics.shared.detent(cents: reading.stable ? reading.cents : nil)
        if reading.inTune && !wasInTune {
            Haptics.shared.lock()
            if !referenceMode {
                let before = allCoursesLocked
                lockedCourses.insert(activeCourse.index)
                if !before && allCoursesLocked { completedFullTune() }
            }
        }
        if let cents = reading.cents, reading.frequency != nil {
            sessionCount += 1
            if reading.stable { stableCount += 1; totalError += abs(cents) }
        }
    }

    private func completedFullTune() {
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
        do { try persistence.append(record); records = persistence.records }
        catch { self.error = String(localized: "Practice could not be saved: \(error.localizedDescription)") }
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
    }

    private static let dayFormatter: DateFormatter = {
        let f = DateFormatter(); f.calendar = Calendar(identifier: .gregorian); f.dateFormat = "yyyy-MM-dd"; return f
    }()
    var todayKey: String { Self.dayFormatter.string(from: Date()) }
    func dailyDone(_ kind: DailyActivity.Kind) -> Bool { settings.dailyDone?[todayKey]?.contains(kind.rawValue) ?? false }
    func markDaily(_ kind: DailyActivity.Kind) {
        guard !dailyDone(kind) else { return }
        let key = todayKey
        updateSettings { settings in
            var done = settings.dailyDone ?? [:]
            done[key, default: []].append(kind.rawValue)
            if done.count > 45 { for old in done.keys.sorted().dropLast(45) { done.removeValue(forKey: old) } }
            settings.dailyDone = done
        }
    }
    var dailySet: [DailyActivity] { DailySet.activities(instrument: instrument, goal: settings.goal) }

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
            self.audio.playTone(PitchMath.frequency(midi: Double(exercise.rootMidi), reference: self.settings.referencePitchHz))
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
        if audio.metronomeRunning { applyMetronome() }
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

    func applyMetronome() { audio.setMetronome(bpm: bpm, beats: beats, subdivision: subdivision, accents: true, beatLevels: beatLevels, sound: metronomeSound) }

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
