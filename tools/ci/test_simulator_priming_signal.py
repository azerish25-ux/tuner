import hashlib
import json
import os
from pathlib import Path
import plistlib
import subprocess
import tempfile
from types import SimpleNamespace
import unittest
from unittest.mock import patch

import simulator_priming_signal as signal
import simulator_warmup as warm

DEVICE = 'E952A9B0-CC78-435C-BF08-06AD47FE1076'
SESSION = 'a58d7f97-86c8-4edc-bc8c-45f4c68be5aa'
OTHER = 'a58d7f97-86c8-4edc-bc8c-45f4c68be5ab'


def payload(**changes):
    result = {'schema': 1, 'diagnosticOnly': True, 'event': 'stage-rest-live-disappeared',
              'sessionID': SESSION, 'pid': 123, 'bundleID': signal.BUNDLE, 'modelID': 'fixture-model',
              'utcEpoch': 1001.0, 'uptime': 200.0, 'semantics': signal.SEMANTICS}
    result.update(changes)
    return json.dumps(result).encode() + b'\n'


class SignalTests(unittest.TestCase):
    def fixture(self, root, session=SESSION):
        container = root / 'CoreSimulator/Devices' / DEVICE / 'data/Containers/Data/Application' / OTHER
        container.mkdir(parents=True)
        (container / '.com.apple.mobile_container_manager.metadata.plist').write_bytes(
            plistlib.dumps({'MCMMetadataIdentifier': signal.BUNDLE}))
        source = container / 'Library/Application Support/TimbreUITests' / session / signal.FILENAME
        source.parent.mkdir(parents=True)
        out = root / 'out'; out.mkdir()
        return container, source, out

    def execute(self, source_bytes=payload(), mutate=None, wait=2):
        with tempfile.TemporaryDirectory() as directory:
            container, source, out = self.fixture(Path(directory).resolve())
            if source_bytes is not None: source.write_bytes(source_bytes)
            if mutate: mutate(container, source, out)
            now = [0.0]
            with patch.object(signal.time, 'monotonic', side_effect=lambda: now[0]), \
                 patch.object(signal.time, 'time', return_value=1002.0), \
                 patch.object(signal.time, 'sleep', side_effect=lambda seconds: now.__setitem__(0, now[0] + seconds)):
                result = signal.wait_for_stage_rest(DEVICE, SESSION, 123, 1000.0, wait,
                                                    lambda: str(container) + '\n', out)
            return result, (out/'priming-stage-signal.log').read_bytes(), now[0]

    def test_exact_bytes_and_hash_of_current_session_milestone(self):
        result, raw, elapsed = self.execute()
        self.assertEqual(raw, payload())
        self.assertEqual(result['sha256'], hashlib.sha256(raw).hexdigest())
        self.assertEqual(result['observed']['sessionID'], SESSION)
        self.assertEqual(elapsed, 0)
        self.assertEqual(result['scope'], 'resting-live-child-lifecycle-not-gpu-completion')

    def test_identity_semantics_and_clock_negatives(self):
        changes = [{'schema': True}, {'schema': 2}, {'diagnosticOnly': False}, {'event': 'ready'},
                   {'sessionID': OTHER}, {'pid': 124}, {'pid': True}, {'bundleID': 'foreign'},
                   {'modelID': ''}, {'modelID': 'x'*129}, {'modelID': 'x\n'}, {'modelID': None},
                   {'utcEpoch': 999}, {'utcEpoch': 1003}, {'utcEpoch': True}, {'uptime': 0},
                   {'uptime': float('nan')}, {'utcEpoch': float('inf')}, {'semantics': 'gpu-ready'},
                   {'unexpected': True}]
        for changed in changes:
            with self.subTest(changed=changed), self.assertRaises(ValueError): self.execute(payload(**changed))

    def test_malformed_duplicate_and_missing_terminator_fail(self):
        for raw in [b'{}\n', b'[]\n', b'null\n', b'{', b'\xff\n', payload().rstrip(),
                    payload().replace(b'"schema": 1', b'"schema": 1, "schema": 1')]:
            with self.subTest(raw=raw), self.assertRaises(ValueError): self.execute(raw)

    def test_missing_signal_uses_only_deadline_and_fails(self):
        with self.assertRaisesRegex(TimeoutError, 'not observed; 30s reserved'):
            self.execute(None)

    def test_stale_namespace_is_not_scanned_or_accepted(self):
        def mutate(container, source, out):
            foreign = source.parent.parent / OTHER; foreign.mkdir()
            (foreign / signal.FILENAME).write_bytes(payload())
        with self.assertRaises(TimeoutError): self.execute(None, mutate)

    def test_symlink_and_nonregular_or_oversized_signal_fail(self):
        def symlink(container, source, out):
            target=out/'original';target.write_bytes(payload());source.unlink();source.symlink_to(target)
        def directory(container, source, out): source.unlink();source.mkdir()
        for mutate in [symlink, directory]:
            with self.subTest(mutate=mutate), self.assertRaises(ValueError): self.execute(mutate=mutate)
        with self.assertRaises(ValueError): self.execute(b' '*4097)

    def test_wrong_container_metadata_fails(self):
        def mutate(container, source, out):
            (container/'.com.apple.mobile_container_manager.metadata.plist').write_bytes(
                plistlib.dumps({'MCMMetadataIdentifier': 'foreign'}))
        with self.assertRaisesRegex(ValueError, 'wrong bundle'): self.execute(mutate=mutate)

    def test_existing_output_is_not_overwritten(self):
        def mutate(container, source, out): (out/'priming-stage-signal.log').write_bytes(b'prior')
        with self.assertRaises(FileExistsError): self.execute(mutate=mutate)

    def test_deadline_expired_before_query_makes_no_query(self):
        query = lambda: self.fail('Query after expired budget')
        with patch.object(signal.time, 'monotonic', return_value=10), self.assertRaises(TimeoutError):
            signal.wait_for_stage_rest(DEVICE, SESSION, 123, 1000, 10, query, Path('unused'))

    def test_no_late_success_after_bounded_read(self):
        times = iter([0, 0, 3])
        with tempfile.TemporaryDirectory() as directory:
            container, source, out = self.fixture(Path(directory).resolve()); source.write_bytes(payload())
            with patch.object(signal.time, 'monotonic', side_effect=lambda: next(times, 3)), \
                 patch.object(signal.time, 'time', return_value=1002), self.assertRaises(TimeoutError):
                signal.wait_for_stage_rest(DEVICE, SESSION, 123, 1000, 2, lambda: str(container), out)
            self.assertFalse((out/'priming-stage-signal.log').exists())

    def test_invalid_container_scope_and_text(self):
        for response in ['booted', '/tmp/foreign', '/tmp\x00bad', '/tmp\nforeign']:
            with self.subTest(response=response), self.assertRaises(ValueError):
                signal.wait_for_stage_rest(DEVICE, SESSION, 123, 1000, float('inf'), lambda: response, Path('unused'))

    def test_output_inside_container_is_rejected_without_copy(self):
        with tempfile.TemporaryDirectory() as directory:
            container, source, out = self.fixture(Path(directory).resolve()); source.write_bytes(payload())
            with patch.object(signal.time, 'monotonic', return_value=0), self.assertRaises(ValueError):
                signal.wait_for_stage_rest(DEVICE, SESSION, 123, 1000, 2, lambda: str(container), source.parent)
            self.assertFalse((source.parent/'priming-stage-signal.log').exists())

    def test_query_failure_is_not_a_signal(self):
        def query(): raise subprocess.TimeoutExpired(['get_app_container'], 5)
        with self.assertRaises(subprocess.TimeoutExpired):
            signal.wait_for_stage_rest(DEVICE, SESSION, 123, 1000, float('inf'), query, Path('unused'))


