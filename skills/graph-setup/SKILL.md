---
name: graph-setup
effort: medium
argument-hint: "[global | repo]"
description: Onboard a workspace of git repos onto the graphify code graph — detect or (with consent) install graphify, record the workspace roots in tools.json, build absent graphs with graphify update after one batch confirmation, and install graphify's post-commit/post-checkout hooks plus dev-loop's post-merge hook per repo. Use when asked to "set up the code graph", "onboard the workspace", "install graphify", "graph setup", or "/dev-loop:graph-setup".
---

# graph-setup — onboard a workspace onto the graphify code graph

Every install and every build in this skill runs only after the user said yes
to an explicit `AskUserQuestion`. Nothing here runs from a SessionStart hook —
`hooks/graph-nudge.sh` only reports; this skill is the only place that builds
or installs.

## Steps

### Step 1 — detect graphify

Run `command -v graphify`.

- **Found** → continue to Step 2.
- **Absent** → ask with `AskUserQuestion`:
  - Option 1: "Install with pipx (Recommended)" — runs the exact command
    `pipx install graphifyy` (the PyPI package name is `graphifyy`, not
    `graphify` — state this to the user).
  - Option 2: "Skip — stop here"

  On yes, run `pipx install graphifyy </dev/null > "$tmp" 2>&1` and show the
  tail of `$tmp`. On no, stop here — nothing else in this skill runs.

### Step 2 — configure the workspace

Run `sh ${CLAUDE_PLUGIN_ROOT}/scripts/resolve-tools.sh --role workspace`.

- Already has `roots`? Use them as-is.
- Unset (`{"kind":"default"}`)? Ask the user for the root directory path(s)
  and the scope, same choice as `/dev-loop:configure`:
  - **Global** (all projects): `~/.claude/dev-loop/tools.json`
  - **Per-repo** (committed, team-shared): `<repo>/.dev-loop/tools.json`

  Write the key into that file (create it as `{}` first if it does not
  exist yet):
  ```sh
  jq '. + {workspace: {roots: $r, depth: 2, exclude: ["node_modules","graphify-out"]}}'
  ```

### Step 3 — show status

Run, with the configured depth/exclude/roots:
```sh
sh ${CLAUDE_PLUGIN_ROOT}/scripts/graph-workspace.sh --status --depth <n> [--exclude <glob>]... -- <root>...
```
Print every returned line verbatim as a table: repo, freshness, hooks.

### Step 4 — build absent graphs

Collect every repo Step 3 reported `absent`. If there are none, skip to
Step 5. Otherwise, before asking, brief the user with this sentence
verbatim:

> graphify update is AST-only (no LLM) and preserves semantic nodes from an
> earlier full run while replacing only code nodes, so the result is not
> identical to a full /graphify build.

Then ask ONE batch `AskUserQuestion` listing every absent repo, with option 1
"Build all N absent graphs now (Recommended)" and an option to skip. On yes,
run `graphify update "<repo>" </dev/null > "$tmp" 2>&1` for each absent repo,
sequentially, and report each result. On no, leave those graphs absent and
continue to Step 5 (hooks still get installed).

### Step 5 — install hooks

For every repo in the workspace, in order:

1. `(cd "<repo>" && graphify hook install)` — installs graphify's own
   `post-commit`/`post-checkout` hooks.
2. `sh ${CLAUDE_PLUGIN_ROOT}/scripts/graph-hooks.sh install "<repo>"` —
   installs dev-loop's `post-merge` hook.

`graph-hooks.sh install` also adds `graphify-out/` to `.git/info/exclude` (graphify's own installer does not); a repo's `.gitignore` is never touched by either — do not edit it yourself either.

### Step 6 — verify

Re-run Step 3's `--status`. Every repo should now report `hooks: ok`.
Anything else (`partial`, `none`, or `cannot-evaluate <reason>`) is listed
with its exact status line, not summarized away.

## Guardrails

- Never run any part of this skill from a SessionStart hook — only an
  explicit `/dev-loop:graph-setup` invocation builds a graph or installs
  anything; `hooks/graph-nudge.sh` only reports.
- Never install (pipx, `graphify hook install`, `graph-hooks.sh install`, or
  `graphify update`) without a preceding `AskUserQuestion` "yes".
- Never edit a repo's `.gitignore` — installs use `.git/info/exclude`
  instead.
- Worktrees (a `.git` **file**, not a directory) are skipped by
  `graph-workspace.sh` by design; point a worker's `--graph` flag at the
  main checkout's `graphify-out/graph.json` instead.

## Pre-send check

- [ ] Did every install (pipx, `graphify hook install`, `graph-hooks.sh
      install`, `graphify update`) have an explicit `AskUserQuestion` "yes"
      first?
- [ ] Was the update-vs-full-build sentence shown before any graph was
      built?
- [ ] Is every repo in the workspace reported as `hooks: ok`, or explicitly
      listed with its non-ok status line?
