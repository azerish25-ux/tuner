#!/usr/bin/env python3
"""Install converted artist models into the app and retire the procedural ones.

python3 tools/models/install_artist_models.py <converted dir> [<converted dir> ...]

Each converted dir holds <model>.usdz, <model>.rig.json (with "credit" and "card2D")
and <model>_hero.png from tools/models/sketchfab/convert.py. MAPPING says which
instrument photographs each model stands for. Photos without an artist model fall
back to the 2D photo stage (photo-rigs.json), so every procedural model is removed.
"""
import hashlib
import json
import shutil
import sys
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
RES = ROOT / "ios/Timbre/Resources"
MODELS = RES / "Models"
ASSETS = RES / "Assets.xcassets"

# model id -> photo assets it represents on stage and in the library
MAPPING = {
    "guitar_acoustic": ["01_guitar_acoustic_guitar"],
    "guitar_classical": ["guitar_classical"],
    "guitar_electric": ["guitar_electric"],
    "bass_p4": ["06_bass_4_string_p_bass"],
    "mandolin": ["13_mandolin_mandolin"],
    "violin": ["17_bowed_strings_violin"],
    "cello": ["19_bowed_strings_cello"],
}
# Library entries that only exist as an artist model: their studio render is the photograph.
RENDER_PHOTOS = {
    "guitar_classical": ("guitar.acoustic.6", "Classical guitar"),
    "guitar_electric": ("guitar.acoustic.6", "Electric guitar"),
}
PHOTOS_JSON = ROOT / "ios/Sources/TimbreCore/Resources/photos.json"


def add_render_photo(model: str, hero: Image.Image, credit: dict) -> None:
    """Adds (or refreshes) a library photograph made from the model's studio render."""
    instrument, label = RENDER_PHOTOS[model]
    asset = model
    photo = hero.resize((960, 960), Image.LANCZOS)
    imageset(asset, photo)
    imageset(f"thumb_{asset}", hero.resize((320, 320), Image.LANCZOS))
    digest = hashlib.sha256((ASSETS / f"{asset}.imageset" / f"{asset}.png").read_bytes()).hexdigest()
    entry = {"instrumentId": instrument, "label": label, "asset": asset, "thumbnail": f"thumb_{asset}",
             "source": f"{model}_hero.png", "sha256": digest,
             "origin": f"render of “{credit['title']}” by {credit['author']} ({credit['url']}), CC {credit['license'].upper()}"}
    photos = json.loads(PHOTOS_JSON.read_text())
    photos = [p for p in photos if p["asset"] != asset]
    # Keep the variants together, right after the instrument's first photograph.
    at = max(i for i, p in enumerate(photos) if p["instrumentId"] == instrument) + 1
    photos.insert(at, entry)
    PHOTOS_JSON.write_text(json.dumps(photos, indent=2, ensure_ascii=False) + "\n")


def imageset(name: str, image: Image.Image) -> None:
    folder = ASSETS / f"{name}.imageset"
    if folder.exists():
        shutil.rmtree(folder)
    folder.mkdir(parents=True)
    image.save(folder / f"{name}.png", optimize=True)
    (folder / "Contents.json").write_text(json.dumps({
        "images": [{"filename": f"{name}.png", "idiom": "universal"}],
        "info": {"author": "xcode", "version": 1},
    }, indent=2) + "\n")


def main() -> None:
    found = {}
    for folder in map(Path, sys.argv[1:]):
        for rig in folder.glob("*.rig.json"):
            model = rig.name[: -len(".rig.json")]
            if model in MAPPING and (folder / f"{model}.usdz").is_file() and (folder / f"{model}_hero.png").is_file():
                found[model] = folder
    missing = sorted(set(MAPPING) - set(found))
    if missing:
        print("not converted yet (skipped):", ", ".join(missing))

    # Retire every procedural model, render and the old manifest entries.
    for path in list(MODELS.glob("*.usdz")) + list(MODELS.glob("*.rig.json")):
        path.unlink()
    for folder in ASSETS.glob("render_*.imageset"):
        shutil.rmtree(folder)
    photos_json = json.loads(PHOTOS_JSON.read_text())
    PHOTOS_JSON.write_text(json.dumps([p for p in photos_json if p["asset"] not in RENDER_PHOTOS or p["asset"] in found], indent=2, ensure_ascii=False) + "\n")

    photos = {}
    for model, folder in sorted(found.items()):
        rig = json.loads((folder / f"{model}.rig.json").read_text())
        assert rig.get("credit"), f"{model}: rig has no credit block"
        assert all(f"{s['anchor']}.peg" in rig.get("card2D", {}) for s in rig["strings"]), f"{model}: card2D incomplete"
        shutil.copy2(folder / f"{model}.usdz", MODELS / f"{model}.usdz")
        (MODELS / f"{model}.rig.json").write_text(json.dumps(rig, indent=1) + "\n")
        hero = Image.open(folder / f"{model}_hero.png").convert("RGBA")
        assert hero.width == hero.height, f"{model}: hero render must be square (card2D is normalised to it)"
        imageset(f"render_{model}", hero.resize((1024, 1024), Image.LANCZOS))
        if model in RENDER_PHOTOS:
            add_render_photo(model, hero, rig["credit"])
        for asset in MAPPING[model]:
            photos[asset] = model
    (MODELS / "models-manifest.json").write_text(json.dumps({"photos": photos}, indent=1, sort_keys=True) + "\n")
    print(f"installed {len(found)} artist models for {len(photos)} photos")


if __name__ == "__main__":
    main()
