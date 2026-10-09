---
id: databases-schema-design-nullability-and-defaults
domain: databases
category: schema-design
applies_to: [postgresql, mysql, general]
confidence: verified
sources:
  - https://www.postgresql.org/docs/current/ddl-constraints.html
  - https://www.postgresql.org/docs/current/functions-comparison.html
  - https://www.postgresql.org/docs/current/queries-order.html
  - https://www.sqlite.org/lang_select.html
  - https://dev.mysql.com/doc/refman/8.4/en/working-with-null.html
  - https://docs.python.org/3/reference/expressions.html
last_verified: 2026-10-04
related: [databases-schema-design-requirements-to-tables, databases-query-optimization-large-in-lists, databases-data-survey-surveying-live-data-for-a-rule, databases-query-optimization-keyset-pagination]
---

# Nullability, Defaults, and Three-Valued Logic

## When this applies

You are declaring columns for a new table, adding a column to an existing one, or
debugging a query that silently drops rows around NULLs.

## Do this

1. Declare `NOT NULL` unless "value unknown/absent" is a real state of the domain.
   For each nullable column, be able to state what NULL **means** (unknown? not yet
   set? not applicable?). If two of those meanings coexist, split the column or add
   a discriminating status column.
2. Give operational columns explicit defaults: `created_at DEFAULT now()`,
   `status DEFAULT 'draft'`, counters `DEFAULT 0`. A default plus `NOT NULL` keeps
   every writer consistent, including ad-hoc inserts and future services.
3. Write NULL-aware predicates:

| Case | Do |
|------|----|
| "column differs from value" must include NULL rows | PostgreSQL: `col IS DISTINCT FROM ?`; MySQL: `NOT (col <=> ?)` — plain `col <> ?` drops NULL rows |
| Anti-join over a nullable key | `NOT EXISTS`, never `NOT IN (subquery)` (one NULL in the subquery empties the result) |
| Aggregating nullable columns | `COUNT(col)` skips NULLs, `AVG` ignores them; use `COALESCE(col, 0)` only when 0 genuinely means the same as absent |
| Unique constraint on nullable column | NULLs don't collide with each other by default; PostgreSQL 15+: `UNIQUE NULLS NOT DISTINCT` when you want at most one NULL |

4. Booleans representing a domain decision: `NOT NULL` with a default. A nullable
   boolean is a hidden three-state enum — when three states are real, use a
   `CHECK`-constrained text/enum status instead.

## Edge cases

| Case | Then |
|------|------|
| Adding a `NOT NULL` column to a large live table | Add with a `DEFAULT` (PostgreSQL 11+ / MySQL 8.0 instant DDL fill it without a rewrite — verify your version's behavior), backfill in batches if needed, then add the constraint |
| Sort order with NULLs | The default position flips with direction on PostgreSQL, SQLite and MySQL alike: PostgreSQL sorts NULL as larger than any value (last on ASC, first on DESC); SQLite and MySQL sort it as smaller (first on ASC, last on DESC). State the position explicitly when it matters, and match the index definition |
| One missing-value order must hold across PostgreSQL, SQLite and MySQL backends and an in-memory implementation (a Python sort, a Fake repository) | Sort on an explicit leading "is absent" key everywhere: SQL `ORDER BY (col IS NULL), col [DESC]`; Python partitions the records on `r.k is None`, sorts the present part by `(r.k, r.id)` and appends the missing part sorted by `r.id`, passing `reverse=True` to each part for DESC — comparing `None` with a value raises `TypeError`, and `reverse=True` over the whole list would move the missing part first. The SQL form also runs where `NULLS LAST` is missing (SQLite before 3.30.0; MySQL 8.4's `SELECT` grammar lists no `NULLS FIRST/LAST`). Test ASC and DESC on every backend against one shared fixture: on SQLite a DESC-only case already puts NULLs last, so it passes before the fix and hides the ASC bug |
| Empty string vs NULL for text | Pick one representation of "absent" per column and enforce it (`CHECK (col <> '')` if NULL is the absent form); mixed representations break both filters and uniqueness |

## Sources

- https://www.postgresql.org/docs/current/ddl-constraints.html — NOT NULL, CHECK, unique constraints
- https://www.postgresql.org/docs/current/functions-comparison.html — IS DISTINCT FROM, NULL comparison semantics
- https://www.postgresql.org/docs/current/queries-order.html — "By default, null values sort as if larger than any non-null value; that is, NULLS FIRST is the default for DESC order, and NULLS LAST otherwise"
- https://www.sqlite.org/lang_select.html — "SQLite considers NULL values to be smaller than any other values for sorting purposes. Hence, NULLs naturally appear at the beginning of an ASC order-by and at the end of a DESC order-by"; `NULLS FIRST/LAST` added in 3.30.0 (https://www.sqlite.org/changes.html)
- https://dev.mysql.com/doc/refman/8.4/en/working-with-null.html — "NULL values are presented first if you do ORDER BY ... ASC and last if you do ORDER BY ... DESC"
- https://docs.python.org/3/reference/expressions.html — value comparisons: "A default order comparison (<, >, <=, and >=) is not provided; an attempt raises TypeError"
- Local reproduction 2026-10-04 (SQLite 3.51.0, rows k = NULL, 5, 1, NULL): `ORDER BY k` put both NULLs first, `ORDER BY k DESC` put them last, `ORDER BY (k IS NULL), k` and `(k IS NULL), k DESC` put them last in both directions; Python 3.14 `sorted([3, None, 1])` raised `TypeError: '<' not supported between instances of 'NoneType' and 'int'`
- Field evidence 2026-10 (a language runtime with a Fake and a SQLite repository): a DESC-only missing-field ordering test on SQLite stayed green before the fix while the ASC and sorted-query cases failed (`FAILED (failures=2, errors=8)`); after the fix a parity test between the Fake and SQLite agreed in both directions
