import SwiftUI
import TimbreCore
import UIKit

// MARK: - What the sheet shows

/// What the lead sheet writes a melody as on a fretted course: the staff, the tab under it, or both.
enum NotationMode: String, CaseIterable, Identifiable {
    case staff, tab, both

    var id: String { rawValue }
    var showsStaff: Bool { self != .tab }
    var showsTab: Bool { self != .staff }

    var title: LocalizedStringKey {
        switch self {
        case .staff: return "Staff"
        case .tab: return "Tab"
        case .both: return "Both"
        }
    }

    /// The UserDefaults key the choice is kept under.
    static let storageKey = "songsheet.notation"
}

/// Where a melody's notes are played, for its tab: by note index, the string and fret (nil where none is known).
struct NotationTab: Equatable {
    let frets: [Fretting?]
    let strings: Int
    /// String 1 (the thinnest) on the top line, as tab is read; else the thickest (Settings › String order).
    let thinnestOnTop: Bool
}

/// A chord symbol over the staff: its bar, the sixteenth it comes in on, and its name as written.
struct ChordMark: Equatable {
    let bar: Int
    let tick: Int
    let name: String

    /// "F#m" as "F♯m", "Bbmaj7" as "B♭maj7", "D/F#" as "D/F♯": a lead sheet's signs, as the app writes notes
    /// everywhere (`NoteNames.glyphs`).
    static func engraved(_ symbol: String) -> String { NoteNames.glyphs(symbol) }
}

/// When a note sounds, in bars from the top of the song.
struct NoteSpan: Equatable {
    let start: Double
    let end: Double
}

// MARK: - Type

/// The text faces of a sheet: chord symbols, the words, fret numbers, the time signature, the clef's 8 and the TAB
/// label, all sized from the staff's space so they read in proportion.
enum NotationFace: Hashable {
    case chord, lyric, fret, time, octave, tabLabel
}

struct NotationType: Equatable {
    /// The gap between two staff lines, in points.
    let space: CGFloat
    /// The words' and chord symbols' point sizes (Dynamic Type grows them a little).
    let lyric: CGFloat
    let chord: CGFloat

    /// The gap between two lines of the tab.
    var tabGap: CGFloat { (space * 1.55).rounded() }

    func size(_ face: NotationFace) -> CGFloat {
        switch face {
        case .chord: return chord
        case .lyric: return lyric
        case .fret: return (tabGap * 0.86).rounded()
        case .time: return space * 2.9
        case .octave: return space * 1.2
        case .tabLabel: return (tabGap * 0.82).rounded()
        }
    }

    func font(_ face: NotationFace) -> Font {
        let points = self.size(face)
        switch face {
        case .chord, .fret: return .custom("Sora-SemiBold", fixedSize: points)
        case .lyric: return .system(size: points)
        case .time: return .system(size: points, weight: .black, design: .serif)
        case .octave: return .system(size: points, weight: .bold, design: .serif)
        case .tabLabel: return .system(size: points, weight: .heavy)
        }
    }

    private func uiFont(_ face: NotationFace) -> UIFont {
        let points = self.size(face)
        switch face {
        case .chord, .fret: return UIFont(name: "Sora-SemiBold", size: points) ?? .systemFont(ofSize: points, weight: .semibold)
        case .lyric: return .systemFont(ofSize: points)
        case .tabLabel: return .systemFont(ofSize: points, weight: .heavy)
        case .time, .octave:
            let base = UIFont.systemFont(ofSize: points, weight: face == .time ? .black : .bold)
            guard let serif = base.fontDescriptor.withDesign(.serif) else { return base }
            return UIFont(descriptor: serif, size: points)
        }
    }

    /// How wide `text` sets in `face`.
    func width(_ text: String, _ face: NotationFace) -> CGFloat {
        ceil((text as NSString).size(withAttributes: [.font: uiFont(face)]).width)
    }
}

// MARK: - An engraved line

/// What a mark lights with while the song plays: the frame (staff lines, barlines), fixed ink (clefs, rests, chord
/// symbols), or a note (its head, stem, accidental, ties and fret) or its syllable, which follow that note.
enum MarkRole: Equatable {
    case frame
    case ink
    case note(Int)
    case lyric(Int)
}

enum EngravedMark {
    case shape(Path, evenOdd: Bool, role: MarkRole)
    case text(String, at: CGPoint, face: NotationFace, anchor: UnitPoint, role: MarkRole)
}

/// One bar of a line, to place the playhead: its edges and the x of each sixteenth where something starts.
struct EngravedBar {
    let index: Int
    let start: CGFloat
    let end: CGFloat
    let ticks: [Int]
    let xs: [CGFloat]
    let barTicks: Int

    /// The x of `fraction` (0…1) of the way through the bar: from slot to slot, as the notes are spaced.
    func x(at fraction: Double) -> CGFloat {
        let tick = max(0, min(1, fraction)) * Double(barTicks)
        guard !ticks.isEmpty else { return start + (end - start) * CGFloat(fraction) }
        var slot = 0
        while slot + 1 < ticks.count && Double(ticks[slot + 1]) <= tick { slot += 1 }
        let from = Double(ticks[slot])
        let to = Double(slot + 1 < ticks.count ? ticks[slot + 1] : barTicks)
        let right = slot + 1 < xs.count ? xs[slot + 1] : end
        let share = to > from ? CGFloat((tick - from) / (to - from)) : 0
        return xs[slot] + (right - xs[slot]) * share
    }
}

/// A line of the sheet, engraved once (layout is cached with the sheet) and drawn by `EngravedLineView`.
struct EngravedLine: Identifiable {
    /// Unique within its sheet and stable across redraws, so a line's view compares cheaply.
    let id: String
    let width: CGFloat
    let height: CGFloat
    let type: NotationType
    let marks: [EngravedMark]
    let bars: [EngravedBar]
    /// The notes in the line: when each sounds, and where its head (or fret number) sits, to light it.
    let spans: [Int: NoteSpan]
    let heads: [Int: CGPoint]
    /// The playhead's vertical reach.
    let playTop: CGFloat
    let playBottom: CGFloat

