"""Hands-off chord-demo timing guard; native identity and painted-frame checks are still required."""
import json
import pathlib
import re
import unittest

ROOT = pathlib.Path(__file__).resolve().parents[2]


class LessonTurnCueContract(unittest.TestCase):
    def setUp(self):
        self.explain = (ROOT / 'ios/Timbre/Learn/LessonExplain.swift').read_text()
        self.show_me = (ROOT / 'ios/Timbre/Learn/ShowMe.swift').read_text()
        tour = (ROOT / 'ios/TimbreUITests/TimbreUITests.swift').read_text()
        self.test = tour.split('func test09LearnChordLesson()', 1)[1].split('\n    func ', 1)[0]

    def test_quiet_window_covers_real_em_demonstration_paths(self):
        curriculum = json.loads((ROOT / 'ios/Sources/TimbreCore/Resources/curriculum.json').read_text())
        lesson = next(lesson for course in curriculum['courses'] for unit in course['units']
                      for lesson in unit['lessons'] if lesson['id'] == 'gtr-1-4')
        chord = lesson['steps'][0]['visual']['chord']
        self.assertEqual(chord['frets'], [0, 2, 2, 0, 0, 0])
        fingers = {finger for finger, fret in zip(chord['fingers'], chord['frets']) if fret > 0 and finger > 0}
        self.assertEqual(len(fingers), 2)
        def constant(source, name):
            return float(re.search(r'static let ' + name + r' = ([\d.]+)', source)[1])
        settle = constant(self.show_me, 'settle')
        patience = constant(self.show_me, 'patience')
        lead = constant(self.show_me, 'lead')
        step = constant(self.explain, 'demoStep')
        tail = float(re.search(r'start \+ \.seconds\(ringAt \+ ([\d.]+)\)\)\n            guard !Task.isCancelled else \{ return \}\n            sounding = false', self.explain)[1])
        opening = self.test.split('element("learn.continue").tap()', 1)[1]
        quiet = float(re.search(r'\n        settle\(([\d.]+)\)', opening)[1])
        self.assertGreaterEqual(quiet, settle + patience + lead + len(fingers) * step + tail)
        self.assertLessEqual(quiet, 12, 'Keep this a bounded demonstration window, not an arbitrary timeout increase')

    def test_no_accessibility_query_interrupts_quiet_window(self):
        opening = self.test.split('element("learn.continue").tap()', 1)[1]
        before = opening.split('settle(10)', 1)[0]
        executable = '\n'.join(line for line in before.splitlines() if not line.strip().startswith('//'))
        for query in ['element(', '.exists', '.snapshot(', '.waitForExistence(', '.debugDescription']:
            self.assertNotIn(query, executable)
        self.assertIn('let turnCue = element("lesson.explain.turnCue")', opening)
        self.assertIn('turnCue.waitForExistence(timeout: 12)', opening)
        self.assertIn('contains(turnCue.label)', opening)
        self.assertNotIn('staticTexts["Your turn', opening)

    def test_only_real_visible_cue_branches_carry_identity(self):
        teacher = self.explain.split('private var teacherLine: some View {', 1)[1].split('private var caption:', 1)[0]
        fallback = self.explain.split('private var yourTurn: some View {', 1)[1].split('private func turnCue(', 1)[0]
        for branch in [teacher, fallback]:
            self.assertIn('if cueShown', branch)
            self.assertIn('.accessibilityIdentifier("lesson.explain.turnCue")', branch)
        self.assertIn('turnCue(compact: false).hidden()', fallback)
        self.assertNotIn('turnCue(compact: false).hidden()\n                    .accessibilityIdentifier', fallback)


if __name__ == '__main__':
    unittest.main()
