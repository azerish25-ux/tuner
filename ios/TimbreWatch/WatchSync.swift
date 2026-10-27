import Foundation
import WatchConnectivity

/// The watch's end of the link with Timbre on iPhone (Timbre/Services/WatchBridge.swift is the other). The iPhone sends
/// its snapshot as application context, and as a complication transfer when the face shows Timbre; either one is kept
/// in the App Group for the complications (`SnapshotStore`) and shown. "Start today's practice" goes back as a message.
@MainActor
final class WatchSync: NSObject, ObservableObject, WCSessionDelegate {
    static let shared = WatchSync()

    /// What "Start today's practice" led to on the iPhone.
    enum Outcome: Equatable, Sendable {
        /// Timbre was on screen and opened Today.
        case opened
        /// The iPhone got it but Timbre isn't on screen: Handoff, or opening Timbre soon, lands on Today.
        case waiting
        /// The iPhone isn't reachable (out of range, or the session isn't up yet).
        case unreachable
    }

    @Published private(set) var snapshot: WatchSnapshot? = SnapshotStore.read()
    private var activated = false

    private override init() { super.init() }

    func activate() {
        #if DEBUG
        if WatchCapture.enabled {
            let value = WatchCapture.snapshot()
            snapshot = value
            if let data = try? JSONEncoder().encode(value) { _ = SnapshotStore.accept(data) }
            return
        }
        #endif
        guard !activated, WCSession.isSupported() else { return }
        activated = true
        WCSession.default.delegate = self
        WCSession.default.activate()
    }

    /// Asks Timbre on iPhone to open today's set. Sending wakes the iPhone app in the background if it isn't running;
    /// only Timbre on screen can show Today at once (an app can't bring itself to the front).
    func startToday() async -> Outcome {
        activate()
        let session = WCSession.default
        guard session.activationState == .activated, session.isReachable else { return .unreachable }
        return await withCheckedContinuation { (continuation: CheckedContinuation<Outcome, Never>) in
            session.sendMessage([WatchLink.action: WatchLink.startToday], replyHandler: { reply in
                let opened = (reply[WatchLink.opened] as? Bool) ?? false
                continuation.resume(returning: opened ? .opened : .waiting)
            }, errorHandler: { _ in
                continuation.resume(returning: .unreachable)
            })
        }
    }

    /// The system woke Timbre to deliver what the iPhone sent while it wasn't running (`.backgroundTask(.watchConnectivity)`):
    /// stays up until it has been received and saved, ten seconds at most.
    nonisolated static func drainPending() async {
        await MainActor.run { WatchSync.shared.activate() }
        for _ in 0..<50 {
            let session = WCSession.default
            if session.activationState == .activated && !session.hasContentPending { break }
            try? await Task.sleep(for: .milliseconds(200))
        }
    }

    // MARK: WCSessionDelegate (called on WatchConnectivity's queue)

    nonisolated func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: (any Error)?) {
        guard let data = session.receivedApplicationContext[WatchLink.snapshot] as? Data else { return }
        receive(data)
    }

    nonisolated func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        guard let data = applicationContext[WatchLink.snapshot] as? Data else { return }
        receive(data)
    }

    /// A complication transfer (`transferCurrentComplicationUserInfo` on the iPhone).
    nonisolated func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any] = [:]) {
        guard let data = userInfo[WatchLink.snapshot] as? Data else { return }
        receive(data)
    }

    /// Saves a newer snapshot (the complications redraw from it) before showing it, so a background wake that ends
    /// right after this still leaves the complications current.
    nonisolated private func receive(_ data: Data) {
        guard let snapshot = SnapshotStore.accept(data) else { return }
        Task { @MainActor in self.snapshot = snapshot }
    }
}
