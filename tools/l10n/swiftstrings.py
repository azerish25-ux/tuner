#!/usr/bin/env python3
"""Find the localizable string literals in Timbre's Swift sources, without Xcode.

Xcode's own export (`xcodebuild -exportLocalizations`, the l10n.yml workflow) is the authority: it knows each
literal's type. This scanner is the quick, dependency-free approximation that `report.py` runs in CI. It
reads a literal as a localization key when it sits where Swift makes it a LocalizedStringKey,
LocalizedStringResource or String.LocalizationValue:

- the title of a SwiftUI view or modifier (Text("…"), Button("…"), .navigationTitle("…"), .accessibilityLabel("…") …),
  String(localized:), NSLocalizedString, the App Intents types (IntentDescription, DisplayRepresentation …);
- an argument of this project's own functions, initializers and memberwise initializers whose parameter is typed
  LocalizedStringKey or LocalizedStringResource;
- the value of a property, variable or function typed that way (`var title: LocalizedStringKey { switch … }`,
  `let label: LocalizedStringKey = done ? "Again" : "Start"`, `name = "Lesson"` after `let name: LocalizedStringKey`);
- an App Shortcut phrase (AppShortcuts.strings).

An interpolation becomes a format specifier as Xcode writes it (%lld for Int, %lf for Double, %@ for text …); the
type is inferred from the declarations it can see, and `report.py` settles it against the keys the string tables
already hold. `Literal.guessed` marks a key whose specifier is a guess.
"""
from __future__ import annotations

import re
from dataclasses import dataclass, field
from pathlib import Path

LOCALIZED_TYPES = {"LocalizedStringKey", "LocalizedStringResource", "IntentDialog", "TypeDisplayRepresentation",
                   "DisplayRepresentation", "IntentDescription", "LocalizationValue"}

# callee -> argument slots that take a localization key ("_0" is the first unlabeled argument). "*" = any slot.
VIEW_SLOTS = {
    "Text": {"_0"}, "Button": {"_0"}, "Label": {"_0"}, "Toggle": {"_0"}, "Picker": {"_0"}, "Section": {"_0"},
    "Menu": {"_0"}, "Link": {"_0"}, "NavigationLink": {"_0"}, "Stepper": {"_0"}, "DatePicker": {"_0"},
    "ColorPicker": {"_0"}, "ProgressView": {"_0"}, "LabeledContent": {"_0"}, "TextField": {"_0"},
    "SecureField": {"_0"}, "ContentUnavailableView": {"_0"}, "ShareLink": {"_0"}, "Tab": {"_0"}, "GroupBox": {"_0"},
    "DisclosureGroup": {"_0"}, "ControlGroup": {"_0"}, "WindowGroup": {"_0"}, "ControlWidgetButton": {"_0"},
    "ControlWidgetToggle": {"_0"}, "LocalizedStringKey": {"_0"}, "LocalizedStringResource": {"_0"},
    "NSLocalizedString": {"_0"}, "IntentDescription": {"_0"}, "IntentDialog": {"_0"},
    "String": {"localized"}, "DisplayRepresentation": {"title", "subtitle", "synonyms"},
    "TypeDisplayRepresentation": {"name"}, "Parameter": {"title", "description"}, "AppShortcut": {"shortTitle"},
    "Summary": {"_0"}, "SharePreview": {"_0"},
}
# Modifiers: only when called as `.name(`.
MODIFIER_SLOTS = {
    "navigationTitle": {"_0"}, "navigationSubtitle": {"_0"}, "accessibilityLabel": {"_0"}, "accessibilityHint": {"_0"},
    "accessibilityValue": {"_0"}, "accessibilityAction": {"named"}, "accessibilityInputLabels": {"_0"},
    "accessibilityCustomContent": {"_0"}, "help": {"_0"}, "badge": {"_0"}, "alert": {"_0"},
    "confirmationDialog": {"_0"}, "searchable": {"prompt"}, "configurationDisplayName": {"_0"},
    "description": {"_0"}, "result": {"dialog"}, "navigationBarTitle": {"_0"}, "displayName": {"_0"},
    "chartXAxisLabel": {"_0"}, "chartYAxisLabel": {"_0"}, "value": {"_0"},
}
CONTROL = {"if", "else", "switch", "for", "while", "guard", "do", "catch", "defer", "repeat", "case", "default"}
TYPE_DECL = {"struct", "class", "enum", "extension", "actor", "protocol"}
CONTINUES = {"?", ":", "??", "+", "-", "*", "&&", "||", "=", ",", "(", "[", "->", "==", "!=", "<", ">", "<=", ">=", "."}

INT_TYPES = {"Int": "%lld", "Int64": "%lld", "Int32": "%d", "Int16": "%d", "Int8": "%d", "UInt": "%llu",
             "UInt64": "%llu", "UInt32": "%u", "UInt8": "%u", "UInt16": "%u"}
FLOAT_TYPES = {"Double": "%lf", "CGFloat": "%lf", "TimeInterval": "%lf", "Float": "%f"}
NAMED_INTS = re.compile(r"^(count|total|n|index|number|days?|minutes?|seconds?|hours?|bpm|tempo|level|xp|streak|"
                        r"stars|score|points|lessons|songs|cents|percent|bars?|beats?|steps?|questions|correct|"
                        r"remaining|best|done|left|value)$", re.I)


@dataclass
class Interp:
    text: str
    tokens: list


@dataclass
class Tok:
    kind: str           # id, str, num, op, nl, attr
    value: object
    line: int
    member: bool = False  # an identifier written after "."


@dataclass
class Literal:
    table: str
    key: str
    parts: list
    file: str
    line: int
    slot: str
    guessed: bool = False
    specs: list = field(default_factory=list)


# ---------------------------------------------------------------------------------------------------------- lexer

