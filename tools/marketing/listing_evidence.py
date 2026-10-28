#!/usr/bin/env python3
"""Bounded, original-byte evidence for future listing runs; never fetch old artifacts.

A review package is not release approval. Failed source manifests remain failed,
without selecting arbitrary XCTest screenshots as substitutes for missing frames.
The workflow retains the complete raw forensic artifact independently.
"""
from __future__ import annotations

import argparse
import json
import os
from pathlib import Path, PurePosixPath
import re
import subprocess
import zipfile

import listing_assets as assets

MIB = 1024 * 1024
MAX_FILE = 128 * MIB
MAX_FILES = 5000
REVIEW_LIMIT = 384 * MIB
DIAGNOSTICS_LIMIT = 64 * MIB


def safe_file(root: Path, relative: str) -> Path:
    """Reject traversal, noncanonical names, symlinks (even internal), and devices."""
    if not isinstance(relative, str) or not relative or len(relative.encode()) > 1024:
        raise ValueError('Invalid evidence path')
    parts = relative.split('/')
    if ('\\' in relative or ':' in relative or '\x00' in relative or
            any(part in ('', '.', '..') for part in parts) or PurePosixPath(relative).is_absolute()):
        raise ValueError('Unsafe evidence path: ' + relative)
    current = root
    if current.is_symlink():
        raise ValueError('Symlink evidence root')
    for part in parts:
        current = current / part
        if current.is_symlink():
            raise ValueError('Symlink evidence path: ' + relative)
    if not current.is_file() or not current.resolve().is_relative_to(root.resolve()):
        raise ValueError('Missing/nonregular evidence file: ' + relative)
    size = current.stat().st_size
    if size <= 0 or size > MAX_FILE:
        raise ValueError('Evidence file outside byte bound: ' + relative)
    return current


def checked_json(root: Path, relative: str):
    path = safe_file(root, relative)
    if path.stat().st_size > 16 * MIB:
        raise ValueError('JSON evidence outside byte bound')
    return assets.read_json(path)


def export_result_summaries(bundle: Path, folder: Path):
    """Best-effort diagnostics must never mask the original UI test exit status.

    Every export status/error is retained. Packaging reports missing or failed
    exports explicitly, and complete raw xcresults remain available separately.
    """
    reports = []
    for report in ('summary', 'tests'):
        command = ['xcrun', 'xcresulttool', 'get', 'test-results', report, '--path', str(bundle)]
        destination = folder / f'xcresult-{report}.json'
        stderr = folder / f'xcresult-{report}.stderr.log'
        item = {'report': report, 'command': command, 'status': 'failed'}
        try:
            with destination.open('w') as out, stderr.open('w') as err:
                result = subprocess.run(command, stdout=out, stderr=err, timeout=120)
            item['exit_code'] = result.returncode
            if result.returncode:
                raise ValueError(f'xcresulttool exited {result.returncode}')
            if not isinstance(assets.read_json(destination), dict):
                raise ValueError('xcresulttool did not return a JSON object')
            item['status'] = 'exported'
        except (OSError, ValueError, subprocess.SubprocessError) as error:
            item['error'] = str(error)
        reports.append(item)
    try:
        assets.write_json(folder / 'xcresult-export-status.json', reports)
    except OSError as error:
        print(f'::warning::Could not persist xcresult summary export status: {error}', flush=True)


def source_identity(build_info: Path, build_archive: Path, source_sha: str) -> dict:
    if not re.fullmatch(r'[a-f0-9]{40}', source_sha):
        raise ValueError('Expected exact source SHA')
    info = assets.read_json(build_info)
    build_hash = assets.digest(build_archive)
    if info.get('source_sha') != source_sha or info.get('archive_sha256') != build_hash:
        raise ValueError('Evidence source/build identity mismatch')
    return {'source_sha': source_sha, 'build_sha256': build_hash,
            'repository': os.environ.get('GITHUB_REPOSITORY'),
            'run_id': os.environ.get('GITHUB_RUN_ID'),
            'run_attempt': os.environ.get('GITHUB_RUN_ATTEMPT'),
            'build_info_sha256': assets.digest(build_info)}


def file_record(root, relative, role, **extra):
    path = safe_file(root, relative)
    return {'path': relative, 'bytes': path.stat().st_size, 'sha256': assets.digest(path),
            'role': role, **extra}


