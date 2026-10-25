import Foundation

// MARK: - Key and capo

/// How a chart is shown to the player: moved to another key (`transpose`, the key the song sounds in) and written
/// for the capo they use (`capo`). A chart's own `{capo}` means its chords are shapes played with that capo on, so the
/// shape shown is the written chord moved by the chart's capo plus the transposition, less the player's capo.
public struct ChartTransform: Equatable, Hashable, Sendable {
    /// Semitones the song is moved from the chart's key (−11…11).
    public var transpose: Int
    /// The capo the player puts on.
    public var capo: Int
    /// The capo the chart was written for.
    public let chartCapo: Int

    public init(transpose: Int = 0, capo: Int? = nil, chartCapo: Int = 0) {
        self.transpose = transpose
        self.chartCapo = max(0, chartCapo)
        self.capo = max(0, capo ?? chartCapo)
    }

    /// Semitones from a written chord to the shape shown.
    public var shapeShift: Int { chartCapo + transpose - capo }
    /// Semitones from a written chord to the chord that sounds.
    public var soundingShift: Int { chartCapo + transpose }

    /// The key the song sounds in, as a key name ("A", "F#m"), when the chart's key is known.
    public func soundingKey(of chart: ChordChart) -> (tonic: Int, minor: Bool)? {
        chart.resolvedKey.map { (tonic: (($0.tonic + soundingShift) % 12 + 12) % 12, minor: $0.minor) }
    }

    /// The key the shapes are in (what the player's hands play), when the chart's key is known.
    public func shapeKey(of chart: ChordChart) -> (tonic: Int, minor: Bool)? {
        chart.resolvedKey.map { (tonic: (($0.tonic + shapeShift) % 12 + 12) % 12, minor: $0.minor) }
    }

    /// A written chord as the player reads it: moved by `shapeShift` and spelled for the key the shapes are in (flats
    /// in F, B♭, E♭…), or the usual spelling of each root when the key isn't known. Unchanged when nothing moves, and
    /// annotations ("N.C.", "*Riff") are never touched.
    public func shape(_ written: String, in chart: ChordChart) -> String {
        shape(written, names: names(for: chart))
    }

    public func shape(_ written: String, names: [String]) -> String {
        guard ((shapeShift % 12) + 12) % 12 != 0, let symbol = ChordSymbol(written) else { return written }
        return symbol.transposed(by: shapeShift, names: names).text
    }

    /// The spelling table for the shapes of `chart`.
    public func names(for chart: ChordChart) -> [String] {
        guard let key = shapeKey(of: chart) else { return ChordSpelling.commonNames }
        return ChordSpelling.prefersFlats(tonic: key.tonic, minor: key.minor) ? ChordSpelling.flatNames : ChordSpelling.sharpNames
    }

    /// The parsed shape of a written chord (nil for an annotation).
    public func shapeSymbol(_ written: String, names: [String]) -> ChordSymbol? {
        guard let symbol = ChordSymbol(written) else { return nil }
        return symbol.transposed(by: shapeShift, names: names)
    }
}

/// Where a capo makes a chart easiest on a guitar: every chord counted by how often it is played, an open-position
/// shape costing nothing and a barre chord one; capos higher up the neck cost a little more, so a lower one wins a tie.
public enum CapoAdvisor {
    /// The easiest capo from `range` for the chords that sound (`sounding`, in the order played): nil when no capo
    /// beats playing without one (or the current capo) by at least one barre chord.
    public static func easiest(sounding: [ChordSymbol], current: Int = 0, range: ClosedRange<Int> = 0...7) -> Int? {
        guard !sounding.isEmpty else { return nil }
        let costs = range.map { (capo: $0, cost: cost(sounding, capo: $0)) }
        guard let best = costs.min(by: { $0.cost < $1.cost }) else { return nil }
        let now = cost(sounding, capo: current)
        return best.capo != current && now - best.cost >= 0.9 ? best.capo : nil
    }

    /// Barre chords to play with the capo at `capo`, weighted by use, plus a small cost per fret of capo.
    public static func cost(_ sounding: [ChordSymbol], capo: Int) -> Double {
        var counts: [String: Int] = [:]
        var symbols: [String: ChordSymbol] = [:]
        for chord in sounding {
            counts[chord.text, default: 0] += 1
            symbols[chord.text] = chord
        }
        let total = Double(sounding.count)
        var barres = 0.0
        for (text, count) in counts {
            guard let chord = symbols[text], !hasOpenShape(chord, capo: capo) else { continue }
            // Each distinct barre chord counts once, plus a share for how much of the song it fills.
            barres += 1 + Double(count) / total
        }
        return barres + 0.08 * Double(capo)
    }

