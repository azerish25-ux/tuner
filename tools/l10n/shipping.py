#!/usr/bin/env python3
"""Which languages the app ships, and how complete each one is.

    python3 tools/l10n/shipping.py                       # coverage per locale, and the locales that ship now
    python3 tools/l10n/shipping.py --min 95              # the locales that would ship at 95 % or more (dry run)
    python3 tools/l10n/shipping.py --min 95 --critical   # ... and only those with every legal, permission and
                                                         #     VoiceOver string translated (the App Store gate)
    python3 tools/l10n/shipping.py --min 95 --apply      # write that set into ios/project.yml
    python3 tools/l10n/shipping.py --all --apply         # ship every locale that has a .lproj again

Which locales ship is the owner's decision. Nothing here deletes a translation: `--apply` changes two things in
ios/project.yml, both on lines marked `# shipping.py`:

    CFBundleLocalizations   the Timbre target's list of localizations (English first)
    excludes                the .lproj folders of the locales left out, in each target that copies string tables,
                            so the App Store lists only the languages that ship and the build carries no others

The .lproj folders and the translators' files stay in the repository, so a locale comes back with `--apply` once it
reaches the bar. The delivery workflow (apple-delivery.yml, input `ship_min_coverage`) applies a bar to its own
checkout without committing it.

Coverage is the share of the app's interface strings (Localizable, InfoPlist, AppShortcuts and the plurals) a locale
has; lesson strings are required in every locale and reported separately. The independent lessons.py --strict gate
requires full lesson coverage across all 48 targets; the UI percentage bar is not a completion certificate.
"""
from __future__ import annotations

import argparse
import os
import re
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
PROJECT = ROOT / "ios/project.yml"
RESOURCES = ROOT / "ios/Timbre/Resources"
SOURCE = "en"
MARK = "# shipping.py"
DECLARED = re.compile(r"^(\s+CFBundleLocalizations:\s*)\[([^\]]*)\](.*)$", re.M)
EXCLUDES = re.compile(r"^(\s+excludes:\s*)\[([^\]]*)\](\s*" + re.escape(MARK) + r".*)$", re.M)


def available() -> list[str]:
    """Every locale with a string table folder, English included."""
    return sorted(p.name[:-6] for p in RESOURCES.glob("*.lproj") if p.name != "Base.lproj")


def declared(text: str | None = None) -> list[str] | None:
    """CFBundleLocalizations in ios/project.yml (the Timbre target's), or None when the project doesn't declare it."""
    text = PROJECT.read_text(encoding="utf-8") if text is None else text
    match = DECLARED.search(text)
    if not match:
        return None
    return [item.strip().strip("'\"") for item in match.group(2).split(",") if item.strip()]


def shipped() -> list[str]:
    """The locales that ship, English excluded: the declared list when there is one, else every .lproj."""
    locales = declared() or available()
    have = set(available())
    return [loc for loc in locales if loc != SOURCE and loc in have]


def coverage(model: dict) -> dict:
    """{locale: {"ui": share, "lessons": share or None, "ui_missing": n, "lessons_missing": n}} from report.build()."""
    out = {}
    ui_total = max(1, model["ui_total"])
    learn_total = max(1, model["learn_total"])
    for loc, entry in model["locales"].items():
        ui_missing = sum(1 for item in entry["todo"] + entry.get("awaiting_apply", []) if item["table"] != "Learn.strings")
        lessons_missing = sum(1 for item in entry["todo"] + entry.get("awaiting_apply", []) if item["table"] == "Learn.strings")
        lessons = loc in model["lesson_locales"]
        out[loc] = {"ui": 1 - ui_missing / ui_total, "ui_missing": ui_missing,
                    "lessons": (1 - lessons_missing / learn_total) if lessons else None, "lessons_missing": lessons_missing}
    return out