class Lexer:
    def __init__(self, text: str):
        self.s = text
        self.comments: dict[int, str] = {}

    def tokens(self) -> list:
        toks, _, _ = self.lex(0, False, 1)
        return toks

    def lex(self, i: int, stop_paren: bool, line: int):
        s, n, out, depth = self.s, len(self.s), [], 0
        while i < n:
            c = s[i]
            if c == "\n":
                out.append(Tok("nl", "\n", line))
                line += 1
                i += 1
            elif c in " \t\r":
                i += 1
            elif s.startswith("//", i):
                end = s.find("\n", i)
                end = n if end < 0 else end
                self.comments.setdefault(line, s[i + 2:end].lstrip("/ ").rstrip())
                i = end
            elif s.startswith("/*", i):
                level, j = 1, i + 2
                while j < n and level:
                    if s.startswith("/*", j):
                        level, j = level + 1, j + 2
                    elif s.startswith("*/", j):
                        level, j = level - 1, j + 2
                    else:
                        j += 1
                line += s.count("\n", i, j)
                i = j
            elif c == '"' or (c == "#" and re.match(r'#+"', s[i:])):
                hashes = len(re.match(r"#*", s[i:]).group(0))
                tok, i, line = self.string(i + hashes, hashes, line)
                out.append(tok)
            elif c.isalpha() or c == "_" or c == "$" or c == "`":
                m = re.match(r"`?[\w$]+`?", s[i:])
                word = m.group(0).strip("`")
                member = bool(out) and out[-1].kind == "op" and out[-1].value == "." and not (
                    len(out) > 1 and out[-2].kind == "op" and out[-2].value == "\\")
                out.append(Tok("id", word, line, member))
                i += m.end()
            elif c == "@" or c == "#":
                m = re.match(r"[@#]\w+", s[i:])
                if m:
                    out.append(Tok("attr", m.group(0)[1:], line))
                    i += m.end()
                else:
                    out.append(Tok("op", c, line))
                    i += 1
            elif c.isdigit():
                m = re.match(r"0x[0-9a-fA-F_]+|[\d_]+(\.\d[\d_]*)?([eE][+-]?\d+)?", s[i:])
                out.append(Tok("num", m.group(0), line))
                i += m.end()
            else:
                m = re.match(r"->|\?\?|==|!=|<=|>=|&&|\|\||\.\.\.|\.\.<|[-+*/%]=|.", s[i:], re.S)
                op = m.group(0)
                if stop_paren:
                    if op == "(":
                        depth += 1
                    elif op == ")":
                        if depth == 0:
                            return out, i + 1, line
                        depth -= 1
                out.append(Tok("op", op, line))
                i += m.end()
        return out, i, line

    def string(self, i: int, hashes: int, line: int):
        """A string literal starting at its opening quote (after any #s). Returns (Tok, end, line)."""
        s, start_line = self.s, line
        multi = s.startswith('"""', i)
        close = ('"""' if multi else '"') + "#" * hashes
        interp = "\\" + "#" * hashes + "("
        esc = "\\" + "#" * hashes
        i += 3 if multi else 1
        parts, buf = [], []
        while i < len(s):
            if s.startswith(close, i):
                i += len(close)
                break
            if s.startswith(interp, i):
                if buf:
                    parts.append("".join(buf))
                    buf = []
                toks, j, line2 = self.lex(i + len(interp), True, line)
                parts.append(Interp(s[i + len(interp):j - 1], toks))
                line = line2
                i = j
                continue
            if s.startswith(esc, i) and i + len(esc) < len(s):
                ch = s[i + len(esc)]
                i += len(esc) + 1
                if ch == "u" and s[i:i + 1] == "{":
                    end = s.index("}", i)
                    buf.append(chr(int(s[i + 1:end], 16)))
                    i = end + 1
                elif ch == "\n":  # line continuation in a multi-line literal
                    buf.append("\u0000CONT")
                    line += 1
                else:
                    buf.append({"n": "\n", "t": "\t", "r": "\r", "0": "\0"}.get(ch, ch))
                continue
            if s[i] == "\n":
                line += 1
            buf.append(s[i])
            i += 1
        if buf:
            parts.append("".join(buf))
        if multi:
            parts = dedent_multiline(parts)
        return Tok("str", parts, start_line), i, line


def dedent_multiline(parts: list) -> list:
    """Applies Swift's multi-line literal rules: drop the first and last line breaks and the closing indentation."""
    text_parts = [p for p in parts if isinstance(p, str)]
    last = text_parts[-1] if text_parts else ""
    indent = last[last.rfind("\n") + 1:] if "\n" in last else ""
    out = []
    for index, part in enumerate(parts):
        if isinstance(part, Interp):
            out.append(part)
            continue
        text = part
        if index == 0 and text.startswith("\n"):
            text = text[1:]
        if index == len(parts) - 1:
            cut = text.rfind("\n")
            text = text[:cut] if cut >= 0 else ""
        if indent:
            lines = text.split("\n")
            text = "\n".join(line[len(indent):] if line.startswith(indent) else line for line in lines)
        out.append(text)
    joined = []
    for part in out:
        if isinstance(part, str):
            part = re.sub(r"\u0000CONT[ \t]*\n?", "", part)
        joined.append(part)
    return [p for p in joined if not (isinstance(p, str) and p == "")] or [""]


# ----------------------------------------------------------------------------------------------- declarations

def sig(tokens: list, i: int) -> int:
    """Index of the next significant token at or after i (skips line breaks)."""
    while i < len(tokens) and tokens[i].kind == "nl":
        i += 1
    return i


def prev_sig(tokens: list, i: int) -> int:
    i -= 1
    while i >= 0 and tokens[i].kind == "nl":
        i -= 1
    return i


def match_close(tokens: list, i: int) -> int:
    """Index of the bracket closing the one at i."""
    pairs = {"(": ")", "[": "]", "{": "}", "<": ">"}
    opener, closer, depth = tokens[i].value, pairs[tokens[i].value], 0
    for j in range(i, len(tokens)):
        t = tokens[j]
        if t.kind != "op":
            continue
        if t.value == opener:
            depth += 1
        elif t.value == closer:
            depth -= 1
            if depth == 0:
                return j
        elif opener == "<" and t.value in "{(;=":
            return i
    return len(tokens) - 1


def type_text(tokens: list) -> str:
    return "".join(str(t.value) for t in tokens if t.kind != "nl")


def is_localized_type(text: str) -> bool:
    base = text.replace("?", "").replace("!", "").replace("SwiftUI.", "").replace("String.", "")
    return base in LOCALIZED_TYPES or bool(re.fullmatch(r"\[(%s)\]" % "|".join(LOCALIZED_TYPES), base))


def tuple_positions(text: str) -> set:
    """Positions typed LocalizedStringKey in a tuple type such as [(String, LocalizedStringKey, String)]."""
    m = re.search(r"\(([^()]*)\)", text)
    if not m:
        return set()
    return {i for i, part in enumerate(m.group(1).split(",")) if is_localized_type(part.split(":")[-1].strip())}


