# Knowledge flush — 4 insight(s) (3 pages; two queue rows were the same lesson)

Queue rows claimed by this run: `c84a501fdfc4637c` (eslint rule), `7a9afd1eae7809f1` + `65299b5a2504f128` (tsx top-level await, English + Korean duplicate), `1366b511a1affcc5` (Next.js Server Action refresh). All harvested 2026-10-12 from linkly-invitation task worktrees (t4c / t4d / t4e).

## Verified best-practice

### 1. `@next/next/no-html-link-for-pages` misses static App Router routes → `verified`

Claim: on `@next/eslint-plugin-next` 16.3.8 (and earlier) the rule flags `<a href="/">` and dynamic app routes only; a static app route such as `/admin` is never reported, because the app-route patterns are built with `normalizeAppPath` (no trailing slash, `^/admin$`) while every href is passed through `normalizeURL`, which appends a slash (`/admin/`).

Sources checked:
- `packages/eslint-plugin-next/src/utils/url.ts` at tag v16.3.8 (read through `gh api …?ref=v16.3.8`): L69–L80 `normalizeURL` (`url.endsWith('/') ? url : url + '/'`), L148 Pages list `^${normalizeURL(url)}$`, L169 App list `^${normalizeAppPath(url)}$`.
- `src/rules/no-html-link-for-pages.ts` at v16.3.8: L149 `normalizeURL(href.value.value)`, L156 `foundUrl.test(normalizeURL(hrefPath))`.
- Canary `url.ts` still has the same two wrappers (L148 / L169), so the gap is unfixed upstream.
- Open upstream PRs https://github.com/vercel/next.js/pull/97557 (2026-08-19, "flag `<a>` links to static App Router routes", describes exactly this mismatch) and https://github.com/vercel/next.js/pull/94556 (2026-06-08, names "`normalizeAppPath` omitted trailing slashes for static app routes"); issue #53473 for the `pageExtensions` gap.
- https://nextjs.org/docs/messages/no-html-link-for-pages resolves (HTTP 200).

How verified: downloaded the published `@next/eslint-plugin-next@16.3.8` tarball into the project scratch dir and called `getUrlFromAppDirectory` + `normalizeURL` from `dist/utils/url.js` directly against a synthetic `app/` tree (`/`, `/admin`, `/admin/login`, `/guestbook`, `/post/[slug]`, `/(group)/about`, `/docs/[...rest]`). Result: only `/`, `/post/abc`, `/docs/a/b` match; `/admin`, `/admin/login`, `/guestbook`, `/about` do not (static routes), including `/admin/` written with a slash. The harvested session's own probe (`eslint-config-next` 16.3.8: `href="/"` exit 1, the three static routes pass) agrees. The replacement grep gate on the page was run against a known-bad file (4 of 4 lines reported) and a known-good file (0 of 5 reported) before being written down.

### 2. tsx + top-level `await` in a package without `"type": "module"` → `verified`

Claim: tsx compiles `.ts` as CommonJS when the nearest `package.json` has no `"type"`, and esbuild refuses top-level `await` in `cjs` output; save the script as `.mts`, wrap the body in `async function main()`, or set `"type": "module"`. tsconfig `module` does not change the decision.

Sources checked:
- https://esbuild.github.io/content-types/#javascript — "bundling code containing top-level await is only supported when the output format is set to esm" (fetched, quote confirmed).
- https://nodejs.org/api/typescript.html — ".mts files will always be run as ES modules", ".cts … CommonJS", `.ts` follows `package.json` `"type"` (read from `nodejs/node` `doc/api/typescript.md` L129–L132; page HTTP 200).
- tsx docs `docs/typescript.md` "Compiler limitations" — "tsx uses esbuild to compile TypeScript and ESM, so it shares some of the same limitations" (raw file read).
- https://github.com/privatenumber/tsx/issues/488 (closed; maintainer answer points to the README and esbuild's JavaScript caveats), #552 (closed, node_modules variant), #849 (open, `tsx -e` variant, mentioned only as an edge).

