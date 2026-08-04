---
id: backend-common-refactoring-call-site-enumeration
domain: backend
category: refactoring
applies_to: [general]
confidence: field-tested
sources:
  - https://refactoring.com/catalog/changeFunctionDeclaration.html
  - https://pubs.opengroup.org/onlinepubs/9699919799/utilities/grep.html
last_verified: 2026-08-04
related: [testing-quality-tests-that-cannot-fail, testing-data-test-data-and-isolation, backend-common-integrations-externally-owned-defaults]
---

# Finding Every Caller Before Changing a Function's Shape

## When this applies

You are changing a function's declaration — adding or removing a parameter,
reordering parameters, or changing the shape of an argument's data structure —
and must migrate its callers. Also when a migration you scoped from a search
turned out to have missed call sites, in a language whose compiler will not
find them for you (Python, Ruby, JavaScript, PHP) or where the change is
type-compatible but semantically breaking.

## Do this

1. **Enumerate by the call target, not by a parameter name.** Search for
   `name(`, `ClassName(`, the imported symbol — then read every hit. A parameter
   name appears in the source text only when the caller passes it as a keyword;
   positional callers contain no trace of it, so a keyword search silently
   under-counts and reports a confident, wrong total.
2. **Search the definition sites of test helpers separately.** A helper that
   builds arguments for the function under change appears once in a call-target
   search while supplying the old shape to every test that calls the helper —
   one hit standing in for many call sites, and the one most likely to keep
   reproducing the structure you are removing.
3. **Cross-check the search's count against a run of the full suite before
   trusting it.** The search bounds the work; the suite is what proves the bound
   was right. Treat a failure count that exceeds the migration count as evidence
   the enumeration missed a shape, not as unrelated breakage.
4. **When the change is type-compatible** — a dict gaining a nesting level, a
   tuple's element order swapped, an added parameter with a default — **make the
   old shape fail loudly for one run** (rename the parameter, assert on the new
   structure at the top of the function) so silent adapters surface as errors
   rather than as passing tests reading stale data.
5. **Record the enumeration in the change**: the search performed, the number of
   sites found, and the number migrated. A reviewer can then check the arithmetic
   instead of re-deriving the scope.

## Edge cases

| Case | Then |
|------|------|
| The name is common (`run`, `get`, `verify`) and the call-target search returns hundreds of hits | Narrow by import: find the modules importing the symbol first, then search only those files — narrowing by the symbol's provenance keeps positional callers, narrowing by argument text drops them |
| The function is also called dynamically (`getattr`, reflection, a dispatch table, a string in config) | No textual search finds these; grep the function's *name as a string literal* as a separate pass and check the dispatch registry by hand |
| The change adds a parameter with a default value | Every existing caller keeps compiling and passing while receiving the default — enumerate and migrate anyway, or the default becomes the permanent behaviour nobody chose |
| The function is exported beyond this repository | Fowler's split migration applies: add the new declaration alongside, move callers, retire the old one — a single atomic rename is available only when you own every caller |
| The suite passes after migration but some call sites were never exercised | Coverage of the changed function tells you which callers ran; unexercised ones are unverified migrations, not finished ones ([testing-quality-tests-that-cannot-fail]) |

## Instead of

| If you are about to | Do this instead | Why |
|---------------------|-----------------|-----|
| Scope the migration from a search for the parameter name (`repo_rows=`) | Search for the call target (`verify(`, `Interpreter(`) and read each hit | Positional callers never contain the parameter name, so the keyword search returns a total that looks complete and is not |
| Trust the hit count as the number of sites to change | Compare it against a full-suite run after migrating | The search counts occurrences of text; the suite counts places the behaviour actually changed |
| Migrate the call sites and leave the test helpers for later | Migrate helper definitions first | A helper keeps manufacturing the old shape for every test that uses it, so the call sites you fixed still receive stale data |
| Rely on "the tests still pass" after a type-compatible shape change | Break the old shape deliberately for one run and require red | A dict that gained a nesting level still indexes without error; passing tests can be reading the wrong level |

## Sources

- https://refactoring.com/catalog/changeFunctionDeclaration.html — Change Function Declaration: the migration-style mechanics (introduce the new declaration, move callers, retire the old) exist because the simple in-place rename is safe only when every caller is reachable and changeable
- https://pubs.opengroup.org/onlinepubs/9699919799/utilities/grep.html — a search matches pattern text against line text; it has no model of the call graph, which is why keyword-argument text is absent from positional calls
- Field incident 2026-08-04 (Python interpreter project, seed-data structure change): a reconnaissance `grep -rn "repo_rows" impl/tests/` returned 13 hits, all keyword-form, and the migration was scoped as "7 of 13". The full suite then reported `Ran 472 tests / FAILED (failures=11)`, all in `test_backend.py`, where the seed was passed as `verify()`'s fourth **positional** argument. A follow-up `grep -n "verify(" impl/tests/test_backend.py` surfaced 8 positional call sites plus a `rows_for()` helper definition that was still supplying the old structure to 5 further call sites
