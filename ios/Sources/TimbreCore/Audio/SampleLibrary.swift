#if canImport(AVFoundation)
import AVFoundation
#endif
import Foundation

/// The recorded instruments bundled in `Samples/` (built by tools/build-ios-samples.py from CC0 libraries; sources in
/// docs/content/AUDIO-SOURCES.md): sparse key zones per instrument, AAC, mono, each with its measured fundamental so a
/// note can be pitched from the nearest zone by an exact ratio. Nothing is decoded until a note needs it; decoded
/// zones live in a size-capped cache (`capacityBytes`) that `purge` empties. Thread-safe: tones and the band render
/// on their own queues at once.
public final class SampleLibrary: @unchecked Sendable {
    /// The app bundle's library, or nil when the app ships without one (everything then synthesizes).
    public static let shared: SampleLibrary? = {
        guard let base = Bundle.main.resourceURL?.appendingPathComponent("Samples", isDirectory: true) else { return nil }
        return SampleLibrary(directory: base)
    }()

    public let directory: URL
    public let manifest: SampleManifest
    /// Most decoded audio kept at once (16-bit mono), least recently used first out.
    public var capacityBytes: Int {
        get { lock.lock(); defer { lock.unlock() }; return capacity }
        set { lock.lock(); capacity = max(1 << 20, newValue); evict(); lock.unlock() }
    }

    private let lock = NSLock()
    private var capacity = 40 << 20
    private var cache: [String: SampleBuffer] = [:]
    private var recency: [String] = []
    private var bytes = 0
    private var failed: Set<String> = []
    private let instruments: [String: SampledInstrument]
    private let byVoice: [String: String]

    /// Reads `directory/manifest.json`; nil when it is missing, unreadable or of another version.
    public convenience init?(directory: URL) {
        let url = directory.appendingPathComponent("manifest.json")
        guard let data = try? Data(contentsOf: url),
              let manifest = try? JSONDecoder().decode(SampleManifest.self, from: data),
              manifest.version == SampleManifest.supportedVersion else { return nil }
        self.init(directory: directory, manifest: manifest)
    }

    /// A library over `manifest`; `buffers` (by zone file) are installed up front, so tests need no files.
    init(directory: URL, manifest: SampleManifest, buffers: [String: SampleBuffer] = [:]) {
        self.directory = directory
        self.manifest = manifest
        var instruments: [String: SampledInstrument] = [:]
        var byVoice: [String: String] = [:]
        for entry in manifest.instruments {
            guard let instrument = SampledInstrument(entry) else { continue }
            instruments[entry.id] = instrument
            for voice in entry.voices { byVoice[voice] = entry.id }
        }
        self.instruments = instruments
        self.byVoice = byVoice
        for (file, buffer) in buffers {
            cache[file] = buffer
            recency.append(file)
            bytes += buffer.bytes
        }
    }

    /// The recorded set that plays `voice`, if there is one.
    public func instrument(for voice: InstrumentVoice) -> SampledInstrument? {
        byVoice[voice.rawValue].flatMap { instruments[$0] }
    }

    /// A set by its manifest id ("piano", "bass", "drums").
    public func instrument(id: String) -> SampledInstrument? { instruments[id] }

    /// Decodes the zones `voice` is most likely to play next (its main layer between `range`), off the caller's
    /// thread's critical path: call it from a background queue when an instrument is chosen.
    public func prewarm(_ voice: InstrumentVoice, range: ClosedRange<Int> = 36...84) {
        guard let instrument = instrument(for: voice) else { return }
        for zone in instrument.mainLayer where range.contains(zone.midi ?? 0) {
            _ = buffer(zone)
        }
    }

    /// Forgets every decoded zone (a memory warning); they decode again when next needed.
    public func purge() {
        lock.lock()
        let released = cache
        cache.removeAll(); recency.removeAll(); bytes = 0
        lock.unlock()
        withExtendedLifetime(released) {}
    }

    /// Decoded audio held now, in bytes.
    public var residentBytes: Int { lock.lock(); defer { lock.unlock() }; return bytes }

    /// Who recorded what, for the app's acknowledgements: one entry per library in use.
    public var credits: [SampleCredit] {
        manifest.sources.keys.sorted().compactMap { key -> SampleCredit? in
            guard let source = manifest.sources[key] else { return nil }
            let titles = manifest.instruments.filter { entry in entry.zones.contains { zone in zone.source == key } }.map(\.title)
            return SampleCredit(id: key, title: source.title, author: source.author, licence: source.licence,
                                link: URL(string: source.repo), licenceLink: URL(string: source.licenceURL), instruments: titles)
        }
    }

    /// The zone's decoded audio: from the cache, else decoded now (on the calling thread). Nil if it can't be read.
    func buffer(_ zone: SampleManifest.Zone) -> SampleBuffer? {
        lock.lock()
        if let hit = cache[zone.file] {
            if recency.last != zone.file, let index = recency.firstIndex(of: zone.file) {
                recency.remove(at: index); recency.append(zone.file)
            }
            lock.unlock()
            return hit
        }
        let known = failed.contains(zone.file)
        lock.unlock()
        guard !known else { return nil }
        let decoded = SampleBuffer.decode(directory.appendingPathComponent(zone.file), zone: zone)
        lock.lock()
        defer { lock.unlock() }
        guard let decoded else { failed.insert(zone.file); return nil }
        if let raced = cache[zone.file] { return raced }
        cache[zone.file] = decoded
        recency.append(zone.file)
        bytes += decoded.bytes
        evict()
        return decoded
    }