class IntegrationTests(unittest.TestCase):
    def execute(self, milestone_failure=None, launch_failure=False, terminate_failure=False):
        with tempfile.TemporaryDirectory() as directory:
            root=Path(directory);app=root/'Timbre.app';app.mkdir();out=root/'out'
            (app/'Info.plist').write_bytes(plistlib.dumps({'CFBundleIdentifier': warm.BUNDLE, 'CFBundleExecutable':'Timbre'}))
            (app/'Timbre').write_bytes(b'fixture')
            calls=[];now=[0.0]
            def native(command, **kwargs):
                calls.append((command,kwargs))
                if command[:3] == ['xcrun','simctl','launch'] and launch_failure:
                    raise subprocess.TimeoutExpired(command,kwargs['timeout'])
                if command[:3] == ['xcrun','simctl','terminate'] and terminate_failure:
                    raise subprocess.TimeoutExpired(command,kwargs['timeout'])
                return SimpleNamespace(returncode=0,stdout=warm.BUNDLE+': 123\n',stderr='')
            def milestone(device,session,pid,started,deadline,query,out):
                self.assertEqual(deadline,270)
                self.assertEqual(pid,123)
                if milestone_failure:
                    now[0]=270
                    raise milestone_failure
                return {'synthetic': True}
            with patch.object(warm.subprocess,'run',side_effect=native), \
                 patch.object(warm,'wait_for_stage_rest',side_effect=milestone) as wait, \
                 patch.object(warm.time,'monotonic',side_effect=lambda:now[0]), patch.object(warm.os,'kill'):
                if milestone_failure or launch_failure or terminate_failure:
                    with self.assertRaises(RuntimeError): warm.warmup(app,DEVICE,['en'],'en_US',out)
                else: warm.warmup(app,DEVICE,['en'],'en_US',out)
            return json.loads((out/'status.json').read_text()), calls, wait.call_count

    def test_warmup_uses_real_reader_for_its_new_launch_session(self):
        with tempfile.TemporaryDirectory() as directory:
            root=Path(directory).resolve(); app=root/'Timbre.app'; app.mkdir(); out=root/'warmup'
            (app/'Info.plist').write_bytes(plistlib.dumps({'CFBundleIdentifier': warm.BUNDLE, 'CFBundleExecutable':'Timbre'}))
            (app/'Timbre').write_bytes(b'fixture')
            container, source, unused = SignalTests().fixture(root)
            events=[]
            def native(command, **kwargs):
                events.append((command,kwargs))
                if command[:3] == ['xcrun','simctl','launch']:
                    session=kwargs['env']['SIMCTL_CHILD_TIMBRE_TEST_STORAGE_ID']
                    actual=source.parent.parent/session/signal.FILENAME;actual.parent.mkdir()
                    actual.write_bytes(payload(sessionID=session,utcEpoch=1002))
                text=str(container)+'\n' if command[:3]==['xcrun','simctl','get_app_container'] else warm.BUNDLE+': 123\n'
                return SimpleNamespace(returncode=0,stdout=text,stderr='')
            with patch.object(warm.subprocess,'run',side_effect=native), patch.object(warm.os,'kill'), \
                 patch.object(warm.time,'time',return_value=1002), patch.object(warm.time,'monotonic',return_value=0):
                warm.warmup(app,DEVICE,['en'],'en_US',out)
            status=json.loads((out/'status.json').read_text())
            self.assertTrue(status['passed'])
            self.assertEqual(status['rest_signal']['observed']['sessionID'],status['automation_storage_id'])
            self.assertEqual(len(status['rest_signal_commands']),1)
            self.assertEqual(status['rest_signal_commands'][0]['timeout_seconds'],5)
            self.assertEqual([c[0][2] for c in events],['install','privacy','launch','get_app_container','terminate'])

    def test_only_successful_launch_enters_milestone_wait_with_reserve(self):
        status,calls,count=self.execute()
        self.assertEqual(count,1);self.assertTrue(status['passed']);self.assertEqual(status['total_budget_seconds'],300)
        self.assertEqual([c[0][2] for c in calls],['install','privacy','launch','terminate'])
        child=calls[2][1]['env'];self.assertEqual(child['SIMCTL_CHILD_TIMBRE_SIMULATOR_PRIMING'],'1')
        self.assertEqual(child['SIMCTL_CHILD_TIMBRE_TEST_STORAGE_ID'],status['automation_storage_id'])

    def test_missing_error_or_foreign_signal_retains_failure_and_cleanup(self):
        for error in [TimeoutError('not observed'),ValueError('foreign session'),OSError('read failed')]:
            with self.subTest(error=error):
                status,calls,count=self.execute(milestone_failure=error)
                self.assertEqual(count,1);self.assertFalse(status['passed']);self.assertTrue(status['cleanup_confirmed'])
                self.assertEqual(calls[-1][0][2],'terminate');self.assertEqual(calls[-1][1]['timeout'],30)
                self.assertEqual(status['launch_attempts'],1)

    def test_launch_timeout_stays_original_and_never_waits(self):
        status,calls,count=self.execute(launch_failure=True)
        self.assertEqual(count,0);self.assertFalse(status['passed']);self.assertIn('120',status['error'])
        self.assertEqual(sum(c[0][:3]==['xcrun','simctl','launch'] for c in calls),1)

    def test_observed_milestone_does_not_clear_termination_failure(self):
        status,calls,count=self.execute(terminate_failure=True)
        self.assertEqual(count,1);self.assertFalse(status['passed']);self.assertIn('30',status['error'])


