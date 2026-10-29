"""Small synthetic Apple-schema fixtures; not account data or approved prices."""
import copy
import io
import json
import unittest
from urllib.parse import parse_qs, urlsplit

from apple_pricing_transport import AppleClient, EvidenceError
from collect_apple_pricing import BUNDLE_ID, PRODUCTS, collect


def item(kind, identity, attributes=None, **relationships):
    return {'type': kind, 'id': identity, 'attributes': attributes or {}, 'relationships': relationships}


def link(kind, identity):
    return {'data': {'type': kind, 'id': identity}}


def related(path):
    return {'links': {'related': path}}


def listing(rows):
    return {'data': rows, 'meta': {'paging': {'total': len(rows)}}, 'links': {}}


class Response(io.BytesIO):
    status = 200
    headers = {}


def fixture():
    routes = {
        '/v1/apps': listing([item('apps', 'app', {'bundleId': BUNDLE_ID})]),
        '/v1/territories': listing([item('territories', 'USA', {'currency': 'USD'})]),
        '/v1/apps/app/appAvailabilityV2': {'data': item('appAvailabilities', 'availability',
            territoryAvailabilities=related('/v2/appAvailabilities/availability/territoryAvailabilities'))},
        '/v2/appAvailabilities/availability/territoryAvailabilities': listing([
            item('territoryAvailabilities', 'usa-available', {'available': True, 'releaseDate': None},
                 territory=link('territories', 'USA'))]),
        '/v1/apps/app/subscriptionGroups': listing([item('subscriptionGroups', 'group')]),
        '/v1/subscriptionGroups/group/subscriptions': listing([
            item('subscriptions', role, {'productId': PRODUCTS[role], 'subscriptionPeriod': period},
                 group=link('subscriptionGroups', 'group'))
            for role, period in [('monthly', 'ONE_MONTH'), ('annual', 'ONE_YEAR')]]),
        '/v1/apps/app/inAppPurchasesV2': listing([item('inAppPurchases', 'lifetime',
            {'productId': PRODUCTS['lifetime'], 'inAppPurchaseType': 'NON_CONSUMABLE'})]),
        '/v2/inAppPurchases/lifetime/inAppPurchaseAvailability': {'data': item('inAppPurchaseAvailabilities',
            'lifetime-available', availableTerritories=related('/v1/inAppPurchaseAvailabilities/lifetime-available/availableTerritories'))},
        '/v1/inAppPurchaseAvailabilities/lifetime-available/availableTerritories': listing([item('territories', 'USA')]),
        '/v2/inAppPurchases/lifetime/iapPriceSchedule': {'data': item('inAppPurchasePriceSchedules', 'schedule',
            manualPrices=related('/v1/inAppPurchasePriceSchedules/schedule/manualPrices'),
            automaticPrices=related('/v1/inAppPurchasePriceSchedules/schedule/automaticPrices'))},
        '/v1/inAppPurchasePriceSchedules/schedule/manualPrices': listing([item('inAppPurchasePrices', 'life-price',
            {'startDate': None, 'endDate': None, 'manual': True},
            territory=link('territories', 'USA'), inAppPurchasePricePoint=link('inAppPurchasePricePoints', 'life-point'))]),
        '/v1/inAppPurchasePriceSchedules/schedule/automaticPrices': listing([]),
        '/v2/inAppPurchases/lifetime/pricePoints': listing([item('inAppPurchasePricePoints', 'life-point',
            {'customerPrice': '9.99', 'proceeds': '7.00'}, territory=link('territories', 'USA'))]),
    }
    for role in ['monthly', 'annual']:
        prefix = '/v1/subscriptions/' + role
        routes[prefix + '/planAvailabilities'] = listing([item('subscriptionPlanAvailabilities', role + '-plan',
            {'planType': 'UPFRONT', 'availableInNewTerritories': False},
            availableTerritories=related('/v1/subscriptionPlanAvailabilities/' + role + '-plan/availableTerritories'))])
        routes['/v1/subscriptionPlanAvailabilities/' + role + '-plan/availableTerritories'] = listing([item('territories', 'USA')])
        routes[prefix + '/prices'] = listing([item('subscriptionPrices', role + '-price',
            {'startDate': None, 'preserved': False, 'planType': 'UPFRONT'},
            territory=link('territories', 'USA'), subscriptionPricePoint=link('subscriptionPricePoints', role + '-point'))])
        routes[prefix + '/pricePoints'] = listing([item('subscriptionPricePoints', role + '-point',
            {'customerPrice': '1.99', 'proceeds': '1.40', 'proceedsYear2': '1.69'}, territory=link('territories', 'USA'))])
    return routes


