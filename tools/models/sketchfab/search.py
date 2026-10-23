#!/usr/bin/env python3
"""Find candidate models on Sketchfab: downloadable, CC0 or CC-BY, with a thumbnail sheet to judge them.

python3 tools/models/sketchfab/search.py build/search "electric bass guitar|bass guitar 4 string"
Writes <out>/search.json (uid, name, author, licence, faces, url) and <out>/search_sheet_<n>.jpg.
"""
import json
import sys
import time
import urllib.parse
import urllib.request
from io import BytesIO
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

API = "https://api.sketchfab.com/v3"
OK = {"cc0", "by"}


def get(url):
    for attempt in range(4):
        try:
            req = urllib.request.Request(url, headers={"User-Agent": "timbre-import/1.0"})
            with urllib.request.urlopen(req, timeout=60) as response:
                return response.read()
        except Exception as exc:
            error = exc
            time.sleep(3 * (attempt + 1))
    raise error


def main():
    out, queries = Path(sys.argv[1]), sys.argv[2].split("|")
    out.mkdir(parents=True, exist_ok=True)
    found = {}
    for q in queries:
        params = urllib.parse.urlencode({"type": "models", "q": q, "downloadable": "true", "count": 24, "sort_by": "-likeCount"})
        data = json.loads(get(f"{API}/search?{params}"))
        for m in data.get("results", []):
            if m["uid"] in found:
                continue
            detail = json.loads(get(f"{API}/models/{m['uid']}"))
            slug = (detail.get("license") or {}).get("slug", "")
            if slug not in OK:
                continue
            thumbs = sorted((detail.get("thumbnails") or {}).get("images", []), key=lambda t: abs(t.get("width", 0) - 640))
            found[m["uid"]] = {"uid": m["uid"], "name": detail.get("name"), "author": (detail.get("user") or {}).get("username"),
                               "license": slug, "faces": detail.get("faceCount"), "likes": detail.get("likeCount"),
                               "url": detail.get("viewerUrl"), "query": q, "thumb": thumbs[0]["url"] if thumbs else None,
                               "tags": [t.get("name") for t in detail.get("tags", [])][:12],
                               "description": (detail.get("description") or "")[:300]}
            time.sleep(0.5)
    rows = list(found.values())
    (out / "search.json").write_text(json.dumps(rows, indent=1))
    try:
        font = ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf", 15)
    except OSError:
        font = ImageFont.load_default()
    per_sheet, cell = 12, (480, 330)
    for s in range(0, len(rows), per_sheet):
        sheet = Image.new("RGB", (cell[0] * 4, cell[1] * 3), (30, 30, 30))
        d = ImageDraw.Draw(sheet)
        for k, row in enumerate(rows[s:s + per_sheet]):
            x, y = (k % 4) * cell[0], (k // 4) * cell[1]
            if row["thumb"]:
                try:
                    im = Image.open(BytesIO(get(row["thumb"]))).convert("RGB")
                    im.thumbnail((cell[0] - 8, cell[1] - 48))
                    sheet.paste(im, (x + 4, y + 4))
                except Exception:
                    pass
            d.text((x + 4, y + cell[1] - 42), f"{s + k}: {row['name'][:40]}", font=font, fill=(240, 240, 240))
            d.text((x + 4, y + cell[1] - 22), f"{row['license']} {row['faces']} faces {row['uid'][:10]}", font=font, fill=(180, 220, 255))
        sheet.save(out / f"search_sheet_{s // per_sheet}.jpg", quality=85)
    print(len(rows), "candidates")


if __name__ == "__main__":
    main()
