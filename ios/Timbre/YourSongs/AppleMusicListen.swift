import MusicKit
import SwiftUI
import TimbreCore

/// "Listen on Apple Music" on a song the player brought: their pick from the Apple Music catalog, played in Apple's own
/// player (`ApplicationMusicPlayer`) for Apple Music subscribers, with plain play, pause and restart.
///
/// Within Apple's MusicKit terms, on purpose: playback starts only from the player's own tap, it is free on every plan
/// (never behind Timbre Pro), and the track is never modified or synchronised with anything: no loop, no slow-down, no
/// chord, lyric or scroll timed to it (the chart's auto-scroll and its following of a recording run on their own
/// clocks, `ChartFollower`), and its audio (DRM-protected, outside the app's audio graph) is never analysed.
///
/// Apple Music needs the MusicKit App Service on the App ID (docs/ios/APPLE-DELIVERY.md). Until it is on, requests fail
/// with `MusicTokenRequestError.developerTokenRequestFailed` and the card says Apple Music isn't available; nothing else
/// in Your songs depends on it.
@MainActor
final class AppleMusicListener: ObservableObject {
    static let shared = AppleMusicListener()

    @Published private(set) var status = MusicAuthorization.currentStatus
    /// Whether this account can play catalog songs (an Apple Music subscription); nil until asked.
    @Published private(set) var canPlayCatalog: Bool?
    @Published private(set) var canSubscribe = false
    @Published private(set) var problem: String?
    /// The catalog song queued in the player by Timbre, if any.
    @Published private(set) var queuedId: String?
    private var updates: Task<Void, Never>?

    private var player: ApplicationMusicPlayer { ApplicationMusicPlayer.shared }

    /// Asks for access the first time (the system's prompt, with the Info.plist's reason); true once allowed.
    @discardableResult func authorize() async -> Bool {
        if MusicAuthorization.currentStatus == .notDetermined {
            status = await MusicAuthorization.request()
        } else {
            status = MusicAuthorization.currentStatus
        }
        guard status == .authorized else { return false }
        await checkSubscription()
        watchSubscription()
        return true
    }

    func refreshStatus() { status = MusicAuthorization.currentStatus }

    func checkSubscription() async {
        do {
            let subscription = try await MusicSubscription.current
            canPlayCatalog = subscription.canPlayCatalogContent
            canSubscribe = subscription.canBecomeSubscriber
        } catch {
            canPlayCatalog = false
            problem = Self.message(for: error)
        }
    }

    private func watchSubscription() {
        guard updates == nil else { return }
        updates = Task { @MainActor [weak self] in
            for await subscription in MusicSubscription.subscriptionUpdates {
                self?.canPlayCatalog = subscription.canPlayCatalogContent
                self?.canSubscribe = subscription.canBecomeSubscriber
            }
        }
    }

    func search(_ term: String) async throws -> [Song] {
        var request = MusicCatalogSearchRequest(term: term, types: [Song.self])
        request.limit = 20
        let response = try await request.response()
        return Array(response.songs)
    }

    func song(id: String) async -> Song? {
        let request = MusicCatalogResourceRequest<Song>(matching: \.id, equalTo: MusicItemID(id))
        do {
            return try await request.response().items.first
        } catch {
            problem = Self.message(for: error)
            return nil
        }
    }

    /// Plays or pauses `song`, only ever from the player's tap.
    func toggle(_ song: Song) async {
        problem = nil
        do {
            if queuedId == song.id.rawValue {
                if player.state.playbackStatus == .playing {
                    player.pause()
                } else {
                    try await player.play()
                }
            } else {
                player.queue = [song]
                queuedId = song.id.rawValue
                try await player.play()
            }
            Analytics.log("yoursongs_apple_music_play")
        } catch {
            problem = Self.message(for: error)
        }
    }

    func restart() { player.restartCurrentEntry() }

    func pause() {
        if player.state.playbackStatus == .playing { player.pause() }
    }

    func isPlaying(_ id: String?) -> Bool { id != nil && queuedId == id && player.state.playbackStatus == .playing }

    var playbackTime: Double {
        let time = player.playbackTime
        return time.isFinite ? time : 0
    }

    static func message(for error: Error) -> String {
        if let token = error as? MusicTokenRequestError {
            switch token {
            case .developerTokenRequestFailed:
                return String(localized: "Apple Music isn't available in this version of Timbre.", bundle: TimbreLocalization.bundle)
            case .privacyAcknowledgementRequired:
                return String(localized: "Open the Music app once to accept Apple Music's privacy terms, then try again.", bundle: TimbreLocalization.bundle)
            case .userNotSignedIn:
                return String(localized: "Sign in to Apple Music in Settings, then try again.", bundle: TimbreLocalization.bundle)
            case .permissionDenied, .userTokenRevoked:
                return String(localized: "Timbre isn't allowed to use Apple Music. You can allow it in Settings.", bundle: TimbreLocalization.bundle)
            default:
                break
            }
        }
        return String(localized: "Apple Music couldn't be reached. Try again in a moment.", bundle: TimbreLocalization.bundle)
    }
}

