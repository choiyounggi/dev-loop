# backend/python — Stack Subtree Index

Route here for: Python stack-specific backend concerns. Language-agnostic principles → wiki/backend/common/.

Interpreter/venv versioning and pinning → wiki/platforms/toolchains/version-management.md.

Match your situation to a "load when" line; load only matching pages.

## concurrency

| Page | Load when |
|------|-----------|
| [gil-and-concurrency-model](concurrency/gil-and-concurrency-model.md) | Choosing threads vs asyncio vs processes for a Python workload; a "parallel" Python service uses only one core; an asyncio service hangs/stalls under load; a coroutine calls a synchronous library (requests, time.sleep, sync DB driver); deciding where CPU-bound work runs in a request-serving process |

## boundaries

| Page | Load when |
|------|-----------|
| [runtime-validation](boundaries/runtime-validation.md) | Typing or validating request bodies, env/config, queue messages, or external API responses in a Python service; type hints treated as guarantees on external data; deciding where runtime validation happens vs where hints + mypy/pyright suffice; choosing strict vs lax coercion per field |

## serving

| Page | Load when |
|------|-----------|
| [app-servers-and-workers](serving/app-servers-and-workers.md) | Deploying a Python web app behind gunicorn/uvicorn; choosing worker count, worker class (sync/gthread/ASGI), or worker timeout; requests queue or time out while CPU sits idle; workers killed mid-request; worker memory growth and preload/max_requests recycling decisions |

## language

| Page | Load when |
|------|-----------|
| [mutable-state-traps](language/mutable-state-traps.md) | State persists or leaks across calls/requests in a long-lived Python process — one user's data appears for another, values "remembered" between calls; loop-built callbacks all use the last value; reviewing function signatures (mutable defaults), class bodies (class attributes), or module-level objects for hidden sharing; choosing contextvars vs thread-locals for request context |
