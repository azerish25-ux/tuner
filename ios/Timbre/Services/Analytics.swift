import AdServices
import CryptoKit
import Foundation
import MetricKit
import os
import UIKit

/// Product events. Every event goes to the device's log. Once the build carries a TelemetryDeck app ID
/// (`TimbreTelemetryAppID`) and the player hasn't switched sharing off, events also go to TelemetryDeck: anonymous,
/// not linked to the person, never used for tracking. Never put audio, names or anything personal in properties.
///
/// The funnel, as the dashboard names it:
/// - `app_open {launch: cold|warm}`: a launch, or a return after half a minute or more away (a new session).
/// - `onboarding_step {step, index}`, `mic_permission {granted, asked}`, `onboarding_first_tune {result}`,
///   `reminder_ask {result}`, `onboarding_first_chord {result}`, `onboarding_complete {…}`.
/// - `paywall_view {reason, variant}`, once per paywall shown (onboarding's included); `paywall_close {reason, variant}`
///   when it is turned down.
/// - `purchase_start {product, reason, variant}`, then `purchase {product, reason, variant, trial, price, currency}`;
///   `purchase_cancelled` and `purchase_failed` come from the commerce service.
/// - `attribution {attributed, campaign, ad_group, keyword, country}`, once per install (Apple Ads).
/// - `metrics_daily` and `diagnostics`, MetricKit's daily summaries.
enum Analytics {
    private static let logger = Logger(subsystem: "com.shahradazerisharghi.timbre", category: "events")
    /// Measurement has been started (at launch, or by the first event).
    private static let startRequested = OSAllocatedUnfairLock(initialState: false)

    static func log(_ event: String, _ properties: [String: String] = [:]) {
        let detail = properties.sorted { $0.key < $1.key }.map { "\($0.key)=\($0.value)" }.joined(separator: " ")
        logger.info("\(event, privacy: .public) \(detail, privacy: .public)")
        Telemetry.shared.send(event, properties)
        // An event before the launch call still starts measurement, so app opens and sessions are never missed.
        let first = startRequested.withLock { (started: inout Bool) -> Bool in
            defer { started = true }
            return !started
        }
        if first { Task { @MainActor in AnalyticsLifecycle.shared.start() } }
    }

    /// Starts measurement: app opens and sessions, the flush when the app goes to the background, MetricKit, the
    /// Apple Ads attribution (once per install) and the remote settings. Call once at launch; safe to call again.
    @MainActor static func start() {
        startRequested.withLock { (started: inout Bool) in started = true }
        AnalyticsLifecycle.shared.start()
    }

    /// The player's switch (Settings › Share anonymous usage data, `UserSettings.sharesUsage`), applied by `AppStore`
    /// as the saved settings open and whenever it changes. Off, nothing more leaves the device and what was waiting is
    /// dropped; the device's own log carries on. On until it is set.
    static func setSharing(_ on: Bool) { Telemetry.shared.setSharing(on) }

    /// Events are leaving the device: the build has an app ID and sharing is on.
    static var isSending: Bool { Telemetry.shared.isSending }
}

// MARK: - App opens and sessions

/// Logs `app_open` on a launch and on a return from the background, starts a new session for it, and sends what is
/// queued when the app goes to the background (inside a background task, so the batch isn't cut off).
@MainActor
private final class AnalyticsLifecycle {
    static let shared = AnalyticsLifecycle()

    /// A return after this long away counts as a new open and a new session.
    private static let newSessionAfter: TimeInterval = 30

    private var started = false
    private var opened = false
    private var backgroundedAt: Date?
    private var backgroundTask: UIBackgroundTaskIdentifier = .invalid
    private var observers: [NSObjectProtocol] = []
    private let metrics = MetricsSubscriber()

    func start() {
        guard !started else { return }
        started = true
        let center = NotificationCenter.default
        observers.append(center.addObserver(forName: UIApplication.didBecomeActiveNotification, object: nil, queue: .main) { _ in
            MainActor.assumeIsolated { AnalyticsLifecycle.shared.becameActive() }
        })
        observers.append(center.addObserver(forName: UIApplication.didEnterBackgroundNotification, object: nil, queue: .main) { _ in
            MainActor.assumeIsolated { AnalyticsLifecycle.shared.enteredBackground() }
        })
        // Started after the app came forward (by a first event): this launch's open is logged once the run loop turns.
        // Started at launch, the activation notification logs it first and this finds it done.
        Task { @MainActor in
            if UIApplication.shared.applicationState == .active { AnalyticsLifecycle.shared.becameActive() }
        }
        MXMetricManager.shared.add(metrics)
        AppleAdsAttribution.sendOnce()
        RemoteConfig.shared.start()
    }

    private func becameActive() {
        guard opened else {
            opened = true
            Analytics.log("app_open", ["launch": "cold"])
            return
        }
        // Control Center or a system sheet also makes the app inactive and active again: only a real return counts.
        guard let away = backgroundedAt else { return }
        backgroundedAt = nil
        guard Date().timeIntervalSince(away) >= Self.newSessionAfter else { return }
        Telemetry.shared.newSession()
        Analytics.log("app_open", ["launch": "warm"])
    }

