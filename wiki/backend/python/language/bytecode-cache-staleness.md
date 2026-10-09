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
  - https://docs.python.org/3/using/cmdline.html
  - https://docs.python.org/3/library/sys.html#sys.pycache_prefix
last_verified: 2026-10-06
related: [backend-python-language-default-encoding-in-text-io, testing-quality-harness-reverse-controls, testing-quality-tests-that-cannot-fail, backend-python-language-mutable-state-traps, backend-python-language-source-introspection-of-a-dynamically-loaded-module, testing-quality-mutation-harness-file-custody]
---

# Edited Python Source the Interpreter Keeps Ignoring

## When this applies

A script or harness rewrites a `.py` file, runs it, and rewrites it again —
mutation testing, an edit/test/revert loop, a codegen check, a bisect
harness — and the run's result no longer tracks what is on disk: a revert
that `git diff` reports as clean still fails, or an injected change produces
no effect at all — including a second mutant that scores the first mutant's
verdict.

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
   that also survives a clock that has not advanced. When each iteration runs
   in a fresh subprocess, a third option leaves the tree untouched: give every
   run its own new, empty `PYTHONPYCACHEPREFIX` directory (Python 3.8+). With a
   prefix set, Python reads and writes `.pyc` files only under it, and any
   `__pycache__` directories in the source tree "will be ignored". It costs a
   full recompile per run (stdlib and site-packages too, because their caches
   are ignored as well) and leaves one directory per run, so choose it when the
   tree must stay untouched; otherwise purge the mutated file's `__pycache__`
   entry. Delete each prefix directory after its run.
3. **Re-verify green after the revert, before starting the next iteration.** A
   revert-and-rerun step that never asserts the baseline lets one poisoned cache
   entry contaminate every subsequent verdict in the run.
4. **For a harness that will run many cycles, switch the harness's compiles to
   hash-based `.pyc` files** (PEP 552): they store a hash of the source contents
   instead of its metadata, so equal-size same-second edits are detected. Compile
   with `py_compile`'s checked-hash invalidation mode, or run the harness under
   `--check-hash-based-pycs always`.
5. **Treat every equal-size pair of writes as invisible to the check, and
   invalidate for all mutants, not only length-preserving ones.** Mutations that
   preserve byte length (`"3.1.0"` → `"3.1.1"`, `<` → `>`, `==` → `!=`) collide
   with the original; two different mutants that each change the size by the
   same amount collide with each other (see the edge case).

## Edge cases

