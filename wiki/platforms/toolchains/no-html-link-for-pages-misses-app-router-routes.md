---
id: platforms-toolchains-no-html-link-for-pages-misses-app-router-routes
domain: platforms
category: toolchains
applies_to: [nextjs, eslint]
confidence: verified
sources:
  - https://github.com/vercel/next.js/blob/v16.3.8/packages/eslint-plugin-next/src/utils/url.ts
  - https://github.com/vercel/next.js/blob/v16.3.8/packages/eslint-plugin-next/src/rules/no-html-link-for-pages.ts
  - https://github.com/vercel/next.js/pull/97557
  - https://github.com/vercel/next.js/pull/94556
  - https://nextjs.org/docs/messages/no-html-link-for-pages
last_verified: 2026-10-12
related: [infrastructure-ci-cd-changed-files-only-gates, testing-quality-checks-that-cannot-pass, platforms-toolchains-flag-availability-at-the-execution-site, frontend-design-design-system-lint-gate-for-agents, platforms-toolchains-nextjs-16-build-output-and-tsconfig-rewrite]
---

# `no-html-link-for-pages` as the Gate for App Router Internal Links

## When this applies

A Next.js App Router project (`app/` directory) relies on
`@next/next/no-html-link-for-pages` — enabled by `eslint-config-next` /
`next/core-web-vitals` and run by `next lint` or `eslint` — to force `next/link`
for internal links. A done criterion, review, or plan says "lint is green, so
every internal link uses `<Link>`", or you are writing the gate that must catch
`<a href="/admin">` in `app/` code.

## Do this

1. **Read what the installed rule can match before citing it.** On
   `@next/eslint-plugin-next` 16.3.8 and earlier the App Router list is built
   with `normalizeAppPath` (`^/admin$`, no trailing slash) while every href is
   passed through `normalizeURL`, which appends one (`/admin/`). The anchored
   regex never matches a static app route; only `/` (both sides `/`) and
   dynamic routes (the `[param]` capture group absorbs the slash) are flagged.
2. **Add your own source gate for static routes** and run it on the
   directories that hold JSX (`app/`, `src/`):

   ```sh
   grep -rnE '<a\b[^>]*\bhref=(\{?["'"'"'])/([^/]|$)' app src
   ```

   It reports `href="/x"`, `href={"/x"}`, and `href="/"`; it skips
   `//cdn…`, `https://…`, `#…`, and `mailto:`. Zero lines is the pass.
3. **Prove the gate with a known-bad probe**: add one file containing
   `<a href="/admin">`, require the gate to print that line, then delete the
   probe in the same step. A gate that has never failed is a hypothesis
   (`testing-quality-checks-that-cannot-pass`).
4. **Keep the ESLint rule on.** It still covers the Pages Router (both sides
   use `normalizeURL`), `/`, and dynamic app routes.
5. **Re-check on every plugin upgrade**: open the installed
   `node_modules/@next/eslint-plugin-next/dist/utils/url.js` and read whether
   `getUrlFromAppDirectory` wraps the url in `normalizeURL`. The upstream fix
   (PR #97557, opened 2026-08-19) was still unmerged on 2026-10-12; once it
   lands, the grep gate can go.

| Href in `app/` code (16.3.8) | ESLint rule | Your grep gate |
|------------------------------|-------------|----------------|
| `<a href="/">` | flagged | flagged |
| `<a href="/admin">`, `/admin/login`, `/guestbook` (static `page.tsx`) | **not flagged** | flagged |
| `<a href="/admin/">` (trailing slash written) | not flagged | flagged |
| `<a href="/post/abc">` (`app/post/[slug]/page.tsx`) | flagged | flagged |
| `<a href="/about">` under a route group `app/(group)/about/page.tsx` | not flagged | flagged |

## Edge cases

| Case | Then |
|------|------|
| The project sets `pageExtensions` (`.page.tsx`) | The rule misses those files on top of this (issue #53473, open); the grep gate does not depend on extensions |
| The href is a template literal or a variable (`href={path}`) | Neither the rule nor the grep reads it; cover with a code-review line item or an AST rule (`no-restricted-syntax` on `JSXOpeningElement[name.name='a']`) |
| Links to the same path inside an `<iframe>`, `<form action>`, or `<link>` | Out of scope for both; the gate is about navigation anchors |
| You only need external anchors to open in a new tab | Different rule; this page is about internal navigation |

## Instead of

| If you are about to | Do this instead | Why |
|---------------------|-----------------|-----|
| Cite `next lint` green as proof that no raw `<a>` to an internal route exists | Run the grep gate after a known-bad probe fails it | The rule matches only `/` and dynamic routes on the App Router |
| Upgrade the plugin to "pick up the fix" | Read `getUrlFromAppDirectory` in the installed `dist/utils/url.js` first | The fix PR is open, not released; the version you get may still carry the gap |
| Turn the rule off because it "does nothing" | Keep it; add the gate | It still covers the Pages Router, `/`, and dynamic app routes |

## Sources

- https://github.com/vercel/next.js/blob/v16.3.8/packages/eslint-plugin-next/src/utils/url.ts — L69–L80 `normalizeURL`: `url = url.endsWith('/') ? url : url + '/'`; L148 the Pages Router list wraps each url in `` `^${normalizeURL(url)}$` ``; L169 the App Router list wraps in `` `^${normalizeAppPath(url)}$` `` (L103 `normalizeAppPath` drops empty, `(group)`, `@parallel`, and trailing `page`/`route` segments and never appends a slash)
- https://github.com/vercel/next.js/blob/v16.3.8/packages/eslint-plugin-next/src/rules/no-html-link-for-pages.ts — L149 `const hrefPath = normalizeURL(href.value.value)`; L156 `if (foundUrl.test(normalizeURL(hrefPath)))`
- https://github.com/vercel/next.js/pull/97557 — "flag `<a>` links to static App Router routes" (open, 2026-08-19): "links were normalize before matching so /dashboard becomes /dashboard/. Those two dont line up, so the route never matches"
- https://github.com/vercel/next.js/pull/94556 — (open, 2026-06-08) names the same two bugs: `parseUrlForAppDir` recursing into `parseUrlForPages`, and "`normalizeAppPath` omitted trailing slashes for static app routes … an invalid `<a href="/about">` inside the `app` directory would silently bypass linting"
- https://nextjs.org/docs/messages/no-html-link-for-pages — the rule's own page: it exists to replace `<a>` with `<Link>` for internal navigation, which is the contract the gate above restores
- Probe 2026-10-12 against the published `@next/eslint-plugin-next@16.3.8` tarball (`dist/utils/url.js` loaded directly): an `app/` tree with `/`, `/admin`, `/admin/login`, `/guestbook`, `/post/[slug]`, `/(group)/about`, `/docs/[...rest]` produced patterns `^\/$`, `^\/admin$`, `^\/admin\/login$`, `^\/guestbook$`, `^\/post\/((?!.+?\..+?).*?)$`, `^\/about$`, `^\/docs\/…$`; `normalizeURL` turned `/admin` into `/admin/`; only `/`, `/post/abc`, and `/docs/a/b` matched. The same day, `eslint-config-next` 16.3.8 in a field project flagged `<a href="/">` (exit 1) and passed `/admin`, `/admin/login`, `/guestbook`. The grep gate above printed all 4 known-bad lines and 0 of 5 known-good lines
