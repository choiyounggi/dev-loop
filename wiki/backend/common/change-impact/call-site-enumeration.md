---
id: backend-common-change-impact-call-site-enumeration
domain: backend
category: change-impact
applies_to: [general]
confidence: verified
sources:
  - https://docs.python.org/3/glossary.html
  - https://docs.python.org/3/library/ast.html
  - https://peps.python.org/pep-0570/
last_verified: 2026-08-05
related: [qa-process-regression-scope, backend-python-language-mutable-state-traps, testing-data-test-data-and-isolation]
---

# Enumerating Call Sites Before Changing a Callee's Contract

## When this applies

You are about to change the contract of a function, method, or constructor that
other code calls — adding, removing, reordering, or redefining a parameter — and
the plan depends on having the complete list of call sites. Also when a
migration you scoped from a search came back green and then failed on call sites
the search never listed.

## Do this

1. **Enumerate by the callee's name (`verify(`, `Interpreter(`) and read every
   hit.** Treat a search for a parameter name (`repo_rows=`) as a partial index:
   it lists only the sites that happen to pass that argument by keyword.

2. **Read the partiality as a language property, not a search-quality problem.**
   Python's default parameter kind is positional-or-keyword — it "specifies an
   argument that can be passed either positionally or as a keyword argument.
   This is the default kind of parameter". The parse tree keeps the two forms in
   separate fields: in `ast.Call`, "`args` holds a list of the arguments passed
   by position" while "`keywords` holds a list of `keyword` objects representing
   arguments passed by keyword". A keyword-name search reads `keywords` only.

3. **Pick the enumeration handle from the callee's shape:**

| Callee | Enumerate by |
|--------|--------------|
| A distinctively named function | The name plus `(`, across the whole repo including tests, fixtures, and scripts |
| A name common enough to collide (`run`, `get`, `verify`) | The language server's find-references, or an AST pass collecting `Call` nodes whose `func` resolves to it — text search cannot separate the homonyms |
| A constructor | The class name plus `(`, plus each import form that renames it (`from m import C as D` → `D(`) |
| Something passed as a value (callback, decorator, registry entry, `functools.partial`) | The bare name without `(` as well — the argument list at those sites lives where the value is invoked, not where it is referenced |
| Dispatched dynamically (`getattr`, a name in config/YAML) | The string form too, and record in the plan that this class of site is not statically enumerable |

4. **State the method next to the count.** "13 call sites (grep `verify(`,
   including tests)" is checkable; "13 call sites" is not, and a plan built on
   an unstated method cannot be reviewed for this gap.

5. **Re-run the same enumeration after the edit and require zero old-contract
   sites**, then run the tests. The re-run is what converts the enumeration from
   a plan input into a completion check.

## Edge cases

| Case | Then |
|------|------|
| The new parameter can be keyword-only | Declare it after a bare `*`; a stale positional call then fails at the call site instead of silently binding to the wrong parameter (PEP 570 defines the `/` and `*` markers that fix a parameter's passing form) |
| A parameter is inserted before existing ones rather than appended | Every positional site rebinds silently and none of them changes text — a keyword search cannot bound the risk, so a full callee-name enumeration is the only scope; prefer appending |
| The callee is re-exported through a package `__init__` or a facade | Enumerate the re-exported name as well; sites importing through the facade never mention the defining module |
| Call sites live in another repository or a published package | The change is a versioned deprecation, not an in-place edit: keep the old contract accepting its old shape for a release, and enumerate what you own now |
| The language has no keyword arguments at all (JavaScript, Go) | Every site is positional, so a parameter-name search returns nothing at all — enumerate by callee name from the start |
| The repo has no working language server for the language | Enumerate by callee name and say so; an AST pass over `Call` nodes is the fallback that survives aliasing |
| A test helper wraps the callee or rebuilds its data shape (a fixture builder feeding it) | Read every helper definition the enumeration surfaces and enumerate the helper's own call sites too — the helper appears once in the callee enumeration while supplying the old contract to every one of its callers ([testing-data-test-data-and-isolation]) |

## Instead of

| If you are about to | Do this instead | Why |
|---------------------|-----------------|-----|
| Report "N call sites, M need editing" from a search for the parameter name | Search the callee name, read each hit, and report the method with the count | Positional-or-keyword is the default parameter kind, so a keyword search is blind to every site that passes the argument by position |
| Treat a green suite after a partial migration as proof the migration is complete | Re-run the callee-name enumeration and require zero old-contract sites | The suite exercises the sites it reaches; the ones the recon missed are the ones that break later |
| Scope a contract change from the plan's original recon | Re-enumerate at edit time | Call sites are added between planning and editing, and the plan's count is what makes the omission invisible |
| Add the parameter in the middle of the signature and update the keyword sites | Append it, or make it keyword-only, then migrate every enumerated site | A middle insertion rebinds existing positional arguments without changing a character at those sites |

## Sources

- https://docs.python.org/3/glossary.html — *positional-or-keyword*: "specifies an argument that can be passed either positionally or as a keyword argument. This is the default kind of parameter"; *keyword-only* requires a bare `*`, *positional-only* a `/`
- https://docs.python.org/3/library/ast.html — `ast.Call`: "`args` holds a list of the arguments passed by position", "`keywords` holds a list of `keyword` objects representing arguments passed by keyword" — the two forms are distinct fields, so a keyword-text search cannot reach positional arguments
- https://peps.python.org/pep-0570/ — the `/` marker for positional-only parameters, alongside the existing `*` marker for keyword-only, as the way a signature fixes how an argument may be passed
- Local reproduction 2026-08-04 (Python 3.14.6, macOS): over four call sites of `verify(...)` where one passes `repo_rows=` by keyword, a regex search for `repo_rows\s*=` matches 1 while an AST pass over `Call` nodes named `verify` finds 4 — 3 sites invisible to the keyword search
- Field incident 2026-08-04 (`linkly-t1-repo-policy`, Python): recon by keyword search reported "13 call sites, 7 need editing"; 8 further seeds passed the same value as `verify()`'s fourth positional argument, and the suite the session had reported green then ran `472 tests / FAILED (failures=11)`
- Field incident 2026-08-05 (`linkly`, Python): a `rows_for()` test helper kept reproducing a removed rule for five call sites while appearing as a single hit in the callee enumeration — helper definitions are fan-out points, not one site