def write_bundle(out: Path, records: list, index: dict, *, limit: int, expanded_limit: int, compress: bool):
    """No truncation or overflow: failed packaging leaves raw inputs untouched."""
    if out.exists():
        raise ValueError('Refusing to overwrite an evidence package')
    if len(records) > MAX_FILES or sum(row['bytes'] for _, row in records) > expanded_limit:
        raise ValueError('Evidence inventory exceeds count/expanded byte bound')
    names = [row['path'] for _, row in records]
    if len(names) != len(set(names)):
        raise ValueError('Duplicate package path')
    index = {**index, 'files': [row for _, row in records]}
    payload = (json.dumps(index, indent=2, ensure_ascii=False) + '\n').encode()
    if len(payload) > MIB:
        raise ValueError('Evidence index exceeds byte bound')
    out.mkdir(parents=True, exist_ok=False)
    temporary = out / 'bundle.zip.partial'
    try:
        compression = zipfile.ZIP_DEFLATED if compress else zipfile.ZIP_STORED
        with zipfile.ZipFile(temporary, 'x', compression=compression, compresslevel=6 if compress else None) as bundle:
            bundle.writestr('EVIDENCE-INDEX.json', payload)
            for root, row in records:
                path = safe_file(root, row['path'])
                if path.stat().st_size != row['bytes'] or assets.digest(path) != row['sha256']:
                    raise ValueError('Evidence changed before packaging: ' + row['path'])
                bundle.write(path, 'originals/' + row['path'])
                if temporary.stat().st_size + len(payload) >= limit:
                    raise ValueError('Evidence package exceeds compressed byte bound')
        # Check the exact final size, including ZIP central directory and separate index.
        if temporary.stat().st_size + len(payload) >= limit:
            raise ValueError('Evidence package exceeds final byte bound')
        with zipfile.ZipFile(temporary) as bundle:
            for _, row in records:
                import hashlib
                with bundle.open('originals/' + row['path']) as stream:
                    actual = hashlib.file_digest(stream, 'sha256').hexdigest()
                if actual != row['sha256']:
                    raise ValueError('Packaged original differs: ' + row['path'])
        temporary.rename(out / 'bundle.zip')
        (out / 'index.json').write_bytes(payload)
    except Exception:
        # Remove only this newly created, incomplete output, never any source evidence.
        temporary.unlink(missing_ok=True)
        raise
    return index


def export_manifest(folder: Path):
    """Validate the native attachment export before allowing its selection mapping."""
    data = checked_json(folder, 'manifest.json')
    if not isinstance(data, list):
        raise ValueError('Invalid native attachment manifest')
    entries = []
    for test in data:
        if not isinstance(test, dict) or not isinstance(test.get('attachments'), list):
            raise ValueError('Invalid native attachment manifest test')
        for entry in test['attachments']:
            if not isinstance(entry, dict) or not isinstance(entry.get('suggestedHumanReadableName'), str):
                raise ValueError('Invalid native attachment record')
            # Validate every path lexically, but read only explicitly selected media/text.
            name = entry.get('exportedFileName')
            if (not isinstance(name, str) or not name or len(name.encode()) > 1024 or
                    '/' in name or '\\' in name or ':' in name or name in ('.', '..') or '\x00' in name):
                raise ValueError('Unsafe native attachment filename')
            entries.append({**entry, 'testIdentifier': test.get('testIdentifier'),
                            'testIdentifierURL': test.get('testIdentifierURL')})
    if len(entries) > MAX_FILES:
        raise ValueError('Native attachment inventory exceeds count bound')
    return entries


