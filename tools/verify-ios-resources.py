"""Verify the native app bundles every authored catalogue/photo/font resource."""
from pathlib import Path
import json
import math
import re
import plistlib

root = Path(__file__).resolve().parents[1]
core = root / 'ios/Sources/TimbreCore/Resources'
resources = root / 'ios/Timbre/Resources'
catalog = json.loads((core / 'catalog.json').read_text(encoding='utf-8'))
photos = json.loads((core / 'photos.json').read_text(encoding='utf-8'))
assert len(catalog['instruments']) == 60
assert len(catalog['tunings']) == 102
assert len(catalog['families']) == 8
assert len(photos) >= 71
assert len({p['asset'] for p in photos}) == len(photos)
for photo in photos:
    for field in ['asset', 'thumbnail']:
        folder = resources / 'Assets.xcassets' / (photo[field] + '.imageset')
        manifest = json.loads((folder / 'Contents.json').read_text())
        assert all((folder / image['filename']).is_file() for image in manifest['images'])
    assert photo['source'] and photo['sha256'] and photo['origin']
for name in ['Sora-Light.ttf', 'Sora-Medium.ttf', 'Sora-SemiBold.ttf', 'Sora-Bold.ttf', 'Sora-OFL.txt']:
    assert (resources / 'Fonts' / name).is_file(), name
# 3D models: every installed model has its rig, render and anchors matching the catalogue.
models = resources / 'Models'
manifest = json.loads((models / 'models-manifest.json').read_text())
photo_by_asset = {p['asset']: p for p in photos}
for asset, model in manifest['photos'].items():
    assert asset in photo_by_asset, asset
    assert (models / f'{model}.usdz').is_file(), model
    rig = json.loads((models / f'{model}.rig.json').read_text())
    assert (resources / 'Assets.xcassets' / f'render_{model}.imageset' / f'render_{model}.png').is_file(), model
    assert rig.get('credit', {}).get('license') in ('by', 'cc0'), (model, 'artist models need a CC BY or CC0 credit')
    instrument = photo_by_asset[asset]['instrumentId']
    anchors = {c['anchorId'] for t in catalog['tunings'] if t['instrumentId'] == instrument for c in t['courses'] if c.get('anchorId')}
    rig_anchors = {s['anchor'] for s in rig['strings']}
    assert anchors <= rig_anchors or rig_anchors <= anchors, (model, anchors, rig_anchors)
    for s in rig['strings']:
        assert f"{s['anchor']}.peg" in rig.get('card2D', {}), (model, s['anchor'])
# 2D photo stage: points for every photograph with tuning anchors, inside the square canvas.
photo_rigs = json.loads((models / 'photo-rigs.json').read_text())
for photo in photos:
    anchors = {c['anchorId'] for t in catalog['tunings'] if t['instrumentId'] == photo['instrumentId'] for c in t['courses'] if c.get('anchorId')}
    if not anchors or photo['asset'] in manifest['photos']:
        continue
    points = photo_rigs.get(photo['asset'], {})
    named = {key.split('.')[0] for key in points}
    assert any(key.endswith('.peg') for key in points), ('photo stage points missing', photo['asset'])
    assert named <= anchors, (photo['asset'], named - anchors)
    assert all(len(p) == 2 and 0 <= p[0] <= 1 and 0 <= p[1] <= 1 for p in points.values()), photo['asset']
# Timers and stability windows use systemUptime only for in-app elapsed events.
# https://developer.apple.com/documentation/bundleresources/app-privacy-configuration/nsprivacyaccessedapitypes/nsprivacyaccessedapitype
privacy = plistlib.loads((resources / 'PrivacyInfo.xcprivacy').read_bytes())
assert {'NSPrivacyAccessedAPIType': 'NSPrivacyAccessedAPICategorySystemBootTime',
        'NSPrivacyAccessedAPITypeReasons': ['35F9.1']} in privacy['NSPrivacyAccessedAPITypes']
# UserDefaults (settings, and the App Group the widgets read) is a required-reason API: CA92.1 + 1C8F.1.
assert any(item['NSPrivacyAccessedAPIType'] == 'NSPrivacyAccessedAPICategoryUserDefaults' and {'CA92.1', '1C8F.1'} <= set(item['NSPrivacyAccessedAPITypeReasons'])
           for item in privacy['NSPrivacyAccessedAPITypes']), 'PrivacyInfo: declare UserDefaults reasons'
widget_privacy = plistlib.loads((root / 'ios/TimbreWidgets/PrivacyInfo.xcprivacy').read_bytes())
assert any(item['NSPrivacyAccessedAPIType'] == 'NSPrivacyAccessedAPICategoryUserDefaults' for item in widget_privacy['NSPrivacyAccessedAPITypes'])
english = (resources / 'en.lproj/Localizable.strings').read_text(encoding='utf-8')
keys = set(re.findall(r'^"([^"]+)"\s*=', english, re.M))
missing = []
for source in (root / 'ios/Timbre').rglob('*.swift'):
    for key in re.findall(r'"(timbre_[a-z0-9_]+)"', source.read_text(encoding='utf-8')):
        if key not in keys and not key.endswith('_'):
            missing.append(f'{source.relative_to(root)}: {key}')
