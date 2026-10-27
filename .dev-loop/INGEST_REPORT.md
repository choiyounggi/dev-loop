# Knowledge flush — 1 insight(s) (headless auto-flush run, 2026-10-27)

6 queue rows were claimed this run: 1 ingested as an edge row, 5 dropped as
project-specific plan-gap rows. Nothing was released, and nothing was folded
into another branch.

| Candidate | Domain | Disposition |
|-----------|--------|-------------|
| `404f15d11e1e93f1`: a done-gate reads the output file of a test run that is still running (TAP plan + "0 failures") | testing → qa | **ingested**: edge row on `qa-process-completion-claims` (verified) |
| `8927976696ef8303`, `26e813b24239dbd0`, `780a7eb76d3aa89b`, `17b8c8361b7d89cf`, `63a6fef2bf0334d1`: linkly t48 plan-gap rows | — | dropped as project-specific (see Local-layer candidates) |

## Verified best-practice

**`404f15d11e1e93f1` (confidence: verified).** Claim: when a gate or monitor
reads a test runner's output file that may still be written, require the
count of finished results to equal the planned total (`grep -c '^ok '` = N
from `1..N`) and zero `not ok`. "Plan line present + 0 failures" is already
true after the first result, because a leading plan is written before any
result.

- https://testanything.org/tap-version-14-specification.html: the plan
  appears exactly once, "either before any Test Point lines, or after all Test
  Point lines". The spec describes the plan as a guard against truncated
  output. So a leading plan says how many results will follow, not that they
  have arrived.
- https://bats-core.readthedocs.io/en/latest/usage.html: the TAP output
  examples print `1..N` before the `ok` lines, and bats defaults to TAP when
  stdout is not a terminal (a redirected log).
  Both were read through web-search result summaries. This run cannot fetch
  pages or run bats (Bash is limited to the queue tool and `gh pr list`).
  The quoted plan-placement sentence comes from that summary of the TAP 14 page.
- Field case from the session: gate-check recorded the gate MET on `full.out`
  at 55 of 1731 tests. With `grep -c '^ok '` = 1731 it stayed unmet until the
  run finished (1731 ok, 0 not ok).
- TAP skips are `ok … # skip` lines, so the `^ok ` count still reaches N on a
  run with skips. The page row does not add a claim about this.

**Plan-gap rows: not researched.** Each records one design decision for the
linkly repository's own RFC files and orchestration notes, so there is no
general best-practice to verify.

## Existing-layer check

Pages read: qa-process-completion-claims

`wiki_search` (k=5) hits considered:

| Query | Top hits |
|-------|----------|
| done-gate checks the output file of a still-running test run; TAP plan + 0 failures | qa-process-completion-claims 0.761 (directive row "Tests pass" → "zero failures and the expected total count"), escape-hatch-uses-as-a-knowledge-gap-signal 0.760, unchanged-function-gates 0.754, qa-process-completion-claims 0.753 (gate ledger row), checks-that-cannot-pass 0.752 |
| reading a background test run's log before it finished; partial output looks green | store-assertions-after-a-rolled-back-run 0.747, qa-process-completion-claims 0.744 (dropped-total edge row), control-signals-vs-primary-artifacts 0.736, session-context-token-budget 0.734, store-assertions-after-a-rolled-back-run 0.732 |

- `qa-process-completion-claims` already makes "zero failures **and** the
  expected total count" the evidence for "tests pass", and it covers gate
  ledger rows marked MET. It does not name the mechanism that lets a gate pass
  on a run that has not finished: the TAP plan is written first. Same trigger
  family, compatible directive, so this is **merged** as one edge row with 2
  sources and the field case. `last_verified` moves to 2026-10-27. The page
  stays `field-tested`, because its other rows are unchanged.
- `testing-quality-checks-that-cannot-pass` (about writing a gate before the
  work exists) and `control-signals-vs-primary-artifacts` (about trusting a
  worker's status signal) were found only as search hits and were not opened.
  Neither is about reading a partial runner log. Both are already in, or next
  to, completion-claims' `related:` list, so no new links were added.
- No conflicts. No page was superseded. The page body grows by one table row
  and stays under 120 body lines.

## Open-PR check

`gh pr list --repo choiyounggi/dev-loop --state open --json number,headRefName --search "head:knowledge/"`
returned 5 heads: #301, #300, #299, #298, #293. This run has no git access.
It compared each PR's changed-file list and body (from `gh pr list --json
files,body`) against the candidate instead of reading their diffs.

| PR | Wiki files touched (testing/qa only) | Overlap with `404f15d11e1e93f1` |
|----|--------------------------------------|---------------------------------|
| #301 | `testing/quality/ci-workflow-step-behavior-tests`, `testing/index.md` | None: deleting replaced workflow tests |
| #300 | `testing/quality/{tests-that-cannot-fail,checks-that-cannot-pass,new-test-outside-a-runner-include-filter}`, `testing/index.md` | Same domain, different trigger. Its `checks-that-cannot-pass` change is a cross-reference about pipe exit masking for a pre-push hook. Its new page is about Gradle include filters. Neither covers a partial runner log, and the target page here is not touched |
| #299 | none under testing/ or qa/ | None |
| #298 | none under testing/ or qa/ | None |
| #293 | `testing/quality/{diff-algorithm-dependent-line-counts,json-manifest-edit-gates}`, `testing/index.md` | None: diff-algorithm line counts |

No open PR touches `wiki/qa/`. Verdicts:
- `404f15d11e1e93f1`: **new**.
- The 5 plan-gap rows were excluded by the layer test, so they were not compared.

Possible merge conflict, not duplicate content: `log.md`, which every open
flush PR appends to.

## Routing decision

| Candidate | Target | Action |
|-----------|--------|--------|
| 404f15d11e1e93f1 | qa/process/completion-claims | +1 edge row, +2 sources plus the field case, `last_verified` 2026-10-27; qa index "load when" extended |
| 5 t48 plan-gap rows | — | dropped (project-specific) |

The candidate's domain hint was `testing`, but the lesson is about what
evidence a completion gate needs, and `qa/process/completion-claims` owns
that. No new category was needed. The task name stays only in the field-case
source line.

## Local-layer candidates

These 5 rows are excluded from this PR. Each records a t48 design decision
for the linkly repository (`scoter` workspace): RFC-0048 pointer lines and
their exact Korean marker text, RFC-0052/0059 chain order, the
`gen_plugin_references.py --check` step, blackboard lines in
`.orchestration/notes/decisions.md`, and two Draft-time edits to RFC-0048.
Each would be wrong in another codebase. To keep any of them, run
wiki-ingest inside that project.

| Row | Decision | Target |
|-----|----------|--------|
| `8927976696ef8303` | t48 section-head pointer lines: which sections, which format | `wiki-local/qa/document-verification/rfc-update-pointer-lines.md` (linkly) |
| `26e813b24239dbd0` | t48 generated plugin references: check, don't regenerate | `wiki-local/qa/document-verification/generated-references-check.md` (linkly) |
| `780a7eb76d3aa89b` | t48 RFC-0052/0059 dependence on 0048 §4: confirm by reading | `wiki-local/qa/document-verification/rfc-update-chain-order.md` (linkly) |
| `17b8c8361b7d89cf` | t48 blackboard lines and CHANGELOG ownership | `wiki-local/infrastructure/agent-orchestration/blackboard-entries.md` (linkly) |
| `63a6fef2bf0334d1` | t48 RFC-0048 targets with no rule-4 final text | `wiki-local/qa/document-verification/rfc-updates-target-final-text.md` (linkly) |