/// The song view's Apple Music card: "Listen on Apple Music" to find the song, then a plain player (artwork, title,
/// play or pause, back to the start, how far it has played) with the states around it (allow access, subscription
/// needed, Apple Music not set up). Free on every plan, and kept apart from the chart's timing.
struct AppleMusicCard: View {
    let song: UserSong
    let chartTitle: String
    let chartArtist: String?
    @ObservedObject private var library = YourSongsStore.shared
    @ObservedObject private var listener = AppleMusicListener.shared
    @ObservedObject private var playerState = ApplicationMusicPlayer.shared.state
    @Environment(\.openURL) private var openURL
    @State private var catalogSong: Song?
    @State private var picking = false
    @State private var offering = false
    @State private var working = false

    private var linked: SongRecording? { song.recording(.appleMusic) }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "music.note").font(.system(size: 13, weight: .semibold)).foregroundStyle(Palette.ink)
                    .accessibilityHidden(true)
                // Apple Music's name as Apple writes it (never in capitals).
                Text("Listen on Apple Music").font(Typeface.label(13, relativeTo: .subheadline)).foregroundStyle(Palette.ink)
                    .accessibilityAddTraits(.isHeader)
                Spacer(minLength: 0)
                if linked != nil {
                    Menu {
                        Button { picking = true } label: { Label("Choose another version", systemImage: "magnifyingglass") }
                        Button(role: .destructive) { unlink() } label: { Label("Remove", systemImage: "xmark") }
                    } label: {
                        Image(systemName: "ellipsis").font(.system(size: 15, weight: .bold)).foregroundStyle(Palette.inkSoft).tapTarget()
                    }
                    .accessibilityLabel(Text("More"))
                }
            }
            content
            if let problem = listener.problem {
                Text(verbatim: problem).font(.footnote).foregroundStyle(Palette.inkSoft).fixedSize(horizontal: false, vertical: true)
            }
        }
        .stillCard(cornerRadius: Metrics.cornerTile, padding: Metrics.tilePadding)
        .sheet(isPresented: $picking) {
            AppleMusicPicker(term: [chartTitle, chartArtist ?? ""].joined(separator: " ").trimmingCharacters(in: .whitespaces)) { picked in
                link(picked)
            }
        }
        .musicSubscriptionOffer(isPresented: $offering)
        .task(id: linked?.reference) { await loadLinked() }
        .accessibilityIdentifier("yoursongs.appleMusic")
    }

    @ViewBuilder private var content: some View {
        if linked == nil {
            Button { Task { await find() } } label: {
                Label("Find this song on Apple Music", systemImage: "magnifyingglass")
            }
            .buttonStyle(SecondaryButtonStyle())
            .disabled(working)
            Text("Plays in Apple Music for subscribers, separate from the chart.")
                .font(.caption).foregroundStyle(Palette.inkFaint).fixedSize(horizontal: false, vertical: true)
        } else if listener.status != .authorized {
            Button { Task { await listener.authorize() } } label: { Text("Allow Apple Music") }
                .buttonStyle(SecondaryButtonStyle())
            if listener.status == .denied || listener.status == .restricted {
                Button("Open Settings") { if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) } }
                    .font(.subheadline.weight(.semibold)).foregroundStyle(Palette.mint)
            }
        } else if listener.canPlayCatalog == false {
            Text("Listening needs an Apple Music subscription.").font(.subheadline).foregroundStyle(Palette.inkSoft)
            if listener.canSubscribe {
                Button { offering = true } label: { Text("Try Apple Music") }
                    .buttonStyle(SecondaryButtonStyle())
            }
        } else if let catalogSong {
            playerRow(catalogSong)
        } else {
            StageSpinner()
        }
    }

    /// The player: artwork beside the title, play or pause, back to the start, and the time played.
    private func playerRow(_ catalog: Song) -> some View {
        let playing = listener.queuedId == catalog.id.rawValue && playerState.playbackStatus == .playing
        return HStack(spacing: 12) {
            if let artwork = catalog.artwork {
                ArtworkImage(artwork, width: 56, height: 56)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .accessibilityHidden(true)
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(verbatim: catalog.title).font(.subheadline.weight(.semibold)).foregroundStyle(Palette.ink).lineLimit(1)
                Text(verbatim: catalog.artistName).font(.caption).foregroundStyle(Palette.inkSoft).lineLimit(1)
                if listener.queuedId == catalog.id.rawValue {
                    TimelineView(.periodic(from: .now, by: 0.5)) { _ in
                        Text(verbatim: Self.clock(listener.playbackTime) + (catalog.duration.map { " / " + Self.clock($0) } ?? ""))
                            .font(Typeface.number(.caption)).foregroundStyle(Palette.inkFaint)
                    }
                }
            }
            Spacer(minLength: 4)
            if listener.queuedId == catalog.id.rawValue {
                IconButton(symbol: "backward.end.fill", size: .compact, label: "Back to the start") { listener.restart() }
            }
            Button { Task { await listener.toggle(catalog) } } label: {
                Image(systemName: playing ? "pause.fill" : "play.fill")
                    .font(.system(size: 18, weight: .bold)).foregroundStyle(Palette.stage)
                    .contentTransition(.symbolEffect(.replace))
                    .frame(width: 44, height: 44)
                    .background(Circle().fill(Palette.ink))
            }
            .buttonStyle(PressScaleStyle())
            .accessibilityLabel(playing ? Text("Pause") : Text("Play"))
            .accessibilityIdentifier("yoursongs.appleMusic.play")
        }
    }

    static func clock(_ seconds: Double) -> String {
        Duration.seconds(max(0, seconds.rounded())).formatted(.time(pattern: .minuteSecond))
    }

    // MARK: Actions

    private func find() async {
        working = true
        defer { working = false }
        guard await listener.authorize() else { return }
        picking = true
    }

    private func loadLinked() async {
        guard let reference = linked?.reference else { catalogSong = nil; return }
        listener.refreshStatus()
        guard listener.status == .authorized else { return }
        if listener.canPlayCatalog == nil { await listener.checkSubscription() }
        if catalogSong?.id.rawValue != reference { catalogSong = await listener.song(id: reference) }
    }

    private func link(_ picked: Song) {
        var changed = song
        changed.attach(SongRecording(kind: .appleMusic, reference: picked.id.rawValue, title: picked.title, artist: picked.artistName,
                                     duration: picked.duration))
        library.update(changed)
        catalogSong = picked
        Analytics.log("yoursongs_apple_music_link")
    }

    private func unlink() {
        if listener.queuedId == linked?.reference { listener.pause() }
        library.removeRecording(.appleMusic, from: song)
        catalogSong = nil
    }
}

