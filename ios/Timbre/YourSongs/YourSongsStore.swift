import SwiftUI
import TimbreCore
import UniformTypeIdentifiers

/// The player's own songs ("Your songs" on the Songs tab): their chord charts and the recordings they play along with,
/// kept in the app's storage on this device (`UserSongLibrary`), never uploaded or synced. Charts come in from Files,
/// the clipboard, the editor, a recording's detected chords, or another app's share sheet ("Open in Timbre", which
/// RootView hands to `receive`); the player supplies every chart and recording, Timbre bundles none.
@MainActor
final class YourSongsStore: ObservableObject {
    static let shared = YourSongsStore()

    @Published private(set) var songs: [UserSong] = []
    /// A song that just came in from outside (another app's "Open in Timbre"): the shelf opens it.
    @Published var pendingOpen: String?
    /// Why the last import didn't work, for an alert.
    @Published var problem: String?

    let library: UserSongLibrary?
    private var charts: [String: (source: String, chart: ChordChart)] = [:]

    /// The largest chart file read: a chord chart is a few kilobytes.
    static let maxChartBytes = 512 * 1024

    private init() {
        var base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Timbre", isDirectory: true)
        #if DEBUG
        // UI tests keep their own state (as `Bootstrap` does for the app's store).
        if let identifier = ProcessInfo.processInfo.environment["TIMBRE_TEST_STORAGE_ID"], UUID(uuidString: identifier) != nil {
            base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
                .appendingPathComponent("TimbreUITests", isDirectory: true).appendingPathComponent(identifier, isDirectory: true)
        }
        #endif
        library = try? UserSongLibrary(directory: base.appendingPathComponent("YourSongs", isDirectory: true))
        reload()
    }

    func reload() {
        songs = library?.loadAll() ?? []
    }

    func song(id: String) -> UserSong? { songs.first { $0.id == id } }

    /// The song's chart, read once per change of its text.
    func chart(for song: UserSong) -> ChordChart {
        if let cached = charts[song.id], cached.source == song.source { return cached.chart }
        let chart = ChordProParser.parse(song.source)
        charts[song.id] = (song.source, chart)
        return chart
    }

    /// The title the shelf shows: the chart's, else "Untitled song".
    func title(of song: UserSong) -> String {
        let title = chart(for: song).title
        return title.isEmpty ? String(localized: "Untitled song", bundle: TimbreLocalization.bundle) : title
    }

    func canAdd(pro: Bool) -> Bool { YourSongsPolicy.canAddChart(existing: songs.count, pro: pro) }

    // MARK: Changing songs

    /// Saves a new song from ChordPro text; nil (with `problem` set) when it can't be stored.
    @discardableResult func add(source: String, recording: SongRecording? = nil) -> UserSong? {
        guard let library else { problem = String(localized: "Your songs can't be saved on this device right now.", bundle: TimbreLocalization.bundle); return nil }
        var song = UserSong(source: source)
        if let recording { song.attach(recording) }
        do {
            try library.save(song)
            reload()
            Analytics.log("yoursongs_add", ["recording": recording == nil ? "0" : "1"])
            return song
        } catch {
            problem = error.localizedDescription
            return nil
        }
    }

    func update(_ song: UserSong) {
        guard let library else { return }
        var changed = song
        changed.modified = Date()
        do {
            try library.save(changed)
            if let index = songs.firstIndex(where: { $0.id == changed.id }) { songs[index] = changed } else { reload() }
        } catch {
            problem = error.localizedDescription
        }
    }

    /// Saves a song's view settings (key, capo, last opened) without moving it up the shelf.
    func remember(_ song: UserSong) {
        guard let library else { return }
        try? library.save(song)
        if let index = songs.firstIndex(where: { $0.id == song.id }) { songs[index] = song }
    }

    func delete(_ song: UserSong) {
        try? library?.delete(song)
        charts[song.id] = nil
        reload()
        Analytics.log("yoursongs_delete")
    }

    // MARK: Charts from outside

    /// The file types a chart can come in: ChordPro (declared in Info.plist as an imported type) and plain text.
    static let chordProType = UTType(importedAs: "org.chordpro.chordpro", conformingTo: .plainText)
    static var chartTypes: [UTType] { [chordProType, .plainText, .utf8PlainText, .text] }
    static let chartExtensions: Set<String> = ["cho", "chordpro", "chopro", "crd", "txt", "text"]

    /// Reads a chart file (a security-scoped URL from Files, or a copy another app handed over) and saves it as a song.
    /// The title is the chart's own, else the file's name.
    @discardableResult func importChart(from url: URL) -> UserSong? {
        do {
            let text = try Self.readText(url)
            let name = url.deletingPathExtension().lastPathComponent
            let source = ChordProImport.convert(text, fallbackTitle: name)
            guard !ChordProParser.parse(source).sections.isEmpty else {
                problem = String(localized: "That file has no chart in it.", bundle: TimbreLocalization.bundle)
                return nil
            }
            return add(source: source)
        } catch let failure as ImportFailure {
            problem = failure.message
        } catch {
            problem = String(localized: "That file couldn't be opened.", bundle: TimbreLocalization.bundle)
        }
        return nil
    }

