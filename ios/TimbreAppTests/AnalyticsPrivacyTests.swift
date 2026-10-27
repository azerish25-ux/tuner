import Foundation
import XCTest
@testable import Timbre

/// No real network: hold and complete URLSession requests at the URLProtocol boundary.
final class AnalyticsPrivacyTests: XCTestCase {
    private var sessions: [(id: String, session: URLSession, invalidated: XCTestExpectation)] = []
    private var transports: [AnalyticsTransport] = []

    private func session() -> URLSession {
        let id = UUID().uuidString
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [PrivacyURLProtocol.self]
        configuration.httpAdditionalHeaders = [PrivacyURLProtocol.scopeHeader: id]
        let invalidated = expectation(description: "session \(id) invalidated")
        let delegate = PrivacySessionDelegate(invalidated: invalidated)
        let session = URLSession(configuration: configuration, delegate: delegate, delegateQueue: nil)
        sessions.append((id, session, invalidated))
        return session
    }

    private func makeTransport(enabled: Bool) -> AnalyticsTransport {
        let transport = AnalyticsTransport(session: session(), enabled: enabled)
        transports.append(transport)
        return transport
    }

    private func configureProtocol(start: @escaping (PrivacyURLProtocol) -> Void, stop: (() -> Void)? = nil) {
        guard let id = sessions.last?.id else { XCTFail("Create the scoped session before its handler"); return }
        PrivacyURLProtocol.configure(id: id, start: start, stop: stop)
    }

    override func tearDown() {
        for transport in transports { transport.setEnabled(false) }
        for entry in sessions { entry.session.invalidateAndCancel() }
        if !sessions.isEmpty { wait(for: sessions.map { $0.invalidated }, timeout: 2) }
        for entry in sessions { PrivacyURLProtocol.reset(id: entry.id) }
        sessions.removeAll()
        transports.removeAll()
        super.tearDown()
    }

    func testRevocationCancelsAnInflightRequestAndRejectsItsResult() throws {
        let transport = makeTransport(enabled: true)
        let started = expectation(description: "request started")
        let stopped = expectation(description: "request canceled")
        let completed = expectation(description: "completion rejected")
        configureProtocol(start: { _ in started.fulfill() }, stop: { stopped.fulfill() })
        let lease = try XCTUnwrap(transport.lease)
        transport.request(URLRequest(url: URL(string: "https://privacy.test/events")!), lease: lease) { result in
            if case .success = result { XCTFail("revoked request must not acknowledge delivery") }
            completed.fulfill()
        }
        wait(for: [started], timeout: 2)
        transport.setEnabled(false)
        wait(for: [stopped, completed], timeout: 2)
        XCTAssertNil(transport.lease)
    }

    func testAnOldGenerationCannotCreateTokensRequestsOrRetriesAfterOffOn() throws {
        let transport = makeTransport(enabled: true)
        let old = try XCTUnwrap(transport.lease)
        transport.setEnabled(false)
        transport.setEnabled(true)
        let forbidden = expectation(description: "old generation work")
        forbidden.isInverted = true
        XCTAssertFalse(transport.withLease(old) { forbidden.fulfill() })
        transport.schedule(after: 0, lease: old) { forbidden.fulfill() }
        transport.request(URLRequest(url: URL(string: "https://privacy.test/old")!), lease: old) { result in
            if case .success = result { XCTFail("old request accepted") }
        }
        wait(for: [forbidden], timeout: 0.1)
        XCTAssertNotEqual(transport.lease, old)
    }

    func testRevocationInvalidatesRetryWorkScheduledWhileConsentWasStillEnabled() throws {
        let transport = makeTransport(enabled: true)
        let lease = try XCTUnwrap(transport.lease)
        let retry = expectation(description: "previously scheduled retry must not run")
        retry.isInverted = true
        transport.schedule(after: 0.1, lease: lease) { retry.fulfill() }
        transport.setEnabled(false)
        wait(for: [retry], timeout: 0.3)
    }

    func testNewGenerationCanDeliverWithoutBeingCanceledByAnOldCompletion() throws {
        let transport = makeTransport(enabled: true)
        let oldStarted = expectation(description: "old request started")
        configureProtocol(start: { _ in oldStarted.fulfill() })
        transport.request(URLRequest(url: URL(string: "https://privacy.test/old")!), lease: try XCTUnwrap(transport.lease)) { _ in }
        wait(for: [oldStarted], timeout: 2)
        transport.setEnabled(false)
        transport.setEnabled(true)
        let delivered = expectation(description: "new request accepted")
        configureProtocol(start: { $0.respond(status: 200) })
        transport.request(URLRequest(url: URL(string: "https://privacy.test/new")!), lease: try XCTUnwrap(transport.lease)) { result in
            guard case .success(let response) = result else { XCTFail("new generation was rejected"); delivered.fulfill(); return }
            XCTAssertEqual(response.status, 200)
            delivered.fulfill()
        }
        wait(for: [delivered], timeout: 2)
    }

