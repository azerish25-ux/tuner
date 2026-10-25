import AVFoundation
import Combine
import UIKit
import TimbreCore

/// The lessons' audio engine: the microphone, tones, the metronome, the drone and the band. Its session goes through
/// `AudioSessionOwner`, shared with `RecordingPlayer`. Pitch analysis runs on a bounded serial queue at ~60 Hz;
/// readings go straight to `onReading` so high-rate values never invalidate unrelated views.
///
/// It keeps going through what happens to a phone's audio: headphones in or out (the engine is rebuilt and what was
/// playing plays on), a call, Siri or an alarm (the tool's click, the drone and the microphone come back when the
/// interruption ends with "should resume"), and a media services reset.
@MainActor
final class AudioService: ObservableObject {
    @Published private(set) var running = false
    @Published private(set) var error: String?
    @Published private(set) var permissionDenied = false
    @Published private(set) var metronomeRunning = false
    /// The Metronome tool started the running click (`setMetronome(…, tool: true)`): it keeps its phase through
    /// tempo and meter changes and plays on in the background. Any other click (a lesson take, the tap-along check,
    /// a song preview) counts in fresh from its first beat and stops when the app leaves the foreground.
    @Published private(set) var metronomeOwnedByTool = false
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
    var courseVoice: InstrumentVoice? {
        didSet { if let courseVoice { warmSamples(courseVoice) } }
    }
    /// Voices whose recorded zones have been decoded ahead of their first note (`warmSamples`).
    private var warmedVoices: Set<InstrumentVoice> = []
    /// Tones render here (a few milliseconds), never on the main thread or in the audio callback.
    private let toneQueue = DispatchQueue(label: "com.timbre.tones", qos: .userInitiated)
    /// Recent renderings: a lesson replays the same chord, the tuner the same string.
    private var toneCache: [ToneRequest: ToneClip] = [:]
    private var toneRecency: [ToneRequest] = []
    /// The tone asked for last, until it starts; a newer one (or a stop) supersedes it.
    private var pendingTone: PendingTone?
    private var toneToken = 0
    /// The running click's settings, so it can be brought back after an interruption.
    private var metronomeSettings: MetronomeSettings?
    /// The running drone's settings, likewise.
    private var droneSettings: DroneSettings?
    /// What was listening and playing when the current interruption began.
    private var interrupted: Interrupted?

