---
id: databases-indexing-index-write-cost
domain: databases
category: indexing
applies_to: [postgresql, mysql, general]
confidence: verified
sources:
  - https://www.postgresql.org/docs/current/indexes.html
  - https://use-the-index-luke.com/
last_verified: 2026-07-10
related: [databases-indexing-index-selection, databases-indexing-covering-indexes]
---

# Budgeting Index Maintenance Cost

## When this applies

You are adding an index to a write-heavy table, auditing a table that accumulated
many indexes, or a bulk load / high-ingest path is slower than expected.

## Do this

1. Price the index before creating it: every `INSERT` and every `UPDATE` touching an
   indexed column must update each such index; each index also adds storage and
   vacuum/purge work. An index used by no query is pure cost.
2. Decide with the read/write balance:

| Case | Do |
|------|----|
| Hot read path, modest write rate | Create the index; reads repay it |
| High-ingest table (events, logs, metrics) | Keep the index set minimal: PK plus the one or two access paths actually queried. Aggregate or replicate to a read-optimized store for ad-hoc analytics |
| Bulk load into an indexed table | Load first, index after: create indexes when the load finishes; for recurring loads, drop-and-recreate secondary indexes around the load when the table is offline to readers |
| Existing table, suspect unused indexes | Measure usage (PostgreSQL: `pg_stat_user_indexes.idx_scan`; MySQL: `sys.schema_unused_indexes`), then drop indexes with zero scans after a full business cycle of observation |

3. In PostgreSQL, prefer keeping frequently-updated columns **out** of indexes:
   updates to non-indexed columns can use HOT (heap-only tuple) updates and skip
   index maintenance entirely; indexing a hot-updated column forfeits that.

## Edge cases

| Case | Then |
|------|------|
| Index is unused but enforces uniqueness or backs a FK | Keep it — correctness indexes are not judged by scan counts |
| Duplicate indexes (same leading columns) | Drop the narrower one after confirming the wider one serves its queries |
| Dropping an index in production | Use `DROP INDEX CONCURRENTLY` (PostgreSQL) / online DDL (MySQL), after checking replicas and scheduled jobs that might depend on it |

## Instead of

| If you are about to | Do this instead | Why |
|---------------------|-----------------|-----|
| Add an index per slow query as a reflex | Check whether an existing index can serve it with a rewrite or column-order change | Index sprawl taxes every write forever; a redundant index helps nothing |

## Sources

- https://www.postgresql.org/docs/current/indexes.html — maintenance overhead of indexes
- https://use-the-index-luke.com/ — write-side cost of indexing