class CollectorTests(unittest.TestCase):
    def run_fixture(self, routes):
        self.requests = []
        def open_fixture(request, timeout):
            parsed = urlsplit(request.full_url)
            self.requests.append(parsed)
            if parsed.path.endswith('/pricePoints'):
                self.assertEqual(parse_qs(parsed.query)['filter[territory]'], ['USA'])
            if parsed.path.endswith('/subscriptions'):
                self.assertEqual(parse_qs(parsed.query)['include'], ['group'])
            return Response(json.dumps(routes[parsed.path]).encode())
        return collect(AppleClient('synthetic-not-a-key', opener=open_fixture))

    def test_complete_owned_inventory_keeps_schedule_provenance_and_fixture_origin(self):
        evidence = self.run_fixture(fixture())
        self.assertEqual(evidence['bundle_id'], BUNDLE_ID)
        self.assertEqual(set(evidence['products']), {'monthly', 'annual', 'lifetime'})
        self.assertIn('fixture', evidence['origin'])
        self.assertNotIn('release_ready', evidence)
        self.assertEqual(evidence['products']['monthly']['prices'][0]['price_point_id'], 'monthly-point')
        self.assertEqual(evidence['products']['lifetime']['prices'][0]['schedule_attributes']['manual'], True)
        self.assertTrue(any(p.path.endswith('/automaticPrices') for p in self.requests))
        self.assertTrue(any(p.path.endswith('/availableTerritories') for p in self.requests))
        self.assertNotIn('synthetic-not-a-key', json.dumps(evidence))

    def test_wrong_bundle_or_duplicate_app_rejected(self):
        for change in ['foreign', 'duplicate']:
            routes = fixture()
            if change == 'foreign':
                routes['/v1/apps']['data'][0]['attributes']['bundleId'] = 'foreign'
            else:
                routes['/v1/apps'] = listing(routes['/v1/apps']['data'] + [item('apps', 'other', {'bundleId': BUNDLE_ID})])
            with self.subTest(change=change), self.assertRaises(EvidenceError):
                self.run_fixture(routes)

    def test_product_type_duration_group_and_missing_identity_rejected(self):
        for change in ['period', 'group', 'missing', 'duplicate', 'consumable']:
            routes = fixture()
            row = routes['/v1/subscriptionGroups/group/subscriptions']['data'][0]
            if change == 'period': row['attributes']['subscriptionPeriod'] = 'ONE_YEAR'
            elif change == 'group': row['relationships']['group'] = link('subscriptionGroups', 'foreign')
            elif change == 'missing': row['attributes']['productId'] = 'foreign'
            elif change == 'duplicate':
                duplicate = copy.deepcopy(row); duplicate['id'] = 'monthly-copy'
                routes['/v1/subscriptionGroups/group/subscriptions'] = listing([row, duplicate])
            else:
                routes['/v1/apps/app/inAppPurchasesV2']['data'][0]['attributes']['inAppPurchaseType'] = 'CONSUMABLE'
            with self.subTest(change=change), self.assertRaises(EvidenceError):
                self.run_fixture(routes)

    def test_price_point_must_belong_to_product_and_territory(self):
        for change in ['foreign-product', 'foreign-territory', 'malformed-amount']:
            routes = fixture()
            row = routes['/v1/subscriptions/monthly/pricePoints']['data'][0]
            if change == 'foreign-product': row['id'] = 'other-point'
            elif change == 'foreign-territory': row['relationships']['territory'] = link('territories', 'CAN')
            else: row['attributes']['customerPrice'] = 1.99
            with self.subTest(change=change), self.assertRaises(EvidenceError):
                self.run_fixture(routes)

    def test_manual_automatic_conflict_and_wrong_provenance_fail(self):
        for change in ['conflict', 'wrong-manual']:
            routes = fixture()
            row = routes['/v1/inAppPurchasePriceSchedules/schedule/manualPrices']['data'][0]
            if change == 'conflict':
                routes['/v1/inAppPurchasePriceSchedules/schedule/automaticPrices'] = listing([copy.deepcopy(row)])
            else: row['attributes']['manual'] = False
            with self.subTest(change=change), self.assertRaises(EvidenceError):
                self.run_fixture(routes)

    def test_future_and_preserved_rows_are_retained_not_silently_selected(self):
        routes = fixture()
        rows = routes['/v1/subscriptions/monthly/prices']['data']
        for identity, attributes in [('old', {'preserved': True, 'startDate': None, 'planType': 'UPFRONT'}),
                                     ('future', {'preserved': False, 'startDate': '2027-01-01', 'planType': 'UPFRONT'})]:
            row = copy.deepcopy(rows[0]); row['id'] = identity; row['attributes'] = attributes; rows.append(row)
        routes['/v1/subscriptions/monthly/prices'] = listing(rows)
        result = self.run_fixture(routes)['products']['monthly']['prices']
        self.assertEqual(len(result), 3)
        self.assertTrue(result[1]['schedule_attributes']['preserved'])
        self.assertEqual(result[2]['schedule_attributes']['startDate'], '2027-01-01')


if __name__ == '__main__':
    unittest.main()
