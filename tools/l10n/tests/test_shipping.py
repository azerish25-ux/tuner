"""Release locale selection must use a real export and cannot hide incomplete UI."""
import contextlib
import io
import json
import os
from pathlib import Path
import sys
import tempfile
import unittest
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import report
import shipping
import critical


class ShippingReleaseTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.root = Path(self.temp.name)
        self.xliff = self.root / 'en.xliff'
        self.xliff.write_text('''<?xml version="1.0"?>
<xliff version="1.2" xmlns="urn:oasis:names:tc:xliff:document:1.2">
<file original="Timbre/Localizable.strings" source-language="en"><body>
<trans-unit id="Subscription renews for %@"><source>Subscription renews for %@</source></trans-unit>
</body></file></xliff>''', encoding='utf-8')
        self.model = {'ui_total': 100, 'learn_total': 1, 'lesson_locales': ['de', 'fr'],
                      'locales': {loc: {'todo': [], 'awaiting_apply': []} for loc in ['de', 'fr']}}

    def tearDown(self):
        self.temp.cleanup()

    def run_selection(self, *args):
        output = io.StringIO()
        with contextlib.redirect_stdout(output):
            status = shipping.main(list(args))
        return status, output.getvalue()

    def test_export_key_controls_critical_aware_selection(self):
        # An inferred key appears translated; Xcode's real key is absent in German.
        missing = {'table': 'Localizable.strings', 'key': 'Subscription renews for %@',
                   'source': 'Subscription renews for %@', 'where': ['ios/Timbre/Paywall/PaywallView.swift:1'],
                   'context': '', 'hints': []}

        def exported_model(path=None):
            if path and missing['key'] in report.xliff_keys(path)['Localizable.strings']:
                self.model['locales']['de']['todo'] = [missing]
            return self.model

        with patch.object(report, 'build', side_effect=exported_model), \
                patch.object(shipping, 'shipped', return_value=['de', 'fr']):
            status, output = self.run_selection('--min', '95', '--critical', '--xliff', str(self.xliff))
        self.assertEqual(status, 0)
        self.assertIn('Would ship en + 1 locales: fr', output)
        self.assertIn('Left out (1): de', output)

    def test_invalid_export_cannot_apply_a_shipping_set(self):
        cases = {'missing': None, 'empty': '', 'no-units': '<xliff xmlns="urn:oasis:names:tc:xliff:document:1.2"/>',
                 'wrong-language': self.xliff.read_text().replace('source-language="en"', 'source-language="de"')}
        for name, content in cases.items():
            with self.subTest(name=name):
                candidate = self.root / f'{name}.xliff'
                if content is not None:
                    candidate.write_text(content)
                with patch.object(report, 'build', return_value=self.model), \
                        patch.object(shipping, 'rewrite') as rewrite:
                    with self.assertRaisesRegex(SystemExit, 'Invalid English XLIFF export'):
                        self.run_selection('--min', '95', '--critical', '--apply', '--xliff', str(candidate))
                    rewrite.assert_not_called()

    def test_unapplied_critical_translation_cannot_be_selected(self):
        self.model['locales']['de']['awaiting_apply'] = [{
            'table': 'InfoPlist.strings', 'key': 'NSMicrophoneUsageDescription', 'source': 'Microphone permission',
        }]
        with patch.object(report, 'build', return_value=self.model), \
                patch.object(shipping, 'shipped', return_value=['de', 'fr']):
            status, output = self.run_selection('--min', '95', '--critical', '--xliff', str(self.xliff))
        self.assertEqual(status, 0)
        self.assertIn('Would ship en + 1 locales: fr', output)

    def test_complete_gate_checks_locales_left_out_by_coverage(self):
        locales = [f'locale{i}' for i in range(48)]
        self.model['locales'] = {loc: {'todo': [], 'awaiting_apply': []} for loc in locales}
        self.model['locales'][locales[-1]]['todo'] = [{'table': 'Localizable.strings', 'key': 'Missing'}]
        with patch.object(report, 'build', return_value=self.model), \
                patch.object(shipping, 'available', return_value=['en'] + locales), \
                patch.object(shipping, 'shipped', return_value=[]):
            status, output = self.run_selection('--min', '100', '--require-complete', '--xliff', str(self.xliff))
        self.assertEqual(status, 1)
        self.assertIn(locales[-1], output)

    def test_complete_gate_requires_full_inventory_and_applied_ui(self):
        for count, pending in [(47, False), (48, True), (48, False)]:
            with self.subTest(count=count, pending=pending):
                locales = [f'locale{i}' for i in range(count)]
                self.model['locales'] = {loc: {'todo': [], 'awaiting_apply': []} for loc in locales}
                if pending:
                    self.model['locales'][locales[0]]['awaiting_apply'] = [{'table': 'Localizable.strings', 'key': 'Pending'}]
                with patch.object(report, 'build', return_value=self.model), \
                        patch.object(shipping, 'available', return_value=['en'] + locales), \
                        patch.object(shipping, 'shipped', return_value=[]):
                    status, _ = self.run_selection('--require-complete', '--xliff', str(self.xliff))
                self.assertEqual(status, 1 if count != 48 or pending else 0)

    def test_complete_gate_requires_authoritative_export(self):
        with self.assertRaises(SystemExit), contextlib.redirect_stderr(io.StringIO()):
            self.run_selection('--require-complete')

    def test_complete_gate_cannot_count_a_missing_english_folder(self):
        locales = [f'locale{i}' for i in range(48)]
        self.model['locales'] = {loc: {'todo': [], 'awaiting_apply': []} for loc in locales}
        with patch.object(report, 'build', return_value=self.model), \
                patch.object(shipping, 'available', return_value=locales), \
                patch.object(shipping, 'shipped', return_value=[]):
            status, _ = self.run_selection('--require-complete', '--xliff', str(self.xliff))
        self.assertEqual(status, 1)

    def assert_real_pending_critical_is_excluded(self, *, key, call, folder):
        # Build the actual report from source, installed tables and a delivered but unapplied translation.
        resources = self.root / 'ios/Timbre/Resources'
        source = self.root / f'ios/Timbre/{folder}/Example.swift'
        source.parent.mkdir(parents=True)
        keys = [key] + [f'Fixture interface text {number}' for number in range(99)]
        calls = [call] + [f'Text({json.dumps(value)})' for value in keys[1:]]
        source.write_text('import SwiftUI\nstruct Example: View { var body: some View { VStack {\n' +
                          '\n'.join(calls) + '\n} } }\n', encoding='utf-8')
        (self.root / 'ios/project.yml').write_text('targets: {}\n')
        for locale in ['en', 'de', 'fr']:
            directory = resources / f'{locale}.lproj'
            directory.mkdir(parents=True)
            values = keys if locale == 'en' else [f'Translation {number}' for number in range(100)]
            (directory / 'Localizable.strings').write_text(''.join(
                f'{json.dumps(k)} = {json.dumps(value)};\n'
                for k, value in zip(keys, values) if locale != 'de' or k != key), encoding='utf-8')
        handoff = self.root / 'tools/l10n'
        (handoff / 'translations').mkdir(parents=True)
        (handoff / 'translations/de.json').write_text(json.dumps({'Localizable.strings': {key: 'Gelieferte Übersetzung'}}),
                                                    encoding='utf-8')
        self.xliff.write_text(self.xliff.read_text().replace('Subscription renews for %@', key), encoding='utf-8')
        # Native CI scans POSIX paths; recognize the same fixture folder on Windows too.
        legal_folders = critical.LEGAL_FOLDERS + tuple(str(Path(folder)) + os.sep for folder in critical.LEGAL_FOLDERS)
        with patch.object(report, 'ROOT', self.root), patch.object(report, 'RES', resources), \
                patch.object(report, 'HERE', handoff), patch.object(report, 'CODE', ['ios/Timbre']), \
                patch.object(report, 'DECLS', []), patch.object(report, 'learn_english', return_value={}), \
                patch.object(report, 'learn_history', return_value={}), \
                patch.object(critical, 'LEGAL_FOLDERS', legal_folders), \
                patch.object(shipping, 'RESOURCES', resources), \
                patch.object(shipping, 'shipped', return_value=['de', 'fr']):
            model = report.build(self.xliff)
            self.assertEqual(model['ui_total'], 100)
            self.assertEqual(len(model['locales']['de']['awaiting_apply']), 1)
            self.assertEqual(model['locales']['de']['awaiting_apply'][0]['key'], key)
            self.assertEqual(shipping.coverage(model)['de']['ui'], 0.99)
            status, output = self.run_selection('--min', '95', '--critical', '--xliff', str(self.xliff))
        self.assertEqual(status, 0)
        self.assertIn('Would ship en + 1 locales: fr', output)
        self.assertIn('Left out (1): de', output)

    def test_real_report_pending_legal_translation_is_excluded(self):
        self.assert_real_pending_critical_is_excluded(
            key='Subscription renews automatically.', call='Text("Subscription renews automatically.")', folder='Paywall')

    def test_real_report_pending_voiceover_translation_is_excluded(self):
        self.assert_real_pending_critical_is_excluded(
            key='Play the next note', call='Image(systemName: "play").accessibilityLabel("Play the next note")', folder='Tune')


if __name__ == '__main__':
    unittest.main()
