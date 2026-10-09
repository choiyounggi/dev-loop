---
id: testing-data-installed-extensions-discovered-at-test-time
domain: testing
category: data
applies_to: [python, general]
confidence: verified
sources:
  - https://packaging.python.org/en/latest/specifications/entry-points/
  - https://docs.python.org/3/library/importlib.metadata.html#entry-points
  - https://docs.pytest.org/en/stable/how-to/plugins.html
last_verified: 2026-10-02
related: [testing-data-test-data-and-isolation, platforms-toolchains-environment-resync-removes-undeclared-packages, testing-flaky-diagnosing-flaky-tests]
---

# Extension Packages Installed in the Test Environment

## When this applies

The project discovers extensions (plugins, drivers, backends, exporters) from
installed packages — Python entry points, or any registry filled by scanning
the environment. You installed one such package into the project's environment
for an experiment, a benchmark, or a manual check, and you are about to run the
full suite there; or the suite is red in that environment while the same commit
is green on CI.

## Do this

1. **Before running the suite, list what the registry currently discovers** and
   compare it with what a clean install of the project discovers:

   ```sh
   python -c 'from importlib.metadata import entry_points as e; print([(p.name, p.dist.name) for p in e(group="<group>")])'
   ```

   Each name in that output whose distribution is not the project or a declared
   dependency is environment state the tests did not create.
2. **Choose where the extension lives by what the run is for:**

| Run | Environment |
|-----|-------------|
| The project's own suite | The project's environment with only declared dependencies installed |
| An experiment that needs the extension | A second virtual environment created for it; the project's environment stays clean |
| The extension was already installed into the project's environment | Uninstall it, re-run step 1, then run the suite |

3. **When the suite is red, read what the failing tests assume before reading
   the diff.** Tests that assert "unknown backend is rejected", "the extension
   list is empty", or an exact list of registered names fail from the installed
   package alone. A failure set made of those assertions, on a tree with no
   change to the registry code, points at the environment.
4. **Confirm by removal**: uninstall the package and re-run the same failing
   tests. Green after removal with no code change closes the question; record
   both summary lines.

## Edge cases

| Case | Then |
|------|------|
| The test runner itself loads plugins from the environment (pytest) | The same mechanism applies one level up: "If a plugin is installed, pytest automatically finds and integrates it". Run with `PYTEST_DISABLE_PLUGIN_AUTOLOAD=1` or `--disable-plugin-autoload` (8.4+) and name the wanted plugins with `-p`, or disable one with `-p no:NAME` |
| The package's `*.dist-info` directory is present and its code is not (an editable install whose source moved, a partial uninstall) | The name is still discovered, because discovery reads `entry_points.txt` only, and loading it raises `ModuleNotFoundError`. Uninstall by distribution name; when the installer refuses because the metadata directory has no install record, list that `*.dist-info` directory, delete it by its absolute path, and re-run step 1 |
| Tests must pass with extensions present (a distribution that ships with drivers) | Make the registry injectable and have each test build its own — the assertion then covers the registry's behaviour, independent of the environment |
| An environment sync tool manages the venv | Re-syncing removes packages the lockfile does not declare ([platforms-toolchains-environment-resync-removes-undeclared-packages]), which is the cleanup here and a surprise for the experiment — another reason to give the experiment its own environment |

## Instead of

| If you are about to | Do this instead | Why |
|---------------------|-----------------|-----|
| Read a red suite in an environment with an extra extension as a regression in your diff | List the discovered extensions and re-run after uninstalling | Discovery reads installed metadata; the package changes results with no import statement and no line in the diff |
| `pip install` an experimental driver into the project's environment "for a minute" | Create a separate environment for the experiment | The install outlives the experiment and fails the next full run, hours later, with nothing connecting the two |
| Make the "no extensions" tests tolerant of extra names so the suite passes locally | Keep the exact assertion and clean the environment, or inject the registry | A tolerant assertion stops detecting an extension the project registers by mistake |

## Sources

- https://packaging.python.org/en/latest/specifications/entry-points/ — "Entry points are a mechanism for an installed distribution to advertise components it provides to be discovered and used by other code"; "Entry points are defined in a file called `entry_points.txt` in the `*.dist-info` directory of the distribution"
- https://docs.python.org/3/library/importlib.metadata.html#entry-points — `entry_points()` returns "a collection of all `EntryPoint` objects" for the installed distributions, selectable by `group`
- https://docs.pytest.org/en/stable/how-to/plugins.html — "If a plugin is installed, pytest automatically finds and integrates it, there is no need to activate it"; `-p no:NAME`, `PYTEST_DISABLE_PLUGIN_AUTOLOAD`, and `--disable-plugin-autoload` ("Added in version 8.4")
- Local reproduction 2026-10-02 (Python 3.14): `entry_points(group="demoapp.backends")` returned `[]`; after a directory holding only `demo_ext-0.0.1.dist-info/METADATA` and `entry_points.txt` was put on `sys.path` it returned `['fake']` with no module of that name present (`.load()` raised `ModuleNotFoundError`); after the directory was removed it returned `[]` again
- Field evidence 2026-10-02 (a Python project that discovers storage drivers by entry point): with an external driver package installed for a load experiment the suite ended `FAILED (failures=4, errors=1, skipped=1)`; after uninstalling it, with no code change, `Ran 4046 tests`, `OK (skipped=1)`
