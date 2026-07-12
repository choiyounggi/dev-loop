---
id: databases-transactions-optimistic-vs-pessimistic-locking
domain: databases
category: transactions
applies_to: [postgresql, mysql, jpa-hibernate, general]
confidence: verified
sources:
  - https://vladmihalcea.com/optimistic-vs-pessimistic-locking/
  - https://www.postgresql.org/docs/current/explicit-locking.html
last_verified: 2026-07-10
related: [databases-transactions-isolation-level-selection]
---

# Optimistic vs Pessimistic Locking

## When this applies

A multi-step read-modify-write cannot fold into one conditional atomic statement
(user edits a form, multi-field business validation between read and write), and
you must choose how concurrent writers to the same rows are handled. (When the
operation CAN fold into one `UPDATE ... WHERE <precondition>`, do that — no lock
of either kind: [databases-transactions-isolation-level-selection].)

## Do this

**Conflict frequency decides — not preference.**

| Case | Do |
|------|----|
| Conflicts are rare (writers seldom target the same row at the same moment) | **Optimistic**: add a `version INT NOT NULL DEFAULT 0` column; write with `UPDATE t SET ..., version = version + 1 WHERE id = ? AND version = ?`; 0 affected rows = someone else won — re-read and retry or surface the conflict. No locks held; readers never wait |
| Conflicts are concentrated on the same rows (flash sale, seat booking, one hot account) | **Pessimistic**: `SELECT ... FOR UPDATE` at the read; writers queue in order, each attempt succeeds once it runs. Throughput of one row is serialized, but no work is wasted |
| The gap between read and write includes user think time (edit form open for minutes) | Optimistic only — a row lock cannot be held across user think time; the version check on save detects that someone else saved meanwhile (classic lost-update guard for stale form submits) |
| Retrying is expensive (long transaction, external side effects inside) | Pessimistic — optimistic retries repeat the whole unit of work |

**Optimistic requires the retry loop to be written**: check affected rows on every
versioned UPDATE; 0 rows is a normal outcome, not an error to ignore — re-read the
current row, re-apply the change or report the conflict to the user. An
unchecked 0-row update silently loses the write.

ORM note (JPA/Hibernate): `@Version` implements the version column and throws an
optimistic-lock exception on conflict; `LockModeType.PESSIMISTIC_WRITE` issues
`FOR UPDATE`. The decision table above is unchanged by the ORM.

## Edge cases

| Case | Then |
|------|------|
| Optimistic under heavy contention | Retry storm: N competitors for one row produce O(N²) attempts — each winner invalidates every concurrent loser, which all re-read and retry. Switch that hot path to pessimistic (or better, a conditional atomic UPDATE) |
| Pessimistic + multiple rows locked per transaction | Lock in one global order to avoid deadlocks; on `deadlock detected`, retry ([databases-transactions-isolation-level-selection] edge rows) |
| Mixed access: most paths rare-conflict, one path hot | Choose per path, not per table — optimistic as the default, `FOR UPDATE` only in the hot endpoint |
| Version column on an API resource | Expose it as an ETag/`If-Match` so stale clients get 409/412 instead of overwriting ([databases-transactions-isolation-level-selection] covers the write; the HTTP shape belongs to the API error contract) |

## Instead of

| If you are about to | Do this instead | Why |
|---------------------|-----------------|-----|
| Add `FOR UPDATE` everywhere "to be safe" | Optimistic by default, pessimistic on measured hot rows | Blanket row locks serialize unrelated traffic and invite deadlocks |
| Ignore the affected-row count of a versioned UPDATE | Treat 0 rows as a conflict branch (retry or 409) | Silent 0-row updates are lost writes |

## Sources

- https://vladmihalcea.com/optimistic-vs-pessimistic-locking/ — trade-offs, retry cost under contention
- https://www.postgresql.org/docs/current/explicit-locking.html — row-level lock semantics of FOR UPDATE
