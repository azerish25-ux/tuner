"""Source guardrails; simulator geometry remains required, these are not visual approval."""
import pathlib
import unittest

ROOT = pathlib.Path(__file__).resolve().parents[2]
SOURCE = ROOT / "ios/Timbre/Learn/LessonSteps.swift"
UI = ROOT / "ios/TimbreUITests/LessonAccessibilityLayoutUITests.swift"


class LessonAccessibilityLayoutContract(unittest.TestCase):
    def setUp(self):
        self.notes = SOURCE.read_text().split("struct NotesStep: View {", 1)[1].split("// MARK:", 1)[0]
        self.ui = UI.read_text()

    def test_accessibility_content_scrolls_above_actions(self):
        self.assertIn("if typeSize.isAccessibilitySize", self.notes)
        self.assertIn("ScrollView {\n                        noteContent", self.notes)
        self.assertIn(".scrollBounceBehavior(.basedOnSize)\n                    stepBar", self.notes)

    def test_status_wraps_outside_bounded_ring(self):
        ring = self.notes.split("private var noteRing:", 1)[1].split("// Below its neighbours", 1)[0]
        ax, normal = ring.split("} else {", 1)
        self.assertLess(ax.index(".frame(width: 290, height: 290)"), ax.index("Text(status)"))
        self.assertIn(".fixedSize(horizontal: false, vertical: true)", ax)
        self.assertIn(".frame(minWidth: 150, maxWidth: 290, minHeight: 150, maxHeight: 290)", normal)

    def test_voiceover_target_and_audio_lifecycle_preserved(self):
        for token in [".accessibilityElement(children: .ignore)", ".accessibilityValue(Text(status))",
                      ".lessonStepArrival()", ".onAppear { listen();",
                      "store.stopLessonListening(owner: owner)", "skip: { finish(score: 0.6) }, hear: { hear() }"]:
            self.assertIn(token, self.notes)

    def test_native_assertions_require_ax5_and_actual_targets(self):
        for token in ["UICTContentSizeCategoryAccessibilityXXXL", 'element("lesson.notes.target")',
                      'XCTAssertEqual(target.value as? String, "Listening…")',
                      "frame.maxY <= viewport.maxY", "target.isHittable",
                      'element("lesson.hear")', 'element("lesson.override")',
                      'app.buttons.matching(identifier: id)', 'scrollClear(explanation']:
            self.assertIn(token, self.ui)

    def test_scroll_geometry_excludes_header_and_moves_both_directions(self):
        for token in ["scroll.frame.intersection(app.frame)", "clearBottom - visible.minY",
                      "viewport.midY - frame.midY", "frame.height <= viewport.height", "viewport.height * 0.45",
                      "thenHoldForDuration: 0.2", "for attempt in 0..<12",
                      'capture("unreachable")', "isClear(target, within: contentViewport(scroll, above: bottom))"]:
            self.assertIn(token, self.ui)

    def test_scroll_evidence_fails_closed_without_hiding_layout_errors(self):
        for token in ["TIMBRE_SCROLL_GEOMETRY", "layout-ax5-scroll-geometry-", "stalled < 2",
                      "if contained && hittable { return }", "contained ? target.isHittable : false",
                      "testReachabilityPlanRequiresCompleteGeometry", "XCTAssertFalse(Self.contains(bottomClipped",
                      "XCTAssertFalse(Self.contains(topClipped", "height: 700", "x: -1",
                      "Self.scrollDistance(.infinite", "in: .null", "XCTAssertFalse(Self.contains(farBelow"]:
            self.assertIn(token, self.ui)
        plan = self.ui.split("private static func scrollDistance", 1)[1].split("private func isClear", 1)[0]
        self.assertIn("!contains(frame, in: viewport)", plan)
        self.assertIn("frame.minX >= viewport.minX, frame.maxX <= viewport.maxX", plan)
        self.assertNotIn("sleep", plan)

    def test_oversized_decoration_is_not_the_semantic_note_target(self):
        burst = self.notes.split("private var ringBurst:", 1)[1].split("private static func burstBand", 1)[0]
        self.assertIn(".frame(width: size.width * 2, height: size.height * 2)", burst)
        self.assertIn(".accessibilityHidden(true)", burst)
        self.assertIn(".allowsHitTesting(false)", burst)
        # The target and its live status remain visible to assistive technology.
        ring = self.notes.split("private var noteRing:", 1)[1].split("private func spokenPhrase", 1)[0]
        self.assertNotIn(".accessibilityHidden", ring)
        self.assertIn('.accessibilityIdentifier("lesson.notes.target")', ring)
        self.assertIn(".accessibilityValue(Text(status))", ring)

    def test_focus_shape_covers_full_note_and_status_not_overflow_decoration(self):
        ring = self.notes.split("private var noteRing:", 1)[1].split("private func spokenPhrase", 1)[0]
        # The native 580x580 burst still inflated the parent despite accessibilityHidden.
        # Define the shape on the whole container, after its AX element, not on the letter.
        shape = ".contentShape(.accessibility, Rectangle())"
        self.assertEqual(ring.count(shape), 1)
        self.assertLess(ring.index("Text(status)"), ring.index(shape))
        self.assertLess(ring.index(".accessibilityElement(children: .ignore)"), ring.index(shape))
        self.assertLess(ring.index(shape), ring.index('.accessibilityIdentifier("lesson.notes.target")'))
        for forbidden in [".clipped()", ".minimumScaleFactor", ".lineLimit", ".dynamicTypeSize"]:
            self.assertNotIn(forbidden, ring)
        for token in ['CGRect(x: -89, y: 315, width: 580, height: 580)',
                      'XCTAssertFalse(Self.contains(decorationBounds',
                      'XCTAssertNil(Self.scrollDistance(decorationBounds',
                      'XCTAssertGreaterThan(target.frame.height, 290',
                      'for label in ["E", "Listening…"]',
                      'XCTAssertTrue(text.exists',
                      'Self.contains(text.frame, in: target.frame)',
                      'Self.contains(text.frame, in: notesViewport)',
                      'XCTAssertEqual(target.label, "E, String 6, open")']:
            self.assertIn(token, self.ui)

    def test_instrument_capture_requires_clear_chip_and_real_selection(self):
        instruments = (ROOT / "ios/Timbre/Instruments/InstrumentsView.swift").read_text()
        filters = instruments.split("private var filters:", 1)[1].split("private static let allFamilies", 1)[0]
        self.assertIn("family == nil ? .isSelected", filters)
        self.assertIn("family == group.id ? .isSelected", filters)
        source = (ROOT / "ios/TimbreUITests/TimbreUITests.swift").read_text()
        capture = source.split("func test17StoreInstrumentWall()", 1)[1].split("// MARK: Show me", 1)[0]
        for token in ["Self.instrumentFilterIsClear(frame, in: app.frame)",
                      'NSPredicate(format: "selected == true")', "selected && banjo.exists && banjo.isHittable",
                      '!element("instrument.01_guitar_acoustic_guitar").exists', 'storeFrame("31b-instruments-folk"']:
            self.assertIn(token, capture)
        self.assertNotIn("if onScreen(folk)", capture)
        geometry = source.split("private static func instrumentFilterIsClear", 1)[1].split('/// App Store frame #4', 1)[0]
        self.assertIn("viewport.insetBy(dx: 52, dy: 8).contains(frame)", geometry)
        self.assertIn("CGRect(x: 10, y: 200, width: 160, height: 44)", geometry)
        self.assertIn("XCTAssertFalse(Self.instrumentFilterIsClear(clippedLeft", geometry)
        self.assertIn("XCTAssertTrue(Self.instrumentFilterIsClear(CGRect(x: 52", geometry)

    def test_quiz_answer_identity_and_focus_exclude_reward_background(self):
        player = (ROOT / "ios/Timbre/Learn/LessonPlayer.swift").read_text()
        row = player.split("private func optionRow", 1)[1].split("private func feedback", 1)[0]
        identity = '.accessibilityIdentifier("lesson.option.\\(index)")'
        reward = row.index("// A right answer bursts")
        self.assertEqual(row.count(identity), 1)
        self.assertLess(row.index(identity), reward)
        self.assertLess(reward, row.index(".contentShape(.accessibility, Rectangle())"))
        self.assertIn("SparkBurst(trigger: burst", row)
        self.assertIn(".frame(width: 260, height: 260)", row)
        self.assertIn("Text(option.localized)", row)
        self.assertIn(".contentShape(Rectangle())", row)
        self.assertIn("guard picked == nil else { return }", row)
        for forbidden in [".clipped()", ".minimumScaleFactor", ".lineLimit", ".dynamicTypeSize", ".accessibilityHidden"]:
            self.assertNotIn(forbidden, row)
        for token in ['CGRect(x: -22, y: 532, width: 260, height: 260)',
                      'XCTAssertNil(Self.scrollDistance(quizDecorationBounds',
                      'XCTAssertFalse(Self.contains(quizDecorationBounds',
                      'app.buttons.matching(identifier: "lesson.option.0")',
                      'for (index, label) in ["A", "D", "B", "G"].enumerated()',
                      'matching(identifier: id).count, 1', 'XCTAssertEqual(option.label, label',
                      'scrollClear(option, above: next.frame.minY)', 'XCTAssertTrue(option.isEnabled)',
                      'scrollClear(first, above: next.frame.minY)', 'first.tap()',
                      'feedback.waitForExistence(timeout: 10)', 'XCTAssertEqual(next.label, "Continue")',
                      'XCTAssertTrue(next.isEnabled)', 'capture("quiz-correct-answer-scroll-clear")']:
            self.assertIn(token, self.ui)

    def test_controls_use_their_actual_layout_container(self):
        along = (ROOT / "ios/Timbre/Learn/Highway.swift").read_text()
        body = along.split("var body: some View {", 1)[1].split("// MARK: Pieces", 1)[0]
        content = along.split("private var stepContent: some View {", 1)[1].split("private var header:", 1)[0]
        self.assertIn("ScrollView { stepContent }", body)
        self.assertIn("controls", content)
        self.assertIn("scrollClear(start)", self.ui)
        self.assertIn("scrollClear(again)", self.ui)
        # TuneCheckStep pins its action outside AX scrolling content, unlike AlongStep.
        self.assertIn('XCTAssertTrue(isClear(skip), "Tune-check skip must be fully on screen")', self.ui)
        self.assertNotIn("scrollClear(skip)", self.ui)

    def test_tunecheck_scrolls_teaching_content_not_skip_or_audio_lifecycle(self):
        tune = SOURCE.read_text().split("struct TuneCheckStep: View {", 1)[1]
        body = tune.split("var body: some View {", 1)[1].split("// Keep the normal stack", 1)[0]
        self.assertIn("if typeSize.isAccessibilitySize", body)
        self.assertIn("VStack(spacing: 14) { teachingContent }", body)
        self.assertIn(".scrollBounceBehavior(.basedOnSize)\n                    skipBar", body)
        self.assertIn("VStack(spacing: 14) {\n                    teachingContent\n                    skipBar", body)
        for token in [".onAppear { listen(); introduce(after: 1.4) }",
                      "lockTask?.cancel(); store.stopLessonListening(owner: owner)",
                      "phase == .active && !finished && !settling"]:
            self.assertIn(token, body)
        bar = tune.split("private var skipBar:", 1)[1].split("/// VoiceOver names", 1)[0]
        self.assertIn('role: .primary, identifier: "lesson.tunecheck.skip") { finish() }', bar)
        for role in ["title", "instructions", "hint"]:
            self.assertIn('lesson.tunecheck.' + role, tune)
            self.assertIn('lesson.tunecheck.' + role, self.ui)
        self.assertIn('scrollClear(element(id), above: skip.frame.minY)', self.ui)
        self.assertIn('capture("tunecheck-arrival")', self.ui)
        self.assertNotIn('if skip.waitForExistence', self.ui)

    def test_real_playback_not_forced_result(self):
        for token in ['["TIMBRE_DEMO_PITCH"] = "1"', '["TIMBRE_SCENE_SONG"] = "gtr-1-2"',
                      "Thread.sleep(forTimeInterval: 7)", "Thread.sleep(forTimeInterval: 14)",
                      'again.waitForExistence(timeout: 30)', 'element("lesson.results.level")']:
            self.assertIn(token, self.ui)
        self.assertNotIn("performAccessibilityAudit", self.ui)


if __name__ == "__main__":
    unittest.main()
