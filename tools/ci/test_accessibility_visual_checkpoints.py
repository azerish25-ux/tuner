"""Compact visual artifacts retain original exports, never large native bundles."""
from pathlib import Path
import hashlib
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[2]
PARTITIONS = ('localization', 'screens', 'tabs')
SUFFIXES = ('*.png', '*.jpg', '*.jpeg', '*.PNG', '*.JPG', '*.JPEG', 'manifest.json', '*.txt')


def block(text, part):
    start = text.index('      - name: Upload compact ' + part + ' audit visuals')
    end = text.index('      - name:', start + 1)
    return start, text[start:end]


def patterns(text, part):
    return [line.strip() for line in block(text, part)[1].splitlines() if line.strip().startswith('ci-out/')]


class CompactAuditVisuals(unittest.TestCase):
    def test_uploads_follow_export_and_precede_logs_and_large_bundle(self):
        text = (ROOT / '.github/workflows/ios.yml').read_text()
        self.assertIn('python3 tools/ci/test_accessibility_visual_checkpoints.py', text)
        for part in PARTITIONS:
            start, value = block(text, part)
            self.assertIn('if: always()', value)
            self.assertIn('name: accessibility-visuals-' + part, value)
            self.assertIn('if-no-files-found: warn', value)
            self.assertIn('retention-days: 7', value)
            self.assertLess(text.index('name: Finalize ' + part + ' evidence'), start)
            self.assertLess(start, text.index('name: accessibility-logs-' + part))
            self.assertLess(start, text.index('name: accessibility-checkpoint-' + part))
            expected = ['ci-out/' + part + '/' + folder + '/' + suffix
                        for folder in ('screenshots', 'screenshots-relaunch') for suffix in SUFFIXES]
            self.assertEqual(patterns(text, part), expected)
            for forbidden in ('**', '.xcresult', '.mp4', '.mov', 'Build/Products', 'continue-on-error'):
                self.assertNotIn(forbidden, value)
        self.assertIn('python3 tools/ci/accessibility_partitions.py aggregate', text)

    def test_actual_upload_globs_retain_original_bytes_and_exclude_large_bundles(self):
        text = (ROOT / '.github/workflows/ios.yml').read_text()
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            expected = set()
            for part in PARTITIONS:
                for folder in ('screenshots', 'screenshots-relaunch'):
                    directory = root / 'ci-out' / part / folder
                    directory.mkdir(parents=True)
                    # Exported attachment names are UUIDs, including hierarchy/report text files.
                    for name in ('A.png', 'B.jpg', 'C.jpeg', 'D.PNG', 'E.JPG', 'F.JPEG', 'manifest.json', 'G.txt'):
                        path = directory / name
                        path.write_bytes(('unaltered fixture: ' + str(path.relative_to(root))).encode())
                        expected.add(path)
                    for name in ('movie.mp4', 'capture.mov', 'sound.m4a', 'snapshot-without-extension', 'other.json'):
                        (directory / name).write_bytes(b'excluded')
                    (directory / 'nested').mkdir()
                    (directory / 'nested' / 'unrelated.png').write_bytes(b'excluded')
                bundle = root / 'ios/build' / ('Accessibility-' + part + '.xcresult')
                bundle.mkdir(parents=True)
                with (bundle / 'data').open('wb') as handle:
                    handle.seek(1550 * 1024 * 1024)
                    handle.write(b'0')
                (root / 'ci-out' / part / 'test.log').write_bytes(b'excluded from visuals')
            products = root / 'ios/build/dd/Build/Products'
            products.mkdir(parents=True)
            (products / 'app.png').write_bytes(b'excluded')
            before = {p: hashlib.sha256(p.read_bytes()).hexdigest() for p in expected}
            selected = {p for part in PARTITIONS for pattern in patterns(text, part) for p in root.glob(pattern)}
            self.assertEqual(selected, expected)
            self.assertLess(sum(p.stat().st_size for p in selected), 16384)
            self.assertEqual({p: hashlib.sha256(p.read_bytes()).hexdigest() for p in selected}, before)


if __name__ == '__main__':
    unittest.main()
