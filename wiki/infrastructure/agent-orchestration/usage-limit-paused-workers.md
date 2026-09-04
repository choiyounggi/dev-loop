---
id: infrastructure-agent-orchestration-usage-limit-paused-workers
domain: infrastructure
category: agent-orchestration
applies_to: [claude-code, tmux, orca, general]
confidence: verified
sources:
  - https://code.claude.com/docs/en/errors
  - https://code.claude.com/docs/en/costs
  - https://github.com/anthropics/claude-code/issues/5977
  - https://code.claude.com/docs/en/interactive-mode#wait-for-a-usage-limit-to-reset
last_verified: 2026-08-29
related: [infrastructure-agent-orchestration-unattended-worker-questions, infrastructure-agent-orchestration-control-signals-vs-primary-artifacts, infrastructure-agent-orchestration-pane-delivery-confirmation, infrastructure-agent-orchestration-dispatching-after-a-completion-report, infrastructure-agent-orchestration-shared-run-state, infrastructure-agent-orchestration-login-expiry-during-unattended-turns]
---

# Worker Sessions Paused by a Provider Usage Limit

## When this applies

Several agent workers billed to one account go quiet within minutes of each other,
their diffs stop, and every liveness check still passes. Also when one worker's
terminal tail carries a `You've hit your … limit · resets …` notice, or when you
are deciding whether to restart, replace, or wait on a worker that reports no
task-level error.

## Do this

1. **Read the terminal tail for the limit marker before classifying the stall**,
   because which limit was hit decides whether waiting is the only move:

| Tail shows | Do |
|------------|----|
| `You've hit your session limit · resets <time>` | Wait until the stated time — the window is shared across all models, so switching models does not restore access |
| `You've hit your weekly limit · resets <day time>` | Wait until the stated day and time; the same model-independence applies |
| `You've hit your Opus limit · resets <time>` | Send `/model` and switch to another model — this limit scopes to Opus only, and the worker keeps working now |
| No limit marker | This is a different stall — classify it with [infrastructure-agent-orchestration-unattended-worker-questions] |

2. **Read a synchronized multi-worker stop as one shared allowance, not N
   independent failures.** The allowance is per seat and shared across Claude Code,
   Claude chat, and Cowork on a rolling five-hour window plus a weekly window, so
   parallel workers draw one pool and reach the wall together — heavy activity
   from any of them counts against the same allowance the others are drawing
   down.
3. **Treat the paused worker as intact and keep its worktree and branch.** Claude
   Code blocks further requests until the reset time; the process, terminal, and
   working tree are unchanged, which is why the substrate liveness checks in
   [infrastructure-agent-orchestration-control-signals-vs-primary-artifacts] all
   report alive.
4. **Send the resume prompt after the stated reset time, not before.** A prompt
   delivered inside the blocked window is answered by the same limit message and
   buys nothing.
5. **Make the resume prompt re-orient the worker in three named parts** — the state
   re-check to run first (`git status`, `git log --oneline`, re-run the task's
   tests), the remaining done-criteria, and the completion signal to emit. Resuming
   across a limit boundary loses the conversation: a reported run answered a bare
   "continue" by re-reading and misinterpreting the plan and redoing finished work
   rather than resuming the interrupted step.
6. **Confirm the resume prompt was consumed by the worker's own effect**, not by
   the pane changing ([infrastructure-agent-orchestration-pane-delivery-confirmation]).

## Edge cases

| Case | Then |
|------|------|
| The session limit resets but the worker is blocked again immediately | The weekly allowance is also exhausted; both count at once. Read the new marker — it names the weekly reset day, which can be days out |
| You need the reset time and the marker scrolled away | Have the worker run `/usage`, which reports the plan limits and when each resets |
| The run must finish before the reset | `/usage-credits` buys usage past the allowance on Pro and Max, or requests it from an admin on Team and Enterprise; the reset time is otherwise the earliest resume |
| Only one worker of several stopped | A per-seat allowance is per account — a single stopped worker points at a model-scoped Opus limit or a different stall, not the shared window |
| The orchestrator's own session is billed to the same account | It hits the wall too, so schedule the resume outside the run (a wake-up at the reset time), not from inside the blocked session |
| Automatic resume is expected from the CLI | Implemented since v2.1.234 (`autoContinueAtUsageLimit`, on by default) for an interactive session signed in with a claude.ai subscription, when the reset is under 24 hours out. It does not self-start for a weekly-limit reset days out, for Remote Control or agent-team teammate sessions, for background/`-p` runs, or for API-key/cloud-provider billing — any of which still needs the orchestrator to start the wait (`/rate-limit-options` → "Wait here, then continue automatically") or re-drive the worker after the reset |

## Instead of

| If you are about to | Do this instead | Why |
|---------------------|-----------------|-----|
| Restart or replace a worker that went silent with no error | Read its terminal tail for the limit marker, then wait for the stated reset | A rate-limited worker is idle-waiting with its work intact; restarting discards completed work to solve a problem waiting solves |
| Send "continue" once the reset passes | Send a prompt naming the state re-check, the remaining done-criteria, and the completion signal | Context does not survive the boundary; a bare continue was reported to re-analyze the plan, misread its state, and redo work already done |
| Switch the worker's model to get it moving | Identify which limit the marker names first | Session and weekly limits are shared across all models; only the Opus limit is cleared by `/model` |
| Send the resume prompt as soon as you notice the stall | Wait until the time printed in the marker, then send | Requests inside the blocked window return the same limit message and delay the real resume |

## Sources

- https://code.claude.com/docs/en/errors — the three marker forms verbatim (`You've hit your session limit · resets 3:45pm`, `You've hit your weekly limit · resets Mon 12:00am`, `You've hit your Opus limit · resets 3:45pm`); "Claude Code **blocks further requests** until the reset time shown in the message"; "The session and weekly limits are **shared across all models**, so switching models doesn't restore access"; "The Opus limit **applies only to Opus requests**, so switching to another model with `/model` keeps you working"; "Usage counts against the session and weekly allowances at the same time"; `/usage` and `/usage-credits` as the remaining moves
- https://code.claude.com/docs/en/costs — "each member's Claude Code usage draws from a per-seat allowance that resets on a rolling five-hour window and a weekly window. The allowance is shared with Claude chat and Cowork, and its size depends on the member's seat tier"; agent teams spawn multiple Claude Code instances whose usage scales with the number of active teammates and how long each one runs
- https://github.com/anthropics/claude-code/issues/5977 — a long task interrupted by "Claude usage limit reached. Your limit will reset at 2pm (America/New_York)": the CLI stops cleanly rather than crashing, and after the reset a "continue" loses context, re-reads and misinterprets the plan, and redoes completed work instead of resuming the interrupted step. Closed as duplicate
- https://code.claude.com/docs/en/interactive-mode#wait-for-a-usage-limit-to-reset — "Claude Code waits in the open session and continues the task on its own after the limit resets. Automatic continue is on by default in interactive sessions signed in with a claude.ai subscription. Requires Claude Code v2.1.234 or later"; it does not self-start for a reset more than 24 hours away, for Remote Control or agent-team teammate sessions, or for background sessions and `-p` runs. (issue #36320, the feature request this replaced, was closed 2026-03-23 as a duplicate of #35744 once the feature shipped)
- Field observation 2026-08-06 (dev-loop Wave 1, three tmux workers): all three stopped within minutes of one another on the same reset time with the identical marker in each pane tail and every liveness check passing; a state-re-check prompt sent after the reset resumed all three at their interrupted step (re-running the task's tests)
