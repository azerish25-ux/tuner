#!/usr/bin/env python3
"""Capture genuine localized watchOS app pages with public simulator tools; never manufactures media."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import struct
import subprocess
import sys
import time
import uuid
import zlib

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / 'tools/l10n'))
import report

BUNDLE = 'com.shahradazerisharghi.timbre.watchkitapp'
SIZE = [416, 496]
PAGES = ('today', 'metronome')
LABEL_KEYS = {
    'today': {'streak': 'day streak', 'practiced': 'Practised today', 'today': 'Today'},
    'metronome': {'title': 'Metronome', 'tempo': 'Andante', 'tap': 'Tap', 'stop': 'Stop', 'meter': 'Meter'},
}


def expectations():
    result = {}
    for language in ['en'] + report.locales():
        table = report.read_strings(report.RES / f'{language}.lproj/Localizable.strings')
        pages = {}
        for page, keys in LABEL_KEYS.items():
            pages[page] = {}
            for field, key in keys.items():
                value = table.get(key, key if language == 'en' else None)
                if not value or not value.strip():
                    raise ValueError(f'{language}: missing applied Watch label {key}')
                pages[page][field] = value
        result[language] = pages
    if len(result) != 49:
        raise ValueError('Watch capture scope must contain all49app languages')
    return result


def store_mappings(languages, image_format='png'):
    suffix = 'png' if image_format == 'png' else 'jpg'
    inventory = json.loads((ROOT / 'tools/l10n/store-locales.json').read_text(encoding='utf-8'))
    rows = []
    for row in inventory['locales']:
        language = row['app_locale'] or row['app_fallback']
        if language not in languages:
            raise ValueError(f"No Watch captures for store locale {row['locale']}: {language}")
        rows.append({'store_locale': row['locale'], 'app_locale': row['app_locale'],
                     'capture_language': language,
                     'mapping': 'supported_app_language' if row['app_locale'] else 'explicit_english_fallback',
                     'screenshots': [f'{language}/{page}.{suffix}' for page in PAGES],
                     'translated_app_ui': row['app_locale'] is not None})
    if len(rows) != 50 or len({row['store_locale'] for row in rows}) != 50:
        raise ValueError('Store inventory must contain50distinct locales')
    return rows


def jpeg_size(path):
    """Read native JPEG SOF dimensions; the capture runner additionally decodes with macOS sips."""
    try:
        data = path.read_bytes()
    except OSError as error:
        raise ValueError(f'Missing screenshot: {path}') from error
    if not data.startswith(b'\xff\xd8') or not data.endswith(b'\xff\xd9'):
        raise ValueError(f'Invalid JPEG screenshot: {path}')
    offset = 2
    while offset + 4 <= len(data):
        if data[offset] != 255:
            raise ValueError(f'Invalid JPEG marker: {path}')
        marker = data[offset + 1]
        length = struct.unpack('>H', data[offset + 2:offset + 4])[0]
        if length < 2 or offset + 2 + length > len(data):
            raise ValueError(f'Truncated JPEG screenshot: {path}')
        if marker in (0xC0, 0xC1, 0xC2):
            if length < 8:
                break
            height, width = struct.unpack('>HH', data[offset + 5:offset + 9])
            return [width, height]
        offset += 2 + length
    raise ValueError(f'No JPEG dimensions: {path}')


def screenshot_format(help_text):
    black = '--mask' in help_text and 'black' in help_text
    png = '--type' in help_text and 'png' in help_text and black
    return {'type': 'png' if png else 'jpeg', 'black_mask': black,
            'reason': 'public native PNG and black mask supported' if png else 'public PNG/black-mask capability not found; native JPEG fallback'}


def validate_format_evidence(directory, manifest):
    path = directory / 'simctl-io-help.txt'
    mode = screenshot_format(path.read_text(encoding='utf-8'))
    if (hashlib.sha256(path.read_bytes()).hexdigest() != manifest.get('simctl_help_sha256')
            or mode != manifest.get('format_selection') or mode['type'] != manifest.get('format')):
        raise ValueError('Manifest format does not match recorded public simulator capabilities')


def png_info(path):
    """Verify lossless native PNG chunks, decoded scanlines and actual pixel opacity without rewriting it."""
    data = path.read_bytes()
    if not data.startswith(b'\x89PNG\r\n\x1a\n'):
        raise ValueError('Invalid PNG signature')
    offset, compressed, header, ended = 8, bytearray(), None, False
    while offset + 12 <= len(data):
        size = struct.unpack('>I', data[offset:offset + 4])[0]
        kind, payload = data[offset + 4:offset + 8], data[offset + 8:offset + 8 + size]
        end = offset + 12 + size
        if end > len(data) or zlib.crc32(kind + payload) != struct.unpack('>I', data[end - 4:end])[0]:
            raise ValueError('PNG chunk CRC or length mismatch')
        if kind == b'IHDR':
            if header is not None or len(payload) != 13:
                raise ValueError('Invalid PNG header')
            header = struct.unpack('>IIBBBBB', payload)
        elif kind == b'IDAT':
            compressed.extend(payload)
        elif kind == b'tRNS':
            raise ValueError('PNG must have opaque pixels without color-key transparency')
        elif kind == b'IEND':
            ended = end == len(data)
            break
        offset = end
    if not ended or header is None:
        raise ValueError('Incomplete PNG')
    width, height, depth, color, compression, filtering, interlace = header
    if [width, height] != SIZE:
        raise ValueError(f'Unsupported PNG dimensions: {[width, height]}')
    channels = {0: 1, 2: 3, 4: 2, 6: 4}.get(color)
    if depth != 8 or not channels or any((compression, filtering, interlace)):
        raise ValueError('Unsupported native PNG encoding')
    stride = width * channels
    decoder = zlib.decompressobj()
    pixels = decoder.decompress(bytes(compressed), (stride + 1) * height + 1)
    if len(pixels) != (stride + 1) * height or not decoder.eof or decoder.unused_data:
        raise ValueError('PNG pixel payload is corrupt or truncated')
    previous = bytearray(stride)
    for row in range(height):
        start = row * (stride + 1)
        method = pixels[start]
        line = bytearray(pixels[start + 1:start + 1 + stride])
        if method not in range(5):
            raise ValueError('Invalid PNG row filter')
        for index in range(stride):
            left = line[index - channels] if index >= channels else 0
            up = previous[index]
            corner = previous[index - channels] if index >= channels else 0
            if method == 1:
                predictor = left
            elif method == 2:
                predictor = up
            elif method == 3:
                predictor = (left + up) // 2
            elif method == 4:
                prediction = left + up - corner
                predictor = min((left, up, corner), key=lambda value: abs(prediction - value))
            else:
                predictor = 0
            line[index] = (line[index] + predictor) & 255
        if color in (4, 6) and any(alpha != 255 for alpha in line[channels - 1::channels]):
            raise ValueError('PNG must have opaque pixels')
        previous = line
    return {'format': 'png', 'dimensions': [width, height], 'alphaChannel': color in (4, 6), 'opaquePixels': True}


def normalized_language(value):
    if value in ('zh-CN', 'zh-Hans', 'zh-Hans-CN'):
        return 'zh-CN'
    return value.replace('_', '-').split('-')[0]


def validate_probe(probe, row, expected, revision):
    for field, value in [('schema', 1), ('revision', revision), ('token', row['token']),
                         ('page', row['page']), ('requestedLanguage', row['language'])]:
        if probe.get(field) != value:
            raise ValueError(f"{row['language']}/{row['page']}: wrong probe {field}")
    if normalized_language(probe.get('effectiveLanguage', '')) != normalized_language(row['language']):
        raise ValueError('Wrong effective Watch language')
    if probe.get('labels') != expected[row['language']][row['page']]:
        raise ValueError('Watch label probe differs from applied translations')
    if probe.get('nativePixels') != SIZE:
        raise ValueError('Watch native pixels do not match selected media size')
    if row['page'] == 'today':
        if not (probe.get('streak', 0) > 0 and probe.get('practicedToday') is True
                and 0 < probe.get('done', 0) < probe.get('total', 0)):
            raise ValueError('Today must show a lit streak and part-done set')
    elif not (probe.get('running') is True and probe.get('pulse', 0) > 0):
        raise ValueError('Metronome must be genuinely running')


def validate_capture(directory, row, expected, revision):
    if row.get('language') not in expected or row.get('page') not in PAGES or not row.get('token'):
        raise ValueError('Unknown Watch capture language/page/token')
    path = (directory / row['file']).resolve()
    if not path.is_relative_to(directory.resolve()):
        raise ValueError('Screenshot outside capture directory')
    if row['file'] not in (f"{row['language']}/{row['page']}.jpg", f"{row['language']}/{row['page']}.png"):
        raise ValueError('Unexpected capture filename')
    info = png_info(path) if path.suffix == '.png' else {'format': 'jpeg', 'dimensions': jpeg_size(path), 'alphaChannel': False, 'opaquePixels': True}
    if info['dimensions'] != SIZE:
        raise ValueError(f"Unsupported or inconsistent dimensions: {info['dimensions']}, expected{SIZE}")
    for name in ('before', 'after'):
        validate_probe(row[name], row, expected, revision)
    if not (row['before'].get('observedAt', 0) <= row.get('screenshotStartedAt', 0)
            <= row.get('screenshotFinishedAt', 0) <= row['after'].get('observedAt', 0)
            and row.get('screenshotStartedAt', 0) > 0):
        raise ValueError('Probe time does not bracket screenshot capture time')
    return {**row, **info, 'sha256': hashlib.sha256(path.read_bytes()).hexdigest()}


def decode_native(path, directory):
    """Force a native ImageIO pixel decode; retain the untouched simulator JPEG as the deliverable."""
    decoded = directory / f'decode-check-{uuid.uuid4().hex}.bmp'
    command(['sips', '-s', 'format', 'bmp', str(path), '--out', str(decoded)])
    data = decoded.read_bytes()
    if len(data) < 54 or data[:2] != b'BM':
        raise ValueError('Native image decoder did not produce valid BMP pixels')
    width, height = struct.unpack('<ii', data[18:26])
    if [width, abs(height)] != SIZE:
        raise ValueError('Native image decode did not confirm416x496')
    decoded.unlink()


def validate_coverage(rows, languages):
    pairs = [(row['language'], row['page']) for row in rows]
    wanted = {(language, page) for language in languages for page in PAGES}
    if len(pairs) != len(set(pairs)) or set(pairs) != wanted:
        raise ValueError('Missing, extra or duplicate Watch language/page captures')


def command(args, *, timeout=120, env=None, log=None):
    if log:
        with log.open('w', encoding='utf-8') as output:
            subprocess.run(args, cwd=ROOT, check=True, timeout=timeout, env=env, stdout=output, stderr=subprocess.STDOUT)
        return ''
    return subprocess.check_output(args, cwd=ROOT, timeout=timeout, env=env, text=True).strip()


def simulator_pair():
    inventory = json.loads(command(['xcrun', 'simctl', 'list', '--json']))
    runtimes = sorted((r for r in inventory['runtimes'] if r.get('isAvailable')),
                      key=lambda r: tuple(map(int, r['version'].split('.'))), reverse=True)
    def template(platform, matches):
        for runtime in runtimes:
            if platform not in runtime['identifier']:
                continue
            for device in inventory['devices'].get(runtime['identifier'], []):
                if device.get('isAvailable') and matches(device['name']):
                    kind = next((t for t in inventory['devicetypes'] if t['name'] == device['name']), None)
                    if kind:
                        return kind, runtime
        raise ValueError(f'No available {platform} template for native416x496Watch capture')
    watch_type, watch_runtime = template('watchOS', lambda name: bool(re.fullmatch(r'Apple Watch Series (10|11|12) \(46mm\)', name)))
    phone_type, phone_runtime = template('iOS', lambda name: name.startswith('iPhone'))
    suffix = uuid.uuid4().hex[:8]
    phone = command(['xcrun', 'simctl', 'create', f'Timbre capture phone {suffix}', phone_type['identifier'], phone_runtime['identifier']])
    watch = command(['xcrun', 'simctl', 'create', f'Timbre capture watch {suffix}', watch_type['identifier'], watch_runtime['identifier']])
    command(['xcrun', 'simctl', 'pair', watch, phone])
    for device in (phone, watch):
        command(['xcrun', 'simctl', 'boot', device])
        command(['xcrun', 'simctl', 'bootstatus', device, '-b'], timeout=180)
    return watch, {'watch_udid': watch, 'phone_udid': phone, 'watch_type': watch_type,
                   'watch_runtime': watch_runtime['identifier'], 'phone_runtime': phone_runtime['identifier']}


def wait_probe(path, row, expected, revision, *, not_before=0):
    deadline = time.monotonic() + 30
    last = 'no probe file'
    while time.monotonic() < deadline:
        try:
            probe = json.loads(path.read_text(encoding='utf-8'))
            validate_probe(probe, row, expected, revision)
            if probe.get('observedAt', 0) < not_before or not 0 <= time.time() - probe.get('observedAt', 0) < 5:
                raise ValueError('Stale page-state probe')
            return probe
        except (OSError, ValueError, KeyError) as error:
            last = str(error)
        time.sleep(0.25)
    raise ValueError(f'Watch did not publish matching rendered-page probe: {last}')


def capture(directory, revision):
    if not re.fullmatch(r'[0-9a-f]{40}', revision):
        raise ValueError('Capture revision must be an exact Git SHA')
    if command(['git', 'rev-parse', 'HEAD']) != revision:
        raise ValueError('Capture revision does not match checkout HEAD')
    command(['git', 'diff', '--exit-code', 'HEAD', '--', 'ios', 'tools/ci/watch_captures.py', 'tools/l10n/store-locales.json'])
    directory.mkdir(parents=True, exist_ok=True)
    if (directory / 'manifest.json').exists():
        raise ValueError('Refuse to replace a completed capture manifest')
    expected = expectations()
    help_text = command(['xcrun', 'simctl', 'help', 'io'])
    (directory / 'simctl-io-help.txt').write_text(help_text + '\n', encoding='utf-8')
    mode = screenshot_format(help_text)
    suffix = 'png' if mode['type'] == 'png' else 'jpg'
    (directory / 'expectations.json').write_text(json.dumps(expected, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
    watch, simulator = simulator_pair()
    build = directory / 'derived-data'
    command(['xcodebuild', 'build', '-project', 'ios/Timbre.xcodeproj', '-scheme', 'TimbreWatch',
             '-configuration', 'Debug', '-destination', f'platform=watchOS Simulator,id={watch}',
             '-derivedDataPath', str(build), 'CODE_SIGNING_ALLOWED=NO'], timeout=1800, log=directory / 'build.log')
    app = build / 'Build/Products/Debug-watchsimulator/TimbreWatch.app'
    if not app.is_dir():
        raise ValueError('Built Watch application not found')
    command(['xcrun', 'simctl', 'install', watch, str(app)])
    rows = []
    for language in expected:
        for page in PAGES:
            row = {'language': language, 'page': page, 'token': str(uuid.uuid4()), 'file': f'{language}/{page}.{suffix}'}
            destination = directory / row['file']
            destination.parent.mkdir(exist_ok=True)
            environment = {**os.environ, **{f'SIMCTL_CHILD_TIMBRE_WATCH_CAPTURE_{key}': value for key, value in {
                'PAGE': page, 'LOCALE': language, 'REVISION': revision, 'TOKEN': row['token']}.items()}}
            command(['xcrun', 'simctl', 'launch', '--terminate-running-process', watch, BUNDLE,
                     '-AppleLanguages', f'({language})', '-AppleLocale', language.replace('-', '_')], env=environment)
            container = Path(command(['xcrun', 'simctl', 'get_app_container', watch, BUNDLE, 'data']))
            probe_path = container / 'Documents/watch-capture.json'
            row['before'] = wait_probe(probe_path, row, expected, revision)
            row['screenshotStartedAt'] = time.time()
            screenshot = ['xcrun', 'simctl', 'io', watch, 'screenshot', f"--type={mode['type']}"]
            if mode['black_mask']:
                screenshot.append('--mask=black')
            command(screenshot + [str(destination)])
            decode_native(destination, directory)
            row['screenshotFinishedAt'] = time.time()
            row['after'] = wait_probe(probe_path, row, expected, revision, not_before=row['screenshotFinishedAt'])
            rows.append(validate_capture(directory, row, expected, revision))
            (directory / 'partial.json').write_text(json.dumps(rows, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
    validate_coverage(rows, set(expected))
    manifest = {'schema': 1, 'revision': revision, 'dimensions': SIZE, 'format': mode['type'], 'format_selection': mode,
                'simctl_help_sha256': hashlib.sha256((directory / 'simctl-io-help.txt').read_bytes()).hexdigest(),
                'decoder': 'sips-bmp-pixel-decode', 'simulator': simulator,
                'capture_tool_sha256': hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),
                'store_inventory_sha256': hashlib.sha256((ROOT / 'tools/l10n/store-locales.json').read_bytes()).hexdigest(),
                'captures': rows, 'store_locales': store_mappings(set(expected), mode['type']),
                'upload_alpha_channel_review_required': any(row['alphaChannel'] for row in rows),
                'complication_face': {'status': 'manual_remaining', 'counted_as_captured': False},
                'limits': 'Page/state/localization probes are app instrumentation; screenshots still require visual review. No system face fabricated.'}
    (directory / 'manifest.json').write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--out', type=Path, required=True)
    parser.add_argument('--revision', required=True)
    parser.add_argument('--validate', action='store_true', help='validate completed media against current applied translations')
    args = parser.parse_args()
    directory = args.out.resolve()
    if args.validate:
        manifest = json.loads((directory / 'manifest.json').read_text(encoding='utf-8'))
        expected = expectations()
        if (manifest['revision'] != args.revision or manifest['dimensions'] != SIZE
                or manifest.get('schema') != 1 or manifest.get('format') not in ('png', 'jpeg')
                or manifest.get('capture_tool_sha256') != hashlib.sha256(Path(__file__).read_bytes()).hexdigest()
                or manifest.get('store_inventory_sha256') != hashlib.sha256((ROOT / 'tools/l10n/store-locales.json').read_bytes()).hexdigest()
                or command(['git', 'rev-parse', 'HEAD']) != args.revision):
            raise ValueError('Manifest source or dimensions mismatch')
        validate_coverage(manifest['captures'], set(expected))
        validate_format_evidence(directory, manifest)
        for row in manifest['captures']:
            validated = validate_capture(directory, row, expected, args.revision)
            decode_native(directory / row['file'], directory)
            if (row['sha256'] != validated['sha256'] or row['dimensions'] != validated['dimensions']
                    or validated['format'] != manifest['format'] or row['alphaChannel'] != validated['alphaChannel']
                    or row['opaquePixels'] != validated['opaquePixels']):
                raise ValueError('Screenshot bytes changed after manifest creation')
        if manifest['store_locales'] != store_mappings(set(expected), manifest['format']):
            raise ValueError('Manifest store mappings differ from current inventory')
        if (manifest.get('upload_alpha_channel_review_required') != any(row['alphaChannel'] for row in manifest['captures'])
                or manifest.get('complication_face') != {'status': 'manual_remaining', 'counted_as_captured': False}):
            raise ValueError('Manifest upload-review or manual-face status is incorrect')
    else:
        capture(directory, args.revision)


if __name__ == '__main__':
    main()
