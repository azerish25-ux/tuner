#!/usr/bin/env python3
"""Fail-closed plans and evidence for the 50-locale listing-assets workflow.

This is capture/render evidence, never release approval. No Apple API or git writes.
"""
from __future__ import annotations

import argparse
from functools import lru_cache
import hashlib
import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
REGISTRY = ROOT / 'tools/l10n/store-locales.json'
PREFIX = 'TimbreUITests/'
EVIDENCE_TEST = PREFIX + 'ListingCaptureEvidenceUITests/testRequestedLanguageActuallyAppears'
CAPTURE_TESTS = {
    '10b-tune-locked': 'test11StoreTunerLock',
    '65-song-perform': 'test14StoreSongPerform',
    '52b-lesson-chord': 'test12StoreChord',
    '31b-instruments-folk': 'test17StoreInstrumentWall',
    '63-songs': 'test10PlayAlongLesson',
    '50-learn': 'test09LearnChordLesson',
    '62-lesson-results': 'test10PlayAlongLesson',
    '11b-tune-strum': 'test13StoreStrum',
    '32-journey': 'test05OtherTabs',
}
ALLOWED_REFS = ('refs/heads/main', 'refs/heads/codex/app-store-readiness-gates')
PUSH_MARKERS = {
    '[listing-assets-pilot]': ('en-US,de-DE,ar-SA', 'all'),
    '[listing-assets-all]': ('all', 'all'),
    '[listing-screenshots-pilot]': ('en-US,de-DE,ar-SA', 'screenshots'),
    '[listing-screenshots-all]': ('all', 'screenshots'),
}
KINDS = ('iphone', 'ipad', 'preview-main', 'preview-violin')
# Explicit regional choices for Apple's language-only listing codes. They are
# formatting locales, not a claim that every regional UI variant is translated.
REGIONS = {
    'ca': 'ca_ES', 'hr': 'hr_HR', 'cs': 'cs_CZ', 'da': 'da_DK', 'fi': 'fi_FI',
    'el': 'el_GR', 'he': 'he_IL', 'hi': 'hi_IN', 'hu': 'hu_HU', 'id': 'id_ID',
    'it': 'it_IT', 'ja': 'ja_JP', 'ko': 'ko_KR', 'ms': 'ms_MY', 'no': 'nb_NO',
    'pl': 'pl_PL', 'ro': 'ro_RO', 'ru': 'ru_RU', 'sk': 'sk_SK', 'sv': 'sv_SE',
    'th': 'th_TH', 'tr': 'tr_TR', 'uk': 'uk_UA', 'vi': 'vi_VN',
    'zh-Hans': 'zh_CN', 'zh-Hant': 'zh_TW',
}
FALLBACK_LANGUAGES = {'ms': 'ms', 'or-IN': 'or', 'zh-Hant': 'zh-Hant'}


def read_json(path: Path):
    return json.loads(path.read_text(encoding='utf-8'))


def write_json(path: Path, value):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(value, indent=2, ensure_ascii=False) + '\n', encoding='utf-8')


def digest(path: Path) -> str:
    value = hashlib.sha256()
    with path.open('rb') as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b''):
            value.update(block)
    return value.hexdigest()


def locale_rows() -> dict:
    registry = read_json(REGISTRY)
    rows = registry['locales']
    found = {row['locale']: row for row in rows}
    if len(rows) != 50 or len(found) != 50:
        raise ValueError('Registry must contain exactly 50 distinct listing locales')
    fallback = {row['locale'] for row in rows if row['app_locale'] is None}
    if fallback != set(FALLBACK_LANGUAGES):
        raise ValueError(f'Unreviewed listing-only fallback set: {fallback}')
    for locale, row in found.items():
        if not re.fullmatch(r'[A-Za-z]+(?:-[A-Za-z0-9]+)*', locale):
            raise ValueError(f'Unsafe locale: {locale}')
        if row['app_locale'] is None and row['app_fallback'] != 'en':
            raise ValueError(f'{locale}: unsupported fallback')
    return found


def lesson_provenance(language: str) -> dict:
    path = ROOT / 'ios/Timbre/Resources' / (language + '.lproj') / 'Learn.strings'
    return {'lesson_resource_status': 'shipped' if path.is_file() else 'pending',
            'lesson_resource_sha256': digest(path) if path.is_file() else None}