    init() {
        observers.append(NotificationCenter.default.addObserver(forName: AVAudioSession.interruptionNotification, object: nil, queue: .main) { [weak self] notification in
            let info = notification.userInfo
            let type = (info?[AVAudioSessionInterruptionTypeKey] as? UInt).flatMap(AVAudioSession.InterruptionType.init(rawValue:))
            let options = AVAudioSession.InterruptionOptions(rawValue: info?[AVAudioSessionInterruptionOptionKey] as? UInt ?? 0)
            Task { @MainActor in
                guard let self, let type else { return }
                switch type {
                case .began: self.interruptionBegan()
                case .ended: self.interruptionEnded(resume: options.contains(.shouldResume))
                @unknown default: break
                }
            }
        })
        observers.append(NotificationCenter.default.addObserver(forName: .AVAudioEngineConfigurationChange, object: nil, queue: .main) { [weak self] notification in
            // Every engine posts this one (the recording player's too): only this engine's change counts here.
            guard let engine = notification.object as? AVAudioEngine else { return }
            let changed = ObjectIdentifier(engine)
            Task { @MainActor in
                guard let self, ObjectIdentifier(self.engine) == changed else { return }
                self.engineConfigurationChanged()
            }
        })
        observers.append(NotificationCenter.default.addObserver(forName: UIApplication.didEnterBackgroundNotification, object: nil, queue: .main) { [weak self] _ in
            // The microphone stops in the background, and so do the lesson band and a lesson's click (its take can't
            // go on unseen, and nothing would stop it from the pocket). The Metronome tool's click and the drone play on.
            Task { @MainActor in
                guard let self else { return }
                self.stopBand()
                if self.metronomeRunning && !self.metronomeOwnedByTool { self.stopMetronome() }
                self.stopCapture()
            }
        })
        observers.append(NotificationCenter.default.addObserver(forName: UIApplication.didReceiveMemoryWarningNotification, object: nil, queue: .main) { [weak self] _ in
            // Rendered bands are a few MB each; the one playing stays alive with its player (tones likewise). Decoded
            // instrument recordings go too (a note decodes its zone again when it next plays).
            SampleLibrary.shared?.purge()
            Task { @MainActor in
                self?.bandCache.removeAll(); self?.toneCache.removeAll(); self?.toneRecency.removeAll()
                self?.warmedVoices.removeAll()
            }
        })
        observers.append(NotificationCenter.default.addObserver(forName: AVAudioSession.routeChangeNotification, object: nil, queue: .main) { [weak self] notification in
            // Headphones in or out: the band follows at once (out: it fades before it can reach the mic).
            Task { @MainActor in self?.refreshRoute() }
            let reason = (notification.userInfo?[AVAudioSessionRouteChangeReasonKey] as? UInt).flatMap(AVAudioSession.RouteChangeReason.init(rawValue:))
            guard reason != nil, reason != .categoryChange, reason != .unknown else { return }
            Task { @MainActor in
                guard let self, self.running else { return }
                let capture = self.captureSettings
                self.stopCapture()
                guard UIApplication.shared.applicationState == .active else { return }
                await self.listen(capture)
            }
        })
        observers.append(NotificationCenter.default.addObserver(forName: AVAudioSession.mediaServicesWereResetNotification, object: nil, queue: .main) { [weak self] _ in
            // The audio server restarted: a new engine and session, and what was going goes on.
            Task { @MainActor in
                guard let self else { return }
                let snapshot = self.snapshot()
                self.suspend(); self.engine = AVAudioEngine()
                self.restore(snapshot)
            }
        })
        // The band knows a song's style from the curriculum (`BandStyleIndex`): it reads it once, a few seconds after
        // launch on the band's own queue, so the first band to render never waits on it.
        bandQueue.asyncAfter(deadline: .now() + 4) { _ = BandStyleIndex.shared }
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
        // The tuner's reference and "Hear it" will want this instrument's recordings: decode them while it listens.
        warmSamples(currentVoice)
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
            // What plays now (the click, the drone, the band) carries on through the restart. Read from this service's
            // own state, not `engine.isRunning`: a configuration change stops the engine with all of it still playing.
            let keepPlaying = outputActive
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
            try attachOutput(keepPlaying: keepPlaying)
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
        running = false; metronomeRunning = false; metronomeOwnedByTool = false; tonePlaying = false; droneRunning = false
        metronomeSettings = nil; droneSettings = nil
        bandRequest = nil; bandPlaying = false
        outroTask?.cancel(); outroTask = nil; bandOutro = false
        onReading?(nil, 0, -120)
        shutdown()
    }

    /// Stops the engine and lets the session go (deactivated off the main thread once nothing else holds it).
    private func shutdown() {
        engine.stop()
        if let source { engine.disconnectNodeOutput(source); engine.detach(source); self.source = nil }
        AudioSessionOwner.shared.release(.lessons)
    }

    private func configureSession() throws {
        try AudioSessionOwner.shared.activate(.lessons)
        heardLatency = currentHeardLatency()
    }