def split_params(tokens: list) -> list:
    """Splits the tokens inside a parameter list at depth-0 commas."""
    params, cur, depth = [], [], 0
    for t in tokens:
        if t.kind == "op" and t.value in "([{<":
            depth += 1
        elif t.kind == "op" and t.value in ")]}>":
            depth -= 1
        if depth == 0 and t.kind == "op" and t.value == ",":
            params.append(cur)
            cur = []
        elif t.kind != "nl":
            cur.append(t)
    if cur:
        params.append(cur)
    return params


def parse_params(tokens: list) -> list:
    """[(label or None, localized?)] for a parameter list's tokens."""
    out = []
    for p in split_params(tokens):
        p = [t for t in p if t.kind != "attr"]
        colon = next((k for k, t in enumerate(p) if t.kind == "op" and t.value == ":"), None)
        if colon is None or colon == 0:
            continue
        names = [t.value for t in p[:colon] if t.kind == "id"]
        label = names[0] if names else None
        if label == "_" or not names:
            label = None
        eq = next((k for k, t in enumerate(p) if t.kind == "op" and t.value == "=" and k > colon), len(p))
        typ = type_text(p[colon + 1:eq]).replace("inout", "")
        out.append((label, is_localized_type(typ)))
    return out


@dataclass
class Decls:
    callables: dict = field(default_factory=dict)    # name -> [(file, private?, [(label, localized)])]
    members: dict = field(default_factory=dict)      # type name -> {stored localized property names}
    type_props: dict = field(default_factory=dict)   # type name -> {property: type}
    prop_types: dict = field(default_factory=dict)   # property name -> {type: count}, every type
    func_types: dict = field(default_factory=dict)   # function name -> {return type: count}
    type_funcs: dict = field(default_factory=dict)   # type name -> {function: return type}
    types: set = field(default_factory=set)          # every type declared
    enum_cases: dict = field(default_factory=dict)   # enum case name -> [associated value types]
    file_decls: dict = field(default_factory=dict)   # file -> [(line, name, type)]
    loc_vars: dict = field(default_factory=dict)     # file -> {names declared with a localized type}
    sinks: set = field(default_factory=set)          # (type, property) read through LocalizedStringKey(x.property)


def vote(counts: dict, name: str, typ: str) -> None:
    base = typ.replace("?", "").replace("!", "").strip()
    if base and base != "Bool":
        bucket = counts.setdefault(name, {})
        bucket[base] = bucket.get(base, 0) + 1


def majority(counts: dict | None):
    if not counts:
        return None
    return max(sorted(counts), key=lambda k: counts[k])


def type_end(tokens: list, k: int) -> int:
    """Index after a type annotation that starts at k."""
    end, level = k, 0
    while end < len(tokens):
        x = tokens[end]
        if x.kind == "op" and x.value in "([<":
            level += 1
        elif x.kind == "op" and x.value in ")]>":
            if level == 0:
                break
            level -= 1
        elif level == 0 and (x.kind == "nl" or (x.kind == "op" and x.value in "={;,")):
            break
        end += 1
    return end


def collect_decls(path: str, tokens: list, decls: Decls) -> None:
    file_decls = decls.file_decls.setdefault(path, [])
    loc_vars = decls.loc_vars.setdefault(path, set())
    type_stack = []  # (type name, brace depth)
    depth = 0
    i = 0
    n = len(tokens)
    while i < n:
        t = tokens[i]
        if t.kind == "op" and t.value == "{":
            depth += 1
        elif t.kind == "op" and t.value == "}":
            depth -= 1
            while type_stack and type_stack[-1][1] > depth:
                type_stack.pop()
        elif t.kind == "id" and t.value in TYPE_DECL and not t.member:
            j = sig(tokens, i + 1)
            if j < n and tokens[j].kind == "id":
                name = tokens[j].value
                k = j
                while k < n and not (tokens[k].kind == "op" and tokens[k].value in "{;"):
                    k += 1
                if k < n and tokens[k].value == "{":
                    type_stack.append((name, depth + 1))
                    decls.types.add(name)
        elif t.kind == "id" and t.value in ("func", "init") and not t.member:
            private = any(tokens[k].kind == "id" and tokens[k].value in ("private", "fileprivate")
                          for k in range(max(0, i - 3), i))
            name = None
            j = sig(tokens, i + 1)
            if t.value == "func" and j < n and tokens[j].kind in ("id", "op"):
                name = str(tokens[j].value)
                j = sig(tokens, j + 1)
            elif t.value == "init":
                name = type_stack[-1][0] if type_stack else None
                while j < n and tokens[j].kind == "op" and tokens[j].value in "?!":
                    j += 1
            if j < n and tokens[j].kind == "op" and tokens[j].value == "<":
                j = sig(tokens, match_close(tokens, j) + 1)
            if name and j < n and tokens[j].kind == "op" and tokens[j].value == "(":
                close = match_close(tokens, j)
                decls.callables.setdefault(name, []).append((path, private, parse_params(tokens[j + 1:close])))
                for p in split_params(tokens[j + 1:close]):
                    colon = next((k for k, x in enumerate(p) if x.kind == "op" and x.value == ":"), None)
                    names = [x.value for x in p[:colon] if x.kind == "id"] if colon else []
                    if names:
                        typ = type_text(p[colon + 1:]).split("=")[0]
                        file_decls.append((p[0].line, names[-1], typ))
                        if is_localized_type(typ):
                            loc_vars.add(names[-1])
                k = close + 1
                while k < n and not (tokens[k].kind == "op" and tokens[k].value in "{=") and tokens[k].kind != "nl":
                    if tokens[k].kind == "op" and tokens[k].value == "->" and t.value == "func":
                        end = type_end(tokens, k + 1)
                        while end < n and not (tokens[end].kind == "op" and tokens[end].value == "{") \
                                and tokens[end].kind != "nl":
                            end += 1
                        ret = type_text(tokens[k + 1:end]).replace("where", " ").split(" ")[0]
                        vote(decls.func_types, name, ret)
                        if type_stack:
                            decls.type_funcs.setdefault(type_stack[-1][0], {})[name] = ret
                        break
                    k += 1
        elif t.kind == "id" and t.value in ("let", "var") and not t.member:
            j = sig(tokens, i + 1)
            if j < n and tokens[j].kind == "id":
                name = tokens[j].value
                k = sig(tokens, j + 1)
                typ = None
                if k < n and tokens[k].kind == "op" and tokens[k].value == ":":
                    typ = type_text(tokens[k + 1:type_end(tokens, k + 1)])
                elif k < n and tokens[k].kind == "op" and tokens[k].value == "=":
                    typ = infer_value_type(tokens, sig(tokens, k + 1), path, decls)
                    if typ is None:  # typed later, once every declaration is known
                        p = prev_sig(tokens, i)
                        condition = p >= 0 and tokens[p].kind in ("id", "op") and tokens[p].value in ("if", "guard", "while", ",")
                        file_decls.append((t.line, name, ("=", initializer(tokens, k + 1, condition))))
                if typ:
                    file_decls.append((t.line, name, typ))
                    vote(decls.prop_types, name, typ)
                    if type_stack and type_stack[-1][1] == depth:
                        decls.type_props.setdefault(type_stack[-1][0], {})[name] = typ
                    if is_localized_type(typ) or tuple_positions(typ):
                        loc_vars.add(name)
                        if type_stack and type_stack[-1][1] == depth and is_localized_type(typ):
                            decls.members.setdefault(type_stack[-1][0], set()).add(name)
        elif t.kind == "id" and t.value == "case" and not t.member:
            collect_case(tokens, i, path, decls, bool(type_stack) and type_stack[-1][1] == depth)
        i += 1


