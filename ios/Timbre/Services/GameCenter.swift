import Combine
import GameKit
import SwiftUI
import TimbreCore

/// The ear games with a Game Center leaderboard.
enum PlayGame: String {
    case sniper, ear
}

/// A friend's Pitch Sniper score to beat, from a challenge link (`timbre://challenge?game=sniper&score=N`). It lasts
/// until the app closes or another challenge arrives.
struct SniperChallenge: Equatable {
    /// The most one game can score: ten rounds of at most 500 points at the ×5 combo. A link claiming more is refused.
    static let maxScore = 25_000
    /// The App Store page to send with a challenge, once the app has one ("https://apps.apple.com/app/id…"); nil leaves
    /// it out. Owner step: docs/ios/APPLE-DELIVERY.md § Game Center.
    static let appStoreLink: String? = nil

    let target: Int
    /// The best game played since the challenge arrived.
    var best: Int?
    var beaten: Bool { (best ?? 0) > target }

    /// What the share sheet sends with the card: the score and the link that opens Pitch Sniper with it to beat.
    static func message(score: Int) -> String {
        let link = DeepLink.challenge(score: score).absoluteString
        let line = String(localized: "Beat my \(score) in Pitch Sniper on Timbre: \(link)")
        guard let store = appStoreLink else { return line }
        return line + "\n" + String(localized: "Get Timbre: \(store)")
    }
}

/// Timbre's competitive layer on Game Center: Pitch Sniper's all-time and weekly leaderboards, the ear trainer's level,
/// and the app's badges as achievements (IDs: `GameCenterIDs`). It never stands in the way: it signs in quietly once
/// onboarding is over and the Play tab's games first show (or a challenge link opens), never shows GameKit's sign-in
/// screen, and when nobody is signed in, Game Center is restricted or App Store Connect has no Game Center set up yet,
/// it simply stays off: the Leaderboard chips stay hidden and nothing is reported. Scores and badges earned before it
/// is on are caught up when it comes on. Nothing is stored about the player beyond which badges were already reported.
@MainActor
final class GameCenter: ObservableObject {
    static let shared = GameCenter()

    /// Signed in and recognised: reports go through and the chips can show.
    @Published private(set) var active = false
    /// The leaderboards App Store Connect has (loaded once signed in); a game's chip opens only one of these.
    @Published private(set) var boards: Set<String> = []
    /// The player's rank on this week's Pitch Sniper board, once they have a score on it.
    @Published private(set) var weeklyRank: Int?
    /// A friend's score to beat, from a challenge link.
    @Published private(set) var challenge: SniperChallenge?

    private weak var store: AppStore?
    private var started = false
    private var watcher: AnyCancellable?
    /// The ear level last sent this launch (Game Center keeps the best).
    private var sentEarLevel = 0
    /// Badges sent this launch and still waiting for an answer, or refused (App Store Connect may not have them yet):
    /// they are tried again next launch.
    private var tried: Set<String> = []
    /// Badges Game Center has confirmed, kept across launches so each is reported once.
    private static let reportedKey = "gamecenter.reported"

    /// Off under XCTest, the UI tests and the demo and screenshot modes (as coach marks are): no sign-in banner in a capture.
    static let enabled: Bool = {
        let environment = ProcessInfo.processInfo.environment
        let quiet = ["XCTestConfigurationFilePath", "TIMBRE_TEST_STORAGE_ID", "TIMBRE_DEMO_PITCH", "TIMBRE_DEMO_DATA", "TIMBRE_SCENE"]
        return !quiet.contains { environment[$0] != nil }
    }()

    private init() {}

    // MARK: Signing in

    /// Signs in quietly, once per launch, and only after onboarding (no banner over the first-run screens).
    func activate(_ store: AppStore) {
        guard Self.enabled, store.settings.onboardingCompleted == true else { return }
        self.store = store
        guard !started else { return }
        started = true
        GKLocalPlayer.local.authenticateHandler = { _, _ in
            // GameKit hands over a sign-in screen when nobody is signed in: it is never shown, and Game Center stays off
            // until the player signs in from Settings (GameKit calls this again then). An app App Store Connect doesn't
            // know yet arrives here with an error and stays off the same way.
            Task { @MainActor in GameCenter.shared.authenticationChanged() }
        }
    }

    private func authenticationChanged() {
        let signedIn = GKLocalPlayer.local.isAuthenticated
        guard signedIn != active else { return }
        active = signedIn
        guard signedIn, let store = self.store else {
            boards = []
            weeklyRank = nil
            watcher = nil
            return
        }
        Analytics.log("game_center_on")
        loadBoards()
        let best = store.progress.stats["sniperBest"] ?? 0
        if best > 0 { submit(best, to: [GameCenterIDs.sniperBest], refreshRank: false) }
        catchUp(store.settings)
        // Badges and ear levels change inside the saved settings; the value arrives before it lands, so it is passed on.
        watcher = store.$settings.dropFirst().sink { [weak self] settings in self?.catchUp(settings) }
    }

    // MARK: Reporting

