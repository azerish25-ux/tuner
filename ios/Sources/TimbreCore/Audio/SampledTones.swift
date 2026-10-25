import Foundation

/// One recorded instrument of a `SampleLibrary`: its zones by pitch (and velocity layer), or a drum kit's pieces.
public struct SampledInstrument: Sendable {
    public enum Kind: String, Sendable { case plucked, struck, sustained, drums }

    /// The recordings of one sampled pitch, one per velocity layer.
    struct Pitched: Sendable {
        /// The zone's sounding pitch (fractional MIDI at A4 = 440 Hz, from its measured pitch).
        let midi: Double
        let layers: [SampleManifest.Zone]
    }

    /// A drum piece's velocity layers, each with its round robins.
    struct Piece: Sendable {
        let layers: [(velocity: Double, hits: [SampleManifest.Zone])]
    }

    public let id: String
    public let kind: Kind
    /// Seconds a note takes to stop at its end.
    public let release: Double
    /// Notes hold a steady pitch (no vibrato): the set can sound the tuner's reference.
    public let steady: Bool
    /// MIDI notes (at A4 = 440 Hz) the set plays; beyond them the synthesized voice takes over.
    public let coverage: ClosedRange<Int>
    /// Notes softer than the recorded layer are darkened, not only quieter (`SampleLibrary.addNote`).
    public let softFilter: Bool
    /// Paired courses: phrases sound two strings this many cents apart in all (0: one string).
    public let pairCents: Double
    let pitched: [Pitched]
    let pieces: [String: Piece]
    /// Each pitch's layer nearest a medium velocity: what `prewarm` decodes.
    let mainLayer: [SampleManifest.Zone]

    init?(_ entry: SampleManifest.Instrument) {
        guard let kind = Kind(rawValue: entry.kind), !entry.zones.isEmpty else { return nil }
        id = entry.id
        self.kind = kind
        release = max(0.005, entry.release)
        steady = entry.steady
        softFilter = (entry.softFilter ?? false) && kind == .plucked
        pairCents = max(0, min(5, entry.pairCents ?? 0))
        let low = entry.coverage.first ?? 0, high = entry.coverage.last ?? 127
        coverage = min(low, high)...max(low, high)
        if kind == .drums {
            var grouped: [String: [Double: [SampleManifest.Zone]]] = [:]
            for zone in entry.zones {
                guard let piece = zone.piece else { continue }
                grouped[piece, default: [:]][zone.velocity, default: []].append(zone)
            }
            var pieces: [String: Piece] = [:]
            for (name, layers) in grouped {
                let sorted = layers.keys.sorted().map { velocity in
                    (velocity: velocity, hits: (layers[velocity] ?? []).sorted { ($0.rr ?? 0) < ($1.rr ?? 0) })
                }
                pieces[name] = Piece(layers: sorted)
            }
            guard !pieces.isEmpty else { return nil }
            self.pieces = pieces
            pitched = []
            mainLayer = []
        } else {
            var grouped: [Int: [SampleManifest.Zone]] = [:]
            for zone in entry.zones {
                guard let midi = zone.midi, let hz = zone.hz, hz.isFinite, hz > 0 else { continue }
                grouped[midi, default: []].append(zone)
            }
            let pitched = grouped.keys.sorted().compactMap { key -> Pitched? in
                guard let layers = grouped[key], let hz = layers.first?.hz else { return nil }
                return Pitched(midi: PitchMath.midi(frequency: hz), layers: layers.sorted { $0.velocity < $1.velocity })
            }
            guard !pitched.isEmpty else { return nil }
            self.pitched = pitched
            pieces = [:]
            mainLayer = pitched.compactMap { group in
                group.layers.min { abs($0.velocity - SampledTones.velocity) < abs($1.velocity - SampledTones.velocity) }
            }
        }
    }

    /// The set plays `hz` (its note lies within `coverage`).
    public func covers(_ hz: Double) -> Bool {
        guard kind != .drums, hz.isFinite, hz > 0 else { return false }
        let midi = PitchMath.midi(frequency: hz)
        return midi >= Double(coverage.lowerBound) - 0.5 && midi <= Double(coverage.upperBound) + 0.5
    }

