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
///   `feel_offer {result: shown|on|later}`, `onboarding_first_chord {result}`, `reminder_ask {result}`,
///   `onboarding_complete {…, path: plan|just_tune|questions}`, `onboarding_questions_closed {step}`.
/// - `paywall_view {reason, variant}`, once per paywall shown (onboarding's included); `paywall_close {reason, variant}`
///   when it is turned down.
/// - `purchase_start {product, reason, variant}`, then `purchase {product, reason, variant, trial, price, currency}`
///   (`trial=1` whenever the plan bought starts a free trial, yearly or monthly); `purchase_cancelled` and
///   `purchase_failed` come from the commerce service.
/// - After the purchase (`SubscriptionOutcomes`): `subscription_state {state, will_renew, offer, product}` when the
///   subscription's status changes, `renewal {product, offer}`, `refund {product, reason}`.
/// - `referral_share {screen}` when "Give a friend a month" is tapped.
/// - `attribution {attributed, campaign, ad_group, keyword, conversion}`, once per install (Apple Ads).
/// - `metrics_daily` and `diagnostics`, MetricKit's daily summaries.
enum Analytics {
    private static let logger = Logger(subsystem: "com.shahradazerisharghi.timbre", category: "events")
    /// Measurement has been started (at launch, or by the first event).
    private static let startRequested = OSAllocatedUnfairLock(initialState: false)

    static func log(_ event: String, _ properties: [String: String] = [:]) {
        logger.info("\(event, privacy: .public)")
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
    /// as the saved settings open and whenever it changes. Off discards queued events and cancels current requests;
    /// already delivered requests cannot be recalled. On until it is set.
    static func setSharing(_ on: Bool) {
        Telemetry.shared.setSharing(on)
        if on { AppleAdsAttribution.sendOnce() }
    }

    /// Explicit submission is acknowledged only when ingest accepts it, never merely when it is queued.
    static func requestSong(title: String, filter: String, completion: @escaping @Sendable (Bool) -> Void) {
        Telemetry.shared.submit("song_request", ["title": title, "filter": filter], completion: completion)
    }

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
final class Telemetry: @unchecked Sendable {
    static let shared: Telemetry = {
        let appID = TestSupport.isAutomated ? nil : AppLinks.string("TimbreTelemetryAppID")
        // AppStore applies the persisted preference before enabling delivery, including the default-on choice.
        // An unusually early event must not escape before a saved opt-out has been read.
        return Telemetry(appID: appID, transport: AnalyticsTransport(enabled: false))
    }()

    let transport: AnalyticsTransport
    private let appID: String?
    private let queue = DispatchQueue(label: "timbre.telemetry")
    private var pending: [[String: Any]] = []
    private var timer: DispatchSourceTimer?
    private var session = UUID().uuidString
    private var sharing = true
    private let endpoint = URL(string: "https://nom.telemetrydeck.com/v2/")!

    init(appID: String?, transport: AnalyticsTransport) {
        self.appID = appID
        self.transport = transport
        if appID == nil { transport.setEnabled(false) }
    }

    var isSending: Bool { appID != nil && transport.lease != nil }

    func setSharing(_ on: Bool) {
        // No transport callback synchronously waits on this queue. Callbacks always re-enqueue below.
        queue.sync { [self] in
            sharing = on
            transport.setEnabled(on && appID != nil)
            guard !on else { return }
            pending.removeAll()
            timer?.cancel(); timer = nil
        }
    }

    func newSession() {
        queue.async { [self] in session = UUID().uuidString }
    }

    /// A random installation identifier, hashed before transmission; unrelated to the Apple Account or IDFA.
    private lazy var clientUser: String = {
        let key = "telemetry.installID"
        let id = UserDefaults.standard.string(forKey: key) ?? {
            let fresh = UUID().uuidString
            UserDefaults.standard.set(fresh, forKey: key)
            return fresh
        }()
        return SHA256.hash(data: Data(id.utf8)).map { String(format: "%02x", $0) }.joined()
    }()

    private func signal(_ event: String, _ properties: [String: String]) -> [String: Any] {
        var payload: [String: Any] = [
            "TelemetryDeck.AppInfo.version": Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "",
            "TelemetryDeck.RunContext.locale": Locale.current.identifier,
            "TelemetryDeck.Device.systemVersion": ProcessInfo.processInfo.operatingSystemVersionString,
        ]
        for (key, value) in properties { payload["Timbre.\(key)"] = value }
        var signal: [String: Any] = ["appID": appID ?? "", "clientUser": clientUser, "sessionID": session, "type": event, "payload": payload]
        #if DEBUG
        signal["isTestMode"] = true
        #endif
        return signal
    }

    func send(_ event: String, _ properties: [String: String]) {
        guard let lease = transport.lease, appID != nil else { return }
        queue.async { [self] in
            guard sharing else { return }
            transport.withLease(lease) {
                pending.append(signal(event, properties))
                if pending.count >= 20 { post(nil) } else { scheduleFlush() }
            }
        }
    }

    /// A user request or attribution outcome is sent immediately and independently of the normal event batch.
    /// Ingest v2 documents HTTP 200 as accepted; other statuses (including arbitrary 2xx) do not confirm delivery.
    func submit(_ event: String, _ properties: [String: String], lease supplied: AnalyticsTransport.Lease? = nil,
                completion: @escaping @Sendable (Bool) -> Void) {
        guard let lease = supplied ?? transport.lease, appID != nil else { completion(false); return }
        queue.async { [self] in
            guard sharing else { completeSubmission(false, lease: lease, completion: completion); return }
            let allowed = transport.withLease(lease) {
                upload([signal(event, properties)], lease: lease) { [self] accepted in
                    completeSubmission(accepted, lease: lease, completion: completion)
                }
            }
            if !allowed { completeSubmission(false, lease: lease, completion: completion) }
        }
    }

    private func completeSubmission(_ accepted: Bool, lease: AnalyticsTransport.Lease,
                                    completion: @escaping @Sendable (Bool) -> Void) {
        DispatchQueue.global(qos: .utility).async { [transport] in
            // Recheck immediately before delivery; user callbacks never run on the telemetry queue or under a lock.
            completion(accepted && transport.lease == lease)
        }
    }

    /// Posts what is queued now; done runs when its request finishes, or immediately if nothing remains.
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

    private func post(_ done: (@Sendable () -> Void)?) {
        timer?.cancel(); timer = nil
        guard sharing, let lease = transport.lease, !pending.isEmpty else { done?(); return }
        let batch = pending
        pending.removeAll()
        upload(batch, lease: lease) { _ in done?() }
    }

    private func upload(_ signals: [[String: Any]], lease: AnalyticsTransport.Lease,
                        completion: @escaping @Sendable (Bool) -> Void) {
        guard let body = try? JSONSerialization.data(withJSONObject: signals) else { completion(false); return }
        var request = URLRequest(url: endpoint, timeoutInterval: 15)
        request.httpMethod = "POST"
        request.setValue("application/json; charset=utf-8", forHTTPHeaderField: "Content-Type")
        request.httpBody = body
        transport.request(request, lease: lease) { result in
            guard case .success(let response) = result else { completion(false); return }
            completion(response.status == 200)
        }
    }
}

// MARK: - Apple Ads

private enum AppleAdsAttribution {
    private static let reporter = AppleAdsReporter(
        transport: Telemetry.shared.transport,
        token: { try? AAAttribution.attributionToken() },
        record: { properties, lease, done in
            Telemetry.shared.submit("attribution", properties, lease: lease, completion: done)
        }
    )

    static func sendOnce() { reporter.start() }
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
