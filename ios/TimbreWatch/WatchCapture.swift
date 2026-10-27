#if DEBUG
import Foundation
import WatchKit

/// Opt-in simulator evidence for the existing Watch views. Absent from Release builds.
@MainActor
enum WatchCapture {
    private static let environment = ProcessInfo.processInfo.environment
    static var page: String? {
        let value = environment["TIMBRE_WATCH_CAPTURE_PAGE"]
        guard value == "today" || value == "metronome",
              environment["TIMBRE_WATCH_CAPTURE_LOCALE"] != nil,
              environment["TIMBRE_WATCH_CAPTURE_REVISION"]?.count == 40,
              environment["TIMBRE_WATCH_CAPTURE_TOKEN"] != nil else { return nil }
        return value
    }
    static var enabled: Bool { page != nil }
    private static var appeared: Set<String> = []

    static func didAppear(_ value: String) { appeared.insert(value) }

    static func snapshot() -> WatchSnapshot {
        var value = WatchSnapshot()
        value.sent = Date()
        value.day = Calendar.current.startOfDay(for: value.sent)
        value.streak = 7
        value.best = 9
        value.practicedToday = true
        value.steps = [
            .init(kind: "tune", symbol: "tuningfork", tint: "neutral", title: String(localized: "Tune"), minutes: 2, done: true),
            .init(kind: "metronome", symbol: "metronome", tint: "neutral", title: String(localized: "Metronome"), minutes: 3, done: false),
            .init(kind: "lesson", symbol: "music.note", tint: "violet", title: String(localized: "Learn"), minutes: 5, done: false)
        ]
        return value
    }

    /// Waits for the selected real page and timer before publishing source-bound, per-launch state.
    static func observe(selected: String, sync: WatchSync, metronome: WristMetronome) async {
        guard let page, page == selected else { return }
        if page == "metronome" {
            metronome.setTempo(96)
            metronome.start()
        }
        for _ in 0..<100 {
            if appeared.contains(page), metronome.active,
               page != "metronome" || (metronome.running && metronome.pulse > 0) { break }
            do { try await Task.sleep(for: .milliseconds(100)) } catch { return }
        }
        guard appeared.contains(page), metronome.active,
              page != "metronome" || (metronome.running && metronome.pulse > 0),
              sync.snapshot != nil else { return }
        // Allow the page entrance and numeric transitions to finish before the host takes a picture.
        do { try await Task.sleep(for: .milliseconds(800)) } catch { return }
        let keys = page == "today"
            ? ["streak": "day streak", "practiced": "Practised today", "today": "Today"]
            : ["title": "Metronome", "tempo": "Andante", "tap": "Tap", "stop": "Stop", "meter": "Meter"]
        let labels = keys.mapValues { NSLocalizedString($0, bundle: .main, comment: "") }
        let device = WKInterfaceDevice.current()
        for _ in 0..<150 {
            guard !Task.isCancelled, metronome.active, let snapshot = sync.snapshot else { return }
            let probe: [String: Any] = [
                "schema": 1, "revision": environment["TIMBRE_WATCH_CAPTURE_REVISION"] ?? "",
                "token": environment["TIMBRE_WATCH_CAPTURE_TOKEN"] ?? "",
                "requestedLanguage": environment["TIMBRE_WATCH_CAPTURE_LOCALE"] ?? "",
                "effectiveLanguage": Bundle.main.preferredLocalizations.first ?? "",
                "page": page, "labels": labels,
                "observedAt": Date().timeIntervalSince1970,
                "streak": snapshot.streak, "practicedToday": snapshot.practicedToday,
                "done": snapshot.steps.filter(\.done).count, "total": snapshot.steps.count,
                "running": metronome.running, "pulse": metronome.pulse,
                "nativePixels": [Int(device.screenBounds.width * device.screenScale), Int(device.screenBounds.height * device.screenScale)]
            ]
            do {
                let directory = try FileManager.default.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
                let data = try JSONSerialization.data(withJSONObject: probe, options: [.sortedKeys])
                try data.write(to: directory.appendingPathComponent("watch-capture.json"), options: .atomic)
            } catch {
                // A missing probe makes the host's bounded wait fail; no success record is emitted.
                NSLog("Watch capture probe write failed: %@", String(describing: error))
                return
            }
            do { try await Task.sleep(for: .milliseconds(200)) } catch { return }
        }
    }
}
#endif
