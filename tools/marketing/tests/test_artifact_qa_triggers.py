"""Trigger/plan contracts only, not native capture or rendering evidence."""
import itertools
from pathlib import Path
import re
import sys
import unittest

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import listing_assets as assets

HANDOFF = 'refs/heads/codex/app-store-readiness-gates'


def job_condition(filename, job):
    source = (assets.ROOT / '.github/workflows' / filename).read_text()
    body = source.split('\n  ' + job + ':\n', 1)[1]
    match = re.search(r'^    if: (.+)(?:\n|$)', body, re.M)
    expression = match.group(1)
    if expression == '>-':
        lines = []
        for line in body[match.end():].splitlines():
            if not line.startswith('      '):
                break
            lines.append(line.strip())
        expression = ' '.join(lines)
    return expression


def enabled(expression, event='push', ref=HANDOFF, message='ordinary checkpoint', labels=()):
    values = {'github.event_name': event, 'github.ref': ref,
              'github.event.head_commit.message': message,
              'github.event.pull_request.labels.*.name': list(labels)}
    for key in sorted(values, key=len, reverse=True):
        expression = expression.replace(key, repr(values[key]))
    expression = expression.replace('&&', ' and ').replace('||', ' or ')
    return eval(expression, {'__builtins__': {}, 'contains': lambda value, item: item in value,
                             'startsWith': lambda value, prefix: value.startswith(prefix)})


class ArtifactQATriggerTests(unittest.TestCase):
    def test_exact_handoff_marker_guards_and_ordinary_checkpoint_skip(self):
        cases = [('localization-matrix.yml', 'localized-launch', '[l10n-matrix]'),
                 ('localized-capture-check.yml', 'lesson-frames', '[capture-check]'),
                 ('l10n.yml', 'export', '[l10n-export]'),
                 ('caption-typography.yml', 'captions', '[caption-typography]')]
        for filename, job, marker in cases:
            with self.subTest(workflow=filename):
                condition = job_condition(filename, job)
                self.assertFalse(enabled(condition))
                self.assertTrue(enabled(condition, message=marker))
                for ref in ['refs/heads/topic', HANDOFF + '-copy', 'refs/tags/main']:
                    self.assertFalse(enabled(condition, ref=ref, message=marker))
                self.assertTrue(enabled(condition, event='workflow_dispatch', ref='refs/heads/main'))
                source = (assets.ROOT / '.github/workflows' / filename).read_text()
                self.assertIn('codex/app-store-readiness-gates', source.split('jobs:', 1)[0])

    def test_listing_job_guard_skips_ordinary_and_unapproved_refs(self):
        condition = job_condition('listing-assets.yml', 'plan')
        self.assertFalse(enabled(condition))
        for marker in assets.PUSH_MARKERS:
            self.assertTrue(enabled(condition, message=marker))
            self.assertFalse(enabled(condition, ref=HANDOFF + '-copy', message=marker))
        self.assertTrue(enabled(condition, event='workflow_dispatch'))
        self.assertFalse(enabled(condition, event='workflow_dispatch', ref='refs/heads/topic'))

    def test_listing_request_ref_event_and_conflict_whitelist(self):
        for ref in assets.ALLOWED_REFS:
            for marker in assets.PUSH_MARKERS:
                result = assets.request_scope('push', marker, 'ja', 'previews', True, ref)
                self.assertFalse(result['violin'])
            for a, b in itertools.combinations(assets.PUSH_MARKERS, 2):
                with self.assertRaises(ValueError):
                    assets.request_scope('push', a + b, 'all', 'all', False, ref)
            with self.assertRaises(ValueError):
                assets.request_scope('push', 'ordinary checkpoint', 'all', 'all', False, ref)
        for ref in ['refs/heads/topic', HANDOFF + '-copy', 'refs/tags/main', '']:
            for event in ['push', 'workflow_dispatch']:
                with self.assertRaises(ValueError):
                    assets.request_scope(event, '[listing-screenshots-all]', 'all', 'all', False, ref)
        with self.assertRaises(ValueError):
            assets.request_scope('pull_request', '[listing-screenshots-all]', 'all', 'all', False, HANDOFF)

    def test_screenshots_only_exact_fifty_coverage_never_claims_previews(self):
        for marker, count in [('[listing-screenshots-all]', 50), ('[listing-screenshots-pilot]', 3)]:
            request = assets.request_scope('push', marker, 'all', 'all', True, HANDOFF)
            plan = assets.make_plan(request['locales'], request['scope'], request['violin'])
            self.assertEqual(plan['kinds'], ['iphone', 'iphone-large', 'ipad'])
            self.assertEqual(plan['requested_scope'], 'screenshots')
            self.assertFalse(plan['full_default_listing_scope'])
            self.assertEqual(plan['full_screenshot_listing_scope'], count == 50)
            for kind in ['iphone', 'iphone-large', 'ipad']:
                locales = [loc for row in plan['matrix']['include'] if row['kind'] == kind
                           for loc in row['locales'].split(',')]
                self.assertEqual(len(locales), count)
                self.assertEqual(len(set(locales)), count)
                self.assertEqual(set(locales), set(assets.locale_rows()) if count == 50 else {'en-US', 'de-DE', 'ar-SA'})

    def test_nightly_captures_includes_sanitizer_without_canceling_running_evidence(self):
        condition = job_condition('nightly.yml', 'tsan')
        self.assertFalse(enabled(condition, event='pull_request'))
        self.assertTrue(enabled(condition, event='pull_request', labels=['captures']))
        self.assertTrue(enabled(condition, event='schedule'))
        for filename in ['nightly.yml', 'listing-assets.yml', 'l10n.yml', 'caption-typography.yml']:
            source = (assets.ROOT / '.github/workflows' / filename).read_text()
            self.assertIn('cancel-in-progress: false', source)

    def test_export_handoff_has_no_write_job_and_listing_scope_is_sent_to_validator(self):
        source = (assets.ROOT / '.github/workflows/l10n.yml').read_text()
        self.assertIn('permissions:\n  contents: read', source)
        self.assertNotIn('contents: write', source.split('  publish:', 1)[0])
        self.assertIn("github.ref != '" + HANDOFF + "'", source.split('  publish:', 1)[1])
        source = (assets.ROOT / '.github/workflows/listing-assets.yml').read_text()
        self.assertIn('--ref "$SOURCE_REF"', source)
        self.assertIn('default: screenshots', source)
        for marker in assets.PUSH_MARKERS:
            self.assertIn(marker, source)


if __name__ == '__main__':
    unittest.main()
