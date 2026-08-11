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

- `https://github.com/postgres/postgres/blob/REL_17_STABLE/src/backend/tcop/postgres.c` — fetched and read directly. `ProcessInterrupts` emits four distinct messages: `"canceling statement due to conflict with recovery"`, `"canceling statement due to lock timeout"`, `"canceling statement due to statement timeout"`, `"canceling autovacuum task"`, and — as the fall-through, guarded by `if (!DoingCommandRead)` — `"canceling statement due to user request"`. Lock timeout uses `ERRCODE_LOCK_NOT_AVAILABLE`; **statement timeout and user request both use `ERRCODE_QUERY_CANCELED` (57014)**, so SQLSTATE cannot separate a server-side timeout from an external cancel and the message text must.
- `https://mybatis.org/mybatis-3/configuration.html` — `defaultStatementTimeout`: "Sets the number of seconds the driver will wait for a response from the database"; valid values "Any positive integer"; default **"Not Set (null)"**.
- `https://github.com/mybatis/mybatis-3/blob/master/src/main/java/org/apache/ibatis/executor/statement/BaseStatementHandler.java` and `.../StatementUtil.java` — fetched and read. `setStatementTimeout` resolves `mappedStatement.getTimeout()`, else `configuration.getDefaultStatementTimeout()`, calls `stmt.setQueryTimeout(queryTimeout)` when either is non-null, then `StatementUtil.applyTransactionTimeout(...)`, which lowers the value to the transaction's remaining time only when that is smaller. **MyBatis therefore bounds a statement with no `ConnectionHolder` in the picture** — the exact contrast with `JdbcTemplate`, whose `DataSourceUtils.applyTimeout` applies the transaction timeout only "if any" and otherwise falls back to a `queryTimeout` defaulting to `-1`.

**Confidence: verified** (framework source read at pinned refs; the measured
durations are field evidence from one production service).

### C2 — a two-arm `EXPLAIN (ANALYZE)` comparison whose fast arm never executed the pipeline

**Claim.** Before attributing a slowdown to factor X from a two-arm plan
comparison, check the fast arm for `never executed`; if its expensive subtree
never ran, X and "did rows flow" both moved and neither is attributable.

**Sources checked.**

- `https://github.com/postgres/postgres/blob/REL_17_STABLE/src/backend/commands/explain.c` — fetched and grepped. The `(actual time=… rows=… loops=…)` line is emitted only under `if (es->analyze && planstate->instrument && planstate->instrument->nloops > 0)`; the `else if (es->analyze)` branch appends `" (never executed)"` **only in `EXPLAIN_FORMAT_TEXT`**, and in other formats emits `Actual Startup Time`/`Actual Total Time` `0.0` and `Actual Rows`/`Actual Loops` `0`. So `never executed` ⟺ `nloops == 0`, and a JSON/YAML-parsing harness sees a 0 ms node rather than the string. (lines ~1841–1888)
- `https://www.postgresql.org/docs/current/using-explain.html` — checked first; it does **not** document `never executed` at all (its only nearby text covers `Subplans Removed` for partition pruning), which is why the page cites the source instead.

**Correction applied to the harvested candidate.** The candidate's directive said
to recover a client-cancelled arm's duration from `pg_stat_statements.total_time`.
That is wrong on two counts and was rewritten before ingest:

- `https://www.postgresql.org/docs/current/pgstatstatements.html` — statistics are updated "at their respective end phase, and **only for successful operations**". A statement cancelled by the client (or by `statement_timeout`) contributes nothing to `calls`/`total_exec_time`. Corroborated by pganalyze ("called from the `ExecutorEnd` hook … no aborted or timed-out query metrics are stored") and by PostgreSQL BUG #14901 "Canceled queries missing from pg_stat_statements".
- The column is `total_exec_time` (with `calls`, `mean_exec_time`); `total_time` is the pre-PostgreSQL-13 name.

The page now directs recovery via re-running without the client deadline,
`pg_stat_activity.query_start` (`https://www.postgresql.org/docs/current/monitoring-stats.html`
— "Time when the currently active query was started"), or `auto_explain`, and
records the `pg_stat_statements` gap as an edge case.

**Confidence: verified** (server source read at a pinned tag; three official doc
pages quoted; the 4-arm timings are field evidence).

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

Also read, from **open PR branches** (these ids do not exist on `main`, so they
are deliberately not in the line above):
`backend-java-jpa-raw-jdbc-inside-a-jpa-transaction` and
`backend-common-reliability-timeouts-and-retries` (PR #73), and PR #52's revision
of `backend-python-language-bytecode-cache-staleness`. The full
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
| C2 — plan-comparison confounding | none. #73 touches `databases/indexing/{index-selection, trigram-index-short-patterns}` only; no open head touches `databases/query-optimization/` | **new** |
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
