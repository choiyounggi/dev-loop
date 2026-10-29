# Knowledge flush — 2 insight(s) (headless auto-flush run 20261029-135519-11504)

This run claimed 20 queue rows:

- **3 candidates ingested as 2 insights**: one new page (two candidates merged into it) and one edge row.
- **14 dropped** as project-specific plan-gap rows.
- **3 released** back to pending as plausible duplicates of open PRs.

Nothing was folded into another branch.

| Candidate | Disposition |
|-----------|-------------|
| `8165adcd84df2acc` fidelity checker shares the builder's manifest | **ingested**: new page `testing-quality-checker-sharing-the-builders-input` |
| `d1e6468cdb111e8c` fidelity check takes its ranges from the build ledger; require unit boundaries | **ingested**: merged into the same new page (the unit-boundary row) |
| `9f1d906f64d671ad` a brand-new function's first red is a missing-name error | **ingested**: edge row on `testing-strategy-failing-test-first` |
| `8a67a97c4afd204c`, `f332524447ff2105` | **released**: still pending duplicates of open PRs #299 / #300 (same verdict as the three earlier runs today) |
| `baac78b023efce53` failure-id allowlist gate must also match the cause | **released**: plausible overlap with #300 (`testing/quality/checks-that-cannot-pass.md`) and #304 (done-gate counting) |
| 14 plan-gap rows from linkly task t3 | dropped as project-specific (see Local-layer candidates) |

Unlike runs 20261029-114716-88588 and 20261029-124846-54962, this run found the queue files for `d1e6468cdb111e8c`, `baac78b023efce53` and `9f1d906f64d671ad`, so they were read and judged. It found them by matching session ids from `~/.claude/history.jsonl` to `~/.dev-loop/queue/<sessionId>.jsonl`.

## Verified best-practice

**`8165adcd84df2acc` + `d1e6468cdb111e8c` → a checker that reads the builder's own input (confidence: field-tested).**
- **Claim:** a fidelity checker that replays the builder's manifest or line ranges proves only that the manifest was applied. A wrong range is copied into both, so they agree.
- **Fix:** add a check whose expected value does not come from the manifest. Options: ranges must start and end on unit boundaries, with neighbouring non-boundary lines declared as drops; a ledger-only line check; a byte comparison with independently built siblings; a rebuild from structural markers.
- **Proof:** mutate the shared manifest or ledger itself, and give each mutant an expected set of failing checks.

Sources:
- https://discovery.ucl.ac.uk/1471263/ — Barr et al., "The Oracle Problem in Software Testing: A Survey" (IEEE TSE 2015). An oracle must tell correct behaviour apart from incorrect behaviour.
- https://github.com/kenjudy/pdca-agentic-coding-framework/issues/181 — the rule "where does the expected value come from, and is that source independent of the code under test?" This is already a source of `testing-quality-cross-component-invariant-via-shared-helper`.
- https://pitest.org/quickstart/basic_concepts/ — a surviving mutant was not detected by the covering tests.
- Field cases from one RFC-consolidation project:
  - t72: an auditor shortened a range in both spec and target, and the checker still returned rc=0.
  - t2: a ledger mutant failed only once the boundary check existed.
  - t7: 12 mutants each failed exactly their expected check set.

How verified: one WebSearch on oracle independence returned the Barr survey plus preprints and a blog that make the same point. The preprints and blog are not cited. This headless run has no page fetch, so the survey was read through its search summary. The techniques come from production runs, not an external doc, so the page is **field-tested**, not verified.

**`9f1d906f64d671ad` → missing-name red for a brand-new function (edge row; the page stays verified).**
- **Claim:** when the first red can only be `AttributeError` or an unresolved symbol, add a stub with the final signature that returns a type-correct wrong value, so the red is an assertion failure. If the missing-name red was already accepted, prove the assertions after green with module mutants. Each mutant must redden its owning test.
- **Consistency with the page:** the page's existing row already says an import/name error is "not RED". The new row covers the case where no setup fix exists before the function does.

Sources:
- The page's existing sources: https://newsletter.kentbeck.com/p/canon-tdd and https://github.com/obra/superpowers (verify RED for the expected reason).
- One WebSearch found that TDD skill guides agree: a compile or import error is not a valid red, and a minimal stub makes the test fail on an assertion. One guide disagrees. Those guides are not cited, because they are skill-directory pages.
- Field case: 5 source mutants reddened the new rule's tests (11/4/2/1/1 failures). A module built by hand needed `__file__` set.

Not researched: the 3 released rows and the 14 plan-gap rows.

## Existing-layer check

Pages read: testing-strategy-failing-test-first, testing-quality-cross-component-invariant-via-shared-helper, testing-quality-spec-artifact-checks, qa-document-verification-spec-document-gates

Also read: `wiki/testing/index.md`, `templates/page.md` and the tail of `log.md`. `wiki_search` was not permitted in this run, so routing used the full testing index.

- **Shared-input checker:**
  - `cross-component-invariant-via-shared-helper` covers one helper called twice in a test, not a document checker that reads the build manifest.
  - `spec-artifact-checks` covers coverage vs value checks and one negative control per check, but not where the expected value comes from. It is also at about 118 body lines, so a merge would break the 120-line limit.
  - So this became a new page that links both. Its body is about 65 lines.
