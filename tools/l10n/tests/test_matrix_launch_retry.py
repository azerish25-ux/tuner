import contextlib
import io
from pathlib import Path
import sys
import tempfile
import unittest

sys.path.insert(0, str(Path(__file__).resolve().parents[2] / 'ci'))
import launch_retry


class MatrixLaunchRetryTests(unittest.TestCase):
    name = 'TimbreUITests/LocalizationMatrixUITests/testLocalizedWelcomeAndTabs'

    def run_classifier(self, messages):
        case = 'TimbreUITests.LocalizationMatrixUITests testLocalizedWelcomeAndTabs'
        log = "Test Case '-[" + case + "]' started.\n"
        log += ''.join("error: -[" + case + "] : " + message + '\n' for message in messages)
        log += "Test Case '-[" + case + "]' failed.\n"
        with tempfile.TemporaryDirectory() as directory:
            source = Path(directory) / 'test.log'
            destination = Path(directory) / 'retry.txt'
            source.write_text(log)
            with contextlib.redirect_stdout(io.StringIO()):
                status = launch_retry.main(['launch_retry.py', str(source), str(destination)])
            return status, destination.read_text()

    def test_process_id_launch_failure_can_retry_once(self):
        status, args = self.run_classifier(["Application 'com.example.app' does not have a process ID"])
        self.assertEqual(status, 0)
        self.assertEqual(args, '-only-testing:' + self.name + '\n')

    def test_translation_assertion_is_never_hidden_by_launch_retry(self):
        status, args = self.run_classifier(["Application does not have a process ID", 'XCTAssertTrue failed - missing translated headline'])
        self.assertEqual(status, 1)
        self.assertEqual(args, '')

    def test_other_failure_cannot_retry_as_launch_infrastructure(self):
        status, args = self.run_classifier(['XCTAssertTrue failed - lesson body is not visible'])
        self.assertEqual(status, 1)
        self.assertEqual(args, '')

    def test_build_failure_has_no_retry_tests(self):
        eligible, other = launch_retry.classify('error: cannot find symbol\n** TEST BUILD FAILED **')
        self.assertEqual((eligible, other), ([], []))
        with tempfile.TemporaryDirectory() as directory:
            source = Path(directory) / 'build.log'
            destination = Path(directory) / 'retry.txt'
            source.write_text('error: cannot find symbol\n** TEST BUILD FAILED **')
            with contextlib.redirect_stdout(io.StringIO()):
                self.assertEqual(launch_retry.main(['script', str(source), str(destination)]), 1)
            self.assertEqual(destination.read_text(), '')

    def test_workflow_retains_attempts_and_uses_only_successful_log(self):
        root = Path(__file__).resolve().parents[3]
        workflow = (root / '.github/workflows/localization-matrix.yml').read_text()
        self.assertIn('python3 tools/ci/launch_retry.py ci-out/test.log ci-out/relaunch.txt', workflow)
        self.assertIn('run_matrix test-without-building ci-out/LocalizationRetry.xcresult ci-out/retry.log', workflow)
        self.assertIn('EVIDENCE_LOG=ci-out/retry.log', workflow)
        self.assertIn('--verify-log "$EVIDENCE_LOG"', workflow)
        self.assertIn('--output-path ci-out/retry-screenshots', workflow)


if __name__ == '__main__':
    unittest.main()
