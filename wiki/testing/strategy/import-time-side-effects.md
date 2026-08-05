---
id: testing-strategy-import-time-side-effects
domain: testing
category: strategy
applies_to: [python, general]
confidence: verified
sources:
  - https://docs.pytest.org/en/stable/how-to/skipping.html
  - https://docs.pytest.org/en/stable/example/pythoncollection.html
  - https://docs.python.org/3/reference/import.html
last_verified: 2026-08-05
related: [testing-strategy-test-level-choice, testing-data-test-data-and-isolation, backend-python-language-mutable-state-traps]
---

# Unit-Testing a Pure Function Whose Module Runs I/O at Import

## When this applies

You are unit-testing a pure function (mapper, calculator, validator, geometry
helper) that lives in a module whose **top level** performs real I/O — `init_db()`,
a client connect, a config/file read, an app object constructed at module scope.
The test reaches the function by importing that module.

## Do this

1. Treat the **module**, not the function, as the unit of dependency. A test's real
   dependency surface is everything the import executes, so a pure function reached
   through an I/O-performing module is an integration test until the module changes.
   Decide the test level from what the import runs ([testing-strategy-test-level-choice]).
2. Pick the structure by what you are allowed to move:

| Case | Do |
|------|----|
| The function can move | Put it in a module whose top level only binds names (imports, `def`, constants) and import it from there; the app module imports it back. The unit test then needs no infrastructure |
| The function must stay (shared module state, public API, no-refactor constraint) | Gate the whole test module exactly as the existing DB-integration tests for that module are gated, and run it in the integration job — same marker, same fixture, same CI step |
| The blocker is an optional third-party import rather than your own I/O | `pytest.importorskip("name")` at module top — it turns the `ImportError` into a skip outcome |
| The module must never be imported in this run (the environment has no DB at all) | List the file in `collect_ignore` / `collect_ignore_glob` in `conftest.py` — collection then never imports it |

3. Place the guard **above** the import it protects. `pytest.skip(reason,
   allow_module_level=True)` and `pytest.importorskip` are module-body statements:
   they only prevent what follows them.
4. Verify the guard by running that test module with the infrastructure stopped. A
   correct guard reports `skipped`; a guard that sits below the import reports a
   collection error instead.

## Edge cases

| Case | Then |
|------|------|
| A module-level `pytestmark = pytest.mark.skipif(...)` still errors instead of skipping | Collection imports the module body top to bottom, so the app import written above that line has already run. Move the guard above the import (`pytest.skip(reason, allow_module_level=True)`) or exclude the file via `collect_ignore` |
| The suite is green locally and errors at collection in CI | The local machine has the service the import needs. Run the suite once with that service stopped — the collection errors enumerate every module carrying an import-time dependency |
| The import-time work sits in a package `__init__.py` above the module | Importing the leaf executes every parent package's `__init__` first; move the function under a package whose `__init__` chain binds names only, or gate the test module |
| The function is pure but its module also holds a module-level singleton tests mutate | The import question is settled; state ownership still applies ([testing-data-test-data-and-isolation]) |
| The module is imported by a `conftest.py` or a shared fixture | Gating the test module changes nothing — the conftest import runs first. Move the import inside the fixture body so only tests requesting it pay the cost |

## Instead of

| If you are about to | Do this instead | Why |
|---------------------|-----------------|-----|
| Conclude a test is infrastructure-free because the function under test does no I/O | Read what the module's top level executes, then choose the level | The import runs first; the function's purity says nothing about the module's |
| Put `@pytest.mark.skipif(no_db)` on the test and expect a clean skip | Guard above the import, or exclude the file from collection | The marker's condition is evaluated after the module has been imported — the connect has already happened or already failed |
| Patch `init_db` inside the test body to neutralize the import | Move the function to a side-effect-free module | Statements in the test body run long after import; patching earlier binds every test to the app's startup internals |
| Copy the pure function into the test file to dodge the import | Extract it into a shared side-effect-free module both import | A copy stops tracking the implementation and passes while production drifts |

## Sources

- https://docs.pytest.org/en/stable/how-to/skipping.html — `pytest.importorskip` at module level; `pytest.skip(reason, allow_module_level=True)`; `pytestmark = pytest.mark.skipif(...)` for a whole module
- https://docs.pytest.org/en/stable/example/pythoncollection.html — `collect_ignore` / `collect_ignore_glob` in `conftest.py`; pytest imports files matching the discovery patterns, which breaks on files that raise on import
- https://docs.python.org/3/reference/import.html — a module's body is executed when it is first imported; parent packages are imported before their submodules
- Reproduced 2026-08-05: importing only a pure function from a module whose first line prints a side effect still executes that line (`from modside import pure_fn` → side effect printed before the function is usable)
