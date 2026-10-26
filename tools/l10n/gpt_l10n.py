#!/usr/bin/env python3
"""GPT batches for Timbre's translation TODO files (docs/l10n/TRANSLATING-WITH-GPT.md).

    python3 gpt_l10n.py split  REPO LOCALE [--size 40] [--out DIR] [--review]  # batches from tools/l10n/todo/LOCALE.json
    python3 gpt_l10n.py prompt REPO LOCALE BATCH.json GLOSSARY.md              # the user message for one batch
    python3 gpt_l10n.py merge  REPO LOCALE BATCH.out.json ...                  # check answers, fill the TODO file

`split` writes DIR/LOCALE-NNN.json (what GPT reads) and DIR/LOCALE-NNN.map.json (which TODO entry each id is): the
entries still empty or rejected, or with --review the ones already filled (for the review pass). `prompt` writes
BATCH.prompt.txt: the locale's glossary, a few of its current translations as style anchors, and the batch. `merge`
reads GPT's answer saved as LOCALE-NNN.out.json beside its batch, runs the import's own checks plus stricter ones, and
fills the "translation" field of each entry that passes. Nothing else in the TODO file changes.
"""
import hashlib
import json
import re
import sys
import unicodedata
from pathlib import Path

ARG = re.compile(r"%(?:(\d+)\$)?[-+ #0]*\d*(?:\.\d+)?(lld|llu|ld|lu|lf|d|u|f|@)")
TOKEN = re.compile(r"\$\{\w+\}")
RTL = {"ar", "fa", "he", "ur"}
WIDE = {"ja", "ko", "zh-CN"}
EMOJI = re.compile("[\U0001F000-\U0001FAFF]")
# Invisible direction marks: ALM, LRM, RLM, the embeddings and overrides, the isolates.
BIDI = re.compile("[" + "".join(map(chr, [0x061C, 0x200E, 0x200F, *range(0x202A, 0x202F), *range(0x2066, 0x206A)])) + "]")
KEEP_AS_IS = {"XP", "Hz", "BPM", "A4", "Timbre", "Timbre Pro", "OK"}


def spec_list(text):
    """Every format argument in the order it is consumed (positional ones put back in order), and the ${…} tokens."""
    found = [(m.group(1), m.group(2)) for m in ARG.finditer(text.replace("%%", ""))]
    if any(p for p, _ in found):
        if not all(p for p, _ in found):
            return ["mixed"]
        found = sorted(found, key=lambda pair: int(pair[0]))
    return [kind for _, kind in found] + sorted(TOKEN.findall(text))


def todo_path(repo, loc):
    return repo / "tools/l10n/todo" / f"{loc}.json"


def entries(path):
    """(line number, entry) for every string of a TODO file (one JSON object per line, as report.py writes it)."""
    for number, line in enumerate(path.read_text(encoding="utf-8").splitlines()):
        if line.startswith("  {"):
            yield number, json.loads(line.strip().rstrip(","))


def plural_forms(repo, loc):
    """The plural categories the locale's own .stringsdict uses (zero one two few many other)."""
    sys.path.insert(0, str(repo / "tools/l10n"))
    import report
    found = set()
    for entry in report.read_stringsdict(repo / f"ios/Timbre/Resources/{loc}.lproj/Localizable.stringsdict").values():
        for value in entry.values():
            if isinstance(value, dict):
                found |= set(value) & {"zero", "one", "two", "few", "many", "other"}
    return [f for f in ("zero", "one", "two", "few", "many", "other") if f in found] or ["one", "other"]


def names_control(source, start):
    """A capitalized name inside a sentence, after a lowercase word or an opening quote ("in Settings", "Tap Listen"),
    not the start of a sentence and not the second word of a name ("Apple Music", "Timbre Pro")."""
    before = source[:start].rstrip()
    word = re.findall(r"[\w’']+$", before)
    return bool(before) and (before[-1].islower() or before[-1] in "“\"«„‘(") and not (word and word[0][:1].isupper())


def code_line(repo, where):
    path, _, line = where.partition(":")
    try:
        return (repo / path).read_text(encoding="utf-8").splitlines()[int(line) - 1].strip()[:240]
    except (OSError, ValueError, IndexError):
        return ""


