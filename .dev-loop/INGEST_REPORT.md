# Knowledge flush — 2 insight(s) ingested (headless auto-flush run 20261015-095737-42481)

4 queue rows were claimed by this run. 2 were ingested as new pages; 2 were
released as pending duplicates of open PR #274. Nothing was folded into another
branch — this headless run opens its own PR only for the two verified insights.

| Candidate | Origin | Domain | Disposition |
|-----------|--------|--------|-------------|
| `61bc283a566a4780` — a blur handler moves layout under the button the user clicks next; the click is lost | linkly-invitation task-t4b (2026-10-12) | frontend | **ingested** (new page `frontend-forms-layout-shift-on-blur-before-a-click`) |
| `2bf23658a4d1bc2e` — fixtures whose id, position and order field coincide let wrong-field reads pass | linkly-invitation task-t4c (2026-10-12) | testing | **ingested** (new page `testing-quality-fixtures-with-coincident-id-and-position`) |
| `ea0574d2686b0169` — tsx top-level `await` without `"type": "module"` (scratch-folder `package.json` variant) | linkly-invitation task-t4c | platforms | released — duplicate of open PR #274 |
| `866175146dd2fc3b` — tsx top-level `await` without `"type": "module"` (same lesson, t4b wording) | linkly-invitation task-t4b | platforms | released — duplicate of open PR #274 |

