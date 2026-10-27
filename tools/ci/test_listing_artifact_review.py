import io
import urllib.error
import hashlib
import json
from pathlib import Path
import stat
import tempfile
import unittest
from unittest.mock import patch
import zipfile

import listing_artifact_review as review


class RecoveryTests(unittest.TestCase):
    def metadata(self):
        return {'id': review.APPROVED['artifact_id'], 'name': review.APPROVED['name'],
                'size_in_bytes': review.APPROVED['size_in_bytes'], 'digest': review.APPROVED['digest'],
                'workflow_run': {'id': review.APPROVED['run_id'], 'head_sha': review.APPROVED['source_sha']},
                'expired': False}

    def archive(self, directory, extra=None, wrong_hash=False):
        # Byte-integrity fixture only: this is never claimed as a native/rendered image.
        payload = b'original-byte-integrity-unit-fixture' * 30
        image = 'assets/de-DE/ipad/rendered/ipad-de-DE-01.jpg'
        manifest = {'status': 'mechanically_verified', 'release_ready': False,
                    'assets': [{'path': 'rendered/ipad-de-DE-01.jpg',
                                'sha256': '0' * 64 if wrong_hash else hashlib.sha256(payload).hexdigest()}]}
        members = {image: payload, 'assets/de-DE/ipad/manifest.json': json.dumps(manifest).encode(),
                   'assets/en-US/ipad/manifest.json': b'{"status":"failed","release_ready":false}',
                   'assets/en-US/ipad/language-check/attempt-1/test.log': b'actual failure log fixture',
                   'assets/de-DE/ipad/capture/attempt-1/attachments/manifest.json': b'[]',
                   'assets/de-DE/ipad/capture/attempt-1/Tests.xcresult/data.log': b'raw result excluded',
                   'assets/de-DE/ipad/capture/attempt-1/attachments/exported.png': b'diagnostic attachment byte fixture',
                   'assets/en-US/ipad/language-check/attempt-2/attachments/failure.jpg': b'diagnostic failure byte fixture',
                   'assets/de-DE/ipad/raw/raw.png': b'unexported raw screenshot excluded',
                   'assets/de-DE/ipad/recording.mp4': b'video excluded'}
        members.update(extra or {})
        archive = Path(directory) / 'source.zip'
        with zipfile.ZipFile(archive, 'w') as z:
            for name, data in members.items():
                z.writestr(name, data)
        expected = {**review.APPROVED, 'size_in_bytes': archive.stat().st_size,
                    'digest': 'sha256:' + review.digest(archive)}
        return archive, expected, members

    def test_metadata_tuple_rejects_every_unreviewed_component(self):
        review.validate_metadata(self.metadata())
        for key in ['id', 'name', 'size_in_bytes', 'digest', 'expired', 'workflow_run']:
            data = self.metadata()
            data[key] = None
            with self.subTest(key=key), self.assertRaises(ValueError):
                review.validate_metadata(data)
        for key in ['id', 'head_sha']:
            data = self.metadata()
            data['workflow_run'][key] = 'other'
            with self.assertRaises(ValueError):
                review.validate_metadata(data)

    def test_original_bytes_hashes_and_failed_manifest_are_unchanged(self):
        with tempfile.TemporaryDirectory() as directory:
            archive, expected, members = self.archive(directory)
            index = review.package(archive, Path(directory) / 'out', expected)
            self.assertEqual(len(index['slices']), 1)
            with zipfile.ZipFile(Path(directory) / 'out' / index['slices'][0]['path']) as z:
                receipt = json.loads(z.read('REVIEW-RECEIPT.json'))
                self.assertEqual(receipt['source'], expected)
                attachments = [row for row in receipt['files'] if '/attachments/' in row['path'] and row['path'].endswith(('.png', '.jpg'))]
                self.assertEqual(len(attachments), 2)
                self.assertTrue(all(row['role'] == 'diagnostic-attachment-only' for row in attachments))
                for row in receipt['files']:
                    self.assertEqual(z.read('originals/' + row['path']), members[row['path']])
                    self.assertEqual(row['sha256'], hashlib.sha256(members[row['path']]).hexdigest())
                self.assertEqual(json.loads(z.read('originals/assets/en-US/ipad/manifest.json'))['status'], 'failed')
                self.assertFalse(any('.xcresult/' in n or n.endswith(('raw.png', '.mp4')) for n in z.namelist()))

    def test_only_exported_capture_and_language_attempt_images_are_selected(self):
        from pathlib import PurePosixPath
        for name in ['assets/en-US/ipad/capture/attempt-1/attachments/failure.png',
                     'assets/de-DE/ipad/language-check/attempt-2/attachments/language.jpg']:
            self.assertTrue(review.selected(PurePosixPath(name)))
        for name in ['assets/en-US/ipad/capture/attempt-1/Tests.xcresult/failure.png',
                     'assets/en-US/ipad/capture/attempt-1/attachments/recording.mp4',
                     'assets/en-US/ipad/capture/attempt-1/warmup/diagnostic-only.png',
                     'assets/en-US/ipad/capture/attempt-0/attachments/failure.png',
                     'assets/en-US/ipad/raw/failure.png']:
            self.assertFalse(review.selected(PurePosixPath(name)))

    def test_wrong_archive_digest_and_original_manifest_hash_fail(self):
        with tempfile.TemporaryDirectory() as directory:
            archive, expected, _ = self.archive(directory, wrong_hash=True)
            with self.assertRaisesRegex(ValueError, 'manifest hash'):
                review.package(archive, Path(directory) / 'bad-image', expected)
            with self.assertRaisesRegex(ValueError, 'archive size/digest'):
                review.package(archive, Path(directory) / 'bad-archive', {**expected, 'digest': 'sha256:' + '0' * 64})

    def test_path_traversal_absolute_backslash_and_symlink_rejected(self):
        for name in ['../escape.log', '/absolute.log', 'a/../b.log', 'a//b.log', 'a\\b.log', 'C:/b.log']:
            with self.subTest(name=name), tempfile.TemporaryDirectory() as directory:
                archive, expected, _ = self.archive(directory, {name: b'bad'})
                with self.assertRaises(ValueError):
                    review.package(archive, Path(directory) / 'out', expected)
        entry = zipfile.ZipInfo('link.log')
        entry.external_attr = (stat.S_IFLNK | 0o777) << 16
        with self.assertRaises(ValueError):
            review.safe_name(entry)

    def test_selected_expansion_and_per_file_limits_fail_closed(self):
        for bound in ['MAX_ENTRY', 'MAX_SELECTED']:
            with tempfile.TemporaryDirectory() as directory:
                archive, expected, _ = self.archive(directory)
                with patch.object(review, bound, 100), self.assertRaises(ValueError):
                    review.package(archive, Path(directory) / 'out', expected)

    def test_slice_limit_and_multiple_slices_preserve_receipt_inventory(self):
        with tempfile.TemporaryDirectory() as directory:
            archive, expected, _ = self.archive(directory, {'extra-1.log': b'a' * 20000, 'extra-2.log': b'b' * 20000})
            index = review.package(archive, Path(directory) / 'out', expected, slice_limit=1_035_000)
            self.assertGreater(len(index['slices']), 1)
            self.assertTrue(all(row['bytes'] < 1_035_000 for row in index['slices']))
            with patch.object(review, 'MAX_SLICES', 1), self.assertRaises(ValueError):
                review.package(archive, Path(directory) / 'too-many', expected, slice_limit=1_035_000)

    def test_authenticated_api_never_forwards_token_to_storage_redirect(self):
        payload = b'archive byte fixture'
        approved = {**review.APPROVED, 'size_in_bytes': len(payload)}
        metadata = self.metadata()
        metadata['size_in_bytes'] = len(payload)
        redirect = urllib.error.HTTPError('api', 302, 'redirect', {'Location': 'https://artifact.blob.core.windows.net/path?signature=fixture'}, None)
        with tempfile.TemporaryDirectory() as directory, patch.object(review, 'APPROVED', approved), patch.dict('os.environ', {'GITHUB_REPOSITORY': approved['repository'], 'GH_TOKEN': 'test-only-token'}), patch.object(review.urllib.request, 'build_opener') as factory:
            factory.return_value.open.side_effect = [io.BytesIO(json.dumps(metadata).encode()), redirect, io.BytesIO(payload)]
            # Default-argument expected metadata is deliberately the reviewed tuple;
            # override validation only for this network-routing unit fixture.
            with patch.object(review, 'validate_metadata'):
                review.fetch(Path(directory) / 'download.zip')
            calls = factory.return_value.open.call_args_list
            self.assertEqual(calls[0].args[0].headers['Authorization'], 'Bearer test-only-token')
            self.assertEqual(calls[1].args[0].headers['Authorization'], 'Bearer test-only-token')
            self.assertIsInstance(calls[2].args[0], str)
            self.assertNotIn('test-only-token', calls[2].args[0])
            self.assertEqual((Path(directory) / 'download.zip').read_bytes(), payload)

    def test_unapproved_storage_redirect_is_rejected(self):
        redirect = urllib.error.HTTPError('api', 302, 'redirect', {'Location': 'https://attacker.example/archive'}, None)
        with patch.dict('os.environ', {'GITHUB_REPOSITORY': review.APPROVED['repository'], 'GH_TOKEN': 'test-only-token'}), patch.object(review.urllib.request, 'build_opener') as factory:
            factory.return_value.open.side_effect = [io.BytesIO(json.dumps(self.metadata()).encode()), redirect]
            with self.assertRaisesRegex(ValueError, 'storage host'):
                review.fetch(Path('unused.zip'))
            self.assertEqual(factory.return_value.open.call_count, 2)

    def test_workflow_is_exact_marker_same_repository_readonly_and_bounded(self):
        path = Path(__file__).resolve().parents[2] / '.github/workflows/listing-artifact-review.yml'
        source = path.read_text()
        self.assertIn('[listing-review-12722724126]', source)
        self.assertIn("inputs.artifact_id == '12722724126'", source)
        self.assertIn('actions: read', source)
        self.assertIn('contents: read', source)
        self.assertIn('timeout-minutes: 30', source)
        self.assertIn('persist-credentials: false', source)
        for forbidden in ['contents: write', 'actions: write', 'secrets.', 'publish-results', 'git push', 'workflow_run:', 'schedule:']:
            self.assertNotIn(forbidden, source)
        with patch.dict('os.environ', {'GITHUB_REPOSITORY': 'different/repo'}), self.assertRaises(ValueError):
            review.fetch(Path('unused.zip'))


if __name__ == '__main__':
    unittest.main()