def option_contexts(repo):
    """All distinct prompts for shared answer keys, not just the first TODO occurrence.

    A direction can describe pitch or a picking stroke; a duration answer may appear
    under several grammatical questions. Preserve every distinct prompt/explanation
    so translators can choose a target that works everywhere or flag a source split.
    """
    path = repo / "ios/Sources/TimbreCore/Resources/curriculum.json"
    if not path.exists():
        return {}
    catalog = json.loads(path.read_text(encoding="utf-8"))
    grouped = {}
    for course in catalog.get("courses", []):
        for unit in course.get("units", []):
            for lesson in unit.get("lessons", []):
                for step in lesson.get("steps", []):
                    prompt = step.get("prompt", {})
                    why = step.get("why", {})
                    prompt = prompt.get("t", "") if isinstance(prompt, dict) else str(prompt)
                    why = why.get("t", "") if isinstance(why, dict) else str(why)
                    for option in step.get("options", []):
                        if not isinstance(option, dict) or not option.get("k"):
                            continue
                        key = option["k"]
                        signature = (prompt, why)
                        contexts = grouped.setdefault(key, {})
                        row = contexts.setdefault(signature, {"prompt": prompt, "explanation": why,
                                                              "occurrences": 0, "example_lessons": []})
                        row["occurrences"] += 1
                        ident = lesson.get("id", "")
                        if ident and ident not in row["example_lessons"] and len(row["example_lessons"]) < 2:
                            row["example_lessons"].append(ident)
    return {key: list(contexts.values()) for key, contexts in grouped.items()}


def source_clarifications(repo):
    """Verified source distinctions, bound to exact English and full curriculum contexts."""
    path = repo / "tools/l10n/source-clarifications.json"
    if not path.exists():
        return {}
    data = json.loads(path.read_text(encoding="utf-8"))
    catalog = json.loads((repo / "ios/Sources/TimbreCore/Resources/curriculum.json").read_text(encoding="utf-8"))
    result = {}
    for row in data["notes"]:
        if row["key"] in result or not row["evidence"] or not row["clarification"].strip():
            raise ValueError("invalid or duplicate source clarification: " + row["key"])
        if hashlib.sha256(row["source"].encode()).hexdigest() != row["source_sha256"]:
            raise ValueError("source clarification hash drift: " + row["key"])
        for guard in row["evidence"]:
            value = catalog
            for key in guard["pointer"].strip("/").split("/"):
                value = value[int(key)] if isinstance(value, list) else value[key]
            encoded = json.dumps(value, sort_keys=True, ensure_ascii=False, separators=(",", ":")).encode()
            if hashlib.sha256(encoded).hexdigest() != guard["sha256"]:
                raise ValueError("source clarification context drift: " + row["key"])
        result[row["key"]] = row
    return result


