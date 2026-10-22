"""Reuse shipped Android translations for exact native SwiftUI copy matches.

Does not create translations. Explicit/dynamic strings still require editorial review.
"""
import json
import re
from pathlib import Path

root = Path(__file__).resolve().parents[1]
table = root / "ios/Timbre/Resources/en.lproj/Localizable.strings"
pairs = re.findall(r'("(?:\\.|[^"\\])*")\s*=\s*("(?:\\.|[^"\\])*");', table.read_text(encoding="utf-8"))
by_copy = {}
for key, value in pairs:
    key, value = json.loads(key), json.loads(value)
    if "%" not in value and value:
        by_copy.setdefault(value, key)
files = ["RootView", "StudioView", "SettingsView", "VoiceView", "HistoryView"]
pattern = re.compile(r'((?:Text|Button|Label|Picker|Section|Toggle|Stepper|NavigationLink|navigationTitle|accessibilityLabel)\()"([^"\\]*)"')
for name in files:
    path = root / f"ios/Timbre/Views/{name}.swift"
    source = path.read_text(encoding="utf-8")
    changed = 0
    def replace(match):
        global changed
        key = by_copy.get(match[2])
        if key is None or key == match[2]:
            return match[0]
        changed += 1
        return match[1] + json.dumps(key)
    updated = pattern.sub(replace, source)
    path.write_text(updated, encoding="utf-8")
    print(f"{name}: {changed} existing translated copy matches")