    /// The playhead's x at `position` (bars from the top of the song), nil when it is in another line.
    func playheadX(at position: Double) -> CGFloat? {
        let bar = Int(position.rounded(.down))
        guard let found = bars.first(where: { $0.index == bar }) else { return nil }
        return found.x(at: position - Double(bar))
    }
}

// MARK: - The engraver

/// Lays a score out as lines: each bar spaced by how long its notes last (and wide enough for its accidentals, dots,
/// flags, chord symbols, words and frets), the bars of a passage broken into the fewest even lines that fit
/// (`NotationLayout.lines`) and stretched to the width, then every mark placed: staff and clef, key and time, ledger
/// lines, heads, stems, flags and beams, dots, ties (over a barline and a line break too), rests, chord symbols, the
/// words with their hyphens and extenders, and the tab with its numbers cut into the strings (with rhythm stems
/// under it when it stands alone).
struct NotationEngraver {
    let score: NotationScore
    /// Each note's syllable as `LeadChart.lyrics` gives it ("Twin-", `TimedNote.held`, nil).
    let lyrics: [String?]
    let chords: [ChordMark]
    let tab: NotationTab?
    let spans: [NoteSpan]
    let showStaff: Bool
    let showTab: Bool
    let type: NotationType
    /// A song sheet: barlines and a time signature. A phrase (a note step) has neither.
    var barlines = true
    var timeSignature = true

    private var sp: CGFloat { type.space }
    private var hasLyrics: Bool { lyrics.contains { $0 != nil && $0 != TimedNote.held } }
    private var hasChords: Bool { !chords.isEmpty }
    private var tabShown: Bool { showTab && tab != nil }
    private var staffShown: Bool { showStaff || !tabShown }

    // MARK: Spacing a bar

    private struct Spacing {
        var ticks: [Int]
        var widths: [CGFloat]
        var weights: [CGFloat]
        var lead: CGFloat
        var natural: CGFloat { lead + widths.reduce(0, +) }

        mutating func spread(_ extra: CGFloat, over range: Range<Int>) {
            guard extra > 0, !range.isEmpty else { return }
            let shares = NotationLayout.share(Double(extra), weights: range.map { Double(weights[$0]) })
            for (offset, index) in range.enumerated() { widths[index] += CGFloat(shares[offset]) }
        }
    }

    /// A syllable as read ("Twin" joining the next), nil for a held note or none.
    private func syllable(_ note: Int) -> (text: String, joins: Bool)? {
        guard note < lyrics.count, let raw = lyrics[note], raw != TimedNote.held else { return nil }
        if raw.hasSuffix("-") { return (text: String(raw.dropLast()), joins: true) }
        return (text: raw, joins: false)
    }

    private func accidentalGlyph(_ alter: Int) -> NotationGlyph {
        switch alter {
        case 2: return .doubleSharp
        case 1: return .sharp
        case -1: return .flat
        case -2: return .doubleFlat
        default: return .natural
        }
    }

    private func spacing(_ measure: NotationMeasure, chordsHere: [ChordMark]) -> Spacing {
        let barTicks = score.meter.barTicks
        var starts = Set(measure.events.map(\.start))
        for chord in chordsHere where chord.tick < barTicks { starts.insert(chord.tick) }
        starts.insert(0)
        let ticks = starts.sorted()
        var at: [Int: NotationEvent] = [:]
        for event in measure.events { at[event.start] = event }

        func left(_ tick: Int) -> CGFloat {
            guard let event = at[tick], !event.fillsBar else { return 0 }
            if event.isRest { return 0.6 * sp }
            var extent = 0.62 * sp
            if staffShown, let alter = event.accidental { extent += 0.25 * sp + accidentalGlyph(alter).width * sp }
            if tabShown { extent = max(extent, 0.75 * sp) }
            return extent
        }
        func right(_ tick: Int) -> CGFloat {
            guard let event = at[tick], !event.fillsBar else { return 0 }
            var extent = event.isRest ? 0.6 * sp : 0.62 * sp
            if event.duration.dotted { extent += 0.9 * sp }
            if !event.isRest, event.beam == nil, event.duration.beams > 0, event.stemUp || !staffShown { extent += 0.95 * sp }
            if tabShown { extent = max(extent, 0.75 * sp) }
            return extent
        }

        var widths: [CGFloat] = []
        var weights: [CGFloat] = []
        for (i, tick) in ticks.enumerated() {
            let next = i + 1 < ticks.count ? ticks[i + 1] : barTicks
            let fills = at[tick]?.fillsBar ?? false
            let base = CGFloat(NotationLayout.space(ticks: fills ? barTicks : next - tick)) * sp
            let clearance = i + 1 < ticks.count ? right(tick) + left(next) + 0.45 * sp : right(tick) + 1.0 * sp
            widths.append(max(base, clearance))
            weights.append(base)
        }
        var result = Spacing(ticks: ticks, widths: widths, weights: weights, lead: max(1.2 * sp, 0.9 * sp + left(0)))

        // The words: neighbouring syllables clear each other (with room for a hyphen inside a word).
        if hasLyrics {
            var sung: [(slot: Int, width: CGFloat, joins: Bool)] = []
            for (slot, tick) in ticks.enumerated() {
                guard let event = at[tick], let note = event.note, !event.continued, let words = syllable(note) else { continue }
                sung.append((slot: slot, width: type.width(words.text, .lyric), joins: words.joins))
            }
            let hyphen = max(8, type.lyric * 0.8)
            let gap = type.lyric * 0.45
            if sung.count >= 2 {
                for k in 0..<(sung.count - 1) {
                    let a = sung[k], b = sung[k + 1]
                    let need = a.width / 2 + b.width / 2 + (a.joins ? hyphen : gap)
                    let have = result.widths[a.slot..<b.slot].reduce(0, +)
                    if have < need { result.spread(need - have, over: a.slot..<b.slot) }
                }
            }
            if let first = sung.first {
                let before = result.lead + result.widths[0..<first.slot].reduce(0, +)
                let need = first.width / 2 - 0.2 * sp
                if before < need { result.lead += need - before }
            }
            if let last = sung.last {
                let after = result.widths[last.slot...].reduce(0, +)
                let need = last.width / 2 + (last.joins ? hyphen / 2 + 2 : gap / 2)
                if after < need { result.spread(need - after, over: last.slot..<result.widths.count) }
            }
        }

        // Chord symbols: each clear of the next.
        let marks = chordsHere.sorted { $0.tick < $1.tick }
        for (k, chord) in marks.enumerated() {
            guard let slot = ticks.firstIndex(of: chord.tick) else { continue }
            let label = type.width(chord.name, .chord)
            if k + 1 < marks.count, let next = ticks.firstIndex(of: marks[k + 1].tick), next > slot {
                let have = result.widths[slot..<next].reduce(0, +)
                let need = label + 0.7 * sp
                if have < need { result.spread(need - have, over: slot..<next) }
            } else {
                let have = result.widths[slot...].reduce(0, +)
                let need = label - 0.6 * sp
                if have < need { result.spread(need - have, over: slot..<result.widths.count) }
            }
        }
        return result
    }

