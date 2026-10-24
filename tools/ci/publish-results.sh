#!/usr/bin/env bash
# Publish a directory of CI evidence (logs, screenshots, renders) as a single
# orphan commit on its own branch, e.g. ci-results/app. Each run replaces the
# branch, so history never grows. Readable with plain `git fetch`, which works
# where artifact downloads are unavailable.
set -euo pipefail
branch="$1"
source_dir="$2"
# Side branches publish next to the main evidence (ci-results/core--dsp-chords) instead of over it.
ref="${GITHUB_HEAD_REF:-${GITHUB_REF_NAME:-}}"
case "$ref" in ""|main|v2/foundations) ;; *) branch="${branch}--${ref//\//-}" ;; esac
[ -d "$source_dir" ] || { echo "No results directory: $source_dir"; exit 0; }
work=$(mktemp -d)
cp -R "$source_dir"/. "$work"/
# GitHub refuses files over 100 MB (a failing UI test can attach a long screen recording):
# leave big files out and list them, so the logs and screenshots still arrive.
find "$work" -type f -size +45M -print | while read -r big; do
  echo "${big#$work/} $(du -h "$big" | cut -f1)" >> "$work/SKIPPED.txt"; rm -f "$big"
done
cat > "$work/RUN.txt" <<EOF
sha=${GITHUB_SHA:-unknown}
ref=${GITHUB_HEAD_REF:-${GITHUB_REF_NAME:-unknown}}
run=${GITHUB_RUN_ID:-unknown}
job=${GITHUB_JOB:-unknown}
date=$(date -u +%FT%TZ)
EOF
cd "$work"
git init -q
git checkout -q -b "$branch"
git add -A
git -c user.name="timbre-ci" -c user.email="timbre-ci@users.noreply.github.com" commit -qm "CI results ${GITHUB_SHA:-local} run ${GITHUB_RUN_ID:-0}"
remote="https://x-access-token:${GH_TOKEN}@github.com/${GITHUB_REPOSITORY}.git"
for attempt in 1 2 3; do
  if git push -qf "$remote" "$branch:$branch" 2> push.err; then
    echo "Published results to $branch"; exit 0
  fi
  cat push.err; sleep $((attempt * 5))
done
# Last resort: publish just the text (logs, summaries, why the push failed) so the run is diagnosable.
echo "Full push failed; publishing logs only"
git rm -rq --cached . && git add -- *.txt *.gz 2>/dev/null || true
{ echo "Screenshots were not published: the full push failed."; cat push.err; } > PUSH-FAILED.txt
git add PUSH-FAILED.txt
git -c user.name="timbre-ci" -c user.email="timbre-ci@users.noreply.github.com" commit -q --amend -m "CI results (logs only) ${GITHUB_SHA:-local} run ${GITHUB_RUN_ID:-0}"
git push -qf "$remote" "$branch:$branch" && echo "Published logs to $branch" || echo "Could not publish results to $branch"
