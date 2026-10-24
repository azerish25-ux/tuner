import Combine
import Foundation
import TimbreCore

/// The chord the chart lights and scrolls to as the song goes: at the chart's tempo on its own clock (auto-scroll),
/// along the player's own recording once it is synced (`SongRecording.timings`), or, while syncing, the chord the
/// next tap times. It never follows Apple Music: nothing may be timed to an Apple Music track.
@MainActor
final class ChartFollower: ObservableObject {
    enum Mode: Equatable {
        case idle
        /// Auto-scroll at `bpm`, one bar a chord.
        case scrolling
        /// Following the player's recording.
        case recording
        /// Tapping along to the recording to sync it.
        case syncing
    }

    @Published private(set) var mode = Mode.idle
    /// The chord lit (an index into `ChordChart.chordSequence`).
    @Published private(set) var current: Int?
    @Published private(set) var tap: TapAlong?
    /// Auto-scroll's tempo.
    @Published private(set) var bpm = 90.0

    /// Chords light this much before they sound, so the hand can get there.
    static let lead = 0.25

    private var timeline: ChartTimeline?
    private var clock: () -> Double = { 0 }
    private var started = Date()
    private var offset = 0.0
    private var count = 0
    private var beatsPerBar = 4
    private var ticker: Task<Void, Never>?

    // MARK: Auto-scroll

    /// Scrolls through `count` chords at `bpm`, starting at chord `from`.
    func scroll(count: Int, bpm: Double, beatsPerBar: Int, from index: Int = 0) {
        self.count = count
        self.beatsPerBar = beatsPerBar
        self.bpm = min(240, max(30, bpm.rounded()))
        let steady = ChartTimeline.steady(count: count, bpm: self.bpm, beatsPerBar: beatsPerBar)
        timeline = steady
        offset = steady.times.indices.contains(index) ? steady.times[index] : 0
        started = Date()
        let origin = offset
        let start = started
        clock = { origin + Date().timeIntervalSince(start) }
        tap = nil
        mode = .scrolling
        run()
    }

    /// A new tempo for auto-scroll, carrying on from the chord it's on.
    func setTempo(_ value: Double) {
        let next = min(240, max(30, value.rounded()))
        guard next != bpm else { return }
        if mode == .scrolling {
            scroll(count: count, bpm: next, beatsPerBar: beatsPerBar, from: current ?? 0)
        } else {
            bpm = next
        }
    }

    // MARK: The recording

    /// Follows the recording's clock along `times` (none: nothing lights until it is synced).
    func follow(times: [Double], count: Int, bpm: Double?, beatsPerBar: Int, clock: @escaping () -> Double) {
        self.count = count
        self.beatsPerBar = beatsPerBar
        timeline = times.isEmpty ? nil : ChartTimeline.extended(times, count: count, bpm: bpm ?? self.bpm, beatsPerBar: beatsPerBar)
        self.clock = clock
        tap = nil
        mode = .recording
        run()
    }

    /// Starts tapping along to time `count` chords; the recording plays meanwhile on `clock`.
    func sync(count: Int, keeping: [Double] = [], from index: Int = 0, clock: @escaping () -> Double) {
        self.count = count
        self.clock = clock
        tap = TapAlong(count: count, keeping: keeping, from: index)
        timeline = nil
        mode = .syncing
        current = tap?.next
        run()
    }

    /// A tap on the change to the next chord; true when it counted.
    @discardableResult func tapNow() -> Bool {
        guard mode == .syncing, var taps = tap else { return false }
        let counted = taps.tap(at: clock())
        tap = taps
        current = taps.isFinished ? nil : taps.next
        return counted
    }

    func undoTap() {
        guard mode == .syncing, var taps = tap else { return }
        taps.undo()
        tap = taps
        current = taps.next
    }

    /// Ends whatever it was doing.
    func stop() {
        ticker?.cancel()
        ticker = nil
        mode = .idle
        current = nil
        tap = nil
        timeline = nil
    }

    // MARK: The clock

    private func run() {
        ticker?.cancel()
        ticker = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                guard let self else { return }
                self.tick()
                try? await Task.sleep(for: .milliseconds(60))
            }
        }
        tick()
    }

    private func tick() {
        switch mode {
        case .idle, .syncing:
            return
        case .scrolling, .recording:
            let time = clock()
            let index = timeline?.index(at: time + Self.lead)
            if index != current { current = index }
            // Auto-scroll stops a bar after the last chord.
            if mode == .scrolling, let last = timeline?.times.last {
                let bar = 60 / max(30, bpm) * Double(max(1, beatsPerBar))
                if time > last + bar { stop() }
            }
        }
    }
}
