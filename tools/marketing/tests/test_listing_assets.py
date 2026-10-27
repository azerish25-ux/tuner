import copy
import json
from pathlib import Path
import sys
import tempfile
import unittest
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import listing_assets as assets
import run_listing_assets as runner


class ListingPlanTests(unittest.TestCase):
    def test_all_fifty_exactly_once_per_default_asset_kind(self):
        plan = assets.make_plan('all', 'all')
        self.assertTrue(plan['full_default_listing_scope'])
        self.assertEqual(len(plan['matrix']['include']), 100)
        self.assertEqual(len(set(x['id'] for x in plan['matrix']['include'])), 100)
        for kind in assets.DEFAULT_KINDS:
            locales = [locale for row in plan['matrix']['include'] if row['kind'] == kind for locale in row['locales'].split(',')]
            self.assertEqual(len(locales), 50)
            self.assertEqual(set(locales), set(assets.locale_rows()))

    def test_partial_scope_never_claims_full_listing(self):
        for scope in ['all', 'screenshots', 'previews']:
            self.assertFalse(assets.make_plan('en-US,de-DE,ar-SA', scope)['full_default_listing_scope'])
        self.assertFalse(assets.make_plan('all', 'screenshots')['full_default_listing_scope'])
        self.assertEqual(assets.make_plan('en-US', 'all', violin=True)['kinds'], list(assets.KINDS))

    def test_push_markers_select_exact_pilot_or_fifty_and_ordinary_push_is_blocked(self):
        for message, wanted in [('Repair [listing-assets-pilot]', ['en-US', 'de-DE', 'ar-SA']),
                                ('Ready [listing-assets-all]', list(assets.locale_rows()))]:
            request = assets.request_scope('push', message, 'ja', 'screenshots', True)
            plan = assets.make_plan(request['locales'], request['scope'], request['violin'])
            self.assertEqual(plan['locales'], wanted)
            self.assertEqual(plan['kinds'], ['iphone', 'iphone-large', 'ipad', 'preview-main'])
        for message in ['Ordinary translation commit', '[capture-check]', '[listing-assets-pilot] [listing-assets-all]']:
            with self.subTest(message=message), self.assertRaises(ValueError):
                assets.request_scope('push', message, 'all', 'all', False)
        manual = assets.request_scope('workflow_dispatch', '[listing-assets-all]', 'de-DE', 'previews', True)
        self.assertEqual(manual, {'locales': 'de-DE', 'scope': 'previews', 'violin': True, 'trigger': 'manual'})

    def test_rejects_duplicate_unknown_or_injected_locale_codes(self):
        for value in ['de-DE,de-DE', '', '../en-US', 'en-US;touch x', 'en_US', 'all,en-US', 'fr-FR, en-US']:
            with self.subTest(value=value), self.assertRaises(ValueError):
                assets.select_locales(value)
        with self.assertRaises(ValueError):
            assets.make_plan('all', 'all', shard_size=50)

    def test_listing_only_languages_are_requested_then_english_not_claimed_supported(self):
        for locale, first in assets.FALLBACK_LANGUAGES.items():
            spec = assets.locale_spec(locale)
            self.assertEqual(spec['apple_languages'], [first, 'en'])
            self.assertEqual(spec['app_language'], 'en')
            self.assertFalse(spec['ui_support_claim'])
            self.assertTrue(spec['listing_only_fallback'])
        self.assertEqual(assets.locale_spec('de-DE')['apple_languages'], ['de'])
        self.assertEqual(assets.locale_spec('zh-Hans')['app_language'], 'zh-CN')
        self.assertEqual(assets.locale_spec('pt-PT')['apple_locale'], 'pt_PT')
        self.assertEqual(assets.locale_spec('pt-BR')['apple_locale'], 'pt_BR')

    def test_real_test_selectors_cover_nine_phone_and_four_tablet_frames(self):
        phone = (assets.ROOT / 'ios/TimbreUITests/TimbreUITests.swift').read_text()
        self.assertEqual(len(assets.expected_captures('en-US', 'iphone')), 9)
        self.assertEqual(len(assets.expected_captures('ar-SA', 'ipad')), 4)
        for name, method in assets.CAPTURE_TESTS.items():
            body = phone.split('func ' + method + '()', 1)[1].split('\n    func ', 1)[0]
            self.assertIn('"' + name + '"', body)
        self.assertEqual(len(assets.selectors('iphone')), 8)
        self.assertEqual([selector.rsplit('/', 1)[1] for selector in assets.selectors('iphone')], [
            'test11StoreTunerLock', 'test17StoreInstrumentWall', 'test14StoreSongPerform',
            'test10PlayAlongLesson', 'test09LearnChordLesson', 'test12StoreChord',
            'test13StoreStrum', 'test05OtherTabs',
        ])
        self.assertNotIn('test19StoreViolinResults', ','.join(assets.selectors('iphone')))
        for kind in assets.KINDS:
            for selector in assets.selectors(kind):
                _, cls, method = selector.split('/')
                self.assertIn('func ' + method + '()', (assets.ROOT / 'ios/TimbreUITests' / (cls + '.swift')).read_text())

    def test_all_required_fixtures_come_from_current_shipped_tables(self):
        with patch.object(assets, 'write_json') as write, patch.object(assets, 'digest', return_value='fixture'):
            result = assets.prepare_fixtures()
        data = write.call_args.args[1]
        self.assertEqual(set(data), {assets.locale_spec(x)['app_language'] for x in assets.locale_rows()})
        self.assertEqual(result['fixture_sha256'], 'fixture')
        for fields in data.values():
            for key in ['tune', 'learn', 'songs', 'practice', 'progress', 'lesson_start', 'lesson_continue', 'all_tuned']:
                self.assertTrue(fields[key])


