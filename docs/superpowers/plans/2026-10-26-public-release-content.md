# Public release content implementation plan

> For agentic workers: implement one task at a time with independent review before committing. The user has authorized repository fixes, commit/push and free Cloudflare hosting; Apple account configuration/signing/upload remain outside this stage.

**Goal:** Publish accurate privacy/support pages on free Cloudflare hosting, record the owner's image provenance, and wire only verified production addresses into the app and listing.

**Architecture:** Markdown is the canonical public policy/support content. A small static build produces HTML served by Cloudflare Workers Static Assets, without a Worker script, database, analytics or paid resources. The existing app configuration and fallback use the same verified URL after deployment.

**Stack:** Markdown, Node.js, pinned Marked/Wrangler, Cloudflare Static Assets, Python resource verification.

## Constraints
- Keep all49 app languages and all50 store locales.
- Preserve existing external CC BY model/audio/font credits and all image hashes.
- Record the owner's actual statement; infer no vendor, source URL or third-party licence.
- Disclose current app behavior precisely. No claims of a hardware/legal/human-native review pass.
- No Apple delivery workflow or account changes.
- Free Cloudflare plan and free workers.dev hostname; no temporary preview URL as the production policy URL.

## Task1: Image provenance
- [ ] Bind the68 entries whose origin is provided at0c67901 to the owner's26October confirmation, "I created/generated them".
- [ ] Update only their provenance metadata in ios/Sources/TimbreCore/Resources/photos.json and document exact asset/hash inventory in docs/content/INSTRUMENT-IMAGE-PROVENANCE.md.
- [ ] Run tools/verify-ios-resources.py; independently verify count/hash preservation and factual scope.

## Task2: Public policy/support build
- [ ] Update docs/ios/PRIVACY.md for local imported recordings/charts, optional MusicKit, accurate identifier/network/support descriptions and opt-out limits. Keep claims aligned with the eventual reviewed analytics fix.
- [ ] Add canonical docs/site/SUPPORT.md, a static builder and pinned package lock, assets-only wrangler.jsonc and strict static response headers.
- [ ] Build into ignored public output. Verify every route, heading/link, no scripts/remote font/analytics and deployment dry run; inspect actual local browser at mobile/desktop widths.
- [ ] Obtain independent source/content review and resolve findings before publication.

## Task3: Publish and wire addresses
- [ ] Complete Cloudflare OAuth in the owner's account after the concrete site is ready; never request/paste API secrets.
- [ ] Deploy the reviewed static assets to the owner's free workers.dev hostname. Check actual HTTPS status/content/headers and privacy/support links.
- [ ] Update ios/project.yml and Services/ShareDestination.swift privacy defaults to the verified address. Update listing source/payload URL facts with source-bound review lineage, preserving translations and release gates.
- [ ] Prepare the legacy GitHub Pages policy update/redirect so old builds reach current information.
- [ ] Verify local gates and exact published source, independently review, commit/push. Keep later Apple-account/hardware checks explicitly pending.

## References
- docs/HANDOVER.md, KNOWN-ISSUES.md§6, RELEASE-CHECKLIST B/C5/H6.
- docs/ios/readiness/reviews/privacy-baseline.json.
- Cloudflare: developers.cloudflare.com/workers/static-assets/get-started/ and /binding/.
- Apple: developer.apple.com/app-store/app-privacy-details/.
