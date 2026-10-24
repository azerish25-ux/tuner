import Foundation

/// One thing written in a bar: a note (or the part of one held over a beat or a barline, tied from the one before) or
/// a rest.
public struct NotationEvent: Equatable, Sendable {
    /// Sixteenths from the start of the bar, and how many it lasts.
    public let start: Int
    public let length: Int
    /// The value written. A rest filling the bar is written as a whole rest whatever the meter.
    public let duration: NoteDuration
    /// The note it sounds, as an index into the notes the score was built from; nil for a rest.
    public let note: Int?
    /// The pitch as written (after the clef's octave); nil for a rest.
    public let pitch: SpelledPitch?
    /// Half spaces above the bottom line (a rest's own place: a whole rest hangs from the fourth line).
    public let position: Int
    /// The sign written before it (−2 … 2, 0 a natural); nil for none.
    public internal(set) var accidental: Int?
    /// Held over from the event before: it has no accidental, syllable or fret of its own.
    public let continued: Bool
    /// Tied on to the next event (in this bar, or the first of the next).
    public internal(set) var tied: Bool
    public internal(set) var stemUp: Bool
    /// The beam it hangs from (an index into its measure's `beams`); nil when it stands alone.
    public internal(set) var beam: Int?
    /// A rest filling the whole bar, centred in it.
    public let fillsBar: Bool

    init(start: Int, length: Int, duration: NoteDuration, note: Int?, pitch: SpelledPitch?, position: Int,
         continued: Bool = false, tied: Bool = false, fillsBar: Bool = false) {
        self.start = start
        self.length = length
        self.duration = duration
        self.note = note
        self.pitch = pitch
        self.position = position
        accidental = nil
        self.continued = continued
        self.tied = tied
        stemUp = true
        beam = nil
        self.fillsBar = fillsBar
    }

    public var isRest: Bool { note == nil }
    /// Where it ends, in sixteenths from the start of the bar.
    public var end: Int { start + length }
}

/// Notes sharing a beam, as indices into their measure's events, and which way their stems point.
public struct NotationBeam: Equatable, Sendable {
    public let events: [Int]
    public let stemUp: Bool
}

/// One bar of the score: its events from its first sixteenth to its last, and its beams.
public struct NotationMeasure: Equatable, Sendable {
    /// The bar's number from the top of the song (0 for the first).
    public let index: Int
    public let events: [NotationEvent]
    public let beams: [NotationBeam]
}

/// A melody written out as standard notation, bar by bar: each note quantized to the sixteenth (a swung melody's
/// off-beats written as straight eighths), split at barlines and wherever the meter wants the beat shown, the parts
/// tied; the gaps filled with rests; each note spelled in the key with the accidentals a bar needs (an accidental
/// lasts to the barline; a note tied over one carries its own); eighths and sixteenths beamed by the beat (two beats of
/// plain eighths together in 2/4 and 4/4, the three eighths of a pulse in 6/8); stems up for notes below the middle
/// line. Slash notation (`slashes`) writes rhythm only, every note on the middle line.
public struct NotationScore: Equatable, Sendable {
    public let meter: NotationMeter
    public let key: KeySignature
    public let clef: Clef
    public let measures: [NotationMeasure]
    /// The melody swings: its long-short off-beats are written as straight eighths (the sheet says "Swing").
    public let swing: Bool
    public let slashes: Bool

