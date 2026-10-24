import AVFoundation
import Combine
import UIKit
import TimbreCore

/// Owns the single audio session. Pitch analysis runs on a bounded serial queue at ~60 Hz;
/// readings go straight to `onReading` so high-rate values never invalidate unrelated views.
@MainActor
final class AudioService: ObservableObject {
    @Published private(set) var running = false
    @Published private(set) var error: String?
    @Published private(set) var permissionDenied = false
    @Published private(set) var metronomeRunning = false
    @Published private(set) var droneRunning = false
    @Published private(set) var tonePlaying = false
    /// Headphones (wired, Bluetooth A2DP or LE, AirPods) carry the output: the backing band may play.
    @Published private(set) var headphones = AudioService.headphonesConnected()
    /// The lesson band is installed under the metronome (it sounds from the next downbeat).
    @Published private(set) var bandPlaying = false
    /// Where the sound goes now; each kind of route keeps its own tap-along calibration.
    @Published private(set) var route = AudioService.currentRoute()
    func clearError() { error = nil }
    var onReading: ((Double?, Double, Double) -> Void)?
    /// Raw microphone samples for lesson analysers (chords, onsets), delivered on the analysis queue.
    let frames = FrameSink()
    private var engine = AVAudioEngine()
    private let analysisQueue = DispatchQueue(label: "com.timbre.pitch", qos: .userInitiated)
    private let renderer = OutputRenderer()
    private var source: AVAudioSourceNode?
    private var tapInstalled = false
    private var observers: [NSObjectProtocol] = []
    private var minimum = 25.0, maximum = 4500.0
    private var sensitivity = 1.0, confidenceThreshold = 0.75
    private var windowOverride: Int?
    private var generation = 0
    private var toneTask: Task<Void, Never>?
    private var resumeCaptureAfterTone = false
    /// How late a click is heard on the current route: the learner's tap-along calibration for this kind of
    /// route when there is one, else the session's output latency (often too low on Bluetooth).
    private var heardLatency = AudioService.calibratedLatency(for: AudioService.currentRoute()) ?? AVAudioSession.sharedInstance().outputLatency
    private let bandQueue = DispatchQueue(label: "com.timbre.band", qos: .utility)
    private var bandRequest: BandRequest?
    private var bandPrepared: BandArrangement?
    private var bandCache: [BandRenderKey: BandTrack] = [:]
    private var bandRendering: Set<BandRenderKey> = []
    /// A final chord is ringing out; the engine stays up for it.
    private var bandOutro = false
    private var outroTask: Task<Void, Never>?
    /// The voice tones sound in when a call names none: the selected instrument's (the store provides it).
    var instrumentVoice: () -> InstrumentVoice = { .guitar }
    /// The open lesson's course instrument while its player is showing; nil falls back to `instrumentVoice`.
    var courseVoice: InstrumentVoice?
    /// Tones render here (a few milliseconds), never on the main thread or in the audio callback.
    private let toneQueue = DispatchQueue(label: "com.timbre.tones", qos: .userInitiated)
    /// Recent renderings: a lesson replays the same chord, the tuner the same string.
    private var toneCache: [ToneRequest: ToneClip] = [:]
    private var toneRecency: [ToneRequest] = []
    /// The tone asked for last, until it starts; a newer one (or a stop) supersedes it.
    private var pendingTone: PendingTone?
    private var toneToken = 0

