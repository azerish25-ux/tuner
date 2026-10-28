#!/usr/bin/env python3
"""Isolate independent XCTest from unconfirmed priming cleanup on owned hosted CI only.

This does not retry priming, remove its failed outcome, erase a device, or claim the
launch failure was benign. No native command runs against an alias or another job.
"""
from __future__ import annotations

from datetime import datetime, timezone
import hashlib
import json
import os
from pathlib import Path
import re
import subprocess
import time
import uuid


def isolate(device: str, warmup_status: Path, out: Path) -> None:
    out.mkdir(parents=True, exist_ok=False)  # An existing result is never overwritten/retried.
    result = {'diagnostic_only': True, 'warmup_failure_retained': True,
              'device': device, 'reset_attempts': 0, 'reset_completed': False,
              'total_budget_seconds': 150, 'commands': []}
    deadline = time.monotonic() + 150

    def stamp():
        return datetime.now(timezone.utc).isoformat()

    def invoke(command, limit):
        event = {'command': command, 'started_at': stamp()}
        result['commands'].append(event)
        try:
            remaining = deadline - time.monotonic()
            if remaining <= 0:
                raise TimeoutError('Owned simulator cleanup total 150-second budget expired')
            event['timeout_seconds'] = min(limit, remaining)
            with (out / 'cleanup.log').open('a') as log:
                log.write(event['started_at'] + ' + ' + ' '.join(command) + '\n')
                log.flush()
                completed = subprocess.run(command, stdout=log, stderr=subprocess.STDOUT,
                                           timeout=event['timeout_seconds'], check=False)
            event['returncode'] = completed.returncode
            if completed.returncode:
                raise RuntimeError(f'Owned simulator cleanup command failed ({completed.returncode}): {command[2]}')
        except (OSError, RuntimeError, subprocess.SubprocessError) as error:
            event['error'] = str(error)
            if isinstance(error, subprocess.TimeoutExpired):
                event['timed_out'] = True
            raise
        finally:
            event['finished_at'] = stamp()

    try:
        if str(uuid.UUID(device)).lower() != device.lower() or os.environ.get('DEVICE_ID') != device:
            raise ValueError('Cleanup requires this job\'s exact selected simulator UUID')
        if os.environ.get('GITHUB_ACTIONS') != 'true' or os.environ.get('RUNNER_ENVIRONMENT') != 'github-hosted':
            raise ValueError('Cleanup is restricted to disposable GitHub-hosted Actions jobs')
        raw = warmup_status.read_bytes()
        prior = json.loads(raw)
        if not isinstance(prior, dict):
            raise ValueError('Warmup receipt must be an object')
        result['warmup_status_sha256'] = hashlib.sha256(raw).hexdigest()
        if prior.get('device') != device or prior.get('diagnostic_only') is not True:
            raise ValueError('Warmup receipt does not identify this diagnostic simulator')
        for field, variable in (('source_sha', 'GITHUB_SHA'), ('run_id', 'GITHUB_RUN_ID'),
                                ('run_attempt', 'GITHUB_RUN_ATTEMPT'), ('job', 'GITHUB_JOB'),
                                ('runner_environment', 'RUNNER_ENVIRONMENT')):
            expected = os.environ.get(variable)
            if not expected or prior.get(field) != expected:
                raise ValueError(f'Warmup receipt does not match current {variable}')
            result[field] = expected
        if not re.fullmatch(r'[0-9a-f]{40}', prior['source_sha']):
            raise ValueError('Warmup source SHA is invalid')
        if prior.get('passed') is True or prior.get('cleanup_confirmed') is True:
            result['skipped'] = 'No unconfirmed failed priming cleanup'
            return
        if 'cleanup_not_required' in prior:
            if prior['cleanup_not_required'] is not True or prior.get('passed') is not False \
                    or type(prior.get('launch_attempts')) is not int or prior['launch_attempts'] != 0 \
                    or 'pid' in prior or prior.get('cleanup_error'):
                raise ValueError('No-launch cleanup marker contradicts the priming receipt')
            result['skipped'] = 'Failed before any app launch attempt'
            return
        if prior.get('passed') is not False or type(prior.get('launch_attempts')) is not int or prior['launch_attempts'] != 1 \
                or prior.get('cleanup_confirmed') is not False or not prior.get('cleanup_error'):
            raise ValueError('Receipt does not establish an unconfirmed failed priming cleanup')
        # One reboot is containment of known unconfirmed termination, not a diagnosis
        # or a retry of the failed launch. Never use shutdown all, erase, or killall.
        result['reset_attempts'] = 1
        invoke(['xcrun', 'simctl', 'shutdown', device], 30)
        invoke(['xcrun', 'simctl', 'bootstatus', device, '-b'], 90)
        result['reset_completed'] = True
        # A reboot can discard the earlier marketing status-bar override.
        invoke(['xcrun', 'simctl', 'status_bar', device, 'override', '--time', '9:41',
                '--batteryState', 'charged', '--batteryLevel', '100', '--cellularBars', '4', '--wifiBars', '3'], 15)
        result['status_bar_restored'] = True
    except (OSError, ValueError, RuntimeError, subprocess.SubprocessError) as error:
        result['error'] = str(error)
        raise RuntimeError('Owned simulator cleanup failed; original warmup failure remains') from error
    finally:
        (out / 'status.json').write_text(json.dumps(result, indent=2) + '\n')
