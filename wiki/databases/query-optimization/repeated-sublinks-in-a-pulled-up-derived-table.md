---
id: databases-query-optimization-repeated-sublinks-in-a-pulled-up-derived-table
domain: databases
category: query-optimization
applies_to: [postgresql]
confidence: verified
sources:
  - https://www.postgresql.org/docs/current/queries-with.html
  - https://www.postgresql.org/docs/current/queries-limit.html
  - https://www.postgresql.org/docs/current/using-explain.html
  - https://www.postgresql.org/docs/current/sql-select.html
last_verified: 2026-08-18
related:
  [
    databases-query-optimization-reading-execution-plans,
    databases-query-optimization-comparing-two-execution-plans,
    databases-query-optimization-n-plus-one-queries,
    testing-quality-generated-sql-property-assertions,
  ]
---

# A Correlated Subquery in a Derived Table Read by Several Aggregates

## When this applies

A PostgreSQL query computes a per-row value with a correlated subquery in a
derived table's select list — `FROM (SELECT (SELECT … WHERE m.k = b.id ORDER BY …
LIMIT 1) AS v FROM b …) s` — and the outer query reads `s.v` from **two or more**
aggregates or expressions (`bool_or(s.v IS NULL)`, `SUM(s.v)`, `MAX(s.v)`). Also
when a query's runtime is a clean multiple of what one pass over the driving rows
should cost, or when you are writing the comment that claims the subquery "runs
once per row".

## Do this

1. **Count the outer references, then read the plan for that many `SubPlan`
   nodes.** The derived table carries no aggregate, `LIMIT`, `DISTINCT`, or set
   operation, so the planner flattens it into the parent query and substitutes the
   SubLink into each referencing expression, and SubPlans are not
   common-subexpression-eliminated — so N references means N evaluations per driving
   row (measured on PostgreSQL 16.11; re-read the plan on the version you deploy).
   `EXPLAIN (COSTS OFF)` names them `SubPlan 1`, `SubPlan 2`, …, and
   `EXPLAIN (ANALYZE)` shows each with its own `loops=`.

2. **Choose the shape by what the query needs, not by which fence is shortest:**

| Situation | Write it as | Plan you should then see |
|---|---|---|
| The subquery returns one column and the join key is available | `LEFT JOIN LATERAL (SELECT … LIMIT 1) s ON true` | No `SubPlan` at all — a Nested Loop Left Join |
| You must keep the derived-table shape (generated SQL, minimal diff) | Add `OFFSET 0` inside the derived table | One `SubPlan`, evaluated inside the scan |
| The value feeds several later query levels | `WITH s AS MATERIALIZED (…)` | One `SubPlan`, under a `CTE` node |
| The derived table already groups or aggregates | Leave it — `GROUP BY` blocks the flattening by itself | One `SubPlan` |
| The derived table already carries `ORDER BY`, `LIMIT`, or `DISTINCT` | Leave it — each blocks the flattening on its own | One `SubPlan` |

3. **Verify the fence by plan diff, not by reading the SQL.** Capture
   `EXPLAIN (COSTS OFF)` before and after and compare the `SubPlan` count; with
   `ANALYZE`, compare the subquery's `loops=` against the driving row count
   ([databases-query-optimization-comparing-two-execution-plans]).

4. **Write the single-evaluation claim as a plan citation.** A comment that says
   "evaluated once per row" is only true of a plan, so record the `EXPLAIN` output
   (or the `SubPlan` count assertion) next to the claim — the SQL text is identical
   in both the fenced and unfenced versions.

## Edge cases

| Case | Then |
|------|------|
| The derived table is written as a plain `WITH` clause instead | It is still folded — the documentation folds a non-recursive, side-effect-free `WITH` referenced once — so the duplication survives the rewrite; add `MATERIALIZED` to get the fence |
| The subquery is cheap and the driving set is small | Keep the fence anyway when the reference count can grow: each new aggregate over `s.v` adds a full extra evaluation per row, and nothing in review flags it |
| The fence costs you a pushed-down predicate | Measure both plans and compare where the filter runs. The documented no-push-down rule covers multiply-referenced `WITH` queries; that it extends to `OFFSET 0` and `MATERIALIZED` here is inferred from the same barrier and was not measured on this page, so treat the plan diff as the evidence |
| The value is expensive and needed by many aggregates over a large set | Prefer the `LATERAL` join over any fence — it removes the SubPlan rather than deduplicating it, so the planner can pick a join strategy and use indexes on the inner relation |
| A test asserts on the generated SQL string | That test cannot see this at all — the rendered text is byte-identical with and without pull-up; pin the property in the plan, and see [testing-quality-generated-sql-property-assertions] for what string assertions can and cannot hold |

## Instead of

| If you are about to | Do this instead | Why |
|---------------------|-----------------|-----|
| Assume a derived-table column is computed once because it is written once | Count `SubPlan` nodes in `EXPLAIN (COSTS OFF)` | The flattening substitutes the SubLink per reference; measured on PostgreSQL 16.11 as 1/2/3 `SubPlan` nodes for 1/2/3 outer references |
| Wrap the subquery in a plain CTE to "materialize" it | Write `WITH … AS MATERIALIZED`, or `OFFSET 0` in the derived table | A plain `WITH` is folded by default, so the plain-CTE rewrite reproduced the same two `SubPlan` nodes |
| Add `LIMIT` inside the derived table to block pull-up | Use `OFFSET 0` | `OFFSET 0` is documented as semantically a no-op, so it fences without changing which rows the query returns |
| Trust a wall-clock comparison on a small dev dataset | Read `loops=` on the subquery node | Doubling a cheap subquery is invisible in wall clock at five rows and linear in production volume |

## Sources

- https://www.postgresql.org/docs/current/queries-with.html — "if a `WITH` query is non-recursive and side-effect-free … then it can be folded into the parent query"; "By default, this happens if the parent query references the `WITH` query just once"; "You can override that decision by specifying `MATERIALIZED` to force separate calculation of the `WITH` query"; and, for multiply-referenced `WITH` queries, "the optimizer is not able to push restrictions from the parent query down"
- https://www.postgresql.org/docs/current/queries-limit.html — "`OFFSET 0` is the same as omitting the `OFFSET` clause, as is `OFFSET` with a NULL argument" — the basis for using it as a semantics-preserving fence
- https://www.postgresql.org/docs/current/using-explain.html — `EXPLAIN ANALYZE` reports actual row counts and `loops` per plan node, which is how the per-row evaluation count is read
- PostgreSQL source, `src/backend/optimizer/prep/prepjointree.c` — `is_simple_subquery()` holds the pull-up predicate that `LIMIT`/`OFFSET`, `ORDER BY`, aggregates/`GROUP BY`, `DISTINCT` and set operations fail; cited for where the rule lives, with the behaviour below measured rather than quoted
- Local reproduction 2026-08-18 (PostgreSQL 16.11, Homebrew, throwaway cluster; 5 driving rows): unfenced derived table read by `bool_or` + `sum` → `SubPlan 1` and `SubPlan 2`, each `loops=5` (10 evaluations); same query with `OFFSET 0` → one `SubPlan`, `loops=5`; `WITH … AS MATERIALIZED` → one `SubPlan` under a `CTE` node; plain `WITH` → two `SubPlan` nodes; `LEFT JOIN LATERAL` → no `SubPlan`, a Nested Loop Left Join; derived table with `GROUP BY` → one `SubPlan`; derived table with `ORDER BY` → one `SubPlan`; 1/2/3 outer references → 1/2/3 `SubPlan` nodes
