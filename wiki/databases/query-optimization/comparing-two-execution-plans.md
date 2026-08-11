---
id: databases-query-optimization-comparing-two-execution-plans
domain: databases
category: query-optimization
applies_to: [postgresql]
confidence: verified
sources:
  - https://www.postgresql.org/docs/current/using-explain.html
  - https://www.postgresql.org/docs/current/ddl-partitioning.html
  - https://github.com/postgres/postgres/blob/083ac033419f690758508e08c1736089384bbee8/src/backend/commands/explain.c
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
"the slowness is caused by X" because one arm was far faster, or to publish an
arm's duration when a client-side deadline cut that arm short.

Reading a single plan → [databases-query-optimization-reading-execution-plans].

## Do this

1. **Read the fast arm's plan for `never executed` before attributing anything.**
   PostgreSQL prints ` (never executed)` whenever a node has no instrumentation
   with a positive loop count — under `EXPLAIN (ANALYZE)` on an ordinary plan
   node that means it ran zero times. An arm whose expensive subtree never
   executed did not pay the cost you are comparing against; it is a different
   experiment, not a baseline.
2. **Count the variables that actually moved.** When the arms differ in both
   "the suspected factor X" and "whether rows reached the expensive subtree",
   two hypotheses explain the gap identically — X, and plain row volume. Any
   attribution to X alone is unsupported at that point.
3. **Add a third arm that holds X at the fast arm's setting and makes rows
   flow.** Only the pair that differs in X *with rows flowing in both* attributes
   the difference to X. Record every arm with the **actual row count** its plan
   reports, not a yes/no: the attribution holds only when the two compared arms
   moved comparable row volumes, and a bare "yes" hides an arm that passed ten
   rows against another that passed a million.

| Arm | X | Rows reach the expensive subtree | What it establishes |
|-----|---|----------------------------------|---------------------|
| 1 | fast setting | no | Confounded — reports the cost of skipping, not of X |
| 2 | fast setting | yes | The baseline arm 1 was mistaken for |
| 3 | suspected setting | yes | Compared against arm 2, isolates X |
| 4 | suspected setting | no | Separates "X alone" from "X plus a specific subtree" |

4. **Quote only durations that came from a completed execution.** A ">25 s"
   from a client that gave up is a property of the client's deadline, not of the
   query. Recover the real number by re-running the arm to completion with the
   client deadline removed, and read `now() - query_start` from
   `pg_stat_activity` for that backend while it runs if you need the number
   before it finishes (`query_start` is "Time when the currently active query was
   started").
5. **Check the arms are otherwise equal** — same data, same instance, and the
   caches in the same state — before scoring the gap
   ([databases-query-optimization-reading-execution-plans] covers the warm-cache
   trap).

## Edge cases

| Case | Then |
|------|------|
| You are reading `EXPLAIN (ANALYZE, FORMAT JSON)` or feeding plans to a script | The string `never executed` exists only in TEXT format; JSON/XML/YAML emit `"Actual Loops": 0` instead. Gate the check on `Actual Loops == 0` — that field is emitted unconditionally, while `Actual Total Time` appears only when timing is on, so a parser keyed on the time silently scores a skipped subtree as a 0 ms one |
| You want the cancelled arm's duration from `pg_stat_statements` | It is not there. The view accumulates execution statistics "only for successful operations", so a statement cancelled by the client or by `statement_timeout` contributes nothing to `calls`/`total_exec_time` — a number you do find for that query text came from some *other*, completed run |
| You reach for `auto_explain` instead, to capture the cancelled arm | It has the same blind spot for the same reason: `auto_explain` logs from `explain_ExecutorEnd`, which it installs as `ExecutorEnd_hook`, and a cancelled statement raises `ERROR` before reaching `ExecutorEnd`. Point `auto_explain` at the deadline-free **re-run** instead of at the cancelled arm |
| A duration you did find in `pg_stat_statements` looks plausible | Divide `total_exec_time` by `calls` before comparing; the column is a running total across every completed execution. It is named `total_time` in extension version 1.7 and earlier — which ships with PostgreSQL 12 and earlier, and also persists on a newer server whose extension was never `ALTER EXTENSION pg_stat_statements UPDATE`d |
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
- https://www.postgresql.org/docs/current/ddl-partitioning.html — the one official page that names the marker: "Determining if partitions were pruned during this phase requires careful inspection of the `loops` property in the `EXPLAIN ANALYZE` output. … Some may be shown as `(never executed)` if they were pruned every time." (`using-explain.html` does not mention it)
- https://github.com/postgres/postgres/blob/083ac033419f690758508e08c1736089384bbee8/src/backend/commands/explain.c — `ExplainNode` prints `" (actual time=… rows=… loops=…)"` only under `if (es->analyze && planstate->instrument && planstate->instrument->nloops > 0)`; the `else if (es->analyze)` branch appends `" (never executed)"` in `EXPLAIN_FORMAT_TEXT`, and in every other format emits `Actual Rows` and `Actual Loops` of `0` unconditionally plus `Actual Startup Time`/`Actual Total Time` of `0.0` when `es->timing` is set — so non-text formats carry no such string, and `Actual Loops` is the field always present to test (read at commit `083ac03`, the tip of branch `REL_17_STABLE` at the time — `REL_17_STABLE` is a branch, not a tag, so the URL is pinned to the SHA; lines 1841–1888)
- https://www.postgresql.org/docs/current/pgstatstatements.html — "planning and execution statistics are updated at their respective end phase, and only for successful operations"; the execution columns are `calls`, `total_exec_time`, `mean_exec_time`
- https://www.postgresql.org/docs/current/monitoring-stats.html — `pg_stat_activity.query_start` is "Time when the currently active query was started, or if `state` is not `active`, when the last query was started"
- Field measurement 2026-08-11 (one statement, same data and instance, four arms; X = whether the filter value reached the planner as a literal or as an opaque bound parameter):

| Arm | X | Rows reach the aggregate subqueries | Duration |
|-----|---|-------------------------------------|----------|
| 1 | literal | no — every aggregate subquery printed `never executed` | 37.7 ms |
| 2 | literal | yes | 7,960 ms |
| 3 | opaque | yes | 143,658 ms |
| 4 | opaque | no | 1,859 ms |

  This record keeps only the binary "did rows reach the subqueries", not the per-arm row counts directive 3 asks for — so it supports the qualitative attribution below but not a claim that arms 2 and 3 moved equal volumes. The two-arm reading available at the time was arm 1 vs arm 3 (37.7 ms vs 143,658 ms), which attributed the whole gap to parameter opacity. Arm 4 falsified that: opacity with nothing flowing costs 1,859 ms. The attributable comparison is arm 2 vs arm 3 — same rows flowing, X the only difference — an 18× penalty that appears only once the aggregate subqueries run. Arm 3's duration was first known only as ">25 s" because the client cancelled; it was recovered by re-running the arm without the client deadline, not from `pg_stat_statements`, which held no row for the cancelled execution