    // MARK: The head of a line

    private var clefWidth: CGFloat {
        guard staffShown else { return 2.2 * sp }
        return (score.clef.sign == .treble ? NotationGlyph.trebleClef.width : NotationGlyph.bassClef.width) * sp
    }

    private var keyWidth: CGFloat {
        let count = staffShown ? abs(score.key.fifths) : 0
        return count > 0 ? CGFloat(count) * sp + 0.5 * sp : 0
    }

    private var timeWidth: CGFloat {
        guard staffShown, timeSignature else { return 0 }
        let top = type.width("\(score.meter.beats)", .time)
        let bottom = type.width("\(score.meter.unit)", .time)
        return max(top, bottom) + 1.0 * sp
    }

    private var prefix: CGFloat { 0.5 * sp + clefWidth + 0.7 * sp + keyWidth }

    // MARK: Engraving a passage

    /// Bars `range` as lines `width` wide. `opening`: the sheet's first passage (its first line shows the time);
    /// `closes`: a double barline ends it; `ends`: the song's final barline does. `carried` is the chord already
    /// sounding as the passage starts, written over its first note when none changes there.
    func engrave(bars range: Range<Int>, width: CGFloat, opening: Bool, closes: Bool, ends: Bool, carried: String?, key: String) -> [EngravedLine] {
        let measures = range.compactMap { score.measure($0) }
        guard !measures.isEmpty else { return [] }
        var chordsByBar: [Int: [ChordMark]] = [:]
        for chord in chords where range.contains(chord.bar) { chordsByBar[chord.bar, default: []].append(chord) }
        if let carried, let first = measures.first, !(chordsByBar[first.index] ?? []).contains(where: { $0.tick == 0 }) {
            chordsByBar[first.index, default: []].append(ChordMark(bar: first.index, tick: 0, name: carried))
        }
        let spacings = measures.map { spacing($0, chordsHere: chordsByBar[$0.index] ?? []) }
        let firstPrefix = prefix + (opening ? timeWidth : 0)
        let breaks = NotationLayout.lines(widths: spacings.map { Double($0.natural) }, available: Double(width),
                                          firstPrefix: Double(firstPrefix), prefix: Double(prefix))
        var lines: [EngravedLine] = []
        for (number, lineRange) in breaks.enumerated() {
            let head = number == 0 ? firstPrefix : prefix
            var parts = Array(spacings[lineRange])
            let natural = parts.reduce(CGFloat(0)) { $0 + $1.natural }
            let room = width - head
            let lastLine = number == breaks.count - 1
            if natural > room {
                let factor = max(0.5, room / max(1, natural))
                for k in parts.indices {
                    parts[k].lead *= factor
                    parts[k].widths = parts[k].widths.map { $0 * factor }
                }
            } else {
                // A short last line stretches only a little; the others fill the width.
                let sparse = lastLine && breaks.count > 1 && natural < room * 0.55
                let extra = sparse ? natural * 0.25 : room - natural
                let shares = NotationLayout.share(Double(extra), weights: parts.map { Double($0.weights.reduce(0, +)) })
                for k in parts.indices {
                    let inner = NotationLayout.share(shares[k], weights: parts[k].weights.map { Double($0) })
                    for slot in parts[k].widths.indices { parts[k].widths[slot] += CGFloat(inner[slot]) }
                }
            }
            let lineMeasures = Array(measures[lineRange])
            let next = lineRange.upperBound < measures.count ? measures[lineRange.upperBound] : nil
            lines.append(line(lineMeasures, spacings: parts, head: head, showTime: opening && number == 0,
                              closes: lastLine && closes, ends: lastLine && ends, nextMeasure: next,
                              id: "\(key).\(lineMeasures[0].index)", chordsByBar: chordsByBar))
        }
        return lines
    }

    // MARK: Vertical layout