def locale_spec(locale: str) -> dict:
    row = locale_rows()[locale]
    fallback = row['app_locale'] is None
    language = row['app_locale'] or row['app_fallback']
    apple_languages = [FALLBACK_LANGUAGES[locale], 'en'] if fallback else [language]
    return {
        'listing_locale': locale,
        'app_language': language,
        'apple_languages': apple_languages,
        'apple_locale': REGIONS.get(locale, locale.replace('-', '_')),
        'listing_only_fallback': fallback,
        'ui_support_claim': not fallback,
        'payload_sha256': digest(ROOT / row['content_file']),
        **lesson_provenance(language),
    }


def select_locales(value: str) -> list[str]:
    known = locale_rows()
    selected = list(known) if value == 'all' else value.split(',')
    if not selected or len(selected) != len(set(selected)) or any(x not in known for x in selected):
        raise ValueError('Select all or distinct exact listing locale codes from store-locales.json')
    return selected


def expected_captures(locale: str, device: str) -> list[str]:
    import screenshots
    rows = screenshots.plan(device, locale=locale)
    names = [row[0] for row in rows]
    count = 9 if device == 'iphone' else 4
    if len(names) != count or len(set(names)) != count:
        raise ValueError(f'{locale}/{device}: expected {count} distinct default screenshots')
    if names != [row[0] for row in screenshots.plan(device)]:
        raise ValueError(f'{locale}/{device}: capture order differs from source')
    return names


def selectors(kind: str) -> list[str]:
    if kind == 'iphone':
        names = expected_captures('en-US', 'iphone')
        return [PREFIX + 'TimbreUITests/' + x for x in dict.fromkeys(CAPTURE_TESTS[n] for n in names)]
    if kind == 'ipad':
        return [PREFIX + 'TabletScreenshotsUITests/testTabletLayouts']
    if kind.startswith('preview-'):
        return [PREFIX + 'AppPreviewUITests/' + ('testAppPreviewViolin' if kind == 'preview-violin' else 'testAppPreview')]
    raise ValueError(f'Unknown asset kind: {kind}')


def make_plan(locales: str, scope: str, violin: bool = False, shard_size: int = 2) -> dict:
    if scope not in ('all', 'screenshots', 'previews') or shard_size not in (1, 2, 3):
        raise ValueError('Unknown scope or shard size (allowed: 1, 2, 3)')
    selected = select_locales(locales)
    kinds = list(KINDS[:2]) if scope == 'screenshots' else []
    if scope == 'all':
        kinds = list(KINDS[:3])
    if scope == 'previews':
        kinds = ['preview-main']
    if violin and scope != 'screenshots':
        kinds.append('preview-violin')
    include = []
    for kind in kinds:
        for start in range(0, len(selected), shard_size):
            include.append({'id': f'{kind}-{start // shard_size + 1:02d}', 'kind': kind,
                            'locales': ','.join(selected[start:start + shard_size])})
    return {'schema_version': 1, 'locales': selected, 'kinds': kinds,
            'requested_scope': scope,
            'full_screenshot_listing_scope': len(selected) == 50 and all(k in kinds for k in KINDS[:2]),
            'full_default_listing_scope': len(selected) == 50 and all(k in kinds for k in KINDS[:3]),
            'matrix': {'include': include}}


def request_scope(event: str, message: str, locales: str, scope: str, violin: bool,
                  ref: str = 'refs/heads/main') -> dict:
    """Exact approved refs only; push requires one unambiguous explicit marker."""
    if ref not in ALLOWED_REFS:
        raise ValueError('Listing assets require main or the exact reviewed handoff branch')
    if event == 'workflow_dispatch':
        return {'locales': locales, 'scope': scope, 'violin': violin, 'trigger': 'manual'}
    if event != 'push':
        raise ValueError('Unsupported listing-assets trigger')
    markers = [marker for marker in PUSH_MARKERS if marker in message]
    if len(markers) != 1:
        raise ValueError('A push must contain exactly one listing-assets/screenshots pilot/all marker')
    selected, selected_scope = PUSH_MARKERS[markers[0]]
    return {'locales': selected, 'scope': selected_scope, 'violin': False,
            'trigger': ref.removeprefix('refs/heads/') + '-push-' + markers[0][1:-1]}


def prepare_fixtures():
    sys.path.insert(0, str(ROOT / 'tools/l10n'))
    import matrix_fixture
    languages = sorted({locale_spec(x)['app_language'] for x in locale_rows()})
    data = matrix_fixture.fixture(languages)
    for language, fields in data.items():
        table = matrix_fixture.report.read_strings(matrix_fixture.report.RES / f'{language}.lproj/Localizable.strings')
        for key, source in [('lesson_start', 'Start'), ('lesson_continue', 'Continue'), ('all_tuned', 'All strings in tune')]:
            value = table.get(source, source if language == 'en' else None)
            if not value:
                raise ValueError(f'{language}: missing {source!r} preview fixture')
            fields[key] = value
    write_json(ROOT / 'ios/TimbreUITests/CaptureLocalizationExpected.json', data)
    return {'languages': languages, 'fixture_sha256': digest(ROOT / 'ios/TimbreUITests/CaptureLocalizationExpected.json')}


