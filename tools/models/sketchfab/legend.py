#!/usr/bin/env python3
"""Put a colour key beside every "ids" render and one review sheet per model.

python3 tools/models/sketchfab/legend.py build/inspect
"""
import json
import sys
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont


def font(size):
    try:
        return ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf", size)
    except OSError:
        return ImageFont.load_default()


def keyed(image_path: Path, members: list) -> Image.Image:
    shot = Image.open(image_path).convert("RGB")
    rows = members[:70]
    panel = Image.new("RGB", (430, shot.height), (24, 24, 24))
    draw = ImageDraw.Draw(panel)
    small = font(12)
    for k, m in enumerate(rows):
        y = 8 + k * (shot.height - 16) // max(len(rows), 1) if len(rows) > 60 else 8 + k * 14
        rgb = tuple(int(c * 255) for c in m["color"])
        draw.rectangle([6, y, 22, y + 11], fill=rgb)
        draw.text((28, y - 1), f"{m['name'][:44]} ({m['vertices']})", font=small, fill=(230, 230, 230))
    if len(members) > len(rows):
        draw.text((6, shot.height - 18), f"+{len(members) - len(rows)} more", font=small, fill=(200, 160, 90))
    out = Image.new("RGB", (shot.width + panel.width, shot.height))
    out.paste(shot, (0, 0))
    out.paste(panel, (shot.width, 0))
    return out


def main():
    folder = Path(sys.argv[1])
    for inv_path in sorted(folder.glob("*.inventory.json")):
        inv = json.loads(inv_path.read_text())
        model_id = inv["id"]
        tiles = []
        for name in (f"{model_id}_overview.png", f"{model_id}_front.png"):
            if (folder / name).exists():
                tiles.append(Image.open(folder / name).convert("RGB").resize((560, 560)))
        for end in ("A", "B"):
            members = inv["ends"].get(end, {}).get("objects", [])
            for side in ("front", "back"):
                path = folder / f"{model_id}_end{end}_{side}_ids.png"
                if path.exists():
                    keyed(path, members).save(folder / f"{model_id}_end{end}_{side}_key.jpg", quality=88)
            tex = folder / f"{model_id}_end{end}_front.png"
            if tex.exists():
                tiles.append(Image.open(tex).convert("RGB").resize((560, 560)))
        if tiles:
            sheet = Image.new("RGB", (560 * len(tiles), 600), (18, 18, 18))
            for k, t in enumerate(tiles):
                sheet.paste(t, (k * 560, 40))
            d = ImageDraw.Draw(sheet)
            d.text((10, 8), f"{model_id}: {len(inv['objects'])} objects · source {inv['source']}", font=font(20), fill=(240, 200, 120))
            sheet.save(folder / f"{model_id}_sheet.jpg", quality=86)


if __name__ == "__main__":
    main()
