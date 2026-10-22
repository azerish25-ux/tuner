import Foundation
import UIKit
import Combine
import GoogleMobileAds
import UserMessagingPlatform
import TimbreCore

/// UMP owns consent evidence; StoreKit owns entitlement evidence. Neither is inferred from local flags.
@MainActor
final class AdvertisingService: NSObject, ObservableObject, FullScreenContentDelegate {
    @Published private(set) var privacyOptionsRequired = false
    @Published private(set) var configured = false
    @Published private(set) var notice: String?
    private let policy = PostTuningAdPolicy()
    private var entitlement: AdEntitlement = .unknown
    private var interstitial: InterstitialAd?
    private var presentingAd: InterstitialAd?
    private var loadedAt: TimeInterval?
    private var loading = false, gatheringConsent = false, consentUpdated = false, sdkStarted = false
    private var generation = 0
    private let unitID: String?

    override init() {
        unitID = Self.configuration()
        super.init()
        configured = unitID != nil
        if !configured { notice = "Advertising is unavailable because this build has no configured iOS AdMob identifiers." }
    }

    /// Invoke after resolved commerce updates, and once from a foreground app task.
    /// Errors suppress unavailable ads and never block tuning or navigation.
    func prepare(entitlement: AdEntitlement) async {
        updateEntitlement(entitlement)
        guard configured, entitlement.isAdSupported, UIApplication.shared.applicationState == .active else { return }
        if !consentUpdated && !gatheringConsent {
            gatheringConsent = true
            let token = generation
            await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
                ConsentInformation.shared.requestConsentInfoUpdate(with: RequestParameters()) { [weak self] updateError in
                    Task { @MainActor in
                        guard let self else { continuation.resume(); return }
                        self.consentUpdated = true
                        if let updateError { self.notice = "Ad privacy choices could not be refreshed: \(updateError.localizedDescription)" }
                        if updateError == nil, self.generation == token, self.entitlement.isAdSupported,
                           UIApplication.shared.applicationState == .active {
                            do { try await ConsentForm.loadAndPresentIfRequired(from: nil) }
                            catch { self.notice = "Ad privacy choices are unavailable: \(error.localizedDescription)" }
                        }
                        self.privacyOptionsRequired = ConsentInformation.shared.privacyOptionsRequirementStatus == .required
                        self.gatheringConsent = false
                        continuation.resume()
                    }
                }
            }
        }
        await preloadIfAllowed()
    }

    func updateEntitlement(_ value: AdEntitlement) {
        entitlement = value
        if !value.isAdSupported {
            generation += 1; interstitial = nil; loadedAt = nil
        }
    }

    /// Explicit Finish tuning only; the completion is consumed even when no ad can be shown.
    /// Pass the latest resolved entitlement at this boundary, never a cached isPlus=false default.
    func completedTuning(sessionId: String, durationMs: Int, stableReadingCount: Int, entitlement: AdEntitlement) {
        updateEntitlement(entitlement)
        let foreground = UIApplication.shared.applicationState == .active
        let fresh = loadedAt.map { ProcessInfo.processInfo.systemUptime - $0 < 3600 } ?? false
        let ready = configured && !gatheringConsent && interstitial != nil && fresh
        let claimed = policy.claimCompletion(sessionId: sessionId, durationMs: durationMs, stableReadingCount: stableReadingCount,
            elapsedRealtimeMs: Int(ProcessInfo.processInfo.systemUptime * 1000), entitlement: entitlement,
            canRequestAds: configured && consentUpdated && ConsentInformation.shared.canRequestAds,
            adReady: ready, foreground: foreground)
        guard claimed, let ad = interstitial else {
            if !fresh { interstitial = nil; loadedAt = nil }
            Task { await preloadIfAllowed() }
            return
        }
        interstitial = nil; loadedAt = nil
        presentingAd = ad
        do { try ad.canPresent(from: nil); ad.present(from: nil) }
        catch { presentingAd = nil; notice = "An advertisement could not be presented."; Task { await preloadIfAllowed() } }
    }

    /// Settings shows a button exactly when privacyOptionsRequired is true.
    func presentPrivacyOptions() async {
        guard configured, privacyOptionsRequired, UIApplication.shared.applicationState == .active else { return }
        generation += 1; interstitial = nil; loadedAt = nil
        gatheringConsent = true
        defer { gatheringConsent = false }
        do { try await ConsentForm.presentPrivacyOptionsForm(from: nil) }
        catch { notice = "Ad privacy choices are unavailable: \(error.localizedDescription)" }
        privacyOptionsRequired = ConsentInformation.shared.privacyOptionsRequirementStatus == .required
        // Loading after this task exits avoids using stale consent during presentation.
        Task { await preloadIfAllowed() }
    }

    private func preloadIfAllowed() async {
        guard let unitID, consentUpdated, !gatheringConsent, ConsentInformation.shared.canRequestAds,
              entitlement.isAdSupported, UIApplication.shared.applicationState == .active,
              !loading, interstitial == nil, presentingAd == nil else { return }
        if !sdkStarted { sdkStarted = true; MobileAds.shared.start() }
        loading = true
        let token = generation
        defer { loading = false }
        do {
            let ad = try await InterstitialAd.load(with: unitID, request: Request())
            guard generation == token, entitlement.isAdSupported, ConsentInformation.shared.canRequestAds else { return }
            ad.fullScreenContentDelegate = self
            interstitial = ad; loadedAt = ProcessInfo.processInfo.systemUptime
        } catch { notice = "No advertisement is currently available." }
    }

    func adDidDismissFullScreenContent(_ ad: FullScreenPresentingAd) { presentingAd = nil; Task { await preloadIfAllowed() } }
    func ad(_ ad: FullScreenPresentingAd, didFailToPresentFullScreenContentWithError error: Error) {
        presentingAd = nil; notice = "An advertisement could not be presented."
        Task { await preloadIfAllowed() }
    }

    private static func configuration() -> String? {
        let info = Bundle.main.infoDictionary ?? [:]
        let sdkApp = (info["GADApplicationIdentifier"] as? String ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        #if DEBUG
        if ProcessInfo.processInfo.environment["TIMBRE_USE_TEST_ADS"] == "1" {
            guard sdkApp == "ca-app-pub-3940256099942544~1458002511" else { return nil }
            return "ca-app-pub-3940256099942544/4411468910"
        }
        // Debug builds never contact production ad units.
        return nil
        #else
        let app = (info["TIMBRE_ADMOB_APP_ID"] as? String ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let unit = (info["TIMBRE_ADMOB_INTERSTITIAL_ID"] as? String ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard app == sdkApp, app.range(of: "^ca-app-pub-[0-9]{16}~[0-9]{10}$", options: .regularExpression) != nil,
              unit.range(of: "^ca-app-pub-[0-9]{16}/[0-9]{10}$", options: .regularExpression) != nil,
              !app.contains("3940256099942544"), !unit.contains("3940256099942544") else { return nil }
        return unit
        #endif
    }
}

