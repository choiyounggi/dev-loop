---
id: databases-schema-design-foreign-keys-and-referential-actions
domain: databases
category: schema-design
applies_to: [postgresql, mysql]
confidence: verified
sources:
  - https://www.postgresql.org/docs/current/ddl-constraints.html
  - https://dev.mysql.com/doc/refman/8.0/en/create-table-foreign-keys.html
last_verified: 2026-07-10
related: [databases-schema-design-requirements-to-tables, databases-schema-design-soft-delete, databases-indexing-index-selection]
---

# Foreign Keys and Referential Actions

## When this applies

You are creating a relationship between tables and must decide: declare the FK in
the database or not, which `ON DELETE`/`ON UPDATE` action, and how to handle
relationships FKs cannot express.

## Do this

1. **Declare the FK constraint in the database** whenever the column references
   another table's key. Application-level integrity alone lasts until the first
   batch job, second service, or manual fix touches the data.
2. **Index the FK column on the child side** — PostgreSQL does not do it for you
   ([databases-indexing-index-selection]).
3. Choose `ON DELETE` by the child's meaning, not by convenience:

| Child rows are… | ON DELETE | Example |
|-----------------|-----------|---------|
| Structural parts of the parent, meaningless alone | `CASCADE` | `order_items` under `orders` |
| Independent records that reference the parent | `RESTRICT` — deletion must go through an application flow that decides their fate | `orders` under `users` |
| Records whose link is optional context | `SET NULL` (column must be nullable) | `posts.editor_id` when an editor account is removed |
| Rows that must survive as history even after parent deletion (payments, audit rows) | `RESTRICT` at the DB, **and** rethink the delete flow itself: soft-delete the parent ([databases-schema-design-soft-delete]) or archive children first — `SET NULL` loses the link, `CASCADE` loses the history | `payments` under `orders` |

4. Default to `RESTRICT` when unsure — it converts a surprising data loss into an
   explicit error you can handle.
5. `ON UPDATE`: with surrogate immutable PKs
   ([databases-schema-design-primary-key-choice]) key updates don't happen; leave the
   default (`NO ACTION`) rather than declaring `ON UPDATE CASCADE` you'll never exercise.

## Edge cases

| Case | Then |
|------|------|
| `CASCADE` chains several levels (user → orders → items → …) | One parent delete can fan out to millions of rows inside one transaction. For big fan-outs, delete children in application-controlled batches first, keep `CASCADE` only as the final safety net |
| Soft-delete schema | DB referential actions fire only on real `DELETE`. Propagation of `deleted_at` is service-layer logic — define it per relationship ([databases-schema-design-soft-delete]) |
| Polymorphic reference (`commentable_type` + `commentable_id`) | A plain FK cannot express it. Use one nullable FK column per target table with a `CHECK` that exactly one is set, or a junction table per target — both keep DB-enforced integrity |
| Circular references (two tables referencing each other) | Make one FK `DEFERRABLE INITIALLY DEFERRED` (PostgreSQL) so both rows can insert in one transaction; in MySQL, insert with NULL then update |
| Bulk loads into FK-constrained tables | Load parents before children. Session-level FK disabling (MySQL `foreign_key_checks=0`) is a migration-window tool only — it skips validation of the rows loaded meanwhile |
| High-contention hot rows (counters on a parent) | Every child insert takes a share lock on the parent key row; extreme write rates on one parent can serialize — measure before dropping the FK, and if you drop it, add a scheduled orphan-detection query |

## Instead of

| If you are about to | Do this instead | Why |
|---------------------|-----------------|-----|
| Skip the FK "for performance" on a normal OLTP table | Declare it; revisit only with measured contention evidence | The check cost is an indexed lookup; orphaned rows cost far more to clean up |
| Use `ON DELETE CASCADE` everywhere so deletes "just work" | Choose per relationship with the table above | Cascade across independent entities silently destroys data users considered theirs |

## Sources

- https://www.postgresql.org/docs/current/ddl-constraints.html — FK constraints, referential actions, deferrable
- https://dev.mysql.com/doc/refman/8.0/en/create-table-foreign-keys.html — InnoDB FK behavior and restrictions