    /// The kit has this piece ("kick", "snare", "hat", "openhat", "ride", "crash").
    public func has(piece: String) -> Bool { pieces[piece] != nil }

    /// The zone to play `hz` from: the nearest sampled pitch, in the layer nearest `velocity`.
    func zone(for hz: Double, velocity: Double) -> SampleManifest.Zone? {
        let midi = PitchMath.midi(frequency: hz)
        guard let group = pitched.min(by: { abs($0.midi - midi) < abs($1.midi - midi) }) else { return nil }
        return group.layers.min { abs($0.velocity - velocity) < abs($1.velocity - velocity) }
    }

    func hit(_ piece: String, velocity: Double, variation: Int) -> SampleManifest.Zone? {
        guard let layers = pieces[piece]?.layers,
              let layer = layers.min(by: { abs($0.velocity - velocity) < abs($1.velocity - velocity) }),
              !layer.hits.isEmpty else { return nil }
        return layer.hits[abs(variation) % layer.hits.count]
    }
}

// MARK: - Playing notes

extension SampleLibrary {
    /// Adds one note of `instrument` at exactly `hz` into `out` from frame `start`, sounding `length` frames: the
    /// nearest zone read at the exact ratio hz / (its measured pitch), times its file rate over `rate`, so the
    /// note's pitch is the one asked for. The last `release` seconds (the instrument's own when nil) fade it out; a
    /// sustained note held past its recording loops its sustain. Loudness follows `velocity` (0...1), which also picks
    /// the layer, and `gain` scales it further; a `softFilter` set played softer than its layer is also darkened.
    /// `paired` sounds a course of two strings (`pairCents` apart, together: two copies of one recording a little
    /// apart in time would comb-filter it) on a set that has them; a reference never does, its pitch must stay single.
    /// False when the zone can't be read (nothing is written).
    @discardableResult
    public func addNote(_ instrument: SampledInstrument, hz: Double, velocity: Double, into out: inout [Float], start: Int,
                        length: Int, rate: Double, release: Double? = nil, gain: Double = 1, paired: Bool = false) -> Bool {
        guard hz.isFinite, hz > 0, rate > 0, let zone = instrument.zone(for: hz, velocity: velocity),
              let zoneHz = zone.hz, zoneHz > 0, let buffer = buffer(zone) else { return false }
        let ratio = hz / zoneHz * buffer.rate / rate
        let amplitude = Float(zone.gain * max(0, velocity) / max(0.05, zone.velocity) * gain)
        let fade = Int((release ?? instrument.release) * rate)
        var loop: (start: Double, end: Double)?
        if instrument.kind == .sustained, let points = zone.loop, points.count == 2, points[1] > points[0] + 64,
           points[1] <= buffer.count {
            loop = (Double(points[0]), Double(points[1]))
        }
        let smoothing = instrument.softFilter ? Self.softening(velocity: velocity, recorded: zone.velocity, rate: rate) : 0
        if paired && instrument.pairCents > 0 {
            let spread = pow(2, instrument.pairCents / 2400)
            Self.play(buffer, ratio: ratio * spread, amplitude: amplitude * 0.55, loop: loop, into: &out, start: start,
                      length: length, fade: fade, smoothing: smoothing)
            Self.play(buffer, ratio: ratio / spread, amplitude: amplitude * 0.55, loop: loop, into: &out, start: start,
                      length: length, fade: fade, smoothing: smoothing)
        } else {
            Self.play(buffer, ratio: ratio, amplitude: amplitude, loop: loop, into: &out, start: start, length: length, fade: fade,
                      smoothing: smoothing)
        }
        return true
    }

    /// The one-pole low-pass coefficient for a note `velocity` against its layer's `recorded` one: none at the
    /// recorded touch or harder, then a cutoff falling from 14 kHz towards 700 Hz as the touch softens (a pluck
    /// that gentle excites fewer overtones). Zero means unfiltered.
    static func softening(velocity: Double, recorded: Double, rate: Double) -> Float {
        let touch = max(0, velocity) / max(0.05, recorded)
        guard touch < 0.97, rate > 0 else { return 0 }
        let cutoff = 700 * pow(14_000.0 / 700, min(1, touch))
        return Float(1 - exp(-2 * Double.pi * min(cutoff, 0.45 * rate) / rate))
    }

