---
id: testing-migration-call-site-enumeration
domain: testing
category: migration
applies_to: [general]
confidence: verified
sources:
  - https://docs.python.org/3/reference/expressions.html
  - https://microsoft.github.io/language-server-protocol/specifications/lsp/3.17/specification/
last_verified: 2026-08-05
related: [testing-quality-behavior-not-implementation, testing-data-test-data-and-isolation, qa-process-regression-scope]
---

# Enumerating Every Call Site of a Signature You Are Changing

## When this applies

You are changing a function's parameter list, or the shape of a structure it
receives, and must migrate every caller in one change. Also when a migration you
believed complete broke tests you had not counted, or when scoping how large such
a change is before starting.

## Do this

1. **Enumerate by what is called, not by what a parameter is named.** Search for
   the callee token with its opening parenthesis — `verify(`, `Interpreter(`,
   `ClassName(` — and read every hit. A positional argument carries no parameter
   name at the call site: "If there are N positional arguments, they are placed in
   the first N slots", while only a keyword argument's "identifier is used to
   determine the corresponding slot". A `param=` search is blind to every
   positional caller by construction.
2. **Sweep test helper definitions as a separate pass.** Grep the test tree for
   functions that build or return the structure you are changing (`def *_for(`,
   `make_*`, `build_*`, fixtures/factories). A helper is one hit in a call-site
   search but supplies the old shape to every test that uses it, so its callers
   never appear in your count.
3. **Reconcile two independent counts before editing.** Take the callee-token
   count and a semantic one (a language server's find-references / call hierarchy,
   or the compiler/type checker after you change the signature). When they
   disagree, the gap is the set you were about to miss.
4. **Let the type checker or a deliberately breaking change do the enumeration
   where the language allows it.** Rename the function alongside the signature
   change, or make the new parameter required: every unmigrated caller becomes a
   compile or collection error instead of a silent runtime mismatch.
5. **Run the full suite, not the tests you touched, and compare the total.** The
   callers you missed are by definition the ones you did not think to run
   ([qa-process-regression-scope] scopes the wider re-test).

## Edge cases

| Case | Then |
|------|------|
| The callee is a common name (`run`, `get`, `verify`) | Qualify by module or receiver (`mod.verify(`, `self.verify(`), then read each hit — a name-only count over-reports as badly as a keyword search under-reports |
| Calls go through a wrapper, decorator, or dependency-injection container | The wrapper is the only textual call site; enumerate the wrapper's callers as a second generation and repeat until the frontier is empty |
| The language allows dynamic dispatch (`getattr`, reflection, string-keyed registries) | Textual and semantic search both miss these — grep for the callee's name as a bare string too, and cover the dispatch path with a test |
| The signature is public API you cannot migrate atomically | Keep both forms: add the new parameter with a default, migrate callers, then remove the old form in a second change |
| The old shape is produced by a helper you intend to delete | Delete the helper first and let the failures enumerate its consumers, rather than migrating the helper's output |
| A caller lives in a fixture or parametrize decorator, not a test body | Search the test tree for the structure's field names as well as the callee — decorator-level data never appears as a call |

## Instead of

| If you are about to | Do this instead | Why |
|---------------------|-----------------|-----|
| Scope the migration with `grep -rn "param_name="` | Search for the callee token (`verify(`) and read each hit | Positional callers never write the parameter name, so the keyword search returns a confident, incomplete number |
| Trust one search's count as the blast radius | Reconcile a textual count with a semantic one (find-references, or the type checker after the change) | The two miss different things; their disagreement is precisely the list you would have shipped broken |
| Migrate call sites and stop | Sweep helper/factory definitions in the test tree in a separate pass | One helper keeps feeding the old shape to many tests while appearing as a single call site |
| Run only the tests near the code you edited | Run the full suite and compare the total against the pre-change run | Missed callers are exactly the ones outside your mental model of the change |

## Sources

- https://docs.python.org/3/reference/expressions.html — Calls: "If there are N positional arguments, they are placed in the first N slots"; "for each keyword argument, the identifier is used to determine the corresponding slot" — the parameter name exists at the call site only in the keyword form
- https://microsoft.github.io/language-server-protocol/specifications/lsp/3.17/specification/ — `textDocument/references` and `callHierarchy/incomingCalls` resolve callers from the language's semantics rather than from text, which is why they and grep disagree

## Field context

`linkly`, 2026-08-04: scoping a change to a repository-row structure by
`grep -rn "repo_rows" impl/tests/` returned 13 hits, all keyword-form, and the
migration was declared 7-of-13 complete. The full suite then reported
`Ran 472 tests / FAILED (failures=11)`, every failure in `test_backend.py`, which
passed the seed as `verify()`'s fourth **positional** argument. Re-enumerating
with `grep -n "verify(" impl/tests/test_backend.py` surfaced 8 positional call
sites plus a `rows_for()` helper definition that was still supplying the
to-be-removed shape to 5 further call sites.
