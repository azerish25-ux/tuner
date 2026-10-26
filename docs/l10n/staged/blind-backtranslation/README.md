# Blind backtranslation review — comparison pending

**Review artifact only. No corrections applied.** Two independent AI review
partitions produced English backtranslations of **1,104 target-language rows**:
23 purchase/permission rows in each of 48 locales. This is not native-human,
legal, device, navigation or release certification.

- `group1-output.json` and `group2-output.json`: complete, byte-exact outputs,
  including uncertainty notes (552 rows each).
- `group1-evidence.json` and `group2-evidence.json`: reported source-blinded method,
  covered IDs, original input/output hashes and mechanical validation evidence.
- `parent-source-map.json`: byte-exact ID-to-source/context/target mapping for the
  **still-pending source comparison**. It was withheld from the backtranslators.
- `checkpoint-summary.json`: verified coverage and pending status.
- `artifact-manifest.json`: staged file hashes and original artifact hashes.

The source comparison has not been performed. Compare all recovered meanings and
uncertainty notes with source intent and context, then record source/key/old/new
ledgers for confirmed discrepancies. Do not infer correctness of the original
translations merely from complete backtranslation coverage or mechanical checks.

## Deduplicated target-only inputs

The original blind inputs contain only ID, locale and target text already present
in the mapping. They are omitted to avoid repeating the same translation content.
This recipe reconstructs each original input **byte for byte**, including its
record order; the result was checked against the original input SHA-256 values:

```python
import hashlib, json
from pathlib import Path

root = Path(__file__).parent  # or this directory when run interactively
mapping = json.loads((root / "parent-source-map.json").read_text())
for group in (1, 2):
    output = json.loads((root / f"group{group}-output.json").read_text())
    evidence = json.loads((root / f"group{group}-evidence.json").read_text())
    rows = [
        {"id": row["id"], "locale": mapping[row["id"]]["locale"],
         "target_text": mapping[row["id"]]["translation"]}
        for row in output
    ]
    data = (json.dumps(rows, ensure_ascii=False, indent=2) + "\n").encode()
    assert hashlib.sha256(data).hexdigest() == evidence["input_sha256"]
```

Checkpoint validation verified all 1,104 unique IDs, exact group order/locale,
complete mapping bijection, 23 rows for every locale, nonempty backtranslations,
uncertainty-note fields, output hashes, and byte-exact reconstructed input hashes.
Those checks establish artifact integrity only, not semantic equivalence.

Private machine paths were normalized in evidence. No prompts, execution scripts,
raw logs, external downloads, or private reviewer identifiers are published.
