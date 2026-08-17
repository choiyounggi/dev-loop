---
id: databases-operations-data-backfill-migrations
domain: databases
category: operations
applies_to: [postgresql, general]
confidence: verified
sources:
  - https://github.com/ankane/strong_migrations
  - https://retool.com/blog/running-safe-database-migrations-using-postgres
last_verified: 2026-08-17
related: [databases-schema-design-online-schema-changes, databases-schema-design-verifying-additive-migrations]
---

# Batching a Data Backfill on a Live Table

## When this applies

A migration needs to populate or transform existing rows on a table that
still takes production writes — backfilling a new column, converting a data
format, or copying values between columns — not just changing the schema.
[databases-schema-design-online-schema-changes] covers the DDL lock itself
(adding the column); this page covers writing data into the rows afterward,
which is the part that scales with table size instead of finishing instantly.

## Do this

| Decision | Do |
|----------|----|
| Backfill transaction shape | Never wrap the whole backfill in one transaction. A single-transaction backfill acquires a row-level lock on every row it touches and holds all of them until the entire backfill finishes, blocking any other write to those rows for the duration |
| Batching | Split the backfill into small batches (in the low hundreds to low thousands of rows), each committed in its own transaction, so each batch's row locks release immediately after that batch commits |
| Load on the primary | Add a short sleep between batches so the backfill does not saturate the connection pool or WAL throughput and starve normal traffic |
| Resumability | Write the backfill so re-running it (after a crash, a deploy, or a manual restart) produces the same result as one uninterrupted run — idempotent per batch (e.g. `WHERE new_col IS NULL`), not "resume from a remembered offset" that goes stale if rows are deleted or inserted mid-run |
| Verifying completion | Query the actual row count still matching the backfill's `WHERE` predicate (e.g. `new_col IS NULL`) after the run, not just "the job reported success" — a batch that errored partway through leaves unbackfilled rows with no other signal |

## Edge cases

| Case | Then |
|------|------|
| Backfill needs to run before the application can read the new column safely | Use dual-write first (the app writes both old and new representations) so the backfill only has to catch up historical rows, not race new writes — verify old vs new agree on a sample before cutting reads over |
| Table is large enough that a full-table `SELECT` for verification is itself expensive | Verify by comparing aggregate counts/checksums per batch as each batch completes, instead of one full-table scan at the end |
| Backfill touches a foreign-key-referenced table under concurrent inserts | Batch by primary-key range (not `OFFSET`/`LIMIT`) so concurrently inserted rows cannot shift which rows a later batch sees, which is what causes rows to be skipped or double-processed under `OFFSET` pagination |

## Instead of

| If you are about to | Do this instead | Why |
|---------------------|-----------------|-----|
| Run `UPDATE ... WHERE ...` over the whole table in the migration's own transaction | Batch the update into small chunks, each in its own transaction, with a short sleep between | The whole-table update holds row locks on every touched row for the entire run, blocking concurrent writes to those rows |
| Treat "the migration script exited 0" as proof the backfill is complete | Query the row count still matching the backfill's target predicate after the run | A batch failure partway through a resumable-but-unmonitored script leaves silently unbackfilled rows |

## Sources

- https://github.com/ankane/strong_migrations — single-transaction lock-holding problem, `in_batches`, throttling between batches
- https://retool.com/blog/running-safe-database-migrations-using-postgres — small-batch/per-batch-transaction pattern, reentrant/idempotent backfill requirement
