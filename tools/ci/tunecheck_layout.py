#!/usr/bin/env python3
"""Run eight real tune-check layouts on one explicitly supplied compact simulator.

Requires already-built Timbre UI tests and an available iPhone SE (3rd generation)
on iOS 18 or later. Before invoking, use the standard native-CI preparation to boot
that exact device, install the built app, and grant its microphone permission.
This runner does not build, install, create devices, or alter privacy permissions.
Never substitutes a device, retries, skips a case, or
changes native attachments. The fresh output directory retains the full xcresult,
original exports, logs, device metadata, and a fail-closed status receipt.
"""
from __future__ import annotations

import argparse
from collections import Counter
import hashlib
import json
from pathlib import Path
import re
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[2]
CLASS = 'TuneCheckLayoutUITests'
DEVICE_TYPE = 'com.apple.CoreSimulator.SimDeviceType.iPhone-SE-3rd-generation'
METHODS = (
    'testEnglishPortraitLarge', 'testEnglishLandscapeLarge',
    'testEnglishPortraitAX5', 'testEnglishLandscapeAX5',
    'testArabicPortraitLarge', 'testArabicLandscapeLarge',
    'testArabicPortraitAX5', 'testArabicLandscapeAX5',
)
EXPECTED = frozenset(f'TimbreUITests/{CLASS}/{method}' for method in METHODS)
PHASES = ('arrival', 'clear-title', 'clear-instructions', 'clear-rail', 'clear-note',
          'clear-hint', 'clear-fretboard', 'skip-activated')
UUID = re.compile(r'[0-9a-fA-F]{8}(?:-[0-9a-fA-F]{4}){3}-[0-9a-fA-F]{12}')
CASE = re.compile(
    r"Test Case '-\[(?P<module>\w+)\.(?P<cls>\w+) (?P<test>\w+)\]' "
    r'(?P<state>started|passed|failed|skipped)')


def validate_source(source: str) -> None:
    methods = re.findall(r'^\s*func (test\w+)\s*\(', source, re.MULTILINE)
    if Counter(methods) != Counter(METHODS):
        raise ValueError('UI source must contain exactly the eight expected test methods')


def validate_device(devices: dict, runtimes: dict, device_id: str) -> dict:
    if UUID.fullmatch(device_id) is None:
        raise ValueError('--device-id must be an explicit simulator UUID')
    matches = [(runtime, device) for runtime, items in devices.get('devices', {}).items()
               for device in items if device.get('udid', '').lower() == device_id.lower()]
    if len(matches) != 1:
        raise ValueError('The supplied simulator UUID must identify exactly one available device')
    runtime_id, device = matches[0]
    if device.get('isAvailable') is not True or device.get('deviceTypeIdentifier') != DEVICE_TYPE:
        raise ValueError('The supplied device must be an available iPhone SE (3rd generation)')
    matching_runtimes = [item for item in runtimes.get('runtimes', []) if item.get('identifier') == runtime_id]
    if len(matching_runtimes) != 1:
        raise ValueError('The selected simulator runtime must have one matching runtime record')
    runtime = matching_runtimes[0]
    identifier = re.fullmatch(r'com\.apple\.CoreSimulator\.SimRuntime\.iOS-(\d+)(?:-\d+)*', runtime_id)
    version = re.fullmatch(r'(\d+)(?:\.\d+)*', runtime.get('version', ''))
    if (runtime.get('isAvailable') is not True or identifier is None or version is None
            or int(version[1]) < 18 or version[1] != identifier[1]):
        raise ValueError('The selected device requires an available iOS 18-or-later runtime')
    return dict(udid=device['udid'], name=device.get('name'), device_type=DEVICE_TYPE,
                runtime=runtime_id, runtime_version=runtime['version'],
                expected_portrait_points=[375, 667])