class EvidenceTests(unittest.TestCase):
    def setUp(self):
        self.spec = assets.locale_spec('de-DE')
        self.record = {k: self.spec[k] for k in ['listing_locale', 'app_language', 'apple_languages', 'apple_locale']}
        self.record['checked_fields'] = ['tune', 'learn', 'songs', 'practice', 'progress']
        self.record['observed_labels'] = assets.expected_tab_labels('de')

    def test_language_evidence_is_actual_check_not_requested_environment(self):
        line = 'TIMBRE_CAPTURE_VERIFIED ' + json.dumps(self.record)
        self.assertEqual(len(assets.validate_language_evidence(self.spec, line, 'VERIFIED')), 1)
        for bad in ['', 'TIMBRE_UI_LANGUAGE=de', line.replace('"de"', '"en"'), line.replace('"songs", ', '')]:
            with self.subTest(bad=bad), self.assertRaises(ValueError):
                assets.validate_language_evidence(self.spec, bad, 'VERIFIED')

    def test_every_launch_must_match_requested_locale(self):
        line = 'TIMBRE_CAPTURE_LAUNCH ' + json.dumps(self.record)
        with self.assertRaises(ValueError):
            assets.validate_language_evidence(self.spec, line, 'LAUNCH', minimum=8)
        other = copy.deepcopy(self.record)
        other['apple_languages'] = ['en']
        with self.assertRaises(ValueError):
            assets.validate_language_evidence(self.spec, line + '\nTIMBRE_CAPTURE_LAUNCH ' + json.dumps(other), 'LAUNCH')

    def test_missing_lesson_resources_fail_before_any_native_capture(self):
        import contextlib
        import io
        from types import SimpleNamespace
        spec = {**assets.locale_spec('de-DE'), 'lesson_resource_status': 'pending', 'lesson_resource_sha256': None}
        with tempfile.TemporaryDirectory() as directory:
            folder = Path(directory)
            args = SimpleNamespace(out=folder / 'assets', manifests=folder / 'manifests', kind='iphone', source_sha='revision')
            with patch.object(assets, 'locale_spec', return_value=spec), patch.object(runner, 'test_attempts') as native, contextlib.redirect_stdout(io.StringIO()):
                self.assertFalse(runner.run_locale('de-DE', args, {'id': 'test-device'}, folder / 'test.xctestrun', 'a' * 64))
                native.assert_not_called()
            manifest = assets.read_json(args.manifests / 'de-DE-iphone.manifest.json')
            self.assertEqual(manifest['status'], 'failed')
            self.assertEqual(manifest['lesson_resource_status'], 'pending')
            self.assertIn('not shipped', manifest['error'])

    def test_launch_environment_keeps_expected_and_requested_languages_separate(self):
        spec = assets.locale_spec('zh-Hant')
        env = runner.environment(spec)
        self.assertEqual(env['TEST_RUNNER_TIMBRE_UI_LANGUAGE'], 'en')
        self.assertEqual(env['TEST_RUNNER_TIMBRE_UI_APPLE_LANGUAGES'], 'zh-Hant,en')
        self.assertEqual(env['TEST_RUNNER_TIMBRE_LISTING_LOCALE'], 'zh-Hant')

    def test_zero_tests_or_skipped_test_cannot_pass(self):
        selector = assets.EVIDENCE_TEST
        with tempfile.TemporaryDirectory() as folder:
            log = Path(folder) / 'test.log'
            for word in ['skipped', 'failed']:
                log.write_text(f"Test Case '-[TimbreUITests.ListingCaptureEvidenceUITests testRequestedLanguageActuallyAppears]' {word}")
                with self.assertRaises(RuntimeError):
                    runner.tested_selectors(log, [selector])
            log.write_text("Test Case '-[TimbreUITests.ListingCaptureEvidenceUITests testRequestedLanguageActuallyAppears]' passed (2.000 seconds).")
            runner.tested_selectors(log, [selector])

    def test_simulator_selection_requires_correct_dimensions_and_latest_runtime(self):
        listing = {'devices': {'com.apple.CoreSimulator.SimRuntime.iOS-26-0': [
            {'name': 'iPhone 17 Pro', 'udid': 'medium'}, {'name': 'iPhone 17 Pro Max', 'udid': 'phone'},
            {'name': 'iPad Air 13-inch (M3)', 'udid': 'air'}, {'name': 'iPad Pro 13-inch (M4)', 'udid': 'pad'},
        ]}}
        with patch.object(runner, 'output', return_value=json.dumps(listing)):
            self.assertEqual(runner.choose_device('iphone')['id'], 'medium')
            self.assertEqual(runner.choose_device('preview-main')['id'], 'phone')
            self.assertEqual(runner.choose_device('ipad')['id'], 'pad')
        with patch.object(runner, 'output', return_value=json.dumps({'devices': {}})), self.assertRaises(RuntimeError):
            runner.choose_device('iphone')


class CaptureInventoryTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.base = Path(self.temp.name)
        self.names = ['first', 'second']
        from PIL import Image
        for i, name in enumerate(self.names):
            Image.new('RGB', (1206, 2622), (i * 50, 0, 0)).save(self.base / (name + '.png'))
        self.expected = patch.object(assets, 'expected_captures', return_value=self.names)
        self.expected.start()

    def tearDown(self):
        self.expected.stop()
        self.temp.cleanup()

    def captures(self):
        return assets.capture_records(self.base, 'de-DE', 'iphone', self.base)

    def test_complete_distinct_pixels_are_hash_bound(self):
        records = self.captures()
        self.assertEqual([r['capture'] for r in records], self.names)
        self.assertEqual(len({r['pixel_sha256'] for r in records}), 2)

    def test_missing_wrong_and_duplicate_capture_attachments_fail(self):
        import screenshots
        original = screenshots.attachments(self.base)
        for wrong in [{**original, 'first-wrong': original['first']},
                      {**original, 'first': []},
                      {**original, 'first': original['first'] * 2},
                      {**original, 'second': original['first']}]:
            with patch.object(screenshots, 'attachments', return_value=wrong), self.assertRaises(ValueError):
                self.captures()

    def test_duplicate_pixels_fail_even_with_distinct_filenames(self):
        (self.base / 'second.png').write_bytes((self.base / 'first.png').read_bytes())
        with self.assertRaisesRegex(ValueError, 'duplicate capture pixels'):
            self.captures()

    def test_wrong_device_size_fails_not_rescaled_into_fake_evidence(self):
        from PIL import Image
        Image.new('RGB', (100, 200)).save(self.base / 'first.png')
        with self.assertRaisesRegex(ValueError, 'actual medium Dynamic Island'):
            self.captures()

    def test_large_phone_cannot_replace_required_medium_capture(self):
        from PIL import Image
        Image.new('RGB', (1320, 2868)).save(self.base / 'first.png')
        with self.assertRaisesRegex(ValueError, 'actual medium Dynamic Island'):
            self.captures()

    def test_default_phone_frame_matches_the_required_native_capture(self):
        from PIL import Image
        import screenshots
        self.assertEqual(screenshots.frame_size('iphone', Image.new('RGB', (1206, 2622))), (1206, 2622))

    def test_standalone_renderer_rejects_large_source_even_with_medium_output(self):
        from PIL import Image
        import screenshots
        output = self.base / 'rendered.jpg'
        Image.new('RGB', (1206, 2622)).save(output)
        raw = self.base / 'first.png'
        self.assertIsNone(screenshots.size_problem('iphone', output, raw))
        Image.new('RGB', (1320, 2868)).save(raw)
        self.assertIn('need a native 1206x2622', screenshots.size_problem('iphone', output, raw))

    def test_attachments_cannot_escape_evidence_folder(self):
        import screenshots
        with patch.object(screenshots, 'attachments', return_value={'first': [self.base.parent / 'other.png']}), self.assertRaises(ValueError):
            self.captures()


