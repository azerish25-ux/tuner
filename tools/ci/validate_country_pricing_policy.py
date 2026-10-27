#!/usr/bin/env python3
"""Validate a proposed country pricing policy; incomplete coverage never passes release mode."""
import argparse
import hashlib
import json
import re
from decimal import Decimal, InvalidOperation
from pathlib import Path
from urllib.parse import urlparse

ROOT = Path(__file__).resolve().parents[2]
DEFAULT_POLICY = ROOT / 'docs/ios/readiness/pricing/country-pricing-policy.json'
ROLES = {'monthly', 'annual', 'lifetime'}
GROUPS = ['low_income', 'lower_middle_income', 'upper_middle_income', 'high_income']


def validate(policy, require_complete=False):
    """Malformed input fails closed; this proposal schema cannot certify live schedules."""
    try:
        return _validate(policy, require_complete)
    except (AttributeError, KeyError, TypeError, ValueError, InvalidOperation):
        return ['malformed pricing policy']


def amount(value):
    if not isinstance(value, str) or not re.fullmatch(r'[0-9]+(?:\.[0-9]+)?', value):
        raise ValueError('prices and factors must be decimal strings')
    parsed = Decimal(value)
    if not parsed.is_finite() or parsed <= 0:
        raise ValueError('prices must be positive and finite')
    return parsed


