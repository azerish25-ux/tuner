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
    'songs': 'Songs',
    'practice': 'Practice',
    'progress': 'Progress',
    'tuned': 'Tuned',
    'in_tune': 'In tune',
    'request_title': 'Request a song',
    'request_unavailable': 'Song requests are unavailable in this build.',
    'request_support': 'Contact support',
    'request_cancel': 'Cancel',
}


LESSON_KEYS = {
    'lesson_title': 'L377bdd369e',
    'lesson_heading': 'L35fd49f78b',
    'lesson_body': 'Ld7f60a63df',
}


def lesson_expectations(locale):
    """Only actual imported lesson text can enable an in-app lesson check."""
    path = report.RES / f'{locale}.lproj/Learn.strings'
    if not path.is_file():
        return {'lesson_status': 'pending'}
    table = report.read_strings(path)
    english = report.read_strings(report.RES / 'en.lproj/Learn.strings')
    values = {'lesson_status': 'available'}
    for field, key in LESSON_KEYS.items():
        source, value = english.get(key), table.get(key)
        if (not source or not source.strip() or not value or not value.strip() or
                (locale != 'en' and report.check(report.LEARN, key, source, value, locale))):
            raise ValueError(f'{locale}: missing or untranslated lesson matrix field {field}')
        values[field] = value
    return values


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
            # English uses literal source keys when its sparse table has no override.
            # Translation targets must still contain an actual value.
            value = table.get(key, key if locale == 'en' else None)
            if not value or not value.strip() or (locale != 'en' and field in ('headline', 'subline') and value == key):
                raise ValueError(f'{locale}: untranslated matrix field {field}')
            values[field] = value
        values.update(lesson_expectations(locale))
        # Mirror SongsView.title: preserve a translated course title (e.g. Italian Canzoni),
        # otherwise use the UI table rather than the curriculum's English fallback.
        course = report.read_strings(report.RES / f'{locale}.lproj/Learn.strings').get('Le1404b4267')
        source_course = report.read_strings(report.RES / 'en.lproj/Learn.strings').get('Le1404b4267', 'Songs')
        if course and course != source_course:
            values['songs'] = course
        result[locale] = values
    return result


def validate_log(expected, log):
    """A skipped test or omitted lesson check must not become green matrix evidence."""
    lines = set(log.splitlines())
    for locale, labels in expected.items():
        status = labels.get('lesson_status')
        if status not in ('available', 'pending'):
            raise ValueError(f'{locale}: unknown lesson fixture status')
        required = ['TIMBRE_L10N_MATRIX_TESTED ' + locale,
                    'TIMBRE_L10N_REQUEST_UNAVAILABLE_TESTED ' + locale,
                    ('TIMBRE_L10N_LESSON_TESTED ' if status == 'available' else 'TIMBRE_L10N_LESSON_PENDING ') + locale]
        forbidden = ('TIMBRE_L10N_LESSON_PENDING ' if status == 'available' else 'TIMBRE_L10N_LESSON_TESTED ') + locale
        if any(marker not in lines for marker in required) or forbidden in lines:
            raise ValueError(f'{locale}: missing or contradictory executed matrix/lesson evidence')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--locales', required=True, help='Comma-separated locale codes')
    parser.add_argument('--out', type=Path, required=True)
    parser.add_argument('--check-workflow', type=Path, help='Require exactly all 48 translated locales in workflow shards')
    parser.add_argument('--verify-log', type=Path, help='Require executed UI and imported-lesson markers')
    args = parser.parse_args()
    locales = args.locales.split(',')
    if args.check_workflow:
        check_workflow(args.check_workflow)
    data = fixture(locales)
    args.out.parent.mkdir(parents=True, exist_ok=True)
    args.out.write_text(json.dumps(data, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
    if args.verify_log:
        validate_log(data, args.verify_log.read_text(encoding='utf-8'))
        print('Executed UI/lesson markers agree with every fixture locale')
    print(f'Wrote exact launch expectations for {len(data)} locales')


if __name__ == '__main__':
    main()
