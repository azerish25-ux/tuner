"""Marketing counts use the production distinct-tune definition, not title variants."""
import json
import re
from pathlib import Path
import sys
import unittest
sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import screenshots


class SongCountTests(unittest.TestCase):
    def test_production_alias_and_exercise_examples(self):
        groups = {
            'greensleeves': ['Greensleeves', 'Greensleeves: the chords', 'Greensleeves: the melody'],
            'amazinggrace': ['Amazing Grace', 'Amazing Grace, fingerpicked'],
            'odetojoy': ['Ode to Joy', 'Ode to Joy on bass'],
            'twinkletwinklelittlestar': ['Twinkle Twinkle Little Star', 'Twinkle, Twinkle, Little Star'],
            'frèrejacques': ['Frère Jacques (round)', 'Frère Jacques（round）', 'Frère Jacques：round'],
        }
        for expected, titles in groups.items():
            for title in titles:
                with self.subTest(title=title): self.assertEqual(screenshots.counted_tune(title), expected)
        for title in ('Your arrangement', 'Walking the blues in A', '!!!', ''):
            self.assertIsNone(screenshots.counted_tune(title))

    def test_production_rule_inventory_matches_port(self):
        swift = (screenshots.ROOT/'ios/Sources/TimbreCore/Learn/SongOfTheDay.swift').read_text()
        exercise_line = re.search(r'public static let exercises: Set<String> = \[(.*?)\]', swift).group(1)
        treatments = re.search(r'for treatment in \[(.*?)\] where', swift).group(1)
        self.assertEqual(set(re.findall(r'"([^"]+)"', exercise_line)),
                         {'yourarrangement', 'walkingthebluesina'})
        self.assertEqual(re.findall(r'"([^"]+)"', treatments), [', fingerpicked', ' on bass'])
        # The native regression fixture also requires these normalized keys.
        native_test = (screenshots.ROOT/'ios/Tests/TimbreCoreTests/CurriculumIndexTests.swift').read_text()
        self.assertIn('["greensleeves", "amazinggrace", "odetojoy", "twinkletwinklelittlestar"]', native_test)

    def test_swift_split_omits_empty_components_but_keeps_whitespace(self):
        self.assertEqual(screenshots.counted_tune(':Ode to Joy'), 'odetojoy')
        self.assertIsNone(screenshots.counted_tune(' :Ode to Joy'))

    def test_bundled_tunes_not_arrangements_or_title_variants(self):
        courses = json.loads(screenshots.CURRICULUM.read_text())['courses']
        songs = [l for c in courses for u in c['units'] for l in u['lessons'] if l.get('kind') == 'song']
        self.assertEqual(len({l['id'] for l in songs}), 616)
        self.assertEqual(sum('arrangement' in l for l in songs), 615)
        self.assertEqual(len({l['title']['t'].strip().lower() for l in songs}), 146)
        counts = screenshots.build_counts()
        self.assertEqual(counts['songs'], 135)
        self.assertEqual(counts['songs_floor'], 130)
        self.assertEqual(counts['originals'], 50)

    def test_stale_marketing_claims_are_rejected(self):
        counts = screenshots.build_counts()
        self.assertTrue(screenshots.count_problems('140+ songs', counts, 'fixture'))
        self.assertTrue(screenshots.count_problems('146 songs', counts, 'fixture'))
        self.assertEqual(screenshots.count_problems('130+ songs', counts, 'fixture'), [])
        self.assertEqual(screenshots.count_problems('135 songs', counts, 'fixture'), [])

    def test_source_claim_snapshot_uses_correct_floor(self):
        source = json.loads((screenshots.ROOT/'tools/l10n/store/en-US.json').read_text())
        self.assertEqual(source['counts']['songs_floor'], screenshots.build_counts()['songs_floor'])
        self.assertIn('130+ songs', source['description'])
        self.assertNotIn('140+', source['description'])


if __name__ == '__main__': unittest.main()