    /// The shape under the capo has an open-position voicing in the guitar library (`ChordLibrary.openShapes`).
    static func hasOpenShape(_ chord: ChordSymbol, capo: Int) -> Bool {
        let pitch = ((chord.root - capo) % 12 + 12) % 12
        return !(ChordLibrary.openShapes[chord.formulaId]?[pitch] ?? []).isEmpty
    }
}

// MARK: - Following the recording

/// When each chord of a chart changes in a recording: one time per entry of `ChordChart.chordSequence`, in seconds
/// from the recording's start, rising.
public struct ChartTimeline: Equatable, Sendable {
    public let times: [Double]

    public init(times: [Double]) {
        // Kept rising: a time before the one ahead of it moves up to it.
        var rising: [Double] = []
        for time in times where time.isFinite {
            rising.append(max(time, rising.last ?? -Double.infinity))
        }
        self.times = rising
    }

    /// The chord sounding at `time`: the last change at or before it; nil before the first change.
    public func index(at time: Double) -> Int? {
        guard let first = times.first, time >= first else { return nil }
        var low = 0, high = times.count - 1
        while low < high {
            let mid = (low + high + 1) / 2
            if times[mid] <= time { low = mid } else { high = mid - 1 }
        }
        return low
    }

    /// How far through chord `index` the time is, 0…1 (the last chord runs `tail` seconds).
    public func progress(of index: Int, at time: Double, tail: Double = 2) -> Double {
        guard times.indices.contains(index) else { return 0 }
        let start = times[index]
        let end = index + 1 < times.count ? times[index + 1] : start + tail
        guard end > start else { return 1 }
        return min(1, max(0, (time - start) / (end - start)))
    }

    /// Steady timing with no recording: each chord one bar (`barsPerChord`) at `bpm`, from `start`.
    public static func steady(count: Int, bpm: Double, beatsPerBar: Int, barsPerChord: Double = 1, start: Double = 0) -> ChartTimeline {
        let bar = 60 / max(20, bpm) * Double(max(1, beatsPerBar)) * max(0.25, barsPerChord)
        return ChartTimeline(times: (0..<max(0, count)).map { start + Double($0) * bar })
    }

    /// The times of a recording synced partway: those known, then the rest spaced at the pace of the last few
    /// (a bar at `bpm` when fewer than two are known).
    public static func extended(_ known: [Double], count: Int, bpm: Double, beatsPerBar: Int) -> ChartTimeline {
        guard count > known.count else { return ChartTimeline(times: Array(known.prefix(count))) }
        var times = known
        let recent = Array(known.suffix(5))
        let gap: Double
        if recent.count >= 2, let first = recent.first, let last = recent.last, last > first {
            gap = (last - first) / Double(recent.count - 1)
        } else {
            gap = 60 / max(20, bpm) * Double(max(1, beatsPerBar))
        }
        var next = (known.last ?? 0) + (known.isEmpty ? 0 : gap)
        while times.count < count {
            times.append(next)
            next += gap
        }
        return ChartTimeline(times: times)
    }
}

/// Syncing a chart to a recording by tapping along: one tap on each chord change, in order, while it plays. Taps
/// closer than `minimumGap` to the one before are a double tap and ignored; a tap can be taken back.
public struct TapAlong: Equatable, Sendable {
    /// Chords to time.
    public let count: Int
    public private(set) var times: [Double]
    public static let minimumGap = 0.12

    /// Starting at chord `from`: the times before it are kept, later ones are timed again.
    public init(count: Int, keeping existing: [Double] = [], from start: Int = 0) {
        self.count = max(0, count)
        times = Array(existing.prefix(max(0, min(start, count))))
    }

    /// The chord the next tap times.
    public var next: Int { times.count }
    public var isFinished: Bool { times.count >= count }

    /// Records a tap at `time` (seconds into the recording); false when it was ignored.
    @discardableResult public mutating func tap(at time: Double) -> Bool {
        guard !isFinished, time.isFinite, time >= 0 else { return false }
        if let last = times.last, time < last + Self.minimumGap { return false }
        times.append(time)
        return true
    }

