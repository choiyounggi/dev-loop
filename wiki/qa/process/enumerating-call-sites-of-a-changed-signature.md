---
id: qa-process-enumerating-call-sites-of-a-changed-signature
domain: qa
category: process
applies_to: [general]
confidence: verified
sources:
  - https://docs.python.org/3/reference/expressions.html#calls
  - https://libcst.readthedocs.io/en/latest/codemods.html
last_verified: 2026-08-05
related: [qa-process-regression-scope, testing-quality-checks-that-cannot-pass, debugging-methodology-verify-the-fix]
---

# Enumerating Every Call Site of a Changed Signature

## When this applies

You are changing a function's, constructor's, or method's signature — parameter
count, parameter order, or the shape of a structure it receives — and must migrate
every caller. You are about to build the call-site census with a text search, and
the census will decide the size of the change and what you re-test.

## Do this

1. **Search by call target, not by parameter name.** Enumerate with the callee's
   name plus its opening paren (`verify(`, `Interpreter(`, `.build(`), then open
   every hit. A parameter name appears in the source only when the caller passes it
   as a keyword; positional callers carry no name to match.
2. **Sweep helper and wrapper definitions separately.** Search the test tree and any
   `helpers`/`factories`/`support` module for functions that *construct* the changed
   structure or *forward* to the changed callee. One helper appears once in a
   call-target search while supplying the old shape to many tests.
3. Choose the enumeration tool by what the language gives you:

| Case | Do |
|------|----|
| The language has a compiler or strict type checker over the whole repo | Make the change, then let the build/`mypy`/`tsc` error list be the census; text search only seeds the first pass |
| Dynamically typed, no whole-repo checker | Run a call-target search, read every hit, then run the **full** suite — the search is the hypothesis, the suite is the verdict |
| The call sites number in the hundreds, or the change is mechanical | Use an AST/CST codemod (LibCST, jscodeshift, `ast-grep`) — it matches call nodes, so positional and keyword forms are found alike |
| The callee's name is common (`run(`, `get(`) and the search floods | Search the import/definition site first to get the owning module, then constrain the call search to files importing it |

4. **State the census as a count you then falsify.** Record "N call sites found by
   `<exact command>`", make the change, and run the whole suite — not the subset you
   believe is affected. A count derived from search is a lower bound until the suite
   agrees.
5. Feed the confirmed call-site list into regression scope: every consumer of a
   changed contract is tested, not a sample ([qa-process-regression-scope]).

## Edge cases

| Case | Then |
|------|------|
| The full suite passes but only a subset was run (marker, path filter, `-k`) | Re-run unfiltered before calling the migration complete; a filtered run silently excludes the file where positional callers cluster |
| The callee is re-exported or aliased (`from x import verify as check`) | Search the alias and the re-export module too; the call-target search misses `check(` |
| Callers pass the structure through `*args` / `**kwargs` / a dict spread | The call site names nothing at all — find these by searching the forwarding wrapper's definition, not its call sites |
| The changed structure is also built by fixtures, factories, or seed files | These are call sites of the *shape*, not of the function; search for the structure's field names as well |
| The callee is public API consumed outside this repo | The in-repo census is not the whole census — version the signature or keep a compatibility overload instead of migrating in place |

## Instead of

| If you are about to | Do this instead | Why |
|---------------------|-----------------|-----|
| Grep `param_name=` to count the call sites to migrate | Grep the call target `callee(` and read every hit | Positional arguments are matched to parameters by position and carry no identifier in the source, so a keyword search cannot match them |
| Trust a search-derived count ("13 hits, 7 to change") as the scope | Treat the count as a hypothesis and let the full suite or the type checker confirm it | The searches that under-report are exactly the ones that look conclusive |
| Migrate the call sites and re-run only the tests you touched | Run the whole suite unfiltered | Old-shape callers live in files the change never opened |
| Update a test helper's callers one by one | Change the helper's definition and let its callers flow through | The helper is the single place the old shape is reproduced; editing callers leaves the source of the old shape intact |

## Sources

- https://docs.python.org/3/reference/expressions.html#calls — "If there are N positional arguments, they are placed in the first N slots"; keyword arguments are matched by identifier. Positional call sites therefore contain no parameter name to search for
- https://libcst.readthedocs.io/en/latest/codemods.html — a codemod is "an automated refactor that can be applied to a codebase of arbitrary size"; CST transformations match call nodes rather than text
