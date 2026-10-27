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
                      'element("lesson.option.\\(index)")', 'scrollClear(explanation']:
            self.assertIn(token, self.ui)

    def test_scroll_geometry_excludes_header_and_moves_both_directions(self):
        for token in ["scroll.frame.intersection(app.frame)", "clearBottom - visible.minY",
                      "target.frame.minY < viewport.minY", "scroll.swipeDown(velocity: .slow)",
                      "scroll.swipeUp(velocity: .slow)", "for _ in 0..<12",
                      'capture("unreachable")', "isClear(target, within: contentViewport(scroll, above: bottom))"]:
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
