#!/usr/bin/env python3
"""Portable reveal-diagnostic contracts; not native compilation, screenshots, or contrast proof."""
import hashlib
import json
import os
from pathlib import Path
import re
import subprocess
import sys
import tempfile
import textwrap
import unittest

import accessibility_partitions
import comment_hygiene

ROOT = Path(__file__).resolve().parents[2]
SOURCE = (ROOT / 'ios/TimbreUITests/OccludedContrastDiagnosticUITests.swift').read_text()
WORKFLOW = (ROOT / '.github/workflows/ios.yml').read_text()
JOB = WORKFLOW.split('  accessibility:\n', 1)[1].split('\n  gate:\n', 1)[0]
CLASS = 'OccludedContrastDiagnosticUITests'
EXPECTED = [
    ('finding-03', 'learn.lesson.gtr-1-1', '', 'Start'),
    ('finding-29', 'practice.ear', '', 'Ear training'),
    ('finding-30', 'practice.ear', '', 'Hear two notes. Name the gap.'),
    ('finding-10', 'songs.filter.violin.standard.4', 'songs.filter.violin.standard.4.title', 'Violin'),
    ('finding-12', 'songs.known.song-ode-to-joy', 'songs.tile.known.song-ode-to-joy.cover.title.1', 'Joy'),
    ('finding-14', 'songs.known.song-ode-to-joy', 'songs.tile.known.song-ode-to-joy.chords.chord.C', 'C'),
    ('finding-15', 'songs.known.song-ode-to-joy', 'songs.tile.known.song-ode-to-joy.chords.chord.G', 'G'),
    ('finding-16', 'songs.known.song-ode-to-joy', 'songs.tile.known.song-ode-to-joy.duration', '2:07'),
    ('finding-17', 'songs.known.song-ode-to-joy', 'songs.tile.known.song-ode-to-joy.xp', '+35 XP'),
    ('finding-18', 'songs.known.gtr-6-5', 'songs.tile.known.gtr-6-5.chords.chord.G', 'G'),
    ('finding-19', 'songs.known.gtr-6-5', 'songs.tile.known.gtr-6-5.chords.chord.C', 'C'),
    ('finding-20', 'songs.known.gtr-6-5', 'songs.tile.known.gtr-6-5.chords.chord.D', 'D'),
    ('finding-21', 'songs.known.song-silent-night', 'songs.tile.known.song-silent-night.cover.title.0', 'Silent'),
    ('finding-22', 'songs.known.song-silent-night', 'songs.tile.known.song-silent-night.cover.title.1', 'Night'),
    ('finding-23', 'songs.known.song-silent-night', 'songs.tile.known.song-silent-night.cover.catalogue', '28'),
    ('finding-24', 'songs.known.song-silent-night', 'songs.tile.known.song-silent-night.chords.chord.A7', 'A7'),
    ('finding-25', 'songs.versions.song-ode-to-joy', 'songs.tile.known.song-ode-to-joy.versions.more', '+5'),
    ('finding-26', 'songs.versions.gtr-6-5', 'songs.tile.known.gtr-6-5.versions.more', '+5'),
]


def step(name):
    body = JOB.split('      - name: ' + name + '\n', 1)[1]
    return re.split(r'^      - ', body, maxsplit=1, flags=re.MULTILINE)[0]


def opt_in_program():
    body = step('Resolve bounded contrast reveal opt-in')
    return textwrap.dedent(body.split("python3 - <<'PYCODE'\n", 1)[1].split('          PYCODE', 1)[0])


