# Knowledge flush — 3 insight(s): 1 new page, 2 project-specific plan-gap drops

## Verified best-practice

### 1. `2b99ac7bc23f307f` — custom-property alias tokens read from script under jsdom → **verified**

Claim: `getComputedStyle(el).getPropertyValue('--a')` for `--a: var(--b)` returns the
substituted value in a browser but the literal `var(--b)` under jsdom; the string is
non-empty so an empty-value fallback never fires, and a canvas consumer silently
ignores it.

- **Reproduced** (2026-09-21, jsdom 30.1.0, scratch project, since removed). Printed output of
  `getPropertyValue` on `:root` with
  `--b:#ff0000; --a:var(--b); --c:var(--a); --u:var(--missing); --x:var(--y); --y:var(--x)`:
  `--b "#ff0000"`, `--a "var(--b)"`, `--c "var(--a)"`, `--u "var(--missing)"`,
  `--x "var(--y)"`, undeclared `--none ""`. This matches the candidate's own evidence
  (`--color-go: var(--color-accent)` read back as `var(--color-accent)` in a Vitest jsdom env).
- https://www.w3.org/TR/css-variables-1/ — §2 computed value of `--*`: "specified value with
  variables substituted, or the guaranteed-invalid value"; §2.2 that value "serializes as the
  empty string"; §2.3 every property in a cycle is invalid at computed-value time. This is the
  browser column of the page's table (derived from the spec, not separately measured in a browser).
- https://html.spec.whatwg.org/multipage/canvas.html — `fillStyle`: "Invalid values are
  ignored" (extracted from the fetched spec text), which is why the failure is silent.
- https://github.com/jsdom/jsdom/issues/1895 — "Implement CSS custom properties", state OPEN
  (read via `gh issue view`): jsdom's support is partial.

One sentence in my first draft (that each simulated DOM implements a different subset) had no
source; it was replaced with a statement limited to what was measured (jsdom only).

### 2. `27f30a2498bd57d3` — resolve `expected_page_id` via a frontmatter-id map → **not ingested (project-specific)**

The directive names dev-loop's own id scheme (`<domain>-<category>-<slug>`, `wiki/**/*.md`,
`index.md`) and one eval-case field. No external verification was attempted because it is not
bundled-wiki material; see Local-layer candidates.

### 3. `d6771df1f2a91b34` — default `eval` recall counts only positive cases → **not ingested (project-specific)**

The directive specifies one function's signature (`evaluate(cfg, cases, k)`), one output format
string and this repo's case counts (15 / 35+15). The general kernel (recall = hits over cases
that have a relevant item) is the textbook definition and adds no routable situation; see
Local-layer candidates.

## Existing-layer check

Routed candidate 1 via `INDEX.md` → `wiki/frontend/index.md` (owning artifact: the UI helper),
and checked `wiki/testing/index.md` as the second domain. Whole-wiki grep: `jsdom` / `happy-dom`
→ 0 files; `getPropertyValue|custom propert|var(--` → 1 file (anti-slop-visual-design, directive 4:
declare tokens once and reference `var(--token)` — authoring tokens, not reading them from
script; no overlap, no conflict). `wiki_search` top-5 for the trigger sentence:
frontend-security-xss-safe-rendering (×2), frontend-design-anti-slop-visual-design,
testing-e2e-e2e-stability, backend-common-change-impact-compiler-as-call-site-inventory — none
describes the same situation. Result: **new page**
`wiki/frontend/design/custom-property-values-read-from-script.md`, no merge target.

Related links added both ways: frontend-design-anti-slop-visual-design (token declaration),
frontend-design-html-in-canvas (canvas consumers), testing-mocking-what-to-mock (the Instead-of
row about mocking `getComputedStyle`). `wiki/frontend/index.md` gained the design row; `log.md`
gained the ingest entry.

For candidates 2–3, `wiki_search` on the recall trigger returned
testing-quality-stale-artifact-baselines, databases-indexing-trigram-index-short-patterns,
qa-process-completion-claims, testing-quality-generated-sql-property-assertions,
databases-indexing-index-write-cost — no page on retrieval-eval scoring; the plan's own
grounding page testing-quality-harness-reverse-controls covers harness discrimination, not
denominators.

Pages read: frontend-design-anti-slop-visual-design, frontend-design-html-in-canvas, testing-mocking-what-to-mock, testing-quality-harness-reverse-controls

Checks run in the checkout: `node scripts/wiki-lint-prohibitions.js` → `directives: 75,
compliant: 75, violations: 0` (count unchanged, matches the bats pin); new page body = 77 lines;
banned-qualifier grep on the new page → 0 hits; `bats tests/wiki-lint-prohibitions.bats
tests/wiki-structure-checks.bats tests/wiki-lint-score.bats` → 35 ok, 0 not ok.

## Open-PR check

Listed 18 open `knowledge/*` heads (#179, #180, #181, #182, #183, #185, #186, #187, #188, #189,
#190, #191, #205, #207, #208, #209, #210, #212). Fetched each and searched
`git diff origin/main origin/<head> -- wiki/`:

- `jsdom|getPropertyValue|happy-dom` → 0 matches in all 18 heads. Candidate 1: **new**.
- `recall@|negative cases|denominator|frontmatter id|hyphenated id` → two unrelated
  "denominator" hits (#185 benchmark-relative grade, #182 vendor benchmark claims), neither about
  retrieval-eval scoring or id resolution. Candidates 2–3: no overlap; **drop** as
  project-specific (not as pending duplicates).

## Routing decision

| Candidate | Decision |
|-----------|----------|
| `2b99ac7bc23f307f` | **new page** → `frontend/design/custom-property-values-read-from-script` (id `frontend-design-custom-property-values-read-from-script`). Existing category `design` fits: it already owns token declaration and canvas effect layers; the artifact changed is the UI helper, so frontend owns it over testing. No new category. |
| `27f30a2498bd57d3` | excluded — project-specific (layer test) |
| `d6771df1f2a91b34` | excluded — project-specific (layer test) |

## Local-layer candidates

Both belong to the `dev-loop` project (run wiki-ingest inside that project; it has no
`wiki-local/` yet, and the decisions are already recorded in
`plans/t2-eval-calibration/design.md` D3/D4 and implemented in commit da64d40):

- `27f30a2498bd57d3` → `wiki-local/testing/quality/eval-case-page-id-resolution.md` — resolve
  `expected_page_id` through a map built from every page's frontmatter `id:` line; categories
  such as `query-optimization` contain hyphens, so the id string cannot be split into a path.
- `d6771df1f2a91b34` → `wiki-local/testing/quality/eval-recall-over-positive-cases.md` — the
  default `eval` recall counts a case only when `expected_page_id` is truthy; negatives stay out
  of `hits`/`total` and the output line format is unchanged.
