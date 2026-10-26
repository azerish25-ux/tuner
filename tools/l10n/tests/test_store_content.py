#!/usr/bin/env python3
"""Text gates are not native, legal, account or visual review."""
import copy
import importlib.util
import json
from pathlib import Path
import sys
import unittest

ROOT = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(ROOT / 'tools/l10n'))
import store


class StoreContentTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.source = store.load('en-US')
        cls.german = store.load('de-DE')
        cls.inventory = json.loads(store.MANIFEST.read_text())['locales']
        cls.registry = store.load_review()

    def test_exact_fifty_content_files(self):
        self.assertEqual({p.stem for p in store.DIRECTORY.glob('*.json')}, {r['locale'] for r in self.inventory})
        self.assertEqual(len(self.inventory), 50)

    def test_all_draft_text_validates(self):
        self.assertEqual(store.check_all(), [])

    def test_primary_snapshot_preserves_english(self):
        self.assertEqual(store.source_snapshot_errors(self.source), [])

    def test_all_release_gates_remain_honest(self):
        for row in self.inventory:
            d = store.load(row['locale'])
            self.assertFalse(d['review']['release_ready'])
            self.assertNotEqual(d['review']['native'], 'verified')
            self.assertNotEqual(d['review']['device'], 'verified')
            self.assertIn('<privacy policy URL>', d['description'])
            self.assertTrue(store.validate(d, self.source, release=True))

    def test_all_ai_review_hashes_are_current(self):
        self.assertEqual(store.review_artifact_errors(self.registry), [])
        for row in self.inventory:
            self.assertEqual(store.ai_review_errors(store.load(row['locale']), self.source, self.registry), [])
        self.assertEqual(sum(r['resolved_corrections'] for r in self.registry['locales'].values()), 94)

    def test_ai_review_does_not_relabel_human_evidence(self):
        for row in self.inventory:
            review = store.load(row['locale'])['review']
            self.assertEqual(review['ai_source_aware'], 'reviewed')
            for field in ('native', 'market_search', 'legal_back_translation'):
                self.assertNotEqual(review.get(field), 'verified')

    def check_review_mutation(self, edit, contains):
        registry = copy.deepcopy(self.registry)
        edit(registry)
        self.assertTrue(any(contains in e for e in store.validate(self.german, self.source, registry=registry)))

    def test_stale_review_content_fails(self):
        self.check_mutation(lambda d:d.__setitem__('subtitle', 'Neuer Untertitel'), 'current-content hash')

    def test_review_source_hash_fails(self):
        self.check_review_mutation(lambda r:r['source'].__setitem__('content_sha256', '0' * 64), 'source content hash')

    def test_review_source_version_fails(self):
        self.check_review_mutation(lambda r:r['source']['version']['counts'].__setitem__('lessons', 1), 'source version/counts')

    def test_missing_review_identity_fails(self):
        self.check_review_mutation(lambda r:r['locales']['de-DE'].pop('reviewer'), 'reviewer identity')

    def test_unresolved_corrections_fail(self):
        self.check_review_mutation(lambda r:r['locales']['de-DE'].__setitem__('unresolved_corrections', ['description']), 'unresolved corrections')

    def test_unapplied_correction_count_fails(self):
        self.check_review_mutation(lambda r:r['locales']['de-DE'].__setitem__('resolved_corrections', 0), 'not all resolved')

    def test_ai_mode_needs_explicit_owner_election(self):
        self.check_review_mutation(lambda r:r['review_policy'].pop('selected_by'), 'explicit owner selection')

    def test_unknown_policy_fails(self):
        errors = store.validate(self.german, self.source, registry=self.registry, review_policy='none')
        self.assertTrue(any('unknown review policy' in e for e in errors))

    def test_missing_policy_defaults_to_human(self):
        d = copy.deepcopy(self.german)
        d['review'].pop('ai_source_aware')
        errors = store.validate(d, self.source, release=True, registry={})
        for field in ('native', 'market_search', 'legal_back_translation'):
            self.assertTrue(any(f'release: {field} not verified' in e for e in errors))

    def release_fixture(self):
        """Synthetic evidence only for gate behavior; never written as real review."""
        d = copy.deepcopy(self.german)
        d['production_privacy_url'] = 'https://example.com/privacy'
        d['description'] = d['description'].replace('<privacy policy URL>', d['production_privacy_url'])
        digest = store.content_hash(d)
        registry = copy.deepcopy(self.registry)
        registry['locales']['de-DE']['reviewed_content_sha256'] = digest
        d['review']['evidence'] = {}
        for field in store.RELEASE_EVIDENCE:
            d['review'][field] = 'verified'
            d['review']['evidence'][field] = {'reference': 'synthetic-test-fixture', 'content_sha256': digest}
        return d, registry

    def test_ai_text_policy_does_not_require_false_native_certification(self):
        d, registry = self.release_fixture()
        self.assertEqual(store.validate(d, self.source, release=True, registry=registry), [])
        self.assertNotEqual(d['review']['native'], 'verified')
        human_errors = store.validate(d, self.source, release=True, registry=registry, review_policy='human')
        for field in ('native', 'market_search', 'legal_back_translation'):
            self.assertTrue(any(f'release: {field} not verified' in e for e in human_errors))

    def test_ai_policy_preserves_every_non_text_release_gate(self):
        for field in store.RELEASE_EVIDENCE:
            with self.subTest(field=field):
                d, registry = self.release_fixture()
                d['review'][field] = 'not_verified'
                errors = store.validate(d, self.source, release=True, registry=registry)
                self.assertTrue(any(f'release: {field} not verified' in e for e in errors))

    def test_status_alone_does_not_replace_release_evidence(self):
        d, registry = self.release_fixture()
        del d['review']['evidence']['screenshots']
        errors = store.validate(d, self.source, release=True, registry=registry)
        self.assertTrue(any('screenshots needs a current-content evidence reference' in e for e in errors))

    def test_privacy_url_must_match_description(self):
        d, registry = self.release_fixture()
        d['production_privacy_url'] = 'http://example.com/other'
        errors = store.validate(d, self.source, release=True, registry=registry)
        self.assertTrue(any('production privacy URL must be HTTPS and present' in e for e in errors))

    def test_review_artifacts_are_hash_bound(self):
        registry = copy.deepcopy(self.registry)
        registry['independent_review']['artifacts']['evidence']['sha256'] = '0' * 64
        self.assertIn('review: evidence artifact hash differs', store.review_artifact_errors(registry))

    def test_registry_hash_must_match_independent_review(self):
        registry = copy.deepcopy(self.registry)
        registry['locales']['de-DE']['reviewed_content_sha256'] = '0' * 64
        self.assertTrue(any('hash differs from independent reviewed proposal' in e for e in store.review_artifact_errors(registry)))

    def check_mutation(self, edit, contains):
        d = copy.deepcopy(self.german)
        edit(d)
        self.assertTrue(any(contains in e for e in store.validate(d, self.source)))

    def test_missing_locale_field_fails(self):
        self.check_mutation(lambda d:d.pop('promotional_text'), 'missing promotional_text')

    def test_empty_gc_translation_fails(self):
        self.check_mutation(lambda d:d['game_center_achievement_names'].__setitem__('timbre.badge.first_tune', None), 'missing text')

    def test_field_length_fails(self):
        self.check_mutation(lambda d:d.__setitem__('subtitle', 'a' * 31), 'maximum 30')

    def test_nfc_fails(self):
        self.check_mutation(lambda d:d.__setitem__('subtitle', 'Cafe\u0301'), 'not NFC')

    def test_untranslated_caption_fails(self):
        self.check_mutation(lambda d:d['iphone_screenshot_captions'][0].__setitem__('caption', 'TRANSLATE: Free'), 'unresolved')

    def test_capture_order_fails(self):
        self.check_mutation(lambda d:d['iphone_screenshot_captions'].reverse(), 'capture IDs/order')

    def test_new_caption_digit_fails(self):
        self.check_mutation(lambda d:d['iphone_screenshot_captions'][0].__setitem__('caption', '100 % gratis'), 'new numeric literal')

    def test_missing_current_count_fails(self):
        self.check_mutation(lambda d:d.__setitem__('description',d['description'].replace('526','499')), 'missing current lessons')

    def test_duplicate_keyword_fails(self):
        self.check_mutation(lambda d:d.__setitem__('keywords','Violine,Violine'), 'duplicate term')

    def test_keyword_comma_space_fails(self):
        self.check_mutation(lambda d:d.__setitem__('keywords','Violine, Cello'), 'whitespace beside comma')

    def test_keyword_title_repetition_fails_without_exception(self):
        self.check_mutation(lambda d:d.__setitem__('keywords','Stimmgerät'), 'repeats name/subtitle')

    def test_missing_page_term_fails(self):
        self.check_mutation(lambda d:d['custom_product_page_keywords'].__setitem__('violin',['not-in-field']), 'absent from field')

    def test_missing_preview_clip_fails(self):
        self.check_mutation(lambda d:d['app_preview_captions']['main'].pop('lock'), 'clip inventory differs')

    def test_iap_description_limit_fails(self):
        self.check_mutation(lambda d:d['iap_descriptions'].__setitem__('timbre_pro_annual','a'*46), '> 45')

    def test_english_fallback_not_translation(self):
        self.check_mutation(lambda d:d.__setitem__('description',self.source['description']), 'copied English source')

    def test_eula_link_preserved(self):
        self.check_mutation(lambda d:d.__setitem__('description',d['description'].replace(store.EULA,'https://example.com/terms')), 'missing unchanged standard EULA')

    def test_claimed_ready_does_not_bypass_evidence(self):
        self.check_mutation(lambda d:d['review'].__setitem__('release_ready',True), 'release:')

    def test_unknown_numeric_claim_fails(self):
        self.check_mutation(lambda d:d.__setitem__('description',d['description']+' 999'), 'unsupported numeric literals')

    def test_game_center_threshold_fails(self):
        self.check_mutation(lambda d:d['game_center_achievement_descriptions'].__setitem__('timbre.badge.lessons_25','Finish 24 lessons'), 'numeric threshold missing')

    def test_all_preview_caption_reads(self):
        sys.path.insert(0,str(ROOT/'tools/marketing'))
        import preview
        for row in self.inventory:
            data=store.load(row['locale'])
            for cut,key in [(None,'main'),('violin','violin')]:
                actual=preview.captions(cut, row['locale'])
                self.assertEqual({k:v[0] for k,v in actual.items()},data['app_preview_captions'][key])

    def test_all_localized_renderer_captures_and_looks(self):
        spec=importlib.util.spec_from_file_location('store_test_screenshots',ROOT/'tools/marketing/screenshots.py')
        shots=importlib.util.module_from_spec(spec);spec.loader.exec_module(shots)
        self.assertEqual(len(shots.LOCALES),49)
        for row in self.inventory:
            for device in ('iphone','ipad'):
                rendered=shots.plan(device,locale=row['locale'])
                self.assertEqual([r[0] for r in rendered],[r[0] for r in shots.plan(device)])
                self.assertEqual([r[3] for r in rendered],[r[3] for r in shots.plan(device)])
        with self.assertRaises(ValueError):shots.plan('iphone',page='violin',locale='de-DE')


if __name__=='__main__':unittest.main()
