#!/usr/bin/env python3
"""Run exhaustive accessibility partitions; checkpoint evidence outside the live xcresult.

Native execution only on the Actions Mac. A successful command without every expected
terminal test case is a failure. Only launch_retry's narrowly classified failures may
be replaced by one retry; all other failures are sticky.
"""
from __future__ import annotations

import json
import os
from pathlib import Path
import re
import subprocess
import sys

from launch_retry import CASE, classify

ROOT = Path(__file__).resolve().parents[2]
PARTITIONS = ('localization', 'screens', 'tabs')


def expected_tests(partition: str) -> set[str]:
    cls = 'LocalizationLaunchUITests' if partition == 'localization' else 'AccessibilityAuditUITests'
    source = (ROOT / 'ios/TimbreUITests' / (cls + '.swift')).read_text()
    methods = re.findall(r'^\s*func (test\w+)\s*\(', source, re.MULTILINE)
    if partition == 'tabs':
        methods = [m for m in methods if m == 'testEveryTab']
    elif partition == 'screens':
        methods = [m for m in methods if m != 'testEveryTab']
    if not methods:
        raise RuntimeError(f'No expected test methods for {partition}')
    return {f'TimbreUITests/{cls}/{m}' for m in methods}


def terminal_tests(text: str) -> set[str]:
    return {f"{m['module']}/{m['cls']}/{m['test']}" for m in CASE.finditer(text)
            if m['state'] in ('passed', 'failed')}


def evaluate_initial(code: int, text: str, expected: set[str]) -> tuple[bool, list[str], list[str]]:
    missing = sorted(expected - terminal_tests(text))
    retry, other = classify(text)
    # Unexpected test failures and infrastructure failure without eligible cases remain failures.
    # Only xcodebuild's test-failure exit (65) is recoverable. A signal or another
    # infrastructure exit stays red even if an earlier test also failed at launch.
    sticky = bool(missing or other or code not in (0, 65)
                  or (code != 0 and not retry) or (code == 0 and retry))
    return sticky, retry if code != 0 else [], missing


def invoke(bundle: Path, log: Path, arguments: list[str]) -> int:
    command = ['xcodebuild', 'test-without-building', '-project', 'ios/Timbre.xcodeproj',
               '-scheme', 'Timbre', '-parallel-testing-enabled', 'NO', *arguments,
               '-destination', f"platform=iOS Simulator,id={os.environ['DEVICE_ID']}",
               '-derivedDataPath', 'ios/build/dd', '-resultBundlePath', str(bundle),
               'CODE_SIGNING_ALLOWED=NO']
    with log.open('w') as output:
        process = subprocess.Popen(command, cwd=ROOT, stdout=subprocess.PIPE,
                                   stderr=subprocess.STDOUT, text=True, bufsize=1)
        assert process.stdout is not None
        for line in process.stdout:
            output.write(line)
            output.flush()
            print(line, end='', flush=True)
        return process.wait()


def run(partition: str) -> int:
    expected = expected_tests(partition)
    directory = ROOT / 'ci-out' / partition
    directory.mkdir(parents=True, exist_ok=True)
    log = directory / 'test.log'
    bundle = ROOT / 'ios/build' / f'Accessibility-{partition}.xcresult'
    # Class selection keeps future methods included; exact coverage is independently checked below.
    arguments = (['-only-testing:TimbreUITests/LocalizationLaunchUITests'] if partition == 'localization'
                 else ['-only-testing:TimbreUITests/AccessibilityAuditUITests/testEveryTab'] if partition == 'tabs'
                 else ['-only-testing:TimbreUITests/AccessibilityAuditUITests',
                       '-skip-testing:TimbreUITests/AccessibilityAuditUITests/testEveryTab'])
    code = invoke(bundle, log, arguments)
    text = log.read_text(errors='replace')
    sticky, retry, missing = evaluate_initial(code, text, expected)
    retry_code = None
    retry_missing: list[str] = []
    if retry:
        retry_log = directory / 'test-relaunch.log'
        retry_code = invoke(bundle.with_name(f'Accessibility-{partition}-relaunch.xcresult'),
                            retry_log, ['-only-testing:' + name for name in retry])
        retry_text = retry_log.read_text(errors='replace')
        retry_missing = sorted(set(retry) - terminal_tests(retry_text))
        retry_launch_failures, retry_failures = classify(retry_text)
        sticky |= bool(retry_code != 0 or retry_missing or retry_failures or retry_launch_failures)
    passed = not sticky
    receipt = dict(partition=partition, expected=sorted(expected), missing=missing,
                   initial_exit=code, retried=retry, retry_exit=retry_code,
                   retry_missing=retry_missing, passed=passed)
    (directory / 'status.json').write_text(json.dumps(receipt, indent=2) + '\n')
    print(json.dumps(receipt), flush=True)
    return 0 if passed else 1


def aggregate() -> int:
    failed = []
    for partition in PARTITIONS:
        path = ROOT / 'ci-out' / partition / 'status.json'
        receipt = json.loads(path.read_text()) if path.exists() else {}
        if not receipt.get('passed') or set(receipt.get('expected', [])) != expected_tests(partition):
            failed.append(partition)
    print('Accessibility partitions: ' + ('failed/missing: ' + ', '.join(failed) if failed else 'all passed'))
    return int(bool(failed))


if __name__ == '__main__':
    if len(sys.argv) != 2 or sys.argv[1] not in (*PARTITIONS, 'aggregate'):
        sys.exit('usage: accessibility_partitions.py localization|screens|tabs|aggregate')
    sys.exit(aggregate() if sys.argv[1] == 'aggregate' else run(sys.argv[1]))
