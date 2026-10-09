---
id: backend-python-language-circular-imports
domain: backend
category: language
applies_to: [python]
confidence: verified
sources:
  - https://docs.python.org/3/faq/programming.html#how-can-i-have-modules-that-mutually-import-each-other
  - https://docs.python.org/3/faq/programming.html#what-are-the-best-practices-for-using-import-in-a-module
  - https://docs.python.org/3/library/typing.html#typing.TYPE_CHECKING
last_verified: 2026-10-06
related: [testing-strategy-import-time-side-effects, backend-common-change-impact-call-site-enumeration]
---

# A New Import That Closes a Module Cycle in Python

## When this applies

You are adding `from <module> import <name>` to a Python module, and `<module>`
already imports — directly or through other modules — the module you are editing
(`wsgi -> config -> serve -> wsgi`). Also when `import pkg.x` fails with
`ImportError: cannot import name '...' from partially initialized module` right
after such an edit.

## Do this

1. Trace the chain before writing the import: for the target module, follow its
   top-level imports until you either return to the module you are editing (a
   cycle) or run out. Record the chain in the change description.
2. Pick the fix by the case below.
3. Prove it with fresh interpreters: run `python -c "import <pkg>.<module>"` once for
   **each** module in the traced cycle (three runs for `wsgi -> config -> serve`),
   because the module imported first decides which one is half-initialized.

| Case | Do |
|------|----|
| The imported name is used only inside one function (or one branch of it, e.g. only when a config path is given) | Move the import into that function or branch. By the time the function runs, both modules have finished initializing |
| The name is needed at module top level (base class, decorator, default argument, module constant) | Restructure: move the shared names into a third module that neither side imports back, and import it from both |
| Both modules need each other's names only inside functions | Use `import <module>` at top level and reference `<module>.<name>` at call time — the module object exists during the cycle, only its names are missing |

The failure mechanism (Python FAQ): a cycle works when both modules use the
`import <module>` form, and fails when the second module grabs a name out of the
first with a top-level `from module import name`, because the first module is
still busy importing the second and has not bound that name yet.

## Edge cases

| Case | Then |
|------|------|
| The function-local import sits on an error path that runs rarely | Add a test that executes that branch; a broken function-local import surfaces only when the line runs, not at module import |
| A type checker needs the name for annotations only, and nothing evaluates those annotations at run time | Import it under `if TYPE_CHECKING:` and quote the annotation (or use `from __future__ import annotations`); nothing is imported at run time |
| The annotations are evaluated at run time (pydantic models, FastAPI signatures, `typing.get_type_hints`, dataclass field resolution) | Use a function-local import or a third module instead of `TYPE_CHECKING` — a name imported only for the type checker is undefined when the annotation is resolved |
| The cycle is between a package `__init__` and one of its submodules | Remove the re-export from `__init__` or import the submodule at the bottom of `__init__` after the names the submodule needs are bound |

## Instead of

| If you are about to | Do this instead | Why |
|---------------------|-----------------|-----|
| Add the top-level `from x import y` and rely on tests passing | Run the per-module fresh-interpreter imports from step 3 | A cycle fails only when a specific module is imported first; a passing test run proves the order that run used, not the order a server entry point uses at boot |
| Reorder top-level imports by trial until the error goes away, with no traced cycle | Trace the cycle (step 1) and apply a fix from the table; the `__init__` bottom-import row is a deliberate placement, not trial reordering | Order-dependent fixes break again when an unrelated import elsewhere changes which module loads first |

## Sources

- https://docs.python.org/3/faq/programming.html#what-are-the-best-practices-for-using-import-in-a-module — "It may be necessary to move imports into a function or class to avoid problems with circular imports"; "Circular imports are fine where both modules use the 'import <module>' form of import. They fail when the 2nd module wants to grab a name out of the first ('from module import name') and the import is at the top level"; "if the second module is only used in one function, then the import can easily be moved into that function"
- https://docs.python.org/3/faq/programming.html#how-can-i-have-modules-that-mutually-import-each-other — restructure so the recursive import is not needed; reference `<module>.<name>` instead of `from <module> import`; Jim Roskind's ordering — exports first, then `import` statements, then active code — is the basis for importing the submodule after the names it needs are bound
- https://docs.python.org/3/library/typing.html#typing.TYPE_CHECKING — "A special constant that is assumed to be True by static type checkers. It's False at runtime."; annotations naming such imports are quoted or deferred
- Field evidence 2026-10 (a Python WSGI service, plan t187): a module-level `from .config import load_config` in `wsgi.py` closed `wsgi -> config -> serve -> wsgi` and broke `import <pkg>.wsgi` outright; moving the import inside the `if config is not None:` branch fixed it, confirmed by running the import before and after
