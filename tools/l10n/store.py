#!/usr/bin/env python3
"""Validate all 50 store text drafts, separately from release readiness.

No uploads or account changes. --release additionally requires the production
privacy URL and device/asset/account evidence. Text review follows the explicit
owner-selected policy, defaulting to human review when no policy is recorded.
Source-aware AI review never certifies native fluency, legal compliance, keyword
popularity, Apple approval or screenshots.
"""
from __future__ import annotations
import argparse
import hashlib
import json
import os
import re
import unicodedata
from pathlib import Path
from urllib.parse import urlsplit

ROOT = Path(__file__).resolve().parents[2]
DIRECTORY = ROOT / 'tools/l10n/store'
MANIFEST = ROOT / 'tools/l10n/store-locales.json'
REVIEW = ROOT / 'tools/l10n/store-review.json'
REVIEW_POLICIES = ('human', 'ai_source_aware')
RELEASE_EVIDENCE = ('privacy_policy', 'device', 'screenshots', 'app_preview',
                    'iap_account_limits', 'game_center_account')
LIMITS = {'name': 30, 'subtitle': 30, 'keywords': 100, 'promotional_text': 170,
          'description': 4000, 'whats_new': 4000}
EULA = 'https://www.apple.com/legal/internet-services/itunes/dev/stdeula/'

APPLICABILITY = ROOT / 'docs/ios/readiness/release-applicability.json'
APPLICABILITY_SOURCES = ('ios/project.yml', 'ios/Timbre/Services/GameCenter.swift',
                         'docs/ios/APP-STORE-LISTING.md', 'docs/ios/AUDIO-DEVICE-TESTS.md')
DEVICE_AUTHORIZATION = ('real device test is not possible depsite what the readme says , '
                        'regardless you should start doing what it needs to be fully ready for app store submission')
DEVICE_LIMITATIONS = ('microphone_start_stop', 'interruptions', 'speaker_leakage_grading',
                     'latency', 'wired_bluetooth_routes', 'haptics', 'watch_hardware',
                     'physical_voiceover_dynamic_type')


PRIVACY_RECEIPT_SCOPE = 'published_policy_and_source_alignment_only'
PRIVACY_BASE_SOURCES = (
    'docs/ios/PRIVACY.md', 'docs/site/privacy.html', 'docs/site/support.html',
    'ios/project.yml', 'ios/Package.swift',
)
PRIVACY_SHIPPING_TREES = ('ios/Timbre', 'ios/Sources', 'ios/TimbreWidgets',
                          'ios/TimbreWatch', 'ios/TimbreWatchWidgets')


def privacy_source_inventory():
    """Every shipped source producer/consumer plus app privacy/config/dependencies.

    Detect new source/config files as well as edits. Tests and generated build
    products are outside this evidence scope; app changes require a new review.
    """
    paths = set(PRIVACY_BASE_SOURCES)
    for directory in PRIVACY_SHIPPING_TREES:
        for path in (ROOT / directory).rglob('*'):
            if path.is_file() and (path.suffix in ('.swift', '.m', '.mm', '.c', '.cc', '.cpp', '.cxx',
                                                      '.h', '.hpp', '.xcconfig', '.plist', '.entitlements', '.xcprivacy')
                                   or path.name in ('InfoPlist.strings', 'Package.resolved')):
                paths.add(path.relative_to(ROOT).as_posix())
    for name in ('Package.resolved', 'ios/Package.resolved', 'ios/.swiftpm/configuration/Package.resolved'):
        if (ROOT / name).is_file():
            paths.add(name)
    return tuple(sorted(paths))


def privacy_receipt_path(reference):
    """Only ordinary files under the checkout; reject aliases and traversal."""
    if not isinstance(reference, str) or not reference or '\\' in reference:
        raise ValueError('invalid receipt path')
    relative = Path(reference)
    if relative.is_absolute() or any(part in ('.', '..') for part in reference.split('/')):
        raise ValueError('receipt path must be repository relative without traversal')
    trusted_root = ROOT.resolve()
    path = trusted_root
    for part in relative.parts:
        path = path / part
        if path.is_symlink():
            raise ValueError('receipt/source symlinks are not allowed')
    if not path.resolve().is_relative_to(trusted_root) or not path.is_file():
        raise ValueError('receipt/source file is absent or outside repository')
    return path


