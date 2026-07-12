# databases — Domain Index

Route here for: schema/table/key design, index decisions, query writing and
optimization, transaction/concurrency behavior.

Match your situation to a "load when" line; load only matching pages.

## indexing

| Page | Load when |
|------|-----------|
| [index-selection](indexing/index-selection.md) | Deciding whether a column/query deserves an index; a query is slow and you suspect a missing index |
| [composite-index-column-order](indexing/composite-index-column-order.md) | Creating a multi-column index; choosing column order for equality + range/sort queries |
| [covering-indexes](indexing/covering-indexes.md) | A query already served by an index still reads the table (heap) heavily; deciding whether to add INCLUDE/covering columns |
| [partial-and-expression-indexes](indexing/partial-and-expression-indexes.md) | Queries always filter a fixed rare condition (status, deleted_at) or a function of a column (lower(email)); a uniqueness rule applies only to a subset of rows (e.g. live rows) |
| [index-write-cost](indexing/index-write-cost.md) | Adding indexes to write-heavy tables; bulk loads; auditing for unused/redundant indexes |

## query-optimization

| Page | Load when |
|------|-----------|
| [reading-execution-plans](query-optimization/reading-execution-plans.md) | A single query/statement is slow; verifying an index/query change with EXPLAIN before shipping (endpoint slow because it runs *many* fast queries → n-plus-one-queries) |
| [keyset-pagination](query-optimization/keyset-pagination.md) | Implementing pagination, infinite scroll, or batch table walks |
| [large-in-lists](query-optimization/large-in-lists.md) | Building `IN (...)` queries whose list size can grow (batch lookups, fetch-by-ids) |
| [n-plus-one-queries](query-optimization/n-plus-one-queries.md) | Loading a list plus per-row associations via an ORM; query count scales with result size |
| [existence-and-count-checks](query-optimization/existence-and-count-checks.md) | Writing "is there any…", counts, badges, or gating logic on row presence |

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

## sqlite

| Page | Load when |
|------|-----------|
| [concurrent-access-for-a-read-api](sqlite/concurrent-access-for-a-read-api.md) | Using SQLite as the store for an HTTP API that serves reads while a background job writes; `database is locked` under load; readers stalling during an import; choosing WAL vs rollback journal, busy_timeout, single-writer, per-connection pragma cost; scaling SQLite-backed reads across worker processes |

## transactions

| Page | Load when |
|------|-----------|
| [isolation-level-selection](transactions/isolation-level-selection.md) | Check-then-act writes, lost updates, duplicate bookings, choosing isolation/locking; deadlock-detected errors; oversell despite @Transactional |
| [optimistic-vs-pessimistic-locking](transactions/optimistic-vs-pessimistic-locking.md) | Multi-step read-modify-write that cannot fold into one UPDATE — choosing version-column optimistic vs FOR UPDATE by conflict frequency; stale form submits; retry storms on hot rows |
