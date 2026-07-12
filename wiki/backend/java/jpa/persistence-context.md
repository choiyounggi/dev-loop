---
id: backend-java-jpa-persistence-context
domain: backend
category: jpa
applies_to: [java, kotlin, jpa, hibernate, spring]
confidence: verified
sources:
  - https://docs.hibernate.org/orm/6.6/userguide/html_single/Hibernate_User_Guide.html
  - https://vladmihalcea.com/jpa-persist-and-merge/
  - https://vladmihalcea.com/the-best-way-to-do-batch-processing-with-jpa-and-hibernate/
  - https://vladmihalcea.com/postgresql-serial-column-hibernate-identity/
last_verified: 2026-07-10
related: [backend-java-jpa-entity-mapping, backend-common-orm-transaction-boundaries]
---

# JPA Persistence Context — Dirty Checking, Detachment, and Batch Writes

## When this applies

Debugging changes that were saved without any `save()`/`persist()` call; stale reads
inside one transaction; "detached entity passed to persist" or lost updates after
`merge()`; JPA batch inserts that are slow or exhaust memory.

## Do this

1. Treat the persistence context as a per-transaction identity map plus dirty
   tracker: every entity loaded in the transaction is managed, and any field change
   on a managed entity is flushed to the DB as an UPDATE at flush time — no explicit
   save call required. When you mutate data you do not intend to persist (display
   formatting, what-if computation), mutate a DTO or a detached copy — leave the
   managed entity untouched.
2. Expect identity-map reads: repeated `find()`/query hits for the same id in one
   transaction return the same instance from the first-level cache — commits from
   other transactions are invisible until you start a new transaction. To re-read
   current DB state mid-flow, start a new transaction (or `refresh()` the entity,
   accepting that it overwrites in-memory changes).
3. Know when flush happens (Hibernate `AUTO` flush): before executing a JPQL/native
   query that touches a table with pending changes, and at commit. A query can
   therefore trigger UPDATEs "early", and reordering statements changes what the
   query sees.
4. Handle detached entities (from a closed context, an HTTP session, or a cache) by
   the operation table:

| Operation on a detached entity | Result | Do |
|--------------------------------|--------|----|
| `merge(detached)` | Loads current row, copies detached state onto a NEW managed instance, returns it | Keep using the returned instance; the argument stays detached and untracked |
| `persist(detached)` (id already set) | Fails (`detached entity passed to persist` / `EntityExistsException`) | `persist` only for new entities; use `merge` for reattachment |

5. Write batches in chunks: enable JDBC batching (`hibernate.jdbc.batch_size=25..100`)
   and every chunk call `flush()` then `clear()` so the context does not accumulate
   every persisted entity in memory. Commit per chunk — chunked transactions and
   resumability are owned by [backend-common-orm-transaction-boundaries].
6. Choose the id generator by write pattern:

| Table | Generator |
|-------|-----------|
| Batch-heavy inserts | `SEQUENCE` (Hibernate gets ids before INSERT, so inserts batch) |
| `IDENTITY`/serial column already in place | Accept that insert batching is disabled — Hibernate must execute each INSERT immediately to learn the id; migrate to `SEQUENCE` when batch insert speed matters |

## Edge cases

| Case | Then |
|------|------|
| An UPDATE appears in the SQL log that no code path saves | A managed entity was mutated and auto-flushed — find the mutation and apply directive 1 (mutate a copy/DTO) |
| Updates from `merge()` silently lost | Code kept mutating the detached argument instead of the returned managed instance — switch to the return value |
| Batch job memory grows linearly with rows processed | Per-entity `persist()` with no `flush()`/`clear()` — apply directive 5 chunking |
| `batch_size` set but inserts still go one-by-one | The entity uses `IDENTITY` generation — see the generator table; also set `hibernate.order_inserts=true` when multiple entity types interleave |

## Instead of

| If you are about to | Do this instead | Why |
|---------------------|-----------------|-----|
| Mutate a managed entity for a computation you won't save | Copy to a DTO and mutate that | Dirty checking persists the mutation at flush whether or not you call save |
| Call `save()`/`persist()` on an already-managed entity "to be sure" | Rely on dirty checking; save only new entities | The extra call adds a merge/persist pass; changes to managed entities flush regardless |
| Reuse the detached object after `merge()` | Use the managed instance `merge()` returned | The argument is never attached; further edits to it are lost |
| Loop `persist()` over 100k rows in one context | Chunk with `batch_size` + `flush()`/`clear()` + per-chunk commit → [backend-common-orm-transaction-boundaries] | The context holds every entity (memory) and defers all inserts to one giant flush |

## Sources

- https://docs.hibernate.org/orm/6.6/userguide/html_single/Hibernate_User_Guide.html — AUTO flush on commit and before JPQL/HQL/native queries; `hibernate.jdbc.batch_size`; fetch/managed-state semantics
- https://vladmihalcea.com/jpa-persist-and-merge/ — persist for new entities only; merge fetches current state and returns a new managed instance
- https://vladmihalcea.com/the-best-way-to-do-batch-processing-with-jpa-and-hibernate/ — batch_size configuration, per-chunk flush/clear and commit
- https://vladmihalcea.com/postgresql-serial-column-hibernate-identity/ — IDENTITY forces immediate INSERT and disables insert batching; prefer SEQUENCE
