"""Bounded test-driver guardrails; not a substitute for native reachability."""
import math
import pathlib
import unittest

ROOT = pathlib.Path(__file__).resolve().parents[2]
UI = ROOT / "ios/TimbreUITests/LessonAccessibilityLayoutUITests.swift"


def valid(rect):
    return all(math.isfinite(v) for v in rect) and rect[2] > 0 and rect[3] > 0


def contains(rect, viewport):
    x, y, w, h = rect
    vx, vy, vw, vh = viewport
    return (valid(rect) and valid(viewport) and x >= vx and y >= vy
            and x + w <= vx + vw and y + h <= vy + vh)


def discovery_distance(frame, old, current):
    if (not contains(frame, old) or not valid(current) or current[:3] != old[:3]
            or current[3] >= old[3] or frame[1] < current[1] + current[3]):
        return None
    return -min(120, current[3] * .35)


class QuizRediscoveryContract(unittest.TestCase):
    def setUp(self):
        self.ui = UI.read_text()
        self.helper = self.ui.split("private func rediscoverSelectedFirstQuizOption", 1)[1].split(
            "func testQuizRediscoveryRequires", 1)[0]

    def test_actual_failure_geometry_only_plans_a_search(self):
        old = (0, 116, 402, 651.3333333333334)
        new = (0, 116, 402, 427.7)
        target = (20, 577.3333333333333, 176, 84.00000000000011)
        distance = discovery_distance(target, old, new)
        self.assertEqual(distance, -120)
        self.assertFalse(contains(target, new))
        self.assertGreater(new[1] + new[3] / 2 + distance, new[1])
        self.assertLess(new[1] + new[3] / 2, new[1] + new[3])
        self.assertIn("testQuizRediscoveryRequiresPreviouslyClearTargetAndShrunkenViewport", self.ui)

    def test_stale_or_unobserved_geometry_cannot_plan(self):
        old = (0, 116, 402, 651.3333333333334)
        new = (0, 116, 402, 427.7)
        target = (20, 577.3333333333333, 176, 84.00000000000011)
        for invalid in [old, (1, 116, 402, 427.7), (0, 117, 402, 427.7),
                        (0, 116, 401, 427.7), (0, 116, 402, 0), (0, 116, 402, math.inf)]:
            with self.subTest(viewport=invalid):
                self.assertIsNone(discovery_distance(target, old, invalid))
        for invalid in [(20, 120, 176, 84), (-1, 577, 176, 84), (20, 740, 176, 84),
                        (20, 577, 176, 0), (20, math.nan, 176, 84)]:
            with self.subTest(target=invalid):
                self.assertIsNone(discovery_distance(invalid, old, new))

    def test_only_previously_seen_same_step_can_be_searched(self):
        for token in ['header.label == "The open strings"', '(header.value as? String) == "Step 4 of 6"',
                      '"What is string 5 called?"', '"Nice — that’s right."',
                      'next.identifier == "lesson.continue"', 'next.label == "Continue"',
                      'scroll.staticTexts.matching(promptPredicate).count == 1',
                      'matchingScrolls.count == 1', 'guard sameStep()',
                      'first.identifier == "lesson.option.0"', 'first.elementType == .button',
                      'scroll.buttons.matching(identifier: "lesson.option.0").count == 1',
                      'first.staticTexts.matching(NSPredicate(format: "label == %@", "A")).count == 1']:
            self.assertIn(token, self.helper)
        callsite = self.ui.split("private func assertQuizOptionsReachableAndSelectable", 1)[1]
        self.assertLess(callsite.index("let previousFrame = first.frame"), callsite.index("first.tap()"))
        self.assertLess(callsite.index('XCTAssertEqual(first.label, "A")'), callsite.index("first.tap()"))
        self.assertLess(callsite.index("feedback.waitForExistence"), callsite.index("rediscoverSelectedFirstQuizOption"))

    def test_missing_target_is_not_a_success_and_search_stops_on_no_progress(self):
        for token in ["for attempt in 0..<4", "guard !first.exists else", "if exactAnswerExists()",
                      "before.minY - after.minY >= 1", "contentViewport(scroll, above: next.frame.minY) == viewport",
                      "Self.valid(after)", 'XCTFail("Previously observed lesson.option.0']:
            self.assertIn(token, self.helper)
        self.assertNotIn("if !first.exists { return", self.helper)
        self.assertNotIn("swipeUp", self.helper)
        self.assertNotIn(".tap()", self.helper)
        self.assertNotIn("Thread.sleep", self.helper)
        self.assertIn("viewport.midY + distance", self.helper)
        self.assertIn("viewport.minX + min(12, viewport.width * 0.1)", self.helper)

    def test_final_current_bounds_hittability_and_complete_text_remain_required(self):
        callsite = self.ui.split("private func assertQuizOptionsReachableAndSelectable", 1)[1]
        self.assertLess(callsite.index("rediscoverSelectedFirstQuizOption"),
                        callsite.index("scrollClear(first, above: next.frame.minY, in: quizScroll)"))
        for token in ['matching(identifier: "lesson.option.0").count, 1',
                      'XCTAssertEqual(first.elementType, .button)', 'XCTAssertTrue(first.isEnabled)',
                      'Self.contains(answerText.firstMatch.frame, in: first.frame)',
                      'Self.contains(answerText.firstMatch.frame, in: contentViewport(quizScroll']:
            self.assertIn(token, callsite)
        self.assertIn("if contained && hittable { return }", self.ui)
        self.assertIn("frame.maxY <= viewport.maxY", self.ui)
        self.assertIn("isClear(target, within: contentViewport(scroll, above: bottom))", self.ui)

    def test_trace_attached_before_failure_not_only_in_defer(self):
        normal = self.ui.split("private func scrollClear", 1)[1].split("private static func quizRediscoveryDistance", 1)[0]
        self.assertIn('attachTrace()\n        capture("unreachable")\n        XCTAssertTrue', normal)
        self.assertIn('attachTrace()\n        capture("quiz-post-feedback-rediscovery-failed")\n        XCTFail', self.helper)
        self.assertIn('capture("quiz-post-feedback-before-rediscovery")', self.helper)
        self.assertIn("TIMBRE_QUIZ_REDISCOVERY", self.helper)


if __name__ == "__main__":
    unittest.main()
