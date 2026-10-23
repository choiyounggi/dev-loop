---
id: databases-transactions-isolation-level-selection
domain: databases
category: transactions
applies_to: [postgresql, mysql]
confidence: verified
sources:
  - https://www.postgresql.org/docs/current/transaction-iso.html
  - https://dev.mysql.com/doc/refman/8.0/en/innodb-transaction-isolation-levels.html
  - https://www.postgresql.org/docs/current/indexes-partial.html
last_verified: 2026-10-23
related: [databases-schema-design-soft-delete, databases-query-optimization-existence-and-count-checks, databases-schema-design-requirements-to-tables, databases-transactions-optimistic-vs-pessimistic-locking, databases-transactions-multi-row-reorder-on-a-shared-resource, testing-quality-proving-a-critical-section-is-lock-protected]
---

# Choosing Transaction Behavior for Concurrent Writes

## When this applies

A transaction reads data and then writes based on what it read (balance check →
debit, availability check → book, read-modify-write), or you are diagnosing lost
updates / duplicate bookings under concurrency.

## Do this

1. Know your baseline: PostgreSQL defaults to Read Committed, MySQL/InnoDB to
   Repeatable Read. At both defaults, **check-then-act on the same rows can still
   race** — two transactions both pass the check, both write.
2. Pick the narrowest tool that closes your race:

| Case | Do |
|------|----|
| Single-row read-modify-write, no precondition (counter, running total) | Atomic statement: `UPDATE t SET n = n + ? WHERE id = ?` — no explicit locking needed |
| Single-row read-modify-write **with a precondition** (reserve the last unit, debit only if balance suffices) | Fold the precondition into the statement: `UPDATE t SET stock = stock - 1 WHERE id = ? AND stock >= 1`, then check affected rows — 0 means the condition no longer holds (reject that request). Exactly one of N concurrent requests wins, at default isolation, no locks |
| Check a row, then act with logic that cannot fold into one `UPDATE`'s `WHERE` (multi-step validation, external decision between read and write) | Lock the row at read: `SELECT ... FOR UPDATE`, then act inside the same transaction |
| Insert-if-absent (unique registration) | Unique constraint + `INSERT ... ON CONFLICT` / handle duplicate-key error — an exists-check alone races |
| Invariant spans multiple rows (sum of bookings ≤ capacity) | `SERIALIZABLE` isolation with retry-on-serialization-failure, or serialize writers on one advisory/parent-row lock |
| Read a consistent snapshot across several queries (reports) | `REPEATABLE READ` (PostgreSQL) — all reads see one snapshot; no write locks needed |
| Genuinely no conflicting writers (append-only logs) | Default isolation, no locks |

3. If you raise isolation to `REPEATABLE READ`+ (PostgreSQL) or use `SERIALIZABLE`,
   **write the retry loop**: these levels abort conflicting transactions
   (serialization failure) instead of blocking; code without retry turns safety into
   user-facing errors.
4. Keep lock-holding transactions short: no external API calls, no user waits inside
   a transaction holding row locks.

## Edge cases

| Case | Then |
|------|------|
| `FOR UPDATE` on rows joined from multiple tables | Lock only the table you'll update: `FOR UPDATE OF t` — otherwise you serialize on rows you never write |
| Two transactions lock the same rows in different orders | Deadlock. Impose one global lock ordering (e.g. by table then ascending id) and batch-lock with one ordered `SELECT ... FOR UPDATE` |
| You receive `deadlock detected` (PostgreSQL 40P01 / MySQL 1213) | Working as designed: the DB found the cycle and rolled back one transaction. Retry the rolled-back transaction (same loop as serialization failures); reduce recurrence with the lock-ordering row above |
| Read-modify-write cannot fold into one statement AND spans user think time or multi-step validation | Choose the locking style by conflict frequency → [databases-transactions-optimistic-vs-pessimistic-locking] |
| MySQL Repeatable Read + `UPDATE` based on stale snapshot reads | Updates see current rows (semi-consistent behavior differs from the read snapshot); apply the conditional-`UPDATE` row above — precondition in the `WHERE`, 0 affected rows = rejected |
| Undecided whether stock is a counter column or reservation rows summed against capacity | The data model decides the locking row: counter column → conditional `UPDATE`; reservation rows → the multi-row invariant row. Model per [databases-schema-design-requirements-to-tables] before choosing machinery |
| Queue-style "grab next unprocessed row" | `SELECT ... FOR UPDATE SKIP LOCKED LIMIT 1` — workers skip contended rows instead of queueing on them |
| Duplicate-key errors on a `unique (parent…, seq)` key where the application computes `seq` (`MAX(seq)+1`) and the write also deactivates the previous row (history kept as a new `seq`) | Before making the numbering atomic, name the rule the collision was enforcing by accident (one active row per parent, when the write deactivates the previous row) and declare it: `CREATE UNIQUE INDEX … ON t (parent…) WHERE active`; map its violation to a user-facing conflict. Atomic numbering alone turns the error into silent corruption: each transaction's deactivating `UPDATE` cannot see the other's uncommitted row, so both commit active |

## Instead of

| If you are about to | Do this instead | Why |
|---------------------|-----------------|-----|
| Rely on `@Transactional` / a transaction alone to prevent concurrent oversell | Fold the precondition into a conditional atomic UPDATE, or take a row lock per the table above | Transaction boundaries control visibility and atomicity of YOUR writes; at default isolation two transactions can both read stock=1, both pass the check, and both commit — no error, stock oversold |

## Sources

- https://www.postgresql.org/docs/current/transaction-iso.html — isolation levels, serialization failures
- https://dev.mysql.com/doc/refman/8.0/en/innodb-transaction-isolation-levels.html — InnoDB level semantics
- https://www.postgresql.org/docs/current/transaction-iso.html — Read Committed: "a SELECT query … sees only data committed before the query began; it never sees either uncommitted data or changes committed by concurrent transactions during the query's execution"
- https://www.postgresql.org/docs/current/indexes-partial.html — Example 11.3, a partial unique index to "ensure that there is only one “successful” entry for a given subject and target combination"
- Reproduction 2026-10-23 (PostgreSQL 16.11, throwaway local cluster, two concurrent sessions each running `UPDATE … SET active='N' WHERE parent=1 AND active='Y'` then `INSERT … (1, nextval(seq), 'Y')`, the first holding its transaction 2 s): with only `unique(parent, seq)` both committed and 2 rows were active; with `CREATE UNIQUE INDEX … ON rel(parent) WHERE active='Y'` the second session waited for the first to commit and failed with `duplicate key value violates unique constraint`, leaving 1 active row
- Field case 2026-09 (a parent-to-child relation table with history `seq`): two concurrent registrations both computed `seq = 1` and one failed on the composite key; an existing-relation guard read before commit did not prevent it
