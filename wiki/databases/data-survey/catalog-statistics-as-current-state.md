---
id: databases-data-survey-catalog-statistics-as-current-state
domain: databases
category: data-survey
applies_to: [postgresql]
confidence: verified
sources:
  - https://www.postgresql.org/docs/current/catalog-pg-class.html
  - https://www.postgresql.org/docs/current/functions-admin.html
  - https://www.postgresql.org/docs/current/runtime-config-preset.html
  - https://www.postgresql.org/docs/current/sql-analyze.html
  - https://www.postgresql.org/docs/current/monitoring-stats.html
  - https://www.postgresql.org/docs/current/ddl-system-columns.html
  - https://www.postgresql.org/docs/current/datatype-oid.html
  - https://www.postgresql.org/docs/release/14.0/
last_verified: 2026-08-12
related: [databases-data-survey-surveying-live-data-for-a-rule, databases-operations-autovacuum-and-wraparound, databases-query-optimization-existence-and-count-checks, databases-query-optimization-keyset-pagination]
---

# Catalog Statistics as Evidence About a Table's Current Contents

## When this applies

You need to know what the newest rows of a large PostgreSQL table are — the latest
batch date, whether an ingest still runs, which values arrived this month — and the
column carrying that answer has no index, so a full scan is too expensive. You reach
for the catalog instead: `pg_class.relpages`/`reltuples`, `pg_stats` most-common
values, or a `ctid` range scan over the last blocks. Also when a cheap probe came
back with only old values and you are about to record "no recent data".

Deriving a mapping or enum rule from a survey → [databases-data-survey-surveying-live-data-for-a-rule].

## Do this

1. **Take the table's physical end from `pg_relation_size`, not from `relpages`.**
   `relpages` is "only an estimate used by the planner" that is "updated by `VACUUM`,
   `ANALYZE`, and a few DDL commands" — it is a snapshot of the last maintenance run,
   so every block appended since is invisible in it. `pg_relation_size(rel)` reads the
   main fork's actual byte size:

   ```sql
   SELECT pg_relation_size('external_data.t')
          / current_setting('block_size')::int AS last_block;
   ```

2. **Divide by `current_setting('block_size')`, not by a literal `8192`.** The
   preset reports "the size of a disk block ... determined by the value of `BLCKSZ`
   when building the server"; 8192 is the default, not a guarantee.

3. **Choose the probe by which question you are answering:**

| Question | Probe |
|----------|-------|
| What values exist near the physical end? | `SELECT DISTINCT col FROM t WHERE ctid > '(<last_block-20>,0)'::tid` — aggregate over the range, so every block in it contributes |
| Does any row newer than X exist? | `SELECT max(col) FROM t WHERE ctid > '(<last_block-N>,0)'::tid`, widening N until the answer stops moving |
| How many rows sit in this range? | `count(*)` over the same predicate — a zero here is unambiguous, an empty `DISTINCT` is not |

4. **When you bound a range probe with `LIMIT n`, read the result as "the first n
   rows at the start of the range", not as "the range's contents".** The scan walks
   the range in ascending block order, so `LIMIT` truncates at its oldest end — the
   newest blocks are exactly what it drops.

5. **Before citing `pg_stats` (most-common values, histogram) as the value set, read
   `last_analyze`, `last_autoanalyze`, and `n_mod_since_analyze` from
   `pg_stat_all_tables`.** ANALYZE "takes a random sample of the table contents,
   rather than examining every row" and its output is "only approximate"; when the
   last analyze is old or `NULL`, values that arrived since are absent from the MCV
   list by construction, not by absence in the table.

6. **Cross-check `reltuples` against `n_live_tup` and treat a gap as unmeasured
   inflow.** `reltuples` moves only at VACUUM/ANALYZE/DDL, while `n_live_tup` is the
   cumulative-statistics estimate; the difference is the signal that the catalog view
   of the table is behind the table.

7. **Report which probe produced the answer, with the block range and the analyze
   timestamps you read.** A tail-scan answer is a statement about the blocks scanned;
   without the range it reads as a statement about the table.

## Edge cases

| Case | Then |
|------|------|
| The table takes UPDATEs or DELETEs, not append-only inserts | Physical order stops tracking insert order — a row's `ctid` "will change if it is updated or moved by `VACUUM FULL`", and freed space is refilled by later writes. Confirm the append-mostly assumption (`n_tup_upd`/`n_tup_del` near zero) before reading the tail as "newest" |
| The server is PostgreSQL 13 or older | Range predicates on `ctid` fall back to a sequential scan; efficient TID range scanning arrived in 14 ("Previously a sequential scan was required for non-equality `TID` specifications"). Bound the cost another way, or accept the scan |
| `reltuples` is `-1` | The table "has never yet been vacuumed or analyzed" and the row count is unknown — no catalog-derived count exists to compare against |
| The last blocks are empty of visible rows | The tail can hold dead tuples or free space; widen the range downward rather than concluding the table stopped receiving rows |
| The size you need includes TOASTed values | `pg_relation_size` with one argument returns the main fork only; `pg_table_size` adds TOAST, FSM, and visibility map. Block arithmetic for `ctid` uses the main fork |
| You may run maintenance on the table | `ANALYZE <table>` refreshes the statistics and makes `pg_stats`/`relpages` answer the question directly — take this path when the table is not so large that the analyze cost matters |
| The probe runs against production | Keep every range bounded by `ctid` and read `EXPLAIN` before executing; an unbounded probe on the same column is the full scan you were avoiding ([databases-query-optimization-reading-execution-plans]) |