def test_command(device_id: str, bundle: Path) -> list[str]:
    if UUID.fullmatch(device_id) is None:
        raise ValueError('Invalid simulator UUID')
    return ['xcodebuild', 'test-without-building', '-project', 'ios/Timbre.xcodeproj',
            '-scheme', 'Timbre', '-parallel-testing-enabled', 'NO',
            '-only-testing:TimbreUITests/' + CLASS, '-test-iterations', '1',
            '-test-timeouts-enabled', 'YES', '-default-test-execution-time-allowance', '180',
            '-maximum-test-execution-time-allowance', '180', '-destination-timeout', '120',
            '-destination', f'platform=iOS Simulator,id={device_id}',
            '-derivedDataPath', 'ios/build/dd', '-resultBundlePath', str(bundle),
            'CODE_SIGNING_ALLOWED=NO']


def evaluate_tests(code: int, text: str) -> dict:
    events = [(f"{m['module']}/{m['cls']}/{m['test']}", m['state']) for m in CASE.finditer(text)]
    seen = {name for name, _ in events}
    counts = {name: Counter(state for case, state in events if case == name) for name in seen}
    unexpected = sorted(seen - EXPECTED)
    missing = sorted(name for name in EXPECTED if counts.get(name, {}).get('passed', 0) == 0)
    invalid = sorted(name for name in seen if counts[name] != Counter(started=1, passed=1)
                     or [state for case, state in events if case == name] != ['started', 'passed'])
    # A failure followed by a pass is never repaired here, even if xcodebuild exits zero.
    failure_markers = bool(re.search(r'\*\* TEST (?:EXECUTE )?FAILED \*\*|Testing failed:|'
                                    r'\berror: -\[|XCTAssert\w* failed|\bfailed - ', text))
    skipped_summary = any(int(match[1]) > 0 for match in re.finditer(r'\b(\d+) tests? skipped\b', text))
    passed = code == 0 and not (unexpected or missing or invalid or failure_markers or skipped_summary)
    return dict(passed=passed, exit_code=code, expected=sorted(EXPECTED),
                missing=missing, unexpected=unexpected, invalid=invalid,
                failure_markers=failure_markers, skipped_summary=skipped_summary,
                events=[dict(test=name, state=state) for name, state in events])


def logged_command(command: list[str], log: Path, root: Path, timeout: int) -> int:
    print('Running: ' + ' '.join(command), flush=True)
    with log.open('w') as output:
        try:
            return subprocess.run(command, cwd=root, stdout=output, stderr=subprocess.STDOUT,
                                  timeout=timeout, check=False).returncode
        except subprocess.TimeoutExpired:
            return 124
        except OSError as error:
            output.write(str(error) + '\n')
            return 127


def export_inventory(directory: Path) -> list[dict]:
    manifest = directory / 'manifest.json'
    if not manifest.is_file() or not isinstance(json.loads(manifest.read_text()), list):
        raise ValueError('Native attachment export did not produce its original JSON manifest')
    files = [path for path in directory.rglob('*') if path.is_file()]
    if len(files) < 2:
        raise ValueError('Native attachment export contains no attachment files')
    return [dict(path=path.relative_to(directory).as_posix(), bytes=path.stat().st_size,
                 sha256=hashlib.sha256(path.read_bytes()).hexdigest()) for path in sorted(files)]


def validate_export_coverage(directory: Path, device_id: str) -> list[str]:
    """Require every real layout phase's original screenshot, hierarchy and geometry."""
    manifest = json.loads((directory / 'manifest.json').read_text())
    problems = []
    for method in METHODS:
        sample = ('en' if 'English' in method else 'ar') + '-' + (
            'landscape' if 'Landscape' in method else 'portrait') + '-' + ('AX5' if 'AX5' in method else 'Large')
        blocks = [block for block in manifest if block.get('testIdentifier', '').removesuffix('()').endswith(
            f'{CLASS}/{method}')]
        attachments = [attachment for block in blocks for attachment in block.get('attachments', [])]
        for phase in PHASES:
            prefix = f'tunecheck-compact-{sample}-{phase}'
            found = set()
            for attachment in attachments:
                name = attachment.get('suggestedHumanReadableName', '')
                if not name.startswith(prefix):
                    continue
                exported = attachment.get('exportedFileName', '')
                if not exported or Path(exported).name != exported:
                    problems.append(f'{method}/{phase}: invalid native export filename')
                    continue
                path = directory / exported
                if not path.is_file() or path.stat().st_size == 0:
                    problems.append(f'{method}/{phase}: missing or empty original {exported}')
                    continue
                if attachment.get('deviceId', '').lower() != device_id.lower():
                    problems.append(f'{method}/{phase}: attachment belongs to a different or unknown device')
                    continue
                suffix = path.suffix.lower()
                if suffix == '.png' and not name.startswith(prefix + '-hierarchy'):
                    found.add('screenshot')
                elif suffix == '.txt' and name.startswith(prefix + '-hierarchy'):
                    found.add('hierarchy')
                elif suffix == '.json' and name.startswith(prefix + '-geometry'):
                    geometry = json.loads(path.read_text())
                    if geometry.get('sample') == sample and geometry.get('phase') == phase:
                        found.add('geometry')
            for missing in sorted({'screenshot', 'hierarchy', 'geometry'} - found):
                problems.append(f'{method}/{phase}: missing original {missing}')
    return problems


