"""Source paint regression, not a substitute for native accessibility audit."""
from pathlib import Path
import re
import unittest

ROOT = Path(__file__).resolve().parents[2]


def contrast(a, b):
    def luminance(rgb):
        channels = [v / 255 for v in rgb]
        return sum(w * (v / 12.92 if v <= .04045 else ((v + .055) / 1.055) ** 2.4)
                   for w, v in zip((.2126, .7152, .0722), channels))
    low, high = sorted((luminance(a), luminance(b)))
    return (high + .05) / (low + .05)


class PaywallOfferContrastTests(unittest.TestCase):
    def test_opaque_offer_ink_has_at_least_twelve_to_one_contrast(self):
        theme = (ROOT / 'ios/Timbre/Design/Theme.swift').read_text()
        def color(name):
            match = re.search(rf'static let {name} = Color\(hex: 0x([0-9A-Fa-f]{{6}})\)', theme)
            self.assertIsNotNone(match)
            return tuple(bytes.fromhex(match[1]))
        self.assertEqual(color('proGoldOffer'), (255, 208, 138))
        self.assertEqual(color('onGold'), (27, 18, 6))
        self.assertGreaterEqual(contrast(color('onGold'), color('proGoldOffer')), 12.8)

    def test_actual_badge_uses_opaque_offer_and_preserves_trial_role(self):
        source = (ROOT / 'ios/Timbre/Paywall/PaywallView.swift').read_text()
        badge = source.split('struct PaywallOfferBadge: View {', 1)[1].split('struct PlanFace', 1)[0]
        self.assertIn('if trial { shape.fill(Palette.mint) } else { shape.fill(Palette.proGoldOffer) }', badge)
        self.assertIn('.foregroundStyle(trial ? Palette.onAccent : Palette.onGold)', badge)
        self.assertNotIn('.opacity(', badge)


if __name__ == '__main__':
    unittest.main()