How verified: reproduction in linkly-invitation (tsx 4.23.15, Node 26.7.0, no `"type"`, tsconfig `"module": "esnext"` / `"moduleResolution": "bundler"`): `tla.ts` → exit 1 with `ERROR: Top-level await is currently not supported with the "cjs" output format`; identical `tla.mts` → `TLA_OK 2`, exit 0; `.ts` with `async function main()` → `MAIN_OK 3`, exit 0. Scratch files removed in the same step.

### 3. Next.js Server Action: current-route refresh vs `revalidatePath` of another path → `verified`

Claim: on Next.js 16.3.8 any `revalidatePath`/`revalidateTag` without a cache-life profile sets `pathWasRevalidated = ActionDidRevalidateStaticAndDynamic` regardless of path, so the action response re-renders the current route; the docs call this temporary and the source carries `// TODO: only revalidate if the path matches`. When the current page must refresh no matter what was revalidated, call `refresh()` from `next/cache` (16.0.0+), and pin the behaviour with a browser check that reads the DOM before any reload.

Sources checked:
- https://nextjs.org/docs/app/api-reference/functions/revalidatePath (docs version 16.3.8) — Good to know: "Updates the UI immediately (if viewing the affected path). Currently, it also causes all previously visited pages to refresh … This behavior is temporary and will be updated in the future to apply only to the specific path."
- https://nextjs.org/docs/app/api-reference/functions/refresh — "refresh allows you to refresh the client router from within a Server Action"; only callable in Server Actions.
- `revalidate.ts` at v16.3.8: L73–L91 `refresh()` (throws outside the action phase, sets `ActionDidRevalidateDynamicOnly`), L255–L256 the TODO and `ActionDidRevalidate` assignment; at v15.5.0 the site sets a boolean and no `refresh` export exists; at v16.0.0 `export function refresh()` is at L60.
- `action-handler.ts` at v16.3.8 L1410–L1412 (`skipPageRendering ||= … undefined || ActionDidNotRevalidate`), L197–L202 (header `x-action-revalidated`).
- `server-action-reducer.ts` at v16.3.8 L206–L207 (both kinds accepted), L364–L365 (`invalidateEntirePrefetchCache` only for static-and-dynamic).

How verified: the same lines were read from the installed `node_modules/next/dist` (16.3.8) in linkly-invitation — `revalidate.js:70-84`, `:221-222`; `action-handler.js:990`; `server-action-reducer.js:129`, `:233` — and the tag-pinned GitHub sources above were fetched with `gh api …?ref=v16.3.8|v16.0.0|v15.5.0` to confirm line numbers and the version the export appeared in. The harvested session's field case (`/admin/photos` refreshed after `revalidatePath('/')`) matches the mechanism.

## Existing-layer check

Pages read: platforms-toolchains-typescript-6-global-types, platforms-toolchains-nextjs-16-build-output-and-tsconfig-rewrite, platforms-toolchains-flag-availability-at-the-execution-site, platforms-toolchains-self-import-inside-a-workspace-package, platforms-toolchains-agent-files-written-by-next-dev, platforms-processes-sentinel-driven-repl-payloads, infrastructure-ci-cd-changed-files-only-gates, frontend-design-design-system-lint-gate-for-agents, testing-quality-checks-that-cannot-pass, testing-quality-tests-that-cannot-fail, testing-quality-harness-reverse-controls, testing-quality-gate-parsing-vs-command-execution, frontend-data-fetching-query-key-prefix-invalidation, frontend-data-fetching-async-ui-states

Also read: `INDEX.md`, `wiki/frontend/index.md`, `wiki/platforms/index.md`, `wiki/infrastructure/index.md`, `wiki/backend/index.md`, `wiki/backend/node/index.md`, `templates/page.md`, `AGENTS.md` (category rules).

Keyword sweep over `wiki/` (`no-html-link-for-pages|top-level await|top-level-await|\.mts\b|revalidatePath|pathWasRevalidated`): 1 file, `platforms-processes-sentinel-driven-repl-payloads` (mentions top-level `await` inside a REPL payload — a different mechanism; linked as related, not merged). `wiki_search` (k=5) for each of the three trigger sentences returned no page describing the same situation (top hits: mobile-navigation-test-files-in-expo-router-app-directory, platforms-toolchains-self-import-inside-a-workspace-package, platforms-toolchains-agent-files-written-by-next-dev).

