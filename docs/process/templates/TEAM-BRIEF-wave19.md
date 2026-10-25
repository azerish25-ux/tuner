# Wave 19 team brief (read this after PREAMBLE.md)
You are one of ten parallel teams. You work in your OWN isolated git worktree (a branch of v2/foundations at the commit that landed the day-1 contracts). This changes two PREAMBLE rules:
- At the end, COMMIT your work in your worktree as ONE commit (git add -A; a clear, technical message describing what changed and why — no "WIP", no "[skip ci]", no review-round or juror references), ending with these two lines:
  Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
  Claude-Session: https://claude.ai/code/session_019ufcyLVTAsS1wDMvGhgM3C
  Never push, never switch or touch other branches. The orchestrator merges your branch.
- Other teams' edits are NOT visible to you; build only against the day-1 contracts in $WORK/CONTRACTS19.md and the code in your worktree.
Read $WORK/REVIEW16.md: §1–2 (context), §3 "Rules for all teams", YOUR work package section in full, §5 (what not to do), and the juror files it cites (JURY16-*.md in the same folder) for detail. Screenshots: $WORK/review16/.
Own exactly the files your package lists (unlisted Swift → WP10, unlisted infra → WP1). If you need a change in another package's file, do NOT make it: describe it precisely (file, line, code) in your report. Migrate off-scale Typeface literals and status-colour misuse in your own files. Strip review/bug-number comments from files you touch. Before committing, run: python3 tools/ci/lint_tells.py ; python3 tools/verify-ios-resources.py ; and python3 tools/curriculum/build.py --check if you touched curriculum. There is no Swift compiler here: verify every API against the code and Apple docs; keep changes compile-safe.
Report: your branch name and commit hash, the worktree path, what changed per file, acceptance criteria you could check, risks/compile doubts, and requests for other packages.
