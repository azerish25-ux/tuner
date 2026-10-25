#!/usr/bin/env python3
"""collect_review.py <out-dir> <ci-results branch>... : copy each branch's screenshots into <out-dir> under their
readable names (the attachment name before its _0_<uuid> suffix), iPad ones prefixed ipad- when the branch is ipad."""
import json, os, re, subprocess, sys

REPO = os.environ.get("REPO") or subprocess.run(["git", "rev-parse", "--show-toplevel"], capture_output=True, text=True).stdout.strip()
out = sys.argv[1]
os.makedirs(out, exist_ok=True)


def git(*args, binary=False):
    return subprocess.run(["git", "-C", REPO, *args], check=True, capture_output=True, text=not binary).stdout


for branch in sys.argv[2:]:
    ref = f"refs/remotes/origin/ci-results/{branch}"
    git("fetch", "-q", "origin", f"+ci-results/{branch}:{ref}")
    run = git("show", f"{ref}:RUN.txt")
    folder = "ipad-screenshots" if branch.startswith("ipad") else "screenshots"
    manifest = json.loads(git("show", f"{ref}:{folder}/manifest.json"))
    count = 0
    for test in manifest:
        for att in test.get("attachments", []):
            name = att["suggestedHumanReadableName"]
            exported = att["exportedFileName"]
            ext = os.path.splitext(exported)[1]
            if ext not in (".png", ".jpg", ".mp4"):
                continue
            base = re.sub(r"_\d+_[0-9A-F-]{36}(\.\w+)?$", "", name)
            base = re.sub(r"\.(png|jpg|mp4)$", "", base)
            if branch.startswith("ipad") and not base.startswith("ipad-"):
                base = "ipad-" + base
            try:
                data = git("show", f"{ref}:{folder}/{exported}", binary=True)
            except subprocess.CalledProcessError:
                continue  # listed in the manifest but not published (screen recordings)
            with open(os.path.join(out, base + ext), "wb") as f:
                f.write(data)
            count += 1
    print(f"{branch}: {count} files ({run.split()[0]})")
