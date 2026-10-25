#!/usr/bin/env python3
"""The hygiene lint's former name, kept so existing commands still work: runs tools/ci/comment_hygiene.py."""
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from comment_hygiene import main  # noqa: E402

if __name__ == "__main__":
    sys.exit(main())