    private func rows(for measures: [NotationMeasure]) -> NotationRows {
        var high: CGFloat = 8
        var low: CGFloat = 0
        if staffShown {
            high = max(high, score.clef.sign == .treble ? 11.6 : 8.4)
            low = min(low, score.clef.sign == .treble ? (score.clef.octaveDown ? -6.4 : -3.8) : (score.clef.octaveDown ? -2.4 : 0))
            if score.key.fifths != 0 { high = max(high, 11.8) }
            for measure in measures {
                for event in measure.events where !event.isRest {
                    let p = CGFloat(event.position)
                    high = max(high, p + 1.2)
                    low = min(low, p - 1.2)
                    if let alter = event.accidental {
                        high = max(high, p + (alter < 0 ? 5 : 3))
                        low = min(low, p - 3)
                    }
                    if event.duration.hasStem {
                        let extra: CGFloat = event.duration.beams > 1 ? 1.7 : 0.6
                        if event.stemUp { high = max(high, max(p + 7, 4) + extra) } else { low = min(low, min(p - 7, 4) - extra) }
                    }
                    if event.tied || event.continued {
                        if event.stemUp { low = min(low, p - 2.6) } else { high = max(high, p + 2.6) }
                    }
                }
            }
        }
        var rows = NotationRows(half: sp / 2)
        var y: CGFloat = 0
        if hasChords {
            rows.chordBaseline = type.chord * 1.05
            y = type.chord * 1.45
        }
        y += 0.25 * sp
        if staffShown {
            rows.staffTop = y + (high - 8) / 2 * sp
            rows.bottomLine = rows.staffTop + 4 * sp
            y = rows.bottomLine + (-low) / 2 * sp
        }
        if hasLyrics && staffShown {
            y += 0.3 * sp
            rows.lyricMiddle = y + type.lyric * 0.6
            y += type.lyric * 1.3
        }
        if tabShown, let tab {
            y += staffShown ? 0.9 * sp : 0.5 * sp
            rows.tabTop = y
            rows.tabBottom = y + CGFloat(max(1, tab.strings - 1)) * type.tabGap
            y = rows.tabBottom
            if !staffShown { y += 3.4 * sp }
        }
        if hasLyrics && !staffShown {
            y += 0.4 * sp
            rows.lyricMiddle = y + type.lyric * 0.6
            y += type.lyric * 1.3
        }
        rows.height = ceil(y + 0.4 * sp)
        return rows
    }

    // MARK: Placing the marks

    private func line(_ measures: [NotationMeasure], spacings: [Spacing], head: CGFloat, showTime: Bool, closes: Bool, ends: Bool,
                      nextMeasure: NotationMeasure?, id: String, chordsByBar: [Int: [ChordMark]]) -> EngravedLine {
        let rows = self.rows(for: measures)
        var drawing = Drawing(space: sp, rows: rows)

        // Bars, left to right.
        var x = head
        var bars: [EngravedBar] = []
        for (k, measure) in measures.enumerated() {
            let spacing = spacings[k]
            var xs: [CGFloat] = []
            var cursor = x + spacing.lead
            for width in spacing.widths {
                xs.append(cursor)
                cursor += width
            }
            bars.append(EngravedBar(index: measure.index, start: x, end: cursor, ticks: spacing.ticks, xs: xs, barTicks: score.meter.barTicks))
            x = cursor
        }
        let end = x

        drawFrame(&drawing, end: end, head: head, showTime: showTime)
        var heads: [Int: CGPoint] = [:]
        var lineSpans: [Int: NoteSpan] = [:]
        var sung: [(note: Int, x: CGFloat, width: CGFloat, joins: Bool, text: String)] = []
        var extenders: [Int: CGFloat] = [:]
        var lastSung: Int?
        var heldFromStart: CGFloat?
        for (k, measure) in measures.enumerated() {
            let bar = bars[k]
            let following: NotationMeasure? = k + 1 < measures.count ? measures[k + 1] : nextMeasure
            let nextOnLine = k + 1 < measures.count
            var placed: [Int: CGFloat] = [:]
            for (index, event) in measure.events.enumerated() {
                guard let slot = bar.ticks.firstIndex(of: event.start) else { continue }
                let noteX = bar.xs[slot]
                placed[index] = noteX
                if event.isRest {
                    drawRest(&drawing, event, x: noteX, bar: bar)
                    continue
                }
                guard let note = event.note else { continue }
                if note < spans.count { lineSpans[note] = spans[note] }
                if staffShown {
                    drawNote(&drawing, event, note: note, x: noteX)
                    if heads[note] == nil { heads[note] = CGPoint(x: noteX, y: rows.y(event.position)) }
                }
                if tabShown, !event.continued, let tab, note < tab.frets.count, let fret = tab.frets[note] {
                    let point = drawing.fret(fret, x: noteX, tab: tab, type: type, note: note)
                    if heads[note] == nil { heads[note] = point }
                }
                if !staffShown && tabShown { drawTabRhythm(&drawing, event, note: note, x: noteX) }
                // The words.
                if hasLyrics, !event.continued {
                    if let words = syllable(note) {
                        sung.append((note: note, x: noteX, width: type.width(words.text, .lyric), joins: words.joins, text: words.text))
                        lastSung = sung.count - 1
                    } else if note < lyrics.count, lyrics[note] == TimedNote.held {
                        if let lastSung, !sung[lastSung].joins {
                            extenders[lastSung] = noteX + 0.62 * sp
                        } else if lastSung == nil {
                            heldFromStart = noteX + 0.62 * sp
                        }
                    }
                }
            }
            // Beams, then ties.
            if staffShown {
                for beam in measure.beams { drawBeam(&drawing, beam, in: measure, xs: placed) }
            } else if tabShown {
                for beam in measure.beams { drawTabBeam(&drawing, beam, in: measure, xs: placed) }
            }
            if staffShown {
                for (index, event) in measure.events.enumerated() where event.tied {
                    guard let from = placed[index] else { continue }
                    var to: CGFloat
                    if index + 1 < measure.events.count, let next = placed[index + 1] {
                        to = next
                    } else if nextOnLine, following != nil, k + 1 < bars.count, let firstX = bars[k + 1].xs.first {
                        to = firstX
                    } else {
                        to = end + 0.9 * sp
                    }
                    if to > end { to = end + 0.9 * sp }
                    drawing.tie(from: from + (event.duration.dotted ? 1.2 * sp : 0), to: to, position: event.position,
                                stemUp: event.stemUp, role: .note(event.note ?? 0), lineEnd: end)
                }
                if k == 0, let first = measure.events.first, first.continued, !first.isRest, let firstX = placed[0] {
                    drawing.tie(from: head - 1.4 * sp, to: firstX, position: first.position, stemUp: first.stemUp,
                                role: .note(first.note ?? 0), lineEnd: end)
                }
            }
            // Chord symbols.
            for chord in (chordsByBar[measure.index] ?? []) {
                guard let slot = bar.ticks.firstIndex(of: chord.tick) else { continue }
                drawing.marks.append(.text(chord.name, at: CGPoint(x: bar.xs[slot] - 0.45 * sp, y: rows.chordBaseline),
                                           face: .chord, anchor: .bottomLeading, role: .ink))
            }
            // The barline.
            if barlines {
                let last = k == measures.count - 1
                drawing.barline(at: bar.end, kind: last && ends ? .ending : last && closes ? .double : .single)
            }
        }
        if let tab, tabShown { drawing.strings(tab: tab, gap: type.tabGap, from: 0, to: end) }
        if hasLyrics { drawLyrics(&drawing, sung: sung, extenders: extenders, heldFromStart: heldFromStart, head: head, end: end) }

        let top = staffShown ? rows.staffTop - 1.2 * sp : (rows.tabTop ?? 0) - 0.8 * sp
        let bottom = tabShown ? rows.tabBottom + 0.6 * sp : rows.bottomLine + 1.2 * sp
        return EngravedLine(id: id, width: end + (barlines ? 0 : 0.5 * sp), height: rows.height, type: type, marks: drawing.marks,
                            bars: bars, spans: lineSpans, heads: heads, playTop: max(0, top), playBottom: min(rows.height, bottom))
    }