@lru_cache(maxsize=49)
def expected_tab_labels(language):
    sys.path.insert(0, str(ROOT / 'tools/l10n'))
    import matrix_fixture
    labels = matrix_fixture.fixture([language])[language]
    return {field: labels[field] for field in ['tune', 'learn', 'songs', 'practice', 'progress']}


def validate_language_evidence(spec: dict, text: str, event: str, minimum: int = 1) -> list[dict]:
    prefix = f'TIMBRE_CAPTURE_{event} '
    records = []
    for line in text.splitlines():
        if line.startswith(prefix):
            record = json.loads(line[len(prefix):])
            if not isinstance(record, dict):
                raise ValueError(f'{event}: expected a structured runtime evidence object')
            for key in ('listing_locale', 'app_language', 'apple_languages', 'apple_locale'):
                if record.get(key) != spec[key]:
                    raise ValueError(f'{spec["listing_locale"]}: wrong {event} evidence field {key}: {record.get(key)!r}')
            if event == 'VERIFIED' and record.get('checked_fields') != ['tune', 'learn', 'songs', 'practice', 'progress']:
                raise ValueError('Runtime evidence did not check every expected tab')
            if event == 'VERIFIED' and record.get('observed_labels') != expected_tab_labels(spec['app_language']):
                raise ValueError('Observed app tab labels do not match the current shipped language')
            records.append(record)
    if len(records) < minimum:
        raise ValueError(f'{spec["listing_locale"]}: missing executed {event} evidence ({len(records)} < {minimum})')
    return records


def image_record(path: Path, base: Path) -> dict:
    from PIL import Image, ImageOps
    with Image.open(path) as source:
        source.load()
        upright = ImageOps.exif_transpose(source).convert('RGB')
        pixels = hashlib.sha256(upright.tobytes()).hexdigest()
        size = list(upright.size)
    return {'path': str(path.relative_to(base)), 'sha256': digest(path), 'pixel_sha256': pixels, 'size': size}


def capture_records(folder: Path, locale: str, device: str, base: Path) -> list[dict]:
    import screenshots
    captures = screenshots.attachments(folder)
    needed = expected_captures(locale, device)
    records, used_paths, used_pixels = [], set(), set()
    for name in needed:
        if name + '-wrong' in captures:
            raise ValueError(f'{name}: test marked capture wrong')
        paths = captures.get(name, [])
        if len(paths) != 1:
            raise ValueError(f'{name}: expected one capture, got {len(paths)}')
        path = paths[0].resolve()
        if not path.is_relative_to(folder.resolve()) or not path.is_file():
            raise ValueError(f'{name}: missing or out-of-folder capture')
        if path in used_paths:
            raise ValueError(f'{name}: attachment file reused for another capture')
        record = image_record(path, base.resolve())
        width, height = record['size']
        if device == 'iphone' and (width, height) != (1206, 2622):
            raise ValueError(f'{name}: need actual medium Dynamic Island iPhone capture, got {width}x{height}')
        if device == 'ipad' and (width, height) != (2752, 2064):
            raise ValueError(f'{name}: need actual landscape 13-inch iPad capture, got {width}x{height}')
        if record['pixel_sha256'] in used_pixels:
            raise ValueError(f'{name}: duplicate capture pixels')
        used_paths.add(path)
        used_pixels.add(record['pixel_sha256'])
        records.append({'capture': name, **record})
    return records


def screenshot_records(out: Path, locale: str, device: str, base: Path) -> list[dict]:
    names = expected_captures(locale, device)
    wanted = {f'{device}-{locale}-{index:02d}.jpg' for index in range(1, len(names) + 1)}
    actual = {p.name for p in out.glob('*.jpg')}
    if actual != wanted:
        raise ValueError(f'{locale}/{device}: missing or extra rendered frames: {actual ^ wanted}')
    records = [image_record(out / name, base) for name in sorted(wanted)]
    size = [1206, 2622] if device == 'iphone' else [2752, 2064]
    if any(r['size'] != size for r in records):
        raise ValueError('Rendered screenshot has wrong size')
    if len({r['pixel_sha256'] for r in records}) != len(records):
        raise ValueError('Duplicate rendered screenshot pixels')
    sheet = out / f'{device}-{locale}-sheet.png'
    if not sheet.is_file():
        raise ValueError('Missing rendered contact sheet')
    return records + [image_record(sheet, base)]


