---
id: databases-query-optimization-large-in-lists
domain: databases
category: query-optimization
applies_to: [postgresql, mysql]
confidence: verified
sources:
  - https://www.postgresql.org/docs/current/functions-comparisons.html
  - https://www.postgresql.org/docs/current/sql-values.html
last_verified: 2026-07-10
related: [databases-query-optimization-reading-execution-plans, databases-query-optimization-n-plus-one-queries]
---

# Queries with Large IN Lists

## When this applies

Application code builds `WHERE col IN (v1, v2, ..., vN)` where N can grow beyond a
few dozen — batch lookups, "fetch by ids" endpoints, sync jobs.

## Do this

| Case | Do |
|------|----|
| N is small and bounded (≤ ~100) by construction | Plain `IN` list with bound parameters is fine; PostgreSQL: prefer `= ANY(:array)` with one array parameter — one prepared statement regardless of N |
| N is large or unbounded (hundreds+) | Join against a relation instead of a literal list: PostgreSQL `JOIN unnest(:array) AS t(id) ON ...` or `JOIN (VALUES ...) v(id) ON ...`; MySQL: load ids into a temporary table and join. The planner gets cardinality and can hash-join |
| N comes from another query you just ran | Push it back into SQL: replace fetch-then-IN with a join or subquery on the original condition — the list never leaves the database |
| Ids arrive in huge batches (10k+) from outside | Chunk into fixed-size batches (e.g. 1k–5k per statement) processed in a loop, sized against statement/packet limits and lock duration |

Always verify the plan at a realistic N ([databases-query-optimization-reading-execution-plans]) —
plans that look fine at N=10 can flip to sequential scans at N=10,000.

## Edge cases

| Case | Then |
|------|------|
| Each distinct N compiles a new statement (`IN (?, ?, ?)`) | Statement-cache churn in the driver/ORM; fix by using the array/`ANY` form or padding list sizes to fixed steps |
| `NOT IN (subquery)` and the subquery can yield NULL | `NOT IN` with any NULL matches nothing — silently empty results. Use `NOT EXISTS`, which has the intended semantics |
| Duplicate values in the list | Deduplicate before binding; duplicates inflate work and, in join-form rewrites, multiply rows |
| List crosses a partitioned table | Confirm the plan prunes partitions per value; if not, group values by partition key in the application |

## Instead of

| If you are about to | Do this instead | Why |
|---------------------|-----------------|-----|
| Interpolate ids into the SQL string | Bind an array parameter (`= ANY(:array)`) or use a values join | String interpolation breaks the plan cache and is an injection vector |
| Raise N without limit because "it worked in staging" | Chunk with a fixed batch size and test at production N | Statement size, parse time, and lock duration all scale with N |

## Sources

- https://www.postgresql.org/docs/current/functions-comparisons.html — `IN` / `= ANY(array)` semantics
- https://www.postgresql.org/docs/current/sql-values.html — VALUES lists as relations
