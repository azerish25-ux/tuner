#!/usr/bin/env python3
"""Inspect the signed archive before export/upload; never modifies signing.

Apple entitlement inspection: https://developer.apple.com/library/archive/technotes/tn2415/
Source policy alone cannot establish the settings/entitlements in a signed app.
"""
import argparse
import importlib.util
import os
from pathlib import Path
import plistlib
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[2]
MAIN_ID = 'com.shahradazerisharghi.timbre'
EXPECTED_IDS = {MAIN_ID, MAIN_ID + '.widgets', MAIN_ID + '.watchkitapp',
                MAIN_ID + '.watchkitapp.widgets'}
GC = 'com.apple.developer.game-center'
APP_GROUP = 'group.com.shahradazerisharghi.timbre'


class ArchiveError(Exception):
    pass


def checked_command(args, runner=subprocess.run):
    result = runner(args, capture_output=True, check=False)
    if result.returncode:
        # codesign diagnostics may contain signing identities: do not echo them.
        raise ArchiveError('Signed bundle inspection failed')
    return result.stdout


def signed_entitlements(bundle, runner=subprocess.run):
    checked_command(['codesign', '--verify', '--strict', str(bundle)], runner)
    raw = checked_command(['codesign', '--display', '--entitlements', ':-', str(bundle)], runner)
    try:
        data = plistlib.loads(raw)
    except (ValueError, plistlib.InvalidFileException):
        raise ArchiveError('Signed entitlements are missing or malformed') from None
    if not isinstance(data, dict):
        raise ArchiveError('Signed entitlements must be a dictionary')
    return data


def enabled(value):
    if value is True or (isinstance(value, str) and value in ('YES', 'true', '1')):
        return True
    if value is False or (isinstance(value, str) and value in ('NO', 'false', '0')):
        return False
    raise ArchiveError('Effective Game Center feature switch is missing or invalid')


def inspect_archive(archive, dispositions, env, read_entitlements=signed_entitlements):
    apps = list((archive / 'Products/Applications').glob('*.app'))
    if len(apps) != 1:
        raise ArchiveError('Archive must contain exactly one top-level app')
    main = apps[0]
    bundles = [main] + sorted(main.rglob('*.app')) + sorted(main.rglob('*.appex'))
    seen = set()
    for bundle in bundles:
        info = plistlib.loads((bundle / 'Info.plist').read_bytes())
        identifier = info.get('CFBundleIdentifier')
        if identifier not in EXPECTED_IDS or identifier in seen:
            raise ArchiveError('Unexpected or duplicate archive bundle identity')
        seen.add(identifier)
        if (info.get('CFBundleShortVersionString') != env['MARKETING_VERSION']
                or info.get('CFBundleVersion') != env['BUILD_NUMBER']):
            raise ArchiveError('Archive bundle version/build differs from approved inputs')
        entitlements = read_entitlements(bundle)
        if (entitlements.get('com.apple.developer.team-identifier') != env['APPLE_TEAM_ID']
                or entitlements.get('application-identifier') != env['APPLE_TEAM_ID'] + '.' + identifier):
            raise ArchiveError('Signed bundle team/application identity differs')
        if entitlements.get('com.apple.security.application-groups') != [APP_GROUP]:
            raise ArchiveError('Signed bundle App Group differs from the required shared group')
        gc_scope = dispositions.get('game_center_account')
        if gc_scope not in ('required', 'not_applicable'):
            raise ArchiveError('Unknown Game Center applicability')
        if gc_scope == 'not_applicable' and GC in entitlements:
            raise ArchiveError('Game Center signed entitlement contradicts omitted-feature policy')
        if bundle == main:
            active = enabled(info.get('TimbreGameCenterEnabled'))
            if gc_scope == 'not_applicable' and active:
                raise ArchiveError('Effective Game Center switch contradicts omitted-feature policy')
            if active and (gc_scope != 'required' or entitlements.get(GC) is not True):
                raise ArchiveError('Enabled Game Center requires applicable evidence and signed entitlement')
            if not active and GC in entitlements:
                raise ArchiveError('Disabled Game Center must not retain a signed entitlement')
            if info.get('TimbreBuildChannel', '') != env.get('BUILD_CHANNEL', ''):
                raise ArchiveError('Archive build channel differs from approved delivery inputs')
    if seen != EXPECTED_IDS:
        raise ArchiveError('Archive is missing a required companion or extension')
    return len(seen)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('archive', type=Path)
    args = parser.parse_args()
    try:
        spec = importlib.util.spec_from_file_location('store_scope', ROOT / 'tools/l10n/store.py')
        store = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(store)
        dispositions, errors = store.release_applicability(store.load('en-US'))
        if errors:
            raise ArchiveError('Release applicability policy is invalid or stale')
        count = inspect_archive(args.archive, dispositions, os.environ)
        print(f'Signed archive scope verified for {count} app/extension bundles; no upload performed.')
        return 0
    except (ArchiveError, OSError, ValueError, KeyError, TypeError, AttributeError) as error:
        message = str(error) if isinstance(error, ArchiveError) else 'Archive evidence is missing or malformed'
        print('Apple archive blocked: ' + message, file=sys.stderr)
        return 1


if __name__ == '__main__':
    raise SystemExit(main())