def privacy_evidence_errors(data):
    """Offline validation of bounded, timestamped publication/source evidence.

    Not a legal attestation, live uptime probe, signed-archive or portal check.
    """
    try:
        evidence = data['review']['evidence']['privacy_policy']
        if not isinstance(evidence, dict) or evidence.get('content_sha256') != content_hash(data):
            raise ValueError('malformed or stale listing evidence mapping')
        path = privacy_receipt_path(evidence.get('reference'))
        raw = path.read_bytes()
        if evidence.get('reference_sha256') != hashlib.sha256(raw).hexdigest():
            raise ValueError('receipt hash missing or stale')
        receipt = json.loads(raw)
        if not isinstance(receipt, dict) or type(receipt.get('schema_version')) is not int or receipt['schema_version'] != 1:
            raise ValueError('unsupported receipt schema')
        if receipt.get('scope') != PRIVACY_RECEIPT_SCOPE:
            raise ValueError('receipt scope must be publication/source only')
        from datetime import datetime
        if not isinstance(receipt.get('verified_utc'), str) or not receipt['verified_utc'].endswith('Z'):
            raise ValueError('missing UTC observation time')
        datetime.fromisoformat(receipt['verified_utc'].replace('Z', '+00:00'))
        if not re.fullmatch(r'[0-9a-f]{40}', receipt.get('source_revision', '')):
            raise ValueError('missing observed source revision')
        hashes = receipt.get('source_sha256')
        if not isinstance(hashes, dict) or set(hashes) != set(privacy_source_inventory()):
            raise ValueError('privacy source inventory differs')
        for name, digest in hashes.items():
            if hashlib.sha256(privacy_receipt_path(name).read_bytes()).hexdigest() != digest:
                raise ValueError('privacy source hash missing or stale: ' + name)
        if receipt.get('policy_source') != {'path': 'docs/ios/PRIVACY.md', 'sha256': hashes['docs/ios/PRIVACY.md']}:
            raise ValueError('policy source binding differs')
        listings = receipt.get('listing_content_sha256')
        inventory = {row['locale'] for row in json.loads(MANIFEST.read_text())['locales']}
        if not isinstance(listings, dict) or set(listings) != inventory or listings.get(data.get('locale')) != content_hash(data):
            raise ValueError('listing content binding missing or stale')
        routes = receipt.get('routes')
        if not isinstance(routes, list) or len(routes) != 2 or not all(isinstance(r, dict) for r in routes):
            raise ValueError('malformed publication routes')
        matches = [r for r in routes if r.get('url') == data.get('production_privacy_url')]
        if len(matches) != 1:
            raise ValueError('privacy URL missing or ambiguous in receipt')
        route = matches[0]
        if (type(route.get('status')) is not int or route['status'] != 200
                or route.get('bytes_equal_committed_html') is not True
                or route.get('source_html') != 'docs/site/privacy.html'
                or route.get('sha256') != hashes['docs/site/privacy.html']
                or route.get('content_type') != 'text/html'):
            raise ValueError('privacy publication bytes/status mismatch')
        limits = receipt.get('limitations')
        if not isinstance(limits, dict) or any(limits.get(key) != value for key, value in {
                'signed_archive': 'unverified', 'app_store_connect_answers': 'unverified',
                'legal_certification': 'not_performed'}.items()):
            raise ValueError('receipt must preserve separate archive/portal/legal limits')
    except (OSError, ValueError, TypeError, KeyError, AttributeError):
        return ['privacy_policy needs a valid hash-bound publication/source receipt']
    return []