def collect_case(tokens: list, i: int, path: str, decls: Decls, in_type_body: bool) -> None:
    """`case drift(name: String, cents: Int)` in an enum records the associated types; `case let .drift(name, cents)`
    in a switch types its bindings from them."""
    n = len(tokens)
    j = sig(tokens, i + 1)
    if in_type_body and j + 1 < n and tokens[j].kind == "id" and tokens[j + 1].kind == "op" and tokens[j + 1].value == "(":
        close = match_close(tokens, j + 1)
        types = []
        for p in split_params(tokens[j + 2:close]):
            colon = next((k for k, x in enumerate(p) if x.kind == "op" and x.value == ":"), None)
            types.append(type_text(p[colon + 1:] if colon is not None else p).split("=")[0])
        decls.enum_cases[tokens[j].value] = types
        return
    outer_let = j < n and tokens[j].kind == "id" and tokens[j].value in ("let", "var")
    if outer_let:
        j = sig(tokens, j + 1)
    if not (j + 2 < n and tokens[j].kind == "op" and tokens[j].value == "." and tokens[j + 1].kind == "id"
            and tokens[j + 2].kind == "op" and tokens[j + 2].value == "("):
        return
    name = tokens[j + 1].value
    close = match_close(tokens, j + 2)
    for index, p in enumerate(split_params(tokens[j + 3:close])):
        ids = [x for x in p if x.kind == "id" and x.value not in ("let", "var")]
        if (outer_let or any(x.kind == "id" and x.value in ("let", "var") for x in p)) and len(ids) == 1 \
                and ids[0].value != "_":
            decls.file_decls.setdefault(path, []).append((tokens[j].line, ids[-1].value, ("case", name, index)))


def initializer(tokens: list, i: int, condition: bool) -> list:
    """The tokens of an initializer expression starting at i (up to the end of its statement or condition)."""
    out, level = [], 0
    while i < len(tokens):
        x = tokens[i]
        if level == 0 and (x.kind == "nl" or (x.kind == "op" and x.value == ";")):
            break
        if level == 0 and condition and ((x.kind == "op" and x.value in ",{") or (x.kind == "id" and x.value == "else")):
            break
        if x.kind == "op" and x.value in "([{":
            level += 1
        elif x.kind == "op" and x.value in ")]}":
            level -= 1
            if level < 0:
                break
        out.append(x)
        i += 1
    return out


def infer_value_type(tokens: list, i: int, path: str = "", decls: "Decls | None" = None):
    """The type of a `let x = …` initializer, when it is obvious."""
    if i >= len(tokens):
        return None
    t = tokens[i]
    nxt = tokens[i + 1] if i + 1 < len(tokens) else None
    ends = nxt is None or nxt.kind == "nl" or (nxt.kind == "op" and nxt.value in ";,)}")
    if t.kind == "num":
        if ends or (nxt.kind == "op" and nxt.value in "+-*/"):
            return "Double" if "." in t.value else "Int"
        return None
    if t.kind == "str":
        return "String"
    if t.kind == "id" and t.value in list(INT_TYPES) + list(FLOAT_TYPES) + ["String", "Text"] and nxt is not None \
            and nxt.kind == "op" and nxt.value == "(":
        return t.value
    if t.kind == "id" and t.value in ("lround",):
        return "Int"
    # … .count, … .formatted()
    j = i
    level = 0
    while j < len(tokens) and not (level == 0 and (tokens[j].kind == "nl" or (tokens[j].kind == "op" and tokens[j].value == ";"))):
        x = tokens[j]
        if x.kind == "op" and x.value in "([{":
            level += 1
        elif x.kind == "op" and x.value in ")]}":
            level -= 1
            if level < 0:
                break
        elif level == 0 and x.kind == "id" and x.value == "count" and x.member:
            nx = tokens[j + 1] if j + 1 < len(tokens) else None
            if nx is None or nx.kind == "nl" or (nx.kind == "op" and nx.value in "+-*/;),"):
                return "Int"
        elif level == 0 and x.kind == "id" and x.value in ("formatted", "uppercased", "lowercased", "capitalized"):
            return "String"
        j += 1
    return None


# ----------------------------------------------------------------------------------------- interpolation specs

def spec_of_type(typ: str | None):
    if not typ:
        return None
    base = typ.replace("?", "").replace("!", "").strip()
    if base in INT_TYPES:
        return INT_TYPES[base]
    if base in FLOAT_TYPES:
        return FLOAT_TYPES[base]
    return "%@"


def local_type(path: str, line: int, name: str, decls: Decls, floor: int = 0, owner: tuple = (None, 0), depth: int = 0):
    """The type of the nearest declaration of `name` above `line` (and below `floor`) in the same file."""
    best = None
    for decl_line, decl_name, typ in decls.file_decls.get(path, []):
        if decl_name == name and floor <= decl_line <= line and (best is None or decl_line >= best[0]):
            best = (decl_line, typ)
    if best and isinstance(best[1], tuple) and best[1][0] == "case":
        types = decls.enum_cases.get(best[1][1], [])
        return types[best[1][2]] if best[1][2] < len(types) else None
    if best and isinstance(best[1], tuple):
        if depth > 4:
            return None
        return expr_type(best[1][1], path, decls, best[0], owner, depth + 1)[0]
    return best[1] if best else None


