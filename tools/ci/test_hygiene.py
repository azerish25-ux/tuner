#!/usr/bin/env python3
"""Tests for the Swift comment lexer, the hygiene lint and the comment sweep: python3 tools/ci/test_hygiene.py"""
from __future__ import annotations

import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import comment_hygiene  # noqa: E402
import sweep_comments  # noqa: E402
from swift_source import scan  # noqa: E402


class LexerTests(unittest.TestCase):
    def comments(self, source: str) -> list[str]:
        return [c.text for c in scan(source)[1]]

    def test_line_and_doc_comments(self):
        self.assertEqual(self.comments('let a = 1 // one\n/// doc\nlet b = 2'), ["// one", "/// doc"])

    def test_nested_block_comment(self):
        source = "a /* outer /* inner */ still outer */ b"
        self.assertEqual(self.comments(source), ["/* outer /* inner */ still outer */"])
        self.assertEqual(scan(source)[0].strip()[0], "a")
        self.assertTrue(scan(source)[0].rstrip().endswith("b"))

    def test_comment_markers_inside_strings_are_text(self):
        self.assertEqual(self.comments('let url = "https://example.com" // real'), ["// real"])
        self.assertEqual(self.comments('let s = "/* not a comment */"'), [])

    def test_escaped_quote_and_backslash(self):
        self.assertEqual(self.comments('let s = "say \\"hi\\" \\\\" // c'), ["// c"])

    def test_interpolation_with_string_and_comment_inside(self):
        source = 'let s = "a \\(f("b // not") /* c1 */ + g()) d" // c2'
        self.assertEqual(self.comments(source), ["/* c1 */", "// c2"])
        code = scan(source)[0]
        self.assertIn("f(", code)
        self.assertNotIn("not", code)

    def test_raw_and_multiline_strings(self):
        source = 'let r = #"a "quoted" \\(x) // no"#\nlet m = """\nline // no\n"""\n// yes'
        self.assertEqual(self.comments(source), ["// yes"])
        self.assertEqual(scan(source)[1][0].line, 5)

    def test_raw_interpolation(self):
        source = 'let r = #"v: \\#(value) "# // c'
        code, comments = scan(source)
        self.assertEqual([c.text for c in comments], ["// c"])
        self.assertIn("value", code)

    def test_mask_keeps_offsets_and_lines(self):
        source = 'a // x\n"s\\n"\n/* y\nz */ b'
        code, _ = scan(source)
        self.assertEqual(len(code), len(source))
        self.assertEqual(code.count("\n"), source.count("\n"))


