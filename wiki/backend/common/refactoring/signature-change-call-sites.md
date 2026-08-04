---
id: backend-common-refactoring-signature-change-call-sites
domain: backend
category: refactoring
applies_to: [general]
confidence: verified
sources:
  - https://docs.python.org/3/reference/expressions.html
  - https://libcst.readthedocs.io/en/latest/codemods.html
  - https://github.com/facebookincubator/bowler
last_verified: 2026-08-04
related: [testing-quality-tests-that-cannot-fail, testing-quality-behavior-not-implementation]
---

# Enumerating Call Sites Before Changing a Signature

## When this applies

You are changing a function, method, or constructor's signature — adding or
removing a parameter, renaming one, or changing the shape of a value it takes —
and need every caller migrated. Also when a migration you scoped by searching for
the parameter name left callers broken.

## Do this

1. **Enumerate call sites by searching for the callee, not for the parameter
   name.** Search `verify(`, `Interpreter(`, `ClassName(`, `.build(` and read each
   hit. A positional argument carries no name at the call site, so a search for
   `repo_rows=` returns only the subset of callers that happened to use keyword
   form and reports that subset as the whole population.
2. **Derive the expected count from the callee search before editing**, and
   reconcile the number you migrated against it. When the two differ, the
   remainder is the list you have not read yet.
3. **Search test helper definitions separately from call sites.** A helper that
   constructs the old shape (`rows_for()`, `make_payload()`, a fixture factory)
   appears once in a callee search while supplying the old shape to every test
   that calls it. Grep for functions that *build* the argument, and migrate the
   helper before its callers.
4. **Take an argument-position inventory for the callee:**

| Call form | Found by | Migration note |
|-----------|----------|----------------|
| `f(a, b, seed)` positional | Callee search only | The parameter's meaning is fixed by index — inserting a parameter anywhere but the end silently rebinds every positional caller |
| `f(a, seed=x)` keyword | Callee search and name search | Renaming the parameter breaks exactly these |
| `f(**opts)` unpacked | Callee search; the key lives in the dict literal or its producer | Trace back to where the dict is built and migrate that |
| `partial(f, ...)`, decorators, callbacks passed by reference | Search for the bare name `f` without a paren | The call happens elsewhere; the arity contract still changes |
| Subclass overrides / protocol implementations | Search for the method name at `def` | An override keeping the old signature type-checks in some languages and breaks at dispatch |

5. **Use a CST/AST codemod when the call sites number more than a handful.**
   LibCST and Bowler match `Call` nodes and rewrite arguments structurally, so
   positional and keyword forms are both matched, and the transform is
   mechanically complete where a text search is a sample.
6. **Run the entire suite, not the tests near your edit.** The suite is the
   enumeration you did not think of; treat a failure count larger than your
   migration list as evidence that the list was short, and go back to step 1.
7. **When adding a parameter, append it with a default and migrate callers in a
   second pass.** Then remove the default so the compiler or type checker
   enumerates whatever remains.

## Edge cases

| Case | Then |
|------|------|
| The callee's name is common (`build`, `run`, `get`) | Anchor the search on the qualified form (`backend.build(`, `self._rows(`) plus the import statements that bind the name, and read the imports to bound the file set |
| The parameter is renamed but its position and type are unchanged | Keyword callers break and positional callers keep working silently with the new meaning — a callee search is the only one that finds them |
| The change reshapes a data structure rather than the parameter list | Search for the producers of that structure as well as the callee; the shape spreads through helpers that no signature search reaches |
| A dynamic dispatch or plugin registry calls the function by name string | Search for the string form of the name, and add a startup assertion on the resolved signature |
| The callee is exported from a package other repos consume | Keep both shapes accepted for one release and log use of the old one, then remove after the log goes quiet |
| The migration is finished and the suite is green | Verify one migrated call site fails when its new argument is wrong, so the tests are actually asserting the new shape ([testing-quality-tests-that-cannot-fail]) |

## Instead of

| If you are about to | Do this instead | Why |
|---------------------|-----------------|-----|
| Scope the migration by grepping the parameter name (`repo_rows`) | Grep the callee (`verify(`, `Interpreter(`) and read every hit | Positional callers carry no parameter name, so the name search cannot see them and reports a partial count as complete |
| Trust a hit count from a name search as the size of the job | Count callee hits, migrate against that number, then run the full suite | The two counts differ by exactly the callers a name search is blind to |
| Migrate call sites and skip test helper definitions | Migrate the helpers first, then their callers | One helper reproduces the old shape for many tests while appearing as a single hit |
| Insert a new parameter in the middle of the list | Append it with a default, migrate, then tighten | Insertion rebinds every positional argument after it without any diagnostic |
| Hand-edit dozens of call sites from a text search | Write a LibCST or Bowler codemod over `Call` nodes | Arguments can be arbitrary expressions, so a regex rewrite is a sample of the call sites while a CST transform is the set |

## Sources

- https://docs.python.org/3/reference/expressions.html — a call's argument list binds positional arguments by position and keyword arguments by name ("If keyword arguments are present, they are first converted to positional arguments"), so the parameter name is absent from the source text of a positional call site
- https://libcst.readthedocs.io/en/latest/codemods.html — LibCST parses source into a lossless concrete syntax tree and its codemod framework matches and rewrites `Call` nodes across a codebase, covering positional and keyword arguments alike
- https://github.com/facebookincubator/bowler — "Safe code refactoring for modern Python": syntax-tree-level manipulation for "safe, large scale code modifications while guaranteeing that the resulting code compiles and runs"
- Field incident 2026-08-04 (linkly, `verify()` seed-parameter reshape): `grep -rn "repo_rows" impl/tests/` returned 13 hits, all keyword form, and the migration was scoped to them. The full suite then reported `Ran 472 tests / FAILED (failures=11)`, all in `test_backend.py`, which passed the seed as `verify()`'s fourth positional argument. `grep -n "verify(" impl/tests/test_backend.py` surfaced the 8 positional call sites plus a `rows_for()` helper that was still producing the removed shape for 5 more
