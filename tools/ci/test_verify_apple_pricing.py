import copy
import hashlib
import json
from pathlib import Path
import tempfile
import unittest

from apple_pricing_transport import EvidenceError
import test_collect_apple_pricing as fixtures
from verify_apple_pricing import load_targets, verify


class VerificationTests(unittest.TestCase):
    def setUp(self):
        self.evidence = fixtures.CollectorTests().run_fixture(fixtures.fixture())
        self.policy = {'territories': [{'public_storefront_country_code': 'US', 'income_group': 'high_income', 'territory_code': 'USA'}]}
        self.targets = {'schema_version': 1, 'bundle_id': self.evidence['bundle_id'], 'app_id': 'app',
            'approval_reference': 'synthetic fixture approval, not an owner decision',
            'source_policy_sha256': 'f' * 64,
            'territories': [{'public_country_code': 'US', 'apple_territory_id': 'USA', 'currency': 'USD'}],
            'products': {role: {'apple_id': role, 'product_id': product['product_id'],
                'plan_type': 'UPFRONT' if role != 'lifetime' else None,
                'prices': {'USA': [{'start_date': None, 'end_date': None,
                    'price_point_id': role + '-point' if role != 'lifetime' else 'life-point',
                    'customer_price': '1.99' if role != 'lifetime' else '9.99', 'currency': 'USD'}]}}
                for role, product in self.evidence['products'].items()}}

    def result(self):
        return verify(self.evidence, self.targets, self.policy, '2026-10-28')

    def test_exact_fixture_match_is_correspondence_only_not_live_or_release_proof(self):
        self.assertEqual(self.result(), [])
        self.assertIn('fixture', self.evidence['origin'])

    def test_approval_hash_is_external_and_tampering_is_rejected(self):
        with tempfile.TemporaryDirectory() as folder:
            path = Path(folder) / 'targets.json'
            raw = json.dumps(self.targets).encode(); path.write_bytes(raw)
            self.assertEqual(load_targets(path, hashlib.sha256(raw).hexdigest()), self.targets)
            with self.assertRaises(EvidenceError): load_targets(path, '0' * 64)
            with self.assertRaises(EvidenceError): load_targets(path, '')
            path.write_text('{}')
            with self.assertRaises(EvidenceError): load_targets(path, hashlib.sha256(raw).hexdigest())
            duplicate = b'{"schema_version":1,"schema_version":2}'
            path.write_bytes(duplicate)
            with self.assertRaises(EvidenceError): load_targets(path, hashlib.sha256(duplicate).hexdigest())

    def test_decimal_value_comparison_is_exact_without_float_rounding(self):
        self.targets['products']['monthly']['prices']['USA'][0]['customer_price'] = '1.9900'
        self.assertEqual(self.result(), [])
        self.targets['products']['monthly']['prices']['USA'][0]['customer_price'] = '1.9900000000000001'
        self.assertTrue(self.result())

    def test_currency_amount_and_point_mismatch_fail(self):
        for field, value in [('currency', 'CAD'), ('customer_price', '2.99'), ('price_point_id', 'foreign'),
                             ('customer_price', 1.99), ('customer_price', 'NaN')]:
            original = copy.deepcopy(self.targets)
            self.targets['products']['monthly']['prices']['USA'][0][field] = value
            with self.subTest(field=field, value=value): self.assertTrue(self.result())
            self.targets = original

    def test_missing_or_foreign_country_product_app_and_approval_fail(self):
        mutations = [lambda t: t.update(app_id='foreign'), lambda t: t.update(approval_reference=''),
                     lambda t: t['products']['monthly'].update(apple_id='foreign'),
                     lambda t: t['products']['monthly'].update(product_id='foreign'),
                     lambda t: t.update(territories=[]),
                     lambda t: t['territories'].append(copy.deepcopy(t['territories'][0]))]
        for mutate in mutations:
            original = copy.deepcopy(self.targets); mutate(self.targets)
            with self.subTest(mutate=mutate): self.assertTrue(self.result())
            self.targets = original

    def test_unavailable_app_or_product_cannot_pass(self):
        self.evidence['app_availability']['USA']['available'] = False
        self.assertTrue(self.result())
        self.evidence['app_availability']['USA']['available'] = True
        self.evidence['products']['annual']['plans'][0]['territories'] = []
        self.assertTrue(self.result())

    def test_preserved_prices_remain_separate_and_do_not_set_acquisition_price(self):
        row = copy.deepcopy(self.evidence['products']['monthly']['prices'][0])
        row['schedule_attributes']['preserved'] = True; row['customer_price'] = '0.99'
        self.evidence['products']['monthly']['prices'].append(row)
        self.assertEqual(self.result(), [])
        self.evidence['products']['monthly']['prices'].pop(0)
        self.assertTrue(self.result())

    def test_all_future_price_changes_require_exact_approved_intervals(self):
        row = copy.deepcopy(self.evidence['products']['monthly']['prices'][0])
        row['apple_price_id'] = 'future'; row['schedule_attributes']['startDate'] = '2027-01-01'
        row['customer_price'] = '2.99'; row['price_point_id'] = 'future-point'
        self.evidence['products']['monthly']['prices'].append(row)
        self.assertTrue(self.result())
        plan = self.targets['products']['monthly']['prices']['USA']
        plan[0]['end_date'] = '2027-01-01'
        plan.append({'start_date': '2027-01-01', 'end_date': None, 'customer_price': '2.99',
                     'currency': 'USD', 'price_point_id': 'future-point'})
        self.assertEqual(self.result(), [])

    def test_overlaps_gaps_and_missing_current_or_terminal_prices_fail(self):
        for start, end in [('2027-01-01', None), (None, '2027-01-01'),
                           ('2026-12-01', '2026-11-01')]:
            original = copy.deepcopy(self.targets)
            self.targets['products']['lifetime']['prices']['USA'][0].update(start_date=start, end_date=end)
            with self.subTest(start=start, end=end): self.assertTrue(self.result())
            self.targets = original
        row = copy.deepcopy(self.evidence['products']['lifetime']['prices'][0])
        row['apple_price_id'] = 'overlap'
        self.evidence['products']['lifetime']['prices'].append(row)
        self.assertTrue(self.result())

    def test_unclassified_country_needs_an_explicit_manual_decision(self):
        self.policy['territories'][0]['income_group'] = None
        self.assertTrue(self.result())
        self.targets['territories'][0]['manual_income_decision'] = 'synthetic country-specific review reference'
        self.assertEqual(self.result(), [])

    def test_unknown_plan_type_missing_preserved_flag_and_bad_date_fail(self):
        row = self.evidence['products']['monthly']['prices'][0]['schedule_attributes']
        row['planType'] = 'UNKNOWN'; self.assertTrue(self.result()); row['planType'] = 'UPFRONT'
        del row['preserved']; self.assertTrue(self.result()); row['preserved'] = False
        row['startDate'] = '2026-99-99'; self.assertTrue(self.result())

    def test_exact_matches_still_need_coherent_product_ordering(self):
        for role, amount in [('annual', '99.99'), ('lifetime', '0.99')]:
            original_evidence, original_targets = copy.deepcopy(self.evidence), copy.deepcopy(self.targets)
            self.evidence['products'][role]['prices'][0]['customer_price'] = amount
            self.targets['products'][role]['prices']['USA'][0]['customer_price'] = amount
            with self.subTest(role=role): self.assertTrue(self.result())
            self.evidence, self.targets = original_evidence, original_targets

    def test_same_count_country_territory_swap_cannot_validate_wrong_countries(self):
        self.policy['territories'].append({'public_storefront_country_code': 'CA', 'income_group': 'high_income', 'territory_code': 'CAN'})
        self.evidence['currencies']['CAN'] = 'CAD'
        self.evidence['app_availability']['CAN'] = {'available': True}
        for role, product in self.evidence['products'].items():
            if role == 'lifetime': product['territories'].append('CAN')
            else: product['plans'][0]['territories'].append('CAN')
            row = copy.deepcopy(product['prices'][0])
            row.update(territory='CAN', currency='CAD', price_point_id=role + '-CAN')
            product['prices'].append(row)
            approved = copy.deepcopy(self.targets['products'][role]['prices']['USA'])
            approved[0].update(currency='CAD', price_point_id=role + '-CAN')
            self.targets['products'][role]['prices']['CAN'] = approved
        self.targets['territories'] = [
            {'public_country_code': 'US', 'apple_territory_id': 'CAN', 'currency': 'CAD'},
            {'public_country_code': 'CA', 'apple_territory_id': 'USA', 'currency': 'USD'}]
        self.assertTrue(self.result())

    def test_unresolved_country_mapping_requires_a_reviewed_reference(self):
        self.policy['territories'][0]['territory_code'] = None
        self.assertTrue(self.result())
        self.targets['territories'][0]['mapping_evidence_reference'] = 'synthetic reviewed mapping receipt'
        self.assertEqual(self.result(), [])


if __name__ == '__main__':
    unittest.main()
