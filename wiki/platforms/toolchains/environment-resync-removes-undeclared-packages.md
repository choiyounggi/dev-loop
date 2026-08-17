---
id: platforms-toolchains-environment-resync-removes-undeclared-packages
domain: platforms
category: toolchains
applies_to: [python, uv, general]
confidence: verified
sources:
  - https://docs.astral.sh/uv/concepts/projects/sync/
  - https://docs.astral.sh/uv/concepts/projects/dependencies/
  - https://docs.astral.sh/uv/reference/cli/
  - https://peps.python.org/pep-0735/
last_verified: 2026-08-07
related: [platforms-toolchains-version-management, platforms-processes-background-services]
---

# A Dependency Command Resyncing the Whole Environment and Deleting Undeclared Packages

## When this applies

A tool that was working (pytest, ruff, a scratch library) is suddenly missing after
an *unrelated* dependency change, and test collection fails on imports that passed
minutes ago; you are about to add or drop a dependency while a long job, test run,
or experiment is in flight; you are deciding where dev-only tools get declared.

## Do this

1. Declare every package the project needs — dev-only tools included — in the
   manifest, not by ad-hoc install: `uv add --dev pytest`. PEP 735
   `[dependency-groups]` is the standard field, and uv syncs the `dev` group by
   default, so a declared tool is restored by the same resync that deletes an
   undeclared one.
2. Read the exactness of each command before running it, rather than assuming a
   manager's add/remove are mirror images. For uv (measured, 0.11.5):

| Command | Syncs the env | Packages absent from the lockfile |
|---------|---------------|-----------------------------------|
| `uv run` | yes, inexact by default | kept; `--exact` removes them |
| `uv add` | yes, no exactness flag exists | kept |
| `uv sync` | yes, exact by default | **removed**; `--inexact` keeps them |
| `uv remove` | yes, no exactness flag exists | **removed**, with no `--inexact` escape |

3. When the destructive command must run while a job is in flight, either wait for
   the job to exit, or re-lock without touching the environment
   (`uv remove <pkg> --no-sync`, or `--frozen` to skip re-locking too) and run
   `uv sync` once the job is done.
4. To repair an environment a resync stripped, run `uv sync` to restore the declared
   set, then re-declare what was ad-hoc (`uv add --dev <tool>`) instead of
   re-running `uv pip install`. For a single package that is present but broken,
   `uv sync --reinstall-package <name>`.
5. For a tool you invoke as a CLI and never import, install it outside the project
   environment with `uv tool install <pkg>`, so no project resync can reach it.

## Edge cases

| Case | Then |
|------|------|
| A process was already running when the resync stripped the package, and it keeps working | Its already-imported modules live in the interpreter's module cache, so the running job survives while any *new* import in that same process raises `ModuleNotFoundError` — the breakage surfaces whenever that import line is first reached, not at the moment of the resync |
| The failure looks like a code regression (22 tests fail to collect, nothing was edited) | Check the environment before the diff: list installed packages and compare against the manifest; a collection-time `ModuleNotFoundError` across unrelated test files is an environment symptom, not a source one |
| You need the dependency dropped now and cannot pause the job | `uv remove <pkg> --no-sync` — the manifest and lockfile update, the environment is left alone until you sync deliberately |
| The removed package is a transitive dependency of something still declared | The exact sync keeps it; only packages absent from the resolved lockfile are removed |
| Another manager (pip, poetry, npm) is in play | The same question applies but the answer differs per tool — `pip install` never prunes, `npm ci` deletes and rebuilds `node_modules` wholesale; check the command's own docs for whether it prunes before running it near live work |

## Instead of

| If you are about to | Do this instead | Why |
|---------------------|-----------------|-----|
| `uv pip install pytest` to get the suite running in a project env | `uv add --dev pytest` | An ad-hoc install is extraneous to the lockfile; the next exact sync deletes it, and the deletion is triggered by an unrelated command |
| Treat `uv add` and `uv remove` as symmetric and run either one mid-job | Run the exactness table above, and gate only the exact commands on the job finishing | Measured: `uv add` left an undeclared package in place, `uv remove` deleted it in the same environment |
| Re-run `uv pip install <tool>` each time the tool disappears | Declare it once in a dependency group | The `dev` group is synced by default, so the command that removed the ad-hoc copy is the one that restores the declared one |

## Sources

- https://docs.astral.sh/uv/concepts/projects/sync/ — "`uv sync` performs 'exact' syncing by default, which means it will remove any packages that are not present in the lockfile"; `--inexact` retains them; "`uv run` uses 'inexact' syncing by default"
- https://docs.astral.sh/uv/concepts/projects/dependencies/ — PEP 735 `[dependency-groups]`; "the `dev` group is synced by default"
- https://docs.astral.sh/uv/reference/cli/ — `uv add`: "The lockfile and project environment will be updated to reflect the added dependencies"; `--no-sync` on `uv remove`: "Avoid syncing the virtual environment after re-locking the project"
- https://peps.python.org/pep-0735/ — dependency groups as a standard manifest field
- Local reproduction 2026-08-07, uv 0.11.5 (aarch64-apple-darwin), throwaway project: with `iniconfig` installed via `uv pip install` (undeclared), `uv add typing-extensions` left it installed, while `uv remove packaging` deleted it — twice, and `uv remove packaging --no-sync` preserved it. A background process that had imported `iniconfig` before the resync kept running and still resolved the cached module, while a later `import tomli_w` in that same process raised `ModuleNotFoundError`. Flag presence confirmed with `uv {add,remove,sync,run} --help`: only `sync` exposes `--inexact` and only `run` exposes `--exact`.