Overlaps / merges: none of the three triggers exists → 3 new pages. The two tsx rows (`7a9afd1eae7809f1`, `65299b5a2504f128`) describe the same situation and directive in two languages; merged into one page. No conflicts with an existing directive.

Related links added both ways:
- A (eslint) ↔ infrastructure-ci-cd-changed-files-only-gates, testing-quality-checks-that-cannot-pass, platforms-toolchains-flag-availability-at-the-execution-site, frontend-design-design-system-lint-gate-for-agents, platforms-toolchains-nextjs-16-build-output-and-tsconfig-rewrite
- B (tsx) ↔ platforms-toolchains-typescript-6-global-types, platforms-processes-sentinel-driven-repl-payloads, platforms-toolchains-self-import-inside-a-workspace-package
- C (refresh) ↔ frontend-data-fetching-query-key-prefix-invalidation, frontend-data-fetching-async-ui-states, platforms-toolchains-flag-availability-at-the-execution-site

## Open-PR check

Open `knowledge/*` heads listed with `gh pr list --search "head:knowledge/"`: #273 (`…-20261011-235540`), #272 (`…-223623`), #271 (`…-213648`), #270 (`…-193253`), #269 (`…-022522`), #268 (`…-002014`), #266 (`…-20261010-021455`), #265 (`…-20261009-222812`). Each head was fetched and `git diff origin/main origin/<head> -- wiki/` grepped for the same keyword set plus `server action|next/link|eslint-config-next|tsx `.

- #269 adds `wiki/frontend/rendering/request-time-data-in-a-nextjs-page.md` (route-segment `revalidate`/`dynamic` config under Cache Components). Different trigger from candidate 3 (that page is about request-time reads in a page; this one is about the action response after a write). Verdict for candidate 3: **new**. A related-link to that page is deferred until #269 merges (linking to a page absent from `main` would be a broken link in this PR).
- #270 adds `wiki/platforms/toolchains/agent-files-written-by-next-dev.md` — already on `main` (merged content); no overlap with any candidate.
- No other open head touches these triggers.

Per-candidate verdicts: `c84a501fdfc4637c` **new**; `7a9afd1eae7809f1` **new** (merged with its sibling row below); `65299b5a2504f128` **drop as in-run duplicate** (same lesson as `7a9afd1eae7809f1`, folded into the same page, not a separate page); `1366b511a1affcc5` **new**.

## Routing decision

| Candidate | Target | Why this category |
|-----------|--------|-------------------|
| `c84a501fdfc4637c` eslint rule | `platforms/toolchains/no-html-link-for-pages-misses-app-router-routes.md` | The lesson is about what a pinned lint toolchain actually checks, not about UI code; the other Next.js tooling pages (`nextjs-16-build-output-and-tsconfig-rewrite`, `agent-files-written-by-next-dev`) already live in `platforms/toolchains`. `frontend` has no lint/routing category, and `frontend/design`'s lint page is design-system specific |
| `7a9afd1eae7809f1` + `65299b5a2504f128` tsx | `platforms/toolchains/tsx-top-level-await-without-type-module.md` | Script-runner module-format behaviour across a toolchain (tsx + esbuild + Node's extension rule), next to `typescript-6-global-types` and `self-import-inside-a-workspace-package`. The rows were harvested under `infrastructure` and `backend`; neither index has a script-runner category and `backend/node` is for service code |
| `1366b511a1affcc5` Server Action refresh | `frontend/data-fetching/server-action-refresh-of-the-current-route.md` | In-UI data refresh after a mutation is this category's subject (`query-key-prefix-invalidation`, `async-ui-states`); the directive governs what the page does after a write, with Next.js mechanics as the evidence |

No new category. `INDEX.md` frontend and platforms rows were extended with one routing phrase each; domain `index.md` rows and `log.md` entries added.

## Local-layer candidates

none — every candidate's directive holds for any Next.js / tsx project; the harvested field evidence (linkly-invitation routes, `/admin/photos`) appears only as a dated reproduction note, not as a directive.