def release_applicability(source, policy=None):
    """Return evidence dispositions plus errors; invalid policy never exempts a gate.

    This is repository scope evidence, not signed-build/portal verification. Delivery
    must separately inspect effective build settings and signed entitlements.
    """
    required = {field: 'required' for field in RELEASE_EVIDENCE}
    try:
        if policy is None:
            policy = json.loads(APPLICABILITY.read_text(encoding='utf-8'))
        if not isinstance(policy, dict) or set(policy) != {
                'schema_version', 'source_sha256', 'listing_source_sha256', 'evidence'}:
            raise ValueError('malformed policy fields')
        if type(policy['schema_version']) is not int or policy['schema_version'] != 1:
            raise ValueError('unsupported schema')
        hashes = policy['source_sha256']
        if not isinstance(hashes, dict) or set(hashes) != set(APPLICABILITY_SOURCES):
            raise ValueError('source inventory differs')
        for name in APPLICABILITY_SOURCES:
            if hashes[name] != hashlib.sha256((ROOT / name).read_bytes()).hexdigest():
                raise ValueError(f'source hash missing or stale: {name}')
        if policy['listing_source_sha256'] != content_hash(source):
            raise ValueError('listing source hash missing or stale')
        records = policy['evidence']
        if not isinstance(records, dict) or set(records) != {'app_preview', 'game_center_account', 'device'}:
            raise ValueError('evidence inventory differs')
        for field, record in records.items():
            if not isinstance(record, dict):
                raise ValueError(f'{field}: malformed record')
            status = record.get('status')
            if status == 'required':
                if set(record) != {'status'}:
                    raise ValueError(f'{field}: unexpected required-record fields')
                continue
            if field == 'device':
                if (set(record) != {'status', 'verification', 'scope', 'selected_by', 'authorization', 'limitations'}
                        or status != 'owner_waived' or record['verification'] != 'unverified'
                        or record['scope'] != 'repository_physical_device_qa_only'
                        or record['selected_by'] != 'owner'
                        or record['authorization'] != DEVICE_AUTHORIZATION
                        or record['limitations'] != list(DEVICE_LIMITATIONS)):
                    raise ValueError('device: invalid bounded owner waiver')
            elif field == 'app_preview':
                if (set(record) != {'status', 'selected_by', 'authorization', 'submission_scope'}
                        or status != 'not_applicable' or record['selected_by'] != 'owner'
                        or record['submission_scope'] != 'screenshots_only_no_preview_upload'
                        or not isinstance(record['authorization'], str)
                        or not record['authorization'].strip()):
                    raise ValueError('app_preview: explicit owner omission authorization missing')
            else:
                if (record != {'status': 'not_applicable', 'reason': 'disabled_in_release_source'}):
                    raise ValueError('game_center_account: invalid disabled-feature evidence')
                project = (ROOT / 'ios/project.yml').read_text(encoding='utf-8')
                # Deliberately accept only the canonical scalar source form. A
                # substring is unsafe: an enabled value could retain the expected
                # binding in a trailing comment. Quoted/flow/indirect forms and
                # duplicates require explicit review, not a guessed exemption.
                active_lines = [line for line in project.splitlines()
                                if line.strip() and not line.lstrip().startswith('#')]
                bindings = [line for line in active_lines if 'TimbreGameCenterEnabled' in line]
                settings = [line for line in active_lines
                            if re.search(r"TIMBRE_GAME_CENTER_ENABLED[\"']?\s*:", line)]
                binding_pattern = r'\s*TimbreGameCenterEnabled: *\$\(TIMBRE_GAME_CENTER_ENABLED\) *(?:#.*)?'
                setting_pattern = r'\s*TIMBRE_GAME_CENTER_ENABLED: *"NO" *(?:#.*)?'
                if (len(bindings) != 1 or not re.fullmatch(binding_pattern, bindings[0])
                        or len(settings) != 1 or not re.fullmatch(setting_pattern, settings[0])):
                    raise ValueError('game_center_account: release source is not explicitly disabled')
                if os.environ.get('TIMBRE_GAME_CENTER_ENABLED', 'NO') != 'NO':
                    raise ValueError('game_center_account: build environment override is not disabled')
                if 'com.apple.developer.game-center' in project or any(
                        'com.apple.developer.game-center' in path.read_text(encoding='utf-8')
                        for path in (ROOT / 'ios').rglob('*.entitlements')):
                    raise ValueError('game_center_account: Game Center entitlement present')
            required[field] = status
    except (OSError, ValueError, TypeError, KeyError) as exc:
        return {field: 'required' for field in RELEASE_EVIDENCE}, [f'release applicability: {exc}']
    return required, []


def release_applicability_errors(source, policy=None):
    return release_applicability(source, policy)[1]

def load(locale):
    return json.loads((DIRECTORY / f'{locale}.json').read_text(encoding='utf-8'))

def strings(value, path=''):
    if isinstance(value, str):
        yield path, value
    elif isinstance(value, dict):
        for key, child in value.items():
            yield from strings(child, path + '.' + key)
    elif isinstance(value, list):
        for i, child in enumerate(value):
            yield from strings(child, path + f'[{i}]')

def content_hash(data):
    """Hash the entire listing payload, not mutable review/provenance metadata."""
    payload = {k: v for k, v in data.items() if k not in ('review', 'provenance')}
    return hashlib.sha256(json.dumps(payload, ensure_ascii=False, sort_keys=True).encode()).hexdigest()


