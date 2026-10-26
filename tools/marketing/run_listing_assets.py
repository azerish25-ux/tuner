#!/usr/bin/env python3
"""Run isolated localized captures from one unsigned simulator build artifact.

Only call on a macOS CI runner. Each locale gets fresh output directories and its
own retained failed attempts; successful retries never overwrite failure evidence.
"""
from __future__ import annotations

import argparse
import json
import os
import platform
import re
import shutil
import subprocess
import sys
import time
from pathlib import Path

import listing_assets as assets

ROOT = assets.ROOT
BUNDLE_ID = 'com.shahradazerisharghi.timbre'
PYTHON = sys.executable


def run(command, *, log=None, env=None, check=True):
    """No shell parsing, and preserve the actual command's exit status."""
    print('+ ' + ' '.join(map(str, command)), flush=True)
    if log:
        log.parent.mkdir(parents=True, exist_ok=True)
        with log.open('w') as handle:
            result = subprocess.run(list(map(str, command)), cwd=ROOT, env=env, stdout=handle, stderr=subprocess.STDOUT)
        # Keep complete logs in artifacts, short tails in the Actions console.
        print('\n'.join(log.read_text(errors='replace').splitlines()[-30:]), flush=True)
    else:
        result = subprocess.run(list(map(str, command)), cwd=ROOT, env=env)
    if check and result.returncode:
        raise RuntimeError(f'Command failed ({result.returncode}): {command[0]}; log: {log}')
    return result.returncode


def output(command):
    return subprocess.check_output(command, cwd=ROOT, text=True).strip()


def choose_device(kind):
    listing = json.loads(output(['xcrun', 'simctl', 'list', 'devices', 'available', '-j']))['devices']
    version = lambda x: tuple(map(int, re.findall(r'\d+', x)))
    for runtime, devices in sorted(listing.items(), key=lambda pair: version(pair[0]), reverse=True):
        if 'iOS' not in runtime:
            continue
        if kind == 'ipad':
            candidates = [d for d in devices if 'iPad Pro' in d['name'] and re.search(r'\b13[- ]inch\b', d['name'])]
        else:
            # These are the 1320x2868 capture devices used by the existing renderer.
            candidates = [d for d in devices if d['name'] in ('iPhone 17 Pro Max', 'iPhone 16 Pro Max')]
        if candidates:
            best = max(candidates, key=lambda d: version(d['name']))
            return {'id': best['udid'], 'name': best['name'], 'runtime': runtime}
    raise RuntimeError(f'No exact supported {kind} simulator; do not substitute an arbitrary device size')


def boot(device, kind):
    udid = device['id']
    run(['xcrun', 'simctl', 'boot', udid], check=False)
    run(['xcrun', 'simctl', 'bootstatus', udid, '-b'])
    if kind == 'ipad':
        keys = ['SBMedusaMultitaskingEnabled', 'SBChamoisWindowingEnabled']
        for key in keys:
            run(['xcrun', 'simctl', 'spawn', udid, 'defaults', 'write', 'com.apple.springboard', key, '-bool', 'NO'])
        time.sleep(2)
        run(['xcrun', 'simctl', 'shutdown', udid])
        run(['xcrun', 'simctl', 'boot', udid])
        run(['xcrun', 'simctl', 'bootstatus', udid, '-b'])
        for key in keys:
            if output(['xcrun', 'simctl', 'spawn', udid, 'defaults', 'read', 'com.apple.springboard', key]) != '0':
                raise RuntimeError('iPad full-screen preference did not persist; do not certify windowed captures')
        # Unlike the old nightly workflow, never quietly fall back to windowed apps.
        launched = False
        for _ in range(6):
            if run(['xcrun', 'simctl', 'launch', udid, 'com.apple.Preferences'], check=False) == 0:
                launched = True
                break
            time.sleep(10)
        if not launched:
            raise RuntimeError('iPad full-screen mode did not launch apps')
        run(['xcrun', 'simctl', 'terminate', udid, 'com.apple.Preferences'])
    run(['xcrun', 'simctl', 'status_bar', udid, 'override', '--time', '9:41',
         '--dataNetwork', 'wifi', '--wifiMode', 'active', '--wifiBars', '3',
         '--cellularMode', 'active', '--cellularBars', '4', '--batteryState', 'charged', '--batteryLevel', '100'])


