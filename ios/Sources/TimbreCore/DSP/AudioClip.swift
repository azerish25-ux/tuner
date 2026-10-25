import AVFoundation
import Foundation

/// A recording as the analysis hears it: mono samples at the recording's own rate. It stands in for the microphone:
/// the real-world corpus, and any test that wants a take played rather than described, hand its audio over in the
/// buffers the microphone tap delivers (`tapFrames`), so a recording runs through exactly the path a live take does
/// (`LessonListening`, `StrokeChords`, `PolyTuner`, the pitch detector) without the audio engine.
public struct AudioClip: Sendable {
    /// Frames in each buffer the microphone tap delivers to the analysis.
    public static let tapFrames = 512

    public let samples: [Float]
    public let sampleRate: Double

    public init(samples: [Float], sampleRate: Double) {
        self.samples = samples
        self.sampleRate = sampleRate
    }

    /// Seconds of audio.
    public var duration: Double { sampleRate > 0 ? Double(samples.count) / sampleRate : 0 }

    /// Why a file couldn't be read as a clip.
    public struct ReadError: Error, CustomStringConvertible {
        public let description: String
    }

    /// Any file `AVAudioFile` reads (WAV, CAF, AIFF, M4A), its channels mixed down to mono, at its own rate.
    public init(contentsOf url: URL) throws {
        let file = try AVAudioFile(forReading: url)
        let format = file.processingFormat
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(file.length)) else {
            throw ReadError(description: "\(url.lastPathComponent): no buffer for \(file.length) frames")
        }
        try file.read(into: buffer)
        guard let channels = buffer.floatChannelData else { throw ReadError(description: "\(url.lastPathComponent): not float audio") }
        let frames = Int(buffer.frameLength), count = Int(format.channelCount)
        var mono = [Float](repeating: 0, count: frames)
        if count > 0 {
            for channel in 0..<count {
                let data = channels[channel]
                for i in 0..<frames { mono[i] += data[i] / Float(count) }
            }
        }
        self.init(samples: mono, sampleRate: format.sampleRate)
    }

    /// The clip in consecutive buffers of `frames` samples (the last one shorter), as the tap hands them over.
    public func buffers(of frames: Int = AudioClip.tapFrames) -> [[Float]] {
        let size = max(1, frames)
        return stride(from: 0, to: samples.count, by: size).map { start in
            Array(samples[start..<min(samples.count, start + size)])
        }
    }

    /// Plays the clip through `consume` buffer by buffer (`buffers(of:)`), each with the time its last sample ends,
    /// in seconds from the start.
    public func play(frames: Int = AudioClip.tapFrames, into consume: ([Float], Double) -> Void) {
        var fed = 0
        for buffer in buffers(of: frames) {
            fed += buffer.count
            consume(buffer, Double(fed) / max(1, sampleRate))
        }
    }

    /// The events `listening` hears in the whole clip, fed as the tap feeds the analysis.
    public func events(through listening: LessonListening, frames: Int = AudioClip.tapFrames) -> [LessonListening.Event] {
        var events: [LessonListening.Event] = []
        play(frames: frames) { buffer, _ in events += listening.feed(buffer, rate: sampleRate) }
        return events
    }

    /// The strokes `StrokeChords` reads in the whole clip, fed as the tap feeds the analysis.
    public func strokes(frames: Int = AudioClip.tapFrames) -> [StrokeChords.Stroke] {
        events(through: LessonListening(chords: false, strokes: true), frames: frames).compactMap { event in
            if case let .stroke(stroke) = event { return stroke }
            return nil
        }
    }
}