def review_records(root: Path, manifests: Path, locales: list, kind: str, source: dict):
    device = checked_json(root, 'device.json')
    if not isinstance(device, dict) or any(not isinstance(device.get(key), str) or not device[key]
                                           for key in ('id', 'name', 'runtime')):
        raise ValueError('Missing native device identity')
    records = [(root, file_record(root, 'device.json', 'original-native-device'))]
    coverage = []
    expected = {f'{locale}-{kind}.manifest.json' for locale in locales}
    if {path.name for path in manifests.glob('*.manifest.json')} != expected:
        raise ValueError('Missing or unexpected requested locale manifest')
    for locale in locales:
        relative = f'{locale}/{kind}'
        base = root / relative
        manifest = checked_json(manifests, f'{locale}-{kind}.manifest.json')
        local_manifest = checked_json(root, relative + '/manifest.json')
        if manifest != local_manifest:
            raise ValueError('Compact/raw manifest disagreement')
        if (manifest.get('source_sha') != source['source_sha'] or
                manifest.get('build_sha256') != source['build_sha256'] or manifest.get('kind') != kind or
                manifest.get('device') != device or
                any(manifest.get(key) != value for key, value in assets.locale_spec(locale).items())):
            raise ValueError('Locale/source/build manifest identity mismatch')
        if (manifest.get('release_ready') is not False or manifest.get('native_review') != 'pending' or
                manifest.get('visual_review') != 'pending'):
            raise ValueError('Packaging cannot certify visual/native/release approval')
        records.append((root, file_record(root, relative + '/manifest.json', 'original-source-manifest')))
        item = {'listing_locale': locale, 'kind': kind, 'source_status': manifest.get('status'),
                'device': manifest.get('device'), 'selected_attempt': manifest.get('selected_attempt')}
        if manifest.get('status') != 'mechanically_verified':
            if manifest.get('status') not in ('failed', 'running'):
                raise ValueError('Unrecognized source status')
            item.update(review_assets='unavailable-unverified-source', error=manifest.get('error'),
                        requested_captures=assets.expected_captures(locale, kind) if kind in assets.SCREENSHOT_KINDS else [])
            coverage.append(item)
            continue
        assets.validate_manifest_assets(manifest)
        for row in manifest.get('captures', []) + manifest['assets']:
            if kind not in assets.SCREENSHOT_KINDS and Path(row['path']).name == 'raw.mp4':
                continue  # Forensic-only input: do not impose review byte limits on it.
            path = safe_file(base, row['path'])
            if assets.digest(path) != row.get('sha256'):
                raise ValueError('Selected original hash mismatch: ' + row['path'])
        if kind in assets.SCREENSHOT_KINDS:
            attempt = manifest.get('selected_attempt')
            if not isinstance(attempt, str) or not re.fullmatch(r'capture/attempt-[12]', attempt):
                raise ValueError('Invalid selected native capture attempt')
            folder = base / attempt / 'attachments'
            safe_file(base, attempt + '/attachments/manifest.json')
            export_manifest(folder)
            captures = assets.capture_records(folder, locale, kind, base)
            if captures != manifest['captures']:
                raise ValueError('Native export selection/hash/pixels do not match capture manifest')
            if assets.screenshot_records(base / 'rendered', locale, kind, base) != manifest['assets']:
                raise ValueError('Rendered selection/hash/pixels do not match asset manifest')
            from PIL import Image
            for row in captures:
                with Image.open(base / row['path']) as image:
                    if image.format != 'PNG':
                        raise ValueError('Requested original native capture is not PNG')
                records.append((root, file_record(root, relative + '/' + row['path'], 'original-native-capture',
                                                  capture=row['capture'], pixel_sha256=row['pixel_sha256'], size=row['size'])))
            records.append((root, file_record(root, relative + '/' + attempt + '/attachments/manifest.json',
                                              'original-native-export-manifest')))
        for row in manifest['assets']:
            # Optional preview raw recording stays in the full forensic artifact, not review.
            if kind not in assets.SCREENSHOT_KINDS and Path(row['path']).name == 'raw.mp4':
                continue
            records.append((root, file_record(root, relative + '/' + row['path'], 'original-final-asset')))
        item['review_assets'] = 'complete'
        coverage.append(item)
    return records, coverage


