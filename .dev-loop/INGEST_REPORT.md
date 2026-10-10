# Knowledge flush — 4 insight(s) + 7 plan-gap rows

**5 new pages, 2 amended pages, 3 domain indexes, 5 back-links, 1 new category (`frontend/browser-apis`).** All 4 harvested insights were verified and ingested (2 new pages, 2 merges). The 7 wiki-plan `[no-wiki]` plan-gap rows from linkly-invitation (t5, t7) are retired as local-layer; 3 of them also carried a platform gotcha with primary sources, which became the 3 other new pages.

Claimed 11 queue rows (run `20261011-022327-727`): `01498dcaf854bc1a`, `1cca7f010c2aa001`, `d9102368d6df90ca`, `ba95e8579459d1b4` (session insights) and `f7b02fb55879f640`, `2fa46092b7786876`, `d1ca050e2a6d0dc0`, `5312101035ca2b92`, `12c2385107e9bc19`, `3a3a0047f000d3a0`, `ef33a29c5e6a7713` (plan gaps).

## Verified best-practice

Every quote below was re-fetched by the coordinator, and every reproduction was re-run by the coordinator after the research agents reported.

| # | Claim | Sources checked | How verified | Confidence |
|---|---|---|---|---|
| `01498dcaf854bc1a` | A `pull`-flag probe on a request body needs `{ highWaterMark: 0 }` or `type: 'bytes'`; a stream with no strategy pulls once after construction | Streams Standard (constructor `ExtractHighWaterMark(strategy, 1)` / bytes `0`, `SetUpReadableStreamDefaultController`, `ReadableStreamDefaultControllerShouldCallPull`, `ReadableStreamFromIterable` with 0, `ReadableStreamDefaultTee`), Fetch Standard (`bodyUsed`) | Node 26.7.0 scripts: unread `Request` body no strategy `pulled=true`, `highWaterMark: 0` and bytes `false`; positive controls true. New edge findings: `clone()`, `tee()`, `pipeThrough()` pull; `cancel()` sets `bodyUsed` without a pull | verified |
| `1cca7f010c2aa001` | Positive control for a pooled DB limit counter: seed to limit − 1 and assert exactly 1 success | node-postgres pool docs (`max` 10, FIFO queue "until a client becomes available"), PostgreSQL Read Committed, `pg_advisory_xact_lock` | `postgres:18.6-alpine` in Docker, 13 concurrent reservations, pool 10, limit 10. Seeded: locked 1 in 20/20, unlocked 5–10 in 20/20. **Correction:** the candidate said the empty-store race is invisible; measured, it is timing-dependent — unlocked read exactly 10 in 2 of 30 runs locally and in 10 of 10 originating runs. A `pg_sleep(0.05)` between count and insert did not help (exactly 10 in 19 of 30). The page states the measured mechanism | verified |
| `d9102368d6df90ca` | Under jsdom, deleting `setSelectionRange` after `select()` is an environment-equivalent mutant; mutate the argument or delete both, and capture the selection inside the `execCommand` stub | jsdom 30.1.2 `HTMLTextAreaElement-impl.js` `select()`; HTML `select()` steps ("Set the selection range with 0 and infinity"); WebKit bug 193758; WebKit Async Clipboard post (legacy example uses `setSelectionRange`) | jsdom 30.1.2 script, 5 variants: (0,19) ×3, (0,18), (19,19); jsdom has no `document.execCommand` (TypeError) and no `navigator.clipboard` | verified |
| `ba95e8579459d1b4` | Korean bigram dedupe: scope by section polarity, negation markers present on one side only mean different lines, short lines exact match only | QAGS (Wang et al., ACL 2020) negation example; 표준국어대사전 entries for 안2, 못4, 없다, 않다, 불-12, 비-30, 무-10, 미-11 and 7 non-negating look-alikes | Computed: 0.6 and 0.8 come only from the overlap coefficient with whitespace removed; `가능` vs `유연근무 가능` = 1.0 (why short lines need exact match); NFC vs NFD of identical text = 0. Added: at threshold 0.6 a 3-bigram line still merges after one changed bigram (0.67) | verified |
| `d1ca050e2a6d0dc0` (general part) | Clipboard copy from a tap: `writeText` before any `await`, a synchronous `execCommand` fallback, failure UI | WebKit Async Clipboard post; MDN Clipboard API and `execCommand`; W3C clipboard-apis IDL `[SecureContext]`; HTML transient activation; WebKit bug 193758 and changeset 251387; CSS-Tricks (secondary, 16px zoom) | Playwright 1.64.0 + Chromium 156: `http://127.0.0.1` has `navigator.clipboard`, `http://<LAN IP>` does not (`isSecureContext` false) | verified (16px and readonly-textarea rows labeled secondary / input-only) |
| `f7b02fb55879f640` (general part) | Next.js page reading a DB: `connection()` or `force-dynamic`; under Cache Components, `<Suspense>` + `await io()` (`connection()` only when rendering must wait for a real request); keep module scope free of env throws | next 16.3.8 bundled docs (glossary:177, caching-without-cache-components:97, connection:6/82, io:83/87/109, migrating-to-cache-components:76, route-segment-config version history, building:59/61, unstable_noStore:7/46, caching:99, cacheLife:73); nextjs.org pages | 10 `next build` variants. Run twice (agent and coordinator), identical: no config → prerender error; force-dynamic and `connection()` → `ƒ /`; module-scope throw → "Failed to collect configuration"; Cache Components + `dynamic` → build error; Suspense + `connection()` → `◐ /`; Cache Components alone → prerender error. Run once (coordinator, after review): Suspense + `await io()` → `◐ /`; Suspense with a read that throws before any I/O → prerender error; Suspense with a read that awaits a 50 ms timer first → `◐ /` | verified |
| `12c2385107e9bc19` (general part) | Photo downscale: EXIF via `from-image`, target from the Claude tier's edge and visual-token limits, check `blob.type` | HTML spec (ImageBitmapOptions, toBlob serialization); MDN createImageBitmap, toBlob, ImageBitmap.close, imageSmoothingQuality; BCD JSON; Anthropic vision and vision-coordinates docs (fetched 2026-10-11) with their reference implementation; WebKit CanvasBase.cpp and bug 271002; shkspr.mobi (secondary, HEIC) | Ran Anthropic's reference `resized_size`: 4032×3024 → 1270×952 standard, 2212×1659 high-res; a 1568×1176 upload is resized again to 1270×952 on standard-tier models. Chromium 156: `toBlob('image/heic')` → PNG, 0×0 canvas → null | verified (`verified_model: claude-opus-5-5`) |

