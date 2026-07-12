---
id: databases-schema-design-requirements-to-tables
domain: databases
category: schema-design
applies_to: [general]
confidence: field-tested
sources:
  - https://www.postgresql.org/docs/current/ddl-constraints.html
last_verified: 2026-07-10
related: [databases-schema-design-primary-key-choice, databases-schema-design-nullability-and-defaults, databases-schema-design-naming-conventions, databases-schema-design-foreign-keys-and-referential-actions, databases-schema-design-column-data-types]
---

# Deriving Tables and Columns from Requirements

## When this applies

You have feature requirements (user stories, a spec, a screen design) and must
produce the tables, columns, and relationships for them.

## Do this

1. **List the nouns and the facts.** From the requirements, extract entities (nouns
   that have identity and lifecycle: user, order, listing) and facts about them
   (attributes and relationships). Each entity with independent identity becomes a
   candidate table.
2. **Classify each relationship** and let the classification pick the structure:

| Relationship in requirements | Structure |
|------------------------------|-----------|
| "an X has one Y" and Y is meaningless alone | Columns on X (no new table) |
| "an X has one Y" and Y has its own lifecycle/queries | Y table with FK from X (or on Y, per ownership direction) |
| "an X has many Y" | Y table with `x_id` FK, indexed |
| "X and Y relate many-to-many" | Junction table; attributes of the relationship (since-date, role) live on the junction |
| "Y happened at time T" (events, status changes, payments) | Append-style table with timestamp; rows are immutable facts — enforce it (`REVOKE UPDATE, DELETE` from the app role, or a `BEFORE UPDATE` trigger that raises), don't rely on convention |
3. **Normalize to 3NF by default**: every non-key column states a fact about the whole
   key. When the same fact would be stored in two places, move it to the table whose
   key it depends on. Denormalize only later, per measured read pattern, with a
   defined re-sync source of truth.
4. **Encode rules as constraints, not conventions**: requirement "every order belongs
   to a customer" → `NOT NULL` FK; "emails are unique" → unique constraint;
   "quantity is positive" → `CHECK`. A rule enforced only in application code is a
   rule your batch jobs and future services will break.
5. **Walk every screen/API through the schema** before finishing: for each required
   read, name the tables, join path, and the index serving it
   ([databases-indexing-index-selection]). A requirement you cannot query cheaply is
   a missing column, missing index, or missing table.

## Edge cases

| Case | Then |
|------|------|
| Attribute set varies wildly per row (product options, form answers) | Model the stable columns relationally and put the variable remainder in one `jsonb`/JSON column with documented shape — not one table per variant, not 50 nullable columns |
| Requirement says "history of changes must be visible" | Design the history table now (append-only, valid-from/to or event rows); bolting history onto a mutable table later loses the past |
| Two teams call different things by the same noun | Split the entity by lifecycle: if "listing" in sales and "listing" in accounting change for different reasons, they are different tables |
| Requirements demand aggregates over huge data on every view | Plan the incremental aggregate (counter, materialized rollup) in the schema now ([databases-query-optimization-existence-and-count-checks]) |

## Sources

- https://www.postgresql.org/docs/current/ddl-constraints.html — constraint types for encoding rules
