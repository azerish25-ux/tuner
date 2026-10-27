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
        self.assertIn("format('manual-{0}', github.run_id)", block)
        for text in (block, plan):
            self.assertIn("github.event_name == 'workflow_dispatch'", text)
            self.assertEqual(set(re.findall(r"contains\(github.event.head_commit.message, '(\[listing-[^']+\])'\)", text)), MARKERS)
        # All explicit marker scopes share the same requested queue; ordinary pushes cannot replace it.
        def category(event, message):
            return 'manual' if event == 'workflow_dispatch' else ('requested' if any(m in message for m in MARKERS) else 'noop')
        self.assertEqual(category('workflow_dispatch', ''), 'manual')
        for marker in MARKERS:
            self.assertEqual(category('push', 'reviewed changes ' + marker), 'requested')
        for message in ['', 'source-only fix', '[caption-typography]', '[ci-refresh]']:
            self.assertEqual(category('push', message), 'noop')

    def test_explicit_supersession_condition_and_legacy_push_group(self):
        source = (ROOT / '.github/workflows/listing-assets.yml').read_text()
        block = source.split('concurrency:\n', 1)[1].split('jobs:\n', 1)[0]
        group = re.search(r'group: >-\n(.*?)\n  # Opt-in', block, re.S).group(1).strip()
        cancel = block.split('cancel-in-progress: >-\n', 1)[1].strip()[3:-2].strip()
        def evaluate(expression, event, ref, message, run_id='123'):
            values = {'github.event_name': event, 'github.ref': ref,
                      'github.event.head_commit.message': message, 'github.run_id': run_id}
            for key in sorted(values, key=len, reverse=True):
                expression = expression.replace(key, repr(values[key]))
            expression = ' '.join(expression.split()).replace('&&', ' and ').replace('||', ' or ').replace('!contains', 'not contains')
            return eval(expression, {'__builtins__': {}, 'contains': lambda text, token: token in text,
                                     'format': lambda template, value: template.format(value)})
        def group_name(event, ref, message, run_id='123'):
            return re.sub(r'\$\{\{(.*?)\}\}', lambda match: str(evaluate(match.group(1), event, ref, message, run_id)), group, flags=re.S)
        branch = 'refs/heads/codex/app-store-readiness-gates'
        pilot, opt = '[listing-screenshots-pilot]', '[supersede-listing-pilot]'
        self.assertTrue(evaluate(cancel, 'push', branch, pilot + opt))
        for event in ['workflow_dispatch', 'pull_request', 'schedule']:
            self.assertFalse(evaluate(cancel, event, branch, pilot + opt))
        for ref in ['refs/heads/main', branch + '-copy', 'refs/heads/topic', 'refs/tags/main']:
            self.assertFalse(evaluate(cancel, 'push', ref, pilot + opt))
        for message in ['', opt, pilot, '[listing-screenshots-all]' + opt,
                        '[listing-assets-pilot]' + opt, '[ci-refresh]']:
            self.assertFalse(evaluate(cancel, 'push', branch, message))
        for conflicting in MARKERS - {pilot}:
            self.assertFalse(evaluate(cancel, 'push', branch, pilot + opt + conflicting))
        legacy = 'listing-assets-' + branch + '-requested'
        self.assertEqual(group_name('push', branch, pilot), legacy)
        self.assertEqual(group_name('push', branch, pilot + opt), legacy)
        self.assertEqual(group_name('push', branch, opt), 'listing-assets-' + branch + '-noop')
        self.assertNotEqual(group_name('workflow_dispatch', branch, pilot + opt), legacy)
        self.assertNotEqual(group_name('workflow_dispatch', branch, '', '1'),
                            group_name('workflow_dispatch', branch, '', '2'))

    def test_contract_runs_in_core(self):
        self.assertIn('python3 tools/ci/test_ci_concurrency_contract.py',
                      (ROOT / '.github/workflows/ios.yml').read_text())


if __name__ == '__main__':
    unittest.main()
