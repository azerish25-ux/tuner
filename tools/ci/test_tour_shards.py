"""Shards preserve selected classes and recover evidence without treating partial runs as green."""
import ast
import contextlib
import glob
import io
import json
import os
import re
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch
import tour_evidence as evidence

ROOT = Path(__file__).resolve().parents[2]


def job_blocks(source):
    """Read only this workflow's fixed two-space job mapping; actionlint validates YAML."""
    jobs = source.split('\njobs:\n', 1)[1]
    starts = list(re.finditer(r'^  ([a-zA-Z0-9_-]+):\n', jobs, re.M))
    return {match.group(1): jobs[match.end():starts[i + 1].start() if i + 1 < len(starts) else len(jobs)]
            for i, match in enumerate(starts)}


def job_field(block, name):
    match = re.search(r'^    ' + re.escape(name) + r': (.+)$', block, re.M)
    if not match:
        return None
    value = match.group(1)
    if value == '>-':
        lines = []
        for line in block[match.end() + 1:].splitlines():
            if not line.startswith('      '): break
            lines.append(line.strip())
        return ' '.join(lines)
    return value


def job_needs(block):
    value = job_field(block, 'needs')
    if value is None: return []
    return [item.strip() for item in value.strip('[]').split(',')]


def condition_value(expression, event, labels, cancelled, predecessor):
    """Evaluate the restricted actual job expression, including Actions' implicit success rule.

    This is a regression model, not a substitute for executing GitHub's scheduler.
    """
    explicit_status = re.search(r'\b(always|success|failure|cancelled)\(', expression)
    expression = re.sub(r"contains\(github\.event\.pull_request\.labels\.\*\.name, '([^']+)'\)",
                        lambda match: str(match.group(1).lower() in {label.lower() for label in labels}), expression)
    expression = expression.replace('github.event_name', repr(event))
    for name, value in [('always()', True), ('cancelled()', cancelled),
                        ('success()', predecessor == 'success'), ('failure()', predecessor == 'failure')]:
        expression = expression.replace(name, str(value))
    expression = expression.replace('&&', ' and ').replace('||', ' or ')
    expression = re.sub(r'!(?!=)', ' not ', expression).strip()
    tree = ast.parse(expression, mode='eval')
    allowed = (ast.Expression, ast.BoolOp, ast.And, ast.Or, ast.UnaryOp, ast.Not,
               ast.Compare, ast.Eq, ast.NotEq, ast.Constant)
    if any(not isinstance(node, allowed) for node in ast.walk(tree)):
        raise ValueError('Unexpected workflow-condition syntax')
    result = bool(eval(compile(tree, '<workflow condition>', 'eval'), {'__builtins__': {}}, {}))
    return result and (bool(explicit_status) or predecessor == 'success')


