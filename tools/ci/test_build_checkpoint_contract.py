"""Build diagnostics must be available before long tests/archives, without masking failures."""
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[2]


class BuildCheckpointContract(unittest.TestCase):
    def test_sanitizer_budget_is_bounded_without_filtering_or_hiding_failures(self):
        workflow = (ROOT / '.github/workflows/nightly.yml').read_text()
        sanitizer = workflow.split('  tsan:\n', 1)[1].split('\n  publish:', 1)[0]
        self.assertEqual([line.strip() for line in sanitizer.splitlines() if 'timeout-minutes:' in line],
                         ['timeout-minutes: 45'])
        self.assertIn('runs-on: macos-15', sanitizer)
        run = sanitizer.split('        run: |\n', 1)[1].split('      - name: Summarize', 1)[0]
        self.assertEqual([line.strip() for line in run.splitlines() if line.strip()], [
            'set -o pipefail',
            'mkdir -p ci-out',
            'swift test --package-path ios --sanitize=thread 2>&1 | tee ci-out/tsan.log',
        ])
        self.assertNotIn('continue-on-error', sanitizer)
        self.assertNotIn('strategy:', sanitizer)
        self.assertIn('name: results-tsan', sanitizer)
        self.assertEqual(sanitizer.count('if: always()'), 2)

    def test_both_simulator_builds_publish_immediately_and_keep_failure_status(self):
        workflow = (ROOT / '.github/workflows/nightly.yml').read_text()
        builds = workflow.split('      - name: Build app and tests\n')[1:]
        self.assertEqual(len(builds), 2)
        for index, build in enumerate(builds):
            checkpoint = build.split('          retention-days: 14', 1)[0]
            self.assertIn('set -o pipefail', checkpoint)
            self.assertIn('tee ci-out/build.log', checkpoint)
            self.assertLess(checkpoint.index('xcodebuild build-for-testing'),
                            checkpoint.index('Summarize simulator build immediately'))
            self.assertLess(checkpoint.index('Summarize simulator build immediately'),
                            checkpoint.index('Upload simulator build checkpoint'))
            self.assertEqual(checkpoint.count("if: always() && hashFiles('ci-out/build.log') != ''"), 2)
            suffix = ''  # Shared tour producer and independent a11y producer both bind run attempt.
            self.assertIn('nightly-build-${{ github.job }}-' + suffix + '${{ github.run_attempt }}', checkpoint)
            self.assertIn('if-no-files-found: error', checkpoint)
            for forbidden in ['continue-on-error', '|| true', 'printenv', 'test-without-building', 'xcodebuild archive']:
                self.assertNotIn(forbidden, checkpoint)
        self.assertIn('tee ci-out/build.log | tail -40 | tee ci-out/build-tail.log', builds[1])

    def test_independent_release_archive_and_final_evidence_remain(self):
        workflow = (ROOT / '.github/workflows/nightly.yml').read_text()
        archive = workflow.split('      - name: Archive unsigned iOS app\n', 1)[1].split('      - name:', 1)[0]
        self.assertNotIn('continue-on-error', archive)
        self.assertEqual(workflow.count('xcodebuild archive '), 1)
        self.assertNotIn('xcodebuild archive', workflow.split('  tour:\n')[1].split('  archive:')[0])
        self.assertIn('set -o pipefail', archive)
        self.assertIn('xcodebuild archive', archive)
        self.assertIn("-destination 'generic/platform=iOS'", archive)
        self.assertIn('name: ios-evidence', workflow)
        self.assertIn('ios/build/Timbre.xcarchive', workflow)

    def test_error_beyond_connector_prefix_is_summarized_and_annotated(self):
        with tempfile.TemporaryDirectory() as directory:
            log = Path(directory) / 'build.log'
            summary = Path(directory) / 'summary.txt'
            error = 'Demo.swift:12:8: error: representative compile failure'
            log.write_text(('compile progress\n' * 150_000) + error + '\n** BUILD FAILED **\n')
            result = subprocess.run([sys.executable, str(ROOT / 'tools/ci/summarize-log.py'),
                                     str(log), str(summary)], capture_output=True, text=True, check=True)
            self.assertIn(error, summary.read_text())
            self.assertIn('::error::' + error, result.stdout)
            self.assertLess(summary.stat().st_size, 10_000)

    def test_new_contracts_and_native_geometry_are_selected(self):
        workflow = (ROOT / '.github/workflows/ios.yml').read_text()
        for token in ['python3 tools/ci/test_result_polish_contract.py',
                      'python3 tools/ci/test_build_checkpoint_contract.py',
                      '-only-testing:TimbreUITests/CaptureLockEvidenceTests',
                      '-only-testing:TimbreUITests/TimbreUITests/testInstrumentFamilyChipMustClearBothFades']:
            self.assertIn(token, workflow)


if __name__ == '__main__':
    unittest.main()
