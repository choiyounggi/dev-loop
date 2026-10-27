# Knowledge flush — 1 insight(s) (headless auto-flush run, 2026-10-27)

11 queue rows were claimed this run (claim id `20261027-143845-77474`): 1 ingested
as an edge row, 1 released because it plausibly overlaps open PRs #299 and #300,
and 9 dropped as project-specific plan-gap rows. Nothing was folded into another
branch.

| Candidate | Domain hint | Disposition |
|-----------|-------------|-------------|
| `57b29eb464b7964d`: deciding whether a later amendment replaced a section while folding a spec into one successor | testing → qa | **ingested**: edge row on `qa-document-verification-superseding-a-knowledge-record` (field-tested) |
| `f332524447ff2105`: a grep absence check in a gate ledger matches its own ledger file | testing | **released**: plausible overlap with open PRs #299 and #300 |
| `3371231584ee3085`, `f6e7dc62dbcab5b8`, `74aab9ebac5fcc50` (t243); `dc64c1aaeff8abd5`, `16e3d7372a1f7310`, `6dd20d910358ec27`, `ab1c6bfa64b3daa4`, `75e9b250fdc419ee`, `971eeda21edb8497` (t72) | — | dropped as project-specific (see Local-layer candidates) |

## Verified best-practice

**`57b29eb464b7964d` (confidence: field-tested).** Claim: when you fold a
specification and the later documents that amended it (*Updates*) into one
successor, let a checker compute each "replaced or kept" verdict from the
sources. Collect the names defined in the code blocks of every amendment
accepted after the original whose *Updates* line names the same section chain,
and skip the quoted old text (`OLD:` / **Old** blocks). For a verdict branch no
current item reaches, force one item down it with an override and require both
outcomes.

- https://www.rfc-editor.org/rfc/rfc9141: an updating RFC that quotes "the
  original text from an RFC to be updated" as OLD and the replacement as NEW.
  It shows that amendments carry the replaced definition verbatim, which is
  why a plain grep over them finds old definitions too. Read through a
  web-search summary only. The search did not show this as an IETF-wide rule,
  and the page says it is one document's convention.
- The *Updates* relation itself is already sourced on the page (RFC 2223 §12).
- Field case from the session: the checker judged four grammar rules replaced.
  An auditor removed the real definition line from one amendment's copy, and
  that verdict turned to "kept" (exit 1). Forcing one rule down the kept branch
  with an env override gave exit 1 without its source line and exit 0 with it.
- Why field-tested, not verified: the mechanism (old text quoted inside
  amendments misleads a grep) rests on one field case plus one RFC read through
  a summary. This headless run cannot fetch pages or run commands (Bash is
  limited to the queue tool and `gh pr list`), so nothing was reproduced here.
  The page keeps its `verified` confidence and its `last_verified` date,
  because its other rows are unchanged.

**`f332524447ff2105`: not researched.** It was released before verification
(see Open-PR check).

**Plan-gap rows: not researched.** Each records one design decision for the
linkly repository's own workflow files, tests, RFC files and orchestration
notes, so there is no general best-practice to verify.

## Existing-layer check

Pages read: qa-document-verification-superseding-a-knowledge-record, platforms-tools-search-evidence-from-a-wrapped-grep, testing-quality-checks-that-cannot-pass

`wiki_search` (k=5) hits considered:

| Query | Top hits |
|-------|----------|
| consolidating a spec superseded by chained partial updates; compute replaced sections, excluding Old blocks | agent-skill-supply-chain 0.749, event-loop-blocking 0.737, optimistic-vs-pessimistic-locking 0.730, environment-config 0.728, image-builds 0.728 (none on topic) |
| force a decision branch with no real data case through an env var override to see both exit codes | gate-evidence-exit-code-class 0.761 / 0.747 / 0.741, tool-diagnostics-without-a-failing-exit-code 0.737, self-hosted-model-load-latency 0.731 |
| amendment document quotes OLD and NEW text; grep for definitions counts the old quoted definition | evaluating-review-feedback 0.775, wrapping-quotes-in-a-frontmatter-value 0.757, model-coupled-guidance-aging-detector 0.750, rationale-prose-after-a-config-value-change 0.741 |
| gate ledger grep check finds its own search phrase; grep is a shell function in interactive zsh | completion-claims 0.814, search-evidence-from-a-wrapped-grep 0.757 / 0.753, evaluating-review-feedback 0.747, checks-that-cannot-pass 0.747 |

- **`57b29eb464b7964d`:** no page covers folding chained amendments into one
  document. `superseding-a-knowledge-record` owns *Updates* vs *Obsoletes* and
  already has a split-successor edge row, so this is the same trigger family
  with a compatible directive. **Merged** as one edge row with 2 sources.
  `gate-evidence-exit-code-class` is about reading a recorded exit code, not
  about forcing an unreached branch, so it was not linked. The "require both
  outcomes" part points to `testing-quality-checks-that-cannot-pass`, which owns
  known-good and known-bad runs of a check; its id was added to `related:`.
  The page body grows by one table row and two source lines and stays under
  120 lines. No conflicting directive was found.
