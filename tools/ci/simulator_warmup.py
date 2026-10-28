#!/usr/bin/env python3
"""Bounded, diagnostic-only simulator app priming before unchanged XCTest checks."""
from __future__ import annotations

from datetime import datetime, timezone
import hashlib
import json
import os
from pathlib import Path
import plistlib
import re
import subprocess
import sys
import time
import uuid

from simulator_priming_signal import wait_for_stage_rest

BUNDLE = 'com.shahradazerisharghi.timbre'
SIMULATOR_PROCESSES = ('SpringBoard', 'testmanagerd', 'runningboardd', 'lsd', 'installd',
                       'launchd', 'ReportCrash', 'tccd', 'mediaserverd', 'audiomxd',
                       'coreaudiod', 'storekitd', 'appstored')


def simulator_predicate(executable: str | None = None) -> str:
    """Use actual executable identity; also retain bundle-tagged events from other services."""
    names = ((executable,) if executable else ()) + SIMULATOR_PROCESSES
    clauses = [f'process == {json.dumps(name)}' for name in names]
    clauses += [f'subsystem == {json.dumps(BUNDLE)}', f'eventMessage CONTAINS[c] {json.dumps(BUNDLE)}']
    return ' OR '.join(clauses)


def installed_executable(container: str, device: str, executable: str, expected_hash: str) -> Path:
    """Fail closed unless get_app_container names this device's genuine installed app."""
    if not isinstance(executable, str) or not executable or Path(executable).name != executable:
        raise ValueError('Invalid installed executable name')
    if not re.fullmatch(r'[0-9a-f]{64}', expected_hash):
        raise ValueError('Invalid expected executable digest')
    if str(uuid.UUID(device)).lower() != device.lower():
        raise ValueError('Process probe requires one explicit simulator UUID')
    bundle = Path(container.strip())
    if not bundle.is_absolute() or '\n' in container.strip() or '..' in bundle.parts:
        raise ValueError('Installed app container is not one absolute path')
    resolved = bundle.resolve(strict=True)
    marker = ('CoreSimulator', 'Devices', device, 'data', 'Containers', 'Bundle', 'Application')
    parts = resolved.parts
    matches = [i for i in range(len(parts)) if parts[i:i + len(marker)] == marker]
    if len(matches) != 1 or len(parts) != matches[0] + len(marker) + 2 or resolved.suffix != '.app':
        raise ValueError('Installed app container is outside the selected simulator bundle directory')
    uuid.UUID(parts[-2])
    metadata = plistlib.loads((resolved / 'Info.plist').read_bytes())
    if not isinstance(metadata, dict) or metadata.get('CFBundleIdentifier') != BUNDLE or metadata.get('CFBundleExecutable') != executable:
        raise ValueError('Installed app identity does not match the selected build')
    path = resolved / executable
    if path.is_symlink() or path.resolve(strict=True).parent != resolved:
        raise ValueError('Installed executable escapes its verified app bundle')
    if hashlib.sha256(path.read_bytes()).hexdigest() != expected_hash:
        raise ValueError('Installed executable differs from selected build')
    return path


def kernel_process_matches(expected: Path) -> dict:
    """macOS child probe: output only matching kernel executable paths; never args/env."""
    import ctypes
    if sys.platform != 'darwin' or os.geteuid() == 0:
        raise RuntimeError('Process lookup is limited to a non-root macOS runner')
    uid = os.getuid()
    result = subprocess.run(['/bin/ps', '-U', str(uid), '-o', 'pid=,uid='],
                            stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True, timeout=3, check=False)
    if result.returncode not in (0, 1):
        raise RuntimeError(f'PID enumeration failed ({result.returncode})')
    rows = result.stdout.splitlines()
    if len(rows) > 4096:
        raise RuntimeError('PID enumeration exceeded diagnostic bound')
    library = ctypes.CDLL('/usr/lib/libproc.dylib', use_errno=True)
    path_for_pid = library.proc_pidpath
    path_for_pid.argtypes = [ctypes.c_int, ctypes.c_void_p, ctypes.c_uint32]
    path_for_pid.restype = ctypes.c_int
    found, unreadable = [], 0
    for row in rows:
        columns = row.split()
        if len(columns) != 2 or not all(x.isdecimal() for x in columns):
            raise ValueError('Unexpected PID enumeration format')
        candidate, owner = map(int, columns)
        if candidate <= 1 or owner != uid:
            continue
        buffer = ctypes.create_string_buffer(4096)
        if path_for_pid(candidate, buffer, len(buffer)) <= 0:
            unreadable += 1
            continue
        if os.fsdecode(buffer.value) == str(expected):
            found.append(candidate)
    return {'expected_executable': str(expected), 'matching_pids': sorted(set(found)), 'unreadable_path_count': unreadable,
            'scope': 'current-user-kernel-executable-path', 'observation_only': True}