    /// `notes` (in beats from the top of the song, `beatsPerBar` to a bar) over at least `bars` bars.
    public init(notes: [TimedNote], beatsPerBar: Int, bars: Int, key: KeySignature, clef: Clef, slashes: Bool = false) {
        let meter = NotationMeter(beatsPerBar: beatsPerBar)
        let swing = !meter.compound && Self.swings(notes)
        self.meter = meter
        self.key = key
        self.clef = clef
        self.swing = swing
        self.slashes = slashes

        let spans = Self.spans(notes, meter: meter, swing: swing)
        // Each note spelled after the one written before it and towards the next different one (a few ahead).
        var pitches: [Int: SpelledPitch] = [:]
        var previous: SpelledPitch?
        for (order, span) in spans.enumerated() {
            let midi = notes[span.note].midi
            var next: Int?
            for ahead in spans[(order + 1)..<min(spans.count, order + 9)] where notes[ahead.note].midi != midi {
                next = clef.written(notes[ahead.note].midi)
                break
            }
            let pitch = key.spell(clef.written(midi), after: previous, before: next)
            pitches[span.note] = pitch
            previous = pitch
        }

        let barTicks = meter.barTicks
        let end = spans.last?.end ?? 0
        let count = max(1, bars, (end + barTicks - 1) / barTicks)
        var measures: [NotationMeasure] = []
        var first = 0
        for bar in 0..<count {
            let from = bar * barTicks
            let to = from + barTicks
            while first < spans.count && spans[first].end <= from { first += 1 }
            var events: [NotationEvent] = []
            var cursor = from
            var index = first
            while index < spans.count && spans[index].start < to {
                let span = spans[index]
                let start = max(span.start, from)
                let stop = min(span.end, to)
                if start > cursor { events += Self.rests(from: cursor - from, to: start - from, meter: meter) }
                let pitch = pitches[span.note]
                let position = slashes ? 4 : (pitch.map { clef.position(of: $0) } ?? 4)
                let pieces = Self.pieces(start: start - from, length: stop - start, meter: meter, rest: false)
                for (part, piece) in pieces.enumerated() {
                    events.append(NotationEvent(start: piece.start, length: piece.duration.ticks, duration: piece.duration,
                                                note: span.note, pitch: pitch, position: position,
                                                continued: part > 0 || span.start < from,
                                                tied: part < pieces.count - 1 || span.end > to))
                }
                cursor = stop
                index += 1
            }
            if cursor < to { events += Self.rests(from: cursor - from, to: barTicks, meter: meter) }
            measures.append(Self.finish(events, index: bar, meter: meter, key: key, slashes: slashes))
        }
        self.measures = measures
    }

    // MARK: Reading the melody

    /// A note as a span of sixteenths.
    struct Span: Equatable {
        let note: Int
        var start: Int
        var end: Int
    }

    /// The melody swings when its off-beats fall a third of the way from the beat's end (0.667) at least as often as
    /// on straight eighths and sixteenths.
    static func swings(_ notes: [TimedNote]) -> Bool {
        var thirds = 0
        var straight = 0
        for note in notes {
            let fraction = note.beat - note.beat.rounded(.down)
            if abs(fraction - 2.0 / 3) < 0.04 || abs(fraction - 1.0 / 3) < 0.04 {
                thirds += 1
            } else if abs(fraction - 0.5) < 0.02 || abs(fraction - 0.25) < 0.02 || abs(fraction - 0.75) < 0.02 {
                straight += 1
            }
        }
        return thirds > 0 && thirds >= straight
    }

    /// `beat` in sixteenths; in a swung melody the long-short off-beat is written on the half beat.
    static func tick(_ beat: Double, meter: NotationMeter, swing: Bool) -> Int {
        guard swing else { return meter.ticks(beat) }
        let whole = beat.rounded(.down)
        if abs(beat - whole - 2.0 / 3) < 0.04 { return meter.ticks(whole + 0.5) }
        return meter.ticks(beat)
    }

    /// The notes as spans of sixteenths, one at a time: a note starting with the one before is left out, one starting
    /// inside it cuts it short, and none is shorter than a sixteenth.
    static func spans(_ notes: [TimedNote], meter: NotationMeter, swing: Bool) -> [Span] {
        var all: [Span] = []
        for (index, note) in notes.enumerated() {
            let start = tick(note.beat, meter: meter, swing: swing)
            guard start >= 0 else { continue }
            let end = max(start + 1, tick(note.beat + note.beats, meter: meter, swing: swing))
            all.append(Span(note: index, start: start, end: end))
        }
        all.sort { ($0.start, $0.note) < ($1.start, $1.note) }
        var line: [Span] = []
        for span in all {
            if let last = line.last {
                if span.start <= last.start { continue }
                if last.end > span.start { line[line.count - 1].end = span.start }
            }
            line.append(span)
        }
        return line
    }

    // MARK: Note values

    /// A stretch of a bar written as tied values (or rests side by side): at each point the longest value the meter
    /// allows there.
    static func pieces(start: Int, length: Int, meter: NotationMeter, rest: Bool) -> [(start: Int, duration: NoteDuration)] {
        var result: [(start: Int, duration: NoteDuration)] = []
        var at = start
        var left = length
        while left > 0 {
            let fits = NoteDuration.all.first { value in
                value.ticks <= left
                    && allowed(start: at, length: value.ticks, whole: value.ticks == left, rest: rest, dotted: value.dotted, meter: meter)
            }
            let value = fits ?? .sixteenth
            result.append((start: at, duration: value))
            at += value.ticks
            left -= value.ticks
        }
        return result
    }