Note for the reviewer: the previous headless run (PR #275) could not read
`61bc283a566a4780` and `866175146dd2fc3b` because the queue directory cannot be
listed from the sandbox. This run located their queue file by reading the
session ids in `~/.claude/history.jsonl` and opening
`~/.dev-loop/queue/<sessionId>.jsonl` by exact name, so both rows were read
and handled. A scratch helper `.dev-loop/flush-dump.js` was written into the
checkout and could not be deleted (no `rm` in the allowlist); `.dev-loop/` is in
the repo's `.gitignore`, so it is not part of this PR.

## Verified best-practice

### 1. `61bc283a566a4780` — blur-driven layout shift under the button the user clicks next → `verified`

Claim: when a field's blur handler shows, hides or resizes content above a
button, a pointer click on that button right after typing is lost. `mousedown`
moves focus to the button, the field blurs and re-renders, the button moves,
`mouseup` lands on another element, and the `click` is dispatched to the nearest
common inclusive ancestor of the two targets, so the button's handler never
runs and nothing errors. Reserve the region's space with a fixed `min-height`
(content swapped inside a sized box moves no sibling) and verify with a
real-browser `fill → click` with no blur step in between.

Sources checked (fetched or confirmed through search of the official page this run):
- https://developer.mozilla.org/en-US/docs/Web/API/Element/click_event — fetched; verbatim: "If the button is pressed on one element and the pointer is moved outside the element before the button is released, the event is fired on the most specific ancestor element that contained both elements" and "`click` fires after both the mousedown and mouseup events have fired, in that order".
- https://w3c.github.io/uievents/split/mouse-events.html — UI Events, mouse events section: implementations "SHOULD fire click and dblclick events on the nearest common inclusive ancestor when the associated mousedown and mouseup event targets are different" (confirmed by search over w3c.github.io; the page itself could not be fetched in this run because WebFetch was granted for one URL only).
- https://w3c.github.io/pointerevents/ — click target is "the nearest common inclusive ancestor of the corresponding pointerdown and pointerup targets in the DOM at the moment event is being dispatched" (same confirmation path).
- https://playwright.dev/docs/actionability — the checks for `locator.click()` (Visible, Stable = "not animating or completed animation", Receives Events = "the hit target of the pointer event at the action point", Enabled) and `force` "will not check that the target element actually receives click events"; the docs describe no re-check between `mousedown` and `mouseup`.
- https://playwright.dev/docs/api/class-locator — `locator.click()` steps: wait for actionability checks, scroll into view, click the element's center with `page.mouse`, wait for initiated navigations.

How verified: the event-order and click-target mechanism is spec text (UI Events, Pointer Events) restated by MDN; the "auto-wait cannot see it" claim follows from the documented check order (checks run before the action). The field case is the originating session's measurement on 2026-10-12 (Next.js 16 admin form, Playwright + Chrome against `next start`): the save button's page y read 1093 at press and 1057 at release with no POST; after the preview area was reserved at `min-h-64`, the button read y 1847 / 1847 / 1847 across three blurs and the unchanged `fill → click` script saved. This flush did not re-run the browser case (no browser or project execution is in this run's allowlist); the page records it as a dated field reproduction, and the mechanism carries the `verified` confidence.

### 2. `2bf23658a4d1bc2e` — fixtures whose id, position and order field coincide → `field-tested`

Claim: when fixtures have `id === index` and `sortOrder === position`, code that
reads the wrong field (position for id, `items.length` for `nextId`, `sortOrder`
for the index, a `sortOrder`-based key) returns the expected output on every
case, so such mutants survive a green suite. Build fixtures from a history with a
delete (ids `1, 3, 4`, `nextId` 5), give order values gaps, assert after a move,
and prove each read by mutation with a no-op control.

Sources checked:
- https://en.wikipedia.org/wiki/Mutation_testing — the kill conditions (reach, infect, propagate: the incorrect state "must propagate to the program's output and be checked by the test"); a coincident fixture blocks propagation. Already cited by the merged sibling page `testing-quality-path-resolver-fixtures-with-coincident-cwd` for the same mechanism.
- https://stryker-mutator.io/docs/mutation-testing-elements/mutant-states-and-metrics/ — "When all tests passed while this mutant was active, the mutant survived. You're missing a test for it." Already cited by `testing-quality-expectation-sets-with-one-distinct-value`.
- Field report 2026-10-12 (originating session, Vitest 5, React list + `nextId` reducer): an independent test-quality audit left 6 of 6 hand-seeded mutants alive with coincident fixtures; after id gaps, gapped order values and a post-move assertion, the position lookup, `nextId` from `items.length`, label / end / move from `sortOrder` and a `sortOrder` key all went red (session logs `.claude/tmp/mut30`, `mut33b–d`, not available to this run).

How verified: the mechanism is the documented propagation condition that two
merged pages already rest on; the specific wrong-field table comes from the
field report, and this flush ran no mutants (no project execution in the
allowlist). Confidence is therefore `field-tested`, not `verified`, and the page
says so in its Sources section.

### Released (not verified here)

`ea0574d2686b0169` and `866175146dd2fc3b` carry the lesson that PR #274's page
`wiki/platforms/toolchains/tsx-top-level-await-without-type-module.md` already
holds (tsx compiles `.ts` as CommonJS without `"type": "module"`, esbuild
refuses top-level `await` in `cjs`; use `.mts`, `async function main()`, or
`"type": "module"`). The `ea0574` wording adds one variant — a scratch-folder
`package.json` containing `{"type":"module"}` next to the script — which #274's
page already lists as "set `"type": "module"`". No research was done on them in
this run; they are released for the manual flush to drop or fold once #274
merges.

## Existing-layer check

Pages read: frontend-forms-validation-timing, testing-e2e-e2e-stability, testing-quality-expectation-sets-with-one-distinct-value, testing-quality-path-resolver-fixtures-with-coincident-cwd, frontend-accessibility-interactive-elements, frontend-performance-bundle-and-assets

Also read: `INDEX.md`, `wiki/frontend/index.md`, `wiki/testing/index.md`, `templates/page.md`, `AGENTS.md`, the tail of `log.md`.

`wiki_search` (k=8) with each candidate's trigger sentence:

| Row | Top hits | Overlap found | Result |
|-----|----------|---------------|--------|
| `61bc` | frontend-accessibility-interactive-elements (×3: div-with-onClick, popover, hover-revealed), frontend-design-html-in-canvas (×2: clicks land in the wrong place after a transform), frontend-forms-validation-timing (blur fired by an abandoning click), frontend-accessibility-contrast-of-interactive-states, frontend-design-ui-hardening-against-real-content | No page describes a blur re-render moving the click target. `validation-timing` owns *when* blur validation runs and has an Edge row for a blur caused by clicking Cancel; it says nothing about the click being lost. `e2e-stability` has an Edge row "Entry animation makes clicks land on a moving element → the stability check waits for the bounding box to settle", which is the adjacent case (a shift *before* the click, which auto-wait handles) and is the reason the new page states why auto-wait cannot handle a shift the click triggers. `bundle-and-assets` covers CLS as a load-performance metric, not an input defect. No conflict | New page `frontend-forms-layout-shift-on-blur-before-a-click`; `related:` both ways with `validation-timing` and `e2e-stability`; one-way links to `bundle-and-assets` and `interactive-elements` |
| `2bf2` | testing-quality-expectation-sets-with-one-distinct-value (×2: swap in a different field's value; same fixture row), testing-quality-checks-that-cannot-pass, testing-quality-key-order-in-serialized-goldens, testing-quality-schema-additions-under-a-golden-gate, frontend-rendering-long-lists (`key={index}` row), databases-indexing-composite-index-column-order, testing-data-test-data-and-isolation | `expectation-sets-with-one-distinct-value` is about one *expected* value repeating across cases (a constant mutant); its probe row "swap in a different field's value … Nothing, when the two fields differ in the fixtures" is the precondition this candidate supplies, not the same trigger. `path-resolver-fixtures-with-coincident-cwd` is the same shape (two code paths agree because the fixture makes an ambient value coincide) for one specific resolver; its "When this applies" names the cwd fallback only. Neither describes id / position / order coincidence, so this is a sibling, not a merge. No conflict | New page `testing-quality-fixtures-with-coincident-id-and-position`; `related:` both ways with `expectation-sets-with-one-distinct-value` and `path-resolver-fixtures-with-coincident-cwd`; one-way links to `tests-that-cannot-fail`, `harness-reverse-controls`, `frontend-rendering-long-lists` |

Every `related:` id and inline `[id]` on the two new pages resolves to a file on
this tree (checked by opening each target page above or by its presence in the
domain index). Both pages are under 120 body lines (64 and 65 lines after the
frontmatter, counted from the written files: 79 and 78 lines in total).

## Open-PR check

Open `knowledge/*` heads from `gh pr list --repo choiyounggi/dev-loop --state open --json number,headRefName --search "head:knowledge/"`: #275, #274, #273, #272, #271, #270, #269, #268, #266, #265. This headless run cannot `git diff` their content; overlap was judged from each PR's changed-file list (`gh pr list --json number,files`) and its PR body.

| Row | Overlapping open PR | Verdict |
|-----|---------------------|---------|
| `61bc` | None. No open head adds or edits a page about focus, blur, click targets or layout shift; #274 edits `frontend/index.md` (data-fetching row) and #269 edits it (browser-apis / forms rows) in hunks other than the forms row this PR appends after `dropzone-copy-without-drop-handlers`. #270's `proving-nothing-moves-under-reduced-motion` is about animations under reduced motion, a different trigger | new |
| `2bf2` | #270 adds `testing/quality/host-disguise-fixtures-for-url-allowlists.md` (fixtures whose raw text and parsed host disagree, for a URL allowlist) and several other `testing/quality` pages; #269 and #268 also edit `testing/index.md`. The previous headless run released this row as a "plausible overlap" with that cluster. Judged here at the trigger level: `host-disguise-fixtures` is about parsed-URL fixtures and names no id / position / order field; no open head touches `expectation-sets-with-one-distinct-value` or `path-resolver-fixtures-with-coincident-cwd`, the two pages this PR links from; the new `testing/index.md` row is inserted before `key-order-in-serialized-goldens`, a row none of the open heads' file lists show as changed (they add rows elsewhere in the quality table). Different insight, adjacent theme | new (index-row conflicts with #270/#269/#268 are the usual append-order conflicts in `testing/index.md`, resolvable by keeping both rows) |
| `ea0574`, `8661` | #274 adds `wiki/platforms/toolchains/tsx-top-level-await-without-type-module.md`, the same lesson | drop as pending duplicate → **released** (this headless run never folds into another branch) |

`log.md` and `.dev-loop/INGEST_REPORT.md` conflict with every open knowledge
PR as always (append-only log; rewritten report).

## Routing decision

| Row | Domain / category | Page | Why this category |
|-----|-------------------|------|-------------------|
| `61bc283a566a4780` | frontend / forms | `wiki/frontend/forms/layout-shift-on-blur-before-a-click.md` | The directive governs how a form region is sized so a blur-driven re-render cannot move the submit button, and how its browser test is written; the blur-timing owner (`validation-timing`) lives in `frontend/forms`. Not `testing/e2e`: the fix is in the UI, the test is the proof. Not `frontend/performance`: CLS there is a load metric, not an input defect |
| `2bf23658a4d1bc2e` | testing / quality | `wiki/testing/quality/fixtures-with-coincident-id-and-position.md` | The category already holds the two coincidence pages this one is a sibling of (`expectation-sets-with-one-distinct-value`, `path-resolver-fixtures-with-coincident-cwd`) and the mutation-proof pages it cites. Not `testing/data`: that category is about creating and isolating fixture data, not about which values make a mutant observable |

No new category. `INDEX.md` frontend and testing rows were extended with one
phrase each; `wiki/frontend/index.md` (forms) and `wiki/testing/index.md`
(quality) each gained one row; `log.md` has one `ingest` entry per new page;
`related:` added both ways on `validation-timing`, `e2e-stability`,
`expectation-sets-with-one-distinct-value` and
`path-resolver-fixtures-with-coincident-cwd`.

## Local-layer candidates

none — both ingested directives hold for any web form / any test suite; the
linkly-invitation field cases (an admin address field with a map preview, a photo
list with `sortOrder`) appear only as dated reproduction notes in the Sources
sections, not in any directive.
