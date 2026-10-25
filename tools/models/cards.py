#!/usr/bin/env python3
"""Review and install the studio cards rendered by tools/models/render_cards.swift (workflow "Render instrument cards").

python3 tools/models/cards.py sheet <results> [--live <screenshots dir>]
    Lays the renders out for review: sheet-closeups.png puts each variant's phone close-up of the acoustic guitar and
    mandolin beside the live stage (10-tune-3d, 49-tune-mandolin-3d from an exported UI-test screenshots folder with
    its manifest.json, e.g. the ci-results/app branch's screenshots/), with the card's own headstock as the 2D stage
    zooms into it; sheet-cards.png shows every card, today's and each variant's, on the stage colour.

python3 tools/models/cards.py install <results> --variant <name> [--models a,b] [--photos] [--force]
    Copies <results>/cards/<variant>/render_<model>.png over Assets.xcassets/render_<model>.imageset (same name, size
    and RGBA). Each new card must cover the same silhouette as the one it replaces (card2D in the rigs points into it);
    a card rendered upside down is turned back. --photos also refreshes the library photographs made from the
    classical and electric cards (<model> 960 px and thumb_<model> 320 px) and their sha256 in photos.json.
"""
import hashlib
import io
import json
import sys
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[2]
ASSETS = ROOT / "ios/Timbre/Resources/Assets.xcassets"
MODELS = ROOT / "ios/Timbre/Resources/Models"
PHOTOS_JSON = ROOT / "ios/Sources/TimbreCore/Resources/photos.json"
# Library photographs that are the model's card (install_artist_models.RENDER_PHOTOS).
RENDER_PHOTOS = ("guitar_classical", "guitar_electric")
STAGE = (14, 12, 11, 255)
LIVE = {"guitar_acoustic": "10-tune-3d", "mandolin": "49-tune-mandolin-3d"}


def arg(name, default=None):
    return sys.argv[sys.argv.index(name) + 1] if name in sys.argv else default


def card_path(model):
    return ASSETS / f"render_{model}.imageset" / f"render_{model}.png"


def head_box(model, size):
    """The square around the card's pegs and nut (card2D), with a margin: what the 2D stage zooms into."""
    rig = json.loads((MODELS / f"{model}.rig.json").read_text())
    points = [p for key, p in rig.get("card2D", {}).items() if key.endswith((".peg", ".nut"))]
    xs, ys = [p[0] * size for p in points], [p[1] * size for p in points]
    cx, cy = (min(xs) + max(xs)) / 2, (min(ys) + max(ys)) / 2
    side = max(max(xs) - min(xs), max(ys) - min(ys)) * 1.5 + 24
    return (int(cx - side / 2), int(cy - side / 2), int(cx + side / 2), int(cy + side / 2))


def on_stage(image, size):
    tile = Image.new("RGBA", image.size, STAGE)
    tile.alpha_composite(image.convert("RGBA"))
    return tile.convert("RGB").resize(size, Image.LANCZOS)


def label(draw, xy, text):
    draw.rectangle((xy[0], xy[1], xy[0] + 7 * len(text) + 8, xy[1] + 16), fill=(0, 0, 0))
    draw.text((xy[0] + 4, xy[1] + 2), text, fill=(255, 255, 255))


def live_images(folder):
    """Stage crops of the live 3D captures, by model, from an exported screenshots folder (manifest.json)."""
    found = {}
    if not folder:
        return found
    folder = Path(folder)
    names = {}
    manifest = folder / "manifest.json"
    if manifest.is_file():
        for test in json.loads(manifest.read_text()):
            for item in test.get("attachments", []):
                names[item.get("suggestedHumanReadableName", "")] = folder / item["exportedFileName"]
    for path in folder.glob("*.png"):
        names.setdefault(path.name, path)
    for model, prefix in LIVE.items():
        match = sorted(p for name, p in names.items() if name.startswith(prefix + "_") or name.startswith(prefix + "."))
        if match and match[-1].is_file():
            shot = Image.open(match[-1]).convert("RGB")
            w, h = shot.size
            # The phone stage: below the header, above the mode buttons.
            found[model] = shot.crop((0, int(h * 0.125), w, int(h * 0.455)))
    return found