    /// Connects the renderer to the engine's mixer. With `keepPlaying`, what sounds now (the click, the drone, the
    /// band, a tone) carries on in phase at the renderer's own sample rate, which the mixer converts to the hardware's
    /// (headphones can bring another rate); otherwise the renderer starts clean at the hardware rate.
    private func attachOutput(keepPlaying: Bool) throws {
        if let source { engine.disconnectNodeOutput(source); engine.detach(source); self.source = nil }
        let hardwareRate = engine.outputNode.inputFormat(forBus: 0).sampleRate
        guard hardwareRate > 0 else { throw AudioFailure.noOutput }
        if !keepPlaying {
            renderer.setSampleRate(hardwareRate, keepState: false)
            bandPlaying = false
        }
        guard let format = AVAudioFormat(standardFormatWithSampleRate: Double(renderer.rate), channels: 1) else { throw AudioFailure.noOutput }
        let source = AVAudioSourceNode { [renderer] _, timestamp, count, audio in
            renderer.render(frameCount: Int(count), audio: audio, timestamp: timestamp)
            return noErr
        }
        engine.attach(source); engine.connect(source, to: engine.mainMixerNode, format: format)
        self.source = source
    }

    /// Starts the engine for output when it isn't running; anything still meant to be playing plays on.
    private func ensureOutput() throws {
        if !engine.isRunning { try configureSession(); try attachOutput(keepPlaying: outputActive); engine.prepare(); try engine.start() }
    }

    // MARK: Configuration changes and interruptions

    /// How the microphone was started, to start it again the same way.
    private var captureSettings: CaptureSettings {
        CaptureSettings(minimum: minimum, maximum: maximum, sensitivity: sensitivity, window: windowOverride, confidence: confidenceThreshold)
    }

    private func listen(_ capture: CaptureSettings) async {
        await start(minimum: capture.minimum, maximum: capture.maximum, micSensitivity: capture.sensitivity,
                    analysisWindowOverride: capture.window, confidenceThreshold: capture.confidence)
    }

    /// The hardware format changed under the engine (headphones in or out, a call taking the route) and the engine
    /// stopped itself. The microphone listens again with a tap in the new input format, and the click, the drone, the
    /// band or a tone play on from where they were. Taken from this service's own state before anything is stopped.
    private func engineConfigurationChanged() {
        guard !engine.isRunning else { return }
        let capture = running ? captureSettings : nil
        if capture != nil { stopCapture() }
        if let capture, UIApplication.shared.applicationState == .active {
            // `start` brings back the output with the microphone.
            Task { await self.listen(capture) }
        } else if outputActive {
            restartOutput()
        }
    }

    private func restartOutput() {
        do {
            try configureSession()
            try attachOutput(keepPlaying: true)
            engine.prepare(); try engine.start()
        } catch {
            suspend(); self.error = String(localized: "Could not start audio: \(error.localizedDescription)")
        }
    }

    /// What is listening and playing now that can come back later: the microphone, the Metronome tool's click and
    /// the drone. A lesson's click and band never come back (their take can't pick up in the middle).
    private func snapshot() -> Interrupted {
        Interrupted(capture: running ? captureSettings : nil,
                    metronome: metronomeRunning && metronomeOwnedByTool ? metronomeSettings : nil,
                    drone: droneRunning ? droneSettings : nil)
    }

    /// Brings back what `snapshot` saw, unless it is already going again; the microphone only with the app in front.
    private func restore(_ snapshot: Interrupted) {
        if let drone = snapshot.drone, !droneRunning {
            setDrone(tonic: drone.tonic, voice: drone.voice, fifth: drone.fifth)
        }
        if let click = snapshot.metronome, !metronomeRunning {
            setMetronome(bpm: click.bpm, beats: click.beats, subdivision: click.subdivision, accents: click.accents,
                         beatLevels: click.beatLevels, sound: click.sound, tool: true)
        }
        if let capture = snapshot.capture, !running, UIApplication.shared.applicationState == .active {
            Task { await self.listen(capture) }
        }
    }

    /// A call, Siri or an alarm took the audio: everything stops, and what was going is remembered for the end.
    private func interruptionBegan() {
        interrupted = snapshot()
        suspend()
    }

