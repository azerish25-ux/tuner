"""Offline receipt mutation tests; no live requests or verification flags written."""
import copy
import hashlib
import json
from pathlib import Path
import shutil
import sys
import tempfile
import unittest
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import store

REFERENCE = 'docs/ios/readiness/reviews/privacy-policy-current-source-verification.json'


class PrivacyEvidenceTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        original = store.ROOT
        for name in (*store.privacy_source_inventory(), REFERENCE, 'tools/l10n/store-locales.json'):
            destination = self.root / name
            destination.parent.mkdir(parents=True, exist_ok=True)
            shutil.copyfile(original / name, destination)
        self.data = copy.deepcopy(store.load('en-US'))
        self.data['review']['evidence'] = {'privacy_policy': {'reference': REFERENCE,
            'content_sha256': store.content_hash(self.data)}}
        self.receipt = json.loads((self.root / REFERENCE).read_text())
        self.addCleanup(patch.stopall)
        patch.object(store, 'ROOT', self.root).start()
        patch.object(store, 'MANIFEST', self.root/'tools/l10n/store-locales.json').start()
        self.write_receipt()

    def write_receipt(self):
        path = self.root / REFERENCE
        path.write_text(json.dumps(self.receipt))
        self.data['review']['evidence']['privacy_policy']['reference_sha256'] = hashlib.sha256(path.read_bytes()).hexdigest()

    def assert_invalid(self):
        self.assertTrue(store.privacy_evidence_errors(self.data))

    def test_current_receipt_passes_offline(self):
        self.assertEqual(store.privacy_evidence_errors(self.data), [])

    def test_trusted_root_ancestor_symlink_is_allowed(self):
        alias_temp = tempfile.TemporaryDirectory()
        self.addCleanup(alias_temp.cleanup)
        alias = Path(alias_temp.name)/'workspace'
        alias.symlink_to(self.root, target_is_directory=True)
        with patch.object(store, 'ROOT', alias):
            self.assertEqual(store.privacy_evidence_errors(self.data), [])

    def test_missing_receipt_and_stale_hash_fail(self):
        self.data['review']['evidence']['privacy_policy']['reference_sha256'] = '0'*64
        self.assert_invalid()
        (self.root/REFERENCE).unlink()
        self.assert_invalid()

    def test_traversal_absolute_and_symlink_fail(self):
        evidence = self.data['review']['evidence']['privacy_policy']
        for reference in ('../outside.json', str(self.root/REFERENCE), './'+REFERENCE, 'docs\\outside.json'):
            evidence['reference'] = reference
            self.assert_invalid()
        evidence['reference'] = REFERENCE
        target = self.root/'original.json'
        (self.root/REFERENCE).rename(target)
        (self.root/REFERENCE).symlink_to(target)
        self.assert_invalid()

    def test_source_symlink_rejected(self):
        source = self.root/'docs/ios/PRIVACY.md'
        target = self.root/'policy.md'
        source.rename(target)
        source.symlink_to(target)
        self.assert_invalid()

    def test_each_source_hash_is_bound(self):
        for name in (*store.PRIVACY_BASE_SOURCES, 'ios/Timbre/Services/AppStore.swift',
                     'ios/Timbre/Songs/SongsView.swift', 'ios/Timbre/Settings/SettingsView.swift'):
            path = self.root/name
            old = path.read_bytes()
            path.write_bytes(old+b'\n')
            with self.subTest(name=name): self.assert_invalid()
            path.write_bytes(old)

    def test_added_shipped_source_or_dependency_invalidates_receipt(self):
        for name in ('ios/Timbre/NewCollection.swift', 'ios/Timbre/NewCollection.mm',
                     'ios/Timbre/NewCollection.m', 'ios/Timbre/NewSettings.xcconfig', 'ios/Package.resolved',
                     'ios/Timbre/NewPermissions.plist'):
            path = self.root/name
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_text('new input')
            with self.subTest(name=name): self.assert_invalid()
            path.unlink()

    def test_bad_scope_time_revision_or_limits_fail(self):
        for field, value in [('scope','legal_certification'), ('schema_version',True),
                             ('verified_utc','yesterday'), ('source_revision','main'),
                             ('limitations',{}), ('source_sha256',{}), ('policy_source',[]),
                             ('listing_content_sha256',{})]:
            old = self.receipt[field]
            self.receipt[field] = value
            self.write_receipt()
            with self.subTest(field=field): self.assert_invalid()
            self.receipt[field] = old

    def test_bad_live_receipt_status_url_or_bytes_fail(self):
        route = self.receipt['routes'][0]
        for field, value in [('status',403), ('url','https://wrong.invalid/privacy'),
                             ('sha256','0'*64), ('bytes_equal_committed_html',False),
                             ('content_type','text/plain'), ('source_html','docs/site/support.html')]:
            old = route[field]
            route[field] = value
            self.write_receipt()
            with self.subTest(field=field): self.assert_invalid()
            route[field] = old

    def test_listing_mutation_invalidates_receipt(self):
        self.data['subtitle'] += '!'
        self.assert_invalid()

    def test_malformed_mappings_fail_without_crashing(self):
        for value in (None, [], 'bad', 4):
            self.data['review']['evidence']['privacy_policy'] = value
            self.assert_invalid()
        self.data['review']['evidence'] = []
        self.assert_invalid()

    def test_malformed_receipt_json_fails(self):
        path = self.root/REFERENCE
        for raw in (b'not-json', b'null', b'[]', b'42'):
            path.write_bytes(raw)
            self.data['review']['evidence']['privacy_policy']['reference_sha256'] = hashlib.sha256(raw).hexdigest()
            self.assert_invalid()


if __name__ == '__main__': unittest.main()
