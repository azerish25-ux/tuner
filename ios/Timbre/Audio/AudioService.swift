import AVFoundation
import Combine
import UIKit
import TimbreCore

/// Owns the single foreground audio session. Pitch analysis runs on a bounded serial queue.
@MainActor
final class AudioService: ObservableObject {
    @Published private(set) var running = false
    @Published private(set) var frequency: Double?
    @Published private(set) var confidence = 0.0
    @Published private(set) var levelDbfs = -120.0
    @Published private(set) var error: String?
    @Published private(set) var metronomeRunning = false
    @Published private(set) var tonePlaying = false
    var onReading: ((Double?, Double, Double) -> Void)?
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
                self.suspend(); self.error = "Audio interrupted. Tap Listen to resume."
            }
        })
        observers.append(NotificationCenter.default.addObserver(forName: UIApplication.didEnterBackgroundNotification, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.stop() }
        })
        observers.append(NotificationCenter.default.addObserver(forName: AVAudioSession.routeChangeNotification, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                let resume = self.running
                let minimum = self.minimum, maximum = self.maximum, sensitivity = self.sensitivity
                let window = self.windowOverride, confidence = self.confidenceThreshold
                self.suspend()
                guard resume, UIApplication.shared.applicationState == .active else { return }
                await self.start(minimum: minimum, maximum: maximum, micSensitivity: sensitivity, analysisWindowOverride: window, confidenceThreshold: confidence)
            }
        })
        observers.append(NotificationCenter.default.addObserver(forName: AVAudioSession.mediaServicesWereResetNotification, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                self.stop(); self.engine = AVAudioEngine(); self.error = "Audio service restarted. Tap Listen to resume."
            }
        })
    }

    func start(minimum: Double = 25, maximum: Double = 4500, micSensitivity: Double = 1, analysisWindowOverride: Int? = nil, confidenceThreshold: Double = 0.75) async {
        guard !running else { return }
        generation += 1
        let token = generation
        let allowed = await AVAudioApplication.requestRecordPermission()
        guard generation == token, UIApplication.shared.applicationState == .active else { return }
        guard allowed else { error = "Microphone access is off. Enable it in Settings → Timbre → Microphone."; return }
        self.minimum = minimum.isFinite && minimum > 0 ? minimum : 25
        self.maximum = maximum.isFinite && maximum > self.minimum ? maximum : max(4500, self.minimum * 2)
        sensitivity = micSensitivity.isFinite ? min(4, max(0.1, micSensitivity)) : 1
        self.confidenceThreshold = confidenceThreshold.isFinite ? min(1, max(0, confidenceThreshold)) : 0.75
        windowOverride = analysisWindowOverride
        do {
            // Stop any output-only graph before changing its connections.
            engine.stop()
            try configureSession()
            let input = engine.inputNode
            let format = input.outputFormat(forBus: 0)
            guard format.sampleRate > 0, format.channelCount > 0 else { throw AudioFailure.noInput }
            let window = AnalysisWindowPolicy.windowSizeForTuningRange(minFrequencyHz: self.minimum, sampleRateHz: Int(format.sampleRate), preferredWindow: analysisWindowOverride)
            let worker = PitchWorker(rate: format.sampleRate, minimum: self.minimum, maximum: self.maximum, window: window, gain: sensitivity)
            let threshold = self.confidenceThreshold
            input.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self, analysisQueue] buffer, _ in
                guard let samples = buffer.floatChannelData?[0], let epoch = worker.reserve() else { return }
                let copy = Array(UnsafeBufferPointer(start: samples, count: Int(buffer.frameLength)))
                analysisQueue.async {
                    let output = worker.consume(copy, epoch: epoch)
                    worker.release()
                    guard let output else { return }
                    Task { @MainActor [weak self] in
                        guard let self, self.generation == token, self.running else { return }
                        self.levelDbfs = output.level
                        let pitch = output.pitch
                        let accepted = !self.tonePlaying && (pitch?.confidence ?? 0) >= threshold
                        self.frequency = accepted ? pitch?.frequencyHz : nil
                        self.confidence = self.tonePlaying ? 0 : pitch?.confidence ?? 0
                        self.onReading?(self.tonePlaying ? nil : pitch?.frequencyHz, self.confidence, output.level)
                    }
                }
            }
            tapInstalled = true
            try attachOutput()
            engine.prepare(); try engine.start()
            running = true; error = nil
        } catch { suspend(); self.error = "Could not start audio: \(error.localizedDescription)" }
    }

    func stop() { suspend() }
    private func suspend() {
        toneTask?.cancel(); toneTask = nil; resumeCaptureAfterTone = false
        generation += 1
        if tapInstalled { engine.inputNode.removeTap(onBus: 0); tapInstalled = false }
        engine.stop(); renderer.stop()
        if let source { engine.disconnectNodeOutput(source); engine.detach(source); self.source = nil }
        running = false; metronomeRunning = false; tonePlaying = false
        frequency = nil; confidence = 0; levelDbfs = -120
        onReading?(nil, 0, -120)
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }
    private func configureSession() throws {
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playAndRecord, mode: .measurement, options: [.defaultToSpeaker, .allowBluetooth])
        try session.setPreferredSampleRate(48000)
        try session.setPreferredIOBufferDuration(0.01)
        try session.setActive(true)
    }
    private func attachOutput() throws {
        if let source { engine.disconnectNodeOutput(source); engine.detach(source); self.source = nil }
        let rate = engine.outputNode.inputFormat(forBus: 0).sampleRate
        guard rate > 0, let format = AVAudioFormat(standardFormatWithSampleRate: rate, channels: 1) else { throw AudioFailure.noOutput }
        renderer.setSampleRate(rate)
        let source = AVAudioSourceNode { [renderer] _, _, count, audio in
            renderer.render(frameCount: Int(count), audio: audio)
            return noErr
        }
        engine.attach(source); engine.connect(source, to: engine.mainMixerNode, format: format)
        self.source = source
    }
    func playTone(_ hz: Double, durationMs: Int = 2000) {
        guard UIApplication.shared.applicationState == .active, hz.isFinite, hz > 0 else { return }
        generation += 1
        let resume = running || resumeCaptureAfterTone
        toneTask?.cancel(); toneTask = nil
        if running { suspend() }
        do {
            if !engine.isRunning { try configureSession(); try attachOutput(); engine.prepare(); try engine.start() }
            renderer.setTone(hz, durationMs: durationMs); tonePlaying = true; resumeCaptureAfterTone = resume
            if durationMs > 0 {
                toneTask = Task { [weak self] in
                    do { try await Task.sleep(for: .milliseconds(durationMs)) } catch { return }
                    guard !Task.isCancelled else { return }
                    self?.stopTone()
                }
            }
        } catch { suspend(); self.error = "Could not play reference tone: \(error.localizedDescription)" }
    }
    func stopTone() {
        toneTask?.cancel(); toneTask = nil
        renderer.setTone(0); tonePlaying = false
        let resume = resumeCaptureAfterTone
        resumeCaptureAfterTone = false
        if resume {
            let token = generation
            Task { guard generation == token else { return }; await start(minimum: minimum, maximum: maximum, micSensitivity: sensitivity, analysisWindowOverride: windowOverride, confidenceThreshold: confidenceThreshold) }
        } else { stopOutputIfIdle() }
    }
    func setMetronome(bpm: Int, beats: Int, subdivision: Int, accents: Bool) {
        guard UIApplication.shared.applicationState == .active else { return }
        do {
            if !engine.isRunning { try configureSession(); try attachOutput(); engine.prepare(); try engine.start() }
            renderer.setMetronome(bpm: bpm, beats: beats, subdivision: subdivision, accents: accents); metronomeRunning = bpm > 0
        } catch { suspend(); self.error = "Could not start metronome: \(error.localizedDescription)" }
    }
    func stopMetronome() { renderer.setMetronome(bpm: 0, beats: 4, subdivision: 1, accents: true); metronomeRunning = false; stopOutputIfIdle() }
    private func stopOutputIfIdle() { if !running && !tonePlaying && !metronomeRunning { suspend() } }
    private enum AudioFailure: LocalizedError {
        case noInput, noOutput
        var errorDescription: String? { self == .noInput ? "No microphone input is available. Check your audio connection." : "No audio output is available. Check your audio connection." }
    }
}

