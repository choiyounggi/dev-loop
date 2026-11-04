---
id: infrastructure-ci-cd-tool-restriction-for-a-ci-agent-runner
domain: infrastructure
category: ci-cd
applies_to: [github-actions, claude-code]
confidence: verified
sources:
  - https://code.claude.com/docs/en/tools-reference
  - https://code.claude.com/docs/en/agent-sdk/permissions
  - https://code.claude.com/docs/en/permissions
  - https://code.claude.com/docs/en/sub-agents
  - https://code.claude.com/docs/en/headless
last_verified: 2026-11-04
related: [infrastructure-ci-cd-secret-needing-gate-on-fork-prs, infrastructure-ci-cd-review-bot-adopted-as-a-blocking-gate, platforms-tools-deny-rules-under-bypassed-permissions, infrastructure-ci-cd-changed-files-only-gates, testing-quality-tests-that-cannot-fail]
---

# Limiting the Tools of an Agent That Runs a CI Job

## When this applies

A CI job runs Claude Code headless — through `anthropics/claude-code-action`
(`claude_args`) or `claude -p` — as a review, gate, or fixer. You limit what the
agent may do by passing `--allowedTools`. The job must finish inside one
process: a sub-agent or background task still running when the run's result is
read counts as lost work. Also applies when such a run passes having examined
nothing (an empty "files examined" list, a verdict with no findings) and the
log shows `Agent` calls.

## Do this

1. **Read `--allowedTools` as "pre-approved", not as "the only tools".** It adds
   allow rules so the listed calls skip the permission prompt. Every tool not on
   the list stays available. A call that would prompt falls through to the
   permission mode. A tool that never prompts runs whether or not it is listed.
2. **Look up which tools need no permission.** The Claude Code tools reference
   has a "Permission required" column. `Agent` is **No**, and so are `Read`,
   `Glob`, `Grep`, `TaskCreate`/`TaskList`/`TaskStop` and the `Cron*` tools. An
   allow-list never limits these.
3. **Remove a tool the job must not use with a bare name in
   `--disallowedTools`.** For a runner that must not delegate:
   `--disallowedTools "Agent"`. A bare name takes the tool out of Claude's
   context. A scoped rule (`Agent(Explore)`) only blocks matching calls and
   leaves the tool visible. Another option is `--tools "<list>"`, which leaves
   only the named built-in tools in the session.
4. **Pin the whole argument list in a test.** Compare the full `claude_args`
   (or argv) your workflow builds against the expected list, so a later edit
   that drops `--disallowedTools "Agent"` turns the test red. Build the expected
   list the way the runner parses the input (for example, drop the comment lines
   your multi-line input allows). Watch the test fail once with the flag removed
   ([testing-quality-tests-that-cannot-fail]).
5. **Make "examined nothing" a failing result.** Have the gate's structured
   output report what it read (files, item count). Fail the job when that is
   empty for a non-empty diff, the same way a missing verdict fails closed
   ([infrastructure-ci-cd-secret-needing-gate-on-fork-prs]).

## Edge cases

| Case | Then |
|------|------|
| The job is meant to delegate (a fan-out review) | Keep `Agent`. Make the run wait for its sub-agents (the headless docs keep the run open for background sub-agents; check your CLI version) and read the **last** `result` message, not the first |
| A named agent carries `disallowedTools` and you rely on it reaching the sub-agents it spawns | Set the limit where it is read: a sub-agent's tools come from its own definition (`tools`/`disallowedTools`). Remove `Agent` from the parent, or set limits on each sub-agent definition |
| The job runs with `bypassPermissions` | Allow rules do nothing in that mode, but deny rules and bare-name removals still apply. Use `--disallowedTools` for the boundary ([platforms-tools-deny-rules-under-bypassed-permissions]) |
| Only some sub-agent types must be blocked | Use the scoped form `--disallowedTools "Agent(Explore)"`. It blocks those calls and leaves the others |

## Instead of

| If you are about to | Do this instead | Why |
|---------------------|-----------------|-----|
| Write `--allowedTools "Read,Grep,Bash(git diff:*)"` and treat it as the runner's whole tool set | Add `--disallowedTools "Agent"` (or `--tools "<list>"`) for the tools it must not have | `--allowedTools` only skips prompts. `Agent` needs no permission, so it stays available |
| Tell the agent in its prompt not to use sub-agents | Remove the tool with `--disallowedTools` | A rule written only in the prompt is a request. Removing the tool is enforced by the CLI |
| Accept a green gate whose output lists no examined files | Fail the job on an empty examined set | The run reported success, but the delegated work never came back |

## Sources

- https://code.claude.com/docs/en/tools-reference — built-in tools table, "Permission required" column: `Agent` "No"; tool names there are the strings used in permission rules and `--allowedTools`/`--disallowedTools` (searched 2026-11-04)
- https://code.claude.com/docs/en/agent-sdk/permissions — `allowed_tools` adds allow rules. Any tool not on the list is still available to Claude, and a call to it that needs approval falls through to the permission mode. A call that needs no approval in default mode runs whether or not you list it. A bare name in `disallowed_tools` hides the tool entirely (searched 2026-11-04)
- https://code.claude.com/docs/en/permissions — a bare name such as `"Bash"` removes the tool from Claude's context; a scoped rule denies matching calls in every permission mode, including `bypassPermissions`; "To leave a tool out, use --tools instead of a deny rule" (searched 2026-11-04)
- https://code.claude.com/docs/en/sub-agents — `claude --disallowedTools "Agent(Explore)"`; a sub-agent's tools come from its own `tools`/`disallowedTools` fields (searched 2026-11-04)
- https://code.claude.com/docs/en/headless — at exit, the run stays open for background sub-agents because their result is part of the final output (searched 2026-11-04)
- Field incident 2026-11-03 (a claude-code-action gate, PR #272 log): the runner was limited with `--allowedTools` only and started 7 background agents. The action read the first `result` message, so the run ended with an empty `examined.files` list and exit 3 before the sub-agents returned. Adding `--disallowedTools "Agent"` with an argument-list test (comment lines dropped before comparing) went red then green. The first-`result` cut-off is from this log only, not from claude-code-action docs