def environment(spec):
    env = os.environ.copy()
    for key, value in {
        'TIMBRE_UI_LANGUAGE': spec['app_language'],
        'TIMBRE_UI_LOCALE': spec['apple_locale'],
        'TIMBRE_UI_APPLE_LANGUAGES': ','.join(spec['apple_languages']),
        'TIMBRE_LISTING_LOCALE': spec['listing_locale'],
    }.items():
        env['TEST_RUNNER_' + key] = value
    return env


def test_command(xctestrun, device, tests, bundle):
    return ['xcodebuild', 'test-without-building', '-xctestrun', xctestrun,
            '-destination', 'platform=iOS Simulator,id=' + device['id'],
            '-parallel-testing-enabled', 'NO', '-resultBundlePath', bundle,
            *['-only-testing:' + test for test in tests], 'CODE_SIGNING_ALLOWED=NO']


def export_attachments(bundle, folder):
    if not bundle.is_dir():
        raise RuntimeError(f'Missing result bundle: {bundle}')
    run(['xcrun', 'xcresulttool', 'export', 'attachments', '--path', bundle, '--output-path', folder])


def launch_only_failure(log):
    sys.path.insert(0, str(ROOT / 'tools/ci'))
    import launch_retry
    retry, other = launch_retry.classify(log.read_text(errors='replace'))
    return bool(retry) and not other


def tested_selectors(log: Path, selected: list[str]):
    """A green zero-test/skip run is not capture evidence."""
    text = log.read_text(errors='replace')
    for selector in selected:
        target, cls, method = selector.split('/')
        pattern = rf"Test Case '-\[{re.escape(target)}\.{re.escape(cls)} {re.escape(method)}\]' passed"
        if not re.search(pattern, text):
            raise RuntimeError(f'No executed passing test: {selector}')


def test_attempts(xctestrun, device, kind, tests, out, env):
    for attempt in (1, 2):
        folder = out / f'attempt-{attempt}'
        folder.mkdir(parents=True, exist_ok=False)
        bundle, log = folder / 'Tests.xcresult', folder / 'test.log'
        code = run(test_command(xctestrun, device, tests, bundle), log=log, env=env, check=False)
        if bundle.exists():
            export_attachments(bundle, folder / 'attachments')
        if code == 0:
            tested_selectors(log, tests)
            return folder
        if attempt == 1 and launch_only_failure(log):
            run(['xcrun', 'simctl', 'shutdown', device['id']], check=False)
            boot(device, kind)
            continue
        raise RuntimeError(f'UI tests failed; retained {folder}')
    raise RuntimeError('No passing test attempt')


def validate_preview_take(folder, kind):
    """Do not let the legacy renderer turn a partial tour into a plausible trim."""
    import preview
    import screenshots
    text = (folder / 'test.log').read_text(errors='replace')
    marks = preview.read_marks([text])
    cut = 'violin' if kind == 'preview-violin' else 'guitar'
    names = ['lock', 'tuned'] + ([] if cut == 'violin' else ['showme']) + ['highway', 'results', 'songs']
    if not marks or marks['result'] != 'passed' or marks['cut'] != cut:
        raise RuntimeError('Preview has no passing, correctly identified tour')
    if [row[0] for row in marks['clips']] != names:
        raise RuntimeError('Preview has missing, duplicate or out-of-order clips')
    if marks['missed']:
        raise RuntimeError('Preview tour missed moments: ' + '; '.join(marks['missed']))
    if not marks['beat'] or not marks['card'] or marks['poster'] is None or 'readout' not in marks['regions']:
        raise RuntimeError('Preview is missing beat/card/poster/readout evidence')
    expected_syncs = ['tuner', 'lock', 'lock-held', 'tuned'] + ([] if cut == 'violin' else ['showme-ready', 'showme'])
    expected_syncs += ['highway', 'highway-2', 'results', 'songs-ready', 'songs']
    if [row[0] for row in marks['syncs']] != expected_syncs:
        raise RuntimeError('Preview has missing or duplicate synchronization moments')
    found = screenshots.attachments(folder / 'attachments')
    used = set()
    for name in expected_syncs:
        images = found.get('sync-' + name, [])
        if len(images) != 1 or not images[0].is_file() or images[0].resolve() in used:
            raise RuntimeError(f'Missing, duplicate or reused preview sync image: {name}')
        if not images[0].resolve().is_relative_to((folder / 'attachments').resolve()):
            raise RuntimeError('Out-of-folder preview attachment')
        used.add(images[0].resolve())
    recording = assets.read_json(folder / 'record.json')
    raw = preview.probe(folder / 'raw.mp4')
    video = next(stream for stream in raw['streams'] if stream['codec_type'] == 'video')
    if (int(video['width']), int(video['height'])) != (1320, 2868):
        raise RuntimeError('Preview raw recording has the wrong capture-device dimensions')
    events = [json.loads(line) for line in (folder / 'app/events.jsonl').read_text().splitlines() if line.strip()]
    times = [event['t'] for event in events if isinstance(event.get('t'), (int, float))]
    if not times or min(times) < recording['started'] - 3 or max(times) > recording['stopped'] + 3:
        raise RuntimeError('App audio events are absent or belong to another take')
    return marks


