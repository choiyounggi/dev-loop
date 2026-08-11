---
id: backend-python-language-bytecode-cache-staleness
domain: backend
category: language
applies_to: [python, cpython]
confidence: verified
sources:
  - https://docs.python.org/3/reference/import.html
  - https://peps.python.org/pep-0552/
  - https://docs.python.org/3/library/py_compile.html
  - https://docs.python.org/3/library/shutil.html
last_verified: 2026-08-11
related: [backend-python-language-default-encoding-in-text-io, testing-quality-harness-reverse-controls, testing-quality-tests-that-cannot-fail, backend-python-language-mutable-state-traps]
---

# Edited Python Source the Interpreter Keeps Ignoring

## When this applies

A script or harness rewrites a `.py` file, runs it, and rewrites it again —
mutation testing, an edit/test/revert loop, a codegen check, a bisect
harness — and the run's result no longer tracks what is on disk: a revert
that `git diff` reports as clean still fails, or an injected change produces
no effect at all.

## Do this

1. **Treat "source on disk differs from behavior observed" as a bytecode-cache
   hit, not as a phantom regression.** CPython writes the source's last-modified
   timestamp *and* size into the `.pyc` header, and validates the cache by
   comparing that stored metadata against the source's current metadata. The
   timestamp has one-second resolution, so **an edit that keeps the byte size
   identical and lands in the same second as the cached compile is invisible to
   the check** and the stale bytecode is reused.
2. **Invalidate explicitly between iterations of any script-driven edit loop.**
   Either remove the `__pycache__` directories under the tree being mutated, or
   refresh the source's mtime after writing it (`touch` / `os.utime` to the
   current time). Both restore correct behavior; removing the cache is the one
   that also survives a clock that has not advanced.
3. **Re-verify green after the revert, before starting the next iteration.** A
   revert-and-rerun step that never asserts the baseline lets one poisoned cache
   entry contaminate every subsequent verdict in the run.
4. **For a harness that will run many cycles, switch the harness's compiles to
   hash-based `.pyc` files** (PEP 552): they store a hash of the source contents
   instead of its metadata, so equal-size same-second edits are detected. Compile
   with `py_compile`'s checked-hash invalidation mode, or run the harness under
   `--check-hash-based-pycs always`.
5. **Choose the equal-size case deliberately when injecting mutations.** Mutations
   designed to preserve byte length (`"3.1.0"` → `"3.1.1"`, `<` → `>`, `==` → `!=`)
   are exactly the ones the timestamp+size check cannot see.

## Edge cases

| Case | Then |
|------|------|
| The mutation is the thing that vanished (injected change has no effect) and the revert looks fine | Same mechanism, opposite direction: the cache predates both writes. Clear `__pycache__` and re-inject, then confirm the mutation *does* change behavior before scoring it as "caught" ([testing-quality-harness-reverse-controls]) |
| The harness reports every mutant caught | Verify one mutation reaches the interpreter by hand first — a stale cache that pins the *original* bytecode makes every mutant look survived, and one that pins a *mutant* makes every later case look caught |
| Writes are driven by a tool that preserves mtime (`rsync -t`, archive extraction, `git checkout` of an unchanged blob, `touch -t` in a script) | The second-granularity race becomes a certainty rather than a race; use hash-based `.pyc` or clear the cache unconditionally |
| The harness backs the file up and restores it with `shutil.copy2` | `copy2` "also attempts to preserve file metadata" via `copystat`, so the restore stamps the *original* mtime back — the same certainty as the row above, arriving through the idiomatic backup/restore call. Restore with `shutil.copyfile` (contents only, "no metadata") or follow the restore with `os.utime(path, None)`; `shutil.copy` also works, since it copies the permission mode but "the file's creation and modification times, is not preserved" |
| The tree is read-only or `PYTHONDONTWRITEBYTECODE` is set | No `.pyc` is written, so this failure cannot occur — and the harness pays a recompile per run |
| The stale module was already imported in a long-lived process | Clearing `__pycache__` does not help; the module object is in `sys.modules` and only a fresh process (or an explicit reload) picks the change up |
| An installed package ships `.pyc` files without sources | The unchecked-hash variant is assumed valid whenever it exists; edits to a co-located source are never consulted |

## Instead of

| If you are about to | Do this instead | Why |
|---------------------|-----------------|-----|
| Debug a "regression" that persists after a revert `git diff` shows as clean | Clear `__pycache__` and re-run before investigating the code | The disk source and the executed bytecode are different artifacts; only one of them is what `git diff` reads |
| Trust that writing the file is enough for the next run to see it | Clear the cache or bump the mtime as part of the write step | The validity check compares (mtime, size); an equal-size write inside the same second changes neither |
| Add a `sleep 1` between the write and the run to dodge the timestamp collision | Clear `__pycache__`, or compile with hash-based invalidation | The sleep costs a second per iteration and still fails whenever a tool restores the original mtime |
| Score a mutation harness run whose cache state you did not control | Fix invalidation, then re-run with a no-op control | Cached bytecode makes both uniform verdicts reachable, and both read as a working harness |

## Sources

- https://docs.python.org/3/reference/import.html — "By default, Python does this by storing the source's last-modified timestamp and size in the cache file when writing it"; "At runtime, the import system then validates the cache file by checking the stored metadata in the cache file against the source's metadata"; hash-based `.pyc` files store "a hash of the source file's contents rather than its metadata", in checked and unchecked variants, overridable with `--check-hash-based-pycs`
- https://peps.python.org/pep-0552/ — hash-based `.pyc` invalidation, added in Python 3.7, as the deterministic alternative to timestamp+size
- https://docs.python.org/3/library/py_compile.html — `PycInvalidationMode` selects timestamp, checked-hash, or unchecked-hash invalidation when compiling
- https://docs.python.org/3/library/shutil.html — `copyfile` copies "the contents (no metadata)"; `copy` copies data and permission mode and "Other metadata, like the file's creation and modification times, is not preserved"; `copy2` is "Identical to `copy()` except that `copy2()` also attempts to preserve file metadata" and "uses `copystat()` to copy the file metadata" — so `copy2` is the mtime-restoring member of the family
- Field reproduction 2026-08-11 (batch mutation harness, one process, byte-length-preserving mutation of a numeric literal, restore via `shutil.copy2`): three consecutive mutants scored GREEN in the batch and the third scored RED when run alone; printing the mutated constant from a fresh subprocess showed all three runs loading the *first* mutant's value. Purging `__pycache__` and calling `os.utime(path, None)` between iterations flipped the third to RED while a no-op control mutation stayed GREEN
- Field reproduction 2026-08-04 (Python 3.14.6, macOS): with `mod.py` pinned to a fixed mtime via `touch -t` and every revision exactly 18 bytes, compiling `VERSION = "3.1.1"` and then reverting the file to `VERSION = "3.1.0"` left `import mod` reporting `3.1.1` — reverted source, mutant bytecode. Deleting `__pycache__` returned `3.1.0`; a bare `touch mod.py` (mtime bumped, cache left in place) also returned `3.1.0`. The `.pyc` header decoded to `flags=0` (timestamp invalidation) with the source's exact mtime and `size=18`