    /// Whether a value of `length` may start at `start` (sixteenths into the bar) without hiding the beat. A note
    /// filling the bar always may. In 6/8, a value stays inside its pulse unless it starts on one and lasts whole
    /// pulses. In simple time, a note on the beat may run on, but not over the middle of a 4/4 bar unless it starts the
    /// bar or ends the note on a beat (quarter, half, quarter); a note off the beat stays inside its beat, apart from
    /// the syncopations eighth-quarter-eighth and eighth-dotted quarter, which end the note inside half the bar; a note
    /// on a sixteenth's off-beat crosses the next eighth only when that ends it. Rests are stricter: never dotted, at
    /// most a beat long apart from a half rest starting the bar or its second half (`whole`: the value is all that is
    /// left of the note).
    static func allowed(start: Int, length: Int, whole: Bool, rest: Bool, dotted: Bool, meter: NotationMeter) -> Bool {
        let end = start + length
        if start == 0 && end == meter.barTicks { return true }
        let pulse = meter.pulseTicks
        let pulseEnd = (start / pulse + 1) * pulse
        if meter.compound {
            if start % pulse == 0 { return end <= pulseEnd || length % pulse == 0 }
            return end <= pulseEnd
        }
        let crossesHalf = meter.beats == 4 && start < 8 && end > 8
        let eighthEnd = (start / 2 + 1) * 2
        if rest {
            if dotted { return false }
            if start % pulse == 0 {
                if length <= pulse { return true }
                return length == 8 && !crossesHalf && (start == 0 || (meter.beats == 4 && start == 8))
            }
            return end <= pulseEnd && (start % 2 == 0 || end <= eighthEnd)
        }
        if start % pulse == 0 {
            return !crossesHalf || start == 0 || (whole && length % pulse == 0)
        }
        if end <= pulseEnd {
            return start % 2 == 0 || end <= eighthEnd || whole
        }
        return whole && start % 2 == 0 && (length == pulse || length == pulse + pulse / 2) && !crossesHalf
    }

    /// Rests over sixteenths `start..<end` of a bar: one whole rest for an empty bar.
    static func rests(from start: Int, to end: Int, meter: NotationMeter) -> [NotationEvent] {
        guard end > start else { return [] }
        if start == 0 && end == meter.barTicks {
            return [NotationEvent(start: 0, length: meter.barTicks, duration: .whole, note: nil, pitch: nil, position: 6, fillsBar: true)]
        }
        return pieces(start: start, length: end - start, meter: meter, rest: true).map { piece in
            NotationEvent(start: piece.start, length: piece.duration.ticks, duration: piece.duration, note: nil, pitch: nil,
                          position: piece.duration.level == 0 ? 6 : 4)
        }
    }

    // MARK: Accidentals, beams and stems

    static func finish(_ input: [NotationEvent], index: Int, meter: NotationMeter, key: KeySignature, slashes: Bool) -> NotationMeasure {
        var events = input
        if !slashes {
            // An accidental holds to the barline for its own line or space; a note tied over the barline carries its
            // own and sets nothing for the notes after it.
            var carried: [Int: Int] = [:]
            for i in events.indices {
                guard let pitch = events[i].pitch, !events[i].continued else { continue }
                let expected = carried[pitch.step] ?? key.alter(ofLetter: pitch.letter)
                if pitch.alter != expected { events[i].accidental = pitch.alter }
                carried[pitch.step] = pitch.alter
            }
        }
        var beams: [NotationBeam] = []
        for group in beamGroups(events, meter: meter) {
            let up = slashes || stemsUp(group.map { events[$0].position })
            for i in group {
                events[i].stemUp = up
                events[i].beam = beams.count
            }
            beams.append(NotationBeam(events: group, stemUp: up))
        }
        for i in events.indices where events[i].beam == nil && !events[i].isRest {
            events[i].stemUp = slashes || stemsUp([events[i].position])
        }
        return NotationMeasure(index: index, events: events, beams: beams)
    }

