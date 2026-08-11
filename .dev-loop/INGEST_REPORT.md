# Knowledge flush — 3 insight(s)

Queue drained: 3 pending candidates from 2 session files
(`ab5516dc-…` ×2, `f0eef7c4-…` ×1). Outcome: **1 ingested here, 2 folded into
open PRs**, so this PR carries a single new page.

## Verified best-practice

### C1 — attributing a query cancellation to the access-technology layer that emitted it

**Claim.** `ERROR: canceling statement due to user request` does not name its
sender; identify the layer by matching the statement's measured duration against
each timeout configured in the application, and read a duration that matches no
configured value *and* varies run to run as "no timeout applies on this path".

**Sources checked and what they establish.**

- `https://github.com/postgres/postgres/blob/083ac033419f690758508e08c1736089384bbee8/src/backend/tcop/postgres.c` — fetched and read directly. `ProcessInterrupts` emits four cancellation messages: `"canceling statement due to lock timeout"`, `"canceling statement due to statement timeout"`, `"canceling autovacuum task"`, and — as the fall-through, guarded by `if (!DoingCommandRead)` — `"canceling statement due to user request"`. (`"canceling statement due to conflict with recovery"` is *not* one of them: it is emitted by `ProcessRecoveryConflictInterrupt` with `ERRCODE_T_R_SERIALIZATION_FAILURE`.) Lock timeout uses `ERRCODE_LOCK_NOT_AVAILABLE`; **statement timeout and user request both use `ERRCODE_QUERY_CANCELED` (57014)**, so SQLSTATE cannot separate a server-side timeout from an external cancel and the message text must.
- `https://mybatis.org/mybatis-3/configuration.html` — `defaultStatementTimeout`: "Sets the number of seconds the driver will wait for a response from the database"; valid values "Any positive integer"; default **"Not Set (null)"**.
- `https://github.com/mybatis/mybatis-3/blob/master/src/main/java/org/apache/ibatis/executor/statement/BaseStatementHandler.java` and `.../StatementUtil.java` — fetched and read. `setStatementTimeout` resolves `mappedStatement.getTimeout()`, else `configuration.getDefaultStatementTimeout()`, calls `stmt.setQueryTimeout(queryTimeout)` when either is non-null, then `StatementUtil.applyTransactionTimeout(...)`, which — given a non-null transaction timeout — lowers the statement to it whenever `queryTimeout` is `null`, is `0` (JDBC's "no limit" sentinel), or exceeds the transaction's remaining time. **MyBatis therefore bounds a statement with no `ConnectionHolder` in the picture** — the exact contrast with `JdbcTemplate`, whose `DataSourceUtils.applyTimeout` applies the transaction timeout only "if any" and otherwise falls back to a `queryTimeout` defaulting to `-1`.

**Confidence: verified** (framework source read from the actual files and now
cited by commit SHA — `REL_17_STABLE` is a *branch*, not a tag, and the MyBatis
files were first read at `master`, so the citations were re-pinned to
`083ac03` / `273ec65` after the cross-check flagged the "pinned" wording as
false; the measured durations are field evidence from one production service).

### C2 — a two-arm `EXPLAIN (ANALYZE)` comparison whose fast arm never executed the pipeline

**Claim.** Before attributing a slowdown to factor X from a two-arm plan
comparison, check the fast arm for `never executed`; if its expensive subtree
never ran, X and "did rows flow" both moved and neither is attributable.

**Sources checked.**

- `https://github.com/postgres/postgres/blob/083ac033419f690758508e08c1736089384bbee8/src/backend/commands/explain.c` (lines 1841–1888) — fetched and grepped. The `(actual time=… rows=… loops=…)` line is emitted only under `if (es->analyze && planstate->instrument && planstate->instrument->nloops > 0)`; the `else if (es->analyze)` branch appends `" (never executed)"` **only in `EXPLAIN_FORMAT_TEXT`**, and in other formats emits `Actual Rows`/`Actual Loops` of `0` **unconditionally** plus `Actual Startup Time`/`Actual Total Time` of `0.0` **only when `es->timing`**. Two consequences the page now states precisely: the marker is not a biconditional on `nloops == 0` (that `else if` also fires when `planstate->instrument` is NULL), and a JSON/YAML harness must key on `Actual Loops == 0` rather than on the time, which may be absent.
- `https://www.postgresql.org/docs/current/using-explain.html` — checked; it does **not** document `never executed` at all (its only nearby text covers `Subplans Removed` for partition pruning).
- `https://www.postgresql.org/docs/current/ddl-partitioning.html` — the one official page that does name it, found via the cross-check: "Some may be shown as `(never executed)` if they were pruned every time." Added to the page's sources so the claim rests on docs as well as on C source.

**Correction applied to the harvested candidate.** The candidate's directive said
to recover a client-cancelled arm's duration from `pg_stat_statements.total_time`.
That is wrong on two counts and was rewritten before ingest:

- `https://www.postgresql.org/docs/current/pgstatstatements.html` — statistics are updated "at their respective end phase, and **only for successful operations**". A statement cancelled by the client (or by `statement_timeout`) contributes nothing to `calls`/`total_exec_time`. Corroborated by pganalyze ("called from the `ExecutorEnd` hook … no aborted or timed-out query metrics are stored") and by PostgreSQL BUG #14901 "Canceled queries missing from pg_stat_statements".
- The column is `total_exec_time` (with `calls`, `mean_exec_time`); `total_time` is the pre-PostgreSQL-13 name.

**Second correction, from the adversarial cross-check.** The rewrite initially
offered `auto_explain` as a third recovery route. That is false for the same
reason: `contrib/auto_explain/auto_explain.c` installs `explain_ExecutorEnd` as
`ExecutorEnd_hook` (line 255) and logs only inside that function (lines 368–389),
so a statement cancelled mid-execution raises `ERROR` and never reaches
`ExecutorEnd` — the page would have offered, as an alternative to re-running, a
tool that only works if you re-run. Verified independently by reading
`auto_explain.c` from a local clone of `postgres/postgres` at `083ac03`.

The page now directs recovery via re-running without the client deadline, with
`pg_stat_activity.query_start` (`https://www.postgresql.org/docs/current/monitoring-stats.html`
— "Time when the currently active query was started") for reading the number
mid-flight, and records **both** the `pg_stat_statements` and the `auto_explain`
blind spots as edge cases pointing at the shared `ExecutorEnd` cause.

**Confidence: verified** (server source read from the file and cited by commit
SHA `083ac03`; four official doc pages quoted; the 4-arm timings are field
evidence, and the page states explicitly that the field record kept only a
binary "did rows flow", not per-arm row counts).

### C3 — a mutation harness whose restore step re-stamps the original mtime

**Claim.** A byte-length-preserving mutation restored with `shutil.copy2` leaves
CPython's `(mtime, size)` cache key unchanged, so a subsequent run loads the
previous iteration's bytecode.

**Sources checked.**

- `https://docs.python.org/3/library/shutil.html` — `copyfile` copies "the contents (no metadata)"; `copy` copies data and permission mode, and "Other metadata, like the file's creation and modification times, is not preserved"; `copy2` is "Identical to `copy()` except that `copy2()` also attempts to preserve file metadata" and "uses `copystat()` to copy the file metadata". So `copy2` is precisely the mtime-restoring member of the family.
- The underlying `(mtime, size)` invalidation mechanism was already verified and cited on the existing wiki page (`docs.python.org/3/reference/import.html`, PEP 552, `py_compile`), including a 2026-08-04 local reproduction.

**Confidence: verified** for the `shutil` behaviour (official docs);
**field-tested** for the batch-vs-solo GREEN/RED reproduction.

## Existing-layer check

Routed via `INDEX.md` → `databases` (the artifact under change is a SQL
statement and its plan) with a cross-read of `backend` and `debugging`.

Pages read: databases-query-optimization-reading-execution-plans, backend-python-language-bytecode-cache-staleness, debugging-methodology-hypothesis-testing

Also read, from **open PR branches**, and therefore deliberately not in the line
above (the gate resolves that line against this checkout):
`backend-java-jpa-raw-jdbc-inside-a-jpa-transaction`, which PR #73 *adds* and
which does not exist on `main`; `backend-common-reliability-timeouts-and-retries`,
which does exist on `main` and which #73 modifies; and PR #52's revision of
`backend-python-language-bytecode-cache-staleness`. The full
`wiki/databases/index.md` and the merged `wiki/qa/` page list were scanned for
category fit.

**Overlaps and what was done.**

| Existing page | Overlap with | Resolution |
|---|---|---|
| `databases-query-optimization-reading-execution-plans` | C2 | **Adjacent, not duplicate** — it covers reading *one* plan (warm cache, skewed parameters, plan on writes). It has no `never executed` content and no two-arm attribution content. Per one-case-per-page it stays as-is; added a `related:` link and one edge-case row routing onward, and the new page links back |
| `debugging-methodology-hypothesis-testing` | C2 | **Adjacent** — it states the general "change exactly one variable per experiment" rule. C2 is the non-obvious database instance where the planner moves a *second* variable in response to your one edit. Cited from the new page's `Instead of`; no conflict |
| `backend-python-language-bytecode-cache-staleness` | C3 | **Covered** — the mechanism, equal-size mutations, cache purge, mtime bump and the uniform-verdict harness failure are all already there. Only `shutil.copy2` was missing from its mtime-preserving list. Folded (see below) |

**Conflicts flagged:** none. Nothing in the merged layer contradicts these
directives.

**Related links added both ways:** `reading-execution-plans` ⇄
`comparing-two-execution-plans`.

One link the new page originally carried,
`qa-deliverables-quantitative-claims-in-a-published-document`, was **removed**:
it exists only on PR #51 and would have been dangling on `main`.

## Open-PR check

Listed with
`gh pr list --repo choiyounggi/dev-loop --state open --search "head:knowledge/"`
→ **17 open heads** (#73, #72, #69, #68, #66, #64, #62, #61, #58, #57, #56, #55,
#52, #51, #50, #49, #47). Four are fork heads, so each was fetched as
`refs/pull/<n>/head` and diffed against `origin/main` over `wiki/`.

| Candidate | Overlapping head | Verdict |
|---|---|---|
| C1 — query-timeout layer attribution | **#73** `backend/java/jpa/raw-jdbc-inside-a-jpa-transaction.md` — same production incident, carrying the *same* measured durations (10,012 / 151,558 / 163,489 ms) | **fold** |
| C2 — plan-comparison confounding | none. #73 touches `databases/indexing/{index-selection, trigram-index-short-patterns}` and `databases/index.md`; no open head touches `databases/query-optimization/` | **new** |
| C3 — mutation harness bytecode staleness | **#52** `backend/python/language/bytecode-cache-staleness.md` | **fold** |

**Folds pushed** (both heads are on this account's fork, so the additions land on
the branch under review rather than as a sibling PR):

- → **#73** `knowledge/dch0202-rsquare-co-kr-20260810-163633`, commit *"knowledge: fold MyBatis timeout layer + duration fingerprinting into raw-jdbc page"* (+12/−1). Adds three edge-case rows (MyBatis as a third access technology bounded independently of the holder chain; duration-fingerprinting against configured values; `user request` vs `statement timeout` sharing SQLSTATE 57014), one `Instead of` row, three sources and the 120,010 ms MyBatis measurement. Body 91 → 99 lines (limit 120).
- → **#52** `knowledge/dch0202-rsquare-20260807-100149`, commit *"knowledge: fold shutil.copy2 mtime-restore case into bytecode-cache-staleness"* (+5/−1). Adds the `shutil.copy2` edge-case row with the `copyfile`/`os.utime` replacement, the `shutil` source, and the batch-vs-solo reproduction. Body 63 → 66 lines.

No sibling duplicate PR was opened for either.

## Routing decision

| Insight | Target | Rationale |
|---|---|---|
| C2 | **`databases` / `query-optimization`** → new page `comparing-two-execution-plans.md` (id `databases-query-optimization-comparing-two-execution-plans`) | The artifact under change is a SQL statement and its plan, so `databases` owns it over `debugging`. `query-optimization` already holds `reading-execution-plans`; the new case — attributing a difference *between two plans* — is a distinct trigger from reading one plan, so `AGENTS.md` rule 1 (one case per page) makes it a new page rather than a merge |
| C1 | PR #73, `backend` / `jpa` | Folded; its trigger ("one endpoint's slow queries are cancelled at N seconds through some paths and run for minutes through others") is already that page's stated trigger |
| C3 | PR #52, `backend` / `language` | Folded; same trigger, same directive, one missing concrete |

**No new category was created.** `query-optimization` covers the case; `databases/index.md`
gained the routing line, and `log.md` gained one `ingest` and one `dedup` entry.

Page checks on the new page: 84 body lines (limit 120); no banned vague
qualifiers in directives; all `related:` ids and inline `[page-id]` references
resolve against this checkout.

## Cross-Check

Cross-Check: independent adversarial review (headless `claude` CLI, separate
process, instructed to refute and to verify every claim against primary sources)
returned **BLOCK** on the first pass and its findings were applied in full before
this PR was opened.

The reviewer had no network tools available, so it verified by blobless shallow
clone and read from disk — `postgres/postgres` @ `083ac033`, `mybatis/mybatis-3`
@ `273ec650`, `python/cpython` @ `219768ff`, plus PostgreSQL's own
`doc/src/sgml/` sources and `REL_12_STABLE`/`REL_13_STABLE` for the version
boundary. That is a stronger substrate than the WebFetch summaries used on the
first pass, and it is what caught the `es->timing` guard.

What it confirmed: the `never executed` mechanism, the `pg_stat_statements`
successful-operations-only rule, the `total_time` → `total_exec_time` boundary at
PostgreSQL 13, the shared SQLSTATE 57014, the MyBatis precedence chain, the
`shutil` metadata semantics, the 18.05× arithmetic, zero dangling page ids, and
every mechanical `AGENTS.md` rule.

What it broke, and what changed as a result:

| Finding | Fix |
|---|---|
| **HIGH** — `auto_explain` cannot capture a cancelled statement (ExecutorEnd-only), yet the page recommended it | Removed from directive 4; added an edge-case row naming the shared `ExecutorEnd` cause |
| **BLOCK** — the `es->timing` correction was still uncommitted; `HEAD` carried the wrong wording | Committed; the Sources bullet and the JSON edge case now both state the guard |
| **BLOCK** — "pinned tag"/"pinned refs" claimed for `REL_17_STABLE` (a branch) and `master` | All citations I added re-pinned to commit SHAs, here and on both fold branches |
| **MEDIUM** — directive 3 demanded a "row-count column" neither table has | Directive now asks for actual row counts and says why; the field table states plainly that it kept only the binary |
| **MEDIUM** — fold-52's new row prescribed `os.utime`, which the same page shows is insufficient | Row now routes to the strong remedy (hash-based `.pyc` / unconditional purge) |
| **MEDIUM** — `⟺ nloops == 0` overstated (the branch also fires when `instrument` is NULL) | Weakened in the page, in `log.md`, and here |
| **LOW** — a better official source for `never executed` existed | `ddl-partitioning.html` added to sources |
| **LOW** — fold-73's frontmatter omitted `StatementUtil.java`; the narrowing description dropped the `null`/`0` arms | Both fixed on that branch |
| **LOW** — three overstatements in this report ("four messages" listing five, "only" for #73's files, an id wrongly said to be absent from `main`) | All three corrected above |

Not fixed, and why: `raw-jdbc-inside-a-jpa-transaction.md` cites pgjdbc at
`blob/master/`. That citation is pre-existing content of PR #73, not part of this
fold, so it is left for that PR's own review rather than rewritten here.

The reviewer had no network, so it could not check the 17-open-head list or the
fold pushes. Those were re-verified with `gh` on the pass that opened this PR:
`gh pr list --state open` returns exactly **17** `knowledge/*` heads; a per-PR
file scan of every open PR returns **no** head touching
`databases/query-optimization/`, so C2's `new` verdict holds; and both fold heads
carry their fix commits on the fork
(`…-20260810-163633` = `b3e7d3b`, `…-20260807-100149` = `b71d931`).

**One defect found on that pass and fixed here.** `log.md`'s new `ingest` entry
still ended its recovery list with "or `auto_explain`" — the exact claim the
HIGH finding removed from the page — while the same entry went on to explain
that `auto_explain` shares the `ExecutorEnd` blind spot. A reader of the log
would have taken the retracted advice. The clause now names only the two working
routes. Independently re-confirmed before the fix: `auto_explain.c` at `083ac03`
has its single `ereport` (line 431) inside `explain_ExecutorEnd`, which is the
last function in the file, so there is no non-`ExecutorEnd` logging path.

## Decision Log

**Intent.** Drain the three queued `★ Insight` candidates into the wiki as one
reviewed PR, with the open-PR check applied first so that sibling flushes do not
pile up duplicate pages (the failure mode recorded in #39 and in the #17–#40 and
#42/#43 consolidations).

**Decisions and the alternatives rejected.**

| Decision | Alternative rejected | Why |
|---|---|---|
| C2 becomes a **new page** in `databases/query-optimization` | Merge into `reading-execution-plans` | `AGENTS.md` rule 1: that page's case is reading *one* plan; attributing a difference between *two* is a separate trigger. Merging would have pushed a 60-line page past its case boundary |
| C1 and C3 **folded** into #73 and #52 instead of ingested here | Ingest here as new pages | #73 carries the same production incident with the identical measured durations, and #52 already carries the `(mtime, size)` mechanism. A sibling page would have been the exact duplicate this skill's step 2b′ exists to prevent |
| Folds **pushed to the branches under review** | Leave a comment on each PR listing the additions | Both heads are on this account's fork, so the additions can land where the reviewer is already looking; each is a separate, self-describing commit on top of the existing head, so it can be dropped independently |
| Kept the harvested candidate's *trigger* but **rewrote its directive** on `pg_stat_statements` | Ingest the candidate as written | The candidate's recovery instruction is false against the official docs. `[추정]` — the harvested number was most likely recovered from a later completed run and mis-attributed to the cancelled one at write-up time |
| `related:` to `qa-deliverables-quantitative-claims-in-a-published-document` **removed** | Keep it, since PR #51 adds that page | It does not exist on `main`; if #51 is rejected or renamed the link dangles. Cross-PR links wait until the target merges |
| Field table keeps a **binary** rows-flowed column, with the limitation stated | Reconstruct plausible row counts | The counts were not recorded. Stating the gap is honest; inventing them would fabricate evidence in a page about not over-claiming from measurements |

**Where a reviewer should look hardest.**

1. `comparing-two-execution-plans.md` directive 4 and the two `ExecutorEnd` edge-case rows — this is the part that was wrong twice and rewritten twice.
2. Whether C2 really deserves its own page rather than living in `reading-execution-plans` (the one `AGENTS.md` judgment call here).
3. The two fold commits on #73 and #52 — they change PRs that are already in your review queue: `b3e7d3b` on #73, `b71d931` on #52.

