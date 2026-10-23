# Knowledge flush — 1 insight(s) (headless auto-flush run 20261022-163155-79805)

4 queue rows were claimed this run: 1 ingested, 3 dropped as project-specific
plan-gap rows. Nothing was released and nothing was folded into another branch.

| Candidate | Domain | Disposition |
|-----------|--------|-------------|
| `446c58c78d5e467f` — an exact `git diff --numstat` count depends on the diff algorithm | testing | **ingested** — new page `testing-quality-diff-algorithm-dependent-line-counts` (field-tested) |
| `00a3c8033bc677c5`, `eb441da588cdd417`, `2648b3d4421a5c78` — t244 plan-gap rows | — | dropped — project-specific (see Local-layer candidates) |

## Verified best-practice

**`446c58c78d5e467f` — confidence: field-tested.** Claim: when a gate expects
an exact changed-line count for a text file, check the edit's content instead,
or pin `--diff-algorithm` in both the measurement and the gate. Git's diff
algorithms can pair lines differently, so the same edit can get different
`--numstat` counts. The default `myers` pulled an unchanged blank line into a
changed block.

- https://git-scm.com/docs/git-diff (fetched 2026-10-22): `--diff-algorithm` lists
  `default`, `myers`, `minimal`, `patience`, `histogram`; `myers` is "The basic greedy
  diff algorithm. Currently, this is the default."; `--minimal` "Spend extra time to make
  sure the smallest possible diff is produced." This is why the page says the default
  does not promise the smallest diff. `--numstat` "shows number of added and deleted
  lines".
- The `diff.algorithm` config override (`--diff-algorithm=default` restores the default)
  was seen only in a web-search summary of the git man pages. The fetched page text did
  not include it, and the page says so.
- https://arxiv.org/abs/1902.02467 (Nugroho, Hata, Matsumoto, "How different are different
  diff algorithms in Git?", EMSE / ICSE 2020 journal-first): Myers vs Histogram gave
  different added/deleted-line results on 14 Java projects (0.8%–6.2% added, 1.4%–7.6%
  deleted). This was read only through a web-search summary. The paper was not fetched
  because WebFetch was not allowed for that URL in this run, and the page says so.
- Field case (session evidence, 2026-10-22): README edit → default numstat `20 20`,
  histogram and patience `19 19`; a line-by-line compare found 19 differing lines; the
  blank line between the blocks was byte-identical (`od -c`). This run has no git access,
  so it could not reproduce the case.
- Why it is field-tested and not verified: the docs confirm that several algorithms
  exist and that the default is not the minimal one. The specific mechanism (a blank
  line pulled into a hunk, so the count is +1) comes from one field case.

**Plan-gap rows** — not researched. Each one records a design decision for one
repository's own files (see Local-layer candidates), so there is no general
best-practice to verify.

## Existing-layer check

Pages read: testing-quality-json-manifest-edit-gates, testing-quality-unchanged-function-gates

- Routed through `INDEX.md` → `wiki/testing/index.md` (quality table read in full).
  No load-when line mentions the diff algorithm, `--diff-algorithm`, or `diff.algorithm`.
- **testing-quality-json-manifest-edit-gates**: the closest sibling. Its trigger is a
  gate that counts diff lines (`--numstat`/`--stat`), but only for a JSON manifest,
  where JSON's comma grammar changes the count even with a single algorithm. This
  candidate is about a text file and the choice of algorithm, so it is a different
  mechanism. It was not merged there, because it would be off-topic under that title.
  Cross-linked both ways: the new page links it in `related:` and in an edge row, and
  the JSON page's `related:` gained the new id. The JSON page's confidence and date
  are unchanged.
- **testing-quality-unchanged-function-gates**: another diff-line gate (proving a
  function was not touched). Different trigger. It is linked from the new page's
  `related:` and an edge row. No edit.
- `testing-quality-checks-that-cannot-pass` is linked as the "run the gate on a
  known-good edit" rule. It was identified from its index load-when line, which covers
  reviewing a plan's gates before adopting them. Its body was not opened, so it is not
  listed under Pages read.
- No conflicting directive was found and no page was superseded. The dev-loop-wiki
  MCP (`wiki_search`) failed to connect this session, so the dedup check was done
  by reading the index and pages directly.

## Open-PR check

`gh pr list --repo choiyounggi/dev-loop --state open --json number,headRefName --search "head:knowledge/"`
returned `[]`. There were no open `knowledge/*` heads at flush time.

- `446c58c78d5e467f`: **new**. The previous run released it because of a plausible
  overlap with PR #291. According to `log.md`, #291 has since merged (its
  pages: `anchor-cases-for-allowlist-regexes`, `checks-that-cannot-pass`, a shell
  page). The merged testing index has no diff-algorithm row, so the overlap did not
  become a duplicate.
- The 3 plan-gap rows were not compared against any PR, because they were excluded
  by the layer test.

## Routing decision

- `446c58c78d5e467f` → `testing` / `quality` → new page
  `wiki/testing/quality/diff-algorithm-dependent-line-counts.md` (field-tested).
  No new category was added: `quality` already owns the sibling gate pages
  (`json-manifest-edit-gates`, `unchanged-function-gates`). A testing index row was
  added next to them. The INDEX.md testing line already covers "cases/assertions".
- `log.md` gained one entry for this run.

## Local-layer candidates

These 3 rows are excluded from this PR. Each records a t244 design decision for the
`emperor` (linkly) repository's own files: `scripts/setup_branch_protection.sh`, its
`CHECKS` literal and required-check context, and that repo's CHANGELOG. Each would
be wrong in another codebase. To keep any of them, run wiki-ingest inside that
project:

| Row | Decision | Target |
|-----|----------|--------|
| `00a3c8033bc677c5` | t244 required check context string `test-quality / gate` and where it is written | `wiki-local/infrastructure/ci-cd/required-check-context.md` |
| `eb441da588cdd417` | t244 how `--check` reports drift against live main | `wiki-local/infrastructure/repo-governance/branch-protection-drift-check.md` |
| `2648b3d4421a5c78` | t244 CHANGELOG entry placement and wording | `wiki-local/qa/release/changelog-bullet-placement.md` |
