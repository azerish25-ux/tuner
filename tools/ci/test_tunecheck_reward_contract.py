"""Bounded decoration guard; native mask pixels and short-screen layout still require iOS."""
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[2]


class TuneCheckRewardContract(unittest.TestCase):
    def setUp(self):
        self.tune = (ROOT / 'ios/Timbre/Learn/LessonSteps.swift').read_text().split('struct TuneCheckStep: View {', 1)[1].split('final class TuneCheckVoice', 1)[0]
        self.row = self.tune.split('private var stringChips:', 1)[1].split('private func stringChip(', 1)[0]

    def test_only_decoration_is_masked_before_its_existing_offset(self):
        reward = self.row.split('.background(alignment: .leading)', 1)[1].split('// Strings lie in space', 1)[0]
        self.assertIn('SparkBurst(trigger: burst, color: accent, reach: 70, startFraction: 0.32, ring: false)', reward)
        self.assertLess(reward.index('.frame(width: 140, height: 140)'), reward.index('.mask { Self.chipRewardMask }'))
        self.assertLess(reward.index('.mask { Self.chipRewardMask }'), reward.index('.offset(x: CGFloat(burstAt)'))
        self.assertLess(reward.index('.offset(x: CGFloat(burstAt)'), reward.index('.padding(.vertical, Self.chipRewardFade)'))
        self.assertEqual(self.tune.count('.mask {'), 1)
        self.assertNotIn('.clipped()', self.tune)
        self.assertNotIn('.scaleEffect', self.row)

    def test_stable_space_matches_the_actual_faded_mask(self):
        for token in ['private static let chip: CGFloat = 44', 'static let chipRewardFade: CGFloat = 8',
                      'chip + 2 * chipRewardFade', 'chipRewardFade / chipRewardHeight',
                      '.init(color: .clear, location: 0)', '.init(color: .white, location: edge)',
                      '.init(color: .white, location: 1 - edge)', '.init(color: .clear, location: 1)',
                      '.frame(height: chipRewardHeight)']:
            self.assertIn(token, self.row)
        self.assertEqual(self.row.count('.padding(.vertical, Self.chipRewardFade)'), 1)
        self.assertNotIn('if burst', self.row)
        self.assertNotIn('if settling', self.row)
        self.assertIn('.environment(\\.layoutDirection, .leftToRight)', self.row)

    def test_native_pixel_guard_has_opaque_negative_control_and_real_edge_checks(self):
        native = (ROOT / 'ios/TimbreAppTests/TuneCheckRewardBandTests.swift').read_text()
        for token in ['for scale in [2, 3]', 'LayoutDirection.leftToRight, .rightToLeft',
                      'DynamicTypeSize.large, .accessibility5', 'Color.red.frame(width: 140, height: 140)',
                      'content.mask { TuneCheckStep.chipRewardMask }', 'if y < start || y >= end',
                      'XCTAssertEqual(escapedInk, 0', 'XCTAssertGreaterThan(insideInk, 0',
                      'XCTAssertEqual(actual, baseline)', 'XCTAssertEqual(unmasked[3], 255',
                      'XCTAssertNotEqual(unmasked, try XCTUnwrap(baseline))', 'renderer.isOpaque = false']:
            self.assertIn(token, native)

    def test_text_primary_orb_and_audio_lifecycle_are_not_changed_or_masked(self):
        header = self.tune.split('@ViewBuilder private var teachingContent:', 1)[1].split('stringChips', 1)[0]
        self.assertIn('Pluck each open string. In-tune strings help Timbre hear you right.', header)
        self.assertIn('.fixedSize(horizontal: false, vertical: true)', header)
        self.assertNotIn('.mask', header)
        cluster = self.tune.split('private var listeningCluster:', 1)[1].split('private enum Reading:', 1)[0]
        self.assertIn('RingMotif(accent: orbColor, symbol: orbSymbol, active: reading.listening)', cluster)
        self.assertNotIn('.mask', cluster)
        for token in ['.onAppear { listen(); introduce(after: 1.4) }',
                      '.onDisappear { lockTask?.cancel(); store.stopLessonListening(owner: owner) }',
                      'if typeSize.isAccessibilitySize', 'ScrollView {',
                      'identifier: "lesson.tunecheck.skip") { finish() }']:
            self.assertIn(token, self.tune)

    def test_whole_app_compact_matrix_uses_real_navigation_and_all_eight_cases(self):
        native = (ROOT / 'ios/TimbreUITests/TuneCheckLayoutUITests.swift').read_text()
        for language in ['English', 'Arabic']:
            for orientation in ['Portrait', 'Landscape']:
                for size in ['Large', 'AX5']:
                    self.assertIn('func test' + language + orientation + size + '()', native)
        for token in ['element("tune.stage")', 'element("learn.lesson.gtr-1-2")',
                      'element("lesson.continue")', 'next.tap()',
                      'element("lesson.tunecheck.skip")', 'skip.tap()',
                      'element("lesson.notes.target")',
                      'CGSize(width: 375, height: 667)', 'CGSize(width: 667, height: 375)',
                      'XCUIDevice.shared.orientation = .landscapeLeft',
                      'self.screen.size == expectedSize',
                      '"-tunecheck.guitar.acoustic.6", "1900-01-01"']:
            self.assertIn(token, native)
        for forbidden in ['XCTSkip', 'ImageRenderer', 'UIHostingController', '.resizable()',
                          'TIMBRE_DEMO_PITCH', 'TIMBRE_SCENE', 'if skip.waitForExistence']:
            self.assertNotIn(forbidden, native)

    def test_whole_app_targets_are_contained_not_merely_tappable_and_failures_keep_evidence(self):
        native = (ROOT / 'ios/TimbreUITests/TuneCheckLayoutUITests.swift').read_text()
        for token in ['chips.count == 6', 'rail[0].isSelected', 'notes.count == 1', 'boards.count == 1',
                      'target.label == expected', 'close.frame.midX > header.frame.midX',
                      'Self.contains(chip.frame, in: viewport(scroll)) && chip.isHittable',
                      'skip.frame == pinnedSkip && close.frame == pinnedClose',
                      'frame.height <= room.height', 'frame.minX >= room.minX && frame.maxX <= room.maxX',
                      'frame.minY >= viewport.minY && frame.maxY <= viewport.maxY',
                      'stalled < 2', 'room.midX', 'for attempt in 0..<12',
                      'railTop - 8 >= instructions.frame.maxY + 14',
                      'railBottom + 8 + 14 <= note.frame.minY',
                      'XCTAttachment(screenshot: screenshot)', 'app.debugDescription',
                      '"screenshotPixels"', '"launchArguments"', '"observations"',
                      'capture("arrival")', 'capture("clear-" + name)', 'capture("skip-activated")']:
            self.assertIn(token, native)
        failure = native.split('private func require(', 1)[1].split('private func exercise(', 1)[0]
        self.assertLess(failure.index('capture("failure")'), failure.index('throw Failure'))
        self.assertNotIn('try?', failure)

    def test_arabic_fixture_copy_is_the_current_shipped_translation(self):
        native = (ROOT / 'ios/TimbreUITests/TuneCheckLayoutUITests.swift').read_text()
        local = (ROOT / 'ios/Timbre/Resources/ar.lproj/Localizable.strings').read_text()
        learn = (ROOT / 'ios/Timbre/Resources/ar.lproj/Learn.strings').read_text()
        for translated in ['تعلّم', 'ضبط الآلة', 'فحص سريع للضبط',
                           'انقر كل وتر مفتوح. الأوتار المضبوطة تساعد Timbre على سماعك بدقة.',
                           'انقر الوتر', 'أوتاري مضبوطة — تخطٍّ']:
            self.assertIn('"' + translated + '"', native)
            self.assertIn('= "' + translated + '";', local)
        self.assertIn('lesson: "الأوتار المطلقة"', native)
        self.assertIn('"Lf608c3d2a6" = "الأوتار المطلقة";', learn)


if __name__ == '__main__':
    unittest.main()