GENERIC_CALLS = {"map", "flatMap", "compactMap", "reduce", "first", "last", "min", "max", "filter", "sorted",
                 "randomElement", "prefix", "suffix", "dropFirst", "dropLast"}


def skip_group(toks: list, k: int) -> int:
    """Index of the bracket closing the one at k."""
    pairs = {"(": ")", "[": "]", "{": "}"}
    opener, closer, level = toks[k].value, pairs.get(toks[k].value), 0
    for m in range(k, len(toks)):
        if toks[m].kind == "op" and toks[m].value == opener:
            level += 1
        elif toks[m].kind == "op" and toks[m].value == closer:
            level -= 1
            if level == 0:
                return m
    return len(toks) - 1


def element_type(typ: str):
    """[K: V] -> V, [T] -> T."""
    base = typ.replace("?", "").strip()
    m = re.fullmatch(r"\[(.+)\]", base)
    if not m:
        return None
    inner = m.group(1)
    level = 0
    for index, ch in enumerate(inner):
        if ch in "[(<":
            level += 1
        elif ch in "])>":
            level -= 1
        elif ch == ":" and level == 0:
            return inner[index + 1:]
    return inner


def interp_spec(part: Interp, path: str, decls: Decls, line: int = 0, owner: tuple = (None, 0)):
    """(specifier, guessed) for one interpolation, as Xcode would write it in the key. `owner` is the enclosing type
    and the line its body opens on."""
    toks = [t for t in part.tokens if t.kind != "nl"]
    for k, t in enumerate(toks):
        if t.kind == "id" and t.value == "specifier" and k + 2 < len(toks) and toks[k + 2].kind == "str":
            return "".join(p for p in toks[k + 2].value if isinstance(p, str)), False
    typ, guessed = expr_type(toks, path, decls, line, owner)
    return spec_of_type(typ) or "%@", guessed


def expr_type(toks: list, path: str, decls: Decls, line: int, owner: tuple, depth: int = 0):
    """(type name or None, guessed) of an expression's tokens, as far as the declarations seen tell."""
    toks = [t for t in toks if t.kind != "nl"]
    for k, t in enumerate(toks):
        if t.kind == "id" and t.value in ("format", "style", "formatter") and k + 1 < len(toks) \
                and toks[k + 1].kind == "op" and toks[k + 1].value == ":":
            return "String", False
    if not toks:
        return None, True
    branch = ternary_branch(toks)
    if branch is not None:
        return expr_type(branch, path, decls, line, owner, depth + 1)
    first = toks[0]
    call = len(toks) > 1 and toks[1].kind == "op" and toks[1].value == "("
    if first.kind == "str":
        return "String", False
    if first.kind == "id" and first.value in ("Text", "Image", "AttributedString", "String") and call:
        return first.value, False
    if first.kind == "id" and (first.value in INT_TYPES or first.value in FLOAT_TYPES) and call:
        return first.value, False
    if first.kind == "id" and first.value == "lround":
        return "Int", False
    if first.kind == "num":
        return ("Double" if "." in first.value else "Int"), False
    if first.kind == "op" and first.value == "(" and len(toks) > 2:
        return expr_type(toks[1:], path, decls, line, owner, depth + 1)
    if first.kind == "id" and first.value in ("max", "min", "abs") and len(toks) > 2:
        return expr_type(toks[2:], path, decls, line, owner, depth + 1)
    # Follow the leading member chain a.b.c(…).d, typing each step from the declarations seen.
    typ, last, started, k = None, None, False, 0
    own, own_line = owner[0], owner[1]
    dollar0 = owner[2] if len(owner) > 2 else None
    while k < len(toks):
        t = toks[k]
        if t.kind == "op" and t.value in (".", "?", "!"):
            k += 1
            continue
        if t.kind != "id":
            break
        name = t.value
        is_call = k + 1 < len(toks) and toks[k + 1].kind == "op" and toks[k + 1].value == "("
        if not started:
            if name in ("self", "Self"):
                typ = own
            elif name == "$0":
                typ = dollar0
            elif is_call:
                typ = decls.type_funcs.get(own, {}).get(name) or majority(decls.func_types.get(name))
            elif name in decls.types and k + 1 < len(toks) and toks[k + 1].value == ".":
                typ = name  # a static member: NoteName.pitchClass(…)
            elif depth < 4:
                typ = (local_type(path, line, name, decls, own_line, owner, depth)
                       or decls.type_props.get(own, {}).get(name)
                       or local_type(path, line, name, decls, 0, owner, depth)
                       or majority(decls.prop_types.get(name)))
            started = True
        else:
            base = (typ or "").replace("?", "").replace("!", "").strip()
            if is_call and name in GENERIC_CALLS:
                typ = None
            elif is_call:
                typ = decls.type_funcs.get(base, {}).get(name) or majority(decls.func_types.get(name))
            else:
                typ = decls.type_props.get(base, {}).get(name) or majority(decls.prop_types.get(name))
        last = name
        if is_call:
            k = skip_group(toks, k + 1)
            # A trailing closure: map { … }
        k += 1
        while k < len(toks) and toks[k].kind == "op" and toks[k].value in ("[", "{", "?", "!"):
            if toks[k].value in ("?", "!"):
                # An optional subscript, `fingers?[safe: i]`: the element type, like a plain subscript.
                if k + 1 < len(toks) and toks[k + 1].kind == "op" and toks[k + 1].value == "[":
                    k += 1
                    continue
                break
            if toks[k].value == "[" and isinstance(typ, str):
                typ = element_type(typ)
            elif toks[k].value == "{":
                typ = None if last in GENERIC_CALLS else typ
            k = skip_group(toks, k) + 1
    rest = toks[k:]
    for m, t in enumerate(rest[:-1]):
        if t.kind == "op" and t.value == "??" and rest[m + 1].kind in ("num", "str"):
            fallback = rest[m + 1]
            if fallback.kind == "str":
                return "String", False
            return ("Double" if "." in fallback.value else "Int"), False
    arithmetic_int = any(t.kind == "op" and t.value in ("+", "-") for t in rest) and \
        any(t.kind == "num" and "." not in t.value for t in rest)
    if last == "count":
        return "Int", False
    if last in ("formatted", "uppercased", "lowercased", "capitalized", "joined", "localized", "description"):
        return "String", False
    if typ and isinstance(typ, str):
        return typ, False
    if arithmetic_int or (last and NAMED_INTS.match(last)):
        return "Int", True
    return None, True


