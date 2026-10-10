---
id: platforms-tools-plugin-dependencies-after-an-update
domain: platforms
category: tools
applies_to: [claude-code, node]
confidence: verified
sources:
  - https://code.claude.com/docs/en/plugins/loading
  - https://code.claude.com/docs/en/plugins/components
  - https://code.claude.com/docs/en/plugins/manifest-reference
  - https://code.claude.com/docs/en/plugins/troubleshooting
  - https://nodejs.org/api/esm.html
last_verified: 2026-10-10
related: [platforms-tools-version-keyed-artifact-cache, platforms-tools-plugin-mcp-server-registration, platforms-toolchains-native-addon-binary-missing-after-bun-install]
---

# A Plugin's npm Dependencies Missing After a Plugin Update

## When this applies

A Claude Code marketplace plugin whose hooks, MCP server, or skill-run scripts
import npm packages fails with `ERR_MODULE_NOT_FOUND` / `Cannot find package`
right after an update while the previous version worked. Also when you author
such a plugin and decide how its dependencies reach users' machines.

## Do this

1. **Check the version directory that is actually installed.** Read the
   plugin's `installPath` from `~/.claude/plugins/installed_plugins.json` and
   look for `node_modules` there. Each version is copied into its own
   `cache/<marketplace>/<plugin>/<version>/`, and the previous directories stay
   on disk with an `.orphaned_at` marker for 14 days — a search across the whole
   cache finds their `node_modules` and hides the gap.
2. **Check that the plugin root ships both `package.json` and a supported
   lockfile.** Claude Code installs Node.js dependencies into every new version
   directory (install, update, first session on a new machine) only when the
   root holds `package.json` plus `package-lock.json` or `npm-shrinkwrap.json`
   (`lockfileVersion` 2 or 3) or a text `bun.lock`. When the lockfile is
   gitignored, no install runs and `claude plugin list` shows no dependency
   note either — that note requires a lockfile.
3. **As the author, commit an npm lockfile and keep the dependencies inside the
   built-in install's limits**: registry packages pinned in the lockfile,
   `https` download links, no npm `overrides`, nothing that needs an install
   script (the install runs with `--ignore-scripts`), finished within 60 s.
   Then install the new version once and confirm its directory holds
   `node_modules`.
4. **For a dependency the built-in install cannot provide, install it from a
   `SessionStart` hook into `${CLAUDE_PLUGIN_DATA}`**, which is kept across
   updates. The documented hook diffs `package.json` against the copy in the
   data directory and re-runs `npm install` only when it changed. Reach the
   result with `NODE_PATH=${CLAUDE_PLUGIN_DATA}/node_modules` from CommonJS
   `require`; for an ESM `import`, link `${CLAUDE_PLUGIN_ROOT}/node_modules` to
   `${CLAUDE_PLUGIN_DATA}/node_modules`, because ESM resolution ignores
   `NODE_PATH`.

| What the plugin root holds | After an update | Do |
|----------------------------|-----------------|----|
| `package.json` + npm lockfile (v2/v3) or text `bun.lock`, registry dependencies | `node_modules` is installed into the new version directory | Nothing more; read `claude plugin list` if a script still fails |
| `package.json` with the lockfile gitignored or absent | No install, no note; imports fail with `ERR_MODULE_NOT_FOUND` | Commit the lockfile (step 3) |
| `yarn.lock`, `pnpm-lock.yaml`, or `bun.lockb` | Install skipped; the note names the lockfile | Replace it with an npm lockfile, or use the step-4 hook |
| Git or linked dependencies, packages that build in install scripts, Python dependencies | The built-in install cannot provide them | Step-4 hook into `${CLAUDE_PLUGIN_DATA}` |

## Edge cases

| Case | Then |
|------|------|
| `claude plugin list` shows `The packages it lists are not installed` | The install can run but did not finish (failed or timed out) — retry with `claude plugin update <name>@<marketplace>`; with `CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC` set the retry is skipped |
| It shows `were not installed, because ...` | The install cannot run for this plugin (lockfile type, package manager missing on this machine) — the author replaces the lockfile, or you install the package manager and update again |
| A relative-path plugin in a marketplace added from a local path | It loads in place and Claude Code installs nothing into the source directory — install there yourself or with the step-4 hook |
| A session started before the update still works | It keeps the previous version's path until `/reload-plugins` or a restart, so a working session proves nothing about the new version directory |
| A skill tells Claude to run the plugin's script through the Bash tool | Write `${CLAUDE_PLUGIN_ROOT}` / `${CLAUDE_PLUGIN_DATA}` in the skill body, where Claude Code substitutes them on load — the Bash tool's environment does not carry these variables |

