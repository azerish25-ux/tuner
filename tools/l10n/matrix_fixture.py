#!/usr/bin/env python3
"""Generate exact shipped strings for the opt-in localization simulator matrix."""
import argparse
import json
import re
from pathlib import Path
import sys

sys.path.insert(0, str(Path(__file__).resolve().parent))
import report

KEYS = {
    'headline': 'Tune in seconds.\nThen learn to play.',
    'subline': 'Timbre listens and tells you exactly how you did.',
    'start': 'Get started',
    'tune': 'Tune',
    'learn': 'Learn',
    'progress': 'Progress',
}


def validate_locales(locales):
    if not locales or any(not re.fullmatch(r'[A-Za-z]+(?:-[A-Za-z0-9]+)*', code) for code in locales):
        raise ValueError('Locale codes must be nonempty identifiers without path components')
    if len(locales) != len(set(locales)):
        raise ValueError('Duplicate locale codes')


def check_workflow(path):
    # These deliberately simple literal shard rows are the workflow's complete matrix.
    rows = re.findall(r"^          - '([A-Za-z0-9,-]+)'$", path.read_text(), re.MULTILINE)
    locales = ','.join(rows).split(',')
    validate_locales(locales)
    shipped = {p.name.removesuffix('.lproj') for p in report.RES.glob('*.lproj') if p.name != 'en.lproj'}
    if len(locales) != 48 or set(locales) != shipped:
        raise ValueError(f'Matrix must cover all 48 translated locales exactly: missing={shipped - set(locales)}, extra={set(locales) - shipped}')


def fixture(locales):
    validate_locales(locales)
    result = {}
    for locale in locales:
        path = report.RES / f'{locale}.lproj/Localizable.strings'
        if not path.is_file():
            raise ValueError(f'Unknown locale: {locale}')
        table = report.read_strings(path)
        values = {}
        for field, key in KEYS.items():
            value = table.get(key)
            if not value or not value.strip() or (locale != 'en' and field in ('headline', 'subline') and value == key):
                raise ValueError(f'{locale}: untranslated matrix field {field}')
            values[field] = value
        result[locale] = values
    return result


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--locales', required=True, help='Comma-separated locale codes')
    parser.add_argument('--out', type=Path, required=True)
    parser.add_argument('--check-workflow', type=Path, help='Require exactly all 48 translated locales in workflow shards')
    args = parser.parse_args()
    locales = args.locales.split(',')
    if args.check_workflow:
        check_workflow(args.check_workflow)
    data = fixture(locales)
    args.out.parent.mkdir(parents=True, exist_ok=True)
    args.out.write_text(json.dumps(data, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
    print(f'Wrote exact launch expectations for {len(data)} locales')


if __name__ == '__main__':
    main()
