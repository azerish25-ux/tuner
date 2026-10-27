"""Keep newest PR checks moving without losing requested capture evidence to no-op pushes."""
from pathlib import Path
import re
import unittest

ROOT = Path(__file__).resolve().parents[2]
MARKERS = {'[listing-assets-pilot]', '[listing-assets-all]',
           '[listing-screenshots-pilot]', '[listing-screenshots-all]'}


class CIConcurrencyContract(unittest.TestCase):
    def test_only_pull_requests_cancel_running_native_checks(self):
        for name, prefix in [('ios', 'ios-native'), ('nightly', 'nightly')]:
            source = (ROOT / f'.github/workflows/{name}.yml').read_text()
            block = source.split('concurrency:\n', 1)[1].split('env:\n', 1)[0]
            self.assertIn(f'group: {prefix}-${{{{ github.ref }}}}', block)
            self.assertIn("cancel-in-progress: ${{ github.event_name == 'pull_request' }}", block)
            self.assertNotIn('[ci-refresh]', block)
            self.assertEqual(block.count('cancel-in-progress:'), 1)

    def test_listing_requests_and_no_ops_use_separate_groups(self):
        source = (ROOT / '.github/workflows/listing-assets.yml').read_text()
        block = source.split('concurrency:\n', 1)[1].split('jobs:\n', 1)[0]
        plan = source.split('  plan:\n', 1)[1].split('    runs-on:', 1)[0]
        self.assertIn('listing-assets-${{ github.ref }}-', block)
        self.assertIn("&& 'requested' || 'noop'", block)
        self.assertIn('cancel-in-progress: false', block)
        for text in (block, plan):
            self.assertIn("github.event_name == 'workflow_dispatch'", text)
            self.assertEqual(set(re.findall(r"contains\(github.event.head_commit.message, '(\[listing-[^']+\])'\)", text)), MARKERS)
        # All explicit marker scopes share the same requested queue; ordinary pushes cannot replace it.
        def category(event, message):
            return 'requested' if event == 'workflow_dispatch' or any(m in message for m in MARKERS) else 'noop'
        self.assertEqual(category('workflow_dispatch', ''), 'requested')
        for marker in MARKERS:
            self.assertEqual(category('push', 'reviewed changes ' + marker), 'requested')
        for message in ['', 'source-only fix', '[caption-typography]', '[ci-refresh]']:
            self.assertEqual(category('push', message), 'noop')

    def test_contract_runs_in_core(self):
        self.assertIn('python3 tools/ci/test_ci_concurrency_contract.py',
                      (ROOT / '.github/workflows/ios.yml').read_text())


if __name__ == '__main__':
    unittest.main()