    /// A chart pasted from the clipboard.
    @discardableResult func importPasted(_ text: String) -> UserSong? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            problem = String(localized: "There's no text on the clipboard.", bundle: TimbreLocalization.bundle)
            return nil
        }
        let source = ChordProImport.convert(trimmed, fallbackTitle: nil)
        let chart = ChordProParser.parse(source)
        let titled = chart.title.isEmpty ? ChordProEdit.setDirective("title", String(localized: "Pasted song", bundle: TimbreLocalization.bundle), in: source) : source
        return add(source: titled)
    }

    struct ImportFailure: Error {
        let message: String
    }

    /// The text of a chart file: UTF-8 (with or without a byte-order mark), UTF-16 with one, else Windows Latin-1, as
    /// older chord files often are. Too large or binary files are refused.
    static func readText(_ url: URL) throws -> String {
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }
        let data = try Data(contentsOf: url)
        guard data.count <= maxChartBytes else {
            throw ImportFailure(message: String(localized: "That file is too big to be a chord chart.", bundle: TimbreLocalization.bundle))
        }
        guard let text = decode(data), !text.contains("\u{0}") else {
            throw ImportFailure(message: String(localized: "That file isn't a text chord chart.", bundle: TimbreLocalization.bundle))
        }
        return text
    }

    static func decode(_ data: Data) -> String? {
        let bytes = [UInt8](data.prefix(3))
        if bytes.count >= 2, (bytes[0] == 0xFF && bytes[1] == 0xFE) || (bytes[0] == 0xFE && bytes[1] == 0xFF) {
            return String(data: data, encoding: .utf16)
        }
        if let text = String(data: data, encoding: .utf8) { return text }
        if let text = String(data: data, encoding: .windowsCP1252) { return text }
        return String(data: data, encoding: .isoLatin1)
    }

    // MARK: "Open in Timbre"

    /// A file another app handed to Timbre: a chart is imported and opened on the Songs tab. False for anything else
    /// (the caller then treats the URL as a link).
    func receive(_ url: URL, store: AppStore) -> Bool {
        guard url.isFileURL, Self.chartExtensions.contains(url.pathExtension.lowercased()) else { return false }
        Analytics.log("yoursongs_open_in")
        defer { Self.removeIfInbox(url) }
        if !canAdd(pro: store.isPro) {
            store.selectedTab = .songs
            store.presentPaywall("your_songs")
            return true
        }
        if let song = importChart(from: url) {
            store.selectedTab = .songs
            pendingOpen = song.id
        } else {
            store.selectedTab = .songs
        }
        return true
    }

    /// Charts left in Documents/Inbox (where the system copies a file opened in Timbre) by a launch that didn't get to
    /// import them: imported now, then removed.
    func collectInbox(store: AppStore) {
        guard let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else { return }
        let inbox = documents.appendingPathComponent("Inbox", isDirectory: true)
        let files = (try? FileManager.default.contentsOfDirectory(at: inbox, includingPropertiesForKeys: nil)) ?? []
        for file in files where Self.chartExtensions.contains(file.pathExtension.lowercased()) {
            guard canAdd(pro: store.isPro) else { break }
            if let song = importChart(from: file) { pendingOpen = song.id }
            try? FileManager.default.removeItem(at: file)
        }
    }

    private static func removeIfInbox(_ url: URL) {
        guard url.pathComponents.contains("Inbox"), url.path.contains("/Documents/") else { return }
        try? FileManager.default.removeItem(at: url)
    }

    // MARK: Recordings

    /// Copies the player's audio file into the library and attaches it to the song (replacing an earlier one).
    @discardableResult func attachAudio(from url: URL, to song: UserSong, title: String? = nil, timings: [Double] = [], bpm: Double? = nil) -> UserSong? {
        guard let library else { return nil }
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }
        do {
            let name = try library.importAudio(from: url, for: song.id)
            // Only audio Timbre can play (not copy-protected, not damaged) is kept.
            guard let duration = RecordingPlayer.duration(of: library.audioURL(named: name)), duration > 0 else {
                library.removeAudio(named: name)
                problem = String(localized: "Timbre can't play that file. Use an audio file of your own that isn't copy-protected.", bundle: TimbreLocalization.bundle)
                return nil
            }
            var changed = song
            if let old = song.recording(.file), old.reference != name { library.removeAudio(named: old.reference) }
            changed.attach(SongRecording(kind: .file, reference: name, title: title ?? url.deletingPathExtension().lastPathComponent,
                                         duration: duration, timings: timings, bpm: bpm))
            update(changed)
            Analytics.log("yoursongs_recording")
            return songs.first { $0.id == song.id }
        } catch {
            problem = String(localized: "That recording couldn't be added.", bundle: TimbreLocalization.bundle)
            return nil
        }
    }

    /// Where a song's own recording is, when it's still there.
    func audioURL(for recording: SongRecording) -> URL? {
        guard recording.kind == .file, let library, library.audioExists(named: recording.reference) else { return nil }
        return library.audioURL(named: recording.reference)
    }

    func removeRecording(_ kind: SongRecording.Kind, from song: UserSong) {
        var changed = song
        if kind == .file, let old = song.recording(.file) { library?.removeAudio(named: old.reference) }
        changed.recordings.removeAll { $0.kind == kind }
        update(changed)
    }
}
