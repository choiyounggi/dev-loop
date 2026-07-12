---
id: databases-query-optimization-keyset-pagination
domain: databases
category: query-optimization
applies_to: [postgresql, mysql, general]
confidence: verified
sources:
  - https://use-the-index-luke.com/no-offset
  - https://www.postgresql.org/docs/current/queries-limit.html
last_verified: 2026-07-10
related: [databases-indexing-composite-index-column-order]
---

# Paginating Large Result Sets

## When this applies

You are implementing pagination (API list endpoints, infinite scroll, batch export)
over a table that is or will become large.

## Do this

| Case | Do |
|------|----|
| Sequential access: next/previous, infinite scroll, batch jobs walking a table | **Keyset pagination**: `WHERE (sort_key, id) > (:last_sort_key, :last_id) ORDER BY sort_key, id LIMIT :n`, backed by an index on `(sort_key, id)`. Cost per page is constant regardless of depth |
| UI genuinely needs "jump to page N" with page numbers | `LIMIT/OFFSET` is acceptable for shallow depths; cap the maximum page (e.g. ≤ ~100 pages) and measure — OFFSET scans and discards all skipped rows, so cost grows linearly with depth |
| Batch export of an entire table | Keyset on the primary key; never OFFSET-walk a table |

Implementation rules for keyset:

1. The sort key must be **totally ordered and stable**: append the primary key as a
   tiebreaker, because equal sort values otherwise skip or repeat rows across pages.
2. Encode the cursor as the last row's `(sort_key, id)` values (opaque token in APIs),
   not as a row number.
3. Create the composite index in the exact sort order
   ([databases-indexing-composite-index-column-order]).

## Edge cases

| Case | Then |
|------|------|
| Rows inserted/deleted between page fetches | Keyset stays consistent relative to the cursor (no skips/repeats at the boundary); OFFSET shifts silently — another reason deep OFFSET pagination corrupts exports |
| Descending order | Flip both the comparison and the index direction: `WHERE (k, id) < (...) ORDER BY k DESC, id DESC` |
| Sort key is a timestamp with duplicates | The `id` tiebreaker is mandatory, not optional — timestamp-only cursors lose rows created in the same instant |
| MySQL row-value comparison `(a,b) > (?,?)` | Optimizes poorly on some versions; rewrite as `a > ? OR (a = ? AND b > ?)` and verify the plan uses the index range |
| Total count display ("Page 1 of 3,514") | Serve counts from an estimate or cached aggregate; an exact `COUNT(*)` per page view costs a full scan of the filtered set |
| Client requests a page beyond the OFFSET cap | Pick one behavior and state it in the API contract: reject with a validation error steering to cursor parameters, or clamp to the cap and mark the response truncated |

## Sources

- https://use-the-index-luke.com/no-offset — keyset pagination rationale and patterns
- https://www.postgresql.org/docs/current/queries-limit.html — LIMIT/OFFSET semantics
