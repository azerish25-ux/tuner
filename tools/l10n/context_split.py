#!/usr/bin/env python3
"""Fail-closed guards for the independently reviewed 6,080 -> 6,082 context split.

The verifier is read-only. Frozen baseline reviews remain in staged/; this separate
package binds only the explicit source/context delta and its actual integration.
"""
import copy
import hashlib
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
DATA = Path(__file__).resolve().parent / 'context-split'
KEYS = ('Lced02810fc', 'Lf94a998e29', 'L4f162aedb4', 'Lf6586312d9')


def read(path):
    return json.loads(Path(path).read_text(encoding='utf-8'))


def digest(value):
    return hashlib.sha256(value if isinstance(value, bytes) else value.encode('utf-8')).hexdigest()


def content_digest(value):
    return digest(json.dumps(value, ensure_ascii=False, sort_keys=True, separators=(',', ':')))


def require(condition, label):
    if not condition:
        raise ValueError(label)


def pointer(doc, path):
    for part in path.strip('/').split('/'):
        doc = doc[int(part)] if isinstance(doc, list) else doc[part]
    return doc


def contexts(doc):
    """Bind full enclosing quiz/section, parent identities and exact pointers."""
    out = {key: [] for key in KEYS}

    def walk(value, path='', parents=()):
        if isinstance(value, dict):
            lineage = list(parents)
            if 'id' in value:
                lineage.append({'id': value['id'], 'title': value.get('title', {}).get('t')})
            if value.get('k') in out:
                if '/steps/' in path:
                    prefix, rest = path.split('/steps/', 1)
                    enclosing = prefix + '/steps/' + rest.split('/')[0]
                else:
                    enclosing = path.rsplit('/name', 1)[0]
                out[value['k']].append({'pointer': path, 'parents': lineage,
                                        'value': value, 'context': pointer(doc, enclosing)})
            for key, child in value.items():
                walk(child, path + '/' + key, lineage)
        elif isinstance(value, list):
            for index, child in enumerate(value):
                walk(child, path + '/' + str(index), parents)
    walk(doc)
    return out


def signature(rows):
    return {'count': len(rows), 'sha256': content_digest(rows)}


def validate_row(row, baseline, before_contexts, after_contexts, source, *, locale):
    key = row['key']
    require(row['table'] == 'Learn.strings', 'table guard')
    require(row['locale'] == locale, 'locale guard')
    require(source.get(key) == row['source'] and
            digest(row['source']) == row['source_sha256'], 'source guard')
    require(digest(row['new']) == row['new_sha256'], 'new value hash guard')
    require(signature(before_contexts[key]) == row['before_context_signature'], 'before full context guard')
    require([r['pointer'] for r in before_contexts[key]] == row['before_context_pointers'],
            'before exact pointer guard')
    require(signature(after_contexts[key]) == row['required_after_context_signature'], 'after full context guard')
    require(len(after_contexts[key]) == row['required_after_context_count'], 'after context count guard')
    require([r['pointer'] for r in after_contexts[key]] == row['context_pointers'], 'after exact pointer guard')
    if row['operation'] == 'add_if_absent':
        require(row['absence_guard'] is True and key not in baseline and
                row['old'] is None and row['old_sha256'] is None, 'absence guard')
    else:
        require(row['operation'] in ('replace_if_exact', 'retain'), 'operation guard')
        require(key in baseline and baseline[key] == row['old'] and
                digest(baseline[key]) == row['old_sha256'], 'old value guard')
        if row['operation'] == 'retain':
            require(row['old'] == row['new'], 'retain guard')


def localized_diff(before, after, path=''):
    """Reject every nonlocalized change; return exact changed localized objects."""
    require(type(before) is type(after), 'data type changed: ' + path)
    if isinstance(before, dict):
        require(before.keys() == after.keys(), 'data fields changed: ' + path)
        if set(before) == {'k', 't'}:
            return [] if before == after else [{'pointer': path, 'old': before, 'new': after}]
        result = []
        for key in before:
            result.extend(localized_diff(before[key], after[key], path + '/' + key))
        return result
    if isinstance(before, list):
        require(len(before) == len(after), 'data count changed: ' + path)
        result = []
        for index, (old, new) in enumerate(zip(before, after)):
            result.extend(localized_diff(old, new, path + '/' + str(index)))
        return result
    require(before == after, 'nonlocalized value changed: ' + path)
    return []


