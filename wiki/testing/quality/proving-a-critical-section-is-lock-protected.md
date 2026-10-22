---
id: testing-quality-proving-a-critical-section-is-lock-protected
domain: testing
category: quality
applies_to: [general, python, postgresql]
confidence: verified
sources:
  - https://docs.python.org/3/library/sys.html#sys.setswitchinterval
  - https://docs.python.org/3/faq/library.html#what-kinds-of-global-value-mutation-are-thread-safe
  - https://testing.googleblog.com/2021/04/mutation-testing.html
  - https://docs.python.org/3/howto/free-threading-python.html
  - https://node-postgres.com/apis/pool
  - https://www.postgresql.org/docs/current/transaction-iso.html
  - https://www.postgresql.org/docs/current/functions-admin.html
last_verified: 2026-10-11
related: [testing-quality-tests-that-cannot-fail, testing-quality-harness-reverse-controls, debugging-concurrency-intermittent-failures, backend-python-concurrency-gil-and-concurrency-model, backend-common-concurrency-shared-state-and-pools, testing-quality-sequential-dispatch-assumption-under-concurrency, databases-transactions-isolation-level-selection]
---

# Proving a Lock-Protected Critical Section Actually Needs Its Lock

## When this applies

Proving a shared-mutable-state critical section is lock-protected under concurrent
writers (e.g. `with lock: shared[key] += n`): a many-thread stress test passes with
or without the lock; auditing whether a concurrency test can fail; a limit counter
(rate limit, quota, seats) behind a database pool passes its race test without the lock.

## Do this

1. **Treat raw thread-count/iteration-count stress as insufficient on its own.** A plain
   in-memory read-modify-write (`d[k] += 1`) rarely straddles a GIL thread
   switch: reproduced 2026-09-10 (CPython 3.14.6, GIL enabled), 16 threads ×
   10 increments with the lock removed reached the correct total of 160 in
   20/20 trials — 0 races detected. The window is real (per
   [backend-python-concurrency-gil-and-concurrency-model], the GIL only
   guarantees one thread runs bytecode *at a time*, not that a whole
   statement is atomic — the Python FAQ lists `D[x] = D[x] + 1` explicitly as
   non-atomic) but too narrow for stress to reliably land in it.
2. **Widen the window deterministically with a test double**, not a longer
   stress run. Wrap the shared container in a subclass whose mutating method
   sleeps inside the read-modify-write span — e.g. a dict subclass whose
   `__setitem__` calls `time.sleep(0.001)` before writing. Reproduced same
   session: 16 threads × 10 increments through that double, lock removed,
   reached only 10 (never 160) in 10/10 trials; with `with lock:` restored,
   reached 160 in 10/10 trials.
3. **Validate the test itself by mutation before trusting it** — the same
   discipline as [testing-quality-tests-that-cannot-fail] step 1: remove the
   lock from the production code, rerun, require red; restore the lock,
   rerun, require green. A concurrency test that has not been through this
   cycle is unproven regardless of how it reads.
4. Choose the technique by what you are proving:

| Situation | Do |
|-----------|-----|
| Confirming *some* concurrent-safety exists, order not important | Raw stress (many threads × iterations) is enough — cheap, but cannot prove a missing lock would be caught |
| Proving a specific critical section needs its lock, and the mutation (lock removed) must reliably fail | Injected-delay test double widening the critical section, per step 2 |
| Either technique, before citing the test as evidence | Mutation check (step 3) — a test that cannot go red under a real mutation is not evidence either way |

5. **Size the sleep against the switch interval and the test budget.** CPython's
   default thread-switch interval is 5 ms (`sys.getswitchinterval()`); a
   per-write sleep at or above that order of magnitude reliably yields the
   GIL mid-critical-section. Keep total added time bounded —
   `threads × iterations × sleep`: 16 × 10 × 1 ms ≈ 160 ms per trial above,
   fast enough to run on every CI invocation rather than only on demand.
