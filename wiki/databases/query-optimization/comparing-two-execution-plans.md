---
id: databases-query-optimization-comparing-two-execution-plans
domain: databases
category: query-optimization
applies_to: [postgresql]
confidence: verified
sources:
  - https://www.postgresql.org/docs/current/using-explain.html
  - https://github.com/postgres/postgres/blob/REL_17_STABLE/src/backend/commands/explain.c
  - https://www.postgresql.org/docs/current/pgstatstatements.html
  - https://www.postgresql.org/docs/current/monitoring-stats.html
last_verified: 2026-08-11
related:
  [
    databases-query-optimization-reading-execution-plans,
    databases-indexing-index-selection,
    debugging-methodology-hypothesis-testing,
  ]
---

# Attributing a Slowdown to One Variable Across Two Execution Plans

## When this applies

You ran `EXPLAIN (ANALYZE)` on two variants of the same statement — literal vs
bound parameter, index on vs off, filter A vs filter B — and are about to say
"the slowness is caused by X" because one arm was far faster. Also when one arm
was cut short by a client-side deadline and you want to quote its duration.

Reading a single plan → [databases-query-optimization-reading-execution-plans].

## Do this

1. **Read the fast arm's plan for `never executed` before attributing anything.**
   PostgreSQL prints ` (never executed)` for a node whose `nloops` is 0 — the
   node was reached but ran zero times. An arm whose expensive subtree never
   executed did not pay the cost you are comparing against; it is a different
   experiment, not a baseline.
2. **Count the variables that actually moved.** When the arms differ in both
   "the suspected factor X" and "whether rows reached the expensive subtree",
   two hypotheses explain the gap identically — X, and plain row volume. Any
   attribution to X alone is unsupported at that point.
3. **Add a third arm that holds X at the fast arm's setting and makes rows
   flow.** Only the pair that differs in X *with rows flowing in both* attributes
   the difference to X. Record all arms; the row-count column is what makes the
   design auditable.

| Arm | X | Rows reach the expensive subtree | What it establishes |
|-----|---|----------------------------------|---------------------|
| 1 | fast setting | no | Confounded — reports the cost of skipping, not of X |
| 2 | fast setting | yes | The baseline arm 1 was mistaken for |
| 3 | suspected setting | yes | Compared against arm 2, isolates X |
| 4 | suspected setting | no | Separates "X alone" from "X plus a specific subtree" |

4. **Quote only durations that came from a completed execution.** A ">25 s"
   from a client that gave up is a property of the client's deadline, not of the
   query. Recover the real number by one of: re-running the arm to completion
   with the client deadline removed; reading `now() - query_start` from
   `pg_stat_activity` for that backend while it runs (`query_start` is "Time when
   the currently active query was started"); or `auto_explain` with
   `log_min_duration`.
5. **Check the arms are otherwise equal** — same data, same instance, and the
   caches in the same state — before scoring the gap
   ([databases-query-optimization-reading-execution-plans] covers the warm-cache
   trap).

## Edge cases

| Case | Then |
|------|------|
| You are reading `EXPLAIN (ANALYZE, FORMAT JSON)` or feeding plans to a script | The string `never executed` exists only in TEXT format; JSON/XML/YAML emit `"Actual Loops": 0` with times of `0.0` instead. Gate the check on `Actual Loops == 0`, or a parser silently scores a skipped subtree as a 0 ms one |
| You want the cancelled arm's duration from `pg_stat_statements` | It is not there. The view accumulates execution statistics "only for successful operations", so a statement cancelled by the client or by `statement_timeout` contributes nothing to `calls`/`total_exec_time` — a number you do find for that query text came from some *other*, completed run |
| A duration you did find in `pg_stat_statements` looks plausible | Divide `total_exec_time` by `calls` before comparing; the column is a running total across every completed execution, and it is named `total_time` on PostgreSQL 12 and earlier |
| The plan node count differs between arms, not just the timings | The planner chose different shapes; compare the per-node actual times rather than the totals, and treat the shape change itself as the finding |
| Only one arm can be run against production | Run the confounded-arm check anyway — `never executed` is visible in the single plan you have, and it tells you the measurement is not a cost |
| The fast arm's subtree is skipped because a filter genuinely matches nothing in production too | That is a real optimization, not a confound — state it as "fast when the filter is empty", and keep arm 2 to document the non-empty cost |

## Instead of

| If you are about to | Do this instead | Why |
|---------------------|-----------------|-----|
| Conclude "X is the cause" from a two-arm gap of 37 ms vs 143 s | Add the third arm with rows flowing and re-compare | The 37 ms arm may never have run the pipeline; the gap then measures skipping, not X |
| Read a fast plan's small total time as "this plan is efficient" | Scan for `never executed` / `loops=0` first | Zero executions is the cheapest possible plan and tells you nothing about the plan's cost |
| Publish ">25 s" for an arm the client cancelled | Re-run it to completion without the deadline and publish the measured value | A client timeout bounds the number from above; quoting it understates the cost by an unknown amount |
| Fix the filter so rows start flowing, having only ever measured the zero-row case | Measure the rows-flowing cost first | The fix changes which arm production runs; nobody has priced the arm you are about to ship |
| Treat "one variable per experiment" as satisfied because you edited one token | Verify in the plan that only one variable moved | The planner can change a second variable — whether a subtree runs at all — in response to your one edit ([debugging-methodology-hypothesis-testing]) |

## Sources

- https://www.postgresql.org/docs/current/using-explain.html — `EXPLAIN ANALYZE` reports actual row counts and loops per node; plain `EXPLAIN` shows intent only
- https://github.com/postgres/postgres/blob/REL_17_STABLE/src/backend/commands/explain.c — `ExplainNode` prints `" (actual time=… rows=… loops=…)"` only under `if (es->analyze && planstate->instrument && planstate->instrument->nloops > 0)`; the `else if (es->analyze)` branch appends `" (never executed)"` in `EXPLAIN_FORMAT_TEXT` and otherwise emits `Actual Startup Time`/`Actual Total Time` of `0.0` and `Actual Rows`/`Actual Loops` of `0` — so non-text formats carry no such string (read at tag `REL_17_STABLE`, lines ~1841–1888)
- https://www.postgresql.org/docs/current/pgstatstatements.html — "planning and execution statistics are updated at their respective end phase, and only for successful operations"; the execution columns are `calls`, `total_exec_time`, `mean_exec_time`
- https://www.postgresql.org/docs/current/monitoring-stats.html — `pg_stat_activity.query_start` is "Time when the currently active query was started, or if `state` is not `active`, when the last query was started"
- Field measurement 2026-08-11 (one statement, same data and instance, four arms; X = whether the filter value reached the planner as a literal or as an opaque bound parameter):

| Arm | X | Rows reach the aggregate subqueries | Duration |
|-----|---|-------------------------------------|----------|
| 1 | literal | no — every aggregate subquery printed `never executed` | 37.7 ms |
| 2 | literal | yes | 7,960 ms |
| 3 | opaque | yes | 143,658 ms |
| 4 | opaque | no | 1,859 ms |

  The two-arm reading available at the time was arm 1 vs arm 3 (37.7 ms vs 143,658 ms), which attributed the whole gap to parameter opacity. Arm 4 falsified that: opacity with nothing flowing costs 1,859 ms. The attributable comparison is arm 2 vs arm 3 — same rows flowing, X the only difference — an 18× penalty that appears only once the aggregate subqueries run. Arm 3's duration was first known only as ">25 s" because the client cancelled; it was recovered by re-running the arm without the client deadline, not from `pg_stat_statements`, which held no row for the cancelled execution
