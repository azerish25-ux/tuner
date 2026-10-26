#!/usr/bin/env python3
"""Audit shipped lesson text in ALL app languages, never mistaking fallback for completion.

python3 tools/l10n/lessons.py          # report only
python3 tools/l10n/lessons.py --strict # full-coverage release gate (expected to fail until translated)

Checks actual Learn.strings, not unapplied JSON deliveries. Identical English is conservatively pending
independent semantic review (including legitimate shared titles), unless explicitly reviewed in lesson-invariants.json;
no blanket allowlist or copied-English completion.
This mechanical check does not certify native-speaker quality or device rendering.
"""
import argparse
import json
from pathlib import Path
import report


def audit():
    english = report.read_strings(report.RES / 'en.lproj/Learn.strings')
    targets = report.lesson_locales()
    if not english or not targets:
        raise ValueError('English lesson source or required app locales are missing')
    result = {}
    for locale in targets:
        table = report.read_strings(report.RES / f'{locale}.lproj/Learn.strings')
        missing, rejected = [], {}
        for key, source in english.items():
            if key not in table:
                missing.append(key)
            else:
                issues = report.check(report.LEARN, key, source, table[key], locale)
                if issues:
                    rejected[key] = issues
        result[locale] = {'required': len(english), 'complete': len(english) - len(missing) - len(rejected),
                          'missing': missing, 'rejected': rejected}
    return result


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--strict', action='store_true')
    parser.add_argument('--out', type=Path, help='write JSON audit evidence')
    args = parser.parse_args()
    result = audit()
    gaps = 0
    for locale, row in result.items():
        gaps += len(row['missing']) + len(row['rejected'])
        print(f"{locale}: {row['complete']}/{row['required']} lessons; "
              f"{len(row['missing'])} absent, {len(row['rejected'])} rejected/English-identical")
    print(f"{'INCOMPLETE' if gaps else 'COMPLETE'}: {len(result)} target locales, {gaps:,} unresolved lesson pairs")
    if args.out:
        args.out.parent.mkdir(parents=True, exist_ok=True)
        args.out.write_text(json.dumps(result, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
    return int(args.strict and gaps > 0)


if __name__ == '__main__':
    raise SystemExit(main())
