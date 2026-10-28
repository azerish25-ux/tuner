#!/usr/bin/env python3
"""Compare fresh read-only Apple pricing evidence with an externally approved manifest.

This is a scoped pricing comparison, never an App Store submission certificate.
The CLI has no offline evidence import: JSON hashes cannot authenticate an API response.
"""
import argparse
from datetime import date
from decimal import localcontext
import hashlib
import json
import os
from pathlib import Path
import re

from apple_pricing_transport import AppleClient, EvidenceError, unique_object
from collect_apple_pricing import BUNDLE_ID, PRODUCTS, collect, decimal_price
from validate_country_pricing_policy import DEFAULT_POLICY, GROUPS, validate as validate_proposal


def load_targets(path, approved_sha256):
    if not isinstance(approved_sha256, str) or not re.fullmatch('[0-9a-f]{64}', approved_sha256):
        raise EvidenceError('Expected target hash must come from a separate owner-approved checkpoint')
    raw = Path(path).read_bytes()
    if hashlib.sha256(raw).hexdigest() != approved_sha256:
        raise EvidenceError('Target manifest differs from the externally approved hash')
    value = json.loads(raw, object_pairs_hook=unique_object)
    if not isinstance(value, dict):
        raise EvidenceError('Target manifest must be an object')
    return value


def _date(value, empty):
    if value is None:
        return empty
    if not isinstance(value, str) or not re.fullmatch(r'\d{4}-\d{2}-\d{2}', value):
        raise EvidenceError('Schedule dates must be explicit ISO dates or null')
    try:
        return date.fromisoformat(value)
    except ValueError:
        raise EvidenceError('Invalid schedule date') from None


def _canonical(intervals, as_of):
    """Compare active and every future interval, retaining source dates in the original evidence."""
    ordered = sorted(intervals, key=lambda row: row[0])
    current = []
    for start, end, point, amount, currency in ordered:
        if start >= end:
            raise EvidenceError('Reversed or empty price interval')
        if end <= as_of:
            continue
        if not isinstance(point, str) or not point or not isinstance(currency, str) or not re.fullmatch('[A-Z]{3}', currency):
            raise EvidenceError('Missing price point or currency')
        amount = decimal_price(amount)
        if amount <= 0:
            raise EvidenceError('Paid shipping products require positive approved prices')
        current.append((max(start, as_of), end, point, amount, currency))
    if not current or current[0][0] != as_of or current[-1][1] != date.max:
        raise EvidenceError('Current price or unbounded terminal schedule is missing')
    if any(left[1] != right[0] for left, right in zip(current, current[1:])):
        raise EvidenceError('Price schedule has a gap or overlap')
    return current


def _actual(product, role, territory, as_of):
    rows = [row for row in product['prices'] if row['territory'] == territory]
    intervals = []
    if role == 'lifetime':
        for row in rows:
            attributes = row['schedule_attributes']
            if type(attributes.get('manual')) is not bool or 'startDate' not in attributes or 'endDate' not in attributes:
                raise EvidenceError('Incomplete IAP interval provenance')
            intervals.append((_date(attributes['startDate'], date.min), _date(attributes['endDate'], date.max),
                              row['price_point_id'], row['customer_price'], row['currency']))
    else:
        standard = []
        for row in rows:
            attributes = row['schedule_attributes']
            if type(attributes.get('preserved')) is not bool or 'startDate' not in attributes:
                raise EvidenceError('Incomplete subscription schedule provenance')
            if attributes.get('planType') != 'UPFRONT':
                raise EvidenceError('Unsupported subscription plan type')
            start = _date(attributes['startDate'], date.min)
            if not attributes['preserved']:
                standard.append((start, row))
        standard.sort(key=lambda pair: pair[0])
        if len({start for start, _ in standard}) != len(standard):
            raise EvidenceError('Ambiguous subscription acquisition prices with equal start dates')
        for index, (start, row) in enumerate(standard):
            end = standard[index + 1][0] if index + 1 < len(standard) else date.max
            intervals.append((start, end, row['price_point_id'], row['customer_price'], row['currency']))
    return _canonical(intervals, as_of)


