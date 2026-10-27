# Public privacy and support pages

Published on Cloudflare Workers Static Assets:

- Privacy: https://timbre-support.timbre.workers.dev/privacy
- Support: https://timbre-support.timbre.workers.dev/support

The public contact is **shahroodazerov@gmail.com**. The publisher is **Shahrad Azeri Sharghi**.
Public pages contain no repository references. The site uses static assets and a free workers.dev hostname,
with no Worker script, database, site analytics or paid binding.

Canonical sources are [PRIVACY.md](../ios/PRIVACY.md) and [SUPPORT.md](SUPPORT.md). Run `npm ci`, then
`npm run build` to generate `public/` and the legacy publication inputs `privacy.html`/`support.html`.
`npm run preview` starts Wrangler locally. `npm run check:deploy` validates deployment without publishing;
`npm run deploy` publishes the current build to the authenticated owner's account.

Use Wrangler OAuth for authentication. Windows credentials are stored encrypted with their key in
Windows Credential Manager. Do not commit credentials, `.wrangler/` or generated `public/` output.
The actual HTTPS content/header verification is recorded under `docs/ios/readiness/reviews/`.

The former GitHub Pages policy address is a compatibility concern for older builds; it must be refreshed or
redirected to the canonical Cloudflare policy. The Apple account's Privacy Policy URL and Support URL
are configured later, when the owner sets up App Store Connect.