def split(repo, loc, size, out, review=False):
    sys.path.insert(0, str(repo / "tools/l10n"))
    import report
    table = report.read_strings(repo / f"ios/Timbre/Resources/{loc}.lproj/Localizable.strings")
    names = {k: v for k, v in table.items() if len(k) <= 30 and k[:1].isupper() and len(k.split()) <= 3
             and "%" not in k and not k.startswith("timbre_")}
    learn_path = repo / "tools/l10n/learn" / f"{loc}.json"
    learned = json.loads(learn_path.read_text(encoding="utf-8")) if learn_path.exists() else {}
    forms = plural_forms(repo, loc)
    answer_contexts = option_contexts(repo)
    clarifications = source_clarifications(repo)
    def group(item):
        """A batch holds one kind: one launch-critical kind, the rest of the interface, or whole lessons."""
        if item["table"] == "Learn.strings":
            return "lesson", re.split(r" · (?:step \d+|title|arrangement)", item.get("context", ""))[0]
        return item.get("launch", "ui"), None

    batches, current = [], []
    for _, item in entries(todo_path(repo, loc)):
        filled = bool(item.get("translation")) and item.get("status") != "rejected"
        if filled != review:
            continue
        if current:
            (kind, lesson), (last_kind, last_lesson) = group(item), group(current[-1])
            # Lessons break only between lessons, so a lesson is always translated whole.
            if kind != last_kind or (len(current) >= size and (lesson is None or lesson != last_lesson)):
                batches.append(current)
                current = []
        current.append(item)
    if current:
        batches.append(current)
    out.mkdir(parents=True, exist_ok=True)
    for number, batch in enumerate(batches, 1):
        items, mapping = [], {}
        for index, item in enumerate(batch, 1):
            ident = f"s{index:03d}"
            mapping[ident] = [item["table"], item["key"]]
            row = {"id": ident, "table": item["table"], "source": item["source"]}
            for field in ("context", "layout", "max_length", "launch", "status", "previous", "problem"):
                if item.get(field):
                    row[field] = item[field]
            if item["table"] == "Learn.strings" and item["key"] in clarifications:
                note = clarifications[item["key"]]
                if item["source"] != note["source"]:
                    raise ValueError("TODO source differs from clarification: " + item["key"])
                row["source_clarification"] = note["clarification"]
            if item["table"] == "Learn.strings" and item["key"] in answer_contexts:
                row["answer_contexts"] = answer_contexts[item["key"]]
            if item.get("status") == "rejected" and item.get("translation"):
                row["rejected_text"] = item["translation"]
            if review:
                row["translation"] = item["translation"]
            if item.get("where"):
                row["where"] = ", ".join(item["where"])
                code = code_line(repo, item["where"][0])
                if code:
                    row["code"] = code
            if item["table"] == "Localizable.stringsdict":
                row["plural_forms"] = forms
            # Other app strings this one names mid-sentence ("Tap Listen to start" names the Listen button).
            refs = {k: v for k, v in names.items() if len(k) > 2 and k not in KEEP_AS_IS
                    and any(names_control(item["source"], m.start()) for m in re.finditer(rf"(?<!\w){re.escape(k)}(?!\w)", item["source"]))}
            if refs:
                row["refs"] = dict(list(refs.items())[:6])
            title = re.search(r"“(.+?)”", item.get("context", ""))
            if item["table"] == "Learn.strings" and title:
                key = "L" + hashlib.sha1(title.group(1).encode("utf-8")).hexdigest()[:10]
                if learned.get(key):
                    row["lesson_title"] = {"english": title.group(1), "translation": learned[key]}
            items.append(row)
        name = f"{loc}-{'review-' if review else ''}{number:03d}"
        doc = {"locale": loc, "language": report.LANGUAGE_NAMES.get(loc, loc), "pass": "review" if review else "translate",
               "kind": "lessons" if batch[0]["table"] == "Learn.strings" else batch[0].get("launch", "ui"), "items": items}
        (out / f"{name}.json").write_text(json.dumps(doc, ensure_ascii=False, indent=1) + "\n", encoding="utf-8")
        (out / f"{name}.map.json").write_text(json.dumps(mapping, ensure_ascii=False, indent=1) + "\n", encoding="utf-8")
    print(f"{loc}: {sum(len(b) for b in batches)} strings in {len(batches)} batches under {out}")


ANCHORS = ["Pluck your thickest string", "Tune every string", "Tap Listen to start", "Play each note as it reaches the line",
           "Tune a few times to see how close you land.", "Hold inside the green ring for a bullseye",
           "Keep your %lld-day streak alive. Next up: %@", "Keeps your streak if you miss a day",
           "A five-minute lesson keeps your streak going.",
           "Pitch is measured on your iPhone. Recordings are never saved or uploaded."]

TRANSLATE = """Translate this batch of Timbre strings from American English into {language} ({locale}).

Locale decisions and glossary for {language} (binding):
<<<
{glossary}
>>>

How Timbre already reads in {language} (current translations; match their register, terms and punctuation):
{anchors}

source_clarification records verified curriculum meaning; preserve that distinction without changing notes or answers.
When answer_contexts is present, the SAME target must work under every listed prompt and explanation.
Do not use pitch-only or past-tense wording for a key also used for physical picking directions.
Flag incompatible shared contexts instead of guessing; do not change source keys or metadata.

The batch: {count} strings, kind "{kind}". Return exactly one item per id, in the JSON format the system prompt gives.
{batch}
"""

