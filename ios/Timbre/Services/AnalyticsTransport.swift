import Foundation

/// Consent and request creation share one lock, so revocation cannot race a later HTTP resume.
/// Callbacks run outside the lock; callers must enqueue work instead of synchronously waiting on another queue.
final class AnalyticsTransport: @unchecked Sendable {
    struct Lease: Equatable, Sendable { fileprivate let generation: UInt64 }
    struct Response: Sendable { let data: Data; let status: Int }
    enum Failure: Error { case revoked, network, invalidResponse }

    private let lock = NSRecursiveLock()
    private let session: URLSession
    private var enabled: Bool
    private var generation: UInt64 = 0
    private var active: [UUID: URLSessionDataTask] = [:]

    init(session: URLSession = URLSession(configuration: .ephemeral), enabled: Bool) {
        self.session = session
        self.enabled = enabled
    }

    var lease: Lease? { lock.withLock { enabled ? Lease(generation: generation) : nil } }

    func setEnabled(_ on: Bool) {
        let canceled: [URLSessionDataTask] = lock.withLock {
            guard enabled != on else { return [] }
            enabled = on
            generation &+= 1
            guard !on else { return [] }
            let tasks = Array(active.values)
            active.removeAll()
            return tasks
        }
        // State is already revoked. A completion racing cancellation cannot acknowledge the old generation.
        for task in canceled { task.cancel() }
    }

    /// Only brief state changes/request starts belong here. Never run a blocking provider or wait for HTTP here.
    @discardableResult
    func withLease(_ lease: Lease, _ work: () -> Void) -> Bool {
        lock.withLock {
            guard current(lease) else { return false }
            work()
            return true
        }
    }

    func schedule(after delay: TimeInterval, lease: Lease, _ work: @escaping @Sendable () -> Void) {
        DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + delay) { [self] in
            _ = withLease(lease, work)
        }
    }

    func request(_ request: URLRequest, lease: Lease,
                 completion: @escaping @Sendable (Result<Response, Failure>) -> Void) {
        let started: Bool = lock.withLock {
            guard current(lease) else { return false }
            let id = UUID()
            let task = session.dataTask(with: request) { [self] data, response, error in
                let result: Result<Response, Failure> = lock.withLock {
                    let tracked = active.removeValue(forKey: id) != nil
                    guard tracked, current(lease) else { return .failure(.revoked) }
                    guard error == nil else { return .failure(.network) }
                    guard let response = response as? HTTPURLResponse else { return .failure(.invalidResponse) }
                    return .success(Response(data: data ?? Data(), status: response.statusCode))
                }
                completion(result)
            }
            active[id] = task
            task.resume()
            return true
        }
        if !started { completion(.failure(.revoked)) }
    }

    private func current(_ lease: Lease) -> Bool { enabled && generation == lease.generation }
}

/// Apple Ads lookup and its bounded retries use the same consent lease as the resulting event upload.
/// A late callback from a revoked run cannot clear a newer run or mark it as sent.
final class AppleAdsReporter: @unchecked Sendable {
    typealias Record = @Sendable ([String: String], AnalyticsTransport.Lease, @escaping @Sendable (Bool) -> Void) -> Void
    private let transport: AnalyticsTransport
    private let defaults: UserDefaults
    private let token: @Sendable () -> String?
    private let record: Record
    private let retryDelay: TimeInterval
    private let tokenQueue: DispatchQueue
    private var activeLease: AnalyticsTransport.Lease?
    private static let doneKey = "telemetry.attributionSent"
    private static let endpoint = URL(string: "https://api-adservices.apple.com/api/v1/")!

    init(transport: AnalyticsTransport, defaults: UserDefaults = .standard, retryDelay: TimeInterval = 5,
         tokenQueue: DispatchQueue = .global(qos: .utility),
         token: @escaping @Sendable () -> String?, record: @escaping Record) {
        self.transport = transport
        self.defaults = defaults
        self.retryDelay = retryDelay
        self.tokenQueue = tokenQueue
        self.token = token
        self.record = record
    }

    func start() {
        guard let lease = transport.lease else { return }
        transport.withLease(lease) { [self] in
            guard !defaults.bool(forKey: Self.doneKey), activeLease != lease else { return }
            activeLease = lease
            tokenQueue.async { [self] in acquireToken(lease: lease) }
        }
    }

    private func acquireToken(lease: AnalyticsTransport.Lease) {
        // Authorize the local provider work immediately before it starts, without retaining the consent lock.
        // AdServices is synchronous and uncancellable: revocation must not wait for an already-started call.
        guard transport.lease == lease else { return }
        let value = token()
        transport.withLease(lease) { [self] in
            // This can be a late provider result after off/on. Do not send it or clear a newer run's handle.
            guard activeLease == lease else { return }
            guard let value else { finish(lease); return }
            attempt(token: value, lease: lease, number: 0)
        }
    }

    private func attempt(token: String, lease: AnalyticsTransport.Lease, number: Int) {
        var request = URLRequest(url: Self.endpoint, timeoutInterval: 15)
        request.httpMethod = "POST"
        request.setValue("text/plain", forHTTPHeaderField: "Content-Type")
        request.httpBody = Data(token.utf8)
        transport.request(request, lease: lease) { [self] result in
            transport.withLease(lease) {
                switch result {
                case .success(let response) where response.status == 200:
                    guard let json = (try? JSONSerialization.jsonObject(with: response.data)) as? [String: Any] else {
                        finish(lease); return
                    }
                    record(Self.properties(json), lease) { [self] accepted in
                        transport.withLease(lease) {
                            if accepted { defaults.set(true, forKey: Self.doneKey) }
                            finish(lease)
                        }
                    }
                case .success(let response) where response.status != 404:
                    finish(lease)
                default:
                    guard number < 2 else { finish(lease); return }
                    transport.schedule(after: retryDelay, lease: lease) { [self] in
                        attempt(token: token, lease: lease, number: number + 1)
                    }
                }
            }
        }
    }

    private func finish(_ lease: AnalyticsTransport.Lease) {
        if activeLease == lease { activeLease = nil }
    }

    /// Only campaign/offer metadata: no country, click date, identifiers or arbitrary response properties.
    private static func properties(_ json: [String: Any]) -> [String: String] {
        var result = ["attributed": (json["attribution"] as? Bool) == true ? "1" : "0"]
        for (key, name) in [("campaignId", "campaign"), ("adGroupId", "ad_group"), ("keywordId", "keyword"),
                            ("conversionType", "conversion")] {
            if let value = json[key] { result[name] = "\(value)" }
        }
        return result
    }
}
