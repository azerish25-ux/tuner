import Foundation

// MARK: - Styles

/// The backing band's genres. `standard` is the gentle groove every course plays under its tunes (folk, nursery,
/// classical, hymns); the others are the Originals' styles, each with its own drums, bass line and comping.
public enum BandStyle: String, CaseIterable, Hashable, Sendable {
    case standard, pop, rock, reggae, country, funk, ballad

    /// Genre words, most specific first: "Punk-pop" is rock, "The power ballad" a ballad, "Indie-rock anthem" rock.
    static let vocabulary: [(style: BandStyle, words: [String])] = [
        (.reggae, ["reggae", "one-drop", "ska "]),
        (.funk, ["funk", "disco"]),
        (.country, ["country", "two-step", "boom-chick", "bluegrass", "honky-tonk", "twang"]),
        (.ballad, ["ballad", "slow dance", "lo-fi", "lullaby", "neo-soul", "doo-wop", "slow burner"]),
        (.rock, ["rock", "punk", "garage", "surf", "grunge", "riff", "shuffle", "blues"]),
        (.pop, ["pop", "anthem", "sing-along", "campfire", "folk", "highlife", "gospel", "big finish", "story"]),
    ]

    /// The style the first of `texts` naming a genre names ("Reggae: chop the offbeat", "Country two-step"); nil
    /// when none does.
    public static func named(in texts: [String]) -> BandStyle? {
        for text in texts {
            let lowered = text.lowercased()
            for entry in vocabulary where entry.words.contains(where: { lowered.contains($0) }) { return entry.style }
        }
        return nil
    }

    /// A style from a one-bar strum pattern (beats from the downbeat) when nothing names one: chops on the offbeats
    /// with nothing on one are reggae; one, its "and" and syncopated "and"s without beat two are funk; a shuffle
    /// (three or more swung "and"s) or driving eighths at 100 bpm or more are rock; sparse strokes at 84 bpm or less
    /// a ballad. Anything else, or a pattern longer than a bar (a melody's beats), keeps the standard groove. 4/4 only.
    public static func inferred(pattern: [Double], bpm: Double, meter: Int) -> BandStyle {
        guard meter == 4, !pattern.isEmpty, pattern.allSatisfy({ $0 >= 0 && $0 < 4 }) else { return .standard }
        func has(_ beat: Double) -> Bool { pattern.contains { abs($0 - beat) < 0.02 } }
        let offbeats = Set([0.5, 1.0, 1.5, 2.5, 3.0, 3.5])
        if !has(0), pattern.allSatisfy({ beat in offbeats.contains { abs($0 - beat) < 0.02 } }) { return .reggae }
        if has(0), has(0.5), !has(1), [1.5, 2.5, 3.5].filter(has).count >= 2 { return .funk }
        if [0.667, 1.667, 2.667, 3.667].filter(has).count >= 3 { return .rock }
        let eighths = pattern.filter { abs($0 * 2 - ($0 * 2).rounded()) < 0.02 }.count
        if eighths >= 7, bpm >= 100 { return .rock }
        let sparse: [Double] = [0, 2, 2.667, 3, 3.5]
        if bpm <= 84, pattern.allSatisfy({ beat in sparse.contains { abs($0 - beat) < 0.02 } }) { return .ballad }
        return .standard
    }

    /// An Originals song's style: the genre its explain steps name, else its unit's title, else its last strum
    /// pattern's. (The other courses' songs keep the standard groove: their titles name a tune's history, "From 1861
    /// to rock and roll", not the band it wants.)
    public static func of(_ lesson: Lesson, unit: LearnUnit) -> BandStyle {
        var titles: [String] = []
        var pattern: [Double]?
        var bpm = 0.0
        var meter = 4
        for step in lesson.steps {
            switch step {
            case let .explain(title, _, _):
                titles.append(title.defaultValue)
            case let .progression(_, _, strokes, rate, beats):
                pattern = strokes
                bpm = rate
                meter = beats ?? max(4, Int((strokes.max() ?? 3) + 1))
            default:
                break
            }
        }
        if let style = named(in: titles) ?? named(in: [unit.title.defaultValue]) { return style }
        return pattern.map { inferred(pattern: $0, bpm: bpm, meter: meter) } ?? .standard
    }
}

// MARK: - Recognising a song

/// Short, tempo-free descriptions of what a band is asked to play, so the band can tell which song it backs without
/// being told: a melody's opening (its first six notes: pitch and onset after the first, in twelfths of a beat) or a
/// chord stretch's (its first four bars' chords, with the strum pattern when there is one), each in its meter.
public enum BandCue {
    public static func melody(_ notes: [TimedNote], meter: Int) -> String? {
        let sorted = notes.sorted { $0.beat < $1.beat }
        guard sorted.count >= 4, let first = sorted.first, Set(sorted.prefix(6).map(\.midi)).count >= 2 else { return nil }
        let head = sorted.prefix(6).map { "\($0.midi)@\(Int((($0.beat - first.beat) * 12).rounded()))" }
        return "m\(max(1, meter)):" + head.joined(separator: ",")
    }