    /// Staff and tab lines, the clef or TAB, the key and the time.
    private func drawFrame(_ drawing: inout Drawing, end: CGFloat, head: CGFloat, showTime: Bool) {
        let rows = drawing.rows
        let rule = max(0.8, 0.11 * sp)
        if staffShown {
            for k in 0..<5 {
                let y = rows.staffTop + CGFloat(k) * sp
                drawing.rect(CGRect(x: 0, y: y - rule / 2, width: end, height: rule), role: .frame)
            }
            let clefX = 0.5 * sp
            drawing.glyph(score.clef.sign == .treble ? .trebleClef : .bassClef, at: CGPoint(x: clefX, y: rows.bottomLine), role: .ink)
            if score.clef.octaveDown {
                let point = score.clef.sign == .treble
                    ? CGPoint(x: clefX + 1.3 * sp, y: rows.bottomLine + 2.5 * sp)
                    : CGPoint(x: clefX + 1.1 * sp, y: rows.bottomLine + 0.85 * sp)
                drawing.marks.append(.text("8", at: point, face: .octave, anchor: .center, role: .ink))
            }
            var keyX = clefX + clefWidth + 0.7 * sp
            let glyph: NotationGlyph = score.key.fifths > 0 ? .sharp : .flat
            for position in score.clef.positions(of: score.key) {
                drawing.glyph(glyph, at: CGPoint(x: keyX, y: rows.y(position)), role: .ink)
                keyX += sp
            }
            if showTime {
                let centre = clefX + clefWidth + 0.7 * sp + keyWidth + timeWidth / 2 - 0.3 * sp
                drawing.marks.append(.text("\(score.meter.beats)", at: CGPoint(x: centre, y: rows.y(6)), face: .time, anchor: .center, role: .ink))
                drawing.marks.append(.text("\(score.meter.unit)", at: CGPoint(x: centre, y: rows.y(2)), face: .time, anchor: .center, role: .ink))
            }
        }
        if tabShown, let tabTop = rows.tabTop {
            let middle = (tabTop + rows.tabBottom) / 2
            let step = min(type.tabGap * 1.0, (rows.tabBottom - tabTop) / 2.6)
            for (k, letter) in ["T", "A", "B"].enumerated() {
                drawing.marks.append(.text(letter, at: CGPoint(x: 0.5 * sp + 1.0 * sp, y: middle + CGFloat(k - 1) * step),
                                           face: .tabLabel, anchor: .center, role: .ink))
            }
            if staffShown {
                // The system's left edge, joining the staff and its tab.
                drawing.rect(CGRect(x: 0, y: rows.staffTop, width: max(1, 0.14 * sp), height: rows.tabBottom - rows.staffTop), role: .frame)
            }
        }
    }

    // MARK: Notes and rests

