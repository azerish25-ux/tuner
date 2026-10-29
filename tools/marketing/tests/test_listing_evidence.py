import copy
import json
from pathlib import Path
import subprocess
import sys
import tempfile
from types import SimpleNamespace
import unittest
from unittest.mock import patch
import zipfile

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import listing_assets as assets
import listing_evidence as evidence
import run_listing_assets as runner


class ReviewEvidenceTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.raw = self.root / 'assets'
        self.manifests = self.root / 'manifests'
        self.base = self.raw / 'de-DE/iphone'
        self.attachments = self.base / 'capture/attempt-1/attachments'
        self.attachments.mkdir(parents=True)
        self.names = ['10b-tune-locked', '31b-instruments-folk']
        for name, value in [('expected_captures', self.names), ('screenshot_role', SimpleNamespace(native_size=(12, 26)))]:
            p = patch.object(assets, name, return_value=value)
            p.start()
            self.addCleanup(p.stop)
        from PIL import Image
        entries = []
        for number, name in enumerate(self.names, 1):
            filename = f'original-{number}.png'
            Image.new('RGB', (12, 26), (number * 60, 20, 30)).save(self.attachments / filename)
            entries.append({'suggestedHumanReadableName': name, 'exportedFileName': filename})
        Image.new('RGB', (12, 26)).save(self.attachments / 'automatic.png')
        (self.attachments / 'automatic.mp4').write_bytes(b'automatic-video-not-selected')
        entries += [{'suggestedHumanReadableName': 'automatic screenshot', 'exportedFileName': 'automatic.png'},
                    {'suggestedHumanReadableName': 'automatic video', 'exportedFileName': 'automatic.mp4'}]
        assets.write_json(self.attachments / 'manifest.json', [{'attachments': entries}])
        rendered = self.base / 'rendered'
        rendered.mkdir()
        for number in (1, 2):
            Image.new('RGB', (12, 26), (number * 50, 90, 30)).save(rendered / f'iphone-de-DE-{number:02d}.jpg')
        Image.new('RGB', (24, 26)).save(rendered / 'iphone-de-DE-sheet.png')
        self.source = {'source_sha': 'a' * 40, 'build_sha256': 'b' * 64}
        spec = assets.locale_spec('de-DE')
        event = {key: spec[key] for key in ('listing_locale', 'app_language', 'apple_languages', 'apple_locale')}
        verified = {**event, 'checked_fields': ['tune', 'learn', 'songs', 'practice', 'progress'],
                    'observed_labels': assets.expected_tab_labels('de')}
        self.manifest = {**spec, **self.source, 'kind': 'iphone', 'schema_version': 1,
                         'status': 'mechanically_verified', 'release_ready': False,
                         'visual_review': 'pending', 'native_review': 'pending',
                         'device': {'name': 'iPhone 17 Pro', 'id': 'fixture-device', 'runtime': 'fixture-runtime'},
                         'language_evidence': [verified], 'launch_evidence': [event] * 2,
                         'captures': assets.capture_records(self.attachments, 'de-DE', 'iphone', self.base),
                         'assets': assets.screenshot_records(rendered, 'de-DE', 'iphone', self.base),
                         'selected_attempt': 'capture/attempt-1'}
        assets.write_json(self.raw / 'device.json', self.manifest['device'])
        self.save()

    def save(self):
        assets.write_json(self.base / 'manifest.json', self.manifest)
        assets.write_json(self.manifests / 'de-DE-iphone.manifest.json', self.manifest)

    def selected(self):
        return evidence.review_records(self.raw, self.manifests, ['de-DE'], 'iphone', self.source)

    def test_original_pngs_and_every_final_asset_are_included_without_automatic_media(self):
        records, coverage = self.selected()
        rows = [row for _, row in records]
        self.assertEqual([row['capture'] for row in rows if row['role'] == 'original-native-capture'], self.names)
        self.assertEqual(len([row for row in rows if row['role'] == 'original-final-asset']), 3)
        self.assertFalse(any('automatic' in row['path'] for row in rows))
        self.assertEqual(coverage[0]['review_assets'], 'complete')
        out = self.root / 'review'
        evidence.write_bundle(out, records, {'source': self.source, 'release_ready': False},
                              limit=1000000, expanded_limit=1000000, compress=False)
        with zipfile.ZipFile(out / 'bundle.zip') as archive:
            for root, row in records:
                self.assertEqual(archive.read('originals/' + row['path']), (root / row['path']).read_bytes())
        self.assertFalse(json.loads((out / 'index.json').read_text())['release_ready'])

    def test_missing_requested_native_png_and_rendered_frame_are_fatal(self):
        for relative in (self.manifest['captures'][0]['path'], self.manifest['assets'][0]['path']):
            path = self.base / relative
            data = path.read_bytes()
            path.unlink()
            with self.subTest(relative=relative), self.assertRaisesRegex(ValueError, 'Missing'):
                self.selected()
            path.write_bytes(data)

    def test_changed_source_bytes_hash_or_pixel_hash_are_fatal(self):
        self.manifest['captures'][0]['sha256'] = 'f' * 64
        self.save()
        with self.assertRaisesRegex(ValueError, 'hash mismatch'):
            self.selected()
        self.manifest['captures'] = assets.capture_records(self.attachments, 'de-DE', 'iphone', self.base)
        self.manifest['captures'][0]['pixel_sha256'] = 'e' * 64
        self.save()
        with self.assertRaisesRegex(ValueError, 'selection/hash/pixels'):
            self.selected()

    def test_native_manifest_cannot_select_another_png_under_the_requested_name(self):
        data = assets.read_json(self.attachments / 'manifest.json')
        data[0]['attachments'][0]['exportedFileName'] = 'automatic.png'
        assets.write_json(self.attachments / 'manifest.json', data)
        with self.assertRaisesRegex(ValueError, 'selection/hash/pixels'):
            self.selected()

    def test_no_loose_filename_fallback_when_native_export_manifest_missing(self):
        (self.attachments / 'manifest.json').unlink()
        with self.assertRaisesRegex(ValueError, 'Missing'):
            self.selected()

    def test_native_export_traversal_is_rejected_before_image_reads(self):
        data = assets.read_json(self.attachments / 'manifest.json')
        for bad in ('../outside.png', '/tmp/outside.png', 'a\\b.png', '..', 'x:y.png'):
            data[0]['attachments'][0]['exportedFileName'] = bad
            assets.write_json(self.attachments / 'manifest.json', data)
            with self.subTest(bad=bad), self.assertRaisesRegex(ValueError, 'Unsafe native'):
                self.selected()

    def test_manifest_path_traversal_absolute_and_noncanonical_names_are_rejected(self):
        for bad in ('../outside.png', '/tmp/outside.png', 'a//b.png', './a.png', 'a\\b.png', 'x:y.png'):
            self.manifest['captures'][0]['path'] = bad
            self.save()
            with self.subTest(bad=bad), self.assertRaises(ValueError):
                self.selected()

    def test_symlinks_for_selected_file_and_locale_parent_are_rejected(self):
        path = self.attachments / 'original-1.png'
        path.rename(self.attachments / 'target.png')
        path.symlink_to('target.png')
        with self.assertRaisesRegex(ValueError, 'Symlink'):
            self.selected()
        path.unlink()
        (self.attachments / 'target.png').rename(path)
        (self.raw / 'de-DE').rename(self.raw / 'actual')
        (self.raw / 'de-DE').symlink_to('actual', target_is_directory=True)
        with self.assertRaisesRegex(ValueError, 'Symlink'):
            self.selected()

    def test_wrong_source_build_locale_and_approval_identity_are_rejected(self):
        original = copy.deepcopy(self.manifest)
        for key, value in [('source_sha', 'c' * 40), ('build_sha256', 'd' * 64), ('listing_locale', 'en-US'),
                           ('payload_sha256', 'e' * 64), ('device', {'id': 'other'}), ('release_ready', True), ('native_review', 'passed')]:
            self.manifest = {**original, key: value}
            self.save()
            with self.subTest(key=key), self.assertRaises(ValueError):
                self.selected()

    def test_selected_attempt_cannot_change_and_compact_manifest_cannot_disagree(self):
        self.manifest['selected_attempt'] = 'capture/attempt-2'
        self.save()
        with self.assertRaises(ValueError):
            self.selected()
        self.manifest['selected_attempt'] = 'capture/attempt-1'
        self.save()
        assets.write_json(self.base / 'manifest.json', {**self.manifest, 'status': 'failed'})
        with self.assertRaisesRegex(ValueError, 'disagreement'):
            self.selected()

    def test_missing_or_extra_requested_locale_manifest_is_not_silently_dropped(self):
        with self.assertRaisesRegex(ValueError, 'Missing or unexpected'):
            evidence.review_records(self.raw, self.manifests, ['de-DE', 'en-US'], 'iphone', self.source)
        assets.write_json(self.manifests / 'en-US-iphone.manifest.json', {})
        with self.assertRaisesRegex(ValueError, 'Missing or unexpected'):
            self.selected()

    def test_failed_source_is_preserved_not_relabelled_or_replaced_with_automatic_media(self):
        self.manifest['status'] = 'failed'
        self.manifest['error'] = 'UI tests failed'
        self.manifest.pop('captures')
        self.manifest.pop('assets')
        self.save()
        before = (self.base / 'manifest.json').read_bytes()
        records, coverage = self.selected()
        self.assertEqual([row['role'] for _, row in records], ['original-native-device', 'original-source-manifest'])
        self.assertEqual(coverage[0]['source_status'], 'failed')
        self.assertEqual(coverage[0]['requested_captures'], self.names)
        self.assertEqual((self.base / 'manifest.json').read_bytes(), before)

    def test_input_and_final_package_bounds_fail_without_touching_originals(self):
        records, _ = self.selected()
        before = (self.base / 'manifest.json').read_bytes()
        with self.assertRaisesRegex(ValueError, 'expanded byte bound'):
            evidence.write_bundle(self.root / 'too-many', records, {}, limit=1000000, expanded_limit=1, compress=False)
        with self.assertRaisesRegex(ValueError, 'byte bound'):
            evidence.write_bundle(self.root / 'too-big', records, {}, limit=200, expanded_limit=1000000, compress=False)
        self.assertFalse((self.root / 'too-big/bundle.zip').exists())
        self.assertFalse((self.root / 'too-big/bundle.zip.partial').exists())
        self.assertEqual((self.base / 'manifest.json').read_bytes(), before)
        with patch.object(evidence, 'MAX_FILE', 1), self.assertRaisesRegex(ValueError, 'byte bound'):
            self.selected()
        with patch.object(evidence, 'MAX_FILES', 1), self.assertRaisesRegex(ValueError, 'count'):
            evidence.write_bundle(self.root / 'count', records, {}, limit=1000000, expanded_limit=1000000, compress=False)

    def test_stale_hash_at_packaging_and_duplicate_paths_are_rejected(self):
        records, _ = self.selected()
        with self.assertRaisesRegex(ValueError, 'Duplicate'):
            evidence.write_bundle(self.root / 'duplicate', records + records, {}, limit=1000000, expanded_limit=1000000, compress=False)
        (self.base / 'manifest.json').write_text('{}')
        with self.assertRaisesRegex(ValueError, 'changed before'):
            evidence.write_bundle(self.root / 'changed', records, {}, limit=1000000, expanded_limit=1000000, compress=False)

    def failure_fixture(self):
        method = 'test10PlayAlongLesson'
        (self.attachments.parent / 'test.log').write_text(
            f"full assertion before console tail\nTest Case '-[TimbreUITests.TimbreUITests {method}]' failed (1 seconds).\n")
        (self.attachments / 'failure.png').write_bytes((self.attachments / 'original-1.png').read_bytes())
        entry = {'suggestedHumanReadableName': f'zz-failure--[TimbreUITests {method}]_0_00000000-0000-0000-0000-000000000000.png',
                 'exportedFileName': 'failure.png', 'deviceId': self.manifest['device']['id'],
                 'deviceName': self.manifest['device']['name']}
        data = assets.read_json(self.attachments / 'manifest.json')
        data.append({'testIdentifier': f'TimbreUITests/{method}()',
                     'testIdentifierURL': f'test://com.apple.xcode/Timbre/TimbreUITests/TimbreUITests/{method}',
                     'attachments': [entry]})
        assets.write_json(self.attachments / 'manifest.json', data)
        return data

    def diagnostics(self):
        with patch.object(assets, 'selectors', return_value=['TimbreUITests/TimbreUITests/test10PlayAlongLesson']):
            return evidence.diagnostic_records(self.raw, source=self.source, locales=['de-DE'], kind='iphone')

    def test_explicit_native_failure_png_is_original_and_diagnostic_only_with_test_provenance(self):
        self.failure_fixture()
        records, errors = self.diagnostics()
        self.assertEqual(errors, [])
        rows = [row for _, row in records if row['role'] == 'original-failure-screenshot-diagnostic-only']
        self.assertEqual(len(rows), 1)
        self.assertEqual(rows[0]['sha256'], assets.digest(self.attachments / 'failure.png'))
        self.assertEqual(rows[0]['testIdentifier'], 'TimbreUITests/test10PlayAlongLesson()')
        self.assertEqual(rows[0]['source_sha'], self.source['source_sha'])
        self.assertEqual(rows[0]['device'], self.manifest['device'])
        self.assertFalse(any('automatic' in row['path'] for _, row in records))
        evidence.write_bundle(self.root / 'failure-review', records, {'release_ready': False},
                              limit=1000000, expanded_limit=1000000, compress=True)
        with zipfile.ZipFile(self.root / 'failure-review/bundle.zip') as bundle:
            self.assertEqual(bundle.read('originals/' + rows[0]['path']), (self.attachments / 'failure.png').read_bytes())

    def test_missing_ambiguous_or_unmapped_failure_png_is_explicit_without_guessing(self):
        original = self.failure_fixture()
        for changed in ('absent', 'duplicate', 'wrong-test', 'wrong-device', 'automatic-name'):
            data = copy.deepcopy(original)
            if changed == 'absent':
                data[-1]['attachments'] = []
            elif changed == 'duplicate':
                data[-1]['attachments'] *= 2
            elif changed == 'wrong-test':
                data[-1]['testIdentifier'] = 'TimbreUITests/test11StoreTunerLock()'
            elif changed == 'wrong-device':
                data[-1]['attachments'][0]['deviceId'] = 'other-device'
            else:
                data[-1]['attachments'][0]['suggestedHumanReadableName'] = 'Automatic XCTest screenshot'
            assets.write_json(self.attachments / 'manifest.json', data)
            records, errors = self.diagnostics()
            with self.subTest(changed=changed):
                self.assertTrue(errors)
                self.assertFalse(any(row['role'] == 'original-failure-screenshot-diagnostic-only' for _, row in records))
                self.assertTrue(any(row['path'].endswith('/test.log') for _, row in records))

    def test_failure_capture_requires_failed_log_and_matching_source(self):
        self.failure_fixture()
        log = self.attachments.parent / 'test.log'
        log.write_text(log.read_text().replace("' failed", "' passed"))
        records, _ = self.diagnostics()
        self.assertFalse(any(row['role'] == 'original-failure-screenshot-diagnostic-only' for _, row in records))
        log.write_text(log.read_text().replace("' passed", "' failed"))
        self.manifest['source_sha'] = 'c' * 40
        self.save()
        records, errors = self.diagnostics()
        self.assertTrue(any('source/build/locale/device' in error for error in errors))
        self.assertFalse(any(row['role'] == 'original-failure-screenshot-diagnostic-only' for _, row in records))

    def test_cli_diagnostics_packages_logs_and_failure_images_separately_with_source_identity(self):
        self.failure_fixture()
        archive = self.root / 'products.tgz'
        archive.write_bytes(b'unsigned simulator build fixture')
        info = self.root / 'build-info.json'
        self.source['build_sha256'] = assets.digest(archive)
        self.manifest['build_sha256'] = self.source['build_sha256']
        self.manifest['status'] = 'failed'
        self.manifest['error'] = 'UI test failed'
        self.save()
        assets.write_json(info, {'source_sha': self.source['source_sha'], 'archive_sha256': self.source['build_sha256']})
        out, failure_out = self.root / 'cli-diagnostics', self.root / 'cli-failures'
        argv = ['listing_evidence.py', 'diagnostics', '--assets', str(self.raw), '--manifests', str(self.manifests),
                '--build-info', str(info), '--build-archive', str(archive), '--source-sha', self.source['source_sha'],
                '--locales', 'de-DE', '--kind', 'iphone', '--out', str(out), '--failure-out', str(failure_out)]
        with patch.object(sys, 'argv', argv), patch.object(assets, 'selectors', return_value=['TimbreUITests/TimbreUITests/test10PlayAlongLesson']):
            self.assertEqual(evidence.main(), 0)
        text_index = assets.read_json(out / 'index.json')
        image_index = assets.read_json(failure_out / 'index.json')
        self.assertFalse(text_index['release_ready'])
        self.assertEqual(text_index['source']['build_sha256'], self.source['build_sha256'])
        self.assertTrue(image_index['diagnostic_only'])
        self.assertEqual(len(image_index['files']), 1)
        self.assertFalse(any(row['path'].endswith('.png') for row in text_index['files']))
        self.assertEqual(assets.read_json(self.base / 'manifest.json')['status'], 'failed')

    def test_failure_media_overflow_cannot_hide_already_packaged_full_logs(self):
        self.failure_fixture()
        records, errors = self.diagnostics()
        self.assertEqual(errors, [])
        out, image_out = self.root / 'logs-first', self.root / 'failure-overflow'
        with patch.object(evidence, 'REVIEW_LIMIT', 100):
            with self.assertRaisesRegex(ValueError, 'byte bound'):
                evidence.write_diagnostics(out, image_out, records, {'status': 'complete'})
        self.assertTrue((out / 'bundle.zip').is_file())
        with zipfile.ZipFile(out / 'bundle.zip') as bundle:
            log_path = 'originals/de-DE/iphone/capture/attempt-1/test.log'
            self.assertEqual(bundle.read(log_path), (self.attachments.parent / 'test.log').read_bytes())
            self.assertFalse(any(path.endswith('.png') for path in bundle.namelist()))
        self.assertFalse((image_out / 'bundle.zip').exists())

    def test_failure_identity_error_does_not_drop_independent_hierarchy_text(self):
        data = self.failure_fixture()
        (self.attachments / 'hierarchy.txt').write_text('original native hierarchy')
        data[0]['attachments'].append({'suggestedHumanReadableName': 'view hierarchy', 'exportedFileName': 'hierarchy.txt'})
        assets.write_json(self.attachments / 'manifest.json', data)
        self.manifest['source_sha'] = 'c' * 40
        self.save()
        records, errors = self.diagnostics()
        self.assertTrue(errors)
        self.assertTrue(any(row['path'].endswith('/hierarchy.txt') for _, row in records))

    def test_missing_png_dependency_retains_logs_with_explicit_gap(self):
        self.failure_fixture()
        with patch.dict(sys.modules, {'PIL': None}):
            records, errors = self.diagnostics()
        self.assertTrue(any('failure PNG unavailable' in error for error in errors))
        self.assertTrue(any(row['path'].endswith('/test.log') for _, row in records))
        self.assertFalse(any(row['role'] == 'original-failure-screenshot-diagnostic-only' for _, row in records))

    def test_failure_png_missing_bytes_wrong_dimensions_and_symlink_are_incomplete(self):
        self.failure_fixture()
        path = self.attachments / 'failure.png'
        path.unlink()
        records, errors = self.diagnostics()
        self.assertTrue(any('failure PNG unavailable' in error for error in errors))
        from PIL import Image
        Image.new('RGB', (1, 1)).save(path)
        _, errors = self.diagnostics()
        self.assertTrue(any('wrong native device dimensions' in error for error in errors))
        path.unlink()
        path.symlink_to('original-1.png')
        with self.assertRaisesRegex(ValueError, 'Symlink'):
            self.diagnostics()


