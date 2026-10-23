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
for attempt in 1 2 3; do
  if git push -qf "https://x-access-token:${GH_TOKEN}@github.com/${GITHUB_REPOSITORY}.git" "$branch:$branch"; then
    echo "Published results to $branch"; exit 0
  fi
  sleep $((attempt * 5))
done
echo "Could not publish results to $branch"
