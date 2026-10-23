#!/usr/bin/env python3
"""Competitor screenshots and store facts for design benchmarking (analysis only, never shipped).

python3 tools/scout/benchmark.py <out>
Uses the public iTunes lookup/search API: the named benchmark apps plus the most-rated
results for common tuner searches. Writes apps.json and one screenshot sheet per app.
"""
import json
import sys
import time
import urllib.parse
import urllib.request
from io import BytesIO
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

NAMED = {"guitartuna": 527588389, "fender_tune": 1107017950}
SEARCHES = ["guitar tuner", "tuner", "violin tuner", "ukulele tuner", "chromatic tuner", "bass tuner"]


def get(url: str) -> bytes:
    request = urllib.request.Request(url, headers={"User-Agent": "timbre-benchmark/1.0"})
    for attempt in range(4):
        try:
            with urllib.request.urlopen(request, timeout=40) as response:
                return response.read()
        except Exception:
            time.sleep(3 * (attempt + 1))
    return b""


def font(size):
    try:
        return ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf", size)
    except OSError:
        return ImageFont.load_default()


def sheet(app: dict, out: Path):
    urls = app.get("screenshotUrls", [])[:10]
    shots = []
    for url in urls:
        data = get(url)
        if data:
            im = Image.open(BytesIO(data)).convert("RGB")
            im.thumbnail((360, 780))
            shots.append(im)
    if not shots:
        return
    h = max(s.height for s in shots)
    canvas = Image.new("RGB", (sum(s.width + 8 for s in shots) + 8, h + 60), (18, 18, 18))
    draw = ImageDraw.Draw(canvas)
    draw.text((8, 8), f"{app['trackName'][:70]}  ·  {app.get('averageUserRating', 0):.2f}★ × {app.get('userRatingCount', 0)}",
              font=font(22), fill=(240, 220, 160))
    x = 8
    for s in shots:
        canvas.paste(s, (x, 50))
        x += s.width + 8
    canvas.save(out, quality=88)


def main():
    out = Path(sys.argv[1])
    out.mkdir(parents=True, exist_ok=True)
    apps = {}
    for key, track in NAMED.items():
        data = json.loads(get(f"https://itunes.apple.com/lookup?id={track}&country=us") or b"{}")
        if data.get("results"):
            apps[key] = data["results"][0]
    for term in SEARCHES:
        query = urllib.parse.urlencode({"term": term, "entity": "software", "country": "us", "limit": 25})
        data = json.loads(get(f"https://itunes.apple.com/search?{query}") or b"{}")
        for app in data.get("results", []):
            apps.setdefault(str(app["trackId"]), app)
        time.sleep(1)
    ranked = sorted(apps.items(), key=lambda kv: (kv[0] in NAMED, kv[1].get("userRatingCount", 0)), reverse=True)
    keep = ranked[:16]
    facts = []
    for key, app in keep:
        name = key if key in NAMED else f"{app.get('userRatingCount', 0):08d}_{app['trackId']}"
        sheet(app, out / f"{name}.jpg")
        facts.append({k: app.get(k) for k in ("trackName", "trackId", "sellerName", "averageUserRating", "userRatingCount",
                                              "price", "formattedPrice", "version", "currentVersionReleaseDate",
                                              "description", "releaseNotes", "genres", "fileSizeBytes")})
        print(app["trackName"], app.get("userRatingCount"))
    (out / "apps.json").write_text(json.dumps(facts, indent=1))


if __name__ == "__main__":
    main()
