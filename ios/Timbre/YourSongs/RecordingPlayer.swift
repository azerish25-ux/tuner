import AVFoundation
import Combine
import TimbreCore

/// Plays the player's own recording of a song (an audio file they imported) for playing along: slowed down without
/// changing its pitch, or moved to the key the chart is transposed to (`AVAudioUnitTimePitch`), and an A–B part
/// looped without a gap (the part read into a buffer the player node loops). Only the player's own files come through
/// here: Apple Music plays in Apple's own player, untouched (`AppleMusicListener`).
///
/// Its own engine, so the lessons' audio (`AudioService`) is never disturbed; the session is shared through
/// `AudioSessionOwner`. When the lessons' engine changes the session (a lesson's microphone, a chord sounded), this
/// one pauses where it was and plays on from there; after a call it plays on by itself when iOS says it should.
@MainActor
final class RecordingPlayer: ObservableObject {
    @Published private(set) var isPlaying = false
    @Published private(set) var duration: Double = 0
    @Published private(set) var loadedURL: URL?
    /// The A–B part looping, in seconds.
    @Published private(set) var loop: ClosedRange<Double>?
    /// Playback speed, 0.5…1.
    @Published private(set) var rate: Float = 1
    /// Semitones the recording is moved, to follow a transposed chart.
    @Published private(set) var semitones = 0
    @Published private(set) var failed = false

    private let engine = AVAudioEngine()
    private let node = AVAudioPlayerNode()
    private let timePitch = AVAudioUnitTimePitch()
    private var file: AVAudioFile?
    private var sampleRate = 44100.0
    private var length: AVAudioFramePosition = 0
    /// What the node was given: from `startFrame`, `firstLength` frames, then (when looping) the part from `loopStart`,
    /// `loopLength` frames long, round and round.
    private var startFrame: AVAudioFramePosition = 0
    private var firstLength: AVAudioFramePosition = 0
    private var loopStart: AVAudioFramePosition = 0
    private var loopLength: AVAudioFramePosition = 0
    private var resumeAt = 0.0
    private var lastTime = 0.0
    private var generation = 0
    private var observers: [NSObjectProtocol] = []
    /// A call (or Siri, an alarm) paused the recording while it played: it plays on if the interruption ends with
    /// "should resume".
    private var resumeAfterInterruption = false
    /// This player activated the session and hasn't turned it off since (a pause leaves it active).
    private var sessionActive = false

    init() {
        engine.attach(node)
        engine.attach(timePitch)
        observers.append(NotificationCenter.default.addObserver(forName: .AVAudioEngineConfigurationChange, object: engine, queue: .main) { [weak self] _ in
            // The session changed under the engine (another engine took it, a route changed): it has stopped.
            Task { @MainActor in self?.engineStopped() }
        })
        observers.append(NotificationCenter.default.addObserver(forName: AVAudioSession.interruptionNotification, object: nil, queue: .main) { [weak self] notification in
            let info = notification.userInfo
            let type = (info?[AVAudioSessionInterruptionTypeKey] as? UInt).flatMap(AVAudioSession.InterruptionType.init(rawValue:))
            let options = AVAudioSession.InterruptionOptions(rawValue: info?[AVAudioSessionInterruptionOptionKey] as? UInt ?? 0)
            Task { @MainActor in
                guard let self, let type else { return }
                switch type {
                case .began:
                    self.resumeAfterInterruption = self.isPlaying
                    self.pause()
                case .ended:
                    let resume = self.resumeAfterInterruption && options.contains(.shouldResume)
                    self.resumeAfterInterruption = false
                    if resume && !self.isPlaying { self.play() }
                @unknown default:
                    break
                }
            }
        })
    }

    deinit {
        for observer in observers { NotificationCenter.default.removeObserver(observer) }
    }

    /// The length of an audio file in seconds; nil when it can't be read (DRM, damaged, not audio).
    nonisolated static func duration(of url: URL) -> Double? {
        guard let file = try? AVAudioFile(forReading: url), file.processingFormat.sampleRate > 0 else { return nil }
        return Double(file.length) / file.processingFormat.sampleRate
    }

    // MARK: Loading

    func load(_ url: URL) {
        guard loadedURL != url else { return }
        stop()
        do {
            let opened = try AVAudioFile(forReading: url)
            file = opened
            sampleRate = opened.processingFormat.sampleRate
            length = opened.length
            duration = sampleRate > 0 ? Double(length) / sampleRate : 0
            loadedURL = url
            loop = nil
            resumeAt = 0
            lastTime = 0
            failed = duration <= 0
        } catch {
            file = nil
            loadedURL = nil
            duration = 0
            failed = true
        }
    }

