#!/usr/bin/env python3
"""Record and aggregate class-sharded tour outcomes; missing evidence never means success."""
import json
import os
from pathlib import Path
import sys

SHARDS = {
    'captures': 'TimbreUITests',
    'launch': 'LaunchPerformanceUITests',
    'first-session': 'FirstSessionUITests',
    'lesson-layout': 'LessonAccessibilityLayoutUITests',
    'song-rails': 'SongShelfRailUITests',
}


def record(directory):
    shard = os.environ['TOUR_SHARD']
    row = dict(shard=shard, test_class=SHARDS[shard], sha=os.environ['GITHUB_SHA'],
               run_id=os.environ['GITHUB_RUN_ID'], run_attempt=os.environ['GITHUB_RUN_ATTEMPT'],
               build=os.environ['TOUR_BUILD_OUTCOME'], tests=os.environ['TOUR_TEST_OUTCOME'],
               device_id=os.environ.get('DEVICE_ID'), job=os.environ.get('GITHUB_JOB'),
               runner_environment=os.environ.get('RUNNER_ENVIRONMENT'))
    priming = directory / 'warmup/status.json'
    row['priming'] = dict(requested=os.environ.get('TOUR_PRIMING_ENABLED') == 'true' and shard != 'launch',
                         outcome=os.environ.get('TOUR_PRIMING_OUTCOME', 'missing'),
                         receipt=json.loads(priming.read_text()) if priming.exists() else None)
    if os.environ.get('TOUR_SHARED_BUILD_REQUIRED') == '1':
        receipt = directory / 'shared-build.json'
        row['shared_build'] = json.loads(receipt.read_text()) if receipt.exists() else None
    directory.mkdir(parents=True, exist_ok=True)
    (directory / 'outcome.json').write_text(json.dumps(row, indent=2) + '\n')


def aggregate(directory):
    problems = []
    evidence = {}
    shared = []
    expected = dict(sha=os.environ['GITHUB_SHA'], run_id=os.environ['GITHUB_RUN_ID'],
                    run_attempt=os.environ['GITHUB_RUN_ATTEMPT'])
    enabled = os.environ.get('TOUR_PRIMING_ENABLED')
    if enabled not in ('true', 'false'):
        problems.append('Missing or invalid diagnostic priming selection')
    for shard, test_class in SHARDS.items():
        suffix = '-attempt-' + expected['run_attempt'] if os.environ.get('TOUR_SHARED_BUILD_REQUIRED') == '1' else ''
        full = directory if shard == 'captures' else directory / 'shards' / ('results-tour-' + shard + suffix)
        candidates = [full / 'outcome.json', directory / 'checkpoints' / ('tour-logs-' + shard + suffix) / 'outcome.json']
        rows = []
        for path in candidates:
            if not path.exists():
                continue
            try:
                row = json.loads(path.read_text())
                if not isinstance(row, dict):
                    raise ValueError('not an object')
                rows.append(row)
            except (ValueError, OSError) as error:
                problems.append(f'{shard}: unreadable {path.name}: {error}')
        if not candidates[0].exists():
            problems.append(f'{shard}: full results artifact missing (checkpoint is diagnostic only)')
        if not rows:
            problems.append(f'{shard}: no outcome record')
            continue
        row = rows[0]
        if any(other != row for other in rows[1:]):
            problems.append(f'{shard}: conflicting full/checkpoint outcomes')
        for key, value in dict(expected, shard=shard, test_class=test_class).items():
            if row.get(key) != value:
                problems.append(f'{shard}: {key} mismatch')
        for key in ('build', 'tests'):
            if row.get(key) != 'success':
                problems.append(f'{shard}: {key}={row.get(key, "missing")}')
        requested = enabled == 'true' and shard != 'launch'
        priming = row.get('priming')
        if not isinstance(priming, dict) or set(priming) != {'requested', 'outcome', 'receipt'} \
                or priming['requested'] is not requested:
            problems.append(f'{shard}: missing or mismatched diagnostic priming selection')
        elif not requested:
            if priming['outcome'] != 'skipped' or priming['receipt'] is not None:
                problems.append(f'{shard}: unrequested diagnostic priming ran or has unexpected evidence')
        else:
            receipt = priming['receipt']
            if priming['outcome'] != 'success' or not isinstance(receipt, dict) \
                    or receipt.get('passed') is not True or receipt.get('diagnostic_only') is not True \
                    or receipt.get('source_sha') != expected['sha'] \
                    or any(receipt.get(key) != expected[key] for key in ('run_id', 'run_attempt')) \
                    or not row.get('device_id') or receipt.get('device') != row['device_id'] \
                    or row.get('job') != 'tour' or receipt.get('job') != row['job'] \
                    or receipt.get('shard') != shard or row.get('runner_environment') != 'github-hosted' \
                    or receipt.get('runner_environment') != row['runner_environment']:
                problems.append(f'{shard}: requested diagnostic priming failed, is missing or belongs to another run')
        if os.environ.get('TOUR_SHARED_BUILD_REQUIRED') == '1':
            receipt = row.get('shared_build')
            if not isinstance(receipt, dict) or receipt.get('identity') != expected:
                problems.append(f'{shard}: missing or foreign shared-build receipt')
            elif not all(receipt.get(key) for key in ('archive_sha256', 'toolchain', 'simulator', 'architectures', 'xctestrun_sha256', 'device_id')) or 'fixtures' not in receipt:
                problems.append(f'{shard}: incomplete shared-build receipt')
            else:
                if receipt['device_id'] != row.get('device_id'):
                    problems.append(f'{shard}: device differs from the restored shared build')
                shared.append({key: value for key, value in receipt.items() if key != 'device_id'})
        evidence[shard] = row
    jobs = {key: os.environ.get(key, 'missing') for key in ('TOUR_JOB_OUTCOME', 'TOUR_ARCHIVE_OUTCOME')}
    if os.environ.get('TOUR_SHARED_BUILD_REQUIRED') == '1':
        jobs['TOUR_PRODUCER_OUTCOME'] = os.environ.get('TOUR_PRODUCER_OUTCOME', 'missing')
        if len(shared) != len(SHARDS) or any(row != shared[0] for row in shared[1:]):
            problems.append('Shared-build identities differ across tour shards or are missing')
    for key, result in jobs.items():
        if result != 'success':
            problems.append(f'{key}={result}')
    directory.mkdir(parents=True, exist_ok=True)
    (directory / 'tour-shards.json').write_text(json.dumps(dict(expected, expected_shards=SHARDS,
        outcomes=evidence, jobs=jobs, problems=problems, complete=not problems), indent=2) + '\n')
    for problem in problems:
        print('::error::' + problem)
    return not problems


if __name__ == '__main__':
    command, path = sys.argv[1:]
    if command == 'record':
        record(Path(path))
    elif command == 'aggregate':
        sys.exit(0 if aggregate(Path(path)) else 1)
    else:
        raise SystemExit('expected record or aggregate')