class NightlySchedulingContracts(unittest.TestCase):
    delayed = ('archive', 'ipad', 'a11y-matrix', 'tsan')

    def setUp(self):
        self.source = (ROOT / '.github/workflows/nightly.yml').read_text()
        self.jobs = job_blocks(self.source)

    def test_only_independent_jobs_wait_for_producer_terminal_not_for_other_consumers(self):
        self.assertEqual(job_needs(self.jobs['tour-build']), [])
        self.assertEqual(job_needs(self.jobs['tour']), ['tour-build'])
        for name in self.delayed:
            with self.subTest(job=name):
                self.assertEqual(job_needs(self.jobs[name]), ['tour-build'])
                self.assertNotIn('actions/download-artifact@', self.jobs[name])
        self.assertEqual(set(job_needs(self.jobs['publish'])), set(self.jobs) - {'publish'})

    def test_original_trigger_eligibility_survives_success_failure_and_skip(self):
        for name in self.delayed:
            expression = job_field(self.jobs[name], 'if')
            self.assertTrue(expression.startswith('always() && !cancelled() && ('))
            for event in ['schedule', 'workflow_dispatch', 'pull_request']:
                for labels in [[], ['captures'], ['accessibility'], ['captures', 'accessibility'], ['unrelated']]:
                    expected = event != 'pull_request' or 'captures' in labels or (name == 'a11y-matrix' and 'accessibility' in labels)
                    for predecessor in ['success', 'failure', 'skipped']:
                        with self.subTest(job=name, event=event, labels=labels, predecessor=predecessor):
                            self.assertEqual(condition_value(expression, event, labels, False, predecessor), expected)

    def test_explicit_workflow_cancellation_blocks_all_four_regardless_of_trigger_or_parent_result(self):
        for name in self.delayed:
            expression = job_field(self.jobs[name], 'if')
            for predecessor in ['success', 'failure', 'skipped', 'cancelled']:
                for event in ['schedule', 'workflow_dispatch', 'pull_request']:
                    self.assertFalse(condition_value(expression, event, ['captures', 'accessibility'], True, predecessor))

    def test_accessibility_only_pr_runs_matrix_after_skipped_unneeded_producer(self):
        self.assertFalse(condition_value(job_field(self.jobs['tour-build'], 'if'), 'pull_request', ['accessibility'], False, 'success'))
        for name in self.delayed:
            self.assertEqual(condition_value(job_field(self.jobs[name], 'if'), 'pull_request', ['accessibility'], False, 'skipped'),
                             name == 'a11y-matrix')
        # cancelled() is a workflow state, not an alias for one prerequisite's result.
        self.assertTrue(condition_value(job_field(self.jobs['archive'], 'if'), 'schedule', [], False, 'cancelled'))
        # Real shared-build consumers still require producer success; no artifact-less tour run is introduced.
        self.assertFalse(condition_value(job_field(self.jobs['tour'], 'if'), 'pull_request', ['captures'], False, 'failure'))

    def test_default_success_and_missing_cancel_guard_are_detectable_negative_controls(self):
        expression = job_field(self.jobs['archive'], 'if')
        original_trigger = expression.split('&& (', 1)[1][:-1]
        self.assertFalse(condition_value(original_trigger, 'pull_request', ['captures'], False, 'failure'))
        unsafe = expression.replace('!cancelled()', 'always()')
        self.assertTrue(condition_value(unsafe, 'pull_request', ['captures'], True, 'success'))
        with self.assertRaises(ValueError): condition_value('unknown()', 'schedule', [], False, 'success')

    def test_dependency_graph_is_acyclic_and_five_initial_macos_roots_replace_nine(self):
        pending = {name: set(job_needs(block)) for name, block in self.jobs.items()}
        self.assertTrue(all(deps <= set(pending) for deps in pending.values()))
        finished = set()
        while pending:
            available = {name for name, deps in pending.items() if deps <= finished}
            self.assertTrue(available, 'Dependency cycle would prevent evidence collection')
            finished.update(available)
            pending = {name: deps for name, deps in pending.items() if name not in available}
        native = job_blocks((ROOT / '.github/workflows/ios.yml').read_text())
        roots = lambda jobs: {name for name, block in jobs.items()
                             if (job_field(block, 'runs-on') or '').startswith('macos-') and not job_needs(block)}
        self.assertEqual(roots(native), {'core', 'app', 'release', 'accessibility'})
        self.assertEqual(roots(self.jobs), {'tour-build'})
        self.assertEqual(len(roots(native)) + len(roots(self.jobs)), 5)
        self.assertEqual(len(roots(native)) + len(roots(self.jobs)) + len(self.delayed), 9)

    def test_scheduling_does_not_raise_timeouts_or_mask_job_failures(self):
        expected = {'tour-build': '30', 'tour': '90', 'archive': '30', 'ipad': '45', 'a11y-matrix': '75', 'tsan': '45'}
        for name, minutes in expected.items():
            self.assertEqual(job_field(self.jobs[name], 'timeout-minutes'), minutes)
            self.assertIsNone(job_field(self.jobs[name], 'continue-on-error'))
        self.assertEqual(self.source.count('contents: write'), 1)
        self.assertIn("cancel-in-progress: ${{ github.event_name == 'pull_request' }}", self.source)


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
        self.assertIn('needs: tour-build', tour)
        self.assertIn('tour-products-${{ github.sha }}-${{ github.run_id }}-${{ github.run_attempt }}', tour)
        self.assertIn('nightly-build-${{ github.job }}-${{ github.run_attempt }}', source)
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
        self.assertIn('name: results-tour-attempt-${{ github.run_attempt }}\n          path: results/results-tour', source)
        self.assertIn('pattern: results-tour-*-attempt-${{ github.run_attempt }}\n          path: results/results-tour/shards\n          merge-multiple: false', source)
        self.assertIn('pattern: tour-logs-*', source)
        self.assertIn('needs: [tour-build, tour, archive, ipad, a11y-matrix, tsan]', source)
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

    def test_original_frame_subset_is_additive_shared_and_before_full_exports(self):
        source = (ROOT / '.github/workflows/nightly.yml').read_text()
        tour = source.split('  tour:\n')[1].split('\n  archive:')[0]
        name = 'Upload original tour frames and metadata before full exports'
        subset = tour.split('      - name: ' + name + '\n', 1)[1].split('\n      - ', 1)[0]
        for token in ['actions/upload-artifact@b7c566a772e6b6bfb58ed0dc250532a479d7789f', 'if: always()',
                      'name: tour-frames-${{ matrix.shard }}-attempt-${{ github.run_attempt }}',
                      'if-no-files-found: error', 'retention-days: 14']:
            self.assertIn(token, subset)
        self.assertNotIn('run:', subset)
        self.assertNotIn('matrix.shard ==', subset)
        self.assertNotIn('continue-on-error', subset)
        order = ['Upload compact shard diagnostics before attachments', 'Export simulator screenshots',
                 name, 'name: ${{ matrix.artifact }}-attempt-', 'name: ios-tour-evidence-']
        positions = [tour.index(item) for item in order]
        self.assertEqual(positions, sorted(positions))
        # This extra retrieval artifact never substitutes for the existing publication/coverage inputs.
        publish = source.split('  publish:\n', 1)[1]
        self.assertNotIn('tour-frames-', publish)

    def test_full_exports_and_compact_logs_stay_separate_and_unchanged(self):
        source = (ROOT / '.github/workflows/nightly.yml').read_text()
        tour = source.split('  tour:\n')[1].split('\n  archive:')[0]
        self.assertIn('name: ${{ matrix.artifact }}-attempt-${{ github.run_attempt }}\n'
                      '          path: ci-out\n          retention-days: 14', tour)
        self.assertIn('name: ios-tour-evidence-${{ matrix.shard }}-attempt-${{ github.run_attempt }}\n'
                      '          path: |\n            ios/build/*.xcresult\n          retention-days: 14', tour)
        compact = tour.split('      - name: Upload compact shard diagnostics before attachments', 1)[1]
        compact = compact.split('      - name: Export simulator screenshots', 1)[0]
        for token in ['ci-out/*.log', 'ci-out/*.summary.txt', 'ci-out/outcome.json', 'ci-out/shared-build.json',
                      'name: tour-logs-${{ matrix.shard }}-attempt-${{ github.run_attempt }}']:
            self.assertIn(token, compact)
        self.assertEqual(tour.count('xcrun xcresulttool export attachments'), 1)
        self.assertNotIn('rm -', tour)

    def test_original_frame_globs_keep_bytes_names_and_manifest_without_recordings_or_bundles(self):
        source = (ROOT / '.github/workflows/nightly.yml').read_text()
        subset = source.split('      - name: Upload original tour frames and metadata before full exports\n', 1)[1]
        subset = subset.split('\n      - ', 1)[0]
        patterns = [line.strip() for line in subset.split('          path: |\n', 1)[1]
                    .split('          if-no-files-found:', 1)[0].splitlines()]
        self.assertEqual(patterns, ['ci-out/screenshots/**/*.png', 'ci-out/screenshots/**/*.txt',
                                    'ci-out/screenshots/**/*.json', '!ci-out/screenshots/**/*.xcresult/**'])
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            originals = {
                'ci-out/screenshots/frame.png': b'original PNG bytes',
                'ci-out/screenshots/hierarchy.txt': b'exact original hierarchy',
                'ci-out/screenshots/state.json': b'{"state":"original"}',
                'ci-out/screenshots/manifest.json': b'[{"file":"frame.png"},{"file":"recording.mp4"}]',
                'ci-out/screenshots/nested/frame.png': b'nested original PNG',
            }
            excluded = ['ci-out/screenshots/recording.mp4', 'ci-out/screenshots/recording.mov',
                        'ci-out/screenshots/nested/recording.mp4', 'ci-out/screenshots/other.bin',
                        'ci-out/screenshots/Result.xcresult/Info.json',
                        'ci-out/screenshots/nested/Result.xcresult/Attachments/frame.png',
                        'ios/build/UITests.xcresult/Info.json', 'ci-out/test.log']
            for relative, content in {**originals, **dict.fromkeys(excluded, b'not a still-frame export')}.items():
                path = root / relative
                path.parent.mkdir(parents=True, exist_ok=True)
                path.write_bytes(content)
            selected = set()
            for pattern in patterns:
                matched = {Path(path).relative_to(root).as_posix()
                           for path in glob.glob(str(root / pattern.lstrip('!')), recursive=True) if Path(path).is_file()}
                if pattern.startswith('!'):
                    selected.difference_update(matched)
                else:
                    selected.update(matched)
            self.assertEqual(selected, set(originals))
            self.assertEqual({name: (root / name).read_bytes() for name in selected}, originals)
            # Launch metrics can have no image attachments; its original empty manifest is still evidence.
            self.assertIn('ci-out/screenshots/manifest.json', selected)

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