    public mutating func undo() {
        if !times.isEmpty { times.removeLast() }
    }
}

// MARK: - Practising a chart

/// What a chart's Practice drills: its chords one at a time, then its progression strummed in time.
public enum ChartPractice {
    /// The chords to play one by one: the distinct shapes, in the order they first come, at most `limit`.
    public static func drill(_ chart: ChordChart, transform: ChartTransform, limit: Int = 6) -> [ChordSymbol] {
        let names = transform.names(for: chart)
        var seen = Set<String>()
        var out: [ChordSymbol] = []
        for ref in chart.chordSequence {
            guard let shape = transform.shapeSymbol(ref.chord, names: names), seen.insert(shape.text).inserted else { continue }
            out.append(shape)
            if out.count >= limit { break }
        }
        return out
    }

    /// The progression to strum: the chart's chords in order, one bar each, a chord repeated straight after itself
    /// held for more bars, up to `maxBars` bars (a line's worth of the song, the way the song starts).
    public static func progression(_ chart: ChordChart, transform: ChartTransform, maxBars: Int = 8) -> [(chord: ChordSymbol, bars: Int)] {
        let names = transform.names(for: chart)
        var out: [(chord: ChordSymbol, bars: Int)] = []
        var total = 0
        for ref in chart.chordSequence {
            guard total < maxBars, let shape = transform.shapeSymbol(ref.chord, names: names) else { continue }
            if let last = out.last, last.chord == shape {
                out[out.count - 1].bars += 1
            } else {
                out.append((chord: shape, bars: 1))
            }
            total += 1
        }
        return out
    }

    /// A comfortable practice tempo: three quarters of the song's, between 60 and 100 BPM (80 without a tempo).
    public static func tempo(for chart: ChordChart) -> Double {
        guard let bpm = chart.tempo else { return 80 }
        return min(100, max(60, (bpm * 0.75).rounded()))
    }

    /// A lesson chord for a shape on strings tuned to `openMidi` (lowest first): the best voicing the chord library
    /// has (curated open and barre shapes on guitar, playable shapes found for other tunings), with its fingering and
    /// the fret its box starts at. Nil when no playable shape exists.
    public static func spec(for chord: ChordSymbol, openMidi: [Int]) -> ChordSpec? {
        guard !openMidi.isEmpty else { return nil }
        let formula = ChordFormula.byId(chord.formulaId)
        guard let shape = ChordLibrary.voicings(root: chord.root, formula: formula, openMidi: openMidi, limit: 1).first else { return nil }
        return ChordSpec(name: chord.text, root: chord.root, quality: formula.id, frets: shape.frets.map { $0 ?? -1 },
                         fingers: shape.fingers, baseFret: shape.highestFret <= 4 ? nil : shape.lowestFret)
    }
}

// MARK: - What's free

/// Your songs on the free plan and with Timbre Pro, in the manner of `AccessPolicy` (and `FreeTier`'s table): ten charts
/// free, enough to make "paste any chord sheet and Timbre listens" the answer to "can I play my song?", as many as you
/// like with Pro. Charts already saved always open, play and edit (they are the player's own); only adding past the
/// limit asks for Pro. With the player's own recording, playing along (the chart following it) and syncing it by
/// tapping along are free; slowing it down, looping a part and detecting its chords are Pro.
///
/// Apple Music is only ever a plain "Listen on Apple Music" player, free for everyone: Apple's MusicKit terms forbid
/// charging for it, modifying it (no loop, no slow-down) and synchronising anything to it, so no chart, chord or scroll
/// is ever timed to an Apple Music track, and its DRM audio is never analysed.
public enum YourSongsPolicy {
    public static let freeChartLimit = 10

    public static func canAddChart(existing: Int, pro: Bool) -> Bool { pro || existing < freeChartLimit }
    public static func canPlayAlongWithRecording(pro: Bool) -> Bool { true }
    public static func canSlowDownAndLoop(pro: Bool) -> Bool { pro }
    public static func canDetectChords(pro: Bool) -> Bool { pro }
    /// Never behind the paywall, whatever the plan.
    public static func canListenOnAppleMusic(pro: Bool) -> Bool { true }
}
