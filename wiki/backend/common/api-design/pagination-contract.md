---
id: backend-common-api-design-pagination-contract
domain: backend
category: api-design
applies_to: [general]
confidence: verified
sources:
  - https://google.aip.dev/158
  - https://docs.stripe.com/api/pagination
last_verified: 2026-07-10
related: [databases-query-optimization-keyset-pagination, databases-query-optimization-existence-and-count-checks]
---

# Designing a List Endpoint's Pagination Contract

## When this applies

Defining the request/response contract for an endpoint that returns a
collection (list, feed, search results, table rows). This page owns the API
shape; [databases-query-optimization-keyset-pagination] owns the SQL and index
that back it.

## Do this

1. Pick the contract by consumption pattern:

| Case | Contract |
|------|----------|
| Feed, infinite scroll, large set, or data that changes while paging (the default) | **Cursor-based**: request `limit` + opaque `cursor`; response `data[]` + `next_cursor` (null at end) or `has_more`. Backed by keyset SQL |
| Small, shallow, jump-to-page admin table | **Page-number**: `page` + `per_page`, with a documented maximum page depth stated in the API docs |

2. The cursor is **opaque**: encode the sort key plus a unique tiebreaker id
   (e.g. base64 of `created_at:id`), and document that clients must not parse
   it (AIP-158). Opacity lets you change the encoding, sort, or backing query
   without breaking clients.
3. Cap `limit` at a documented maximum (Stripe caps at 100). When a client
   requests more, coerce down to the maximum (AIP-158) and **return the limit
   actually applied** in the response so clients detect the cap instead of
   assuming their request was honored.
4. The sort order must be total: sort on a unique column, or append `id` as a
   tiebreaker. A non-unique sort key makes page boundaries skip or repeat rows.
5. Include `total_count` only when it is cheap (small bounded table) or when
   you return an estimate labeled as an estimate. Exact counts on large tables
   scan — [databases-query-optimization-existence-and-count-checks] owns that
   decision. `has_more`/`next_cursor` replaces the count for "is there a next
   page".
6. Expired or malformed cursor → 400 with a stable error code (e.g.
   `invalid_cursor`), documented so clients restart from the first page instead
   of retrying the same cursor.

## Edge cases

| Case | Then |
|------|------|
| Product asks for "jump to page N" on a cursor API | Serve the jump need with filters and sort options that narrow the list; deep offset jumps skip/repeat rows under concurrent writes and slow down linearly with depth |
| Rows inserted or deleted while a client pages | Cursor/keyset paging continues from the last-seen key without skips or duplicates at the boundary — this is why page-number is restricted to shallow admin views |
| Client needs a consistent full export | Serve exports as a job that walks the table by keyset with a fixed upper bound (e.g. `created_at <= job start`), not as client-driven live pagination |
| Backward paging (prev/next buttons) | Two mutually exclusive cursor params (Stripe: `starting_after` / `ending_before`); reject requests that send both with 400 |

## Instead of

| If you are about to | Do this instead | Why |
|---------------------|-----------------|-----|
| Expose raw `offset`/`limit` on an unbounded public list | Opaque cursor + limit | Offset reads and discards all skipped rows, and pages drift under concurrent writes |
| Put the literal sort value in the query string (`?after_id=123`) | Encode it inside the opaque cursor | Clients couple to your sort key and you can never change the ordering |
| Return exact `total_count` on every page of a large table | `has_more`/`next_cursor`, plus a labeled estimate only where the UI needs a number | Exact COUNT costs grow with the table and are recomputed per page |

## Sources

- https://google.aip.dev/158 — opaque page tokens, coercing oversized page sizes
- https://docs.stripe.com/api/pagination — cursor params (`starting_after`/`ending_before`), `limit` max 100, `has_more`