def load_review():
    if not REVIEW.exists():
        return {}
    return json.loads(REVIEW.read_text(encoding='utf-8'))


def selected_policy(registry, override=None):
    return override or registry.get('review_policy', {}).get('mode', 'human')


def ai_review_errors(data, source, registry):
    """Validate actual source-aware review evidence without relabeling it human."""
    errors = []
    policy = registry.get('review_policy', {})
    if (policy.get('mode') != 'ai_source_aware' or policy.get('selected_by') != 'owner'
            or not policy.get('authorization')):
        errors.append('AI review policy lacks explicit owner selection')
    source_record = registry.get('source', {})
    if source_record.get('content_sha256') != content_hash(source):
        errors.append('AI review source content hash is missing or stale')
    version = {'schema_version': source.get('schema_version'), 'counts': source.get('counts')}
    if source_record.get('version') != version:
        errors.append('AI review source version/counts are missing or stale')
    record = registry.get('locales', {}).get(data.get('locale'), {})
    if not record.get('reviewer') or record.get('method') != 'independent_source_aware_ai':
        errors.append('AI reviewer identity or source-aware method is missing')
    if record.get('status') != 'reviewed_identified_corrections_resolved':
        errors.append('AI review is incomplete or corrections are unresolved')
    if record.get('reviewed_content_sha256') != content_hash(data):
        errors.append('AI review current-content hash is missing or stale')
    if record.get('source_content_sha256') != content_hash(source):
        errors.append('AI review locale source hash is missing or stale')
    if record.get('unresolved_corrections') != []:
        errors.append('AI review unresolved corrections must be explicitly empty')
    if (not isinstance(record.get('identified_corrections'), int)
            or record.get('identified_corrections', -1) < 0
            or record.get('resolved_corrections') != record.get('identified_corrections')):
        errors.append('AI review identified corrections are not all resolved')
    return errors


def review_artifact_errors(registry):
    """Review evidence and exact-old corrections are durable, hash-bound artifacts."""
    errors = []
    artifacts = registry.get('independent_review', {}).get('artifacts', {})
    for name in ('evidence', 'corrections'):
        artifact = artifacts.get(name, {})
        path = ROOT / artifact.get('file', '')
        if not path.is_file():
            errors.append(f'review: missing {name} artifact')
        elif hashlib.sha256(path.read_bytes()).hexdigest() != artifact.get('sha256'):
            errors.append(f'review: {name} artifact hash differs')
    if errors:
        return errors
    evidence = json.loads((ROOT / artifacts['evidence']['file']).read_text(encoding='utf-8'))
    corrections = json.loads((ROOT / artifacts['corrections']['file']).read_text(encoding='utf-8'))
    if set(evidence) != set(registry.get('locales', {})):
        errors.append('review: independent evidence locale inventory differs')
    for locale, record in registry.get('locales', {}).items():
        if record.get('reviewed_content_sha256') != evidence.get(locale, {}).get('proposed_content_sha256'):
            errors.append(f'{locale}: review hash differs from independent reviewed proposal')
        count = sum(row['locale'] == locale for row in corrections)
        if record.get('identified_corrections') != count or record.get('resolved_corrections') != count:
            errors.append(f'{locale}: correction count differs from independent review artifact')
    return errors


