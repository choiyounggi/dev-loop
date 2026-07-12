---
id: databases-query-optimization-n-plus-one-queries
domain: databases
category: query-optimization
applies_to: [general, jpa-hibernate, activerecord, django-orm]
confidence: verified
sources:
  - https://vladmihalcea.com/n-plus-1-query-problem/
  - https://docs.djangoproject.com/en/stable/ref/models/querysets/#select-related
last_verified: 2026-07-10
related: [databases-query-optimization-large-in-lists, databases-query-optimization-reading-execution-plans]
---

# Loading Parent Rows with Their Associations (N+1)

## When this applies

Code loads a list of N rows, then accesses an association per row — producing 1 list
query plus N per-row queries. Typical smell: a loop whose body triggers lazy loading,
or a list endpoint whose query count scales with result size.

## Do this

1. **Detect by counting statements, not by reading code.** Enable statement logging
   or a test-time query counter; assert list endpoints run O(1) queries regardless
   of row count.
2. Choose the batching strategy per shape:

| Case | Do |
|------|----|
| To-one association needed for every row (author of each post) | Fetch with a join in the list query: JPA `join fetch` / entity graph, ActiveRecord `includes` (or `eager_load`), Django `select_related` |
| To-many association (comments of each post) | Load in a second batched query by parent ids, then stitch in memory: JPA `@BatchSize` or a separate `WHERE parent_id IN (...)` query, ActiveRecord `includes`, Django `prefetch_related` — joining to-many rows into the list query multiplies parent rows |
| Only aggregates needed (comment count per post) | Query the aggregate grouped by parent id (`GROUP BY parent_id`) or maintain a counter column; loading full children to count them is waste |
| Deep chains (posts → comments → authors) | Batch each level explicitly (nested prefetch/entity graph); verify total query count is O(depth), not O(rows) |

3. Keep lazy loading as the default mapping and batch **per use case** at the query
   site — global eager fetching trades N+1 for over-fetching every caller.

## Edge cases

| Case | Then |
|------|------|
| Endpoint needs both a to-one and an aggregate per row (author + comment count) | The strategies compose: join-fetch the to-one in the list query, plus one grouped aggregate query — two statements total, still O(1) |
| Join-fetching two to-many collections at once (JPA `MultipleBagFetchException`, row explosion elsewhere) | Fetch one collection per query: split into sequential batched queries on the same parent set |
| Batched `IN` list grows with page size × association fan-out | Apply the large-IN rules ([databases-query-optimization-large-in-lists]) |
| Pagination plus to-many join fetch | The database paginates joined rows, not parents (JPA may paginate in memory). Paginate parent ids first, then batch-load associations for that page |
| Serializer/template accesses a field nobody batched | Query counter in tests catches it; add the association to the endpoint's fetch spec |

## Sources

- https://vladmihalcea.com/n-plus-1-query-problem/ — JPA/Hibernate detection and fixes
- https://docs.djangoproject.com/en/stable/ref/models/querysets/#select-related — select_related/prefetch_related semantics
