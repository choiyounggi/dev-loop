---
id: databases-sqlite-concurrent-access-for-a-read-api
domain: databases
category: sqlite
applies_to: [sqlite]
confidence: verified
sources:
  - https://www.sqlite.org/wal.html
  - https://www.sqlite.org/pragma.html#pragma_busy_timeout
  - https://www.sqlite.org/faq.html
last_verified: 2026-07-12
related: [databases-transactions-isolation-level-selection, backend-common-jobs-scheduled-job-overlap]
---

# SQLite Concurrency for a Read-Heavy API with a Background Writer

## When this applies

SQLite backs an HTTP API that serves concurrent reads while a scheduled job
writes (a periodic import/sync). Readers stall while the writer runs, or you see
`database is locked` under load.

## Do this

1. **Enable WAL mode once** — `PRAGMA journal_mode=WAL`; it persists on the file.
   In the default rollback-journal mode a writer holds an exclusive lock that
   blocks every reader for the whole transaction; WAL lets readers proceed during
   a write and lets multiple reader processes run at once.
2. **Set `busy_timeout` on every connection** (`PRAGMA busy_timeout=5000`). Without
   it, a connection that meets a lock raises `database is locked` immediately; with
   it the connection waits up to the timeout for the lock to clear.
3. **Set `synchronous=NORMAL` on the writer** — safe under WAL, one less fsync per
   commit. Readers do not need it.
4. **Keep a single writer.** SQLite serializes writes regardless of WAL; funnel all
   writes through one path/process.
5. **Run the writer as its own process, separate from the API workers.** A batch
   that builds thousands of rows is CPU/interpreter-lock-heavy; inside the API
   process it starves request handling. A separate process + WAL keeps API reads
   fast during the import ([backend-common-jobs-scheduled-job-overlap]).
6. **Scale reads with multiple processes** (web workers), not threads — WAL allows
   concurrent readers across processes; one process is bounded by its interpreter
   lock.

## Edge cases

| Case | Then |
|------|------|
| `PRAGMA journal_mode`/`synchronous` on every request is slow | They cost ~0.4ms per connection (a WAL/checkpoint check); set them once at init and put only the cheap `busy_timeout` (~0.04ms) on per-request connections |
| Opening a fresh connection per request feels wasteful | Fine for SQLite (~0.05ms open); reuse a per-thread connection only if a profile shows connection-open dominating |
| The `-wal` file grows without bound | The default auto-checkpoint folds it back every ~1000 pages; when a single bulk import writes more than that and the file stays large, run `PRAGMA wal_checkpoint(TRUNCATE)` after the import |
| Reads run in a different process from the writer | Exactly the case WAL is for — but every process must be able to create the `-wal`/`-shm` files (same directory, write permission) |
| A read must see the newest write instantly | WAL readers see all committed data with no staleness; cross-process visibility is immediate on commit |

## Instead of

| If you are about to | Do this instead | Why |
|---------------------|-----------------|-----|
| Run the import loop inside the API server process | Run it as a separate scheduled process | The batch's CPU work blocks request handling; a separate process isolates it |
| Keep the default rollback journal and add retries for `database is locked` | WAL + `busy_timeout` | WAL removes the reader-blocks-on-writer contention; retries only paper over it |
| Set `journal_mode=WAL` on every connection | Set it once — it persists on the file | Re-asserting it per request adds a measurable per-connection cost for no benefit |
| Scale a SQLite-backed API with more threads in one process | Add worker processes | Threads share one interpreter lock; processes each get their own and WAL lets them read concurrently |

## Sources

- https://www.sqlite.org/wal.html — WAL: concurrent readers during a write, persistence, checkpointing
- https://www.sqlite.org/pragma.html#pragma_busy_timeout — busy_timeout waits for a lock instead of erroring
- https://www.sqlite.org/faq.html — SQLite serializes writers (one writer at a time)
