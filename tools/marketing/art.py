"""Art direction shared by the store frames (screenshots.py) and the App Preview (preview.py).

The palette is the app's own (ios/Timbre/Design/Theme.swift, "Studio Noir"): a near-black stage, mint for in tune,
gold for rewards (the stars' `starGold`), and the course hues (sky, violet, orchid, lime). Amber and coral are status
colours in the app (adjust, wrong), so no frame is washed in them. Type is the app's Sora. A frame's background takes the
accent of the feature it shows, so a set reads as a colour progression at thumbnail size instead of one dark image
repeated. Captions are set in Sora when it has every glyph, else in the first system font that does (CJK and
Cyrillic captions), or the one `--font` names.

Needs Pillow with libraqm, fontTools and regex (python3 -m pip install pillow fonttools regex).
"""
from __future__ import annotations

import os
from functools import lru_cache
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
FONTS = ROOT / "ios/Timbre/Resources/Fonts"
ASSETS = ROOT / "ios/Timbre/Resources/Assets.xcassets"
ICON = ASSETS / "AppIcon.appiconset/icon.png"

# Theme.swift
INK = (245, 243, 239)
STAGE = (6, 7, 8)
STAGE_RAISED = (17, 19, 23)
PAPER = (244, 240, 232)       # the one light frame: warm paper, the stage light's colour at its palest
PAPER_INK = (18, 20, 24)
TINTS = {
    "mint": (76, 242, 184),
    "sky": (98, 201, 255),
    "amber": (255, 181, 71),
    "violet": (165, 146, 255),
    "orchid": (227, 138, 219),
    "lime": (196, 232, 107),
    "gold": (240, 169, 59),
    "coral": (255, 126, 107),
    "flame": (255, 159, 67),
    "spotlight": (255, 196, 140),
    "frost": (159, 216, 255),
}

# Fonts with CJK and Cyrillic, in the order tried when Sora lacks a caption's glyphs (macOS first, then Linux).
FALLBACK_FONTS = [
    "/System/Library/Fonts/Hiragino Sans GB.ttc",
    "/System/Library/Fonts/ヒラギノ角ゴシック W6.ttc",
    "/System/Library/Fonts/AppleSDGothicNeo.ttc",
    "/System/Library/Fonts/PingFang.ttc",
    "/System/Library/Fonts/SFNS.ttf",
    "/System/Library/Fonts/Supplemental/Arial Unicode.ttf",
    "/usr/share/fonts/opentype/noto/NotoSansCJK-Bold.ttc",
    "/usr/share/fonts/opentype/noto/NotoSerifCJK-Bold.ttc",
    "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf",
    *[f"/usr/share/fonts/truetype/noto/NotoSans{script}-Bold.ttf" for script in
      ["Bengali", "Devanagari", "Gujarati", "Gurmukhi", "Kannada", "Malayalam", "Oriya", "Tamil", "Telugu", "Thai"]],
    "/usr/share/fonts/truetype/noto/NotoNaskhArabic-Bold.ttf",
    "/usr/share/fonts/truetype/noto/NotoNastaliqUrdu-Bold.ttf",
]
EXTRA_FONT = os.environ.get("TIMBRE_CAPTION_FONT")  # screenshots.py --font sets it


def tint(name: str) -> tuple:
    return TINTS.get(name, TINTS["mint"])


def mix(a: tuple, b: tuple, amount: float) -> tuple:
    """`a` moved `amount` (0…1) of the way to `b`."""
    return tuple(int(round(x + (y - x) * amount)) for x, y in zip(a, b))


@lru_cache(maxsize=64)
def sora(weight: str, size: int):
    from PIL import ImageFont
    return ImageFont.truetype(str(FONTS / f"Sora-{weight}.ttf"), size)


@lru_cache(maxsize=512)
def _cmap(path: str, index: int = 0) -> frozenset | None:
    """Glyphs in exactly the selected rendered face; never a union of collection faces."""
    try:
        from fontTools.ttLib import TTFont
        with TTFont(path, fontNumber=index, lazy=True) as face:
            return frozenset((face.getBestCmap() or {}).keys())
    except Exception:
        return None


@lru_cache(maxsize=128)
def collection_face(path: str, locale: str) -> int:
    if not path.lower().endswith(".ttc"):
        return 0
    wanted = "TC" if locale.startswith("zh-Hant") else "SC" if locale.startswith("zh") else "KR" if locale.startswith("ko") else "JP" if locale.startswith("ja") else None
    if wanted is None:
        return 0
    try:
        from fontTools.ttLib import TTCollection
        with TTCollection(path, lazy=True) as collection:
            for index, face in enumerate(collection.fonts):
                family = face["name"].getDebugName(1) or ""
                if family.endswith(" " + wanted) and ("Noto Sans CJK" in family or "Noto Serif CJK" in family or "PingFang" in family):
                    return index
    except Exception:
        pass
    return 0


def caption_locale() -> str:
    return os.environ.get("TIMBRE_CAPTION_LOCALE", "en-US")