    private func drawNote(_ drawing: inout Drawing, _ event: NotationEvent, note: Int, x: CGFloat) {
        let rows = drawing.rows
        let role = MarkRole.note(note)
        let y = rows.y(event.position)
        let half = 0.62 * sp
        // Ledger lines.
        if event.position <= -2 {
            for p in stride(from: -2, through: event.position, by: -2) { drawing.ledger(x: x, y: rows.y(p)) }
        }
        if event.position >= 10 {
            for p in stride(from: 10, through: event.position, by: 2) { drawing.ledger(x: x, y: rows.y(p)) }
        }
        if let alter = event.accidental, !score.slashes {
            let glyph = accidentalGlyph(alter)
            drawing.glyph(glyph, at: CGPoint(x: x - half - 0.22 * sp - glyph.width * sp, y: y), role: role)
        }
        let headGlyph: NotationGlyph
        if score.slashes {
            headGlyph = event.duration.hollow ? .slashHollow : .slashHead
        } else {
            headGlyph = event.duration.level == 0 ? .wholeHead : event.duration.hollow ? .halfHead : .blackHead
        }
        drawing.glyph(headGlyph, at: CGPoint(x: x, y: y), role: role)
        if event.duration.dotted {
            let dotY = event.position % 2 == 0 ? rows.y(event.position + 1) : y
            drawing.glyph(.dot, at: CGPoint(x: x + half + 0.5 * sp, y: dotY), role: role)
        }
        guard event.duration.hasStem, event.beam == nil else { return }
        let stem = stemX(x, up: event.stemUp)
        let flags = event.duration.beams
        var tip = event.stemUp ? min(y - 3.5 * sp, rows.y(4)) : max(y + 3.5 * sp, rows.y(4))
        if flags > 1 { tip += event.stemUp ? -0.7 * sp : 0.7 * sp }
        drawing.stem(x: stem, from: y + (event.stemUp ? -0.15 * sp : 0.15 * sp), to: tip, role: role)
        for k in 0..<flags {
            let offset = CGFloat(k) * 0.8 * sp
            let width = max(1, 0.12 * sp)
            if event.stemUp {
                drawing.glyph(.flagUp, at: CGPoint(x: stem + width / 2 - 0.02 * sp, y: tip + offset), role: role)
            } else {
                drawing.glyph(.flagDown, at: CGPoint(x: stem + width / 2 - 0.02 * sp, y: tip - offset), role: role)
            }
        }
    }

    /// Where a stem stands: on the head's right going up, its left going down.
    private func stemX(_ x: CGFloat, up: Bool) -> CGFloat {
        let width = max(1, 0.12 * sp)
        return up ? x + 0.6 * sp - width / 2 : x - 0.6 * sp + width / 2
    }

    private func drawRest(_ drawing: inout Drawing, _ event: NotationEvent, x: CGFloat, bar: EngravedBar) {
        let rows = drawing.rows
        let middle: CGFloat
        if staffShown {
            middle = rows.y(4)
        } else if let tabTop = rows.tabTop {
            middle = (tabTop + rows.tabBottom) / 2
        } else {
            return
        }
        let fourth = staffShown ? rows.y(6) : middle - sp
        let glyph: NotationGlyph
        let origin: CGPoint
        switch event.duration.level {
        case 0:
            glyph = .wholeRest
            let centre = event.fillsBar ? (bar.start + bar.end) / 2 : x
            origin = CGPoint(x: centre - 0.6 * sp, y: fourth)
        case 1:
            glyph = .halfRest
            origin = CGPoint(x: x - 0.6 * sp, y: middle)
        case 2:
            glyph = .quarterRest
            origin = CGPoint(x: x - 0.55 * sp, y: middle)
        case 3:
            glyph = .eighthRest
            origin = CGPoint(x: x - 0.6 * sp, y: middle)
        default:
            glyph = .sixteenthRest
            origin = CGPoint(x: x - 0.65 * sp, y: middle)
        }
        drawing.glyph(glyph, at: origin, role: .ink)
        if event.duration.dotted {
            drawing.glyph(.dot, at: CGPoint(x: x + 0.95 * sp, y: middle - 0.5 * sp), role: .ink)
        }
    }

    /// A beamed run: stems to one beam, sloping with the run (no more than a space), far enough from every head;
    /// sixteenths take a second beam, or a stub where only one note has it.
    private func drawBeam(_ drawing: inout Drawing, _ beam: NotationBeam, in measure: NotationMeasure, xs: [Int: CGFloat]) {
        let rows = drawing.rows
        let members = beam.events.compactMap { index -> (event: NotationEvent, x: CGFloat, y: CGFloat, stem: CGFloat)? in
            guard index < measure.events.count, let x = xs[index] else { return nil }
            let event = measure.events[index]
            let y = rows.y(event.position)
            return (event: event, x: x, y: y, stem: stemX(x, up: beam.stemUp))
        }
        guard let first = members.first, let last = members.last, members.count >= 2 else { return }
        let up = beam.stemUp
        let direction: CGFloat = up ? -1 : 1
        let length = 3.5 * sp
        let startTip = first.y + direction * length
        let endTip = last.y + direction * length
        let run = max(1, last.stem - first.stem)
        var rise = endTip - startTip
        let limit = min(1.0 * sp, run * 0.22)
        rise = max(-limit, min(limit, rise))
        if first.event.position == last.event.position { rise = 0 }
        let slope = rise / run
        let deepest = members.map { $0.event.duration.beams }.max() ?? 1
        let shortest = (deepest > 1 ? 3.0 : 2.6) * sp
        var base = startTip
        for member in members {
            let at = base + slope * (member.stem - first.stem)
            let stemLength = (member.y - at) * -direction
            if stemLength < shortest { base += direction * (shortest - stemLength) }
        }
        func beamY(_ x: CGFloat) -> CGFloat { base + slope * (x - first.stem) }
        let width = max(1, 0.12 * sp)
        for member in members {
            let role = MarkRole.note(member.event.note ?? 0)
            drawing.stem(x: member.stem, from: member.y - direction * 0.15 * sp, to: beamY(member.stem), role: role)
        }
        let thickness = 0.48 * sp
        let inward = -direction
        let role = MarkRole.note(first.event.note ?? 0)
        drawing.beam(from: first.stem - width / 2, to: last.stem + width / 2, y: beamY, thickness: thickness * inward, role: role)
        let second = 0.75 * sp * inward
        for (k, member) in members.enumerated() where member.event.duration.beams >= 2 {
            let before = k > 0 && members[k - 1].event.duration.beams >= 2
            let after = k + 1 < members.count && members[k + 1].event.duration.beams >= 2
            let memberRole = MarkRole.note(member.event.note ?? 0)
            if after {
                let next = members[k + 1]
                drawing.beam(from: member.stem - width / 2, to: next.stem + width / 2, y: { beamY($0) + second },
                             thickness: thickness * inward, role: memberRole)
            } else if !before {
                let pointsLeft = k == members.count - 1 || (k > 0 && members[k - 1].event.duration.dotted)
                let stub = 1.1 * sp
                let from = pointsLeft ? member.stem - stub : member.stem - width / 2
                let to = pointsLeft ? member.stem + width / 2 : member.stem + stub
                drawing.beam(from: from, to: to, y: { beamY($0) + second }, thickness: thickness * inward, role: memberRole)
            }
        }
    }

