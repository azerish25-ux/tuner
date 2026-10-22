import SwiftUI
import TimbreCore

@MainActor
final class AppStore: ObservableObject {
    let catalog: Catalog
    let audio = AudioService()
    let commerce = CommerceService()
    let ads = AdvertisingService()
    private let persistence: LocalStore
    @Published private(set) var settings: UserSettings
    @Published private(set) var records: [PracticeRecord]
    @Published var selectedTab = 1
    @Published var showPlus = false
    @Published var showSettings = false
    @Published var error: String?
    @Published var referenceMode = false
    @Published var referenceMidi = 69
    @Published var selectedCourse = 0
    @Published var automatic = true
    @Published private(set) var reading = TuningReading(frequency: nil, cents: nil, stable: false, inTune: false, status: "noSignal")
    @Published var voiceLevel = 1 {
        didSet { if voiceLevel != oldValue { updateSettings { $0.selectedVoiceLevel = voiceLevel } } }
    }
    @Published var voiceRoot = 57
    @Published private(set) var voiceRunning = false
    @Published private(set) var countdown = 0
    @Published private(set) var voiceElapsed = 0
    @Published private(set) var voiceLiveHoldMs = 0
    @Published private(set) var voiceResult: VoiceResult?
    @Published private(set) var voiceSaveFailed = false
    @Published private(set) var trace: [Double?] = []
    @Published var bpm = 80
    @Published var beats = 4
    @Published var subdivision = 1
    @Published var accents = true
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

