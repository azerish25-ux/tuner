"""Art direction shared by the store frames (screenshots.py) and the App Preview (preview.py).

The palette is the app's own (ios/Timbre/Design/Theme.swift, "Studio Noir"): a near-black stage, mint for in tune,
amber for rewards, and the course accents (sky, violet, coral). Type is the app's Sora. A frame's background takes the
accent of the feature it shows, so a set reads as a colour progression at thumbnail size instead of one dark image
repeated. Captions are set in Sora when it has every glyph, else in the first system font that does (CJK and
Cyrillic captions), or the one `--font` names.

Needs Pillow (python3 -m pip install pillow).
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


@lru_cache(maxsize=32)
def _cmap(path: str) -> frozenset | None:
    """The characters a font file maps (None when fontTools can't read it: the caller then trusts the font)."""
    try:
        from fontTools.ttLib import TTCollection, TTFont
    except ImportError:
        return None
    try:
        if path.lower().endswith(".ttc"):
            fonts = TTCollection(path).fonts
        else:
            fonts = [TTFont(path, lazy=True)]
        chars: set = set()
        for face in fonts:
            table = face.getBestCmap() or {}
            chars.update(table.keys())
        return frozenset(chars)
    except Exception:
        return None


def covers(path: str, text: str) -> bool:
    chars = _cmap(path)
    if chars is None:
        return True
    return all(ch.isspace() or ord(ch) in chars for ch in text)


def caption_font(text: str, weight: str, size: int):
    """Sora when it has every glyph of `text`, else the first fallback that does (raises when none does)."""
    from PIL import ImageFont
    sora_path = str(FONTS / f"Sora-{weight}.ttf")
    if covers(sora_path, text):
        return sora(weight, size)
    for path in ([EXTRA_FONT] if EXTRA_FONT else []) + FALLBACK_FONTS:
        if path and Path(path).exists() and covers(path, text):
            return ImageFont.truetype(path, size)
    raise SystemExit(f"No font has every character of “{text}”: pass --font <a .ttf/.ttc that does>")


def wrap(text: str, font, width: float, lines: int = 2) -> list[str]:
    """One line when it fits; otherwise the break into `lines` lines whose longest line is shortest. Text without
    spaces (Japanese, Chinese) breaks between characters."""
    if font.getlength(text) <= width:
        return [text]
    words = text.split()
    units = words if len(words) > 1 else list(text)
    joiner = " " if len(words) > 1 else ""
    best = [text]
    best_width = float("inf")
    if lines >= 2:
        for i in range(1, len(units)):
            candidate = [joiner.join(units[:i]), joiner.join(units[i:])]
            widest = max(font.getlength(line) for line in candidate)
            if widest < best_width:
                best, best_width = candidate, widest
    return best


def fit_lines(text: str, weight: str, size: int, smallest: int, width: float, lines: int = 2):
    """The largest size from `size` down to `smallest` at which `text` fits `width` in at most `lines` lines;
    returns (font, lines)."""
    for current in range(size, smallest - 1, -2):
        font = caption_font(text, weight, current)
        wrapped = wrap(text, font, width, lines)
        if len(wrapped) <= lines and all(font.getlength(line) <= width for line in wrapped):
            return font, wrapped
    font = caption_font(text, weight, smallest)
    return font, wrap(text, font, width, lines)


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
    step = int(font.size * leading)
    y = top
    for line in lines:
        draw.text((centre_x, y), line, font=font, fill=colour, anchor="ma")
        y += step
    return y


def app_icon(size: int):
    """The app icon at `size`, in the iOS squircle's corner radius (22.4 %)."""
    from PIL import Image
    with Image.open(ICON) as icon:
        picture = icon.convert("RGB").resize((size, size), Image.LANCZOS)
    return rounded(picture, int(size * 0.224))
