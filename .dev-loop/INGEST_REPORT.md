# Knowledge flush — 2 insight(s) (headless auto-flush run 20261030-153306-64550)

35 queue rows were claimed this run: 2 ingested, 31 dropped as project-specific
plan-gap rows, 2 released because they plausibly overlap open PRs. Nothing was folded
into another branch.

The 31 plan-gap rows are lines 278–308 of `~/.dev-loop/queue/plan-gaps.jsonl`. This
headless session cannot list the queue directory, so the rows were located by
filename: claim order follows sorted filenames and file order, the first and last six
claimed ids match lines 278 and 303–308, and the 31 ids fill that range exactly.

## Verified best-practice

1. **Freshness check of an uncommitted generated file** (row `9950a83a55ea53e7`).
   Claim: before a generated file's first commit, compare a saved copy with the
   regenerated file (`cmp`); `git diff --exit-code` after `git add -N` is always red.
   - https://git-scm.com/docs/git-add — `-N`: "An entry for the path is placed in
     the index with no content."
   - https://git-scm.com/docs/git-diff — the plain form shows changes "relative to the
     index"; `--exit-code` exits 1 on differences.
   - https://code.googlesource.com/git/+/HEAD/t/t2203-add-intent.sh — git's own
     tests expect an intent-to-add path to diff as a new file with all lines added.
   - Session evidence: the gate exited 1 with `new file mode 100644` and 444 added
     lines on a byte-identical regeneration; the `cmp` check exited 0.
   - Confidence: **verified** (official docs plus a field reproduction). No command
     was re-run in this headless session, which has no shell for git.
2. **Test module written during a background baseline run** (row `bc0e0b2a5d0c2dca`).
   Claim: when a full-suite baseline runs in the background, wait for it or run it in
   a separate copy before creating test modules in the same tree; a test that
   re-discovers the tree at runtime imports the half-written file.
   - https://docs.python.org/3/library/unittest.html#unittest.TestLoader.discover —
     "If importing a module fails … this will be recorded as a single error and
     discovery will continue."
   - Session evidence: 2 `test_readme_currency` failures citing
     `Failed to import test module: tests.test_mcp_exec_tools` (the file being
     written); with the module complete, the full run reached 5959 OK.
   - Confidence: the mechanism is doc-backed; the directive is **field-tested**. It is
     added as one edge row on a `verified` page, and its source line marks it as a
     field incident.

## Existing-layer check

Pages read: qa-document-verification-generated-reference-drift-gates, platforms-tools-staging-tracked-files-under-an-ignored-directory, testing-data-test-data-and-isolation

Also read the domain indexes `wiki/testing/index.md`, `wiki/qa/index.md` and
`wiki/platforms/index.md`, and ran `wiki_search` for each candidate's trigger.

- Row 1: no page covers intent-to-add or untracked files in a freshness gate.
  `generated-reference-drift-gates` owns `--check` gates for closed-vocabulary
  references (a narrower trigger), and `staging-tracked-files-under-an-ignored-directory`
  owns `git add` exit codes. → **new page** `platforms/tools/freshness-check-of-an-uncommitted-generated-file.md`,
  related-linked to both, to `platforms-toolchains-regeneration-silently-drops-hand-edited-state`,
  and to `testing-quality-checks-that-cannot-pass`.
- Row 2: no page covers a concurrent edit breaking a runtime-discovery test.
  `testing-data-test-data-and-isolation` owns "suite behaves differently because of
  its environment". → **merged** as one Edge-cases row plus two source lines, a
  related link to `qa-process-scope-purity-checks` (same root cause: a suite reading
  the live tree), and an extended load-when line in the testing index.
- No conflicts with existing directives.

## Open-PR check

Open `knowledge/*` heads: #318, #317, #315, #310, #309, #308, #307, #306, #305, #304,
#301, #300, #299, #298, #293. This headless run read their changed-file lists
(`gh pr list --json files`), not their diffs.

| Row | Overlapping PR | Verdict |
|-----|----------------|---------|
| `9950a83a55ea53e7` git add -N freshness check | none — #293 (diff-algorithm line counts) and #306 (pip `--require-hashes` known-bad test) touch other mechanisms and pages | new |
| `bc0e0b2a5d0c2dca` test file written mid-baseline | none — #317 touches `testing/data/artifact-leakage-from-a-suite.md` (leftover files), a different trigger | new |
| `fc76dc4dfa08ecde` docker schema validator: skip vs `REQUIRE` fail, known-bad document | plausibly #300 (edits `testing/quality/tests-that-cannot-fail.md` and `checks-that-cannot-pass.md`) | released (pending duplicate) |
| `122dd81477d4a447` absence-in-source assertion fails on its own explanatory comment | plausibly #317 ("self-matching gate CHECKs", edits `checks-that-cannot-pass.md`) | released (pending duplicate) |

The released rows are left `pending`, not retired, so the manual flush can diff them
against those PRs.

## Routing decision

- Row 1 → `platforms/tools/freshness-check-of-an-uncommitted-generated-file.md` (new
  page). It is a git-behaviour edge case that applies to any repository, which is
  the scope of the `tools` category; no new category needed.
- Row 2 → `testing/data/test-data-and-isolation.md`, Edge cases (merge).

- 31 plan-gap rows → not ingested (see below).

## Local-layer candidates

31 rows from `plan-gaps.jsonl` (repo `shag` = linkly, task plans of orchestration
run oi1029; the 7 rows read in full come from t1, t5 and t9), ids `1d01cb971e07f6cb` … `9bf49772c47a2672`. Each records
one plan decision (`Planning tN: deciding … (no owning wiki page)`) that names
linkly's own files, flags and plan ids (`cmd_token`, `docs/backends.md`,
`benchmarks/token/`, `plans/t9/design.md D23`), so it would be wrong in another
codebase. Target, if anyone wants them kept: `wiki-local/<domain>/<category>/<slug>.md`
inside linkly — run wiki-ingest inside that project. Each decision is already
recorded in that run's `plans/tN/design.md`, so they were retired as
`dropped: project-specific plan-gap (local layer of its repo)`, the same outcome
earlier flushes gave such rows.
