---
id: databases-schema-design-nullability-and-defaults
domain: databases
category: schema-design
applies_to: [postgresql, mysql, general]
confidence: verified
sources:
  - https://www.postgresql.org/docs/current/ddl-constraints.html
  - https://www.postgresql.org/docs/current/functions-comparison.html
last_verified: 2026-07-10
related: [databases-schema-design-requirements-to-tables, databases-query-optimization-large-in-lists]
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
| Sort order with NULLs | PostgreSQL sorts NULLs last on ASC by default, MySQL first; state `NULLS FIRST/LAST` explicitly when it matters, and match the index definition |
| Empty string vs NULL for text | Pick one representation of "absent" per column and enforce it (`CHECK (col <> '')` if NULL is the absent form); mixed representations break both filters and uniqueness |

## Sources

- https://www.postgresql.org/docs/current/ddl-constraints.html — NOT NULL, CHECK, unique constraints
- https://www.postgresql.org/docs/current/functions-comparison.html — IS DISTINCT FROM, NULL comparison semantics