    /// Tab on its own: a stem under each number (shorter for a half note, none for a whole), flags and flat beams.
    private func drawTabRhythm(_ drawing: inout Drawing, _ event: NotationEvent, note: Int, x: CGFloat) {
        let rows = drawing.rows
        guard event.duration.hasStem else { return }
        let top = rows.tabBottom + 0.7 * sp
        let bottom = rows.tabBottom + (event.duration.hollow ? 2.2 : 3.2) * sp
        let role = MarkRole.note(note)
        drawing.stem(x: x, from: top, to: bottom, role: role)
        if event.beam == nil {
            for k in 0..<event.duration.beams {
                drawing.glyph(.flagDown, at: CGPoint(x: x + max(1, 0.12 * sp) / 2, y: bottom - CGFloat(k) * 0.8 * sp), role: role)
            }
        }
        if event.duration.dotted {
            drawing.glyph(.dot, at: CGPoint(x: x + 0.7 * sp, y: bottom - 0.3 * sp), role: role)
        }
    }

    private func drawTabBeam(_ drawing: inout Drawing, _ beam: NotationBeam, in measure: NotationMeasure, xs: [Int: CGFloat]) {
        let rows = drawing.rows
        let members = beam.events.compactMap { index -> (event: NotationEvent, x: CGFloat)? in
            guard index < measure.events.count, let x = xs[index] else { return nil }
            return (event: measure.events[index], x: x)
        }
        guard let first = members.first, let last = members.last, members.count >= 2 else { return }
        let y = rows.tabBottom + 3.2 * sp
        let width = max(1, 0.12 * sp)
        let thickness = -0.42 * sp
        let role = MarkRole.note(first.event.note ?? 0)
        drawing.beam(from: first.x - width / 2, to: last.x + width / 2, y: { _ in y }, thickness: thickness, role: role)
        for (k, member) in members.enumerated() where member.event.duration.beams >= 2 {
            let after = k + 1 < members.count && members[k + 1].event.duration.beams >= 2
            let before = k > 0 && members[k - 1].event.duration.beams >= 2
            if after {
                drawing.beam(from: member.x - width / 2, to: members[k + 1].x + width / 2, y: { _ in y - 0.68 * self.sp },
                             thickness: thickness, role: role)
            } else if !before {
                let left = k == members.count - 1
                drawing.beam(from: left ? member.x - 1.0 * sp : member.x, to: left ? member.x : member.x + 1.0 * sp,
                             y: { _ in y - 0.68 * self.sp }, thickness: thickness, role: role)
            }
        }
    }

    // MARK: Words

    private func drawLyrics(_ drawing: inout Drawing, sung: [(note: Int, x: CGFloat, width: CGFloat, joins: Bool, text: String)],
                            extenders: [Int: CGFloat], heldFromStart: CGFloat?, head: CGFloat, end: CGFloat) {
        guard let middle = drawing.rows.lyricMiddle else { return }
        let rule = max(0.8, type.lyric * 0.07)
        if let heldFromStart, heldFromStart > head {
            drawing.rect(CGRect(x: head, y: middle + type.lyric * 0.42, width: heldFromStart - head, height: rule), role: .ink)
        }
        for (k, syllable) in sung.enumerated() {
            drawing.marks.append(.text(syllable.text, at: CGPoint(x: syllable.x, y: middle), face: .lyric, anchor: .center,
                                       role: .lyric(syllable.note)))
            let right = syllable.x + syllable.width / 2
            if syllable.joins {
                let nextLeft = k + 1 < sung.count ? sung[k + 1].x - sung[k + 1].width / 2 : end
                let gap = nextLeft - right
                if gap >= 4 {
                    let dash = min(type.lyric * 0.45, gap * 0.6)
                    let centre = (right + nextLeft) / 2
                    drawing.rect(CGRect(x: centre - dash / 2, y: middle - rule / 2 + type.lyric * 0.05, width: dash, height: rule),
                                 role: .lyric(syllable.note))
                }
            } else if let until = extenders[k], until > right + 3 {
                drawing.rect(CGRect(x: right + 1.5, y: middle + type.lyric * 0.42, width: until - right - 1.5, height: rule),
                             role: .lyric(syllable.note))
            }
        }
    }
}

// MARK: - Collecting marks

/// Where a line's rows sit, top to bottom: the chord symbols' baseline, the staff, the words, the tab.
private struct NotationRows {
    /// Half a staff space: a step from a line to the next space.
    let half: CGFloat
    var chordBaseline: CGFloat = 0
    var staffTop: CGFloat = 0
    var bottomLine: CGFloat = 0
    var lyricMiddle: CGFloat?
    var tabTop: CGFloat?
    var tabBottom: CGFloat = 0
    var height: CGFloat = 0

    init(half: CGFloat) { self.half = half }

    /// The y of a staff position (half spaces above the bottom line).
    func y(_ position: Int) -> CGFloat { bottomLine - CGFloat(position) * half }
}

/// The marks of one line as they are placed, with the line's rows to measure from.
private struct Drawing {
    let space: CGFloat
    let rows: NotationRows
    var marks: [EngravedMark] = []
    /// Per string row, the stretches a fret number covers (the string is cut there).
    var cuts: [Int: [ClosedRange<CGFloat>]] = [:]