def write_status(directory: Path, receipt: dict) -> None:
    (directory / 'status.json').write_text(json.dumps(receipt, indent=2) + '\n')


def run(root: Path, output: Path, device_id: str) -> int:
    # Never mix this attempt with a previous bundle, passing log, or exported attachment.
    output.mkdir(parents=True, exist_ok=False)
    receipt = dict(schema=1, passed=False, state='preflight', expected=sorted(EXPECTED),
                   requested_device=device_id, attempts=0, issues=[])
    write_status(output, receipt)
    bundle = output / 'TuneCheckLayout.xcresult'
    try:
        validate_source((root / f'ios/TimbreUITests/{CLASS}.swift').read_text())
        for name, command in [
            ('devices', ['xcrun', 'simctl', 'list', 'devices', 'available', '--json']),
            ('runtimes', ['xcrun', 'simctl', 'list', 'runtimes', '--json']),
        ]:
            code = logged_command(command, output / f'{name}.json', root, 60)
            if code != 0:
                raise RuntimeError(f'simctl {name} failed with exit {code}')
        receipt['device'] = validate_device(json.loads((output / 'devices.json').read_text()),
                                            json.loads((output / 'runtimes.json').read_text()), device_id)
        command = test_command(receipt['device']['udid'], bundle)
        receipt.update(state='testing', attempts=1, command=command)
        write_status(output, receipt)
        code = logged_command(command, output / 'test.log', root, 2400)
        receipt['tests'] = evaluate_tests(code, (output / 'test.log').read_text(errors='replace'))
        receipt['state'] = 'exporting'
        write_status(output, receipt)
        if not bundle.is_dir():
            raise RuntimeError('xcodebuild did not preserve the expected native result bundle')
        export_code = logged_command(
            ['xcrun', 'xcresulttool', 'export', 'attachments', '--path', str(bundle),
             '--output-path', str(output / 'attachments')], output / 'export.log', root, 300)
        receipt['export_exit'] = export_code
        if export_code != 0:
            raise RuntimeError(f'Native attachment export failed with exit {export_code}')
        receipt['original_exports'] = export_inventory(output / 'attachments')
        receipt['evidence_issues'] = validate_export_coverage(output / 'attachments', receipt['device']['udid'])
        receipt['passed'] = receipt['tests']['passed'] and not receipt['evidence_issues']
        receipt['state'] = 'complete'
    except Exception as error:
        receipt['issues'].append(f'{type(error).__name__}: {error}')
        receipt.update(passed=False, state='failed')
    write_status(output, receipt)
    print(json.dumps(receipt), flush=True)
    return 0 if receipt['passed'] else 1


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--device-id', required=True, help='Existing compact SE3 simulator UUID; no fallback')
    parser.add_argument('--repo', type=Path, default=ROOT, help='Repository with already-built UI tests')
    parser.add_argument('--output', type=Path, help='Fresh evidence directory (must not exist)')
    args = parser.parse_args(argv)
    root = args.repo.resolve()
    output = (args.output or root / 'ci-out/tunecheck-layout').resolve()
    try:
        return run(root, output, args.device_id)
    except FileExistsError:
        print(f'Refusing existing evidence directory: {output}', file=sys.stderr)
        return 1


if __name__ == '__main__':
    sys.exit(main())
