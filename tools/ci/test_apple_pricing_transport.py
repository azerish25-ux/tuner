"""Fixture transport tests. These never contact or authenticate with Apple."""
import io
import json
import unittest
from urllib.error import HTTPError

from apple_pricing_transport import AppleClient, EvidenceError


class Response(io.BytesIO):
    status = 200
    headers = {'Date': 'Wed, 28 Oct 2026 12:00:00 GMT'}


def page(ids, total, next_url=None):
    return {'data': [{'type': 'territories', 'id': value} for value in ids],
            'meta': {'paging': {'total': total}}, 'links': {'next': next_url}}


class TransportTests(unittest.TestCase):
    def client(self, replies, **kwargs):
        self.requests = []
        def open_fixture(request, timeout):
            self.requests.append(request)
            reply = replies.pop(0)
            if isinstance(reply, Exception):
                raise reply
            return Response(reply if isinstance(reply, bytes) else json.dumps(reply).encode())
        return AppleClient('fixture-secret', opener=open_fixture, **kwargs)

    def test_complete_pagination_keeps_original_bytes_and_get_only_requests(self):
        client = self.client([page(['USA'], 2, '?cursor=two'), page(['CAN'], 2)])
        self.assertEqual([r['id'] for r in client.collection('/v1/territories')], ['USA', 'CAN'])
        self.assertEqual(len(client.pages), 2)
        self.assertEqual(client.origin, 'fixture_transport_not_authenticated_evidence')
        for request in self.requests:
            self.assertEqual(request.method, 'GET')
            self.assertEqual(request.get_header('Authorization'), 'Bearer fixture-secret')
        serialized = json.dumps(client.pages)
        self.assertNotIn('fixture-secret', serialized)
        self.assertIn('response_body', serialized)
        self.assertEqual(client.pages[0]['status'], 200)

    def test_incomplete_and_duplicate_collection_fail(self):
        for replies in [[page(['USA'], 2)], [page(['USA', 'USA'], 2)],
                        [page(['USA'], 1, '?cursor=next'), page(['CAN'], 2)]]:
            with self.subTest(replies=replies), self.assertRaises(EvidenceError):
                self.client(replies).collection('/v1/territories')

    def test_missing_total_is_not_complete_evidence(self):
        with self.assertRaises(EvidenceError):
            self.client([{'data': [], 'links': {}}]).collection('/v1/territories')

    def test_host_scheme_credentials_fragment_port_and_path_changes_rejected(self):
        for destination in ['http://api.appstoreconnect.apple.com/v1/territories',
                            'https://attacker.invalid/v1/territories',
                            'https://user@api.appstoreconnect.apple.com/v1/territories',
                            'https://api.appstoreconnect.apple.com:444/v1/territories',
                            'https://api.appstoreconnect.apple.com/v1/territories#secret',
                            'https://api.appstoreconnect.apple.com/v1/apps/foreign',
                            '?access_token=secret']:
            client = self.client([page(['USA'], 2, destination)])
            with self.subTest(destination=destination), self.assertRaises(EvidenceError):
                client.collection('/v1/territories')
            self.assertEqual(len(self.requests), 1)

    def test_pagination_cannot_change_a_filter(self):
        client = self.client([page(['USA'], 2, '?filter[territory]=CAN&cursor=next')])
        with self.assertRaises(EvidenceError):
            client.collection('/v1/territories?filter[territory]=USA')
        self.assertEqual(len(self.requests), 1)

    def test_loops_and_request_limit_fail(self):
        for kwargs in [{}, {'max_requests': 1}]:
            client = self.client([page(['USA'], 2, '/v1/territories')], **kwargs)
            with self.subTest(kwargs=kwargs), self.assertRaises(EvidenceError):
                client.collection('/v1/territories')
            self.assertEqual(len(self.requests), 1)

    def test_redirect_or_http_failure_does_not_expose_response_or_token(self):
        for status in [302, 401, 403, 429, 500]:
            body = io.BytesIO(b'fixture-secret')
            error = HTTPError('https://api.appstoreconnect.apple.com/v1/apps', status,
                              'fixture-secret reflected', {}, body)
            client = self.client([error])
            with self.subTest(status=status), self.assertRaises(EvidenceError) as caught:
                client.one('/v1/apps/example', 'apps')
            self.assertNotIn('fixture-secret', str(caught.exception))
            self.assertEqual(client.pages, [])
            self.assertTrue(body.closed)

    def test_oversized_malformed_and_duplicate_json_keys_rejected(self):
        for raw in [b'x' * 101, b'{', b'{"data":{},"data":{}}']:
            client = self.client([raw], max_response_bytes=100)
            with self.subTest(raw=raw), self.assertRaises(EvidenceError):
                client.one('/v1/apps/example', 'apps')

    def test_wrong_resource_type_and_identity_fail(self):
        for resource in [{'type': 'subscriptions', 'id': 'example'},
                         {'type': 'apps', 'id': 'foreign'}]:
            client = self.client([{'data': resource}])
            with self.subTest(resource=resource), self.assertRaises(EvidenceError):
                client.one('/v1/apps/example', 'apps', 'example')

    def test_relationship_collection_must_be_fetched_independently(self):
        client = self.client([{'data': {'type': 'inAppPurchaseAvailabilities', 'id': 'a',
            'relationships': {'availableTerritories': {'data': [{'type': 'territories', 'id': 'USA'}],
                'links': {'related': '/v1/inAppPurchaseAvailabilities/a/availableTerritories'}}}}},
            page(['USA', 'CAN'], 2)])
        resource = client.one('/v1/inAppPurchaseAvailabilities/a', 'inAppPurchaseAvailabilities', 'a')
        self.assertEqual(len(client.relationship(resource, 'availableTerritories', 'territories')), 2)
        self.assertEqual(len(self.requests), 2)


if __name__ == '__main__':
    unittest.main()