def ternary_branch(toks: list):
    """The first branch of a top-level conditional expression (`c ? a : b` -> the tokens of `a`), or None. Both
    branches of a Swift conditional have one type, and the condition's own type (often a Double compared with 0)
    says nothing about it. A `?` followed by `.`, `[`, `)` or `,` is optional chaining, not a conditional."""
    level, question = 0, None
    for k, t in enumerate(toks):
        if t.kind != "op":
            continue
        if t.value in ("(", "[", "{"):
            level += 1
        elif t.value in (")", "]", "}"):
            level -= 1
        elif level == 0 and t.value == "?" and question is None:
            after = toks[k + 1] if k + 1 < len(toks) else None
            if after is not None and not (after.kind == "op" and after.value in (".", "[", ")", ",")):
                question = k
        elif level == 0 and t.value == ":" and question is not None:
            return toks[question + 1:k] or None
    return None


def make_key(parts: list, path: str, decls: Decls, shortcut: bool = False, line: int = 0, owner: tuple = (None, 0)):
    if shortcut:
        out = []
        for p in parts:
            if isinstance(p, Interp):
                name = re.sub(r"[^\w]", "", p.text.replace("\\.", "").replace(".", "").replace("$", ""))
                out.append("${%s}" % name)
            else:
                out.append(p)
        return "".join(out), [], False
    has_interp = any(isinstance(p, Interp) for p in parts)
    out, specs, guessed = [], [], False
    for p in parts:
        if isinstance(p, Interp):
            spec, guess = interp_spec(p, path, decls, line, owner)
            out.append(spec)
            specs.append(spec)
            guessed = guessed or guess
        else:
            out.append(p.replace("%", "%%") if has_interp else p)
    return "".join(out), specs, guessed


# ---------------------------------------------------------------------------------------------- literal scan

@dataclass
class Group:
    opener: str
    callee: str | None = None
    member: bool = False
    index: int = 0             # unlabeled arguments so far
    label: str | None = None   # label of the current argument
    arg_start: bool = True
    localized_body: bool = False
    tuple_pos: set = field(default_factory=set)
    state: str | None = None   # statement state: "loc", "nonloc" or None
    commas: int = 0
    owner: tuple | None = None  # (type name, line) when this brace is a type's body
    dollar0: str | None = None  # the type of $0 when this brace is a closure such as `rank.map { … }`


def callee_slots(group: Group, decls: Decls, path: str):
    """True/False when the group's call decides; None when the call is unknown (or a bare parenthesis)."""
    name = group.callee
    if name is None:
        return None
    slot = group.label if group.label else f"_{group.index}"
    if group.member and name in MODIFIER_SLOTS:
        return slot in MODIFIER_SLOTS[name]
    if not group.member and name in VIEW_SLOTS:
        return slot in VIEW_SLOTS[name]
    found = decls.callables.get(name, [])
    # A function declared in this file shadows the project's others (each file's private `stat(…)`).
    here = [params for file, _, params in found if file == path]
    candidates = here or [params for file, private, params in found if not private]
    for params in candidates:
        if group.label:
            if any(lbl == group.label and loc for lbl, loc in params):
                return True
        else:
            unlabeled = [loc for lbl, loc in params if lbl is None]
            if group.index < len(unlabeled) and unlabeled[group.index]:
                return True
    if not group.member and group.label and group.label in decls.members.get(name, set()):
        return True
    if not group.member and group.label and (name, group.label) in decls.sinks:
        return True
    return False


def scan_file(path: str, text: str, decls: Decls, tokens: list, rel: str) -> list:
    found = []
    walk(tokens, path, rel, decls, found, [Group("file")])
    return found