def semantic_preview_audio(folder, kind, locale, marks):
    """Keep the band gates even when the displayed caption does not say English 'band'."""
    import gates
    import preview
    import soundtrack
    cut = 'violin' if kind == 'preview-violin' else 'guitar'
    layout = assets.read_json(folder / 'cut.json')
    names = [row[0] for row in marks['clips']] + ['end card']
    if [section['name'] for section in layout['sections']] != names:
        raise RuntimeError('Rendered preview omitted, repeated or reordered a clip')
    localized = preview.captions(cut, locale)
    source = preview.captions(cut, 'en-US')
    sections = []
    for row in layout['sections']:
        name = row['name']
        if name != 'end card' and row.get('caption') != localized[name][0]:
            raise RuntimeError(f'Wrong localized caption in rendered preview: {name}')
        # Semantic obligation is attached to the highway scene, not a translated word.
        caption = 'band' if name == 'highway' else source.get(name, ('', ''))[0]
        sections.append(gates.Section(name, row['start'], row['end'], caption))
    lines, silence, bandless = gates.sound_report(folder / 'preview.mp4', sections)
    app_audio = soundtrack.AppAudio(folder / 'app')
    for name, start, end, *_ in marks['clips']:
        if name == 'highway' and app_audio.band_playing(start, end) is not True:
            bandless.append('highway: app band events do not prove playback through the recorded clip')
    result = {'scope': 'Source-clip semantic band obligations, independent of caption language',
              'passed': not silence and not bandless, 'retryable': bool(bandless) and not silence,
              'lines': lines, 'errors': silence + bandless,
              'event_ledger_sha256': assets.digest(folder / 'app/events.jsonl')}
    assets.write_json(folder / 'semantic-audio-check.json', result)
    return result['passed']


