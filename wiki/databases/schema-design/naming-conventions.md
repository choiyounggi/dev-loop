---
id: databases-schema-design-naming-conventions
domain: databases
category: schema-design
applies_to: [postgresql, mysql, general]
confidence: field-tested
sources:
  - https://www.postgresql.org/docs/current/sql-syntax-lexical.html
  - https://guides.rubyonrails.org/active_record_basics.html
last_verified: 2026-07-10
related: [databases-schema-design-requirements-to-tables, databases-schema-design-foreign-keys-and-referential-actions]
---

# Naming Tables, Columns, Indexes, and Constraints

## When this applies

You are creating or renaming any database object and must pick its name, or you are
setting conventions for a new project.

## Do this

1. Resolve the convention source in this order — stop at the first match:

| Case | Do |
|------|----|
| Existing schema already has a dominant convention | Follow it exactly, even where it differs from this page — one consistent wrong beats two mixed rights |
| ORM/framework has a default convention (Rails/ActiveRecord: plural snake_case tables; Django: `app_model`; JPA: per naming strategy) | Follow the framework default; overriding it costs configuration on every entity forever |
| Greenfield, no framework convention | Use the defaults below and record them in the project README |

2. Greenfield defaults:

| Object | Rule | Example |
|--------|------|---------|
| Table | `snake_case`, plural noun | `orders`, `order_items` |
| Junction table | Both table names, alphabetical, plural | `products_tags`; when the relationship has its own meaning, name the concept instead: `enrollments` |
| Column | `snake_case`, singular; no table-name prefix | `status`, not `order_status` inside `orders` |
| Primary key | `id` | `id` |
| Foreign key | `<referenced_table_singular>_id`; role-qualified when two FKs point at one table | `user_id`; `approver_id` + `requester_id` |
| Boolean | `is_`/`has_` prefix, or a past participle | `is_active`, `archived` |
| Timestamp | `<event>_at` (`TIMESTAMPTZ`) | `created_at`, `deleted_at` |
| Date | `<event>_on` (`DATE`) | `billed_on` |
| Index | `idx_<table>_<cols>` when named manually; keep tool-generated names when a migration tool generates them | `idx_orders_user_id_created_at` |
| Unique / check / FK constraint | `uq_` / `chk_` / `fk_` + `<table>_<cols or rule>` | `uq_users_email`, `fk_orders_user_id` |

3. Spell words out; abbreviate only tokens every engineer already reads fluently
   (`id`, `url`, `ip`). Never invent project-local abbreviations (`cust_addr_ln2`).
4. Use only lowercase ASCII letters, digits, and underscores. This avoids quoted
   identifiers entirely — PostgreSQL folds unquoted names to lowercase, MySQL case
   sensitivity depends on the host filesystem, so mixed case eventually forces
   quoting everywhere.
5. Check reserved words before finalizing (`user`, `order`, `group`, `default` are
   the classic collisions): PostgreSQL `SELECT * FROM pg_get_keywords()`. Prefer a
   synonym (`users` table, `sort_order` column) over living with quoting.

## Edge cases

| Case | Then |
|------|------|
| Renaming a live table/column | Treat as a multi-deploy migration: add new name (or view/alias), dual-write or backfill, switch readers, drop old — never a single in-place rename under traffic |
| Same concept named differently across services (`customer` vs `client`) | Pick one term in a shared glossary and use it for every new object; rename old objects only when already touching them |
| Identifier length limits (PostgreSQL 63 bytes; MySQL 64) | Long generated constraint names get truncated silently in PostgreSQL — name long-multi-column constraints manually |

## Instead of

| If you are about to | Do this instead | Why |
|---------------------|-----------------|-----|
| Encode the type into the name (`str_name`, `tbl_users`) | Plain descriptive name; the type lives in the schema | Type prefixes rot when types change and add noise to every query |
| Mix singular and plural table names as each feels natural | Apply the resolved convention to every table | Every consumer must otherwise memorize per-table spelling |

## Sources

- https://www.postgresql.org/docs/current/sql-syntax-lexical.html — identifier folding, quoting, length limits
- https://guides.rubyonrails.org/active_record_basics.html — framework convention example (plural snake_case)
