---
id: databases-query-optimization-existence-and-count-checks
domain: databases
category: query-optimization
applies_to: [postgresql, mysql, general]
confidence: verified
sources:
  - https://www.postgresql.org/docs/current/functions-subquery.html
  - https://wiki.postgresql.org/wiki/Count_estimate
last_verified: 2026-07-10
related: [databases-query-optimization-reading-execution-plans, databases-query-optimization-keyset-pagination]
---

# Existence Checks and Counts

## When this applies

Code needs "is there at least one…", "how many…", or gates logic on a row's
presence — validation checks, badges, dashboards, guard clauses.

## Do this

| Case | Do |
|------|----|
| Need only presence/absence | `SELECT EXISTS (SELECT 1 FROM ... WHERE ...)` — stops at the first matching row. In ORMs use the exists/`LIMIT 1` form, not a count comparison |
| Filter parents by child existence | `WHERE EXISTS (SELECT 1 FROM child WHERE child.parent_id = parent.id AND ...)` — also immune to the `NOT IN` NULL trap and to join-induced row duplication |
| Need an exact count for a filtered, indexed subset | `SELECT COUNT(*)` with the predicate; verify the plan uses the index. Exact counts over large sets scan every qualifying row — that cost is inherent |
| Need "N of M items" style UI over a big table | Show an estimate or a capped count (`SELECT COUNT(*) FROM (... LIMIT 1001) t` → display "1000+") |
| Counter displayed on every page load (unread badge, cart size) | Maintain it incrementally: counter column or cache updated on write, reconciled periodically — not a live aggregate per view |
| Approximate table-wide count is enough | Use planner statistics (PostgreSQL `pg_class.reltuples`) instead of scanning |

## Edge cases

| Case | Then |
|------|------|
| `COUNT(col)` vs `COUNT(*)` | `COUNT(col)` skips NULLs in that column — use it only when that is the intended semantics; otherwise `COUNT(*)` |
| Guard clause does exists-check then insert (check-then-act) | Two statements race under concurrency. Enforce with a unique constraint and handle the conflict (`ON CONFLICT` / duplicate-key error) — the exists-check is only a UX fast path |
| Counting distinct values over large sets | Exact `COUNT(DISTINCT ...)` is expensive; for analytics-grade needs use approximate distinct (e.g. HyperLogLog extensions) and label it approximate |

## Instead of

| If you are about to | Do this instead | Why |
|---------------------|-----------------|-----|
| `SELECT COUNT(*) ... > 0` to test existence | `SELECT EXISTS (...)` | COUNT scans all matches; EXISTS stops at one |
| Fetch rows into the application to `len()` them | `COUNT(*)` in SQL, or an incremental counter | Transferring rows to count them pays network and memory for data you discard |

## Sources

- https://www.postgresql.org/docs/current/functions-subquery.html — EXISTS semantics
- https://wiki.postgresql.org/wiki/Count_estimate — why exact counts are expensive, estimate techniques