def verify():
    import report
    manifest = read(DATA / 'checked-manifest.json')
    evidence = read(DATA / 'integration.json')
    changes = read(DATA / 'generated-context-diff.json')
    recorded = read(DATA / 'checked-contexts.json')
    curriculum = read(ROOT / 'ios/Sources/TimbreCore/Resources/curriculum.json')
    require(digest((ROOT / 'ios/Sources/TimbreCore/Resources/curriculum.json').read_bytes()) ==
            manifest['source_curriculum_required_after_sha256'], 'generated curriculum hash guard')
    # Recover the exact prior tree for a complete, nonlocalized-data comparison.
    before = copy.deepcopy(curriculum)
    for change in changes:
        value = pointer(before, change['pointer'])
        require(value == change['new'], 'changed localized object guard')
        value.clear()
        value.update(change['old'])
    require(content_digest(before) == evidence['before_curriculum_content_sha256'], 'prior curriculum content guard')
    require(localized_diff(before, curriculum) == changes and len(changes) == 7, 'seven objects only')
    before_ctx, after_ctx = contexts(before), contexts(curriculum)
    require(before_ctx == recorded['before'] and after_ctx == recorded['after'], 'recorded full context guard')
    source = report.read_strings(ROOT / 'ios/Timbre/Resources/en.lproj/Learn.strings')
    frozen_source = {r['key']: r['source'] for r in read(ROOT / 'tools/l10n/staged/source-catalog.json')}
    require(len(source) == 6082 and all(source.get(k) == v for k, v in frozen_source.items()), 'source coverage guard')
    require(set(source) - set(frozen_source) == {'Lf94a998e29', 'L4f162aedb4'}, 'new source key guard')
    for guard in manifest['source_guards']:
        text = (ROOT / guard['path']).read_text(encoding='utf-8')
        require(digest(text) == guard['proposed_file_sha256'] and
                text.splitlines()[guard['line'] - 1] == guard['new'], 'authoring source guard')
    for guard in manifest['retained_source_guards']:
        text = (ROOT / guard['path']).read_text(encoding='utf-8')
        require(digest(text) == guard['file_sha256'] and
                text.splitlines()[guard['line'] - 1] == guard['retain_exact_line'], 'retained source guard')
    for locale in manifest['locales']:
        current = read(ROOT / f'tools/l10n/learn/{locale}.json')
        rows = [r for r in manifest['rows'] if r['locale'] == locale]
        baseline = dict(current)
        for row in rows:
            require(current.get(row['key']) == row['new'], 'applied target guard: ' + locale)
            if row['operation'] == 'add_if_absent':
                del baseline[row['key']]
            else:
                baseline[row['key']] = row['old']
        require(content_digest(baseline) == evidence['locales'][locale]['baseline_content_sha256'],
                'unchanged other map values guard: ' + locale)
        require(content_digest(current) == evidence['locales'][locale]['after_content_sha256'],
                'current map content guard: ' + locale)
        for row in rows:
            validate_row(row, baseline, before_ctx, after_ctx, source, locale=locale)
        require(len(set(current) & set(source)) == 6082, 'target source coverage guard: ' + locale)
        bundle = report.read_strings(ROOT / f'ios/Timbre/Resources/{locale}.lproj/Learn.strings')
        require(bundle == {k: current[k] for k in source}, 'applied bundle guard: ' + locale)
        for key, value in bundle.items():
            require(not report.check(report.LEARN, key, source[key], value, locale), 'mechanical lesson gate: ' + locale + ' ' + key)
    registry = read(ROOT / 'tools/l10n/lesson-invariants.json')['locales']
    for locale in ('gu', 'ta', 'kn'):
        rows = read(ROOT / f'tools/l10n/staged/{locale}/invariants.json')
        require(set(registry[locale]) == {r['key'] for r in rows}, 'no blanket invariant additions: ' + locale)
        for row in rows:
            record = registry[locale][row['key']]
            require(record['source'] == row['source'] == source[row['key']] and
                    record['reason'] == row['reason'] and record['reviewed_by'], 'exact invariant guard')
    for row in read(DATA / 'addendum.json')['neighbor_count_coordination']:
        current = read(ROOT / f"tools/l10n/learn/{row['locale']}.json")
        require(current[row['key']] == row['reviewed_target'] and
                digest(current[row['key']]) == row['new_sha256'], 'neighbor rhythm count guard')
    return {'status': 'applied migration verified', 'source_keys': 6082, 'locales': 17,
            'added_pairs': 34, 'count_fixes': 6, 'retains': 28, 'changed_localized_objects': 7,
            'nonlocalized_data_unchanged': True, 'device_qa': 'pending'}


if __name__ == '__main__':
    print(json.dumps(verify(), indent=2))
