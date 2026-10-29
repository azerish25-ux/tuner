"""Keep audit diagnostics small and immediate without changing audit enforcement."""
from pathlib import Path
import tempfile
import unittest
ROOT = Path(__file__).resolve().parents[2]

class CompactAuditLogs(unittest.TestCase):
    def test_each_partition_has_immediate_log_only_upload(self):
        text = (ROOT / '.github/workflows/ios.yml').read_text()
        for part in ('localization', 'screens', 'tabs'):
            start = text.index('      - name: Upload compact ' + part + ' audit logs')
            stop = text.index('      - uses:', start)
            block = text[start:stop]
            self.assertIn('if: always()', block)
            self.assertIn('name: accessibility-logs-' + part, block)
            for pattern in ('test*.log', '*.summary.txt', '*.json'):
                self.assertIn('ci-out/' + part + '/' + pattern, block)
            for forbidden in ('screenshots', '.xcresult', '**', 'continue-on-error'):
                self.assertNotIn(forbidden, block)
            self.assertLess(start, text.index('name: accessibility-checkpoint-' + part))
        self.assertIn('python3 tools/ci/accessibility_partitions.py aggregate', text)
        self.assertIn('timeout-minutes: 75', text)
        self.assertIn('python3 tools/ci/test_accessibility_log_checkpoints.py', text)

    def test_selection_excludes_oversized_native_bundles(self):
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            for name in ('test.log', 'test-relaunch.log', 'test.summary.txt', 'result.json'):
                (root / name).write_text('diagnostic')
            (root / 'screenshots').mkdir()
            (root / 'screenshots' / 'image.png').write_bytes(b'synthetic test marker')
            bundle = root / 'Audit.xcresult'
            bundle.mkdir()
            with (bundle / 'data').open('wb') as handle:
                handle.seek(513 * 1024 * 1024)
                handle.write(b'0')
            selected = {p for pattern in ('test*.log', '*.summary.txt', '*.json') for p in root.glob(pattern)}
            self.assertEqual({p.name for p in selected}, {'test.log', 'test-relaunch.log', 'test.summary.txt', 'result.json'})
            self.assertLess(sum(p.stat().st_size for p in selected), 1024)
            self.assertGreater((bundle / 'data').stat().st_size, 512 * 1024 * 1024)

if __name__ == '__main__':
    unittest.main()
