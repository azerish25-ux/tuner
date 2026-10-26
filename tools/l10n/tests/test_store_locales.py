#!/usr/bin/env python3
"""Validate exact Apple inventory and truthful per-locale draft evidence, never release approval."""
import json
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[3]
# Exact shortcodes from Apple's official locale-shortcodes Markdown table.
EXPECTED = set('ar-SA bn-BD ca zh-Hans zh-Hant hr cs da nl-NL en-AU en-CA en-GB en-US fi fr-FR fr-CA de-DE el gu-IN he hi hu id it ja kn-IN ko ms ml-IN mr-IN no or-IN pl pt-BR pt-PT pa-IN ro ru sk sl-SI es-MX es-ES sv ta-IN te-IN th tr uk ur-PK vi'.split())
LEGACY = set('de-DE fr-FR es-MX pt-BR it ja ko zh-Hans ru'.split())


class StoreLocaleRequirementsTests(unittest.TestCase):
    def setUp(self):
        self.manifest = json.loads((ROOT / 'tools/l10n/store-locales.json').read_text())
        self.rows = self.manifest['locales']

    def test_exact_apple_inventory_and_sources(self):
        self.assertEqual(len(self.rows), 50)
        self.assertEqual({r['locale'] for r in self.rows}, EXPECTED)
        self.assertEqual(self.manifest['listing_locale_count'], 50)
        self.assertEqual(self.manifest['primary_locale'], 'en-US')
        self.assertEqual(self.manifest['verified_on'], '2026-10-26')
        for url in self.manifest['sources'].values():
            self.assertTrue(url.startswith('https://developer.apple.com/'))

    def test_app_mapping_does_not_expand_ui_languages(self):
        app = {p.stem for p in (ROOT / 'ios/Timbre/Resources').glob('*.lproj')}
        self.assertEqual(len(app), self.manifest['app_language_count'])
        self.assertEqual(len(app), 49)
        special = {'zh-Hans': 'zh-CN', 'zh-Hant': None, 'ms': None, 'or-IN': None}
        for row in self.rows:
            expected = special.get(row['locale'], row['locale'].split('-')[0])
            self.assertEqual(row['app_locale'], expected)
            self.assertEqual(row['app_fallback'], 'en' if expected is None else None)
            if expected:
                self.assertIn(expected, app)
        unmatched = app - {r['app_locale'] for r in self.rows}
        self.assertEqual(unmatched, set('fa bg et is lt lv sw zu'.split()))
        self.assertEqual(set(self.manifest['fallback_policy']['app_only_languages']), unmatched)
        self.assertEqual({r['locale'] for r in self.rows if r['app_locale'] is None}, {'ms', 'or-IN', 'zh-Hant'})

    def test_requirements_are_not_claimed_translations(self):
        self.assertEqual(set(self.manifest['existing_localized_blocks']), LEGACY)
        self.assertTrue(all(r['state'] == 'ai_draft_structurally_valid' for r in self.rows if r['locale'] != 'en-US'))
        for row in self.rows:
            self.assertTrue((ROOT / row['content_file']).exists())
            self.assertTrue(row['draft_validation']['passed'])
            self.assertFalse(row['release_ready'])
            self.assertTrue(row['release_blockers'])
        self.assertEqual({r['locale'] for r in self.rows if r['state'] == 'english_source'}, {'en-US'})
        for row in self.rows:
            self.assertEqual(row['native_review'], 'not_verified')
            self.assertEqual(row['device_review'], 'not_verified')
        self.assertEqual(set(self.manifest['required_fields']), {
            'name', 'subtitle', 'keywords', 'promotional_text', 'description', 'whats_new',
            'iphone_screenshot_captions', 'ipad_screenshot_captions', 'app_preview_captions',
            'iap_display_names', 'iap_descriptions', 'game_center_leaderboard_names',
            'game_center_achievement_names', 'game_center_achievement_descriptions',
        })


if __name__ == '__main__':
    unittest.main()
