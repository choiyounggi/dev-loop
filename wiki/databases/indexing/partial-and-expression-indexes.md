---
id: databases-indexing-partial-and-expression-indexes
domain: databases
category: indexing
applies_to: [postgresql]
confidence: verified
sources:
  - https://www.postgresql.org/docs/current/indexes-partial.html
  - https://www.postgresql.org/docs/current/indexes-expressional.html
last_verified: 2026-07-10
related: [databases-indexing-index-selection, databases-schema-design-soft-delete]
---

# Partial and Expression Indexes

## When this applies

A query always filters on a fixed rare condition (`status = 'pending'`,
`deleted_at IS NULL`); or filters on a function of a column (`lower(email)`); or a
uniqueness rule applies only to a subset of rows (e.g. among live rows). Applies
whether you are designing a new index or replacing a bloated/unused full-column one.

## Do this

| Case | Do |
|------|----|
| Queries target a rare fixed value in a skewed column | Partial index: `CREATE INDEX ... ON t (created_at) WHERE status = 'pending'` — small, hot, and the planner uses it exactly for matching queries |
| Live rows are the minority or queries always exclude soft-deleted rows | Partial index `WHERE deleted_at IS NULL` on the columns those queries use |
| Uniqueness must hold only among live rows | Partial **unique** index: `CREATE UNIQUE INDEX ... ON t (email) WHERE deleted_at IS NULL` |
| Uniqueness among live rows AND case-insensitive (emails, usernames) | Combine expression + partial: `CREATE UNIQUE INDEX ... ON t (lower(email)) WHERE deleted_at IS NULL` — and query with `lower(email) = lower(?)` |
| Predicate applies a function/expression (`lower(email) = ?`, `(payload->>'type') = ?`) | Expression index on exactly that expression: `CREATE INDEX ... ON t (lower(email))` |

Then verify the plan uses the index. For partial indexes the query's `WHERE` must
imply the index predicate **as written** — keep query and index predicate textually
aligned to avoid planner-provability gaps.

## Edge cases

| Case | Then |
|------|------|
| Query filters the rare value via a bind parameter (`status = $1`) | Planner cannot prove `$1 = 'pending'` matches the index predicate at plan time; generic plans skip the partial index. Use a literal in the hot query, a dedicated query for the rare value, or a full index |
| Expression index exists on `lower(email)` but query compares `email = ?` | Not matched — expression must appear identically in the query. Normalize at the application boundary or query with `lower(email) = lower(?)` |
| MySQL | No partial indexes; nearest tools are prefix indexes and generated-column indexes (expression indexes exist as functional key parts in 8.0.13+) |
| Expression is expensive (e.g. jsonb extraction) | The expression is computed on every write to maintain the index; confirm write volume tolerates it |

## Sources

- https://www.postgresql.org/docs/current/indexes-partial.html — partial index semantics, predicate implication
- https://www.postgresql.org/docs/current/indexes-expressional.html — expression index matching rules