class AggregationTests(unittest.TestCase):
    def test_large_phone_manifest_cannot_replace_required_medium_set(self):
        record = self.fixture()
        assets.validate_manifest_assets(record)
        for image in record['assets']:
            if image['path'].endswith('.jpg'):
                image['size'] = [1320, 2868]
        with self.assertRaisesRegex(ValueError, 'Wrong screenshot dimensions'):
            assets.validate_manifest_assets(record)

    def fixture(self, locale='de-DE'):
        import hashlib
        spec = assets.locale_spec(locale)
        runtime = {key: spec[key] for key in ['listing_locale', 'app_language', 'apple_languages', 'apple_locale']}
        verified = {**runtime, 'checked_fields': ['tune', 'learn', 'songs', 'practice', 'progress'],
                    'observed_labels': assets.expected_tab_labels(spec['app_language'])}
        needed = assets.expected_captures(locale, 'iphone')
        files = [{'path': f'rendered/iphone-{locale}-{i:02d}.jpg', 'sha256': 'a' * 64, 'size': [1206, 2622]}
                 for i in range(1, len(needed) + 1)]
        files.append({'path': f'rendered/iphone-{locale}-sheet.png', 'sha256': 'b' * 64})
        return {**spec, 'kind': 'iphone', 'source_sha': 'revision', 'build_sha256': 'c' * 64,
                'status': 'mechanically_verified', 'release_ready': False, 'visual_review': 'pending', 'native_review': 'pending',
                'language_evidence': [verified], 'launch_evidence': [runtime] * 8, 'assets': files,
                'captures': [{'capture': n, 'size': [1206, 2622], 'pixel_sha256': hashlib.sha256((locale + n).encode()).hexdigest()} for n in needed]}

    def test_missing_failed_stale_duplicate_and_wrong_build_never_become_green(self):
        plan = {'locales': ['de-DE'], 'kinds': ['iphone']}
        with tempfile.TemporaryDirectory() as folder:
            path = Path(folder) / 'one.manifest.json'
            self.assertTrue(assets.aggregate(plan, Path(folder), 'revision')['errors'])
            good = self.fixture()
            assets.write_json(path, good)
            self.assertFalse(assets.aggregate(plan, Path(folder), 'revision')['errors'])
            for field, value in [('status', 'failed'), ('source_sha', 'old'), ('payload_sha256', 'old'),
                                 ('release_ready', True), ('visual_review', 'passed'), ('assets', []), ('build_sha256', None)]:
                assets.write_json(path, {**good, field: value})
                self.assertTrue(assets.aggregate(plan, Path(folder), 'revision')['errors'], field)
            assets.write_json(path, good)
            assets.write_json(Path(folder) / 'duplicate.manifest.json', good)
            self.assertTrue(assets.aggregate(plan, Path(folder), 'revision')['errors'])

    def test_malformed_top_level_and_capture_schemas_write_incomplete_inventory(self):
        import contextlib
        import io
        with tempfile.TemporaryDirectory() as directory:
            folder = Path(directory)
            manifests = folder / 'manifests'
            plan = folder / 'plan.json'
            inventory = folder / 'inventory.json'
            assets.write_json(plan, {'locales': ['de-DE'], 'kinds': ['iphone']})
            cases = [[], None, ['bad']]
            cases += [{**self.fixture(), 'captures': value} for value in [[], None, ['bad']]]
            cases += [{**self.fixture(), 'listing_locale': []}, {**self.fixture(), 'build_sha256': []}]
            for value in cases:
                with self.subTest(value=value):
                    assets.write_json(manifests / 'bad.manifest.json', value)
                    args = ['listing_assets.py', 'aggregate', '--plan', str(plan), '--manifests', str(manifests),
                            '--source-sha', 'revision', '--out', str(inventory)]
                    with patch.object(sys, 'argv', args), contextlib.redirect_stdout(io.StringIO()), contextlib.redirect_stderr(io.StringIO()):
                        self.assertEqual(assets.main(), 1)
                    result = assets.read_json(inventory)
                    self.assertEqual(result['status'], 'incomplete')
                    self.assertTrue(result['errors'])
                    self.assertFalse(result['release_ready'])

    def test_malformed_plan_and_invalid_manifest_json_are_reported_not_crashed(self):
        with tempfile.TemporaryDirectory() as directory:
            folder = Path(directory)
            (folder / 'broken.manifest.json').write_text('{')
            for plan in [None, [], {'locales': None, 'kinds': ['iphone']}, {'locales': ['bad'], 'kinds': ['iphone']}]:
                result = assets.aggregate(plan, folder, 'revision')
                self.assertEqual(result['status'], 'incomplete')
                self.assertTrue(any('Malformed plan' in message for message in result['errors']))
                self.assertTrue(any('unreadable manifest JSON' in message for message in result['errors']))

    def test_complete_all_fifty_phone_inventory_and_fallback_remain_unapproved(self):
        with tempfile.TemporaryDirectory() as folder, patch.object(assets, 'lesson_provenance', return_value={'lesson_resource_status': 'shipped', 'lesson_resource_sha256': 'd' * 64}):
            locales = list(assets.locale_rows())
            for locale in locales:
                assets.write_json(Path(folder) / (locale + '.manifest.json'), self.fixture(locale))
            result = assets.aggregate({'locales': locales, 'kinds': ['iphone']}, Path(folder), 'revision')
            self.assertFalse(result['errors'], result['errors'])
            self.assertEqual(result['manifest_count'], 50)
            self.assertFalse(result['release_ready'])
            self.assertEqual(result['visual_review'], 'pending')
            fallback = [row for row in result['manifests'] if row['listing_only_fallback']]
            self.assertEqual({row['listing_locale'] for row in fallback}, {'ms', 'or-IN', 'zh-Hant'})
            self.assertTrue(all(not row['ui_support_claim'] for row in fallback))

    def test_complete_identical_pixels_in_different_app_languages_are_rejected(self):
        with tempfile.TemporaryDirectory() as folder:
            english, german = self.fixture('en-US'), self.fixture('de-DE')
            german['captures'] = english['captures']
            assets.write_json(Path(folder) / 'english.manifest.json', english)
            assets.write_json(Path(folder) / 'german.manifest.json', german)
            result = assets.aggregate({'locales': ['en-US', 'de-DE'], 'kinds': ['iphone']}, Path(folder), 'revision')
            self.assertTrue(any('identical complete capture pixels' in x for x in result['errors']))



