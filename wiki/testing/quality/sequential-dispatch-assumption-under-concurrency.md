---
id: testing-quality-sequential-dispatch-assumption-under-concurrency
domain: testing
category: quality
applies_to: [general]
confidence: verified
sources:
  - https://docs.python.org/3/library/concurrent.futures.html
  - https://martinfowler.com/articles/nonDeterminism.html
  - https://testing.googleblog.com/2017/04/where-do-our-flaky-tests-come-from.html
last_verified: 2026-09-10
related: [testing-quality-tests-that-cannot-fail, testing-flaky-diagnosing-flaky-tests, backend-common-concurrency-shared-state-and-pools, backend-python-concurrency-gil-and-concurrency-model, testing-quality-proving-a-critical-section-is-lock-protected]
---

# A Sequential-Dispatch Test's Exact-Count Assertion After the Loop Becomes Concurrent

## When this applies

A previously-sequential per-item dispatch loop (`for item in items: process(item)`)
is being parallelized (`ThreadPoolExecutor`/equivalent), and an existing test
sets a flag or raises from inside one item's processing mid-run and then
asserts an exact call count or exact per-item state — a "stop after item N"
or "only N items ran" style assertion.

## Do this

1. **Before trusting such a test still passes under the new concurrent code,
   run it with the real default (or production-configured) concurrency cap —
   not a synthetic `max_workers=1`.** A cap-of-1 test double forces strict
   one-at-a-time dispatch, which is exactly the sequential assumption the
   migration invalidated; green under cap=1 proves nothing about the
   concurrent path and hides the bug.
2. **Flag any such test whose item count is ≤ the real cap as a likely
   sequential-dispatch assumption.** `Executor.submit()` schedules the
   callable and returns immediately — it does not wait for earlier
   submissions to start or finish. When `max_workers` ≥ the item count, every
   item's task is created and can pass a start-of-task "check the flag" gate
   before any one item's side effect (setting the flag, raising) becomes
   visible to it, because submission for later items races ahead of the
   earlier item's in-progress work rather than waiting on it.
3. Resolve by item-count-vs-cap, not by tightening the assertion in place:

| Case | Do |
|------|----|
| Item count ≤ real cap; the test's intent is to verify the stop-check logic itself | Pin that test's own executor to `max_workers=1` deliberately and name it as verifying the guard in isolation from scheduling (e.g. `test_stop_check_logic_sequential`) — this is a legitimate unit test of the predicate, not a claim about concurrent behavior |
| Item count ≤ real cap; the test's intent is to verify behavior under real concurrent dispatch | Rewrite the assertion to what non-blocking submission actually guarantees: all items already submitted before the flag was observably set will run — assert "≤ cap items ran, and the stop is honored only for items submitted in a later batch" (or, if the loop submits every item up front in one batch, assert that all of them ran and the flag only prevents a *second* round of submissions) |
| Item count > real cap | The cap genuinely throttles dispatch — an exact-count assertion can still hold once submission is restructured to check the flag before each `submit()` call, not only inside each task |

## Edge cases

| Case | Then |
|------|------|
| Migrating test doubles as coverage for `shutdown(cancel_futures=True)` draining | `cancel_futures=True` cancels only futures the executor has not started running; already-running futures complete regardless. Assert against "started" count, not "submitted" count |
| The stop condition is an exception raised from item processing rather than an explicit flag write | The exception surfaces only when `.result()` is called on that specific future; other already-submitted tasks are unaffected by it. Assert per-future outcomes individually rather than assuming the dispatch loop halts on the first exception |
| The test currently passes only because its fixture hardcodes `max_workers=1` | That configuration is not evidence the migrated code is correct — it forces exactly the sequential order the migration removed; still run once at the real cap per step 1 before merging |

## Instead of

| If you are about to | Do this instead | Why |
|---------------------|-----------------|-----|
| Trust a migrated "stop after item N" test because it is green under a synthetic `max_workers=1` fixture | Re-run it under the real default/production cap before merging | cap=1 forces strict one-at-a-time dispatch — the exact sequential assumption the migration invalidated; green there says nothing about the concurrent path |
| Leave a pre-existing exact-call-count test unexamined after swapping a sequential loop for a thread pool | Compare its item count to the real concurrency cap; when count ≤ cap, split or rewrite it per the decision table | Under `max_workers` ≥ item count, `submit()` returns immediately, so every task can pass a start-of-task flag check before an earlier item's side effect lands |

## Sources

- https://docs.python.org/3/library/concurrent.futures.html — `Executor.submit()` "schedules the callable... and returns a Future" (non-blocking); `ThreadPoolExecutor` default `max_workers` is `min(32, (os.process_cpu_count() or 1) + 4)` (3.13+); `shutdown(cancel_futures=True)` cancels only futures "the executor has not started running" — running/completed futures are unaffected
- https://martinfowler.com/articles/nonDeterminism.html — tests that encode a hidden ordering/timing assumption pass under the old execution model and fail once that assumption is removed; poll/assert the actual guaranteed condition instead of an incidental one
- https://testing.googleblog.com/2017/04/where-do-our-flaky-tests-come-from.html — threading/concurrency changes are a measured source of tests whose pass/fail depends on an execution-order assumption the test never states
- Field reproduction, 2026-09-10 (CPython 3.14.6, `concurrent.futures.ThreadPoolExecutor`): 3 tasks, `max_workers=4`, task for `i==1` sets a `threading.Event` before running; each task checks the event at its own top and returns early if set. Result: all 3 tasks ran (`ran: [0, 1, 2]`) — the flag never took effect, because all 3 were submitted and passed their gate check before task 1's side effect became visible. The identical harness with `max_workers=1` produced `ran: [0, 1]`, `skipped-2` — strict sequential dispatch is what made the original assertion true, not the stop logic
- Field observation, 2026-09-10 (a Python per-company contact pipeline, `tests/test_resume.py::TestGracefulShutdown::test_shutdown_stops_after_current_company`, 3 companies, default `MAX_COMPANY_WORKERS=4`): passed under the prior sequential-loop dispatch; went deterministically red (`call_count` 3 vs expected 1) the moment per-company dispatch moved to `ThreadPoolExecutor` — reproduced on repeated runs via `sh scripts/run_tests.sh` (265/266 passing, only this test failing), not a flake