def validate(data, source, release=False, registry=None, review_policy=None, applicability_policy=None):
    errors = []
    loc = data.get('locale', '?')
    def fail(message): errors.append(f'{loc}: {message}')
    for field in json.loads(MANIFEST.read_text())['required_fields']:
        if not data.get(field): fail(f'missing {field}')
    for path, value in strings({k:v for k,v in data.items() if k != 'review'}):
        if value != unicodedata.normalize('NFC', value): fail(f'{path}: not NFC')
        if not value.strip(): fail(f'{path}: empty text')
        if 'TRANSLATE:' in value or re.search(r'\{[^{}]+\}|%(?:\d+\$)?(?:@|lld|d|s)', value): fail(f'{path}: unresolved translation/count placeholder')
        if '\ufffd' in value or any(ord(c)<32 and c not in '\n\t' for c in value): fail(f'{path}: invalid/control character')
    for field, limit in LIMITS.items():
        text = data.get(field)
        if not isinstance(text,str): continue
        if len(unicodedata.normalize('NFC',text)) > limit: fail(f'{field}: {len(text)} characters; maximum {limit}')
        if loc not in ('en-US','en-AU','en-CA','en-GB') and field not in ('name','keywords') and text == source.get(field): fail(f'{field}: copied English source')
    if data.get('counts') != source['counts']: fail('counts differ from English source snapshot')
    for field in ('description','whats_new'):
        val=data.get(field,'')
        expected=('instruments','lessons') if field=='whats_new' else ('instruments','tunings','courses','lessons','songs_floor','originals')
        for key in expected:
            if not re.search(r'(?<!\d)'+str(source['counts'][key])+r'(?!\d)',val): fail(f'{field}: missing current {key} count {source["counts"][key]}')
    for field in ('description','promotional_text','whats_new'):
        expected=set(re.findall(r'\d+',source[field]))
        if field=='description': expected.add('2')  # Source says two-day trial reminder in words.
        unexpected=set(re.findall(r'\d+',data.get(field,'')))-expected
        if unexpected:fail(f'{field}: unsupported numeric literals {sorted(unexpected)}')
    if EULA not in data.get('description',''): fail('description: missing unchanged standard EULA URL')
    if '<privacy policy URL>' not in data.get('description','') and not data.get('production_privacy_url'): fail('description: missing privacy URL or explicit draft placeholder')
    for device in ('iphone','ipad'):
        field=device+'_screenshot_captions'; rows=data.get(field,[]); original=source[field]
        if [r.get('capture') for r in rows] != [r['capture'] for r in original]: fail(f'{field}: capture IDs/order differ from source')
        for i,(r,s) in enumerate(zip(rows,original),1):
            if not isinstance(r.get('caption'),str) or not isinstance(r.get('supporting_line'),str): fail(f'{field} #{i}: missing text');continue
            if len(r['caption'])>30: fail(f'{field} #{i}: caption {len(r["caption"])} >30')
            for f in ('caption','supporting_line'):
                if '|' in r[f]: fail(f'{field} #{i}: table separator in text')
                if set(re.findall(r'\d+',r[f]))-set(re.findall(r'\d+',s[f])): fail(f'{field} #{i}: new numeric literal in {f}')
    for cut, original in source['app_preview_captions'].items():
        actual=data.get('app_preview_captions',{}).get(cut,{})
        if set(actual)!=set(original): fail(f'app_preview_captions.{cut}: clip inventory differs')
        for key in original:
            if not actual.get(key):fail(f'app_preview_captions.{cut}.{key}: missing text')
    for field,limit in [('iap_display_names',30),('iap_descriptions',45),('game_center_leaderboard_names',100),('game_center_achievement_names',100),('game_center_achievement_descriptions',500)]:
        actual=data.get(field,{})
        if set(actual)!=set(source[field]):fail(f'{field}: product/achievement/leaderboard ID inventory differs')
        for key in source[field]:
            val=actual.get(key)
            if not isinstance(val,str) or not val.strip():fail(f'{field}.{key}: missing text')
            elif field=='iap_display_names' and len(val)<2:fail(f'{field}.{key}: minimum 2 characters')
            elif len(val)>limit:fail(f'{field}.{key}: {len(val)} > {limit}')
            elif field=='game_center_achievement_descriptions':
                def numbers(text):
                    return [re.sub(r'\D','',n) for n in re.findall(r'\d+(?:[, .\u00a0\u202f]\d{3})*',text)]
                required=numbers(source[field][key])
                actual_numbers=numbers(val)
                if any(n not in actual_numbers for n in required):fail(f'{field}.{key}: source numeric threshold missing')

    words=data.get('keywords','').split(',')
    if any(w!=w.strip() or not w for w in words):fail('keywords: empty term or whitespace beside comma')
    if len(set(w.casefold() for w in words))!=len(words):fail('keywords: duplicate term')
    pagewords=[]
    for page, assigned in data.get('custom_product_page_keywords',{}).items():
        for word in assigned:
            if word.casefold() not in [w.casefold() for w in words]: fail(f'page {page}: keyword {word!r} absent from field')
            if word.casefold() in pagewords:fail(f'page {page}: keyword assigned to multiple pages')
            pagewords.append(word.casefold())
    name=(data.get('name','')+' '+data.get('subtitle','')).casefold()
    for w in words:
        if w.casefold() in pagewords:continue
        pattern=re.escape(w.casefold()) if loc in ('ja','ko','zh-Hans','zh-Hant') else r'(?<!\w)'+re.escape(w.casefold())+r'(?!\w)'
        if w and re.search(pattern,name):fail(f'keyword {w!r} repeats name/subtitle without a page exception')
    review=data.get('review',{})
    if review.get('release_ready') is True:
        release=True
    registry = load_review() if registry is None else registry
    policy = selected_policy(registry, review_policy)
    if policy not in REVIEW_POLICIES:
        fail(f'unknown review policy {policy!r}')
    if policy == 'ai_source_aware' or review.get('ai_source_aware') == 'reviewed':
        for error in ai_review_errors(data, source, registry):
            fail(error)
    if release or review.get('privacy_policy') == 'verified':
        for error in privacy_evidence_errors(data):
            fail(error)
    if release:
        if '<privacy policy URL>' in data.get('description',''):fail('release: unresolved production privacy URL')
        privacy_url = data.get('production_privacy_url', '')
        parsed = urlsplit(privacy_url)
        if parsed.scheme != 'https' or not parsed.hostname or privacy_url not in data.get('description', ''):
            fail('release: production privacy URL must be HTTPS and present in description')
        dispositions, applicability_errors = release_applicability(source, applicability_policy)
        for error in applicability_errors:
            fail(error)
        required = tuple(field for field in RELEASE_EVIDENCE if dispositions[field] == 'required')
        if policy == 'human':
            required += ('native', 'market_search', 'legal_back_translation')
        for field in required:
            if review.get(field)!='verified':fail(f'release: {field} not verified')
            evidence_records = review.get('evidence', {})
            evidence = evidence_records.get(field, {}) if isinstance(evidence_records, dict) else {}
            if not isinstance(evidence, dict) or not evidence.get('reference') or evidence.get('content_sha256') != content_hash(data):
                fail(f'release: {field} needs a current-content evidence reference')
    return errors