class PreviewEvidenceTests(unittest.TestCase):
    def test_translated_caption_cannot_turn_off_semantic_band_obligation(self):
        import gates
        import preview
        import soundtrack
        from unittest.mock import MagicMock
        for locale in ['ar-SA', 'de-DE', 'zh-Hant']:
            with self.subTest(locale=locale), tempfile.TemporaryDirectory() as directory:
                folder = Path(directory)
                (folder / 'app').mkdir()
                (folder / 'app/events.jsonl').write_text('{}\n')
                clips = [('lock', 100, 104), ('tuned', 104, 108), ('showme', 108, 111),
                         ('highway', 111, 116), ('results', 116, 120), ('songs', 120, 123)]
                captions = preview.captions('guitar', locale)
                sections = [{'name': name, 'start': start - 100, 'end': end - 100, 'caption': captions[name][0]}
                            for name, start, end in clips]
                sections.append({'name': 'end card', 'start': 23, 'end': 25, 'caption': ''})
                assets.write_json(folder / 'cut.json', {'sections': sections})
                audio = MagicMock()
                audio.band_playing.return_value = True
                with patch.object(gates, 'sound_report', return_value=([], [], [])) as report, patch.object(soundtrack, 'AppAudio', return_value=audio):
                    self.assertTrue(runner.semantic_preview_audio(folder, 'preview-main', locale, {'clips': clips}))
                    highway = next(x for x in report.call_args.args[1] if x.name == 'highway')
                    self.assertTrue(highway.promises_band)
                    audio.band_playing.assert_called_once_with(111, 116)
                    audio.band_playing.return_value = None
                    self.assertFalse(runner.semantic_preview_audio(folder, 'preview-main', locale, {'clips': clips}))
                sections[0]['caption'] = 'wrong'
                assets.write_json(folder / 'cut.json', {'sections': sections})
                with self.assertRaisesRegex(RuntimeError, 'Wrong localized caption'):
                    runner.semantic_preview_audio(folder, 'preview-main', locale, {'clips': clips})

    def test_partial_trim_or_wrong_cut_cannot_pass_native_video_inventory(self):
        import preview
        with tempfile.TemporaryDirectory() as directory:
            folder = Path(directory)
            (folder / 'test.log').write_text('')
            with patch.object(preview, 'read_marks', return_value=None), self.assertRaises(RuntimeError):
                runner.validate_preview_take(folder, 'preview-main')
            marks = {'result': 'passed', 'cut': 'guitar', 'clips': [('fallback', 1, 20)]}
            with patch.object(preview, 'read_marks', return_value=marks), self.assertRaisesRegex(RuntimeError, 'missing, duplicate'):
                runner.validate_preview_take(folder, 'preview-main')