def walk(tokens: list, path: str, rel: str, decls: Decls, found: list, stack: list) -> None:
    loc_vars = decls.loc_vars.get(path, set())
    n = len(tokens)
    pending_body = None  # (localized?, tuple positions) for the next "{"
    pending_type = None  # a type declaration's name, for the next "{"
    i = 0
    while i < n:
        t = tokens[i]
        g = stack[-1]
        if t.kind == "nl":
            p, q = prev_sig(tokens, i), sig(tokens, i + 1)
            before = tokens[p] if p >= 0 else None
            after = tokens[q] if q < n else None
            cont = (before is not None and before.kind == "op" and before.value in CONTINUES) or \
                   (after is not None and after.kind == "op" and after.value in ("?", ":", ".", "??", "+", "&&", "||"))
            if not cont:
                g.state = None
            i += 1
            continue
        if t.kind == "op" and t.value in "([{":
            new = Group(t.value)
            p = prev_sig(tokens, i)
            prev = tokens[p] if p >= 0 else None
            if t.value == "(" and prev is not None and prev.kind in ("id", "attr") and tokens[i - 1].kind != "nl":
                new.callee, new.member = prev.value, prev.member
            elif t.value == "(" and prev is not None and prev.kind == "op" and prev.value == ">":
                # Generic call: Name<T>(…)
                k = p
                level = 0
                while k >= 0:
                    if tokens[k].kind == "op" and tokens[k].value == ">":
                        level += 1
                    elif tokens[k].kind == "op" and tokens[k].value == "<":
                        level -= 1
                        if level == 0:
                            break
                    k -= 1
                if k > 0 and tokens[k - 1].kind == "id":
                    new.callee, new.member = tokens[k - 1].value, tokens[k - 1].member
            if t.value == "{" and pending_type is not None:
                new.owner = (pending_type, t.line)
                pending_type = None
            if t.value == "{":
                new.dollar0 = closure_element(tokens, i, path, decls, stack)
            if t.value == "{":
                if pending_body is not None:
                    new.localized_body, new.tuple_pos = pending_body
                    pending_body = None
                else:
                    head = statement_head(tokens, i)
                    if head in CONTROL or head == "in_switch":
                        new.localized_body, new.tuple_pos = g.localized_body or g.state == "loc", g.tuple_pos
            if t.value in "([" and (g.localized_body or g.state == "loc") and new.callee is None:
                new.localized_body, new.tuple_pos = True, g.tuple_pos
                new.state = None
            stack.append(new)
            i += 1
            continue
        if t.kind == "op" and t.value in ")]}":
            if len(stack) > 1:
                stack.pop()
            stack[-1].arg_start = False
            i += 1
            continue
        if t.kind == "op" and t.value == "," and g.opener in "([":
            g.commas += 1
            if g.label is None:
                g.index += 1
            g.label, g.arg_start, g.state = None, True, None
            i += 1
            continue
        if t.kind == "op" and t.value == ";":
            g.state = None
            i += 1
            continue
        if g.opener in "([" and g.arg_start and t.kind == "id":
            q = sig(tokens, i + 1)
            if q < n and tokens[q].kind == "op" and tokens[q].value == ":":
                g.label = t.value
                g.arg_start = False
                i = q + 1
                continue
        if t.kind != "nl":
            g.arg_start = False
        if t.kind == "id" and t.value in TYPE_DECL and not t.member:
            j = sig(tokens, i + 1)
            if j < n and tokens[j].kind == "id":
                pending_type = tokens[j].value
        # Declarations that make what follows localized.
        if t.kind == "id" and t.value in ("let", "var") and not t.member:
            j = sig(tokens, i + 1)
            k = sig(tokens, j + 1)
            if j < n and tokens[j].kind == "id" and k < n and tokens[k].kind == "op" and tokens[k].value == ":":
                end = k + 1
                level = 0
                while end < n:
                    x = tokens[end]
                    if x.kind == "op" and x.value in "([<":
                        level += 1
                    elif x.kind == "op" and x.value in ")]>":
                        level -= 1
                    elif level == 0 and (x.kind == "nl" or (x.kind == "op" and x.value in "={;")):
                        break
                    end += 1
                typ = type_text(tokens[k + 1:end])
                loc = is_localized_type(typ)
                tpos = tuple_positions(typ)
                if end < n and tokens[end].kind == "op" and tokens[end].value == "{":
                    pending_body = (loc or bool(tpos), tpos)
                elif end < n and tokens[end].kind == "op" and tokens[end].value == "=":
                    g.state = "loc" if (loc or tpos) else "nonloc"
                    g.tuple_pos = tpos or g.tuple_pos
                    i = end + 1
                    continue
                i = end
                continue
            if j < n and tokens[j].kind == "id" and k < n and tokens[k].kind == "op" and tokens[k].value == "=":
                g.state = "nonloc"
                i = k + 1
                continue
        if t.kind == "id" and t.value == "func" and not t.member:
            j = i + 1
            while j < n and not (tokens[j].kind == "op" and tokens[j].value in "{"):
                if tokens[j].kind == "op" and tokens[j].value == "(":
                    j = match_close(tokens, j)
                j += 1
            arrow = None
            for k in range(i, j):
                if tokens[k].kind == "op" and tokens[k].value == "->":
                    arrow = k
            if arrow is not None:
                typ = type_text(tokens[arrow + 1:j])
                tpos = tuple_positions(typ)
                pending_body = (is_localized_type(typ) or bool(tpos), tpos)
            else:
                pending_body = (False, set())
            # Walk the parameter list normally (default values are not localized).
            i += 1
            continue
        if t.kind == "id" and t.value in loc_vars:
            q = sig(tokens, i + 1)
            if q < n and tokens[q].kind == "op" and tokens[q].value == "=" and g.state is None:
                g.state = "loc"
                i = q + 1
                continue
        if t.kind == "id" and t.value == "return":
            g.state = None
        if t.kind == "str":
            handle_literal(tokens, i, t, stack, path, rel, decls, found)
            for part in t.value:
                if isinstance(part, Interp):
                    walk(part.tokens, path, rel, decls, found, [Group("interp", owner=enclosing(stack))])
        i += 1


def enclosing(stack: list) -> tuple:
    """(enclosing type, the line its body opens on, the type of $0 in the innermost typed closure)."""
    dollar0 = next((grp.dollar0 for grp in reversed(stack) if grp.dollar0), None)
    for grp in reversed(stack):
        if grp.owner:
            return grp.owner + (dollar0,)
    return (None, 0, dollar0)


ELEMENT_CALLS = {"map", "flatMap", "compactMap", "filter", "first", "contains", "forEach", "allSatisfy", "sorted",
                 "min", "max"}


def closure_element(tokens: list, i: int, path: str, decls: Decls, stack: list):
    """The type of $0 in a closure opening at i after `receiver.map` (an Optional's or an array's element)."""
    p = prev_sig(tokens, i)
    if p < 1 or tokens[p].kind != "id" or tokens[p].value not in ELEMENT_CALLS or not tokens[p].member:
        return None
    k = p - 1  # the "."
    start = k
    level = 0
    while start - 1 >= 0:
        x = tokens[start - 1]
        if x.kind == "op" and x.value in ")]":
            level += 1
        elif x.kind == "op" and x.value in "([":
            if level == 0:
                break
            level -= 1
        elif level == 0 and not (x.kind == "id" or (x.kind == "op" and x.value in ".?!")):
            break
        elif x.kind == "nl":
            break
        start -= 1
    receiver = tokens[start:k]
    if not receiver:
        return None
    typ, _ = expr_type(receiver, path, decls, tokens[i].line, enclosing(stack))
    if not typ:
        return None
    base = typ.strip()
    if base.endswith("?"):
        return base[:-1]
    return element_type(base)


def statement_head(tokens: list, i: int) -> str | None:
    """The keyword that starts the statement whose block opens at i (if, switch, …), or None."""
    j = i - 1
    level = 0
    while j >= 0:
        t = tokens[j]
        if t.kind == "op" and t.value in ")]":
            level += 1
        elif t.kind == "op" and t.value in "([":
            if level == 0:
                return None
            level -= 1
        elif level == 0 and t.kind == "op" and t.value in "{};":
            return None
        elif level == 0 and t.kind == "id" and t.value in CONTROL and not t.member:
            return t.value
        elif level == 0 and t.kind == "id" and t.value == "in":
            return None
        elif level == 0 and t.kind == "nl":
            p = prev_sig(tokens, j)
            if p < 0 or not (tokens[p].kind == "op" and tokens[p].value in CONTINUES):
                k = sig(tokens, j + 1)
                if not (tokens[k].kind == "op" and tokens[k].value in ("?", ":", ".", "&&", "||", ",")):
                    return None
        j -= 1
    return None


