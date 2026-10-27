"""Shards preserve selected classes and recover evidence without treating partial runs as green."""
import contextlib
import io
import json
import os
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch
import tour_evidence as evidence

ROOT = Path(__file__).resolve().parents[2]


class TourShardContracts(unittest.TestCase):
    def test_matrix_preserves_every_original_class_and_is_failure_independent(self):
        source = (ROOT / '.github/workflows/nightly.yml').read_text()
        tour = source.split('  tour:\n')[1].split('\n  archive:')[0]
        self.assertIn('fail-fast: false', tour)
        self.assertEqual(tour.count('test_class:'), 5)
        for shard, name in evidence.SHARDS.items():
            self.assertIn(f'- shard: {shard}\n            test_class: {name}', tour)
        self.assertIn('-only-testing:TimbreUITests/${{ matrix.test_class }}', tour)
        self.assertNotIn('-skip-testing', tour)
        self.assertNotIn('continue-on-error:', tour)
        self.assertIn('set -o pipefail', tour)
        self.assertIn('nightly-build-${{ github.job }}-${{ matrix.shard }}-${{ github.run_attempt }}', tour)
        self.assertLess(tour.index('Upload compact shard diagnostics'), tour.index('Export simulator screenshots'))
        self.assertLess(tour.index('Upload compact shard diagnostics'), tour.index('name: ios-tour-evidence-'))
        self.assertIn('id: tests\n', tour)
        self.assertIn('timeout-minutes: 60', tour)
        self.assertNotIn('xcodebuild archive', tour)
        self.assertIn('Missing UI result bundle; compact logs are diagnostic only', tour)
        self.assertNotIn('--output-path ci-out/screenshots || true', tour)
        self.assertEqual(source.count('xcodebuild archive '), 1)

    def test_capture_layout_and_partial_publishing_are_preserved(self):
        source = (ROOT / '.github/workflows/nightly.yml').read_text()
        self.assertIn('test_class: TimbreUITests\n            artifact: results-tour', source)
        self.assertIn('--output-path ci-out/screenshots', source)
        self.assertIn('name: results-tour\n          path: results/results-tour', source)
        self.assertIn('pattern: results-tour-*\n          path: results/results-tour/shards\n          merge-multiple: false', source)
        self.assertIn('pattern: tour-logs-*', source)
        self.assertIn('needs: [tour, archive, ipad, a11y-matrix, tsan]', source)
        self.assertIn('tour_evidence.py aggregate results/results-tour', source)
        self.assertIn('- name: Publish\n        if: always()', source)
        self.assertIn('tour:app', source)
        self.assertIn('name: ios-evidence\n          path: ios/build/Timbre.xcarchive\n          if-no-files-found: error', source)

    def test_priming_excludes_launch_and_never_substitutes_for_tests(self):
        source = (ROOT / '.github/workflows/nightly.yml').read_text()
        tour = source.split('  tour:\n')[1].split('\n  archive:')[0]
        warm = tour.split('      - name: Diagnostic simulator priming', 1)[1].split('      - name: Selected UI class', 1)[0]
        self.assertIn("if: success() && matrix.shard != 'launch'", warm)
        self.assertIn('from simulator_warmup import warmup', warm)
        self.assertIn("os.environ['DEVICE_ID'], ['en'], 'en_US', Path('ci-out/warmup')", warm)
        self.assertIn('timeout-minutes: 6', warm)
        self.assertNotIn('continue-on-error', warm)
        self.assertNotIn('GITHUB_ENV', warm)
        self.assertNotIn('SIMCTL_CHILD_', warm)
        self.assertIn('name: tour-warmup-${{ matrix.shard }}', warm)
        self.assertIn('ci-out/warmup/status.json', warm)
        self.assertIn('ci-out/warmup/*.log', warm)
        self.assertNotIn('path: ci-out/warmup\n', warm)
        self.assertNotIn('*.png', warm)
        tests = tour.split('      - name: Selected UI class', 1)[1].split('      - name: Finalize', 1)[0]
        self.assertIn("if: ${{ !cancelled() && steps.build.outcome == 'success' }}", tests)
        self.assertNotIn('steps.warmup.outcome', tests)
        self.assertIn('timeout-minutes: 60', tests)
        self.assertIn('ci-out/warmup/status.json', tour)

    def test_contract_is_selected(self):
        self.assertIn('python3 tools/ci/test_tour_shards.py', (ROOT / '.github/workflows/ios.yml').read_text())


class TourOutcomes(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.root = Path(self.temp.name)
        self.env = patch.dict(os.environ, dict(GITHUB_SHA='abc', GITHUB_RUN_ID='123', GITHUB_RUN_ATTEMPT='1',
            TOUR_JOB_OUTCOME='success', TOUR_ARCHIVE_OUTCOME='success', TOUR_BUILD_OUTCOME='success', TOUR_TEST_OUTCOME='success'))
        self.env.start()
        for shard in evidence.SHARDS:
            os.environ['TOUR_SHARD'] = shard
            evidence.record(self.full(shard))

    def tearDown(self):
        self.env.stop()
        self.temp.cleanup()

    def full(self, shard):
        return self.root if shard == 'captures' else self.root / 'shards' / ('results-tour-' + shard)

    def change(self, shard, **updates):
        path = self.full(shard) / 'outcome.json'
        row = json.loads(path.read_text()); row.update(updates); path.write_text(json.dumps(row))

    def aggregate(self):
        with contextlib.redirect_stdout(io.StringIO()):
            return evidence.aggregate(self.root)

    def test_all_same_run_successes_are_required(self):
        self.assertTrue(self.aggregate())
        self.assertTrue(json.loads((self.root / 'tour-shards.json').read_text())['complete'])

    def test_missing_full_results_cannot_be_replaced_by_compact_checkpoint(self):
        checkpoint = self.root / 'checkpoints/tour-logs-captures'
        checkpoint.mkdir(parents=True)
        (self.root / 'outcome.json').rename(checkpoint / 'outcome.json')
        self.assertFalse(self.aggregate())

    def test_wrong_revision_attempt_class_or_failed_test_rejects(self):
        for update in [dict(sha='old'), dict(run_attempt='0'), dict(test_class='Other'), dict(tests='failure'), dict(build='skipped')]:
            with self.subTest(update=update):
                self.change('song-rails', sha='abc', run_attempt='1', test_class='SongShelfRailUITests', tests='success', build='success')
                self.change('song-rails', **update)
                self.assertFalse(self.aggregate())

    def test_conflicting_or_invalid_records_fail_closed(self):
        checkpoint = self.root / 'checkpoints/tour-logs-captures'
        checkpoint.mkdir(parents=True)
        (checkpoint / 'outcome.json').write_text('{"tests": "failure"}')
        self.assertFalse(self.aggregate())
        (checkpoint / 'outcome.json').write_text('[]')
        self.assertFalse(self.aggregate())

    def test_cancelled_matrix_or_failed_archive_cannot_pass(self):
        os.environ['TOUR_JOB_OUTCOME'] = 'cancelled'
        self.assertFalse(self.aggregate())
        os.environ['TOUR_JOB_OUTCOME'] = 'success'; os.environ['TOUR_ARCHIVE_OUTCOME'] = 'failure'
        self.assertFalse(self.aggregate())

if __name__ == '__main__':
    unittest.main()
