---
id: databases-schema-design-soft-delete
domain: databases
category: schema-design
applies_to: [postgresql, mysql, general]
confidence: field-tested
sources:
  - https://www.postgresql.org/docs/current/indexes-partial.html
last_verified: 2026-07-10
related: [databases-indexing-partial-and-expression-indexes, databases-schema-design-nullability-and-defaults, databases-schema-design-foreign-keys-and-referential-actions]
---

# Soft Delete

## When this applies

Requirements say deleted records must be restorable, auditable, or referenced by
history — so rows are marked deleted instead of removed. Or you are debugging
duplicate/ghost rows in a schema that already soft-deletes.

## Do this

1. Use `deleted_at TIMESTAMPTZ NULL` (NULL = live). It records when, doubles as the
   flag, and supports retention jobs. Add `deleted_by` when audit requires the actor.
2. Make the live-row filter structural, not a convention:

| Layer | Do |
|-------|----|
| Queries | Route reads through a base scope/view that appends `deleted_at IS NULL` (ORM default scope, or a `*_live` view) — per-query hand-written filters get forgotten |
| Uniqueness | Partial unique index among live rows: `CREATE UNIQUE INDEX ... ON t (email) WHERE deleted_at IS NULL` — a full unique index blocks re-registration after deletion ([databases-indexing-partial-and-expression-indexes]) |
| Hot indexes | Add `WHERE deleted_at IS NULL` to indexes serving live-row queries; dead rows stop bloating them |
| Foreign keys | Decide per relationship what child rows do when the parent soft-deletes (cascade the mark, forbid, or keep) — the database FK won't do it for you; enforce in the service layer that owns the delete |

3. Pair with retention: a scheduled job that hard-deletes (or archives) rows past the
   retention window. Soft-delete without retention is an unbounded table.

## Edge cases

| Case | Then |
|------|------|
| Some tables never need restore (logs, sessions, join rows) | Hard-delete those; soft-delete only where the requirement exists. Mixing is fine when each table's rule is explicit |
| "Audit" means who-changed-what history, not just keeping deleted rows | A history/audit table (append-only) per [databases-schema-design-requirements-to-tables] — `deleted_at` preserves only the final state, not the changes |
| Table also has a `status` column | Keep deletion out of the status value set — `deleted_at` is the single source of deletion truth; a 'deleted' status value creates two flags that will disagree |
| Unique column must also be case-insensitive (emails) | Combine expression + partial: `UNIQUE INDEX ON t (lower(email)) WHERE deleted_at IS NULL` ([databases-indexing-partial-and-expression-indexes]) |
| Aggregates/counts silently include deleted rows | Every aggregate must go through the live scope too — test list and count endpoints against a fixture containing deleted rows |
| MySQL (no partial indexes) | Emulate live-row uniqueness with a generated column (e.g. `alive = IF(deleted_at IS NULL, 1, NULL)`) in a composite unique key — unique keys ignore NULL rows |
| Restore collides with a live row created meanwhile | Restoration is an upsert-style operation: handle the unique conflict explicitly (merge, rename, or reject) |
| Regulatory erasure (GDPR-style) | Soft delete does not satisfy erasure; hard-delete or anonymize the personal fields while keeping the skeleton row |

## Sources

- https://www.postgresql.org/docs/current/indexes-partial.html — partial unique indexes for live-row constraints