    /// Drops the least recently used zones while over capacity (always keeping the newest). Call under the lock.
    private func evict() {
        while bytes > capacity, recency.count > 1 {
            let oldest = recency.removeFirst()
            if let gone = cache.removeValue(forKey: oldest) { bytes -= gone.bytes }
        }
    }
}

/// One library's credit line.
public struct SampleCredit: Identifiable, Hashable, Sendable {
    public let id: String
    public let title: String
    public let author: String
    public let licence: String
    public let link: URL?
    public let licenceLink: URL?
    /// The app's instruments recorded from it.
    public let instruments: [String]
}

// MARK: - Manifest

/// `Samples/manifest.json`, as tools/build-ios-samples.py writes it.
public struct SampleManifest: Decodable, Sendable {
    public static let supportedVersion = 1

    public struct Source: Decodable, Sendable {
        public let title: String
        public let author: String
        public let licence: String
        public let licenceURL: String
        public let repo: String
        public let commit: String
    }

    /// One recording. `hz` is its measured fundamental at `rate`; `frames` its length as written (a decoder that
    /// returns more kept the encoder's priming, which is dropped); `mark` is the first frame at `markLevel` (a quarter
    /// of its peak), the build's check that encoding kept the attack in place; `gain` evens the attack loudness across
    /// the set at `velocity`; `loop` is a sustained note's loop of whole periods (frames).
    public struct Zone: Decodable, Sendable {
        public let file: String
        public let midi: Int?
        public let hz: Double?
        public let layer: String
        public let velocity: Double
        public let gain: Double
        public let frames: Int
        public let mark: Int
        public let markLevel: Double
        public let loop: [Int]?
        public let piece: String?
        public let rr: Int?
        public let source: String
    }

    public struct Instrument: Decodable, Sendable {
        public let id: String
        public let title: String
        public let voices: [String]
        /// "plucked", "struck", "sustained" or "drums".
        public let kind: String
        /// Seconds a note takes to stop at its end (a damped string, a lifted bow).
        public let release: Double
        /// Notes hold a steady pitch (no vibrato), so the set can sound the tuner's reference.
        public let steady: Bool
        /// MIDI notes the set may play (zones are pitched at most a few semitones beyond their own note).
        public let coverage: [Int]
        public let zones: [Zone]
    }

    public let version: Int
    public let sampleRate: Int
    public let sources: [String: Source]
    public let instruments: [Instrument]
}

// MARK: - Decoded audio

/// A zone's audio, mono 16-bit, with its leading decoder priming already dropped. Immutable once made.
final class SampleBuffer: @unchecked Sendable {
    let rate: Double
    let samples: [Int16]
    var count: Int { samples.count }
    var bytes: Int { samples.count * MemoryLayout<Int16>.size }

    init(rate: Double, samples: [Int16]) {
        self.rate = rate
        self.samples = samples
    }

    /// `values` (-1...1) at `rate`, as a test or an offline tool would hand them in.
    convenience init(rate: Double, values: [Float]) {
        self.init(rate: rate, samples: values.map { $0.isFinite ? Int16(max(-1, min(1, $0)) * 32767) : 0 })
    }

    /// Leading frames ffmpeg's AAC encoder adds (the build's encoder; recorded in each file's edit list).
    static let priming = 1024

    /// Decodes a file (channels averaged), without any encoder priming or end padding.
    static func decode(_ url: URL, zone: SampleManifest.Zone) -> SampleBuffer? {
        #if canImport(AVFoundation)
        guard let file = try? AVAudioFile(forReading: url, commonFormat: .pcmFormatFloat32, interleaved: false) else { return nil }
        let format = file.processingFormat
        let channels = Int(format.channelCount)
        guard channels > 0, format.sampleRate > 0 else { return nil }
        let chunk: AVAudioFrameCount = 16_384
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: chunk) else { return nil }
        var samples: [Int16] = []
        samples.reserveCapacity(max(0, Int(file.length)) + 4096)
        let scale = 32767 / Float(channels)
        while file.framePosition < file.length {
            do { try file.read(into: buffer, frameCount: chunk) } catch { break }
            let frames = Int(buffer.frameLength)
            guard frames > 0, let data = buffer.floatChannelData else { break }
            for index in 0..<frames {
                var sum: Float = 0
                for channel in 0..<channels { sum += data[channel][index] }
                let value = sum * scale
                samples.append(value.isFinite ? Int16(max(-32767, min(32767, value))) : 0)
            }
        }
        guard !samples.isEmpty else { return nil }
        // AAC carries the encoder's priming (1024 frames from the build's encoder) and pads its last packet (less than
        // 1024 frames). A decoder that honours the file's edit list returns the frames written (`zone.frames`), maybe
        // with that padding; one that doesn't returns the priming first, 1024 frames or more over: it goes, so attacks
        // land on the frame they were written for.
        if zone.frames > 0 && samples.count >= zone.frames + SampleBuffer.priming {
            samples.removeFirst(SampleBuffer.priming)
        }
        if zone.frames > 0 && samples.count > zone.frames { samples.removeLast(samples.count - zone.frames) }
        return SampleBuffer(rate: format.sampleRate, samples: samples)
        #else
        return nil
        #endif
    }
}
