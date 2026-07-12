---
id: databases-query-optimization-reading-execution-plans
domain: databases
category: query-optimization
applies_to: [postgresql, mysql]
confidence: verified
sources:
  - https://www.postgresql.org/docs/current/using-explain.html
  - https://dev.mysql.com/doc/refman/8.0/en/explain-output.html
last_verified: 2026-07-10
related: [databases-indexing-index-selection, databases-query-optimization-large-in-lists]
---

# Diagnosing a Query with Its Execution Plan

## When this applies

A query is slow, or you changed a query/index and must verify the change works
before shipping it.

## Do this

1. Get the **executed** plan, not just the estimate: PostgreSQL
   `EXPLAIN (ANALYZE, BUFFERS)`, MySQL `EXPLAIN ANALYZE`. Plain `EXPLAIN` shows
   intent only; mismatches between estimate and reality are themselves the clue.
2. Read bottom-up / innermost-first; find the node consuming the most actual time.
3. Match symptom to action:

| Plan symptom | Do |
|--------------|----|
| Seq/full scan on a large table with a selective predicate | Add or fix the index for that predicate ([databases-indexing-index-selection]) |
| Index scan, but `rows` estimate is off from actual by orders of magnitude | Refresh statistics (`ANALYZE` / `ANALYZE TABLE`); for correlated columns add extended statistics (PostgreSQL `CREATE STATISTICS`) |
| Sort node feeding a small `LIMIT` | Give the sort an index in query order ([databases-indexing-composite-index-column-order]) |
| Nested loop with a huge inner-side row count | Check join-key indexes; if estimates are wrong fix statistics first — join order follows estimates |
| High `Heap Fetches` on an Index Only Scan | Vacuum/visibility problem ([databases-indexing-covering-indexes]) |
| Hash join spilling (`Batches > 1` in PostgreSQL) | Reduce the joined row set earlier (filter pushdown) or raise `work_mem` for that query, in that order |

4. Re-run the plan after each change; keep exactly the changes that moved actual time.

## Edge cases

| Case | Then |
|------|------|
| Query is fast in a re-run but slow first time | You are measuring a warmed cache. Judge with `BUFFERS` read counts (not just ms), and reproduce cold behavior on a different data slice before declaring it fixed |
| Plan differs between parameter values | Skewed data: one plan per value class. Test with production-representative parameters, worst class included |
| `EXPLAIN ANALYZE` on writes (`INSERT/UPDATE/DELETE`) | It executes them. Wrap in `BEGIN; ... ROLLBACK;` |
| Production incident, can't run ANALYZE variants freely | Capture the live plan via `pg_stat_statements` / slow query log + `auto_explain` instead of experimenting on prod |

## Sources

- https://www.postgresql.org/docs/current/using-explain.html — reading EXPLAIN/EXPLAIN ANALYZE
- https://dev.mysql.com/doc/refman/8.0/en/explain-output.html — MySQL plan columns
