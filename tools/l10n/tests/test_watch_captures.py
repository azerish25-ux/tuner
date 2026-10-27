"""Watch capture evidence must fail closed; fixture bytes never count as native captures."""
import copy
import importlib.util
import hashlib
import json
from pathlib import Path
import struct
import tempfile
import unittest
from unittest.mock import patch
import subprocess
import zlib

SPEC = importlib.util.spec_from_file_location('watch_captures', Path(__file__).resolve().parents[2] / 'ci/watch_captures.py')
watch = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(watch)


class WatchCaptureTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.root = Path(self.temp.name)
        self.revision = 'a' * 40
        self.expected = watch.expectations()
        self.row = {'language': 'de', 'page': 'today', 'file': 'de/today.jpg', 'token': 'unique-launch-token'}
        self.row.update(screenshotStartedAt=2, screenshotFinishedAt=3)
        path = self.root / self.row['file']
        path.parent.mkdir()
        # Header fixture only: validates parser behavior, never offered as actual screenshot evidence.
        path.write_bytes(b'\xff\xd8\xff\xc0' + struct.pack('>H', 17) + b'\x08' + struct.pack('>HH', 496, 416) + b'\x03' + b'\x01\x11\x00\x02\x11\x00\x03\x11\x00' + b'\xff\xd9')
        probe = {'schema': 1, 'revision': self.revision, 'token': self.row['token'], 'requestedLanguage': 'de',
                 'effectiveLanguage': 'de', 'page': 'today', 'labels': self.expected['de']['today'],
                 'streak': 7, 'practicedToday': True, 'done': 1, 'total': 3, 'running': False, 'pulse': 0,
                 'nativePixels': [416, 496], 'observedAt': 1}
        self.row['before'] = probe
        self.row['after'] = copy.deepcopy(probe)
        self.row['after']['observedAt'] = 4

    def tearDown(self):
        self.temp.cleanup()

    def test_real_applied_labels_and_exact_49_language_coverage(self):
        self.assertEqual(len(self.expected), 49)
        self.assertIn('en', self.expected)
        self.assertEqual(self.expected['de']['today']['practiced'], 'Heute geübt')
        self.assertEqual(set(self.expected['ar']), {'today', 'metronome'})

    def test_dimensions_and_media_hash_are_read_from_file(self):
        result = watch.validate_capture(self.root, self.row, self.expected, self.revision)
        self.assertEqual(result['dimensions'], [416, 496])
        self.assertEqual(len(result['sha256']), 64)
        path = self.root / self.row['file']
        path.write_bytes(path.read_bytes().replace(struct.pack('>HH', 496, 416), struct.pack('>HH', 448, 368)))
        with self.assertRaisesRegex(ValueError, 'dimensions'):
            watch.validate_capture(self.root, self.row, self.expected, self.revision)

    def test_missing_invalid_and_escaped_media_cannot_pass(self):
        for name, data in [('missing.jpg', None), ('invalid.jpg', b'not a JPEG')]:
            row = copy.deepcopy(self.row)
            row['file'] = name
            if data:
                (self.root / name).write_bytes(data)
            with self.subTest(name=name), self.assertRaises(ValueError):
                watch.validate_capture(self.root, row, self.expected, self.revision)
        row = copy.deepcopy(self.row)
        row['file'] = '../escape.jpg'
        with self.assertRaisesRegex(ValueError, 'outside'):
            watch.validate_capture(self.root, row, self.expected, self.revision)

    def test_both_probes_must_match_revision_token_page_language_labels(self):
        for when in ['before', 'after']:
            for field, value in [('revision', 'b' * 40), ('token', 'stale'), ('page', 'metronome'),
                                 ('effectiveLanguage', 'en'), ('requestedLanguage', 'en'), ('labels', {})]:
                row = copy.deepcopy(self.row)
                row[when][field] = value
                with self.subTest(when=when, field=field), self.assertRaises(ValueError):
                    watch.validate_capture(self.root, row, self.expected, self.revision)

    def test_today_requires_lit_streak_and_part_done_ring(self):
        for field, value in [('streak', 0), ('practicedToday', False), ('done', 0), ('done', 3), ('total', 0)]:
            row = copy.deepcopy(self.row)
            row['before'][field] = value
            with self.subTest(field=field, value=value), self.assertRaises(ValueError):
                watch.validate_capture(self.root, row, self.expected, self.revision)

    def test_stale_probe_cannot_certify_a_later_screenshot(self):
        row = copy.deepcopy(self.row)
        row['after']['observedAt'] = 1
        with self.assertRaisesRegex(ValueError, 'time'):
            watch.validate_capture(self.root, row, self.expected, self.revision)
        row = copy.deepcopy(self.row)
        row['before']['nativePixels'] = [368, 448]
        with self.assertRaisesRegex(ValueError, 'pixels'):
            watch.validate_capture(self.root, row, self.expected, self.revision)

    def test_metronome_requires_actual_running_timer(self):
        row = copy.deepcopy(self.row)
        row['page'] = 'metronome'
        row['file'] = 'de/metronome.jpg'
        (self.root / row['file']).write_bytes((self.root / self.row['file']).read_bytes())
        for probe in [row['before'], row['after']]:
            probe.update(page='metronome', labels=self.expected['de']['metronome'], running=True, pulse=2)
        watch.validate_capture(self.root, row, self.expected, self.revision)
        for field, value in [('running', False), ('pulse', 0)]:
            bad = copy.deepcopy(row)
            bad['after'][field] = value
            with self.subTest(field=field), self.assertRaises(ValueError):
                watch.validate_capture(self.root, bad, self.expected, self.revision)

    def test_a_page_cannot_alias_another_pages_media_file(self):
        row = copy.deepcopy(self.row)
        row['file'] = 'de/copied.jpg'
        (self.root / row['file']).write_bytes((self.root / self.row['file']).read_bytes())
        with self.assertRaisesRegex(ValueError, 'filename'):
            watch.validate_capture(self.root, row, self.expected, self.revision)

    def write_png(self, alpha=255):
        def chunk(kind, data):
            return struct.pack('>I', len(data)) + kind + data + struct.pack('>I', zlib.crc32(kind + data))
        pixels = b''.join(b'\0' + bytes([12, 24, 36, alpha]) * 416 for _ in range(496))
        path = self.root / 'de/today.png'
        path.write_bytes(b'\x89PNG\r\n\x1a\n' + chunk(b'IHDR', struct.pack('>IIBBBBB', 416, 496, 8, 6, 0, 0, 0)) +
                         chunk(b'IDAT', zlib.compress(pixels)) + chunk(b'IEND', b''))
        return path

    def test_native_png_preserves_bytes_and_records_opaque_alpha_channel(self):
        path = self.write_png()
        original = path.read_bytes()
        row = dict(self.row, file='de/today.png')
        result = watch.validate_capture(self.root, row, self.expected, self.revision)
        self.assertEqual(result['format'], 'png')
        self.assertTrue(result['opaquePixels'])
        self.assertTrue(result['alphaChannel'])
        self.assertEqual(path.read_bytes(), original)

    def test_transparent_or_corrupt_png_is_rejected(self):
        row = dict(self.row, file='de/today.png')
        for alpha in [0, 254]:
            self.write_png(alpha=alpha)
            with self.subTest(alpha=alpha), self.assertRaisesRegex(ValueError, 'opaque'):
                watch.validate_capture(self.root, row, self.expected, self.revision)
        path = self.write_png()
        data = bytearray(path.read_bytes())
        data[-1] ^= 1
        path.write_bytes(data)
        with self.assertRaisesRegex(ValueError, 'CRC'):
            watch.validate_capture(self.root, row, self.expected, self.revision)

    def test_installed_public_help_selects_png_or_honest_jpeg_fallback(self):
        selected = watch.screenshot_format('--type=<type> png,jpeg --mask=<policy> ignored,alpha,black')
        self.assertEqual(selected['type'], 'png')
        self.assertTrue(selected['black_mask'])
        fallback = watch.screenshot_format('screenshot --type jpeg')
        self.assertEqual(fallback['type'], 'jpeg')
        self.assertFalse(fallback['black_mask'])

    def test_missing_native_help_cannot_be_treated_as_a_jpeg_capability(self):
        for help_text in ['', '\n', 'simctl help unavailable', '--type png']:
            with self.subTest(help_text=help_text), self.assertRaises(ValueError):
                watch.screenshot_format(help_text)

    def test_help_can_be_captured_from_stderr_without_changing_json_commands(self):
        with patch.object(watch.subprocess, 'check_output', return_value='--type png,jpeg --mask black') as run:
            watch.command(['xcrun', 'simctl', 'help', 'io'], capture_stderr=True)
        self.assertEqual(run.call_args.kwargs['stderr'], subprocess.STDOUT)

    def test_scene_update_relaunch_is_bounded_and_every_attempt_uses_a_fresh_token(self):
        calls = []
        def launch(args, **kwargs):
            calls.append(kwargs['env']['SIMCTL_CHILD_TIMBRE_WATCH_CAPTURE_TOKEN'])
            return subprocess.CompletedProcess(args, 1 if len(calls) == 1 else 0,
                stdout='FBSOpenApplicationServiceErrorDomain: Scene update failed' if len(calls) == 1 else 'bundle: 42')
        with patch.object(watch.subprocess, 'run', side_effect=launch), \
                patch.object(watch, 'command'), patch.object(watch.time, 'sleep'):
            watch.launch_capture('watch-device', self.row, self.revision, self.root)
        self.assertEqual(len(calls), 2)
        self.assertNotEqual(calls[0], calls[1])
        self.assertEqual(self.row['token'], calls[1])
        records = json.loads((self.root / 'launches.json').read_text())
        self.assertEqual([item['returncode'] for item in records], [1, 0])

    def test_other_launch_errors_fail_without_retry_or_success_evidence(self):
        with patch.object(watch.subprocess, 'run', return_value=subprocess.CompletedProcess([], 1, stdout='Bundle not installed')) as run, \
                patch.object(watch, 'command'), patch.object(watch.time, 'sleep'), self.assertRaises(subprocess.CalledProcessError):
            watch.launch_capture('watch-device', self.row, self.revision, self.root)
        self.assertEqual(run.call_count, 1)
        self.assertFalse((self.root / 'manifest.json').exists())

    def test_repeated_scene_update_failure_never_becomes_a_capture(self):
        with patch.object(watch.subprocess, 'run', return_value=subprocess.CompletedProcess([], 1, stdout='FBSOpenApplicationServiceErrorDomain: Scene update failed')) as run, \
                patch.object(watch, 'command'), patch.object(watch.time, 'sleep'), self.assertRaises(subprocess.CalledProcessError):
            watch.launch_capture('watch-device', self.row, self.revision, self.root)
        self.assertEqual(run.call_count, 3)
        self.assertFalse((self.root / 'manifest.json').exists())

    def test_launch_timeout_keeps_partial_output_and_never_retries(self):
        error = subprocess.TimeoutExpired(['xcrun', 'simctl', 'launch'], 120, output=b'partial native output')
        with patch.object(watch.subprocess, 'run', side_effect=error) as run, \
                patch.object(watch, 'command'), patch.object(watch.time, 'sleep'), self.assertRaises(subprocess.TimeoutExpired):
            watch.launch_capture('watch-device', self.row, self.revision, self.root)
        self.assertEqual(run.call_count, 1)
        records = json.loads((self.root / 'launches.json').read_text())
        self.assertEqual(records[0]['failure_type'], 'TimeoutExpired')
        self.assertIn('partial native output', records[0]['output'])
        self.assertFalse((self.root / 'manifest.json').exists())

    def test_manifest_format_is_bound_to_recorded_native_help(self):
        help_text = '--type png,jpeg --mask black,alpha\n'
        path = self.root / 'simctl-io-help.txt'
        path.write_text(help_text)
        manifest = {'format': 'png', 'format_selection': watch.screenshot_format(help_text),
                    'simctl_help_sha256': hashlib.sha256(path.read_bytes()).hexdigest()}
        watch.validate_format_evidence(self.root, manifest)
        path.write_text('different installed capabilities')
        with self.assertRaises(ValueError):
            watch.validate_format_evidence(self.root, manifest)

    def test_manifest_requires_every_language_page_once(self):
        rows = [dict(self.row, language=language, page=page) for language in self.expected for page in ['today', 'metronome']]
        watch.validate_coverage(rows, set(self.expected))
        for bad in [rows[:-1], rows + [rows[0]], rows + [dict(self.row, language='xx')]]:
            with self.assertRaises(ValueError):
                watch.validate_coverage(bad, set(self.expected))

    def test_all_50_store_locales_bind_supported_or_explicit_fallback_media(self):
        mapping = watch.store_mappings(set(self.expected))
        self.assertEqual(len(mapping), 50)
        rows = {row['store_locale']: row for row in mapping}
        for locale in ['ms', 'or-IN', 'zh-Hant']:
            self.assertEqual(rows[locale]['capture_language'], 'en')
            self.assertEqual(rows[locale]['mapping'], 'explicit_english_fallback')
        self.assertEqual(rows['zh-Hans']['capture_language'], 'zh-CN')
        self.assertEqual(rows['en-CA']['capture_language'], 'en')
        with self.assertRaises(ValueError):
            watch.store_mappings({'en'})


if __name__ == '__main__':
    unittest.main()
