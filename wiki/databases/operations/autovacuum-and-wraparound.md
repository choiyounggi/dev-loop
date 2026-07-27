---
id: databases-operations-autovacuum-and-wraparound
domain: databases
category: operations
applies_to: [postgresql]
confidence: verified
sources:
  - https://www.postgresql.org/docs/current/routine-vacuuming.html
last_verified: 2026-07-23
related: [databases-indexing-index-write-cost, databases-query-optimization-reading-execution-plans, databases-schema-design-online-schema-changes]
---

# Keeping Autovacuum Ahead of a Write-Heavy Table (and Off the Wraparound Cliff)

## When this applies

A table takes sustained `UPDATE`/`DELETE`/`INSERT` traffic in production. Two
failure modes grow silently: **bloat** (dead tuples autovacuum hasn't reclaimed,
so scans and indexes slow down) and **transaction-ID wraparound** (unfrozen old
rows approaching the 32-bit XID limit). Wraparound is the severe one: at the
cliff, Postgres refuses all writes cluster-wide until you vacuum. Default
autovacuum is tuned for average tables and can fall behind a hot one.

## Do this

1. **Monitor both clocks on a schedule** (weekly is enough until a table is hot):

   | Signal | Query | Act when |
   |--------|-------|----------|
   | Wraparound age | `SELECT datname, age(datfrozenxid) FROM pg_database ORDER BY 2 DESC;` | Investigate above ~150M; `autovacuum_freeze_max_age` default is 200M, and aggressive autovacuum should hold it well below that |
   | Per-table freeze age | `age(relfrozenxid)` from `pg_stat_user_tables` | A single table climbing while others are flat means autovacuum can't finish it (long txn holding it back, or cost limits too low) |
   | Bloat | `n_dead_tup`, `last_autovacuum` from `pg_stat_user_tables` | Dead ratio stays high and `last_autovacuum` is stale → autovacuum isn't triggering often enough |

2. **Tune the hot table specifically, not the cluster.** Autovacuum triggers at
   `threshold + scale_factor × rows`; the default `autovacuum_vacuum_scale_factor`
   of 0.2 means a 1M-row table must reach ~200k dead tuples first. Lower it
   per-table so it fires earlier:
   `ALTER TABLE t SET (autovacuum_vacuum_scale_factor = 0.02, autovacuum_vacuum_cost_limit = 2000);`
   The default cost limit (200) with a 2ms delay throttles I/O and is often why
   autovacuum can't keep up on a busy table.

3. **Set `log_autovacuum_min_duration = 0`** so every autovacuum is logged — you
   need the record to see whether it's running and how long it takes.

## Edge cases

| Case | Then |
|------|------|
| An autovacuum on one table runs for over an hour or never seems to finish | Its cost limits are too low for the table's churn, or a long-running transaction / idle-in-transaction session is holding `xmin` back so nothing can be frozen — find it in `pg_stat_activity` and end it |
| Insert-only table (append log) never gets vacuumed, then triggers a huge aggressive freeze | Insert-triggered autovacuum (PG13+) helps, but also lower the table's `autovacuum_freeze_min_age` so ordinary vacuums freeze rows early and spread the work |
| Wraparound warning already in the log ("must be vacuumed within N transactions") | Run a plain database-wide `VACUUM` (not `VACUUM FULL` — it needs an XID and fails; not `VACUUM FREEZE` — it does more than needed). First clear what pins `xmin`: long transactions, orphaned prepared transactions (`pg_prepared_xacts`), and stale replication slots (`pg_replication_slots`) |
| Database already refusing writes (read-only, ~3M XIDs left) | Only `VACUUM` and reads work. Vacuum in single-user mode if needed; this is an incident, so the real fix is the monitoring above so you never reach it |
| `VACUUM FULL` proposed to reclaim space on a live table | It takes `ACCESS EXCLUSIVE` and rewrites the whole table — an outage. Prefer `pg_repack` for online bloat reclamation; reserve `VACUUM FULL` for a maintenance window |

## Sources

- https://www.postgresql.org/docs/current/routine-vacuuming.html — vacuum's four jobs, wraparound mechanics and thresholds, autovacuum trigger formula and cost settings, recovery steps and the VACUUM FULL/FREEZE caveats
