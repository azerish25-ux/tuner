# Read-only pricing verification

The collector and verifier are implemented and tested with synthetic fixtures. **No authenticated account collection, approved target prices, live price configuration or sandbox purchase verification has been performed.** This tool does not set any release-readiness flag. The existing schema-2 proposal remains blocked in complete/release mode.

`tools/ci/verify_apple_pricing.py` makes fresh GET requests to Apple and compares the resulting inventory against a separately approved target manifest. It discovers the app by its shipping bundle ID, discovers the three shipping products through that app's collections, and checks their types and durations. Every collection and relationship is paginated independently. Scheduled price-point IDs must belong to the expected product's territory-filtered catalogue; IDs are never decoded or inferred.

The comparison requires complete public-country coverage from the reviewed policy, unique country/Apple-territory pairs, matching currencies and app/product availability. Known territory candidates must match the source policy. An unresolved mapping needs a `mapping_evidence_reference`; an unclassified income group needs a `manual_income_decision`. Those references and decisions must be part of the owner-reviewed manifest, not invented by the collector.

All acquisition prices active on the evaluation date and all scheduled future changes must match exact decimal amounts, currencies, point IDs and intervals. The verifier rejects gaps, overlaps, unknown plans, missing acquisition prices and incoherent monthly/annual/lifetime ordering. Preserved subscriber prices remain in the evidence but are explicitly excluded from new-customer comparisons. Original schedule dates and manual/automatic provenance are retained.

## Owner-stage inputs

Supply an approved manifest containing:

- `schema_version: 1`, shipping `bundle_id`, actual Apple `app_id`, and an `approval_reference`.
- `source_policy_sha256`: the hash of the reviewed `country-pricing-policy.json` bytes.
- `territories`: all policy countries, each with `public_country_code`, actual `apple_territory_id`, `currency`, and any required mapping/income review reference.
- `products`: exactly `monthly`, `annual`, `lifetime`. Each has the shipping `product_id`, actual `apple_id`, `plan_type: "UPFRONT"` for subscriptions, and a `prices` map keyed by Apple territory ID.
- Each price-map value is a list of intervals with exactly `start_date`, `end_date`, `price_point_id`, `customer_price`, and `currency`. Dates are ISO dates or null for an unbounded endpoint; amounts are positive decimal strings. Current and all future intervals must form a continuous schedule.

The approved manifest's SHA-256 must come from a separate owner-reviewed checkpoint. Computing a hash from arbitrary local targets and treating it as approval does not establish that approval. No target manifest is supplied with guessed country prices.

After authorized read access is available, a protected execution environment can provide a short-lived bearer token through `ASC_READ_ONLY_BEARER_TOKEN`. Do not paste credentials into chat, arguments, repository files or receipts. The tool uses GET exclusively, rejects redirects, restricts requests to Apple's API host, bounds responses/requests, and excludes authorization material from saved evidence and errors. It does not create keys, change availability or prices, sign, upload or submit anything.

```sh
python3 tools/ci/verify_apple_pricing.py \
  --approved-targets /secure/path/approved-targets.json \
  --approved-target-sha256 "$APPROVED_PRICE_TARGET_HASH" \
  --as-of YYYY-MM-DD \
  --output ci-out/pricing/comparison.json
```

The date is explicit because the result is scoped to that schedule date and future changes. A successful run means fresh prices match the supplied approved targets; it does not prove agreements, tax/banking, sandbox checkout, metadata or submission readiness.

Saved raw response bodies, page URLs, statuses, timestamps and hashes support review and integrity checks. **Hashes and an `origin` string do not authenticate offline JSON.** The CLI has no offline evidence import. Fixture tests prove correspondence logic only. Reusing a saved report as release evidence requires independent verification of its trusted execution provenance and source/target revisions.

## Validation

```sh
PYTHONPATH=tools/ci python3 -W error::ResourceWarning -m unittest \
  test_apple_pricing_transport test_collect_apple_pricing \
  test_verify_apple_pricing test_country_pricing_policy
```

The isolated Linux workflow runs these tests without account credentials or network requests. The remaining account-stage work is to approve actual territory targets and exceptions, authorize reads, configure prices through the owner's approved process, collect/read back the resulting state, and verify real StoreKit storefront behavior.

API sources: [app availability](https://developer.apple.com/documentation/appstoreconnectapi/get-v1-apps-_id_-appavailabilityv2), [subscription plan availability](https://developer.apple.com/documentation/appstoreconnectapi/get-v1-subscriptions-_id_-planavailabilities), [subscription prices](https://developer.apple.com/documentation/appstoreconnectapi/get-v1-subscriptions-_id_-prices), [subscription price points](https://developer.apple.com/documentation/appstoreconnectapi/get-v1-subscriptions-_id_-pricepoints), [IAP availability](https://developer.apple.com/documentation/appstoreconnectapi/get-v2-inapppurchases-_id_-inapppurchaseavailability), [IAP schedules](https://developer.apple.com/documentation/appstoreconnectapi/get-v2-inapppurchases-_id_-iappriceschedule), [IAP price points](https://developer.apple.com/documentation/appstoreconnectapi/get-v2-inapppurchases-_id_-pricepoints).
