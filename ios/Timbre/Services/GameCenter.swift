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

/// A song's "Beat my score" when Game Center's own challenge isn't there (before iOS 26, signed out, or no challenge
/// for the song in App Store Connect): the points and the link that opens the song (`timbre://lesson?id=…`).
enum PerformChallenge {
    static func message(points: Int, title: String, lesson: String) -> String {
        let link = DeepLink.lesson(id: lesson).absoluteString
        let line = String(localized: "Beat my \(points) on \(title) in Timbre: \(link)")
        guard let store = SniperChallenge.appStoreLink else { return line }
        return line + "\n" + String(localized: "Get Timbre: \(store)")
    }
}

/// Where the player's practice streak stands among their Game Center friends who are on one: "Streak #2 of 5 among
/// friends" on Progress's week card and its poster. Only counts, never a name. Nil without friends on a streak, or
/// without a streak of the player's own.
struct FriendStreak: Equatable {
    /// 1: the longest.
    let rank: Int
    /// The player and the friends on a streak.
    let total: Int

    init?(mine: Int, friends: [Int]?) {
        guard mine > 0, let friends, !friends.isEmpty else { return nil }
        rank = 1 + friends.filter { $0 > mine }.count
        total = friends.count + 1
    }
}

/// Whether friends' streaks can be read: `off` without Game Center, without the streak board, without the app's
/// NSGKFriendListUsageDescription, or when the player said no (or a parent restricts it); `ask` while GameKit may still
/// ask; `granted` once the player said yes.
enum FriendsAccess {
    case off, ask, granted
}

