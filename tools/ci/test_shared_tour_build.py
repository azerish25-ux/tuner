"""Shared products never substitute provenance, coverage or launch isolation."""
import contextlib
import copy
import io
import json
import os
from pathlib import Path
import plistlib
import tarfile
import tempfile
import unittest
from unittest.mock import patch
import shared_tour_build as shared
import tour_evidence

ROOT = Path(__file__).resolve().parents[2]


class IdentityTests(unittest.TestCase):
    def test_exact_source_run_attempt_toolchain_and_fixture_identity(self):
        identity = dict(sha='a' * 40, run_id='123', run_attempt='1')
        tools = dict(xcode='Xcode 26.3 build A', sdk='26.2', sdk_build='B', machine='arm64')
        info = dict(identity=identity, toolchain=tools, fixtures={'expected.json': 'hash'})
        shared.validate_identity(info, identity, tools, info['fixtures'])
        for section in ['identity', 'toolchain', 'fixtures']:
            for key in info[section]:
                bad = copy.deepcopy(info); bad[section][key] = 'foreign'
                with self.subTest(section=section, key=key), self.assertRaises(ValueError):
                    shared.validate_identity(bad, identity, tools, info['fixtures'])
        with self.assertRaises(ValueError):
            shared.validate_identity(info, identity, tools, {})

    def inventory(self):
        return {'runtimes': [{'identifier': 'com.apple.CoreSimulator.SimRuntime.iOS-26-2', 'version': '26.2',
                              'buildversion': 'A', 'isAvailable': True}],
                'devices': {'com.apple.CoreSimulator.SimRuntime.iOS-26-2': [
                    {'name': 'iPhone 17', 'deviceTypeIdentifier': 'type17', 'udid': 'worker-device', 'isAvailable': True}]}}

    def test_runtime_build_and_device_type_must_match_not_latest_fallback(self):
        inventory = self.inventory()
        udid, expected = shared.device(inventory)
        self.assertEqual(udid, 'worker-device')
        for key in expected:
            altered = dict(expected, **{key: 'different'})
            with self.subTest(key=key), self.assertRaises(ValueError):
                shared.device(inventory, altered)
        self.assertEqual(shared.device(inventory, expected)[1], expected)

    def test_missing_or_unavailable_devices_fail(self):
        inventory = self.inventory()
        inventory['runtimes'][0]['isAvailable'] = False
        with self.assertRaises(ValueError):
            shared.device(inventory)

    def test_archive_rejects_traversal_links_and_special_files(self):
        def verify(name, kind=tarfile.REGTYPE, link=''):
            stream = io.BytesIO()
            with tarfile.open(fileobj=stream, mode='w') as archive:
                item = tarfile.TarInfo(name); item.type = kind; item.linkname = link
                archive.addfile(item)
            stream.seek(0)
            with tarfile.open(fileobj=stream) as archive:
                shared.safe_members(archive)
        verify('Products/app')
        verify('Products/A/Current', tarfile.SYMTYPE, 'Versions/A')
        for name, kind, link in [('../evil', tarfile.REGTYPE, ''), ('/tmp/evil', tarfile.REGTYPE, ''),
                                 ('Products/link', tarfile.SYMTYPE, '../../outside'),
                                 ('Products/link', tarfile.SYMTYPE, '/absolute'), ('Products/fifo', tarfile.FIFOTYPE, '')]:
            with self.subTest(name=name, kind=kind), self.assertRaises(ValueError):
                verify(name, kind, link)

    def test_xctestrun_requires_one_file_and_resolvable_relative_products(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            with self.assertRaises(ValueError):
                shared.validate_xctestrun(root)
            app = root / 'Timbre.app'; app.mkdir()
            target = root / 'Timbre.xctestrun'
            target.write_bytes(plistlib.dumps({'TestHostPath': '__TESTROOT__/Timbre.app'}))
            self.assertEqual(shared.validate_xctestrun(root), target)
            for bad in ['__TESTROOT__/missing.app', '__TESTROOT__/../escape', '/Users/runner/build/Timbre.app']:
                target.write_bytes(plistlib.dumps({'TestHostPath': bad}))
                with self.subTest(bad=bad), self.assertRaises(ValueError):
                    shared.validate_xctestrun(root)

    def test_products_inventory_detects_mutation_modes_and_symlink_escape(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory); executable = root / 'binary'; executable.write_bytes(b'original'); executable.chmod(0o755)
            before = shared.inventory_products(root)
            executable.chmod(0o644)
            self.assertNotEqual(shared.inventory_products(root), before)
            executable.write_bytes(b'changed')
            self.assertNotEqual(shared.inventory_products(root), before)
            (root / 'escape').symlink_to('/tmp')
            with self.assertRaises(ValueError):
                shared.inventory_products(root)

    def test_restore_rejects_foreign_archive_before_extraction(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            info = dict(schema=1, identity={}, toolchain={}, fixtures={}, archive_sha256='wrong')
            (root / 'build-info.json').write_text(json.dumps(info)); (root / 'products.tgz').write_bytes(b'wrong')
            with patch.object(shared, 'identity', return_value={}), patch.object(shared, 'toolchain', return_value={}), \
                    patch.object(shared, 'fixtures', return_value={}), patch.object(shared.subprocess, 'run') as run, self.assertRaisesRegex(ValueError, 'hash'):
                shared.restore(root)
            run.assert_not_called()

    def test_pack_restore_roundtrip_preserves_exact_products_and_receipt(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory); producer = root / 'producer'; consumer = root / 'consumer'; artifacts = root / 'artifacts'
            products = producer / 'Products'; products.mkdir(parents=True); artifacts.mkdir()
            (products / 'Timbre.app').mkdir(); binary = products / 'Timbre.app/Timbre'
            binary.write_bytes(b'native fixture'); binary.chmod(0o755)
            (products / 'Timbre.xctestrun').write_bytes(plistlib.dumps({'TestHostPath': '__TESTROOT__/Timbre.app'}))
            ident = dict(sha='a' * 40, run_id='123', run_attempt='1'); tools = dict(xcode='A')
            inventory = self.inventory(); _, scope = shared.device(inventory)
            selection = dict(identity=ident, toolchain=tools, fixtures={}, simulator=scope)
            (artifacts / 'selection.json').write_text(json.dumps(selection))
            with patch.object(shared, 'identity', return_value=ident), patch.object(shared, 'toolchain', return_value=tools), \
                    patch.object(shared, 'fixtures', return_value={}), patch.object(shared, 'architectures', return_value={'app': ['arm64']}):
                with patch.object(shared, 'PRODUCTS', products):
                    shared.pack(artifacts)
                target = consumer / 'Build/Products'
                with patch.object(shared, 'ROOT', consumer), patch.object(shared, 'PRODUCTS', target), \
                        patch.object(shared, 'output', return_value=json.dumps(inventory)), \
                        patch.dict(os.environ, {'GITHUB_ENV': str(root / 'environment')}):
                    shared.restore(artifacts)
                self.assertEqual(shared.inventory_products(products), shared.inventory_products(target))
                receipt = json.loads((consumer / 'ci-out/shared-build.json').read_text())
                self.assertEqual(receipt['identity'], ident)
                self.assertEqual(receipt['simulator'], scope)
                self.assertEqual(receipt['archive_sha256'], shared.digest(artifacts / 'products.tgz'))
                self.assertIn('XCTESTRUN=', (root / 'environment').read_text())

    def test_darwin_pack_disables_appledouble_and_checks_produced_archive(self):
        # Actual macOS listing artifact 12776617030 contains a top-level ._Products.
        # Do not broaden the extractor to permit siblings; prevent them in the producer.
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory); products = root / 'Products'; products.mkdir()
            (products / 'Timbre.app').mkdir()
            spec = products / 'Timbre.xctestrun'
            spec.write_bytes(plistlib.dumps({'TestHostPath': '__TESTROOT__/Timbre.app'}))
            artifacts = root / 'artifacts'; artifacts.mkdir()
            (artifacts / 'selection.json').write_text(json.dumps({'identity': {}, 'toolchain': {}, 'fixtures': {}}))
            def native_tar(args, **kwargs):
                self.assertEqual(args[:3], ['tar', '--no-mac-metadata', '-czf'])
                # Simulate a producer failing to honor metadata suppression: it must not upload.
                with tarfile.open(args[3], 'w:gz') as archive:
                    archive.add(products, arcname='Products')
                    archive.addfile(tarfile.TarInfo('._Products'))
            with patch.object(shared, 'PRODUCTS', products), patch.object(shared, 'identity', return_value={}), \
                    patch.object(shared, 'toolchain', return_value={}), patch.object(shared, 'fixtures', return_value={}), \
                    patch.object(shared, 'architectures', return_value={}), patch.object(shared.platform, 'system', return_value='Darwin'), \
                    patch.object(shared.subprocess, 'run', side_effect=native_tar), self.assertRaisesRegex(ValueError, 'Unsafe shared archive path'):
                shared.pack(artifacts)
            self.assertFalse((artifacts / 'build-info.json').exists())

    def test_native_architecture_must_include_consumer_machine(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory); app = root / 'Timbre.app'; app.mkdir()
            (app / 'Info.plist').write_bytes(plistlib.dumps({'CFBundleExecutable': 'Timbre'})); (app / 'Timbre').write_bytes(b'executable')
            with patch.object(shared, 'output', return_value='arm64 x86_64'), patch.object(shared.platform, 'machine', return_value='arm64'):
                self.assertEqual(shared.architectures(root), {'Timbre.app/Timbre': ['arm64', 'x86_64']})
            with patch.object(shared, 'output', return_value='x86_64'), patch.object(shared.platform, 'machine', return_value='arm64'), self.assertRaises(ValueError):
                shared.architectures(root)


class WorkflowTests(unittest.TestCase):
    def test_only_five_tour_shards_share_same_attempt_artifact(self):
        workflow = (ROOT / '.github/workflows/nightly.yml').read_text()
        producer = workflow.split('  tour-build:\n')[1].split('  tour:\n')[0]
        tour = workflow.split('  tour:\n')[1].split('  archive:\n')[0]
        self.assertEqual(producer.count('xcodebuild build-for-testing'), 1)
        self.assertNotIn('build-for-testing', tour)
        self.assertEqual(tour.count('test_class:'), 5)
        self.assertIn('needs: tour-build', tour)
        artifact = 'tour-products-${{ github.sha }}-${{ github.run_id }}-${{ github.run_attempt }}'
        self.assertIn(artifact, producer); self.assertIn(artifact, tour)
        self.assertIn('if-no-files-found: error', producer)
        self.assertNotIn('continue-on-error:', tour)
        self.assertIn('-xctestrun "$XCTESTRUN"', tour)
        self.assertIn("if: success() && matrix.shard != 'launch'", tour)
        self.assertIn('ci-out/shared-build.json', tour)
        for name in ['${{ matrix.artifact }}', 'tour-logs-${{ matrix.shard }}', 'tour-warmup-${{ matrix.shard }}', 'ios-tour-evidence-${{ matrix.shard }}']:
            self.assertIn('name: ' + name + '-attempt-${{ github.run_attempt }}', tour)
        self.assertNotIn('overwrite:', tour)
        self.assertIn('pattern: results-tour-*-attempt-${{ github.run_attempt }}', workflow)
        self.assertIn("TOUR_PRODUCER_OUTCOME: ${{ needs['tour-build'].result }}", workflow)
        self.assertIn("if: always() && needs['tour-build'].result != 'skipped'", workflow)

    def test_aggregate_rejects_missing_mixed_or_failed_producer(self):
        with tempfile.TemporaryDirectory() as directory, patch.dict(os.environ, {
                'GITHUB_SHA': 'abc', 'GITHUB_RUN_ID': '123', 'GITHUB_RUN_ATTEMPT': '1',
                'TOUR_SHARED_BUILD_REQUIRED': '1', 'TOUR_PRODUCER_OUTCOME': 'success',
                'TOUR_JOB_OUTCOME': 'success', 'TOUR_ARCHIVE_OUTCOME': 'success',
                'TOUR_BUILD_OUTCOME': 'success', 'TOUR_TEST_OUTCOME': 'success'}):
            root = Path(directory)
            receipt = dict(identity={'sha': 'abc', 'run_id': '123', 'run_attempt': '1'}, archive_sha256='archive',
                           toolchain={'xcode': 'A'}, fixtures={}, simulator={'runtime': 'A'}, architectures={'app': ['arm64']},
                           xctestrun_sha256='xctest', device_id='local')
            for shard in tour_evidence.SHARDS:
                folder = root if shard == 'captures' else root / 'shards' / ('results-tour-' + shard + '-attempt-1')
                folder.mkdir(parents=True, exist_ok=True)
                (folder / 'shared-build.json').write_text(json.dumps(receipt)); os.environ['TOUR_SHARD'] = shard
                tour_evidence.record(folder)
            def aggregate():
                # Expected rejection fixtures must not emit false GitHub error annotations.
                with contextlib.redirect_stdout(io.StringIO()):
                    return tour_evidence.aggregate(root)
            self.assertTrue(aggregate())
            os.environ['TOUR_PRODUCER_OUTCOME'] = 'failure'
            self.assertFalse(aggregate()); os.environ['TOUR_PRODUCER_OUTCOME'] = 'success'
            path = root / 'outcome.json'; good = json.loads(path.read_text())
            for bad in [None, dict(receipt, archive_sha256='another'), dict(receipt, identity={'sha': 'wrong'})]:
                changed = dict(good, shared_build=bad); path.write_text(json.dumps(changed))
                self.assertFalse(aggregate())


if __name__ == '__main__':
    unittest.main()