def source_snapshot_errors(source):
    """Keep the JSON snapshot tied to unchanged English prose and current build counts."""
    import importlib.util
    spec = importlib.util.spec_from_file_location("store_source_screenshots", ROOT / "tools/marketing/screenshots.py")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    english = module.LISTING.read_text(encoding="utf-8")
    errors = []
    for key, heading in [('keywords','Keywords'),('promotional_text','Promotional text'),('description','Description'),('whats_new',"What's New")]:
        if source.get(key) != module._block_after(english, heading):
            errors.append(f'en-US: {key} snapshot differs from authoritative English source')
    for key, label in [('name','Name'),('subtitle','Subtitle')]:
        row = re.search(r'^\| '+label+r' \| (.*?) \|', english, re.M)
        if not row or source.get(key) != row.group(1):errors.append(f'en-US: {key} snapshot differs from source')
    counts = module.build_counts()
    for key,value in source['counts'].items():
        if counts.get(key)!=value:errors.append(f'en-US: {key} snapshot {value} differs from build {counts.get(key)}')
    for device in ('iphone','ipad'):
        expected=[dict(capture=c,caption=t,supporting_line=l) for c,t,l,_ in module.plan(device)]
        if source.get(device+'_screenshot_captions')!=expected:errors.append(f'en-US: {device} screenshot snapshot differs')
    for cut,page in [('main',None),('violin','violin')]:
        if source.get('app_preview_captions',{}).get(cut)!=module._preview_table(english,page):errors.append(f'en-US: {cut} preview snapshot differs')
    return errors


