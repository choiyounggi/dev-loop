---
id: testing-quality-store-assertions-after-a-rolled-back-run
domain: testing
category: quality
applies_to: [general]
confidence: verified
sources:
  - https://www.postgresql.org/docs/current/sql-rollback.html
  - https://peps.python.org/pep-0249/
last_verified: 2026-09-03
related: [testing-quality-write-path-assertions, testing-quality-tests-that-cannot-fail, testing-data-test-data-and-isolation, backend-common-orm-transaction-boundaries]
---

# Asserting Store State After a Run That Failed and Rolled Back

## When this applies

Writing a test that asserts on repository or store state after a workflow, job, or
interpreter run that failed partway through, when the runner rolls the store back on
any final status other than completed; a test that "saw the write land" mid-run and
then fails with a missing key or stale value after the run returns.

## Do this

1. Treat the store as holding pre-run state once a run has ended in failure.
   `ROLLBACK` (and a `.rollback()` call on the same connection or fake) discards
   every write made since the transaction began — including writes made before the
   step that failed, not only the failing step's own.
2. Assert on a record the runner keeps outside the transaction: trace entries,
   application logs, emitted events. An entry such as "assignment applied" with its
   target and value records what happened during the run regardless of whether the
   run's store changes survived.
3. When the store observation is unavoidable, read it before the runner decides the
   final status — inside the same transaction before the failing step's exception
   propagates, or from a pre-rollback hook — not after the run object reports failed.
4. Treat a reference captured mid-run as invalid after the run ends. An in-memory
   fake repository whose `find`/read returns the live stored object (not a copy)
   makes a write through that reference visibly land during the run; the same
   object is cleared or replaced when the rollback path executes, so an assertion
   on the captured reference after the run tests whatever the rollback left.

| You want to prove | Assert on |
|-------------------|-----------|
| A step before the failure ran and computed the right value | The trace/log entry for that step (target, value) |
| The failed run left no partial writes behind | The store, read fresh after the run, equals its pre-run snapshot |
| A completed run persisted its result | The store, read fresh after the run ([testing-quality-write-path-assertions]) |

## Edge cases

| Case | Then |
|------|------|
| The rollback branch keys on final status rather than on exceptions | Read the runner's status-handling branch to learn which statuses roll back; "non-completed" and "raised" are not always the same set |
| The trace itself is written inside the transaction that rolls back | It is not rollback-proof; confirm where the trace write sits relative to the transaction boundary before relying on it |
| The store is a real database rather than a fake | The same contract applies: `ROLLBACK` discards all updates since the transaction's start, not just the failing statement's |
| The test harness also wraps each test in a rolled-back transaction | That is test isolation ([testing-data-test-data-and-isolation]); the runner's own rollback happens inside it and is the one this page is about |

## Instead of

| If you are about to | Do this instead | Why |
|---------------------|-----------------|-----|
| Assert `repo.find(id)["field"] == expected` after an intentionally failed run | Assert on the trace or log entries the run emitted | The write was real during the run; the runner's rollback-on-failure branch discards it before the test observes it |
| Keep a mid-run reference to a fake repository's row and assert on it after the run | Read the store fresh after the run through the same path the runner uses | A live-reference fake makes "the returned row is the stored object" true only until the rollback path clears it |

## Sources

- https://www.postgresql.org/docs/current/sql-rollback.html — "ROLLBACK rolls back the current transaction and causes all the updates made by the transaction to be discarded"
- https://peps.python.org/pep-0249/ — `.rollback()` "causes the database to roll back to the start of any pending transaction. Closing a connection without committing the changes first will cause an implicit rollback to be performed"
- Field reproduction 2026-08-31 (linkly interpreter, in-memory fake repository): a test asserting `report_row(interp)["totalClicks"] == 0` after an intentionally failed workflow run (empty row set: `sum` succeeded, `avg` raised) got `KeyError`; traced to `run_workflow` calling `self.repo.rollback()` in the non-completed branch right after its `try/except RunError` block, discarding the earlier write. Asserting on `trace.to_dict()["logs"]` entries with `message == "assignment applied"` proved the earlier step instead
