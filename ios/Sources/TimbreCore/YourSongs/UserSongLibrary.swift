import Foundation

/// A song the player brought: their chart as ChordPro text, how they like it shown (key, capo), and the recordings
/// they play along with, each with the times its chords change.
public struct UserSong: Codable, Equatable, Identifiable, Sendable {
    public var id: String
    /// The chart, as ChordPro (`ChordProParser` reads it).
    public var source: String
    public var created: Date
    public var modified: Date
    /// Semitones the player moved the song (−11…11).
    public var transpose: Int
    /// The capo the player uses; nil for the chart's own.
    public var capo: Int?
    public var recordings: [SongRecording]
    public var lastOpened: Date?

    public init(id: String = UUID().uuidString, source: String, created: Date = Date(), modified: Date? = nil,
                transpose: Int = 0, capo: Int? = nil, recordings: [SongRecording] = [], lastOpened: Date? = nil) {
        self.id = id; self.source = source; self.created = created; self.modified = modified ?? created
        self.transpose = transpose; self.capo = capo; self.recordings = recordings; self.lastOpened = lastOpened
    }

    enum CodingKeys: String, CodingKey { case id, source, created, modified, transpose, capo, recordings, lastOpened }

    /// Lenient, so a file from a later version (or a damaged recording entry) still opens the chart.
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        source = try c.decode(String.self, forKey: .source)
        created = (try? c.decodeIfPresent(Date.self, forKey: .created)) ?? Date(timeIntervalSince1970: 0)
        modified = (try? c.decodeIfPresent(Date.self, forKey: .modified)) ?? created
        transpose = max(-11, min(11, (try? c.decodeIfPresent(Int.self, forKey: .transpose)) ?? 0))
        capo = (try? c.decodeIfPresent(Int.self, forKey: .capo)).flatMap { $0 }.map { max(0, min(12, $0)) }
        recordings = (try? c.decodeIfPresent([SongRecording].self, forKey: .recordings)) ?? []
        lastOpened = try? c.decodeIfPresent(Date.self, forKey: .lastOpened)
    }

    /// The chart, read from the source.
    public var chart: ChordChart { ChordProParser.parse(source) }

    public var transform: ChartTransform {
        ChartTransform(transpose: transpose, capo: capo, chartCapo: chart.capo)
    }

    public func recording(_ kind: SongRecording.Kind) -> SongRecording? { recordings.first { $0.kind == kind } }

    /// Adds `recording`, or replaces the one of its kind.
    public mutating func attach(_ recording: SongRecording) {
        recordings.removeAll { $0.kind == recording.kind }
        recordings.append(recording)
    }
}

/// A recording a chart plays along with: an Apple Music catalog song or an audio file the player imported.
public struct SongRecording: Codable, Equatable, Identifiable, Sendable {
    public enum Kind: String, Codable, Sendable { case appleMusic, file }

    public var kind: Kind
    /// The Apple Music catalog id, or the file's name in the library's audio folder.
    public var reference: String
    public var title: String
    public var artist: String?
    public var duration: Double?
    /// When each chord of the chart changes, in seconds (`ChartTimeline`); empty until synced.
    public var timings: [Double]
    /// The tempo found in the recording, when it was analysed.
    public var bpm: Double?

    public var id: String { kind.rawValue + ":" + reference }

    public init(kind: Kind, reference: String, title: String, artist: String? = nil, duration: Double? = nil,
                timings: [Double] = [], bpm: Double? = nil) {
        self.kind = kind; self.reference = reference; self.title = title; self.artist = artist
        self.duration = duration; self.timings = timings; self.bpm = bpm
    }

