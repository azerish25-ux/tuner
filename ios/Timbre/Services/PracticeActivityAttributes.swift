import ActivityKit
import Foundation

// Shared by the app (LiveActivityController starts, updates and ends the activity) and the widget extension
// (PracticeLiveActivity draws it). Updates are local only, never pushed.

/// A practice session on the Lock Screen and in the Dynamic Island: the metronome's tempo and bar, the drone's
/// tonic, or the session clock while the player tunes or works through a lesson.
struct PracticeActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        enum Mode: String, Codable, Hashable {
            /// The Metronome tool is clicking (it leads when the drone sounds too).
            case metronome
            /// The Drone tool is sounding.
            case drone
            /// Tuning, singing or a lesson.
            case practice
            /// The session's last frame, left briefly on the Lock Screen after a real practice.
            case done
        }

        var mode: Mode
        /// When the session began: the clock counts up from here, drawn by the system (`Text(timerInterval:)`).
        var since: Date
        /// Metronome: tempo, beats in the bar and each beat's level (2 accent, 1 normal, 0 silent).
        var bpm = 0
        var beats = 4
        var levels: [Int] = []
        /// The drone's tonic in the player's note names ("A", "Bb", "La"); empty while no drone sounds.
        var drone = ""
        /// What is being practised, already in the app's language: a lesson title, the instrument, "Metronome".
        var detail = ""
        /// SF Symbol for practice: the lesson's course, the tuning fork or the microphone.
        var symbol = "tuningfork"
        var streak = 0
        /// `done` only: the session's length in seconds.
        var seconds = 0
    }
}

extension PracticeActivityAttributes.ContentState {
    /// "4/4", or "6/8" for compound meters, as the metronome's meter chips read.
    var meter: String { "\(beats)/\(beats == 6 || beats == 9 || beats == 12 ? 8 : 4)" }

    /// One level per beat of the bar (the first accented when the player set none).
    var beatLevels: [Int] {
        if levels.count == beats { return levels }
        return (0..<max(1, min(beats, 12))).map { $0 == 0 ? 2 : 1 }
    }
}
