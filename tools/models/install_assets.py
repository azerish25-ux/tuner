#!/usr/bin/env python3
"""Install built 3D assets (from the CI results branch or a local build) into the app.

python3 tools/models/install_assets.py <built_dir>
Copies <id>.usdz and <id>.rig.json into ios/Timbre/Resources/Models, the studio card
render into Assets.xcassets/render_<id>.imageset, and writes models-manifest.json.
"""
import json
import shutil
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
MODELS = ROOT / "ios/Timbre/Resources/Models"
ASSETS = ROOT / "ios/Timbre/Resources/Assets.xcassets"


def main():
    built = Path(sys.argv[1])
    manifest = json.loads((built / "manifest.json").read_text())
    MODELS.mkdir(parents=True, exist_ok=True)
    installed = []
    for model_id in manifest["models"]:
        usdz, rig, card = built / f"{model_id}.usdz", built / f"{model_id}.rig.json", built / f"{model_id}_card.png"
        if not (usdz.exists() and rig.exists() and card.exists()):
            print("skip", model_id)
            continue
        shutil.copy2(usdz, MODELS / usdz.name)
        data = json.loads(rig.read_text())
        data.pop("hero2D", None)
        (MODELS / rig.name).write_text(json.dumps(data, separators=(",", ":")))
        imageset = ASSETS / f"render_{model_id}.imageset"
        imageset.mkdir(exist_ok=True)
        shutil.copy2(card, imageset / f"render_{model_id}.png")
        (imageset / "Contents.json").write_text(json.dumps({
            "images": [{"filename": f"render_{model_id}.png", "idiom": "universal"}],
            "info": {"author": "xcode", "version": 1},
        }, indent=2))
        installed.append(model_id)
    photos = {asset: model for asset, model in manifest["photos"].items() if model in installed}
    existing = MODELS / "models-manifest.json"
    if existing.exists():
        previous = json.loads(existing.read_text()).get("photos", {})
        previous.update(photos)
        photos = previous
    existing.write_text(json.dumps({"photos": photos}, indent=1, sort_keys=True))
    print("installed", installed)


if __name__ == "__main__":
    main()
