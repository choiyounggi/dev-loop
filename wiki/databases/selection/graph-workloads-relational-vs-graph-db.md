---
id: databases-selection-graph-workloads-relational-vs-graph-db
domain: databases
category: selection
applies_to: [postgresql, neo4j]
confidence: verified
sources:
  - https://neo4j.com/blog/graph-database/graph-database-vs-relational-database/
  - https://www.pedroalonso.net/blog/graphrag-vs-vector-postgres/
  - https://developersvoice.com/blog/database/graph-databases-sql-server-vs-neo4j/
last_verified: 2026-09-03
related: [databases-selection-choosing-a-datastore-by-workload, databases-selection-vector-search-engine-selection, databases-schema-design-foreign-keys-and-referential-actions]
---

# Relationship-Heavy Data: Relational Joins/CTEs vs a Graph Database

## When this applies

The domain is connection-centric (social/follow graphs, org hierarchies, fraud
rings, dependency/lineage graphs, recommendations, knowledge graphs) and you
are deciding whether relational tables with joins and recursive CTEs suffice or
a graph database (Neo4j, Neptune, etc.) is warranted; or an existing
self-join/CTE query over a relationship table is becoming slow or unreadable.

## Do this

1. Model relationships relationally first: an edge table
   (`edges(src_id, dst_id, type, properties)`) with FKs and composite indexes
   both directions handles lookups, 1–2-hop joins, and bounded-depth
   `WITH RECURSIVE` traversals well — one less system.
2. Decide by **traversal shape**, not by whether the domain "is a graph":

| Case | Do |
|------|----|
| Lookups and 1–2-hop expansions (followers, direct reports, item's related items) | Relational joins on the edge table |
| Bounded-depth hierarchy walk (org chart, category tree, fan-out for RAG context) | `WITH RECURSIVE` CTE with a depth cap and cycle guard |
| Frequent unbounded/variable-depth traversals, pattern matching ("paths A→B where every hop is type X"), shortest-path/centrality/community algorithms | Graph database — native adjacency traverses per-hop without per-level self-joins, and Cypher/Gremlin expresses patterns recursive SQL cannot say readably |
| Relationship queries are rare/analytical while OLTP dominates | Keep relational as system of record; run graph analytics on an exported projection or a query layer over the tables |
| Aggregation-dominant workload (SUM/GROUP BY over entities) | Stay relational/columnar — graph engines are not built for bulk aggregation |

3. Adopt a graph database when at least two hold: traversal depth is unbounded
   or ≥3 hops in hot paths; the relationship itself carries queried data;
   graph algorithms (pathfinding, centrality) are product features. One
   symptom alone (an ugly CTE) is a query-tuning problem first.
4. If adopted alongside the relational DB, the graph is a **derived projection**
   of relational facts (one-way sync), per the gate in
   [databases-selection-choosing-a-datastore-by-workload] — including the team
   learning Cypher/Gremlin as a real adoption cost.

## Edge cases

| Case | Then |
|------|------|
| Recursive CTE slow at depth | Check the composite index covers the recursion's join direction (`(src_id)` vs `(dst_id)`), cap depth, and dedupe visited nodes in the CTE before concluding "we need a graph DB" |
| Cycles in the data hang the CTE | Track the path (`array` of visited ids) and prune revisits — `UNION` alone dedupes rows, not paths |
| "Knowledge graph for RAG" requirement | Entity fan-out for context assembly is bounded-depth → CTEs suffice; genuine multi-hop reasoning/link analysis between entities is the graph-DB case |
| Both graph traversal and similarity search needed | They are separate axes — vector selection → [databases-selection-vector-search-engine-selection]; combine via candidate-set handoff, not one engine for both |

## Instead of

| If you are about to | Do this instead | Why |
|---------------------|-----------------|-----|
| Introduce Neo4j because the ER diagram "looks like a graph" | Apply the traversal-shape table; every relational schema is a graph on paper | The differentiator is hot-path unbounded traversal, not the domain's connectedness |
| Re-implement shortest-path/centrality in application code over SQL rows | Use a graph engine (or in-process graph lib over an exported edge list) | Per-hop round-trips and join fan-out scale super-linearly; native adjacency and built-in algorithms are the graph engine's actual value |

## Sources

- https://neo4j.com/blog/graph-database/graph-database-vs-relational-database/ — join-depth cost vs native adjacency; when each fits
- https://www.pedroalonso.net/blog/graphrag-vs-vector-postgres/ — bounded fan-out favors recursive CTEs; pathfinding/link analysis favors a graph engine
- https://developersvoice.com/blog/database/graph-databases-sql-server-vs-neo4j/ — ≥3-hop readability/performance breakpoint; Cypher pattern matching vs recursive SQL