    /// `symbols`: the chord of each bar ("-" for none). Nil for fewer than two different chords: a one-chord stretch
    /// (a strum exercise) says nothing about the song.
    public static func chords(_ symbols: [String], meter: Int, pattern: [Double]? = nil) -> String? {
        let head = Array(symbols.prefix(4))
        guard Set(head.filter { $0 != "-" }).count >= 2 else { return nil }
        var cue = "c\(max(1, meter)):" + head.joined(separator: ",")
        if let pattern {
            cue += "|" + pattern.prefix(8).map { String(Int(($0 * 12).rounded())) }.joined(separator: ",")
        }
        return cue
    }

    /// Chords held for `bars` bars each, bar by bar.
    public static func perBar(_ chords: [ChordSpec], bars: [Int]) -> [String] {
        var out: [String] = []
        for (index, chord) in chords.enumerated() {
            out += Array(repeating: chord.symbol, count: index < bars.count ? max(0, bars[index]) : 1)
        }
        return out
    }
}

/// Every song lesson's cues (its play-alongs, its progressions with and without their strum, every four-bar window
/// of its chart, each section of its whole take) mapped to the lesson's style: an Originals song's own, the standard
/// groove for every other course's. A cue two songs of different styles share means nothing and is dropped. Built
/// once, the first time a band needs it, off the main thread.
public final class BandStyleIndex: Sendable {
    public static let shared = BandStyleIndex(curriculum: try? Curriculum.bundled())
    /// The course whose songs are written in today's styles.
    public static let styledCourse = "originals"

    private let styles: [String: BandStyle]

    public init(curriculum: Curriculum?) {
        var styles: [String: BandStyle] = [:]
        var clashing: Set<String> = []
        for course in curriculum?.courses ?? [] {
            for unit in course.units {
                for lesson in unit.lessons where lesson.kind == .song {
                    let style = course.id == Self.styledCourse ? BandStyle.of(lesson, unit: unit) : .standard
                    for cue in Self.cues(of: lesson) where !clashing.contains(cue) {
                        if let known = styles[cue], known != style {
                            styles[cue] = nil
                            clashing.insert(cue)
                        } else {
                            styles[cue] = style
                        }
                    }
                }
            }
        }
        self.styles = styles
    }

    /// The style of the song `cue` belongs to (`standard` for a song of another course); nil for a cue no song (or
    /// more than one style) owns.
    public func style(forCue cue: String) -> BandStyle? { styles[cue] }

    public var count: Int { styles.count }

    static func cues(of lesson: Lesson) -> [String] {
        var out: [String?] = []
        for step in lesson.steps {
            switch step {
            case let .playAlong(notes, _, beatsPerBar, _):
                out.append(BandCue.melody(notes, meter: beatsPerBar))
            case let .progression(chords, bars, pattern, _, beatsPerBar):
                // The meter as the strum step counts it: 4, or longer if the pattern needs it.
                let meter = beatsPerBar ?? max(4, Int((pattern.max() ?? 3) + 1))
                let symbols = BandCue.perBar(chords, bars: bars)
                out.append(BandCue.chords(symbols, meter: meter, pattern: pattern))
                out.append(BandCue.chords(symbols, meter: meter))
            default:
                break
            }
        }
        if let arrangement = lesson.arrangement {
            // The chart bar by bar as a preview fills it (each bar the chord last named).
            var held: String?
            let symbols: [String] = arrangement.chordPerBar.map { chord in
                if let chord { held = chord.symbol }
                return held ?? "-"
            }
            for start in symbols.indices {
                out.append(BandCue.chords(Array(symbols[start...].prefix(4)), meter: arrangement.beatsPerBar))
            }
            if let take = lesson.songTake {
                for section in arrangement.sections {
                    out.append(BandCue.melody(arrangement.notes(of: section, in: take.notes), meter: arrangement.beatsPerBar))
                }
            }
        }
        return out.compactMap { $0 }
    }
}

// MARK: - What the band plays in a bar

/// One bar of the band in a style, in beats from the bar's downbeat: the drummer's hits, the bass line (intervals
/// above the bar's root) and the chord strokes (who plays them, for how long, how hard, down or up). Pure data: the
/// app's `BandSynth` renders it with the recorded kit, bass, piano and electric guitar.
public struct BandGroove: Equatable, Sendable {
    /// The kit's pieces (the sample set "drums").
    public enum Piece: String, CaseIterable, Sendable {
        case kick, snare, hat, openhat, ride, crash, xstick, tomhi, tomlo, tamb, shaker
    }

    public struct Hit: Equatable, Sendable {
        public let beat: Double
        public let piece: Piece
        public let velocity: Float
    }

