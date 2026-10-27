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
               build=os.environ['TOUR_BUILD_OUTCOME'], tests=os.environ['TOUR_TEST_OUTCOME'])
    directory.mkdir(parents=True, exist_ok=True)
    (directory / 'outcome.json').write_text(json.dumps(row, indent=2) + '\n')


def aggregate(directory):
    problems = []
    evidence = {}
    expected = dict(sha=os.environ['GITHUB_SHA'], run_id=os.environ['GITHUB_RUN_ID'],
                    run_attempt=os.environ['GITHUB_RUN_ATTEMPT'])
    for shard, test_class in SHARDS.items():
        full = directory if shard == 'captures' else directory / 'shards' / ('results-tour-' + shard)
        candidates = [full / 'outcome.json', directory / 'checkpoints' / ('tour-logs-' + shard) / 'outcome.json']
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
        evidence[shard] = row
    jobs = {key: os.environ.get(key, 'missing') for key in ('TOUR_JOB_OUTCOME', 'TOUR_ARCHIVE_OUTCOME')}
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