REVIEW = """Review this batch of {language} ({locale}) translations of Timbre strings. Each item has the English
(`source`) and the current `translation`. Check meaning, the glossary, register, grammar and every hard rule of the
system prompt. Return exactly one item per id: the translation unchanged when it is right (note ""), or corrected,
with `note` saying in English what you changed and why.

Locale decisions and glossary for {language} (binding):
<<<
{glossary}
>>>

How Timbre already reads in {language}:
{anchors}

source_clarification records verified curriculum meaning; preserve that distinction without changing notes or answers.
When answer_contexts is present, the SAME target must work under every listed prompt and explanation.
Do not use pitch-only or past-tense wording for a key also used for physical picking directions.
Flag incompatible shared contexts instead of guessing; do not change source keys or metadata.

The batch: {count} strings, kind "{kind}".
{batch}
"""


def prompt(repo, loc, batch_path, glossary_path):
    sys.path.insert(0, str(repo / "tools/l10n"))
    import report
    batch = json.loads(Path(batch_path).read_text(encoding="utf-8"))
    table = report.read_strings(repo / f"ios/Timbre/Resources/{loc}.lproj/Localizable.strings")
    lines = [f"- {json.dumps(k, ensure_ascii=False)} → {json.dumps(table[k], ensure_ascii=False)}" for k in ANCHORS if k in table]
    if batch["kind"] == "lessons":
        learn_path = repo / "tools/l10n/learn" / f"{loc}.json"
        learned = json.loads(learn_path.read_text(encoding="utf-8")) if learn_path.exists() else {}
        english = report.read_strings(repo / "ios/Timbre/Resources/en.lproj/Learn.strings")
        picked = [(english[k], learned[k]) for k in english if learned.get(k) and 80 <= len(english[k]) <= 220][:6]
        lines += [f"- {json.dumps(e, ensure_ascii=False)} → {json.dumps(t, ensure_ascii=False)}" for e, t in picked]
    template = REVIEW if batch.get("pass") == "review" else TRANSLATE
    text = template.format(language=batch["language"], locale=loc, kind=batch["kind"], count=len(batch["items"]),
                           glossary=Path(glossary_path).read_text(encoding="utf-8").strip(),
                           anchors="\n".join(lines) or "(none yet)",
                           batch=json.dumps(batch["items"], ensure_ascii=False, indent=1))
    out = Path(batch_path).with_suffix(".prompt.txt")
    out.write_text(text, encoding="utf-8")
    print(f"{out}: {len(text)} characters")


def width(text, loc):
    if loc not in WIDE:
        return len(text)
    return sum(2 if unicodedata.east_asian_width(ch) in ("W", "F") else 1 for ch in text)


def problems(item, value, loc, report):
    """(errors, warnings) for one answer. Errors keep the answer out of the TODO file."""
    table, key, source = item["table"], item["key"], item["source"]
    errors = list(report.check(table, key, source, value, loc))
    texts = list(value.values()) if isinstance(value, dict) else [value]
    warnings = []
    if table == "Localizable.stringsdict":
        if isinstance(value, dict):
            wanted = set(item.get("plural_forms") or [])
            missing = sorted(wanted - set(value))
            if missing:
                warnings.append(f"plural forms missing: {', '.join(missing)}")
    reference = source if table == "Learn.strings" else (key if table != "InfoPlist.strings" else source)
    for text in texts:
        text = str(text)
        if table != "Learn.strings" and spec_list(reference) != spec_list(text):
            errors.append(f"format arguments differ (%lf, %llu and %u included): {spec_list(reference)} vs {spec_list(text)}")
        if table != "Learn.strings" and text.count("\n") != source.count("\n"):
            warnings.append("line breaks differ from the English")
        if item.get("max_length") and width(text, loc) > item["max_length"]:
            warnings.append(f"longer than max_length {item['max_length']} ({width(text, loc)})")
        for brand in ("Timbre Pro", "Timbre"):
            if text.count(brand) != source.count(brand):
                warnings.append(f"“{brand}” appears {text.count(brand)}× (English {source.count(brand)}×)")
                break
        if text.count("!") + text.count("！") > source.count("!"):
            warnings.append("an exclamation mark the English doesn't have")
        if EMOJI.search(text) and not EMOJI.search(source):
            warnings.append("an emoji the English doesn't have")
        if "…" in source and "..." in text:
            warnings.append("three dots where the English has …")
        if text != text.strip() or (source[:1].isspace() != text[:1].isspace()):
            warnings.append("leading or trailing spaces")
        if text == source and source not in KEEP_AS_IS and re.search(r"[A-Za-z]{3,}", source):
            warnings.append("identical to the English")
        if loc in RTL:
            # Numbers don't decide a paragraph's direction; a %@ (a note, a chord, a title) or a Latin word can.
            bare = re.sub(r"%(?:\d+\$)?[-+ #0]*\d*(?:\.\d+)?(?:lld|llu|ld|lu|lf|d|u|f)", "0", text)
            first = next((ch for ch in bare if unicodedata.bidirectional(ch) in ("L", "R", "AL") or ch == "%"), "")
            if first == "%" or unicodedata.bidirectional(first or " ") == "L":
                warnings.append("starts with %@ or Latin text: begin with a word of the language, or with U+200F")
        if BIDI.search(text):
            warnings.append("invisible direction marks: " + ", ".join(f"U+{ord(c):04X}" for c in BIDI.findall(text)))
    return errors, warnings


