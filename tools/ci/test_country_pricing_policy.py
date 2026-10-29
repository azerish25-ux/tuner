#!/usr/bin/env python3
import copy
import json
import unittest
from validate_country_pricing_policy import DEFAULT_POLICY, validate


class CountryPricingPolicyTests(unittest.TestCase):
    def setUp(self):
        self.policy = json.loads(DEFAULT_POLICY.read_text())

    def test_provisional_structure(self):
        self.assertEqual(validate(self.policy), [])

    def test_release_coverage_gate_stays_blocked(self):
        self.assertIn('pricing verification is incomplete', validate(self.policy, require_complete=True))

    def test_language_cannot_select_price(self):
        self.policy['language_selects_price'] = True
        self.assertTrue(validate(self.policy))

    def test_locale_key_rejected(self):
        self.policy['territories'][0]['public_storefront_country_code'] = 'en-US'
        self.assertTrue(validate(self.policy))

    def test_duplicate_territory_rejected(self):
        self.policy['territories'].append(copy.deepcopy(self.policy['territories'][0]))
        self.assertTrue(validate(self.policy))

    def test_poorer_band_cannot_cost_more(self):
        self.policy['income_group_policy']['multipliers']['low_income'] = '1.00'
        self.assertTrue(validate(self.policy))

    def test_unclassified_cannot_default_to_high(self):
        row = self.policy['territories'][0]
        row['income_group'] = 'unknown'
        self.assertTrue(validate(self.policy))

    def test_no_currency_no_amount(self):
        self.policy['territories'][0]['prices']['monthly'] = '1.99'
        self.assertTrue(validate(self.policy))

    def test_false_complete_cannot_pass(self):
        self.policy['coverage']['complete'] = True
        self.assertTrue(validate(self.policy))

    def test_research_cannot_promote_release(self):
        self.policy['release_ready'] = True
        self.assertTrue(validate(self.policy))

    def test_lifetime_same_pro_nonconsumable(self):
        self.policy['products']['lifetime']['entitlement'] = 'Plus'
        self.assertTrue(validate(self.policy))

    def test_configured_claim_is_rejected(self):
        self.policy['configured_in_app_store_connect'] = True
        self.assertTrue(validate(self.policy))

    def test_wrong_product_ids_and_types_rejected(self):
        for field, value in [('id', 'different_product'), ('type', 'consumable')]:
            with self.subTest(field=field):
                bad = copy.deepcopy(self.policy)
                bad['products']['monthly'][field] = value
                self.assertTrue(validate(bad))

    def test_anchor_currency_and_missing_anchor_rejected(self):
        self.policy['proposed_anchor_prices']['CAN']['currency'] = 'USD'
        self.assertTrue(validate(self.policy))
        self.policy['proposed_anchor_prices'] = {}
        self.assertTrue(validate(self.policy))

    def test_invalid_local_amounts_fail_closed(self):
        for value in ['0', '-1', 'NaN', 'Infinity', 'garbage', True, 1.99]:
            with self.subTest(value=value):
                bad = copy.deepcopy(self.policy)
                bad['territories'][0]['currency'] = 'USD'
                bad['territories'][0]['prices']['monthly'] = value
                self.assertTrue(validate(bad))

    def test_invalid_currency_and_price_point_rejected(self):
        row = self.policy['territories'][0]
        row['currency'] = 'en-US'
        self.assertTrue(validate(self.policy))
        row['currency'] = 'USD'
        row['apple_price_point_ids']['monthly'] = True
        self.assertTrue(validate(self.policy))

    def test_complete_empty_inventory_is_not_vacuously_valid(self):
        self.policy['territories'] = []
        self.policy['coverage'].update(complete=True, mapped_country_count=0, expected_storefront_count=0)
        self.assertTrue(validate(self.policy, require_complete=True))

    def test_fabricated_complete_flags_do_not_replace_evidence(self):
        self.policy['coverage'].update(complete=True, expected_storefront_count=len(self.policy['territories']))
        for row in self.policy['territories']:
            row.update(apple_territory_verified=True, currency='USD')
            row['prices'] = {'monthly': '3.99', 'annual': '19.99', 'lifetime': '59.99'}
            row['apple_price_point_ids'] = {k: 'invented-' + k for k in row['prices']}
        errors = validate(self.policy, require_complete=True)
        self.assertIn('proposal schema cannot certify live pricing; use the separate fresh Apple evidence verifier', errors)

    def test_malformed_shapes_fail_closed_without_exception(self):
        for value in [None, [], True, 'policy', {'territories': [None]}, {'sources': []}]:
            with self.subTest(value=value):
                self.assertTrue(validate(value))

    def test_primary_source_url_required(self):
        self.policy['sources']['world_bank_fy2027']['url'] = 'https://example.com/classifications'
        self.assertTrue(validate(self.policy))

    def test_enum_count_is_not_public_inventory(self):
        self.policy['coverage']['expected_storefront_count'] = 233
        self.assertTrue(validate(self.policy))

    def test_matching_count_wrong_country_rejected(self):
        self.policy['territories'][0]['public_storefront_country_code'] = 'ZZ'
        self.assertTrue(validate(self.policy))

    def test_evidence_hash_tampering_rejected(self):
        self.policy['evidence']['sha256'] = '0' * 64
        self.assertTrue(validate(self.policy))

    def test_income_override_rejected(self):
        row = next(r for r in self.policy['territories'] if r['public_storefront_country_code'] == 'IN')
        row['income_group'] = 'high_income'
        row['affordability_multiplier'] = '1.00'
        self.assertTrue(validate(self.policy))

    def test_kosovo_api_id_not_invented(self):
        row = next(r for r in self.policy['territories'] if r['public_storefront_country_code'] == 'XK')
        self.assertIsNone(row['territory_code'])
        row['territory_code'] = 'XKX'
        self.assertTrue(validate(self.policy))

    def test_taiwan_uses_own_explicit_source(self):
        row = next(r for r in self.policy['territories'] if r['public_storefront_country_code'] == 'TW')
        self.assertEqual(row['income_group'], 'high_income')
        self.assertEqual(row['income_group_source'], 'world_bank_fy2027_table')

    def test_two_manual_exceptions_never_default_high(self):
        rows = [r for r in self.policy['territories'] if r['status'] == 'manual_review']
        self.assertEqual({r['public_storefront_country_code'] for r in rows}, {'AI', 'MS'})
        self.assertTrue(all(r['income_group'] is None and r['affordability_multiplier'] is None for r in rows))

    def test_unverified_coverage_claims_must_remain_false(self):
        for field in ('authenticated_app_availability_verified', 'supported_price_points_verified'):
            for value in (True, None, 0, 'false'):
                with self.subTest(field=field, value=value):
                    bad = copy.deepcopy(self.policy)
                    bad['coverage'][field] = value
                    self.assertIn('proposal coverage cannot claim verification: ' + field, validate(bad))

    def test_unverified_country_claims_must_remain_false(self):
        for field in ('apple_territory_verified', 'authenticated_app_availability_verified'):
            for value in (True, None, 0, 'false'):
                with self.subTest(field=field, value=value):
                    bad = copy.deepcopy(self.policy)
                    bad['territories'][0][field] = value
                    self.assertIn('proposal country cannot claim verification: ' + field, validate(bad))

    def test_unsupported_status_and_date_rejected(self):
        for field, value in [('status', 'ready'), ('as_of', '2026-10-28'), ('as_of', None)]:
            with self.subTest(field=field, value=value):
                bad = copy.deepcopy(self.policy)
                bad[field] = value
                self.assertTrue(validate(bad))
        self.policy['territories'][0]['status'] = 'verified'
        self.assertIn('unsupported country proposal status', validate(self.policy))

    def test_local_anchors_are_explicit_currency(self):
        anchors = self.policy['proposed_anchor_prices']
        self.assertEqual(anchors['USA']['currency'], 'USD')
        self.assertEqual(anchors['CAN']['currency'], 'CAD')


if __name__ == '__main__':
    unittest.main()
