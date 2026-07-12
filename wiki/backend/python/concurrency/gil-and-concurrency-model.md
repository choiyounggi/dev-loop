---
id: backend-python-concurrency-gil-and-concurrency-model
domain: backend
category: concurrency
applies_to: [python, cpython]
confidence: verified
sources:
  - https://docs.python.org/3/glossary.html#term-global-interpreter-lock
  - https://docs.python.org/3/library/asyncio-dev.html
  - https://docs.python.org/3/library/asyncio-task.html#asyncio.to_thread
  - https://docs.python.org/3/library/multiprocessing.html
  - https://docs.python.org/3/howto/free-threading-python.html
last_verified: 2026-07-10
related: [backend-common-concurrency-shared-state-and-pools, backend-common-jobs-idempotent-handlers, backend-python-serving-app-servers-and-workers]
---

# The GIL and Choosing Threads vs asyncio vs Processes

## When this applies

Choosing threads vs asyncio vs processes for a Python workload; a "parallel"
Python service uses only one core; an asyncio service hangs or stalls under
load; a coroutine calls a synchronous library.

## Do this

1. CPython's GIL allows one thread to execute Python bytecode at a time. The
   GIL is always released during I/O, and C extensions (numpy, compression,
   hashing) release it during heavy computation. Choose by workload:

| Workload | Do |
|----------|----|
| Blocking I/O, moderate concurrency (tens of in-flight operations) | Use threads — the GIL is released while a thread waits on I/O, so threads overlap I/O correctly |
| High-concurrency I/O (hundreds+ of in-flight operations) | Use asyncio — one thread, tasks yield at explicit `await` points; requires async-native libraries end to end |
| CPU-bound pure-Python work | Use a process pool (`multiprocessing.Pool` / `concurrent.futures.ProcessPoolExecutor`) — subprocesses side-step the GIL; threads give ~zero speedup because bytecode execution is serialized |
| CPU-bound numeric work on arrays | Use a GIL-releasing C extension (numpy et al.) — then threads do run the computation in parallel |
| Mixed CPU + request handling in one service | Keep CPU work out of the request path: enqueue it to a worker process → [backend-common-jobs-idempotent-handlers]; the request handler stays I/O-shaped |

2. The asyncio blocking trap: a synchronous call inside a coroutine
   (`requests`, `time.sleep`, a heavy CPU loop, a sync DB driver) stalls the
   **whole event loop** — every task and connection on that loop waits until
   the call returns. Replace by case:

| Blocking call in async code | Replace with |
|-----------------------------|--------------|
| Sync HTTP / DB / Redis client | The async-native client for that system |
| Sync-only library doing blocking I/O (no async equivalent) | `asyncio.to_thread(fn, ...)` or `loop.run_in_executor(None, fn)` — runs it on a thread; works because the GIL is released during I/O |
| CPU-heavy function | `loop.run_in_executor` with a `ProcessPoolExecutor` — a thread executor does not help here, the GIL keeps the loop's thread starved |

3. Detect blocking with event loop debug mode: set `PYTHONASYNCIODEBUG=1` or
   `asyncio.run(main(), debug=True)`. Callbacks running longer than 100 ms are
   logged; tune the threshold via `loop.slow_callback_duration` (seconds).

4. Adding threads or tasks means handlers now share in-process mutable state —
   apply [backend-common-concurrency-shared-state-and-pools] to that state.

## Edge cases

| Case | Then |
|------|------|
| CPython 3.13+ free-threaded (GIL-disabled) build is available | Decide by the table above for production services today — extension packages that are not free-threading-ready re-enable the GIL at import, and the build carries single-threaded overhead (1–8%) plus higher memory use |
| Work passed to a process pool | Arguments and results are pickled across process boundaries — pass small picklable values, not open connections or large objects |
| Service is deployed under gunicorn/uvicorn workers | The worker model multiplies whichever choice you make here — worker-count and blocking interactions → [backend-python-serving-app-servers-and-workers] |

## Instead of

| If you are about to | Do this instead | Why |
|---------------------|-----------------|-----|
| Add threads to speed up a pure-Python CPU loop | Use a process pool | The GIL serializes bytecode — threads add switching overhead, not parallelism |
| Call `requests`/`time.sleep`/a sync driver inside a coroutine | Async client, or `asyncio.to_thread` for sync-only libraries | One blocking call stalls every task on the loop |
| Raise worker/instance counts because an async service intermittently hangs | Run with `PYTHONASYNCIODEBUG=1` and find the slow callback | Scaling multiplies the stalled loops; the blocking call is the fault |

## Sources

- https://docs.python.org/3/glossary.html#term-global-interpreter-lock — one thread executes bytecode at a time; GIL always released during I/O; extensions release it for compression/hashing
- https://docs.python.org/3/library/asyncio-dev.html — blocking (CPU-bound) code must not be called directly in coroutines; `run_in_executor` for threads or processes; debug mode logs callbacks > 100 ms, `loop.slow_callback_duration`, `PYTHONASYNCIODEBUG`
- https://docs.python.org/3/library/asyncio-task.html#asyncio.to_thread — `to_thread` runs a blocking function on a thread; due to the GIL it can only make I/O-bound functions non-blocking
- https://docs.python.org/3/library/multiprocessing.html — subprocesses side-step the GIL and fully leverage multiple processors; `Pool` for data parallelism
- https://docs.python.org/3/howto/free-threading-python.html — 3.13+ free-threaded build; non-ready extensions re-enable the GIL; 1–8% single-threaded overhead and increased memory use
