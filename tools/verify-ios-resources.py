"""Verify the native app bundles every authored catalogue/photo/font resource."""
from pathlib import Path
import json
import re

root = Path(__file__).resolve().parents[1]
core = root / 'ios/Sources/TimbreCore/Resources'
resources = root / 'ios/Timbre/Resources'
catalog = json.loads((core / 'catalog.json').read_text(encoding='utf-8'))
photos = json.loads((core / 'photos.json').read_text(encoding='utf-8'))
assert len(catalog['instruments']) == 60
assert len(catalog['tunings']) == 102
assert len(catalog['families']) == 8
assert len(photos) == 71
assert len({p['asset'] for p in photos}) == 71
for photo in photos:
    for field in ['asset', 'thumbnail']:
        folder = resources / 'Assets.xcassets' / (photo[field] + '.imageset')
        manifest = json.loads((folder / 'Contents.json').read_text())
        assert all((folder / image['filename']).is_file() for image in manifest['images'])
    assert photo['source'] and photo['sha256'] and photo['origin']
for name in ['space_grotesk.ttf', 'inter.ttf', 'ibm_plex_mono.ttf', 'SpaceGrotesk-OFL.txt', 'Inter-OFL.txt', 'IBMPlexMono-OFL.txt']:
    assert (resources / 'Fonts' / name).is_file(), name
english = (resources / 'en.lproj/Localizable.strings').read_text(encoding='utf-8')
keys = set(re.findall(r'^"([^"]+)"\s*=', english, re.M))
missing = []
for source in (root / 'ios/Timbre/Views').rglob('*.swift'):
    for key in re.findall(r'"(timbre_[a-z0-9_]+)"', source.read_text(encoding='utf-8')):
        if key not in keys and not key.endswith('_'):
            missing.append(f'{source.relative_to(root)}: {key}')
assert not missing, '\n'.join(missing)
locales = list(resources.glob('*.lproj'))
assert len(locales) == 49
print(f'OK: 60 instruments, 102 tunings, 71 photos/142 images, 49 locales, 3 licensed fonts; all literal localization keys exist.')
