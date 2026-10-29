#!/usr/bin/env python3
"""Run exhaustive accessibility partitions; checkpoint evidence outside the live xcresult.

Native execution only on the Actions Mac. A successful command without every expected
terminal test case is a failure. Only launch_retry's narrowly classified failures may
be replaced by one retry; all other failures are sticky.
"""
from __future__ import annotations

import json
import gzip
import os
from pathlib import Path
import re
import subprocess
import sys

from launch_retry import CASE, ERROR, classify

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


def submission_disposition(receipt: dict, text: str, expected: set[str]) -> dict:
    """Prospective submission policy; never changes the strict SDK test result.

    Contrast callbacks and the two uncorroborated SDK layout-audit timeouts are advisory.
    Functional assertions, other accessibility failures and incomplete execution still block.
    The fallback deliberately excludes retries and requires one complete execution of every case.
    """
    blocking, advisory, advisory_cases = [], [], set()
    events = {}
    pattern = re.compile(r"Test Case '-\[(\w+)\.(\w+) (test\w+)\]' (started|passed|failed|skipped)")
    for match in pattern.finditer(text):
        name = '/'.join(match.group(1, 2, 3))
        events.setdefault(name, []).append(match[4])
    failed = {name for name, states in events.items() if states == ['started', 'failed']}
    if set(events) != expected or any(states not in (['started', 'passed'], ['started', 'failed']) for states in events.values()):
        blocking.append('Missing, skipped, repeated or unexpected native test execution')
    required = {'expected', 'initial_exit', 'retried', 'retry_exit', 'missing', 'retry_missing', 'passed'}
    if (not required.issubset(receipt) or set(receipt.get('expected', [])) != expected or receipt.get('retried')
            or receipt.get('retry_exit') is not None or receipt.get('missing') or receipt.get('retry_missing')):
        blocking.append('Incomplete, foreign or retried evidence is not eligible for advisory fallback')
    if (type(receipt.get('initial_exit')) is not int or receipt.get('initial_exit') != (65 if failed else 0)
            or receipt.get('passed') is not (not failed)):
        blocking.append('Exit status or strict receipt disagrees with native test events')
    if re.search(r'Test crashed|unexpected exit|exceeded execution|[1-9]\d* tests? skipped', text, re.IGNORECASE):
        blocking.append('Native execution did not finish normally')
    contrast = re.compile(r'^failed - [^:]+: \[contrast, enforced\] Contrast failed \|')
    timeout = re.compile(r'^failed - [^:]+: the accessibility audit could not run '
                         r'\(up to [1-3] isolated tries\): (?:Dynamic Type|clipped text): '
                         r'Audit failed to complete in time$')
    for line in text.splitlines():
        if 'error:' not in line:
            continue
        match = ERROR.search(line)
        if match:
            name = f"{match['module']}/{match['cls']}/{match['test']}"
            message = match['message']
            if name in expected and (contrast.match(message) or timeout.fullmatch(message)):
                advisory.append(message)
                advisory_cases.add(name)
                continue
        blocking.append(line)
    if failed != advisory_cases:
        blocking.append('A failed native case is not fully explained by advisory SDK findings')
    return {'required_checks_passed': not blocking, 'strict_sdk_passed': receipt.get('passed') is True,
            'advisory': advisory, 'blocking': blocking}


def submission_summary(directory: Path) -> dict:
    result = {}
    for partition in PARTITIONS:
        folder = directory / ('accessibility-logs-' + partition)
        try:
            receipt = json.loads((folder / 'status.json').read_text())
            if receipt.get('partition') != partition:
                raise ValueError('Partition identity differs from its evidence directory')
            log = folder / 'test.log'
            text = log.read_text(errors='replace') if log.is_file() else gzip.decompress(
                (folder / 'test.log.gz').read_bytes()).decode('utf-8', errors='replace')
            result[partition] = submission_disposition(receipt, text, expected_tests(partition))
        except (OSError, ValueError, TypeError) as error:
            result[partition] = {'required_checks_passed': False, 'blocking': [str(error)]}
    return {'required_checks_passed': all(value['required_checks_passed'] for value in result.values()),
            'strict_sdk_result_reclassified_as_pass': False, 'partitions': result}


def submission_step_disposition(outcomes: dict) -> list[str]:
    """Only the original SDK partition/aggregate failures may be advisory, never setup/evidence failures."""
    workflow = (ROOT / '.github/workflows/ios.yml').read_text()
    job = workflow.split('  accessibility:\n', 1)[1].split('\n  gate:\n', 1)[0]
    blocks = re.split(r'(?=^      - )', job, flags=re.MULTILINE)[1:]
    identities, optional = set(), set()
    for block in blocks:
        match = re.search(r'^        id: ([\w-]+)$', block, re.MULTILINE)
        if not match or match[1] in identities:
            return ['Every accessibility step must have a unique explicit identity']
        identities.add(match[1])
        if "steps.reveal-opt-in.outputs.enabled == 'true'" in block:
            optional.add(match[1])
    if not isinstance(outcomes, dict) or set(outcomes) != identities:
        return ['Missing or foreign accessibility step outcomes']
    sdk = {'ax-sdk-localization', 'ax-sdk-screens', 'ax-sdk-tabs', 'ax-sdk-aggregate'}
    problems = []
    for identity, details in outcomes.items():
        outcome = details.get('outcome')
        if outcome == 'success' or (identity in sdk and outcome == 'failure'):
            continue
        if identity in optional and outcome == 'skipped':
            continue
        problems.append(identity + ': ' + str(outcome))
    return problems


if __name__ == '__main__':
    if len(sys.argv) != 2 or sys.argv[1] not in (*PARTITIONS, 'aggregate'):
        sys.exit('usage: accessibility_partitions.py localization|screens|tabs|aggregate')
    sys.exit(aggregate() if sys.argv[1] == 'aggregate' else run(sys.argv[1]))
