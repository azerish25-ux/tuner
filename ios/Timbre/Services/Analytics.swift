import CryptoKit
import Foundation
import os
import UIKit

/// Product events: always logged on-device; also sent to TelemetryDeck (privacy-first, anonymous)
/// once the owner sets `TimbreTelemetryAppID` in the build settings. With no app ID nothing leaves
/// the device. Never include audio, names or anything personal in properties.
enum Analytics {
    private static let logger = Logger(subsystem: "com.shahradazerisharghi.timbre", category: "events")

    static func log(_ event: String, _ properties: [String: String] = [:]) {
        let detail = properties.sorted { $0.key < $1.key }.map { "\($0.key)=\($0.value)" }.joined(separator: " ")
        logger.info("\(event, privacy: .public) \(detail, privacy: .public)")
        Telemetry.shared.send(event, properties)
    }
}

/// A small TelemetryDeck client (ingest API v2): signals are batched and posted every 30 s,
/// at 20 queued, and when the app goes to the background.
private final class Telemetry: @unchecked Sendable {
    static let shared = Telemetry()

    private let appID: String?
    private let queue = DispatchQueue(label: "timbre.telemetry")
    private var pending: [[String: Any]] = []
    private var timer: DispatchSourceTimer?
    private let session = UUID().uuidString
    private let endpoint = URL(string: "https://nom.telemetrydeck.com/v2/")!

    private init() {
        let id = (Bundle.main.object(forInfoDictionaryKey: "TimbreTelemetryAppID") as? String)?.trimmingCharacters(in: .whitespaces) ?? ""
        let environment = ProcessInfo.processInfo.environment
        let underTest = environment["XCTestConfigurationFilePath"] != nil || environment["TIMBRE_DEMO_PITCH"] != nil
        appID = id.isEmpty || id.hasPrefix("$(") || underTest ? nil : id
        guard appID != nil else { return }
        NotificationCenter.default.addObserver(forName: UIApplication.didEnterBackgroundNotification, object: nil, queue: nil) { [weak self] _ in
            self?.queue.async { self?.flush() }
        }
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
            if pending.count >= 20 { flush() } else { scheduleFlush() }
        }
    }

    private func scheduleFlush() {
        guard timer == nil else { return }
        let next = DispatchSource.makeTimerSource(queue: queue)
        next.schedule(deadline: .now() + 30)
        next.setEventHandler { [weak self] in self?.flush() }
        timer = next
        next.resume()
    }

    /// Posts what's queued; on failure the batch is dropped (analytics must never retry-storm or grow unbounded).
    private func flush() {
        timer?.cancel(); timer = nil
        guard !pending.isEmpty, let body = try? JSONSerialization.data(withJSONObject: pending) else { return }
        pending.removeAll()
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json; charset=utf-8", forHTTPHeaderField: "Content-Type")
        request.httpBody = body
        URLSession.shared.dataTask(with: request).resume()
    }
}
