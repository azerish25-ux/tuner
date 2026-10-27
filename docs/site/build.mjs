import { mkdir, readFile, writeFile } from 'node:fs/promises';
import { marked } from 'marked';

const output = new URL('./public/', import.meta.url);
await mkdir(output, { recursive: true });
const styles = `
:root{color-scheme:dark light;--bg:#0e0c0b;--ink:#f5efe6;--soft:#b3a99e;--link:#6ee7c1;--line:#3c3530}
@media(prefers-color-scheme:light){:root{--bg:#f8f5ef;--ink:#1a1510;--soft:#5e554c;--link:#005b45;--line:#c9bfb1}}
*{box-sizing:border-box}body{margin:0;background:var(--bg);color:var(--ink);font:17px/1.7 system-ui,sans-serif}
header,main,footer{max-width:760px;margin:auto;padding:24px}header{display:flex;align-items:center;justify-content:space-between;gap:24px;border-bottom:1px solid var(--line)}
nav{display:flex;gap:20px;flex-wrap:wrap}a{color:var(--link);text-underline-offset:.2em}a:focus-visible{outline:3px solid var(--link);outline-offset:5px;border-radius:2px}
.brand{color:var(--ink);font-weight:700;text-decoration:none;letter-spacing:.03em}main{padding-top:32px;padding-bottom:40px;overflow-wrap:break-word}
h1{font:400 clamp(2.1rem,7vw,3rem)/1.2 Georgia,serif;margin:8px 0 28px}h2{font-size:1.2rem;line-height:1.4;margin:34px 0 12px}p,li{color:var(--soft)}li+li{margin-top:12px}strong{color:var(--ink)}
footer{border-top:1px solid var(--line);font-size:.875rem}.skip{position:absolute;top:-80px;left:16px;padding:12px;background:var(--bg);z-index:1}.skip:focus{top:12px}
@media(max-width:420px){header,main,footer{padding-left:20px;padding-right:20px}header{align-items:flex-start;gap:16px}nav{gap:12px}}
`;

for (const [slug, title, source] of [
  ['privacy', 'Timbre Privacy Policy', '../ios/PRIVACY.md'],
  ['support', 'Timbre Support', './SUPPORT.md'],
]) {
  const markdown = await readFile(new URL(source, import.meta.url), 'utf8');
  const body = marked.parse(markdown, { gfm: true });
  const html = `<!doctype html>
<html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1">
<title>${title}</title><meta name="description" content="${title} — official information and help for Timbre."><style>${styles}</style></head>
<body><a class="skip" href="#content">Skip to content</a>
<header><a class="brand" href="support.html">Timbre</a><nav aria-label="Information"><a href="support.html"${slug === 'support' ? ' aria-current="page"' : ''}>Support</a><a href="privacy.html"${slug === 'privacy' ? ' aria-current="page"' : ''}>Privacy</a></nav></header>
<main id="content">${body}</main><footer>Timbre · Shahrad Azeri Sharghi</footer></body></html>
`;
  await writeFile(new URL(`${slug}.html`, output), html);
  // Keep the existing publication inputs synchronized for the legacy GitHub Pages address.
  await writeFile(new URL(`./${slug}.html`, import.meta.url), html);
}
await writeFile(new URL('_redirects', output), '/ /support 302\n');
await writeFile(new URL('_headers', output), `/*
  Content-Security-Policy: default-src 'none'; style-src 'unsafe-inline'; base-uri 'none'; form-action 'none'; frame-ancestors 'none'
  X-Content-Type-Options: nosniff
  Referrer-Policy: no-referrer
  Permissions-Policy: camera=(), microphone=(), geolocation=()
  Cache-Control: public, max-age=300
`);
console.log('Built privacy/support static pages; no Worker script or paid binding.');
