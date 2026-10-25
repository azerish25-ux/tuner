import XCTest
@testable import TimbreCore

final class UserSongLibraryTests: XCTestCase {
    private var directory: URL!

    override func setUpWithError() throws {
        directory = FileManager.default.temporaryDirectory.appendingPathComponent("YourSongs-\(UUID().uuidString)", isDirectory: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: directory)
    }

    func testSavesLoadsAndDeletes() throws {
        let library = try UserSongLibrary(directory: directory)
        let older = UserSong(id: "a", source: "{title: Old}\n[G]x", created: Date(timeIntervalSince1970: 1000))
        var newer = UserSong(id: "b", source: "{title: New}\n[C]y", created: Date(timeIntervalSince1970: 2000))
        newer.attach(SongRecording(kind: .file, reference: "take.m4a", title: "New", artist: "Band", duration: 180, timings: [1, 2, 3]))
        newer.attach(SongRecording(kind: .appleMusic, reference: "123", title: "New", artist: "Band", duration: 180, timings: [1, 2, 3]))
        try library.save(older)
        try library.save(newer)
        let loaded = library.loadAll()
        XCTAssertEqual(loaded.map(\.id), ["b", "a"], "most recently changed first")
        XCTAssertEqual(loaded.first?.recording(.file)?.timings, [1, 2, 3])
        XCTAssertEqual(loaded.first?.recording(.appleMusic)?.timings, [], "nothing is ever timed to Apple Music")
        XCTAssertEqual(loaded.first?.recordings.count, 2)
        XCTAssertEqual(loaded.first?.chart.title, "New")

        try library.delete(older)
        XCTAssertEqual(library.loadAll().map(\.id), ["b"])
    }

    func testSkipsDamagedFilesAndReadsOldOnes() throws {
        let library = try UserSongLibrary(directory: directory)
        try Data("not json".utf8).write(to: directory.appendingPathComponent("broken.json"))
        // A file from before transposing and recordings existed.
        let old = #"{"id":"c","source":"{title: Kept}\n[G]x","created":"2026-01-01T00:00:00Z"}"#
        try Data(old.utf8).write(to: directory.appendingPathComponent("c.json"))
        let loaded = library.loadAll()
        XCTAssertEqual(loaded.map(\.id), ["c"])
        XCTAssertEqual(loaded.first?.transpose, 0)
        XCTAssertEqual(loaded.first?.recordings, [])
        XCTAssertEqual(loaded.first?.chart.title, "Kept")
    }

    func testImportsAudioIntoTheLibrary() throws {
        let library = try UserSongLibrary(directory: directory)
        let source = directory.appendingPathComponent("take one.m4a")
        try Data([1, 2, 3]).write(to: source)
        let name = try library.importAudio(from: source, for: "song-1")
        XCTAssertTrue(name.hasPrefix("song-1-"))
        XCTAssertTrue(name.hasSuffix(".m4a"))
        XCTAssertTrue(library.audioExists(named: name))
        var song = UserSong(id: "song-1", source: "{title: T}")
        song.attach(SongRecording(kind: .file, reference: name, title: "take one"))
        song.attach(SongRecording(kind: .file, reference: name, title: "take one again"))
        XCTAssertEqual(song.recordings.count, 1, "one recording of each kind")
        try library.save(song)
        try library.delete(song)
        XCTAssertFalse(library.audioExists(named: name), "its audio goes with it")
    }

    func testSafeNames() {
        XCTAssertEqual(UserSongLibrary.safeName("a/b c.json"), "a_b_c.json")
        XCTAssertEqual(UserSongLibrary.safeName(".hidden"), "_.hidden")
    }
}
