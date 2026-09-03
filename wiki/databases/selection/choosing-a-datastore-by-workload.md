---
id: databases-selection-choosing-a-datastore-by-workload
domain: databases
category: selection
applies_to: [general]
confidence: verified
sources:
  - https://martinfowler.com/bliki/PolyglotPersistence.html
  - https://www.sysdesai.com/learn/data-management-patterns/polyglot-persistence
  - https://tacnode.io/post/polyglot-persistence-and-the-retrieval-gap
last_verified: 2026-09-03
related: [databases-selection-relational-jsonb-vs-document-store, databases-selection-vector-search-engine-selection, databases-selection-graph-workloads-relational-vs-graph-db, databases-schema-design-requirements-to-tables]
---

# Choosing a Datastore for a New System or Workload

## When this applies

Designing a new system/service and deciding which database(s) it uses; a design
proposes adding a second datastore (document, vector, graph, search, cache)
alongside the existing one; comparing "one general-purpose DB" against
per-workload specialized stores (polyglot persistence).

## Do this

1. Default to one general-purpose relational database (e.g. PostgreSQL) as the
   **system of record**. It covers transactional integrity, joins, ad-hoc
   queries, and — via extensions — moderate document (JSONB), full-text, and
   vector workloads in a single operational surface.
2. Add a specialized store only when a **specific, demonstrated workload limit**
   is named, not from the data's "shape" alone. Before adding one, answer all
   three:

| Question | Add the store only if |
|----------|-----------------------|
| Is the existing DB measurably failing at this workload? | Yes, and indexing/tuning inside it was tried first |
| Does the data have a fundamentally different access pattern or lifecycle? | Yes (e.g. TTL-based metrics, similarity search, deep traversals) |
| Can the team operate the new store in production? | Yes — backups, upgrades, monitoring are owned |

3. Map the workload to the store type when step 2 passes:

| Dominant workload | Store type |
|-------------------|-----------|
| Check-then-act writes, invariants across rows, ad-hoc joins/reporting | Relational (system of record) |
| Self-contained hierarchical records, schema varies per record | Document store, or JSONB in the relational DB → [databases-selection-relational-jsonb-vs-document-store] |
| Semantic/similarity search over embeddings | Vector index/engine → [databases-selection-vector-search-engine-selection] |
| Multi-hop relationship traversal, pathfinding, pattern matching | Graph engine → [databases-selection-graph-workloads-relational-vs-graph-db] |
| Full-text/faceted search at scale | Search engine (derived index) |
| Ephemeral hot state (sessions, counters, queues) | In-memory KV cache |

4. Keep exactly **one system of record per fact**. Every specialized store is a
   *derived projection* of it, rebuilt from the source of truth — the projection
   direction is one-way (record → index), so a lost or corrupt index is
   re-derivable, never authoritative.
5. Budget the real cost of each added store when comparing options: a sync
   pipeline (dual writes race and drift — use CDC/outbox), separate backup and
   upgrade procedures, and cross-store queries that can no longer join.

## Edge cases

| Case | Then |
|------|------|
| Two workloads pull toward different stores but data volume is small (< millions of rows) | Stay on the relational DB with extensions; revisit when a limit is measured |
| The app is analytics/reporting-dominant (bulk scans, aggregations) | That axis is row-store vs columnar warehouse, not relational vs NoSQL — pick a warehouse for the reporting copy, keep OLTP relational |
| A managed platform bundles several models (e.g. Postgres + JSONB + pgvector) | Treat it as one store operationally — the three-question gate applies to new *systems*, not new extensions |
| The specialized store is proposed as the system of record (e.g. "MongoDB for everything") | Apply the same gate in reverse: name the relational capability being given up (joins, cross-document transactions, constraints) and who re-implements it |

## Instead of

| If you are about to | Do this instead | Why |
|---------------------|-----------------|-----|
| Pick a store because the data "looks like documents/a graph" | Pick by the dominant *query pattern* and demonstrated limits | Shape is cheap to project; a store chosen against the query pattern is expensive to leave |
| Dual-write the same fact to two stores from application code | Write to the system of record, project asynchronously (CDC/outbox) | Dual writes fail independently and drift silently; sync is the #1 reported pain of polyglot setups |
| Add a store "for future scale" with no measured limit | Record the trigger metric that would justify it and defer | Each store adds a permanent ops + consistency tax that starts on day one; the scale may never come |

## Sources

- https://martinfowler.com/bliki/PolyglotPersistence.html — polyglot persistence defined; per-workload store choice
- https://www.sysdesai.com/learn/data-management-patterns/polyglot-persistence — the adoption gate questions (measured limit, lifecycle, ops readiness)
- https://tacnode.io/post/polyglot-persistence-and-the-retrieval-gap — sync/consistency cost of multi-store architectures