def rewrite(text: str, keep: list[str]) -> str:
    """ios/project.yml shipping `keep` (English always first): CFBundleLocalizations and the marked excludes lines."""
    ordered = [SOURCE] + sorted(loc for loc in set(keep) if loc != SOURCE)
    if not DECLARED.search(text):
        raise SystemExit("ios/project.yml declares no CFBundleLocalizations line to rewrite")
    # Quoted: YAML would read a bare `no` (Norwegian) as false.
    quoted = ", ".join(f'"{loc}"' for loc in ordered)
    text = DECLARED.sub(lambda m: f"{m.group(1)}[{quoted}]{m.group(3)}", text, count=1)
    left_out = [loc for loc in available() if loc not in ordered]
    patterns = [f'"{loc}.lproj"' for loc in left_out] + [f'"{loc}.lproj/*"' for loc in left_out]

    def excludes(match: re.Match) -> str:
        kept = [item.strip() for item in match.group(2).split(",") if item.strip() and ".lproj" not in item]
        return f"{match.group(1)}[{', '.join(kept + patterns)}]{match.group(3)}"

    text, count = EXCLUDES.subn(excludes, text)
    if not count:
        raise SystemExit(f"ios/project.yml has no `excludes: [...]  {MARK}` lines to rewrite")
    return text


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    choice = parser.add_mutually_exclusive_group()
    choice.add_argument("--min", type=float, metavar="PERCENT", help="ship the locales with at least this coverage")
    choice.add_argument("--all", action="store_true", help="ship every locale that has a .lproj")
    parser.add_argument("--critical", action="store_true",
                        help="with --min: also require every legal, permission and VoiceOver string")
    parser.add_argument("--apply", action="store_true", help="write the set into ios/project.yml")
    parser.add_argument("--github-output", action="store_true", help="append locales=<comma list> to $GITHUB_OUTPUT")
    args = parser.parse_args(argv)

    sys.path.insert(0, str(HERE))
    import report  # noqa: E402

    model = report.build()
    shares = coverage(model)
    gaps: dict = {}
    if args.critical or args.min is None:
        import critical  # noqa: E402
        found = critical.missing(model, sorted(shares), critical.Classifier())
        gaps = {loc: sum(len(items) for items in per.values()) for loc, per in found.items()}
    now = set(shipped())

    print(f"{'locale':8} {'interface':>10} {'lessons':>9} {'critical gaps':>14}  ships now")
    for loc in sorted(shares):
        share = shares[loc]
        lessons = f"{share['lessons'] * 100:7.1f} %" if share["lessons"] is not None else "        —"
        critical_gaps = str(gaps.get(loc, "")) if gaps else ""
        print(f"{loc:8} {share['ui'] * 100:8.1f} % {lessons} {critical_gaps:>14}  {'yes' if loc in now else 'no'}")

    if args.min is None and not args.all:
        print(f"\nShipping now: {SOURCE} + {len(now)} locales. Choose a bar with --min PERCENT (add --apply to write it).")
        return 0
    if args.all:
        keep = [loc for loc in available() if loc != SOURCE]
    else:
        keep = [loc for loc, share in shares.items() if share["ui"] * 100 >= args.min
                and (not args.critical or gaps.get(loc, 0) == 0)]
    left_out = sorted(set(shares) - set(keep))
    print(f"\nWould ship {SOURCE} + {len(keep)} locales: {', '.join(sorted(keep)) or 'none'}")
    print(f"Left out ({len(left_out)}): {', '.join(left_out) or 'none'}")
    if args.apply:
        text = PROJECT.read_text(encoding="utf-8")
        updated = rewrite(text, keep)
        if updated != text:
            PROJECT.write_text(updated, encoding="utf-8")
        print("ios/project.yml " + ("updated" if updated != text else "already ships this set")
              + ": regenerate the Xcode project (xcodegen generate).")
    if args.github_output and os.environ.get("GITHUB_OUTPUT"):
        with open(os.environ["GITHUB_OUTPUT"], "a", encoding="utf-8") as handle:
            handle.write(f"locales={','.join(sorted(keep))}\n")
    return 0


if __name__ == "__main__":
    sys.exit(main())
