#!/usr/bin/env python3
"""Trim/centre studio renders, make app thumbnails and a review contact sheet."""
import sys
from pathlib import Path

from PIL import Image


def square(image, size, margin=0.06):
    box = image.getchannel("A").point(lambda a: 255 if a > 8 else 0).getbbox()
    if box:
        image = image.crop(box)
    side = int(max(image.size) * (1 + 2 * margin))
    canvas = Image.new("RGBA", (side, side), (0, 0, 0, 0))
    canvas.paste(image, ((side - image.width) // 2, (side - image.height) // 2), image)
    return canvas.resize((size, size), Image.LANCZOS)


def main():
    folder = Path(sys.argv[1])
    heroes = sorted(folder.glob("*_hero.png"))
    for hero in heroes:
        image = Image.open(hero).convert("RGBA")
        square(image, 1024).save(hero.with_name(hero.stem.replace("_hero", "_card") + ".png"))
        square(image, 320).save(hero.with_name(hero.stem.replace("_hero", "_thumb") + ".png"))
    renders = heroes + sorted(folder.glob("*_head.png"))
    if not renders:
        return
    cell = 384
    cols = 4
    rows = (len(renders) + cols - 1) // cols
    sheet = Image.new("RGB", (cols * cell, rows * cell), (16, 14, 13))
    for i, path in enumerate(renders):
        tile = square(Image.open(path).convert("RGBA"), cell, 0.03)
        sheet.paste(tile, ((i % cols) * cell, (i // cols) * cell), tile)
    sheet.save(folder / "contact_sheet.jpg", quality=88)


if __name__ == "__main__":
    main()