    init() {
        observers.append(NotificationCenter.default.addObserver(forName: AVAudioSession.interruptionNotification, object: nil, queue: .main) { [weak self] notification in
            let began = (notification.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt) == AVAudioSession.InterruptionType.began.rawValue
            Task { @MainActor in
                guard began, let self else { return }
                self.suspend()
            }
        })
        observers.append(NotificationCenter.default.addObserver(forName: UIApplication.didEnterBackgroundNotification, object: nil, queue: .main) { [weak self] _ in
            // The microphone stops in the background; metronome and drone keep playing, the lesson band stops.
            Task { @MainActor in self?.stopBand(); self?.stopCapture() }
        })
        observers.append(NotificationCenter.default.addObserver(forName: UIApplication.didReceiveMemoryWarningNotification, object: nil, queue: .main) { [weak self] _ in
            // Rendered bands are a few MB each; the one playing stays alive with its player (tones likewise).
            Task { @MainActor in self?.bandCache.removeAll(); self?.toneCache.removeAll(); self?.toneRecency.removeAll() }
        })
        observers.append(NotificationCenter.default.addObserver(forName: AVAudioSession.routeChangeNotification, object: nil, queue: .main) { [weak self] notification in
            // Headphones in or out: the band follows at once (out: it fades before it can reach the mic).
            Task { @MainActor in self?.refreshRoute() }
            let reason = (notification.userInfo?[AVAudioSessionRouteChangeReasonKey] as? UInt).flatMap(AVAudioSession.RouteChangeReason.init(rawValue:))
            guard reason != nil, reason != .categoryChange, reason != .unknown else { return }
            Task { @MainActor in
                guard let self, self.running else { return }
                let minimum = self.minimum, maximum = self.maximum, sensitivity = self.sensitivity
                let window = self.windowOverride, confidence = self.confidenceThreshold
                self.stopCapture()
                guard UIApplication.shared.applicationState == .active else { return }
                await self.start(minimum: minimum, maximum: maximum, micSensitivity: sensitivity, analysisWindowOverride: window, confidenceThreshold: confidence)
            }
        })
        observers.append(NotificationCenter.default.addObserver(forName: AVAudioSession.mediaServicesWereResetNotification, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                self.suspend(); self.engine = AVAudioEngine()
            }
        })
    }

    var outputActive: Bool { metronomeRunning || droneRunning || tonePlaying || bandOutro }

    func start(minimum: Double = 25, maximum: Double = 4500, micSensitivity: Double = 1, analysisWindowOverride: Int? = nil, confidenceThreshold: Double = 0.75) async {
        guard !running, !Task.isCancelled else { return }
        if tonePlaying {
            toneTask?.cancel(); toneTask = nil; resumeCaptureAfterTone = false
            pendingTone = nil
            renderer.stopClip(); tonePlaying = false
        }
        generation += 1
        let token = generation
        let allowed = await AVAudioApplication.requestRecordPermission()
        guard generation == token, !Task.isCancelled else { return }
        permissionDenied = !allowed
        guard allowed else { error = String(localized: "Microphone access is off. Turn it on in Settings to tune."); return }
        var transitionChecks = 0
        while UIApplication.shared.applicationState == .inactive && transitionChecks < 20 {
            do { try await Task.sleep(for: .milliseconds(50)) } catch { return }
            guard generation == token, !Task.isCancelled else { return }
            transitionChecks += 1
        }
        guard UIApplication.shared.applicationState == .active else { return }
        self.minimum = minimum.isFinite && minimum > 0 ? minimum : 25
        self.maximum = maximum.isFinite && maximum > self.minimum ? maximum : max(4500, self.minimum * 2)
        sensitivity = micSensitivity.isFinite ? min(4, max(0.1, micSensitivity)) : 1
        self.confidenceThreshold = confidenceThreshold.isFinite ? min(1, max(0, confidenceThreshold)) : 0.75
        windowOverride = analysisWindowOverride
        do {
            let wasOutputting = engine.isRunning
            engine.stop()
            try configureSession()
            let input = engine.inputNode
            let format = input.outputFormat(forBus: 0)
            guard format.sampleRate > 0, format.channelCount > 0 else { throw AudioFailure.noInput }
            let window = AnalysisWindowPolicy.windowSizeForTuningRange(minFrequencyHz: self.minimum, sampleRateHz: Int(format.sampleRate), preferredWindow: analysisWindowOverride)
            let worker = PitchWorker(rate: format.sampleRate, minimum: self.minimum, maximum: self.maximum, window: window, gain: sensitivity)
            let frames = self.frames, rate = format.sampleRate
            input.installTap(onBus: 0, bufferSize: 512, format: format) { [weak self, analysisQueue] buffer, _ in
                guard let samples = buffer.floatChannelData?[0], let epoch = worker.reserve() else { return }
                let copy = Array(UnsafeBufferPointer(start: samples, count: Int(buffer.frameLength)))
                analysisQueue.async {
                    frames.send(copy, rate: rate)
                    let output = worker.consume(copy, epoch: epoch)
                    worker.release()
                    guard let output else { return }
                    Task { @MainActor [weak self] in
                        guard let self, self.generation == token, self.running else { return }
                        let silent = self.tonePlaying
                        self.onReading?(silent ? nil : output.pitch?.frequencyHz, silent ? 0 : output.pitch?.confidence ?? 0, output.level)
                    }
                }
            }
            tapInstalled = true
            try attachOutput(keepState: wasOutputting)
            engine.prepare(); try engine.start()
            running = true; error = nil
        } catch { suspend(); self.error = String(localized: "Could not start audio: \(error.localizedDescription)") }
    }

    #if DEBUG
    /// Screenshot and UI-test mode (TIMBRE_DEMO_PITCH=1): a plucked string drifting from
    /// 14 cents flat into tune, re-plucked every six seconds. No microphone involved.
    /// `target` nil is silence; `cued` plays the target in tune at once (a note played on time).
    func startDemo(target: @escaping () -> Double?, cued: @escaping () -> Bool = { false }) {
        guard !running else { return }
        generation += 1
        let token = generation
        running = true; error = nil
        let start = ProcessInfo.processInfo.systemUptime
        Task { @MainActor [weak self] in
            while let self, self.generation == token, self.running {
                let t = ProcessInfo.processInfo.systemUptime - start
                let cycle = t.truncatingRemainder(dividingBy: 6)
                if let hz = target() {
                    let onCue = cued()
                    let cents = onCue || cycle >= 4.2 ? 0.3 * sin(t * 5) : -14 * (1 - cycle / 4.2) + 0.4 * sin(t * 9)
                    let level = onCue ? -24 : -22 - 18 * min(1, cycle / 6)
                    self.onReading?(hz * pow(2, cents / 1200), 0.95, level)
                } else {
                    self.onReading?(nil, 0, -120)
                }
                try? await Task.sleep(for: .milliseconds(16))
            }
        }
    }
    #endif

    /// Stops listening; output (metronome, drone) continues.
    func stopCapture() {
        guard running || tapInstalled else { return }
        generation += 1
        toneTask?.cancel(); toneTask = nil; resumeCaptureAfterTone = false
        if tapInstalled { engine.inputNode.removeTap(onBus: 0); tapInstalled = false }
        running = false
        onReading?(nil, 0, -120)
        if !outputActive { shutdown() }
    }

    func stop() { suspend() }

    private func suspend() {
        toneTask?.cancel(); toneTask = nil; resumeCaptureAfterTone = false
        pendingTone = nil
        generation += 1
        if tapInstalled { engine.inputNode.removeTap(onBus: 0); tapInstalled = false }
        renderer.stop()
        running = false; metronomeRunning = false; tonePlaying = false; droneRunning = false
        bandRequest = nil; bandPlaying = false
        outroTask?.cancel(); outroTask = nil; bandOutro = false
        onReading?(nil, 0, -120)
        shutdown()
    }

    private func shutdown() {
        engine.stop()
        if let source { engine.disconnectNodeOutput(source); engine.detach(source); self.source = nil }
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    private func configureSession() throws {
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playAndRecord, mode: .measurement, options: [.defaultToSpeaker, .allowBluetoothA2DP, .mixWithOthers])
        try session.setPreferredSampleRate(48000)
        try session.setPreferredIOBufferDuration(0.005)
        try session.setActive(true)
        heardLatency = currentHeardLatency()
    }

    private func attachOutput(keepState: Bool = false) throws {
        if let source { engine.disconnectNodeOutput(source); engine.detach(source); self.source = nil }
        let rate = engine.outputNode.inputFormat(forBus: 0).sampleRate
        guard rate > 0, let format = AVAudioFormat(standardFormatWithSampleRate: rate, channels: 1) else { throw AudioFailure.noOutput }
        if !renderer.setSampleRate(rate, keepState: keepState) { bandPlaying = false }
        let source = AVAudioSourceNode { [renderer] _, timestamp, count, audio in
            renderer.render(frameCount: Int(count), audio: audio, timestamp: timestamp)
            return noErr
        }
        engine.attach(source); engine.connect(source, to: engine.mainMixerNode, format: format)
        self.source = source
    }

    private func ensureOutput() throws {
        if !engine.isRunning { try configureSession(); try attachOutput(); engine.prepare(); try engine.start() }
    }

    /// The tuner's reference (and other single held notes): the instrument's own voice at exactly `hz`, a string
    /// plucked again every one to two seconds or a bowed, blown or sung note held without vibrato, so it can be
    /// tuned to by ear. `voice` defaults to the open course's instrument, else the selected one. Capture pauses
    /// while it sounds and resumes after; `durationMs` 0 sounds until `stopTone`.
    func playTone(_ hz: Double, durationMs: Int = 2000, voice: InstrumentVoice? = nil) {
        guard UIApplication.shared.applicationState == .active, hz.isFinite, hz > 0 else { return }
        let resume = running || resumeCaptureAfterTone
        toneTask?.cancel(); toneTask = nil
        if running { stopCapture() }
        do {
            try ensureOutput()
            tonePlaying = true; resumeCaptureAfterTone = resume
            let request = ToneRequest(frequencies: [hz], kind: .reference(durationMs: max(0, durationMs)),
                                      voice: voice ?? currentVoice, sampleRate: renderer.rate)
            sound(request, reference: true)
        } catch { suspend(); self.error = String(localized: "Could not play the reference tone: \(error.localizedDescription)") }
    }

    /// "Hear it", chord buttons, listen steps and ear training: notes in turn, or together (strummed low to high
    /// on plucked voices), in `voice`, else the open course's instrument, else the selected one. Capture pauses
    /// while they sound.
    func playTones(_ frequencies: [Double], together: Bool, noteMs: Int = 900, gapMs: Int = 150, voice: InstrumentVoice? = nil) {
        guard UIApplication.shared.applicationState == .active, !frequencies.isEmpty else { return }
        if running { stopCapture() }
        do {
            try ensureOutput()
            let kind = ToneRequest.Kind.phrase(together: together, noteMs: together ? noteMs + 400 : noteMs, gapMs: gapMs)
            let request = ToneRequest(frequencies: frequencies, kind: kind, voice: voice ?? currentVoice, sampleRate: renderer.rate)
            tonePlaying = true
            toneTask?.cancel(); toneTask = nil
            sound(request, reference: false)
        } catch { self.error = String(localized: "Could not play tones: \(error.localizedDescription)") }
    }

    private var currentVoice: InstrumentVoice { courseVoice ?? instrumentVoice() }

    /// Plays a request from the cache, or renders it on the tone queue first; a newer request or a stop
    /// in the meantime wins.
    private func sound(_ request: ToneRequest, reference: Bool) {
        toneToken += 1
        let token = toneToken
        let pending = PendingTone(request: request, token: token, reference: reference)
        pendingTone = pending
        if let clip = toneCache[request] {
            remember(clip, for: request)
            begin(clip, pending)
            return
        }
        toneQueue.async { [weak self] in
            let clip = ToneSynth.render(request)
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.remember(clip, for: request)
                guard let pending = self.pendingTone, pending.token == token else { return }
                self.begin(clip, pending)
            }
        }
    }

    /// Starts a rendered tone (the one sounding fades under it) and times its end.
    private func begin(_ clip: ToneClip, _ pending: PendingTone) {
        pendingTone = nil
        guard tonePlaying else { return }
        guard renderer.setClip(clip) else {
            // The output's rate changed while it rendered: once more at the new rate.
            let rate = renderer.rate
            guard rate != pending.request.sampleRate else { tonePlaying = false; return }
            sound(pending.request.at(sampleRate: rate), reference: pending.reference)
            return
        }
        let ms = pending.request.durationMs
        guard ms > 0 else { return }
        let reference = pending.reference
        toneTask?.cancel()
        toneTask = Task { [weak self] in
            do { try await Task.sleep(for: .milliseconds(reference ? ms : ms + 60)) } catch { return }
            guard !Task.isCancelled, let self else { return }
            if reference {
                self.stopTone()
            } else {
                self.tonePlaying = false
                if !self.running && !self.outputActive { self.shutdown() }
            }
        }
    }

    /// Keeps the last few renderings, most recent last.
    private func remember(_ clip: ToneClip, for request: ToneRequest) {
        toneRecency.removeAll { $0 == request }
        toneRecency.append(request)
        toneCache[request] = clip
        while toneRecency.count > 16 { toneCache[toneRecency.removeFirst()] = nil }
    }

    func stopTone() {
        toneTask?.cancel(); toneTask = nil
        pendingTone = nil
        renderer.stopClip(); tonePlaying = false
        let resume = resumeCaptureAfterTone
        resumeCaptureAfterTone = false
        if resume {
            let token = generation
            Task { guard generation == token else { return }; await start(minimum: minimum, maximum: maximum, micSensitivity: sensitivity, analysisWindowOverride: windowOverride, confidenceThreshold: confidenceThreshold) }
        } else if !running && !outputActive { shutdown() }
    }

    func setMetronome(bpm: Int, beats: Int, subdivision: Int, accents: Bool, beatLevels: [Int]? = nil, sound: MetronomeRenderer.Sound = .click) {
        do {
            try ensureOutput()
            renderer.setMetronome(bpm: bpm, beats: beats, subdivision: subdivision, accents: accents, beatLevels: beatLevels, sound: sound)
            metronomeRunning = bpm > 0
        } catch { suspend(); self.error = String(localized: "Could not start the metronome: \(error.localizedDescription)") }
    }

    /// Stops the click; a lesson band under it fades out with it (a final chord already ringing finishes).
    func stopMetronome() {
        renderer.setMetronome(bpm: 0, beats: 4, subdivision: 1, accents: true, beatLevels: nil, sound: .click)
        metronomeRunning = false
        bandRequest = nil; bandPlaying = false
        if !running && !outputActive { shutdown() }
    }

    /// When the running metronome's first click reached the ears, on the CACurrentMediaTime clock:
    /// the render host time of its first frame plus how late this route is heard (its tap-along
    /// calibration, else the output latency). Engine restarts (the microphone starting) and Bluetooth
    /// delay are included; nil until the first buffer plays.
    func metronomeOrigin() -> TimeInterval? {
        guard let anchor = metronomeRenderOrigin() else { return nil }
        return anchor + heardLatency
    }

    /// When the running metronome's first click left the engine (no output latency added), on the
    /// CACurrentMediaTime clock; the tap-along calibration measures from here.
    func metronomeRenderOrigin() -> TimeInterval? {
        guard metronomeRunning else { return nil }
        return renderer.clock.read()
    }

    // MARK: Latency calibration

    /// Kinds of output route that keep their own calibration.
    enum OutputRoute: String, CaseIterable {
        case speaker, wired, bluetooth
    }

    nonisolated static func currentRoute() -> OutputRoute {
        let ports = AVAudioSession.sharedInstance().currentRoute.outputs.map(\.portType)
        let wireless: Set<AVAudioSession.Port> = [.bluetoothA2DP, .bluetoothLE, .bluetoothHFP, .airPlay, .carAudio]
        let wired: Set<AVAudioSession.Port> = [.headphones, .usbAudio, .lineOut, .HDMI]
        if ports.contains(where: { wireless.contains($0) }) { return .bluetooth }
        if ports.contains(where: { wired.contains($0) }) { return .wired }
        return .speaker
    }

    private nonisolated static func calibrationKey(_ route: OutputRoute) -> String { "latency.calibrated.\(route.rawValue)" }

    /// The saved tap-along delay for a kind of route, in seconds.
    nonisolated static func calibratedLatency(for route: OutputRoute) -> Double? {
        guard let value = UserDefaults.standard.object(forKey: calibrationKey(route)) as? Double, value.isFinite else { return nil }
        return min(LatencyCalibration.range.upperBound, max(LatencyCalibration.range.lowerBound, value))
    }

    /// Saves a tap-along result for a kind of route (nil forgets it); lessons time from it at once.
    func saveCalibration(_ seconds: Double?, for route: OutputRoute) {
        if let seconds, seconds.isFinite {
            UserDefaults.standard.set(min(LatencyCalibration.range.upperBound, max(LatencyCalibration.range.lowerBound, seconds)), forKey: Self.calibrationKey(route))
        } else {
            UserDefaults.standard.removeObject(forKey: Self.calibrationKey(route))
        }
        heardLatency = currentHeardLatency()
    }

    private func currentHeardLatency() -> Double {
        Self.calibratedLatency(for: Self.currentRoute()) ?? AVAudioSession.sharedInstance().outputLatency
    }

    /// A step clock started at `start` (its tap on Start), moved toward the audio clock by at most
    /// 25 ms per call, so notes glide rather than jump: nil when there is nothing to correct (no click
    /// yet, a shift under 3 ms, or an implausible one).
    func heardStart(near start: TimeInterval) -> TimeInterval? {
        guard let origin = metronomeOrigin() else { return nil }
        let shift = origin - start
        guard abs(shift) > 0.003, abs(shift) < 0.75 else { return nil }
        return start + min(0.025, max(-0.025, shift))
    }

    // MARK: Lesson band

    /// Headphones of any kind carry the output: wired (3.5 mm/Lightning, or USB-C EarPods, which report
    /// as USB audio), Bluetooth A2DP or LE (AirPods). The speaker, car kits (HFP), AirPlay and line out
    /// don't count: there the band would reach the microphone.
    nonisolated static func headphonesConnected() -> Bool {
        let ports: Set<AVAudioSession.Port> = [.headphones, .bluetoothA2DP, .bluetoothLE, .usbAudio]
        return AVAudioSession.sharedInstance().currentRoute.outputs.contains { ports.contains($0.portType) }
    }

    /// Re-reads the output route (headphones, latency) and lets the band follow it.
    func refreshRoute() {
        heardLatency = currentHeardLatency()
        let kind = Self.currentRoute()
        if kind != route { route = kind }
        let connected = Self.headphonesConnected()
        if connected != headphones { headphones = connected }
        refreshBand()
    }

    /// The player's band switch (and the app's sound effects switch) allow a band.
    private var bandAllowed: Bool {
        (UserDefaults.standard.object(forKey: BandArrangement.preferenceKey) as? Bool ?? true) && SoundFX.shared.enabled
    }

    /// A step that may play with a band: renders it ahead of time, off the main thread, when it could be
    /// heard now (headphones, band on), or as soon as headphones connect.
    func prepareBand(_ arrangement: BandArrangement?) {
        bandPrepared = arrangement
        refreshBand()
    }

    /// The step's band, from metronome bar `firstBar` (1: after a one-bar count-in). Call after
    /// `setMetronome`; it plays only on headphones and joins at the next downbeat when they connect.
    func playBand(_ arrangement: BandArrangement?, firstBar: Int = 1) {
        bandRequest = arrangement.map { BandRequest(arrangement: $0, firstBar: firstBar) }
        if bandPlaying { renderer.stopBand(); bandPlaying = false }
        if let arrangement { bandPrepared = arrangement }
        refreshBand()
    }

    /// Ends the step's band and metronome: a final chord when the take went well, else a short fade.
    func finishBand(celebrate: Bool) {
        if celebrate && bandPlaying {
            renderer.finishBand()
            bandOutro = true
            outroTask?.cancel()
            outroTask = Task { [weak self] in
                do { try await Task.sleep(for: .milliseconds(1800)) } catch { return }
                guard let self else { return }
                self.bandOutro = false
                if !self.running && !self.outputActive { self.shutdown() }
            }
        }
        stopMetronome()
    }

    /// Silences the band now (the step left, the app went to the background); the click is untouched.
    /// Also forgets the prepared arrangement, so headphones connecting elsewhere render nothing.
    func stopBand() {
        let ringing = bandOutro
        bandRequest = nil; bandPrepared = nil; bandPlaying = false
        outroTask?.cancel(); outroTask = nil; bandOutro = false
        renderer.stopBand()
        if ringing { shutdownSoonIfIdle() }
    }

    /// Brings the band in line with the switch, the route and the metronome. Headphones out (or the
    /// switch off) fades it at once; in, it joins at the next downbeat, rendering first if needed.
    /// The step's request stays, so the band comes back when the headphones do.
    func refreshBand() {
        let audible = bandAllowed && headphones && UIApplication.shared.applicationState != .background
        guard audible else {
            guard bandPlaying || bandOutro else { return }
            let ringing = bandOutro
            renderer.stopBand(); bandPlaying = false
            outroTask?.cancel(); outroTask = nil; bandOutro = false
            if ringing { shutdownSoonIfIdle() }
            return
        }
        guard let arrangement = bandRequest?.arrangement ?? bandPrepared, let track = bandTrack(for: arrangement) else { return }
        guard let request = bandRequest, metronomeRunning, !bandPlaying else { return }
        bandPlaying = renderer.setBand(track, firstBar: request.firstBar)
    }

    /// After a band fade, lets the engine go if nothing else plays or listens.
    private func shutdownSoonIfIdle() {
        Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(120))
            guard let self, !self.running, !self.outputActive else { return }
            self.shutdown()
        }
    }

    /// The rendered band at the output's sample rate: from the cache, or nil while it renders on a
    /// background queue (`refreshBand` runs again when it is ready).
    private func bandTrack(for arrangement: BandArrangement) -> BandTrack? {
        let rate = renderer.rate
        let key = BandRenderKey(arrangement: arrangement, rate: rate)
        if let track = bandCache[key] { return track }
        guard !bandRendering.contains(key) else { return nil }
        bandRendering.insert(key)
        bandQueue.async { [weak self] in
            let track = BandSynth.render(arrangement, sampleRate: rate)
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.bandRendering.remove(key)
                // A couple of steps' worth (normal and slow tempo); the playing one lives on in its player.
                if self.bandCache.count >= 2 { self.bandCache.removeAll() }
                self.bandCache[key] = track
                self.refreshBand()
            }
        }
        return nil
    }

    func setDrone(tonic: Double, voice: DroneRenderer.Voice, fifth: Bool) {
        do {
            try ensureOutput()
            renderer.setDrone(tonic: tonic, voice: voice, fifth: fifth)
            droneFifth = fifth
            droneRunning = true
        } catch { self.error = String(localized: "Could not start the drone: \(error.localizedDescription)") }
    }

    /// The drone's first string as it was last set: Pa, a fifth below Sa (true), or Ma, a fourth (false).
    private(set) var droneFifth = true

    /// When the running drone's first sample reached the ears, on the CACurrentMediaTime clock: the render host
    /// time of its first frame plus how late this route is heard. Its plucks fall on a fixed grid from there
    /// (`DroneCycle`), so the tanpura on screen plucks its strings with the sound, engine restarts (the
    /// microphone starting) included. Nil until the first buffer plays.
    func droneOrigin() -> TimeInterval? {
        guard droneRunning, let anchor = renderer.droneClock.read() else { return nil }
        return anchor + heardLatency
    }

    func stopDrone() {
        renderer.stopDrone()
        droneRunning = false
        Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(320))
            guard let self, !self.running, !self.outputActive else { return }
            self.shutdown()
        }
    }

    private enum AudioFailure: LocalizedError {
        case noInput, noOutput
        var errorDescription: String? {
            self == .noInput ? String(localized: "No microphone input is available.") : String(localized: "No audio output is available.")
        }
    }
}

