"""Bounded GET-only Apple pricing transport; archived JSON alone does not prove origin.

Apple pagination: https://developer.apple.com/documentation/appstoreconnectapi/paginginformation
Relationship collections must be read independently of limited `included` resources.
This module neither configures prices nor certifies submission readiness.
"""
import hashlib
import json
from datetime import datetime, timezone
from urllib.error import HTTPError, URLError
from urllib.parse import parse_qs, urlencode, urljoin, urlsplit, urlunsplit
from urllib.request import HTTPRedirectHandler, Request, build_opener

BASE = 'https://api.appstoreconnect.apple.com'


class EvidenceError(ValueError):
    """Evidence is incomplete, inconsistent or unsupported."""


class NoRedirect(HTTPRedirectHandler):
    def redirect_request(self, request, fp, code, message, headers, new_url):
        return None


def unique_object(pairs):
    result = {}
    for key, value in pairs:
        if key in result:
            raise EvidenceError('Duplicate JSON object key')
        result[key] = value
    return result


def resource(value, kind, expected_id=None):
    if not isinstance(kind, str) or not kind or not isinstance(value, dict) or value.get('type') != kind:
        raise EvidenceError('Unexpected resource type: ' + kind)
    identity = value.get('id')
    if not isinstance(identity, str) or not identity or (expected_id is not None and identity != expected_id):
        raise EvidenceError('Unexpected resource identity: ' + kind)
    return value


class AppleClient:
    def __init__(self, token, *, opener=None, max_requests=2000, max_response_bytes=16 * 1024 * 1024):
        if not isinstance(token, str) or not token.strip() or any(c in token for c in '\r\n'):
            raise EvidenceError('A nonempty bearer token is required')
        if type(max_requests) is not int or max_requests < 1 or type(max_response_bytes) is not int or max_response_bytes < 1:
            raise EvidenceError('Transport limits must be positive integers')
        self._token = token
        self._open = opener if opener is not None else build_opener(NoRedirect()).open
        self.origin = ('fixture_transport_not_authenticated_evidence' if opener is not None
                       else 'fresh_apple_https_transport_not_an_offline_attestation')
        self.max_requests = max_requests
        self.max_response_bytes = max_response_bytes
        self._requests = 0
        self.pages = []

    def url(self, value, relative_to=BASE + '/'):
        if not isinstance(value, str) or not value or any(ord(c) < 32 for c in value):
            raise EvidenceError('Invalid Apple API URL')
        url = urljoin(relative_to, value)
        try:
            parsed = urlsplit(url)
            valid = (parsed.scheme == 'https' and parsed.hostname == 'api.appstoreconnect.apple.com'
                     and parsed.username is None and parsed.password is None and parsed.port in (None, 443)
                     and not parsed.fragment and parsed.path.startswith(('/v1/', '/v2/')))
        except ValueError:
            valid = False
        if not valid or self._token in url:
            raise EvidenceError('Untrusted Apple API destination')
        sensitive = {'access_token', 'authorization', 'token', 'jwt'}
        if any(key.lower() in sensitive for key in parse_qs(parsed.query, keep_blank_values=True)):
            raise EvidenceError('Credentials may not appear in an evidence URL')
        return url

    def _get(self, location):
        url = self.url(location)
        if self._requests >= self.max_requests:
            raise EvidenceError('Apple evidence request limit exceeded')
        self._requests += 1
        request = Request(url, method='GET', headers={'Authorization': 'Bearer ' + self._token,
                                                     'Accept': 'application/json'})
        try:
            with self._open(request, timeout=30) as response:
                if response.status != 200:
                    raise EvidenceError('Apple evidence request did not return HTTP 200')
                raw = response.read(self.max_response_bytes + 1)
                response_date = response.headers.get('Date')
        except HTTPError as error:
            # Server bodies, reason strings and headers may reflect credentials; never log them.
            status = error.code
            error.close()
            raise EvidenceError('Apple evidence HTTP status ' + str(status)) from None
        except (URLError, OSError, TimeoutError):
            raise EvidenceError('Apple evidence transport failed') from None
        if len(raw) > self.max_response_bytes:
            raise EvidenceError('Apple evidence response exceeds byte limit')
        try:
            text = raw.decode('utf-8')
            document = json.loads(text, object_pairs_hook=unique_object)
        except (UnicodeError, ValueError):
            raise EvidenceError('Malformed Apple JSON evidence') from None
        if not isinstance(document, dict) or 'errors' in document:
            raise EvidenceError('Apple response is not successful resource evidence')
        if self._token in text or self._token in str(response_date):
            raise EvidenceError('Response unexpectedly contains authorization material')
        self.pages.append({'url': url, 'method': 'GET', 'status': 200,
                           'fetched_at': datetime.now(timezone.utc).isoformat(),
                           'server_date': response_date, 'sha256': hashlib.sha256(raw).hexdigest(),
                           'response_body': text})
        return document

    def one(self, location, kind, expected_id=None):
        document = self._get(location)
        if document.get('links', {}).get('next'):
            raise EvidenceError('Unexpected pagination on a single resource')
        return resource(document.get('data'), kind, expected_id)

    def collection(self, location, kind=None):
        url = self.url(location)
        first = urlsplit(url)
        initial_query = parse_qs(first.query, keep_blank_values=True)
        visited, identities, rows = set(), set(), []
        total = None
        while url:
            if url in visited:
                raise EvidenceError('Apple evidence pagination loop')
            visited.add(url)
            document = self._get(url)
            data = document.get('data')
            count = document.get('meta', {}).get('paging', {}).get('total')
            if not isinstance(data, list) or type(count) is not int or count < 0:
                raise EvidenceError('Collection completeness metadata is missing')
            if total is None:
                total = count
            if count != total:
                raise EvidenceError('Collection changed during evidence collection')
            for row in data:
                row_kind = kind if kind is not None else row.get('type') if isinstance(row, dict) else None
                row = resource(row, row_kind)
                identity = (row['type'], row['id'])
                if identity in identities:
                    raise EvidenceError('Duplicate collection resource')
                identities.add(identity)
                rows.append(row)
            destination = document.get('links', {}).get('next')
            if not destination:
                break
            next_url = self.url(destination, relative_to=url)
            parsed = urlsplit(next_url)
            query = parse_qs(parsed.query, keep_blank_values=True)
            if (parsed.path != first.path
                    or any(query.get(k) != v for k, v in initial_query.items() if k != 'cursor')
                    or set(query) - set(initial_query) - {'cursor', 'limit'}):
                raise EvidenceError('Pagination changed collection scope')
            url = next_url
        if len(rows) != total:
            raise EvidenceError('Incomplete Apple resource collection')
        return rows

    def relationship(self, parent, name, kind, *, include=None):
        # `data`/`included` may contain only the first 50 related entries. Always use the related collection.
        try:
            related = parent['relationships'][name]['links']['related']
        except (KeyError, TypeError):
            raise EvidenceError('Missing complete relationship endpoint: ' + name) from None
        if include:
            parsed = urlsplit(self.url(related))
            query = parse_qs(parsed.query, keep_blank_values=True)
            if 'include' in query and query['include'] != [include]:
                raise EvidenceError('Conflicting relationship include scope')
            query['include'] = [include]
            related = urlunsplit(parsed._replace(query=urlencode(query, doseq=True)))
        return self.collection(related, kind)