def preferred_fallbacks() -> list[str]:
    locale = caption_locale()
    marker = "ヒラギノ" if locale.startswith("ja") else "AppleSDGothic" if locale.startswith("ko") else "PingFang" if locale.startswith("zh") else "DejaVu"
    return sorted(FALLBACK_FONTS, key=lambda path: 0 if marker and marker in path else 1)


def covers(path: str, text: str) -> bool:
    chars = _cmap(path, collection_face(path, caption_locale()))
    if chars is None:
        return False
    return all(ch.isspace() or ord(ch) in chars for ch in text)


@lru_cache(maxsize=1)
def system_fallbacks() -> tuple[str, ...]:
    """Discover installed macOS script fonts after the preferred families, without downloading fonts."""
    root = Path("/System/Library/Fonts")
    return tuple(str(p) for p in sorted(root.rglob("*")) if p.suffix.lower() in {".ttf", ".ttc", ".otf"}) if root.exists() else ()


def managed_fonts() -> list[str]:
    directory = Path(os.environ.get("TIMBRE_CAPTION_FONT_DIR", str(ROOT / "build/marketing-fonts")))
    if not directory.is_dir():
        return []
    locale = caption_locale()
    wanted = "NotoSansTC" if locale.startswith("zh-Hant") else "NotoSansSC" if locale.startswith("zh") else "NotoSansKR" if locale.startswith("ko") else "NotoSansJP" if locale.startswith("ja") else None
    cjk = ("NotoSansJP", "NotoSansKR", "NotoSansSC", "NotoSansTC")
    return [str(p) for p in sorted(directory.glob("*.ttf"))
            if not p.name.startswith(cjk) or (wanted and p.name.startswith(wanted))]


def fallback_font(path: str, weight: str, size: int):
    from PIL import ImageFont
    font = ImageFont.truetype(path, size, index=collection_face(path, caption_locale()))
    try:
        axes = font.get_variation_axes()
    except OSError:
        return font
    wanted = {"Bold": 700, "SemiBold": 600, "Medium": 500, "Regular": 400}.get(weight, 400)
    font.set_variation_by_axes([
        max(axis["minimum"], min(axis["maximum"], wanted)) if axis["name"] == b"Weight" else axis["default"]
        for axis in axes
    ])
    return font


def caption_font(text: str, weight: str, size: int):
    """Sora when it has every glyph of `text`, else the first fallback that does (raises when none does)."""
    from PIL import ImageFont, features
    try:
        import fontTools  # noqa: F401
    except ImportError:
        raise SystemExit("Caption glyph verification requires fontTools: python3 -m pip install fonttools")
    if any(ord(ch) > 0x02FF and not ch.isspace() for ch in text) and not features.check("raqm"):
        raise SystemExit("Unicode captions require Pillow with libraqm shaping; do not render unshaped text.")
    sora_path = str(FONTS / f"Sora-{weight}.ttf")
    if covers(sora_path, text):
        return sora(weight, size)
    for path in ([EXTRA_FONT] if EXTRA_FONT else []) + managed_fonts() + preferred_fallbacks() + list(system_fallbacks()):
        if path and Path(path).exists() and covers(path, text):
            return fallback_font(path, weight, size)
    raise SystemExit(f"No font has every character of “{text}”: pass --font <a .ttf/.ttc that does>")


def text_layout() -> dict:
    language = caption_locale()
    base = language.split("-")[0]
    return {"direction": "rtl" if base in {"ar", "fa", "he", "ur"} else "ltr", "language": language}


def line_step(font, lines: list[str], leading: float = 1.06) -> int:
    """Keep combining marks and descenders on adjacent shaped lines from overlapping."""
    import math
    bounds = [font.getbbox(line, anchor="la", **text_layout()) for line in lines if line]
    ink = max(box[3] for box in bounds) - min(box[1] for box in bounds) if bounds else 0
    return math.ceil(max(font.size * leading, ink + font.size * 0.08))


def wrap(text: str, font, width: float, lines: int = 2) -> list[str]:
    """One line when it fits; otherwise the break into `lines` lines whose longest line is shortest. Text without
    spaces (Japanese, Chinese) breaks between characters."""
    if font.getlength(text, **text_layout()) <= width:
        return [text]
    words = text.split()
    if len(words) > 1:
        units = words
    else:
        try:
            import regex
        except ImportError:
            raise SystemExit("Caption wrapping requires Unicode grapheme support: python3 -m pip install regex")
        units = regex.findall(r"\X", text)
    joiner = " " if len(words) > 1 else ""
    best = [text]
    best_width = float("inf")
    natural = None
    natural_width = float("inf")
    if lines >= 2:
        for i in range(1, len(units)):
            candidate = [joiner.join(units[:i]), joiner.join(units[i:])]
            if not joiner:
                # Japanese small kana/prolongation marks and closing punctuation stay
                # with the preceding grapheme, never stranded at a line's start.
                nonstarters = "、。，．？！：；ー々ゝゞヽヾぁぃぅぇぉっゃゅょゎァィゥェォッャュョヮヵヶ）］｝〉》」』】〕〗〙〛"
                openers = "（［｛〈《「『【〔〖〘〚"
                if candidate[1][0] in nonstarters or candidate[0][-1] in openers:
                    continue
            widest = max(font.getlength(line, **text_layout()) for line in candidate)
            if not joiner and candidate[0][-1] in "。！？、，" and widest <= width and widest < natural_width:
                natural, natural_width = candidate, widest
            if widest < best_width:
                best, best_width = candidate, widest
    return natural or best


