---
id: backend-python-packaging-data-files-and-install-paths
domain: backend
category: packaging
applies_to: [python]
confidence: verified
sources:
  - https://setuptools.pypa.io/en/latest/userguide/datafiles.html
  - https://docs.python.org/3/library/importlib.resources.html
last_verified: 2026-08-14
related: [testing-data-test-data-and-isolation]
---

# A Python Package That Reads Data Files Shipped Next to Its Code

## When this applies

A Python package reads non-code files at runtime — grammar definitions, dialect
files, templates, knowledge bases — and locates them with `__file__`-relative
paths (`Path(__file__).parent / ...` or `.parents[N]`); or an installed console
script cannot find a data file that exists in the repository.

## Do this

1. **Declare the data files as package data** so the build backend puts them in
   the wheel: `include_package_data = True` (files matched by `MANIFEST.in` or
   tracked by VCS) or explicit `package_data` / `tool.setuptools.package-data`
   globs. A file the wheel does not contain cannot be found by any path logic
   after install.
2. **Resolve them by package name, not filesystem position**:
   `importlib.resources.files("mypkg.data").joinpath("grammar.mlir").read_text()`.
   When a real on-disk path is required (a subprocess takes a filename), wrap it
   in `as_file()` — the context manager extracts from a zip when necessary and
   removes the extraction on exit.
3. **Keep every path anchor inside the package.** A `.parents[N]` walk that
   escapes the package directory resolves into the venv's internals after a
   non-editable install — the repo layout above the package does not exist in
   `site-packages`.
4. **Verify against a real non-editable install, not the checkout**: build and
   install into a scratch venv with `pip install .` (no `-e`), then run the
   entry point from a directory outside the repo. Editable installs and
   `PYTHONPATH` runs anchor `__file__` in the repo, so they pass even when the
   wheel ships zero data files.

## Edge cases

| Case | Then |
|------|------|
| The data file must be handed to an external tool as a path | `with as_file(files("pkg.data") / name) as p:` and consume `p` inside the block — a zip extraction is deleted when the block exits |
| Data lives outside any package directory (repo-root `data/`) | Move it under an importable package — setuptools includes data files per package, and `files()` resolves by importable name |
| Python < 3.9 must run the code | Use the `importlib-resources` backport, which provides the same `files()` API |
| Every existing test runs from the repo checkout | Add one job that installs the built wheel into a clean venv and smoke-tests the CLI from outside the repo — repo-anchored resolution failures are invisible to in-repo tests |

## Instead of

| If you are about to | Do this instead | Why |
|---------------------|-----------------|-----|
| Compute a data path as `Path(__file__).resolve().parents[N] / "data"` | Resolve via `importlib.resources.files()` on the owning package | `__file__` anchors wherever the module was imported from; after `pip install .` that is `site-packages`, and the `parents[N]` walk lands inside the venv where the repo's directories do not exist |
| Prove packaging works by running the suite in the checkout | Install the wheel into a scratch venv and run the entry point from outside the repo | Editable and `PYTHONPATH` runs resolve `__file__` to the repo, masking a wheel that ships no data files |

## Sources

- https://setuptools.pypa.io/en/latest/userguide/datafiles.html — "It is strongly recommended that, if you are using data files, you should use `importlib.resources` to access them"; `include_package_data` / `package_data` control what the wheel contains; `__file__` manipulation "isn't compatible with PEP 302-based import hooks, including importing from zip files"
- https://docs.python.org/3/library/importlib.resources.html — packages and resources "do not have to exist as physical files and directories on the file system"; `as_file()` yields a `pathlib.Path` and cleans up any temporary extraction on exit
- Field reproduction 2026-08-14 (linkly v0.4.0): installed `lnpl build` failed rc=4 — the `__file__`-anchored grammar path resolved to `.venv/lib/python3.13/mlir/lnpl.irdl.mlir`, which the wheel never shipped (`impl/lnpl/backend.py:63-64`), while `PYTHONPATH=impl` runs of the same source built fine