    enum Barline { case single, double, ending }

    init(space: CGFloat, rows: NotationRows) {
        self.space = space
        self.rows = rows
    }

    mutating func rect(_ rect: CGRect, role: MarkRole) {
        marks.append(.shape(Path(rect), evenOdd: false, role: role))
    }

    mutating func glyph(_ glyph: NotationGlyph, at point: CGPoint, role: MarkRole) {
        for part in NotationGlyphs.placed(glyph, at: point, space: space) {
            marks.append(.shape(part.path, evenOdd: part.evenOdd, role: role))
        }
    }

    mutating func ledger(x: CGFloat, y: CGFloat) {
        let rule = max(0.8, 0.13 * space)
        rect(CGRect(x: x - 1.0 * space, y: y - rule / 2, width: 2.0 * space, height: rule), role: .frame)
    }

    mutating func stem(x: CGFloat, from: CGFloat, to: CGFloat, role: MarkRole) {
        let width = max(1, 0.12 * space)
        rect(CGRect(x: x - width / 2, y: min(from, to), width: width, height: abs(to - from)), role: role)
    }

    /// A beam from `from` to `to`, its outer edge on `y(x)`, `thickness` towards the heads.
    mutating func beam(from: CGFloat, to: CGFloat, y: (CGFloat) -> CGFloat, thickness: CGFloat, role: MarkRole) {
        guard to > from else { return }
        var path = Path()
        path.addLines([CGPoint(x: from, y: y(from)), CGPoint(x: to, y: y(to)),
                       CGPoint(x: to, y: y(to) + thickness), CGPoint(x: from, y: y(from) + thickness)])
        path.closeSubpath()
        marks.append(.shape(path, evenOdd: false, role: role))
    }

    /// A tie from the head at `from` to the head at `to`, curving away from the stems; past `lineEnd` it runs off
    /// the line's end (to carry on in the next).
    mutating func tie(from: CGFloat, to: CGFloat, position: Int, stemUp: Bool, role: MarkRole, lineEnd: CGFloat) {
        let y = rows.y(position) + (stemUp ? 0.62 : -0.62) * space
        let start = from + 0.55 * space
        let stop = to > lineEnd ? lineEnd - 0.1 * space : to - 0.55 * space
        guard stop - start > 0.6 * space else { return }
        let lift = min(0.9 * space, 0.3 * space + (stop - start) * 0.06) * (stemUp ? 1 : -1)
        let thick = 0.16 * space * (stemUp ? 1 : -1)
        let middle = (start + stop) / 2
        var path = Path()
        path.move(to: CGPoint(x: start, y: y))
        path.addQuadCurve(to: CGPoint(x: stop, y: y), control: CGPoint(x: middle, y: y + 2 * lift))
        path.addQuadCurve(to: CGPoint(x: start, y: y), control: CGPoint(x: middle, y: y + 2 * (lift - thick)))
        path.closeSubpath()
        marks.append(.shape(path, evenOdd: false, role: role))
    }

    mutating func barline(at x: CGFloat, kind: Barline) {
        let thin = max(1, 0.14 * space)
        var spans: [(CGFloat, CGFloat)] = []
        if rows.bottomLine > rows.staffTop { spans.append((rows.staffTop, rows.bottomLine)) }
        if let tabTop = rows.tabTop { spans.append((tabTop, rows.tabBottom)) }
        for (top, bottom) in spans {
            switch kind {
            case .single:
                rect(CGRect(x: x - thin, y: top, width: thin, height: bottom - top), role: .frame)
            case .double:
                rect(CGRect(x: x - thin, y: top, width: thin, height: bottom - top), role: .frame)
                rect(CGRect(x: x - thin * 2 - 0.4 * space, y: top, width: thin, height: bottom - top), role: .frame)
            case .ending:
                let thick = 0.5 * space
                rect(CGRect(x: x - thick, y: top, width: thick, height: bottom - top), role: .ink)
                rect(CGRect(x: x - thick - 0.4 * space - thin, y: top, width: thin, height: bottom - top), role: .frame)
            }
        }
    }

    /// A fret number on its string, the string cut around it. Returns where it sits.
    mutating func fret(_ fret: Fretting, x: CGFloat, tab: NotationTab, type: NotationType, note: Int) -> CGPoint {
        guard let tabTop = rows.tabTop else { return CGPoint(x: x, y: 0) }
        let count = max(1, tab.strings)
        let number = max(1, min(count, fret.string))
        let row = tab.thinnestOnTop ? number - 1 : count - number
        let y = tabTop + CGFloat(row) * type.tabGap
        let text = "\(fret.fret)"
        let width = type.width(text, .fret)
        marks.append(.text(text, at: CGPoint(x: x, y: y), face: .fret, anchor: .center, role: .note(note)))
        cuts[row, default: []].append((x - width / 2 - 1.5)...(x + width / 2 + 1.5))
        return CGPoint(x: x, y: y)
    }

    /// The tab's strings from `from` to `to`, cut where numbers sit.
    mutating func strings(tab: NotationTab, gap: CGFloat, from: CGFloat, to: CGFloat) {
        guard let tabTop = rows.tabTop else { return }
        let rule = max(0.8, 0.1 * space)
        for row in 0..<max(1, tab.strings) {
            let y = tabTop + CGFloat(row) * gap
            var cursor = from
            for cut in (cuts[row] ?? []).sorted(by: { $0.lowerBound < $1.lowerBound }) {
                if cut.lowerBound > cursor { rect(CGRect(x: cursor, y: y - rule / 2, width: cut.lowerBound - cursor, height: rule), role: .frame) }
                cursor = max(cursor, cut.upperBound)
            }
            if to > cursor { rect(CGRect(x: cursor, y: y - rule / 2, width: to - cursor, height: rule), role: .frame) }
        }
    }
}