## Instead of

| If you are about to | Do this instead | Why |
|---------------------|-----------------|-----|
| Start a tail scan at `relpages` | Start at `pg_relation_size(rel)/current_setting('block_size')::int` | `relpages` is the planner's estimate from the last VACUUM/ANALYZE; blocks appended since sit above it and are never scanned |
| Read "the MCV list's newest value is April" as "nothing arrived after April" | Read `last_analyze`/`last_autoanalyze` first, and re-probe the heap when they are old or `NULL` | The MCV list is a sample from the moment of the last analyze, so recency of data and recency of statistics are different facts |
| Bound a `ctid` range probe with `LIMIT 20` and read the values as the range's | Aggregate the range (`DISTINCT`, `max`, `count`) or narrow it to the last blocks | The scan returns the range's oldest rows first, so `LIMIT` yields the end you were not asking about |
| Hard-code `/ 8192` in the block arithmetic | Read `current_setting('block_size')` | `BLCKSZ` is a build-time choice; the arithmetic silently points at the wrong block on a non-default build |
| Conclude "the ingest stopped" from one cheap catalog probe | Name the probe and its range in the finding, then confirm with a second probe of a different kind | Catalog estimates and heap contents are different sources; agreement between two of them is what makes the conclusion an observation |

## Sources

- https://www.postgresql.org/docs/current/catalog-pg-class.html — `relpages`: "Size of the on-disk representation of this table in pages (of size `BLCKSZ`). This is only an estimate used by the planner. It is updated by `VACUUM`, `ANALYZE`, and a few DDL commands such as `CREATE INDEX`"; `reltuples` carries the same estimate/update wording and "If the table has never yet been vacuumed or analyzed, `reltuples` contains `-1` indicating that the row count is unknown"
- https://www.postgresql.org/docs/current/functions-admin.html — `pg_relation_size(relation regclass [, fork text]) → bigint` "Computes the disk space used by one 'fork' of the specified relation ... With one argument, this returns the size of the main data fork"; results "are measured in bytes"; `pg_table_size` "Computes the disk space used by the specified table, excluding indexes (but including its TOAST table if any, free space map, and visibility map)"
- https://www.postgresql.org/docs/current/runtime-config-preset.html — `block_size`: "Reports the size of a disk block. It is determined by the value of `BLCKSZ` when building the server. The default value is 8192 bytes"
- https://www.postgresql.org/docs/current/sql-analyze.html — "For large tables, `ANALYZE` takes a random sample of the table contents, rather than examining every row"; "the statistics are only approximate, and will change slightly each time `ANALYZE` is run"; the collected statistics are "a list of some of the most common values in each column and a histogram showing the approximate data distribution"
- https://www.postgresql.org/docs/current/monitoring-stats.html — `pg_stat_all_tables`: `n_live_tup` "Estimated number of live rows", `n_mod_since_analyze` "Estimated number of rows modified since this table was last analyzed", `last_analyze` "Last time at which this table was manually analyzed", `last_autoanalyze` "Last time at which this table was analyzed by the autovacuum daemon"
- https://www.postgresql.org/docs/current/ddl-system-columns.html — `ctid`: "The physical location of the row version within its table. Note that although the `ctid` can be used to locate the row version very quickly, a row's `ctid` will change if it is updated or moved by `VACUUM FULL`"
- https://www.postgresql.org/docs/current/datatype-oid.html — "`tid`, or tuple identifier (row identifier) ... A tuple ID is a pair (block number, tuple index within block) that identifies the physical location of the row within its table"
- https://www.postgresql.org/docs/release/14.0/ — Optimizer: "Allow efficient heap scanning of a range of `TIDs` (Edmund Horner, David Rowley) ... Previously a sequential scan was required for non-equality `TID` specifications"
- Field observation 2026-08-12 (PostgreSQL, `external_data.collected_from_seumter`, ~1.07M rows, no index on the batch-date column): `relpages` = 43992 while `pg_relation_size` gave 44897 blocks — 905 blocks appended since the last maintenance. `ctid > '(43970,0)' LIMIT 20` returned only `20260619`, while `SELECT DISTINCT` over `ctid > '(44880,0)'` returned `20260719`. The `pg_stats` MCV list topped out at `20260427`, missing three months of arrivals; `reltuples` (1,069,782) trailed `n_live_tup` (1,092,465) by ~22.7k rows, which was the cross-signal that the catalog was behind the heap