    /// Adds one hit of a kit piece at its recorded pitch: the layer nearest `velocity`, `variation` choosing among its
    /// round robins, `gain` scaling it. False when the kit has no such piece or it can't be read.
    @discardableResult
    public func addHit(_ kit: SampledInstrument, piece: String, velocity: Double, variation: Int, into out: inout [Float],
                       start: Int, rate: Double, gain: Double = 1) -> Bool {
        guard rate > 0, let zone = kit.hit(piece, velocity: velocity, variation: variation), let buffer = buffer(zone) else { return false }
        let amplitude = Float(zone.gain * max(0, velocity) / max(0.05, zone.velocity) * gain)
        Self.play(buffer, ratio: buffer.rate / rate, amplitude: amplitude, loop: nil, into: &out, start: start,
                  length: Int(Double(buffer.count) * rate / buffer.rate) + 1, fade: Int(0.004 * rate))
        return true
    }

    /// Reads `buffer` at `ratio` frames per output frame (4-point cubic interpolation) into out[start...], for at most
    /// `length` frames, the last `fade` of them faded with a raised cosine. A loop crossfades its last 80 ms into the
    /// stretch before its start, so the jump back is seamless. `smoothing` (0...1, 0 off) runs the note through a
    /// one-pole low-pass.
    static func play(_ buffer: SampleBuffer, ratio: Double, amplitude: Float, loop: (start: Double, end: Double)?,
                     into out: inout [Float], start: Int, length: Int, fade: Int, smoothing: Float = 0) {
        guard start >= 0, start < out.count, ratio > 0, ratio.isFinite else { return }
        let count = min(length, out.count - start)
        guard count > 0 else { return }
        let fadeFrames = max(0, min(fade, count / 2))
        let scale = amplitude / 32767
        buffer.samples.withUnsafeBufferPointer { source in
            out.withUnsafeMutableBufferPointer { target in
                let last = Double(source.count - 1)
                var span = 0.0, crossfade = 0.0, fadeIn = 0.0
                if let loop {
                    span = loop.end - loop.start
                    crossfade = min(0.08 * buffer.rate, span / 2, loop.start)
                    fadeIn = loop.end - crossfade
                }
                var position = 0.0
                var low: Float = 0
                for n in 0..<count {
                    if let loop, position >= loop.end { position -= span }
                    if loop == nil && position >= last { break }
                    var value = cubic(source, position)
                    if loop != nil, crossfade > 0, position > fadeIn {
                        let w = Float((position - fadeIn) / crossfade)
                        value = value * (1 - w) + cubic(source, position - span) * w
                    }
                    if smoothing > 0 {
                        low += smoothing * (value - low)
                        value = low
                    }
                    var envelope: Float = 1
                    if fadeFrames > 0 && n >= count - fadeFrames {
                        let x = Double(n - (count - fadeFrames)) / Double(fadeFrames)
                        envelope = Float(0.5 + 0.5 * cos(Double.pi * x))
                    }
                    target[start + n] += value * scale * envelope
                    position += ratio
                }
            }
        }
    }

    /// Catmull-Rom between source[i] and source[i + 1] (silence beyond either end), in 16-bit units.
    @inline(__always)
    private static func cubic(_ source: UnsafeBufferPointer<Int16>, _ position: Double) -> Float {
        let i = Int(position)
        let t = Float(position - Double(i))
        let n = source.count
        let y0: Float = i >= 1 && i - 1 < n ? Float(source[i - 1]) : 0
        let y1: Float = i >= 0 && i < n ? Float(source[i]) : 0
        let y2: Float = i + 1 >= 0 && i + 1 < n ? Float(source[i + 1]) : 0
        let y3: Float = i + 2 >= 0 && i + 2 < n ? Float(source[i + 2]) : 0
        let c1 = 0.5 * (y2 - y0)
        let c2 = y0 - 2.5 * y1 + 2 * y2 - 0.5 * y3
        let c3 = 0.5 * (y3 - y0) + 1.5 * (y1 - y2)
        return ((c3 * t + c2) * t + c1) * t + y1
    }
}