    /// The interruption is over. With "should resume" what was going comes back; without it, it stays stopped.
    private func interruptionEnded(resume: Bool) {
        guard let snapshot = interrupted else { return }
        interrupted = nil
        if resume { restore(snapshot) }
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
            warmSamples(request.voice)
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
            warmSamples(request.voice)
            tonePlaying = true
            toneTask?.cancel(); toneTask = nil
            sound(request, reference: false)
        } catch { self.error = String(localized: "Could not play tones: \(error.localizedDescription)") }
    }

    private var currentVoice: InstrumentVoice { courseVoice ?? instrumentVoice() }

    /// Decodes `voice`'s recorded zones on a utility queue, once (until a memory warning), so its first notes don't
    /// wait on decoding. A voice without recordings costs nothing; nothing is decoded at launch.
    private func warmSamples(_ voice: InstrumentVoice) {
        guard !warmedVoices.contains(voice), let library = SampleLibrary.shared, library.instrument(for: voice) != nil else { return }
        warmedVoices.insert(voice)
        DispatchQueue.global(qos: .utility).async { library.prewarm(voice) }
    }

    /// Plays a request from the cache, or renders it on the tone queue first (from the instrument's recordings when
    /// the app has them, else synthesized); a newer request or a stop in the meantime wins.
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
            let clip = ToneSynth.render(request, samples: SampleLibrary.shared)
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

    /// Starts the click. Only the Metronome tool changing its own running click (`tool`) keeps the phase; every other
    /// call is a fresh count from its first click (bar counter, played frames and clock start again), so a lesson's
    /// count-in, runway and judging start with the click they assume, even over the tool's click left running.
    func setMetronome(bpm: Int, beats: Int, subdivision: Int, accents: Bool, beatLevels: [Int]? = nil, sound: MetronomeRenderer.Sound = .click, tool: Bool = false) {
        do {
            try ensureOutput()
            let continuing = tool && metronomeOwnedByTool && metronomeRunning
            // A fresh count takes the old band with it; the new owner asks for its own (`playBand`).
            if !continuing { bandRequest = nil; bandPlaying = false }
            renderer.setMetronome(bpm: bpm, beats: beats, subdivision: subdivision, accents: accents, beatLevels: beatLevels, sound: sound, restart: !continuing)
            metronomeRunning = bpm > 0
            metronomeOwnedByTool = tool && bpm > 0
            metronomeSettings = bpm > 0 ? MetronomeSettings(bpm: bpm, beats: beats, subdivision: subdivision, accents: accents,
                                                            beatLevels: beatLevels, sound: sound) : nil
        } catch { suspend(); self.error = String(localized: "Could not start the metronome: \(error.localizedDescription)") }
    }

    /// Stops the click; a lesson band under it fades out with it (a final chord already ringing finishes).
    func stopMetronome() {
        renderer.setMetronome(bpm: 0, beats: 4, subdivision: 1, accents: true, beatLevels: nil, sound: .click)
        metronomeRunning = false
        metronomeOwnedByTool = false
        metronomeSettings = nil
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
            let track = BandSynth.render(arrangement, sampleRate: rate, samples: SampleLibrary.shared)
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
            droneSettings = DroneSettings(tonic: tonic, voice: voice, fifth: fifth)
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
        droneSettings = nil
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

/// The app's one owner of the shared audio session: its category, mode and activation. The lessons' engine
/// (`AudioService`) and the player's own recordings (`RecordingPlayer`) both go through it, so neither turns the session
/// off under the other, and deactivation (which blocks while the hardware winds down) runs off the main thread.
final class AudioSessionOwner: @unchecked Sendable {
    static let shared = AudioSessionOwner()

    enum User: Hashable, Sendable {
        /// `AudioService`: the microphone, tones, the metronome, the drone and the band (play and record, measurement mode).
        case lessons
        /// `RecordingPlayer`: a recording of the player's own (playback, unless the lessons' play-and-record is set).
        case recording
    }

    private let lock = NSLock()
    private var holders: Set<User> = []
    /// Moves on with every activation and release: a deactivation still waiting goes ahead only if nothing happened since.
    private var epoch = 0
    private let queue = DispatchQueue(label: "com.timbre.audio-session", qos: .userInitiated)

    private init() {}

    /// Sets the session up for `user` and activates it, on the main thread just before an engine starts. A
    /// deactivation still waiting is called off; one already under way is waited for, so it can't land afterwards.
    func activate(_ user: User) throws {
        lock.lock()
        defer { lock.unlock() }
        epoch &+= 1
        let session = AVAudioSession.sharedInstance()
        switch user {
        case .lessons:
            try session.setCategory(.playAndRecord, mode: .measurement, options: [.defaultToSpeaker, .allowBluetoothA2DP, .mixWithOthers])
            // Off by default: iOS would silence every haptic (the tuner's detents and lock, the highway's beats)
            // while the microphone records.
            try? session.setAllowHapticsAndSystemSoundsDuringRecording(true)
            try session.setPreferredSampleRate(48000)
            try session.setPreferredIOBufferDuration(0.005)
        case .recording:
            // The lessons' play-and-record session (held now, or left from before) carries the recording as it is;
            // otherwise plain playback.
            if session.category != .playAndRecord {
                try session.setCategory(.playback, mode: .default, options: [])
            }
        }
        try session.setActive(true)
        holders.insert(user)
    }

    /// `user` is done with the session. With `deactivate`, once nobody holds it the session is turned off on a
    /// background queue and other apps' audio may resume; an activation before that runs calls it off.
    func release(_ user: User, deactivate: Bool = true) {
        lock.lock()
        holders.remove(user)
        guard deactivate, holders.isEmpty else { lock.unlock(); return }
        epoch &+= 1
        let ticket = epoch
        lock.unlock()
        queue.async { [self] in
            lock.lock()
            defer { lock.unlock() }
            guard epoch == ticket, holders.isEmpty else { return }
            try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        }
    }
}

/// How the microphone was started.
private struct CaptureSettings { let minimum, maximum, sensitivity: Double; let window: Int?; let confidence: Double }
/// How the click was started.
private struct MetronomeSettings {
    let bpm, beats, subdivision: Int
    let accents: Bool
    let beatLevels: [Int]?
    let sound: MetronomeRenderer.Sound
}
/// How the drone was started.
private struct DroneSettings { let tonic: Double; let voice: DroneRenderer.Voice; let fifth: Bool }
/// What can come back after an interruption or a media services reset (`AudioService.snapshot`).
private struct Interrupted { let capture: CaptureSettings?; let metronome: MetronomeSettings?; let drone: DroneSettings? }
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
    /// `restart`: a fresh count even when a click is already running (a new owner); otherwise a running click keeps
    /// its phase and only changes tempo, meter and sound.
    func setMetronome(bpm: Int, beats: Int, subdivision: Int, accents: Bool, beatLevels: [Int]?, sound: MetronomeRenderer.Sound, restart: Bool = false) {
        lock.lock(); defer { lock.unlock() }
        guard bpm > 0 else {
            // The band fades with the click; a final chord already ringing is left to finish.
            metronome = nil; band?.stop(force: false); clock.set(nil)
            return
        }
        // The lessons' own floor (slowest rungs, bar loops) is the pattern's: the click never runs ahead of the runway.
        let tempo = min(MetronomePattern.tempoRange.upperBound, max(MetronomePattern.tempoRange.lowerBound, bpm))
        let pattern = MetronomePattern(bpm: tempo, beatsPerBar: min(12, max(1, beats)), subdivision: min(4, max(1, subdivision)))
        let renderer: MetronomeRenderer
        if let metronome, !restart {
            renderer = metronome
        } else {
            // A fresh count from its first click: the bar counter, frame count and clock start again, and an older
            // band can't follow it.
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
