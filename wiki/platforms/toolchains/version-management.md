---
id: platforms-toolchains-version-management
domain: platforms
category: toolchains
applies_to: [node, python, general]
confidence: verified
sources:
  - https://github.com/nvm-sh/nvm#nvmrc
  - https://docs.astral.sh/uv/concepts/python-versions/
  - https://mise.jdx.dev/configuration.html
  - https://docs.npmjs.com/cli/v11/configuring-npm/package-json
last_verified: 2026-07-10
related: [platforms-processes-background-services, platforms-shells-portable-shell-scripts]
---

# Pinning Tool Versions So Every Machine Runs the Same Toolchain

## When this applies

"Works on my machine" traced to tool-version drift; a project needs a specific
language/tool version; onboarding a new machine reproducibly; CI builds behave
differently from local builds.

## Do this

1. Pin per-project versions in a committed file the version manager auto-reads:

| Ecosystem | Pin with |
|-----------|----------|
| Node | `.nvmrc` (nvm) or `.tool-versions`/`mise.toml` (asdf/mise), plus `"engines"` in package.json and a committed lockfile |
| Python | `.python-version` (uv/pyenv) plus locked dependencies (uv.lock / poetry.lock / pip-tools output) |
| Project spanning several tools (node + python + terraform…) | One `.tool-versions` (asdf) or `mise.toml` (mise) listing all of them |
| System CLIs (jq, gh, shellcheck) | Committed Brewfile / package list with versions, installed by one command — an executable bundle, not README prose |

2. Activate the manager per-directory via its shell hook (mise/asdf activation,
   nvm auto-use hook) so `cd` into the project selects the pinned version with no
   manual switching step to forget.
3. CI reads the same pin file: point the workflow at it (e.g. actions/setup-node
   `node-version-file: .nvmrc`). One source — a version restated inside the
   workflow file is a second source that will drift.
4. Non-interactive shells (scripts, cron, CI `sh` steps, git hooks, service units)
   load no rc files, so version-manager shims and lazy-load functions are absent
   there. In those contexts call the real binary by absolute path
   (`~/.nvm/versions/node/v20.x/bin/node`) or initialize the manager explicitly at
   the top of the script.
5. Lockfiles are the dependency half of reproducibility: commit them and install
   from them (`npm ci`, `uv sync --frozen`). Vetting what the lockfile pulls in is
   a security concern — see wiki/security/ (dependency trust).

## Edge cases

| Case | Then |
|------|------|
| `"engines"` in package.json has no effect | npm only warns unless the `engine-strict` config is set — add `engine-strict=true` to the project `.npmrc` to make mismatches fail |
| Docker build needs the pinned version | The base image tag is the pin (`node:20.11-alpine`); a version manager does not belong inside an image |
| Two pin sources disagree (`.nvmrc` says 20, `engines` says 18) | Declare the file your manager and CI both read as canonical, fix the other to match, and add a CI check that compares them |
| Hotfix on a machine without the version manager | Install the pinned version directly for the fix — change the machine to match the pin, never the pin to match the machine |
| Pinned version is missing on a machine | Run the manager's install (`nvm install`, `mise install`) so the pinned version is used — falling back to whatever `node` is on PATH reintroduces the drift |

## Instead of

| If you are about to | Do this instead | Why |
|---------------------|-----------------|-----|
| Write "install Node 20" in the README | Commit `.nvmrc` / `.tool-versions` that the tooling enforces | Prose is not executed; enforced files stop drift at `cd`/CI time |
| Restate the version inside the CI workflow | Make the workflow read the pin file (`node-version-file`) | Two declarations of one version always diverge eventually |
| Call `node`/`python` bare in cron, hooks, or service units | Absolute path to the managed binary, or explicit manager init in the script | Shims live in rc files that non-interactive shells never load |

## Sources

- https://github.com/nvm-sh/nvm#nvmrc — `.nvmrc` per-project Node pin
- https://docs.astral.sh/uv/concepts/python-versions/ — `.python-version` discovery and `uv python pin`
- https://mise.jdx.dev/configuration.html — per-directory config resolution (walks up the tree)
- https://docs.npmjs.com/cli/v11/configuring-npm/package-json — `engines` field and engine-strict behavior
