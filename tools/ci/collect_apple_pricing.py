"""Collect app-owned pricing inventory through GET requests; no price or account writes.

Current API contracts:
https://developer.apple.com/documentation/appstoreconnectapi/get-v1-apps-_id_-appavailabilityv2
https://developer.apple.com/documentation/appstoreconnectapi/get-v1-subscriptions-_id_-planavailabilities
https://developer.apple.com/documentation/appstoreconnectapi/get-v1-subscriptions-_id_-prices
https://developer.apple.com/documentation/appstoreconnectapi/get-v2-inapppurchases-_id_-iappriceschedule

Raw pages preserve acquisition evidence, not an offline authentication attestation.
Collection is deliberately separate from owner approval and policy compliance.
"""
from decimal import Decimal
import re
from urllib.parse import quote, urlencode

from apple_pricing_transport import EvidenceError

BUNDLE_ID = 'com.shahradazerisharghi.timbre'
PRODUCTS = {'monthly': 'timbre_pro_monthly', 'annual': 'timbre_pro_annual',
            'lifetime': 'timbre_plus_lifetime'}


def path_id(value):
    if not isinstance(value, str) or not value:
        raise EvidenceError('Missing Apple resource identifier')
    return quote(value, safe='')


def linkage(parent, name, kind):
    try:
        value = parent['relationships'][name]['data']
    except (KeyError, TypeError):
        raise EvidenceError('Missing resource relationship: ' + name) from None
    if not isinstance(value, dict) or value.get('type') != kind:
        raise EvidenceError('Unexpected relationship type: ' + name)
    path_id(value.get('id'))
    return value['id']


def decimal_price(value):
    if not isinstance(value, str) or len(value) > 64 or not re.fullmatch(r'[0-9]+(?:\.[0-9]+)?', value):
        raise EvidenceError('Apple prices must be nonnegative decimal strings')
    number = Decimal(value)
    if not number.is_finite():
        raise EvidenceError('Apple price is not finite')
    return number


def _unique(rows, label):
    by_id = {}
    for row in rows:
        if row['id'] in by_id:
            raise EvidenceError('Duplicate ' + label)
        by_id[row['id']] = row
    return by_id


def _product(rows, role):
    matches = [row for row in rows if row.get('attributes', {}).get('productId') == PRODUCTS[role]]
    if len(matches) != 1:
        raise EvidenceError('App-owned product missing or ambiguous: ' + role)
    product = matches[0]
    attributes = product['attributes']
    if role == 'lifetime':
        valid = attributes.get('inAppPurchaseType') == 'NON_CONSUMABLE'
    else:
        valid = attributes.get('subscriptionPeriod') == {'monthly': 'ONE_MONTH', 'annual': 'ONE_YEAR'}[role]
    if not valid:
        raise EvidenceError('Shipping product type or duration differs: ' + role)
    return product