    public struct Note: Equatable, Sendable {
        public let beat: Double
        public let beats: Double
        public let interval: Int
        public let velocity: Float
    }

    /// Who sounds a chord stroke: the piano (the chord, rolled), the piano one chord tone at a time (`tone`, a broken
    /// chord), the electric guitar's power chord, its staccato chop of the upper voicing, or its let-ring chord.
    public enum Part: String, Sendable { case piano, arpeggio, power, chop, ring }

    public struct Stroke: Equatable, Sendable {
        public let beat: Double
        public let beats: Double
        public let velocity: Double
        public let up: Bool
        public let part: Part
        /// For `arpeggio`: which tone of the broken chord (0 the bass note, then upwards, wrapping).
        public let tone: Int

        init(_ beat: Double, _ beats: Double, _ velocity: Double, _ part: Part, up: Bool = false, tone: Int = 0) {
            self.beat = beat; self.beats = beats; self.velocity = velocity; self.part = part; self.up = up; self.tone = tone
        }
    }

    /// Where a bar sits and what it holds.
    public struct Context: Equatable, Sendable {
        public var meter: Int
        public var bpm: Double
        /// Off-beats on the triplet grid.
        public var swing: Bool
        /// A fill closing a four-bar phrase.
        public var fill: Bool
        /// The first bar of a new phrase (after a fill): a crash in the bigger styles.
        public var lift: Bool
        /// The final chord.
        public var ending: Bool
        /// 1 answers the root with the octave instead of the fifth.
        public var variation: Int
        /// The bar has a chord (else the band plays drums and a bass on a key's tonic only).
        public var chord: Bool
        /// The fifth the bass may use: 7, or 0 for a chord without one.
        public var fifth: Int

        public init(meter: Int, bpm: Double, swing: Bool, fill: Bool, lift: Bool, ending: Bool, variation: Int, chord: Bool,
                    fifth: Int) {
            self.meter = meter; self.bpm = bpm; self.swing = swing; self.fill = fill; self.lift = lift
            self.ending = ending; self.variation = variation; self.chord = chord; self.fifth = fifth
        }
    }

    public let hits: [Hit]
    public let bass: [Note]
    public let comp: [Stroke]

    public static func bar(_ style: BandStyle, _ context: Context) -> BandGroove {
        let meter = max(1, context.meter)
        if context.ending { return ending(style, context) }
        let compound = meter >= 6 && meter % 3 == 0
        switch style {
        case .standard:
            return standard(context)
        case .ballad where meter == 3:
            return waltzBallad(context)
        case _ where compound:
            return compoundBar(style, context)
        case _ where meter != 4:
            return standard(context)
        case .pop: return pop(context)
        case .rock: return rock(context)
        case .reggae: return reggae(context)
        case .country: return country(context)
        case .funk: return funk(context)
        case .ballad: return ballad(context)
        }
    }

    // MARK: Every style

    /// The final chord with a cymbal: the bass on the root, the chord ringing about 1.25 s.
    static func ending(_ style: BandStyle, _ c: Context) -> BandGroove {
        let ring = 1.25 * max(20, c.bpm) / 60
        let hits = [Hit(beat: 0, piece: .kick, velocity: 1), Hit(beat: 0, piece: .crash, velocity: 1)]
        let bass = [Note(beat: 0, beats: Double(min(max(1, c.meter), 2)), interval: 0, velocity: 1)]
        var comp = [Stroke(0, ring, 0.62, .piano)]
        switch style {
        case .rock: comp = [Stroke(0, ring, 0.75, .ring)]
        case .country: comp.append(Stroke(0, ring, 0.6, .ring))
        default: break
        }
        return BandGroove(hits: hits, bass: bass, comp: comp)
    }

    /// The eighth after `beat` on the bar's grid: halfway, or two-thirds of the way when swung.
    static func and(_ beat: Double, _ c: Context) -> Double { beat + (c.swing ? 2.0 / 3.0 : 0.5) }

    /// Closed hats on the beats and their "and"s, `on` and `off` loud, dropped where `skip` says.
    static func hats(_ c: Context, on: Float, off: Float, accent: Float? = nil, until end: Double = 4,
                     skip: (Double) -> Bool = { _ in false }) -> [Hit] {
        var out: [Hit] = []
        for b in 0..<max(1, c.meter) where Double(b) < end {
            let beat = Double(b)
            if !skip(beat) { out.append(Hit(beat: beat, piece: .hat, velocity: b == 0 ? (accent ?? on) : on)) }
            let offbeat = and(beat, c)
            if offbeat < end, !skip(offbeat) { out.append(Hit(beat: offbeat, piece: .hat, velocity: off)) }
        }
        return out
    }

    /// The last beat (or two) given to the toms and snare in the bigger styles: snare, snare, high tom, low tom.
    static func tomFill(from start: Double, loud: Float) -> [Hit] {
        [Hit(beat: start, piece: .snare, velocity: loud * 0.75), Hit(beat: start + 0.25, piece: .snare, velocity: loud * 0.65),
         Hit(beat: start + 0.5, piece: .tomhi, velocity: loud * 0.85), Hit(beat: start + 0.75, piece: .tomlo, velocity: loud * 0.95)]
    }

