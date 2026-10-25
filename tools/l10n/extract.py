#!/usr/bin/env python3
"""List the interface strings some locale still lacks, settled against an Xcode export.

python3 tools/l10n/extract.py <exported en.xliff> > tools/l10n/pending.json
The xliff comes from the "Localization export" workflow (ci-results/l10n).

This is `report.py --xliff` printing only pending.json. `python3 tools/l10n/report.py` (no xliff needed) writes
pending.json together with the translators' TODO files and docs/l10n/HANDOFF.md; prefer it.
"""
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import report  # noqa: E402


def main() -> None:
    sys.stdout.write(report.render_pending(report.build(Path(sys.argv[1]))))


if __name__ == "__main__":
    main()
