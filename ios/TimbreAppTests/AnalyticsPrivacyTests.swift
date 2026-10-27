import Foundation
import XCTest
@testable import Timbre

/// No real network: hold and complete URLSession requests at the URLProtocol boundary.
final class AnalyticsPrivacyTests: XCTestCase {
    private func session() -> URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [PrivacyURLProtocol.self]
        return URLSession(configuration: configuration)
    }

    override func tearDown() {
        PrivacyURLProtocol.reset()
        super.tearDown()
    }

    func testRevocationCancelsAnInflightRequestAndRejectsItsResult() throws {
        let transport = AnalyticsTransport(session: session(), enabled: true)
        let started = expectation(description: "request started")
        let stopped = expectation(description: "request canceled")
        let completed = expectation(description: "completion rejected")
        PrivacyURLProtocol.configure(start: { _ in started.fulfill() }, stop: { stopped.fulfill() })
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
        let transport = AnalyticsTransport(session: session(), enabled: true)
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

    func testNewGenerationCanDeliverWithoutBeingCanceledByAnOldCompletion() throws {
        let transport = AnalyticsTransport(session: session(), enabled: true)
        let oldStarted = expectation(description: "old request started")
        PrivacyURLProtocol.configure(start: { _ in oldStarted.fulfill() })
        transport.request(URLRequest(url: URL(string: "https://privacy.test/old")!), lease: try XCTUnwrap(transport.lease)) { _ in }
        wait(for: [oldStarted], timeout: 2)
        transport.setEnabled(false)
        transport.setEnabled(true)
        let delivered = expectation(description: "new request accepted")
        PrivacyURLProtocol.configure(start: { $0.respond(status: 200) })
        transport.request(URLRequest(url: URL(string: "https://privacy.test/new")!), lease: try XCTUnwrap(transport.lease)) { result in
            guard case .success(let response) = result else { XCTFail("new generation was rejected"); delivered.fulfill(); return }
            XCTAssertEqual(response.status, 200)
            delivered.fulfill()
        }
        wait(for: [delivered], timeout: 2)
    }

    func testOptOutDropsQueuedSignalsAndPreventsFurtherUploads() {
        let transport = AnalyticsTransport(session: session(), enabled: true)
        let telemetry = Telemetry(appID: "privacy-test", transport: transport)
        telemetry.send("queued", [:])
        telemetry.setSharing(false)
        let flushed = expectation(description: "empty queue flush")
        let unexpected = expectation(description: "no request")
        unexpected.isInverted = true
        PrivacyURLProtocol.configure(start: { _ in unexpected.fulfill() })
        telemetry.send("after_revocation", [:])
        telemetry.flush { flushed.fulfill() }
        wait(for: [flushed, unexpected], timeout: 0.1)
    }

    func testExplicitRequestAcknowledgesOnlyIngestHTTP200AndNeverJustQueueing() {
        for status in [200, 202, 422, 500] {
            let transport = AnalyticsTransport(session: session(), enabled: true)
            let telemetry = Telemetry(appID: "privacy-test", transport: transport)
            let completed = expectation(description: "HTTP \(status) result")
            PrivacyURLProtocol.configure(start: { $0.respond(status: status) })
            telemetry.submit("song_request", ["title": "Example"]) { accepted in
                XCTAssertEqual(accepted, status == 200)
                completed.fulfill()
            }
            wait(for: [completed], timeout: 2)
        }
    }

    func testExplicitRequestDoesNotSucceedWithoutConfigurationOrConsent() {
        for appID in [nil, "privacy-test"] as [String?] {
            let transport = AnalyticsTransport(session: session(), enabled: appID != nil)
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
        let transport = AnalyticsTransport(session: session(), enabled: false)
        let telemetry = Telemetry(appID: "privacy-test", transport: transport)
        XCTAssertFalse(telemetry.isSending)
        let denied = expectation(description: "not yet enabled")
        telemetry.submit("song_request", ["title": "Example"]) { accepted in
            XCTAssertFalse(accepted); denied.fulfill()
        }
        wait(for: [denied], timeout: 2)
        telemetry.setSharing(true)
        let accepted = expectation(description: "saved default-on preference applied")
        PrivacyURLProtocol.configure(start: { $0.respond(status: 200) })
        telemetry.submit("song_request", ["title": "Example"]) { success in
            XCTAssertTrue(success); accepted.fulfill()
        }
        wait(for: [accepted], timeout: 2)
    }

    func testAttributionRevocationBeforeStartDoesNotCreateToken() {
        let transport = AnalyticsTransport(session: session(), enabled: false)
        let called = expectation(description: "token or event")
        called.isInverted = true
        let reporter = AppleAdsReporter(transport: transport, defaults: freshDefaults(), token: {
            called.fulfill(); return "token"
        }, record: { _, _, _ in called.fulfill() })
        reporter.start()
        wait(for: [called], timeout: 0.1)
    }

    func testHeldTokenProviderDoesNotBlockStartOrRevocationAndItsResultIsDiscarded() {
        let transport = AnalyticsTransport(session: session(), enabled: true)
        let defaults = PrivacyDefaults()
        let providerEntered = expectation(description: "token provider held")
        let startReturned = expectation(description: "start caller returned while provider held")
        let revokeReturned = expectation(description: "revocation returned while provider held")
        let providerReturned = expectation(description: "provider released")
        let escaped = expectation(description: "revoked provider must not send or record")
        escaped.isInverted = true
        let release = DispatchSemaphore(value: 0)
        defer { release.signal() }
        PrivacyURLProtocol.configure(start: { _ in escaped.fulfill() })
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
        let transport = AnalyticsTransport(session: session(), enabled: true)
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
        PrivacyURLProtocol.configure(start: { request in
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
        let transport = AnalyticsTransport(session: session(), enabled: true)
        let first = expectation(description: "attribution first attempt")
        let later = expectation(description: "no later attribution")
        later.isInverted = true
        PrivacyURLProtocol.configure(start: { request in
            if request.request.url?.path == "/api/v1/" { first.fulfill(); request.respond(status: 404) }
        })
        let reporter = AppleAdsReporter(transport: transport, defaults: freshDefaults(), retryDelay: 0.1,
                                       token: { "token" }, record: { _, _, _ in later.fulfill() })
        reporter.start()
        wait(for: [first], timeout: 2)
        transport.setEnabled(false)
        PrivacyURLProtocol.configure(start: { _ in later.fulfill() })
        wait(for: [later], timeout: 0.3)
    }

    func testInflightAttributionIsCanceledAndAnOffOnCycleCanStartExactlyOneNewRun() {
        let transport = AnalyticsTransport(session: session(), enabled: true)
        let first = expectation(description: "first attribution held")
        let canceled = expectation(description: "first attribution canceled")
        let second = expectation(description: "second attribution held")
        let recorded = expectation(description: "only the new generation uploads")
        let tokens = PrivacyCounter()
        let requests = PrivacyCounter()
        PrivacyURLProtocol.configure(start: { request in
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
        let transport = AnalyticsTransport(session: session(), enabled: true)
        let defaults = PrivacyDefaults()
        let recorded = expectation(description: "attribution upload")
        PrivacyURLProtocol.configure(start: { $0.respond(status: 200, body: #"{"attribution":true,"countryOrRegion":"US","campaignId":42,"clickDate":"private"}"#) })
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

    private func freshDefaults() -> UserDefaults {
        UserDefaults(suiteName: "privacy-tests.\(UUID().uuidString)")!
    }
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
    private static let lock = NSLock()
    private nonisolated(unsafe) static var onStart: ((PrivacyURLProtocol) -> Void)?
    private nonisolated(unsafe) static var onStop: (() -> Void)?

    static func configure(start: @escaping (PrivacyURLProtocol) -> Void, stop: (() -> Void)? = nil) {
        lock.withLock { onStart = start; onStop = stop }
    }
    static func reset() { lock.withLock { onStart = nil; onStop = nil } }
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() { Self.lock.withLock { Self.onStart }?(self) }
    override func stopLoading() { Self.lock.withLock { Self.onStop }?() }
    func respond(status: Int, body: String = "OK") {
        let response = HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: "HTTP/1.1", headerFields: nil)!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Data(body.utf8))
        client?.urlProtocolDidFinishLoading(self)
    }
}