def merge(repo, loc, outputs):
    sys.path.insert(0, str(repo / "tools/l10n"))
    import report
    path = todo_path(repo, loc)
    by_key = {(item["table"], item["key"]): item for _, item in entries(path)}
    updates, failed = {}, 0
    for output in outputs:
        output = Path(output)
        stem = output.name.removesuffix(".out.json")
        mapping = json.loads((output.parent / f"{stem}.map.json").read_text(encoding="utf-8"))
        batch = {row["id"]: row for row in json.loads((output.parent / f"{stem}.json").read_text(encoding="utf-8"))["items"]}
        answer = json.loads(output.read_text(encoding="utf-8"))
        seen = set()
        for row in answer.get("items", []):
            ident = row.get("id")
            if ident not in mapping:
                print(f"{stem} {ident}: not an id of this batch")
                failed += 1
                continue
            seen.add(ident)
            item = by_key.get(tuple(mapping[ident]))
            if item is None:
                print(f"{stem} {ident}: no longer in {path.name} (translated meanwhile, or the English changed)")
                continue
            plural = row.get("plural")
            value = {k: v for k, v in plural.items() if v} if isinstance(plural, dict) else row.get("translation", "")
            if not value:
                print(f"{stem} {ident}: empty")
                failed += 1
                continue
            item = dict(item, plural_forms=batch.get(ident, {}).get("plural_forms"))
            errors, warnings = problems(item, value, loc, report)
            label = f"{stem} {ident} {item['source'][:60]!r}"
            for warning in warnings:
                print(f"WARN  {label}: {warning}")
            if row.get("note"):
                print(f"NOTE  {label}: {row['note']}")
            if errors:
                print(f"ERROR {label}: {'; '.join(errors)} -> not written")
                failed += 1
                continue
            updates[tuple(mapping[ident])] = value
        for ident in sorted(set(mapping) - seen):
            print(f"{stem} {ident}: no answer")
            failed += 1
    lines = path.read_text(encoding="utf-8").splitlines()
    for number, item in entries(path):
        ident = (item["table"], item["key"])
        if ident in updates:
            item["translation"] = updates[ident]
            comma = "," if lines[number].rstrip().endswith(",") else ""
            lines[number] = "  " + json.dumps(item, ensure_ascii=False) + comma
    path.write_text("\n".join(lines) + "\n", encoding="utf-8")
    print(f"{loc}: {len(updates)} translations written into {path}, {failed} kept out")
    return 1 if failed else 0


def main(argv):
    if len(argv) < 3 or argv[0] not in ("split", "prompt", "merge"):
        sys.exit(__doc__)
    command, repo, loc = argv[0], Path(argv[1]).resolve(), argv[2]
    if command == "split":
        size = int(argv[argv.index("--size") + 1]) if "--size" in argv else 40
        out = Path(argv[argv.index("--out") + 1]) if "--out" in argv else Path("batches")
        split(repo, loc, size, out, review="--review" in argv)
        return 0
    if command == "prompt":
        prompt(repo, loc, argv[3], argv[4])
        return 0
    return merge(repo, loc, [a for a in argv[3:] if a.endswith(".out.json")])


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
