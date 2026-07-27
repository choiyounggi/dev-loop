---
id: databases-schema-design-online-schema-changes
domain: databases
category: schema-design
applies_to: [postgresql]
confidence: verified
sources:
  - https://www.postgresql.org/docs/current/sql-altertable.html
last_verified: 2026-07-23
related: [databases-schema-design-column-data-types, databases-schema-design-foreign-keys-and-referential-actions, databases-indexing-index-write-cost, databases-schema-design-nullability-and-defaults]
---

# Applying Schema Changes to a Live Table Without Blocking Writes

## When this applies

Running `ALTER TABLE` / `CREATE INDEX` against a table that takes concurrent
production traffic, on a table large enough that a full scan or rewrite is not
instant. Most `ALTER TABLE` forms take an `ACCESS EXCLUSIVE` lock — it blocks
reads *and* writes for the whole operation, so a multi-second rewrite is a
multi-second outage. The goal: make each change either instant-under-lock or
lock-light.

## Do this

Split every risky change into an instant metadata step plus a concurrent/validated
step. Pick the row for your change:

| Change | Do |
|--------|----|
| Add a column with a default | Postgres 11+ stores a **non-volatile** default as metadata — instant, no rewrite. Keep the default constant (`DEFAULT now()` is fine; `DEFAULT clock_timestamp()`, a stored generated column, or an identity column force a full rewrite) |
| Add a `CHECK` or `FOREIGN KEY` constraint | Add it `NOT VALID` (skips the scan, takes the lock only briefly), then `ALTER TABLE ... VALIDATE CONSTRAINT` in a separate statement — validation takes only `SHARE UPDATE EXCLUSIVE`, so writes continue |
| Make a column `NOT NULL` | First add `CHECK (col IS NOT NULL) NOT VALID`, `VALIDATE` it, then `SET NOT NULL` — a valid CHECK proving no NULLs lets `SET NOT NULL` skip its table scan |
| Add an index | `CREATE INDEX CONCURRENTLY` — builds without an `ACCESS EXCLUSIVE` lock ([databases-indexing-index-write-cost]). Never inside a transaction block |
| Add a foreign key | `ADD FOREIGN KEY` needs only `SHARE ROW EXCLUSIVE` (not ACCESS EXCLUSIVE), but still add it `NOT VALID` + `VALIDATE` to avoid the reference scan under lock |
| Rename/drop a column, or change a type | These force `ACCESS EXCLUSIVE` (and a type change rewrites the whole table by default — see the binary-coercible exception in Edge cases). Use expand-and-contract instead of an in-place change (see below) |

**Expand and contract** — for renames, type changes, and column splits, never
mutate in place under load. Expand: add the new column/table (instant steps
above) and dual-write from the app. Migrate: backfill old rows in batches.
Contract: switch reads to the new shape, then drop the old column in a final
quick `ACCESS EXCLUSIVE` step. This also decouples the deploy: the app tolerates
both shapes across the window, so DB migration and app release need not be atomic.

## Edge cases

| Case | Then |
|------|------|
| Type change where old type is binary-coercible to new (e.g. `text`→`varchar`, no collation change) | No rewrite, and indexes are not rebuilt — the fast path. Verify against your exact types before assuming instant |
| `CREATE INDEX CONCURRENTLY` fails midway | It leaves an `INVALID` index that still costs writes; `DROP INDEX` it and retry, don't leave it |
| The brief `ACCESS EXCLUSIVE` step queues behind a long-running query | The `ALTER` waits for the lock *and every query that arrives behind it also waits* — a lock queue pile-up. Set a short `lock_timeout` on the DDL and retry, so it backs off instead of freezing traffic |
| Batched backfill during expand | Keep each batch a short transaction and throttle — a single `UPDATE` over the whole table holds row locks and generates dead tuples faster than autovacuum clears them ([databases-operations-autovacuum-and-wraparound]) |
| Adding a volatile default / generated / identity column is unavoidable | It rewrites the table under `ACCESS EXCLUSIVE`; schedule it as a maintenance-window operation, not a live deploy |

## Sources

- https://www.postgresql.org/docs/current/sql-altertable.html — lock levels per ALTER form, NOT VALID / VALIDATE, non-volatile default fast path, type-change rewrite rules
- https://www.postgresql.org/docs/current/sql-createindex.html — CREATE INDEX CONCURRENTLY lock behavior
