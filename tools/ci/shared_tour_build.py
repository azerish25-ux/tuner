#!/usr/bin/env python3
"""Same-run tour products: fail closed on source, toolchain, runtime or payload drift."""
import hashlib
import json
import os
from pathlib import Path
import platform
import plistlib
import re
import subprocess
import sys
import tarfile

ROOT = Path(__file__).resolve().parents[2]
PRODUCTS = ROOT / 'ios/build/dd/Build/Products'


def output(*args):
    return subprocess.check_output(args, cwd=ROOT, text=True).strip()


def digest(path):
    with path.open('rb') as stream:
        result = hashlib.sha256()
        for block in iter(lambda: stream.read(1024 * 1024), b''):
            result.update(block)
        return result.hexdigest()


def write(path, value):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(value, indent=2, sort_keys=True) + '\n')


def identity():
    sha = output('git', 'rev-parse', 'HEAD')
    if sha != os.environ['GITHUB_SHA'] or not re.fullmatch('[0-9a-f]{40}', sha):
        raise ValueError('Checkout is not the requested exact source')
    output('git', 'diff', '--exit-code', 'HEAD', '--', 'ios', 'tools/ci/shared_tour_build.py')
    return dict(sha=sha, run_id=os.environ['GITHUB_RUN_ID'], run_attempt=os.environ['GITHUB_RUN_ATTEMPT'])


def toolchain():
    return dict(xcode=output('xcodebuild', '-version'), sdk=output('xcrun', '--sdk', 'iphonesimulator', '--show-sdk-version'),
                sdk_build=output('xcrun', '--sdk', 'iphonesimulator', '--show-sdk-build-version'),
                machine=platform.machine(), macos=platform.mac_ver()[0])


def fixtures():
    # Absence is explicit too. A newly generated untracked fixture changes this map.
    paths = sorted(p for base in ('ios/TimbreUITests', 'ios/Tests/Fixtures')
                   for p in (ROOT / base).rglob('*') if p.suffix in ('.json', '.storekit'))
    return {str(p.relative_to(ROOT)): digest(p) for p in paths if p.is_file()}


def device(inventory, expected=None):
    candidates = []
    for runtime in inventory['runtimes']:
        if not runtime.get('isAvailable') or '.iOS-' not in runtime['identifier']:
            continue
        for item in inventory['devices'].get(runtime['identifier'], []):
            if not item.get('isAvailable') or not item['name'].startswith('iPhone'):
                continue
            scope = dict(runtime=runtime['identifier'], runtime_version=runtime['version'],
                         runtime_build=runtime['buildversion'], device_type=item['deviceTypeIdentifier'])
            if expected is None or scope == expected:
                candidates.append((tuple(map(int, runtime['version'].split('.'))), item['name'], item['udid'], scope))
    if not candidates:
        raise ValueError('No exact runtime/build/device-type match for shared test products')
    # Preserve existing first available iPhone within the newest runtime.
    newest = max(row[0] for row in candidates)
    chosen = next(row for row in candidates if row[0] == newest)
    return chosen[2], chosen[3]


def inventory_products(root):
    rows = {}
    for path in sorted(root.rglob('*')):
        relative = str(path.relative_to(root))
        if path.is_symlink():
            if not path.resolve().is_relative_to(root.resolve()):
                raise ValueError('Products symlink escapes archive')
            rows[relative] = dict(link=os.readlink(path))
        elif path.is_file():
            rows[relative] = dict(sha256=digest(path), mode=path.stat().st_mode & 0o777)
    if not rows:
        raise ValueError('Missing build products')
    return rows


def validate_xctestrun(root):
    paths = list(root.glob('*.xctestrun'))
    if len(paths) != 1:
        raise ValueError('Expected exactly one xctestrun')
    content = plistlib.loads(paths[0].read_bytes())
    def inspect(value):
        if isinstance(value, dict):
            for item in value.values():
                inspect(item)
        elif isinstance(value, list):
            for item in value:
                inspect(item)
        elif isinstance(value, str):
            # Producer-home absolute paths are not transferable, even when hosted paths happen to coincide.
            if '/Users/' in value or '/home/' in value:
                raise ValueError('xctestrun contains a producer-machine absolute path')
            for part in value.split(':'):
                if part.startswith('__TESTROOT__/'):
                    target = (root / part.removeprefix('__TESTROOT__/')).resolve()
                    if not target.is_relative_to(root.resolve()) or not target.exists():
                        raise ValueError('xctestrun test-root path is missing or escapes Products')
    inspect(content)
    return paths[0]