- **Missing-name red:** `failing-test-first` owns RED classification, so the case became an edge row there. The page's "When this applies" line, its testing-index "load when" cell and `last_verified` were updated.
- **Dropped run's lessons:** the run 20261028-100340-23911 marked related rows `c9e00eb2a93a55e3`, `b3a7b01998f7d6aa`, `f8a300baed4c34f0` and `bdb042f44f413d06` as ingested. No PR exists for that run (open or closed; `gh pr list --state all`), and its edge rows are not on `main`. The new page restates the shared-ranges lesson of `c9e00eb2a93a55e3` and cites its t72 field case. The other three rows are not recovered by this PR.
- **Back-links:** none added to existing pages, to keep this PR off pages that open PRs might touch.
- **Conflicts:** none.

## Open-PR check

Open `knowledge/*` heads: #309, #308, #307, #306, #305, #304, #301, #300, #299, #298, #293. This run has no git access, so overlap was judged from each PR's changed-file list (`gh pr list --json files`) and the bodies of #307, #308 and #309.

| Candidate | Overlapping open PR | Verdict |
|-----------|---------------------|---------|
| 8165adcd84df2acc + d1e6468cdb111e8c (checker shares builder input) | None by trigger. No open PR adds or edits a page about checker/builder oracle independence. #305 and #308 edit `qa/document-verification/` pages about superseded sections and Korean particles. #293, #300 and #301 edit other `testing/quality/` pages | **new** → ingested |
| 9f1d906f64d671ad (missing-name red) | None. No open PR touches `testing/strategy/failing-test-first.md`. #309 adds `testing/strategy/long-lived-processes-under-bats.md` and edits `calls-that-must-not-block.md`, a different trigger | **new** → ingested |
| baac78b023efce53 (failure-id allowlist gate) | #300 edits `testing/quality/checks-that-cannot-pass.md`, whose trigger covers new-vs-baseline failure-list gates. #304 edits `qa/process/completion-claims.md` about done-gate result counting | **pending duplicate** → released |
| 8a67a97c4afd204c (`grep -q` + SIGPIPE) | #299 (`platforms/tools/search-evidence-from-a-wrapped-grep.md`) | **pending duplicate** → released |
| f332524447ff2105 (gate grep matches its own ledger) | #299, #300 (`testing/quality/checks-that-cannot-pass.md`) | **pending duplicate** → released |
| 14 plan-gap rows | n/a (project-specific) | dropped |

Possible merge conflicts, not duplicate content: `wiki/testing/index.md` (#293, #300, #301 and #309 also edit it) and `log.md` (every open flush PR appends to it).

## Routing decision

- `8165adcd84df2acc` + `d1e6468cdb111e8c` → `testing/quality/checker-sharing-the-builders-input.md`. This is a new page in an existing category. `quality` owns "can this check discriminate" pages, beside `spec-artifact-checks` and `cross-component-invariant-via-shared-helper`. The `qa` hint on d1e6468cdb111e8c was not followed: the lesson is about the check's design, which `testing/quality/spec-artifact-checks` owns, and `qa/document-verification` covers accepting the deliverable.
- `9f1d906f64d671ad` → edge row on `testing/strategy/failing-test-first.md`.
- No new category. Project names, RFC numbers and script names appear only in field-case source lines.

## Local-layer candidates

These 14 rows are excluded from this PR. Each records one wiki-plan Phase B design decision for task t3 of project **linkly** (checkout `shag`, the RFC-0068/RFC-0071 consolidation). To keep any of them, run wiki-ingest inside that project.

| Row | Decision | Target |
|-----|----------|--------|
| 848078b686341fea | how the two new RFCs are produced (pinned build.sh + manifests) | `wiki-local/qa/document-verification/mechanical-spec-consolidation.md` |
| f868362a14d380d7 | source snapshot | `wiki-local/qa/document-verification/mechanical-spec-consolidation.md` |
| 6409709bc7de8005 | RFC-0071 §2 composition | `wiki-local/qa/document-verification/mechanical-spec-consolidation.md` |
| 0eede9eeb197bfe1 | RFC-0068 §Execution Model composition | `wiki-local/qa/document-verification/mechanical-spec-consolidation.md` |
| 2bfada8fcb132df5 | RFC-0068 §Guard composition | `wiki-local/qa/document-verification/mechanical-spec-consolidation.md` |
| e99f07771edc44cd | RFC-0068 §Policy Enforcement composition | `wiki-local/qa/document-verification/mechanical-spec-consolidation.md` |
| fa0741fda15f983b | RFC-0068 timeline C composition | `wiki-local/qa/document-verification/mechanical-spec-consolidation.md` |
| fb6584b057acd049 | sections no updater touched | `wiki-local/qa/document-verification/mechanical-spec-consolidation.md` |
| 48921c6112310078 | RFC-0071 §Examples and §Open Questions | `wiki-local/qa/document-verification/mechanical-spec-consolidation.md` |
| b04e2d9faa1f7dfb | dropped text, only through declared drops | `wiki-local/qa/document-verification/mechanical-spec-consolidation.md` |
| bdd729dc5e0fa5f4 | updater completeness re-run | `wiki-local/qa/document-verification/mechanical-spec-consolidation.md` |
| 66825d94512555ac | script retention (C16) | `wiki-local/infrastructure/agent-orchestration/scratch-retention.md` |
| 3d44fec16896399e | C15 silent-drift sweep | `wiki-local/qa/document-verification/mechanical-spec-consolidation.md` |
| d38f5dbd8754d367 | work order | `wiki-local/qa/document-verification/mechanical-spec-consolidation.md` |