/// One worker per capture generation; queued callbacks can never reconfigure a newer detector.
private final class PitchWorker: @unchecked Sendable {
    private let lock = NSLock()
    private var pending = 0, epoch = 0
    private var consumedEpoch = 0, sinceReading = 0
    private let detector: YinPitchDetector
    private var ring: [Float]
    private var head = 0, filled = 0
    private let window: Int, hop: Int
    private let gain: Float
    private var frame: [Float]
    init(rate: Double, minimum: Double, maximum: Double, window: Int, gain: Double) {
        detector = YinPitchDetector(sampleRate: rate, minFrequency: minimum, maxFrequency: maximum)
        self.window = window
        hop = max(1, Int((rate / 60).rounded()))
        self.gain = Float(gain)
        ring = .init(repeating: 0, count: window)
        frame = .init(repeating: 0, count: window)
    }
    func reserve() -> Int? {
        lock.lock(); defer { lock.unlock() }
        guard pending < 6 else { epoch += 1; return nil }
        pending += 1; return epoch
    }
    func release() { lock.lock(); pending -= 1; lock.unlock() }
    func consume(_ chunk: [Float], epoch: Int) -> (pitch: DetectedPitch?, level: Double)? {
        if consumedEpoch != epoch { head = 0; filled = 0; sinceReading = 0; consumedEpoch = epoch }
        for sample in chunk {
            ring[head] = sample * gain
            head = (head + 1) % window
        }
        filled = min(window, filled + chunk.count)
        sinceReading += chunk.count
        guard filled >= window, sinceReading >= hop else { return nil }
        sinceReading %= hop
        // Unroll the ring into chronological order.
        let tail = window - head
        frame.withUnsafeMutableBufferPointer { out in
            ring.withUnsafeBufferPointer { src in
                out.baseAddress!.update(from: src.baseAddress! + head, count: tail)
                (out.baseAddress! + tail).update(from: src.baseAddress!, count: head)
            }
        }
        return (detector.detect(frame), DspMath.rmsDbfs(frame))
    }
}

