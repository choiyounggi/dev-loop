---
id: databases-transactions-multi-row-reorder-on-a-shared-resource
domain: databases
category: transactions
applies_to: [postgresql, general]
confidence: verified
sources:
  - https://www.postgresql.org/docs/current/explicit-locking.html
  - https://www.postgresql.org/docs/current/sql-createtable.html
  - https://www.postgresql.org/docs/current/sql-set-constraints.html
  - https://www.postgresql.org/docs/current/sql-insert.html
  - "Field evidence 2026-08-31 (linkly-calendar orchestration run, review findings t1 F2 / t3 F1): a shared-calendar reorder shipped as unguarded per-row updates; fixed to a parent-row lock inside one transaction with a DB upsert"
last_verified: 2026-09-06
related: [databases-transactions-isolation-level-selection, databases-transactions-optimistic-vs-pessimistic-locking, backend-common-orm-transaction-boundaries]
---

# Rewriting Several Rows at Once on a Resource Several Writers Share

## When this applies

Designing or reviewing an operation that updates many rows of one parent in a
single user action — drag-to-reorder positions in a shared list, bulk status
changes, re-ranking, re-numbering — where the parent (a shared calendar, board,
playlist, team) is edited by more than one client; a review asks "what happens
when two users reorder at once"; a `unique (parent_id, position)` constraint
exists or is proposed.

## Do this

**Settle three things at design time, before the first migration; on a shared
resource the concurrent writer is the normal path, not an exception.**

1. **Transaction boundary: one transaction per user action, holding a lock on
   the parent row.** `SELECT ... FROM parent WHERE id = $1 FOR UPDATE` as the
   first statement, then every child write, then commit. Two simultaneous
   reorders then run one after the other, each seeing the other's committed
   result; without it, row-level last-writer-wins interleaves two intended orders
   into one nobody asked for ([databases-transactions-isolation-level-selection],
   multi-row invariant row).

2. **Uniqueness on position: decide whether the constraint exists, and how the
   transient state passes it.**

| Constraint on `(parent_id, position)` | Do |
|---------------------------------------|----|
| Wanted, and the write is a full rewrite of the parent's rows | Declare it `UNIQUE (...) DEFERRABLE INITIALLY DEFERRED` so the check runs at commit, or run `SET CONSTRAINTS ... DEFERRED` inside the transaction; an immediate constraint fails mid-rewrite when row B takes A's old slot before A has moved |
| Wanted, and the constraint must stay immediate | Two-phase write inside the transaction: shift every affected row to a temporary range (`position = -position`, or `+ offset`), then to the final values |
| Not wanted | The parent lock in step 1 is the ordering guarantee; state in the schema comment that positions are unique by protocol, not by constraint, and add the uniqueness assertion to the reorder's tests |

3. **Final-state rule: define what the committed result is when writes race.**
   Pick one and encode it in the write:

| Rule | Write shape |
|------|-------------|
| Whole-list replace (the last committed action defines the full order) | The client sends the full ordered id list; the server rewrites all positions with `INSERT ... ON CONFLICT (parent_id, item_id) DO UPDATE SET position = EXCLUDED.position` (upsert) inside the locked transaction |
| Merge (each action moves one item; the others keep their relative order) | The server recomputes positions from the current committed order plus the one move; the client sends the move, not the list |
| Reject stale (the action was computed on an older list) | Version column on the parent; the write carries the version it read; 0 affected rows → 409 ([databases-transactions-optimistic-vs-pessimistic-locking]) |

4. **Test with two writers.** One test opens two transactions, issues both
   reorders, and asserts that the committed order equals what the chosen rule
   predicts and that positions are unique after both commit; a single-writer
   test proves none of the three decisions.

## Edge cases

| Case | Then |
|------|------|
| Rows are inserted and deleted in the same action as the reorder | Same transaction, same parent lock; delete first, then upsert positions, so a deleted row cannot hold a slot the constraint check sees |
| The ORM issues one `UPDATE` per row under autocommit | Wrap the action explicitly ([backend-common-orm-transaction-boundaries]); per-row autocommit is the interleaving case in step 1 |
| Many parents are reordered in one request | Lock the parent rows in one ordered `SELECT ... FOR UPDATE` (ascending id) so lock order stays global and deadlocks are avoided |
| Positions are fractional or sparse keys (LexoRank-style) so a move touches one row | Step 2's constraint question disappears for the moving row, but two movers inserting between the same neighbours still produce equal keys; keep the parent lock, or make the key unique and retry on conflict |
| Readers must see a consistent order mid-rewrite | Readers at Read Committed see either the pre-commit or the post-commit order, never the interleaving, because the rewrite is one transaction |

## Instead of

| If you are about to | Do this instead | Why |
|---------------------|-----------------|-----|
| Update each row's position in its own statement with no surrounding transaction | One transaction per action, parent row locked first | Two concurrent actions interleave per row and commit an order neither user intended |
| Add `UNIQUE (parent_id, position)` and update positions in place | Make it `DEFERRABLE INITIALLY DEFERRED`, or write through a temporary range | An immediate unique check fails on the first row that lands in another row's not-yet-vacated slot |
| Treat the concurrent-reorder case as "rare, handle later" | Decide the three rules now and test with two writers | On a shared resource the second writer is the default; a later retrofit changes the write shape and the API |

## Sources

- https://www.postgresql.org/docs/current/explicit-locking.html — `FOR UPDATE` "causes the rows retrieved by the SELECT statement to be locked as though for update. This prevents them from being locked, modified or deleted by other transactions until the current transaction ends"
- https://www.postgresql.org/docs/current/sql-createtable.html — `DEFERRABLE` / `NOT DEFERRABLE`: "Checking of constraints that are deferrable can be postponed until the end of the transaction (using the SET CONSTRAINTS command)"
- https://www.postgresql.org/docs/current/sql-set-constraints.html — "DEFERRED constraints are not checked until transaction commit"
- https://www.postgresql.org/docs/current/sql-insert.html — `ON CONFLICT DO UPDATE`, "also known as UPSERT"
- Field evidence 2026-08-31 (linkly-calendar orchestration run, review findings t1 F2 and t3 F1): the shared-calendar reorder was implemented as unguarded per-row updates; the review required the three decisions above and the fix landed as a pessimistic parent lock inside a single transaction with a DB-level upsert