def collect(client):
    """Fetch complete collections and normalize identities; not a policy/readiness verdict."""
    apps = client.collection('/v1/apps?' + urlencode({'filter[bundleId]': BUNDLE_ID}), 'apps')
    if len(apps) != 1 or apps[0].get('attributes', {}).get('bundleId') != BUNDLE_ID:
        raise EvidenceError('Expected app bundle identity is missing or ambiguous')
    app = apps[0]
    app_path = '/v1/apps/' + path_id(app['id'])
    currencies = {}
    for territory in client.collection('/v1/territories?limit=200', 'territories'):
        currency = territory.get('attributes', {}).get('currency')
        if not isinstance(currency, str) or not re.fullmatch('[A-Z]{3}', currency):
            raise EvidenceError('Apple territory currency is missing or invalid')
        currencies[territory['id']] = currency

    availability = client.one(app_path + '/appAvailabilityV2', 'appAvailabilities')
    app_territories = client.relationship(availability, 'territoryAvailabilities', 'territoryAvailabilities', include='territory')
    app_available = {}
    for item in app_territories:
        territory = linkage(item, 'territory', 'territories')
        attributes = item.get('attributes', {})
        if territory in app_available or territory not in currencies or type(attributes.get('available')) is not bool:
            raise EvidenceError('Ambiguous app territory or missing availability')
        app_available[territory] = {'availability_id': item['id'], **attributes}

    # Product ownership is established by app-scoped lists, never caller-supplied product resource IDs.
    subscriptions = []
    for group in client.collection(app_path + '/subscriptionGroups?limit=200', 'subscriptionGroups'):
        children = client.collection('/v1/subscriptionGroups/' + path_id(group['id']) + '/subscriptions?include=group&limit=200',
                                     'subscriptions')
        for child in children:
            if linkage(child, 'group', 'subscriptionGroups') != group['id']:
                raise EvidenceError('Subscription group ownership mismatch')
        subscriptions.extend(children)
    _unique(subscriptions, 'app subscription resource')
    purchases = client.collection(app_path + '/inAppPurchasesV2?limit=200', 'inAppPurchases')
    _unique(purchases, 'app IAP resource')

    points = {}
    def prices(rows, role, product_root, manual=None):
        result = []
        for row in rows:
            territory = linkage(row, 'territory', 'territories')
            if territory not in currencies:
                raise EvidenceError('Price references an unknown Apple territory')
            kind = 'inAppPurchasePricePoints' if role == 'lifetime' else 'subscriptionPricePoints'
            relation = 'inAppPurchasePricePoint' if role == 'lifetime' else 'subscriptionPricePoint'
            point_id = linkage(row, relation, kind)
            key = (product_root, territory)
            if key not in points:
                # Membership in this product's complete catalogue binds opaque point IDs to the product.
                query = urlencode({'filter[territory]': territory, 'include': 'territory', 'limit': 8000})
                catalogue = client.collection(product_root + '/pricePoints?' + query, kind)
                points[key] = _unique(catalogue, 'product price point')
            point = points[key].get(point_id)
            if point is None:
                raise EvidenceError('Scheduled price point is absent from its app-owned product catalogue')
            if linkage(point, 'territory', 'territories') != territory:
                raise EvidenceError('Price point belongs to a different territory')
            attributes = row.get('attributes', {})
            if manual is not None and attributes.get('manual') is not manual:
                raise EvidenceError('Manual/automatic schedule provenance mismatch')
            value = point.get('attributes', {}).get('customerPrice')
            decimal_price(value)
            result.append({'apple_price_id': row['id'], 'territory': territory,
                           'currency': currencies[territory], 'price_point_id': point_id,
                           'customer_price': value, 'schedule_attributes': attributes,
                           'point_attributes': point['attributes']})
        return result

    products = {}
    for role in ['monthly', 'annual']:
        product = _product(subscriptions, role)
        root = '/v1/subscriptions/' + path_id(product['id'])
        plans = []
        for plan in client.collection(root + '/planAvailabilities?limit=200', 'subscriptionPlanAvailabilities'):
            available = client.relationship(plan, 'availableTerritories', 'territories')
            territories = [row['id'] for row in available]
            if any(territory not in currencies for territory in territories):
                raise EvidenceError('Subscription availability references an unknown territory')
            plans.append({'id': plan['id'], 'attributes': plan.get('attributes', {}), 'territories': territories})
        records = client.collection(root + '/prices?include=territory,subscriptionPricePoint&limit=200', 'subscriptionPrices')
        products[role] = {'apple_id': product['id'], 'product_id': PRODUCTS[role],
                          'attributes': product['attributes'], 'plans': plans, 'prices': prices(records, role, root)}

    product = _product(purchases, 'lifetime')
    root = '/v2/inAppPurchases/' + path_id(product['id'])
    available = client.one(root + '/inAppPurchaseAvailability', 'inAppPurchaseAvailabilities')
    territories = [row['id'] for row in client.relationship(available, 'availableTerritories', 'territories')]
    if any(territory not in currencies for territory in territories):
        raise EvidenceError('IAP availability references an unknown territory')
    schedule = client.one(root + '/iapPriceSchedule', 'inAppPurchasePriceSchedules')
    manual = client.relationship(schedule, 'manualPrices', 'inAppPurchasePrices', include='territory,inAppPurchasePricePoint')
    automatic = client.relationship(schedule, 'automaticPrices', 'inAppPurchasePrices', include='territory,inAppPurchasePricePoint')
    if {row['id'] for row in manual} & {row['id'] for row in automatic}:
        raise EvidenceError('A price appears in both schedule sources')
    products['lifetime'] = {'apple_id': product['id'], 'product_id': PRODUCTS['lifetime'],
        'attributes': product['attributes'], 'availability_id': available['id'],
        'territories': territories, 'schedule_id': schedule['id'],
        'prices': prices(manual, 'lifetime', root, True) + prices(automatic, 'lifetime', root, False)}
    return {'schema_version': 1, 'status': 'collected_inventory_not_policy_approval_or_submission_readiness',
            'origin': client.origin, 'bundle_id': BUNDLE_ID, 'app_id': app['id'],
            'currencies': currencies, 'app_availability': app_available, 'products': products,
            'pages': client.pages}
