# Proposed country-based pricing

**Status: proposed prices; 175 public storefronts reconciled; two income-classification exceptions; no live prices configured or verified.**

The owner requested lower monthly, annual and lifetime prices in less affluent countries, independent of app/listing language. The customer’s Apple Account storefront determines the applicable territory. The 50 metadata localizations are not a pricing-country list. [Apple availability](https://developer.apple.com/help/app-store-connect/manage-your-apps-availability/manage-availability-for-your-app-on-the-app-store).

## Proposed anchors

| Storefront | Currency | Monthly | Annual | Lifetime |
|---|---|---:|---:|---:|
| United States | USD | 3.99 | 19.99 | 59.99 |
| Canada | CAD | 4.99 | 24.99 | 74.99 |

These are editorial launch proposals, not verified Apple price points or an earnings forecast. They supersede the earlier high-price research recommendation only after the owner’s pricing plan is reconciled into the authoritative release documentation. No price has been applied by this artifact.

Lifetime uses the historical `timbre_plus_lifetime` identifier but grants the same Pro access as subscriptions (`ios/Sources/TimbreCore/Commerce/Access.swift`). Keep the existing product identifiers; do not create one product per country or infer an entitlement tier from its name.

## Evidence checked 2026-10-27

Public App Store IAP lists may contain old or account-specific offers; these are listed options, not verified checkout offers for every customer.

| Competitor option | US monthly / annual | Canada monthly / annual |
|---|---|---|
| GuitarTuna Tools | USD 6.49 / 29.99 | CAD 6.99 / 27.99 |
| GuitarTuna Play | USD 9.99 / 39.99 | CAD 9.99 / 39.99 |
| GuitarTuna Learn | USD 24.99 / 139.99 | CAD 24.99 / 179.99 |
| Yousician one instrument | USD 19.99 / 119.99 | CAD 27.99 / 159.99 |

Sources: [GuitarTuna US](https://apps.apple.com/us/app/guitartuna-tune-play-guitar/id527588389), [Canada](https://apps.apple.com/ca/app/guitartuna-tune-play-guitar/id527588389), [Yousician US](https://apps.apple.com/us/app/yousician-learn-play-guitar/id959883039), [Canada](https://apps.apple.com/ca/app/yousician-learn-play-guitar/id959883039).

The proposed monthly/annual anchors are lower than these named paid options. **Do not claim cheaper than all competitors:** [Simply Tune is free](https://apps.apple.com/us/app/guitar-tuner-simply-tune/id1573260863), and utility-only apps can cost less than the proposed lifetime purchase. No like-for-like curriculum-inclusive lifetime competitor price was verified. Preserve the app’s useful free tuning tier and explain the learning/practice value of Pro.

## Affordability methodology

Use World Bank FY2027 income classification, based on 2025 Atlas GNI per capita, as an initial country-level proxy: high income 100%, upper-middle 65%, lower-middle 35%, low income 20% of the base economic price. These percentages are our policy proposals, **not World Bank recommendations**. Thresholds are USD 1,175 / 4,635 / 14,375. Income group is not a measurement of an individual customer’s income, nor proof of willingness to pay. [Current classification](https://datahelpdesk.worldbank.org/knowledgebase/articles/906519-world-bank%20country-and-lending-groups).

Apply the factor first, then use dated exchange-rate evidence and a supported local Apple price point, preferably at or below the affordability target. Review local competition, estimated proceeds, taxes, support costs and coherent monthly/annual/lifetime ordering. Equal or neighboring local points may result from rounding. Unclassified countries require manual review, not an expensive default. Recheck quarterly and after major currency/tax changes.

Apple supports territory-specific subscription prices; subscription prices generally do not automatically change for currency/tax changes. [Subscription guidance](https://developer.apple.com/app-store/subscriptions/). Non-consumable prices can use automatic equalization or manual territory overrides; manually managed prices require maintenance. Automatic equalization is not this affordability policy. [IAP pricing guidance](https://developer.apple.com/help/app-store-connect/manage-in-app-purchases/set-a-price-for-an-in-app-purchase).

## Machine-readable state and release gate

`country-pricing-policy.json` maps **175 public App Store storefront countries**. Apple's public App Store country selector and the App Store service sections of its [Media Services availability page](https://support.apple.com/en-us/118205) independently reconcile to the same 175 countries. The selector has 177 rows because Armenia and Turkmenistan are repeated identically, not because there are 177 storefronts.

Income classification is verified for 173 countries: 172 from the World Bank API and Taiwan from its explicit high-income classification in the official FY2027 table. **Anguilla and Montserrat remain unclassified/manual review**; do not inherit the UK's income group or default to high-income prices. Kosovo's public storefront is XK and its World Bank identifier is XKX; its actual App Store Connect territory ID remains unresolved.

Public availability is distinct from this app's authenticated availability and purchase readiness. All actual currency amounts, supported Apple price-point IDs, app/product availability checks and live schedules remain unverified. The generic Apple TerritoryCode enum is not the active inventory (234 rows, 233 unique codes, including a duplicate ARE label); do not use that enum count as coverage.

The compact source-data JSON contains country facts, source URLs and archived-byte hashes. Full source HTML is not redistributed. The validator binds every policy row to the reviewed evidence, rejects duplicate/missing/substituted countries, unsupported income overrides and invented API identifiers. US/Canada anchor proposals remain separate from verified schedules.

Run:

```sh
python3 tools/ci/test_country_pricing_policy.py
python3 tools/ci/validate_country_pricing_policy.py
python3 tools/ci/validate_country_pricing_policy.py --require-complete
```

Structural validation is permitted for a clearly labelled proposal. `--require-complete` is deliberately blocked in this proposal schema: an independent active-territory importer and source-bound Apple price-point verifier are not implemented yet. Filling in counts, flags or arbitrary IDs cannot bypass that blocker. Implement and review that evidence verifier before certifying a complete mapping. Do not infer readiness from the structural test passing.

Before configuration, verify the current authenticated Apple territory IDs, resolve both income-classification exceptions using country-specific evidence, resolve supported prices for all three products, and review proceeds. After configuration, independently read back schedules and verify sandbox prices. Existing annual price-experiment products must not bypass the country policy if activated.

The paywall already uses StoreKit `displayPrice`, numeric prices and their currency formatting for comparisons. Test storefront changes separately from UI language; do not add location/IP/language-based price selection. [StoreKit displayPrice](https://developer.apple.com/documentation/storekit/product/displayprice).
