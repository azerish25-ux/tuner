import Foundation
import Observation
import TimbreCore

/// The lock as the tuner shows it. The tracker (`TuningTracker`) stays strict: one reading outside the band, or a
/// moment with nothing heard, and its lock is over. The screen keeps what it said once a string locks: the readout's
/// In tune badge, the quiet status line, the peg's tick and the chip's solid mint stay for at least `minimum`, then for
/// as long as the string stays in the band, so a string that is in tune reads as in tune rather than as a flicker.
///
/// It ends as soon as the screen would be wrong to keep it: the pitch heard outside the band for `release` (the peg
/// turned away, the string plucked out of tune), another string or target, nothing heard for `silence` once
/// `minimum` has passed, or the tracker starting its hold again from nothing (the player chose the same string again).
/// Fed every tuner reading by `TuneView` (`AppStore.onTunerFrame`); views read `holding` through `shows`.
@Observable
@MainActor
final class LockLatch {
    /// The shortest time a lock stays on screen.
    static let minimum: TimeInterval = 1.5
    /// How long a pitch outside the band ends the lock: a passing reading doesn't, a turned peg does.
    static let release: TimeInterval = 0.2
    /// How long nothing heard ends the lock once `minimum` has passed: the readout's own hold over a gap.
    static let silence: TimeInterval = ReadoutMotion.printHold
    /// Readings further apart than this are a pause in them (a busy moment), never the tracker starting over.
    static let pause: TimeInterval = 0.25
    /// Readings further apart than this are a different session: whatever was locked before is earned again.
    static let session: TimeInterval = 10

    /// A lock is on screen.
    private(set) var holding = false
    @ObservationIgnored private var lockedAt: TimeInterval?
    @ObservationIgnored private var target: Double?
    @ObservationIgnored private var outSince: TimeInterval?
    @ObservationIgnored private var quietSince: TimeInterval?
    @ObservationIgnored private var lastTime: TimeInterval?
    @ObservationIgnored private var lastLocked = false

    /// One tuner reading. `band` is the lock band in cents (`Palette.tuningBand`).
    func step(_ frame: TunerFrame, band: Double) {
        let reading = frame.reading
        let now = frame.time
        let gap = lastTime.map { now - $0 } ?? 0
        // Locked, then holding toward a lock from nothing on the very next reading: the hold was started again on
        // purpose (the same string chosen again), and the lock is earned again rather than carried over.
        let restarted = lastLocked && !reading.inTune && reading.status == .settling && gap < Self.pause
        lastTime = now
        lastLocked = reading.inTune
        if frame.enteredTune && frame.measuring {
            lockedAt = now; target = frame.targetHz; outSince = nil; quietSince = nil
        }
        guard let lockedAt, let target, frame.measuring, !restarted, abs(target - frame.targetHz) < 0.001, gap < Self.session else {
            end()
            return
        }
        if reading.inTune {
            outSince = nil; quietSince = nil
            show(true)
            return
        }
        if let cents = reading.cents, reading.frequency != nil {
            quietSince = nil
            if abs(cents) <= band {
                outSince = nil
            } else {
                let since = outSince ?? now
                outSince = since
                if now - since >= Self.release { end(); return }
            }
        } else {
            outSince = nil
            let since = quietSince ?? now
            quietSince = since
            if now - lockedAt >= Self.minimum && now - since >= Self.silence { end(); return }
        }
        show(true)
    }

    /// The lock the screen shows for `reading`: the tracker's own, or this one while listening, as long as the whole
    /// cents on screen (`shown`) are inside the band, so the badge never reads "In tune · 7¢".
    func shows(_ reading: TuningReading, listening: Bool, shown: Int?) -> Bool {
        if reading.inTune { return true }
        guard holding, listening else { return false }
        return shown.map { Double(abs($0)) <= Palette.tuningBand } ?? true
    }

    /// Listening stopped, or the tuner gave the microphone to another screen: the next lock is earned afresh.
    func reset() {
        lastTime = nil
        lastLocked = false
        end()
    }

    private func end() {
        lockedAt = nil; target = nil; outSince = nil; quietSince = nil
        show(false)
    }

    private func show(_ on: Bool) {
        if holding != on { holding = on }
    }
}
