---
id: infrastructure-agent-orchestration-session-completion-gates
domain: infrastructure
category: agent-orchestration
applies_to: [claude-code, general]
confidence: verified
sources:
  - https://code.claude.com/docs/en/hooks
last_verified: 2026-08-05
related: [infrastructure-agent-orchestration-pane-delivery-confirmation, infrastructure-agent-orchestration-worktree-isolated-workers, platforms-processes-tool-diagnostics-without-a-failing-exit-code]
---

# A Gate That Blocks a Worker Session from Ending Mid-Workflow

## When this applies

You are writing a completion gate — a `Stop`/`SubagentStop` hook or equivalent —
that refuses to let an orchestrated worker session end while its recorded phase
says the work is unfinished. Also when such a gate fires on a worker that did
exactly what its own prompt told it to do.

## Do this

1. **Enumerate every phase at which the protocol itself tells a worker to
   stop**, and put all of them in the gate's terminal set — not only the phases
   that mean "finished". Read the session prompt and the phase vocabulary side
   by side and classify each phase:

| Phase kind | Example | Gate treats it as |
|------------|---------|-------------------|
| Completed | `done`, `merged`, `failed` | terminal — allow stop |
| Instructed pause awaiting an external actor | `plan_ready` awaiting approval, `impl_done` awaiting review | terminal — allow stop |
| Unknown or unset | `""`, a phase name the gate does not recognize | terminal — allow stop, and log the unrecognized value |
| Work in progress the worker abandoned | `implementing`, `planning` | blocking — emit the instruction and block |

2. **Derive the set from the prompt that the workers actually receive**, and
   re-derive it whenever that prompt or the phase vocabulary changes. The two
   are one contract; a phase added to the status script without a matching gate
   entry becomes a stall.
3. **Make the gate self-limiting via the harness's re-entry flag.** In Claude
   Code, exit 0 immediately when `stop_hook_active` is true, before any other
   logic — the flag marks a session already continuing because of this hook, and
   without the early return the gate can block indefinitely. Claude Code
   overrides a Stop hook after it blocks eight consecutive times.
4. **No-op outside the managed workspace.** Locate the orchestration state by
   walking up from the session's `cwd`; when it is absent, exit 0. A gate that
   assumes it is managed fires in every unrelated session on the machine.
5. **Say what to do, not that something is wrong.** The block message names the
   phase, the next action, and the exact command that records completion — a
   blocked session's only input is that text.

## Edge cases

| Case | Then |
|------|------|
| A worker legitimately stops at an approval point but its status was never updated | The gate is right to block; make the status update the last step of the instructed pause so "stopped where told" and "recorded as paused" cannot diverge |
| The gate's state file is unreadable or its parser is missing | Exit 0 and log — a gate that blocks on its own malfunction traps every session |
| Several workers share one status directory | Match the entry by the session's resolved physical `cwd`; on macOS resolve `/var`→`/private/var` and symlinks on both sides before comparing |
| A phase means "waiting on another worker" | Terminal — the worker cannot progress it; the orchestrator's wait loop owns that transition |
| The worker cannot reach a terminal phase because the task is genuinely blocked | Provide a `failed` transition it may record itself; without one, the only escapes are fabricated completion or an eight-block override |

## Instead of

| If you are about to | Do this instead | Why |
|---------------------|-----------------|-----|
| List only "success" phases as terminal | Add every phase at which the protocol instructs a stop, including mid-workflow handoffs | The gate otherwise fights the prompts the system issues, pushing the worker to fabricate completion or to do work it was told to hold |
| Treat an unrecognized phase value as unfinished | Treat it as terminal and log the value | A typo or a newly added phase would otherwise trap sessions until someone reads the hook |
| Rely on the block message alone to stop a loop | Return early on the harness's re-entry flag first | The message does not bound repetition; the flag is what makes the gate fire once |

## Sources

- https://code.claude.com/docs/en/hooks — `Stop`/`SubagentStop` input includes `stop_hook_active`; hooks check it and exit early to allow the stop. Claude Code overrides a Stop hook after it blocks eight times in a row without progress (cap adjustable via `CLAUDE_CODE_STOP_HOOK_BLOCK_CAP`)
- Field reproduction 2026-08-05, dev-loop repo at `95cf947`: `hooks/loop-gate.sh:55` lists `done|approved|merged|failed|""` as terminal, while `skills/orchestrate/templates/session-prompt.md:20` instructs a plan-phase worker to record `plan_ready` and "wait for an approval message. Do NOT write implementation code yet." A worker that followed its prompt exactly was blocked; the `stop_hook_active` early return at line 30 is what kept the block from repeating