class SourceContracts(unittest.TestCase):
    def test_exact_historical_eighteen_parent_leaf_bindings(self):
        actual = re.findall(r'\.init\("(finding-\d+)", "([^"]+)", "([^"]*)", "([^"]+)"', SOURCE)
        self.assertEqual(actual, EXPECTED)
        self.assertEqual(len(actual), 18)

    def test_five_groups_cover_all_targets_once(self):
        self.assertEqual(len(re.findall(r'func testReveal\w+\(', SOURCE)), 5)
        methods = SOURCE.split('func testRevealLearnStart', 1)[1].split('private func collect', 1)[0]
        keys = re.findall(r'"(finding-\d+)"', methods)
        self.assertEqual(sorted(keys), sorted(row[0] for row in EXPECTED))

    def test_diagnostic_does_not_enter_strict_partition_or_callback(self):
        selected = set.union(*(accessibility_partitions.expected_tests(part)
                               for part in accessibility_partitions.PARTITIONS))
        self.assertFalse(any(CLASS in name for name in selected))
        strict = (ROOT / 'ios/TimbreUITests/AccessibilityAuditUITests.swift').read_text()
        self.assertNotIn(CLASS, strict)
        self.assertNotIn('TIMBRE_REVEAL_CONTRAST', strict)
        self.assertNotIn('contrast-reveal-', strict)

    def test_no_issue_suppression_or_pixel_proof_activation(self):
        callback = SOURCE.split('performAccessibilityAudit(for: .contrast)', 1)[1].split('auditReturned = true', 1)[0]
        self.assertEqual(callback.count('return false'), 1)
        self.assertNotIn('return true', callback)
        for token in ['known:', 'ContrastProofCatalog', 'OccludedContrastPolicy', '.accessibilityHidden', '.opacity(']:
            self.assertNotIn(token, SOURCE)
        self.assertIn('originalFailuresResolved=0', SOURCE)
        self.assertIn('pixelProof=false', SOURCE)

    def test_default_skip_and_explicit_native_budgets(self):
        self.assertIn('throw XCTSkip(', SOURCE)
        self.assertIn('executionTimeAllowance = 120', SOURCE)
        self.assertIn('<= 90', SOURCE)
        self.assertIn('horizontal ? 6 : 3', SOURCE)
        self.assertIn('for _ in 0..<3 where !tab.isSelected', SOURCE)
        self.assertIn('let originalIdentities = state.identities', SOURCE)
        self.assertIn('same(state, after)', SOURCE)
        self.assertIn('state.clearBand.contains($0)', SOURCE)

    def test_snapshot_schema_and_geometry_are_explicit(self):
        tree = SOURCE.split('private struct Hierarchy: Encodable', 1)[1].split('private enum Blocked', 1)[0]
        for field in ['identifier: String', 'label: String', 'value: String', 'type: UInt', 'frame: [Double]', 'children: [Hierarchy]']:
            self.assertIn(field, tree)
        self.assertNotIn('debugDescription', SOURCE)
        for token in ['AdditionalDimmingOverlay', 'songs.page', 'songs.filter.all', 'let left: CGFloat', 'let right: CGFloat']:
            self.assertIn(token, SOURCE)
        self.assertIn('JSONEncoder().encode(Hierarchy(app.snapshot()))', SOURCE)

    def test_workflow_keeps_three_strict_partitions_before_diagnostic(self):
        previous = -1
        for partition in accessibility_partitions.PARTITIONS:
            run = JOB.index('run: python3 tools/ci/accessibility_partitions.py ' + partition)
            checkpoint = JOB.index('name: accessibility-checkpoint-' + partition)
            self.assertLess(previous, run)
            self.assertLess(run, checkpoint)
            previous = checkpoint
        diagnostic = JOB.index('name: Collect opt-in revealed contrast frames')
        self.assertLess(previous, diagnostic)
        self.assertGreater(JOB.index('accessibility_partitions.py aggregate'), diagnostic)
        self.assertEqual(JOB.count("!cancelled() && steps.ax-build.outcome == 'success'"), 3)

    def test_new_execution_is_bounded_opt_in_and_failure_preserving(self):
        body = step('Collect opt-in revealed contrast frames (never dismiss strict failures)')
        self.assertIn("steps.reveal-opt-in.outputs.enabled == 'true'", body)
        self.assertIn("steps.ax-build.outcome == 'success'", body)
        self.assertIn('!cancelled()', body)
        self.assertIn('timeout-minutes: 15', body)
        self.assertIn('set -euo pipefail', body)
        self.assertIn('-only-testing:TimbreUITests/' + CLASS, body)
        self.assertIn('-maximum-test-execution-time-allowance 120', body)
        self.assertIn('TEST_RUNNER_TIMBRE_REVEAL_CONTRAST', body)
        self.assertIn('TEST_RUNNER_TIMBRE_DIAGNOSTIC_SOURCE_SHA', body)
        self.assertNotIn('continue-on-error', body)
        self.assertNotIn('|| true', body)
        upload = step('Upload separate contrast reveal diagnostic evidence')
        self.assertIn('always()', upload)
        self.assertIn('name: accessibility-reveal-diagnostics', upload)
        self.assertIn('if-no-files-found: error', upload)
        self.assertIn('ios/build/ContrastReveal.xcresult', upload)

    def test_compact_reveal_artifacts_precede_unchanged_full_evidence_and_strict_aggregate(self):
        names = ['Export opt-in contrast reveal attachments', 'Summarize opt-in contrast reveal log',
                 'Upload compact contrast reveal logs and metadata', 'Upload contrast reveal exported attachments',
                 'Upload separate contrast reveal diagnostic evidence',
                 'Require every accessibility partition and expected test']
        self.assertEqual(sorted(JOB.index('name: ' + name) for name in names),
                         [JOB.index('name: ' + name) for name in names])
        summary = step(names[1])
        self.assertIn('summarize-log.py ci-out/contrast-reveal/test.log ci-out/contrast-reveal/test.summary.txt', summary)
        for name, artifact in [(names[2], 'accessibility-reveal-logs'),
                               (names[3], 'accessibility-reveal-attachments')]:
            body = step(name)
            self.assertIn("always() && steps.reveal-opt-in.outputs.enabled == 'true'", body)
            self.assertIn('actions/upload-artifact@b7c566a772e6b6bfb58ed0dc250532a479d7789f', body)
            self.assertIn('name: ' + artifact, body)
            self.assertIn('if-no-files-found: error', body)
            self.assertIn('retention-days: 7', body)
            for forbidden in ['.xcresult', 'continue-on-error', '|| true', 'rm ', 'gzip ', 'zip ']:
                self.assertNotIn(forbidden, body)
        self.assertIn('path: ci-out/contrast-reveal/attachments', step(names[3]))
        original = step(names[4])
        self.assertIn('name: accessibility-reveal-diagnostics', original)
        self.assertIn('path: |\n            ci-out/contrast-reveal\n            ios/build/ContrastReveal.xcresult', original)
        self.assertIn('if-no-files-found: error', original)
        self.assertIn('run: python3 tools/ci/accessibility_partitions.py aggregate', step(names[5]))

    def test_compact_reveal_globs_preserve_original_metadata_and_exports_without_native_duplicate(self):
        body = step('Upload compact contrast reveal logs and metadata')
        patterns = [line.strip() for line in body.splitlines() if line.strip().startswith('ci-out/')]
        self.assertEqual(patterns, ['ci-out/contrast-reveal/test*.log', 'ci-out/contrast-reveal/*.summary.txt',
                                  'ci-out/contrast-reveal/*.json', 'ci-out/contrast-reveal/attachments/*.json',
                                  'ci-out/contrast-reveal/attachments/*.txt'])
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder)
            reveal = root / 'ci-out/contrast-reveal'
            exported = reveal / 'attachments'
            exported.mkdir(parents=True)
            metadata = [reveal / 'test.log', reveal / 'test.summary.txt', reveal / 'invocation.json',
                        exported / 'manifest.json', exported / 'hierarchy.json', exported / 'report.txt']
            original_exports = [exported / 'native.png', exported / 'recording.mp4', exported / 'native-snapshot']
            for path in metadata + original_exports:
                path.write_bytes(('unaltered export: ' + path.name).encode())
            native = root / 'ios/build/ContrastReveal.xcresult'
            native.mkdir(parents=True)
            with (native / 'data').open('wb') as handle:
                handle.seek(600 * 1024 * 1024)
                handle.write(b'0')
            before = {path: hashlib.sha256(path.read_bytes()).hexdigest() for path in metadata + original_exports}
            selected = {path for pattern in patterns for path in root.glob(pattern)}
            self.assertEqual(selected, set(metadata))
            self.assertLess(sum(path.stat().st_size for path in selected), 4096)
            self.assertEqual(set(exported.rglob('*')), set(metadata[3:] + original_exports))
            self.assertEqual({path: hashlib.sha256(path.read_bytes()).hexdigest() for path in before}, before)

    def test_hygiene_and_bounded_swift_line_lengths(self):
        self.assertEqual(comment_hygiene.lint_source('ios/TimbreUITests/' + CLASS + '.swift', SOURCE), [])
        self.assertLessEqual(max(map(len, SOURCE.splitlines())), 160)


