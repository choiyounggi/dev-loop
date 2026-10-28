# Knowledge flush — 4 insight(s) (headless auto-flush run 20261028-100340-23911)

6 queue rows were claimed this run: 4 ingested as edge rows on existing testing
pages, 1 released because it plausibly overlaps open PR #299, 1 dropped as a
project-specific plan-gap row. Nothing was folded into another branch.

| Candidate | Domain hint | Disposition |
|-----------|-------------|-------------|
| `c9e00eb2a93a55e3`: a document checker and its composer hard-code the same source line ranges | testing | **ingested**: edge row on `testing-quality-cross-component-invariant-via-shared-helper` (field-tested) |
| `f8a300baed4c34f0`: a "text of X lives in D §N" pointer checked only for the heading existing | qa → testing | **ingested**: edge row on `testing-quality-spec-artifact-checks` (field-tested) |
| `b3a7b01998f7d6aa`: a citation checker exempts whole history lines | testing | **ingested**: edge row on `testing-quality-guard-shape-vs-consequence` (field-tested) |
| `bdb042f44f413d06`: a new test reads a repo-root file a mutation harness's fixed copy list lacks | testing | **ingested**: edge row on `testing-quality-harness-reverse-controls` (field-tested) |
| `f332524447ff2105`: a grep absence check in a gate ledger matches its own ledger file | testing | **released**: plausible overlap with open PR #299 |
| `6867bb478197b062`: linkly t246 plan-gap (which Python classifiers `pyproject.toml` gains) | — | dropped as project-specific (see Local-layer candidates) |

## Verified best-practice

This headless run could not fetch pages or run commands (Bash is limited to the
queue tool and `gh pr list`). Every external source below was read through a
web-search result summary, and each source line on the pages says so. The field
cases come from the originating sessions and were not re-run here. So every
ingested row is **field-tested**, and each page keeps its own `confidence` and
`last_verified`.

**`c9e00eb2a93a55e3` (field-tested).** Claim: when a completeness checker and
the composer of an assembled document share hand-typed source line ranges,
take the ranges from structural markers in the source, or rebuild the expected
text from those markers inside the checker. Then require red when one range is
shortened in both copies.
- Basis: the page's existing source, kenjudy/pdca-agentic-coding-framework#181
  ("is that source independent of the code under test?"), and PIT's "Survived"
  definition. Two copies of one list are one oracle, and an oracle that is not
  independent agrees with a wrong output.
- Field case: shortening range 207-301 to 207-300 in both copies left the
  checker at rc=0 while the last sentence of §3.3 was missing.