    private func enteredBackground() {
        backgroundedAt = Date()
        endBackgroundTask()
        backgroundTask = UIApplication.shared.beginBackgroundTask(withName: "timbre.analytics") {
            MainActor.assumeIsolated { AnalyticsLifecycle.shared.endBackgroundTask() }
        }
        Telemetry.shared.flush {
            Task { @MainActor in AnalyticsLifecycle.shared.endBackgroundTask() }
        }
    }

    private func endBackgroundTask() {
        guard backgroundTask != .invalid else { return }
        UIApplication.shared.endBackgroundTask(backgroundTask)
        backgroundTask = .invalid
    }
}

// MARK: - TelemetryDeck

/// A small TelemetryDeck client (ingest API v2): signals are batched and posted every 30 s, at 20 queued, and when
/// the app goes to the background. A failed post is dropped: analytics never retry-storm or grow without bound.
private final class Telemetry: @unchecked Sendable {
    static let shared = Telemetry()

    private let appID: String?
    private let queue = DispatchQueue(label: "timbre.telemetry")
    private var pending: [[String: Any]] = []
    private var timer: DispatchSourceTimer?
    private var session = UUID().uuidString
    private var sharing = true
    private let endpoint = URL(string: "https://nom.telemetrydeck.com/v2/")!

    private init() {
        var underTest = false
        #if DEBUG
        let environment = ProcessInfo.processInfo.environment
        underTest = environment["XCTestConfigurationFilePath"] != nil || environment["TIMBRE_DEMO_PITCH"] != nil
        #endif
        appID = underTest ? nil : AppLinks.string("TimbreTelemetryAppID")
    }

    var isSending: Bool { queue.sync { appID != nil && sharing } }

    func setSharing(_ on: Bool) {
        queue.async { [self] in
            sharing = on
            guard !on else { return }
            pending.removeAll()
            timer?.cancel(); timer = nil
        }
    }

    func newSession() {
        queue.async { [self] in session = UUID().uuidString }
    }

    /// A stable, anonymous per-install identifier (random, hashed; not linked to the Apple Account).
    private lazy var clientUser: String = {
        let key = "telemetry.installID"
        let id = UserDefaults.standard.string(forKey: key) ?? {
            let fresh = UUID().uuidString
            UserDefaults.standard.set(fresh, forKey: key)
            return fresh
        }()
        return SHA256.hash(data: Data(id.utf8)).map { String(format: "%02x", $0) }.joined()
    }()

    func send(_ event: String, _ properties: [String: String]) {
        guard let appID else { return }
        queue.async { [self] in
            guard sharing else { return }
            var payload: [String: Any] = [
                "TelemetryDeck.AppInfo.version": Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "",
                "TelemetryDeck.RunContext.locale": Locale.current.identifier,
                "TelemetryDeck.Device.systemVersion": ProcessInfo.processInfo.operatingSystemVersionString,
            ]
            for (key, value) in properties { payload["Timbre.\(key)"] = value }
            var signal: [String: Any] = ["appID": appID, "clientUser": clientUser, "sessionID": session, "type": event, "payload": payload]
            #if DEBUG
            signal["isTestMode"] = true
            #endif
            pending.append(signal)
            if pending.count >= 20 { post(nil) } else { scheduleFlush() }
        }
    }

    /// Posts what is queued now; `done` runs once the post has finished (at once with nothing to send).
    func flush(_ done: @escaping @Sendable () -> Void) {
        queue.async { [self] in post(done) }
    }

    private func scheduleFlush() {
        guard timer == nil else { return }
        let next = DispatchSource.makeTimerSource(queue: queue)
        next.schedule(deadline: .now() + 30)
        next.setEventHandler { [weak self] in self?.post(nil) }
        timer = next
        next.resume()
    }

    /// On the queue: sends the batch and empties it.
    private func post(_ done: (@Sendable () -> Void)?) {
        timer?.cancel(); timer = nil
        guard !pending.isEmpty, let body = try? JSONSerialization.data(withJSONObject: pending) else { done?(); return }
        pending.removeAll()
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json; charset=utf-8", forHTTPHeaderField: "Content-Type")
        request.httpBody = body
        URLSession.shared.dataTask(with: request) { _, _, _ in done?() }.resume()
    }
}

// MARK: - Apple Ads

/// Which Apple Ads campaign, ad group and keyword brought this install, if any: the AdServices token is resolved with
/// Apple's attribution API once per install, and the answer is logged as `attribution`. The token says nothing about
/// the person and needs no tracking permission. Only while events are leaving the device.
private enum AppleAdsAttribution {
    private static let doneKey = "telemetry.attributionSent"
    private static let endpoint = URL(string: "https://api-adservices.apple.com/api/v1/")!

