# Website pages (to publish)

`privacy.html` (generated from [docs/ios/PRIVACY.md](../ios/PRIVACY.md)) and `support.html` are the pages the App Store
listing and the app link to. They are **not published automatically**: the live copies are on the `gh-pages` branch
(https://azerish25-ux.github.io/tuner/privacy.html), which on 2026-10-25 still carries the 23 October policy that says
analytics stay on the device — out of date, because the app now sends anonymous analytics (with an opt-out).

To publish (owner): copy these two files onto the `gh-pages` branch (or your own domain) and push; then set the App
Store Connect **Privacy Policy URL** and **Support URL** to them. Regenerate `privacy.html` whenever PRIVACY.md changes.