def _targets(rows, as_of):
    fields = {'start_date', 'end_date', 'price_point_id', 'customer_price', 'currency'}
    if not isinstance(rows, list) or any(not isinstance(row, dict) or set(row) != fields for row in rows):
        raise EvidenceError('Malformed approved price intervals')
    return _canonical([(_date(row['start_date'], date.min), _date(row['end_date'], date.max),
                        row['price_point_id'], row['customer_price'], row['currency']) for row in rows], as_of)


def verify(evidence, targets, policy, as_of):
    """Pure correspondence check. Passing fixture/offline input cannot establish authenticated origin."""
    try:
        return _verify(evidence, targets, policy, as_of)
    except (EvidenceError, KeyError, TypeError, AttributeError, ValueError) as error:
        return ['Invalid or incomplete pricing evidence: ' + str(error)]


def _verify(evidence, targets, policy, as_of):
    evaluated = _date(as_of, None)
    if evaluated is None:
        raise EvidenceError('An explicit evaluation date is required')
    errors = []
    def check(condition, message):
        if not condition:
            errors.append(message)
    check(type(targets.get('schema_version')) is int and targets['schema_version'] == 1, 'Unsupported target schema')
    check(evidence.get('schema_version') == 1, 'Unsupported evidence schema')
    check(targets.get('bundle_id') == evidence.get('bundle_id') == BUNDLE_ID, 'App bundle identity differs')
    check(isinstance(targets.get('app_id'), str) and targets['app_id'] == evidence.get('app_id'), 'App resource identity differs')
    check(isinstance(targets.get('approval_reference'), str) and bool(targets['approval_reference'].strip()), 'Owner approval reference missing')
    check(isinstance(targets.get('source_policy_sha256'), str) and re.fullmatch('[0-9a-f]{64}', targets['source_policy_sha256']) is not None,
          'Source policy hash missing')
    source = {row['public_storefront_country_code']: row for row in policy['territories']}
    mappings = targets['territories']
    countries = [row['public_country_code'] for row in mappings]
    territories = [row['apple_territory_id'] for row in mappings]
    check(len(countries) == len(set(countries)) and set(countries) == set(source), 'Public country coverage differs from source policy')
    check(len(territories) == len(set(territories)) and all(isinstance(t, str) and t for t in territories), 'Apple territory mapping missing or duplicated')
    expected = set(territories)
    active = {key for key, row in evidence['app_availability'].items() if row.get('available') is True}
    check(active == expected, 'Active app territories differ from the complete approved mapping')
    currencies = {}
    for mapping in mappings:
        country, territory = mapping['public_country_code'], mapping['apple_territory_id']
        currency = mapping['currency']
        currencies[territory] = currency
        check(evidence['currencies'].get(territory) == currency, 'Territory currency differs: ' + territory)
        known_mapping = source.get(country, {}).get('territory_code')
        if known_mapping is not None:
            check(territory == known_mapping, 'Country/territory pair conflicts with reviewed source: ' + country)
        else:
            reference = mapping.get('mapping_evidence_reference')
            check(isinstance(reference, str) and bool(reference.strip()),
                  'Unresolved country mapping needs a reviewed evidence reference: ' + country)
        if source.get(country, {}).get('income_group') not in GROUPS:
            decision = mapping.get('manual_income_decision')
            check(isinstance(decision, str) and bool(decision.strip()), 'Unclassified country needs explicit review: ' + country)
    check(set(targets['products']) == set(evidence['products']) == set(PRODUCTS), 'Exactly the three shipping products are required')
    approved_intervals = {territory: {} for territory in expected}
    for role, product_id in PRODUCTS.items():
        product, target = evidence['products'][role], targets['products'][role]
        check(target.get('product_id') == product.get('product_id') == product_id, 'Shipping product ID differs: ' + role)
        check(target.get('apple_id') == product.get('apple_id'), 'Apple product resource identity differs: ' + role)
        if role == 'lifetime':
            available = set(product['territories'])
        else:
            check(target.get('plan_type') == 'UPFRONT', 'Only the reviewed upfront acquisition plan is supported: ' + role)
            plans = [plan for plan in product['plans'] if plan['attributes'].get('planType') == 'UPFRONT']
            check(len(plans) == 1 and len(product['plans']) == 1, 'Subscription plan availability is missing or ambiguous: ' + role)
            available = set(plans[0]['territories']) if len(plans) == 1 else set()
        check(available == expected, 'Product availability differs from approved territories: ' + role)
        check(set(target['prices']) == expected, 'Approved price coverage differs: ' + role)
        for territory in sorted(expected):
            actual = _actual(product, role, territory, evaluated)
            intended = _targets(target['prices'][territory], evaluated)
            approved_intervals[territory][role] = intended
            check(all(row[4] == currencies[territory] for row in intended), 'Approved currency differs from mapping: ' + role + '/' + territory)
            check(actual == intended, 'Current or future acquisition price differs: ' + role + '/' + territory)
    for territory, schedules in approved_intervals.items():
        boundaries = {row[0] for rows in schedules.values() for row in rows}
        for boundary in boundaries:
            amounts = {role: next(row[3] for row in rows if row[0] <= boundary < row[1])
                       for role, rows in schedules.items()}
            # Input decimal strings are capped at 64 characters; this keeps the multiplication exact.
            with localcontext() as context:
                context.prec = 128
                check(amounts['annual'] < 12 * amounts['monthly'] and amounts['lifetime'] > amounts['annual'],
                      'Product price ordering invalid: ' + territory + '/' + boundary.isoformat())
    return errors


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--approved-targets', type=Path, required=True)
    parser.add_argument('--approved-target-sha256', required=True)
    parser.add_argument('--as-of', required=True, help='Explicit YYYY-MM-DD pricing schedule evaluation date')
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    client = None
    try:
        targets = load_targets(args.approved_targets, args.approved_target_sha256)
        raw_policy = DEFAULT_POLICY.read_bytes()
        if hashlib.sha256(raw_policy).hexdigest() != targets.get('source_policy_sha256'):
            raise EvidenceError('Approved targets are not bound to the current reviewed policy')
        policy = json.loads(raw_policy)
        if validate_proposal(policy):
            raise EvidenceError('The reviewed country proposal is structurally invalid')
        _date(args.as_of, None)
        token = os.environ.get('ASC_READ_ONLY_BEARER_TOKEN', '')
        client = AppleClient(token)
        evidence = collect(client)
        errors = verify(evidence, targets, policy, args.as_of)
        report = {'status': 'pricing_comparison_failed' if errors else 'fresh_pricing_matches_approved_targets',
                  'as_of': args.as_of, 'approved_target_sha256': args.approved_target_sha256,
                  'scope': 'Acquisition pricing and availability only; no submission-readiness certification',
                  'preserved_subscription_prices': 'Retained separately; excluded from new-customer comparison',
                  'offline_json_authentication': 'Not supported; saved responses require independent provenance review',
                  'errors': errors, 'evidence': evidence}
        args.output.parent.mkdir(parents=True, exist_ok=True)
        args.output.write_text(json.dumps(report, indent=2) + '\n', encoding='utf-8')
        print(report['status'] + '. This does not certify submission readiness.')
        return int(bool(errors))
    except (EvidenceError, OSError, ValueError, TypeError) as error:
        # Deliberately omit exception causes/HTTP bodies and authorization material.
        message = str(error) if isinstance(error, EvidenceError) else 'Input or output could not be processed'
        if client is not None:
            args.output.parent.mkdir(parents=True, exist_ok=True)
            args.output.write_text(json.dumps({'status': 'incomplete_collection', 'error': message,
                'origin': client.origin, 'pages': client.pages}, indent=2) + '\n', encoding='utf-8')
        print('ERROR: ' + message)
        return 1


if __name__ == '__main__':
    raise SystemExit(main())