    /// A progress event as `AppStore.recordProgress` saved it: a finished Pitch Sniper game goes to both its boards and
    /// counts toward a friend's challenge.
    func recorded(_ event: ProgressEvent) {
        guard case .sniperGame(let score, _) = event, score > 0 else { return }
        if var current = challenge {
            let wasBeaten = current.beaten
            current.best = max(current.best ?? 0, score)
            challenge = current
            if current.beaten && !wasBeaten { Analytics.log("challenge_beaten", ["game": PlayGame.sniper.rawValue]) }
        }
        submit(score, to: [GameCenterIDs.sniperWeekly, GameCenterIDs.sniperBest], refreshRank: true)
    }

    /// Sends what Game Center doesn't have yet: badges earned (each once), and the ear trainer's level when it rises.
    private func catchUp(_ settings: UserSettings) {
        guard active else { return }
        let earned = settings.progress?.achievements ?? []
        let reported = Set(UserDefaults.standard.stringArray(forKey: Self.reportedKey) ?? [])
        let pending = earned.filter { !reported.contains($0) && !tried.contains($0) }
        if !pending.isEmpty { report(badges: pending) }
        if let levels = settings.earLevels, !levels.isEmpty {
            let level = (EarDrill.allCases.map { levels[$0.rawValue] ?? 0 }.max() ?? 0) + 1
            if level > sentEarLevel {
                sentEarLevel = level
                submit(level, to: [GameCenterIDs.earLevel], refreshRank: false)
            }
        }
    }

    /// Reports badges as completed achievements. The app announces badges itself, so Game Center's banner stays off.
    /// Badges without an achievement count as reported straight away.
    private func report(badges: [String]) {
        tried.formUnion(badges)
        let achievements = badges.compactMap { badge -> GKAchievement? in
            guard let id = GameCenterIDs.achievementID(forBadge: badge) else { return nil }
            let achievement = GKAchievement(identifier: id)
            achievement.percentComplete = 100
            achievement.showsCompletionBanner = false
            return achievement
        }
        guard !achievements.isEmpty else { Self.markReported(badges); return }
        GKAchievement.report(achievements) { error in
            guard error == nil else { return }
            Task { @MainActor in GameCenter.markReported(badges) }
        }
    }

    private static func markReported(_ badges: [String]) {
        let defaults = UserDefaults.standard
        let reported = Set(defaults.stringArray(forKey: reportedKey) ?? []).union(badges)
        defaults.set(reported.sorted(), forKey: reportedKey)
    }

    private func submit(_ score: Int, to ids: [String], refreshRank: Bool) {
        guard active, score > 0, !ids.isEmpty else { return }
        GKLeaderboard.submitScore(score, context: 0, player: GKLocalPlayer.local, leaderboardIDs: ids) { error in
            guard error == nil, refreshRank else { return }
            Task { @MainActor in GameCenter.shared.loadBoards() }
        }
    }

    /// Which of the app's leaderboards exist, and the player's rank on this week's Pitch Sniper board.
    private func loadBoards() {
        GKLeaderboard.loadLeaderboards(IDs: GameCenterIDs.leaderboards) { found, _ in
            let list = found ?? []
            let ids = Set(list.map(\.baseLeaderboardID))
            Task { @MainActor in GameCenter.shared.boards = ids }
            guard let weekly = list.first(where: { $0.baseLeaderboardID == GameCenterIDs.sniperWeekly }) else { return }
            weekly.loadEntries(for: [GKLocalPlayer.local], timeScope: .allTime) { local, _, _ in
                let rank = local?.rank
                Task { @MainActor in GameCenter.shared.weeklyRank = rank }
            }
        }
    }

    // MARK: Leaderboards

    /// The board a game's chip opens: Pitch Sniper's week when App Store Connect has it (else its all-time board), the
    /// ear trainer's level. Nil while Game Center is off or the board doesn't exist.
    func leaderboard(for game: PlayGame) -> String? {
        guard active else { return nil }
        switch game {
        case .sniper:
            if boards.contains(GameCenterIDs.sniperWeekly) { return GameCenterIDs.sniperWeekly }
            return boards.contains(GameCenterIDs.sniperBest) ? GameCenterIDs.sniperBest : nil
        case .ear:
            return boards.contains(GameCenterIDs.earLevel) ? GameCenterIDs.earLevel : nil
        }
    }

    /// Opens the game's leaderboard in the Game Center dashboard.
    func showLeaderboard(_ game: PlayGame) {
        guard let id = leaderboard(for: game) else { return }
        GKAccessPoint.shared.trigger(leaderboardID: id, playerScope: .global, timeScope: .allTime)
        Analytics.log("leaderboard_opened", ["game": game.rawValue])
    }

    // MARK: Challenges

    /// A challenge link arrived: its score is the one to beat, on the Pitch Sniper card and in the game.
    func accept(sniperTarget score: Int) {
        challenge = SniperChallenge(target: score)
        Analytics.log("challenge_opened", ["game": PlayGame.sniper.rawValue])
    }
}
