#!/usr/bin/env python3
"""Find artist-made 3D instrument models that a paid app may ship.

python3 tools/scout/scout.py <out> [instrument,instrument...]
Sketchfab: downloadable models under CC0 or CC-BY only (NC, ND and SA are excluded),
ranked by likes, each licence confirmed on the model's own page. Poly Haven: CC0 models
whose name or tags match. Writes results.json and one contact sheet per instrument.
Searching needs no account; downloading later needs the owner's Sketchfab API token.
"""
import json
import sys
import time
import urllib.parse
import urllib.request
from io import BytesIO
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

# Instrument (app model id) -> search phrases.
QUERIES = {
    "guitar_acoustic": ["acoustic guitar"], "guitar_classical": ["classical guitar"], "guitar_electric": ["electric guitar"],
    "guitar_7": ["7 string guitar"], "guitar_12": ["12 string guitar"], "guitar_baritone": ["baritone guitar"],
    "guitar_tenor": ["tenor guitar"], "bass_electric": ["bass guitar", "electric bass"], "bass_5": ["5 string bass"],
    "guitalele": ["guitalele"], "guitarron": ["guitarron"], "ukulele": ["ukulele"], "ukulele_bass": ["bass ukulele"],
    "mandolin": ["mandolin"], "violin": ["violin"], "viola": ["viola"], "cello": ["cello"], "double_bass": ["double bass", "contrabass"],
    "banjo": ["banjo"], "bouzouki": ["bouzouki"], "charango": ["charango"], "dulcimer": ["appalachian dulcimer", "mountain dulcimer"],
    "hammered_dulcimer": ["hammered dulcimer", "santur", "cimbalom"], "autoharp": ["autoharp", "zither"], "lute": ["lute"],
    "sitar": ["sitar"], "sarod": ["sarod"], "kora": ["kora"], "oud": ["oud"], "guqin": ["guqin"], "guzheng": ["guzheng"],
    "pipa": ["pipa"], "erhu": ["erhu"], "shamisen": ["shamisen"], "koto": ["koto"], "gayageum": ["gayageum"],
    "balalaika": ["balalaika"], "domra": ["domra"], "harp": ["harp"], "piano": ["grand piano", "piano"],
    "harpsichord": ["harpsichord"], "accordion": ["accordion"], "concertina": ["concertina"], "flute": ["flute instrument", "transverse flute"],
    "recorder": ["recorder instrument"], "clarinet": ["clarinet"], "saxophone": ["saxophone"], "trumpet": ["trumpet"],
    "trombone": ["trombone"], "french_horn": ["french horn"], "harmonica": ["harmonica"], "tin_whistle": ["tin whistle"],
    "bansuri": ["bansuri"], "shakuhachi": ["shakuhachi"], "ocarina": ["ocarina"], "didgeridoo": ["didgeridoo"],
    "marimba": ["marimba"], "xylophone": ["xylophone"], "glockenspiel": ["glockenspiel"], "vibraphone": ["vibraphone"],
    "timpani": ["timpani"], "kalimba": ["kalimba"], "handpan": ["handpan", "hang drum"],
}
OK_LICENSES = {"cc0", "by"}
API = "https://api.sketchfab.com/v3"
KEEP = 12


def get(url: str) -> bytes:
    request = urllib.request.Request(url, headers={"User-Agent": "timbre-asset-scout/1.0"})
    error = None
    for attempt in range(5):
        try:
            with urllib.request.urlopen(request, timeout=40) as response:
                return response.read()
        except Exception as exc:  # rate limits and flaky network: back off and retry
            error = exc
            time.sleep(4 * (attempt + 1))
    raise error


SAMPLE = []
OUT = Path("build/scout")


def search(query: str, license: str) -> list:
    params = {"type": "models", "q": query, "downloadable": "true", "license": license, "count": 24, "sort_by": "-likeCount"}
    rows = json.loads(get(f"{API}/search?{urllib.parse.urlencode(params)}")).get("results", [])
    if rows and not SAMPLE:
        SAMPLE.append(rows[0])
        OUT.mkdir(parents=True, exist_ok=True)
        (OUT / "sample-row.json").write_text(json.dumps(rows[0], indent=1))
        print("sample search row keys:", sorted(rows[0].keys()), "license:", rows[0].get("license"), flush=True)
    return rows


def thumbnail(model: dict, width: int = 640) -> str:
    images = sorted(model.get("thumbnails", {}).get("images", []), key=lambda i: abs(i.get("width", 0) - width))
    return images[0]["url"] if images else ""


LABELS = {"CC Attribution": "by", "CC0 Public Domain": "cc0", "CC Attribution-ShareAlike": "by-sa",
          "CC Attribution-NoDerivs": "by-nd", "CC Attribution-NonCommercial": "by-nc"}


def slug(license) -> str:
    """Search rows carry the licence label only; model pages carry the slug."""
    if not isinstance(license, dict):
        return str(license or "")
    if license.get("slug"):
        return license["slug"]
    label = license.get("label", "")
    return LABELS.get(label, "cc0" if label.startswith("CC0") else label)


