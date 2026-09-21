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
  - https://code.claude.com/docs/en/sub-agents#choose-a-model
  - https://code.claude.com/docs/en/model-config#fable-and-usage-credits
last_verified: 2026-09-14
related: [infrastructure-agent-orchestration-unattended-worker-questions, infrastructure-agent-orchestration-control-signals-vs-primary-artifacts, infrastructure-agent-orchestration-pane-delivery-confirmation, infrastructure-agent-orchestration-dispatching-after-a-completion-report, infrastructure-agent-orchestration-shared-run-state, infrastructure-agent-orchestration-login-expiry-during-unattended-turns]
---

# Worker Sessions Paused by a Provider Usage Limit

## When this applies

Several agent workers billed to one account go quiet within minutes of each other,
their diffs stop, and every liveness check still passes. Also when one worker's
terminal tail carries a `You've hit your … limit · resets …` notice, when you
are deciding whether to restart, replace, or wait on a worker that reports no
task-level error, or when a subagent call fails at once with a rate-limit error
that names one model.

## Do this

1. **Read the terminal tail for the limit marker before classifying the stall**,
   because which limit was hit decides whether waiting is the only move:

| Tail shows | Do |
|------------|----|
| `You've hit your session limit · resets <time>` | Wait until the stated time — the window is shared across all models, so switching models does not restore access |
| `You've hit your weekly limit · resets <day time>` | Wait until the stated day and time; the same model-independence applies |
| `You've hit your Opus limit` / `You've hit your Sonnet limit · resets <time>` | Send `/model` and switch to a model outside that family — each limit scopes to its own family, and the worker keeps working now |
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
7. **When a subagent call fails immediately with a model-scoped limit
   (`rate_limit`, HTTP 429, the error naming a model such as `claude-fable-5-1`),
   re-issue the identical call with a per-invocation `model` outside that family**
   (`model: "sonnet"`). A subagent definition's `model` frontmatter (`model: fable`)
   pins it independently of the session's model, so the session keeps working while
   every call to that subagent fails; the per-invocation parameter ranks first in
   Claude Code's subagent model order. Treat the failure as infrastructure noise,
   not as the subagent's verdict, and record which model the rerun used.

## Edge cases

| Case | Then |
|------|------|
| The session limit resets but the worker is blocked again immediately | The weekly allowance is also exhausted; both count at once. Read the new marker — it names the weekly reset day, which can be days out |
| You need the reset time and the marker scrolled away | Have the worker run `/usage`, which reports the plan limits and when each resets |
| The run must finish before the reset | `/usage-credits` buys usage past the allowance on Pro and Max, or requests it from an admin on Team and Enterprise; the reset time is otherwise the earliest resume |
| Only one worker of several stopped | A per-seat allowance is per account — a single stopped worker points at a model-scoped Opus or Sonnet limit or a different stall, not the shared window |
| The orchestrator's own session is billed to the same account | It hits the wall too, so schedule the resume outside the run (a wake-up at the reset time), not from inside the blocked session |
| Automatic resume is expected from the CLI | Implemented since v2.1.234 (`autoContinueAtUsageLimit`, on by default) for an interactive session signed in with a claude.ai subscription, when the reset is under 24 hours out. It does not self-start for a weekly-limit reset days out, for Remote Control or agent-team teammate sessions, for background/`-p` runs, or for API-key/cloud-provider billing — any of which still needs the orchestrator to start the wait (`/rate-limit-options` → "Wait here, then continue automatically") or re-drive the worker after the reset |
| The subagent rerun with a model override fails the same way | The limit is the shared session or weekly window, or the substitute family is limited too; read the marker and wait for the reset (steps 1 and 4) |
| The marker names Fable (`Fable limit reached · continuing on Fable 5.1 uses usage credits … nothing was sent`) in a background, Remote Control, or teammate session | Fable can bill to usage credits behind a consent prompt only the session's own terminal shows; answer it there, or `/model` (subagent: per-invocation `model`) to a model that does not bill credits |
| `CLAUDE_CODE_SUBAGENT_MODEL` is set on a CLI older than v2.1.251 | The environment variable ranked first then and overrode the per-invocation parameter; change or unset it for the rerun |
| The subagent is a reviewer or auditor whose definition picks its model on purpose | Record the substituted model beside its verdict; rerun on the defined model after the reset when the gate requires that model |
| An organization `availableModels` allowlist blocks the override | Claude Code substitutes another model for the subagent; `/tasks` names the model each subagent row runs on (v2.1.242+) |

## Instead of

