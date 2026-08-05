---
id: qa-process-call-site-enumeration
domain: qa
category: process
applies_to: [general]
confidence: field-tested
sources:
  - https://docs.python.org/3/tutorial/controlflow.html
  - https://martinfowler.com/articles/rise-test-impact-analysis.html
last_verified: 2026-08-05
related: [qa-process-regression-scope, testing-quality-minimum-case-set, debugging-methodology-verify-the-fix]
---

# Enumerating Every Caller of a Changed Signature

## When this applies

You are changing a function's, constructor's, or method's signature — parameter
count, parameter order, or the shape of a structure it takes — and must migrate
every call site. Also when you are reviewing a migration whose completeness was
established by a search, before it is called done.

## Do this

1. **Search by the thing being called, not by the thing being passed.** Enumerate
   with the callee's name and its opening paren (`verify(`, `Interpreter(`,
   `ClassName(`), then open each hit. A search for a parameter name finds only
   the callers that happened to pass it by keyword.
2. **State the count from the callee search as the denominator**, and treat any
   earlier count from a keyword search as a lower bound, not a total.
3. **Sweep the test tree's helper definitions separately.** A helper that builds
   the old structure appears once in a call-site search while feeding many
   assertions; migrating the callers around it leaves it manufacturing the shape
   you removed.
4. **Order the search by how a call can hide from it:**

| Call form | Found by | Also check |
|-----------|----------|------------|
| Keyword: `f(rows=x)` | parameter-name search | — |
| Positional: `f(a, b, c, x)` | callee-name search | argument position against the new signature |
| Via a helper/fixture that wraps the callee | callee-name search (one hit) | the helper's own definition and every caller of the helper |
| Indirect: stored reference, `getattr`, DI registration, decorator, mock target | full-text search for the bare name, plus the mock/patch target strings | the tests that patch it by dotted path |

5. **Run the full suite, not the tests you touched**, and read the failure count
   as the enumeration's audit. When the suite names files your search did not,
   the search was the incomplete step — redo it before fixing the failures one
   by one.
6. **Prefer a change the compiler or type checker can enumerate for you**:
   renaming the callee alongside the signature change turns every missed caller
   into a name error instead of a silently wrong positional argument.

## Edge cases

| Case | Then |
|------|------|
| The language allows both positional and keyword calls (Python, Ruby, JS objects) | The callee search is mandatory — a positional caller is invisible to any parameter-name search |
| Adding a parameter at the end with a default | Callers keep compiling and running with the old behavior; enumerate anyway and decide per call site, since "still passes" is not "still correct" |
| Reordering parameters of the same type | The most dangerous case: every positional caller still type-checks and silently swaps values. Rename the callee, or change the parameter type, so the mismatch surfaces |
| The callee is exported and used outside this repo | The in-repo enumeration is not the migration scope — the contract's consumers are ([qa-process-regression-scope] Integration ring) |
| The old structure is produced by a fixture in a language with no static checking | Delete the old builder in the same change; a builder left behind reintroduces the old shape at the next test someone writes |

## Instead of

| If you are about to | Do this instead | Why |
|---------------------|-----------------|-----|
| Enumerate call sites with a parameter-name search (`grep -rn "rows="`) | Search for the callee (`grep -rn "verify("`) and read each hit | Positional callers never contain the parameter name, so the search reports a total that excludes them |
| Migrate the call sites the search listed and run the affected tests | Run the whole suite and treat unexpected failing files as missed call sites | The files the search missed are exactly the files you would not think to test |
| Update a test helper's callers and leave the helper | Migrate the helper's definition in the same change | The helper keeps producing the removed shape for every test that uses it |

## Sources

- https://docs.python.org/3/tutorial/controlflow.html — Keyword Arguments: a function may be called with positional arguments, keyword arguments of the form `kwarg=value`, or a mix — so the `kwarg=` text exists only in the keyword-style calls
- https://martinfowler.com/articles/rise-test-impact-analysis.html — deriving what a change affects from a map of the change's actual reach rather than from habit
- Field reproduction: a signature migration scoped by `grep -rn "repo_rows" impl/ tests/` returned 13 hits, all keyword-style, and was reported as "7 of 13 call sites". The full suite then reported `Ran 472 tests / FAILED (failures=11)`, all in one test file that passed the value as the callee's fourth positional argument; `grep -n "verify(" tests/test_backend.py` additionally revealed 8 positional calls plus a `rows_for()` helper still supplying the removed structure to 5 more call sites
