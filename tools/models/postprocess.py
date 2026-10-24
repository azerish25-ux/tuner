#!/usr/bin/env python3
"""Trim/centre studio renders, make app thumbnails and a review contact sheet."""
import json
import sys
from pathlib import Path

from PIL import Image


def frame(image, margin=0.06):
    """Crop to content and pad to a centred square: returns (box, side, offset)."""
    box = image.getchannel("A").point(lambda a: 255 if a > 8 else 0).getbbox() or (0, 0, image.width, image.height)
    w, h = box[2] - box[0], box[3] - box[1]
    side = int(max(w, h) * (1 + 2 * margin))
    return box, side, ((side - w) // 2, (side - h) // 2)


def square(image, size, margin=0.06):
    box, side, offset = frame(image, margin)
    cropped = image.crop(box)
    canvas = Image.new("RGBA", (side, side), (0, 0, 0, 0))
    canvas.paste(cropped, offset, cropped)
    return canvas.resize((size, size), Image.LANCZOS)


def card_points(image, hero2d, margin=0.06):
    """Map normalised hero-render coordinates into the card image."""
    box, side, offset = frame(image, margin)
    out = {}
    for name, (u, v) in hero2d.items():
        out[name] = [round((u * image.width - box[0] + offset[0]) / side, 5), round((v * image.height - box[1] + offset[1]) / side, 5)]
    return out


def main():
    folder = Path(sys.argv[1])
    heroes = sorted(folder.glob("*_hero.png"))
    for hero in heroes:
        image = Image.open(hero).convert("RGBA")
        square(image, 1024).save(hero.with_name(hero.stem.replace("_hero", "_card") + ".png"))
        rig_path = hero.with_name(hero.stem.replace("_hero", "") + ".rig.json")
        if rig_path.exists():
            rig = json.loads(rig_path.read_text())
            if "hero2D" in rig:
                rig["card2D"] = card_points(image, rig["hero2D"])
                rig_path.write_text(json.dumps(rig, indent=1))
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