6. **For a limit counter checked through a database connection pool, seed the
   store to one below the limit and assert exactly one success.** Fire two or
   more concurrent requests: with the lock one is admitted, and without it every
   transaction that reads the count before another commits is admitted. A race
   from an empty store is decided by commit timing: N requests admit at most N
   rows, so with N at or below the limit the lock-removed mutant cannot exceed
   it; with N above the pool size, a queued request starts as soon as one client
   is released (node-postgres: requests "wait in a FIFO queue until a client
   becomes available"), and it reads a stale count only in the runs where other
   transactions are still open. The step-2 delay does not replace the seed here.
   Measured 2026-10-11 (PostgreSQL 18.6, node-postgres pool `max` 10, limit 10,
   13 concurrent reservations, each `BEGIN` → `pg_advisory_xact_lock` in the
   locked variant → `count(*)` → conditional `INSERT` → `COMMIT`):

| Store before the burst | With the lock | Lock removed |
|---|---|---|
| Seeded to 9 (limit − 1) | 1 success in 20/20 runs | 5–10 successes in 20/20 runs |
| Empty | 10 in 20/20 runs | 10–13; exactly 10, the locked result, in 2 of 30 runs |
| Empty, `pg_sleep(0.05)` between the count and the insert | 10 in 10/10 runs | Exactly 10 in 19 of 30 runs |

## Edge cases

| Case | Then |
|------|------|
| Target runs on a CPython 3.13+ free-threaded (no-GIL) build | The race window is real concurrent execution, not just a switch — the injected-delay double still applies and becomes *more* reliable at finding races, since there is no GIL serializing the interpreter loop at all ([backend-python-concurrency-gil-and-concurrency-model] free-threaded row) |
| The mutated operation is one the Python FAQ already lists as atomic (`L.append(x)`, `D[x] = y`, `x = y`) | Skip the delay double — there is no read-modify-write span to widen, and a lock around an already-atomic op is not what the test needs to catch |
| Sleep is too short relative to thread count/iterations | The window narrows back toward stress-only odds; raise the per-write sleep before adding more threads |
| Sleep is too long relative to the CI time budget | Reduce iterations per thread rather than the per-write sleep — cutting the sleep reopens the gap that made the test unable to fail |
| Critical section already uses a C-level atomic primitive (`itertools.count().__next__`, an `atomics`-style library, a DB's atomic increment) | No Python-level lock or injected delay is the right target — verify atomicity against that primitive's own documentation instead |
| A step-6 burst of N requests is at or below the remaining capacity (limit minus the rows already stored) | The lock-removed mutant cannot over-admit in any run; make N larger than the remaining capacity — seeding to limit − 1 does it with N = 2 |
| Seeding rows is awkward (the count comes from another table or service) | Set the limit below the burst's concurrency instead: limit 5, empty store, pool 10 gave 5 with the lock in 10/10 runs and 9–11 without it in 20/20 runs |

## Instead of

| If you are about to | Do this instead | Why |
|---------------------|-----------------|-----|
| Rely on raw thread-count/iteration-count stress alone to prove a critical section needs its lock | Inject an artificial delay inside the critical section via a test double (e.g. a dict subclass whose `__setitem__` sleeps) so the read-modify-write span reliably overlaps across threads | A 16-thread/160-increment stress test with no injected delay passed 100% of the time (20/20) even with the lock completely removed from production code; only the injected delay made the same broken code fail deterministically (10 vs 160) |
| Race N requests from an empty store whose limit equals the pool size | Seed the store to limit − 1, fire two or more concurrent requests, and assert exactly one success (step 6) | Without the lock the empty-store race still read exactly the limit in 2 of 30 runs here and in 10 of 10 runs in the originating session; the seeded control separated in 20/20 runs |

## Sources

- https://docs.python.org/3/library/sys.html#sys.setswitchinterval — the thread switch interval controls how often CPython considers switching threads between bytecode instructions; its default order of magnitude sizes the injected sleep
- https://docs.python.org/3/faq/library.html#what-kinds-of-global-value-mutation-are-thread-safe — `D[x] = D[x] + 1` and `i = i+1` are explicitly listed as non-atomic; `D[x] = y`, `L.append(x)`, `x = y` are atomic and need no widening
- https://testing.googleblog.com/2021/04/mutation-testing.html — a test proves detection only if it fails when the guarded behavior is removed; the mutation-check discipline this page applies specifically to concurrency tests
- https://docs.python.org/3/howto/free-threading-python.html — the 3.13+ free-threaded (GIL-disabled) build changes the underlying concurrency model
- Local reproduction 2026-09-10 (CPython 3.14.6, GIL enabled, `sys._is_gil_enabled()` → True): plain `dict` `+=`, 16 threads × 10 increments, no lock, 20/20 trials landed on 160 (0 races detected); the same shape through a `__setitem__`-sleeping (1 ms) dict subclass, no lock, 10/10 trials landed on 10; with `with lock:` restored, 10/10 trials landed on 160
- https://node-postgres.com/apis/pool — `max`: "By default this is set to 10."; "If the pool is ‘full’ and all clients are currently checked out, requests will wait in a FIFO queue until a client becomes available by being released back to the pool."
- https://www.postgresql.org/docs/current/transaction-iso.html — Read Committed: "a SELECT query (without a FOR UPDATE/SHARE clause) sees only data committed before the query began"
- https://www.postgresql.org/docs/current/functions-admin.html — `pg_advisory_xact_lock`: "Obtains an exclusive transaction-level advisory lock, waiting if necessary."; transaction-level locks "are held until the current transaction ends"
- Local reproduction 2026-10-11 (postgres:18.6-alpine in Docker, node-postgres, Node 26.7.0; successes per run, 10-run batches): seeded to 9 — locked 1 in all 20 runs of two batches, lock removed [10,9,10,8,7,9,9,8,10,5] and [9,6,10,9,10,10,10,10,10,10]; empty — locked 10 in all 20 runs of two batches, lock removed [13,13,13,10,12,13,12,13,11,13], [10,11,11,11,13,13,13,13,12,13] and [13,13,11,13,13,13,12,13,13,13]; empty with `pg_sleep(0.05)` — locked 10 in all 10 runs of one batch, lock removed [10,10,12,10,10,10,13,10,10,10], [10,10,10,10,10,10,10,11,10,10] and [13,12,11,13,13,13,11,10,10,13]; limit 5 from empty — locked 5 in all 10 runs of one batch, lock removed [10,10,10,10,10,10,9,10,10,10] and [9,10,11,10,11,10,11,10,11,10]
- Field origin 2026-10-10 (linkly-invitation task t2b, Testcontainers postgres:18.6-alpine, pool 10, limit 10, 13 concurrent reservations, 10 runs each; recorded by the originating session, not re-run in this flush): from an empty store 10 successes with and without the lock; seeded to 9, 1 with the lock and 10 without