// MARK: - Tones from samples

/// `ToneRequest`s rendered from recorded instruments: the same timing, strum and reference rules as `ToneSynth`
/// (a reference re-plucks every `ToneSynth.repluckInterval`; a held one loops whole periods), the same peak levels,
/// each note pitched exactly. Nil whenever the recording can't serve the request (no set for the voice, a note out of
/// its range, a bowed reference from a vibrato recording, an unreadable file): the caller then synthesizes.
public enum SampledTones {
    /// The velocity "Hear it", chords and references play at.
    public static let velocity = 0.75

    public static func render(_ request: ToneRequest, library: SampleLibrary?) -> ToneClip? {
        guard let library, let instrument = library.instrument(for: request.voice), instrument.kind != .drums,
              !request.frequencies.isEmpty, request.frequencies.allSatisfy({ instrument.covers($0) }) else { return nil }
        let rate = Double(max(1, request.sampleRate))
        switch request.kind {
        case let .phrase(together, noteMs, gapMs):
            guard var out = phrase(request.frequencies, together: together, noteMs: noteMs, gapMs: gapMs,
                                   instrument: instrument, library: library, rate: rate,
                                   strummed: StrumFeel.strums(request.voice)) else { return nil }
            return ToneClip(frames: finish(&out, instrument: instrument, rate: rate, fadeEnd: true), sampleRate: request.sampleRate)
        case let .reference(durationMs):
            guard let hz = request.frequencies.first,
                  let rendered = reference(hz, durationMs: durationMs, voice: request.voice, instrument: instrument,
                                           library: library, rate: rate) else { return nil }
            return ToneClip(frames: rendered.frames, sampleRate: request.sampleRate, loopStart: rendered.loopStart)
        }
    }

    /// As `ToneSynth.phrase`: notes in turn (`noteMs` each, `gapMs` of silence after) or together for `noteMs`. A
    /// fretted voice's chord (`strummed`) is a relaxed downstroke across its strings (`StrumFeel`: the pick's timing
    /// and weight string by string); other plucked chords roll low to high `ToneSynth.strumSpread` apart, sustained
    /// ones enter almost at once, with the same small human jitter. Paired courses sound as pairs.
    static func phrase(_ frequencies: [Double], together: Bool, noteMs: Int, gapMs: Int, instrument: SampledInstrument,
                       library: SampleLibrary, rate: Double, strummed: Bool = false) -> [Float]? {
        let note = max(1, Int(Double(max(1, noteMs)) * rate / 1000))
        let step = Int(Double(max(1, noteMs) + max(0, gapMs)) * rate / 1000)
        let total = together ? note : max(1, step * frequencies.count)
        var out = [Float](repeating: 0, count: total)
        if together {
            let order = frequencies.indices.sorted { frequencies[$0] < frequencies[$1] }
            if strummed && instrument.kind == .plucked {
                let span = StrumFeel.span(strings: order.count)
                let hits = StrumFeel.hits(strings: order.count, stroke: .down, span: span, velocity: velocity,
                                          seed: 0x5EED_0000 &+ UInt64(order.count))
                for hit in hits {
                    let start = max(0, Int(hit.delay * rate))
                    guard start < total else { continue }
                    guard library.addNote(instrument, hz: frequencies[order[hit.string]], velocity: hit.velocity, into: &out,
                                          start: start, length: total - start, rate: rate, paired: true) else { return nil }
                }
                return out
            }
            let spread = instrument.kind == .sustained ? 0.012 : ToneSynth.strumSpread
            var feel = ToneNoise(seed: 0x5EED_0000 &+ UInt64(order.count))
            for (rank, index) in order.enumerated() {
                let jitter = rank == 0 ? 0 : 0.004 * Double(feel.next())
                let start = max(0, Int((Double(rank) * spread + jitter) * rate))
                let strength = velocity * (1 - 0.03 * Double(rank) + 0.04 * Double(feel.next()))
                guard start < total else { continue }
                guard library.addNote(instrument, hz: frequencies[index], velocity: strength, into: &out, start: start,
                                      length: total - start, rate: rate, paired: true) else { return nil }
            }
        } else {
            for (index, hz) in frequencies.enumerated() {
                guard library.addNote(instrument, hz: hz, velocity: velocity, into: &out, start: index * step,
                                      length: note, rate: rate, paired: true) else { return nil }
            }
        }
        return out
    }