/// One worker per capture generation; queued callbacks can never reconfigure a newer detector.
private final class PitchWorker: @unchecked Sendable {
    private let lock = NSLock()
    private var pending = 0, epoch = 0
    private var consumedEpoch = 0, sinceReading = 0
    private let detector: YinPitchDetector
    private var samples: [Float] = []
    private let window: Int, hop: Int
    private let gain: Float
    init(rate: Double, minimum: Double, maximum: Double, window: Int, gain: Double) {
        detector = YinPitchDetector(sampleRate: rate, minFrequency: minimum, maxFrequency: maximum)
        self.window = window; hop = max(1, Int((rate / 20).rounded())); self.gain = Float(gain)
        samples.reserveCapacity(window + hop + 2048)
    }
    func reserve() -> Int? {
        lock.lock(); defer { lock.unlock() }
        guard pending < 4 else { epoch += 1; return nil }
        pending += 1; return epoch
    }
    func release() { lock.lock(); pending -= 1; lock.unlock() }
    func consume(_ chunk: [Float], epoch: Int) -> (pitch: DetectedPitch?, level: Double)? {
        if consumedEpoch != epoch {
            samples.removeAll(keepingCapacity: true); sinceReading = 0; consumedEpoch = epoch
        }
        samples.append(contentsOf: chunk.map { $0 * gain })
        sinceReading += chunk.count
        guard samples.count >= window else { return nil }
        if samples.count > window { samples.removeFirst(samples.count - window) }
        guard sinceReading >= hop else { return nil }
        sinceReading %= hop
        let frame = samples
        return (detector.detect(frame), DspMath.rmsDbfs(frame))
    }
}

