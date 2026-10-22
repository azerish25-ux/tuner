import XCTest
@testable import TimbreCore

final class VoiceTests: XCTestCase {
    private func hz(_ midi: Int, cents: Double = 0) -> Double { 440 * pow(2, Double(midi - 69) / 12 + cents / 1200) }
    func testEightExercisesAndTiming() {
        XCTAssertEqual(VoiceExercise(level: 5).notes, [57, 61])
        XCTAssertEqual(VoiceExercise(level: 5, rootMidi: 80).notes, [80, 76])
        XCTAssertEqual(VoiceExercise(level: 8).notes, [57, 57, 58, 60, 60, 58, 57, 55])
        XCTAssertEqual(VoiceExercise(level: 7).durationMs, 26000)
        XCTAssertEqual(VoiceExercise(level: 8).noteIndex(at: 1500), 1)
        XCTAssertEqual(VoiceExercise(level: 8).noteIndex(at: Int.max), 7)
        XCTAssertEqual(VoiceExercise(level: 6).noteIndex(at: -1), 0)
    }
    func testSilenceAndInvalidFrequenciesProduceNoScores() {
        let attempt = VoiceAttempt(exercise: VoiceExercise(level: 2))
        for (index, frequency) in [Double?.none, .some(.nan), .some(.infinity), .some(0), .some(-1)].enumerated() {
            attempt.accept(frequency: frequency, stable: true, elapsedMs: index * 50)
        }
        let result = attempt.finish()
        XCTAssertNil(result.accuracy)
        XCTAssertNil(result.stability)
        XCTAssertFalse(result.demonstrated)
        XCTAssertEqual(result.readingCount, 0)
    }
    func testExactToleranceAndGapsCannotJoinHolds() {
        let attempt = VoiceAttempt(exercise: VoiceExercise(level: 4))
        for start in [0, 3000] {
            for index in 0..<40 { attempt.accept(frequency: hz(57, cents: 30), stable: true, elapsedMs: start + index * 50) }
        }
        XCTAssertEqual(attempt.finish().longestHoldMs, 1950)
        XCTAssertNil(attempt.finish().accuracy)
        XCTAssertFalse(attempt.finish().demonstrated)
    }
    func testOffTargetSustainIsMeasuredButCannotDemonstrate() {
        let attempt = VoiceAttempt(exercise: VoiceExercise(level: 4))
        for index in 0..<110 { attempt.accept(frequency: hz(57, cents: 34), stable: true, elapsedMs: index * 50) }
        let result = attempt.finish()
        XCTAssertNotNil(result.accuracy)
        XCTAssertEqual(result.stability, 100)
        XCTAssertEqual(result.longestHoldMs, 0)
        XCTAssertFalse(result.demonstrated)
        XCTAssertTrue(result.explanation.contains("proxy"))
    }
    func testSustainedTargetDemonstratesButWarmupIsUnscored() {
        for level in [1, 4] {
            let attempt = VoiceAttempt(exercise: VoiceExercise(level: level))
            for index in 0..<110 { attempt.accept(frequency: hz(57), stable: true, elapsedMs: index * 50) }
            XCTAssertEqual(attempt.finish().accuracy, level == 1 ? nil : 100)
            XCTAssertEqual(attempt.finish().demonstrated, level == 4)
        }
    }
    func testSilenceBetweenFragmentsDoesNotCountAsSustainedSinging() {
        for level in 2...6 {
            let attempt = VoiceAttempt(exercise: VoiceExercise(level: level))
            for index in 0..<120 { attempt.accept(frequency: index % 10 == 0 ? nil : hz(57), stable: true, elapsedMs: index * 50) }
            XCTAssertNil(attempt.finish().accuracy)
        }
    }
    func testMajorThirdScoredRelativeToSungStartingNote() {
        let attempt = VoiceAttempt(exercise: VoiceExercise(level: 5))
        for stage in 0...1 {
            for index in 0..<40 { attempt.accept(frequency: hz(60 + stage * 4), stable: true, elapsedMs: stage * 3000 + index * 50) }
        }
        XCTAssertEqual(attempt.finish().accuracy, 100)
        XCTAssertTrue(attempt.finish().demonstrated)
        XCTAssertNil(attempt.finish().stability)
    }
    func testRangeRequiresRepeatedHeldNearTargetNotes() {
        let exercise = VoiceExercise(level: 7)
        let attempt = VoiceAttempt(exercise: exercise)
        for (stage, note) in exercise.notes.enumerated() {
            if [53, 55, 57, 59].contains(note) {
                for index in 0..<20 { attempt.accept(frequency: hz(note), stable: true, elapsedMs: stage * 2000 + index * 50) }
            } else { attempt.accept(frequency: nil, stable: false, elapsedMs: stage * 2000) }
        }
        let result = attempt.finish()
        XCTAssertEqual(result.lowestMidi, 53)
        XCTAssertEqual(result.highestMidi, 59)
        XCTAssertNil(result.accuracy)
        XCTAssertNil(result.meanAbsoluteCentsError)
        XCTAssertFalse(result.demonstrated)
    }
    func testOneRangeNoteDoesNotInventSpan() {
        let attempt = VoiceAttempt(exercise: VoiceExercise(level: 7))
        for index in 0..<20 { attempt.accept(frequency: hz(57), stable: true, elapsedMs: index * 50) }
        attempt.accept(frequency: hz(55), stable: true, elapsedMs: 2000)
        XCTAssertNil(attempt.finish().lowestMidi)
        XCTAssertNil(attempt.finish().highestMidi)
    }
    func testProgressionNeverLocksSelection() {
        var progression = VocalProgression()
        for level in 1...8 { progression.select(level: level); XCTAssertEqual(progression.selectedLevel, level) }
        XCTAssertEqual(progression.suggestedLevel, 1)
    }
    func testAccuracyAndStabilityMeasureDifferentProperties() {
        let flat = VoiceAttempt(exercise: VoiceExercise(level: 4))
        let wobble = VoiceAttempt(exercise: VoiceExercise(level: 4))
        for index in 0..<110 {
            flat.accept(frequency: hz(57, cents: -25), stable: true, elapsedMs: index * 50)
            wobble.accept(frequency: hz(57, cents: index % 2 == 0 ? -20 : 20), stable: true, elapsedMs: index * 50)
        }
        XCTAssertGreaterThan(wobble.finish().accuracy!, flat.finish().accuracy!)
        XCTAssertGreaterThan(flat.finish().stability!, wobble.finish().stability!)
    }
    func testEveryMelodyStageMustContainSustainedEvidence() {
        let exercise = VoiceExercise(level: 8)
        let attempt = VoiceAttempt(exercise: exercise)
        for stage in 0..<7 {
            for index in 0..<20 {
                attempt.accept(frequency: hz(exercise.notes[stage]), stable: true, elapsedMs: stage * 1500 + index * 50)
            }
        }
        XCTAssertNil(attempt.finish().accuracy)
        for index in 0..<20 {
            attempt.accept(frequency: hz(exercise.notes[7]), stable: true, elapsedMs: 10500 + index * 50)
        }
        XCTAssertEqual(attempt.finish().accuracy, 100)
        XCTAssertEqual(attempt.finish().contourPercent, 100)
        XCTAssertTrue(attempt.finish().demonstrated)
    }
}
