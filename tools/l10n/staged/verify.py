#!/usr/bin/env python3
"""Read-only integrity verification of the pending localization checkpoint.

Run from anywhere. Does not import lessons, write registries, or certify release.
"""
import hashlib
import json
from pathlib import Path
import re
import sys

BASE = Path(__file__).resolve().parent
ROOT = BASE.parents[2]
DOC = ROOT / 'docs/l10n/staged'
LOCALES = ('ur', 'gu', 'ta', 'kn')


def read(path):
    return json.loads(path.read_text(encoding='utf-8'))


def digest(text):
    return hashlib.sha256(text.encode('utf-8')).hexdigest()


def file_digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def content_digest(rows):
    return digest(json.dumps(rows, ensure_ascii=False, sort_keys=True, separators=(',', ':')))


def main():
    catalog = read(BASE / 'source-catalog.json')
    source = {r['key']: r for r in catalog}
    assert len(source) == len(catalog) == 6080, 'source coverage'
    assert {r['batch'] for r in catalog} == set(range(1, 60)), 'batch coverage'
    for row in catalog:
        assert row['key'] == 'L' + hashlib.sha1(row['source'].encode()).hexdigest()[:10]
        assert row['source_sha256'] == digest(row['source'])
        assert row['table'] == 'Learn.strings'
        assert row['curriculum_pointers'] and len(set(row['curriculum_pointers'])) == len(row['curriculum_pointers'])
    result = {'source_keys': len(source), 'locales': {}}
    for loc in LOCALES:
        directory = BASE / loc
        candidate = read(directory / 'candidate.json')
        corrections = read(directory / 'corrections.json')
        invariant = read(directory / 'invariants.json')
        coverage = read(directory / 'coverage.json')
        baseline = read(directory / 'baseline.json')
        changes = {r['key']: r for r in corrections}
        cv = {r['key']: r for r in coverage}
        assert len(changes) == len(corrections) and len(cv) == len(coverage)
        assert set(candidate) == set(source) == set(cv)
        assert len({r['key'] for r in invariant}) == len(invariant)
        author = dict(candidate)
        for row in corrections:
            key = row['key']
            assert row['locale'] == loc and row.get('table', 'Learn.strings') == 'Learn.strings'
            assert row['source'] == source[key]['source']
            assert row['source_sha256'] == digest(row['source'])
            assert row['old_sha256'] == digest(row['old'])
            assert row['new_sha256'] == digest(row['new'])
            assert row['new'] == candidate[key] and row['old'] != row['new']
            author[key] = row['old']
        for row in invariant:
            key = row['key']
            assert row['source'] == source[key]['source']
            assert row['source_sha256'] == digest(row['source'])
            assert row['reason'].strip()
            assert row.get('locale', loc) == loc
            # Isolates may surround a genuine literal in Urdu; approval still binds exact source.
            assert re.sub('[\u2066-\u2069]', '', author[key]) == row['source']
        for key in source:
            assert isinstance(candidate[key], str) and candidate[key].strip()
            assert cv[key]['author_sha256'] == digest(author[key])
            assert cv[key]['candidate_sha256'] == digest(candidate[key])
        for name, values in [('author', author), ('candidate', candidate)]:
            assert baseline[name + '_content_sha256'] == content_digest([[k, source[k]['source'], values[k]] for k in sorted(values)])
        assert len(baseline['original_author_batch_file_sha256']) == 59 * 3
        result['locales'][loc] = {'pairs': len(candidate), 'corrections': len(corrections), 'source_bound_invariants': len(invariant)}
    partial = BASE / 'partial'
    if partial.exists():
        result['unreviewed_partial_captures'] = {}
        for loc in ('ml', 'mr', 'pa'):
            directory = partial / loc
            rows = read(directory / 'drafts.json')
            info = read(directory / 'capture.json')
            identities = read(directory / 'identity-candidates.json')
            assert len(rows) == len({r['key'] for r in rows}) == info['unique_draft_keys_preserved']
            assert len(identities) == info['identity_candidates_unapproved']
            for row in rows:
                assert row['source'] == source[row['key']]['source']
                assert row['source_sha256'] == digest(row['source'])
                assert row['variants']
                for variant in row['variants']:
                    assert variant['translation'] and variant['translation_sha256'] == digest(variant['translation'])
                    assert variant['origins']
            for row in identities:
                assert row['source'] == source[row['key']]['source']
                assert row['source_sha256'] == digest(row['source'])
                assert row['approval_status'] == 'unreviewed_candidate_only_not_registered'
            assert info['independent_review'] is False
            result['unreviewed_partial_captures'][loc] = {'draft_keys': len(rows), 'identity_candidates': len(identities)}
    parsed = 0
    for directory in (BASE, DOC):
        for path in directory.rglob('*.json'):
            read(path)
            parsed += 1
        for path in directory.rglob('*'):
            if path.is_file() and path.suffix != '.pyc':
                text = path.read_text(encoding='utf-8')
                assert not any(s in text for s in tuple('/' + name + '/' for name in ('root', 'tmp', 'workspace'))), f'private path: {path}'
    manifest = DOC / 'artifact-manifest.json'
    if manifest.exists():
        data = read(manifest)
        paths = {str(p.relative_to(ROOT)) for d in (BASE, DOC) for p in d.rglob('*') if p.is_file() and p != manifest and '__pycache__' not in str(p)}
        assert paths == set(data['files']), 'manifest file coverage'
        for name, record in data['files'].items():
            path = ROOT / name
            assert path.stat().st_size == record['bytes']
            assert file_digest(path) == record['sha256'], name
        result['manifest_files_verified'] = len(paths)
    result['json_files_parsed'] = parsed
    result['status'] = 'checkpoint integrity passed; not an import or release approval'
    print(json.dumps(result, indent=2))


if __name__ == '__main__':
    main()