class SourceContractTests(unittest.TestCase):
    def test_workflow_is_explicit_opt_in_approved_refs_artifact_only_and_bounded(self):
        source = (assets.ROOT / '.github/workflows/listing-assets.yml').read_text()
        self.assertIn('workflow_dispatch:', source)
        self.assertIn('\n  push:\n    branches: [main, codex/app-store-readiness-gates]', source)
        self.assertIn("contains(github.event.head_commit.message, '[listing-assets-pilot]')", source)
        self.assertIn("contains(github.event.head_commit.message, '[listing-assets-all]')", source)
        self.assertIn("github.ref == 'refs/heads/main'", source)
        self.assertIn('contents: read', source)
        self.assertIn('max-parallel: 2', source)
        self.assertIn('cancel-in-progress: false', source)
        for forbidden in ['contents: write', 'publish-results.sh', 'ci-results/', 'git push', 'secrets.', 'apple-delivery', 'archivePath']:
            self.assertNotIn(forbidden, source)
        self.assertEqual(source.count('xcodebuild build-for-testing'), 1)
        self.assertRegex(source, r'actions/upload-artifact@[a-f0-9]{40}\b')
        self.assertIn('persist-credentials: false', source)
        self.assertNotIn('-allowProvisioningUpdates', source)

    def test_preview_keeps_real_playing_audio_and_localizes_selectors(self):
        source = (assets.ROOT / 'ios/TimbreUITests/AppPreviewUITests.swift').read_text()
        self.assertIn('CaptureLocalization.launchArguments', source)
        self.assertIn('CaptureLocalization.recordLaunch', source)
        self.assertIn('CaptureLocalization.lessonButtonLabel(title)', source)
        self.assertIn('CaptureLocalization.tabLabel(name)', source)
        self.assertIn('performance.combo.', source)
        for forbidden in ['TIMBRE_SCENE_STILL', 'node.label == "Combo"', '"(en)"', 'app.tabBars.buttons[name]']:
            self.assertNotIn(forbidden, source)
        self.assertIn('"TIMBRE_PREVIEW_AUDIO": exchange.path', source)
        self.assertIn('mark("PREVIEW-CHECK multiplier fail', source)
        self.assertIn('awaitEvent("lock"', source)

    def test_shared_capture_arguments_and_markers_cover_phone_tablet_preview(self):
        helper = (assets.ROOT / 'ios/TimbreUITests/CaptureLocalization.swift').read_text()
        for member in ['static let listingLocale', 'static let appleLanguages', 'static var launchArguments',
                       'static func recordLaunch', 'static func recordVerified', 'static func lessonButtonLabel', 'static var allTuned']:
            self.assertIn(member, helper)
        self.assertIn('TIMBRE_UI_APPLE_LANGUAGES', helper)
        self.assertIn('"observed_labels": observed', helper)
        self.assertIn('return language == "en" ? source : nil', helper)
        for filename in ['TimbreUITests.swift', 'TabletScreenshotsUITests.swift', 'AppPreviewUITests.swift']:
            source = (assets.ROOT / 'ios/TimbreUITests' / filename).read_text()
            self.assertIn('app.launchArguments = CaptureLocalization.launchArguments', source)
            self.assertIn('CaptureLocalization.recordLaunch(context:', source)
        evidence = (assets.ROOT / 'ios/TimbreUITests/ListingCaptureEvidenceUITests.swift').read_text()
        self.assertIn('continueAfterFailure = false', evidence)
        self.assertIn('XCTAssertEqual(button.label, expected', evidence)
        self.assertIn('XCTAssertTrue(button.isHittable', evidence)
        self.assertLess(evidence.index('XCTAssertEqual(button.label, expected'), evidence.index('CaptureLocalization.recordVerified'))
        self.assertIn('observed[field] = button.label', evidence)

    def test_default_still_tuner_does_not_repluck_or_weaken_true_lock_checks(self):
        source = (assets.ROOT / 'ios/TimbreUITests/TimbreUITests.swift').read_text()
        method = source.split('func test11StoreTunerLock()', 1)[1].split('func test16StoreViolinStage()', 1)[0]
        self.assertIn('launch(pitch: true, scene: "tune-locked")', method)
        self.assertNotIn('comet: true', method)
        self.assertIn('lockedTunerFrame(strings: 3)', method)
        checks = source.split('private func tunerLock(strings:', 1)[1].split('private func lockHolds(', 1)[0]
        self.assertIn('status == nil || status == inTuneWord', checks)
        self.assertIn('stage && tuned >= strings && selectedTuned && badge', checks)
        self.assertNotIn('"Hold it…"', checks.split('let badge =', 1)[1].split('return ', 1)[0])
        locked = source.split('private func lockedTunerFrame(', 1)[1].split('private func readoutRegion()', 1)[0]
        self.assertIn('let lock = tunerLock(strings: strings)', locked)
        self.assertIn('let hold = lockHolds(stages: stages)', locked)
        self.assertIn('XCTAssertTrue(hold.held', locked)
        self.assertIn('as: name + "-wrong"', source)
        # The violin CPP's optional shimmer and actual video tour are not changed by this still repair.
        violin = source.split('func test16StoreViolinStage()', 1)[1].split('func test20StoreCelloStage()', 1)[0]
        self.assertIn('comet: true', violin)

    def test_runner_preserves_gate_failure_and_never_swallows_assertions(self):
        source = (assets.ROOT / 'tools/marketing/run_listing_assets.py').read_text()
        self.assertIn("if cut in (3, 4) and attempt < 3:", source)
        self.assertIn('if attempt == 1 and launch_only_failure(log):', source)
        self.assertIn("'check', '--out', folder", source)
        self.assertIn("'NOT FOR UPLOAD:' in report", source)
        self.assertNotIn('--reanchor', source)
        self.assertNotIn('--allow-english', source)
        self.assertNotIn('shutil.rmtree', source)


if __name__ == '__main__':
    unittest.main()
