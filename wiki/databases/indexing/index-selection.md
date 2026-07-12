---
id: databases-indexing-index-selection
domain: databases
category: indexing
applies_to: [postgresql, mysql, general]
confidence: verified
sources:
  - https://www.postgresql.org/docs/current/indexes.html
  - https://use-the-index-luke.com/
last_verified: 2026-07-10
related: [databases-indexing-composite-index-column-order, databases-indexing-index-write-cost, databases-query-optimization-reading-execution-plans]
---

# Deciding Whether a Column Needs an Index

## When this applies

You are adding a query the schema wasn't designed for, a query is slow, or you are
designing a new table and choosing initial indexes.

## Do this

1. Collect the actual predicates: `WHERE`, `JOIN ... ON`, `ORDER BY`, `GROUP BY`
   clauses the workload runs. Index for queries, not for tables.
2. Measure selectivity — what fraction of rows does the predicate keep? Read it from
   statistics (PostgreSQL: `most_common_vals`/`most_common_freqs` in `pg_stats`) or a
   direct `SELECT val, count(*) ... GROUP BY 1 ORDER BY 2 DESC` on a replica/sample.

| Case | Do |
|------|----|
| Predicate keeps a small fraction of rows (e.g. lookup by user id, order number) | Index it — this is the primary use case for a B-tree index |
| Predicate keeps a large fraction (e.g. `status = 'active'` where 90% are active), and hot queries filter it with a **literal** on one measured-rare value | Partial index on that rare value ([databases-indexing-partial-and-expression-indexes]) |
| Predicate keeps a large fraction, and the value **varies at runtime** (bind parameter) or several values are queried | Do not index the column alone; place it as a trailing column of a composite index whose leading columns are selective |
| Column is only in `SELECT`, never in predicates | Do not index it for its own sake; include it in a covering index only when a hot query needs it ([databases-indexing-covering-indexes]) |
| Query sorts/paginates on the column with a limit | Index it in the sort order the query uses — an index that satisfies `ORDER BY ... LIMIT` avoids sorting the whole result |
| Foreign key column on the child table | Index it. Joins and parent-side deletes/updates scan the child otherwise (PostgreSQL does not auto-index FK columns; MySQL/InnoDB does) |

3. Verify with an execution plan before and after
   ([databases-query-optimization-reading-execution-plans]). Keep the index only if
   the plan actually uses it under production-like data volume.
4. Before creating, check existing indexes: a new index whose columns are a leftmost
   prefix of an existing composite index is redundant — the existing index already
   serves those queries.

## Edge cases

| Case | Then |
|------|------|
| Table is small (fits in a few pages) | Planner will sequential-scan regardless; skip the index until the table grows |
| Column has few distinct values but you always query one rare value | Partial index on that value beats a full index |
| Text search / `LIKE '%term%'` | B-tree cannot serve infix matches; use a trigram or full-text index type instead of adding a useless B-tree |
| Write-heavy table, marginal read gain | Weigh maintenance cost first ([databases-indexing-index-write-cost]) |
| Creating the index on a large live table | PostgreSQL: `CREATE INDEX CONCURRENTLY` — no long write-block, cannot run inside a transaction, and a failed build leaves an `INVALID` index (drop it, retry). MySQL 8.0: online DDL (`ALGORITHM=INPLACE, LOCK=NONE`) |

## Sources

- https://www.postgresql.org/docs/current/indexes.html — index basics, when indexes are used
- https://use-the-index-luke.com/ — selectivity and index design from real query shapes