def sync_game_center():
    """Reuse available app text after lesson/UI imports; keep authored drafts for absent keys."""
    import report
    manifest=json.loads(MANIFEST.read_text())
    gc=(ROOT/'ios/Timbre/Services/GameCenterIDs.swift').read_text()
    progression=(ROOT/'ios/Sources/TimbreCore/Practice/Progression.swift').read_text()
    ids=set(re.findall(r'Badge\(id: "([^"]+)"',gc))
    badges={i:(t,d) for i,t,d in re.findall(r'Achievement\(id: "([^"]+)", title: "([^"]+)", detail: "([^"]+)"',progression) if i in ids}
    songs=re.findall(r'Song\(lesson: "([^"]+)", slug: "([^"]+)"',gc)
    curriculum=json.loads((ROOT/'ios/Sources/TimbreCore/Resources/curriculum.json').read_text())
    titles={l['id']:l['title'] for c in curriculum['courses'] for u in c['units'] for l in u['lessons']}
    source=load('en-US')
    for row in manifest['locales']:
        loc=row['locale'];app=row['app_locale']
        if not app or app=='en':continue
        data=load(loc)
        table=dict(report.read_strings(ROOT/f'ios/Timbre/Resources/{app}.lproj/Localizable.strings'))
        learn=dict(report.read_strings(ROOT/f'ios/Timbre/Resources/{app}.lproj/Learn.strings'))
        reused=[];pending=[]
        for field in ('game_center_achievement_names','game_center_achievement_descriptions'):
            for key,english in source[field].items():
                if table.get(english):data[field][key]=table[english];reused.append(key+':'+field)
        for key,english in source['game_center_leaderboard_names'].items():
            if not key.startswith('timbre.song.') and table.get(english):data['game_center_leaderboard_names'][key]=table[english]
        for lesson,slug in songs:
            key='timbre.song.'+slug;title=titles[lesson];value=learn.get(title['k'])
            if value:data['game_center_leaderboard_names'][key]=value;reused.append(key)
            else:pending.append(key)
        data['review']['song_title_alignment']={'state':'app_text_reused' if not pending else 'pending_app_alignment','pending_app_alignment':pending,'native_review':'not_verified'}
        data.setdefault('provenance',{})['game_center_app_reuse']={'app_locale':app,'reused_fields':reused,'note':'Available app values reused exactly; missing app values retain authored store drafts. Does not certify native or device review.'}
        DIRECTORY.joinpath(loc+'.json').write_text(json.dumps(data,ensure_ascii=False,indent=2)+'\n')

def sync_manifest():
    """Record factual draft/review validation; never promote release evidence."""
    manifest=json.loads(MANIFEST.read_text());source=load('en-US');registry=load_review()
    manifest['schema_version']=2
    manifest['content_directory']='tools/l10n/store'
    manifest['review_policy']=selected_policy(registry)
    for row in manifest['locales']:
        data=load(row['locale']);errors=validate(data,source,registry=registry)
        row['content_file']=f'tools/l10n/store/{row["locale"]}.json'
        row['state']='english_source' if row['locale']=='en-US' else 'ai_draft_structurally_valid' if not errors else 'ai_draft_incomplete'
        row['draft_validation']={'passed':not errors,'error_count':len(errors)}
        row['release_ready']=False
        row['release_blockers']=list(data['review'].get('blockers',[]))
        row['native_review']=data['review'].get('native','not_verified')
        row['device_review']=data['review'].get('device','not_verified')
        row['ai_source_aware_review']='current' if not ai_review_errors(data,source,registry) else 'missing_or_stale'
    MANIFEST.write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+'\n')

def check_all(release=False, review_policy=None):
    source=load('en-US'); errors=source_snapshot_errors(source);registry=load_review()
    if selected_policy(registry, review_policy) == 'ai_source_aware':
        errors += review_artifact_errors(registry)
        expected = {row['locale'] for row in json.loads(MANIFEST.read_text())['locales']}
        if set(registry.get('locales', {})) != expected:
            errors.append('review: AI evidence locale inventory differs from all 50 required listings')
    for row in json.loads(MANIFEST.read_text())['locales']:
        try: data=load(row['locale'])
        except (OSError,ValueError) as exc: errors.append(f'{row["locale"]}: {exc}');continue
        errors+=validate(data,source,release,registry,review_policy)
    return errors

def main():
    parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--release',action='store_true');parser.add_argument('--sync-manifest',action='store_true');parser.add_argument('--sync-game-center',action='store_true');parser.add_argument('--review-policy',choices=REVIEW_POLICIES,help='Audit a policy without changing the recorded owner selection');args=parser.parse_args()
    if args.sync_game_center:sync_game_center()
    if args.sync_manifest:sync_manifest()
    errors=check_all(args.release,args.review_policy)
    if args.release:
        dispositions, scope_errors = release_applicability(load('en-US'))
        if not scope_errors:
            print('Release evidence scope: ' + ', '.join(
                f'{field}={status}' + (' (physically unverified)' if status == 'owner_waived' else '')
                for field, status in dispositions.items()))
    for error in errors:print(error)
    print(f'50 listing locales checked: {len(errors)} problems. '+('Release gate.' if args.release else 'Draft text/review gate only; native, legal, market, device, assets and account evidence remain separate.'))
    return bool(errors)
if __name__=='__main__':raise SystemExit(main())
