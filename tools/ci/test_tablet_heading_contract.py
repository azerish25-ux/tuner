"""Source contracts supplement, never replace, native tablet geometry and screenshot tests."""
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[2]

class TabletHeadingContracts(unittest.TestCase):
    def test_identifier_is_on_actual_title_not_section_container(self):
        kit = (ROOT / 'ios/Timbre/Design/Kit.swift').read_text()
        view = (ROOT / 'ios/Timbre/Instruments/InstrumentsView.swift').read_text()
        self.assertIn('title.accessibilityIdentifier(titleIdentifier)', kit)
        self.assertIn('titleIdentifier: "instruments.section." + group.id', view)
        self.assertNotIn('.accessibilityIdentifier("instruments.section.', view)

    def test_early_and_final_acceptance_require_heading_and_cards(self):
        source = (ROOT / 'ios/TimbreUITests/TabletScreenshotsUITests.swift').read_text()
        block = source.split('private func scrollToFolkShelf() -> Bool {', 1)[1].split('private func folkSpan', 1)[0]
        self.assertEqual(block.count('TabletShelfAlignment.accepts('), 2)
        self.assertIn('let heading = element("instruments.section.bowed_strings")', block)
        self.assertIn('guard let headingFrame = liveFrame(heading)', block)
        self.assertIn('else { whole = false }', block)
        self.assertIn('TabletShelfAlignment.correction(', block)
        self.assertIn('if span.minY >= top && span.maxY <= foot {', block)

    def test_geometry_keeps_strict_safe_regions(self):
        source = (ROOT / 'ios/TimbreUITests/TabletShelfAlignment.swift').read_text()
        self.assertIn('cardsTop >= clearTop && cardsBottom <= foot', source)
        self.assertIn('headingTop >= clearTop || headingBottom <= hiddenBottom', source)
        self.assertIn('hiddenBottom < clearTop', source)
        self.assertIn('allSatisfy(\\.isFinite)', source)

    def test_native_geometry_and_source_contract_are_selected(self):
        workflow = (ROOT / '.github/workflows/ios.yml').read_text()
        self.assertIn('-only-testing:TimbreUITests/TabletShelfAlignmentTests', workflow)
        self.assertIn('python3 tools/ci/test_tablet_heading_contract.py', workflow)

if __name__ == '__main__':
    unittest.main()