def validate_manifest_assets(record: dict):
    """Validate the compact inventory too; a nonempty list is not complete evidence."""
    locale, kind = record['listing_locale'], record['kind']
    if record.get('lesson_resource_status') != 'shipped':
        raise ValueError('Required localized lesson resource is still pending')
    for field, minimum in [('language_evidence', 1), ('launch_evidence', len(selectors(kind)) if kind in ('iphone', 'ipad') else 4 if kind == 'preview-main' else 3)]:
        rows = record.get(field, [])
        event = 'VERIFIED' if field == 'language_evidence' else 'LAUNCH'
        if not isinstance(rows, list) or not all(isinstance(row, dict) for row in rows):
            raise ValueError(f'{field}: expected structured runtime evidence')
        text = '\n'.join('TIMBRE_CAPTURE_' + event + ' ' + json.dumps(row) for row in rows)
        validate_language_evidence(locale_spec(locale), text, event, minimum=minimum)
    files = record.get('assets', [])
    if not isinstance(files, list) or not files or not all(isinstance(row, dict) for row in files):
        raise ValueError('Missing structured asset inventory')
    paths = [row.get('path') for row in files]
    if any(not isinstance(path, str) or Path(path).is_absolute() or '..' in Path(path).parts for path in paths):
        raise ValueError('Invalid asset path')
    if len(set(paths)) != len(paths):
        raise ValueError('Duplicate asset inventory paths')
    if any(not re.fullmatch('[a-f0-9]{64}', row.get('sha256', '')) for row in files):
        raise ValueError('Missing/invalid asset hash')
    if kind in ('iphone', 'ipad'):
        captures = record.get('captures')
        if not isinstance(captures, list) or not all(isinstance(row, dict) for row in captures):
            raise ValueError('Expected a list of structured capture records')
        needed = expected_captures(locale, kind)
        if [row.get('capture') for row in captures] != needed:
            raise ValueError('Incomplete capture inventory')
        if any(not re.fullmatch('[a-f0-9]{64}', row.get('pixel_sha256', '')) for row in captures):
            raise ValueError('Missing actual capture pixel hashes')
        if len({row['pixel_sha256'] for row in captures}) != len(captures):
            raise ValueError('Duplicate actual capture pixels')
        wanted = {f'{kind}-{locale}-{i:02d}.jpg' for i in range(1, len(needed) + 1)}
        wanted.add(f'{kind}-{locale}-sheet.png')
        if {Path(path).name for path in paths} != wanted or len(paths) != len(wanted):
            raise ValueError('Missing or extra screenshot asset inventory')
        size = [1206, 2622] if kind == 'iphone' else [2752, 2064]
        if any(row.get('size') != size for row in files if row['path'].endswith('.jpg')):
            raise ValueError('Wrong screenshot dimensions in manifest')
    else:
        wanted = {'preview.mp4', 'poster.png', 'contact.png', 'PREVIEW.txt', 'cut.json', 'raw.mp4',
                  'record.json', 'events.jsonl', 'audio-check.log', 'semantic-audio-check.json'}
        if {Path(path).name for path in paths} != wanted or len(paths) != len(wanted):
            raise ValueError('Missing or extra preview evidence inventory')
        if any(not isinstance(row.get('bytes'), int) or row['bytes'] <= 0 for row in files):
            raise ValueError('Empty preview evidence file')


