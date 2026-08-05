---
id: testing-quality-migration-call-site-survey
domain: testing
category: quality
applies_to: [general, python, javascript, typescript]
confidence: verified
sources:
  - https://docs.python.org/3/tutorial/controlflow.html#keyword-arguments
  - https://deepwiki.com/python-rope/rope/4.6-change-signature-and-other-refactorings
  - https://www.jetbrains.com/help/resharper/Refactorings__Change_Signature.html
last_verified: 2026-08-05
related: [testing-quality-tests-that-cannot-fail, testing-quality-checks-that-cannot-pass, testing-data-test-data-and-isolation, debugging-methodology-verify-the-fix]
---

# Claiming a Signature Change Covered Every Call Site, Based on a Text Search

## When this applies

You are changing a function/constructor signature or the shape of a structure it
takes, must update every caller, and you surveyed the callers with a text search.
Also when reviewing a migration PR whose description states a call-site count
("13 sites, 7 updated").

## Do this

1. **Enumerate by the callee, not by the parameter.** Search for the thing that
   cannot be omitted at a call site — `verify(`, `Interpreter(`, `ClassName(` —
   and read each hit. A parameter name appears in the call text only when the
   caller chose keyword form; positional callers are invisible to a
   parameter-name search, and the language permits either form for the same
   parameter.

2. **Take the count from the callee search, and treat any parameter-name search as
   a subset.** When the two counts differ, the difference is positional callers —
   the ones the migration would otherwise miss.

3. **Audit helper/factory definitions in the same sweep.** Search the test tree
   for functions that *construct* the old shape (`def rows_for`, `build_x`,
   `make_fixture`) as well as ones that call the target. A helper appears once in a
   call-site search yet supplies the old structure to every test that uses it, so
   one missed helper reproduces the old contract across many callers.

4. **Cover the call forms the language allows, per callee:**

| Call form | Found by | Also search |
|-----------|----------|-------------|
| `verify(a, b, seed)` positional | `verify(` | — |
| `verify(seed=...)` keyword | `verify(` and `seed=` | — |
| `verify(*args)` / `verify(**kwargs)` unpacked | `verify(` | The construction of `args`/`kwargs` at its assignment |
| Bound/aliased: `f = verify` then `f(...)` | Neither reliably | `= verify`, `import verify`, and the alias name |
| Subclass override / interface implementation | Neither | The base declaration and `class .*\(.*Base` implementors |

5. **Run the full suite before claiming the migration is complete, and read which
   files fail.** A survey is a hypothesis about coverage; the suite is the
   measurement. Failures clustered in one file name the call form the survey
   missed, which tells you what to re-search rather than only what to patch.

6. **When the language and tooling support it, prefer a symbol-aware rename** — an
   IDE/refactoring-library Change Signature resolves call sites through the symbol
   and rewrites positional and keyword forms alike. Use the text search to
   *verify* its result, not to plan the migration.

## Edge cases

| Case | Then |
|------|------|
| The callee's name is short or common (`get`, `run`, `verify`) | Qualify by module or receiver (`mod.verify(`, `self.verify(`), then widen; a bare short name buries real hits in noise |
| Callers live outside this repo | The signature is a published contract — version it and keep the old form accepting both shapes for one release rather than migrating in place |
| A test helper produces the old shape *and* the code under test still accepts it | Both pass and hide the gap. Delete the old-shape path from the callee first, so every stale producer fails loudly |
| The suite is green after the change | Confirm the tests would fail without it — a helper that silently normalizes the shape makes them unable to detect the migration at all ([testing-quality-tests-that-cannot-fail]) |
| Dynamic dispatch (`getattr`, a registry dict, DI container) | Text search cannot resolve these; search the registration site and enumerate registered names |
| The change only adds a parameter with a default | Positional callers still break when the new parameter is inserted before an existing one — order matters, not just arity |

## Instead of

| If you are about to | Do this instead | Why |
|---------------------|-----------------|-----|
| Grep for the parameter name to find call sites | Grep for the callee name and read each hit | Positional call sites contain no parameter name and never appear in that search |
| Report "N call sites, M migrated" from a text search | Report the count from the callee search and confirm with a full suite run | The parameter-name count is a subset; the difference is exactly the sites that will break |
| Skip test helpers because they are "just fixtures" | Search helper definitions for the old shape in the same pass | One helper feeds the old structure to every test that calls it, from a single search hit |
| Call the migration done when the changed tests pass | Run the whole suite and read the failing file names | The failures identify the call form the survey missed, which is the information needed to finish |

## Sources

- https://docs.python.org/3/tutorial/controlflow.html#keyword-arguments — a function may be called with positional or keyword arguments for the same parameters, so the parameter name is absent from the text of a positional call
- https://deepwiki.com/python-rope/rope/4.6-change-signature-and-other-refactorings — rope's ChangeSignature updates call sites by resolving the callee symbol and normalizing argument forms (positional↔keyword), rather than by matching parameter-name text
- https://www.jetbrains.com/help/resharper/Refactorings__Change_Signature.html — Change Signature "finds and updates all usages, base symbols, implementations, and overrides of the modified symbol", including overrides that a call-site text search does not reach

## Field context

Measured 2026-08-05. A reconnaissance search on the parameter name
(`grep -rn "repo_rows" impl/tests/`) returned 13 hits, all keyword-form, and the
migration was scoped as "7 of 13". The full suite then reported
`Ran 472 tests / FAILED (failures=11)`, every failure in one file that passed the
value as the fourth *positional* argument to `verify()`. Re-searching by callee
(`grep -n "verify(" impl/tests/test_backend.py`) surfaced 8 positional call sites
plus a `rows_for()` helper definition that was still generating the old rule shape
for 5 further call sites — none of which the parameter-name search could reach.