| If you are about to | Do this instead | Why |
|---------------------|-----------------|-----|
| Restart or replace a worker that went silent with no error | Read its terminal tail for the limit marker, then wait for the stated reset | A rate-limited worker is idle-waiting with its work intact; restarting discards completed work to solve a problem waiting solves |
| Send "continue" once the reset passes | Send a prompt naming the state re-check, the remaining done-criteria, and the completion signal | Context does not survive the boundary; a bare continue was reported to re-analyze the plan, misread its state, and redo work already done |
| Switch the worker's model to get it moving | Identify which limit the marker names first | Session and weekly limits are shared across all models; only the model-scoped Opus and Sonnet limits are cleared by switching outside the family |
| Send the resume prompt as soon as you notice the stall | Wait until the time printed in the marker, then send | Requests inside the blocked window return the same limit message and delay the real resume |
| Wait out, or record as a failed audit, a subagent call that returned a model-named 429 | Re-issue the same call with a per-invocation `model` outside that family | The limit scopes to the model the subagent's definition chose, not to the session |

## Sources

- https://code.claude.com/docs/en/errors (quotes checked against the raw page, `curl https://code.claude.com/docs/en/errors.md`, 2026-09-21 — a summarizing fetch of this ~4,400-line page can omit the Usage limits and Fable consent sections) — the marker forms verbatim (`You've hit your session limit · resets 3:45pm`, `You've hit your weekly limit · resets Mon 12:00am`, `You've hit your Opus limit · resets 3:45pm`, `You've hit your Sonnet limit · resets 3:45pm`); "Claude Code **blocks further requests** until the reset time shown in the message"; "The session and weekly limits are **shared across all models**, so switching models doesn't restore access. The Opus and Sonnet limits each apply only to requests to that model family, so switching to a model outside the family with `/model` keeps you working"; "Usage counts against the session and weekly allowances at the same time"; `/usage` and `/usage-credits` as the remaining moves; "The prompt to confirm went unanswered": `Fable limit reached · continuing on Fable 5.1 uses usage credits, and the prompt to confirm went unanswered — nothing was sent · answer it where this session is running, or /model to change`, raised in Remote Control, background, and agent-team teammate sessions
- https://code.claude.com/docs/en/costs — "each member's Claude Code usage draws from a per-seat allowance that resets on a rolling five-hour window and a weekly window. The allowance is shared with Claude chat and Cowork, and its size depends on the member's seat tier"; agent teams spawn multiple Claude Code instances whose usage scales with the number of active teammates and how long each one runs
- https://github.com/anthropics/claude-code/issues/5977 — a long task interrupted by "Claude usage limit reached. Your limit will reset at 2pm (America/New_York)": the CLI stops cleanly rather than crashing, and after the reset a "continue" loses context, re-reads and misinterprets the plan, and redoes completed work instead of resuming the interrupted step. Closed as duplicate
- https://code.claude.com/docs/en/interactive-mode#wait-for-a-usage-limit-to-reset — "Claude Code waits in the open session and continues the task on its own after the limit resets. Automatic continue is on by default in interactive sessions signed in with a claude.ai subscription. Requires Claude Code v2.1.234 or later"; it does not self-start for a reset more than 24 hours away, for Remote Control or agent-team teammate sessions, or for background sessions and `-p` runs. (issue #36320, the feature request this replaced, was closed 2026-03-23 as a duplicate of #35744 once the feature shipped)
- https://code.claude.com/docs/en/sub-agents#choose-a-model — "When Claude invokes a subagent, it can also pass a `model` parameter for that specific invocation. Claude Code resolves the subagent's model in this order: 1. The per-invocation `model` parameter 2. The subagent definition's `model` frontmatter … 3. The `CLAUDE_CODE_SUBAGENT_MODEL` environment variable … 4. The main conversation's model"; "Before v2.1.251, `CLAUDE_CODE_SUBAGENT_MODEL` came first in this order"; blocked values under `availableModels` are substituted; `/tasks` names the subagent's model (v2.1.242+); the per-invocation value persists across resume (v2.1.211+)
- https://code.claude.com/docs/en/model-config#fable-and-usage-credits — "Depending on your plan and seat tier, Fable usage can bill to usage credits instead of drawing on your plan's included limits"; interactive sessions show a consent prompt before a Fable request bills usage credits
- Field observation 2026-08-06 (dev-loop Wave 1, three tmux workers): all three stopped within minutes of one another on the same reset time with the identical marker in each pane tail and every liveness check passing; a state-re-check prompt sent after the reset resumed all three at their interrupted step (re-running the task's tests)
- Field observation 2026-09-14 (two independent orchestrated worker sessions, dev-loop 1.21.0 whose `test-quality-auditor` agent declares `model: fable`): each first `dev-loop:test-quality-auditor` call failed with `rate_limit, HTTP 429` — "You've reached your Fable limit … model sent to the API: claude-fable-5-1" — while the session itself kept working; re-issuing the identical call with `model: "sonnet"` succeeded and completed the audit in both sessions