def aggregate(plan: dict, folder: Path, source_sha: str) -> dict:
    records, errors, seen, language_pixels = [], [], set(), {}
    expected = set()
    # A corrupt plan or manifest must produce an incomplete inventory, not crash
    # before inventory.json can explain the failure to the next reviewer.
    valid_plan = (isinstance(plan, dict) and isinstance(plan.get('locales'), list)
                  and isinstance(plan.get('kinds'), list) and bool(plan['locales']) and bool(plan['kinds'])
                  and all(isinstance(x, str) for x in plan['locales'] + plan['kinds']))
    if valid_plan:
        valid_plan = (len(set(plan['locales'])) == len(plan['locales'])
                      and len(set(plan['kinds'])) == len(plan['kinds'])
                      and set(plan['locales']) <= set(locale_rows()) and set(plan['kinds']) <= set(KINDS))
    if not valid_plan:
        errors.append('Malformed plan: expected distinct known locales and asset kinds')
    else:
        expected = {(locale, kind) for locale in plan['locales'] for kind in plan['kinds']}
    for path in sorted(folder.rglob('*.manifest.json')):
        try:
            record = read_json(path)
        except (ValueError, OSError, UnicodeError) as error:
            errors.append(f'{path.name}: unreadable manifest JSON: {error}')
            continue
        if not isinstance(record, dict):
            errors.append(f'{path.name}: malformed manifest: expected an object')
            continue
        key = (record.get('listing_locale'), record.get('kind'))
        if not all(isinstance(value, str) for value in key):
            errors.append(f'{path.name}: malformed manifest locale/kind identifiers')
            continue
        if key not in expected or key in seen:
            errors.append(f'Unexpected or duplicate manifest: {key}')
            continue
        seen.add(key)
        if record.get('source_sha') != source_sha:
            errors.append(f'{key}: wrong source revision')
        spec = locale_spec(key[0])
        if any(record.get(k) != spec[k] for k in spec):
            errors.append(f'{key}: stale/wrong locale or payload provenance')
        if record.get('status') != 'mechanically_verified':
            errors.append(f'{key}: {record.get("status")}: {record.get("error", "unknown failure")}')
        if record.get('release_ready') is not False or record.get('visual_review') != 'pending' or record.get('native_review') != 'pending':
            errors.append(f'{key}: mechanical evidence cannot certify release or visual review')
        if record.get('status') == 'mechanically_verified':
            try:
                validate_manifest_assets(record)
            except (ValueError, TypeError, KeyError) as error:
                errors.append(f'{key}: malformed or incomplete asset evidence: {error}')
            else:
                if key[1] in ('iphone', 'ipad'):
                    signature = tuple(x['pixel_sha256'] for x in record['captures'])
                    previous = language_pixels.setdefault((key[1], signature), spec['app_language'])
                    if previous != spec['app_language']:
                        errors.append(f'{key}: identical complete capture pixels for different app languages')
        records.append(record)
    errors.extend(f'Missing locale/assets manifest: {key}' for key in sorted(expected - seen))
    builds = [r.get('build_sha256') for r in records]
    if not builds or any(not isinstance(x, str) or not re.fullmatch('[a-f0-9]{64}', x) for x in builds) or len(set(builds)) != 1:
        errors.append('Evidence must use one identified shared build artifact')
    return {'schema_version': 1, 'source_sha': source_sha, 'expected_sets': len(expected),
            'manifest_count': len(records), 'scope': plan, 'errors': errors,
            'status': 'mechanically_verified' if not errors else 'incomplete',
            'release_ready': False, 'visual_review': 'pending', 'native_review': 'pending',
            'note': 'Device/render evidence only. No upload, signing, account changes, or release approval.',
            'manifests': records}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    commands = parser.add_subparsers(dest='command', required=True)
    plan = commands.add_parser('plan')
    plan.add_argument('--locales', default='all')
    plan.add_argument('--scope', choices=['all', 'screenshots', 'previews'], default='all')
    plan.add_argument('--violin', action='store_true')
    plan.add_argument('--shard-size', type=int, default=2)
    plan.add_argument('--out', type=Path, required=True)
    plan.add_argument('--event', choices=['workflow_dispatch', 'push'], default='workflow_dispatch')
    plan.add_argument('--message', default='')
    plan.add_argument('--ref', default='refs/heads/main')
    commands.add_parser('fixtures')
    combined = commands.add_parser('aggregate')
    combined.add_argument('--plan', type=Path, required=True)
    combined.add_argument('--manifests', type=Path, required=True)
    combined.add_argument('--source-sha', required=True)
    combined.add_argument('--out', type=Path, required=True)
    args = parser.parse_args()
    if args.command == 'plan':
        request = request_scope(args.event, args.message, args.locales, args.scope, args.violin, args.ref)
        result = make_plan(request['locales'], request['scope'], request['violin'], args.shard_size)
        result['trigger'] = request['trigger']
        write_json(args.out, result)
        print(json.dumps(result['matrix'], separators=(',', ':')))
    elif args.command == 'fixtures':
        print(json.dumps(prepare_fixtures()))
    else:
        result = aggregate(read_json(args.plan), args.manifests, args.source_sha)
        write_json(args.out, result)
        print(f'{result["manifest_count"]}/{result["expected_sets"]} asset sets: {result["status"]}; visual review pending')
        for error in result['errors']:
            print(error, file=sys.stderr)
        return int(bool(result['errors']))
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