    enum CodingKeys: String, CodingKey { case kind, reference, title, artist, duration, timings, bpm }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        kind = try c.decode(Kind.self, forKey: .kind)
        reference = try c.decode(String.self, forKey: .reference)
        title = (try? c.decodeIfPresent(String.self, forKey: .title)) ?? ""
        artist = (try? c.decodeIfPresent(String.self, forKey: .artist)).flatMap { $0 }
        duration = (try? c.decodeIfPresent(Double.self, forKey: .duration)).flatMap { $0 }
        timings = ((try? c.decodeIfPresent([Double].self, forKey: .timings)) ?? []).filter(\.isFinite)
        bpm = (try? c.decodeIfPresent(Double.self, forKey: .bpm)).flatMap { $0 }
    }
}

/// The player's songs on this device: one JSON file per chart in `directory`, and the audio files they imported in
/// its `Audio` folder. Nothing is synced or uploaded. A damaged file is skipped rather than failing the shelf.
public final class UserSongLibrary: @unchecked Sendable {
    public let directory: URL
    public var audioDirectory: URL { directory.appendingPathComponent("Audio", isDirectory: true) }
    private let lock = NSLock()

    public init(directory: URL) throws {
        self.directory = directory
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: directory.appendingPathComponent("Audio", isDirectory: true), withIntermediateDirectories: true)
    }

    private func url(for id: String) -> URL {
        directory.appendingPathComponent(Self.safeName(id) + ".json")
    }

    /// Every song, most recently changed first.
    public func loadAll() -> [UserSong] {
        lock.lock(); defer { lock.unlock() }
        let files = (try? FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)) ?? []
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        var songs: [UserSong] = []
        for file in files where file.pathExtension == "json" {
            guard let data = try? Data(contentsOf: file), let song = try? decoder.decode(UserSong.self, from: data) else { continue }
            songs.append(song)
        }
        return songs.sorted { $0.modified != $1.modified ? $0.modified > $1.modified : $0.id < $1.id }
    }

    public func save(_ song: UserSong) throws {
        lock.lock(); defer { lock.unlock() }
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.sortedKeys]
        try encoder.encode(song).write(to: url(for: song.id), options: [.atomic])
    }

    /// Deletes the song and the audio files it owned.
    public func delete(_ song: UserSong) throws {
        lock.lock(); defer { lock.unlock() }
        for recording in song.recordings where recording.kind == .file {
            try? FileManager.default.removeItem(at: audioDirectory.appendingPathComponent(Self.safeName(recording.reference)))
        }
        let file = url(for: song.id)
        if FileManager.default.fileExists(atPath: file.path) { try FileManager.default.removeItem(at: file) }
    }

    /// Copies an audio file into the library for the song `id`; returns the copy's name (a `SongRecording` reference).
    /// The copy is left out of iCloud backups: the player still has the original.
    public func importAudio(from source: URL, for id: String) throws -> String {
        let ext = source.pathExtension.isEmpty ? "m4a" : source.pathExtension.lowercased()
        let name = Self.safeName(id) + "-" + String(UUID().uuidString.prefix(8)) + "." + ext
        var destination = audioDirectory.appendingPathComponent(name)
        lock.lock(); defer { lock.unlock() }
        try FileManager.default.copyItem(at: source, to: destination)
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        try? destination.setResourceValues(values)
        return name
    }

    /// Removes an imported audio file (one replaced by another).
    public func removeAudio(named name: String) {
        lock.lock(); defer { lock.unlock() }
        try? FileManager.default.removeItem(at: audioDirectory.appendingPathComponent(Self.safeName(name)))
    }

    public func audioURL(named name: String) -> URL { audioDirectory.appendingPathComponent(Self.safeName(name)) }

    public func audioExists(named name: String) -> Bool { FileManager.default.fileExists(atPath: audioURL(named: name).path) }

    /// A name safe to use as a file name: letters, digits, dot, dash and underscore only.
    static func safeName(_ name: String) -> String {
        let allowed = name.unicodeScalars.map { scalar -> Character in
            CharacterSet.alphanumerics.contains(scalar) && scalar.isASCII || scalar == "." || scalar == "-" || scalar == "_" ? Character(scalar) : "_"
        }
        let joined = String(allowed)
        return joined.isEmpty || joined.hasPrefix(".") ? "_" + joined : joined
    }
}
