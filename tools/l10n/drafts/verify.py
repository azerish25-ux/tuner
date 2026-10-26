#!/usr/bin/env python3
"""Verify preserved partial draft bytes/source bindings; never import or certify them."""
import hashlib
import json
from pathlib import Path
import sys

BASE = Path(__file__).resolve().parent / 'ongoing'
sys.path.insert(0, str(BASE.parents[1]))
from apply_learn import LINE, unescape
ROOT = BASE.parents[3]
source = {key: unescape(value) for key, value in LINE.findall(
    (ROOT / 'ios/Timbre/Resources/en.lproj/Learn.strings').read_text())}
manifest = json.loads((BASE / 'manifest.json').read_text())
for name, expected in manifest['files'].items():
    assert hashlib.sha256((BASE / name).read_bytes()).hexdigest() == expected, name
for locale, count in manifest['counts'].items():
    data = json.loads((BASE / (locale + '.json')).read_text())
    assert data['status'] == 'partial-unreviewed-author-draft-not-imported'
    assert data['review_status'] == 'independent semantic review pending'
    rows = data['rows']
    assert len(rows) == len({r['key'] for r in rows}) == count == data['drafted_nonempty_entries']
    for row in rows:
        assert row['table'] == 'Learn.strings' and source[row['key']] == row['source']
        assert isinstance(row['translation'], str) and row['translation'].strip()
print('PASS: partial draft hashes and source bindings; semantic review and import remain pending')
