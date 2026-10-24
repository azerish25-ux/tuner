import Foundation
import Observation
import TimbreCore

/// High-rate values (about 60 updates a second). Kept apart from `AppStore` so only the
/// views that draw the reading re-render; everything else stays still.
@Observable
@MainActor
final class LiveReading {
    var reading = TuningReading(frequency: nil, cents: nil, stable: false, inTune: false, status: "noSignal")
    var level: Double = -120
    var preserved = false
    var updatedAt: TimeInterval = 0
    // Voice practice
    var trace: [Double?] = []
    var voiceElapsed = 0
    var voiceLiveHoldMs = 0

    func clear() {
        reading = TuningReading(frequency: nil, cents: nil, stable: false, inTune: false, status: "noSignal")
        preserved = false
    }
}
