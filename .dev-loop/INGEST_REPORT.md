# Knowledge flush — 4 insight(s)

Drained from `~/.dev-loop/queue/` (4 pending rows across 3 sessions / 3 repos:
`chungyak-alimi`, `track-b-ranking`, `linkly`). Four pages created, one new
category, twelve existing pages back-linked. No page overwritten, no conflict found.

## Verified best-practice

### 1. Import-time I/O makes a "pure function" unit test infrastructure-bound
**Claim** — a pure function reached by importing a module whose top level runs
`init_db()`/connect is not DB-free; a module-level `pytestmark = pytest.mark.skipif(...)`
cannot prevent it, because collection imports the module body top-to-bottom and the
app import above that line has already run.

**Sources checked**
- https://docs.pytest.org/en/stable/how-to/skipping.html — confirms the three real
  escape hatches: `pytest.importorskip` at module level, `pytest.skip(reason,
  allow_module_level=True)`, and `pytestmark = pytest.mark.skipif(...)` for a module.
  (Read from the upstream doc source `doc/en/how-to/skipping.rst` on
  `pytest-dev/pytest@main` after docs.pytest.org returned HTTP 429.)
- https://docs.pytest.org/en/stable/example/pythoncollection.html — `collect_ignore` /
  `collect_ignore_glob`; states pytest imports files matching the discovery patterns,
  which breaks on files that raise on import. This is the mechanism the insight names.
- https://docs.python.org/3/reference/import.html — module body executes on first import.

**How verified** — official docs plus a local reproduction (2026-08-05): a module
whose first line prints a side effect still prints it when only its pure function is
imported (`from modside import pure_fn` → side effect printed, then `pure_fn(2) == 4`).

**Refinement made during verification** — the queued directive said skipif markers are
"무력" (powerless). That holds for the *ordering* reason only; the docs show that an
`allow_module_level` skip placed **above** the import, `importorskip`, and
`collect_ignore` all do work. The page states the ordering rule ("place the guard above
the import it protects") rather than the blanket claim.

**Confidence: verified**

### 2. Confirm volume before reading a distribution query
**Claim** — `GROUP BY`/`DISTINCT` over an empty table return zero rows without error,
which reads as "no values to normalize"; `count(*)` returns a row containing `0` and is
the only unambiguous shape. When the count is 0, derive the rule from the writers and
fixtures instead, and record the substitution in the artifact.

**Sources checked**
- https://www.postgresql.org/docs/current/functions-aggregate.html — "except for
  `count`, these functions return a null value when no rows are selected. In
  particular, `sum` of no rows returns null, not zero as one might expect, and
  `array_agg` returns null rather than an empty array".
- https://greatexpectations.io/blog/exploring-data-quality-volume/ — volume (row count)
  as a first-class data-quality dimension; undetected volume anomalies "skew analyses
  and lead to flawed decision-making". Supports "check volume first" as established
  practice rather than a local habit.
- https://www.postgresql.org/docs/current/tutorial-agg.html was checked first and does
  **not** state the empty-input behaviour; it is therefore not cited.

**How verified** — reproduced 2026-08-05 in `sqlite3 :memory:` over an empty table:
`SELECT area_nm, count(*) … GROUP BY area_nm` → 0 rows; `SELECT count(*)` → one row
`0`; `SELECT max(area_nm)` → one row `NULL`. Matches the PostgreSQL-documented
semantics, so the page is written engine-neutral.

**Confidence: verified**

### 3. Enumerate call sites by call target, not by parameter name
**Claim** — grepping `param=` cannot find callers that pass the argument positionally,
so a keyword-based census silently under-reports; test helpers compound this by
reproducing the old shape at many sites while appearing once in a call-target search.

**Sources checked**
- https://docs.python.org/3/reference/expressions.html#calls — "If there are N
  positional arguments, they are placed in the first N slots"; keyword arguments are
  matched by identifier. This is the mechanism: a positional call site contains no
  parameter name, so no keyword pattern can match it.
- https://libcst.readthedocs.io/en/latest/codemods.html — a codemod is "an automated
  refactor that can be applied to a codebase of arbitrary size"; CST transforms match
  call nodes rather than text. (Definition confirmed via the upstream
  `docs/source/codemods.rst`; readthedocs returned HTTP 429.) The page cites LibCST
  only for the tool-choice row. A widely-repeated "regex is insufficient for call-site
  refactors" line traces to a Medium post I could not fetch, so that wording is **not**
  asserted anywhere in the page.
- The originating session's own failure record: a `repo_rows=` census reported 13 hits,
  the real run was `Ran 472 tests / FAILED (failures=11)`, all in `test_backend.py`,
  plus a `rows_for()` helper feeding 5 further sites.

**How verified** — language-reference semantics (positional binding by position) plus
the reproduced failure above. The mechanism generalizes to any language with positional
calls, so `applies_to: [general]`.

**Confidence: verified**

### 4. `${VAR:-default}` discards an empty override
**Claim** — passing `VAR=` to turn a feature off is silently ignored when the script
reads `${VAR:-default}`, because the colon form substitutes the default for null *and*
unset. Pass a sentinel the script's own validation rejects, or change the read to
`${VAR-default}`.

**Sources checked**
- https://pubs.opengroup.org/onlinepubs/9699919799/utilities/V3_chap02.html (POSIX
  2.6.2) — "use of the <colon> in the format shall result in a test for a parameter
  that is unset or null; omission of the <colon> shall result in a test for a parameter
  that is only unset", with the full four-operator behaviour table.
- https://www.gnu.org/software/bash/manual/html_node/Shell-Parameter-Expansion.html —
  "Omitting the colon results in a test only for a parameter that is unset."

