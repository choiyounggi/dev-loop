---
id: backend-python-language-mutable-state-traps
domain: backend
category: language
applies_to: [python]
confidence: verified
sources:
  - https://docs.python.org/3/faq/programming.html
  - https://docs.python.org/3/tutorial/classes.html#class-and-instance-variables
  - https://docs.python.org/3/library/dataclasses.html
  - https://docs.python.org/3/library/contextvars.html
  - https://docs.python.org/3/library/asyncio-task.html
last_verified: 2026-07-10
related: [backend-common-concurrency-shared-state-and-pools]
---

# Mutable State Shared Across Calls and Requests in Python

## When this applies

State mysteriously persists or leaks across calls/requests in a long-lived
Python process — one user's data appears in another's response, values are
"remembered" between function calls; also when reviewing function signatures,
class bodies, or module-level objects for hidden sharing.

## Do this

1. Map the symptom to the trap first:

| Symptom | Trap |
|---------|------|
| Values accumulate across separate calls to one function | Mutable default argument (row 2) |
| All instances see each other's items | Mutable class attribute (row 3) |
| One request's data appears in another request | Module-level or class-level mutable object mutated per request (rows 3–4) |
| Callbacks/lambdas built in a loop all use the last loop value | Late-binding closure (row 5) |
| State differs between replicas or vanishes on restart | Module state is per-process → [backend-common-concurrency-shared-state-and-pools] |

2. Default argument values are evaluated **once, at function definition** —
   `def f(items=[])` creates one list shared by every call for the life of
   the process (in a web app: shared across all requests the worker serves).
   Use the sentinel pattern for any mutable default:
   `def f(items=None): if items is None: items = []`.

3. Class attributes are shared by all instances — a `list`/`dict` in the
   class body is process-global state, and `self.items.append(x)` mutates it
   for every instance. Initialize per-instance state in `__init__`
   (`self.items = []`); in dataclasses use `field(default_factory=list)` —
   `@dataclass` raises `ValueError` on a directly-assigned mutable default
   for exactly this reason.

4. Module-level mutable objects are per-process singletons shared across all
   requests, and with thread/gthread workers across threads simultaneously.
   Reserve them for immutable or startup-initialized read-only data. For
   request-scoped data, pass it explicitly through call arguments; for
   ambient request context (request id, tenant), use `contextvars.ContextVar`
   — asyncio Tasks copy the current context at creation and run in the copy,
   so values isolate per task, while `threading.local` bleeds state between
   asyncio tasks because tasks share one thread.

5. Closures bind variables, not values — `for i in ...: fns.append(lambda: i)`
   makes every function read `i` at call time (all see the final value).
   Bind at definition with a default argument: `lambda i=i: i`.

## Edge cases

| Case | Then |
|------|------|
| Mutable default is intentional (memoization cache in a script) | Make the sharing explicit — module-level cache with a name saying so, or `functools.lru_cache`; a default argument hides the lifetime |
| Class attribute holds an immutable value (int, str, tuple) | Safe as a shared constant/default — rebinding via `self.x = ...` creates an instance attribute and never affects other instances; only in-place mutation shares |
| `ContextVar` default is mutable | Set a fresh object per request (`var.set([])` in middleware) — a mutable default object is itself a process-wide singleton |
| Multiple replicas each hold their own module-level state | Per-process state diverges across replicas — correctness-bearing state moves to the shared store → [backend-common-concurrency-shared-state-and-pools] |

## Instead of

| If you are about to | Do this instead | Why |
|---------------------|-----------------|-----|
| Write `def f(items=[])` / `def f(opts={})` | `None` sentinel, create inside the function | The one default object is shared by all calls in the process |
| Put `items: list = []` in a class body as a per-instance default | `__init__` assignment or `field(default_factory=list)` | Class attributes are shared by every instance |
| Use `threading.local()` for request context in asyncio code | `contextvars.ContextVar` | Tasks share a thread — thread-local state bleeds across tasks; contextvars isolate per task |
| Stash request data in a module-level dict keyed by nothing | Pass it explicitly, or `ContextVar` set per request | Module state is process-global — concurrent requests overwrite each other |
| Append `lambda: x` inside a loop | `lambda x=x: x` (bind at definition) | The closure reads the variable at call time, after the loop finished |

## Sources

- https://docs.python.org/3/faq/programming.html — default values created exactly once at function definition; shared mutable default dict example; `None` sentinel recommendation; loop lambdas all return the last value (late binding) and the `n=x` default-argument fix
- https://docs.python.org/3/tutorial/classes.html#class-and-instance-variables — class variables shared by all instances; mutable `tricks` list as class variable is a mistake; per-instance list in `__init__`
- https://docs.python.org/3/library/dataclasses.html — shared class-attribute default demonstrated; `field(default_factory=list)`; `@dataclass` raises `ValueError` on unhashable (mutable) defaults
- https://docs.python.org/3/library/contextvars.html — context-local state; use instead of `threading.local()` to prevent state bleeding in concurrent code; natively supported in asyncio
- https://docs.python.org/3/library/asyncio-task.html — a Task copies the current context and runs its coroutine in the copied context