class MarkerExecutionTests(unittest.TestCase):
    def invoke(self, message, branch='codex/app-store-readiness-gates', repository='azerish25-ux/tuner',
               descendant=False, invalid_head=False, wrong_checkout=False):
        with tempfile.TemporaryDirectory() as folder:
            def git(*args):
                return subprocess.check_output(['git', *args], cwd=folder, text=True, stderr=subprocess.DEVNULL).strip()
            git('init')
            git('config', 'user.name', 'Diagnostic fixture')
            git('config', 'user.email', 'fixture@example.invalid')
            git('commit', '--allow-empty', '-m', message)
            if descendant:
                git('commit', '--allow-empty', '-m', 'Unmarked descendant')
            head = git('rev-parse', 'HEAD')
            env = dict(os.environ, SOURCE_HEAD='invalid' if invalid_head else head,
                       SOURCE_REPOSITORY=repository, SOURCE_BRANCH=branch,
                       GITHUB_SHA='0' * 40 if wrong_checkout else head,
                       GITHUB_OUTPUT=str(Path(folder) / 'output'))
            run = subprocess.run([sys.executable, '-c', opt_in_program()], cwd=folder, env=env,
                                 text=True, capture_output=True, timeout=20)
            receipt_path = Path(folder) / 'ci-out/contrast-reveal/invocation.json'
            receipt = json.loads(receipt_path.read_text()) if receipt_path.exists() else None
            output = (Path(folder) / 'output').read_text() if (Path(folder) / 'output').exists() else ''
            return run, receipt, output, head

    def enabled(self, message, **kwargs):
        run, receipt, output, head = self.invoke(message, **kwargs)
        self.assertEqual(run.returncode, 0, run.stderr)
        self.assertEqual(set(receipt), {'diagnosticOnly', 'enabled', 'headSHA', 'builtCheckoutSHA', 'originalFailuresResolved'})
        self.assertTrue(receipt['diagnosticOnly'])
        self.assertEqual(receipt['headSHA'], head)
        self.assertEqual(receipt['builtCheckoutSHA'], head)
        self.assertEqual(receipt['originalFailuresResolved'], 0)
        self.assertEqual(output, f"enabled={str(receipt['enabled']).lower()}\nsource={head}\n")
        return receipt['enabled']

    def test_exact_standalone_marker(self):
        self.assertTrue(self.enabled('Collect evidence\n\n[contrast-reveal-diagnostics]'))

    def test_main_marker(self):
        self.assertTrue(self.enabled('[contrast-reveal-diagnostics]', branch='main'))

    def test_absent_marker(self):
        self.assertFalse(self.enabled('Collect evidence'))

    def test_embedded_marker(self):
        self.assertFalse(self.enabled('Collect [contrast-reveal-diagnostics] evidence'))

    def test_ancestor_marker(self):
        self.assertFalse(self.enabled('[contrast-reveal-diagnostics]', descendant=True))

    def test_fork_marker(self):
        self.assertFalse(self.enabled('[contrast-reveal-diagnostics]', repository='fixture/fork'))

    def test_unapproved_branch_marker(self):
        self.assertFalse(self.enabled('[contrast-reveal-diagnostics]', branch='unapproved'))

    def test_malformed_head_fails_closed(self):
        run, receipt, output, _ = self.invoke('[contrast-reveal-diagnostics]', invalid_head=True)
        self.assertNotEqual(run.returncode, 0)
        self.assertIsNone(receipt)
        self.assertEqual(output, '')

    def test_checkout_sha_mismatch_fails_closed(self):
        run, receipt, output, _ = self.invoke('[contrast-reveal-diagnostics]', wrong_checkout=True)
        self.assertNotEqual(run.returncode, 0)
        self.assertIsNone(receipt)
        self.assertEqual(output, '')


if __name__ == '__main__':
    unittest.main()
