---
id: platforms-toolchains-native-addon-binary-missing-after-bun-install
domain: platforms
category: toolchains
applies_to: [node, general]
confidence: verified
sources:
  - https://bun.com/docs/pm/lifecycle
  - https://bun.com/docs/pm/cli/pm
  - https://bun.com/docs/guides/install/trusted
  - https://github.com/oven-sh/bun/blob/main/src/install/default-trusted-dependencies.txt
  - https://github.com/nodejs/node-gyp#installation
  - https://github.com/WiseLibs/better-sqlite3/blob/master/package.json
last_verified: 2026-09-28
related: [platforms-toolchains-version-management, platforms-toolchains-compiler-sysroot-on-macos, platforms-environment-path-resolution, security-dependencies-supply-chain, platforms-tools-plugin-mcp-server-registration]
---

# A Native Addon Has No `.node` Binary After `bun install`

## When this applies

A CLI, MCP stdio server, or app installed with `bun install` or `bun install -g`
dies at startup with `Could not locate the bindings file` (or another missing
`.node` error) for a native dependency such as better-sqlite3, sqlite3, sharp or a
tree-sitter grammar; the dependency's `build/Release/` holds `obj*` directories and
no `.node`; deciding between `bun pm trust`, `--trust`, and rebuilding by hand.

## Do this

1. **Read bun's own install notice before choosing a remedy.** bun reports a
   skipped script and a failed script differently, and only one of them is a
   trust problem:

| `bun install` printed | What happened | Do |
|-----------------------|---------------|----|
| `Blocked N postinstall. Run \`bun pm untrusted\` for details.` and exit 0 | The package is not on the allowlist, so its script never ran | `bun pm trust <name>` in the install root: it runs the blocked script now and appends the name to `trustedDependencies` |
| `error: install script from "<pkg>" exited with 1` and exit 1 | The script ran and failed; a partial build dir stays behind and no lockfile is written | Fix the build prerequisite (step 3), then re-run `bun install` |

2. **When the install output is gone**, run `bun pm untrusted` in the install
   root (`~/.bun/install/global` for a `-g` install):

| `bun pm untrusted` says | Then |
|-------------------------|------|
| Lists the package and its script | It was blocked: `bun pm trust <name>` |
| Does not list it and `bun pm default-trusted` contains it | Its script ran and produced no usable binary: step 3 |
| `error: Lockfile not found` | The install itself failed: re-run `bun install` and read its error |

3. **Rebuild under the runtime that will load the binary.** The launcher decides:
   a `#!/usr/bin/env node` or `#!/bin/sh` bin runs under the `node` on PATH, a
   `#!/usr/bin/env bun` bin under bun. In the dependency's directory run
   `npx prebuild-install` (downloads a prebuilt for that runtime's ABI; exits
   non-zero when none is published for it), then
   `npx node-gyp rebuild --release --python=<supported Python>`. node-gyp needs
   Xcode Command Line Tools on macOS and a supported Python (`--python`,
   `npm_config_python`, or `PYTHON`). Confirm with `ls build/Release/*.node`, then
   re-run the CLI itself.
4. **When you add `trustedDependencies` to a package.json, also list every
   default-allowlisted package you rely on** (`bun pm default-trusted` prints the
   list): the field replaces bun's default allowlist instead of extending it, and
   the default list applies only to packages installed from npm, never to
   `file:`, `link:`, `git:` or `github:` sources.

## Edge cases

| Case | Then |
|------|------|
| The package is on the default list but the project's `trustedDependencies` omits it | It is blocked from now on; add it to the field |
| Node was upgraded after the install (Homebrew major bump) | The compiled addon targets the old ABI; rebuild with step 3 under the new `node` |
| The CLI's bin is a `#!/bin/sh` script and you test it with `bun <bin>` | bun parses the shell script as JavaScript and reports `Syntax Error`; run the bin directly |
| `--ignore-scripts` is set (flag, `bunfig.toml`, `.npmrc`) | It skips the project's own scripts; dependency scripts are governed by the allowlist alone, so it does not explain a blocked dependency |
| The symptom is an MCP server that reports `CONNECTION_CLOSED` at connect | Run the server command by hand; the bindings error is on its stderr, which the client does not surface |

## Instead of

| If you are about to | Do this instead | Why |
|---------------------|-----------------|-----|
| Reinstall with `--trust` for a package already on `bun pm default-trusted` | Run `bun pm untrusted`, then step 3 | The script already ran; `--trust` re-runs the same failing compile and, by writing `trustedDependencies`, drops every other default-list package |
| Delete `node_modules` and reinstall to reset the failure | Read the install error and fix the prerequisite it names | The compile prerequisite is unchanged, so the same script fails again |
| Conclude from the missing `.node` that bun blocked the script | Distinguish blocked from failed with the notices in step 1 | A failed script also leaves no `.node`, but it leaves `obj` directories and an exit 1 |

## Sources

- https://bun.com/docs/pm/lifecycle — bun runs lifecycle scripts only for allowlisted packages; the default list applies to npm sources only; `--ignore-scripts`
- https://bun.com/docs/pm/cli/pm — `bun pm untrusted`, `bun pm trust`, `bun pm default-trusted`, `bun pm ls --trusted`; a set `trustedDependencies` replaces the default list
- https://bun.com/docs/guides/install/trusted — default allowlist note and the replace-not-extend rule
- https://github.com/oven-sh/bun/blob/main/src/install/default-trusted-dependencies.txt — better-sqlite3 and sqlite3 are on the default list
- https://github.com/nodejs/node-gyp#installation — Xcode CLT and supported Python requirements; `--python`, `npm_config_python`, `PYTHON`; `rebuild` = clean + configure + build
- https://github.com/WiseLibs/better-sqlite3/blob/master/package.json — install script `prebuild-install || node-gyp rebuild --release`
- Reproduction, bun 1.3.11, 2026-09-28: a trusted `file:` dependency whose install script exits 1 makes `bun install` exit 1 with `error: install script from "failing-dep" exited with 1`, leaves `build/Release/obj`, and writes no lockfile (`bun pm untrusted` then reports `Lockfile not found`); an unlisted dependency yields `Blocked 1 postinstall` with exit 0, and `bun pm trust` runs its script and writes `trustedDependencies`
- Field case, 2026-09-28: a globally bun-installed MCP server depending on better-sqlite3 12.8.0 launched under Node 26 with only `obj` directories in `build/Release`; better-sqlite3 was on the default list and absent from `bun pm untrusted`; `prebuild-install` had no binary for that ABI and `node-gyp rebuild --release --python=<3.11>` produced `better_sqlite3.node`, after which the server connected
