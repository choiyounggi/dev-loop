---
id: platforms-tools-hook-config-lookup-from-shell-cwd
domain: platforms
category: tools
applies_to: [claude-code, git]
confidence: verified
sources:
  - https://code.claude.com/docs/en/hooks
  - https://code.claude.com/docs/en/tools-reference
  - https://git-scm.com/docs/git-rev-parse
last_verified: 2026-10-07
related: [platforms-tools-deny-rules-under-bypassed-permissions, platforms-shells-command-text-inspected-before-execution, platforms-tools-harness-mediated-tool-results, infrastructure-agent-orchestration-worktree-isolated-workers]
---

# Per-Project Hook Policy Lost When the Shell Sits in a Nested Repository

## When this applies

- An agent session runs under a PreToolUse hook that finds its per-project
  policy file by searching upward from the shell's current directory, stopping
  at `git rev-parse --show-toplevel`. Example: a `.groundwork/guardrails.json` beside the
  project root.
- The agent `cd`s into a nested git repository inside the project that does not
  carry that policy file itself (a scratch clone under `.claude/tmp/` of another
  repo, a vendored repo, a test fixture repo). A command the project policy allows,
  such as cleanup with `rm -rf`, is then blocked or escalated by the stricter global rule.
- You are writing such a hook and choosing where its config search starts.

## Do this

1. **Keep the persistent shell directory at the project root.** Address the nested repo
   with per-command directory flags instead of a persistent `cd`: `git -C <path>`,
   `make -C <path>`, `npm --prefix <path>`, or a one-command subshell
   `(cd <path> && …)`. The hook runs before the command, in the shell directory
   the previous call left behind, so a subshell `cd` inside the command never
   moves the hook's starting point. A bare `cd <path> && cmd` does persist into
   the next call.
2. **For a launched worker, make the reset mechanical.** Set
   `CLAUDE_BASH_MAINTAIN_PROJECT_WORKING_DIR=1` in the worker's environment, and
   every Bash command then starts in the project directory.
3. **Issue cleanup from a call that starts at the root, with absolute paths.**
   If an earlier call left the shell inside the nested repo, first run a bare
   `cd <project root>` as its own call. Then run the cleanup.
4. **When a hook blocks a command it allowed earlier in the same session, check
   the directory first.** Print `pwd` and `git rev-parse --show-toplevel`. If that
   toplevel is not the project root and holds no policy file between it and `pwd`,
   the project policy was never loaded. The fix is the directory, not a policy change.

| Hook-author decision | Behavior to plan for |
|----------------------|----------------------|
| Search from `$PWD`, or from the input JSON's `cwd` | Both follow the agent's `cd`. The search changes whenever the agent moves |
| Stop the search at `git rev-parse --show-toplevel` | Inside a nested clone the toplevel is that clone, so the search never reaches the outer project's config |
| Start from `$CLAUDE_PROJECT_DIR` | The docs define it as "the project root where the session started". It stays put when the session enters a worktree; `cwd` is the field that follows |

## Edge cases

| Case | Then |
|------|------|
| The nested repo is a linked worktree or clone of the same project and the policy file is tracked | The checkout carries its own copy, the search finds it, and the policy holds. The trap needs a nested repo without the file (another repo, or the file untracked or ignored) |
| The nested repo is a submodule | `--show-toplevel` returns the submodule root. Not reproduced here; `--show-superproject-working-tree` names the outer root if a hook needs it |
| The directory is not inside any git repo (a plain scratch dir) | guardrails 1.2.2 checks only the literal `$PWD` there, so the project config is also missing. Use the same root-shell fix |
| `cd` into a directory outside the project and its added directories | Claude Code resets the shell to the project directory and appends `Shell cwd was reset to <dir>`. A nested clone under `.claude/tmp/` is inside the project, so the `cd` persists. That is exactly where this trap fires |
| You want the nested repo to carry its own policy | Commit a config file at the nested repo's root. The search then finds it before reaching the toplevel |

## Instead of

| If you are about to | Do this instead | Why |
|---------------------|-----------------|-----|
| `cd` into a nested clone for several steps, then clean up from there | Stay at the root and use `git -C` or a one-command subshell; clean up from the root | The policy search stops at the nested toplevel, so the global rule decides |
| Loosen the global rule because it fired on an allowed command | Move the shell back to the project root and rerun | The project rule already allows the command, but it was never loaded |

## Sources

- https://code.claude.com/docs/en/hooks — the common input field `cwd` is the "Current
  working directory when the hook is invoked". `cwd` "follows Claude":
  it is "the new directory after Claude runs `cd`". `${CLAUDE_PROJECT_DIR}` is "the
  project root where the session started", and stays put when Claude enters a
  worktree.
- https://code.claude.com/docs/en/tools-reference (Bash tool):
  - A `cd` "carries over to later Bash commands as long as it stays inside the
    project directory or an additional working directory".
  - "If `cd` lands outside those directories, Claude Code resets to the project
    directory and appends `Shell cwd was reset to <dir>`".
  - "set `CLAUDE_BASH_MAINTAIN_PROJECT_WORKING_DIR=1`" so every Bash command starts
    in the project directory.
  - "Subagent sessions never carry over working directory changes".
- https://git-scm.com/docs/git-rev-parse — `--show-toplevel`: "Show the (by
  default, absolute) path of the top-level directory of the working tree".
  `--show-superproject-working-tree` gives the superproject root of a submodule.
- Hook source, groundwork guardrails 1.2.2 `hooks/bash-guard.sh`, function `find_repo_cfg`
  (read 2026-10-07): it starts at `$PWD`, sets `top=$(git rev-parse --show-toplevel)`,
  walks up to `top` looking for `.groundwork/guardrails.json`, then falls back to
  `~/.claude/groundwork/guardrails.json`.
- Local reproduction 2026-10-07: an outer repo held `.groundwork/guardrails.json`, with an inner `git init`
  at `outer/.claude/tmp/inner`.
  - `git rev-parse --show-toplevel` from `inner/sub` printed `…/outer/.claude/tmp/inner`.
  - From `outer/.claude/tmp` it printed `…/outer`.
  - A linked worktree added at `outer/.claude/tmp/wt` printed `…/outer/.claude/tmp/wt`.
- Field report, queued 2026-10-06 (orchestrated worker):
  - The same kind of `rm -rf` was allowed from the worktree root.
  - It was escalated under rule `rm_rf`, pausing the worker, when the cwd was
    `<worktree>/.claude/tmp/<repo>/.claude/tmp/t1-clean`, inside a nested git
    clone `<repo>`.
