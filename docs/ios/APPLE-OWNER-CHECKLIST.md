# Apple Developer / App Store Connect — owner checklist

**Documentation checked: 28 October 2026. Account status below is a prior verified snapshot, not a new portal inspection.** This checklist neither changes an account nor authorizes agreements, credentials, signing, upload or release. It does not answer legal or tax questions for the owner.

At **00:09 on 28 October**, the owner said this setup was **not yet done** and that they would notify us after completing it. That remains the handoff boundary. No later completion is assumed; no login, verification-code or private-document request is outstanding from this checklist.

## 1. What already exists, and what is still unknown

| Item | Last verified / recorded state | What it does not prove |
|---|---|---|
| App record | Timbre, Apple ID **6827721551**, SKU **timbre-ios-001** | No public release, processed build or approval implied |
| Developer team | **L8BZ8KG2WB** | Membership renewal, current permissions and signing still need action-time verification |
| Listing drafts | **50 names/subtitles and 50 version-text drafts saved** | These are drafts, not approved listings or complete screenshot uploads |
| Screenshots | **Not uploaded** at last verification | Local compositions/pilot captures are not portal uploads |
| Identifiers | Four explicit bundle IDs and one App Group registered; see below | Registration alone does not prove correct capability associations or signed profiles |
| Free agreement | **Active** at last verification | Does not replace the Paid Apps Agreement for IAP |
| Paid Apps Agreement | **New** at last verification | Not accepted/active; do not mark it complete |
| Legal entity / DSA | **Incomplete** at last verification | No identity/trader determination has been made on the owner's behalf |
| Bank and tax | **Unverified** | Not a claim that they are absent, submitted, approved or payable |
| Game Center | **Off** for this release | Do not enable it as an incidental setup step |
| CI signing / live commerce / TestFlight | **Not established by this checklist** | Unsigned simulator passes and local StoreKit fixtures are not proof |

Registered identifiers:

- Main app: `com.shahradazerisharghi.timbre`
- iOS widgets: `com.shahradazerisharghi.timbre.widgets`
- Watch app: `com.shahradazerisharghi.timbre.watchkitapp`
- Watch widgets: `com.shahradazerisharghi.timbre.watchkitapp.widgets`
- App Group: `group.com.shahradazerisharghi.timbre`