def fit_lines(text: str, weight: str, size: int, smallest: int, width: float, lines: int = 2):
    """The largest size from `size` down to `smallest` at which `text` fits `width` in at most `lines` lines;
    returns (font, lines)."""
    if not (size >= smallest > 0 and width > 0 and lines > 0):
        raise ValueError("Invalid caption font size, width or line count")
    sizes = list(range(size, smallest - 1, -2))
    if sizes[-1] != smallest:
        sizes.append(smallest)
    for current in sizes:
        font = caption_font(text, weight, current)
        wrapped = wrap(text, font, width, lines)
        if len(wrapped) <= lines and all(font.getlength(line, **text_layout()) <= width for line in wrapped):
            return font, wrapped
    raise ValueError(f"Caption cannot fit {lines} lines at the minimum {smallest}px within {width}px: {text}")


def backdrop(size: tuple, accent: str, light: bool = False, glow: tuple = (0.5, 0.16), wash: float = 1.0):
    """A frame's stage: near-black washed with the feature's accent (or warm paper for the light frame), a soft glow
    of the accent behind the caption and a gentle falloff toward the bottom, so frames differ by hue at a glance."""
    from PIL import Image, ImageDraw, ImageFilter
    w, h = size
    colour = tint(accent)
    if light:
        top, bottom, glow_colour, glow_alpha = PAPER, mix(PAPER, colour, 0.10), mix(PAPER, colour, 0.35), 150
    else:
        top = mix(STAGE, colour, 0.20 * wash)
        bottom = mix(STAGE, colour, 0.05 * wash)
        glow_colour, glow_alpha = mix(STAGE, colour, 0.55 * wash), 170
    gradient = Image.linear_gradient("L").resize((w, h))
    base = Image.composite(Image.new("RGB", size, bottom), Image.new("RGB", size, top), gradient)
    halo = Image.new("L", size, 0)
    gx, gy = glow
    ImageDraw.Draw(halo).ellipse([w * (gx - 0.55), h * (gy - 0.16), w * (gx + 0.55), h * (gy + 0.20)], fill=glow_alpha)
    halo = halo.filter(ImageFilter.GaussianBlur(min(w, h) * 0.12))
    return Image.composite(Image.new("RGB", size, glow_colour), base, halo)


def rounded(image, radius: int, corners: tuple = (True, True, True, True)):
    """`image` with rounded corners (an RGBA copy)."""
    from PIL import Image, ImageDraw
    mask = Image.new("L", image.size, 0)
    ImageDraw.Draw(mask).rounded_rectangle([0, 0, image.width - 1, image.height - 1], radius=radius, fill=255, corners=corners)
    out = Image.new("RGBA", image.size, (0, 0, 0, 0))
    out.paste(image.convert("RGBA"), (0, 0), mask)
    return out


def drop_shadow(canvas, box: tuple, radius: int, blur: int, opacity: int, offset: int = 0):
    """A soft shadow under the rectangle `box` (x0, y0, x1, y1) on an RGBA canvas."""
    from PIL import Image, ImageDraw, ImageFilter
    pad = blur * 3
    x0, y0, x1, y1 = box
    layer = Image.new("RGBA", (int(x1 - x0) + 2 * pad, int(y1 - y0) + 2 * pad), (0, 0, 0, 0))
    ImageDraw.Draw(layer).rounded_rectangle([pad, pad, pad + x1 - x0, pad + y1 - y0], radius=radius, fill=(0, 0, 0, opacity))
    layer = layer.filter(ImageFilter.GaussianBlur(blur))
    canvas.alpha_composite(layer, (int(x0) - pad, int(y0) - pad + offset))


def outline(canvas, box: tuple, radius: int, colour: tuple, width: int = 3):
    from PIL import ImageDraw
    ImageDraw.Draw(canvas).rounded_rectangle(list(box), radius=radius, outline=colour, width=width)


def text_block(canvas, lines: list[str], font, centre_x: float, top: float, colour: tuple, leading: float = 1.06):
    """Centred lines from `top`; returns the y below the last line."""
    from PIL import ImageDraw
    draw = ImageDraw.Draw(canvas)
    step = line_step(font, lines, leading)
    y = top
    for line in lines:
        draw.text((centre_x, y), line, font=font, fill=colour, anchor="ma", **text_layout())
        y += step
    if lines:
        last_bottom = y - step + font.getbbox(lines[-1], anchor="ma", **text_layout())[3]
        y = max(y, last_bottom)
    return y


def app_icon(size: int):
    """The app icon at `size`, in the iOS squircle's corner radius (22.4 %)."""
    from PIL import Image
    with Image.open(ICON) as icon:
        picture = icon.convert("RGB").resize((size, size), Image.LANCZOS)
    return rounded(picture, int(size * 0.224))