def summary(model: dict) -> dict:
    license = model.get("license") or {}
    archives = model.get("archives") or {}
    return {
        "uid": model["uid"], "name": model.get("name", ""), "user": (model.get("user") or {}).get("username", ""),
        "license": slug(license),
        "licenseLabel": license.get("label", "") if isinstance(license, dict) else "",
        "faces": model.get("faceCount", 0), "vertices": model.get("vertexCount", 0), "likes": model.get("likeCount", 0),
        "views": model.get("viewCount", 0), "animated": model.get("animationCount", 0),
        "url": model.get("viewerUrl", f"https://sketchfab.com/3d-models/{model['uid']}"), "thumb": thumbnail(model),
        "thumbLarge": thumbnail(model, 1280),
        "gltf": (archives.get("gltf") or {}).get("size"), "textures": (archives.get("gltf") or {}).get("textureCount"),
    }


def font(size: int):
    for path in ("/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf", "/usr/share/fonts/truetype/liberation/LiberationSans-Regular.ttf"):
        try:
            return ImageFont.truetype(path, size)
        except OSError:
            continue
    return ImageFont.load_default()


def sheet(title: str, models: list, out: Path):
    cols, tw, th, cap = 4, 400, 225, 46
    rows = max(1, (len(models) + cols - 1) // cols)
    canvas = Image.new("RGB", (cols * tw, 34 + rows * (th + cap)), (16, 15, 14))
    draw = ImageDraw.Draw(canvas)
    big, small = font(20), font(13)
    draw.text((8, 6), f"{title}  ({len(models)} candidates)", font=big, fill=(240, 200, 120))
    for k, m in enumerate(models):
        x, y = (k % cols) * tw, 34 + (k // cols) * (th + cap)
        try:
            im = Image.open(BytesIO(get(m["thumb"]))).convert("RGB") if m["thumb"] else None
        except Exception:
            im = None
        if im:
            im.thumbnail((tw - 4, th - 4))
            canvas.paste(im, (x + (tw - im.width) // 2, y + (th - im.height) // 2))
        draw.text((x + 6, y + th + 2), f"{k + 1}. {m['name'][:44]}", font=small, fill=(235, 230, 220))
        draw.text((x + 6, y + th + 20), f"{m['license']} · {m['faces'] // 1000}k tris · {m['likes']} likes · {m['user'][:16]}",
                  font=small, fill=(160, 152, 140))
    canvas.save(out, quality=86)


def polyhaven(out: Path) -> list:
    words = ["guitar", "violin", "cello", "piano", "drum", "trumpet", "horn", "flute", "instrument", "ukulele", "banjo",
             "harp", "saxophone", "accordion", "music", "string"]
    try:
        assets = json.loads(get("https://api.polyhaven.com/assets?t=models"))
    except Exception as exc:
        print("polyhaven unavailable:", exc)
        return []
    found = []
    for key, asset in assets.items():
        text = " ".join([key, asset.get("name", "")] + asset.get("tags", []) + asset.get("categories", [])).lower()
        if any(w in text for w in words):
            found.append({"id": key, "name": asset.get("name", key), "tags": asset.get("tags", []),
                          "thumb": f"https://cdn.polyhaven.com/asset_img/thumbs/{key}.png?width=512&height=512",
                          "url": f"https://polyhaven.com/a/{key}", "license": "cc0", "faces": 0, "likes": 0, "user": "Poly Haven"})
    if found:
        sheet("Poly Haven (CC0)", found[:24], out / "polyhaven.jpg")
    return found


def main():
    global OUT
    out = OUT = Path(sys.argv[1])
    out.mkdir(parents=True, exist_ok=True)
    (out / "large").mkdir(exist_ok=True)
    only = set(sys.argv[2].split(",")) if len(sys.argv) > 2 and sys.argv[2] else set()
    results = {}
    for instrument, queries in QUERIES.items():
        if only and instrument not in only:
            continue
        pool = {}
        for query in queries:
            for license in sorted(OK_LICENSES):
                try:
                    for model in search(query, license):
                        pool.setdefault(model["uid"], model)
                except Exception as exc:
                    print(f"{instrument}: search '{query}' ({license}) failed: {exc}")
                time.sleep(1.2)
        ranked = sorted(pool.values(), key=lambda m: (m.get("likeCount", 0), m.get("viewCount", 0)), reverse=True)
        chosen = []
        for model in ranked:
            if len(chosen) == KEEP:
                break
            detail = {}
            if not isinstance(model.get("license"), dict):  # search rows normally carry it; confirm otherwise
                try:
                    detail = json.loads(get(f"{API}/models/{model['uid']}"))
                    time.sleep(1.0)
                except Exception as exc:
                    print(f"{instrument}: detail {model['uid']} failed: {exc}")
                    continue
            item = summary({**model, **detail})
            if item["license"] in OK_LICENSES and {**model, **detail}.get("isDownloadable", True):
                chosen.append(item)
        results[instrument] = chosen
        sheet(instrument, chosen, out / f"{instrument}.jpg")
        for k, item in enumerate(chosen[:4]):  # larger renders for design mockups (internal review only)
            data = get(item["thumbLarge"]) if item["thumbLarge"] else b""
            if data:
                (out / "large" / f"{instrument}_{k + 1}.jpg").write_bytes(data)
        (out / "results.json").write_text(json.dumps(results, indent=1))
        print(f"{instrument}: {len(pool)} found, {len(chosen)} kept", flush=True)
    results["_polyhaven"] = polyhaven(out)
    (out / "results.json").write_text(json.dumps(results, indent=1))
    if not only:
        return


if __name__ == "__main__":
    main()