assert not missing, '\n'.join(missing)
locales = list(resources.glob('*.lproj'))
assert len(locales) == 49
# Recorded instruments (tools/build-ios-samples.py): every manifest file present and nothing unlisted, licences that
# allow redistribution in a commercial app (CC0, or CC-BY with a credit), sources pinned on GitHub, pitches measured,
# the band's kit, bass and piano there, every file traced in docs/content/AUDIO-SOURCES.md, the total within budget.
samples = resources / 'Samples'
sample_manifest = json.loads((samples / 'manifest.json').read_text(encoding='utf-8'))
assert sample_manifest['version'] == 1 and sample_manifest['sampleRate'] == 44100
allowed_licences = {'CC0-1.0', 'CC-BY-3.0', 'CC-BY-4.0'}
sample_sources = sample_manifest['sources']
audio_doc = (root / 'docs/content/AUDIO-SOURCES.md').read_text(encoding='utf-8')
for key, source in sample_sources.items():
    assert source['licence'] in allowed_licences, (key, source['licence'])
    assert source['licenceURL'].startswith('https://creativecommons.org/'), key
    assert source['repo'].startswith('https://github.com/') and re.fullmatch(r'[0-9a-f]{40}', source['commit']), key
    assert source['title'] and source['author'], key
    assert source['commit'] in audio_doc and source['title'] in audio_doc, ('AUDIO-SOURCES.md must list', key)
voice_cases = {'guitar', 'bass', 'ukulele', 'mandolin', 'banjo', 'harp', 'piano', 'mallet', 'violin', 'cello', 'flute', 'reed', 'brass', 'voice'}
# The kit pieces BandSynth plays (Band.swift `Drum.piece`).
drum_pieces = {'kick', 'snare', 'hat', 'openhat', 'ride', 'crash', 'xstick', 'tomhi', 'tomlo', 'tamb', 'shaker'}
listed, sample_bytes, played_voices = set(), 0, set()
for inst in sample_manifest['instruments']:
    assert inst['kind'] in {'plucked', 'struck', 'sustained', 'drums'} and inst['zones'], inst['id']
    assert set(inst['voices']) <= voice_cases and not (set(inst['voices']) & played_voices), inst['id']
    played_voices |= set(inst['voices'])
    for zone in inst['zones']:
        path = samples / zone['file']
        assert path.is_file() and path.suffix == '.m4a', zone['file']
        assert zone['file'] not in listed, ('listed twice', zone['file'])
        listed.add(zone['file'])
        sample_bytes += path.stat().st_size
        assert zone['source'] in sample_sources, zone['file']
        assert zone['original'] and re.fullmatch(r'[0-9a-f]{64}( \+ [0-9a-f]{64})*', zone['sha256']), zone['file']
        assert f"`Samples/{zone['file']}`" in audio_doc, ('AUDIO-SOURCES.md must list', zone['file'])
        assert zone['gain'] > 0 and 0 < zone['velocity'] <= 1 and 0 <= zone['mark'] < zone['frames'] and zone['markLevel'] > 0, zone['file']
        if inst['kind'] == 'drums':
            assert zone['piece'] in drum_pieces, zone['file']
        else:
            equal_tempered = 440 * 2 ** ((zone['midi'] - 69) / 12)
            assert zone['hz'] > 0 and abs(1200 * math.log2(zone['hz'] / equal_tempered)) <= 35, zone['file']
            assert inst['coverage'][0] - 6 <= zone['midi'] <= inst['coverage'][1] + 6, zone['file']
        if 'loop' in zone:
            assert inst['kind'] == 'sustained' and 0 < zone['loop'][0] < zone['loop'][1] <= zone['frames'], zone['file']
    # Optional play-time voicing: a velocity-tracked darkening (single-layer plucked sets), paired courses (mandolin).
    assert inst.get('softFilter', False) in (True, False) and (not inst.get('softFilter') or inst['kind'] == 'plucked'), inst['id']
    assert 0 <= inst.get('pairCents', 0) <= 5, inst['id']
on_disk = {str(p.relative_to(samples)) for p in samples.rglob('*') if p.is_file() and p.name != 'manifest.json'}
assert on_disk == listed, ('unlisted or missing samples', sorted(on_disk - listed), sorted(listed - on_disk))
sample_sets = {inst['id']: inst for inst in sample_manifest['instruments']}
folders = {p.name for p in samples.iterdir() if p.is_dir()}
assert folders == set(sample_sets), ('sample folders without a manifest set, or sets without a folder', sorted(folders ^ set(sample_sets)))
assert all(z['file'].split('/')[0] == inst_id for inst_id, inst in sample_sets.items() for z in inst['zones']), 'a set\'s files live in its own folder'
assert {'drums', 'bass', 'piano'} <= set(sample_sets), 'the backing band needs drums, bass and piano'
assert {'kick', 'snare', 'hat', 'crash'} <= {z['piece'] for z in sample_sets['drums']['zones']}
# The band's electric guitar (let-ring comping and staccato chops) plays no instrument voice of its own.
for band_only in ('eguitar', 'chops'):
    if band_only in sample_sets:
        assert not sample_sets[band_only]['voices'] and sample_sets[band_only]['kind'] == 'plucked', band_only
assert {'guitar', 'piano', 'bass'} <= played_voices
assert sample_bytes <= 35_000_000, f'samples {sample_bytes / 1e6:.1f} MB over the 35 MB budget'
print(f'OK: 60 instruments, 102 tunings, {len(photos)} photos/{2 * len(photos)} images, 49 locales, 1 licensed font family, {len(manifest['photos'])} 3D models; all literal localization keys exist; {len(listed)} instrument samples ({sample_bytes / 1e6:.1f} MB, {len(sample_sets)} sets, {", ".join(sorted(sample_sources))}).')