def preview_attempts(xctestrun, device, kind, out, env):
    tests = assets.selectors(kind)
    for attempt in (1, 2, 3):
        folder = out / f'attempt-{attempt}'
        folder.mkdir(parents=True, exist_ok=False)
        handshake = (folder / 'handshake').resolve()
        log, bundle = folder / 'test.log', folder / 'Tests.xcresult'
        log.touch()
        recorder_log = (folder / 'recorder-launch.log').open('w')
        waiter = subprocess.Popen([PYTHON, 'tools/marketing/preview.py', 'record', '--device', device['id'],
                                   '--out', str(folder), '--handshake', str(handshake), '--log', str(log)],
                                  cwd=ROOT, stdout=recorder_log, stderr=subprocess.STDOUT)
        take_env = dict(env, TEST_RUNNER_PREVIEW_HANDSHAKE=str(handshake))
        try:
            code = run(test_command(xctestrun, device, tests, bundle), log=log, env=take_env, check=False)
        finally:
            if waiter.poll() is None:
                waiter.terminate()
            try:
                waiter.wait(timeout=30)
            except subprocess.TimeoutExpired:
                waiter.kill()
                waiter.wait(timeout=10)
            finally:
                recorder_log.close()
                stop = run([PYTHON, 'tools/marketing/preview.py', 'stop', '--out', folder],
                           log=folder / 'stop.log', check=False)
        if bundle.exists():
            export_attachments(bundle, folder / 'attachments')
        if code:
            if attempt == 1 and launch_only_failure(log):
                run(['xcrun', 'simctl', 'shutdown', device['id']], check=False)
                boot(device, 'iphone')
                continue
            raise RuntimeError(f'Preview UI test failed; retained {folder}')
        tested_selectors(log, tests)
        if stop or not (folder / 'record.json').is_file() or not (folder / 'raw.mp4').is_file():
            raise RuntimeError('Preview recorder did not finish a nonempty recording')
        audio_source = handshake / 'app'
        if not (audio_source / 'events.jsonl').is_file():
            container = output(['xcrun', 'simctl', 'get_app_container', device['id'], BUNDLE_ID, 'data'])
            audio_source = Path(container) / 'Library/Caches/preview-audio'
        if not (audio_source / 'events.jsonl').is_file():
            raise RuntimeError('No app-generated audio event ledger from this preview take')
        shutil.copytree(audio_source, folder / 'app')
        marks = validate_preview_take(folder, kind)
        # Rejected captures never get relabeled by merely changing translated captions.
        spec = assets.locale_spec(env['TEST_RUNNER_TIMBRE_LISTING_LOCALE'])
        assets.validate_language_evidence(spec, log.read_text(errors='replace'), 'LAUNCH', minimum=4 if kind == 'preview-main' else 3)
        cut = run([PYTHON, 'tools/marketing/preview.py', 'render', '--out', folder,
                   '--log', log, '--attachments', folder / 'attachments', '--audio', folder / 'app',
                   '--locale', spec['listing_locale']], log=folder / 'render.log', check=False)
        if cut in (3, 4) and attempt < 3:
            # Existing renderer retake policy only, never retry translation/assertion failures.
            continue
        if cut:
            raise RuntimeError(f'Preview gates failed ({cut}); retained {folder}')
        run([PYTHON, 'tools/marketing/preview.py', 'check', '--out', folder], log=folder / 'audio-check.log')
        report = (folder / 'PREVIEW.txt').read_text()
        if 'NOT FOR UPLOAD:' in report or 'Meets the App Preview spec and its gates.' not in report:
            raise RuntimeError('Preview gate report did not explicitly pass')
        if assets.read_json(folder / 'cut.json')['cut'] != ('violin' if kind == 'preview-violin' else 'guitar'):
            raise RuntimeError('Wrong preview cut')
        if not semantic_preview_audio(folder, kind, spec['listing_locale'], marks):
            if assets.read_json(folder / 'semantic-audio-check.json')['retryable'] and attempt < 3:
                continue  # The same band-missing retake class as the English renderer's exit 4.
            raise RuntimeError(f'Semantic preview band/audio gates failed; retained {folder}')
        return folder
    raise RuntimeError('No valid preview take')


def preview_records(folder, base):
    required = ['preview.mp4', 'poster.png', 'contact.png', 'PREVIEW.txt', 'cut.json',
                'raw.mp4', 'record.json', 'app/events.jsonl', 'audio-check.log', 'semantic-audio-check.json']
    records = []
    for name in required:
        path = folder / name
        if not path.is_file() or path.stat().st_size == 0:
            raise RuntimeError(f'Missing preview evidence: {path}')
        record = {'path': str(path.relative_to(base)), 'sha256': assets.digest(path), 'bytes': path.stat().st_size}
        if path.suffix == '.png':
            record.update(assets.image_record(path, base))
        records.append(record)
    return records