class DiagnosticEvidenceTests(unittest.TestCase):
    def test_full_log_summary_hierarchy_and_export_manifest_without_media_or_xcresult(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            attempt = root / 'de-DE/iphone/capture/attempt-1'
            attach = attempt / 'attachments'
            attach.mkdir(parents=True)
            full_log = 'assertion before the console tail\n' + '\n'.join(str(i) for i in range(1000))
            (attempt / 'test.log').write_text(full_log)
            (attempt / 'Tests.xcresult').mkdir()
            (attempt / 'Tests.xcresult/opaque.bin').write_bytes(b'opaque')
            (attach / 'tree.txt').write_text('full native hierarchy')
            (attach / 'automatic.png').write_bytes(b'not included')
            (attach / 'automatic.mp4').write_bytes(b'not included')
            assets.write_json(attach / 'manifest.json', [{'attachments': [
                {'suggestedHumanReadableName': 'screen-hierarchy', 'exportedFileName': 'tree.txt'},
                {'suggestedHumanReadableName': 'automatic', 'exportedFileName': 'automatic.png'}]}])
            for report in ('summary', 'tests'):
                assets.write_json(attempt / f'xcresult-{report}.json', {'testFailures': ['original assertion']})
            assets.write_json(attempt / 'xcresult-export-status.json', [
                {'report': name, 'status': 'exported'} for name in ('summary', 'tests')])
            records, errors = evidence.diagnostic_records(root)
            self.assertEqual(errors, [])
            paths = [row['path'] for _, row in records]
            self.assertTrue(any(path.endswith('/tree.txt') for path in paths))
            self.assertFalse(any(path.endswith(('.png', '.mp4', '.bin')) for path in paths))
            evidence.write_bundle(root / 'output', records, {'status': 'complete'}, limit=1000000,
                                  expanded_limit=1000000, compress=True)
            with zipfile.ZipFile(root / 'output/bundle.zip') as bundle:
                self.assertEqual(bundle.read('originals/' + str((attempt / 'test.log').relative_to(root))).decode(), full_log)

    def test_missing_summary_is_explicit_and_log_is_still_packaged(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            (root / 'Tests.xcresult').mkdir()
            (root / 'test.log').write_text('test failed')
            records, errors = evidence.diagnostic_records(root)
            self.assertTrue(any('summary export missing' in error for error in errors))
            self.assertEqual(records[0][1]['path'], 'test.log')

    def test_export_failures_are_recorded_and_never_mask_original_test_status(self):
        with tempfile.TemporaryDirectory() as temporary:
            folder = Path(temporary)
            for failure in (OSError('no xcrun'), subprocess.TimeoutExpired('xcrun', 120)):
                with patch.object(evidence.subprocess, 'run', side_effect=failure):
                    evidence.export_result_summaries(folder / 'Tests.xcresult', folder)
                rows = assets.read_json(folder / 'xcresult-export-status.json')
                self.assertEqual(len(rows), 2)
                self.assertTrue(all(row['status'] == 'failed' for row in rows))
            with patch.object(evidence, 'export_result_summaries') as summaries, patch.object(runner, 'run') as export:
                (folder / 'Tests.xcresult').mkdir()
                runner.export_attachments(folder / 'Tests.xcresult', folder / 'attachments')
                summaries.assert_called_once()
                export.assert_called_once()

    def test_partial_or_malformed_attachment_export_keeps_safe_full_logs(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            (root / 'test.log').write_text('original full failing assertion')
            folder = root / 'attachments'
            folder.mkdir()
            for content in (None, '{broken', '[{"attachments": [{"suggestedHumanReadableName":"tree", "exportedFileName":"../outside.txt"}]}]'):
                if content is not None:
                    (folder / 'manifest.json').write_text(content)
                records, errors = evidence.diagnostic_records(root)
                self.assertTrue(any('attachment export incomplete' in error for error in errors))
                self.assertIn('test.log', [row['path'] for _, row in records])
                self.assertFalse(any('outside' in row['path'] for _, row in records))

    def test_exported_status_without_actual_logs_and_summaries_is_incomplete(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            (root / 'Tests.xcresult').mkdir()
            assets.write_json(root / 'xcresult-export-status.json', [
                {'report': report, 'status': 'exported'} for report in ('summary', 'tests')])
            _, errors = evidence.diagnostic_records(root)
            self.assertEqual(len(errors), 4)
            for name in ('test.log', 'xcresult-summary.json', 'xcresult-tests.json'):
                self.assertTrue(any(name in error for error in errors))

    def test_summary_status_write_failure_does_not_mask_native_failure(self):
        import contextlib
        import io
        with tempfile.TemporaryDirectory() as temporary:
            with patch.object(evidence.subprocess, 'run', side_effect=OSError('native failure')):
                with patch.object(evidence.assets, 'write_json', side_effect=OSError('disk full')):
                    with contextlib.redirect_stdout(io.StringIO()) as output:
                        evidence.export_result_summaries(Path(temporary) / 'Tests.xcresult', Path(temporary))
            self.assertIn('Could not persist', output.getvalue())

    def test_build_archive_and_source_identity_must_match(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            archive = root / 'products.tgz'
            archive.write_bytes(b'fixture unsigned products')
            info = root / 'build-info.json'
            assets.write_json(info, {'source_sha': 'a' * 40, 'archive_sha256': assets.digest(archive)})
            self.assertEqual(evidence.source_identity(info, archive, 'a' * 40)['build_sha256'], assets.digest(archive))
            for sha in ('bad', 'c' * 40):
                with self.subTest(sha=sha), self.assertRaises(ValueError):
                    evidence.source_identity(info, archive, sha)
            archive.write_bytes(b'changed products')
            with self.assertRaisesRegex(ValueError, 'identity mismatch'):
                evidence.source_identity(info, archive, 'a' * 40)


class WorkflowContractTests(unittest.TestCase):
    def test_small_uploads_precede_unchanged_full_forensics_and_failures_are_not_ignored(self):
        text = (assets.ROOT / '.github/workflows/listing-assets.yml').read_text()
        start = text.index('      - name: Capture and render selected locales without rebuilding')
        end = text.index('\n  inventory:', start)
        section = text[start:end]
        for name in ('listing-manifests-', 'listing-diagnostics-', 'listing-failure-images-', 'listing-review-'):
            self.assertLess(section.index('name: ' + name), section.index('name: listing-assets-'))
        raw = section[section.index('name: listing-assets-'):]
        self.assertIn('ci-out/assets\n            ci-out/caption-typography.json', raw)
        self.assertIn('retention-days: 7', raw)
        self.assertEqual(section.count('if: always()'), 7)
        self.assertIn('\"${LISTING_PY:-python3}\" tools/marketing/listing_evidence.py diagnostics', section)
        self.assertNotIn('continue-on-error', section)
        self.assertNotIn('|| true', section)
        self.assertNotIn('delete-artifact', text)
        self.assertIn("-p 'test_listing_evidence.py'", text)
        self.assertIn('pattern: listing-manifests-*', text)


if __name__ == '__main__':
    unittest.main()
