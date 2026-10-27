#!/usr/bin/env python3
"""Source guards; native renders/captures remain required for visual acceptance."""
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[2]


class ResultPolishContractTests(unittest.TestCase):
    def test_week_stat_wraps_at_normal_font_instead_of_shrinking_or_ellipsizing(self):
        source = (ROOT / 'ios/Timbre/Journey/WeekRecap.swift').read_text()
        stat = source.split('struct WeekStat: View {', 1)[1].split('@ViewBuilder private var icon', 1)[0]
        label = stat.split('label.font(.caption)', 1)[1].split('\n            }', 1)[0]
        self.assertIn('.fixedSize(horizontal: false, vertical: true)', label)
        self.assertNotIn('.lineLimit(1)', label)
        self.assertNotIn('.minimumScaleFactor', label)
        self.assertIn('HStackLayout(alignment: .top, spacing: 6)', source)
        self.assertIn('typeSize.isAccessibilitySize', source)

    def test_expired_burst_clears_even_when_timeline_retains_old_date(self):
        source = (ROOT / 'ios/Timbre/Design/SparkBurst.swift').read_text()
        self.assertIn('if live { draw(&context, size: size, t: t) }', source)
        self.assertIn('if started == launched { live = false }', source)
        self.assertIn('guard t >= 0, t < Self.duration else { return }', source)

    def test_capture_waits_for_reveal_without_replacing_real_results_checks(self):
        source = (ROOT / 'ios/Timbre/Learn/LessonResults.swift').read_text()
        task = source.split('.task {', 1)[1].split('.overlay(alignment:', 1)[0]
        self.assertLess(task.index('captureSettled = false'), task.index('await reveal()'))
        self.assertLess(task.index('await reveal()'), task.index('captureSettled = true'))
        self.assertIn('SparkBurst.duration + 0.1', task)
        self.assertIn('#if DEBUG', task)
        self.assertIn('captureSettled && celebrating == nil', source)
        ui = (ROOT / 'ios/TimbreUITests/TimbreUITests.swift').read_text()
        helper = ui.split('private func openResultsForCapture()', 1)[1].split('func testCaptureLocalization', 1)[0]
        self.assertEqual(helper.count('return waitForSettledResults()'), 2)
        self.assertIn('waitSparingly(for: element("lesson.results.settled"), timeout: 20)', helper)
        self.assertIn('headline && room.fits', ui)
        self.assertIn('lesson.results.stars.3', ui)


if __name__ == '__main__':
    unittest.main()