## Instead of

| If you are about to | Do this instead | Why |
|---------------------|-----------------|-----|
| Run `npm install` inside the cached version directory to clear the error | Commit the lockfile in the plugin source (step 3) | The fix lasts until the next update creates a fresh directory, and the `package-lock.json` npm writes there makes that copy look as if it shipped one |
| Search `~/.claude/plugins/cache/<marketplace>/<plugin>/` for `node_modules` to confirm the install | Check the `installPath` that `installed_plugins.json` records | Orphaned older versions keep their `node_modules` for 14 days |
| Set `NODE_PATH` for an `.mjs` script that imports from `${CLAUDE_PLUGIN_DATA}` | Link `node_modules` beside the script, or ship the lockfile | ESM `import` never reads `NODE_PATH` and still fails with `ERR_MODULE_NOT_FOUND` |

## Sources

- https://code.claude.com/docs/en/plugins/loading — marketplace plugins are copied into `cache/<marketplace>/<plugin>/<version>/` and `${CLAUDE_PLUGIN_ROOT}` points there; "Keep a plugin's durable files in `${CLAUDE_PLUGIN_DATA}` instead"; "Claude Code installs the dependencies into the copied version directory each time it creates one"; "The install runs only when the plugin's root directory contains both a `package.json` and a supported lockfile" (`bun.lock`; `npm-shrinkwrap.json` or `package-lock.json` with `lockfileVersion` 2 or 3); limits: registry packages only, `https`, frozen resolution, `--ignore-scripts`, no `overrides`, "60-second timeout"; the note appears "on an enabled plugin whose cached copy has a lockfile and a `package.json` that lists runtime dependencies, but no `node_modules` directory"; "When the automatic install can't provide a dependency, install it from a hook into the persistent data directory"; the previous version gets an `.orphaned_at` marker and is removed "in a background cleanup 14 days later"; in-place relative-path plugins get no install
- https://code.claude.com/docs/en/plugins/components — the `SessionStart` hook that runs `diff -q` on `package.json` and `npm install` in `${CLAUDE_PLUGIN_DATA}`; "An MCP server can then set `NODE_PATH` to `${CLAUDE_PLUGIN_DATA}/node_modules` in its `env`"
- https://code.claude.com/docs/en/plugins/manifest-reference — `${CLAUDE_PLUGIN_DATA}` resolves to `~/.claude/plugins/data/<id>/`, "kept across plugin updates", for "Installed dependencies such as `node_modules`"; "The variables aren't present in the environment of commands Claude runs through the Bash tool"; skill content gets them substituted inline
- https://code.claude.com/docs/en/plugins/troubleshooting — `are not installed`: "the install can run for this plugin but didn't finish" — retry with `claude plugin update`; `were not installed, because ...`: "the install can't run for this plugin"
- https://nodejs.org/api/esm.html — "`NODE_PATH` is not part of resolving `import` specifiers. Please use symlinks if this behavior is desired."
- Local observation 2026-10-10 (Claude Code 2.1.295, plugin auto-velog): `installPath` → `…/auto-velog/0.2.2`; 0.2.0 and 0.2.1 carry `.orphaned_at` and hold `node_modules/playwright` plus a `package-lock.json` written about 38 h and 9 min after their other files (a hand-run `npm install`); 0.2.2 holds `package.json` only; the upstream repository has never committed `package-lock.json` and its `.gitignore` has listed it since the first commit; `claude plugin list` shows 0.2.2 as `✔ enabled` with no dependency note; `import.meta.resolve('playwright')` from `0.2.2/scripts` throws `ERR_MODULE_NOT_FOUND` while `0.2.1/scripts` resolves to its own `node_modules`
- Local reproduction 2026-10-10 (Node 26.7.0): an `.mjs` importing a package present only under a `NODE_PATH` directory fails with `ERR_MODULE_NOT_FOUND`; the same package loads through CommonJS `require` with `NODE_PATH`, and through `import` after symlinking `node_modules` beside the script
