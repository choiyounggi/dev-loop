---
id: backend-python-language-source-introspection-of-a-dynamically-loaded-module
domain: backend
category: language
applies_to: [python, cpython]
confidence: verified
sources:
  - https://docs.python.org/3/library/importlib.html
  - https://docs.python.org/3/library/inspect.html
  - https://docs.python.org/3/reference/import.html
last_verified: 2026-08-18
related:
  [
    backend-python-language-bytecode-cache-staleness,
    testing-quality-checks-that-cannot-pass,
    testing-quality-tests-that-cannot-fail,
  ]
---

# Reading the Source of a Class in a Module Loaded by File Path

## When this applies

A check, doc snippet, or test loads a module by path with
`importlib.util.spec_from_file_location` + `module_from_spec` + `exec_module`
(because the file is a script, a generated artifact, or outside the import path)
and then introspects it — `inspect.getsource`, `getfile`, `getsourcelines`,
`getmodule` — or pickles an object it defined. Also when such a snippet raises
`TypeError: <class 'x.C'> is a built-in class` and the class it names is plainly
not built in.

## Do this

1. **Register the module before executing it, exactly as the standard library's
   own recipe does** — `sys.modules[module_name] = module` sits between
   `module_from_spec` and `exec_module` in the documented "Importing a source
   file directly" recipe:

```python
spec = importlib.util.spec_from_file_location(name, path)
m = importlib.util.module_from_spec(spec)
sys.modules[spec.name] = m          # required before class introspection or pickling
spec.loader.exec_module(m)
```

2. **Pick the introspection target by what resolves it.** `inspect.getfile`
   takes two different routes, so the same snippet succeeds or fails purely by
   the kind of object handed to it:

| Object handed to `inspect.getsource` | How the file is resolved | Works without `sys.modules` registration |
|---|---|---|
| Function, method, code object, frame, traceback | `object.__code__.co_filename` — carried on the object | Yes |
| Class | `sys.modules.get(object.__module__)`, then that module's `__file__` | No — raises `TypeError: … is a built-in class` |
| Module object itself | its own `__file__` | Yes |

3. **When you cannot change the loader (a fixed harness, a doc snippet you are
   only allowed to narrow), assert against a method instead of the class** —
   `inspect.getsource(m.Handler.do_GET)` reads the same text region through the
   code-object route and needs no registration.

4. **Clean up what you registered when the snippet runs inside a longer
   process.** `del sys.modules[spec.name]` after the check, so a later real
   `import <name>` is not served your path-loaded copy.

## Edge cases

| Case | Then |
|------|------|
| The failure appears only for *some* assertions in the same file, and the function-based ones pass | That split is the signature of this defect — read it as "the class route needs registration", not as a defect in the code being inspected |
| The check has never been observed passing, only failing | Run it against a known-good target before treating the failure as a finding ([testing-quality-checks-that-cannot-pass]) — a snippet that dies before its `assert` reports the same red for correct and broken targets |
| The name you register collides with a real importable module | Register under a unique name (`spec_from_file_location("probe_" + uuid4().hex, path)`) so the check cannot shadow a real import |
| `object.__module__` is `"__main__"` and `__main__` has no `__file__` (a `-c` run, a REPL) | Register the module under a non-`__main__` name — the error you get for the same cause differs by version: measured `OSError: source code not available` on CPython 3.11.13/3.13.11/3.14.6, and the same `TypeError: … is a built-in class` on 3.9.6 |
| You need pickling, dataclass `__module__` resolution, or relative imports inside the loaded file | Register **before** `exec_module`, per the documented recipe — registering afterwards is enough for `getsource` but too late for anything the module body itself resolves |

## Instead of

| If you are about to | Do this instead | Why |
|---------------------|-----------------|-----|
| Read the `TypeError: … is a built-in class` as "this class is C-implemented" | Check whether `sys.modules[cls.__module__]` exists | The message names the fallback branch, not the class's implementation language; a pure-Python class hits it whenever its module was never registered |
| Widen the check (drop the assertion, catch the exception) to make the snippet pass | Register the module, or move the target from the class to one of its methods | Both keep the assertion; catching the error turns an always-failing check into an always-passing one |
| Copy a working function-based snippet and swap in a class | Register the module in the same edit | The two objects take different resolution routes, so the swap changes what the snippet requires of its environment |

## Sources

- https://docs.python.org/3/library/importlib.html — "Importing a source file directly" recipe: `module = importlib.util.module_from_spec(spec)`, then `sys.modules[module_name] = module`, then `spec.loader.exec_module(module)`
- https://docs.python.org/3/library/inspect.html — `getsource`: "The argument may be a module, class, method, function, traceback, frame, or code object"; both it and `getfile` state that "A `TypeError` is raised if the object is a built-in module, class, or function" — the documented condition names *built-in*, which is why the message misdescribes the unregistered-module case
- https://docs.python.org/3/reference/import.html — the module cache: "The first place checked during import search is `sys.modules`"
- CPython `inspect.py` (3.14.6, `getfile`) — the class branch reads `module = sys.modules.get(object.__module__)` and raises `TypeError('{!r} is a built-in class')` when that module has no `__file__`; the function branch falls through to `object.__code__` and returns `co_filename`
- Local reproduction 2026-08-18 (macOS, CPython 3.9.6, 3.11.13, 3.13.11, 3.14.6 — the behaviour below is identical on all four; the `__main__` edge case above is not): a module loaded via `spec_from_file_location`/`module_from_spec`/`exec_module` without registration → `inspect.getsource(m.Handler)` raises `TypeError: <class 'aw.Handler'> is a built-in class`, while `inspect.getsource(m.Handler.do_GET)` and `inspect.getsource(m.select)` return their source; after `sys.modules[spec.name] = m` the class call returns 57 characters of source