    // MARK: Transport

    /// Plays from `time` (seconds), or from where it paused.
    func play(from time: Double? = nil) {
        guard let file, duration > 0 else { return }
        var start = max(0, min(duration - 0.05, time ?? resumeAt))
        if start >= duration - 0.1 { start = 0 }
        do {
            try activateSession()
            if !engine.isRunning {
                engine.disconnectNodeOutput(node)
                engine.disconnectNodeOutput(timePitch)
                engine.connect(node, to: timePitch, format: file.processingFormat)
                engine.connect(timePitch, to: engine.mainMixerNode, format: file.processingFormat)
                engine.prepare()
                try engine.start()
            }
        } catch {
            // The session is busy (a call, another app): nothing plays, and the next tap tries again.
            return
        }
        schedule(file, from: start)
        node.play()
        isPlaying = true
        lastTime = start
    }

    func pause() {
        guard isPlaying else { return }
        resumeAt = currentTime()
        generation += 1
        node.stop()
        // The engine lets the session go while paused, so the lessons' microphone can take it (it stays active).
        engine.stop()
        releaseSession(deactivate: false)
        isPlaying = false
    }

    func toggle() {
        resumeAfterInterruption = false
        isPlaying ? pause() : play()
    }

    func seek(to time: Double) {
        let target = max(0, min(duration, time))
        if isPlaying {
            play(from: target)
        } else {
            resumeAt = target
            lastTime = target
            // Nothing published changes while paused: views showing the time read it again.
            objectWillChange.send()
        }
    }

    func skip(by seconds: Double) { seek(to: currentTime() + seconds) }

    /// Stops and lets the audio session go (deactivated off the main thread when nothing else in the app holds it).
    func stop() {
        generation += 1
        resumeAfterInterruption = false
        node.stop()
        if engine.isRunning { engine.stop() }
        isPlaying = false
        resumeAt = 0
        lastTime = 0
        releaseSession(deactivate: true)
    }

    /// Where playback is, in seconds.
    func currentTime() -> Double {
        guard isPlaying, let nodeTime = node.lastRenderTime, nodeTime.isSampleTimeValid,
              let playerTime = node.playerTime(forNodeTime: nodeTime), sampleRate > 0 else { return isPlaying ? lastTime : resumeAt }
        let played = max(0, playerTime.sampleTime)
        let frame: AVAudioFramePosition
        if loopLength > 0 && played >= firstLength {
            frame = loopStart + (played - firstLength) % loopLength
        } else {
            frame = min(length, startFrame + played)
        }
        lastTime = Double(frame) / sampleRate
        return lastTime
    }

    // MARK: Speed, key and loop

    func setRate(_ value: Float) {
        rate = min(1, max(0.5, value))
        timePitch.rate = rate
    }

    func setSemitones(_ value: Int) {
        semitones = max(-12, min(12, value))
        timePitch.pitch = Float(semitones * 100)
    }

    /// Loops `range` (at least half a second), or plays straight through again with nil. Playing on from inside it.
    func setLoop(_ range: ClosedRange<Double>?) {
        let low = max(0, range?.lowerBound ?? 0)
        let high = min(duration, range?.upperBound ?? 0)
        loop = range != nil && high - low >= 0.5 ? low...high : nil
        if isPlaying { play(from: currentTime()) }
    }

    // MARK: Scheduling

    private func schedule(_ file: AVAudioFile, from time: Double) {
        generation += 1
        let token = generation
        node.stop()
        var frame = max(0, min(length - 1, AVAudioFramePosition(time * sampleRate)))
        loopLength = 0
        if let loop, let buffer = loopBuffer(loop) {
            let a = AVAudioFramePosition(loop.lowerBound * sampleRate)
            let b = a + AVAudioFramePosition(buffer.frameLength)
            if frame < a || frame >= b { frame = a }
            startFrame = frame
            firstLength = b - frame
            if firstLength > 0 {
                node.scheduleSegment(file, startingFrame: frame, frameCount: AVAudioFrameCount(firstLength), at: nil, completionHandler: nil)
            }
            loopStart = a
            loopLength = AVAudioFramePosition(buffer.frameLength)
            node.scheduleBuffer(buffer, at: nil, options: .loops, completionHandler: nil)
        } else {
            startFrame = frame
            firstLength = length - frame
            node.scheduleSegment(file, startingFrame: frame, frameCount: AVAudioFrameCount(max(0, firstLength)), at: nil,
                                 completionCallbackType: .dataPlayedBack) { [weak self] _ in
                Task { @MainActor in self?.reachedEnd(token) }
            }
        }
    }

