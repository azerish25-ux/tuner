#!/usr/bin/env python3
"""Download chosen artist-made models from Sketchfab (glTF) with the owner's API token.

SKETCHFAB_TOKEN=... python3 tools/models/sketchfab/fetch.py tools/models/sketchfab/picks.json build/import
picks.json maps our id to a Sketchfab uid: {"violin": "<uid>", ...}. Only CC0 and CC-BY
models are accepted; each lands in <out>/<id>/ with meta.json carrying the credit line.
"""
import json
import os
import sys
import time
import urllib.request
import zipfile
from io import BytesIO
from pathlib import Path

API = "https://api.sketchfab.com/v3"
OK_LICENSES = {"cc0", "by"}


def get(url: str, token: str = "") -> bytes:
    headers = {"User-Agent": "timbre-import/1.0"}
    if token:
        headers["Authorization"] = f"Token {token}"
    error = None
    for attempt in range(5):
        try:
            with urllib.request.urlopen(urllib.request.Request(url, headers=headers), timeout=120) as response:
                return response.read()
        except Exception as exc:
            error = exc
            time.sleep(5 * (attempt + 1))
    raise error


def main():
    picks, out = json.loads(Path(sys.argv[1]).read_text()), Path(sys.argv[2])
    only = set(sys.argv[3].split(",")) if len(sys.argv) > 3 and sys.argv[3] else set()
    token = os.environ.get("SKETCHFAB_TOKEN", "")
    if not token:
        sys.exit("SKETCHFAB_TOKEN is not set: add it under Settings > Secrets and variables > Actions.")
    report = {}
    for model_id, uid in picks.items():
        if only and model_id not in only:
            continue
        try:
            info = json.loads(get(f"{API}/models/{uid}"))
            license = (info.get("license") or {}).get("slug", "")
            if license not in OK_LICENSES:
                report[model_id] = f"skipped: licence {license!r}"
                continue
            links = json.loads(get(f"{API}/models/{uid}/download", token))
            archive = get(links["gltf"]["url"])
            target = out / model_id
            target.mkdir(parents=True, exist_ok=True)
            zipfile.ZipFile(BytesIO(archive)).extractall(target)
            user = info.get("user") or {}
            meta = {"id": model_id, "uid": uid, "title": info.get("name", ""), "author": user.get("displayName") or user.get("username", ""),
                    "authorUrl": user.get("profileUrl", ""), "license": license, "licenseLabel": (info.get("license") or {}).get("label", ""),
                    "url": info.get("viewerUrl", f"https://sketchfab.com/3d-models/{uid}"), "faces": info.get("faceCount"),
                    "archiveBytes": len(archive)}
            (target / "meta.json").write_text(json.dumps(meta, indent=1))
            report[model_id] = f"ok {len(archive) // 1024} KB, {meta['faces']} faces"
        except Exception as exc:
            report[model_id] = f"failed: {exc}"
        print(model_id, report[model_id], flush=True)
        time.sleep(2)
    out.mkdir(parents=True, exist_ok=True)
    (out / "fetch-report.json").write_text(json.dumps(report, indent=1))


if __name__ == "__main__":
    main()
