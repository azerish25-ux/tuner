#!/usr/bin/env python3
"""Install pinned OFL caption fonts and audit all store caption glyphs (not app screenshots)."""
from __future__ import annotations
import argparse
import hashlib
import json
import os
from pathlib import Path
import urllib.request

ROOT = Path(__file__).resolve().parents[2]
MANIFEST = Path(__file__).with_name('caption-fonts.json')


def fetch_checked(url: str, digest: str, target: Path, commit: str) -> None:
    prefix = f'https://raw.githubusercontent.com/google/fonts/{commit}/ofl/'
    if not url.startswith(prefix):
        raise ValueError('Unapproved font source or filename')
    if target.exists():
        if hashlib.sha256(target.read_bytes()).hexdigest() != digest:
            raise ValueError(f'Unexpected existing font/cache bytes: {target.name}')
        return
    request = urllib.request.Request(url, headers={'User-Agent': 'Timbre caption font preparation'})
    with urllib.request.urlopen(request, timeout=90) as response:
        data = response.read(20_000_001)
    if len(data) > 20_000_000 or hashlib.sha256(data).hexdigest() != digest:
        raise ValueError(f'Font/license download hash mismatch: {target.name}')
    target.write_bytes(data)


def install(directory: Path) -> dict:
    manifest = json.loads(MANIFEST.read_text())
    directory.mkdir(parents=True, exist_ok=True)
    for font in manifest['fonts']:
        if Path(font['filename']).name != font['filename'] or '/' in font['family']:
            raise ValueError('Invalid font manifest filename')
        fetch_checked(font['url'], font['sha256'], directory / font['filename'], manifest['commit'])
        fetch_checked(font['license_url'], font['license_sha256'], directory / (font['family'] + '-OFL.txt'), manifest['commit'])
    return manifest


def caption_rows():
    for path in sorted((ROOT / 'tools/l10n/store').glob('*.json')):
        data = json.loads(path.read_text())
        for device in ['iphone_screenshot_captions', 'ipad_screenshot_captions']:
            for index, row in enumerate(data[device]):
                for field in ['caption', 'supporting_line']:
                    yield path.stem, f'{device}/{index}/{field}', row[field]
        for page, fields in data['app_preview_captions'].items():
            for field, text in fields.items():
                yield path.stem, f'app_preview_captions/{page}/{field}', text


def audit(directory: Path) -> dict:
    os.environ['TIMBRE_CAPTION_FONT_DIR'] = str(directory.resolve())
    import art
    checked = 0
    locales = set()
    failures = []
    fonts = {}
    for locale, field, text in caption_rows():
        checked += 1
        locales.add(locale)
        os.environ['TIMBRE_CAPTION_LOCALE'] = locale
        try:
            font = art.caption_font(text, 'SemiBold', 48)
            # Force actual shaping/measurement, not only a cmap lookup.
            font.getlength(text, **art.text_layout())
            name = Path(font.path).name + '#' + str(font.index)
            fonts[name] = fonts.get(name, 0) + 1
        except (SystemExit, ValueError, OSError) as error:
            failures.append({'locale': locale, 'field': field, 'error': str(error)})
    return {'caption_strings': checked, 'listing_locales': len(locales), 'failures': failures,
            'fonts_used': fonts, 'scope': 'Glyph coverage and shaping preflight only; not full layout, native-language or app screenshot certification.'}


def audit_layouts() -> dict:
    """Measure the existing plans without substituting English app captures."""
    import art
    import screenshots
    import preview
    failures = []
    checked = 0
    for locale in ["en-US"] + screenshots.LOCALES:
        os.environ["TIMBRE_CAPTION_LOCALE"] = locale
        for device in ["iphone", "ipad"]:
            for capture, title, line, look in screenshots.plan(device, locale=locale):
                layout = look.split()[0]
                landscape = device == "ipad" and "landscape" in capture
                size = screenshots.SIZES[device]
                if landscape:
                    size = size[::-1]
                unit = min(size) / 1320
                margin = round((120 if landscape else 96 if layout.startswith("offset") else 84) * unit)
                width = size[0] - 2 * margin - (round(40 * unit) if layout.startswith("offset") and not landscape else 0)
                for text, weight, start, minimum in [(title, "SemiBold", 136, 96), (line, "Medium", 56, 52)]:
                    checked += 1
                    try:
                        art.fit_lines(text, weight, round(start * unit), round(minimum * unit), width)
                    except (SystemExit, ValueError, OSError) as error:
                        failures.append({"locale": locale, "capture": capture, "error": str(error)})
    for locale, field, text in caption_rows():
        if not field.startswith("app_preview"):
            continue
        os.environ["TIMBRE_CAPTION_LOCALE"] = locale
        checked += 1
        end, note = field.endswith("/end"), field.endswith("/end-note")
        start, minimum, width = (38, 30, preview.WIDTH - 140) if note else (54, 40, preview.WIDTH - 120) if end else (80, 48, preview.WIDTH - 2 * preview.SCREEN_X)
        try:
            font, lines = art.fit_lines(text, "Medium" if end or note else "SemiBold", start, minimum, width, 2)
            if not end and not note:
                step = art.line_step(font, lines, 1.08)
                bounds = [font.getbbox(line, anchor="ma", **art.text_layout()) for line in lines]
                height = max(i * step + box[3] for i, box in enumerate(bounds)) - min(box[1] for box in bounds)
                if height > preview.BAND - 24:
                    raise ValueError("Preview caption exceeds its band")
        except (SystemExit, ValueError, OSError) as error:
            failures.append({"locale": locale, "field": field, "error": str(error)})
    return {"layout_strings": checked, "layout_failures": failures,
            "layout_scope": "Existing screenshot caption widths and preview caption widths/band heights; not underlying app layout or final composed image review."}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--directory', type=Path, default=ROOT / 'build/marketing-fonts')
    parser.add_argument('--audit', action='store_true')
    parser.add_argument('--out', type=Path)
    args = parser.parse_args()
    manifest = install(args.directory)
    result = audit(args.directory) if args.audit else {'installed_fonts': len(manifest['fonts'])}
    if args.audit and not result.get('failures'):
        result.update(audit_layouts())
    result['font_source_commit'] = manifest['commit']
    if args.out:
        args.out.parent.mkdir(parents=True, exist_ok=True)
        args.out.write_text(json.dumps(result, ensure_ascii=False, indent=2) + '\n')
    print(json.dumps(result, ensure_ascii=False))
    return 1 if result.get('failures') or result.get('layout_failures') else 0


if __name__ == '__main__':
    raise SystemExit(main())
