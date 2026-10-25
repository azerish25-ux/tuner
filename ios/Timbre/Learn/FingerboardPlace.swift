import SwiftUI
import TimbreCore

/// A bowed string instrument's fingerboard, which has no frets: its players read where a note is played as a string
/// and a finger, never as a fret (a semitone count). In first position the violin and viola space their fingers about
/// a tone apart (fingers 1, 2, 3 and 4 on the semitones 2, 4, 5 and 7 above the open string; "low 2" on 3), the cello
/// a semitone apart (1–4 on 2–5), the double bass a semitone apart with its third finger resting (1, 2 and 4 on 2–4).
enum Fingerboard: Equatable, Sendable {
    /// Violin and viola.
    case violin
    case cello
    case doubleBass

    /// The fingerboard of a course's instrument; nil for a fretted instrument (the electric bass included), a voice
    /// or no instrument.
    init?(instrument id: String?) {
        guard let id else { return nil }
        if id.hasPrefix("violin") || id.hasPrefix("viola") {
            self = .violin
        } else if id.hasPrefix("cello") {
            self = .cello
        } else if id.hasPrefix("double_bass") || id.hasPrefix("contrabass") || id.hasPrefix("bass.upright") || id.hasPrefix("bass.double") {
            self = .doubleBass
        } else {
            return nil
        }
    }

    /// Semitones above the open string where `finger` (1 index … 4 little) stops it in first position.
    func home(of finger: Int) -> Int {
        let index = min(4, max(1, finger)) - 1
        switch self {
        case .violin: return [2, 4, 5, 7][index]
        case .cello: return [2, 3, 4, 5][index]
        case .doubleBass: return [2, 3, 4, 4][index]
        }
    }

    /// The finger that usually stops `fret` semitones above the open string in first position (for a note whose
    /// lesson names no finger).
    func finger(forFret fret: Int) -> Int {
        var best = 1
        for finger in 1...4 where abs(home(of: finger) - fret) < abs(home(of: best) - fret) { best = finger }
        return best
    }

    /// The position the hand is in when `finger` stops `fret`: where finger 1 then lies, counted as its players count
    /// positions (first position puts finger 1 a tone above the open string). Two and up.
    func position(fret: Int, finger: Int) -> Int {
        let first = fret - (home(of: finger) - home(of: 1))
        switch self {
        case .violin:
            // Positions climb the scale a step at a time: about seven positions to the octave.
            return max(2, Int((Double(first - 2) * 7 / 12).rounded()) + 1)
        case .cello, .doubleBass:
            return max(2, first - 1)
        }
    }
}

/// Where a note is played on a fingerboard, as its teachers name it: the string, the finger (0 for the open string),
/// and how the finger sits: on its first-position place, a semitone low or high of it (a violin's "low 2", "high 3"),
/// or with the hand moved up the neck into another position (a cello's fourth position).
struct FingerPlace: Equatable {
    enum Reach: Equatable {
        /// Open, or the finger on its first-position place.
        case home
        /// A semitone below its place.
        case low
        /// A semitone above its place.
        case high
        /// The hand in another position (2 and up).
        case position(Int)
    }

    /// 1 is the highest string.
    let string: Int
    /// 0 for the open string, else 1 index … 4 little.
    let finger: Int
    let reach: Reach

    init(_ at: Fretting, on board: Fingerboard) {
        string = at.string
        guard at.fret > 0 else {
            finger = 0
            reach = .home
            return
        }
        let named = at.finger.flatMap { (1...4).contains($0) ? $0 : nil }
        let used = named ?? board.finger(forFret: at.fret)
        finger = used
        let off = at.fret - board.home(of: used)
        if off == 0 {
            reach = .home
        } else if off == 1 {
            reach = .high
        } else if off > 1 {
            reach = .position(board.position(fret: at.fret, finger: used))
        } else {
            reach = .low
        }
    }

    /// The big figure on a gem or a tile: the finger, "0" for the open string.
    var figure: String { "\(finger)" }

    /// The mark beside the figure: an arrow for a finger reaching low or high, the position for a hand moved up the
    /// neck; nil on the finger's own place.
    var mark: String? {
        switch reach {
        case .home: return nil
        case .low: return "↓"
        case .high: return "↑"
        case let .position(number): return String(localized: "Pos. \(number)", bundle: TimbreLocalization.bundle)
        }
    }

    /// The figure with its arrow, for a tile too small for the position: "↓2", "3".
    var shortLabel: String {
        switch reach {
        case .low: return "↓\(finger)"
        case .high: return "↑\(finger)"
        case .home, .position: return figure
        }
    }

    /// "String 1, open", "String 1, finger 1", "String 2, low 2", "String 3, high 3", "String 2, finger 1, position 4".
    var words: String {
        let bundle = TimbreLocalization.bundle
        if finger == 0 { return String(localized: "String \(string), open", bundle: bundle) }
        switch reach {
        case .home: return String(localized: "String \(string), finger \(finger)", bundle: bundle)
        case .low: return String(localized: "String \(string), low \(finger)", bundle: bundle)
        case .high: return String(localized: "String \(string), high \(finger)", bundle: bundle)
        case let .position(number):
            return String(localized: "String \(string), finger \(finger), position \(number)", bundle: bundle)
        }
    }
}

/// Where to play a note in words, as the play-along's "Next" row and VoiceOver name it: the string and fret on a
/// fretted neck ("String 2, fret 3"), the string and finger on a fingerboard ("String 2, finger 1").
enum NotePlace {
    static func words(_ at: Fretting, board: Fingerboard?) -> String {
        if let board { return FingerPlace(at, on: board).words }
        let bundle = TimbreLocalization.bundle
        return at.fret == 0 ? String(localized: "String \(at.string), open", bundle: bundle)
                            : String(localized: "String \(at.string), fret \(at.fret)", bundle: bundle)
    }

    /// The note's name and where to play it, as VoiceOver reads the runway: "F sharp, String 1, finger 1". Without a
    /// place (pitch lanes), the name alone.
    static func spoken(_ note: TimedNote, fretted: Bool, board: Fingerboard?) -> String {
        guard board != nil, fretted, let at = note.at else { return SpokenCues.phrase(note, fretted: fretted, brief: false) }
        return SpokenCues.spokenName(note.midi) + ", " + words(at, board: board)
    }
}