class SourceContractTests(unittest.TestCase):
    def test_existing_rest_path_and_strict_live_disappearance_guards(self):
        root=Path(__file__).resolve().parents[2]
        source=(root/'ios/Timbre/Stage/InstrumentStage.swift').read_text()
        self.assertIn('controller.detach()\n        mounted = false',source)
        self.assertIn('.onDisappear { reportPrimingRest() }',source)
        body=source.split('private func reportPrimingRest()',1)[1].split('    #endif',1)[0]
        for exact in ['ready, still, !mounted, resting, !showcase','controller.wanted == modelID',
                      'controller.loadedModel == modelID, !controller.failed','TestSupport.stageResting']:
            self.assertIn(exact,body)
        for forbidden in ['Task.sleep','mounted =','ready =','still =','controller.detach()']:
            self.assertNotIn(forbidden,body)
        self.assertIn('static let idle = 12.0',source)

    def test_debug_only_one_attempt_writer_and_no_ui_override(self):
        root=Path(__file__).resolve().parents[2]
        source=(root/'ios/Timbre/Support/TestSupport.swift').read_text()
        body=source.split('#if DEBUG\nextension TestSupport {',1)[1]
        self.assertTrue(body.rstrip().endswith('#endif'))
        for exact in ['@MainActor private static var primingRestReported = false','isOn(.simulatorPriming), stageResting',
                      'UUID(uuidString: session) != nil','let directory = storageRoot','primingRestReported = true',
                      'options: .atomic','resting-live-child-disappeared-after-detach-not-gpu-completion']:
            self.assertIn(exact,body)
        for forbidden in ['accessibility','UserDefaults','URLSession']:
            self.assertNotIn(forbidden,body)

    def test_host_has_no_guessed_settle_and_unmodified_independent_test_contract(self):
        root=Path(__file__).resolve().parents[2]
        source=(root/'tools/ci/simulator_warmup.py').read_text()
        self.assertNotIn('time.sleep(budget(10))',source)
        self.assertIn("deadline = time.monotonic() + 300",source)
        self.assertIn("launch_started_epoch, deadline - 30",source)
        self.assertIn("record_key='rest_signal_commands'",source)
        marketing=(root/'tools/marketing/run_listing_assets.py').read_text()
        self.assertIn('if attempt == 1 and not warmup_failed and launch_only_failure(log):',marketing)
        self.assertIn("retain('warmup', error)",marketing)
        self.assertIn('independent XCTest still runs',marketing)
        workflow=(root/'.github/workflows/ios.yml').read_text()
        self.assertIn('python3 tools/ci/test_simulator_priming_signal.py',workflow)


if __name__=='__main__':unittest.main()