    // MARK: Standard (the courses' own groove)

    /// A gentle groove per meter: 4/4 kick on 1 and 3, snare on 2 and 4; 3/4 a waltz; 6/8 (and 9/8, 12/8) in dotted
    /// groups; anything else kick on 1, snare on the off beats. Hi-hat throughout. Root and fifth (or octave) on the
    /// bass, the chord on the piano in half bars, waltz "pah-pah"s or dotted groups.
    static func standard(_ c: Context) -> BandGroove {
        let meter = max(1, c.meter)
        let compound = meter >= 6 && meter % 3 == 0
        let offbeat = c.swing ? 2.0 / 3.0 : 0.5
        let fills = c.fill && meter >= 2
        let fillStart = fills ? Double(compound ? meter - 2 : meter - 1) : Double(meter)
        var hits: [Hit] = []
        for b in 0..<meter where Double(b) < fillStart {
            let beat = Double(b)
            if compound {
                if b % 3 == 0 {
                    let group = b / 3
                    hits.append(Hit(beat: beat, piece: group % 2 == 0 ? .kick : .snare, velocity: group == 0 ? 1 : 0.7))
                }
                hits.append(Hit(beat: beat, piece: .hat, velocity: b % 3 == 0 ? 0.8 : 0.5))
                continue
            }
            switch meter {
            case 3:
                hits.append(Hit(beat: beat, piece: b == 0 ? .kick : .snare, velocity: b == 0 ? 1 : 0.4))
            case 4:
                hits.append(Hit(beat: beat, piece: b % 2 == 0 ? .kick : .snare, velocity: b == 0 ? 1 : 0.75))
            default:
                if b == 0 { hits.append(Hit(beat: beat, piece: .kick, velocity: 1)) }
                else if b % 2 == 1 { hits.append(Hit(beat: beat, piece: .snare, velocity: 0.65)) }
            }
            hits.append(Hit(beat: beat, piece: .hat, velocity: b == 0 ? 0.8 : 0.65))
            hits.append(Hit(beat: beat + offbeat, piece: .hat, velocity: 0.4))
        }
        if fills {
            let steps: [Double] = compound ? [0, 1, 1.5] : [0, 0.25, 0.5, 0.75]
            for (index, step) in steps.enumerated() {
                hits.append(Hit(beat: fillStart + step, piece: .snare, velocity: 0.45 + 0.14 * Float(index)))
            }
        }
        return BandGroove(hits: hits, bass: standardBass(c), comp: c.chord ? standardComp(c) : [])
    }

    /// Root on the downbeat, answered by the fifth (or the octave) mid-bar, with a pickup in 4/4.
    static func standardBass(_ c: Context) -> [Note] {
        let meter = max(1, c.meter)
        let answer = c.variation == 0 ? c.fifth : 12
        switch meter {
        case 4:
            var notes = [Note(beat: 0, beats: 1.8, interval: 0, velocity: 1), Note(beat: 2, beats: 1.3, interval: answer, velocity: 0.85)]
            if !c.fill { notes.append(Note(beat: 3.5, beats: 0.4, interval: c.variation == 0 ? 12 : c.fifth, velocity: 0.6)) }
            return notes
        case 3:
            return [Note(beat: 0, beats: 1.8, interval: 0, velocity: 1), Note(beat: 2, beats: 0.9, interval: answer, velocity: 0.75)]
        case 2:
            return [Note(beat: 0, beats: 0.9, interval: 0, velocity: 1), Note(beat: 1, beats: 0.9, interval: answer, velocity: 0.8)]
        default:
            if meter >= 6 && meter % 3 == 0 {
                return stride(from: 0, to: meter, by: 3).map { (b: Int) -> Note in
                    let interval: Int = (b / 3) % 2 == 0 ? 0 : answer
                    let velocity: Float = b == 0 ? 1 : 0.8
                    return Note(beat: Double(b), beats: 2.7, interval: interval, velocity: velocity)
                }
            }
            if meter >= 4 {
                let half = meter / 2
                return [Note(beat: 0, beats: Double(half) - 0.2, interval: 0, velocity: 1),
                        Note(beat: Double(half), beats: Double(meter - half) - 0.2, interval: answer, velocity: 0.8)]
            }
            return [Note(beat: 0, beats: Double(meter) * 0.9, interval: 0, velocity: 1)]
        }
    }

