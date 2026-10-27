#!/usr/bin/env python3
"""Recover reviewed original listing files only; no rendering or approval changes."""
from __future__ import annotations

import hashlib
import json
import os
import re
from pathlib import Path, PurePosixPath
import shutil
import stat
import sys
import time
import urllib.error
import urllib.parse
import urllib.request
import zipfile

APPROVED = {
    'repository': 'azerish25-ux/tuner', 'artifact_id': 12722724126,
    'name': 'listing-assets-ipad-01', 'run_id': 40472603655,
    'source_sha': 'fa5a28aa77abb63fd84ba68c70fb150e84cedc47',
    'size_in_bytes': 1352807197,
    'digest': 'sha256:145260370afa7f8780b831e92cb6fa5c93f18b0d863ef7aee458cdc68c4c9560',
}
SLICE_LIMIT = 350_000_000
MAX_SLICES = 8
MAX_SELECTED = 2_000_000_000
MAX_ENTRY = 300_000_000


def digest(path):
    h = hashlib.sha256()
    with Path(path).open('rb') as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b''):
            h.update(block)
    return h.hexdigest()


def validate_metadata(metadata, expected=APPROVED):
    if not isinstance(metadata, dict):
        raise ValueError('Malformed artifact metadata')
    for key, wanted in [('id', expected['artifact_id']), ('name', expected['name']),
                        ('size_in_bytes', expected['size_in_bytes']), ('digest', expected['digest'])]:
        if metadata.get(key) != wanted:
            raise ValueError('Unreviewed artifact metadata: ' + key)
    run = metadata.get('workflow_run', {})
    if not isinstance(run, dict) or run.get('id') != expected['run_id'] or run.get('head_sha') != expected['source_sha']:
        raise ValueError('Unreviewed artifact source run/revision')
    if metadata.get('expired') is not False:
        raise ValueError('Source artifact expired or expiry status missing')


def safe_name(info):
    name = info.filename
    path = PurePosixPath(name)
    if (not name or name.startswith('/') or '\\' in name or ':' in name or
            any(p in ('', '.', '..') for p in name.rstrip('/').split('/')) or
            len(name.encode()) > 1024 or stat.S_ISLNK(info.external_attr >> 16)):
        raise ValueError('Unsafe ZIP member: ' + name)
    return path


def selected(path):
    parts = path.parts
    if any(p.endswith('.xcresult') for p in parts) or any(p in ('Products', 'DerivedData', 'Build') for p in parts):
        return False
    suffix = path.suffix.lower()
    # Exported attempt attachments remain diagnostic-only, never rendered/approved.
    if suffix in ('.jpg', '.jpeg', '.png'):
        attachment = (len(parts) == 7 and parts[0] == 'assets' and
                      parts[2] in ('iphone', 'ipad') and
                      parts[3] in ('capture', 'language-check') and
                      re.fullmatch(r'attempt-[1-9]\d*', parts[4]) and parts[5] == 'attachments')
        return 'rendered' in parts or bool(attachment)
    return suffix in ('.json', '.jsonl', '.log', '.txt', '.gz')


def verify_rendered(records, extracted):
    """Bind rendered files to the original locale manifest; retain failures unchanged."""
    known = {}
    for record in records:
        path = PurePosixPath(record['path'])
        if not (len(path.parts) == 4 and path.parts[0] == 'assets' and
                path.parts[2] in ('iphone', 'ipad') and path.name == 'manifest.json'):
            continue
        manifest = json.loads((extracted / record['path']).read_text())
        if not isinstance(manifest, dict):
            raise ValueError('Malformed original locale manifest')
        for asset in manifest.get('assets', []):
            name = str(path.parent / asset['path'])
            known[name] = asset['sha256']
    for record in records:
        if 'rendered' in PurePosixPath(record['path']).parts and PurePosixPath(record['path']).suffix.lower() in ('.jpg', '.jpeg', '.png'):
            if known.get(record['path']) != record['sha256']:
                raise ValueError('Rendered file lacks matching original manifest hash: ' + record['path'])


