#!/usr/bin/env bash
report() {  # print jobs plus error annotations of failed jobs
  echo "$jobs"
  gh run view "$run" --json jobs --jq '.jobs[] | select(.conclusion=="failure") | .databaseId' | while read -r jid; do
    gh api "repos/azerish25-ux/tuner/check-runs/$jid/annotations" --jq '.[] | select(.annotation_level=="failure") | .message' 2>/dev/null | grep -v "exit code" | cut -c1-400 | head -12
  done
}
# Usage: [REPO=<checkout>] [BRANCH=<branch>] ciwait.sh <sha-prefix> [workflow-name]
# Exits when the app job's build step fails or every job of the iOS run completes.
cd "${REPO:-$(git rev-parse --show-toplevel)}"
branch="${BRANCH:-v2/foundations}"
sha="$1"; wf="${2:-iOS}"
for i in $(seq 1 120); do
  run=$(gh run list -b "$branch" -L 10 --json databaseId,headSha,workflowName --jq ".[] | select(.workflowName==\"$wf\") | select(.headSha|startswith(\"$sha\")) | .databaseId" 2>/dev/null | head -1)
  if [ -n "$run" ]; then
    jobs=$(gh run view "$run" --json jobs --jq '.jobs[] | "\(.name)|\(.status)|\(.conclusion)|" + ([.steps[] | select(.conclusion=="failure") | .name] | join(","))' 2>/dev/null)
    if echo "$jobs" | grep -q '|failure|'; then
      if ! echo "$jobs" | grep -q '|in_progress|\||queued|'; then report; exit 0; fi
      if echo "$jobs" | grep -E '^app\|' | grep -q 'Build app and tests'; then report; exit 0; fi
    fi
    if ! echo "$jobs" | grep -qE '\|(in_progress|queued|pending|waiting)\|'; then [ -n "$jobs" ] && { report; exit 0; }; fi
  fi
  sleep 30
done
echo "timeout"