class LintTests(unittest.TestCase):
    def rules(self, source: str, path: str = "ios/Timbre/Learn/X.swift") -> list[str]:
        return [f.rule for f in comment_hygiene.lint_source(path, source)]

    def test_review_and_bug_references_in_comments(self):
        self.assertEqual(self.rules("// held still (review 14, bug 2).\nlet a = 1"), ["review-ref", "bug-ref"])
        self.assertEqual(self.rules("/// the chart, review 15's 51b)."), ["review-ref"])
        self.assertEqual(self.rules("/// (bug 06b) and (QA M11)"), ["bug-ref", "qa-ref"])

    def test_references_in_strings_and_identifiers_pass(self):
        self.assertEqual(self.rules('let s = "review 14"\nlet preview2 = debug(3) // preview 2, debug 4'), [])

    def test_store_frame_only_in_product_code(self):
        source = "// App Store frame #4: the chord step"
        self.assertIn("store-frame", self.rules(source))
        self.assertNotIn("store-frame", self.rules(source, "ios/TimbreUITests/TimbreUITests.swift"))
        self.assertNotIn("store-frame", self.rules(source, "ios/Timbre/Root/DemoScenes.swift"))

    def test_wip_and_process_references(self):
        self.assertEqual(self.rules("// WIP: finish\n// the jurors asked for it"), ["wip", "process-ref"])

    def test_tool_names_are_not_policed(self):
        self.assertEqual(self.rules("// Written with Claude's help, reviewed by a person."), [])

    def test_code_rules_ignore_comments_and_strings(self):
        self.assertEqual(self.rules('IconOrb(symbol: "x") // IconOrb( again\nlet s = "IconOrb("'), ["icon-orb"])

    def test_type_scale(self):
        source = "Text(a).font(Typeface.display(16))\nText(b).font(Typeface.label(17))\nText(c).font(Typeface.hero(44))"
        self.assertEqual(self.rules(source), ["type-scale"])

    def test_inline_orb_is_a_tinted_circle_behind_a_glyph(self):
        tinted = "Image(systemName: s).background(Circle().fill(tint.opacity(0.14)))"
        solid = "Image(systemName: s).background(Circle().fill(Palette.mint))"
        self.assertEqual(self.rules(tinted), ["inline-orb"])
        self.assertEqual(self.rules(solid), [])

    def test_status_colour_outside_the_tokens(self):
        self.assertEqual(self.rules("Text(a).foregroundStyle(Palette.amber)"), ["status-colour"])
        self.assertEqual(self.rules("static let x = Palette.coral", "ios/Timbre/Design/Theme.swift"), [])

    def test_a_warn_rule_arms_itself_once_its_baseline_is_empty(self):
        allowed = comment_hygiene.tally([comment_hygiene.Finding("type-scale", "a.swift", 1, "Typeface.label(14", "")])
        armed = comment_hygiene.armed_rules(allowed, strict=False)
        self.assertIn("review-ref", armed)
        self.assertIn("icon-orb", armed)
        self.assertNotIn("type-scale", armed)
        self.assertIn("type-scale", comment_hygiene.armed_rules(allowed, strict=True))
        self.assertNotIn("test-coupling", comment_hygiene.armed_rules(allowed, strict=True))

    def test_baseline_allows_existing_count_and_blocks_one_more(self):
        old = [comment_hygiene.Finding("review-ref", "a.swift", 3, "review 14", "")]
        allowed = comment_hygiene.tally(old)
        over, shrink = comment_hygiene.compare(old, allowed)
        self.assertEqual((over, shrink), ([], []))
        two = old + [comment_hygiene.Finding("review-ref", "a.swift", 9, "Review 14", "")]
        over, _ = comment_hygiene.compare(two, allowed)
        self.assertEqual(len(over), 2)
        over, shrink = comment_hygiene.compare([], allowed)
        self.assertEqual(over, [])
        self.assertEqual(len(shrink), 1)


class SweepTests(unittest.TestCase):
    def sweep(self, source: str) -> str:
        return sweep_comments.sweep_source(source)[0]

    def test_reference_only_parenthesis_is_removed(self):
        self.assertEqual(self.sweep("/// came out as \"ORIGI…\" (review 14).\n"), "/// came out as \"ORIGI…\".\n")
        self.assertEqual(self.sweep("// not dimmed for nothing (review 14, bug 2).\n"), "// not dimmed for nothing.\n")
        self.assertEqual(self.sweep("/// any size (bug 06b); the column\n"), "/// any size; the column\n")
        self.assertEqual(self.sweep("/// two sets (store frame 51b, review 15). Drawn\n"), "/// two sets. Drawn\n")

    def test_reference_before_an_explanation(self):
        self.assertEqual(self.sweep("/// part-way (bug 64, a step stuck at 30 %), so\n"), "/// part-way (a step stuck at 30 %), so\n")
        self.assertEqual(self.sweep("/// differently (bug 5: the outline said\n"), "/// differently (the outline said\n")

    def test_reference_after_an_example(self):
        self.assertEqual(self.sweep("// the name (\"Cho|rus\", review 14).\n"), "// the name (\"Cho|rus\").\n")
        self.assertEqual(self.sweep("/// the switch on, review 15's 51b).\n"), "/// the switch on).\n")

    def test_orphaned_punctuation_joins_the_previous_line(self):
        source = "    // sat over the edge\n    // (review 14). The stage gives up the room.\n    upcoming\n"
        self.assertEqual(self.sweep(source), "    // sat over the edge.\n    // The stage gives up the room.\n    upcoming\n")

    def test_code_and_strings_are_untouched(self):
        source = 'let s = "(review 14)" // keep (bug 3)\n'
        self.assertEqual(self.sweep(source), 'let s = "(review 14)" // keep\n')

    def test_unresolvable_reference_is_reported(self):
        out, manual = sweep_comments.sweep_source("/// Review 13's results: four clean steps\n")
        self.assertEqual(out, "/// Review 13's results: four clean steps\n")
        self.assertEqual(len(manual), 1)


if __name__ == "__main__":
    unittest.main(verbosity=1)