    init(directory: URL? = nil) throws {
        catalog = try Catalog()
        let storageDirectory = directory ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("Timbre", isDirectory: true)
        persistence = try LocalStore(directory: storageDirectory)
        settings = persistence.settings; records = persistence.records
        voiceLevel = settings.selectedVoiceLevel ?? 1
        TimbreLocalization.language = settings.language
        tracker.confidenceThreshold = settings.confidenceThreshold
        audio.onReading = { [weak self] hz, confidence, level in self?.accept(hz, confidence: confidence, level: level) }
    }
    var demonstratedLevels: Set<Int> { persistence.demonstratedLevels }
    var adEntitlement: AdEntitlement { commerce.isPlus ? .paid : commerce.pending ? .pending : commerce.entitlementResolved ? .free : .unknown }
    var instrument: Instrument { catalog.instrument(id: settings.selectedInstrumentId) ?? catalog.instruments[0] }
    var tuning: Tuning {
        let id = settings.lastTuningIds[instrument.id] ?? instrument.defaultTuningId
        return catalog.tuning(id: id) ?? catalog.tuning(id: instrument.defaultTuningId)!
    }
    var courses: [Course] { tuning.courses.sorted { $0.index < $1.index } }
    var activeCourse: Course { courses.first(where: { $0.index == selectedCourse }) ?? courses[0] }
    var activeMidi: Int { referenceMode ? referenceMidi : activeCourse.targetMidi }
    var targetHz: Double {
        Temperament.byId(settings.temperamentId).frequency(midi: activeMidi, reference: settings.referencePitchHz, letterName: referenceMode ? nil : activeCourse.label)
    }
    var targetName: String { referenceMode ? PitchMath.noteName(midi: activeMidi + settings.transposition - settings.capo, notation: settings.notation) : TargetLabelFormatter.splitCue(courseLabel(activeCourse)).main }
    func courseLabel(_ course: Course) -> String { TargetLabelFormatter.display(label: course.label, midi: course.targetMidi, notation: settings.notation, transposition: settings.transposition, capo: settings.capo) }
    var photo: InstrumentPhoto? {
        catalog.photo(instrumentId: instrument.id, tuningId: tuning.id, preferredAsset: settings.selectedPhotoAsset)
    }
    var voiceExercise: VoiceExercise { VoiceExercise(level: voiceLevel, rootMidi: voiceRoot) }
    var voiceTargetMidi: Int { voiceExercise.note(at: voiceElapsed) }
    var statusText: String {
        switch reading.status {
        case "inTune": return "In tune"
        case "flat": return "Flat · tighten gently"
        case "sharp": return "Sharp · loosen gently"
        case "settling": return "Hold steady"
        case "uncertain": return "Uncertain · play one clear note"
        default: return audio.running ? "Play a note" : "Ready to listen"
        }
    }
    @discardableResult func updateSettings(_ mutation: (inout UserSettings) -> Void) -> Bool {
        var next = settings; mutation(&next)
        do {
            try persistence.saveSettings(next); settings = persistence.settings
            TimbreLocalization.language = settings.language
            tracker.confidenceThreshold = settings.confidenceThreshold; tracker.reset()
            if audio.running || audio.tonePlaying || audio.metronomeRunning || voiceRunning { stopActivity() }
            return true
        }
        catch { self.error = "Settings could not be saved: \(error.localizedDescription)"; return false }
    }
    func selectInstrument(_ instrument: Instrument, photo: String? = nil) {
        guard commerce.isPlus || instrument.isFree else { showPlus = true; return }
        let saved = updateSettings {
            $0.selectedInstrumentId = instrument.id; $0.selectedPhotoAsset = photo
            $0.recentInstrumentIds = Array(([instrument.id] + $0.recentInstrumentIds.filter { $0 != instrument.id }).prefix(8))
        }
        guard saved else { return }
        stopActivity(); resetTuningMeasurements(); referenceMode = false
        selectedCourse = courses.first?.index ?? 0; selectedTab = 1
    }
    func selectTuning(_ tuning: Tuning) {
        guard tuning.instrumentId == instrument.id else { error = "This tuning belongs to a different instrument."; return }
        guard commerce.isPlus || (instrument.isFree && tuning.isFree) else { showPlus = true; return }
        guard updateSettings({ $0.lastTuningIds[instrument.id] = tuning.id }) else { return }
        stopActivity(); resetTuningMeasurements()
        selectedCourse = courses.first?.index ?? 0
    }
    func selectReference() { stopActivity(); resetTuningMeasurements(); referenceMode = true; selectedTab = 1 }
    func chooseCourse(_ index: Int) { selectedCourse = index; automatic = false; tracker.reset(); clearReading(); audio.stopTone() }
    func toggleListening() {
        if audio.running { audio.stop(); tracker.reset() }
        else {
            guard referenceMode || commerce.isPlus || (instrument.isFree && tuning.isFree) else { showPlus = true; return }
            if sessionStarted == nil { sessionStarted = Date(); sessionStartedUptime = ProcessInfo.processInfo.systemUptime }
            let scale = settings.referencePitchHz / 440
            let margin = pow(2.0, 2.0 / 12.0)
            let targets = referenceMode ? [25.0, 4500.0] : courses.map { target(for: $0) }
            let low = min(referenceMode ? 25 : instrument.minFrequencyHz * scale, targets.min() ?? 25) / margin
            let high = max(referenceMode ? 4500 : instrument.maxFrequencyHz * scale, targets.max() ?? 4500) * margin
            Task { await audio.start(minimum: low, maximum: high, micSensitivity: microphoneGain, analysisWindowOverride: settings.analysisWindowOverride, confidenceThreshold: settings.confidenceThreshold) }
        }
    }
    func toggleTone() {
        if audio.tonePlaying { audio.stopTone(); tracker.reset() }
        else {
            guard referenceMode || commerce.isPlus || (instrument.isFree && tuning.isFree) else { showPlus = true; return }
            tracker.reset()
            audio.playTone(targetHz)
        }
    }
    private var microphoneGain: Double { pow(10, Double(settings.micSensitivity - 60) / 40) }
    private func resetTuningMeasurements() { sessionCount = 0; stableCount = 0; totalError = 0; sessionStarted = nil; sessionStartedUptime = nil; autoHits = 0; lastAutoIndex = nil }
    private func clearReading() { reading = TuningReading(frequency: nil, cents: nil, stable: false, inTune: false, status: "noSignal") }
    func accept(_ hz: Double?, confidence: Double, level: Double) {
        let now = Int(ProcessInfo.processInfo.systemUptime * 1000)
        if hz == nil || confidence < settings.confidenceThreshold { autoHits = 0; lastAutoIndex = nil }
        if voiceRunning {
            guard countdown == 0, let attempt else { return }
            let elapsed = Int((ProcessInfo.processInfo.systemUptime - voiceStarted) * 1000)
            guard elapsed < voiceExercise.durationMs else { return }
            let stable = voiceStability.update(confidence >= settings.confidenceThreshold ? hz : nil)
            attempt.accept(frequency: hz, stable: stable, elapsedMs: elapsed)
            voiceLiveHoldMs = attempt.liveHoldMs
            let target = PitchMath.frequency(midi: Double(voiceExercise.note(at: elapsed)), reference: settings.referencePitchHz)
            reading = tracker.accept(frequency: hz, confidence: confidence, target: target, timestampMs: now)
            trace.append(hz.map { PitchMath.cents(target: target, measured: $0) }); if trace.count > 600 { trace.removeFirst() }
            return
        }
        if automatic, !referenceMode, let hz, confidence >= settings.confidenceThreshold {
            let best = courses.min { abs(log(hz / target(for: $0))) < abs(log(hz / target(for: $1))) }
            if let best {
                if lastAutoIndex == best.index { autoHits += 1 } else { autoHits = 1; lastAutoIndex = best.index }
                if autoHits >= 3 { selectedCourse = best.index }
            }
        }
        if referenceMode, automatic, let hz, hz > 0, confidence >= settings.confidenceThreshold {
            referenceMidi = min(119, max(12, Int(PitchMath.midi(frequency: hz, reference: settings.referencePitchHz).rounded())))
        }
        let previousInTune = reading.inTune
        reading = tracker.accept(frequency: hz, confidence: confidence, target: targetHz, timestampMs: now)
        if hz == nil && level > -60 && !audio.tonePlaying {
            reading = TuningReading(frequency: nil, cents: nil, stable: false, inTune: false, status: "uncertain")
        }
        if reading.inTune && !previousInTune && settings.hapticsEnabled { UIImpactFeedbackGenerator(style: .light).impactOccurred() }
        if let cents = reading.cents, reading.frequency != nil {
            sessionCount += 1
            if reading.stable { stableCount += 1; totalError += abs(cents) }
        }
    }
    func target(for course: Course) -> Double { Temperament.byId(settings.temperamentId).frequency(midi: course.targetMidi, reference: settings.referencePitchHz, letterName: course.label) }
    func finishTuning() {
        audio.stop(); tracker.reset()
        guard sessionCount > 0 else { error = "No measured notes to save. Listen and play a clear note first."; return }
        let duration = sessionStartedUptime.map { max(0, Int((ProcessInfo.processInfo.systemUptime - $0) * 1000)) }
        let record = PracticeRecord(date: sessionStarted ?? Date(), instrumentId: referenceMode ? "reference.chromatic" : instrument.id, tuningId: referenceMode ? nil : tuning.id, kind: "tuning", count: sessionCount, stableCount: stableCount, meanAbsoluteCents: stableCount > 0 ? totalError / Double(stableCount) : nil, durationMs: duration)
        do {
            try persistence.append(record); records = persistence.records
            let duration = Int((ProcessInfo.processInfo.systemUptime - (sessionStartedUptime ?? ProcessInfo.processInfo.systemUptime)) * 1000)
            ads.completedTuning(sessionId: record.id.uuidString, durationMs: duration, stableReadingCount: stableCount, entitlement: adEntitlement)
            resetTuningMeasurements()
        }
        catch { self.error = "Practice could not be saved. Your measurements are retained; try Finish again. \(error.localizedDescription)" }
    }
    func startVoice() {
        guard commerce.isPlus else { showPlus = true; return }
        if pendingVoiceRecord != nil { retryVoiceSave(); return }
        stopActivity(); voiceResult = nil; trace = []; tracker.reset(); voiceStability.reset(); voiceLiveHoldMs = 0
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
            self.voiceElapsed = 0; self.countdown = 0
            while !Task.isCancelled {
                let elapsed = Int((ProcessInfo.processInfo.systemUptime - self.voiceStarted) * 1000)
                self.voiceElapsed = min(elapsed, exercise.durationMs - 1)
                if elapsed >= exercise.durationMs { self.finishVoice(); return }
                try? await Task.sleep(for: .milliseconds(50))
            }
        }
    }
    func finishVoice() {
        voiceTask?.cancel(); voiceTask = nil
        audio.stop(); voiceRunning = false; countdown = 0
        guard let attempt else { return }
        let result = attempt.finish(); voiceResult = result
        let record = PracticeRecord(instrumentId: "voice", tuningId: attempt.exercise.id, kind: "voice", count: result.readingCount, stableCount: result.stableReadingCount, meanAbsoluteCents: result.meanAbsoluteCentsError, voiceResult: result, durationMs: min(attempt.exercise.durationMs, max(0, Int((ProcessInfo.processInfo.systemUptime - voiceStarted) * 1000))))
        pendingVoiceRecord = record
        retryVoiceSave()
    }
    func retryVoiceSave() {
        guard let record = pendingVoiceRecord else { return }
        do { try persistence.append(record); records = persistence.records; self.attempt = nil; pendingVoiceRecord = nil; voiceSaveFailed = false }
        catch { voiceSaveFailed = true; self.error = "Voice result could not be saved: \(error.localizedDescription)" }
    }
    func cancelVoice() { voiceTask?.cancel(); voiceTask = nil; attempt = nil; voiceRunning = false; countdown = 0; voiceLiveHoldMs = 0; audio.stop(); tracker.reset(); voiceStability.reset() }
    func stopActivity() { cancelVoice(); audio.stop(); tracker.reset(); reading = TuningReading(frequency: nil, cents: nil, stable: false, inTune: false, status: "noSignal") }
    func clearHistory() {
        do {
            try persistence.clearHistory(); records = persistence.records
            pendingVoiceRecord = nil; voiceSaveFailed = false; voiceResult = nil
            stopActivity(); resetTuningMeasurements()
        } catch { self.error = "History could not be cleared: \(error.localizedDescription)" }
    }
    func toggleMetronome() {
        guard commerce.isPlus else { showPlus = true; return }
        if audio.metronomeRunning { audio.stopMetronome() } else { updateMetronome() }
    }
    func updateMetronome() { audio.setMetronome(bpm: bpm, beats: beats, subdivision: subdivision, accents: accents) }
    func tapTempo() {
        guard commerce.isPlus else { showPlus = true; return }
        let now = ProcessInfo.processInfo.systemUptime
        if lastTaps.last.map({ now - $0 > 2 }) == true { lastTaps = [] }
        lastTaps.append(now); lastTaps = Array(lastTaps.suffix(5))
        if lastTaps.count > 1 { bpm = min(240, max(40, Int((60 * Double(lastTaps.count - 1) / (now - lastTaps[0])).rounded()))) }
        if audio.metronomeRunning { updateMetronome() }
    }
}
