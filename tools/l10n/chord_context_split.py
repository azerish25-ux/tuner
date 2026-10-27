#!/usr/bin/env python3
"""Verify the bounded major-chord/key context repair, not translation readiness.

The immutable source package records the exact 26 localized-object changes. A
successful source check does not approve any of the 816 target-context reviews.
Do not apply this source migration to a release without the reviewed addendum.
"""
import copy
import hashlib
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
DATA = Path(__file__).resolve().parent / 'chord-context-split'


def read(path):
    return json.loads(Path(path).read_text(encoding='utf-8'))


def digest(value):
    return hashlib.sha256(json.dumps(value, ensure_ascii=False, sort_keys=True,
                                     separators=(',', ':')).encode('utf-8')).hexdigest()


def require(condition, message):
    if not condition:
        raise ValueError(message)


def pointer(document, path):
    for part in path.strip('/').split('/'):
        document = document[int(part)] if isinstance(document, list) else document[part]
    return document


def validate_source(curriculum, english, manifest, changes):
    """Prove no lesson answers, audio, order, identifiers or old source text changed."""
    require(digest(curriculum) == manifest['after_curriculum_content_sha256'],
            'current curriculum content guard')
    require(digest(english) == manifest['after_english_content_sha256'],
            'current English source guard')
    require(len(changes) == manifest['changed_localized_objects'] == 26,
            'localized change count guard')
    require(len({row['pointer'] for row in changes}) == len(changes), 'duplicate pointer guard')
    before = copy.deepcopy(curriculum)
    for row in changes:
        require(set(row['old']) == set(row['new']) == {'k', 't'}, 'localized object guard')
        value = pointer(before, row['pointer'])
        require(value == row['new'], 'exact localized target guard')
        value.clear()
        value.update(row['old'])
    require(digest(before) == manifest['before_curriculum_content_sha256'],
            'unchanged nonlocalized content guard')
    old_english = dict(english)
    require(len(manifest['new_sources']) == 7, 'seven new source keys guard')
    for key, text in manifest['new_sources'].items():
        require(old_english.pop(key, None) == text, 'new source text guard')
    require(digest(old_english) == manifest['before_english_content_sha256'],
            'all old source keys retained unchanged guard')
    require(len(english) == manifest['source_key_count_after'] == 6090 and
            len(old_english) == manifest['source_key_count_before'] == 6083,
            'source counts guard')
    for key, text in manifest['retained_sources'].items():
        require(english.get(key) == text, 'retained context source guard')
    return before


def validate_review(row, source, contexts, baseline, *, locale):
    """Fail closed on later reviewed addenda; merely drafting a target is not review."""
    require(row['locale'] == locale and row['table'] == 'Learn.strings', 'review identity guard')
    key = row['key']
    require(source.get(key) == row['source'], 'review source guard')
    require(hashlib.sha256(row['source'].encode()).hexdigest() == row['source_sha256'],
            'review source hash guard')
    require(digest(contexts[key]) == row['after_context_sha256'], 'review full context guard')
    require([r['pointer'] for r in contexts[key]] == row['after_context_pointers'],
            'review exact pointers guard')
    old = baseline.get(key)
    require(old == row['before_target'], 'review exact old value guard')
    old_hash = hashlib.sha256(old.encode()).hexdigest() if old is not None else None
    require(old_hash == row['before_target_sha256'], 'review old value hash guard')
    if row['operation'] == 'add_if_absent':
        require(key not in baseline, 'review absence guard')
    else:
        require(row['operation'] == 'review_retained_context', 'review operation guard')
    require(isinstance(row['translation'], str) and bool(row['translation'].strip()),
            'review translation missing')
    require(row['status'] == 'independently reviewed' and
            isinstance(row.get('reviewed_by'), str) and bool(row['reviewed_by'].strip()),
            'independent review missing')


def verify_source():
    import report
    manifest = read(DATA / 'manifest.json')
    curriculum = read(ROOT / 'ios/Sources/TimbreCore/Resources/curriculum.json')
    english = report.read_strings(ROOT / 'ios/Timbre/Resources/en.lproj/Learn.strings')
    validate_source(curriculum, english, manifest, read(DATA / 'changes.json'))
    for row in manifest['source_file_guards']:
        actual = hashlib.sha256((ROOT / row['path']).read_bytes()).hexdigest()
        require(actual == row['after_sha256'], 'source file guard: ' + row['path'])
    queue = read(DATA / 'pending-addendum.json')
    require(queue['total_rows'] == len(queue['items']) == 816, 'target-context inventory guard')
    require(len(queue['locales']) == 51 and queue['rows_per_locale'] == 16,
            'all target locales guard')
    return {'source_correction_verified': True, 'localized_objects_changed': 26,
            'new_source_keys': 7, 'source_keys': 6090,
            'translation_context_reviews': 'pending', 'release_ready': False}


if __name__ == '__main__':
    print(json.dumps(verify_source(), indent=2))
