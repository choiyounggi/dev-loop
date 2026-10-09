---
id: debugging-methodology-hiding-a-tool-to-reproduce-its-absent-branch
domain: debugging
category: methodology
applies_to: [general]
confidence: verified
sources:
  - https://docs.python.org/3/library/shutil.html#shutil.which
  - https://cmake.org/cmake/help/latest/command/find_program.html
last_verified: 2026-10-02
related: [debugging-methodology-reproduce-first, platforms-environment-path-resolution, platforms-toolchains-compiler-sysroot-on-macos, testing-quality-tests-that-cannot-fail]
---

# Hiding an Installed Tool to Reproduce Its "Tool Absent" Branch

## When this applies

A test of the "external tool not installed" branch (compiler, linter, database
client) fails on CI, where the tool is absent, and the full suite is green on
your machine, where it is installed. You are about to reproduce the CI state
locally by shrinking `PATH`, or to confirm a fix by re-running the suite with
the tool "hidden".

## Do this

1. **Read the function that locates the tool and list every place it looks, in
   order**, before hiding anything. `PATH` is one entry in that list. A
   hand-written lookup can add an override environment variable and one or more
   install prefixes; build systems add their own (CMake's `find_program` searches
   the `CMAKE_PREFIX_PATH` / `CMAKE_PROGRAM_PATH` cache variables and the
   same-named environment variables, `HINTS`, `PATH`, the `CMAKE_SYSTEM_*`
   variables, then `PATHS`).
2. **Neutralize each entry on the list**, in the way that entry is read:

| Lookup source | Hide it by |
|---------------|-----------|
| `PATH` | Run with `PATH` reduced to the directories the test runner itself needs |
| An override environment variable | Point it at an empty directory you created; when the resolver treats "unset" as "use the default", unsetting it re-enables the fallback |
| An install prefix written into the source (a module constant, a default argument) | Patch that constant for the run — a test fixture, `mock.patch.object`, or the resolver's own "no default path" switch (`NO_DEFAULT_PATH` in CMake) |
| A cached result (memoized lookup, build cache variable) | Clear the cache, or start a fresh process after the three rows above |

3. **Assert the hidden state in one line before running the tests**: call the
   resolver itself and require "not found" — `python -c 'import pkg; print(pkg.find_tool("x"))'`
   printing `None`, or the tool's own "not found" error. A path in that output
   means one source on the list is still live.
4. **Run the failing test and require the same failure text CI printed.** A
   different failure means a different state; a pass means the tool is still
   reachable.
5. **After the fix, run the whole suite once in the hidden state**, and record
   the runner's summary line with its skip count. The tests that need the tool
   report as skipped; compare that count with the skip count of CI's run — equal
   counts mean the suite saw the same state.

## Edge cases

| Case | Then |
|------|------|
| The resolver is a library call you do not own (`shutil.which`, `find_program`) | Read its documented search order, then check the edge you rely on with a one-line call. `shutil.which` reads `PATH`; with `PATH` unset it searches the system default directories and still finds tools in `/bin` and `/usr/bin`, and with `PATH` set to the empty string it returns `None` — unsetting and emptying are different states |
| Tests mutate the override variable and do not restore it | A later test sees the previous test's value; on a machine with the install-prefix fallback the leak is masked, on CI it is not. Restore the variable in teardown and re-run in the hidden state |
| The fallback prefix exists on your machine and not on CI (a package-manager prefix) | That prefix is the whole local/CI difference — hiding it is the reproduction; a container without the tool is the same check with no patching |
| Several tools share one resolver | One hidden-state assertion per tool name; a resolver can find one tool through the fallback and miss another |

## Instead of

| If you are about to | Do this instead | Why |
|---------------------|-----------------|-----|
| Shrink `PATH` and read a green local run as "cannot reproduce" | Assert the resolver returns "not found" first, then run | A resolver with an install-prefix fallback still finds the tool, so the absent-tool test runs its tool-present path and passes |
| Hide the tool by environment variable alone | Walk the full lookup order and neutralize each source | Each source is read independently; one live source is enough to find the tool |
| Declare the fix done from the single reproduced test | Run the full suite in the hidden state | Other tests on the same branch share the lookup and fail the same way on CI |

## Sources

- https://docs.python.org/3/library/shutil.html#shutil.which — "When no *path* is specified, the `PATH` environment variable is read from `os.environ`, falling back to `os.defpath` if it is not set"; a lookup that passes its own `path=` argument searches directories `PATH` never names
- https://cmake.org/cmake/help/latest/command/find_program.html — the documented search order continues past "The directories in `PATH` itself" to platform variables (`CMAKE_SYSTEM_PREFIX_PATH`, `CMAKE_SYSTEM_PROGRAM_PATH`: "locations that typically include installed software") and then the `PATHS` option ("These are typically hard-coded guesses"); `NO_DEFAULT_PATH` and `NO_SYSTEM_ENVIRONMENT_PATH` switch sources off one by one
- Local check 2026-10-02 (Python 3.9 and 3.14, macOS): with `PATH` unset `shutil.which("ls")` returned `/bin/ls`; with `PATH=""` it returned `None`
- Local reproduction 2026-10-02 (Python 3.14, macOS): a resolver trying `shutil.which(name)`, then an override variable, then a fixed prefix returned the tool's path with `PATH=/usr/bin:/bin` and the override pointed at an empty directory; it returned `None` only after the fixed prefix was also replaced
- Field evidence 2026-10-02 (a compiler project whose backend shells out to an LLVM tool): CI failed an absent-tool test while the local suite was green. With `PATH` reduced and the override variable pointed at an empty directory the resolver still returned the Homebrew prefix path; after the module's fallback-prefix constant was patched too, the CI failure text reproduced verbatim. The fixed tree then ran the whole suite in the hidden state: `Ran 3999 tests`, `OK (skipped=132)`, and the CI gate went green