    func testOptOutDropsQueuedSignalsAndPreventsFurtherUploads() {
        let transport = makeTransport(enabled: true)
        let telemetry = Telemetry(appID: "privacy-test", transport: transport)
        telemetry.send("queued", [:])
        telemetry.setSharing(false)
        let flushed = expectation(description: "empty queue flush")
        let unexpected = expectation(description: "no request")
        unexpected.isInverted = true
        configureProtocol(start: { _ in unexpected.fulfill() })
        telemetry.send("after_revocation", [:])
        telemetry.flush { flushed.fulfill() }
        wait(for: [flushed, unexpected], timeout: 0.1)
    }

    func testExplicitRequestAcknowledgesOnlyIngestHTTP200AndNeverJustQueueing() {
        for status in [200, 202, 422, 500] {
            let transport = makeTransport(enabled: true)
            let telemetry = Telemetry(appID: "privacy-test", transport: transport)
            let completed = expectation(description: "HTTP \(status) result")
            configureProtocol(start: { $0.respond(status: status) })
            telemetry.submit("song_request", ["title": "Example"]) { accepted in
                XCTAssertEqual(accepted, status == 200)
                completed.fulfill()
            }
            wait(for: [completed], timeout: 2)
        }
    }

    func testExplicitRequestDoesNotSucceedWithoutConfigurationOrConsent() {
        for appID in [nil, "privacy-test"] as [String?] {
            let transport = makeTransport(enabled: appID != nil)
            let telemetry = Telemetry(appID: appID, transport: transport)
            telemetry.setSharing(false)
            let completed = expectation(description: "request unavailable")
            telemetry.submit("song_request", ["title": "Example"]) { accepted in
                XCTAssertFalse(accepted)
                completed.fulfill()
            }
            wait(for: [completed], timeout: 2)
        }
    }

    func testDeliveryRemainsOffUntilSavedPreferenceIsApplied() {
        let transport = makeTransport(enabled: false)
        let telemetry = Telemetry(appID: "privacy-test", transport: transport)
        XCTAssertFalse(telemetry.isSending)
        let denied = expectation(description: "not yet enabled")
        telemetry.submit("song_request", ["title": "Example"]) { accepted in
            XCTAssertFalse(accepted); denied.fulfill()
        }
        wait(for: [denied], timeout: 2)
        telemetry.setSharing(true)
        let accepted = expectation(description: "saved default-on preference applied")
        configureProtocol(start: { $0.respond(status: 200) })
        telemetry.submit("song_request", ["title": "Example"]) { success in
            XCTAssertTrue(success); accepted.fulfill()
        }
        wait(for: [accepted], timeout: 2)
    }

    func testAttributionRevocationBeforeStartDoesNotCreateToken() {
        let transport = makeTransport(enabled: false)
        let called = expectation(description: "token or event")
        called.isInverted = true
        let reporter = AppleAdsReporter(transport: transport, defaults: freshDefaults(), token: {
            called.fulfill(); return "token"
        }, record: { _, _, _ in called.fulfill() })
        reporter.start()
        wait(for: [called], timeout: 0.1)
    }

    func testHeldTokenProviderDoesNotBlockStartOrRevocationAndItsResultIsDiscarded() {
        let transport = makeTransport(enabled: true)
        let defaults = PrivacyDefaults()
        let providerEntered = expectation(description: "token provider held")
        let startReturned = expectation(description: "start caller returned while provider held")
        let revokeReturned = expectation(description: "revocation returned while provider held")
        let providerReturned = expectation(description: "provider released")
        let escaped = expectation(description: "revoked provider must not send or record")
        escaped.isInverted = true
        let release = DispatchSemaphore(value: 0)
        defer { release.signal() }
        configureProtocol(start: { _ in escaped.fulfill() })
        let reporter = AppleAdsReporter(transport: transport, defaults: defaults.value, token: {
            providerEntered.fulfill()
            _ = release.wait(timeout: .now() + 3)
            providerReturned.fulfill()
            return "revoked-token"
        }, record: { _, _, _ in escaped.fulfill() })
        DispatchQueue(label: "privacy-test.start").async {
            reporter.start()
            startReturned.fulfill()
        }
        wait(for: [providerEntered], timeout: 2)
        wait(for: [startReturned], timeout: 0.3)
        DispatchQueue(label: "privacy-test.revoke").async {
            transport.setEnabled(false)
            revokeReturned.fulfill()
        }
        wait(for: [revokeReturned], timeout: 0.3)
        XCTAssertNil(transport.lease)
        release.signal()
        wait(for: [providerReturned, escaped], timeout: 0.3)
        XCTAssertFalse(defaults.value.bool(forKey: "telemetry.attributionSent"))
    }

