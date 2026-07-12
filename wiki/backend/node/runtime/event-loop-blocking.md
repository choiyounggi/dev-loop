---
id: backend-node-runtime-event-loop-blocking
domain: backend
category: runtime
applies_to: [nodejs, typescript]
confidence: verified
sources:
  - https://nodejs.org/en/learn/asynchronous-work/dont-block-the-event-loop
  - https://nodejs.org/api/worker_threads.html
  - https://nodejs.org/api/perf_hooks.html
last_verified: 2026-07-10
related: [backend-common-concurrency-shared-state-and-pools, backend-common-reliability-timeouts-and-retries]
---

# Synchronous Work Blocking the Node.js Event Loop

## When this applies

A Node service where ALL requests slow down together under specific inputs, p99
latency spikes when a CPU-bound feature runs (big JSON, crypto, compression, regex
matching), or you are writing/reviewing handler code that does heavy synchronous work.

## Do this

1. **Treat the event loop as a shared single lane.** One event loop serves every
   request in the process. A synchronous block in one handler stalls every other
   in-flight request — a slow handler is never isolated. Keep the main loop for I/O
   coordination only; route anything CPU-bound off it.
2. Replace each blocking source with its non-blocking form:

| Blocking source in a request path | Do |
|-----------------------------------|-----|
| `*Sync` core APIs: `fs.readFileSync`, `crypto.pbkdf2Sync`, `zlib.deflateSync`, `child_process.execSync` | Call the async variant (`fs.promises.*`, callback/promise crypto and zlib, `child_process.exec`) — the async forms run on libuv's thread pool, not the event loop |
| `JSON.parse`/`JSON.stringify` on large payloads (multi-MB bodies, big exports) | Stream or chunk the (de)serialization, or move it to a worker thread; parsing is O(n) on the event loop and a single large payload stalls the process |
| CPU-heavy loops and transforms (image processing, report generation, scoring) | Offload to a `worker_threads` pool sized to CPU core count — workers exist for CPU-intensive JavaScript; async I/O stays on the main loop where it is more efficient |
| Regex on user-controlled input with nested quantifiers or overlapping alternation (`(a+)*`, `(\/.+)+$`) | Use a linear-time engine (RE2-style, e.g. `node-re2`), rewrite to a pattern without backtracking blowup, or replace with `indexOf`/length-capped checks — crafted input against a backtracking pattern is ReDoS: one request blocks the whole process |
| Chunkable pure-JS computation you cannot move to a worker | Partition it: process a slice per turn and yield with `setImmediate` between slices so other requests interleave |

3. **Detect blocking with event-loop delay monitoring**, not per-endpoint timing:
   `perf_hooks.monitorEventLoopDelay()` returns a histogram of loop delay in
   nanoseconds — alert on its p99. Endpoint-level APM shows victims, not the culprit.

## Edge cases

| Case | Then |
|------|------|
| Every endpoint slows down at once, including trivial ones | Diagnose as event-loop blocking, not a slow dependency — per-endpoint slowness points to that endpoint's I/O; process-wide slowness points to a synchronous block anywhere in the process |
| `*Sync` API at startup (config load, key read) before the server listens | Acceptable — nothing is being served yet; the ban applies to request paths |
| Work is I/O-bound, not CPU-bound | Keep it on the main loop with async APIs — worker threads do not help I/O; Node's built-in async I/O is more efficient than workers |
| Worker pool receives more jobs than cores | Bound the pool and its queue; an unbounded queue hides backlog until memory pressure ([backend-common-concurrency-shared-state-and-pools]) |
| Blocking code lives in a dependency you cannot edit | Wrap the call in a worker thread, or isolate it behind a separate process/service with a timeout ([backend-common-reliability-timeouts-and-retries]) |

## Instead of

| If you are about to | Do this instead | Why |
|---------------------|-----------------|-----|
| Call `fs.readFileSync`/`pbkdf2Sync`/`deflateSync` inside a handler | Await the async variant | The sync form blocks every request in the process for its full duration |
| `JSON.stringify` a huge object in a hot endpoint | Stream the serialization or build it in a worker | O(n) stringify of a large object stalls the loop for hundreds of ms |
| Run user input through a backtracking-prone regex | Linear-time pattern/engine + input length cap | One crafted string = process-wide denial of service (ReDoS) |
| Add more instances to fix "everything is slow" | Find and offload the synchronous block first | Scaling out multiplies the cost but keeps each process stallable by one request |

## Sources

- https://nodejs.org/en/learn/asynchronous-work/dont-block-the-event-loop — one loop serves all clients; sync API list; JSON cost; ReDoS; partitioning vs offloading
- https://nodejs.org/api/worker_threads.html — workers for CPU-intensive JS; not helpful for I/O
- https://nodejs.org/api/perf_hooks.html — `monitorEventLoopDelay()` histogram (nanoseconds)