def warmup(app: Path, device: str, languages: list[str], locale: str, out: Path) -> None:
    """Install/launch once, terminate, or raise; never certify language/capture evidence."""
    if str(uuid.UUID(device)).lower() != device.lower():
        raise ValueError('Warmup requires an explicit simulator UUID, never an alias')
    out.mkdir(parents=True, exist_ok=False)
    receipt = {'passed': False, 'diagnostic_only': True, 'device': device,
               'app': str(app), 'languages': languages, 'locale': locale,
               'source_sha': os.environ.get('GITHUB_SHA'), 'launch_attempts': 0}
    receipt['run_id'] = os.environ.get('GITHUB_RUN_ID')
    receipt['run_attempt'] = os.environ.get('GITHUB_RUN_ATTEMPT')
    receipt['job'] = os.environ.get('GITHUB_JOB')
    receipt['runner_environment'] = os.environ.get('RUNNER_ENVIRONMENT')
    log = out / 'warmup.log'
    launched = False
    predicate = simulator_predicate()  # Available even if bundle validation fails.
    deadline = time.monotonic() + 300

    def budget(limit, reserve=0):
        remaining = deadline - time.monotonic() - reserve
        if remaining <= 0:
            if reserve:
                raise TimeoutError(f'Warmup diagnostic budget exhausted; {reserve}s reserved for cleanup')
            raise TimeoutError('Simulator warmup total 300-second budget expired')
        return min(limit, remaining)

    child_env = os.environ.copy()
    # Never allow a priming launch to touch the normal user's persisted app state.
    storage = str(uuid.uuid4())
    child_env.update(SIMCTL_CHILD_TIMBRE_TEST_STORAGE_ID=storage,
                     SIMCTL_CHILD_TIMBRE_SKIP_ONBOARDING='1',
                     SIMCTL_CHILD_TIMBRE_DEMO_DATA='1', SIMCTL_CHILD_TIMBRE_DEMO_PITCH='1',
                     SIMCTL_CHILD_TIMBRE_STAGE_REST='1', SIMCTL_CHILD_TIMBRE_SIMULATOR_PRIMING='1')
    receipt['automation_storage_id'] = storage

    def stamp():
        return datetime.now(timezone.utc).isoformat()

    def invoke(args, timeout=120, env=None):
        with log.open('a') as output:
            event = {'command': list(map(str, args)), 'started_at': stamp()}
            receipt.setdefault('commands', []).append(event)
            output.write(event['started_at'] + ' + ' + ' '.join(map(str, args)) + '\n')
            output.flush()
            try:
                result = subprocess.run(list(map(str, args)), env=env, stdout=subprocess.PIPE,
                                        stderr=subprocess.STDOUT, text=True, timeout=budget(timeout))
            except subprocess.TimeoutExpired as error:
                partial = error.stdout or ''
                output.write(partial.decode(errors='replace') if isinstance(partial, bytes) else partial)
                event['timed_out'] = True
                output.write('\nWarmup command deadline expired\n')
                raise
            finally:
                event['finished_at'] = stamp()
            event['returncode'] = result.returncode
            output.write(result.stdout or '')
        if result.returncode:
            raise RuntimeError(f'Warmup command failed ({result.returncode}): {args[2]}')
        return result.stdout or ''

    def diagnose(command, filename, reserve_cleanup=True):
        """Record inconclusive/nonzero diagnostics too; never affect the warmup result."""
        event = {'command': list(map(str, command)), 'filename': filename, 'started_at': stamp()}
        receipt.setdefault('diagnostics', []).append(event)
        try:
            # Do not let optional evidence consume the last cleanup opportunity.
            timeout = budget(30, reserve=30 if launched and reserve_cleanup else 0)
            event['timeout_seconds'] = timeout
            with (out / filename).open('w') as output:
                result = subprocess.run(command, stdout=output, stderr=subprocess.STDOUT, timeout=timeout, check=False)
            event['returncode'] = result.returncode
        except (OSError, subprocess.SubprocessError) as error:
            event['error'] = str(error)
            if isinstance(error, subprocess.TimeoutExpired):
                event['timed_out'] = True
            receipt.setdefault('diagnostic_errors', []).append(str(error))
        finally:
            event['finished_at'] = stamp()

    def probe_query(command, limit=5, record_key='process_probe_commands'):
        event = {'command': list(map(str, command)), 'started_at': stamp()}
        receipt.setdefault(record_key, []).append(event)
        try:
            event['timeout_seconds'] = budget(limit, reserve=30)
            result = subprocess.run(command, stdout=subprocess.PIPE, stderr=subprocess.PIPE,
                                    text=True, timeout=event['timeout_seconds'], check=False)
            event['returncode'] = result.returncode
            if result.returncode:
                raise RuntimeError(f'Process probe command failed ({result.returncode})')
            return result.stdout
        except (OSError, subprocess.SubprocessError, RuntimeError) as error:
            # Do not retain stdout/stderr from process enumeration or environment details.
            event['error'] = str(error)
            raise
        finally:
            event['finished_at'] = stamp()

    def locate_unknown_pid():
        observation = {'status': 'inconclusive', 'diagnostic_only': True,
                       'absence_is_not_proof_of_no_launch': True, 'sample_attempts': 0,
                       'sample_skipped': 'identity_not_atomically_bound'}
        receipt['unknown_launch_pid_probe'] = observation
        try:
            container = probe_query(['xcrun', 'simctl', 'get_app_container', device, BUNDLE, 'app'])
            # Installed plist/digest reads and process metadata stay inside this timeout too.
            command = [sys.executable, str(Path(__file__).absolute()), '--probe-installed-app',
                       container.strip(), device, receipt['executable'], receipt['executable_sha256']]
            found = json.loads(probe_query(command, limit=8))
            if not isinstance(found, dict):
                raise ValueError('Process probe did not return an object')
            candidates = found.get('matching_pids')
            expected = found.get('expected_executable')
            unreadable = found.get('unreadable_path_count')
            if not isinstance(candidates, list) or any(type(pid) is not int or pid <= 1 for pid in candidates) \
                    or len(candidates) != len(set(candidates)) or not isinstance(expected, str) \
                    or not Path(expected).is_absolute() or Path(expected).name != receipt['executable'] \
                    or type(unreadable) is not int or unreadable < 0 \
                    or found.get('scope') != 'current-user-kernel-executable-path' or found.get('observation_only') is not True:
                raise ValueError('Malformed scoped process observation')
            observation['lookup'] = found
            if not candidates:
                observation['status'] = 'no_exact_process_observed'
            elif len(candidates) != 1:
                observation['status'] = 'ambiguous_exact_processes'
            else:
                observation['observed_pid'] = candidates[0]
                observation['status'] = 'one_exact_process_observed'
            # Deliberately no sample PID: another process could reuse/exec the PID after verification.
            # A postcheck cannot undo an out-of-scope sample; metadata is the bounded safe evidence.
        except (OSError, ValueError, KeyError, RuntimeError, subprocess.SubprocessError) as error:
            observation['error'] = str(error)

    try:
        if not languages or len(set(languages)) != len(languages) or any(not re.fullmatch(r'[A-Za-z]+(?:-[A-Za-z0-9]+)*', x) for x in languages):
            raise ValueError('Warmup requires exact explicit AppleLanguages')
        if not re.fullmatch(r'[A-Za-z]+(?:[_-][A-Za-z0-9]+)*', locale):
            raise ValueError('Warmup requires explicit AppleLocale')
        with (app / 'Info.plist').open('rb') as info:
            metadata = plistlib.load(info)
            if metadata.get('CFBundleIdentifier') != BUNDLE:
                raise ValueError('Warmup app bundle identity mismatch')
        executable = metadata.get('CFBundleExecutable', '')
        if not executable or Path(executable).name != executable:
            raise ValueError('Warmup app executable identity missing')
        receipt['bundle_id'] = metadata['CFBundleIdentifier']
        receipt['executable'] = executable
        receipt['info_plist_sha256'] = hashlib.sha256((app / 'Info.plist').read_bytes()).hexdigest()
        receipt['executable_sha256'] = hashlib.sha256((app / executable).read_bytes()).hexdigest()
        # Xcode Debug executables may be a launcher stub; do not mistake its hash for the app code.
        debug_dylib = app / (executable + '.debug.dylib')
        if debug_dylib.is_file():
            receipt['debug_dylib_sha256'] = hashlib.sha256(debug_dylib.read_bytes()).hexdigest()
        predicate = simulator_predicate(executable)
        receipt['total_budget_seconds'] = 300
        invoke(['xcrun', 'simctl', 'install', device, app])
        # A successful CLI grant is a fixture action, not observed in-app permission state.
        receipt['microphone_runtime_permission'] = 'not_observed'
        receipt['microphone_grant_command_succeeded'] = False
        invoke(['xcrun', 'simctl', 'privacy', device, 'grant', 'microphone', BUNDLE], timeout=15)
        receipt['microphone_grant_command_succeeded'] = True
        receipt['launch_attempts'] = 1
        # Terminate even after a timed-out launch: the process may have started.
        launched = True
        launch_started_epoch = time.time()
        output = invoke(['xcrun', 'simctl', 'launch', device, BUNDLE,
                         '-AppleLanguages', '(' + ','.join(languages) + ')', '-AppleLocale', locale], env=child_env)
        match = re.search(re.escape(BUNDLE) + r': ([1-9]\d*)\b', output)
        if not match:
            raise RuntimeError('Warmup launch did not return a valid process ID')
        receipt['pid'] = int(match[1])
        # Wait for the existing resting live child's disappearance, never an elapsed-time guess.
        # It is a lifecycle milestone, not GPU completion or passing UI evidence. Keep cleanup's 30s.
        receipt['rest_signal'] = wait_for_stage_rest(
            device, storage, receipt['pid'], launch_started_epoch, deadline - 30,
            lambda: probe_query(['xcrun', 'simctl', 'get_app_container', device, BUNDLE, 'data'],
                                record_key='rest_signal_commands'), out)
        os.kill(receipt['pid'], 0)
        invoke(['xcrun', 'simctl', 'terminate', device, BUNDLE], timeout=30)
        launched = False
        receipt['cleanup_confirmed'] = True
        receipt['passed'] = True
    except (OSError, ValueError, RuntimeError, subprocess.SubprocessError) as error:
        receipt['error'] = str(error)
        if 'pid' in receipt:
            # Probe only the PID returned by this scoped launch; never send a signal.
            receipt['owned_pid_observed_at'] = stamp()
            try:
                os.kill(receipt['pid'], 0)
                receipt['owned_pid_present'] = True
            except OSError as pid_error:
                receipt['owned_pid_present'] = False
                receipt['owned_pid_error'] = str(pid_error)
        if launched and 'pid' not in receipt:
            locate_unknown_pid()
        # Best-effort diagnosis must never turn a failed warmup into success.
        diagnostics = [
            (['xcrun', 'simctl', 'spawn', device, 'log', 'show', '--last', '5m', '--info', '--debug', '--style', 'compact',
              '--predicate', predicate], 'simulator.log'),
            (['xcrun', 'simctl', 'io', device, 'screenshot', str(out / 'diagnostic-only.png')], 'screenshot.log'),
            (['/usr/bin/log', 'show', '--last', '5m', '--info', '--debug', '--style', 'compact', '--predicate',
              f'eventMessage CONTAINS[c] "{device}" OR eventMessage CONTAINS[c] "{BUNDLE}"'], 'host-launch.log'),
            (['xcrun', 'simctl', 'list', 'devices', '--json'], 'devices.log'),
        ]
        if 'pid' in receipt:
            diagnostics.append((['/bin/ps', '-p', str(receipt['pid']), '-o', 'pid=,ppid=,stat=,etime=,command='], 'owned-pid.log'))
        for command, filename in diagnostics:
            diagnose(command, filename)
        raise RuntimeError('Simulator warmup failed; diagnostic-only evidence: ' + str(out)) from error
    finally:
        if launched:
            try:
                invoke(['xcrun', 'simctl', 'terminate', device, BUNDLE], timeout=30)
                receipt['cleanup_confirmed'] = True
            except (OSError, RuntimeError, subprocess.SubprocessError) as error:
                receipt['cleanup_confirmed'] = False
                receipt['cleanup_error'] = str(error)
                diagnose(['xcrun', 'simctl', 'spawn', device, 'log', 'show', '--last', '5m', '--info', '--debug',
                          '--style', 'compact', '--predicate', predicate],
                         'simulator-after-cleanup.log', reserve_cleanup=False)
        (out / 'status.json').write_text(json.dumps(receipt, indent=2) + '\n')


if __name__ == '__main__':
    try:
        if len(sys.argv) != 6 or sys.argv[1] != '--probe-installed-app':
            raise ValueError('Only the bounded installed-app metadata probe is supported')
        expected = installed_executable(*sys.argv[2:])
        print(json.dumps(kernel_process_matches(expected)))
    except (OSError, ValueError, RuntimeError, subprocess.SubprocessError) as error:
        print(json.dumps({'error': str(error)}))
        raise SystemExit(1)
