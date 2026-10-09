# Knowledge flush — 1 insight (1 page amended, 4 plan-gaps retired as local-layer)

## Verified best-practice

**Insight `5c36b7664eecdfca` — choosing the value of a band-checked count on a shared integration branch.**

- Claim: when a repo test checks a README's approximate count ("~N tests") against the real count within a tolerance band, and your branch adds tests to an integration branch other branches also merge into, pick a value inside the overlap of the bands around your branch's count and the integration tip's count, and write it into every copy of the claim (prose line, pasted run output, each language's README).
- Sources checked:
  - https://docs.github.com/en/repositories/configuring-branches-and-merges-in-your-repository/configuring-pull-request-merges/managing-a-merge-queue — fetched 2026-10-05; the merge queue checks a PR's changes "when applied to the latest version of the target branch and any pull requests already in the queue". This backs the mechanism: a branch green on its own is not evidence the target stays green.
  - A second candidate source (graydon2.dreamwidth.org "not rocket science rule") returned an empty page on fetch and is **not cited**.
- How verified: re-ran the field evidence in the originating worktree on 2026-10-05. `impl/tests/test_readme_currency.py` defines `SUITE_CLAIM_BAND = 0.05` and checks both the prose claim and the pasted `Ran N tests` line in `README.md` and `README.ko.md` (4 places, all reading 4090 / 4,090). `python -m unittest tests.test_readme_currency` → `Ran 10 tests ... OK`. Band arithmetic: |4108−4090| = 18 ≤ 205.4 and |4075−4090| = 15 ≤ 203.75.
- Confidence: **field-tested** (page stays `field-tested`; the external doc backs the mechanism, not the band-picking rule itself).

## Existing-layer check

Pages read: infrastructure-agent-orchestration-ours-resolution-on-a-mixed-content-conflict, qa-deliverables-quantitative-claims-in-a-published-document, infrastructure-agent-orchestration-verify-command-in-a-worker-brief

- `wiki_search` top-5 for the trigger: verify-command-in-a-worker-brief (edge case + instead-of), backend-python-packaging-data-files-and-install-paths, testing-quality-assertion-scanner-false-positive-on-unittest-convention, ours-resolution-on-a-mixed-content-conflict (instead-of).
- **ours-resolution-on-a-mixed-content-conflict** already owns the trigger "writing the brief for workers who will each change a count a currency test checks" and directs each worker to write its own measured value. It does not cover a tolerance band, where one value can satisfy several merge orders. → **merged** as one Edge-case row + one Instead-of row + two source lines.
- **quantitative-claims-in-a-published-document** already says to fix every copy of a number (translated README) — consistent with the new row, no conflict; not edited.
- **verify-command-in-a-worker-brief** (read via grep hits and search snippets only) covers naming currency gates on a task's verify line — different directive, no conflict.
- Conflicts flagged: none. `related:` already links ours-resolution ↔ quantitative-claims; no new links needed.
- `last_verified` left at 2026-09-03: only the new rows were re-verified today, not the whole page.

## Open-PR check

Open `knowledge/*` heads diffed against `origin/main -- wiki/`: #223, #225, #226, #227, #228, #229, #230, #231, #233, #234, #235, #236, #237, #238.

- Only #223 touches the target page, and only its `related:` frontmatter line (adds `word-level-union-merge-reassembly`). It carries nothing about tolerance bands or count-value selection. This PR leaves the `related:` line untouched and inserts its new source line two lines above it, with `last_verified` between them as an unchanged separator, so both should merge in either order.
- Keyword sweep (`README.*count|test count|tolerance band|±N%|merge order|integration tip|currency test`) over every open head's wiki diff: 0 hits except #223 (1, the related-line context). Positive control: the same pattern hits 7 lines in the target page on `main`.
- Verdict for `5c36b7664eecdfca`: **new**.

## Routing decision

- `5c36b7664eecdfca` → `infrastructure/agent-orchestration/ours-resolution-on-a-mixed-content-conflict.md` (merge, no new page). The situation arises from integrating parallel branches, which this category owns. `wiki/infrastructure/index.md` load-when for the page is extended with the band-value case. `log.md` has an ingest entry.
- Layer test: the directive names no repo's files; band checks on approximate doc counts and order-independent merges hold in any codebase. linkly appears only as field evidence → bundled wiki.
- Lint: `node scripts/wiki-lint-prohibitions.js wiki/` → violations: 0. Page body 59 lines (≤120).

## Local-layer candidates

Four `plan-gap` rows from linkly task t193's wiki-plan (`ebc151c5f983f079`, `4a00613ab264b2ec`, `1fbbb4c7327deb07`, `282a78f6c9000665`). They cover the task split, which `.lnpl` snippets go in a doc, where a `docs/backends.md` link row goes, and the changelog heading shape. Each one names linkly's own files and conventions (`docs/backends.md` section 5, `.orchestration/changelog/t182.md` precedent, `python -m lnpl`). They are plan decisions, not reusable lessons, so they are excluded from this PR and retired. If a lesson is wanted: `wiki-local/qa/document-verification/<slug>.md` in linkly — run wiki-ingest inside that project.