    /// A pianist comping the bar's chord: half-bar chords with a soft push before the next bar in 4/4, the waltz's
    /// "pah-pah" in 3/4, one chord per dotted group in compound meters; a fill bar holds one chord under the drums.
    static func standardComp(_ c: Context) -> [Stroke] {
        let meter = max(1, c.meter)
        let push = c.swing ? 2.0 / 3.0 : 0.5
        if c.fill { return [Stroke(0, Double(meter) - 0.1, 0.55, .piano)] }
        if meter >= 6 && meter % 3 == 0 {
            return stride(from: 0, to: meter, by: 3).map { (b: Int) -> Stroke in
                let velocity: Double = b == 0 ? 0.58 : 0.46
                return Stroke(Double(b), 2.8, velocity, .piano)
            }
        }
        switch meter {
        case 4: return [Stroke(0, 1.9, 0.6, .piano), Stroke(2, 1.4, 0.5, .piano), Stroke(3 + push, 0.45, 0.36, .piano)]
        case 3: return [Stroke(0, 0.9, 0.4, .piano), Stroke(1, 0.8, 0.45, .piano), Stroke(2, 0.8, 0.42, .piano)]
        case 2: return [Stroke(0, 0.9, 0.55, .piano), Stroke(1, 0.9, 0.45, .piano)]
        default: return [Stroke(0, Double(meter) - 0.1, 0.55, .piano)]
        }
    }

    // MARK: Pop

    /// Kick on one, the "and" of two and three, snare and tambourine on two and four, eighth hats; the bass pushes
    /// the same "and"; the piano holds half bars and pushes into beats three and one.
    static func pop(_ c: Context) -> BandGroove {
        let end = c.fill ? 3.0 : 4.0
        var hits: [Hit] = [Hit(beat: 0, piece: .kick, velocity: 1), Hit(beat: and(1, c), piece: .kick, velocity: 0.6),
                           Hit(beat: 2, piece: .kick, velocity: 0.85), Hit(beat: 1, piece: .snare, velocity: 0.8),
                           Hit(beat: 1, piece: .tamb, velocity: 0.5)]
        if !c.fill { hits += [Hit(beat: 3, piece: .snare, velocity: 0.82), Hit(beat: 3, piece: .tamb, velocity: 0.5)] }
        hits += hats(c, on: 0.6, off: 0.38, accent: 0.7, until: end, skip: { $0 == 0 && c.lift })
        if c.lift { hits.append(Hit(beat: 0, piece: .crash, velocity: 0.75)) }
        if c.fill { hits += tomFill(from: 3, loud: 0.8) }
        var bass = [Note(beat: 0, beats: 1.4, interval: 0, velocity: 1), Note(beat: and(1, c), beats: 0.45, interval: 0, velocity: 0.7),
                    Note(beat: 2, beats: 0.9, interval: c.fifth, velocity: 0.85)]
        bass += c.fill ? [Note(beat: 3, beats: 0.9, interval: 0, velocity: 0.8)]
                       : [Note(beat: 3, beats: 0.45, interval: 0, velocity: 0.75), Note(beat: and(3, c), beats: 0.4, interval: 12, velocity: 0.6)]
        var comp: [Stroke] = []
        if c.chord {
            comp = c.fill ? [Stroke(0, 2.9, 0.55, .piano)]
                          : [Stroke(0, 1.45, 0.6, .piano), Stroke(and(1, c), 0.4, 0.42, .piano), Stroke(2, 1.45, 0.52, .piano),
                             Stroke(and(3, c), 0.4, 0.4, .piano)]
        }
        return BandGroove(hits: hits, bass: bass, comp: comp)
    }

    // MARK: Rock

    /// A harder backbeat, the kick on one, the "and" of two and three; the bass drives eighths on the root (a
    /// shuffle's boogie when swung); the electric guitar chugs power chords on the eighths, letting the first ring
    /// on a new phrase; the toms take the last beat of a fill.
    static func rock(_ c: Context) -> BandGroove {
        let end = c.fill ? 3.0 : 4.0
        var hits: [Hit] = [Hit(beat: 0, piece: .kick, velocity: 1), Hit(beat: and(1, c), piece: .kick, velocity: 0.7),
                           Hit(beat: 2, piece: .kick, velocity: 0.9), Hit(beat: 1, piece: .snare, velocity: 0.95)]
        if !c.fill { hits.append(Hit(beat: 3, piece: .snare, velocity: 0.95)) }
        if c.variation == 1 && !c.fill { hits.append(Hit(beat: and(3, c), piece: .kick, velocity: 0.6)) }
        hits += hats(c, on: 0.72, off: 0.5, accent: 0.8, until: end, skip: { $0 == 0 && c.lift })
        if c.lift { hits.append(Hit(beat: 0, piece: .crash, velocity: 0.9)) }
        if c.fill { hits += tomFill(from: 3, loud: 1) + [Hit(beat: 3, piece: .kick, velocity: 0.8)] }
        // A swung shuffle walks root, fifth and sixth; a straight bar drives the root.
        let boogie = c.swing && c.chord && c.fifth == 7 ? [0, 0, 7, 7, 9, 9, 7, 7] : [Int](repeating: 0, count: 8)
        var bass: [Note] = []
        for b in 0..<4 where Double(b) < end {
            bass.append(Note(beat: Double(b), beats: 0.42, interval: boogie[2 * b], velocity: 0.95))
            bass.append(Note(beat: and(Double(b), c), beats: 0.36, interval: boogie[2 * b + 1], velocity: 0.75))
        }
        if c.fill { bass.append(Note(beat: 3, beats: 0.9, interval: 0, velocity: 0.9)) }
        var comp: [Stroke] = []
        if c.chord {
            if c.fill {
                comp = [Stroke(0, 2.9, 0.7, .ring)]
            } else {
                let from = c.lift ? 2 : 0
                if c.lift { comp.append(Stroke(0, 1.9, 0.75, .ring)) }
                for b in from..<4 {
                    comp.append(Stroke(Double(b), 0.42, 0.62, .power))
                    comp.append(Stroke(and(Double(b), c), 0.36, 0.48, .power))
                }
            }
        }
        return BandGroove(hits: hits, bass: bass, comp: comp)
    }