Not ingested anywhere in the bundled wiki: `2fa46092b7786876` (the `supertoss://send` link has no Toss-published spec; the plan's own research found only community sources), `5312101035ca2b92`, `3a3a0047f000d3a0`, `ef33a29c5e6a7713` (design choices with no transferable directive).

## Existing-layer check

`wiki_search` (k=5) per trigger; the page bodies listed below were opened ("When this applies" for every hit):

| Candidate | Top-5 hits | Same situation? |
|---|---|---|
| pull probe | tests-that-cannot-fail, write-time-limit-guards, masking-verification, coerced-enum-defaults-in-kotlinx-serialization, write-path-assertions | No → new page |
| lock counter | proving-a-critical-section-is-lock-protected, distributed-locks (×2), isolation-level-selection, shared-run-state | Yes, the first → merged as step 6 |
| jsdom select | custom-property-values-read-from-script, dynamic-file-input-uploads-in-headless-chromium (×2), spec-artifact-checks, fake-intersection-observer-for-viewport-animations | No → merged as an edge row into surviving-mutant-equivalence-triage (the triage owner for a surviving mutant) |
| Korean dedupe | quantitative-claims-in-a-published-document, model-coupled-guidance-aging-detector, exploratory-sessions, unicode-text-matching, word-level-union-merge-reassembly | No → new page |
| clipboard | dropzone-copy-without-drop-handlers, hook-input-fields-from-the-reference, suppression-state-and-delivery-failure, heredoc-body-expansion-with-backtick-prose, non-interactive-cli-invocation | No → new page |
| Next.js | agent-files-written-by-next-dev, prisma-7-config-env-and-generated-client, context-window-budget, test-files-in-expo-router-app-directory, call-counts-under-render-retries | No → new page |
| downscale | bundle-and-assets, html-in-canvas, element-crop-screenshots, responsive-layout (×2) | No → new page |

Pages read: testing-quality-proving-a-critical-section-is-lock-protected, testing-quality-surviving-mutant-equivalence-triage, infrastructure-agent-orchestration-escape-hatch-uses-as-a-knowledge-gap-signal, testing-quality-tests-that-cannot-fail, infrastructure-ci-cd-write-time-limit-guards, security-data-masking-verification, backend-java-kotlin-coerced-enum-defaults-in-kotlinx-serialization, testing-quality-write-path-assertions, backend-common-concurrency-distributed-locks, databases-transactions-isolation-level-selection, infrastructure-agent-orchestration-shared-run-state, frontend-design-custom-property-values-read-from-script, testing-e2e-dynamic-file-input-uploads-in-headless-chromium, testing-quality-spec-artifact-checks, testing-mocking-fake-intersection-observer-for-viewport-animations, qa-deliverables-quantitative-claims-in-a-published-document, qa-document-verification-model-coupled-guidance-aging-detector, qa-exploratory-exploratory-sessions, platforms-environment-unicode-text-matching, infrastructure-agent-orchestration-word-level-union-merge-reassembly, frontend-forms-dropzone-copy-without-drop-handlers, platforms-tools-hook-input-fields-from-the-reference, infrastructure-observability-suppression-state-and-delivery-failure, platforms-shells-heredoc-body-expansion-with-backtick-prose, platforms-processes-non-interactive-cli-invocation, platforms-toolchains-agent-files-written-by-next-dev, backend-common-orm-prisma-7-config-env-and-generated-client, backend-common-llm-context-window-budget, mobile-navigation-test-files-in-expo-router-app-directory, testing-mocking-call-counts-under-render-retries, frontend-performance-bundle-and-assets, frontend-design-html-in-canvas, qa-environments-element-crop-screenshots, frontend-design-responsive-layout, testing-mocking-what-to-mock, backend-common-llm-completion-response-validation, mobile-security-sensitive-data-on-device, infrastructure-agent-orchestration-inherited-lock-ownership-in-a-spawned-session

- **Merged:** `testing-quality-proving-a-critical-section-is-lock-protected` (trigger widened; step 6 with the measured table; 2 edge rows; 1 Instead-of row; 5 sources; `applies_to` + postgresql; `last_verified` 2026-10-11; 71 → 98 body lines). `testing-quality-surviving-mutant-equivalence-triage` (1 edge row + 1 source line; the page sits at 119 of 120 body lines, so the trigger text stayed unchanged and the index row carries the jsdom trigger).
- **Conflicts:** none flagged. Step 2 of the lock page (an injected delay widens the window) is about in-memory read-modify-write; step 6 records that for a pooled database counter the delay did not substitute for seeding — condition-scoped, stated in step 6, not a contradiction.
- **Related links both ways:** lock page ↔ isolation-level-selection; Korean dedupe ↔ unicode-text-matching and completion-response-validation; Next.js page ↔ prisma-7-config-env-and-generated-client; downscale ↔ dropzone-copy-without-drop-handlers; clipboard ↔ surviving-mutant-equivalence-triage. One way only: pull probe → tests-that-cannot-fail and what-to-mock, because open PR #268 rewrites both pages' `related:` lines.
- **Checks on this branch:** `node scripts/wiki-structure-checks.js wiki` → `pages: 431, indexes: 13, findings: 0` (baseline on the untouched branch: 426 pages, 0 findings); `node scripts/wiki-lint-prohibitions.js wiki` → `violations: 0` (baseline 0); every inline `[page-id]` link in the changed wiki files resolves (each file's distinct `[domain-…]` tokens, 24 in total across the 15 files, checked against all 431 page ids); every changed page is at or under 120 body lines. `scripts/wiki-lint-model-era.js` (report-only) lists the downscale page because its default current set is `opus-4`/`fable-5` and the page carries `verified_model: claude-opus-5-5`.

## Open-PR check

Open heads listed with `gh pr list --repo choiyounggi/dev-loop --state open --search "head:knowledge/"`; each fetched and diffed against `origin/main` on `wiki/`, `INDEX.md` and `log.md`:

| PR / head | What it changes | Overlap with this flush | Verdict |
|---|---|---|---|
| #268 `knowledge/choiyounggi-20261011-002014` | New `testing/mocking/proving-no-file-was-written`, `backend/common/integrations/cutting-scraped-text-at-a-noise-marker`; related lines of tests-that-cannot-fail and what-to-mock; a testing-index row after line 106 | Sibling of the pull probe (proving a negative), but a different mechanism (fs mocks vs stream pull timing); scraped-text noise cut is a different trigger from the Korean dedupe | new (all candidates) |
| #266 `knowledge/choiyounggi-20261010-021455` | New `backend/node/async/request-body-reader-cancel` (cancel hangs when a deadline wins) and 3 other pages | Same object (a request body) but a different trigger — cancelling under a deadline vs probing whether a read happened | new |
| #265 `knowledge/choiyounggi-20261009-222812` | Wrapped grep, review diff base, frontmatter quotes, GITHUB_TOKEN chaining, blind LLM judges; INDEX.md rows 15/17/19/22 | No trigger overlap | new |

No fold and no drop. Avoided collisions: `INDEX.md` is unchanged (#265 rewrites the rows next to frontend and testing); the new testing-index row sits after `captured-call-arguments`, away from #268's insertion; no page edited here is edited by an open PR. Expected textual conflicts: `log.md`, where every flush appends at the end — keep both entries; and `.dev-loop/INGEST_REPORT.md`, which #265, #266 and #268 also rewrite — keep the report of the PR being merged. After #266 and #268 merge, link the pull-probe page with `backend-node-async-request-body-reader-cancel` and `testing-mocking-proving-no-file-was-written`.

## Routing decision

| Candidate | Layer | Target |
|---|---|---|
| `01498dcaf854bc1a` | bundled | new `testing/mocking/pull-probe-for-an-unread-request-body` — the probe stream is a test double |
| `1cca7f010c2aa001` | bundled | merged into `testing/quality/proving-a-critical-section-is-lock-protected` |
| `d9102368d6df90ca` | bundled | edge row in `testing/quality/surviving-mutant-equivalence-triage`, plus a testing row in the clipboard page that links to it |
| `ba95e8579459d1b4` | bundled | new `backend/common/llm/korean-summary-line-dedupe-by-bigram-overlap` — post-processing of model-written summaries |
| `d1ca050e2a6d0dc0` | local + bundled | general part → new `frontend/browser-apis/copying-text-from-a-tap` |
| `f7b02fb55879f640` | local + bundled | general part → new `frontend/rendering/request-time-data-in-a-nextjs-page` (server render mode belongs to rendering; the category so far held client render cost only) |
| `12c2385107e9bc19` | local + bundled | general part → new `frontend/browser-apis/downscaling-a-photo-before-upload` |
| `2fa46092b7786876`, `5312101035ca2b92`, `3a3a0047f000d3a0`, `ef33a29c5e6a7713` | local only | see Local-layer candidates |

**New category `frontend/browser-apis`:** the existing frontend categories cover state, structure, rendering, data fetching, performance, forms (validation and upload controls), security (XSS-safe output), auth, agent interfaces, accessibility and design. None covers calling Web APIs whose availability depends on a secure context, user activation, or the engine's encoder support. Both pages in it are about that.

## Independent review

Two fresh-context reviewers ran on the whole change set before the commit. The adversarial one re-ran every script, the Next.js builds and a Postgres batch, and checked every quote against the saved and the live sources; the format one checked AGENTS.md "Page format", the template, the indexes and this report. Both returned PASS-WITH-FIXES, and every finding was applied:

| Reviewer | Finding | Resolution |
|---|---|---|
| Format (major) | Next.js page: the `io()` and `"use cache"` edge rows named no API and pulled against step 1 | Read the bundled `io.md` ("Prefer `io()` over `connection()`", added in 16.3.0), built 3 more variants (Suspense + `io()` → `◐ /`; a read that throws before any I/O → prerender error; a read that awaits I/O first → `◐ /`), rewrote step 1's Cache Components row around `io()` with `connection()` for request-bound rendering, and named `cacheLife` in the `"use cache"` row |
| Adversarial | Lock page: the locked column's 20/20 and 10/10 had no per-run list | The sources state the batches ("all 20 runs of two batches", "all 10 runs of one batch") |
| Adversarial | Korean page: the NFC/NFD number named no script, and 6 of 7 look-alike words were not in the saved dictionary pages | The source names the one-off `node -e` computation; 불꽃, 불가리아, 비용, 미래, 못자리, 어처구니없다 were each fetched from 표준국어대사전 (none negates) |
| Adversarial | The QAGS quote reads "nn-gram" in ar5iv's HTML | A note on the rendering was added |
| Both | "24 inline links" was not reproducible | The counting method is stated |
| Format | Pull probe: the "only the clone is read" row ended in a limit with no action | It now says to assert on the response and side effects |
| Format | Clipboard: decision row 3 contradicted step 3 and predicted `false` | Step 3 names the rejection-callback path; row 3 handles both `true` and `false` |
| Format | Korean: the step-4 example sat outside its own floor; `없다` "at the end of a word" still matched 어처구니없다 | The example now sits in the 3-bigram case that the first edge row covers; `없다` matches as a separate word or through the word list |
| Format | Downscale: a hedge in a directive cell, a limits row with no action, an off-case computer-use row, `verified_model` key order | Rewritten, given an action, removed, and moved after `last_verified` |
| Format | "When this applies" over 4 lines on five pages; "kill-test" wording | All five are 4 lines; "prove the test with mutants … and require red" |
| Format | This section was pending; the `INGEST_REPORT.md` conflict was not named | Filled in; the Open-PR check names it |

Before the fixes, `git status`, `git diff` and the new files were byte-identical to a backup taken before the reviewers started. After the fixes: structure check 0 findings, prohibitions 0 violations, every changed page at or under 120 body lines.

## Local-layer candidates

| Row | Project | Target |
|---|---|---|
| `f7b02fb55879f640` Planning t5: How `/` reads the wedding | linkly-invitation | `wiki-local/frontend/rendering/t5-home-page-request-time-read.md` — run wiki-ingest inside that project |
| `2fa46092b7786876` Planning t5: Toss transfer link | linkly-invitation | `wiki-local/frontend/browser-apis/t5-toss-transfer-link.md` — run wiki-ingest inside that project |
| `d1ca050e2a6d0dc0` Planning t5: Copy routine | linkly-invitation | `wiki-local/frontend/browser-apis/t5-copy-text-routine.md` — run wiki-ingest inside that project |
| `5312101035ca2b92` Planning t5: Parents line | linkly-invitation | `wiki-local/frontend/design/t5-parents-line.md` — run wiki-ingest inside that project |
| `12c2385107e9bc19` Planning t7: Client downscale before upload | linkly-invitation | `wiki-local/frontend/browser-apis/t7-client-downscale.md` — run wiki-ingest inside that project |
| `3a3a0047f000d3a0` Planning t7: Speech-bubble schedule | linkly-invitation | `wiki-local/frontend/rendering/t7-speech-bubble-scheduler.md` — run wiki-ingest inside that project |
| `ef33a29c5e6a7713` Planning t7: Numbers for about 200 guests | linkly-invitation | `wiki-local/frontend/design/t7-plaza-guest-numbers.md` — run wiki-ingest inside that project |

All seven name linkly-invitation's own files (`src/app/page.tsx`, `copy-text.ts`, `downscale.ts`, `bubbles.ts`); they are excluded from this PR and retired from the queue. For the project owner: the t7 decision's 1568 px long edge is resized again to 1270×952 for a 4:3 photo on standard-tier Claude models and uses 2352 of 4784 tokens on high-resolution models (see the downscale page).

## Run notes

- **Lock:** this headless run was spawned by `hooks/auto-flush.sh` with `DEV_LOOP_FLUSH_RUN_ID=20261011-022327-727` in its environment. The skill's step-0 snippet (`skills/knowledge-flush/SKILL.md:36`) generates a fresh id, so the first acquire was refused by the run's own parent (`held 20261011-022327-727 11s`). The run re-acquired under the inherited id (`already-owned`, the re-entrant path `scripts/flush-lock.sh` documents) — the failure `infrastructure-agent-orchestration-inherited-lock-ownership-in-a-spawned-session` describes. A background keeper refreshed the lock every 4 minutes while research ran.

🤖 Generated with [Claude Code](https://claude.com/claude-code)
