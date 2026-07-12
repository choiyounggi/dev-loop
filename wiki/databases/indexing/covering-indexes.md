---
id: databases-indexing-covering-indexes
domain: databases
category: indexing
applies_to: [postgresql, mysql]
confidence: verified
sources:
  - https://www.postgresql.org/docs/current/indexes-index-only-scans.html
  - https://dev.mysql.com/doc/refman/8.0/en/innodb-index-types.html
last_verified: 2026-07-10
related: [databases-indexing-composite-index-column-order, databases-indexing-index-write-cost]
---

# Covering Indexes and Index-Only Scans

## When this applies

A hot query is already served by an index for its predicates, but the plan still
visits the table (heap) for every matched row to fetch selected columns — and that
heap access dominates the cost.

## Do this

1. Confirm the symptom in the plan: an Index Scan with high buffer/page reads, on a
   query selecting few columns beyond the indexed ones.
2. Make the index cover the query:

| Engine | Do |
|--------|----|
| PostgreSQL 11+ | Keep key columns as-is and append payload columns with `INCLUDE (col, ...)` — they are stored in the leaf, not part of the key, so they don't bloat ordering or uniqueness semantics |
| PostgreSQL < 11 | Append payload columns as trailing key columns |
| MySQL/InnoDB | Append payload columns as trailing key columns; secondary indexes also implicitly contain the PK columns, so `SELECT pk, key_cols` is already covered |

3. Verify the plan now shows `Index Only Scan` (PostgreSQL) / `Using index` in
   `Extra` (MySQL), and that reads dropped.
4. Re-check the trade: every covered column added makes the index larger and every
   write to that column now touches the index ([databases-indexing-index-write-cost]).
   Cover only queries measured to be hot.

## Edge cases

| Case | Then |
|------|------|
| PostgreSQL plan says Index Only Scan but `Heap Fetches` is high | The visibility map is stale — rows modified recently still require heap visits. Autovacuum/`VACUUM` the table, then re-measure; on high-churn tables index-only scans may never fully pay off |
| Query selects `*` | Covering is off the table; narrow the select list first — covering only works for a stable, small column set |
| Wide payload column (large text/jsonb) | Storing it in the index multiplies index size; fetch it from the heap instead and cover only the narrow columns |

## Instead of

| If you are about to | Do this instead | Why |
|---------------------|-----------------|-----|
| Add every selected column to the index "to be safe" | Cover exactly the measured hot query's select list | Index size and write amplification grow per column; unmeasured covering is pure cost |

## Sources

- https://www.postgresql.org/docs/current/indexes-index-only-scans.html — index-only scans, INCLUDE, visibility map dependence
- https://dev.mysql.com/doc/refman/8.0/en/innodb-index-types.html — InnoDB secondary indexes contain PK columns