def failure_screenshot_records(root, folder, entries, source, locales, kind):
    """Only the source's explicit teardown capture, never automatic XCTest media."""
    relative = folder.relative_to(root)
    parts = relative.parts
    if (kind not in ('iphone', 'iphone-large') or len(parts) != 5 or
            parts[1:3] != (kind, 'capture') or not re.fullmatch(r'attempt-[12]', parts[3])):
        return [], []
    locale = parts[0]
    log = safe_file(root, str(relative.parent / 'test.log'))
    text = log.read_text(errors='replace')
    failed = []
    for selector in assets.selectors(kind):
        target, cls, method = selector.split('/')
        pattern = rf"Test Case '-\[{re.escape(target)}\.{re.escape(cls)} {re.escape(method)}\]' failed"
        if re.search(pattern, text):
            failed.append((target, cls, method))
    if not failed:
        return [], []
    if not source or locale not in locales:
        raise ValueError('Failure PNG lacks requested source/locale identity')
    manifest = checked_json(root, f'{locale}/{kind}/manifest.json')
    device = checked_json(root, 'device.json')
    if (manifest.get('source_sha') != source['source_sha'] or manifest.get('build_sha256') != source['build_sha256'] or
            manifest.get('kind') != kind or manifest.get('device') != device or
            any(manifest.get(key) != value for key, value in assets.locale_spec(locale).items())):
        raise ValueError('Failure PNG source/build/locale/device identity mismatch')
    records, errors, used = [], [], set()
    for target, cls, method in failed:
        name = f'zz-failure--[{cls} {method}]'
        selected = [entry for entry in entries if re.sub(r'_\d+_[0-9A-Fa-f-]{36}(\.\w+)?$', '',
                    entry['suggestedHumanReadableName']) == name]
        if len(selected) != 1:
            errors.append(f'{relative}: {cls}/{method}: expected one explicit {name} PNG, got {len(selected)}')
            continue
        entry = selected[0]
        test_id = f'{cls}/{method}()'
        test_url = entry.get('testIdentifierURL')
        if (entry.get('testIdentifier') != test_id or not isinstance(test_url, str) or
                not test_url.startswith('test://com.apple.xcode/') or not test_url.endswith(f'/{target}/{cls}/{method}') or
                entry.get('deviceId') != device.get('id') or entry.get('deviceName') != device.get('name')):
            errors.append(f'{relative}: {name}: native export test/device identity mismatch')
            continue
        try:
            filename = entry['exportedFileName']
            if filename in used or Path(filename).suffix.lower() != '.png':
                raise ValueError('Reused or non-PNG failure attachment')
            path = safe_file(root, str(relative / filename))
            from PIL import Image
            with Image.open(path) as image:
                if image.format != 'PNG':
                    raise ValueError('Failure attachment is not original PNG')
            image_info = assets.image_record(path, root)
            if image_info['size'] != list(assets.screenshot_role(kind).native_size):
                raise ValueError('Failure PNG has wrong native device dimensions')
            row = file_record(root, str(relative / filename), 'original-failure-screenshot-diagnostic-only',
                              capture=name, testIdentifier=test_id, testIdentifierURL=test_url,
                              listing_locale=locale, kind=kind, attempt=str(relative.parent), device=device,
                              source_sha=source['source_sha'], build_sha256=source['build_sha256'],
                              pixel_sha256=image_info['pixel_sha256'], size=image_info['size'])
            records.append((root, row))
            used.add(filename)
        except Exception as error:
            # A missing image dependency or unreadable PNG must not hide the full logs.
            errors.append(f'{relative}: {name}: failure PNG unavailable: {error}')
    return records, errors


def diagnostic_records(root: Path, *, source=None, locales=(), kind=None):
    records, errors = [], []
    if not root.is_dir() or root.is_symlink():
        raise ValueError('Missing/unsafe native evidence root')
    for current, directories, files in os.walk(root, followlinks=False):
        folder = Path(current)
        for name in directories + files:
            if (folder / name).is_symlink():
                raise ValueError('Symlink in diagnostic evidence')
        bundles = [name for name in directories if name.endswith('.xcresult')]
        directories[:] = [name for name in directories if not name.endswith('.xcresult')]
        if bundles:
            if not (folder / 'attachments/manifest.json').is_file():
                errors.append(str(folder.relative_to(root)) + ': native attachment export manifest missing')
            label = str(folder.relative_to(root))
            try:
                reports = checked_json(root, str((folder / 'xcresult-export-status.json').relative_to(root)))
                if (not isinstance(reports, list) or len(reports) != 2 or
                        {r.get('report') for r in reports if isinstance(r, dict)} != {'summary', 'tests'} or
                        any(not isinstance(r, dict) or r.get('status') != 'exported' for r in reports)):
                    errors.append(label + ': xcresult summary export incomplete')
            except (ValueError, OSError) as error:
                errors.append(label + ': xcresult summary export missing/invalid: ' + str(error))
            for name in ('test.log', 'xcresult-summary.json', 'xcresult-tests.json'):
                try:
                    safe_file(root, str((folder / name).relative_to(root)))
                    if name.endswith('.json') and not isinstance(checked_json(folder, name), dict):
                        raise ValueError('Expected xcresult JSON object')
                except (ValueError, OSError) as error:
                    errors.append(label + ': required diagnostic missing/invalid: ' + str(error))
        if folder.name == 'attachments':
            # An interrupted export must not prevent the full test logs being published.
            # Retain its manifest when readable, but never guess a text attachment name.
            wanted = {'manifest.json'} if 'manifest.json' in files else set()
            try:
                entries = export_manifest(folder)
                wanted.update(entry['exportedFileName'] for entry in entries
                              if Path(entry['exportedFileName']).suffix.lower() in ('.txt', '.json', '.log', '.xml'))
                failure_records, failure_errors = failure_screenshot_records(root, folder, entries, source, locales, kind)
                records.extend(failure_records)
                errors.extend(failure_errors)
            except (ValueError, OSError) as error:
                errors.append(str(folder.relative_to(root)) + ': attachment export incomplete: ' + str(error))
        else:
            wanted = {name for name in files if Path(name).suffix.lower() in ('.log', '.json', '.jsonl', '.txt')}
        for name in sorted(wanted):
            path = folder / name
            if path.exists() and path.stat().st_size == 0:
                if name == 'test.log' or name in ('xcresult-summary.json', 'xcresult-tests.json'):
                    errors.append(str(path.relative_to(root)) + ': empty required diagnostic')
                continue  # Empty stderr is normal; there are no bytes to truncate.
            relative = str(path.relative_to(root))
            try:
                records.append((root, file_record(root, relative, 'original-diagnostic')))
            except (ValueError, OSError) as error:
                errors.append(relative + ': diagnostic not packaged: ' + str(error))
            if len(records) > MAX_FILES:
                raise ValueError('Diagnostic file count exceeds bound')
    if not records:
        errors.append('No diagnostic evidence produced')
    return records, errors


