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
import time
import uuid

BUNDLE = 'com.shahradazerisharghi.timbre'


def warmup(app: Path, device: str, languages: list[str], locale: str, out: Path) -> None:
    """Install/launch once, terminate, or raise; never certify language/capture evidence."""
    out.mkdir(parents=True, exist_ok=False)
    receipt = {'passed': False, 'diagnostic_only': True, 'device': device,
               'app': str(app), 'languages': languages, 'locale': locale,
               'source_sha': os.environ.get('GITHUB_SHA'), 'launch_attempts': 0}
    log = out / 'warmup.log'
    launched = False
    deadline = time.monotonic() + 300

    def budget(limit):
        remaining = deadline - time.monotonic()
        if remaining <= 0:
            raise TimeoutError('Simulator warmup total 300-second budget expired')
        return min(limit, remaining)

    child_env = os.environ.copy()
    # Never allow a priming launch to touch the normal user's persisted app state.
    storage = str(uuid.uuid4())
    child_env.update(SIMCTL_CHILD_TIMBRE_TEST_STORAGE_ID=storage,
                     SIMCTL_CHILD_TIMBRE_SKIP_ONBOARDING='1',
                     SIMCTL_CHILD_TIMBRE_DEMO_DATA='1', SIMCTL_CHILD_TIMBRE_DEMO_PITCH='1',
                     SIMCTL_CHILD_TIMBRE_STAGE_REST='1')
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
        receipt['executable_sha256'] = hashlib.sha256((app / executable).read_bytes()).hexdigest()
        receipt['total_budget_seconds'] = 300
        invoke(['xcrun', 'simctl', 'install', device, app])
        receipt['launch_attempts'] = 1
        # Terminate even after a timed-out launch: the process may have started.
        launched = True
        output = invoke(['xcrun', 'simctl', 'launch', device, BUNDLE,
                         '-AppleLanguages', '(' + ','.join(languages) + ')', '-AppleLocale', locale], env=child_env)
        match = re.search(re.escape(BUNDLE) + r': ([1-9]\d*)\b', output)
        if not match:
            raise RuntimeError('Warmup launch did not return a valid process ID')
        receipt['pid'] = int(match[1])
        # Existing accessibility priming uses the same ten-second settle. This is
        # not an assertion timeout increase and contributes no passing UI evidence.
        time.sleep(budget(10))
        os.kill(receipt['pid'], 0)
        invoke(['xcrun', 'simctl', 'terminate', device, BUNDLE], timeout=30)
        launched = False
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
        # Best-effort diagnosis must never turn a failed warmup into success.
        diagnostics = [
            (['xcrun', 'simctl', 'spawn', device, 'log', 'show', '--last', '3m', '--style', 'compact',
              '--predicate', 'process == "Timbre" OR process == "SpringBoard" OR process == "testmanagerd"'], 'simulator.log'),
            (['xcrun', 'simctl', 'io', device, 'screenshot', str(out / 'diagnostic-only.png')], 'screenshot.log'),
        ]
        if 'pid' in receipt:
            diagnostics.append((['/bin/ps', '-p', str(receipt['pid']), '-o', 'pid=,ppid=,stat=,etime=,command='], 'owned-pid.log'))
        for command, filename in diagnostics:
            try:
                with (out / filename).open('w') as output:
                    subprocess.run(command, stdout=output, stderr=subprocess.STDOUT, timeout=budget(30), check=False)
            except (OSError, subprocess.SubprocessError) as diagnostic_error:
                receipt.setdefault('diagnostic_errors', []).append(str(diagnostic_error))
        raise RuntimeError('Simulator warmup failed; diagnostic-only evidence: ' + str(out)) from error
    finally:
        if launched:
            try:
                invoke(['xcrun', 'simctl', 'terminate', device, BUNDLE], timeout=30)
            except (OSError, RuntimeError, subprocess.SubprocessError) as error:
                receipt['cleanup_error'] = str(error)
        (out / 'status.json').write_text(json.dumps(receipt, indent=2) + '\n')