def handle_literal(tokens, i, t, stack, path, rel, decls, found):
    g = stack[-1]
    p, q = prev_sig(tokens, i), sig(tokens, i + 1)
    prev = tokens[p] if p >= 0 else None
    nxt = tokens[q] if q < len(tokens) else None
    # Never a key: patterns, comparisons, dictionary keys, a String fallback (`name ?? "…"` is a String, not a key),
    # concatenations ("timbre_photo_" + id).
    if prev is not None and ((prev.kind == "id" and prev.value in ("case",)) or
                             (prev.kind == "op" and prev.value in ("==", "!=", "~=", "??", "+"))):
        return
    if nxt is not None and nxt.kind == "op" and nxt.value in ("==", "!=", "~=", "+", "??"):
        return
    if all(isinstance(part, str) and not part.strip() for part in t.value):
        return
    if nxt is not None and nxt.kind == "op" and nxt.value == ":" and g.opener == "[":
        return
    table, slot = None, None
    # App Shortcut phrases.
    if g.opener == "[" and len(stack) > 1:
        outer = stack[-2]
        if outer.callee == "AppShortcut" and outer.label == "phrases":
            table, slot = "AppShortcuts.strings", "AppShortcut.phrases"
    if table is None:
        verdict = None
        k = len(stack) - 1
        while k >= 0:
            grp = stack[k]
            if grp.opener == "(":
                verdict = callee_slots(grp, decls, path)
                if verdict is None:  # a bare parenthesis or tuple: look outward / at the tuple position
                    if grp.tuple_pos and grp.commas >= 0 and grp.index in grp.tuple_pos and grp.label is None:
                        verdict = True
                        break
                    if grp.localized_body and not grp.tuple_pos:
                        verdict = True if grp.state != "nonloc" else False
                        break
                    if grp.commas == 0:
                        k -= 1
                        continue
                    verdict = False
                break
            if grp.opener == "[":
                if grp.localized_body and grp.state != "nonloc" and not grp.tuple_pos:
                    verdict = True
                    break
                if grp.tuple_pos:
                    k -= 1  # the tuple decides
                    continue
                k -= 1  # an array argument: the call decides (synonyms: […], accessibilityInputLabels([…]))
                continue
            if grp.opener in ("{", "file", "interp"):
                if grp.state == "loc":
                    verdict = True
                elif grp.state == "nonloc":
                    verdict = False
                elif grp.localized_body and not grp.tuple_pos:
                    verdict = True
                break
            break
        if verdict:
            table = "Localizable.strings"
            grp = stack[k] if k >= 0 else g
            slot = (("." if grp.member else "") + grp.callee + "(" + (grp.label or "_") + ":)") if grp.callee else "value"
    if table is None:
        # Not a key here; report.py still matches plain text against the keys the tables already hold (strings
        # shown through a dynamic lookup, such as the badge names in TimbreCore).
        if all(isinstance(part, str) for part in t.value):
            found.append(Literal("", "".join(t.value), t.value, rel, t.line, "plain"))
        return
    named = table == "AppShortcuts.strings" or slot == "Summary(_:)"
    key, specs, guessed = make_key(t.value, path, decls, shortcut=named, line=t.line, owner=enclosing(stack))
    found.append(Literal(table, key, t.value, rel, t.line, slot, guessed, specs))


SINK_CALLS = {"LocalizedStringKey", "NSLocalizedString", "LocalizationValue", "LocalizedStringResource"}


def collect_sinks(path: str, tokens: list, decls: Decls) -> None:
    """Properties shown through a dynamic lookup: LocalizedStringKey(badge.title) makes every literal passed as
    `title:` to the badge's type a key."""
    type_stack, depth, n = [], 0, len(tokens)
    for i, t in enumerate(tokens):
        if t.kind == "op" and t.value == "{":
            depth += 1
        elif t.kind == "op" and t.value == "}":
            depth -= 1
            while type_stack and type_stack[-1][1] > depth:
                type_stack.pop()
        elif t.kind == "id" and t.value in TYPE_DECL and not t.member:
            j = sig(tokens, i + 1)
            if j < n and tokens[j].kind == "id":
                k = j
                while k < n and not (tokens[k].kind == "op" and tokens[k].value in "{;"):
                    k += 1
                if k < n and tokens[k].value == "{":
                    type_stack.append((tokens[j].value, depth + 1, tokens[k].line))
        elif t.kind == "id" and t.value in SINK_CALLS and i + 1 < n and tokens[i + 1].kind == "op" \
                and tokens[i + 1].value == "(":
            args, level = [], 0
            for x in tokens[i + 2:]:
                if x.kind == "op" and x.value in "([{":
                    level += 1
                elif x.kind == "op" and x.value in ")]}":
                    if level == 0:
                        break
                    level -= 1
                elif level == 0 and x.kind == "op" and x.value == ",":
                    break
                if x.kind != "nl":
                    args.append(x)
            if not args or any(x.kind not in ("id", "op") or (x.kind == "op" and x.value not in (".", "?", "!"))
                               for x in args):
                continue
            ids = [x for x in args if x.kind == "id"]
            if len(ids) < 2:
                continue
            prop = ids[-1].value
            cut = max(k for k, x in enumerate(args) if x.kind == "id" and x is ids[-1])
            prefix = [x for x in args[:cut] if not (x.kind == "op" and x.value in ("?", "!"))]
            while prefix and prefix[-1].kind == "op" and prefix[-1].value == ".":
                prefix.pop()
            owner = (type_stack[-1][0], type_stack[-1][2]) if type_stack else (None, 0)
            typ, _ = expr_type(prefix, path, decls, t.line, owner)
            if typ:
                base = typ.replace("?", "").replace("!", "").strip()
                if base in decls.types:
                    decls.sinks.add((base, prop))


def scan(root: Path, folders: list, decl_folders: list | None = None) -> tuple[list, dict]:
    """Every literal under root/folders (localizable ones with their table; the rest as plain text, table "").
    Returns (literals, {file: Lexer}) for context lookups. decl_folders are read for declarations only."""
    decls = Decls()
    lexed = {}
    files = []
    for folder in folders:
        files += sorted((root / folder).rglob("*.swift"))
    for folder in decl_folders or []:
        for path in sorted((root / folder).rglob("*.swift")):
            if path not in files:
                lexer = Lexer(path.read_text(encoding="utf-8"))
                collect_decls(str(path), lexer.tokens(), decls)
    tokens_by_file = {}
    for path in files:
        lexer = Lexer(path.read_text(encoding="utf-8"))
        toks = lexer.tokens()
        tokens_by_file[path] = toks
        lexed[str(path.relative_to(root))] = lexer
        collect_decls(str(path), toks, decls)
    for path in files:
        collect_sinks(str(path), tokens_by_file[path], decls)
    literals = []
    for path in files:
        literals += scan_file(str(path), "", decls, tokens_by_file[path], str(path.relative_to(root)))
    return literals, lexed
