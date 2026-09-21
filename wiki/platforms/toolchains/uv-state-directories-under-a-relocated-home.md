---
id: platforms-toolchains-uv-state-directories-under-a-relocated-home
domain: platforms
category: toolchains
applies_to: [uv, python]
confidence: verified
sources:
  - https://docs.astral.sh/uv/reference/storage/
  - https://docs.astral.sh/uv/concepts/cache/
last_verified: 2026-09-17
related: [testing-data-test-data-and-isolation, testing-quality-tests-that-cannot-fail, platforms-toolchains-version-management, platforms-toolchains-environment-resync-removes-undeclared-packages]
---

# Running uv From a Process Whose HOME Points at a Scratch Directory

## When this applies

A test suite, sandbox, or hook sets `HOME` (or `XDG_CACHE_HOME` /
`XDG_DATA_HOME`) to a scratch directory for isolation and then invokes `uv run`,
`uv tool run`, or a uv-launched script — especially with `--offline`. Symptoms:
`… was not found in the cache` for a package that resolves fine from your shell,
uv picking a different Python than it does interactively, or uv-dependent test
cases that report `skip` on a machine where uv works.

## Do this

1. **Carry both of uv's HOME-derived locations across the HOME swap.** uv keeps
   two separate stores, each resolved from the environment at invocation:

| Store | Default on Unix | Override |
|-------|-----------------|----------|
| Package cache (wheels, built sdists, resolution data) | `$XDG_CACHE_HOME/uv` or `$HOME/.cache/uv` | `UV_CACHE_DIR` (or `--cache-dir`) |
| Managed Python interpreters | `python/` under the data dir, e.g. `~/.local/share/uv/python` | `UV_PYTHON_INSTALL_DIR` |
| Installed tools (`uv tool install`) | `tools/` under the data dir, e.g. `~/.local/share/uv/tools` | `UV_TOOL_DIR` |

   Capture the real locations **before** the swap and export them after it:

   ```sh
   REAL_UV_CACHE="$(uv cache dir)"; REAL_UV_PYTHON="$(uv python dir)"
   export HOME="$SCRATCH"
   export UV_CACHE_DIR="$REAL_UV_CACHE" UV_PYTHON_INSTALL_DIR="$REAL_UV_PYTHON"
   ```

2. **Pass the interpreter store even when only the cache seems to matter.**
   With the cache alone, uv no longer sees its managed interpreters and falls
   back to a system Python of another version (reproduced). In the reported
   field case the cached artifacts for the original interpreter then did not
   apply, and `--offline` failed on a package that was in the cache.
3. **Confirm from inside the swapped environment, not from your shell:** run
   `uv cache dir`, `uv python dir`, and `uv python list --only-installed` under
   the same `HOME` the suite uses, and require the managed interpreter in the
   list.
4. **Require the uv-dependent cases to report `ok`, by count.** When the suite
   converts an unavailable uv into `skip`, a broken environment is
   indistinguishable from a green run. Read the runner's per-case output once
   the variables are in place and assert the number of executed cases; keep
   `skip` for "uv is not installed", and fail on "uv is installed and the
   offline resolve failed".

## Edge cases

| Case | Then |
|------|------|
| The suite must also stay hermetic (no writes into the developer's real cache) | Pre-warm a suite-owned cache once (`UV_CACHE_DIR=<repo-ignored dir> uv sync`) and point the tests at that copy; pass the real `UV_PYTHON_INSTALL_DIR` read-only, or pin `--python` to a system interpreter present on every runner |
| CI runner has no managed interpreter at all | The fallback to system Python is then the normal path; pin the version (`.python-version`, `--python 3.x`) so the local and CI resolutions match ([platforms-toolchains-version-management]) |
| The isolation swaps `XDG_CACHE_HOME` / `XDG_DATA_HOME` and leaves `HOME` alone | Same effect — the XDG variables take precedence over the `$HOME` defaults; the same two overrides restore the stores |
| Windows | The documented cache default is `%LOCALAPPDATA%\uv\cache`, so the variable that relocates it differs from Unix; run step 3 under the suite's environment to see which store moved before choosing overrides |
| Other per-user tools in the same suite (npm, pip, cargo, gh) | Each has its own cache/config variable; list the tools the suite spawns and carry each one's store explicitly rather than restoring `HOME` ([testing-data-test-data-and-isolation]) |

## Instead of

| If you are about to | Do this instead | Why |
|---------------------|-----------------|-----|
| Export only `UV_CACHE_DIR` after relocating `HOME` | Export `UV_CACHE_DIR` and `UV_PYTHON_INSTALL_DIR` together | The interpreter store is resolved from the data dir, not the cache dir; without it uv selects another Python and the cached artifacts for the original one go unused |
| Restore the real `HOME` for the uv-calling cases | Keep `HOME` on the scratch dir and override uv's two stores | Restoring `HOME` re-opens every other `~`-derived write path the isolation was added to close |
| Read a run with zero failures as proof the uv cases pass | Count `ok` versus `skip` for those cases | A skip-on-unavailable guard turns an environment fault into a silent pass, so the cases exist without ever executing |

## Sources

- https://docs.astral.sh/uv/reference/storage/ — cache directory is `$XDG_CACHE_HOME/uv` or `$HOME/.cache/uv` on Unix; "By default, Python versions managed by uv are stored in a `python/` subdirectory of the persistent data directory, e.g., `~/.local/share/uv/python`", overridden by `UV_PYTHON_INSTALL_DIR`; tools live in `tools/` under the same data dir, overridden by `UV_TOOL_DIR`
- https://docs.astral.sh/uv/concepts/cache/ — cache directory precedence: a temporary dir under `--no-cache`, then "the specific cache directory specified via `--cache-dir`, `UV_CACHE_DIR`, or `tool.uv.cache-dir`", then "`$XDG_CACHE_HOME/uv` or `$HOME/.cache/uv` on Unix and `%LOCALAPPDATA%\uv\cache` on Windows"
- Reproduction 2026-09-17 (uv 0.11.5, macOS arm64): with `HOME` set to a scratch directory, `uv cache dir` and `uv python dir` both printed paths under the scratch directory, and `uv python list --only-installed` no longer listed the managed `cpython-3.14.4` and `cpython-3.12.13` builds — only Homebrew and python.org interpreters remained. Exporting `UV_CACHE_DIR` and `UV_PYTHON_INSTALL_DIR` with the pre-swap values made both commands print the original locations again. With `HOME` untouched, `XDG_CACHE_HOME=<dir>` moved `uv cache dir` to `<dir>/uv` and `XDG_DATA_HOME=<dir>` moved `uv python dir` / `uv tool dir` to `<dir>/uv/python` / `<dir>/uv/tools`
- Reported field measurement 2026-09-17 (bats suite with `HOME` relocated, `uv run --offline`; from the originating session, not independently reproduced — it depends on that project's cache contents): with `UV_CACHE_DIR` alone, one dependency resolved and another failed with "not found in the cache"; after adding `UV_PYTHON_INSTALL_DIR` uv selected its managed CPython 3.14.4 and the resolve succeeded — five stdio-handshake cases moved from `skip` to `ok`