- Searched for Google TotT "Don't Put Logic in Tests"
  (https://testing.googleblog.com/2014/07/testing-on-toilet-dont-put-logic-in.html).
  The search did not return the body text, so the page does not cite it.

**`f8a300baed4c34f0` (field-tested).** Claim: for each "X lives in D §N"
pointer, require §N at the pinned ref to define X itself. When §N only forwards
to another document, retarget the pointer to that final owner.
- https://lychee.cli.rs/recipes/anchors/: `--include-fragments` checks anchors
  generated from headings and explicit ids. An anchor check shows only that the
  target exists, which is why it misses a forward-only section.
- Field case: the t74 checker (16 checks, 18 mutants) was green until a
  per-item definition check was added. Reverting the fix then failed with
  "`Duration` -> RFC-0071 §1: not defined there".

**`b3a7b01998f7d6aa` (field-tested).** Claim: when a checker exempts whole
lines as history, still apply the never-exempt pattern (a section-anchored
citation) to those lines. Keep a narrow per-line allowlist that names a reason
for each entry.
- https://eslint.org/docs/head/use/configure/rules: a disable comment with no
  rule names turns off every rule on the line, and the docs show listing rule
  names to narrow it. That is the same mechanism: an exemption wider than its
  reason hides other findings.
- Field case: the t73 checker passed a mixed line at 15/15. With the rule
  applied to history lines, the round-0 file failed exactly that line (12/16).
- Searched for ruff `blanket-noqa` (PGH004). Both searches returned unrelated
  results, so it is not cited.

**`bdb042f44f413d06` (field-tested).** Claim: when a harness builds mutant trees
from a fixed list of copied paths, a change whose test reads a new root file
adds that path to the list in the same change. It also runs the test that pins
the list.
- https://mutmut.readthedocs.io: `also_copy` lists the extra files and
  directories that mutmut copies into `mutants/` because the full suite needs
  them. Fixed copy lists are a documented harness design.
- The page already says to copy the whole repository (step 4 and its Instead-of
  row). The new row covers harnesses that keep a fixed list on purpose.
- Field case: `test_mutation_tree` failed with
  `{'requirements.lock.txt': ['test_supply_chain.py']} != {}` until the path was
  added to `TREE_CONTENTS`. After that, 17 tests ran OK.

**`f332524447ff2105`: not researched.** It was released before verification
(see Open-PR check).

**`6867bb478197b062`: not researched.** It is a plan-gap row that records one
design decision for the linkly repository's own `pyproject.toml`, so there is no
general best-practice to verify.

## Existing-layer check

Pages read: testing-quality-harness-reverse-controls, testing-quality-spec-artifact-checks, testing-quality-cross-component-invariant-via-shared-helper, testing-quality-guard-shape-vs-consequence

Also read: `wiki/testing/index.md` and `wiki/qa/index.md` (routing). I ran
`wiki_search` once per candidate. The hits pointed to the same pages, plus
`testing-quality-mutation-harness-file-custody` and
`testing-quality-schema-additions-under-a-golden-gate`. Their snippets did not
match these mechanisms, so I did not open them.

- `c9e00…`: no existing row covers two hand-typed copies of a range list.
  The shared-helper page's claim ("both sides built from one source agree
  regardless of production") is the same mechanism, so I merged the case in as
  an edge row. Added `related: testing-quality-spec-artifact-checks`.
- `f8a3…`: spec-artifact-checks owns "ids that must resolve across documents".
  Its control table repoints an id to a target that does not exist, but nothing
  covers a target that exists and does not define the item. Merged as an edge
  row.
- `b3a7…`: guard-shape-vs-consequence already has an edge row on exemption
  lists ("each entry is a case the guard stopped measuring"). The new row adds
  the line-granularity case. No conflict.
- `bdb0…`: harness-reverse-controls step 4 already says "copy the whole
  repository". The candidate does not conflict with it; it covers harnesses
  whose fixed list is deliberate, so it is an edge row and not a duplicate.
- I created no new pages. The `testing/index.md` load-when lines and the four
  pages' "When this applies" paragraphs were extended to match. `log.md` has one
  new ingest line.

## Open-PR check

Open `knowledge/*` heads (`gh pr list --repo choiyounggi/dev-loop --state open
--search "head:knowledge/"`): #306, #305, #304, #301, #300, #299, #298, #293.
This run cannot `git diff` them. I compared each candidate against each PR's
file list and its INGEST_REPORT body, both read through `gh pr list --json`.

- `f332524447ff2105` → **released**. #299 adds
  `platforms-tools-search-evidence-from-a-wrapped-grep`: the Bash tool's `grep`
  is a shell function, and that is the same mechanism as this candidate.
  PR #305 released this row for the same reason.
- `c9e00…`, `f8a3…`, `b3a7…`, `bdb0…` → **new**. None of their target pages
  appears in any open PR's file list. I checked the nearest PRs too:
  - #305 (superseded-section verdicts, on `qa-document-verification-superseding-a-knowledge-record`)
    is about computing replace/keep verdicts, not range oracles or pointer
    targets.
  - #300's `testing-quality-new-test-outside-a-runner-include-filter` is about a
    Gradle include filter that leaves a test unrun, not mutant trees missing a
    file.
  - #299's `security-agent-exposure-command-guard-exemption-matching` is about
    command-text matching in a security guard, not line-level exemptions in a
    document checker.
- `6867…` → dropped as project-specific, so no open-PR verdict applies.

## Routing decision

| Candidate | Target |
|-----------|--------|
| `c9e00…` | testing/quality → `wiki/testing/quality/cross-component-invariant-via-shared-helper.md` (edge row + source line) |
| `f8a3…` | testing/quality → `wiki/testing/quality/spec-artifact-checks.md` (edge row + 2 source lines; frontmatter source added). The hint was `qa`, but qa/document-verification/spec-document-gates routes check-authoring to this page |
| `b3a7…` | testing/quality → `wiki/testing/quality/guard-shape-vs-consequence.md` (edge row + 2 source lines; frontmatter source added) |
| `bdb0…` | testing/quality → `wiki/testing/quality/harness-reverse-controls.md` (edge row + 2 source lines; frontmatter source added) |

No new category or page. The existing `testing/quality` pages each own the
mechanism.

## Local-layer candidates

- `6867bb478197b062` (linkly/scoter, plan-gap t246: the four
  `Programming Language :: Python :: 3.11`–`3.14` classifiers and where they go
  in `pyproject.toml`) → `wiki-local/infrastructure/packaging/python-version-classifiers.md`.
  Run wiki-ingest inside that project.