    // MARK: Reggae

    /// The one-drop: nothing on one, kick and cross-stick together on three, light eighth hats; the bass enters
    /// after the drop and leans on three; the guitar's staccato skank on two and four, the piano doubling it softly.
    static func reggae(_ c: Context) -> BandGroove {
        let end = c.fill ? 3.0 : 4.0
        var hits: [Hit] = [Hit(beat: 2, piece: .kick, velocity: 0.9), Hit(beat: 2, piece: .xstick, velocity: 0.8)]
        hits += hats(c, on: 0.45, off: 0.3, until: end)
        if c.fill {
            hits += [Hit(beat: 3, piece: .xstick, velocity: 0.55), Hit(beat: 3.5, piece: .snare, velocity: 0.5),
                     Hit(beat: 3.75, piece: .snare, velocity: 0.62)]
        } else {
            hits.append(Hit(beat: and(3, c), piece: .openhat, velocity: 0.3))
        }
        var bass = [Note(beat: and(0, c), beats: 1.3, interval: 0, velocity: 0.95), Note(beat: 2, beats: 0.9, interval: c.fifth, velocity: 0.9)]
        if !c.fill {
            bass += [Note(beat: 3, beats: 0.4, interval: c.variation == 0 ? 12 : 0, velocity: 0.65),
                     Note(beat: and(3, c), beats: 0.4, interval: c.fifth, velocity: 0.6)]
        }
        var comp: [Stroke] = []
        if c.chord {
            comp = [Stroke(1, 0.35, 0.62, .chop, up: true), Stroke(1, 0.35, 0.3, .piano)]
            if !c.fill { comp += [Stroke(3, 0.35, 0.62, .chop, up: true), Stroke(3, 0.35, 0.3, .piano)] }
        }
        return BandGroove(hits: hits, bass: bass, comp: comp)
    }

    // MARK: Country

    /// The two-step: kick on one and three, a lighter snare on two and four, eighth hats; the bass's "boom" walks
    /// root to fifth (or octave); the Gretsch's staccato "chick" answers on two and four; a snare roll-up fills.
    static func country(_ c: Context) -> BandGroove {
        let end = c.fill ? 3.0 : 4.0
        var hits: [Hit] = [Hit(beat: 0, piece: .kick, velocity: 1), Hit(beat: 2, piece: .kick, velocity: 0.85),
                           Hit(beat: 1, piece: .snare, velocity: 0.6)]
        if !c.fill { hits.append(Hit(beat: 3, piece: .snare, velocity: 0.62)) }
        hits += hats(c, on: 0.45, off: 0.3, until: end, skip: { $0 == 0 && c.lift })
        if c.lift { hits.append(Hit(beat: 0, piece: .crash, velocity: 0.7)) }
        if c.fill {
            hits += [Hit(beat: 3, piece: .snare, velocity: 0.5), Hit(beat: 3.5, piece: .snare, velocity: 0.6),
                     Hit(beat: 3.75, piece: .snare, velocity: 0.72)]
        }
        let answer = c.variation == 0 ? c.fifth : 12
        var bass = [Note(beat: 0, beats: 0.9, interval: 0, velocity: 1), Note(beat: 2, beats: 0.9, interval: answer, velocity: 0.9)]
        if !c.fill { bass.append(Note(beat: 3, beats: 0.45, interval: answer == 12 ? c.fifth : 12, velocity: 0.55)) }
        var comp: [Stroke] = []
        if c.chord {
            comp = [Stroke(1, 0.3, 0.62, .chop)]
            if !c.fill { comp.append(Stroke(3, 0.3, 0.64, .chop)) }
            if c.lift { comp.append(Stroke(0, 0.9, 0.5, .ring)) }
        }
        return BandGroove(hits: hits, bass: bass, comp: comp)
    }

    // MARK: Funk