/// Timbre's competitive and social layer on Game Center (IDs: `GameCenterIDs`):
/// - leaderboards: Pitch Sniper's all-time and weekly boards, the ear trainer's level, the practice streak and a board
///   per featured song (a whole take at the song's tempo);
/// - challenges (iOS 26): "Challenge a friend" opens Game Center's own challenge for Pitch Sniper or the song, built on
///   its board; without one it sends a "Beat my score" card and link instead (`ChallengeFriendButton`);
/// - activities (iOS 26): a player who taps a challenge or activity in the Games app lands in Pitch Sniper or the song;
/// - friends: with the player's yes, Progress's week card says where their streak stands among friends;
/// - the app's badges as achievements.
///
/// It never stands in the way: it signs in quietly once onboarding is over and the Play tab's games or Progress's week
/// card first show (or a challenge link or Games app activity opens), never shows GameKit's sign-in screen, and when
/// nobody is signed in, Game Center is restricted or App Store Connect has no Game Center set up yet, it simply stays
/// off: the chips stay hidden, challenges fall back to links and nothing is reported. Scores and badges earned before it
/// is on are caught up when it comes on (once each, never at every launch: a score sent counts as a try in a
/// challenge). Nothing is stored about the player beyond what was already sent; friends' streaks stay in memory.
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
    /// Game Center's own challenges (iOS 26) by the leaderboard each is built on.
    @Published private(set) var challengeDefinitions: [String: String] = [:]
    /// Boards with a challenge going on now (iOS 26).
    @Published private(set) var liveChallenges: Set<String> = []
    @Published private(set) var friendsAccess = FriendsAccess.off
    /// Friends' streaks in days, only those still going (sent today or yesterday); nil until read, or without access.
    @Published private(set) var friendStreaks: [Int]?

    private weak var store: AppStore?
    private var started = false
    private var watcher: AnyCancellable?
    private var recordsWatcher: AnyCancellable?
    /// The boards have loaded once since signing in (the streak and friends follow them).
    private var boardsReady = false
    private var listener: GameCenterListener?
    private var challengesLoadedAt: Date?
    private var friendsLoadedAt: Date?
    /// This launch's best take at full tempo per song lesson, for "Challenge a friend" on its results.
    private var performBests: [String: Int] = [:]
    /// The ear level last sent this launch (Game Center keeps the best).
    private var sentEarLevel = 0
    /// Badges sent this launch and still waiting for an answer, or refused (App Store Connect may not have them yet):
    /// they are tried again next launch.
    private var tried: Set<String> = []
    /// Badges Game Center has confirmed, kept across launches so each is reported once.
    private static let reportedKey = "gamecenter.reported"
    /// The best Pitch Sniper score already sent (GameKit queues a submission made offline).
    private static let sniperSentKey = "gamecenter.sniper.sent"
    /// The streak last sent and on which day ("2026-10-24:12").
    private static let streakSentKey = "gamecenter.streak.sent"

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

    /// At launch (RootView): on iOS 26, a Games app challenge or activity waiting for Timbre signs in straight away, so
    /// GameKit can hand it over and `play(activity:lesson:)` opens its screen. Nothing waiting: Game Center stays
    /// asleep (no banner) until the games show. GameKit allows the check before signing in.
    func launched(_ store: AppStore) {
        guard Self.enabled, store.settings.onboardingCompleted == true, !started else { return }
        guard #available(iOS 26.0, *) else { return }
        self.store = store
        GKGameActivity.checkPendingGameActivityExistence { pending in
            guard pending else { return }
            Task { @MainActor in GameCenter.shared.activatePending() }
        }
    }

    private func activatePending() {
        guard let store else { return }
        activate(store)
    }

    private func authenticationChanged() {
        let signedIn = GKLocalPlayer.local.isAuthenticated
        guard signedIn != active else { return }
        active = signedIn
        guard signedIn, let store = self.store else {
            boards = []
            weeklyRank = nil
            watcher = nil
            recordsWatcher = nil
            boardsReady = false
            challengeDefinitions = [:]
            liveChallenges = []
            challengesLoadedAt = nil
            friendsAccess = .off
            friendStreaks = nil
            friendsLoadedAt = nil
            return
        }
        Analytics.log("game_center_on")
        listen()
        loadBoards()
        refreshChallenges(force: true)
        // A best set while Game Center was off goes to the all-time board, once.
        let best = store.progress.stats["sniperBest"] ?? 0
        if best > UserDefaults.standard.integer(forKey: Self.sniperSentKey) {
            submit(best, to: [GameCenterIDs.sniperBest], refreshRank: false)
            Self.markSniperSent(best)
        }
        catchUp(store.settings)
        // Badges and ear levels change inside the saved settings; the value arrives before it lands, so it is passed on.
        watcher = store.$settings.dropFirst().sink { [weak self] settings in self?.catchUp(settings) }
        // A day's practice lands in the records: the streak is sent once they have settled.
        recordsWatcher = store.$records.dropFirst()
            .debounce(for: .seconds(2), scheduler: DispatchQueue.main)
            .sink { [weak self] _ in self?.reportStreak() }
    }

    /// Hears Game Center's activities for this player (iOS 26) from now on.
    private func listen() {
        guard listener == nil else { return }
        let listener = GameCenterListener()
        self.listener = listener
        GKLocalPlayer.local.register(listener)
    }

    // MARK: Reporting

    /// A progress event as `AppStore.recordProgress` saved it: a finished Pitch Sniper game goes to both its boards (and
    /// so to a Game Center challenge on them) and counts toward a friend's challenge link.
    func recorded(_ event: ProgressEvent) {
        guard case .sniperGame(let score, _) = event, score > 0 else { return }
        if var current = challenge {
            let wasBeaten = current.beaten
            current.best = max(current.best ?? 0, score)
            challenge = current
            if current.beaten && !wasBeaten { Analytics.log("challenge_beaten", ["game": PlayGame.sniper.rawValue]) }
        }
        submit(score, to: [GameCenterIDs.sniperWeekly, GameCenterIDs.sniperBest], refreshRank: true)
        if active { Self.markSniperSent(score) }
    }

    /// A whole take of a song at its own tempo (Learn/SongPerform.swift): kept for "Challenge a friend" on the results,
    /// and sent to the song's board when it is a featured song. `notes` caps what a take can claim.
    func performed(lesson id: String, points: Int, notes: Int) {
        guard points > 0, points <= notes * GameCenterIDs.pointsPerNote else { return }
        performBests[id] = max(performBests[id] ?? 0, points)
        guard let song = GameCenterIDs.song(forLesson: id) else { return }
        submit(points, to: [song.leaderboardID], refreshRank: false)
    }

    /// A take at full tempo stopped part-way (Stop, or the app left). While a Game Center challenge on the song is on,
    /// its points so far count as that try, as Apple asks, so leaving a weak take can't buy a fresh one. Otherwise
    /// nothing is sent, as the stage promises.
    func performStopped(lesson id: String, points: Int, notes: Int) {
        guard let song = GameCenterIDs.song(forLesson: id), hasLiveChallenge(on: song.leaderboardID),
              points >= 0, points <= notes * GameCenterIDs.pointsPerNote else { return }
        submit(points, to: [song.leaderboardID], refreshRank: false, allowZero: true)
    }

    /// This launch's best take of the song at full tempo, if there is one.
    func performBest(for lesson: String) -> Int? {
        performBests[lesson]
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

    /// The practice streak, when it has changed or a new day has begun ("Most recent score": it can go down), so
    /// friends' week cards read it fresh.
    private func reportStreak() {
        guard active, boards.contains(GameCenterIDs.streak), let store else { return }
        let days = store.streak.current
        let key = store.todayKey + ":" + String(days)
        let defaults = UserDefaults.standard
        guard defaults.string(forKey: Self.streakSentKey) != key else { return }
        defaults.set(key, forKey: Self.streakSentKey)
        submit(days, to: [GameCenterIDs.streak], refreshRank: false, allowZero: true)
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

    private static func markSniperSent(_ score: Int) {
        let defaults = UserDefaults.standard
        defaults.set(max(score, defaults.integer(forKey: sniperSentKey)), forKey: sniperSentKey)
    }

    /// Submits at the end of a game or take only, as challenges count every submission as a try. Zero goes through
    /// only where it means something (a streak that ended, a challenged take stopped at once).
    private func submit(_ score: Int, to ids: [String], refreshRank: Bool, allowZero: Bool = false) {
        guard active, score > 0 || (allowZero && score == 0), !ids.isEmpty else { return }
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
            Task { @MainActor in GameCenter.shared.boardsLoaded(ids) }
            guard let weekly = list.first(where: { $0.baseLeaderboardID == GameCenterIDs.sniperWeekly }) else { return }
            weekly.loadEntries(for: [GKLocalPlayer.local], timeScope: .allTime) { local, _, _ in
                let rank = local?.rank
                Task { @MainActor in GameCenter.shared.weeklyRank = rank }
            }
        }
    }

    /// The first time the boards arrive after signing in, the streak is sent and friends' streaks are read.
    private func boardsLoaded(_ ids: Set<String>) {
        guard active else { return }
        boards = ids
        guard !boardsReady else { return }
        boardsReady = true
        reportStreak()
        checkFriendsAccess()
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

    // MARK: Challenge links

    /// A challenge link arrived: its score is the one to beat, on the Pitch Sniper card and in the game.
    func accept(sniperTarget score: Int) {
        challenge = SniperChallenge(target: score)
        Analytics.log("challenge_opened", ["game": PlayGame.sniper.rawValue])
    }

    // MARK: Game Center challenges (iOS 26)

    /// The board a game's "Challenge a friend" is built on: Pitch Sniper's weekly board (its all-time one should App
    /// Store Connect have the challenge there instead). The ear trainer has no challenge.
    func challengeBoard(for game: PlayGame) -> String? {
        switch game {
        case .sniper:
            let onBest = challengeDefinitions[GameCenterIDs.sniperBest] != nil
            let onWeekly = challengeDefinitions[GameCenterIDs.sniperWeekly] != nil
            return onBest && !onWeekly ? GameCenterIDs.sniperBest : GameCenterIDs.sniperWeekly
        case .ear:
            return nil
        }
    }

    /// Game Center can run a challenge on the board: iOS 26, signed in, and App Store Connect has one on it.
    func canChallenge(on board: String) -> Bool {
        active && challengeDefinitions[board] != nil
    }

    /// A challenge on the board is going on now (the end screen says so and opens it).
    func hasLiveChallenge(on board: String) -> Bool {
        active && liveChallenges.contains(board)
    }

    /// Game Center's own screen for starting the board's challenge: the player picks friends (or anyone in Contacts),
    /// how many tries and how long it runs, and Game Center keeps score from the board.
    func challengeFriends(on board: String, from screen: String) {
        guard active, let id = challengeDefinitions[board] else { return }
        guard #available(iOS 26.0, *) else { return }
        Analytics.log("challenge_compose", ["board": board, "screen": screen])
        GKAccessPoint.shared.trigger(challengeDefinitionID: id) {
            Task { @MainActor in GameCenter.shared.refreshChallenges(force: true) }
        }
    }

    /// Game Center's challenges for Timbre: those going on, and new ones to start.
    func showChallenges() {
        guard active else { return }
        guard #available(iOS 26.0, *) else { return }
        Analytics.log("challenges_opened")
        GKAccessPoint.shared.triggerForChallenges(handler: nil)
    }

    /// Which challenges App Store Connect has, and which are going on: at sign-in, after one is started, and when a
    /// game's end screen shows (at most once a minute then). Nothing before iOS 26.
    func refreshChallenges(force: Bool = false) {
        guard active else { return }
        if !force, let at = challengesLoadedAt, Date().timeIntervalSince(at) < 60 { return }
        challengesLoadedAt = Date()
        guard #available(iOS 26.0, *) else { return }
        loadChallenges()
    }

    @available(iOS 26.0, *)
    private func loadChallenges() {
        GKChallengeDefinition.loadChallengeDefinitions { definitions, _ in
            let list = definitions ?? []
            var byBoard: [String: String] = [:]
            for definition in list {
                guard let board = definition.leaderboard?.baseLeaderboardID else { continue }
                // Two challenges on one board: the one named in GameCenterIDs wins.
                if byBoard[board] == nil || GameCenterIDs.challenges.contains(definition.identifier) {
                    byBoard[board] = definition.identifier
                }
            }
            let found = byBoard
            Task { @MainActor in GameCenter.shared.challengesLoaded(found) }
            for definition in list {
                guard let board = definition.leaderboard?.baseLeaderboardID else { continue }
                definition.hasActiveChallenges(completionHandler: { live, _ in
                    Task { @MainActor in GameCenter.shared.challengeLive(board, live) }
                })
            }
        }
    }

    private func challengesLoaded(_ found: [String: String]) {
        guard active else { return }
        challengeDefinitions = found
    }

    private func challengeLive(_ board: String, _ live: Bool) {
        guard active else { return }
        if live { liveChallenges.insert(board) } else { liveChallenges.remove(board) }
    }

    // MARK: Activities (iOS 26)

    /// A player chose one of Timbre's activities in Game Center or the Games app, most often from a friend's challenge:
    /// the song it names opens (as a `timbre://lesson` link, so Learn's access rules apply), or Pitch Sniper. False for
    /// an activity Timbre doesn't know.
    @discardableResult
    func play(activity id: String, lesson: String?) -> Bool {
        guard let store else { return false }
        Analytics.log("game_activity", ["activity": id])
        let song = lesson ?? GameCenterIDs.songs.first(where: { $0.activityID == id })?.lesson
        if let song, store.curriculum.lesson(id: song) != nil {
            DeepLink.open(DeepLink.lesson(id: song), store: store)
            return true
        }
        guard id == GameCenterIDs.sniperActivity else { return false }
        store.selectedTab = .practice
        store.pendingPracticeRoute = .sniper
        return true
    }

    // MARK: Friends

    /// The usage description GameKit shows when it asks for friends; without it GameKit refuses, so nothing asks.
    private static var friendsDescribed: Bool {
        Bundle.main.object(forInfoDictionaryKey: "NSGKFriendListUsageDescription") != nil
    }

    private func checkFriendsAccess() {
        guard active, boards.contains(GameCenterIDs.streak), Self.friendsDescribed else { friendsChanged(.off); return }
        GKLocalPlayer.local.loadFriendsAuthorizationStatus { status, error in
            let access: FriendsAccess
            if error != nil {
                access = .off
            } else {
                switch status {
                case .authorized: access = .granted
                case .notDetermined: access = .ask
                default: access = .off
                }
            }
            Task { @MainActor in GameCenter.shared.friendsChanged(access) }
        }
    }

    /// A no (or a restriction) drops whatever was read about friends.
    private func friendsChanged(_ access: FriendsAccess) {
        guard active else { friendsAccess = .off; friendStreaks = nil; return }
        friendsAccess = access
        if access == .granted { loadFriendStreaks() } else { friendStreaks = nil }
    }

    /// "Compare streaks with friends" on Progress: GameKit asks, once, with the app's reason; a yes fills in the line.
    func askFriends() {
        guard active, friendsAccess == .ask else { return }
        Analytics.log("friends_asked")
        GKLocalPlayer.local.loadFriends { _, _ in
            Task { @MainActor in GameCenter.shared.checkFriendsAccess() }
        }
    }

    /// Progress's week card is showing: friends' streaks are read again, at most every five minutes.
    func refreshFriends() {
        guard active, boardsReady else { return }
        if let at = friendsLoadedAt, Date().timeIntervalSince(at) < 300 { return }
        friendsLoadedAt = Date()
        checkFriendsAccess()
    }

    /// Friends who also allow it, and their streaks: one still counts when it was sent today or yesterday (older, it
    /// has ended; the app sends it again on their next day of practice).
    private func loadFriendStreaks() {
        friendsLoadedAt = Date()
        let calendar = Calendar.current
        let since = calendar.date(byAdding: .day, value: -1, to: calendar.startOfDay(for: Date())) ?? Date()
        GKLocalPlayer.local.loadFriends { friends, error in
            guard error == nil, let friends, !friends.isEmpty else {
                Task { @MainActor in GameCenter.shared.friendStreaksLoaded(nil) }
                return
            }
            GKLeaderboard.loadLeaderboards(IDs: [GameCenterIDs.streak]) { found, _ in
                guard let board = found?.first else {
                    Task { @MainActor in GameCenter.shared.friendStreaksLoaded(nil) }
                    return
                }
                board.loadEntries(for: friends, timeScope: .allTime) { _, entries, _ in
                    let live = (entries ?? []).filter { $0.score > 0 && $0.date >= since }.map(\.score)
                    Task { @MainActor in GameCenter.shared.friendStreaksLoaded(live) }
                }
            }
        }
    }

    private func friendStreaksLoaded(_ streaks: [Int]?) {
        guard active, friendsAccess == .granted else { friendStreaks = nil; return }
        friendStreaks = streaks
    }
}

/// Hears Game Center's events for the local player. Only activities are handled (iOS 26): a player who chose one of
/// Timbre's is taken to it.
final class GameCenterListener: NSObject, GKLocalPlayerListener {
    @available(iOS 26.0, *)
    func player(_ player: GKPlayer, wantsToPlay activity: GKGameActivity, completionHandler: @escaping @Sendable (Bool) -> Void) {
        let definition = activity.activityDefinition
        let id = definition.identifier
        let lesson = activity.properties[GameCenterIDs.lessonProperty] ?? definition.defaultProperties[GameCenterIDs.lessonProperty]
        Task { @MainActor in
            completionHandler(GameCenter.shared.play(activity: id, lesson: lesson))
        }
    }
}