/// The step's band and the metronome bar it starts on.
private struct BandRequest { let arrangement: BandArrangement; let firstBar: Int }
/// A tone waiting for its rendering; `reference` tones resume capture when they end.
private struct PendingTone { let request: ToneRequest; let token: Int; let reference: Bool }
/// A rendering is only valid at the sample rate it was made for.
private struct BandRenderKey: Hashable { let arrangement: BandArrangement; let rate: Int }

/// One Double handed from the render thread to the main thread. The render thread only ever
/// `try`s the lock (it skips a publish rather than wait), so it can never block on the UI.
private final class ClockSlot: @unchecked Sendable {
    private let lock = NSLock()
    private var value: Double?
    func publish(_ next: Double) { guard lock.try() else { return }; value = next; lock.unlock() }
    func set(_ next: Double?) { lock.lock(); value = next; lock.unlock() }
    func read() -> Double? { lock.lock(); defer { lock.unlock() }; return value }
}

/// Controls synchronize once per PCM buffer. Core renderers own sample-clock phase and envelopes.
private final class OutputRenderer: @unchecked Sendable {
    private let lock = NSLock()
    private var sampleRate = 48000
    /// The tone sounding (a rendered instrument clip) and the one before it, fading out underneath.
    private var clip: ToneClipPlayer?
    private var fadingClip: ToneClipPlayer?
    private var metronome: MetronomeRenderer?
    private var drone: DroneRenderer?
    /// The lesson band; it starts bars on the metronome's downbeats.
    private var band: BandPlayer?
    /// Downbeats since the metronome started (0 = its first click, the count-in bar).
    private var bar = -1
    /// Frames the current metronome has played: with the buffer's host time, where its first click sits.
    private var metronomeFrames: Int64 = 0
    /// Host-clock seconds of the current metronome's first frame (render time, before output latency).
    let clock = ClockSlot()
    /// Frames the current drone has played, and host-clock seconds of its first frame (render time), so the
    /// screen can follow its pluck cycle.
    private var droneFrames: Int64 = 0
    let droneClock = ClockSlot()
    private let secondsPerTick: Double