def architectures(root):
    result = {}
    for info_path in sorted(root.rglob('Info.plist')):
        bundle = info_path.parent
        if bundle.suffix not in ('.app', '.xctest'):
            continue
        info = plistlib.loads(info_path.read_bytes())
        executable = bundle / info['CFBundleExecutable']
        slices = sorted(output('lipo', '-archs', str(executable)).split())
        if platform.machine() not in slices:
            raise ValueError('Product cannot run on this worker architecture')
        result[str(executable.relative_to(root))] = slices
    if not result:
        raise ValueError('No executable app/test products found')
    return result


def validate_identity(info, current, tools, fixture_map):
    if info['identity'] != current or info['toolchain'] != tools or info['fixtures'] != fixture_map:
        raise ValueError('Shared build source/run/attempt/toolchain/fixture mismatch; rerun tour-build and its dependent jobs')


def safe_members(archive):
    for member in archive.getmembers():
        path = Path(member.name)
        if path.is_absolute() or '..' in path.parts or not path.parts or path.parts[0] != 'Products':
            raise ValueError('Unsafe shared archive path')
        if not (member.isfile() or member.isdir() or member.issym()):
            raise ValueError('Unsupported archive member type')
        if member.issym():
            target = Path(member.linkname)
            # Resolve against a fictitious root, rejecting links escaping Products.
            resolved = (Path('/archive') / path.parent / target).resolve()
            if target.is_absolute() or not resolved.is_relative_to(Path('/archive/Products')):
                raise ValueError('Unsafe shared archive symlink')


def select(directory):
    udid, scope = device(json.loads(output('xcrun', 'simctl', 'list', '--json')))
    write(directory / 'selection.json', dict(identity=identity(), toolchain=toolchain(), fixtures=fixtures(), simulator=scope))
    with open(os.environ['GITHUB_ENV'], 'a') as env:
        env.write(f'DEVICE_ID={udid}\n')


def pack(directory):
    info = json.loads((directory / 'selection.json').read_text())
    validate_identity(info, identity(), toolchain(), fixtures())
    xctestrun = validate_xctestrun(PRODUCTS)
    info.update(schema=1, products=inventory_products(PRODUCTS), xctestrun=xctestrun.name, architectures=architectures(PRODUCTS))
    archive = directory / 'products.tgz'
    # Darwin bsdtar otherwise emits AppleDouble siblings such as ._Products outside
    # the declared tree. Product file bytes/modes/symlinks, not unbound xattrs, are transferred.
    metadata_options = ['--no-mac-metadata'] if platform.system() == 'Darwin' else []
    subprocess.run(['tar', *metadata_options, '-czf', str(archive.resolve()),
                    '-C', str(PRODUCTS.parent), 'Products'], check=True)
    # Fail the producer before publication if its tar emits anything consumers reject.
    with tarfile.open(archive) as contents:
        safe_members(contents)
    info['archive_sha256'] = digest(archive)
    write(directory / 'build-info.json', info)


def restore(directory):
    info = json.loads((directory / 'build-info.json').read_text())
    if info.get('schema') != 1:
        raise ValueError('Unsupported shared products schema')
    validate_identity(info, identity(), toolchain(), fixtures())
    archive = directory / 'products.tgz'
    if digest(archive) != info['archive_sha256']:
        raise ValueError('Shared archive hash mismatch')
    udid, scope = device(json.loads(output('xcrun', 'simctl', 'list', '--json')), info['simulator'])
    if PRODUCTS.exists():
        raise ValueError('Refusing to overlay existing build products')
    with tarfile.open(archive) as contents:
        safe_members(contents)
    PRODUCTS.parent.mkdir(parents=True, exist_ok=True)
    subprocess.run(['tar', '-xzf', str(archive.resolve()), '-C', str(PRODUCTS.parent)], check=True)
    if inventory_products(PRODUCTS) != info['products']:
        raise ValueError('Restored products differ from producer inventory')
    if architectures(PRODUCTS) != info['architectures']:
        raise ValueError('Restored executable architectures differ')
    xctestrun = validate_xctestrun(PRODUCTS)
    if xctestrun.name != info['xctestrun']:
        raise ValueError('Wrong test run specification')
    receipt = dict(identity=info['identity'], archive_sha256=info['archive_sha256'], toolchain=info['toolchain'],
                   fixtures=info['fixtures'], architectures=info['architectures'], simulator=scope, xctestrun_sha256=digest(xctestrun), device_id=udid)
    write(ROOT / 'ci-out/shared-build.json', receipt)
    with open(os.environ['GITHUB_ENV'], 'a') as env:
        env.write(f'DEVICE_ID={udid}\nXCTESTRUN={xctestrun}\n')


if __name__ == '__main__':
    action, location = sys.argv[1:]
    {'select': select, 'pack': pack, 'restore': restore}[action](Path(location))
