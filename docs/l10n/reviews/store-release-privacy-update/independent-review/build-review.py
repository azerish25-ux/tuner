"""Reproduce bounded independent review guards; writes review artifacts only."""
import hashlib
import importlib.util
import json
from collections import Counter
from datetime import datetime, timezone
from pathlib import Path

ROOT = Path(__file__).resolve().parents[5]
BASE = ROOT / 'docs/l10n/reviews/store-release-privacy-update'
OUT = BASE / 'independent-review'
sha = lambda value: hashlib.sha256(value if isinstance(value, bytes) else value.encode()).hexdigest()
canonical = lambda value: json.dumps(value, ensure_ascii=False, sort_keys=True)
read = lambda path: json.loads(path.read_text(encoding='utf-8'))
write = lambda name, value: (OUT / name).write_text(json.dumps(value, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
spec = importlib.util.spec_from_file_location('store', ROOT / 'tools/l10n/store.py')
store = importlib.util.module_from_spec(spec)
spec.loader.exec_module(store)
proposals = read(BASE / 'proposals.json')['proposals']
context = read(BASE / 'context-and-lineage.json')
source = read(BASE / 'source-update-proposal.json')
author_manifest = read(BASE / 'manifest.json')
url = 'https://timbre-support.timbre.workers.dev/privacy'
inputs = {str(path.relative_to(ROOT)).replace('\\', '/'): sha(path.read_bytes()) for path in BASE.glob('*.json')}
checks = []
def check(name, passed):
    checks.append({'check': name, 'pass': bool(passed)})
    assert passed, name

for record in author_manifest['files']:
    check('author artifact hash: ' + record['path'], sha((ROOT / record['path']).read_bytes()) == record['sha256'])
for path, expected in context['input_hashes'].items():
    check('context current file hash: ' + path, sha((ROOT / path).read_bytes()) == expected)
registry = read(ROOT / 'tools/l10n/store-review.json')
independent = read(ROOT / 'tools/l10n/store-review-independent.json')
ledger = read(ROOT / 'tools/l10n/store-corrections.json')
check('historical correction ledger contains 309 entries', len(ledger) == 309)
source_current = read(ROOT / 'tools/l10n/store/en-US.json')
check('current English source content hash', store.content_hash(source_current) == context['current_source_en_US_content_sha256'])
check('English source document file hash', sha((ROOT / source['source_document']['path']).read_bytes()) == source['source_document']['sha256'])
source_description = source['description']['old']
for operation in source['exact_prose_operations']:
    check('English prose old occurrence: ' + operation['old'][:45], source_description.count(operation['old']) == 1)
    source_description = source_description.replace(operation['old'], operation['new'], 1)
check('English source proposal exact bounded reconstruction', source_description == source['description']['new'])
check('English source old text hash', sha(source['description']['old']) == source['description']['old_sha256'])
check('English source new text hash', sha(source_description) == source['description']['new_sha256'])
check('English source old description equals current payload', source['description']['old'] == source_current['description'])
source_proposed = dict(source_current, description=source_description, production_privacy_url=url)
check('proposed English source content hash', store.content_hash(source_proposed) == context['proposed_source_en_US_content_sha256'])
check('candidate Game Center default is NO', 'TIMBRE_GAME_CENTER_ENABLED: "NO"' in (ROOT / 'ios/project.yml').read_text())

# These are reviewer judgements after directly reading all actual old/new privacy
# paragraphs, every removed GC claim, and each embedded before/after line.
# Keep the established singular/informal reader address in the surrounding prose.
refinement_terms = {
    'el': ('στη συσκευή σας', 'στη συσκευή σου', 'The existing description addresses the reader with σου/σε and singular imperatives; preserve that register in the revised privacy sentence.'),
    'id': ('di perangkat Anda', 'di perangkatmu', 'The existing description uses permainanmu, buatanmu and kamu; preserve its informal reader address in the revised privacy sentence.'),
}
notes = {
    'en-AU': 'Analysed retained for Australian English; microphone scope explicit.',
    'en-GB': 'Analysed retained for British English; microphone scope explicit.',
    'en-CA': 'Analyzed is acceptable Canadian usage; no substantive regional mismatch.',
    'en-US': 'Analyzed matches US English and proposed source.',
    'fr-CA': 'Téléversé and appareil are appropriate Canadian French terms.',
    'fr-FR': 'Téléversé remains understandable and was inherited; optional France-oriented polish could use mis en ligne, but it is not a semantic blocker.',
    'ms': 'Malay peranti, dirakam, dimuat naik and akaun are retained; langsung daripada mikrofon scopes live microphone audio.',
    'or-IN': 'Odia microphone input and same-time device analysis are explicit; no denial of importing saved recordings is added.',
    'zh-Hant': 'Traditional forms 麥克風, 即時音訊, 裝置, 帳號 and 上傳 are appropriate; no simplified-character drift.',
    'zh-Hans': 'Simplified 麦克风, 实时音频, 设备 and 账号 are consistent.',
    'pt-BR': 'Seu dispositivo and enviado retain Brazilian usage and microphone/real-time scope.',
    'pt-PT': 'Teu dispositivo, conceção and carregado retain Portugal usage.',
    'ko': 'Conversational ending is compatible with the existing opening 없어요; live microphone scope and device analysis remain explicit.',
}
decisions = []
refinements = []
kinds = Counter()
histories = {record['locale']: record for record in context['review_history']}
for p in proposals:
    locale = p['locale']
    current = read(ROOT / p['current_payload_file'])
    ops = p['bounded_operations']
    fields = {change['field']: change for change in p['field_changes']}
    old, new = fields['description']['old'], fields['description']['new']
    gc = ops['game_center_removal']
    kinds[gc['kind']] += 1
    check(locale + ': current file hash', sha((ROOT / p['current_payload_file']).read_bytes()) == p['current_file_sha256'])
    check(locale + ': current payload content hash', store.content_hash(current) == p['current_content_sha256'])
    check(locale + ': exact-old description current', current['description'] == old)
    check(locale + ': old/new description hashes', sha(old) == p['current_description_sha256'] and sha(new) == p['new_description_sha256'])
    check(locale + ': source paragraph hash', sha(p['source']) == p['source_sha256'])
    check(locale + ': proposed source binding', p['source_proposed_en_US_content_sha256'] == store.content_hash(source_proposed))
    check(locale + ': old/new privacy hashes', sha(ops['old_privacy_paragraph']) == ops['old_privacy_paragraph_sha256'] and sha(ops['new_privacy_paragraph']) == ops['new_privacy_paragraph_sha256'])
    check(locale + ': removed GC hash', sha(gc['exact_old']) == gc['old_sha256'])
    reconstructed = old
    for before, after in [(ops['old_privacy_paragraph'], ops['new_privacy_paragraph']), (gc['exact_old'], gc['new']), (ops['privacy_url']['old'], url)]:
        check(locale + ': unique exact operation ' + before[:28], reconstructed.count(before) == 1)
        reconstructed = reconstructed.replace(before, after, 1)
    check(locale + ': full description contains only allowed delta', reconstructed == new)
    check(locale + ': URL/newline/limit contract', new.count(url) == 1 and '<privacy policy URL>' not in new and '\r' not in new and len(new) <= 4000 and new.count(store.EULA) == old.count(store.EULA) == 1)
    if gc['new_containing_line'] is not None:
        check(locale + ': embedded GC leaves all adjacent sentences exact', gc['old_containing_line'].replace(gc['exact_old'], '', 1) == gc['new_containing_line'] and gc['new_containing_line'] in new)
    unchanged = {key: value for key, value in current.items() if key != 'description'}
    check(locale + ': unchanged-field guard including review metadata', sha(canonical(unchanged)) == p['unchanged_fields_sha256'])
    proposed = dict(current)
    for field, change in fields.items():
        proposed[field] = change['new']
    check(locale + ': only description and production URL fields differ', {key for key in set(current) | set(proposed) if current.get(key) != proposed.get(key)} == {'description', 'production_privacy_url'})
    check(locale + ': proposed payload content hash', store.content_hash(proposed) == p['author_proposed_content_sha256'])
    history = histories[locale]
    check(locale + ': prior full-review record preserved', history['prior_full_payload_review_record'] == registry['locales'][locale])
    check(locale + ': prior independent-review evidence preserved', history['prior_independent_evidence_record'] == independent[locale])
    check(locale + ': prior correction count preserved', history['historical_ledger_correction_count'] == sum(entry['locale'] == locale for entry in ledger))
    final = dict(proposed)
    if locale in refinement_terms:
        before, after, reason = refinement_terms[locale]
        check(locale + ': unique guarded register refinement', ops['new_privacy_paragraph'].count(before) == 1)
        final['description'] = new.replace(before, after, 1)
        refinements.append({'locale': locale, 'field': 'description', 'author_proposal_file_sha256': inputs['docs/l10n/reviews/store-release-privacy-update/proposals.json'], 'author_description_sha256': sha(new), 'exact_old_paragraph': ops['new_privacy_paragraph'], 'replacement_paragraph': ops['new_privacy_paragraph'].replace(before, after, 1), 'exact_occurrences': 1, 'final_description': final['description'], 'final_description_sha256': sha(final['description']), 'final_content_sha256': store.content_hash(final), 'reason': reason})
    decisions.append({'locale': locale, 'reviewer': 'Codex /root/store_release_copy_review', 'method': 'independent source-aware AI bounded semantic/delta review', 'decision': 'accept-with-guarded-register-refinement' if locale in refinement_terms else 'accept-as-proposed', 'directly_read': ['actual old privacy paragraph', 'actual new privacy paragraph', 'actual removed GC claim', 'actual full containing line before/after for embedded claim'], 'meaning_checks': {'live_microphone_scope': True, 'on_user_device': True, 'never_recorded_or_uploaded_scoped_to_microphone_audio': True, 'no_account_no_ads_retained': True, 'does_not_deny_imported_local_recordings': True, 'no_new_telemetry_storage_duration_or_legal_claim': True, 'only_unconditional_gc_promise_removed': True}, 'old_privacy_paragraph': ops['old_privacy_paragraph'], 'author_privacy_paragraph': ops['new_privacy_paragraph'], 'reviewed_privacy_paragraph': ops['new_privacy_paragraph'] if locale not in refinement_terms else refinements[-1]['replacement_paragraph'], 'gc_removal': gc, 'current_content_sha256': p['current_content_sha256'], 'author_proposed_content_sha256': p['author_proposed_content_sha256'], 'reviewed_final_content_sha256': store.content_hash(final), 'reviewed_final_description_sha256': sha(final['description']), 'reviewed_source_content_sha256': store.content_hash(source_proposed), 'unchanged_fields_sha256': p['unchanged_fields_sha256'], 'notes': notes.get(locale, 'Live microphone input and on-device analysis read together; recording/upload denial stays scoped to that input. No-account/no-ad meaning retained.'), 'lineage': 'Full payload review and 309-correction history inherited only for unchanged material; this new review covers the exact bounded delta.'})

check('50 unique locale decisions', len(decisions) == len({p['locale'] for p in proposals}) == 50)
check('16 embedded and 34 standalone removals', sum(count for kind, count in kinds.items() if 'standalone' in kind) == 34 and sum(count for kind, count in kinds.items() if 'standalone' not in kind) == 16)
publication = read(ROOT / 'docs/ios/readiness/reviews/cloudflare-publication.json')
check('parent publication route evidence', any(route['url'] == url and route['status'] == 200 for route in publication['routes']))
check('parent identity evidence', publication['publisher_name'] == 'Shahrad Azeri Sharghi' and publication['public_contact_email'] == 'shahroodazerov@gmail.com' and publication['no_repository_references'] is True)
write('per-locale-decisions.json', {'reviewer': 'Codex /root/store_release_copy_review', 'locale_count': 50, 'decisions': decisions})
write('guarded-refinements.json', {'scope': 'Apply only after verifying frozen author file and exact paragraph guards. No live files changed by reviewer.', 'refinements': refinements})
write('checks-and-advisories.json', {'checks': checks, 'check_count': len(checks), 'all_passed': all(item['pass'] for item in checks), 'removal_kinds': dict(kinds), 'source_decision': 'Accept exact English description proposal; integrate App Information privacy row and obsolete owner TODO cleanup in same transaction.', 'required_integration': ['Apply all50 accepted descriptions, with Greek/Indonesian register refinements, and production_privacy_url fields atomically with English source document.', 'Replace App Information Privacy Policy URL placeholder and remove obsolete owner TODO that demands a custom domain/URL replacement and conditional GC bullet deletion; use verified URL and current default-NO facts.', 'Rebind source snapshots and record new delta review identities/hashes; preserve every previous full-review object and all309 historical corrections without relabeling old approvals.', 'Do not mark privacy/native/device/legal/Apple-account/release gates passed based on this text review.'], 'url_verification_attribution': {'basis': 'Read parent durable publication artifact; this reviewer made no HTTP request.', 'artifact': 'docs/ios/readiness/reviews/cloudflare-publication.json', 'sha256': sha((ROOT / 'docs/ios/readiness/reviews/cloudflare-publication.json').read_bytes()), 'recorded_user_agent': publication['verification_user_agent'], 'recorded_status': 200, 'hosting_observation': publication['hosting_observation']}, 'optional_advisories': ['French France téléversé is inherited and understandable; mis en ligne is an optional regional polish, excluded from guarded refinements.', 'Source document age-rating/social-messaging/contest answers mention GC separately; their truth is outside this bounded listing delta and should follow actual candidate functionality in the readiness review.'], 'limitations': ['Independent source-aware AI review, not native fluency certification or blinded legal back-translation.', 'No fresh full-payload semantic re-review claimed: unchanged descriptions/metadata are guarded exactly and inherit prior reviews.', 'No account/device/screenshot/Apple approval or release_ready certification.'], 'release_ready': False})
manifest = {'reviewer': 'Codex /root/store_release_copy_review', 'role': 'independent bounded semantic/delta reviewer; separate from author /root/review_is', 'reviewed_utc': datetime.now(timezone.utc).isoformat(), 'scope': 'Actual all50 old/new privacy paragraphs and removed GC claims directly read; 16 mixed lines read before/after; full-description delta exhaustively reconstructed and guarded.', 'frozen_author_inputs': inputs, 'artifacts': {name: sha((OUT / name).read_bytes()) for name in ['build-review.py', 'per-locale-decisions.json', 'guarded-refinements.json', 'checks-and-advisories.json']}, 'decisions': {'accept_as_proposed': 48, 'accept_with_guarded_register_refinement': 2}, 'integration_status': 'proposed only; root integration and source/lineage rebinding pending', 'release_ready': False}
write('manifest.json', manifest)
print(json.dumps({'locales': len(decisions), 'checks': len(checks), 'all_passed': True, 'refinements': list(refinement_terms), 'manifest_sha256': sha((OUT / 'manifest.json').read_bytes())}))