    /// Sixteenth hats, the kick on one, its "a" and the "and" of three, a hard backbeat with ghost notes between;
    /// a syncopated bass with octave pops; the guitar scratching sixteenths, accented on the backbeat and the "and"s.
    static func funk(_ c: Context) -> BandGroove {
        let end = c.fill ? 3.0 : 4.0
        var hits: [Hit] = [Hit(beat: 0, piece: .kick, velocity: 1), Hit(beat: 0.75, piece: .kick, velocity: 0.7),
                           Hit(beat: 2.5, piece: .kick, velocity: 0.85), Hit(beat: 1, piece: .snare, velocity: 0.9),
                           Hit(beat: 1.75, piece: .snare, velocity: 0.16), Hit(beat: 2.25, piece: .snare, velocity: 0.16)]
        if !c.fill {
            hits += [Hit(beat: 3, piece: .snare, velocity: 0.95), Hit(beat: 3.25, piece: .snare, velocity: 0.16),
                     Hit(beat: 3.5, piece: .openhat, velocity: 0.4)]
            if c.variation == 1 { hits.append(Hit(beat: 3.75, piece: .kick, velocity: 0.6)) }
        }
        for k in 0..<16 {
            let beat = Double(k) * 0.25
            guard beat < end, !(beat == 3.5 || beat == 3.75) || c.fill else { continue }
            hits.append(Hit(beat: beat, piece: .hat, velocity: k % 4 == 0 ? 0.55 : k % 2 == 0 ? 0.4 : 0.22))
        }
        if c.fill {
            for k in 0..<4 { hits.append(Hit(beat: 3 + 0.25 * Double(k), piece: .snare, velocity: 0.4 + 0.12 * Float(k))) }
        }
        var bass = [Note(beat: 0, beats: 0.4, interval: 0, velocity: 1), Note(beat: 0.75, beats: 0.2, interval: 0, velocity: 0.7),
                    Note(beat: 1.5, beats: 0.2, interval: 12, velocity: 0.9), Note(beat: 2.5, beats: 0.4, interval: 0, velocity: 0.9)]
        if !c.fill {
            bass += [Note(beat: 3.25, beats: 0.2, interval: c.fifth, velocity: 0.75), Note(beat: 3.5, beats: 0.2, interval: 12, velocity: 0.85),
                     Note(beat: 3.75, beats: 0.2, interval: c.fifth, velocity: 0.6)]
        }
        var comp: [Stroke] = []
        if c.chord {
            for k in 0..<16 {
                let beat = Double(k) * 0.25
                guard beat < end else { break }
                let accent = k == 4 || k == 12 ? 0.7 : k % 4 == 2 ? 0.5 : 0.2
                comp.append(Stroke(beat, 0.18, accent, .chop, up: k % 2 == 1))
            }
        }
        return BandGroove(hits: hits, bass: bass, comp: comp)
    }

    // MARK: Ballad

    /// Soft: the kick on one and the "and" of three, cross-stick on two and four, quiet hats; the bass in half
    /// notes; the piano breaking the chord into eighths over the pedal; a soft crash opens a phrase, the toms fill.
    static func ballad(_ c: Context) -> BandGroove {
        let end = c.fill ? 3.0 : 4.0
        var hits: [Hit] = [Hit(beat: 0, piece: .kick, velocity: 0.8), Hit(beat: and(2, c), piece: .kick, velocity: 0.5),
                           Hit(beat: 1, piece: .xstick, velocity: 0.6)]
        if !c.fill { hits.append(Hit(beat: 3, piece: .xstick, velocity: 0.62)) }
        hits += hats(c, on: 0.32, off: 0.16, until: end, skip: { $0 == 0 && c.lift })
        if c.lift { hits.append(Hit(beat: 0, piece: .crash, velocity: 0.5)) }
        if c.fill {
            hits += [Hit(beat: 3, piece: .tomhi, velocity: 0.45), Hit(beat: 3.5, piece: .tomlo, velocity: 0.55),
                     Hit(beat: 3.75, piece: .tomlo, velocity: 0.5)]
        }
        let bass = c.fill ? [Note(beat: 0, beats: 3.8, interval: 0, velocity: 0.85)]
                          : [Note(beat: 0, beats: 1.9, interval: 0, velocity: 0.9),
                             Note(beat: 2, beats: 1.9, interval: c.variation == 0 ? c.fifth : 12, velocity: 0.75)]
        var comp: [Stroke] = []
        if c.chord {
            if c.fill {
                comp = [Stroke(0, 3.9, 0.5, .piano)]
            } else {
                let tones = [0, 1, 2, 3, 2, 1, 2, 3]
                for k in 0..<8 {
                    let beat = k % 2 == 0 ? Double(k / 2) : and(Double(k / 2), c)
                    comp.append(Stroke(beat, 4.2 - beat, k == 0 ? 0.48 : 0.36, .arpeggio, tone: tones[k]))
                }
            }
        }
        return BandGroove(hits: hits, bass: bass, comp: comp)
    }

