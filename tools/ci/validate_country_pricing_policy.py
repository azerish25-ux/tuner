#!/usr/bin/env python3
"""Validate a proposed country pricing policy; incomplete coverage never passes release mode."""
import argparse
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
    check(type(policy.get('schema_version')) is int and policy.get('schema_version') == 1, 'unsupported schema')
    check(policy.get('price_selection_basis') == 'app_store_storefront', 'prices must follow storefront')
    check(policy.get('language_selects_price') is False, 'language must not select price')
    check(policy.get('release_ready') is False, 'pricing research cannot promote release readiness')
    check(policy.get('status') == 'proposed_incomplete_not_configured', 'only an unconfigured proposal is supported')
    check(policy.get('configured_in_app_store_connect') is False, 'proposal cannot claim live configuration')
    sources = policy.get('sources', {})
    for source in sources.values():
        url = urlparse(source.get('url', ''))
        check(url.scheme == 'https' and url.hostname in {'developer.apple.com', 'apps.apple.com', 'datahelpdesk.worldbank.org'},
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
    codes = [r.get('territory_code') for r in territories]
    check(len(set(codes)) == len(codes), 'duplicate territory')
    check(all(isinstance(c, str) and re.fullmatch(r'[A-Z]{3}', c) for c in codes), 'invalid territory code; never use locale keys')
    coverage = policy.get('coverage', {})
    check(coverage.get('mapped_country_count') == len(territories), 'coverage count mismatch')
    check(type(coverage.get('mapped_country_count')) is int, 'mapped count must be an integer')
    check(type(coverage.get('expected_storefront_count')) is int and coverage['expected_storefront_count'] > 0,
          'expected storefront count must be positive')
    check(coverage.get('expected_count_source') in sources, 'missing territory count source')
    check(isinstance(coverage.get('complete'), bool), 'complete must be an explicit boolean')
    check(bool(territories), 'country examples must not be empty')
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
        check(isinstance(row.get('apple_territory_verified'), bool), 'territory verification must be explicit')
        if row.get('currency') is None:
            check(all(v is None for v in row.get('prices', {}).values()), 'cannot assign local amounts without currency')
        if group not in GROUPS:
            check(all(v is None for v in row.get('prices', {}).values()), 'unclassified country cannot receive inferred prices')
    if complete or require_complete:
        # A hand-edited count/boolean/ID is not independent evidence. Until an importer and
        # source-bound price-point verifier exist, this research artifact must never certify coverage.
        errors.append('independent active-territory and Apple price-point evidence verifier is not implemented')
        check(complete, 'country inventory is incomplete')
        check(len(territories) == coverage.get('expected_storefront_count'), 'full Apple territory coverage not established')
        check(all(r.get('apple_territory_verified') is True for r in territories), 'active Apple territory verification missing')
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
    print('Structure valid. PROPOSED ONLY: country coverage and live Apple pricing remain unverified.' if not policy['coverage']['complete'] else 'Policy structure valid; independently verify live configuration before release.')
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
