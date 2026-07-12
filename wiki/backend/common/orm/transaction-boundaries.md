---
id: backend-common-orm-transaction-boundaries
domain: backend
category: orm
applies_to: [general]
confidence: verified
sources:
  - https://docs.spring.io/spring-framework/reference/data-access/transaction/declarative/annotations.html
  - https://docs.spring.io/spring-framework/reference/data-access/transaction/declarative/tx-propagation.html
  - https://vladmihalcea.com/spring-transaction-best-practices/
last_verified: 2026-07-10
related: [backend-common-jobs-idempotent-handlers, backend-common-errors-exception-handling, databases-transactions-isolation-level-selection]
---

# Transaction Boundaries in Application Code

## When this applies

Deciding where a DB transaction starts and ends in application code — service
methods, `@Transactional`-style annotations or decorators. Also when debugging
partial writes, a "transaction silently marked as rollback-only" error, or
connection-pool exhaustion around open transactions.

## Do this

1. One business operation = one transaction, opened at the use-case/service-layer
   entry method and spanning every write of that operation. The HTTP controller
   stays outside the boundary (serialization and response work is not DB work).
   Individual repository calls stay inside one shared boundary — a boundary per
   repository call commits each statement separately, so a mid-operation failure
   leaves earlier writes permanently committed.
2. Keep only DB work inside the boundary:

| Work | Where it goes |
|------|---------------|
| External HTTP call whose result the writes depend on (validation, price lookup) | Before the transaction |
| External effect announcing the writes (email, webhook, event) | After commit — record it in a transactional outbox inside the transaction, deliver from a job → [backend-common-jobs-idempotent-handlers] |
| Slow computation | Compute before; only write inside |

3. Know the annotation/decorator mechanics (framework-agnostic; Spring is the
   documented example):

| Mechanic | Rule |
|----------|------|
| Self-invocation (`this.method()`) | Bypasses the proxy — no transaction at runtime and no error. Route the call through the container-managed reference, or move the annotation to the entry method called from outside |
| Method visibility | Interface-based proxies advise `public` methods only; Spring 6+ class-based proxies also advise `protected`/package-visible. Confirm your framework's rule before annotating a non-public method |
| Nested calls (default propagation `REQUIRED`) | The inner annotated method joins the outer physical transaction; an inner failure marks the shared transaction rollback-only, and the outer commit throws `UnexpectedRollbackException` |
| Inner step that must survive an outer rollback (audit log) | Give it its own physical transaction (`REQUIRES_NEW`) — and accept that it commits even when the outer operation rolls back |
| Pure reads | Mark the boundary read-only — enables driver/ORM optimizations and read-replica routing |

4. Keep transactions short: row locks are held until commit and block concurrent
   writers for the boundary's full duration — lock behavior per isolation level
   → [databases-transactions-isolation-level-selection].

## Edge cases

| Case | Then |
|------|------|
| Connection pool exhausts under load while transactions sit open across an external call | The connection is pinned for the call's full latency; move the call out per the table above — this fixes the exhaustion without growing the pool |
| `UnexpectedRollbackException` at the outer commit | An inner joined method failed and marked the shared transaction rollback-only; find the swallowed inner exception rather than catching the rollback error — catch/log placement → [backend-common-errors-exception-handling] |

## Instead of

| If you are about to | Do this instead | Why |
|---------------------|-----------------|-----|
| Let each repository call run in its own transaction | One service-layer transaction per business operation | Per-call commits make partial failure permanent — half the operation's writes survive the crash |
| Open the transaction in the HTTP controller | Open it at the service/use-case entry method | Response serialization holds the connection and row locks with no DB work left to do |
| Wrap a batch of thousands of rows in one transaction | Chunked transactions with per-chunk commit and idempotent resume via checkpointing → [backend-common-jobs-idempotent-handlers] | One giant transaction holds locks for the whole run, and a crash at row 9,999 redoes everything |
| Call an external API inside the transaction | Call it before (validation) or after commit (outbox delivery) | Locks and the pooled connection are held for the API's latency; an API timeout rolls back finished DB work |

## Sources

- https://docs.spring.io/spring-framework/reference/data-access/transaction/declarative/annotations.html — proxy-mode interception, self-invocation bypass, method-visibility rules, `REQUIRED` default settings
- https://docs.spring.io/spring-framework/reference/data-access/transaction/declarative/tx-propagation.html — inner scope marking the shared transaction rollback-only, `UnexpectedRollbackException`, `REQUIRES_NEW` independent transaction
- https://vladmihalcea.com/spring-transaction-best-practices/ — service layer as the owner of transaction boundaries; read-only transaction benefits (replica routing)
