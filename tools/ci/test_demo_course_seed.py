from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[2]

class DemoCourseSeedTests(unittest.TestCase):
    def test_seed_includes_course_after_empty_guard_and_is_debug_only(self):
        source = (ROOT / 'ios/Timbre/Support/DemoData.swift').read_text()
        self.assertLess(source.index('#if DEBUG'), source.index('enum DemoData'))
        reset = source.index('Preferences.learnCourse = Preferences.defaultLearnCourse')
        self.assertLess(source.index('guard store.records.isEmpty else { return }'), reset)
        self.assertLess(reset, source.index('var learn = LearnProgress()'))
        self.assertTrue(source.rstrip().endswith('#endif'))

    def test_app_still_seeds_only_requested_empty_demo_store(self):
        source = (ROOT / 'ios/Timbre/TimbreApp.swift').read_text()
        self.assertIn('if TestSupport.isOn(.demoData), store.records.isEmpty { DemoData.seed(store) }', source)
        seed = source.index('DemoData.seed(store)')
        self.assertGreater(source.rfind('#if DEBUG', 0, seed), source.rfind('#endif', 0, seed))

if __name__ == '__main__':
    unittest.main()