def sheet(results, live_folder):
    variants = sorted(p.name for p in (results / "cards").iterdir() if p.is_dir())
    models = sorted({p.stem[len("render_"):] for v in variants for p in (results / "cards" / v).glob("render_*.png")})
    live = live_images(live_folder)

    # Close-ups: live stage | variants' close-ups, and the card's headstock as the 2D stage shows it.
    tile = (402, 300)
    square = (300, 300)
    columns = [m for m in LIVE if m in models]
    width = len(columns) * tile[0] + 2 * square[0] + 10 * (len(columns) + 2)
    rows = ["live / today"] + variants
    out = Image.new("RGB", (width, len(rows) * (tile[1] + 10)), (40, 40, 40))
    draw = ImageDraw.Draw(out)
    for r, row in enumerate(rows):
        y = r * (tile[1] + 10)
        x = 0
        for model in columns:
            if r == 0:
                image = live.get(model)
                image = image.resize(tile, Image.LANCZOS) if image is not None else None
            else:
                path = results / "closeups" / f"{model}_{row}.png"
                image = Image.open(path).convert("RGB").resize(tile, Image.LANCZOS) if path.is_file() else None
            if image is not None:
                out.paste(image, (x, y))
            label(draw, (x + 4, y + 4), f"{row}: {model}" if r else f"live: {model}" + ("" if image is not None else " (missing)"))
            x += tile[0] + 10
        card = card_path("guitar_acoustic") if r == 0 else results / "cards" / row / "render_guitar_acoustic.png"
        if card.is_file():
            image = Image.open(card).convert("RGBA")
            out.paste(on_stage(image.crop(head_box("guitar_acoustic", image.width)), square), (x, y))
            out.paste(on_stage(image, square), (x + square[0] + 10, y))
        label(draw, (x + 4, y + 4), "today's card" if r == 0 else f"{row}: card")
    out.save(results / "sheet-closeups.png")

    # Every card: today's, then each variant's.
    size = 200
    rows = ["today"] + variants
    out = Image.new("RGB", (len(models) * (size + 6), len(rows) * (size + 6)), (40, 40, 40))
    draw = ImageDraw.Draw(out)
    for r, row in enumerate(rows):
        for c, model in enumerate(models):
            path = card_path(model) if r == 0 else results / "cards" / row / f"render_{model}.png"
            if path.is_file():
                out.paste(on_stage(Image.open(path), (size, size)), (c * (size + 6), r * (size + 6)))
            label(draw, (c * (size + 6) + 2, r * (size + 6) + 2), f"{row} {model}"[:26])
    out.save(results / "sheet-cards.png")
    print("wrote", results / "sheet-closeups.png", "and", results / "sheet-cards.png")


def silhouette(image):
    return np.asarray(image.convert("RGBA"))[..., 3] > 127


def overlap(a, b):
    return float((a & b).sum()) / max(1, float((a | b).sum()))


def png_bytes(image):
    buffer = io.BytesIO()
    image.save(buffer, format="PNG", optimize=True)
    return buffer.getvalue()


def install(results, variant, only, photos, force):
    folder = results / "cards" / variant
    if not folder.is_dir():
        raise SystemExit(f"no such variant: {folder}")
    before = after = 0
    installed = {}
    for path in sorted(folder.glob("render_*.png")):
        model = path.stem[len("render_"):]
        target = card_path(model)
        if only and model not in only:
            continue
        if not target.is_file():
            print("skip", model, "(no card in the app)")
            continue
        old, new = Image.open(target).convert("RGBA"), Image.open(path).convert("RGBA")
        if new.size != old.size:
            raise SystemExit(f"{model}: {new.size} render for a {old.size} card")
        if not silhouette(new).any():
            raise SystemExit(f"{model}: the render is empty")
        score = overlap(silhouette(new), silhouette(old))
        flipped = overlap(silhouette(new)[::-1], silhouette(old))
        if flipped > score + 0.2:
            print(f"{model}: rendered upside down, turned back")
            new = new.transpose(Image.FLIP_TOP_BOTTOM)
            score = flipped
        if score < 0.85 and not force:
            raise SystemExit(f"{model}: silhouette overlap {score:.2f} with today's card; card2D would point elsewhere (--force to install anyway)")
        data = png_bytes(new)
        before += target.stat().st_size
        after += len(data)
        target.write_bytes(data)
        installed[model] = new
        print(f"{model}: overlap {score:.3f}, {target.stat().st_size // 1024} KB")
    if photos:
        entries = json.loads(PHOTOS_JSON.read_text(encoding="utf-8"))
        for model in RENDER_PHOTOS:
            if model not in installed:
                continue
            for name, side in ((model, 960), (f"thumb_{model}", 320)):
                target = ASSETS / f"{name}.imageset" / f"{name}.png"
                data = png_bytes(installed[model].resize((side, side), Image.LANCZOS))
                before += target.stat().st_size
                after += len(data)
                target.write_bytes(data)
                if name == model:
                    digest = hashlib.sha256(data).hexdigest()
                    for entry in entries:
                        if entry["asset"] == model:
                            entry["sha256"] = digest
            print(f"{model}: library photograph and thumbnail refreshed")
        PHOTOS_JSON.write_text(json.dumps(entries, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    print(f"installed {len(installed)} cards from {variant}: {before // 1024} KB -> {after // 1024} KB")


def main():
    if len(sys.argv) < 3 or sys.argv[1] not in ("sheet", "install"):
        raise SystemExit(__doc__)
    results = Path(sys.argv[2])
    if sys.argv[1] == "sheet":
        sheet(results, arg("--live"))
    else:
        variant = arg("--variant")
        if not variant:
            raise SystemExit("install needs --variant <name> (see sheet-closeups.png)")
        only = set(filter(None, (arg("--models") or "").split(",")))
        install(results, variant, only, "--photos" in sys.argv, "--force" in sys.argv)


if __name__ == "__main__":
    main()
