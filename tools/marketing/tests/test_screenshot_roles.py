"""Role registry contracts, not native image evidence."""
from pathlib import Path
import sys
import unittest
import json
import tempfile
from unittest.mock import patch
from PIL import Image
import hashlib
from dataclasses import FrozenInstanceError

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from screenshot_roles import ROLES, SCREENSHOT_KINDS, expected_screenshot_count, screenshot_role


class ScreenshotRoleTests(unittest.TestCase):
    def test_medium_and_large_are_distinct_native_roles_with_shared_captions(self):
        medium, large = screenshot_role('iphone'), screenshot_role('iphone-large')
        self.assertEqual(medium.native_size, (1206, 2622))
        self.assertEqual(large.native_size, (1320, 2868))
        self.assertEqual((medium.caption_device, large.caption_device), ('iphone', 'iphone'))
        self.assertEqual((medium.frame_count, large.frame_count), (9, 9))
        self.assertFalse(set(medium.simulator_names) & set(large.simulator_names))
        self.assertTrue(all('Max' not in n for n in medium.simulator_names))
        self.assertTrue(all('Pro Max' in n for n in large.simulator_names))

    def test_exact_three_screenshot_roles_and_counts_exclude_videos_and_sheets(self):
        self.assertEqual(SCREENSHOT_KINDS, ('iphone', 'iphone-large', 'ipad'))
        self.assertEqual(screenshot_role('ipad').native_size, (2752, 2064))
        self.assertEqual(expected_screenshot_count([str(i) for i in range(50)]), 1100)
        self.assertEqual(expected_screenshot_count(['en-US', 'de-DE', 'ar-SA']), 66)
        self.assertEqual(50 * len(SCREENSHOT_KINDS), 150)

    def test_unknown_roles_never_fall_back_and_registry_is_immutable(self):
        for role in ('phone', 'iphone-max', 'preview-main', '', None):
            with self.assertRaises(ValueError):
                screenshot_role(role)
        with self.assertRaises(TypeError):
            ROLES['iphone-large'] = ROLES['iphone']
        with self.assertRaises(FrozenInstanceError):
            ROLES['iphone'].native_size = (1320, 2868)
        with self.assertRaises(ValueError):
            expected_screenshot_count(['en-US', 'en-US'])
        with self.assertRaises(ValueError):
            expected_screenshot_count(['en-US'], ['iphone', 'iphone'])