    static func sendOnce() {
        guard Analytics.isSending, !UserDefaults.standard.bool(forKey: doneKey) else { return }
        Task.detached(priority: .utility) {
            guard let token = try? AAAttribution.attributionToken() else { return }
            // The answer can take a little while to be ready (404 until then): three tries, five seconds apart.
            for attempt in 0..<3 {
                if attempt > 0 { try? await Task.sleep(for: .seconds(5)) }
                var request = URLRequest(url: endpoint, timeoutInterval: 15)
                request.httpMethod = "POST"
                request.setValue("text/plain", forHTTPHeaderField: "Content-Type")
                request.httpBody = Data(token.utf8)
                guard let (data, response) = try? await URLSession.shared.data(for: request) else { continue }
                let status = (response as? HTTPURLResponse)?.statusCode ?? 0
                if status == 404 { continue }
                guard status == 200, let json = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] else { return }
                Analytics.log("attribution", properties(json))
                UserDefaults.standard.set(true, forKey: doneKey)
                return
            }
        }
    }

    /// The campaign's numbers only (never a click date or anything about the person).
    private static func properties(_ json: [String: Any]) -> [String: String] {
        var result = ["attributed": (json["attribution"] as? Bool) == true ? "1" : "0"]
        let fields = [("campaignId", "campaign"), ("adGroupId", "ad_group"), ("keywordId", "keyword"),
                      ("countryOrRegion", "country"), ("conversionType", "conversion")]
        for (key, name) in fields {
            if let value = json[key] { result[name] = "\(value)" }
        }
        return result
    }
}

// MARK: - MetricKit

/// MetricKit's daily summaries as two events: `metrics_daily` (launch and hang medians, peak memory, CPU, scroll
/// hitches and how the app ended in the foreground) and `diagnostics` (crash and hang reports, counted).
private final class MetricsSubscriber: NSObject, MXMetricManagerSubscriber {
    func didReceive(_ payloads: [MXMetricPayload]) {
        for payload in payloads { Analytics.log("metrics_daily", Self.summary(payload)) }
    }

    func didReceive(_ payloads: [MXDiagnosticPayload]) {
        for payload in payloads {
            let crashes = payload.crashDiagnostics?.count ?? 0
            let hangs = payload.hangDiagnostics?.count ?? 0
            let cpu = payload.cpuExceptionDiagnostics?.count ?? 0
            let disk = payload.diskWriteExceptionDiagnostics?.count ?? 0
            guard crashes + hangs + cpu + disk > 0 else { continue }
            Analytics.log("diagnostics", ["crashes": String(crashes), "hangs": String(hangs), "cpu": String(cpu), "disk": String(disk)])
        }
    }

    private static func summary(_ payload: MXMetricPayload) -> [String: String] {
        var result = ["version": payload.latestApplicationVersion]
        if let launch = payload.applicationLaunchMetrics, let ms = median(launch.histogrammedTimeToFirstDraw) {
            result["launch_ms"] = String(Int(ms.rounded()))
        }
        if let responsiveness = payload.applicationResponsivenessMetrics, let ms = median(responsiveness.histogrammedApplicationHangTime) {
            result["hang_ms"] = String(Int(ms.rounded()))
        }
        if let memory = payload.memoryMetrics {
            result["peak_mb"] = String(Int(memory.peakMemoryUsage.converted(to: .megabytes).value.rounded()))
        }
        if let cpu = payload.cpuMetrics {
            result["cpu_s"] = String(Int(cpu.cumulativeCPUTime.converted(to: .seconds).value.rounded()))
        }
        if let animation = payload.animationMetrics {
            result["scroll_hitch"] = String(format: "%.4f", animation.scrollHitchTimeRatio.value)
        }
        if let exits = payload.applicationExitMetrics?.foregroundExitData {
            result["fg_normal"] = String(exits.cumulativeNormalAppExitCount)
            result["fg_crash"] = String(exits.cumulativeBadAccessExitCount + exits.cumulativeIllegalInstructionExitCount + exits.cumulativeAbnormalExitCount)
            result["fg_memory"] = String(exits.cumulativeMemoryResourceLimitExitCount)
            result["fg_watchdog"] = String(exits.cumulativeAppWatchdogExitCount)
        }
        return result
    }

    /// The middle of a histogram, in milliseconds: the midpoint of the bucket holding its median.
    private static func median(_ histogram: MXHistogram<UnitDuration>) -> Double? {
        var buckets: [(middle: Double, count: Int)] = []
        let enumerator = histogram.bucketEnumerator
        while let bucket = enumerator.nextObject() as? MXHistogramBucket<UnitDuration> {
            let start = bucket.bucketStart.converted(to: .milliseconds).value
            let end = bucket.bucketEnd.converted(to: .milliseconds).value
            buckets.append(((start + end) / 2, bucket.bucketCount))
        }
        let total = buckets.reduce(0) { $0 + $1.count }
        guard total > 0 else { return nil }
        var seen = 0
        for bucket in buckets {
            seen += bucket.count
            if seen * 2 >= total { return bucket.middle }
        }
        return buckets.last?.middle
    }
}