def write_diagnostics(out, failure_out, records, index):
    """Persist full text first; excessive failure media must never hide assertions."""
    failures = [(root, row) for root, row in records if row['role'] == 'original-failure-screenshot-diagnostic-only']
    text_records = [(root, row) for root, row in records if row['role'] != 'original-failure-screenshot-diagnostic-only']
    text_index = {**index, 'failure_images_stored_separately': [row for _, row in failures]}
    write_bundle(out, text_records, text_index, limit=DIAGNOSTICS_LIMIT, expanded_limit=256 * MIB, compress=True)
    failure_index = {**index, 'diagnostic_only': True,
                     'note': 'Explicit original native failure PNGs, not listing assets. Full logs are in the separate diagnostics artifact.'}
    write_bundle(failure_out, failures, failure_index, limit=REVIEW_LIMIT, expanded_limit=REVIEW_LIMIT - 2 * MIB, compress=False)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('mode', choices=['diagnostics', 'review'])
    parser.add_argument('--assets', type=Path, required=True)
    parser.add_argument('--manifests', type=Path, required=True)
    parser.add_argument('--build-info', type=Path, required=True)
    parser.add_argument('--build-archive', type=Path, required=True)
    parser.add_argument('--source-sha', required=True)
    parser.add_argument('--locales', required=True)
    parser.add_argument('--kind', choices=assets.KINDS, required=True)
    parser.add_argument('--out', type=Path, required=True)
    parser.add_argument('--failure-out', type=Path)
    args = parser.parse_args()
    locales = assets.select_locales(args.locales)
    if len(locales) > 3:
        raise ValueError('Evidence packaging requires the existing bounded locale shard')
    source = source_identity(args.build_info, args.build_archive, args.source_sha)
    root = args.assets.resolve()
    if args.assets.is_symlink() or args.manifests.is_symlink():
        raise ValueError('Symlink evidence input')
    index = {'schema_version': 1, 'source': source, 'requested_locales': locales, 'kind': args.kind,
             'release_ready': False, 'visual_review': 'pending', 'native_review': 'pending',
             'note': 'Original bytes only. Failed source tests remain failed. Full raw forensic artifact is retained separately.'}
    if args.mode == 'review':
        records, coverage = review_records(root, args.manifests, locales, args.kind, source)
        records.append((args.build_info.parent, file_record(args.build_info.parent, args.build_info.name, 'original-build-provenance')))
        index['coverage'] = coverage
        index['status'] = 'complete' if all(row['review_assets'] == 'complete' for row in coverage) else 'incomplete-source-failure'
        write_bundle(args.out, records, index, limit=REVIEW_LIMIT, expanded_limit=REVIEW_LIMIT - 2 * MIB, compress=False)
        return 0  # An incomplete source remains failed in the capture step and inventory.
    if args.failure_out is None:
        raise ValueError('Diagnostics requires a separate failure-image output')
    records, errors = diagnostic_records(root, source=source, locales=locales, kind=args.kind)
    records.append((args.build_info.parent, file_record(args.build_info.parent, args.build_info.name, 'original-build-provenance')))
    index.update(errors=errors, status='complete' if not errors else 'incomplete')
    write_diagnostics(args.out, args.failure_out, records, index)
    return 1 if errors else 0


if __name__ == '__main__':
    raise SystemExit(main())
