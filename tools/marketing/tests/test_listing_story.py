"""The broad-instrument listing story stays consistent across native phone roles/locales."""
from pathlib import Path
import json
import sys
import unittest

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import screenshots

ORDER = [
    '10b-tune-locked', '31b-instruments-folk', '65-song-perform',
    '63-songs', '50-learn', '52b-lesson-chord',
    '62-lesson-results', '11b-tune-strum', '32-journey',
]


class ListingStoryTests(unittest.TestCase):
    def test_first_three_show_tuning_breadth_and_playing_not_only_guitar(self):
        self.assertEqual([row[0] for row in screenshots.plan('iphone')], ORDER)
        self.assertEqual([row[0] for row in screenshots.plan('iphone-large')], ORDER)

    def test_all_fifty_payloads_preserve_caption_capture_pairs_on_both_phone_roles(self):
        paths = sorted((screenshots.ROOT / 'tools/l10n/store').glob('*.json'))
        self.assertEqual(len(paths), 50)
        for path in paths:
            data = json.loads(path.read_text())
            rows = data['iphone_screenshot_captions']
            with self.subTest(locale=data['locale']):
                self.assertEqual([row['capture'] for row in rows], ORDER)
                self.assertEqual(len({row['capture'] for row in rows}), len(ORDER))
                pairs = {row['capture']: (row['caption'], row['supporting_line']) for row in rows}
                for role in ('iphone', 'iphone-large'):
                    rendered_plan = screenshots.plan(role, locale=data['locale'])
                    self.assertEqual([row[0] for row in rendered_plan], ORDER)
                    for capture, caption, supporting, _ in rendered_plan:
                        self.assertEqual((caption, supporting), pairs[capture])


if __name__ == '__main__':
    unittest.main()