/// Controls synchronize once per PCM buffer. Core renderers own sample-clock phase and envelopes.
private final class OutputRenderer: @unchecked Sendable {
    private let lock = NSLock()
    private var sampleRate = 48000
    private var tone: ReferenceToneRenderer?
    private var metronome: MetronomeRenderer?
    func setSampleRate(_ rate: Double) {
        lock.lock(); defer { lock.unlock() }
        sampleRate = max(40, Int(rate.rounded())); tone = nil; metronome = nil
    }
    func setTone(_ hz: Double, durationMs: Int = 2000) {
        lock.lock(); defer { lock.unlock() }
        guard hz > 0, hz < Double(sampleRate) / 2 else { tone?.stop(); return }
        tone = ReferenceToneRenderer(frequencyHz: hz, sampleRateHz: sampleRate, durationMs: durationMs)
    }
    func setMetronome(bpm: Int, beats: Int, subdivision: Int, accents: Bool) {
        lock.lock(); defer { lock.unlock() }
        guard bpm > 0 else { metronome = nil; return }
        let pattern = MetronomePattern(bpm: min(240, max(40, bpm)), beatsPerBar: min(7, max(2, beats)), subdivision: min(4, max(1, subdivision)))
        if let metronome { metronome.update(pattern); metronome.accents = accents }
        else { let renderer = MetronomeRenderer(sampleRate: sampleRate, initial: pattern); renderer.accents = accents; metronome = renderer }
    }
    func stop() { lock.lock(); tone = nil; metronome = nil; lock.unlock() }
    func render(frameCount: Int, audio: UnsafeMutablePointer<AudioBufferList>) {
        let buffers = UnsafeMutableAudioBufferListPointer(audio)
        guard lock.try() else {
            for buffer in buffers { if let data = buffer.mData { memset(data, 0, Int(buffer.mDataByteSize)) } }
            return
        }
        defer { lock.unlock() }
        for frame in 0..<frameCount {
            let value = (tone?.nextSample() ?? 0) + (metronome?.nextSample() ?? 0)
            for buffer in buffers { buffer.mData?.assumingMemoryBound(to: Float.self)[frame] = value }
        }
    }
}

