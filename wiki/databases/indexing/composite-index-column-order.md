---
id: databases-indexing-composite-index-column-order
domain: databases
category: indexing
applies_to: [postgresql, mysql, general]
confidence: verified
sources:
  - https://www.postgresql.org/docs/current/indexes-multicolumn.html
  - https://dev.mysql.com/doc/refman/8.0/en/multiple-column-indexes.html
  - https://use-the-index-luke.com/
last_verified: 2026-07-10
related: [databases-indexing-index-selection, databases-indexing-covering-indexes]
---

# Composite Index Column Order

## When this applies

You are creating an index on 2+ columns, or a query filters on multiple columns and
you must decide one index's column order.

## Do this

Order columns by how the query uses them, left to right:

1. **Equality predicates first** (`col = ?`, `col IN (...)` with few values).
   Among equality columns, put the ones present in the most queries first, so one
   index serves many queries via the leftmost-prefix rule.
2. **Then the range or sort column** (`>`, `<`, `BETWEEN`, `LIKE 'prefix%'`,
   `ORDER BY`). After a range column, later index columns can no longer narrow the
   scan — so only one range/sort column earns a meaningful position.
3. **Then payload columns** needed only for covering
   ([databases-indexing-covering-indexes]).

| Query shape | Index |
|-------------|-------|
| `WHERE a = ? AND b = ?` | `(a, b)` or `(b, a)` — pick the order whose prefix serves other queries too |
| `WHERE a = ? AND b > ?` | `(a, b)` — equality first, range last |
| `WHERE a = ? ORDER BY b LIMIT n` | `(a, b)` — index returns rows pre-sorted, no sort node |
| `WHERE a > ? AND b = ?` | `(b, a)` — the equality column goes first even though it appears second in SQL |
| `WHERE a = ? AND b = 'literal' ORDER BY c DESC LIMIT n` (the commonest OLTP list shape) | `(a, b, c)` — walked backwards for the DESC; when `'literal'` is a measured-rare fixed value, `(a, c) WHERE b = 'literal'` is the smaller alternative ([databases-indexing-partial-and-expression-indexes]) |

## Edge cases

| Case | Then |
|------|------|
| Query filters only on `b` but index is `(a, b)` | The index rarely helps (no leftmost prefix). Create `(b, ...)` or add `b`-leading queries to the workload analysis |
| Two range predicates (`a > ? AND b > ?`) | Only the first range column narrows the scan; put the more selective one first and accept the other as a filter |
| `ORDER BY b DESC` with index `(a, b ASC)` | Single-column direction can be walked backwards; mixed directions (`ORDER BY b ASC, c DESC`) need the index declared with matching per-column directions |
| Skip-scan support (PostgreSQL 18+, MySQL 8.0.13+ can skip a low-cardinality leading column) | Treat as a rescue for existing indexes, not a design target — design for leftmost-prefix use |

## Instead of

| If you are about to | Do this instead | Why |
|---------------------|-----------------|-----|
| Create one single-column index per filtered column and rely on the planner to combine them | Create one composite index matching the hot query's shape | Bitmap-AND of separate indexes costs more than one exact composite; sorts still happen |
| Mirror the `WHERE` clause's textual order into the index | Order by equality-then-range as above | SQL text order is irrelevant to the optimizer; predicate kind determines useful order |

## Sources

- https://www.postgresql.org/docs/current/indexes-multicolumn.html — leftmost-prefix and multicolumn behavior
- https://dev.mysql.com/doc/refman/8.0/en/multiple-column-indexes.html — MySQL leftmost-prefix rule
- https://use-the-index-luke.com/ — equality-first/range-last design method
