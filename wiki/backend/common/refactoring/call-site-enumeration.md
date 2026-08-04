---
id: backend-common-refactoring-call-site-enumeration
domain: backend
category: refactoring
applies_to: [general]
confidence: verified
sources:
  - https://microsoft.github.io/language-server-protocol/specifications/lsp/3.17/specification/
  - https://docs.python.org/3/reference/expressions.html#calls
  - https://peps.python.org/pep-3102/
last_verified: 2026-08-04
related: [testing-quality-behavior-not-implementation, qa-process-regression-scope, backend-common-api-design-pagination-contract]
---

# Enumerating Call Sites When a Signature Changes

## When this applies

You are changing a function, method, or constructor's signature — adding,
removing, reordering, or restructuring a parameter — and every existing call
must be migrated. Includes scoping the change up front ("how many places does
this touch?") and explaining why a migration you believed complete broke tests.

## Do this

1. **Enumerate by the callee, not by the parameter name.** Search for the call
   token (`verify(`, `Interpreter(`, `ClassName(`) and read every hit. A
   positional argument carries no parameter name anywhere in the call
   expression, so a parameter-name search cannot see it — it finds keyword call
   sites only, and reports a scope smaller than the real one.

2. **Prefer resolved references over text search.** Use the language server's
   find-references (LSP `textDocument/references`, an IDE's "Find Usages") or an
   AST query. These resolve the symbol, so they return positional and keyword
   calls alike, and they do not over-match a same-named function on another
   type. Use callee-token grep as the fallback when no server is available.

3. **Sweep helper and factory definitions as their own step.** A test helper or
   fixture factory that builds the old argument shape appears once in a callee
   search while supplying many call sites. Search the parameter name too — not
   to enumerate calls, but to find the *producers* of the old shape.

4. **Make a stale call fail loudly rather than bind silently.** Where the
   language allows it, mark the changed parameter keyword-only (Python's `*`
   marker, PEP 3102) or otherwise change arity, so a not-yet-migrated positional
   call raises instead of passing its value into a neighbouring parameter.

5. **Run the whole suite, not the files you edited.** The call sites the recon
   search missed are exactly the ones whose tests you had no reason to run.

| Migration shape | Enumerate with |
|-----------------|----------------|
| Renaming a parameter | Callee references — the old name exists only at keyword call sites, so a name search reports a subset |
| Changing a parameter's type or data shape | Callee references, then read the argument at that position in every hit |
| Removing or reordering parameters | Callee references, plus a keyword-only or arity change so unmigrated positional calls raise |
| Changing what a helper/factory produces | Search the produced structure's field names to find every producer, then the callee references of each producer |

## Edge cases

| Case | Then |
|------|------|
| The callee is reached dynamically (`getattr`, reflection, a DI container, a registry keyed by name) | Find-references and callee grep both miss it — additionally search the bare name as a string literal, and keep a runtime assertion on the new shape |
| The name is shared by several types (`save(`, `run(`) | Callee-token grep over-matches; use find-references, or scope the search to the defining module's importers |
| Arguments are supplied by a wrapper (`functools.partial`, a decorator, a curried factory) | The binding happens at the wrapper, not at the visible call — migrate the wrapper and treat its own call sites as a second enumeration pass |
| The recon search and the migration search return the same count | Confirm the count came from callee references; two searches agreeing on the wrong basis is not corroboration |
| The language has no keyword arguments (Go, Java) | The compiler enumerates for you once the arity or type changes — make the change type-incompatible rather than type-compatible, so a missed site fails to build instead of compiling with a wrong value |

## Instead of

| If you are about to | Do this instead | Why |
|---------------------|-----------------|-----|
| Scope the migration by grepping the parameter name (`repo_rows`) | Grep the callee token (`verify(`) or run find-references | A positional call never mentions the parameter name, so the name search returns keyword call sites only and understates the scope |
| Treat the recon search's hit count as the migration's size | Read every hit, and re-enumerate by callee before declaring the migration complete | The count answers "how many places name this parameter", not "how many places call this function" |
| Migrate the call sites and leave the parameter positionally compatible | Make it keyword-only or change arity | A stale positional call otherwise binds its value to whatever parameter now occupies that slot, which type checks and runs |
| Verify the migration by running the tests for the files you edited | Run the full suite | The tests that catch a missed call site live in the files you did not know to open |

## Sources

- https://microsoft.github.io/language-server-protocol/specifications/lsp/3.17/specification/ — `textDocument/references` resolves all references to a symbol, with `includeDeclaration` controlling whether the declaration is returned; a resolved-reference query is independent of how each call spells its arguments
- https://docs.python.org/3/reference/expressions.html#calls — argument binding rules: positional arguments are matched to parameters by position, keyword arguments by name; the two forms of the same call therefore share no common text
- https://peps.python.org/pep-3102/ — keyword-only arguments: parameters after a bare `*` can only be supplied by keyword
- Local reproduction 2026-08-04 (CPython 3.14.6): for a file holding `verify("s","a",1, repo_rows=[…])` and `verify("s","a",1,[…])`, `grep -n "repo_rows"` returns the definition and the keyword call (2 hits) while `grep -n "verify("` returns the definition and both calls (3 hits) — the positional call is invisible to the parameter-name search. Marking the parameter keyword-only (`def verify(spec, mode, budget, *, repo_rows=None)`) turns the stale positional call into `TypeError: verify() takes 3 positional arguments but 4 were given`
- Field evidence (linkly, 2026-08-04): a signature migration scoped by `grep -rn "repo_rows" impl/tests/` (13 hits, all keyword) reported 7 remaining sites; the full suite then reported `Ran 472 tests / FAILED (failures=11)`, all in one file that passed the value as `verify()`'s fourth positional argument, and a `rows_for()` helper was still producing the old shape for 5 further call sites
