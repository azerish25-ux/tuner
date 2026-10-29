#!/usr/bin/env python3
"""Synthetic archive fixtures; no signing identities or Apple access."""
import importlib.util
from pathlib import Path
import plistlib
import os
import subprocess
import tempfile
from types import SimpleNamespace
import unittest
from unittest.mock import Mock

spec = importlib.util.spec_from_file_location('archive_scope', Path(__file__).with_name('apple_archive_scope.py'))
a = importlib.util.module_from_spec(spec)
spec.loader.exec_module(a)


class ArchiveScopeTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.archive = Path(self.temp.name) / 'Timbre.xcarchive'
        self.app = self.archive / 'Products/Applications/Timbre.app'
        self.env = {'APPLE_TEAM_ID': 'A'*10, 'MARKETING_VERSION': '2.0.0', 'BUILD_NUMBER': '1', 'BUILD_CHANNEL': ''}
        self.scope = {'game_center_account': 'not_applicable'}
        self.entitlements = {}
        self.bundles = [self.app, self.app/'PlugIns/Widget.appex', self.app/'Watch/Watch.app',
                        self.app/'Watch/Watch.app/PlugIns/Complication.appex']
        ids = [a.MAIN_ID, a.MAIN_ID+'.widgets', a.MAIN_ID+'.watchkitapp', a.MAIN_ID+'.watchkitapp.widgets']
        for bundle, identifier in zip(self.bundles, ids):
            bundle.mkdir(parents=True, exist_ok=True)
            info = {'CFBundleIdentifier': identifier, 'CFBundleShortVersionString': '2.0.0', 'CFBundleVersion': '1'}
            if bundle == self.app:
                info.update(TimbreGameCenterEnabled='NO', TimbreBuildChannel='')
            (bundle/'Info.plist').write_bytes(plistlib.dumps(info))
            self.entitlements[bundle] = {'com.apple.security.application-groups': [a.APP_GROUP],
                                        'com.apple.developer.team-identifier': 'A'*10,
                                        'application-identifier': 'A'*10+'.'+identifier}

    def inspect(self):
        return a.inspect_archive(self.archive, self.scope, self.env, self.entitlements.__getitem__)

    def change_info(self, bundle, field, value):
        file = bundle/'Info.plist'
        data = plistlib.loads(file.read_bytes())
        if value is None: data.pop(field, None)
        else: data[field] = value
        file.write_bytes(plistlib.dumps(data))

    def test_disabled_signed_archive_passes(self):
        self.assertEqual(self.inspect(), 4)

    def test_enabled_switch_or_missing_switch_blocks(self):
        for value in ('YES', True, '$(TIMBRE_GAME_CENTER_ENABLED)', None):
            self.change_info(self.app, 'TimbreGameCenterEnabled', value)
            with self.subTest(value=value), self.assertRaises(a.ArchiveError): self.inspect()

    def test_any_signed_game_center_entitlement_blocks_omission(self):
        for bundle in self.bundles:
            for value in (True, False):
                self.entitlements[bundle][a.GC] = value
                with self.subTest(bundle=bundle, value=value), self.assertRaises(a.ArchiveError): self.inspect()
            del self.entitlements[bundle][a.GC]

    def test_enabled_feature_needs_entitlement(self):
        self.scope['game_center_account'] = 'required'
        self.change_info(self.app, 'TimbreGameCenterEnabled', 'YES')
        with self.assertRaises(a.ArchiveError): self.inspect()
        self.entitlements[self.app][a.GC] = True
        self.assertEqual(self.inspect(), 4)

    def test_build_channel_must_match_internal_path(self):
        self.env['BUILD_CHANNEL'] = 'internal'
        with self.assertRaises(a.ArchiveError): self.inspect()
        self.change_info(self.app, 'TimbreBuildChannel', 'internal')
        self.assertEqual(self.inspect(), 4)
        self.env['BUILD_CHANNEL'] = ''
        with self.assertRaises(a.ArchiveError): self.inspect()

    def test_wrong_version_or_identity_blocks(self):
        original = (self.bundles[-1]/'Info.plist').read_bytes()
        for field, value in [('CFBundleVersion','2'), ('CFBundleShortVersionString','3.0'), ('CFBundleIdentifier','wrong')]:
            self.change_info(self.bundles[-1], field, value)
            with self.subTest(field=field), self.assertRaises(a.ArchiveError): self.inspect()
            (self.bundles[-1]/'Info.plist').write_bytes(original)

    def test_wrong_team_or_signed_identifier_blocks(self):
        for field in ('com.apple.developer.team-identifier', 'application-identifier'):
            old = self.entitlements[self.app][field]
            self.entitlements[self.app][field] = 'wrong'
            with self.assertRaises(a.ArchiveError): self.inspect()
            self.entitlements[self.app][field] = old

    def test_every_bundle_requires_exact_app_group(self):
        key = 'com.apple.security.application-groups'
        for bundle in self.bundles:
            for value in (None, [], ['group.wrong'], [a.APP_GROUP, 'group.extra'], a.APP_GROUP):
                if value is None:
                    self.entitlements[bundle].pop(key, None)
                else:
                    self.entitlements[bundle][key] = value
                with self.subTest(bundle=bundle, value=value), self.assertRaises(a.ArchiveError):
                    self.inspect()
            self.entitlements[bundle][key] = [a.APP_GROUP]

    def test_missing_companion_blocks(self):
        (self.bundles[-1]/'Info.plist').unlink()
        self.bundles[-1].rmdir()
        with self.assertRaises(a.ArchiveError): self.inspect()

    def test_signature_failure_does_not_log_identity(self):
        runner = Mock(return_value=SimpleNamespace(returncode=1, stdout=b'', stderr=b'SENSITIVE SIGNING IDENTITY'))
        with self.assertRaises(a.ArchiveError) as caught: a.signed_entitlements(self.app, runner)
        self.assertNotIn('SENSITIVE', str(caught.exception))

    def test_entitlements_are_read_from_signature_not_source(self):
        payload = plistlib.dumps(self.entitlements[self.app])
        runner = Mock(side_effect=[SimpleNamespace(returncode=0, stdout=b''), SimpleNamespace(returncode=0, stdout=payload)])
        self.assertEqual(a.signed_entitlements(self.app, runner), self.entitlements[self.app])
        self.assertEqual(runner.call_args_list[0].args[0][:3], ['codesign','--verify','--strict'])
        self.assertEqual(runner.call_args_list[1].args[0][:4], ['codesign','--display','--entitlements',':-'])

    def test_malformed_signed_entitlements_block(self):
        runner = Mock(return_value=SimpleNamespace(returncode=0, stdout=b'not a plist'))
        with self.assertRaises(a.ArchiveError): a.signed_entitlements(self.app, runner)

    def test_directory_export_visible_to_same_step_python(self):
        workflow = (a.ROOT/'.github/workflows/apple-delivery.yml').read_text()
        assignment = next(line.strip() for line in workflow.splitlines() if 'export DELIVERY_DIRECTORY=' in line)
        result = subprocess.run(['bash','-c', assignment + '\npython3 -c \'import os; assert os.environ["DELIVERY_DIRECTORY"].endswith("/apple-delivery")\''],
                                env={'PATH':os.environ['PATH'], 'RUNNER_TEMP':self.temp.name}, capture_output=True)
        self.assertEqual(result.returncode, 0)
        self.assertLess(workflow.index('export DELIVERY_DIRECTORY='), workflow.index("directory = pathlib.Path(os.environ['DELIVERY_DIRECTORY'])"))
        self.assertLess(workflow.index('tools/ci/apple_archive_scope.py'), workflow.index('- name: Export, sign and upload'))


if __name__ == '__main__': unittest.main()
