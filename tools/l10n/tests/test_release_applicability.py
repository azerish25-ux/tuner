"""Applicability must not forge verification or remove unrelated release gates."""
import copy
import hashlib
import json
import os
from pathlib import Path
import sys
import tempfile
import unittest
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import store


class ReleaseApplicabilityTests(unittest.TestCase):
    def setUp(self):
        self.source = store.load('en-US')
        self.policy = json.loads(store.APPLICABILITY.read_text())

    def dispositions(self, policy=None):
        return store.release_applicability(self.source, self.policy if policy is None else policy)

    def assert_rejected(self, policy):
        statuses, errors = self.dispositions(policy)
        self.assertTrue(errors)
        self.assertEqual(statuses, dict.fromkeys(store.RELEASE_EVIDENCE, 'required'))

    def test_committed_scope_preserves_mandatory_gates(self):
        statuses, errors = self.dispositions()
        self.assertEqual(errors, [])
        self.assertEqual(statuses['app_preview'], 'not_applicable')
        self.assertEqual(statuses['game_center_account'], 'not_applicable')
        self.assertEqual(statuses['device'], 'owner_waived')
        for field in ('screenshots', 'privacy_policy', 'iap_account_limits'):
            self.assertEqual(statuses[field], 'required')
        self.assertTrue(store.validate(self.source, self.source, release=True))
        self.assertFalse(self.source['review']['release_ready'])
        self.assertNotEqual(self.source['review']['device'], 'verified')

    def test_missing_or_malformed_file_fails_closed(self):
        with tempfile.TemporaryDirectory() as temp:
            file = Path(temp) / 'policy.json'
            with patch.object(store, 'APPLICABILITY', file):
                self.assertTrue(store.release_applicability_errors(self.source))
                for payload in ('null', '[]', '{', '"hello"'):
                    file.write_text(payload)
                    self.assertTrue(store.release_applicability_errors(self.source))

    def test_all_policy_fields_are_required(self):
        for key in self.policy:
            with self.subTest(key=key):
                policy = copy.deepcopy(self.policy)
                del policy[key]
                self.assert_rejected(policy)

    def test_each_source_hash_is_required_and_current(self):
        for key in store.APPLICABILITY_SOURCES:
            for value in (None, '0' * 64):
                policy = copy.deepcopy(self.policy)
                policy['source_sha256'][key] = value
                self.assert_rejected(policy)
        policy = copy.deepcopy(self.policy)
        policy['listing_source_sha256'] = '0' * 64
        self.assert_rejected(policy)

    def test_inventory_and_types_cannot_add_exclusions(self):
        for key, value in [('evidence', []), ('schema_version', True), ('source_sha256', []), ('extra', 'x')]:
            policy = copy.deepcopy(self.policy)
            policy[key] = value
            self.assert_rejected(policy)
        policy = copy.deepcopy(self.policy)
        policy['evidence']['screenshots'] = {'status': 'not_applicable'}
        self.assert_rejected(policy)

    def test_device_waiver_is_bounded_and_not_verification(self):
        for key in self.policy['evidence']['device']:
            policy = copy.deepcopy(self.policy)
            del policy['evidence']['device'][key]
            self.assert_rejected(policy)
        for status in ('verified', 'not_applicable', 'waived'):
            policy = copy.deepcopy(self.policy)
            policy['evidence']['device']['status'] = status
            self.assert_rejected(policy)

    def test_preview_omission_needs_explicit_owner_record(self):
        policy = copy.deepcopy(self.policy)
        record = {'status': 'not_applicable', 'selected_by': 'owner',
                  'authorization': 'SYNTHETIC TEST ONLY: omit preview videos.',
                  'submission_scope': 'screenshots_only_no_preview_upload'}
        policy['evidence']['app_preview'] = record
        statuses, errors = self.dispositions(policy)
        self.assertEqual(errors, [])
        self.assertEqual(statuses['app_preview'], 'not_applicable')
        for key in record:
            bad = copy.deepcopy(policy)
            del bad['evidence']['app_preview'][key]
            self.assert_rejected(bad)
        record['authorization'] = ' '
        self.assert_rejected(policy)

    def test_enabled_build_override_cannot_claim_disabled(self):
        for value in ('YES', 'TRUE', '1', '', 'unknown'):
            with patch.dict(os.environ, {'TIMBRE_GAME_CENTER_ENABLED': value}):
                self.assert_rejected(self.policy)

    def test_source_enablement_and_entitlement_rejected_even_after_rehash(self):
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            for name in store.APPLICABILITY_SOURCES:
                dest = root / name
                dest.parent.mkdir(parents=True, exist_ok=True)
                dest.write_bytes((store.ROOT / name).read_bytes())
            project = root / 'ios/project.yml'
            original = project.read_text()
            mutations = [original.replace('TIMBRE_GAME_CENTER_ENABLED: "NO"', 'TIMBRE_GAME_CENTER_ENABLED: "YES"'),
                         original + '\nTIMBRE_GAME_CENTER_ENABLED: "NO"\n',
                         original + '\ncom.apple.developer.game-center: true\n']
            binding = 'TimbreGameCenterEnabled: $(TIMBRE_GAME_CENTER_ENABLED)'
            mutations.extend(original.replace(binding, replacement) for replacement in (
                'TimbreGameCenterEnabled: YES # formerly ' + binding,
                '# ' + binding,
                binding + '\n        TimbreGameCenterEnabled: YES',
                binding + '\n        "TimbreGameCenterEnabled": YES',
                'TimbreGameCenterEnabled: "YES # formerly ' + binding + '"',
                'TimbreGameCenterEnabled: $(OTHER_SETTING)',
                'TimbreGameCenterEnabled: *enabled',
                'TimbreGameCenterEnabled: "$(TIMBRE_GAME_CENTER_ENABLED) # not a comment"',
            ))
            mutations.extend(original.replace('TIMBRE_GAME_CENTER_ENABLED: "NO"', replacement)
                             for replacement in (
                                 'TIMBRE_GAME_CENTER_ENABLED: "NO # not a comment"',
                                 'TIMBRE_GAME_CENTER_ENABLED: "NO" extra',
                                 'TIMBRE_GAME_CENTER_ENABLED: *disabled',
                                 '# TIMBRE_GAME_CENTER_ENABLED: "NO"',
                                 '"TIMBRE_GAME_CENTER_ENABLED": "NO"',
                             ))
            for text in mutations:
                project.write_text(text)
                policy = copy.deepcopy(self.policy)
                policy['source_sha256']['ios/project.yml'] = hashlib.sha256(project.read_bytes()).hexdigest()
                with patch.object(store, 'ROOT', root):
                    self.assert_rejected(policy)
            project.write_text(original)
            (root / 'ios/new.entitlements').write_text('<key>com.apple.developer.game-center</key>')
            with patch.object(store, 'ROOT', root):
                self.assert_rejected(self.policy)

    def test_exclusions_need_no_false_verified_flags_but_keep_dependencies(self):
        data = copy.deepcopy(self.source)
        statuses, errors = self.dispositions()
        self.assertEqual(errors, [])
        data['review']['evidence'] = {}
        for field, status in statuses.items():
            data['review'][field] = 'not_verified'
            if status == 'required':
                data['review'][field] = 'verified'
                data['review']['evidence'][field] = {
                    'reference': 'SYNTHETIC TEST ONLY', 'content_sha256': store.content_hash(data)}
        reference = 'docs/ios/readiness/reviews/privacy-policy-current-source-verification.json'
        data['review']['evidence']['privacy_policy'] = {
            'reference': reference, 'content_sha256': store.content_hash(data),
            'reference_sha256': hashlib.sha256((store.ROOT/reference).read_bytes()).hexdigest()}
        self.assertEqual(store.validate(data, self.source, release=True), [])
        for field in ('privacy_policy', 'screenshots', 'iap_account_limits'):
            bad = copy.deepcopy(data)
            del bad['review']['evidence'][field]
            errors = store.validate(bad, self.source, release=True)
            self.assertTrue(any(f'{field} needs a current-content evidence reference' in e for e in errors))
        # Re-enabling a scope restores its ordinary evidence requirement.
        for field in ('app_preview', 'game_center_account', 'device'):
            policy = copy.deepcopy(self.policy)
            policy['evidence'][field] = {'status': 'required'}
            errors = store.validate(data, self.source, release=True, applicability_policy=policy)
            self.assertTrue(any(f'{field} not verified' in e for e in errors))
            self.assertTrue(any(f'{field} needs a current-content evidence reference' in e for e in errors))

    def test_invalid_policy_does_not_remove_evidence_errors(self):
        bad = copy.deepcopy(self.policy)
        bad['evidence']['device']['authorization'] = 'assumed approval'
        errors = store.validate(self.source, self.source, release=True, applicability_policy=bad)
        self.assertTrue(any('release applicability:' in e for e in errors))
        for field in store.RELEASE_EVIDENCE:
            self.assertTrue(any(f'release: {field} not verified' in e for e in errors))


if __name__ == '__main__':
    unittest.main()
