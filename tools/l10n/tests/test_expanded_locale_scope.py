"""Contracts for52locale integration; real resources remain required by existing gates."""
import json
from pathlib import Path
import re
import sys
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(ROOT / 'tools/l10n'))
sys.path.insert(0, str(ROOT / 'tools/ci'))
sys.path.insert(0, str(ROOT / 'tools/marketing'))
import report
import shipping
import watch_captures
import listing_assets


class ExpandedLocaleScopeTests(unittest.TestCase):
    def test_declarations_share_exact_canonical_scope(self):
        expected = set(report.LANGUAGE_NAMES) | {'en'}
        self.assertEqual(len(expected), 52)
        self.assertEqual(expected, watch_captures.SHIPPED_LANGUAGES)
        self.assertEqual(shipping.RELEASE_LANGUAGE_COUNT, 52)
        settings = (ROOT / 'ios/Timbre/Settings/SettingsView.swift').read_text()
        actual = re.search(r'static let languages = (\[[^\]]+\])', settings).group(1)
        declared_languages = json.loads(actual)
        self.assertEqual(set(declared_languages), expected)
        self.assertEqual(len(declared_languages), len(expected))
        self.assertEqual(declared_languages, sorted(expected))
        self.assertTrue(all(len(line) <= 160 for line in actual.splitlines()))
        project = (ROOT / 'ios/project.yml').read_text()
        declared = re.search(r'CFBundleLocalizations: (\[[^\n]+\])', project).group(1)
        self.assertEqual(set(json.loads(declared)), expected)

    def test_all_listings_have_real_mapping_and_no_readiness_promotion(self):
        rows = listing_assets.locale_rows()
        self.assertEqual(len(rows), 50)
        for row in rows.values():
            self.assertIn(row['app_locale'], set(report.LANGUAGE_NAMES) | {'en'})
            self.assertIsNone(row['app_fallback'])
            self.assertFalse(row['release_ready'])
            self.assertEqual(row['native_review'], 'not_verified')

    def test_old_or_same_count_wrong_mapping_cannot_pass(self):
        original = json.loads(listing_assets.REGISTRY.read_text())
        for locale, wrong in [('zh-Hant', 'zh-CN'), ('ms', 'en'), ('or-IN', 'en')]:
            mutated = json.loads(json.dumps(original))
            next(row for row in mutated['locales'] if row['locale'] == locale)['app_locale'] = wrong
            with patch.object(listing_assets, 'read_json', return_value=mutated):
                with self.assertRaises(ValueError):
                    listing_assets.locale_rows()

    def test_regional_alias_native_tests_are_present(self):
        core = (ROOT / 'ios/Tests/TimbreCoreTests/TimbreLocalizationTests.swift').read_text()
        hosted = (ROOT / 'ios/TimbreAppTests/LocalizationTests.swift').read_text()
        for alias in ['zh-Hant', 'zh-HK', 'zh-MO', 'zh-CN', 'zh-SG', 'or-IN']:
            self.assertIn('"' + alias + '"', core)
            self.assertIn('"' + alias + '"', hosted)
        self.assertIn('XCTAssertEqual(cases.count, 52)', hosted)


if __name__ == '__main__':
    unittest.main()