    func testOldHeldTokenCannotSendOrClearTheNewRunAfterOffOn() {
        let transport = makeTransport(enabled: true)
        let defaults = PrivacyDefaults()
        let oldEntered = expectation(description: "old provider held")
        let oldReturned = expectation(description: "old provider released")
        let newRequest = expectation(description: "new generation request held")
        let recorded = expectation(description: "new generation recorded once")
        let oldRelease = DispatchSemaphore(value: 0)
        defer { oldRelease.signal() }
        let tokens = PrivacyCounter()
        let requests = PrivacyCounter()
        let heldRequest = PrivacyHeldRequest()
        newRequest.assertForOverFulfill = true
        configureProtocol(start: { request in
            _ = requests.increment()
            heldRequest.value = request
            newRequest.fulfill()
        })
        let reporter = AppleAdsReporter(transport: transport, defaults: defaults.value, token: {
            if tokens.increment() == 1 {
                oldEntered.fulfill()
                _ = oldRelease.wait(timeout: .now() + 3)
                oldReturned.fulfill()
                return "old-token"
            }
            return "new-token"
        }, record: { _, _, done in done(true); recorded.fulfill() })
        reporter.start()
        wait(for: [oldEntered], timeout: 2)
        transport.setEnabled(false)
        transport.setEnabled(true)
        reporter.start()
        wait(for: [newRequest], timeout: 2)
        oldRelease.signal()
        wait(for: [oldReturned], timeout: 2)
        // The old provider's completion must not clear this generation's still-active request.
        reporter.start()
        XCTAssertEqual(tokens.value, 2)
        XCTAssertFalse(defaults.value.bool(forKey: "telemetry.attributionSent"))
        heldRequest.value?.respond(status: 200, body: #"{"attribution":false}"#)
        wait(for: [recorded], timeout: 2)
        XCTAssertEqual(requests.value, 1)
        XCTAssertTrue(defaults.value.bool(forKey: "telemetry.attributionSent"))
    }

    func testAttributionRevocationDuringRetryWaitPreventsMoreRequestsAndEvents() {
        let transport = makeTransport(enabled: true)
        let first = expectation(description: "attribution first attempt")
        let later = expectation(description: "no later attribution")
        later.isInverted = true
        configureProtocol(start: { request in
            XCTAssertEqual(request.request.url, URL(string: "https://api-adservices.apple.com/api/v1/"))
            first.fulfill()
            request.respond(status: 404)
        })
        let reporter = AppleAdsReporter(transport: transport, defaults: freshDefaults(), retryDelay: 0.1,
                                       token: { "token" }, record: { _, _, _ in later.fulfill() })
        reporter.start()
        wait(for: [first], timeout: 2)
        transport.setEnabled(false)
        configureProtocol(start: { _ in later.fulfill() })
        wait(for: [later], timeout: 0.3)
    }

    func testInflightAttributionIsCanceledAndAnOffOnCycleCanStartExactlyOneNewRun() {
        let transport = makeTransport(enabled: true)
        let first = expectation(description: "first attribution held")
        let canceled = expectation(description: "first attribution canceled")
        let second = expectation(description: "second attribution held")
        let recorded = expectation(description: "only the new generation uploads")
        let tokens = PrivacyCounter()
        let requests = PrivacyCounter()
        configureProtocol(start: { request in
            if requests.increment() == 1 { first.fulfill() } else {
                second.fulfill()
                request.respond(status: 200, body: #"{"attribution":false}"#)
            }
        }, stop: { canceled.fulfill() })
        let reporter = AppleAdsReporter(transport: transport, defaults: freshDefaults(), token: {
            _ = tokens.increment(); return "token"
        }, record: { _, _, done in done(true); recorded.fulfill() })
        reporter.start()
        wait(for: [first], timeout: 2)
        transport.setEnabled(false)
        wait(for: [canceled], timeout: 2)
        transport.setEnabled(true)
        reporter.start()
        reporter.start()
        wait(for: [second, recorded], timeout: 2)
        XCTAssertEqual(tokens.value, 2)
        XCTAssertEqual(requests.value, 2)
    }

    func testAttributionWhitelistOmitsCountryAndDoesNotMarkSentBeforeAcknowledgment() {
        let transport = makeTransport(enabled: true)
        let defaults = PrivacyDefaults()
        let recorded = expectation(description: "attribution upload")
        configureProtocol(start: { $0.respond(status: 200, body: #"{"attribution":true,"countryOrRegion":"US","campaignId":42,"clickDate":"private"}"#) })
        let reporter = AppleAdsReporter(transport: transport, defaults: defaults.value, token: { "token" }, record: { values, _, done in
            XCTAssertEqual(values["campaign"], "42")
            XCTAssertNil(values["country"])
            XCTAssertNil(values["clickDate"])
            XCTAssertFalse(defaults.value.bool(forKey: "telemetry.attributionSent"))
            done(false)
            recorded.fulfill()
        })
        reporter.start()
        wait(for: [recorded], timeout: 2)
        XCTAssertFalse(defaults.value.bool(forKey: "telemetry.attributionSent"))
    }

    func testGameCenterRequiresExplicitConfigurationAndNonautomatedRun() {
        for value in [nil, "", "$(TIMBRE_GAME_CENTER_ENABLED)", "NO", "false", false] as [Any?] {
            XCTAssertFalse(GameCenterConfiguration.enabled(value: value, automated: false))
        }
        XCTAssertTrue(GameCenterConfiguration.enabled(value: "YES", automated: false))
        XCTAssertTrue(GameCenterConfiguration.enabled(value: true, automated: false))
        XCTAssertFalse(GameCenterConfiguration.enabled(value: "YES", automated: true))
    }

    func testHeldProtocolKeepsItsOwnSessionHandlersWhenAnotherSessionIsConfigured() {
        let firstID = UUID().uuidString, secondID = UUID().uuidString
        defer { PrivacyURLProtocol.reset(id: firstID); PrivacyURLProtocol.reset(id: secondID) }
        let firstStarts = PrivacyCounter(), firstStops = PrivacyCounter(), secondCalls = PrivacyCounter()
        PrivacyURLProtocol.configure(id: firstID, start: { _ in _ = firstStarts.increment() },
                                     stop: { _ = firstStops.increment() })
        let request = protocolRequest(id: firstID)
        request.startLoading()
        PrivacyURLProtocol.configure(id: secondID, start: { _ in _ = secondCalls.increment() },
                                     stop: { _ = secondCalls.increment() })
        request.stopLoading()
        XCTAssertEqual(firstStarts.value, 1)
        XCTAssertEqual(firstStops.value, 1)
        XCTAssertEqual(secondCalls.value, 0)
    }

    func testRetiredProtocolScopeFailsClosedInsteadOfAdoptingTheNextSession() {
        let retired = UUID().uuidString, current = UUID().uuidString
        defer { PrivacyURLProtocol.reset(id: current) }
        let escaped = PrivacyCounter()
        PrivacyURLProtocol.configure(id: retired, start: { _ in _ = escaped.increment() })
        let client = PrivacyProtocolClient()
        let request = protocolRequest(id: retired, client: client)
        PrivacyURLProtocol.reset(id: retired)
        PrivacyURLProtocol.configure(id: current, start: { _ in _ = escaped.increment() })
        request.startLoading()
        XCTAssertEqual(escaped.value, 0)
        XCTAssertEqual(client.failures, [URLError.Code.cancelled.rawValue])
    }

    func testCanceledProtocolCannotSendLateResponseOrStopTwice() {
        let id = UUID().uuidString
        defer { PrivacyURLProtocol.reset(id: id) }
        let stops = PrivacyCounter(), client = PrivacyProtocolClient()
        PrivacyURLProtocol.configure(id: id, start: { _ in }, stop: { _ = stops.increment() })
        let request = protocolRequest(id: id, client: client)
        request.startLoading()
        request.stopLoading()
        request.respond(status: 200)
        request.stopLoading()
        XCTAssertEqual(stops.value, 1)
        XCTAssertEqual(client.responses, 0)
        XCTAssertEqual(client.completions, 0)
    }

    private func protocolRequest(id: String, client: URLProtocolClient? = nil) -> PrivacyURLProtocol {
        var request = URLRequest(url: URL(string: "https://privacy.test/held")!)
        request.setValue(id, forHTTPHeaderField: PrivacyURLProtocol.scopeHeader)
        return PrivacyURLProtocol(request: request, cachedResponse: nil, client: client)
    }

    private func freshDefaults() -> UserDefaults {
        UserDefaults(suiteName: "privacy-tests.\(UUID().uuidString)")!
    }
}

private final class PrivacySessionDelegate: NSObject, URLSessionDelegate, @unchecked Sendable {
    private let invalidated: XCTestExpectation
    init(invalidated: XCTestExpectation) { self.invalidated = invalidated; super.init() }
    func urlSession(_ session: URLSession, didBecomeInvalidWithError error: Error?) { invalidated.fulfill() }
}

private final class PrivacyProtocolClient: NSObject, URLProtocolClient, @unchecked Sendable {
    private let lock = NSLock()
    private var storedFailures: [Int] = []
    private var storedResponses = 0, storedCompletions = 0
    var failures: [Int] { lock.withLock { storedFailures } }
    var responses: Int { lock.withLock { storedResponses } }
    var completions: Int { lock.withLock { storedCompletions } }
    func urlProtocol(_ loadingProtocol: URLProtocol, wasRedirectedTo request: URLRequest, redirectResponse: URLResponse) {}
    func urlProtocol(_ loadingProtocol: URLProtocol, cachedResponseIsValid cachedResponse: CachedURLResponse) {}
    func urlProtocol(_ loadingProtocol: URLProtocol, didReceive response: URLResponse, cacheStoragePolicy policy: URLCache.StoragePolicy) {
        lock.withLock { storedResponses += 1 }
    }
    func urlProtocol(_ loadingProtocol: URLProtocol, didLoad data: Data) {}
    func urlProtocolDidFinishLoading(_ loadingProtocol: URLProtocol) { lock.withLock { storedCompletions += 1 } }
    func urlProtocol(_ loadingProtocol: URLProtocol, didFailWithError error: Error) {
        lock.withLock { storedFailures.append((error as NSError).code) }
    }
    func urlProtocol(_ loadingProtocol: URLProtocol, didReceive challenge: URLAuthenticationChallenge) {}
    func urlProtocol(_ loadingProtocol: URLProtocol, didCancel challenge: URLAuthenticationChallenge) {}
}

private final class PrivacyDefaults: @unchecked Sendable {
    let value = UserDefaults(suiteName: "privacy-tests.\(UUID().uuidString)")!
}

private final class PrivacyCounter: @unchecked Sendable {
    private let lock = NSLock()
    private var count = 0
    var value: Int { lock.withLock { count } }
    func increment() -> Int { lock.withLock { count += 1; return count } }
}

private final class PrivacyHeldRequest: @unchecked Sendable {
    private let lock = NSLock()
    private var stored: PrivacyURLProtocol?
    var value: PrivacyURLProtocol? {
        get { lock.withLock { stored } }
        set { lock.withLock { stored = newValue } }
    }
}

private final class PrivacyURLProtocol: URLProtocol, @unchecked Sendable {
    static let scopeHeader = "X-Timbre-Privacy-Test-Scope"
    private struct Handlers {
        let start: (PrivacyURLProtocol) -> Void
        let stop: (() -> Void)?
    }
    private static let lock = NSLock()
    private nonisolated(unsafe) static var handlers: [String: Handlers] = [:]
    private let stateLock = NSRecursiveLock()
    private enum State { case waiting, loading, stopped, finished }
    private var state = State.waiting
    private var onStop: (() -> Void)?

    static func configure(id: String, start: @escaping (PrivacyURLProtocol) -> Void, stop: (() -> Void)? = nil) {
        lock.withLock { handlers[id] = Handlers(start: start, stop: stop) }
    }
    static func reset(id: String) { _ = lock.withLock { handlers.removeValue(forKey: id) } }
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        let id = request.value(forHTTPHeaderField: Self.scopeHeader) ?? ""
        let handler = Self.lock.withLock { Self.handlers[id] }
        stateLock.withLock {
            guard state == .waiting else { return }
            guard let handler else {
                state = .finished
                client?.urlProtocol(self, didFailWithError: URLError(.cancelled))
                return
            }
            state = .loading
            onStop = handler.stop
            handler.start(self)
        }
    }
    override func stopLoading() {
        let stopped: (() -> Void)? = stateLock.withLock {
            guard state == .waiting || state == .loading else { return nil }
            state = .stopped
            let callback = onStop
            onStop = nil
            return callback
        }
        stopped?()
    }
    func respond(status: Int, body: String = "OK") {
        stateLock.withLock {
            guard state == .loading else { return }
            state = .finished
            onStop = nil
            let response = HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: "HTTP/1.1", headerFields: nil)!
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: Data(body.utf8))
            client?.urlProtocolDidFinishLoading(self)
        }
    }
}
