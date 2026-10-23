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

    init() {
        observers.append(NotificationCenter.default.addObserver(forName: AVAudioSession.interruptionNotification, object: nil, queue: .main) { [weak self] notification in
            let began = (notification.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt) == AVAudioSession.InterruptionType.began.rawValue
            Task { @MainActor in
                guard began, let self else { return }
                self.suspend()
            }
        })
        observers.append(NotificationCenter.default.addObserver(forName: UIApplication.didEnterBackgroundNotification, object: nil, queue: .main) { [weak self] _ in
            // The microphone stops in the background; metronome and drone keep playing.
            Task { @MainActor in self?.stopCapture() }
        })
        observers.append(NotificationCenter.default.addObserver(forName: AVAudioSession.routeChangeNotification, object: nil, queue: .main) { [weak self] notification in
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

    var outputActive: Bool { metronomeRunning || droneRunning || tonePlaying }

    func start(minimum: Double = 25, maximum: Double = 4500, micSensitivity: Double = 1, analysisWindowOverride: Int? = nil, confidenceThreshold: Double = 0.75) async {
        guard !running, !Task.isCancelled else { return }
        if tonePlaying {
            toneTask?.cancel(); toneTask = nil; resumeCaptureAfterTone = false
            renderer.setTone(0); tonePlaying = false
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
    func startDemo(target: @escaping () -> Double) {
        guard !running else { return }
        generation += 1
        let token = generation
        running = true; error = nil
        let start = ProcessInfo.processInfo.systemUptime
        Task { @MainActor [weak self] in
            while let self, self.generation == token, self.running {
                let t = ProcessInfo.processInfo.systemUptime - start
                let cycle = t.truncatingRemainder(dividingBy: 6)
                let cents = cycle < 4.2 ? -14 * (1 - cycle / 4.2) + 0.4 * sin(t * 9) : 0.3 * sin(t * 5)
                let level = -22 - 18 * min(1, cycle / 6)
                self.onReading?(target() * pow(2, cents / 1200), 0.95, level)
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
        generation += 1
        if tapInstalled { engine.inputNode.removeTap(onBus: 0); tapInstalled = false }
        renderer.stop()
        running = false; metronomeRunning = false; tonePlaying = false; droneRunning = false
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
    }

    private func attachOutput(keepState: Bool = false) throws {
        if let source { engine.disconnectNodeOutput(source); engine.detach(source); self.source = nil }
        let rate = engine.outputNode.inputFormat(forBus: 0).sampleRate
        guard rate > 0, let format = AVAudioFormat(standardFormatWithSampleRate: rate, channels: 1) else { throw AudioFailure.noOutput }
        renderer.setSampleRate(rate, keepState: keepState)
        let source = AVAudioSourceNode { [renderer] _, _, count, audio in
            renderer.render(frameCount: Int(count), audio: audio)
            return noErr
        }
        engine.attach(source); engine.connect(source, to: engine.mainMixerNode, format: format)
        self.source = source
    }

    private func ensureOutput() throws {
        if !engine.isRunning { try configureSession(); try attachOutput(); engine.prepare(); try engine.start() }
    }

    func playTone(_ hz: Double, durationMs: Int = 2000) {
        guard UIApplication.shared.applicationState == .active, hz.isFinite, hz > 0 else { return }
        let resume = running || resumeCaptureAfterTone
        toneTask?.cancel(); toneTask = nil
        if running { stopCapture() }
        do {
            try ensureOutput()
            renderer.setTone(hz, durationMs: durationMs); tonePlaying = true; resumeCaptureAfterTone = resume
            if durationMs > 0 {
                toneTask = Task { [weak self] in
                    do { try await Task.sleep(for: .milliseconds(durationMs)) } catch { return }
                    guard !Task.isCancelled else { return }
                    self?.stopTone()
                }
            }
        } catch { suspend(); self.error = String(localized: "Could not play the reference tone: \(error.localizedDescription)") }
    }

    /// Ear training: tones in sequence or together. Capture pauses while they sound.
    func playTones(_ frequencies: [Double], together: Bool, noteMs: Int = 900, gapMs: Int = 150) {
        guard UIApplication.shared.applicationState == .active, !frequencies.isEmpty else { return }
        if running { stopCapture() }
        do {
            try ensureOutput()
            let total = together ? noteMs + 400 : frequencies.count * (noteMs + gapMs)
            renderer.setSequence(frequencies, together: together, noteMs: together ? noteMs + 400 : noteMs, gapMs: gapMs)
            tonePlaying = true
            toneTask?.cancel()
            toneTask = Task { [weak self] in
                do { try await Task.sleep(for: .milliseconds(total + 60)) } catch { return }
                guard !Task.isCancelled, let self else { return }
                self.tonePlaying = false
                if !self.running && !self.metronomeRunning && !self.droneRunning { self.shutdown() }
            }
        } catch { self.error = String(localized: "Could not play tones: \(error.localizedDescription)") }
    }

    func stopTone() {
        toneTask?.cancel(); toneTask = nil
        renderer.setTone(0); tonePlaying = false
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

    func stopMetronome() {
        renderer.setMetronome(bpm: 0, beats: 4, subdivision: 1, accents: true, beatLevels: nil, sound: .click)
        metronomeRunning = false
        if !running && !outputActive { shutdown() }
    }

    func setDrone(tonic: Double, voice: DroneRenderer.Voice, fifth: Bool) {
        do {
            try ensureOutput()
            renderer.setDrone(tonic: tonic, voice: voice, fifth: fifth)
            droneRunning = true
        } catch { self.error = String(localized: "Could not start the drone: \(error.localizedDescription)") }
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

/// Controls synchronize once per PCM buffer. Core renderers own sample-clock phase and envelopes.
private final class OutputRenderer: @unchecked Sendable {
    private struct Scheduled { let renderer: ReferenceToneRenderer; let start: Int64 }
    private let lock = NSLock()
    private var sampleRate = 48000
    private var tone: ReferenceToneRenderer?
    private var sequence: [Scheduled] = []
    private var sequenceFrame: Int64 = 0
    private var metronome: MetronomeRenderer?
    private var drone: DroneRenderer?
    func setSampleRate(_ rate: Double, keepState: Bool) {
        lock.lock(); defer { lock.unlock() }
        let next = max(40, Int(rate.rounded()))
        if !keepState || next != sampleRate { tone = nil; sequence = []; metronome = nil; drone = nil }
        sampleRate = next
    }
    func setTone(_ hz: Double, durationMs: Int = 2000) {
        lock.lock(); defer { lock.unlock() }
        guard hz > 0, hz < Double(sampleRate) / 2 else { tone?.stop(); return }
        tone = ReferenceToneRenderer(frequencyHz: hz, sampleRateHz: sampleRate, durationMs: durationMs)
    }
    func setSequence(_ frequencies: [Double], together: Bool, noteMs: Int, gapMs: Int) {
        lock.lock(); defer { lock.unlock() }
        sequenceFrame = 0
        sequence = frequencies.enumerated().compactMap { index, hz in
            guard hz > 0, hz < Double(sampleRate) / 2 else { return nil }
            let start = together ? 0 : Int64(index * (noteMs + gapMs)) * Int64(sampleRate) / 1000
            return Scheduled(renderer: ReferenceToneRenderer(frequencyHz: hz, sampleRateHz: sampleRate, durationMs: noteMs, amplitude: together ? 0.12 : 0.2), start: start)
        }
    }
    func setMetronome(bpm: Int, beats: Int, subdivision: Int, accents: Bool, beatLevels: [Int]?, sound: MetronomeRenderer.Sound) {
        lock.lock(); defer { lock.unlock() }
        guard bpm > 0 else { metronome = nil; return }
        let pattern = MetronomePattern(bpm: min(300, max(30, bpm)), beatsPerBar: min(12, max(1, beats)), subdivision: min(4, max(1, subdivision)))
        let renderer = metronome ?? MetronomeRenderer(sampleRate: sampleRate, initial: pattern)
        renderer.update(pattern)
        renderer.accents = accents; renderer.beatLevels = beatLevels; renderer.sound = sound
        metronome = renderer
    }
    func setDrone(tonic: Double, voice: DroneRenderer.Voice, fifth: Bool) {
        lock.lock(); defer { lock.unlock() }
        drone = DroneRenderer(tonic: tonic, fifth: fifth, voice: voice, sampleRate: sampleRate)
    }
    func stopDrone() { lock.lock(); drone?.stop(); lock.unlock() }
    func stop() { lock.lock(); tone = nil; sequence = []; metronome = nil; drone = nil; lock.unlock() }
    func render(frameCount: Int, audio: UnsafeMutablePointer<AudioBufferList>) {
        let buffers = UnsafeMutableAudioBufferListPointer(audio)
        guard lock.try() else {
            for buffer in buffers { if let data = buffer.mData { memset(data, 0, Int(buffer.mDataByteSize)) } }
            return
        }
        defer { lock.unlock() }
        for frame in 0..<frameCount {
            var value = (tone?.nextSample() ?? 0) + (metronome?.nextSample() ?? 0) + (drone?.nextSample() ?? 0)
            if !sequence.isEmpty {
                for item in sequence where sequenceFrame >= item.start { value += item.renderer.nextSample() }
                sequenceFrame += 1
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
