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
/// one pauses at its last reported position and waits for the next play request; after a call it plays on by itself
/// when iOS says it should and the user has not paused or stopped it.
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
    /// Removes its observers when the player goes; it isn't main-actor state, so letting go of it never needs the
    /// main actor.
    private let observers = ObserverBag()
    /// A call (or Siri, an alarm) paused the recording while it played: it plays on if the interruption ends with
    /// "should resume".
    private var resumeAfterInterruption = false
    /// This player activated the session and hasn't turned it off since (a pause leaves it active).
    private var sessionActive = false
    private var activationsPending = 0
    /// Desired transport state drives Play/Pause even while the hardware is still starting. isPlaying drives clocks.
    @Published private(set) var playbackRequested = false
    private var deactivateWhenIdle = true
    private let reserveSession: @MainActor () -> Void
    private let activateSession: @MainActor () async throws -> Void
    private let releaseOwnedSession: @MainActor (Bool) -> Void
    private let preparePlaybackOverride: (() throws -> Void)?

    init(activateSession: @escaping @MainActor () async throws -> Void = {
             try await AudioSessionOwner.shared.activateInBackground(.recording)
         }, releaseSession: @escaping @MainActor (Bool) -> Void = {
             AudioSessionOwner.shared.release(.recording, deactivate: $0)
         }, preparePlayback: (() throws -> Void)? = nil,
         reserveSession: @escaping @MainActor () -> Void = { AudioSessionOwner.shared.reserveIntent(.recording) }) {
        self.reserveSession = reserveSession
        self.activateSession = activateSession
        self.releaseOwnedSession = releaseSession
        self.preparePlaybackOverride = preparePlayback
        engine.attach(node)
        engine.attach(timePitch)
        observers.add(NotificationCenter.default.addObserver(forName: .AVAudioEngineConfigurationChange, object: engine, queue: .main) { [weak self] _ in
            // The session changed under the engine (another engine took it, a route changed): it has stopped.
            Task { @MainActor in self?.engineStopped() }
        })
        observers.add(NotificationCenter.default.addObserver(forName: AVAudioSession.interruptionNotification, object: nil, queue: .main) { [weak self] notification in
            // A notification for the app having been suspended isn't answered (`SessionInterruption`).
            guard let interruption = SessionInterruption(notification) else { return }
            Task { @MainActor in
                guard let self else { return }
                switch interruption {
                case .began:
                    self.resumeAfterInterruption = self.isPlaying || self.playbackRequested
                    self.pauseTransport()
                case .ended(let shouldResume):
                    let resume = self.resumeAfterInterruption && shouldResume
                    self.resumeAfterInterruption = false
                    if resume && !self.isPlaying { self.play() }
                }
            }
        })
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
    @discardableResult
    func play(from time: Double? = nil) -> AudioReadiness {
        guard let file, duration > 0 else { return .failed() }
        let requested = max(0, min(duration - 0.05, time ?? resumeAt))
        let start = requested >= duration - 0.1 ? 0 : requested
        resumeAfterInterruption = false
        generation += 1
        let token = generation
        playbackRequested = true
        reserveSession()
        sessionActive = true
        resumeAt = start
        deactivateWhenIdle = true
        activationsPending += 1
        return AudioReadiness(task: Task { @MainActor in
            defer {
                self.activationsPending -= 1
                if self.activationsPending == 0 && !self.playbackRequested {
                    self.releaseSession(deactivate: self.deactivateWhenIdle)
                }
            }
            guard self.generation == token, self.playbackRequested else { return false }
            guard !Task.isCancelled else { self.playbackRequested = false; return false }
            do {
                // A failed activation can still have changed the category; its reservation needs cleanup too.
                self.sessionActive = true
                try await self.activateSession()
                guard self.generation == token, self.playbackRequested else { return false }
                guard !Task.isCancelled else { self.pause(); return false }
                if let prepare = self.preparePlaybackOverride {
                    try prepare()
                } else {
                    if !self.engine.isRunning {
                        self.engine.disconnectNodeOutput(self.node)
                        self.engine.disconnectNodeOutput(self.timePitch)
                        self.engine.connect(self.node, to: self.timePitch, format: file.processingFormat)
                        self.engine.connect(self.timePitch, to: self.engine.mainMixerNode, format: file.processingFormat)
                        self.engine.prepare()
                        try self.engine.start()
                    }
                    self.schedule(file, from: start)
                    self.node.play()
                }
                self.isPlaying = true
                self.lastTime = start
                return true
            } catch {
                guard self.generation == token else { return false }
                self.playbackRequested = self.isPlaying
                // Hardware can be temporarily unavailable; the next explicit play request may try again.
                return false
            }
        }, current: { [weak self] in
            guard let self else { return false }
            return self.generation == token && self.playbackRequested && self.isPlaying
        })
    }

    func pause() {
        resumeAfterInterruption = false
        pauseTransport()
    }

    private func pauseTransport() {
        guard isPlaying || playbackRequested else { return }
        // A seek/play request already records its target before activation. Pausing during that activation keeps
        // the requested target rather than overwriting it with the old node's still-playing position.
        if activationsPending == 0 { resumeAt = currentTime() }
        generation += 1
        playbackRequested = false
        deactivateWhenIdle = false
        node.stop()
        // The engine lets the session go while paused, so the lessons' microphone can take it (it stays active).
        engine.stop()
        if activationsPending == 0 { releaseSession(deactivate: false) }
        isPlaying = false
    }

    func toggle() {
        resumeAfterInterruption = false
        if isPlaying || playbackRequested { pause() } else { play() }
    }

    func seek(to time: Double) {
        let target = max(0, min(duration, time))
        if isPlaying || playbackRequested {
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
        playbackRequested = false
        deactivateWhenIdle = true
        resumeAfterInterruption = false
        node.stop()
        if engine.isRunning { engine.stop() }
        isPlaying = false
        resumeAt = 0
        lastTime = 0
        if activationsPending == 0 { releaseSession(deactivate: true) }
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
        playbackRequested = false
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
        playbackRequested = false
        if activationsPending == 0 { releaseSession(deactivate: false) }
    }

    /// This player's engine no longer needs the session. `deactivate`: it is turned off too (off the main thread, once
    /// nothing else in the app holds it); otherwise it stays active for whoever plays next.
    private func releaseSession(deactivate: Bool) {
        guard sessionActive else { return }
        releaseOwnedSession(deactivate)
        if deactivate { sessionActive = false }
    }
}

/// Notification observers removed together when their owner goes, from whatever thread lets go of it last.
private final class ObserverBag: @unchecked Sendable {
    private let lock = NSLock()
    private var tokens: [NSObjectProtocol] = []

    func add(_ token: NSObjectProtocol) {
        lock.lock(); tokens.append(token); lock.unlock()
    }

    deinit {
        for token in tokens { NotificationCenter.default.removeObserver(token) }
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
