---
id: backend-java-jpa-entity-mapping
domain: backend
category: jpa
applies_to: [java, kotlin, jpa, hibernate, spring]
confidence: verified
sources:
  - https://vladmihalcea.com/eager-fetching-is-a-code-smell/
  - https://vladmihalcea.com/the-best-way-to-handle-the-lazyinitializationexception/
  - https://vladmihalcea.com/jpa-hibernate-synchronize-bidirectional-entity-associations/
  - https://vladmihalcea.com/the-best-way-to-implement-equals-hashcode-and-tostring-with-jpa-and-hibernate/
  - https://vladmihalcea.com/the-open-session-in-view-anti-pattern/
  - https://vladmihalcea.com/hibernate-multiplebagfetchexception/
last_verified: 2026-07-10
related: [backend-java-jpa-persistence-context, databases-query-optimization-n-plus-one-queries]
---

# JPA Entity Association Mapping and Entity Identity

## When this applies

Writing or reviewing JPA/Hibernate entity classes and their associations; debugging
`LazyInitializationException`; debugging extra queries or joins that trace back to
mapping annotations rather than the query itself.

## Do this

1. Set the fetch type per association kind — EAGER on a mapping is a tax every query
   loading that entity pays, and it cannot be turned off at query time; LAZY can be
   fetched eagerly per use case in the query
   ([databases-query-optimization-n-plus-one-queries] owns the N+1 mechanics):

| Association | JPA default | Do |
|-------------|-------------|----|
| `@ManyToOne`, `@OneToOne` | EAGER | Declare `fetch = FetchType.LAZY` explicitly on every one |
| `@OneToMany`, `@ManyToMany` | LAZY | Keep the default |

2. In a bidirectional association, only the owning side (the side holding the FK,
   without `mappedBy`) is written to the database. Sync both sides in one place —
   helper methods on the parent (`addChild` sets `child.setParent(this)` and adds to
   the collection; `removeChild` nulls it and removes) — and make callers use only
   those helpers. Setting just the `mappedBy` side persists nothing.
3. Base `equals`/`hashCode` on identity that stays stable across entity state
   transitions:

| Entity has | Base equality on |
|------------|------------------|
| An immutable business key (natural id, e.g. ISBN) | That key, in both `equals` and `hashCode` |
| A generated id only | `equals` compares ids and returns false while either id is null; `hashCode` returns a constant (e.g. `getClass().hashCode()`) so the hash does not change when the id is assigned at persist |

4. When a lazy association is needed by a use case, fetch it in that use case's query
   — `JOIN FETCH` in JPQL or an entity graph — inside the transaction. That is the
   fix for `LazyInitializationException`: the exception means the association was
   touched after the persistence context closed.
5. For read-only endpoints, select a DTO projection (constructor expression /
   interface projection) instead of loading entities — no managed state, no lazy
   associations to trip on, smaller SELECT list.

## Edge cases

| Case | Then |
|------|------|
| `MultipleBagFetchException` when join-fetching two `List` collections in one query | Fetch one collection per query (two queries on the same entity set); the persistence context assembles the full graph. Changing `List` to `Set` compiles but produces a cartesian product — keep the queries separate |
| Entity "disappears" from a `HashSet` after `persist()` | Its `hashCode` changed when the id was assigned — apply the constant-`hashCode` pattern from the table above |
| `LazyInitializationException` thrown during JSON serialization of a returned entity | The serializer walks lazy fields after the transaction closed — return a DTO projection, or add the needed association to that query's `JOIN FETCH` |
| One entity is loaded by many queries that each need different associations | Keep every mapping LAZY and give each query its own fetch plan (`JOIN FETCH`/entity graph per use case) |

## Instead of

| If you are about to | Do this instead | Why |
|---------------------|-----------------|-----|
| Set an association EAGER to stop `LazyInitializationException` | `JOIN FETCH`/entity graph in the query of the use case that needs it | EAGER loads the association on every query of that entity forever, including the ones that never read it |
| Enable Open Session in View (`spring.jpa.open-in-view=true`) to survive lazy access in the view | Fetch everything the response needs inside the service transaction, or return a DTO | OSIV holds the DB connection through view rendering — connection lease time grows with render time and the pool congests under load |
| Put Lombok `@Data`/`@EqualsAndHashCode` on an entity | Hand-write `equals`/`hashCode` per the identity table above | Generated versions use all mutable fields; equality changes as state changes and hash-based collections break |
| Set only `child.setParent(parent)` or only `parent.getChildren().add(child)` | Call the sync helper that sets both sides | Only the owning (FK) side persists; a one-sided update leaves the in-memory graph and the DB disagreeing |

## Sources

- https://vladmihalcea.com/eager-fetching-is-a-code-smell/ — to-one defaults EAGER; EAGER cannot be overridden at query time; fetch per use case
- https://vladmihalcea.com/the-best-way-to-handle-the-lazyinitializationexception/ — JOIN FETCH and DTO projection as the fixes; EAGER and OSIV rejected
- https://vladmihalcea.com/jpa-hibernate-synchronize-bidirectional-entity-associations/ — owning side semantics, add/remove sync helper methods
- https://vladmihalcea.com/the-best-way-to-implement-equals-hashcode-and-tostring-with-jpa-and-hibernate/ — business-key equality; id equality with constant hashCode across state transitions
- https://vladmihalcea.com/the-open-session-in-view-anti-pattern/ — OSIV holds the connection through UI rendering; throughput cost
- https://vladmihalcea.com/hibernate-multiplebagfetchexception/ — two-List join fetch failure; one-collection-per-query fix; Set switch creates cartesian product
