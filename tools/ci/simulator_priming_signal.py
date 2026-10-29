"""Bounded observation of one priming session's real resting-stage lifecycle milestone.

This is not a GPU-completion, cold-launch or UI acceptance oracle. Never infer readiness
from elapsed time, an alive PID, a saved store, quiet logs or a missing signal.
"""
from __future__ import annotations

import hashlib
import json
import math
import os
from pathlib import Path
import time
import uuid

from collect_song_page_trace import (CollectionError, bounded_read, invalid_constant,
                                     no_symlinks, scoped_container, unique_object)

FILENAME = 'simulator-priming-stage.json'
MAX_BYTES = 4096
SEMANTICS = 'resting-live-child-disappeared-after-detach-not-gpu-completion'
FIELDS = {'schema', 'diagnosticOnly', 'event', 'sessionID', 'pid', 'bundleID', 'modelID',
          'utcEpoch', 'uptime', 'semantics'}
BUNDLE = 'com.shahradazerisharghi.timbre'


def validate_signal(raw, session, pid, launch_started_epoch, observed_epoch):
    try:
        value = json.loads(raw.decode('utf-8'), object_pairs_hook=unique_object,
                           parse_constant=invalid_constant)
    except (UnicodeError, ValueError, RecursionError) as error:
        raise ValueError('Malformed priming rest signal') from error
    if (not raw.endswith(b'\n') or not isinstance(value, dict) or set(value) != FIELDS
            or type(value['schema']) is not int or value['schema'] != 1
            or value['diagnosticOnly'] is not True
            or value['event'] != 'stage-rest-live-disappeared' or value['semantics'] != SEMANTICS
            or value['sessionID'] != session or type(value['pid']) is not int or value['pid'] != pid
            or value['bundleID'] != BUNDLE or not isinstance(value['modelID'], str)
            or not value['modelID'] or len(value['modelID']) > 128
            or any(ord(c) < 32 for c in value['modelID'])):
        raise ValueError('Priming rest signal has foreign or invalid identity/semantics')
    for field in ('utcEpoch', 'uptime'):
        if type(value[field]) not in (int, float) or not math.isfinite(value[field]) or value[field] <= 0:
            raise ValueError('Priming rest signal has invalid timestamps')
    if not launch_started_epoch <= value['utcEpoch'] <= observed_epoch:
        raise ValueError('Priming rest signal is stale or from a future clock')
    return value


def prepare_stage_rest_container(device, session, deadline, query_container):
    """Resolve once before launch; later calls revalidate locally without asking simctl.

    Pin the installed data directory, not app readiness. A replaced directory, changed
    bundle owner, symlink, existing session namespace or exhausted budget is a failure.
    """
    if str(uuid.UUID(device)).lower() != device.lower() or str(uuid.UUID(session)) != session:
        raise ValueError('Priming preflight requires exact device and fresh canonical session UUIDs')
    if time.monotonic() >= deadline:
        raise TimeoutError('Priming container preflight budget exhausted; 30s reserved for cleanup')
    try:
        container = scoped_container(query_container(), device.upper())
        info = container.lstat()
        if info.st_uid != os.getuid():
            raise ValueError('Priming data container is not owned by the current runner')
        identity = (info.st_dev, info.st_ino, info.st_uid)
        namespace = container / 'Library/Application Support/TimbreUITests' / session
        no_symlinks(namespace, allow_missing=True)
        if namespace.exists():
            raise ValueError('Fresh priming session namespace already exists')
        if time.monotonic() >= deadline:
            raise TimeoutError('Priming container preflight exceeded its cleanup-reserved deadline')
    except CollectionError as error:
        raise ValueError(str(error)) from error

    def revalidate():
        # The successful launch still supplies the PID/time used by wait_for_stage_rest.
        # Cached path text alone is not trusted across app startup.
        try:
            current = scoped_container(str(container), device.upper())
            current_info = current.lstat()
            if (current_info.st_dev, current_info.st_ino, current_info.st_uid) != identity:
                raise ValueError('Prepared priming data container identity changed after launch')
        except CollectionError as error:
            raise ValueError(str(error)) from error
        return str(current)

    return revalidate


def wait_for_stage_rest(device, session, pid, launch_started_epoch, deadline, query_container, out):
    """Deadline already excludes cleanup's reserve. Missing signal is a failure, never success."""
    if str(uuid.UUID(device)).lower() != device.lower() or str(uuid.UUID(session)) != session:
        raise ValueError('Priming rest signal requires exact device and fresh canonical session UUIDs')
    if type(pid) is not int or pid <= 1:
        raise ValueError('Priming rest signal requires the successful scoped launch PID')
    if time.monotonic() >= deadline:
        raise TimeoutError('Priming rest milestone budget exhausted; 30s reserved for cleanup')
    try:
        container = scoped_container(query_container(), device.upper())
        output = Path(out).absolute()
        no_symlinks(output)
        output = output.resolve(strict=True)
        if output == container or container in output.parents:
            raise ValueError('Priming diagnostic output cannot modify app data')
        source = container / 'Library/Application Support/TimbreUITests' / session / FILENAME
        while time.monotonic() < deadline:
            no_symlinks(source, allow_missing=True)
            try:
                raw = bounded_read(source, MAX_BYTES)
            except FileNotFoundError:
                raw = None
            except CollectionError as error:
                # The reusable reader reports absent paths with a scoped error; only genuine absence waits.
                if str(error) != 'Missing source path':
                    raise
                raw = None
            if raw is not None:
                # The prepared callable is local-only. Recheck its pinned directory at acceptance,
                # including when the file appeared after several missing-signal polls.
                if scoped_container(query_container(), device.upper()) != container:
                    raise ValueError('Priming data container changed while waiting for its signal')
                observed_epoch = time.time()
                value = validate_signal(raw, session, pid, launch_started_epoch, observed_epoch)
                # Preserve original bytes for diagnostics, but never write into the simulator's data container.
                if time.monotonic() >= deadline:
                    raise TimeoutError('Priming rest signal arrived after its cleanup-reserved deadline')
                destination = output / 'priming-stage-signal.log'
                with destination.open('xb') as stream:
                    stream.write(raw)
                return {'observed': value, 'sha256': hashlib.sha256(raw).hexdigest(),
                        'observed_at_epoch': observed_epoch, 'diagnostic_only': True,
                        'scope': 'resting-live-child-lifecycle-not-gpu-completion'}
            remaining = deadline - time.monotonic()
            if remaining > 0:
                time.sleep(min(0.25, remaining))
    except CollectionError as error:
        raise ValueError(str(error)) from error
    raise TimeoutError('Priming rest milestone not observed; 30s reserved for cleanup')
