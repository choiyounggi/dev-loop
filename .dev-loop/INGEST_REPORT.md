# Knowledge flush — 3 insight(s): 1 ingested, 1 folded into #73, 1 dropped as an in-flight duplicate

## Verified best-practice

### 1. PostgreSQL catalog statistics are not evidence about a table's current contents — **verified** (ingested)

**Claim.** To find the newest rows of a large unindexed table, start the `ctid` tail
scan at `pg_relation_size(rel)/current_setting('block_size')::int`, not at
`pg_class.relpages`; bound the range probe by aggregating (`DISTINCT`/`max`/`count`)
rather than with `LIMIT n`; and read `last_analyze`/`n_mod_since_analyze` before
citing `pg_stats` most-common values as the value set.

Every URL below was opened in this session and the quoted text read out of the
fetched page (they are reproduced verbatim in the page's Sources block):

| Sub-claim | Source | What it says |
|---|---|---|
| `relpages` is a stale snapshot | postgresql.org/docs/current/catalog-pg-class.html | "This is only an estimate used by the planner. It is updated by `VACUUM`, `ANALYZE`, and a few DDL commands such as `CREATE INDEX`"; `reltuples` is `-1` when never vacuumed/analyzed |
| `pg_relation_size` measures actual bytes | postgresql.org/docs/current/functions-admin.html | "Computes the disk space used by one 'fork' … With one argument, this returns the size of the main data fork"; results "measured in bytes" |
| Block size is build-time, not 8192 by law | postgresql.org/docs/current/runtime-config-preset.html | `block_size` "is determined by the value of `BLCKSZ` when building the server. The default value is 8192 bytes" |
| `pg_stats` is a sample from the last analyze | postgresql.org/docs/current/sql-analyze.html | "For large tables, `ANALYZE` takes a random sample of the table contents"; "the statistics are only approximate" |
| Analyze recency is observable | postgresql.org/docs/current/monitoring-stats.html | `last_analyze`, `last_autoanalyze`, `n_mod_since_analyze`, `n_live_tup` definitions |
| ctid = (block, offset), and it moves | postgresql.org/docs/current/datatype-oid.html + ddl-system-columns.html | "A tuple ID is a pair (block number, tuple index within block)"; "a row's `ctid` will change if it is updated or moved by `VACUUM FULL`" |
| Efficient range scans need PG 14+ | postgresql.org/docs/release/14.0/ | "Allow efficient heap scanning of a range of `TIDs` … Previously a sequential scan was required for non-equality `TID` specifications" |

**Field observation carried from the session** (PRD, `external_data.collected_from_seumter`,
read-only): `relpages` 43992 vs `pg_relation_size` 44897 blocks; `ctid > '(43970,0)'
LIMIT 20` returned only `20260619` while `DISTINCT` over `ctid > '(44880,0)'`
returned `20260719`; the `pg_stats` MCV list topped out at `20260427`;
`reltuples` 1,069,782 vs `n_live_tup` 1,092,465.

**Corrections made to the raw candidate during verification** (the candidate is a
draft, not the page): the candidate hard-coded `/8192`, which the `block_size`
preset contradicts → the page divides by `current_setting('block_size')`. The
candidate also stated the tail-scan technique unconditionally; the `ctid` doc's
update/`VACUUM FULL` caveat and the PG14 release note bound it to append-mostly
tables on PG 14+, both now edge-case rows. No local Postgres was available in this
environment (no `psql`, docker daemon down), so the mechanism rests on the official
docs plus the field observation — no reproduction was fabricated.

### 2. A mechanism fixture equal to the shipped default — **verified** (folded into #73)

**Claim.** When a config knob's test fixture repeats the code's default value,
"override honoured" and "override ignored" produce the same output, so
`cfg.get("k", DEFAULT) → DEFAULT` is unkillable by any assertion.

Mechanism is deductive (two paths with an identical observable) and was reproduced
in the field. Evidence opened and re-read in this session rather than taken from the
candidate's prose: `heal/heal_detector.py:30` `RENOTIFY_SEC_DEFAULT = 21600` and
`:225` `renotify = det.get("renotify_sec", RENOTIFY_SEC_DEFAULT)`; the tests now
carry `{"renotify_sec": 100}` (`heal/test_heal_detector.py:420,435`), the post-fix
state the candidate describes. Reported result: at fixture `21600` the
knob-deleting mutant left 36 tests GREEN; at fixture `100`, no assertion changed,
the same mutant went RED in 2 cases. The existing citation base of the target page
(PIT "Survived", Stryker mutator set) already covers the mutation vocabulary used.

### 3. Python bytecode cache invalidates a mutation run — **verified but already carried** (dropped)

The claim (equal-size same-second edits reuse cached bytecode; purge `__pycache__`
and run under `-B`; require a surviving no-op control) is correct and sourced — and
open PR **#52** already carries it in
`backend/python/language/bytecode-cache-staleness`, including the exact nuance the
candidate adds: "Both settings govern writing only … so a `.pyc` left on disk by an
earlier run is still validated and reused … Purge `__pycache__` once before the run
and keep `-B` set for the rest of it", cited to docs.python.org/3/using/cmdline.html.
Nothing in the candidate is absent there.

## Existing-layer check

Routed via `INDEX.md` → databases ("surveying live data to derive a rule") and
testing ("cases/assertions, test data").

Pages read: databases-data-survey-surveying-live-data-for-a-rule,
databases-query-optimization-reading-execution-plans,
databases-operations-autovacuum-and-wraparound,
databases-query-optimization-existence-and-count-checks,
databases-query-optimization-keyset-pagination,
testing-quality-harness-reverse-controls,
backend-python-language-bytecode-cache-staleness,
testing-data-test-data-and-isolation,
testing-quality-tests-that-cannot-fail

Findings:

- **Overlap, kept distinct:** `surveying-live-data-for-a-rule` also deals with
  drawing conclusions from a survey, but its trigger is *empty-result ambiguity*
  when deriving a mapping/enum rule (`GROUP BY` over zero rows). The new page's
  trigger is *stale catalog estimates* standing in for heap contents. Different
  question, different remedy; cross-linked both ways (the existing page's `related:`
  now names the new one).
- **No duplicate found:** `grep` for `degenerate|equal to the default|same as the
  default` across the merged wiki returned nothing; there is no page on catalog
  statistics as an evidence source.
- **No conflicts flagged.** The new page's directives do not contradict any
  directive on the pages read; `reading-execution-plans` is referenced inline for
  the "probe runs against production" edge case.
- **Merged-page edit:** `surveying-live-data-for-a-rule` frontmatter `related:` only
  (no body change).
- Candidate 1's target page (`bytecode-cache-staleness`) was read in both its merged
  and its #52 form — the merged form alone would have justified an append, and the
  #52 form makes even that redundant. That distinction is why the open-PR check
  below, not the merged-layer check, decided this candidate.

## Open-PR check

Listed all 19 open `knowledge/*` heads (`gh pr list --search "head:knowledge/"`) and
took each PR's changed-file list, then fetched and read the heads whose files
overlapped a candidate's trigger space. Note: heads #72–#76 live on the fork
`dch0202-rsquare/dev-loop`, so `git fetch origin <head>` fails on them with
`couldn't find remote ref` — they were fetched from the `fork` remote instead.

| Head (PR) | Overlapping files | Verdict for our candidates |
|---|---|---|
| #52 `…20260807-100149` | `backend/python/language/bytecode-cache-staleness`, `testing/quality/surviving-mutant-equivalence-triage`, `harness-reverse-controls` | **drop** candidate 3 — this branch already carries it, including the `-B`-governs-writing-only row |
| #73 `…co-kr-20260810-163633` | `testing/quality/default-values-under-test` (new page), `tests-that-cannot-fail`, `minimum-case-set` | **fold** candidate 2 — same subject, complementary side; pushed as commit `74215dc` to that branch and noted on the PR |
| #61 `…20260807-213244` | `testing/data/harness-vs-run-path-fixtures`, `harness-reverse-controls`, `test-data-and-isolation` | read in full — its fixture topic is an *absent* operand in a synthesized input, not a value equal to a default; no overlap |
| #49, #47 | `tests-that-cannot-fail`, `harness-reverse-controls` | file-level overlap only; neither touches fixture-vs-default or catalog statistics |
| #74 (`comparing-two-execution-plans`), #73 (`trigram-index-short-patterns`, `index-selection`) | databases pages | read the file lists; no page on catalog statistics or `ctid` scanning — candidate 3's target area is untouched by every open head |
| #76, #72, #69, #68, #66, #64, #62, #58, #57, #56, #55, #51, #50 | none in our trigger space | **new** — no bearing on candidate 1 |

Per-candidate verdicts: **1 new** (catalog statistics), **1 fold** (#73), **1 drop**
(pending duplicate of #52). No sibling duplicate PR was opened for either the folded
or the dropped candidate.

## Routing decision

| Insight | Target | Rationale |
|---|---|---|
| Catalog statistics as current state | `databases` / `data-survey` / `catalog-statistics-as-current-state.md` (new page, existing category) | The task is "survey a live table to establish a fact", which is what `data-survey` owns. `operations` was considered and rejected: that category is about *running* VACUUM/ANALYZE (bloat, wraparound tuning), while this page is about reading their leftovers as evidence. `query-optimization` was rejected because the `ctid` scan here is a probe, not a query being made faster. No new category needed |
| Mechanism fixture vs shipped default | `testing` / `quality` / `default-values-under-test.md` — **on PR #73's branch, not here** | The page is the mirror subject and is still in flight; a second page with an adjacent trigger is exactly the pile-up the flush protocol warns about |
| Python bytecode cache in a mutation harness | none — retired | Already on PR #52 |

Plumbing updated on this branch: `wiki/databases/index.md` (new `data-survey` row
with its load-when line), `log.md` (dated ingest entry recording all three verdicts),
`surveying-live-data-for-a-rule` `related:` back-link. Page body is 93 lines
(limit 120); all four `related:` ids and the one inline `[page-id]` reference were
resolved against `wiki/` before commit.

Cross-Check: the five load-bearing claims of this report were re-verified against
their artifacts rather than from memory — (a) each cited PostgreSQL URL was fetched
in-session and the page's quoted strings match the fetched text; (b) `relpages` vs
`pg_relation_size` semantics come from the catalog doc, not from the candidate's
prose, which was corrected on two points (`/8192`, unbounded applicability);
(c) the #52 duplicate verdict was taken from the branch diff, not from its PR title;
(d) the #73 fold evidence was read out of `heal_detector.py:30,225` and
`test_heal_detector.py:420,435` in the worktree, not copied from the queue row;
(e) every `Pages read:` id was resolved to a file with `grep -rl "^id: …"`. Not
verified: no reproduction of the catalog staleness was run locally — no `psql` and
no running Docker daemon in this environment — so that mechanism rests on the
official docs plus the recorded field observation, and the page says so.
