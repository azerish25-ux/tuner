"""Late optional tune-check source guards; actual iOS execution remains a separate required check."""
from datetime import datetime, timedelta
from pathlib import Path
import re
import unittest

ROOT = Path(__file__).resolve().parents[2]


class PlayAlongReadinessContracts(unittest.TestCase):
    def setUp(self):
        self.tour = (ROOT / 'ios/TimbreUITests/TimbreUITests.swift').read_text()
        self.capture = self.tour.split('func test10PlayAlongLesson()', 1)[1].split('private func waitForPlayAlongReady()', 1)[0]
        self.helper = self.tour.split('private func waitForPlayAlongReady()', 1)[1].split('private func playAlongReadinessFailed(', 1)[0]
        self.policy = (ROOT / 'ios/TimbreUITests/CapturePlayAlongReadiness.swift').read_text()

    def test_recovered_event_crosses_day_boundary_and_real_source_uses_today(self):
        start = datetime.fromisoformat('2026-10-27T23:57:58.598')
        self.assertEqual((start + timedelta(seconds=104.61)).date(), start.date())
        self.assertGreater((start + timedelta(seconds=124.88)).date(), start.date())
        steps = (ROOT / 'ios/Timbre/Learn/LessonSteps.swift').read_text()
        needed = steps.split('static func needed(for course: LearnCourse)', 1)[1].split('var body:', 1)[0]
        self.assertIn('Quests.dayKey(Date())', needed)
        player = (ROOT / 'ios/Timbre/Learn/LessonPlayer.swift').read_text()
        self.assertIn('step.usesMicrophone, !tuneChecked, TuneCheckStep.needed(for: course)', player)

    def test_ready_capture_and_start_are_after_positive_stage_verification(self):
        guard = self.capture.index('guard waitForPlayAlongReady() else { return }')
        shot = self.capture.index('shot("59-along-ready")')
        start = self.capture.index('element("lesson.continue").tap(); settle(7)')
        self.assertLess(guard, shot)
        self.assertLess(shot, start)
        self.assertIn('viewport.contains($0.frame)', self.helper)
        self.assertIn('!$0.frame.isEmpty', self.helper)
        self.assertIn('CaptureLocalization.lessonButtonLabel("Start")', self.helper)
        self.assertIn('element("lesson.continue").isHittable', self.helper)

    def test_only_recognized_check_gets_bounded_quiet_time_without_taps_or_state_changes(self):
        self.assertIn('for observation in 0...3', self.helper)
        self.assertIn('guard observation < 3 else { break }', self.helper)
        tune = self.helper.split('case .tuneCheck:', 1)[1].split('case .unexpected:', 1)[0]
        self.assertIn('settle(10)', tune)
        self.assertIn('shot("playalong-optional-tunecheck-', tune)
        for forbidden in ['.tap()', 'tapIfPresent(', 'UserDefaults', 'launchEnvironment', 'tuneChecked =', 'waitForExistence']:
            self.assertNotIn(forbidden, self.helper)
        self.assertIn('settle(1.5)', self.helper.split('case .unexpected:', 1)[1])

    def test_policy_requires_both_check_markers_or_real_enabled_localized_start_and_tempo(self):
        for token in ['identifiers.contains("lesson.tunecheck.title")', 'skip.count == 1', 'skip[0].enabled',
                      'primary.isEmpty, along.isEmpty', 'primary.count == 1', 'primary[0].label == startLabel',
                      'primary[0].enabled', '$0.identifier == "along.tempo.0" && $0.enabled',
                      '!identifiers.contains("along.again")', '!identifiers.contains("lesson.notes.target")',
                      '$0.hasPrefix("lesson.option.")']:
            self.assertIn(token, self.policy)
        self.assertIn('return .unexpected', self.policy)

    def test_failure_keeps_diagnostics_and_never_valid_capture_name(self):
        failure = self.tour.split('private func playAlongReadinessFailed(', 1)[1].split('\n    ///', 1)[0]
        for token in ['XCTFail(message)', 'shot("59-along-ready-wrong")', 'XCTAttachment(string: app.debugDescription)',
                      'hierarchy.lifetime = .keepAlways', 'return false']:
            self.assertIn(token, failure)
        self.assertNotIn('shot("59-along-ready")', failure)

    def test_original_frames_playback_window_and_real_results_assertions_remain(self):
        for name in ['63-songs', '64-songs-lesson', '56-lesson-notes', '57-lesson-quiz', '58-lesson-listen',
                     '59-along-ready', '60-along-playing', '61-along-done', '62-lesson-results']:
            self.assertIn('"' + name + '"', self.capture)
        quiet = self.capture.split('element("lesson.continue").tap(); settle(7)', 1)[1].split('XCTAssertTrue', 1)[0]
        executable = '\n'.join(line for line in quiet.splitlines() if not line.strip().startswith('//'))
        self.assertIn('settle(14)', executable)
        for query in ['element(', '.exists', '.snapshot(', '.waitForExistence(']:
            self.assertNotIn(query, executable)
        for token in ['element("along.again").waitForExistence(timeout: 30)', 'guard openResultsForCapture() else { return }',
                      'lesson.results.stars.3', 'headline && room.fits']:
            self.assertIn(token, self.capture)

    def test_native_regressions_and_contract_are_selected_by_gate(self):
        workflow = (ROOT / '.github/workflows/ios.yml').read_text()
        self.assertIn('python3 tools/ci/test_playalong_readiness_contract.py', workflow)
        self.assertIn('-only-testing:TimbreUITests/CapturePlayAlongReadinessTests', workflow)
        native = (ROOT / 'ios/TimbreUITests/CapturePlayAlongReadinessTests.swift').read_text()
        self.assertEqual(len(re.findall(r'func test\w+\(', native)), 6)
        for token in ['testLateTuneCheckMustCompleteBeforeReadyCapture', 'testPartialMixedAndDisabledCheck',
                      'testContinuePlayingDoneAndQuestionStates', 'testMissingDisabledOrDuplicateControls',
                      'testStartMustMatchTheRequestedLocaleWithoutEnglishFallback']:
            self.assertIn(token, native)


if __name__ == '__main__':
    unittest.main()