    /// A ballad in 3/4: kick on one, cross-stick on two and three, the bass held, the piano broken into eighths.
    static func waltzBallad(_ c: Context) -> BandGroove {
        var hits: [Hit] = [Hit(beat: 0, piece: .kick, velocity: 0.8), Hit(beat: 1, piece: .xstick, velocity: 0.45)]
        if c.fill {
            hits += [Hit(beat: 2, piece: .tomhi, velocity: 0.4), Hit(beat: 2.5, piece: .tomlo, velocity: 0.5)]
        } else {
            hits.append(Hit(beat: 2, piece: .xstick, velocity: 0.4))
        }
        hits += hats(c, on: 0.3, off: 0.14, until: c.fill ? 2 : 3)
        let bass = [Note(beat: 0, beats: 2.8, interval: 0, velocity: 0.9)]
        var comp: [Stroke] = []
        if c.chord {
            let tones = [0, 1, 2, 3, 2, 1]
            for k in 0..<6 {
                let beat = k % 2 == 0 ? Double(k / 2) : and(Double(k / 2), c)
                comp.append(Stroke(beat, 3.2 - beat, k == 0 ? 0.46 : 0.34, .arpeggio, tone: tones[k]))
            }
        }
        return BandGroove(hits: hits, bass: bass, comp: comp)
    }

    // MARK: Compound meters

    /// 6/8 (and 12/8), counted in eighths: kick on the first group, the backbeat on the second, every eighth on the
    /// hats. Rock chugs power chords on the eighths; a ballad breaks the chord on the piano; the rest comp in dotted
    /// groups on the piano. The toms take the last group of a fill.
    static func compoundBar(_ style: BandStyle, _ c: Context) -> BandGroove {
        let meter = max(6, c.meter)
        let groups = meter / 3
        let soft = style == .ballad
        let hard = style == .rock
        let fillFrom = c.fill ? meter - 3 : meter
        var hits: [Hit] = []
        for g in 0..<groups where g * 3 < fillFrom {
            let beat = Double(g * 3)
            if g % 2 == 0 {
                hits.append(Hit(beat: beat, piece: .kick, velocity: soft ? 0.8 : 1))
                if hard { hits.append(Hit(beat: beat + 2, piece: .kick, velocity: 0.55)) }
            } else {
                hits.append(Hit(beat: beat, piece: soft ? .xstick : .snare, velocity: soft ? 0.55 : hard ? 0.95 : 0.75))
                if style == .pop { hits.append(Hit(beat: beat, piece: .tamb, velocity: 0.45)) }
            }
        }
        let accented: Float = soft ? 0.28 : hard ? 0.7 : 0.5
        let plain: Float = soft ? 0.15 : hard ? 0.48 : 0.32
        for e in 0..<fillFrom {
            if e == 0 && c.lift {
                hits.append(Hit(beat: 0, piece: .crash, velocity: 0.75))
            } else {
                hits.append(Hit(beat: Double(e), piece: .hat, velocity: e % 3 == 0 ? accented : plain))
            }
        }
        if c.fill {
            let start = Double(fillFrom)
            hits += soft ? [Hit(beat: start, piece: .tomhi, velocity: 0.45), Hit(beat: start + 1.5, piece: .tomlo, velocity: 0.55)]
                         : [Hit(beat: start, piece: .snare, velocity: 0.7), Hit(beat: start + 1, piece: .tomhi, velocity: 0.8),
                            Hit(beat: start + 2, piece: .tomlo, velocity: 0.9)]
        }
        let answer = c.variation == 0 ? c.fifth : 12
        var bass: [Note] = []
        if soft {
            bass = [Note(beat: 0, beats: Double(meter) - 0.2, interval: 0, velocity: 0.9)]
        } else {
            for g in 0..<groups {
                bass.append(Note(beat: Double(g * 3), beats: 2.7, interval: g % 2 == 0 ? 0 : answer, velocity: g == 0 ? 1 : 0.8))
            }
        }
        var comp: [Stroke] = []
        if c.chord {
            if hard {
                for e in 0..<fillFrom { comp.append(Stroke(Double(e), 0.8, e % 3 == 0 ? 0.62 : 0.45, .power)) }
                if c.fill { comp.append(Stroke(Double(fillFrom), 2.8, 0.7, .ring)) }
            } else if soft {
                let tones = [0, 1, 2, 3, 2, 1]
                for e in 0..<meter {
                    comp.append(Stroke(Double(e), Double(meter) + 0.3 - Double(e), e == 0 ? 0.46 : 0.34, .arpeggio, tone: tones[e % 6]))
                }
            } else {
                comp = (0..<groups).map { (g: Int) -> Stroke in Stroke(Double(g * 3), 2.8, g == 0 ? 0.58 : 0.46, .piano) }
            }
        }
        return BandGroove(hits: hits, bass: bass, comp: comp)
    }
}
