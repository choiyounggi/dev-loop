# databases — Domain Index

Route here for: schema/table/key design, index decisions, query writing and
optimization, transaction/concurrency behavior. Datastore backup/restore and
data-loss planning → wiki/infrastructure/data/backup-and-restore.md.

Match your situation to a "load when" line; load only matching pages.

## indexing

| Page | Load when |
|------|-----------|
| [index-selection](indexing/index-selection.md) | Deciding whether a column/query deserves an index; a query is slow and you suspect a missing index |
| [composite-index-column-order](indexing/composite-index-column-order.md) | Creating a multi-column index; choosing column order for equality + range/sort queries |
| [covering-indexes](indexing/covering-indexes.md) | A query already served by an index still reads the table (heap) heavily; deciding whether to add INCLUDE/covering columns |
| [partial-and-expression-indexes](indexing/partial-and-expression-indexes.md) | Queries always filter a fixed rare condition (status, deleted_at) or a function of a column (lower(email)); a uniqueness rule applies only to a subset of rows (e.g. live rows) |
| [trigram-index-short-patterns](indexing/trigram-index-short-patterns.md) | A `LIKE`/`ILIKE '%keyword%'` search on a PostgreSQL `pg_trgm` GIN/GiST index is fast for ordinary words and slow for one- or two-character keywords; `EXPLAIN` shows a `Bitmap Index Scan` on the trigram index and the query is still slow; choosing a minimum search-keyword length, or deciding between pg_trgm, pg_bigm, and a driver index for another condition |
| [index-write-cost](indexing/index-write-cost.md) | Adding indexes to write-heavy tables; bulk loads; auditing for unused/redundant indexes |

## query-optimization

| Page | Load when |
|------|-----------|
| [reading-execution-plans](query-optimization/reading-execution-plans.md) | A single query/statement is slow; verifying an index/query change with EXPLAIN before shipping (endpoint slow because it runs *many* fast queries → n-plus-one-queries) |
| [comparing-two-execution-plans](query-optimization/comparing-two-execution-plans.md) | Attributing a slowdown to one variable by comparing `EXPLAIN (ANALYZE)` across two variants of a statement; one arm came back far faster or its plan shows `never executed` / `loops=0`; quoting the duration of an arm a client deadline cut short |
| [keyset-pagination](query-optimization/keyset-pagination.md) | Implementing pagination, infinite scroll, or batch table walks |
| [streaming-large-result-sets](query-optimization/streaming-large-result-sets.md) | Exporting/reading a very large single-query result into the app; process memory peaks on `fetchall` or building a big file; server-side cursor blocked by autocommit or a read-only proxy |
| [large-in-lists](query-optimization/large-in-lists.md) | Building `IN (...)` queries whose list size can grow (batch lookups, fetch-by-ids) |
| [n-plus-one-queries](query-optimization/n-plus-one-queries.md) | Loading a list plus per-row associations via an ORM; query count scales with result size |
| [existence-and-count-checks](query-optimization/existence-and-count-checks.md) | Writing "is there any…", counts, badges, or gating logic on row presence |
| [repeated-sublinks-in-a-pulled-up-derived-table](query-optimization/repeated-sublinks-in-a-pulled-up-derived-table.md) | A PostgreSQL correlated subquery sits in a derived table's select list and two or more outer aggregates/expressions read it; runtime is a clean multiple of one pass over the driving rows; choosing between `OFFSET 0`, `WITH ... AS MATERIALIZED`, `LATERAL` and leaving a grouped derived table alone; writing or reviewing a comment that claims a per-row value is computed once; understanding why a generated-SQL string test cannot see repeated evaluation |


## schema-design

