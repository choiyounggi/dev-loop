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

## packaging

| Page | Load when |
|------|-----------|
| [data-files-and-install-paths](packaging/data-files-and-install-paths.md) | A Python package reads non-code files (grammars, templates, KBs) located via `__file__`-relative paths; an installed console script cannot find a data file that exists in the repo; deciding how data files get into the wheel and how code resolves them after `pip install .` |

## language

| Page | Load when |
|------|-----------|
| [mutable-state-traps](language/mutable-state-traps.md) | State persists or leaks across calls/requests in a long-lived Python process — one user's data appears for another, values "remembered" between calls; loop-built callbacks all use the last value; reviewing function signatures (mutable defaults), class bodies (class attributes), or module-level objects for hidden sharing; choosing contextvars vs thread-locals for request context |
| [bytecode-cache-staleness](language/bytecode-cache-staleness.md) | A script or harness rewrites `.py` files and re-runs them in a loop (mutation testing, edit/test/revert, codegen check, bisect) and the result stops tracking what is on disk — a revert that `git diff` reports clean still fails, or an injected change has no effect; choosing between clearing `__pycache__`, refreshing mtime, and hash-based `.pyc` (PEP 552); designing byte-length-preserving mutations |
| [default-encoding-in-text-io](language/default-encoding-in-text-io.md) | Python opens a text file without `encoding=` (`open`, `Path.read_text`, `subprocess` text mode) and you are adding the argument or writing the regression test that keeps it there; a file-writing bug reproduces on Windows, a `LANG=C` container, or a cp949/cp932 desktop but not on your machine; choosing a test discriminator that does not depend on the runner's locale |