def package(archive, out, expected=APPROVED, slice_limit=SLICE_LIMIT):
    archive, out = Path(archive), Path(out)
    if archive.stat().st_size != expected['size_in_bytes'] or 'sha256:' + digest(archive) != expected['digest']:
        raise ValueError('Original archive size/digest differs from reviewed metadata')
    out.mkdir(parents=True, exist_ok=False)
    extracted = out / 'originals'
    records, seen, total = [], set(), 0
    with zipfile.ZipFile(archive) as source:
        if len(source.infolist()) > 100000:
            raise ValueError('Too many ZIP members')
        for entry in source.infolist():
            path = safe_name(entry)
            if entry.filename in seen:
                raise ValueError('Duplicate ZIP member')
            seen.add(entry.filename)
            if entry.is_dir() or not selected(path):
                continue
            if entry.file_size > MAX_ENTRY or entry.file_size < 0:
                raise ValueError('Selected file exceeds size bound')
            total += entry.file_size
            if total > MAX_SELECTED:
                raise ValueError('Selected expansion exceeds size bound')
            destination = extracted / str(path)
            destination.parent.mkdir(parents=True, exist_ok=True)
            h, count = hashlib.sha256(), 0
            with source.open(entry) as original, destination.open('xb') as target:
                for block in iter(lambda: original.read(1024 * 1024), b''):
                    count += len(block)
                    if count > entry.file_size:
                        raise ValueError('ZIP member expanded beyond declared size')
                    target.write(block)
                    h.update(block)
            if count != entry.file_size:
                raise ValueError('ZIP member size differs')
            role = ('rendered-original' if 'rendered' in path.parts else
                    'diagnostic-attachment-only' if path.suffix.lower() in ('.jpg', '.jpeg', '.png') else
                    'original-text-or-metadata')
            records.append({'path': str(path), 'bytes': count, 'sha256': h.hexdigest(), 'role': role})
    if not records or not any('rendered' in PurePosixPath(r['path']).parts for r in records):
        raise ValueError('No original rendered listing images selected')
    verify_rendered(records, extracted)
    groups, group, size = [], [], 0
    for record in sorted(records, key=lambda r: r['path']):
        # Reserve ample room for ZIP headers and receipts; store bytes uncompressed.
        cost = record['bytes'] + 4096
        if cost + 1_000_000 > slice_limit:
            raise ValueError('One file cannot fit within slice bound')
        if group and size + cost + 1_000_000 > slice_limit:
            groups.append(group)
            group, size = [], 0
        group.append(record)
        size += cost
    if group:
        groups.append(group)
    if len(groups) > MAX_SLICES:
        raise ValueError('Too many review slices')
    index = {'source': expected, 'diagnostic_review_only': True,
             'note': 'Original bytes only. Exported attachments are diagnostic-only, not accepted listing assets. Existing manifest failures and release flags unchanged.',
             'selected_bytes': total, 'selected_files': len(records), 'slices': []}
    for number, rows in enumerate(groups, 1):
        filename = f'listing-review-{number:02d}.zip'
        receipt = {'source': expected, 'slice': number, 'slice_count': len(groups),
                   'diagnostic_review_only': True, 'files': rows}
        with zipfile.ZipFile(out / filename, 'x', compression=zipfile.ZIP_STORED) as dest:
            dest.writestr(zipfile.ZipInfo('REVIEW-RECEIPT.json'), json.dumps(receipt, indent=2) + '\n')
            for row in rows:
                info = zipfile.ZipInfo('originals/' + row['path'])
                with (extracted / row['path']).open('rb') as source, dest.open(info, 'w') as target:
                    shutil.copyfileobj(source, target, 1024 * 1024)
        if (out / filename).stat().st_size >= slice_limit:
            raise ValueError('Packaged slice exceeds size bound')
        index['slices'].append({'path': filename, 'bytes': (out / filename).stat().st_size,
                                'sha256': digest(out / filename)})
    (out / 'index.json').write_text(json.dumps(index, indent=2) + '\n')
    return index


class NoRedirect(urllib.request.HTTPRedirectHandler):
    def redirect_request(self, request, fp, code, message, headers, url):
        return None


def fetch(archive):
    if os.environ.get('GITHUB_REPOSITORY') != APPROVED['repository']:
        raise ValueError('Only the reviewed same repository is allowed')
    token = os.environ['GH_TOKEN']
    base = 'https://api.github.com/repos/' + APPROVED['repository'] + '/actions/artifacts/' + str(APPROVED['artifact_id'])
    headers = {'Authorization': 'Bearer ' + token, 'Accept': 'application/vnd.github+json',
               'X-GitHub-Api-Version': '2022-11-28'}
    with urllib.request.build_opener(NoRedirect).open(urllib.request.Request(base, headers=headers), timeout=30) as response:
        metadata = json.load(response)
    validate_metadata(metadata)
    try:
        urllib.request.build_opener(NoRedirect).open(urllib.request.Request(base + '/zip', headers=headers), timeout=30)
    except urllib.error.HTTPError as response:
        if response.code != 302:
            raise
        location = response.headers['Location']
    else:
        raise ValueError('Expected authenticated artifact download redirect')
    parsed = urllib.parse.urlparse(location)
    if (parsed.scheme != 'https' or not parsed.hostname or
            not parsed.hostname.endswith('.blob.core.windows.net') or parsed.username or parsed.password):
        raise ValueError('Unexpected GitHub artifact storage host')
    # Never forward the GitHub token to the signed storage URL.
    deadline, count = time.monotonic() + 900, 0
    with urllib.request.build_opener(NoRedirect).open(location, timeout=30) as response, Path(archive).open('xb') as target:
        for block in iter(lambda: response.read(1024 * 1024), b''):
            count += len(block)
            if count > APPROVED['size_in_bytes'] or time.monotonic() > deadline:
                raise ValueError('Artifact download exceeds reviewed byte/time bound')
            target.write(block)
    if count != APPROVED['size_in_bytes']:
        raise ValueError('Incomplete source archive download')


def main():
    if len(sys.argv) != 1:
        raise SystemExit('No arbitrary artifact IDs, metadata, or URLs accepted')
    archive = Path('source-listing-artifact.zip')
    fetch(archive)
    index = package(archive, Path('review-out'))
    print(json.dumps(index, indent=2))
    with open(os.environ['GITHUB_OUTPUT'], 'a') as output:
        output.write('slice_count=' + str(len(index['slices'])) + '\n')


if __name__ == '__main__':
    main()
