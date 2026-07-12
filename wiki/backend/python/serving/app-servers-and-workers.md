---
id: backend-python-serving-app-servers-and-workers
domain: backend
category: serving
applies_to: [python, gunicorn, uvicorn]
confidence: verified
sources:
  - https://gunicorn.org/design/
  - https://gunicorn.org/reference/settings/
  - https://uvicorn.dev/deployment/
last_verified: 2026-07-10
related: [backend-python-concurrency-gil-and-concurrency-model, backend-common-jobs-idempotent-handlers, backend-common-reliability-timeouts-and-retries]
---

# App Server and Worker Configuration for Python Web Services

## When this applies

Deploying a Python web app behind gunicorn/uvicorn; choosing worker count,
worker class, or timeout; requests queue or time out while CPU sits idle;
workers get killed mid-request or leak memory over time.

## Do this

1. One gunicorn sync worker handles exactly one in-flight request — total
   concurrency is the worker count. Choose the worker model by framework and
   workload:

| Case | Do |
|------|----|
| Sync/WSGI framework (Flask, classic Django) | gunicorn sync workers; start at `(2 × cores) + 1` and tune by measurement under load — workers ≠ expected clients, a handful of workers serves heavy traffic |
| Sync framework whose handlers spend most time in blocking I/O | gthread workers (`--threads`) — concurrency becomes `workers × threads` without rewriting to async; the GIL is released during I/O so threads overlap correctly |
| Async/ASGI framework (FastAPI, Starlette) | `uvicorn --workers N` or gunicorn with the uvicorn worker class (install the `uvicorn-worker` package; `uvicorn.workers` is deprecated). Concurrency within one worker comes from the event loop, so set worker count ≈ cores. One blocking call stalls that worker's entire loop → [backend-python-concurrency-gil-and-concurrency-model] |

2. Worker timeout: gunicorn kills and restarts any worker silent for
   `timeout` seconds (default 30). A worker killed mid-request drops that
   request's work — pair long-running endpoints with
   [backend-common-jobs-idempotent-handlers] so replays are safe. For an
   endpoint that legitimately runs long, either raise `timeout` deliberately
   for that service or move the work to a job queue and return a job id.

3. Set the chain of timeouts so the outer layer waits longest:
   LB/proxy timeout > app-server `timeout` > per-call timeouts inside the
   handler. Budgeting rules → [backend-common-reliability-timeouts-and-retries].

4. Memory:

| Concern | Do |
|---------|----|
| N workers each load a full copy of the app | Enable `preload_app` — the app loads once before fork and workers share pages copy-on-write; trade-off: code reload requires a full restart, not worker recycling |
| Slow memory leak grows worker RSS over days | Set `max_requests` with `max_requests_jitter` — workers restart after that many requests, jitter staggers the restarts so they never recycle simultaneously. This is a backstop that caps damage; profile and fix the leak separately |

## Edge cases

| Case | Then |
|------|------|
| Requests time out while host CPU is near idle | All sync workers are occupied by blocking I/O — move to gthread workers or an ASGI worker model (table above), not more sync workers per core |
| `uvicorn --workers` on Windows or with heavyweight per-worker init | uvicorn spawns (no pre-fork), so there is no copy-on-write sharing — put per-worker init in lifespan/startup hooks and measure memory per worker |
| `timeout` raised very high to accommodate one slow endpoint | The raised value now applies to every worker — a hung worker holds its slot that long. Move the slow endpoint's work to a job instead |
| gthread threads share process state | Handlers now run concurrently in one process — shared mutable state rules → [backend-common-concurrency-shared-state-and-pools] via the GIL page's state note |

## Instead of

| If you are about to | Do this instead | Why |
|---------------------|-----------------|-----|
| Set worker count to expected concurrent clients | Start at `(2 × cores) + 1` (sync) or ≈ cores (ASGI) and tune by measurement | Workers are OS processes bound by cores and RAM; gunicorn serves heavy traffic with 4–12 workers |
| Raise `timeout` because a batch-style endpoint gets killed | Return a job id and run the work in a queue worker → [backend-common-jobs-idempotent-handlers] | The timeout is a liveness check for every worker, not a per-endpoint budget |
| Use `max_requests` recycling as the fix for a leak | Treat it as a backstop; find the leak with memory profiling | Recycling hides growth until traffic outpaces the restart cadence |
| Run one uvicorn process ("async handles the concurrency") | Run ≈ one worker per core under a process manager | One process uses one core for Python bytecode; the manager also restarts crashed workers and enables zero-drop upgrades |

## Sources

- https://gunicorn.org/design/ — sync worker handles one request at a time; `workers = (2 × cores) + 1` starting point; workers ≠ clients, 4–12 workers handle heavy traffic; async/gthread workers for long blocking I/O; ASGI workers for async frameworks
- https://gunicorn.org/reference/settings/ — `timeout` kills workers silent longer than the setting (default 30 s); `max_requests`/`max_requests_jitter` restart workers to cap memory-leak damage, jitter staggers restarts; `preload_app` loads code before fork and saves RAM; `threads` switches to gthread
- https://uvicorn.dev/deployment/ — `--workers` runs multiple processes via spawn (not pre-fork); gunicorn as process manager with the uvicorn worker class, `uvicorn.workers` deprecated in favor of the `uvicorn-worker` package; process manager gives resilient multi-process serving and upgrades without dropping requests