    /// The tuner's reference at exactly `hz`, as `ToneSynth.reference`: up to 8 s rendered whole (a plucked or struck
    /// note sounding again every `ToneSynth.repluckInterval`); longer or 0 (until stopped) one loopable cycle. Sustained
    /// sets play it only when their recordings hold a steady pitch (`steady`), else nil.
    static func reference(_ hz: Double, durationMs: Int, voice: InstrumentVoice, instrument: SampledInstrument,
                          library: SampleLibrary, rate: Double) -> (frames: [Float], loopStart: Int?)? {
        let bounded = durationMs > 0 && durationMs <= 8000
        let length = max(1, Int(Double(max(1, durationMs)) * rate / 1000))
        if instrument.kind == .sustained {
            guard instrument.steady else { return nil }
            if bounded {
                var out = [Float](repeating: 0, count: length)
                guard library.addNote(instrument, hz: hz, velocity: velocity, into: &out, start: 0, length: length, rate: rate) else { return nil }
                return (finish(&out, instrument: instrument, rate: rate, fadeEnd: true), nil)
            }
            // A second to settle, then about two seconds of whole periods that loop back onto it.
            let settle = Int(rate)
            let periods = max(1, (2 * hz).rounded())
            let loop = max(1, Int((periods * rate / max(1, hz)).rounded()))
            var out = [Float](repeating: 0, count: settle + loop + Int(0.4 * rate))
            guard library.addNote(instrument, hz: hz, velocity: velocity, into: &out, start: 0, length: out.count,
                                  rate: rate, release: 0) else { return nil }
            out.removeLast(out.count - (settle + loop))
            let crossfade = min(Int(0.05 * rate), settle, loop)
            for j in 0..<crossfade {
                let w = Float(j) / Float(crossfade)
                let index = settle + loop - crossfade + j
                out[index] = out[index] * (1 - w) + out[settle - crossfade + j] * w
            }
            return (finish(&out, instrument: instrument, rate: rate, fadeEnd: false), settle)
        }
        let cycle = max(1, Int(ToneSynth.repluckInterval(hz, voice: voice) * rate))
        let total = bounded ? length : cycle
        var out = [Float](repeating: 0, count: total)
        var start = 0
        while start < total {
            // No new pluck in the last third of a second: it would be cut off at once.
            if start > 0 && total - start < Int(0.35 * rate) { break }
            guard library.addNote(instrument, hz: hz, velocity: velocity, into: &out, start: start,
                                  length: min(cycle, total - start), rate: rate) else { return nil }
            start += cycle
        }
        return (finish(&out, instrument: instrument, rate: rate, fadeEnd: true), bounded ? nil : 0)
    }

    /// Closes the last 4 ms (`fadeEnd`; not on a loop) and brings the clip to `ToneSynth`'s peak for its kind, so a
    /// recorded voice sits at the level the synthesized one did.
    static func finish(_ out: inout [Float], instrument: SampledInstrument, rate: Double, fadeEnd: Bool) -> [Float] {
        if fadeEnd {
            let fade = min(out.count, max(1, Int(0.004 * rate)))
            for j in 0..<fade { out[out.count - fade + j] *= Float(fade - 1 - j) / Float(fade) }
        }
        var peak: Float = 0
        for value in out where value.isFinite { peak = max(peak, abs(value)) }
        let target = instrument.kind == .sustained ? ToneSynth.sustainedPeak : ToneSynth.pluckedPeak
        let scale = peak > 0 ? target / peak : 0
        return out.map { $0.isFinite ? $0 * scale : 0 }
    }
}

extension ToneSynth {
    /// `request` from recorded samples when `samples` has a set for its voice that covers every note (see
    /// `SampledTones`), else synthesized as before. Off the main thread and the audio callback, like `render(_:)`.
    public static func render(_ request: ToneRequest, samples: SampleLibrary?) -> ToneClip {
        SampledTones.render(request, library: samples) ?? render(request)
    }
}
