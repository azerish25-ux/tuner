import io
import contextlib
import os
import sys
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
    def metadata(self, expected=review.APPROVED):
        base = 'https://api.github.com/repos/' + expected['repository'] + '/actions/artifacts/' + str(expected['artifact_id'])
        return {'id': expected['artifact_id'], 'name': expected['name'],
                'size_in_bytes': expected['size_in_bytes'], 'digest': expected['digest'],
                'workflow_run': {'id': expected['run_id'], 'head_sha': expected['source_sha'],
                                 'repository_id': review.REPOSITORY_ID,
                                 'head_repository_id': review.REPOSITORY_ID},
                'url': base, 'archive_download_url': base + '/zip', 'expired': False}

    def event(self, artifact_id, event_name='push'):
        event = {'repository': {'full_name': review.APPROVED['repository']}}
        if event_name == 'push':
            event['head_commit'] = {'message': 'Recover original review bytes [listing-review-' + artifact_id + ']'}
        else:
            event['inputs'] = {'artifact_id': artifact_id}
        return event

    def select(self, event_name, event, **kwargs):
        return review.select_artifact(event_name, event,
                                      kwargs.get('repository', review.APPROVED['repository']),
                                      kwargs.get('ref', review.ALLOWED_REFS[1]))

    def archive(self, directory, extra=None, wrong_hash=False, approved=review.APPROVED):
        # Byte-integrity fixture only: this is never claimed as a native/rendered image.
        payload = b'original-byte-integrity-unit-fixture' * 30
        image = 'assets/de-DE/ipad/rendered/ipad-de-DE-01.jpg'
        manifest = {'status': 'mechanically_verified', 'release_ready': False,
                    'visual_review': 'pending', 'native_review': 'pending',
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
        if approved['name'] == 'listing-assets-iphone-01':
            members = {name.replace('/ipad/', '/iphone/').replace('ipad-', 'iphone-'):
                       data.replace(b'/ipad-', b'/iphone-') for name, data in members.items()}
        members.update(extra or {})
        archive = Path(directory) / 'source.zip'
        with zipfile.ZipFile(archive, 'w') as z:
            for name, data in members.items():
                z.writestr(name, data)
        expected = {**approved, 'size_in_bytes': archive.stat().st_size,
                    'digest': 'sha256:' + review.digest(archive)}
        return archive, expected, members

    def test_metadata_tuple_rejects_every_unreviewed_component(self):
        for artifact_id, expected in review.REVIEWED_ARTIFACTS.items():
            review.validate_metadata(self.metadata(expected), expected)
            for key in ['id', 'name', 'size_in_bytes', 'digest', 'expired', 'workflow_run',
                        'url', 'archive_download_url']:
                data = self.metadata(expected)
                data[key] = None
                with self.subTest(artifact_id=artifact_id, key=key), self.assertRaises(ValueError):
                    review.validate_metadata(data, expected)
            for key in ['id', 'head_sha', 'repository_id', 'head_repository_id']:
                data = self.metadata(expected)
                data['workflow_run'][key] = 'other'
                with self.subTest(artifact_id=artifact_id, key=key), self.assertRaises(ValueError):
                    review.validate_metadata(data, expected)
            for key in ['url', 'archive_download_url']:
                for replacement in [('azerish25-ux/tuner', 'different/repo'),
                                    (artifact_id, '999'), ('https://', 'http://')]:
                    data = self.metadata(expected)
                    data[key] = data[key].replace(*replacement)
                    with self.assertRaisesRegex(ValueError, 'repository/path'):
                        review.validate_metadata(data, expected)
        old, new = review.REVIEWED_ARTIFACTS.values()
        with self.assertRaises(ValueError):
            review.validate_metadata(self.metadata(old), new)
        with self.assertRaises(ValueError):
            review.validate_metadata(self.metadata(new), old)

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
        for artifact_id, expected in review.REVIEWED_ARTIFACTS.items():
            payload = b'archive byte fixture'
            approved = {**expected, 'size_in_bytes': len(payload)}
            redirect = urllib.error.HTTPError('api', 302, 'redirect', {'Location': 'https://artifact.blob.core.windows.net/path?signature=fixture'}, None)
            with tempfile.TemporaryDirectory() as directory, patch.dict(review.REVIEWED_ARTIFACTS, {artifact_id: approved}), patch.dict('os.environ', {'GITHUB_REPOSITORY': approved['repository'], 'GH_TOKEN': 'test-only-token'}), patch.object(review.urllib.request, 'build_opener') as factory:
                factory.return_value.open.side_effect = [io.BytesIO(json.dumps(self.metadata(approved)).encode()), redirect, io.BytesIO(payload)]
                review.fetch(Path(directory) / 'download.zip', artifact_id)
                calls = factory.return_value.open.call_args_list
                self.assertEqual(calls[0].args[0].full_url, self.metadata(approved)['url'])
                self.assertEqual(calls[1].args[0].full_url, self.metadata(approved)['archive_download_url'])
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
        self.assertIn("options: ['12722724126', '12781917198']", source)
        self.assertIn("github.repository == 'azerish25-ux/tuner'", source)
        self.assertIn('cancel-in-progress: false', source)
        self.assertIn("if: ${{ success() && steps.recover.outputs.artifact_id != '' }}", source)
        self.assertEqual(source.count("success() && steps.recover.outputs.slice_count != ''"), 8)
        self.assertEqual(source.count('name: listing-review-${{ steps.recover.outputs.artifact_id }}-'), 9)
        for artifact_id in review.REVIEWED_ARTIFACTS:
            self.assertIn('[listing-review-' + artifact_id + ']', source)
            self.assertIn("inputs.artifact_id == '" + artifact_id + "'", source)
        self.assertIn('actions: read', source)
        self.assertIn('contents: read', source)
        self.assertIn('timeout-minutes: 30', source)
        self.assertIn('persist-credentials: false', source)
        for forbidden in ['contents: write', 'actions: write', 'secrets.', 'publish-results', 'git push', 'workflow_run:', 'schedule:', 'always()', 'continue-on-error:', 'pull_request_target:', 'inputs.url', '[skip ci]']:
            self.assertNotIn(forbidden, source)
        with patch.dict('os.environ', {'GITHUB_REPOSITORY': 'different/repo'}), self.assertRaises(ValueError):
            review.fetch(Path('unused.zip'))

    def test_registry_is_exactly_the_two_independently_reviewed_pins(self):
        self.assertEqual(set(review.REVIEWED_ARTIFACTS), {'12722724126', '12781917198'})
        new = review.REVIEWED_ARTIFACTS['12781917198']
        self.assertEqual(new, {
            'repository': 'azerish25-ux/tuner', 'artifact_id': 12781917198,
            'name': 'listing-assets-iphone-01', 'run_id': 40600424514,
            'source_sha': '9e1e3c41ec24c1a2c78c22ea7a90726dc4ae6599',
            'size_in_bytes': 627943240,
            'digest': 'sha256:2aff1f3f12163c9c779718ffd9642a886dcd025471cbb8f42663bd2d3add8258',
        })
        self.assertIs(review.REVIEWED_ARTIFACTS['12722724126'], review.APPROVED)

    def test_both_pins_keep_dispatch_and_exact_push_routes(self):
        for artifact_id, expected in review.REVIEWED_ARTIFACTS.items():
            for event_name in ['push', 'workflow_dispatch']:
                for ref in review.ALLOWED_REFS:
                    self.assertIs(self.select(event_name, self.event(artifact_id, event_name), ref=ref), expected)

    def test_unknown_inputs_ambiguous_markers_and_wrong_repository_fail_closed(self):
        valid = '12781917198'
        for artifact_id in ['999', '', '../12781917198', '12781917198/zip', ' 12781917198',
                            'https://api.github.com/repos/azerish25-ux/tuner/actions/artifacts/12781917198']:
            for event_name in ['push', 'workflow_dispatch']:
                with self.subTest(artifact_id=artifact_id, event_name=event_name), self.assertRaises(ValueError):
                    self.select(event_name, self.event(artifact_id, event_name))
        for message in ['', '[listing-review-12781917198',
                        '[listing-review-12781917198] [listing-review-12722724126]',
                        '[listing-review-12781917198] [listing-review-12781917198]',
                        '[listing-review-12781917198] [listing-review-999]',
                        '[listing-review-12781917198] [listing-review-999']:
            event = self.event(valid)
            event['head_commit']['message'] = message
            with self.assertRaises(ValueError):
                self.select('push', event)
        for event_name in ['push', 'workflow_dispatch']:
            event = self.event(valid, event_name)
            for kwargs in [{'repository': 'different/repo'}, {'ref': 'refs/pull/3/merge'}, {'ref': 'refs/heads/unreviewed'}]:
                with self.assertRaises(ValueError):
                    self.select(event_name, event, **kwargs)
            event['repository']['full_name'] = 'different/repo'
            with self.assertRaises(ValueError):
                self.select(event_name, event)
        for event_name, event in [('workflow_run', self.event(valid)), ('pull_request', self.event(valid)),
                                  ('push', {}), ('push', None), ('workflow_dispatch', {'inputs': []})]:
            with self.assertRaises(ValueError):
                self.select(event_name, event)

    def test_fetch_rejects_unreviewed_ids_and_repo_before_network(self):
        with patch.object(review.urllib.request, 'build_opener') as opener:
            for artifact_id in [None, 12781917198, '999', '12781917198/zip', 'https://attacker.example']:
                with self.assertRaises(ValueError):
                    review.fetch(Path('unused.zip'), artifact_id)
            for artifact_id in review.REVIEWED_ARTIFACTS:
                with patch.dict('os.environ', {'GITHUB_REPOSITORY': 'different/repo'}), self.assertRaises(ValueError):
                    review.fetch(Path('unused.zip'), artifact_id)
            opener.assert_not_called()

    def test_iphone_originals_failed_status_and_pending_reviews_are_unchanged(self):
        with tempfile.TemporaryDirectory() as directory:
            archive, expected, members = self.archive(directory, approved=review.REVIEWED_ARTIFACTS['12781917198'])
            index = review.package(archive, Path(directory) / 'out', expected)
            self.assertEqual(index['source'], expected)
            self.assertTrue(index['diagnostic_review_only'])
            with zipfile.ZipFile(Path(directory) / 'out' / index['slices'][0]['path']) as source:
                receipt = json.loads(source.read('REVIEW-RECEIPT.json'))
                self.assertTrue(any('/iphone/rendered/' in row['path'] for row in receipt['files']))
                for row in receipt['files']:
                    self.assertEqual(source.read('originals/' + row['path']), members[row['path']])
                manifest = json.loads(source.read('originals/assets/en-US/iphone/manifest.json'))
                self.assertEqual(manifest['status'], 'failed')
                self.assertFalse(manifest['release_ready'])
                german = json.loads(source.read('originals/assets/de-DE/iphone/manifest.json'))
                self.assertEqual(german['status'], 'mechanically_verified')
                self.assertFalse(german['release_ready'])
                self.assertEqual(german['visual_review'], 'pending')
                self.assertEqual(german['native_review'], 'pending')

    def test_fetch_truncation_excess_and_metadata_errors_fail_closed(self):
        for artifact_id, expected in review.REVIEWED_ARTIFACTS.items():
            approved = {**expected, 'size_in_bytes': 10}
            for payload in [b'short', b'way too many bytes']:
                redirect = urllib.error.HTTPError('api', 302, 'redirect', {'Location': 'https://artifact.blob.core.windows.net/path'}, None)
                with tempfile.TemporaryDirectory() as directory, patch.dict(review.REVIEWED_ARTIFACTS, {artifact_id: approved}), patch.dict('os.environ', {'GITHUB_REPOSITORY': approved['repository'], 'GH_TOKEN': 'test-only-token'}), patch.object(review.urllib.request, 'build_opener') as factory:
                    factory.return_value.open.side_effect = [io.BytesIO(json.dumps(self.metadata(approved)).encode()), redirect, io.BytesIO(payload)]
                    with self.assertRaises(ValueError):
                        review.fetch(Path(directory) / 'archive.zip', artifact_id)
            with patch.dict('os.environ', {'GITHUB_REPOSITORY': expected['repository'], 'GH_TOKEN': 'test-only-token'}), patch.object(review.urllib.request, 'build_opener') as factory:
                metadata = self.metadata(expected)
                metadata['digest'] = 'sha256:' + '0' * 64
                factory.return_value.open.return_value = io.BytesIO(json.dumps(metadata).encode())
                with self.assertRaises(ValueError):
                    review.fetch(Path('unused.zip'), artifact_id)
                self.assertEqual(factory.return_value.open.call_count, 1)

    def test_main_publishes_pin_and_slice_outputs_only_after_success(self):
        for artifact_id, expected in review.REVIEWED_ARTIFACTS.items():
            for failure in [None, 'fetch', 'package']:
                with tempfile.TemporaryDirectory() as directory:
                    event = Path(directory) / 'event.json'
                    output = Path(directory) / 'output.txt'
                    event.write_text(json.dumps(self.event(artifact_id)))
                    env = {'GITHUB_REPOSITORY': expected['repository'], 'GITHUB_REF': review.ALLOWED_REFS[1],
                           'GITHUB_EVENT_NAME': 'push', 'GITHUB_EVENT_PATH': str(event), 'GITHUB_OUTPUT': str(output)}
                    with patch.dict(os.environ, env), patch.object(sys, 'argv', ['listing_artifact_review.py']), patch.object(review, 'fetch') as fetch, patch.object(review, 'package') as package, contextlib.redirect_stdout(io.StringIO()):
                        package.return_value = {'slices': [{'path': 'listing-review-01.zip'}]}
                        if failure:
                            {'fetch': fetch, 'package': package}[failure].side_effect = ValueError('fixture failure')
                            with self.assertRaises(ValueError):
                                review.main()
                            self.assertFalse(output.exists())
                            if failure == 'fetch':
                                package.assert_not_called()
                        else:
                            review.main()
                            fetch.assert_called_once_with(Path('source-listing-artifact.zip'), artifact_id)
                            package.assert_called_once_with(Path('source-listing-artifact.zip'), Path('review-out'), expected)
                            self.assertEqual(output.read_text(), 'artifact_id=' + artifact_id + '\nslice_count=1\n')

    def test_main_rejects_ambiguous_event_and_cli_inputs_before_recovery(self):
        with tempfile.TemporaryDirectory() as directory:
            event = Path(directory) / 'event.json'
            data = self.event('12781917198')
            data['head_commit']['message'] += ' [listing-review-12722724126]'
            event.write_text(json.dumps(data))
            env = {'GITHUB_REPOSITORY': review.APPROVED['repository'], 'GITHUB_REF': review.ALLOWED_REFS[1],
                   'GITHUB_EVENT_NAME': 'push', 'GITHUB_EVENT_PATH': str(event)}
            with patch.dict(os.environ, env), patch.object(review, 'fetch') as fetch, patch.object(review, 'package') as package:
                with patch.object(sys, 'argv', ['listing_artifact_review.py']), self.assertRaises(ValueError):
                    review.main()
                with patch.object(sys, 'argv', ['listing_artifact_review.py', '12781917198']), self.assertRaises(SystemExit):
                    review.main()
                fetch.assert_not_called()
                package.assert_not_called()


if __name__ == '__main__':
    unittest.main()