| Case | Then |
|------|------|
| The mutation is the thing that vanished (injected change has no effect) and the revert looks fine | Same mechanism, opposite direction: the cache predates both writes. Clear `__pycache__` and re-inject, then confirm the mutation *does* change behavior before scoring it as "caught" ([testing-quality-harness-reverse-controls]) |
| The harness reports every mutant caught | Verify one mutation reaches the interpreter by hand first — a stale cache that pins the *original* bytecode makes every mutant look survived, and one that pins a *mutant* makes every later case look caught |
| Writes are driven by a tool that preserves mtime (`rsync -t`, archive extraction, `git checkout` of an unchanged blob, `touch -t` in a script) | The second-granularity race becomes a certainty rather than a race; use hash-based `.pyc` or clear the cache unconditionally |
| The harness backs the file up and restores it with `shutil.copy2` | `copy2` "also attempts to preserve file metadata" via `copystat`, so the restore stamps the *original* mtime back — the same certainty as the row above, reached through the idiomatic backup/restore call. Apply that row's remedy (hash-based `.pyc`, or clear `__pycache__` unconditionally), and switch the restore to `shutil.copyfile` ("no metadata") or `shutil.copy` ("the file's creation and modification times, is not preserved") so the write at least stops re-stamping the old timestamp. A bare `os.utime(path, None)` after the restore is not sufficient on its own: it sets mtime to *now*, which collides again whenever the cached compile happened in the same second |
| The tree is read-only, or the harness runs under `-B` / `PYTHONDONTWRITEBYTECODE` | Both settings govern writing only — Python "won't try to write `.pyc` files on the import of source modules" — so a `.pyc` left on disk by an earlier run is still validated and reused, and this failure still occurs. Purge `__pycache__` once before the run and keep `-B` set for the rest of it: with nothing cached and nothing written, every iteration recompiles from source |
| Two *different* mutations each change the file by the same number of bytes (both shrink it by 10) and are written in the same second | They differ from the original's size but not from each other's, so the second mutant loads the first mutant's bytecode and its verdict is the first one's. Purge the mutated file's `__pycache__` entry between mutants, or run each mutant's subprocess with its own fresh `PYTHONPYCACHEPREFIX` when the tree must stay untouched (step 2). Reusing one prefix across mutants brings the collision back inside that prefix |
| The harness re-imports the mutated file through a fresh `importlib.util.spec_from_file_location` + `module_from_spec` + `exec_module` each iteration | A fresh spec and module object bypass `sys.modules`, not the on-disk cache: the source loader still validates `__pycache__` and reuses it. Purge the cache (or compile with hash-based invalidation) between iterations, or read the file yourself and `exec(compile(text, path, "exec"), ns)`, which consults no cache |
| The mutate-and-revert was done by a different actor sharing the worktree (a test-quality auditor subagent, a reviewer agent, a teammate's script) and your session only runs the suite afterwards | You never saw the mutation, so nothing in your own loop prompts a purge. Clear `__pycache__` under the tree before the first full-suite run after any delegated verification step returns, and treat a failure that `grep` on the source contradicts as this row before debugging the code |
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
- https://docs.python.org/3/using/cmdline.html — `-B`: "If given, Python won't try to write `.pyc` files on the import of source modules"; `PYTHONDONTWRITEBYTECODE` "is equivalent to specifying the `-B` option" — both describe writing only, so neither stops an existing `.pyc` from being read. `PYTHONPYCACHEPREFIX`: "If this is set, Python will write .pyc files in a mirror directory tree at this path, instead of in `__pycache__` directories within the source tree"; "Added in version 3.8"
- https://docs.python.org/3/library/sys.html#sys.pycache_prefix — "Python will write bytecode-cache .pyc files to (and read them from) a parallel directory tree rooted at this directory … Any `__pycache__` directories in the source code tree will be ignored"
- Reproduction 2026-10-06 (Python 3.14.6, macOS): `mod.py` holding `X = "orig"`, then mutant A `X = "aa"` and mutant B `X = "zz"` (same size as each other, 2 bytes shorter than the original), both pinned to the same mtime. Default cache: A printed `aa`, B printed `aa` too (stale). B under a fresh `PYTHONPYCACHEPREFIX` printed `zz`, even though the in-tree `__pycache__` still held A. A third mutant `X = "yy"` run under that same prefix printed `zz`, and under a new prefix it printed `yy`. After one run, the prefix held an `opt/` tree (the Homebrew stdlib's bytecode) next to the scratch tree, so the recompile covers more than the mutated file. Field case the same day: two mutations of `wsgi.py`, each 10 bytes shorter, were written within one second; the second scored GREEN in the runner and FAILED by hand, and every mutant went RED once each run had its own prefix
- https://docs.python.org/3/library/shutil.html — `copyfile` copies "the contents (no metadata)"; `copy` copies data and permission mode and "Other metadata, like the file's creation and modification times, is not preserved"; `copy2` is "Identical to `copy()` except that `copy2()` also attempts to preserve file metadata" and "uses `copystat()` to copy the file metadata" — so `copy2` is the mtime-restoring member of the family
- Field reproduction 2026-08-11 (batch mutation harness, one process, byte-length-preserving mutation of a numeric literal, restore via `shutil.copy2`): three consecutive mutants scored GREEN in the batch and the third scored RED when run alone; printing the mutated constant from a fresh subprocess showed all three runs loading the *first* mutant's value. Purging `__pycache__` and calling `os.utime(path, None)` between iterations flipped the third to RED while a no-op control mutation stayed GREEN
- Field reproduction 2026-08-11 (Python 3.14.6, macOS, fresh-spec import path): `mod.py` holding `VERSION = "3.1.0"` was pinned to a fixed mtime and loaded via `spec_from_file_location` + `module_from_spec` + `exec_module`, which wrote `__pycache__/mod.cpython-314.pyc`. Rewriting the file to the same-length `"3.1.1"` and re-pinning the same mtime, the identical loader printed `3.1.0`; re-running under `python3 -B` with that `.pyc` still present also printed `3.1.0`. A fresh spec and `-B` each leave stale bytecode in play
- Field reproduction 2026-09-13 (orchestrated worktree, delegated audit): a test-quality-auditor subagent mutated a same-length string literal (`"n/a"` → `"N/A"`) in `src/pipeline.py` to prove a test was load-bearing, then reverted it. The parent session's next full-suite run kept printing `"N/A"` while `grep` on the file showed `"n/a"`; deleting `__pycache__`/`*.pyc` and rerunning fixed it, repeatably across several runs — the parent had no signal that a mutation had happened
- Field reproduction 2026-08-04 (Python 3.14.6, macOS): with `mod.py` pinned to a fixed mtime via `touch -t` and every revision exactly 18 bytes, compiling `VERSION = "3.1.1"` and then reverting the file to `VERSION = "3.1.0"` left `import mod` reporting `3.1.1` — reverted source, mutant bytecode. Deleting `__pycache__` returned `3.1.0`; a bare `touch mod.py` (mtime bumped, cache left in place) also returned `3.1.0`. The `.pyc` header decoded to `flags=0` (timestamp invalidation) with the source's exact mtime and `size=18`