Use the [existing app record](https://appstoreconnect.apple.com/apps/6827721551), not a new app/SKU. Source configuration remains in `ios/project.yml`. Recheck the four targets' App Group associations and required capabilities without enabling Game Center. Optional MusicKit configuration and its remaining verification are documented in [Apple delivery](https://github.com/azerish25-ux/tuner/blob/f937c5d412956fd4d7b5468659f049103aee402f/docs/ios/APPLE-DELIVERY.md#8-your-songs-and-apple-music-musickit-owner-steps).

## 2. Owner completes the business/account blockers

These are owner-operated steps for the correct team, not permission for an assistant to accept terms or submit personal information.

### A. Verify the legal entity

- [ ] In [App Store Connect](https://appstoreconnect.apple.com/), open **Business → Agreements** and review the legal entity already associated with this membership. The last observed screen showed **Edit Legal Entity**; that historical label does not guarantee that today's UI or state is unchanged. Use the existing business record, not a new registration.
- [ ] Supply only accurate information from the owner's own records in Apple's fields. Do not select an organization type, residency, address or identifier merely to get past validation.
- [ ] Distinguish completing missing fields from changing an existing membership entity. Apple says membership name/address changes require a verified request through membership details/Apple Support; do not treat an Edit button as authority to replace the contracting entity. Keep any requested identity/business documentation inside Apple's approved process. [Apple account-update guidance](https://developer.apple.com/help/account/membership/updating-your-account-information).

### B. Review agreements personally

- [ ] The **Account Holder** reviews any pending Developer Program terms and the **Paid Apps Agreement** in **Business → Agreements**. For the Paid row, use **View and Agree to Terms** only after personally reading and deciding to accept. Apple notes that acceptance cannot be undone. Even a free-download app needs this agreement to offer IAP.
- [ ] Complete the required follow-on information and wait for the actual agreement status to become **Active**. Record the displayed status and date; a successful click is not activation evidence. [Apple agreement instructions](https://developer.apple.com/help/app-store-connect/manage-agreements/sign-and-update-agreements/).

### C. Complete tax and bank information

- [ ] After accepting the paid agreement, use **Business → Agreements → Tax Forms → Add Tax Info** for the forms Apple presents. The required forms depend on the enrolled entity/jurisdiction; Apple requires a US tax form for all developers under the paid agreement. The owner or their qualified adviser determines the applicable form, tax residency, beneficial-owner information and any treaty claims. Do not copy guessed answers from a sample. Submit and retain the actual processing status. [Apple tax instructions](https://developer.apple.com/help/app-store-connect/manage-tax-information/provide-tax-information).
- [ ] In **Bank Accounts → Add Bank Account**, enter the owner's actual eligible account details, account currency, routing/IBAN where applicable, and bank-account-holder information. Verify against the bank's records; do not substitute an intermediary bank or invent missing fields. Account Holder, Admin or Finance can enter information, but changes initiated by Admin/Finance may require Account Holder approval. Tax requirements must also be completed for processing. Confirm the final bank status, not just that a row exists. [Apple banking instructions](https://developer.apple.com/help/app-store-connect/manage-banking-information/enter-banking-information).

**Keep tax IDs, banking details, identity scans and legal documents out of this repository, chat, issue comments and CI artifacts.** If uncertain, obtain advice from the relevant professional or Apple; this document is operational guidance, not legal/tax advice.

### D. Complete DSA declarations accurately

- [ ] Account Holder/Admin: **Business → Agreements → Compliance → Digital Services Act → Complete Compliance Requirements**. The owner determines trader status; uncertainty belongs with their legal adviser. Do not select non-trader just to avoid contact verification.
- [ ] For a trader declaration, complete Apple's contact verification and any requested documentation/certification. Trader contact information is displayed publicly for EU distribution; inspect exactly what will be published. Organization and individual requirements differ. Do not paste those private inputs into the handoff.
- [ ] Reconcile this app's declaration under **Apps → Timbre → App Information → App Store Regulations and Permits → Digital Services Act**. Apple requires a trader-status declaration even if EU distribution is not selected. Verify account-level processing and app-specific status before claiming completion. [Apple DSA guidance](https://developer.apple.com/help/app-store-connect/manage-compliance-information/manage-european-union-digital-services-act-trader-requirements/).

## 3. Configure commerce only after owner decisions

Preserve these existing product identities; verify rather than duplicate existing portal records:

| Product ID | Intended type |
|---|---|
| `timbre_pro_monthly` | Monthly auto-renewable subscription, group **Timbre Pro** |
| `timbre_pro_annual` | Annual auto-renewable subscription, same group/Pro entitlement |
| `timbre_plus_lifetime` | Non-consumable lifetime Pro access; the historical ID does not mean a weaker tier |

- [ ] Verify the group, durations, product availability, localized names/descriptions, review screenshots and review notes. Determine any trial/offer policy explicitly; no trial is assumed from test fixtures. Configure through the app's **Subscriptions** and **In-App Purchases** sections. Follow Apple's [IAP configuration overview](https://developer.apple.com/help/app-store-connect/configure-in-app-purchase-settings/overview-for-configuring-in-app-purchases/) and [first-IAP submission instructions](https://developer.apple.com/help/app-store-connect/manage-submissions-to-app-review/submit-an-in-app-purchase/).
- [ ] Do not enable optional annual price-test products, Family Sharing, grace-period experiments or promotional offers merely because code supports them. They require separate decisions and verification; [Family Sharing cannot be turned off for a product once enabled](https://developer.apple.com/help/app-store-connect/configure-in-app-purchase-settings/turn-on-family-sharing-for-in-app-purchases).

### Country/storefront pricing is still a proposal

The [country-pricing policy](https://github.com/azerish25-ux/tuner/blob/f937c5d412956fd4d7b5468659f049103aee402f/docs/ios/readiness/pricing/country-pricing-policy.md) and its JSON are the existing proposal, **not configured or verified live prices**. Recorded anchors are USD **3.99 / 19.99 / 59.99** and CAD **4.99 / 24.99 / 74.99** for monthly/annual/lifetime. These are not confirmed Apple price points, approval to apply them, or a revenue forecast.

- [ ] Owner reviews the proposed affordability approach and every intended storefront before configuration. The recorded public inventory has 175 countries, with Anguilla/Montserrat classification unresolved and Kosovo's authenticated territory mapping unresolved; that prior public research has **not** been rechecked here.
- [ ] Resolve authenticated app/product availability, Apple's actual territory identifiers, available currencies/price points, taxes/proceeds and dates. Use the same three product IDs across storefronts, not one product per language/country. The customer’s storefront—not UI language, IP or device region—selects the offer. [Apple subscription availability](https://developer.apple.com/help/app-store-connect/manage-subscriptions/set-availability-for-an-auto-renewable-subscription).
- [ ] In each subscription's **Subscription Prices**, review the starting-country price and every offered equivalent/override before confirming. Non-consumable pricing has its own schedule. Apple's equalization is not the proposed affordability policy; do not assume subscription prices are automatically maintained like other pricing. [Subscription pricing](https://developer.apple.com/help/app-store-connect/manage-subscriptions/manage-pricing-for-auto-renewable-subscriptions), [IAP pricing](https://developer.apple.com/help/app-store-connect/manage-in-app-purchases/set-a-price-for-an-in-app-purchase).
- [ ] After configuration, independently read back schedules and test actual localized StoreKit prices. Structural policy validation is not completion; the current `--require-complete` gate intentionally remains blocked until its authenticated evidence verifier exists. Never flip readiness flags to bypass it.

## 4. Secure CI signing credentials — no secrets in the repository

The current [manual delivery workflow](https://github.com/azerish25-ux/tuner/blob/f937c5d412956fd4d7b5468659f049103aee402f/.github/workflows/apple-delivery.yml) uses Xcode automatic provisioning/signing plus an App Store Connect API key. It does not currently require a manually uploaded `.p12` or provisioning-profile secret. Do not add a parallel signing mechanism without review.

- [ ] Account Holder requests API access if needed. An authorized Account Holder/Admin creates a dedicated **team** key under **Users and Access → Integrations → App Store Connect API → Team Keys**, with the least role privileges that actually permit this workflow's provisioning/upload tasks. Do not default to broad Admin access to resolve a failure. Team keys cover all apps; they cannot be limited to Timbre alone. [Apple API-access guidance](https://developer.apple.com/help/app-store-connect/get-started/app-store-connect-api/).
- [ ] A user-scoped individual key is **not interchangeable** here: Apple excludes individual keys from provisioning endpoints, while this workflow uses `-allowProvisioningUpdates` and an issuer ID. Download the private key once, store it securely, and revoke it promptly if compromised. Never put `.p8` contents in source, chat, screenshots or client code. [Apple key types and security](https://developer.apple.com/documentation/AppStoreConnectAPI/creating-api-keys-for-app-store-connect-api).
- [ ] An authorized repository administrator configures the protected **apple-delivery** GitHub environment, restricted to the approved delivery branch and owner approval before credentials are released. Confirm these protections actually exist. Use provider secret fields only:

| Environment secret | Required value |
|---|---|
| `APPLE_TEAM_ID` | `L8BZ8KG2WB` |
| `APP_STORE_CONNECT_KEY_ID` | The authorized team's key ID |
| `APP_STORE_CONNECT_ISSUER_ID` | Its issuer UUID |
| `APP_STORE_CONNECT_API_KEY_P8` | Raw PEM private-key contents, **not Base64** |

The workflow writes the key with restrictive temporary permissions and deletes its temporary signing directory in an always-run cleanup step. Do not print the values to troubleshoot. Environment-secret presence is not proof of successful authentication or signing. Creating persistent credentials and dispatching upload are separate owner-authorized actions, not actions performed by this checklist.

## 5. What still must pass after the owner finishes setup

1. **Recheck account status.** Record non-sensitive statuses and verification time for legal entity, agreements, DSA, bank/tax, identifiers/capabilities and intended prices. Owner confirmation is welcome but does not itself certify signed binaries or live purchase behavior.
2. **Exact-source delivery gates.** Follow [Apple delivery](https://github.com/azerish25-ux/tuner/blob/f937c5d412956fd4d7b5468659f049103aee402f/docs/ios/APPLE-DELIVERY.md) and the [release checklist](https://github.com/azerish25-ux/tuner/blob/f937c5d412956fd4d7b5468659f049103aee402f/docs/ios/RELEASE-CHECKLIST.md). The current main revision, latest required native jobs, source-bound privacy/listing evidence and localization gates must genuinely pass. Historical green runs, cancelled jobs, draft metadata and source-only tests cannot replace them.
3. **Signed archive.** After explicit authorization for the revision/version/build/destination, verify Xcode signs all four targets for the intended team; inspect embedded profiles, App Group/capability entitlements, bundle/version/build consistency and the archive-scope report. Registered IDs alone do not prove this. No signing/upload is dispatched merely because the owner completed business forms.
4. **Apple processing/TestFlight.** An upload receipt is not processed-build availability. Check processing errors, compliance questions and the exact build in TestFlight. Invite only authorized testers; external beta testing has separate review requirements. An internal-only export cannot be reused for external testing or App Store submission. [Apple upload guidance](https://developer.apple.com/help/app-store-connect/manage-builds/upload-builds/), [TestFlight overview](https://developer.apple.com/help/app-store-connect/test-a-beta-version/testflight-overview/).
5. **Real configured-product sandbox checks.** Verify product loading, storefront price/currency, eligible offers, purchase/cancel/pending flows, restore, entitlement changes, renewal/expiry and refund/revocation behavior. TestFlight uses the sandbox; accelerated renewals are not production billing. Local `.storekit` fixtures and a TestFlight install alone do not establish live product correctness. No real-money purchase is required merely to prove sandbox behavior. [Apple sandbox overview](https://developer.apple.com/help/app-store-connect/test-in-app-purchases/overview-of-testing-in-sandbox/), [TestFlight IAP testing](https://developer.apple.com/help/app-store-connect/test-a-beta-version/testing-subscriptions-and-in-app-purchases-in-testflight/).
6. **Listing and submission.** Reconcile the 50 saved text drafts with the exact shipping build. Upload only accepted native-backed screenshots into the correct locale/device slots after separate upload authorization; screenshots remain unuploaded in the last account snapshot. Complete accurate privacy, content-rights, age-rating, export-compliance and review-contact answers; the owner supplies legal determinations. Game Center stays off. Initial scope remains screenshots, not App Preview uploads. Submission and public release remain separate approvals.

### Non-sensitive completion handoff

When the owner reports completion, record only status/date or a redacted receipt: legal-entity verification; Free/Paid agreement statuses; tax/bank processing statuses; DSA verification/app declaration; whether the protected CI environment is configured; which pricing decisions were approved/applied. Do **not** include account numbers, tax IDs, addresses, verification codes, private keys, identity scans or legal attestations in repository evidence. Leave every unverified item explicitly unverified.