    /// The A–B part read into memory from a second handle on the file (the node is reading the first).
    private func loopBuffer(_ range: ClosedRange<Double>) -> AVAudioPCMBuffer? {
        guard let url = loadedURL, let reader = try? AVAudioFile(forReading: url) else { return nil }
        let a = max(0, AVAudioFramePosition(range.lowerBound * sampleRate))
        let b = min(length, AVAudioFramePosition(range.upperBound * sampleRate))
        guard b - a > AVAudioFramePosition(sampleRate * 0.25),
              let buffer = AVAudioPCMBuffer(pcmFormat: reader.processingFormat, frameCapacity: AVAudioFrameCount(b - a)) else { return nil }
        reader.framePosition = a
        do { try reader.read(into: buffer, frameCount: AVAudioFrameCount(b - a)) } catch { return nil }
        return buffer.frameLength > 0 ? buffer : nil
    }

    private func reachedEnd(_ token: Int) {
        // A stop or a new schedule also ends the segment: only the one still playing counts.
        guard token == generation, isPlaying else { return }
        isPlaying = false
        resumeAt = 0
        lastTime = duration
        node.stop()
        // Played to the end: the engine and the session go until the next play.
        engine.stop()
        releaseSession(deactivate: true)
    }

    private func engineStopped() {
        guard isPlaying else { return }
        resumeAt = lastTime
        generation += 1
        isPlaying = false
        releaseSession(deactivate: false)
    }

    /// The app's own playback session, through the one owner (`AudioSessionOwner`); the lessons' play-and-record
    /// session is left as it is.
    private func activateSession() throws {
        try AudioSessionOwner.shared.activate(.recording)
        sessionActive = true
    }

    /// This player's engine no longer needs the session. `deactivate`: it is turned off too (off the main thread, once
    /// nothing else in the app holds it); otherwise it stays active for whoever plays next.
    private func releaseSession(deactivate: Bool) {
        guard sessionActive else { return }
        AudioSessionOwner.shared.release(.recording, deactivate: deactivate)
        if deactivate { sessionActive = false }
    }
}

/// Reads the player's recording and runs `RecordingAnalyzer` over it, off the main thread: the channels mixed to mono,
/// a second at a time, the first ten minutes at most.
enum RecordingReader {
    static let maxSeconds = 600.0

    static func analyze(_ url: URL, beatsPerBar: Int, progress: @escaping @Sendable (Double) -> Void) async -> RecordingAnalysis? {
        await Task.detached(priority: .userInitiated) { () -> RecordingAnalysis? in
            guard let file = try? AVAudioFile(forReading: url) else { return nil }
            let format = file.processingFormat
            guard let analyzer = RecordingAnalyzer(sampleRate: format.sampleRate) else { return nil }
            let total = min(file.length, AVAudioFramePosition(RecordingReader.maxSeconds * format.sampleRate))
            let chunk = AVAudioFrameCount(max(4096, Int(format.sampleRate)))
            guard total > 0, let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: chunk) else { return nil }
            var read: AVAudioFramePosition = 0
            while read < total {
                if Task.isCancelled { return nil }
                let wanted = AVAudioFrameCount(min(AVAudioFramePosition(chunk), total - read))
                do { try file.read(into: buffer, frameCount: wanted) } catch { break }
                let frames = Int(buffer.frameLength)
                guard frames > 0, let channels = buffer.floatChannelData else { break }
                let count = Int(format.channelCount)
                var mono = [Float](repeating: 0, count: frames)
                for channel in 0..<count {
                    let samples = channels[channel]
                    for i in 0..<frames { mono[i] += samples[i] }
                }
                if count > 1 {
                    let scale = 1 / Float(count)
                    for i in 0..<frames { mono[i] *= scale }
                }
                analyzer.feed(mono)
                read += AVAudioFramePosition(frames)
                progress(Double(read) / Double(total))
            }
            if Task.isCancelled { return nil }
            return analyzer.finish(beatsPerBar: beatsPerBar)
        }.value
    }
}