class ScreenshotRoleIntegrationTests(unittest.TestCase):
    def test_exact_full_and_pilot_inventory_without_previews(self):
        import listing_assets as assets
        for locales, count in [('all', 50), ('en-US,de-DE,ar-SA', 3)]:
            plan = assets.make_plan(locales, 'screenshots')
            pairs = [(locale, row['kind']) for row in plan['matrix']['include'] for locale in row['locales'].split(',')]
            self.assertEqual(len(pairs), count * 3)
            self.assertEqual(len(set(pairs)), count * 3)
            self.assertEqual(plan['expected_screenshot_sets'], count * 3)
            self.assertEqual(plan['expected_screenshots'], count * 22)
            self.assertFalse(any('preview' in kind for kind in plan['kinds']))
            self.assertEqual(plan['full_screenshot_listing_scope'], count == 50)
        for locale in assets.locale_rows():
            self.assertEqual(assets.expected_captures(locale, 'iphone-large'), assets.expected_captures(locale, 'iphone'))
        self.assertEqual(assets.selectors('iphone'), assets.selectors('iphone-large'))

    def test_exact_device_selection_and_no_unknown_or_medium_fallback(self):
        import run_listing_assets as runner
        devices = {'devices': {'com.apple.CoreSimulator.SimRuntime.iOS-26-2': [
            {'name': 'iPhone 17 Pro', 'udid': 'medium'}, {'name': 'iPhone 17 Pro Max', 'udid': 'large'}]}}
        with patch.object(runner, 'output', return_value=json.dumps(devices)) as command:
            self.assertEqual(runner.choose_device('iphone')['id'], 'medium')
            self.assertEqual(runner.choose_device('iphone-large')['id'], 'large')
            command.reset_mock()
            with self.assertRaises(ValueError):
                runner.choose_device('iphone-arbitrary')
            command.assert_not_called()
        devices['devices'][next(iter(devices['devices']))].pop(0)
        with patch.object(runner, 'output', return_value=json.dumps(devices)), self.assertRaises(RuntimeError):
            runner.choose_device('iphone')

    def test_native_and_rendered_dimensions_cannot_cross_phone_roles(self):
        import listing_assets as assets
        import screenshots
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            raw, output = root / 'raw.png', root / 'frame.jpg'
            for kind in ('iphone', 'iphone-large'):
                size = screenshot_role(kind).native_size
                Image.new('RGB', size).save(raw)
                original_hash = hashlib.sha256(raw.read_bytes()).hexdigest()
                Image.new('RGB', size).save(output)
                self.assertEqual(screenshots.frame_size(kind, Image.new('RGB', size)), size)
                self.assertIsNone(screenshots.size_problem(kind, output, raw))
                with patch.object(assets, 'expected_captures', return_value=['native']), patch.object(screenshots, 'attachments', return_value={'native': [raw]}):
                    self.assertEqual(assets.capture_records(root, 'en-US', kind, root)[0]['size'], list(size))
                    other = 'iphone-large' if kind == 'iphone' else 'iphone'
                    with self.assertRaises(ValueError):
                        assets.capture_records(root, 'en-US', other, root)
                    with self.assertRaises(ValueError):
                        screenshots.compose('zoom mint', raw, 'native', 'Title', 'Line', other, output)
                self.assertEqual(original_hash, hashlib.sha256(raw.read_bytes()).hexdigest())
                Image.new('RGB', screenshot_role(other).native_size).save(output)
                self.assertIsNotNone(screenshots.size_problem(kind, output, raw))

    def test_legacy_full_medium_tablet_plan_cannot_claim_current_full_scope(self):
        import listing_assets as assets
        plan = assets.make_plan('all', 'screenshots')
        plan['kinds'].remove('iphone-large')
        with tempfile.TemporaryDirectory() as directory:
            result = assets.aggregate(plan, Path(directory), 'revision')
        self.assertTrue(any('full screenshot scope' in error for error in result['errors']))
        self.assertTrue(any('missing required native' in error for error in result['errors']))
        self.assertFalse(result['release_ready'])

    def test_manifest_native_dimensions_and_explicit_role_are_required(self):
        import listing_assets as assets
        for kind in ('iphone', 'iphone-large'):
            size = list(screenshot_role(kind).native_size)
            record = {'listing_locale': 'en-US', 'kind': kind, 'lesson_resource_status': 'shipped',
                      'language_evidence': [], 'launch_evidence': [],
                      'captures': [{'capture': 'native', 'pixel_sha256': 'a' * 64, 'size': size}],
                      'assets': [{'path': f'rendered/{kind}-en-US-01.jpg', 'sha256': 'b' * 64, 'size': size},
                                 {'path': f'rendered/{kind}-en-US-sheet.png', 'sha256': 'c' * 64}]}
            with patch.object(assets, 'validate_language_evidence'), patch.object(assets, 'selectors', return_value=['fixture-test']), patch.object(assets, 'expected_captures', return_value=['native']):
                assets.validate_manifest_assets(record)
                record['captures'][0]['size'] = [1320, 2868] if kind == 'iphone' else [1206, 2622]
                with self.assertRaisesRegex(ValueError, 'native capture dimensions'):
                    assets.validate_manifest_assets(record)
                record['kind'] = 'unknown'
                with self.assertRaisesRegex(ValueError, 'Unknown manifest asset role'):
                    assets.validate_manifest_assets(record)


if __name__ == '__main__':
    unittest.main()
