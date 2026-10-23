"""Verify the native app bundles every authored catalogue/photo/font resource."""
from pathlib import Path
import json
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
print(f'OK: 60 instruments, 102 tunings, {len(photos)} photos/{2 * len(photos)} images, 49 locales, 1 licensed font family, {len(manifest['photos'])} 3D models; all literal localization keys exist.')