def run_locale(locale, args, device, xctestrun, build_hash):
    spec = assets.locale_spec(locale)
    base = args.out / locale / args.kind
    base.mkdir(parents=True, exist_ok=False)
    env = environment(spec)
    manifest = {'schema_version': 1, **spec, 'kind': args.kind, 'source_sha': args.source_sha,
                'build_sha256': build_hash, 'device': device, 'status': 'running',
                'release_ready': False, 'visual_review': 'pending', 'native_review': 'pending',
                'scope': 'Default listing assets' if args.kind != 'preview-violin' else 'Supplemental violin CPP preview only; not a complete CPP asset set'}
    manifest_file = args.manifests / f'{locale}-{args.kind}.manifest.json'
    assets.write_json(manifest_file, manifest)
    try:
        if spec['lesson_resource_status'] != 'shipped':
            raise RuntimeError(f'{spec["app_language"]}: localized Learn.strings is not shipped; do not frame English lesson fallback as localized assets')
        verified = test_attempts(xctestrun, device, args.kind, [assets.EVIDENCE_TEST], base / 'language-check', env)
        manifest['language_evidence'] = assets.validate_language_evidence(spec, (verified / 'test.log').read_text(errors='replace'), 'VERIFIED')
        if args.kind in ('iphone', 'ipad'):
            selected = assets.selectors(args.kind)
            result = test_attempts(xctestrun, device, args.kind, selected, base / 'capture', env)
            manifest['launch_evidence'] = assets.validate_language_evidence(spec, (result / 'test.log').read_text(errors='replace'), 'LAUNCH', minimum=len(selected))
            manifest['captures'] = assets.capture_records(result / 'attachments', locale, args.kind, base)
            rendered = base / 'rendered'
            command = [PYTHON, 'tools/marketing/screenshots.py', result / 'attachments', rendered, '--locale', locale]
            if args.kind == 'ipad':
                command.append('--ipad')
            run(command, log=base / 'render.log', env=env)
            manifest['assets'] = assets.screenshot_records(rendered, locale, args.kind, base)
        else:
            result = preview_attempts(xctestrun, device, args.kind, base / 'preview', env)
            manifest['launch_evidence'] = assets.validate_language_evidence(spec, (result / 'test.log').read_text(errors='replace'), 'LAUNCH', minimum=4 if args.kind == 'preview-main' else 3)
            manifest['assets'] = preview_records(result, base)
        manifest['selected_attempt'] = str(result.relative_to(base))
        manifest['status'] = 'mechanically_verified'
        return True
    except (ValueError, RuntimeError, OSError, subprocess.SubprocessError) as error:
        manifest['status'], manifest['error'] = 'failed', str(error)
        print(f'::error::{locale}/{args.kind}: {error}', flush=True)
        return False
    finally:
        assets.write_json(manifest_file, manifest)
        assets.write_json(base / 'manifest.json', manifest)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--locales', required=True)
    parser.add_argument('--kind', choices=assets.KINDS, required=True)
    parser.add_argument('--products', type=Path, required=True)
    parser.add_argument('--build-archive', type=Path, required=True)
    parser.add_argument('--build-info', type=Path, required=True)
    parser.add_argument('--source-sha', required=True)
    parser.add_argument('--out', type=Path, required=True)
    parser.add_argument('--manifests', type=Path, required=True)
    args = parser.parse_args()
    if platform.system() != 'Darwin':
        raise SystemExit('Native captures require a macOS/Xcode runner')
    selected = assets.select_locales(args.locales)
    if len(selected) > 3:
        raise SystemExit('A worker accepts at most three locales; use the bounded matrix')
    args.out = args.out.resolve()
    args.manifests = args.manifests.resolve()
    if args.out.exists() and any(args.out.iterdir()):
        raise SystemExit('Refusing to mix a new run into previous capture output')
    build_hash = assets.digest(args.build_archive)
    info = assets.read_json(args.build_info)
    if info['source_sha'] != args.source_sha or info['archive_sha256'] != build_hash:
        raise SystemExit('Shared build provenance does not match this source revision/archive')
    if info['xcode_version'] != output(['xcodebuild', '-version']) or info['machine'] != platform.machine():
        raise SystemExit('Shared build and worker Xcode/architecture differ')
    runs = list(args.products.glob('*.xctestrun'))
    if len(runs) != 1:
        raise SystemExit(f'Expected exactly one shared xctestrun file, got {len(runs)}')
    device = choose_device(args.kind)
    assets.write_json(args.out / 'device.json', device)
    boot(device, args.kind)
    passed = [run_locale(locale, args, device, runs[0].resolve(), build_hash) for locale in selected]
    return 0 if all(passed) else 1


if __name__ == '__main__':
    raise SystemExit(main())
