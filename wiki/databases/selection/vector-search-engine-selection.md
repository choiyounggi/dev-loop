---
id: databases-selection-vector-search-engine-selection
domain: databases
category: selection
applies_to: [postgresql, pgvector]
confidence: verified
sources:
  - https://github.com/pgvector/pgvector
  - https://nisai.dev/guides/vector-databases-compared-2026/
  - https://qdrant.tech/blog/pgvector-tradeoffs/
  - https://tensoria.fr/en/blog/vector-database-comparison
last_verified: 2026-09-03
related: [databases-selection-choosing-a-datastore-by-workload, databases-selection-graph-workloads-relational-vs-graph-db]
---

# Choosing Where Embedding/Similarity Search Lives

## When this applies

Adding semantic search, RAG retrieval, or recommendation over embeddings, and
deciding between a vector extension in the existing relational database
(pgvector) and a dedicated vector engine (Qdrant, Weaviate, Pinecone, Milvus);
or an existing pgvector setup is hitting limits and you are judging when to
move.

## Do this

1. Start with the vector capability of the database you already run (pgvector
   with an HNSW index in PostgreSQL). Up to roughly the single-digit millions of
   vectors on adequately sized RAM, benchmarks show it matching dedicated
   engines, and it keeps embeddings transactionally consistent with their source
   rows — no sync pipeline.
2. Filtered search is the common real workload — prefilter with SQL `WHERE` on
   the same row's columns (tenant, ACL, date) combined with the vector index;
   this joint filtering in one system is pgvector's main structural advantage.
3. Move to a dedicated vector engine when a **specific limit is measured**, not
   preemptively:

| Measured limit | Move indicator |
|----------------|----------------|
| Vector count beyond what one instance's RAM holds (HNSW for 10M × 1536-dim float32 ≈ 60–70 GB) | Dedicated engine with quantization/disk-backed indexes, or dimensionality/quantization reduction first |
| Index rebuild/insert throughput stalls bulk re-embedding | Dedicated engine with faster index maintenance |
| Vector query load starves OLTP (shared buffers/CPU contention) | Separate the search layer so it scales independently |
| Need native horizontal scaling / multi-tenant namespace isolation at hundreds of millions of vectors | Managed dedicated engine |
| Hybrid dense+sparse (BM25 + vector) ranking as a first-class feature | Engine with built-in hybrid search |

4. When you do split, treat the vector store as a **derived index**: embeddings
   are re-derivable projections of source rows, synced one-way (CDC/outbox) —
   the general polyglot rule → [databases-selection-choosing-a-datastore-by-workload].
   Practitioners report source↔vector-store sync as the top operational pain of
   dedicated stores; budget it as a feature, not glue.

## Edge cases

| Case | Then |
|------|------|
| Recall drops after heavy row churn (HNSW graph degrades on deletes) | Scheduled `REINDEX`/index rebuild; if rebuild windows are unacceptable, that is a genuine move indicator |
| Highly selective metadata filter + HNSW returns too few results | Tune `hnsw.ef_search` up, or use iterative index scans (pgvector ≥ 0.8) / partial indexes per hot filter |
| Embeddings change model/dimension | Version the embedding column/collection and re-embed offline; either store choice must support dual-version rollover |
| "We might reach 100M vectors" with no current traffic | Record the trigger metric and stay consolidated — dedicated infra for hypothetical scale is the anti-pattern in the parent page's gate |

## Instead of

| If you are about to | Do this instead | Why |
|---------------------|-----------------|-----|
| Spin up a dedicated vector DB for a first RAG prototype | pgvector in the DB you run (or SQLite-vec/an in-process index for toys) | Prototype scale never exercises what dedicated engines are for; you pay the sync+ops tax immediately |
| Store embeddings only in the vector engine | Keep source text + embedding-version in the system of record; engine holds a projection | Lost/corrupt index becomes a re-embed job instead of data loss |

## Sources

- https://github.com/pgvector/pgvector — HNSW/IVFFlat options, filtering, iterative scans
- https://nisai.dev/guides/vector-databases-compared-2026/ — "move only on a specific limit: rebuild time, hybrid search, single-instance scale"
- https://qdrant.tech/blog/pgvector-tradeoffs/ — dedicated-store advantages and the sync pain (from the vendor arguing for moving)
- https://tensoria.fr/en/blog/vector-database-comparison — 1M-scale parity benchmarks; 10M × 1536-dim HNSW RAM footprint
