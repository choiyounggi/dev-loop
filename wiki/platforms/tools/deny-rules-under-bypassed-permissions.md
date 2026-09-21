---
id: platforms-tools-deny-rules-under-bypassed-permissions
domain: platforms
category: tools
applies_to: [claude-code, agent-harness]
confidence: verified
sources:
  - https://code.claude.com/docs/en/permission-modes
  - https://code.claude.com/docs/en/permissions
last_verified: 2026-09-03
related: [platforms-tools-agent-permission-classifier-denials, infrastructure-agent-orchestration-worktree-isolated-workers, infrastructure-agent-orchestration-control-signals-vs-primary-artifacts, backend-common-llm-binding-instructions-for-agents, testing-quality-checks-that-cannot-pass]
---

# Blocking One Command Class for a Worker That Runs With Permissions Bypassed

## When this applies

You are launching Claude Code worker sessions in `bypassPermissions` mode
(`--dangerously-skip-permissions`, `--permission-mode bypassPermissions`) and one
command class must stay off-limits mechanically — `git stash` against a stash
stack shared across worktrees, `git push`, `rm -rf` — because a sentence in the
prompt or CLAUDE.md is the only thing currently forbidding it. Also when a
`permissions.allow` rule you added for a bypass-mode worker appears to do nothing.

## Do this

1. **Write the boundary as a `permissions.deny` rule in the worktree's
   `.claude/settings.local.json`**, not as prose:

```json
{ "permissions": { "deny": ["Bash(git stash:*)", "Bash(git push:*)"] } }
```

   Deny rules block in every mode, including `bypassPermissions`; allow rules
   have no effect in that mode. A deny at any settings level cannot be undone by
   another level or by `--allowedTools`.

2. **Choose the file by who must be unable to relax the rule:**

| Boundary | Put the deny in |
|----------|-----------------|
| One run's workers on a machine you control | the worktree's `.claude/settings.local.json` (per checkout, gitignored) |
| Every clone of the repo | `.claude/settings.json` (committed) |
| Every session of this user, any repo | `~/.claude/settings.json` |
| Must hold even if the agent edits project or user settings | managed settings — the docs' example is a managed deny that `--allowedTools` cannot override |

3. **Write the pattern per subcommand — compound commands are split before
   matching.** The harness splits on `&&`, `||`, `;`, `|`, `|&`, `&`, and
   newlines and matches each piece on its own, so `Bash(git stash:*)` also
   catches `cd x && git stash`; conversely an allow must match every piece.

4. **Count on the documented wrapper set being stripped, and on nothing else.**
   Before matching, a leading `timeout`, `time`, `nice`, `nohup`, `stdbuf`, the
   builtins `command`/`builtin`, zsh `noglob`, and a leading `VAR=value`
   assignment of known-safe variables are removed. `env cmd`, `sh -c 'cmd'`,
   `xargs cmd`, and `bash script.sh` are not — add a deny entry for each wrapper
   shape the boundary must hold against (`Bash(sh -c:*)`), or record that those
   shapes stay covered only by the prose rule.

5. **Probe the rule from inside one worker before fanning out.** Launch a
   session in the intended mode and have it run the forbidden command in its
   plainest form and in a compound form; require the denial for both. A rule
   read from the docs has not been proven against the version installed
   ([testing-quality-checks-that-cannot-pass] — a control in each direction).

## Edge cases

| Case | Then |
|------|------|
| The worker must still run the read-only members of the family (`git stash list`) | Deny the mutating subcommands by prefix — `Bash(git stash push:*)`, `Bash(git stash pop:*)`, `Bash(git stash drop:*)`, `Bash(git stash clear:*)` — rather than the whole family |
| The effect is reachable through a non-Bash tool (an MCP tool that runs git, a file write into `.git/`) | A `Bash(...)` rule covers only the Bash tool; deny that tool's name too, or add a PreToolUse hook that matches it ([infrastructure-agent-orchestration-worktree-isolated-workers]) |
| The worker adds its own `allow` entry to get past the boundary | It changes nothing — allow is inert in bypass mode and deny wins at every level; the worker's correct move is to report the denial ([infrastructure-agent-orchestration-control-signals-vs-primary-artifacts]) |
| The task genuinely needs the denied command | Edit the settings file from outside the worker and re-prompt it; a denial is not a cue to reach the same effect by another command |
| The rule must survive the session but no settings file is acceptable in the repo | `~/.claude/settings.json` at user scope; a boundary stated only in conversation is lost at compaction ([platforms-tools-agent-permission-classifier-denials]) |

## Instead of

| If you are about to | Do this instead | Why |
|---------------------|-----------------|-----|
| Forbid `git stash` in the worker prompt and rely on compliance | Add `Bash(git stash:*)` to `permissions.deny` in the worktree settings | Prose is advisory under pressure; a deny rule is enforced by the harness in every mode |
| Constrain a bypass-mode worker with a `permissions.allow` list | Use `deny` for the boundary | Allow rules have no effect in `bypassPermissions` |
| Assume `env FOO=1 git stash` is caught because `timeout git stash` is | Add the wrapper shape to the deny list | Only the documented wrappers and `VAR=value` prefixes are stripped; `env` is not on the list |

## Sources

- https://code.claude.com/docs/en/permission-modes — "Deny rules block in every mode, including `bypassPermissions`. … Allow rules have no effect in `bypassPermissions`"
- https://code.claude.com/docs/en/permissions — "If a tool is denied at any level, no other level can allow it. For example, a managed settings deny can't be overridden by `--allowedTools`"; deny rules from any scope are evaluated before allow rules; "The recognized command separators are `&&`, `||`, `;`, `|`, `|&`, `&`, and newlines. A rule must match each subcommand independently"; "The stripped wrappers are `timeout`, `time`, `nice`, `nohup`, and `stdbuf`, plus the shell builtins `command` and `builtin`, and zsh's `noglob`"; "also strips a leading assignment of certain known-safe environment variables"
- Field context 2026-09-02 (dev-loop orchestration, workers launched with permissions bypassed): the stash stack shared across worktrees was protected by a prose rule alone; the deny form above was adopted after the docs confirmed deny applies under bypass. The session's first draft listed `env` among the stripped wrappers — the docs' list does not include it, which is why step 4 names it
