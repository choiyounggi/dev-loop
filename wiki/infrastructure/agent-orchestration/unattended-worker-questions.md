---
id: infrastructure-agent-orchestration-unattended-worker-questions
domain: infrastructure
category: agent-orchestration
applies_to: [tmux, general]
confidence: verified
sources:
  - https://github.com/anthropics/claude-code/issues/50728
  - https://github.com/anthropics/claude-code/issues/29530
  - https://man7.org/linux/man-pages/man1/tmux.1.html
last_verified: 2026-08-08
related: [infrastructure-agent-orchestration-usage-limit-paused-workers, infrastructure-agent-orchestration-pane-delivery-confirmation, infrastructure-agent-orchestration-control-signals-vs-primary-artifacts, infrastructure-agent-orchestration-shared-run-state, infrastructure-agent-orchestration-session-completion-gates, platforms-processes-non-interactive-cli-invocation]
---

# A Worker Agent Asks a Question With No Human at Its Terminal

## When this applies

An orchestrator runs agent workers unattended (tmux panes, a task runner, an SDK
subprocess) and one worker raises a question through its own in-band question UI —
a numbered chooser, a confirmation screen, a trust or re-auth prompt. Also when a
worker is judged stalled with a live terminal and no task-level error, or when a
worker reports a decision it "assumed" that nobody was asked about.

## Do this

1. **Treat an in-band question as unanswerable and design an out-of-band channel
   for it.** Give the worker one command that writes a durable question record the
   coordinator polls — `{ts, taskId, question, options, worktree}` in a
   `questions/` directory beside the run's status directory
   ([infrastructure-agent-orchestration-shared-run-state]) — and have the worker
   end its turn after writing it. The record survives the worker's turn; a UI
   waiting for a keystroke does not.
2. **State the channel in the worker's first prompt**, naming the command and the
   rule that a decision needing the coordinator is written to that channel rather
   than raised locally. A worker follows the prompt it was given; without the rule
   it reaches for its default question UI.
3. **Make a pending question a distinct wake reason** in the watcher, separate
   from "failed" and from "all tasks reached the phase", so it is handled and
   cleared rather than aggregated into a timeout.
4. **Classify before acting on a stall — read the terminal tail first.** "Wedged
   on a question" and "finished but never reported" are identical from outside and
   need opposite responses:

| Terminal tail shows | Do |
|---------------------|----|
| A question UI with selectable options | Unblock it by key (step 5), then re-drive the interrupted work (step 6) |
| The idle prompt, work visibly complete | Ask for the completion signal; the worker finished and skipped its report |
| The busy/working indicator | Not a stall — keep waiting ([infrastructure-agent-orchestration-pane-delivery-confirmation]) |
| A usage-limit or re-auth notice | Idle waiting, not a crash; resume after the stated reset, following [infrastructure-agent-orchestration-usage-limit-paused-workers] |

5. **Unblock a question UI with an allowlisted key sequence, validated whole
   before any key is sent.** Restrict the allowlist to navigation and answer keys
   (`Up Down Left Right Enter Escape Tab Space 0-9 y n`), send one key per call so
   ordering is deterministic and a failure names the key that did not land, and
   re-read the terminal until the idle prompt returns — a chooser can have a
   selection step and a confirmation step, and one key answers only the first.
6. **Re-send the prompt that was in flight when the question opened.** Text typed
   or pasted into the input line before the UI opened is not submitted by the keys
   that answer the UI; the turn ends quietly with the work never started. Confirm
   from the artifact the prompt was supposed to produce, not from the terminal.

## Edge cases

| Case | Then |
|------|------|
| The worker runs with no TTY (SDK subprocess, container, CI) | The question tool does not block — it resolves immediately with empty answers and the agent continues as if answered, so the failure is a silent wrong decision instead of a stall. The out-of-band channel is the fix in both substrates |
| Liveness and heartbeat checks all pass while nothing progresses | A live PTY on a question UI is alive-and-not-progressing, a third state distinct from alive and dead; add a per-agent activity check to see it |
| The stall detector keys off terminal output timestamps | A TUI repaints its spinner continuously, so a wedged worker reports output "0 seconds ago" — key off the agent's own state timestamp instead |
| The out-of-band ask has a timeout and it expires | A timeout leaves the question pending; it is not an answer. Resume the same question rather than deciding it in the worker or asking it again |
| Answering the question requires a decision the coordinator also cannot make | Record it against the task and hand the whole record to the human once, rather than blocking each worker separately |
| The question record's task id is attacker- or environment-derived | It becomes a filename — reject `/`, `.`, `..`, and empty before writing, so a record cannot escape the questions directory |

## Instead of

| If you are about to | Do this instead | Why |
|---------------------|-----------------|-----|
| Let a worker raise its question through its own interactive UI | Have it write a durable question record and end its turn | The UI needs a human at that terminal; with a TTY it waits indefinitely, and without one it self-answers empty |
| Restart or replace a worker that a stall check flagged | Read the terminal tail and classify first | A worker waiting on a question is intact and one keystroke from resuming; restarting discards its completed work |
| Send free text to answer a chooser | Send allowlisted key events, validated as a set before the first is sent | A chooser reads key events, and a half-delivered sequence leaves it in a state neither side can name |
| Tell a worker to "decide it yourself and note the assumption" | Give it the question channel and have it wait for the answer | Measured on a 3-worker run: at 600 s and 900 s both workers instead proceeded on a conservative assumption and reported the guess after the fact |

## Sources

- https://github.com/anthropics/claude-code/issues/50728 — `AskUserQuestion` in a headless/no-TTY environment (Docker, `claude-agent-sdk` 0.1.63, bundled CLI 2.1.114): "auto-resolves immediately with empty answers", completing in ~37 ms before a `can_use_tool` callback or `PreToolUse` hook can intervene; the agent receives "User has answered your questions: ." and continues. Closed as not planned
- https://github.com/anthropics/claude-code/issues/29530 — same tool "does not render any interactive UI (question text, selectable options)" and returns an empty answer (CLI 2.1.63, open) — a second report that the in-band channel cannot be relied on to reach a human
- https://man7.org/linux/man-pages/man1/tmux.1.html — `send-keys` writes key events into a pane; named keys are sent without `-l`, which sends the literal characters instead
- Shipped implementation, dev-loop 1.4.2 `skills/orchestrate/`: `scripts/ask-coordinator.sh` writes one atomic `questions/<task>.json` record per task and refuses a task name containing `/`, `.`, or `..`; `scripts/watch-status.sh` surfaces it as its own exit code within one poll; `scripts/send-prompt.sh keys` validates every key against the allowlist before sending any and sends one `send-keys` per key; `scripts/orca-worker-stalled.sh` documents the measurement behind the third state — three workers held a live PTY on an interactive prompt for 75 minutes with byte-identical diffs while every alive/dead check passed, and terminal-output timestamps were measured and rejected because a TUI's repaint keeps them fresh
- Field observation 2026-08-08 (dev-loop orchestrate, tmux worker `lo-4-qag1`): the worker raised a numbered chooser in its pane and sat 30 minutes past its silence threshold with the terminal alive. Two rounds of number-then-Enter cleared it (selection, then confirmation); the prompt queued in the input line before the chooser opened was never submitted, and the phase reached its next state only after that prompt was re-sent