    /// Stems point up when the notes lie further below the middle line than above it (the farthest note decides), down
    /// otherwise; a note on the middle line points down.
    static func stemsUp(_ positions: [Int]) -> Bool {
        guard let high = positions.max(), let low = positions.min() else { return true }
        return 4 - low > high - 4
    }

    /// Runs of eighths and sixteenths inside one pulse (a rest breaks a run), as event indices; in 2/4 and 4/4, two
    /// beats of plain eighths starting on beat one or three share a beam.
    static func beamGroups(_ events: [NotationEvent], meter: NotationMeter) -> [[Int]] {
        var groups: [[Int]] = []
        var current: [Int] = []
        var window = -1
        for (i, event) in events.enumerated() {
            guard !event.isRest, event.duration.beams > 0 else {
                if current.count >= 2 { groups.append(current) }
                current = []
                window = -1
                continue
            }
            let here = event.start / meter.pulseTicks
            if here != window {
                if current.count >= 2 { groups.append(current) }
                current = []
                window = here
            }
            current.append(i)
        }
        if current.count >= 2 { groups.append(current) }
        guard !meter.compound, meter.beats == 2 || meter.beats == 4 else { return groups }
        var merged: [[Int]] = []
        for group in groups {
            if let last = merged.last, pairedEighths(last, events), pairedEighths(group, events) {
                let beat = events[last[0]].start / 4
                if beat % 2 == 0 && events[group[0]].start / 4 == beat + 1 {
                    merged[merged.count - 1] = last + group
                    continue
                }
            }
            merged.append(group)
        }
        return merged
    }

    /// Two plain eighths filling one beat.
    private static func pairedEighths(_ group: [Int], _ events: [NotationEvent]) -> Bool {
        group.count == 2 && events[group[0]].start % 4 == 0 && group.allSatisfy { events[$0].duration == .eighth }
    }

    // MARK: Finding things

    /// The measure for bar `index`, if the score reaches it.
    public func measure(_ index: Int) -> NotationMeasure? { measures.indices.contains(index) ? measures[index] : nil }
}

// MARK: - Lines

/// Breaking a score into lines and spreading a line to its width.
public enum NotationLayout {
    /// The room a note takes before the next one, in staff spaces, by how long it lasts (in sixteenths): a sixteenth
    /// 2, an eighth 2.6, a quarter 3.2, a half 3.8, a whole 4.4. Longer notes take more room, but not in proportion,
    /// as engravers space them.
    public static func space(ticks: Int) -> Double { 2 + 0.6 * log2(Double(max(1, ticks))) }

    /// The bars of a passage in lines no wider than `available`: as few lines as hold them, then the breaks that leave
    /// the lines most evenly full. `widths` are each bar's narrowest; the first line spends `firstPrefix` on its clef,
    /// key and time signature, the others `prefix` on clef and key. A bar too wide for any line has one to itself.
    public static func lines(widths: [Double], available: Double, firstPrefix: Double, prefix: Double) -> [Range<Int>] {
        let count = widths.count
        guard count > 0 else { return [] }
        var best: [(lines: Int, cost: Double, from: Int)?] = Array(repeating: nil, count: count + 1)
        best[0] = (lines: 0, cost: 0, from: 0)
        for end in 1...count {
            var width = 0.0
            var start = end - 1
            while start >= 0 {
                width += widths[start]
                let used = width + (start == 0 ? firstPrefix : prefix)
                if used > available && start < end - 1 { break }
                if let before = best[start] {
                    let slack = max(0, available - used) / max(1, available)
                    let candidate = (lines: before.lines + 1, cost: before.cost + slack * slack, from: start)
                    if let current = best[end] {
                        if (candidate.lines, candidate.cost) < (current.lines, current.cost) { best[end] = candidate }
                    } else {
                        best[end] = candidate
                    }
                }
                start -= 1
            }
        }
        var ranges: [Range<Int>] = []
        var end = count
        while end > 0, let entry = best[end] {
            ranges.insert(entry.from..<end, at: 0)
            end = entry.from
        }
        return ranges
    }

    /// `extra` points shared out in proportion to `weights` (evenly when they weigh nothing).
    public static func share(_ extra: Double, weights: [Double]) -> [Double] {
        guard !weights.isEmpty else { return [] }
        let total = weights.reduce(0, +)
        guard total > 0 else { return weights.map { _ in extra / Double(weights.count) } }
        return weights.map { extra * $0 / total }
    }
}