/// Finding the song in the Apple Music catalog: a search field (the chart's title and artist to start), the songs it
/// finds with their artwork, and a tap to choose one.
struct AppleMusicPicker: View {
    let term: String
    let onPick: (Song) -> Void
    @ObservedObject private var listener = AppleMusicListener.shared
    @Environment(\.dismiss) private var dismiss
    @State private var query = ""
    @State private var results: [Song] = []
    @State private var searching = false
    @State private var failure: String?

    var body: some View {
        NavigationStack {
            List {
                if searching && results.isEmpty {
                    StageSpinner("Searching Apple Music…").listRowBackground(Color.clear)
                } else if let failure {
                    Text(verbatim: failure).font(.subheadline).foregroundStyle(Palette.inkSoft).listRowBackground(Color.clear)
                } else if results.isEmpty && !query.isEmpty {
                    ContentUnavailableView.search(text: query).listRowBackground(Color.clear)
                }
                ForEach(results, id: \.id) { song in
                    Button {
                        onPick(song)
                        dismiss()
                    } label: { row(song) }
                    .listRowBackground(Palette.stageRaised)
                }
            }
            .scrollContentBackground(.hidden)
            .background(Palette.stage)
            .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always), prompt: Text("Song or artist"))
            .onSubmit(of: .search) { Task { await search() } }
            .navigationTitle(Text("Apple Music"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
            }
        }
        .presentationBackground(Palette.stage)
        .preferredColorScheme(.dark)
        .task {
            guard query.isEmpty else { return }
            query = term
            await search()
        }
    }

    private func row(_ song: Song) -> some View {
        HStack(spacing: 12) {
            if let artwork = song.artwork {
                ArtworkImage(artwork, width: 48, height: 48)
                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                    .accessibilityHidden(true)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(verbatim: song.title).font(.subheadline.weight(.semibold)).foregroundStyle(Palette.ink).lineLimit(1)
                Text(verbatim: [song.artistName, song.albumTitle ?? ""].filter { !$0.isEmpty }.joined(separator: " · "))
                    .font(.caption).foregroundStyle(Palette.inkSoft).lineLimit(1)
            }
            Spacer(minLength: 0)
        }
        .contentShape(Rectangle())
    }

    private func search() async {
        let text = query.trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty else { return }
        searching = true
        failure = nil
        defer { searching = false }
        do {
            results = try await listener.search(text)
        } catch {
            results = []
            failure = AppleMusicListener.message(for: error)
        }
    }
}
