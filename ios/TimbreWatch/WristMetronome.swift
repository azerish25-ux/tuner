import Foundation
import WatchKit

/// The haptic metronome on the wrist: a strong tap on the downbeat (`.start`) and a light one on every other beat
/// (`.click`), 30–240 BPM, 2/4 to 7/4. Beats are scheduled against an absolute clock (each one an interval after the
/// last was due, never after the last fired), so timer jitter doesn't add up into drift.
///
/// watchOS plays haptics only for the app on screen and awake: with the wrist down (Always On, `active` false) the beat
/// keeps its place in the bar silently and the taps resume when the wrist comes up. An extended runtime session would
/// keep it going with the screen off, but its session types (self care, mindfulness, physical therapy, smart alarm) don't
/// cover a practice metronome, so Timbre doesn't claim one. Leaving the app stops the beat.
@MainActor
final class WristMetronome: ObservableObject {
    static let tempoRange = 30...240
    static let meterRange = 2...7

    /// The Digital Crown's value; the beat uses it rounded (`bpm`).
    @Published var crownTempo: Double {
        didSet { if bpm != Int(oldValue.rounded()) { tempoChanged() } }
    }
    @Published private(set) var beatsPerBar: Int
    @Published private(set) var running = false
    /// The beat just played (0 is the downbeat); nil while stopped.
    @Published private(set) var beat: Int?
    /// Counts every beat played: the ring flashes on each.
    @Published private(set) var pulse = 0
    /// False while the screen is dimmed or covered: beats keep time without a tap.
    var active = true

    var bpm: Int { Int(crownTempo.rounded()) }
    /// Seconds between beats.
    var interval: Double { 60 / Double(max(1, bpm)) }

    private var timer: DispatchSourceTimer?
    /// When the last beat was due, and when the next one is.
    private var last = DispatchTime.now()
    private var next = DispatchTime.now()
    private var count = 0
    private var taps: [Date] = []
    /// Set while the iPhone's tempo is applied, so it isn't saved as the wrist's own.
    private var adopting = false

    private enum Keys {
        static let tempo = "metronome.bpm"
        static let meter = "metronome.beats"
    }

    init() {
        let defaults = UserDefaults.standard
        let tempo = defaults.integer(forKey: Keys.tempo)
        crownTempo = Double(Self.tempoRange.contains(tempo) ? tempo : 96)
        let meter = defaults.integer(forKey: Keys.meter)
        beatsPerBar = Self.meterRange.contains(meter) ? meter : 4
    }

    func toggle() {
        if running { stop() } else { start() }
    }

    func start() {
        guard !running else { return }
        running = true
        count = 0
        let source = DispatchSource.makeTimerSource(queue: .main)
        // The timer fires on the main queue, so the handler is already on the main actor.
        source.setEventHandler { [weak self] in
            MainActor.assumeIsolated {
                guard let self else { return }
                self.tick()
            }
        }
        timer = source
        next = .now()
        last = next
        source.schedule(deadline: next, leeway: .milliseconds(1))
        source.resume()
    }

    func stop() {
        timer?.cancel()
        timer = nil
        running = false
        beat = nil
        count = 0
    }

    /// 2/4 → 3/4 → … → 7/4 → 2/4. A running beat starts the new bar on its next beat.
    func cycleMeter() {
        beatsPerBar = beatsPerBar >= Self.meterRange.upperBound ? Self.meterRange.lowerBound : beatsPerBar + 1
        count = 0
        UserDefaults.standard.set(beatsPerBar, forKey: Keys.meter)
    }

    func setTempo(_ value: Int) {
        crownTempo = Double(min(max(value, Self.tempoRange.lowerBound), Self.tempoRange.upperBound))
    }

    /// Tap tempo: the average gap of the last few taps, once two land within two seconds.
    func tap() {
        let now = Date()
        if let previous = taps.last, now.timeIntervalSince(previous) > 2 { taps.removeAll() }
        taps.append(now)
        taps = Array(taps.suffix(5))
        guard taps.count >= 2, let first = taps.first else { return }
        let gap = now.timeIntervalSince(first) / Double(taps.count - 1)
        guard gap > 0 else { return }
        setTempo(Int((60 / gap).rounded()))
    }

    /// The iPhone metronome's tempo and meter, until the wrist has its own (a crown turn, a tap or a meter change).
    func adopt(tempo: Int, beats: Int) {
        let defaults = UserDefaults.standard
        guard !running, defaults.object(forKey: Keys.tempo) == nil, defaults.object(forKey: Keys.meter) == nil else { return }
        adopting = true
        setTempo(tempo)
        adopting = false
        if Self.meterRange.contains(beats) { beatsPerBar = beats }
    }

    private func tick() {
        guard running, let timer else { return }
        let index = count % beatsPerBar
        if active { WKInterfaceDevice.current().play(index == 0 ? .start : .click) }
        beat = index
        pulse &+= 1
        count += 1
        last = next
        next = next + interval
        // After a stall (the app paused in the background) carry on from now rather than catching up in a burst.
        let now = DispatchTime.now()
        if next < now { next = now }
        timer.schedule(deadline: next, leeway: .milliseconds(1))
    }

    /// Saves the wrist's tempo; a running beat feels the change on its very next tap (one new interval after the last).
    private func tempoChanged() {
        if !adopting { UserDefaults.standard.set(bpm, forKey: Keys.tempo) }
        guard running, let timer else { return }
        next = last + interval
        let now = DispatchTime.now()
        if next < now { next = now }
        timer.schedule(deadline: next, leeway: .milliseconds(1))
    }
}