| Page | Load when |
|------|-----------|
| [requirements-to-tables](schema-design/requirements-to-tables.md) | Turning feature requirements into tables, columns, and relationships |
| [naming-conventions](schema-design/naming-conventions.md) | Creating or renaming a table/column/index/constraint and picking its name; setting conventions for a new project (skip when only changing existing objects' behavior) |
| [primary-key-choice](schema-design/primary-key-choice.md) | Choosing PK type (sequence vs UUID); ids exposed publicly; MySQL clustered-index concerns |
| [foreign-keys-and-referential-actions](schema-design/foreign-keys-and-referential-actions.md) | Declaring FKs; choosing ON DELETE behavior; polymorphic/circular references; bulk loads under FKs |
| [column-data-types](schema-design/column-data-types.md) | Picking column types: money, time, text, enums, JSON, binary; changing a type on a live table |
| [nullability-and-defaults](schema-design/nullability-and-defaults.md) | Declaring column nullability/defaults; queries dropping rows around NULLs |
| [soft-delete](schema-design/soft-delete.md) | Deleted records themselves must be restorable or kept (deleted_at schemas); deciding what a parent's deletion does to children that must survive (for who-changed-what history → requirements-to-tables) |
| [online-schema-changes](schema-design/online-schema-changes.md) | Running ALTER TABLE / CREATE INDEX on a large table under live traffic; a migration blocks reads/writes (ACCESS EXCLUSIVE); adding a column/constraint/NOT NULL/index/type change safely; expand-and-contract to decouple DB migration from app deploy |
| [verifying-additive-migrations](schema-design/verifying-additive-migrations.md) | The project has no migration tool and schema comes from an ORM `create_all()` plus hand-written `ALTER TABLE ADD COLUMN IF NOT EXISTS`; writing the test that proves a new column reaches an already-deployed database; asserting a column's type/nullability/default from the catalog; a column added on the model never appeared on the deployed table |

## operations

| Page | Load when |
|------|-----------|
| [autovacuum-and-wraparound](operations/autovacuum-and-wraparound.md) | A write-heavy table bloats or slows over time; tuning autovacuum for a hot table; monitoring/preventing transaction-ID wraparound (age(datfrozenxid)); the database starts refusing writes to avoid wraparound; deciding VACUUM vs VACUUM FULL vs pg_repack |
| [data-backfill-migrations](operations/data-backfill-migrations.md) | A migration must populate/transform existing rows on a live table (not just alter the schema); choosing batch size and transaction boundaries so the backfill doesn't hold row locks for its full duration; making a backfill resumable/idempotent; verifying a backfill actually completed instead of trusting exit status |

## data-survey

| Page | Load when |
|------|-----------|
| [catalog-statistics-as-current-state](data-survey/catalog-statistics-as-current-state.md) | Finding a large PostgreSQL table's newest rows when the column has no index, so you reach for `pg_class.relpages`/`reltuples`, `pg_stats` most-common values, or a `ctid` range scan of the last blocks; about to conclude "no recent data" from a cheap catalog probe; choosing the scan's starting block or how to bound a `ctid` range |
| [audit-columns-as-update-evidence](data-survey/audit-columns-as-update-evidence.md) | About to read `update_dt`/`updated_at`/`modified_by` (NULL, or equal to the insert timestamp) as evidence that rows were never modified or a feature is unused; an incident needs to know whether writes to those rows were *attempted*; deciding whether ORM callback auditing or a DB trigger is the right writer for the claim you need to make |
| [surveying-live-data-for-a-rule](data-survey/surveying-live-data-for-a-rule.md) | A task says to sample real data to decide a mapping table, normalization/canonicalization rule, enum value set, or parsing rule; a `GROUP BY`/`DISTINCT` survey came back with zero rows; deciding what evidence replaces the data when the table is empty; recording in the deliverable which evidence a rule was actually derived from |

## sqlite

| Page | Load when |
|------|-----------|
| [concurrent-access-for-a-read-api](sqlite/concurrent-access-for-a-read-api.md) | Using SQLite as the store for an HTTP API that serves reads while a background job writes; `database is locked` under load; readers stalling during an import; choosing WAL vs rollback journal, busy_timeout, single-writer, per-connection pragma cost; scaling SQLite-backed reads across worker processes |

## transactions

| Page | Load when |
|------|-----------|
| [isolation-level-selection](transactions/isolation-level-selection.md) | Check-then-act writes, lost updates, duplicate bookings, choosing isolation/locking; deadlock-detected errors; oversell despite @Transactional |
| [optimistic-vs-pessimistic-locking](transactions/optimistic-vs-pessimistic-locking.md) | Multi-step read-modify-write that cannot fold into one UPDATE — choosing version-column optimistic vs FOR UPDATE by conflict frequency; stale form submits; retry storms on hot rows |
