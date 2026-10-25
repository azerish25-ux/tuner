import XCTest
@testable import TimbreCore

/// The bundled curriculum's songs as a learner meets them: a free song at the end of every instrument course's first
/// unit; ukulele editions that keep the tune's steps and sit in keys a ukulele player can hold; cello and bass shelves of
/// their own; and the chops and chunks the strum lessons teach marked as muted strokes.
final class SongbookEditionTests: XCTestCase {
    private static let instrumentCourses = ["guitar", "ukulele", "bass", "violin", "cello", "mandolin", "banjo", "voice"]

    /// Every instrument course's first unit ends on a whole song, free like the rest of the unit; ukulele's needs only
    /// the C chord its lesson before it teaches.
    func testEveryInstrumentCourseEndsItsFirstUnitOnAFreeSong() throws {
        let curriculum = try Curriculum.bundled()
        for id in Self.instrumentCourses {
            let course = try XCTUnwrap(curriculum.course(id: id), id)
            let unit = try XCTUnwrap(course.units.first, id)
            let song = try XCTUnwrap(unit.lessons.last, id)
            XCTAssertEqual(song.kind, .song, id)
            XCTAssertTrue(unit.lessons.allSatisfy(\.free), id)
            XCTAssertNotNil(song.arrangement, id)
            XCTAssertNotNil(song.songTake, id)
        }
        let uke = try XCTUnwrap(curriculum.course(id: "ukulele")?.units.first)
        XCTAssertEqual(uke.lessons.suffix(2).map(\.id), ["uke-2-1", "uke-1-7"])
        XCTAssertEqual(Set(uke.lessons.last?.arrangement?.shapes.map(\.name) ?? []), ["C"])
    }

    /// No ukulele edition turns a step of the tune (two half steps or less) into a leap of ten or more: a phrase that
    /// moves by an octave moves whole, cut where the tune already leaps or rests.
    func testUkuleleEditionsKeepEveryStepOfTheTune() throws {
        let curriculum = try Curriculum.bundled()
        var sources: [String: Lesson] = [:]
        for id in ["songs", "standards", "originals"] {
            for lesson in curriculum.course(id: id)?.lessons ?? [] { sources[lesson.id] = lesson }
        }
        let book = try XCTUnwrap(curriculum.course(id: "ukulele-songbook"))
        XCTAssertGreaterThanOrEqual(book.lessons.count, 107)
        for edition in book.lessons {
            let sourceId = String(edition.id.dropFirst("uke-sb-".count))
            let source = try XCTUnwrap(sources[sourceId], edition.id)
            let before = try XCTUnwrap(source.songTake, sourceId).notes.sorted { $0.beat < $1.beat }
            let after = try XCTUnwrap(edition.songTake, edition.id).notes.sorted { $0.beat < $1.beat }
            XCTAssertEqual(before.count, after.count, edition.id)
            guard before.count == after.count, before.count > 1 else { continue }
            for index in 1..<before.count where abs(before[index].midi - before[index - 1].midi) <= 2 {
                XCTAssertLessThan(abs(after[index].midi - after[index - 1].midi), 10, "\(edition.id), note \(index)")
            }
        }
    }

    /// The ukulele Rondo alla Turca stays minor (its A major coda doesn't make it major) and Carmen stays in a key with
    /// open shapes: neither needs C minor, F minor, E flat or B flat 7. Chords are named by their degree in the key, so
    /// no ukulele key spells one as D sharp or A sharp.
    func testUkuleleEditionsSitInKeysTheHandCanHold() throws {
        let book = try XCTUnwrap(try Curriculum.bundled().course(id: "ukulele-songbook"))
        for id in ["uke-sb-std-rondo-alla-turca", "uke-sb-std-carmen-prelude"] {
            let lesson = try XCTUnwrap(book.lessons.first { $0.id == id }, id)
            let names = Set(lesson.arrangement?.shapes.map(\.name) ?? [])
            XCTAssertTrue(names.isDisjoint(with: ["Cm", "Fm", "Eb", "Bb7", "D#", "D#m"]), "\(id): \(names.sorted())")
        }
        let rondo = try XCTUnwrap(book.lessons.first { $0.id == "uke-sb-std-rondo-alla-turca" })
        XCTAssertTrue(rondo.arrangement?.shapes.contains { $0.name == "Dm" } ?? false, "the minor theme in D minor")
        for lesson in book.lessons {
            for shape in lesson.arrangement?.shapes ?? [] {
                XCTAssertFalse(shape.name.hasPrefix("D#") || shape.name.hasPrefix("A#"), "\(lesson.id): \(shape.name)")
            }
        }
    }

    /// Cello and bass get shelves of their own: the cello songbook in first position (C2 to D4), and a root-and-fifth
    /// line under every chart for bass, low in first position.
    func testCelloAndBassSongbooks() throws {
        let curriculum = try Curriculum.bundled()
        let cello = try XCTUnwrap(curriculum.course(id: "cello-songbook"))
        XCTAssertGreaterThanOrEqual(cello.lessons.count, 40)
        for lesson in cello.lessons {
            let take = try XCTUnwrap(lesson.songTake, lesson.id)
            XCTAssertTrue(take.notes.allSatisfy { (36...62).contains($0.midi) }, lesson.id)
        }
        let bass = try XCTUnwrap(curriculum.course(id: "bass-songbook"))
        XCTAssertTrue(bass.isSongbook)
        XCTAssertGreaterThanOrEqual(bass.lessons.count, 30)
        for lesson in bass.lessons {
            let take = try XCTUnwrap(lesson.songTake, lesson.id)
            XCTAssertTrue(take.notes.allSatisfy { (28...46).contains($0.midi) }, lesson.id)
            XCTAssertNil(lesson.arrangement?.words, "\(lesson.id): a bass line sings no words")
        }
    }

    /// Chunks, chops and skanks are muted strokes, and the 3-3-2 lesson marks its accents, so a correct choked stroke
    /// isn't heard as a missing chord.
    func testChunksAndChopsAreMarkedMuted() throws {
        let curriculum = try Curriculum.bundled()
        func steps(_ id: String) throws -> [LessonStep] { try XCTUnwrap(curriculum.lesson(id: id)?.lesson.steps, id) }
        for id in ["uke-8-1", "uke-8-2", "uke-8-6", "man-4-4", "man-4-5", "man-4-6", "man-6-5", "gtr-15-3",
                   "orig-low-tide-radio", "orig-saltwater-sunday"] {
            XCTAssertTrue(try steps(id).contains { !$0.muted.isEmpty }, id)
        }
        XCTAssertTrue(try steps("uke-8-4").contains { $0.accents == [0, 1.5, 3] })
        for step in try steps("man-4-4") {
            if case let .strum(_, pattern, _, _, _, muted, _) = step { XCTAssertEqual(pattern, muted, "every stroke of the chop lesson is a chop") }
        }
    }
}