    init() {
        var info = mach_timebase_info_data_t()
        mach_timebase_info(&info)
        secondsPerTick = Double(info.numer) / Double(max(1, info.denom)) / 1_000_000_000
    }

    var rate: Int { lock.lock(); defer { lock.unlock() }; return sampleRate }

    /// Returns whether playing state was kept (same rate, `keepState`); otherwise everything stopped.
    @discardableResult func setSampleRate(_ rate: Double, keepState: Bool) -> Bool {
        lock.lock(); defer { lock.unlock() }
        let next = max(40, Int(rate.rounded()))
        let kept = keepState && next == sampleRate
        if !kept { clip = nil; fadingClip = nil; metronome = nil; drone = nil; band = nil; clock.set(nil); droneClock.set(nil) }
        sampleRate = next
        return kept
    }
    /// Plays a rendered tone; the one sounding is damped under it (25 ms) rather than cut. False when the
    /// clip was rendered for another output rate.
    func setClip(_ next: ToneClip) -> Bool {
        lock.lock()
        guard next.sampleRate == sampleRate else { lock.unlock(); return false }
        let released = fadingClip
        clip?.stop(fadeFrames: sampleRate / 40)
        fadingClip = clip
        clip = ToneClipPlayer(clip: next)
        lock.unlock()
        // The player let go (and maybe its clip) is freed here, not under the render lock.
        withExtendedLifetime(released) {}
        return true
    }
    /// Damps the tone sounding over 30 ms, like a hand on the strings.
    func stopClip() { lock.lock(); clip?.stop(fadeFrames: sampleRate * 3 / 100); lock.unlock() }
    func setMetronome(bpm: Int, beats: Int, subdivision: Int, accents: Bool, beatLevels: [Int]?, sound: MetronomeRenderer.Sound) {
        lock.lock(); defer { lock.unlock() }
        guard bpm > 0 else {
            // The band fades with the click; a final chord already ringing is left to finish.
            metronome = nil; band?.stop(force: false); clock.set(nil)
            return
        }
        let pattern = MetronomePattern(bpm: min(300, max(30, bpm)), beatsPerBar: min(12, max(1, beats)), subdivision: min(4, max(1, subdivision)))
        let renderer: MetronomeRenderer
        if let metronome {
            renderer = metronome
        } else {
            // A fresh count from its first click; an older band can't follow it.
            renderer = MetronomeRenderer(sampleRate: sampleRate, initial: pattern)
            bar = -1; metronomeFrames = 0; band?.stop(); clock.set(nil)
        }
        renderer.update(pattern)
        renderer.accents = accents; renderer.beatLevels = beatLevels; renderer.sound = sound
        metronome = renderer
    }
    /// Installs a band under the running metronome; it starts at the next downbeat. False when the
    /// rendering's sample rate doesn't match the output (or no metronome runs).
    func setBand(_ track: BandTrack, firstBar: Int) -> Bool {
        lock.lock()
        guard track.sampleRate == sampleRate, metronome != nil else { lock.unlock(); return false }
        let previous = band
        band = BandPlayer(track: track, firstBar: firstBar)
        lock.unlock()
        // The old player (and maybe its buffer) is released here, not under the render lock.
        withExtendedLifetime(previous) {}
        return true
    }
    func stopBand() { lock.lock(); band?.stop(); lock.unlock() }
    func finishBand() { lock.lock(); band?.finish(); lock.unlock() }
    func setDrone(tonic: Double, voice: DroneRenderer.Voice, fifth: Bool) {
        lock.lock(); defer { lock.unlock() }
        drone = DroneRenderer(tonic: tonic, fifth: fifth, voice: voice, sampleRate: sampleRate)
        droneFrames = 0; droneClock.set(nil)
    }
    func stopDrone() { lock.lock(); drone?.stop(); lock.unlock() }
    func stop() { lock.lock(); clip = nil; fadingClip = nil; metronome = nil; drone = nil; band = nil; clock.set(nil); droneClock.set(nil); lock.unlock() }
    func render(frameCount: Int, audio: UnsafeMutablePointer<AudioBufferList>, timestamp: UnsafePointer<AudioTimeStamp>) {
        let buffers = UnsafeMutableAudioBufferListPointer(audio)
        guard lock.try() else {
            for buffer in buffers { if let data = buffer.mData { memset(data, 0, Int(buffer.mDataByteSize)) } }
            return
        }
        defer { lock.unlock() }
        if metronome != nil {
            // This buffer's host time minus what the metronome already played = its first frame, so the
            // step clock can follow the audio (engine restarts and dropped buffers included).
            let stamp = timestamp.pointee
            let host = stamp.mFlags.contains(.hostTimeValid) ? stamp.mHostTime : mach_absolute_time()
            clock.publish(Double(host) * secondsPerTick - Double(metronomeFrames) / Double(sampleRate))
        }
        if drone != nil {
            // The drone's first frame on the host clock, as for the metronome; its plucks sit on a fixed grid from there.
            let stamp = timestamp.pointee
            let host = stamp.mFlags.contains(.hostTimeValid) ? stamp.mHostTime : mach_absolute_time()
            droneClock.publish(Double(host) * secondsPerTick - Double(droneFrames) / Double(sampleRate))
            droneFrames += Int64(frameCount)
        }
        for frame in 0..<frameCount {
            var value = (clip?.nextSample() ?? 0) + (fadingClip?.nextSample() ?? 0) + (drone?.nextSample() ?? 0)
            if let metronome {
                let click = metronome.nextSample()
                metronomeFrames += 1
                // Bars of the band start on the metronome's own downbeats: same sample, same clock.
                if let pulse = metronome.lastPulse, pulse.beat == 0, pulse.subdivision == 0 {
                    bar += 1
                    band?.downbeat(bar)
                }
                if let band {
                    // Under the band (headphones only) the click steps back; the count-in stays full.
                    value += band.nextSample() + click * (band.isSounding ? 0.45 : 1)
                } else {
                    value += click
                }
            } else if let band {
                value += band.nextSample()
            }
            for buffer in buffers { buffer.mData?.assumingMemoryBound(to: Float.self)[frame] = max(-1, min(1, value)) }
        }
    }
}

/// A thread-safe slot for one raw-sample consumer.
final class FrameSink: @unchecked Sendable {
    private let lock = NSLock()
    private var handler: (([Float], Double) -> Void)?
    func set(_ handler: (([Float], Double) -> Void)?) { lock.lock(); self.handler = handler; lock.unlock() }
    func send(_ samples: [Float], rate: Double) {
        lock.lock(); let handler = self.handler; lock.unlock()
        handler?(samples, rate)
    }
}