**How verified** — reproduced 2026-08-05 in `bash`: with `v=""`, `${v:-tmux}` → `tmux`
while `${v-tmux}` → empty; with `v` unset both → `tmux`.

**Confidence: verified**

## Existing-layer check

**Pages read in full before writing** — `AGENTS.md`, `INDEX.md`, the `testing`,
`databases`, `platforms`, `debugging`, `qa` and `backend/python` domain indexes,
`testing/strategy/test-level-choice`, `testing/data/test-data-and-isolation`,
`databases/query-optimization/existence-and-count-checks`,
`databases/schema-design/requirements-to-tables`, `qa/process/regression-scope`,
`platforms/shells/portable-shell-scripts`, plus the full 135-page inventory.

**Overlaps found, and what was done**

| Existing page | Overlap | Decision |
|---|---|---|
| `testing/strategy/test-level-choice` | Its edge case "logic buried in a controller… extract it" shares the *extraction* remedy | **New page.** Different trigger (import-time I/O, failing at collection) and a different decision set (`importorskip` / module-level skip / `collect_ignore`). Cross-linked both ways |
| `testing/data/test-data-and-isolation` | Owns state leakage between tests | **Not merged.** Import-time coupling is a dependency-surface question, not fixture ownership; the new page hands off to it for the module-singleton case |
| `databases/query-optimization/existence-and-count-checks` | Both discuss `count(*)` | **Not merged.** That page answers "how do I write an existence check cheaply"; the new page answers "what does an empty result prove". No conflict — the `count(*)`-first rule is about evidence, not cost. Cross-linked |
| `databases/schema-design/requirements-to-tables` | Deriving structure from requirements | **Not merged.** Requirements-driven vs data-driven derivation. Cross-linked |
| `qa/process/regression-scope` | Its Integration ring: "test **every** consumer of that contract, not a sample" | **Complementary.** regression-scope says *which* consumers must be tested; the new page says *how to find all of them*. Strongest link in the batch; cross-linked both ways |
| `platforms/shells/portable-shell-scripts` | Mentions `"${OPT:-}"` once, as a `set -u` workaround | **Not merged.** That page's trigger is cross-machine portability; nothing in it covers colon-vs-no-colon semantics or the caller-side override problem. The new page's `set -u` edge case defers to it. Cross-linked |
| `platforms/environment/unicode-text-matching` | Also a "grep returns fewer hits than reality" page | **Distinct and deliberately not linked** — encoding/normalization cause vs call-syntax cause, different domain; a link would create a misleading route |

**Conflicts flagged:** none. No existing directive is contradicted by any of the four.

**Related-links added (both ways):** 12 existing pages gained the new ids —
`testing/strategy/test-level-choice`, `testing/data/test-data-and-isolation`,
`backend/python/language/mutable-state-traps`,
`databases/query-optimization/existence-and-count-checks`,
`databases/schema-design/requirements-to-tables`,
`databases/schema-design/nullability-and-defaults`, `qa/process/regression-scope`,
`testing/quality/checks-that-cannot-pass`, `debugging/methodology/verify-the-fix`,
`platforms/shells/portable-shell-scripts`, `platforms/environment/path-resolution`,
`platforms/processes/non-interactive-cli-invocation`.

## Routing decision

| # | Target page | New category? |
|---|---|---|
| 1 | `testing / strategy / import-time-side-effects` | No |
| 2 | `databases / data-survey / surveying-live-data-for-a-rule` | **Yes — `data-survey`** |
| 3 | `qa / process / enumerating-call-sites-of-a-changed-signature` | No |
| 4 | `platforms / shells / disabling-a-feature-through-an-environment-variable` | No |

**1 — testing/strategy.** The decision this page forces is structural: what level the
test really sits at, and whether the function moves or the whole module gets gated.
`strategy` owns level/structure decisions; `data` owns fixtures and state, which is not
the question.

**2 — databases/data-survey (new category).** Existing categories are `indexing`,
`query-optimization`, `schema-design`, `operations`, `sqlite`, `transactions`. None
covers *reading live data as evidence for a decision*: `query-optimization` is about
cost, `schema-design` derives structure from requirements rather than from rows. Each
was re-checked under its alternative reading before creating the category, per
wiki-ingest step 3. `databases` is the right domain because the artifact queried and
misread is the database. Root `INDEX.md` and the domain index were widened to route in.

**3 — qa/process.** The one judgement call worth the owner's attention. The queue's own
hint was `domain: testing` and the observed failure was 11 broken tests — but the
page's subject is *enumerating what a change touches*, which is
`qa/process/regression-scope`'s question one level lower (a code-level census feeding
its Integration ring). Alternatives considered and rejected: `testing/*` (the practice
governs production call sites too, not test authoring); `testing/quality` (sibling to
the grep-gate pages, but those are about *checks*, not censuses); `debugging` (nothing
is being diagnosed); `backend/common` (the practice is language- and tier-agnostic).
**If you prefer it under `testing`, this is the page to move — say so on review and it
moves with its links.**

**4 — platforms/shells.** Category already exists and the case is squarely shell
semantics. Folding it into `portable-shell-scripts` as an edge-case row was considered
and rejected: that page's trigger is "runs on machine A, fails on machine B", which
does not match "my override was ignored", and one-case-per-page applies.

## Verification of the wiki edit itself

- Body lengths: 56 / 65 / 58 / 58 lines — all under the 120-line cap.
- All `related:` ids across all 135 pages resolve; all inline `[page-id]` refs resolve.
- All `INDEX.md` and domain-index links resolve to existing files.
- No banned vague qualifiers in the new pages.
- `log.md` carries the `## [2026-08-05] ingest | …` entry.