- **`f332524447ff2105`:** the merged `search-evidence-from-a-wrapped-grep`
  already covers the interactive `grep` function vs `/usr/bin/grep` in a
  script (step 1 and the "gate script greps" edge row). The self-match of the
  ledger file is not covered there or on `checks-that-cannot-pass`. Its natural
  targets are exactly those two pages, which open PRs edit, so it was released
  rather than ingested (next section).

## Open-PR check

`gh pr list --repo choiyounggi/dev-loop --state open --json number,headRefName --search "head:knowledge/"`
returned 6 heads: #304, #301, #300, #299, #298, #293. This run has no git access.
It compared each PR's changed-file list and body (from `gh pr list --json
files,body`) against the candidates instead of reading their diffs.

| PR | Relevant files touched | Overlap |
|----|------------------------|---------|
| #304 | `qa/process/completion-claims`, `qa/index.md` | None for either candidate. Same domain, different category: it covers a done-gate reading a still-running TAP log |
| #301 | `testing/quality/ci-workflow-step-behavior-tests`, `testing/index.md` | None: replacing exact-text workflow tests |
| #300 | `testing/quality/{checks-that-cannot-pass,tests-that-cannot-fail,new-test-outside-a-runner-include-filter}`, `testing/index.md` | `f332524447ff2105`: plausible. Its gate-validation target page is edited here. `57b29eb464b7964d` only links to `checks-that-cannot-pass` and does not edit it |
| #299 | `platforms/tools/search-evidence-from-a-wrapped-grep` and other grep pitfalls | `f332524447ff2105`: plausible. It adds a wrapped-grep failure mode to the page this candidate would extend |
| #298 | none under qa/ or testing/ | None |
| #293 | `testing/quality/{diff-algorithm-dependent-line-counts,json-manifest-edit-gates}` | None |

No open PR touches `wiki/qa/document-verification/`. Verdicts:
- `57b29eb464b7964d`: **new**.
- `f332524447ff2105`: treated as a pending duplicate and **released** back to
  pending (`queue-claim.js release`), so a manual flush can diff it against
  #299 and #300.
- The 9 plan-gap rows were excluded by the layer test, so they were not compared.

Possible merge conflicts, not duplicate content: `log.md`, which every open
flush PR appends to, and `wiki/qa/index.md`, which #304 also edits (it changes
the `completion-claims` row; this PR changes only the `superseding-a-knowledge-record` row).

## Routing decision

| Candidate | Target | Action |
|-----------|--------|--------|
| 57b29eb464b7964d | qa/document-verification/superseding-a-knowledge-record | +1 edge row, +2 sources (frontmatter and Sources), related id `testing-quality-checks-that-cannot-pass`; qa index "load when" extended; confidence and `last_verified` unchanged |
| f332524447ff2105 | — | released (open-PR overlap) |
| 9 plan-gap rows | — | dropped (project-specific) |

The domain hint was `testing`, but the lesson is about how to decide what a
consolidated document must carry, and `qa/document-verification` owns
superseding and amending records. No new category was needed. The project's
RFC numbers and task names were removed from the row; they stay only in the
field-case source line as "a spec-consolidation task".

## Local-layer candidates

These 9 rows are excluded from this PR. Each records one design decision for
the linkly repository (`scoter` workspace). Each would be wrong in another
codebase. To keep any of them, run wiki-ingest inside that project.

| Row | Decision | Target |
|-----|----------|--------|
| `3371231584ee3085` | t243 pin form for workflow `uses:` lines (SHA plus version comment, which refs stay) | `wiki-local/infrastructure/ci-cd/action-pin-form.md` (linkly) |
| `f6e7dc62dbcab5b8` | t243 repair of the upload-artifact assertion in one test file | `wiki-local/testing/quality/workflow-pin-assertions.md` (linkly) |
| `74aab9ebac5fcc50` | t243 job ids and required check names stay unchanged | `wiki-local/infrastructure/ci-cd/required-check-names.md` (linkly) |
| `dc64c1aaeff8abd5` | t72 RFC-0016 §3 composition from RFC-0054 | `wiki-local/qa/document-verification/rfc-consolidation-sections.md` (linkly) |
| `16e3d7372a1f7310` | t72 RFC-0016 §5 composition from RFC-0052 | `wiki-local/qa/document-verification/rfc-consolidation-sections.md` (linkly) |
| `6dd20d910358ec27` | t72 RFC-0016 lines carried verbatim and lines dropped | `wiki-local/qa/document-verification/rfc-consolidation-sections.md` (linkly) |
| `ab1c6bfa64b3daa4` | t72 the 9 citation edits | `wiki-local/qa/document-verification/rfc-citation-renumbering.md` (linkly) |
| `75e9b250fdc419ee` | t72 Open Questions items and conflict entries | `wiki-local/qa/document-verification/rfc-consolidation-conflicts.md` (linkly) |
| `971eeda21edb8497` | t72 blackboard lines | `wiki-local/infrastructure/agent-orchestration/blackboard-entries.md` (linkly) |
