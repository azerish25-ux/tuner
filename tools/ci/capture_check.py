#!/usr/bin/env python3
"""Run the native capture pilot with one strictly bounded launch-only recovery.

Original and retry evidence remain separate. This never manufactures captures or
approves release; a passing attempt must execute all eight tests and export all
six original capture attachments.
"""
from __future__ import annotations

import json
import os
from pathlib import Path
import subprocess
import sys

from launch_retry import CASE, classify

ROOT = Path(__file__).resolve().parents[2]
METHODS = (
    'testCaptureLocalizationNavigationFixture', 'testStoreResultsBoundsCalculation',
    'test11StoreTunerLock', 'test13StoreStrum', 'test14StoreSongPerform',
    'test17StoreInstrumentWall', 'test12StoreChord', 'test19StoreViolinResults',
)
EXPECTED = {'TimbreUITests/TimbreUITests/' + method for method in METHODS}
CAPTURES = ('10b-tune-locked', '11b-tune-strum', '31b-instruments-folk',
            '52b-lesson-chord', '62b-lesson-results-violin', '65-song-perform')


def evaluate(code: int, text: str) -> tuple[bool, bool]:
    """Return (passed, retryable); partial/abnormal/contradictory runs fail closed."""
    terminal = [m for m in CASE.finditer(text) if m['state'] in ('passed', 'failed')]
    names = [f"{m['module']}/{m['cls']}/{m['test']}" for m in terminal]
    if len(names) != len(EXPECTED) or set(names) != EXPECTED:
        return False, False
    retry, other = classify(text)
    failed = any(m['state'] == 'failed' for m in terminal)
    # The classifier accounts for per-test XCTest errors; reject standalone build,
    # infrastructure, or otherwise unclassified error lines as well.
    from launch_retry import ERROR
    failed_names = {f"{m['module']}/{m['cls']}/{m['test']}" for m in terminal if m['state'] == 'failed'}
    errors = [m for line in text.splitlines() if (m := ERROR.search(line))]
    if any(f"{m['module']}/{m['cls']}/{m['test']}" not in failed_names for m in errors):
        return False, False
    if any('error:' in line and not ERROR.search(line) for line in text.splitlines()):
        return False, False
    if code == 0:
        return not failed and not retry and not other, False
    return False, code == 65 and bool(retry) and not other


def command(mode: str, bundle: Path) -> list[str]:
    return ['xcodebuild', mode, '-project', 'ios/Timbre.xcodeproj', '-scheme', 'Timbre',
            '-destination', 'platform=iOS Simulator,id=' + os.environ['DEVICE_ID'],
            '-derivedDataPath', 'ios/build/capture-check', '-parallel-testing-enabled', 'NO',
            *['-only-testing:' + name for name in sorted(EXPECTED)],
            '-resultBundlePath', str(bundle), 'CODE_SIGNING_ALLOWED=NO']


def invoke(mode: str, bundle: Path, log: Path) -> int:
    with log.open('w') as output:
        process = subprocess.Popen(command(mode, bundle), cwd=ROOT, stdout=subprocess.PIPE,
                                   stderr=subprocess.STDOUT, text=True, bufsize=1)
        assert process.stdout is not None
        for line in process.stdout:
            output.write(line)
            output.flush()
            print(line, end='', flush=True)
        return process.wait()


def validate_captures(folder: Path):
    sys.path.insert(0, str(ROOT / 'tools/marketing'))
    from screenshots import attachments
    found = attachments(folder)
    paths = []
    for name in CAPTURES:
        if name + '-wrong' in found or len(found.get(name, [])) != 1:
            raise ValueError(name + ': missing, duplicate, or explicitly invalid capture')
        path = found[name][0].resolve()
        if not path.is_relative_to(folder.resolve()) or not path.is_file():
            raise ValueError(name + ': missing or out-of-folder capture')
        paths.append(path)
    if len(set(paths)) != len(CAPTURES):
        raise ValueError('One original attachment reused for different frames')


def run(out: Path) -> int:
    out.mkdir(parents=True, exist_ok=True)
    receipt = {'source_sha': os.environ.get('GITHUB_SHA'),
               'language': os.environ.get('TEST_RUNNER_TIMBRE_UI_LANGUAGE'),
               'locale': os.environ.get('TEST_RUNNER_TIMBRE_UI_LOCALE'),
               'attempts': [], 'selected_attempt': None, 'passed': False}
    try:
        for attempt in (1, 2):
            folder = out / f'attempt-{attempt}'
            folder.mkdir(exist_ok=False)
            bundle, log = folder / 'CaptureCheck.xcresult', folder / 'test.log'
            code = invoke('test' if attempt == 1 else 'test-without-building', bundle, log)
            passed, retryable = evaluate(code, log.read_text(errors='replace'))
            receipt['attempts'].append({'attempt': attempt, 'exit': code,
                                        'tests_passed': passed, 'launch_retry_eligible': retryable})
            # Export both attempts independently, never merge or replace originals.
            if bundle.is_dir():
                subprocess.run(['xcrun', 'xcresulttool', 'export', 'attachments', '--path', str(bundle),
                                '--output-path', str(folder / 'screenshots')], check=True)
            if passed:
                validate_captures(folder / 'screenshots')
                receipt.update(selected_attempt=attempt, passed=True)
                return 0
            if attempt != 1 or not retryable:
                return 1
            subprocess.run(['xcrun', 'simctl', 'shutdown', os.environ['DEVICE_ID']], check=True)
            subprocess.run(['xcrun', 'simctl', 'boot', os.environ['DEVICE_ID']], check=True)
            subprocess.run(['xcrun', 'simctl', 'bootstatus', os.environ['DEVICE_ID'], '-b'], check=True)
        return 1
    except (OSError, ValueError, subprocess.CalledProcessError) as error:
        receipt['error'] = str(error)
        print(str(error), file=sys.stderr)
        return 1
    finally:
        (out / 'status.json').write_text(json.dumps(receipt, indent=2) + '\n')
        print(json.dumps(receipt), flush=True)


if __name__ == '__main__':
    sys.exit(run(ROOT / 'ci-out'))
