---
id: backend-common-change-impact-threading-a-parameter-through-executor-hops
domain: backend
category: change-impact
applies_to: [general, python]
confidence: verified
sources:
  - https://docs.python.org/3/library/concurrent.futures.html
  - https://docs.python.org/3/library/symtable.html
last_verified: 2026-09-28
related: [backend-common-change-impact-call-site-enumeration, backend-common-errors-async-failure-handling, testing-quality-sequential-dispatch-assumption-under-concurrency, debugging-signals-stack-traces]
---

# Threading a New Parameter Through a Call Chain That Crosses an Executor

## When this applies

You are adding a parameter to a callee and threading its value from the function
that has it, through one or more intermediate helpers, to the function that
consumes it — and one hop on that path is an `Executor.submit()` / `Executor.map()`
boundary (`ThreadPoolExecutor` or equivalent). Also when, after such a change, a
parallel section "produced no results" — an empty list, zero recorded outcomes —
with no traceback in the output and a green exit code.

Enumerating the *callers* of the callee whose signature changed →
[backend-common-change-impact-call-site-enumeration].

## Do this

1. **Enumerate the path by the new value's name, not by the callee's name.** The
   callee enumeration lists who calls the changed function; an intermediate
   helper that forgot the parameter is not a caller of anything new — it is a
   function that *references* the new name without *binding* it. Run a scope
   scan over the file before running tests:

   ```python
   import symtable, builtins
   top = symtable.symtable(src, path, "exec")
   module_names = {s.get_name() for s in top.get_symbols() if s.is_assigned() or s.is_imported()}
   def walk(t):
       if t.get_type() == "function":
           bound = set(t.get_parameters()) | set(t.get_locals())
           for s in t.get_symbols():
               n = s.get_name()
               if s.is_referenced() and n not in bound and (s.is_global() or s.is_free()) \
                  and n not in module_names and not hasattr(builtins, n):
                   print(f"{t.get_name()}: uses {n!r} but does not bind it")
       for c in t.get_children(): walk(c)
   walk(top)
   ```

   `symtable` exposes the two facts the scan needs — `Function.get_parameters()`
   "Return a tuple containing names of parameters to this function" and
   `Symbol.is_referenced()` "Return `True` if the symbol is used in its block". A
   referenced name that is neither parameter, local, module binding nor builtin
   is a `NameError` waiting for the first call.

2. **Read the executor boundary as an exception sink.** `Future.result()`: "If
   the call raised an exception, this method will raise the same exception";
   `Executor.map()`: the exception "will be raised when its value is retrieved
   from the iterator". Nothing raises at `submit()` time. A caller that records
   only futures whose `exception()` is `None` — or appends `result()` inside a
   `try` that continues — converts every worker failure into missing work.

3. **Decide the surfacing policy per collection loop:**

| Collection loop | Do |
|-----------------|----|
| Records `result()` only for futures that finished OK | Log or re-raise `future.exception()` for every other future — each per-future failure must leave a trace with its item id |
| Iterates `Executor.map()` | The first failed item raises at retrieval and skips the remaining retrievals — decide whether that abort is wanted, and catch per item if not |
| `as_completed` with `except Exception: continue` | Record `repr(exc)` against the item before continuing; an empty `except` here is the silent mode |

4. **Treat "block produced no results" in executor code as a possible swallowed
   exception before treating it as a logic error.** Print `future.exception()`
   for each future, or call `result()` on one, before reading the business logic.

5. **Re-run the scan after the edit and require zero unbound names on the path,
   then run the tests** — the re-run turns the scan into a completion check.

## Edge cases

| Case | Then |
|------|------|
| The path crosses a `functools.partial`, a lambda, or a bound method handed to `submit` | The argument list lives at the `submit`/`partial` site — include those sites in the path enumeration |
| A retry wrapper sits between caller and callee | The wrapper is a function on the path and needs the parameter as much as the callee — the field incident's missing hop was the retry helper |
| The new name shadows a module-level or builtin name (`keys`, `id`, `input`) | The scan's module/builtin exclusions hide it; grep the name as well — a same-named module binding turns the `NameError` into wrong-value behaviour with no exception at all |
| The language is not Python | The mechanism holds where a result is materialized on read: Java `Future.get()` wraps the failure in `ExecutionException`, JS `Promise.allSettled` records rejections, Rust `JoinHandle::join` returns `Err` — the collection loop decides what surfaces |
| The parallel branch's test asserts `== []` or a count that can legitimately be zero | That assertion cannot separate "nothing to do" from "every worker raised" — add a per-item outcome assertion ([testing-quality-sequential-dispatch-assumption-under-concurrency]) |

## Instead of

| If you are about to | Do this instead | Why |
|---------------------|-----------------|-----|
| Grep the callee's name, update its callers, run the tests | Also scan every function between the value's source and the callee for a reference to the new name that is not bound there | The intermediate helper is not a caller of the changed callee, and it is exactly where the `NameError` lives |
| Read "N parallel tests fail with `[]`" as a scheduling or ordering bug | Print `future.exception()` for each future first | Reproduced 2026-09-28: a `NameError` in the worker gave `results: []`, exit code 0, no traceback |
| Keep `if f.exception() is None: results.append(f.result())` as the whole collection loop | Record every non-`None` exception against its item | The loop is correct for the futures it records and silent for the ones that carried the failure |

## Sources

- https://docs.python.org/3/library/concurrent.futures.html — `Future.result()`: "If the call raised an exception, this method will raise the same exception"; `Future.exception()`: "Return the exception raised by the call … If the call completed without raising, `None` is returned"; `Executor.map()`: "If a *fn* call raises an exception, then that exception will be raised when its value is retrieved from the iterator" — the exception is stored on the future and surfaces only where a result is read
- https://docs.python.org/3/library/symtable.html — `Function.get_parameters()` "Return a tuple containing names of parameters to this function"; `Function.get_locals()` "Return a tuple containing names of locals in this function"; `Symbol.is_referenced()` "Return `True` if the symbol is used in its block"; `Symbol.is_free()` "Return `True` if the symbol is referenced in its block, but not assigned to"; `SymbolTable.get_children()` "Return a list of the nested symbol tables" — the basis for the step-1 scan
- Reproduction 2026-09-28 (CPython 3.14.4, macOS): `run_parallel` submits `run_with_retry(step)` to a `ThreadPoolExecutor(max_workers=4)` and appends `result()` only when `exception()` is `None`; `run_with_retry` calls `run_step(step, keys)` without binding `keys`. Output: `results: []`, exit code 0, no traceback. Calling `result()` on one future raised `NameError: name 'keys' is not defined` from inside the worker. The step-1 scan printed `run_with_retry: uses 'keys' but does not bind it` on the broken file and printed nothing on the fixed file (parameter added and passed at the `submit` site), which then returned three results
- Field incident 2026-09-28 (a Python workflow runtime, task t175): `binding_keys` was threaded to the step executor but not to `_execute_step_with_retry`, which ran inside `ThreadPoolExecutor` workers; 8 `test_parallel_execution` cases failed showing `[]` steps and no traceback. An `ast.walk` scan listing each function's references to the name against its parameters/locals located the single missing hop and confirmed no other function on the path lacked it
