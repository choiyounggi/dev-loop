---
id: backend-node-convex-parallel-children-writing-one-parent-document
domain: backend
category: convex
applies_to: [convex, convex-test, convex-workpool]
confidence: verified
sources:
  - https://docs.convex.dev/error
  - https://docs.convex.dev/testing/convex-test
  - convex-test 0.0.60 npm package, dist/index.js, TransactionManager.begin
  - "@convex-dev/workpool npm package README, section Reducing database write conflicts"
last_verified: 2026-11-04
related: [databases-transactions-optimistic-vs-pessimistic-locking, backend-node-convex-ascii-keys-in-returned-objects]
---

# Parallel Convex Jobs That Report Into One Parent Document

## When this applies

A Convex job fans out parallel actions (a workpool, scheduled functions), and
each child or its `onComplete` handler patches one shared parent document.
Also when the job passes under `convex-test` and fails on a deployment with
"changed while this mutation was being run and on every subsequent retry".

## Do this

1. Write each child's result to its own ledger row, with a unique key per slot.
2. Advance the parent in one finalizer mutation, which reads the ledger after
   the children finish.
3. Add a test that counts writes to the parent. The count grows with job steps,
   and stays flat as the number of children grows.
4. Run the job once on a real deployment with a realistic child count before
   calling it proven.

| Writers per document | Do |
|----------------------|----|
| One child per row | Plain insert or patch |
| Many children, one aggregate value | Ledger rows plus one finalizer; a sharded counter for a running total |
| A few short writes per second must hit one document, and waiting in line is acceptable | Enqueue that mutation on a workpool with `maxParallelism: 1`; it runs serially, so it cannot conflict with itself |
| A progress display needs live numbers | Read the count from the ledger rows, and keep the parent out of the per-child path |

## Edge cases

| Case | Then |
|------|------|
| The conflict names a component function, such as a workpool `complete` | Look at what its `onComplete` callback writes: workpool 0.4.13 can run the callback inline in that mutation, and schedules it otherwise |
| Reads also conflict after the writes moved | Narrow the mutation's reads with selective index ranges; the error also covers a mutation reading a whole table while another writes to it |
| A mutation under test awaits `setTimeout` to widen a race | `convex-test` rejects it as unsupported in queries and mutations; a mock cannot show this race at any timing, so use a deployment |

## Instead of

| If you are about to | Do this instead | Why |
|---------------------|-----------------|-----|
| Treat a green `convex-test` run as proof of concurrency safety | Count parent writes in the test and run once on a deployment | `convex-test` serializes top-level transactions, so two mutations never conflict there |
| Keep the fan-out and hope internal retries absorb the conflicts | Move the writes off the shared document, or serialize that one mutation | The docs say retries run out when calls arrive faster than they execute, and name the data model as the fix |

## Sources

- https://docs.convex.dev/error — write conflict error text, internal retries, and the remedy: design the data model so it does not need many writes to the same document
- https://docs.convex.dev/testing/convex-test — Limitations section; the mock lacks many backend behaviors. It does not mention concurrency, so the serialization claim rests on the source below
- convex-test 0.0.60, dist/index.js, `TransactionManager` — comment "restricts `convexTest` to run one function at a time"; `begin` waits on `_waitOnCurrentFunction` for each top-level transaction
- @convex-dev/workpool README, "Reducing database write conflicts (aka OCC errors)" — a mutation on a pool with `maxParallelism: 1` "will never throw an error due to conflicts with parallel mutations"
- @convex-dev/workpool 0.4.13, dist/component/complete.js — `onComplete` runs through `ctx.runMutation` when `runOnCompleteInline` is set, and through `ctx.scheduler.runAfter(0, ...)` otherwise
- Local reproduction 2026-11-04 (convex 1.46.0, convex-test 0.0.60): 34 mutations in `Promise.allSettled`, each reading and patching one document, gave 0 rejections and a final count of 34
- Field report: a job with 34 parallel children passed 281 `convex-test` tests, then failed on a development deployment with this conflict on the parent table