def _validate(policy, require_complete=False):
    errors = []
    def check(condition, message):
        if not condition:
            errors.append(message)
    check(type(policy.get('schema_version')) is int and policy.get('schema_version') == 2, 'unsupported schema')
    check(policy.get('as_of') == '2026-10-27', 'unsupported policy evidence date')
    check(policy.get('price_selection_basis') == 'app_store_storefront', 'prices must follow storefront')
    check(policy.get('language_selects_price') is False, 'language must not select price')
    check(policy.get('release_ready') is False, 'pricing research cannot promote release readiness')
    check(policy.get('status') == 'proposed_public_inventory_complete_pricing_unverified', 'only an unconfigured proposal is supported')
    check(policy.get('configured_in_app_store_connect') is False, 'proposal cannot claim live configuration')
    sources = policy.get('sources', {})
    for source in sources.values():
        url = urlparse(source.get('url', ''))
        check(url.scheme == 'https' and url.hostname in {'developer.apple.com', 'apps.apple.com', 'datahelpdesk.worldbank.org', 'api.worldbank.org', 'support.apple.com'},
              'source must be a recognized primary-source HTTPS URL')
        check(re.fullmatch(r'\d{4}-\d{2}-\d{2}', source.get('checked_on', '')) is not None, 'source check date missing')
    check('world_bank_fy2027' in sources and 'apple_availability' in sources, 'missing primary sources')
    income = policy.get('income_group_policy', {})
    multipliers = income.get('multipliers', {})
    try:
        values = [amount(multipliers[g]) for g in GROUPS]
        check(all(v.is_finite() and 0 < v <= 1 for v in values), 'invalid affordability factor')
        check(all(a < b for a, b in zip(values, values[1:])), 'income bands must have increasing factors')
    except (KeyError, TypeError, InvalidOperation):
        errors.append('missing or invalid income multipliers')
    check(income.get('unclassified_policy') == 'manual_review_no_price_assigned', 'unclassified countries require manual review')
    products = policy.get('products', {})
    check(set(products) == ROLES, 'all three product roles required')
    check(all(p.get('entitlement') == 'Pro' for p in products.values()), 'products must grant the same Pro scope')
    check(products.get('lifetime', {}).get('type') == 'non_consumable', 'lifetime must be non-consumable')
    expected_ids = {'monthly': 'timbre_pro_monthly', 'annual': 'timbre_pro_annual', 'lifetime': 'timbre_plus_lifetime'}
    for role, product in products.items():
        check(product.get('id') == expected_ids.get(role), 'product ID differs from shipping product')
        expected_type = 'non_consumable' if role == 'lifetime' else 'auto_renewable_subscription'
        check(product.get('type') == expected_type, 'incorrect product type')
    anchors = policy.get('proposed_anchor_prices', {})
    check(set(anchors) == {'USA', 'CAN'}, 'both proposed anchors required')
    for code, anchor in anchors.items():
        check(anchor.get('currency') == {'USA': 'USD', 'CAN': 'CAD'}.get(code), 'anchor currency mismatch')
        check(re.fullmatch(r'[A-Z]{3}', code) is not None, 'anchor is not a territory code')
        try:
            month, annual, life = [amount(anchor[k]) for k in ['monthly', 'annual', 'lifetime']]
            check(all(v.is_finite() and v > 0 for v in [month, annual, life]), 'anchor must be positive')
            check(annual < month * 12 and life > annual, 'anchor product ordering invalid')
        except (KeyError, TypeError, InvalidOperation):
            errors.append('invalid anchor amounts')
        check(anchor.get('apple_price_points_verified') is False, 'proposal anchor cannot claim verified Apple points')
    territories = policy.get('territories', [])
    codes = [r.get('public_storefront_country_code') for r in territories]
    check(len(set(codes)) == len(codes), 'duplicate public storefront')
    check(all(isinstance(c, str) and re.fullmatch(r'[A-Z]{2}', c) for c in codes), 'invalid public country code; never use locale keys')
    evidence = policy.get('evidence', {})
    evidence_name = 'source-data/public-country-income-evidence-2026-10-27.json'
    check(evidence.get('path') == evidence_name, 'unexpected evidence path')
    try:
        raw = (DEFAULT_POLICY.parent / evidence_name).read_bytes()
        check(hashlib.sha256(raw).hexdigest() == evidence.get('sha256'), 'country evidence hash mismatch')
        snapshot = json.loads(raw)
        check(snapshot.get('as_of') == policy.get('as_of'), 'policy and evidence dates differ')
        check(snapshot.get('status') == 'public_country_inventory_and_income_evidence_not_live_product_configuration', 'unsupported evidence status')
        source_rows = snapshot['countries']
        source_codes = [r['public_storefront_country_code'] for r in source_rows]
        check(len(source_codes) == len(set(source_codes)) == 175, 'invalid source public inventory')
        check(set(codes) == set(source_codes), 'policy country set differs from verified public inventory')
        source_by_code = {r['public_storefront_country_code']: r for r in source_rows}
        group_names = {'HIC': 'high_income', 'UMC': 'upper_middle_income', 'LMC': 'lower_middle_income', 'LIC': 'low_income'}
        for row in territories:
            source = source_by_code.get(row.get('public_storefront_country_code'), {})
            check(row.get('name') == source.get('apple_public_name'), 'country name differs from evidence')
            check(row.get('income_group') == group_names.get(source.get('income_group_id')), 'income classification differs from evidence')
            check(row.get('income_group_source') == source.get('income_group_source'), 'classification source differs from evidence')
            check(row.get('territory_code') == source.get('apple_territory_code_candidate'), 'unverified Apple territory code override')
    except (OSError, ValueError, KeyError, TypeError) as exc:
        errors.append('country evidence unavailable or invalid: ' + str(exc))
    coverage = policy.get('coverage', {})
    check(coverage.get('mapped_country_count') == len(territories), 'coverage count mismatch')
    check(type(coverage.get('mapped_country_count')) is int, 'mapped count must be an integer')
    check(type(coverage.get('expected_storefront_count')) is int and coverage['expected_storefront_count'] > 0,
          'expected storefront count must be positive')
    check(coverage.get('expected_count_source') in sources, 'missing territory count source')
    check(isinstance(coverage.get('complete'), bool), 'complete must be an explicit boolean')
    check(bool(territories), 'country examples must not be empty')
    check(coverage.get('expected_storefront_count') == 175, 'expected count must match verified public inventory, not enum size')
    classified = [r for r in territories if r.get('income_group') in GROUPS]
    manual = sorted(r.get('public_storefront_country_code') for r in territories if r.get('income_group') not in GROUPS)
    check(coverage.get('classified_country_count') == len(classified), 'classified count mismatch')
    check(coverage.get('manual_review_country_codes') == manual, 'manual-review inventory mismatch')
    check(coverage.get('classification_complete') is (not manual), 'classification completeness is incorrect')
    check(coverage.get('public_inventory_complete') is True, 'public inventory is not verified complete')
    for field in ('authenticated_app_availability_verified', 'supported_price_points_verified'):
        check(coverage.get(field) is False, 'proposal coverage cannot claim verification: ' + field)
    complete = coverage.get('complete') is True
    for row in territories:
        group = row.get('income_group')
        if group in GROUPS:
            check(row.get('income_group_source') in sources, 'missing classification source')
            check(row.get('affordability_multiplier') == multipliers.get(group), 'country multiplier differs from income band')
        else:
            check(row.get('status') == 'manual_review' and row.get('affordability_multiplier') is None, 'unclassified country must be explicit manual review')
        check(set(row.get('prices', {})) == ROLES, 'territory missing price roles')
        check(set(row.get('apple_price_point_ids', {})) == ROLES, 'territory missing price point roles')
        currency = row.get('currency')
        check(currency is None or (isinstance(currency, str) and re.fullmatch(r'[A-Z]{3}', currency)), 'invalid currency')
        prices = row.get('prices', {})
        for value in prices.values():
            if value is not None:
                amount(value)
        if all(prices.get(k) is not None for k in ROLES):
            check(amount(prices['annual']) < 12 * amount(prices['monthly']) and
                  amount(prices['lifetime']) > amount(prices['annual']), 'territory product ordering invalid')
        for point in row.get('apple_price_point_ids', {}).values():
            check(point is None or (isinstance(point, str) and bool(point.strip())), 'invalid Apple price point ID')
        for field in ('apple_territory_verified', 'authenticated_app_availability_verified'):
            check(row.get(field) is False, 'proposal country cannot claim verification: ' + field)
        expected_status = 'proposed_requires_territory_and_price_point_verification' if group in GROUPS else 'manual_review'
        check(row.get('status') == expected_status, 'unsupported country proposal status')
        check(row.get('public_app_store_availability_verified') is True, 'public availability evidence missing')
        if row.get('currency') is None:
            check(all(v is None for v in row.get('prices', {}).values()), 'cannot assign local amounts without currency')
        if group not in GROUPS:
            check(all(v is None for v in row.get('prices', {}).values()), 'unclassified country cannot receive inferred prices')
    if complete or require_complete:
        # A hand-edited count/boolean/ID is not independent evidence. Until an importer and
        # source-bound price-point verifier exist, this research artifact must never certify coverage.
        errors.append('independent active-territory and Apple price-point evidence verifier is not implemented')
        check(complete, 'pricing verification is incomplete')
        check(coverage.get('classification_complete') is True, 'country income review unresolved')
        check(coverage.get('authenticated_app_availability_verified') is True, 'authenticated app availability unverified')
        check(coverage.get('supported_price_points_verified') is True, 'supported price point verification incomplete')
        check(policy.get('configured_in_app_store_connect') is True, 'live pricing configuration unverified')
        check(len(territories) == coverage.get('expected_storefront_count'), 'full Apple territory coverage not established')
        check(all(r.get('apple_territory_verified') is True and r.get('territory_code') and r.get('authenticated_app_availability_verified') is True for r in territories), 'authenticated Apple territory and product availability verification missing')
        check(all(r.get('currency') and all(r.get('apple_price_point_ids', {}).get(k) for k in ROLES) and all(r.get('prices', {}).get(k) for k in ROLES) for r in territories), 'supported local prices and Apple price point IDs missing')
    return errors


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--policy', type=Path, default=DEFAULT_POLICY)
    parser.add_argument('--require-complete', action='store_true')
    args = parser.parse_args()
    try:
        policy = json.loads(args.policy.read_text())
        errors = validate(policy, args.require_complete)
    except (OSError, ValueError, TypeError, AttributeError) as exc:
        errors = [str(exc)]
    if errors:
        print('\n'.join('ERROR: ' + e for e in errors))
        return 1
    print('Structure valid. PUBLIC COUNTRY INVENTORY: 175. PROPOSED PRICING ONLY: income exceptions and live Apple pricing remain unverified.' if not policy['coverage']['complete'] else 'Policy structure valid; independently verify live configuration before release.')
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
