---
id: infrastructure-agent-orchestration-pane-delivery-confirmation
domain: infrastructure
category: agent-orchestration
applies_to: [tmux, general]
confidence: verified
sources:
  - https://man7.org/linux/man-pages/man3/termios.3.html
  - https://man7.org/linux/man-pages/man1/tmux.1.html
last_verified: 2026-08-25
related: [platforms-shells-option-like-argument-values, infrastructure-agent-orchestration-session-completion-gates, platforms-processes-non-interactive-cli-invocation, infrastructure-agent-orchestration-unattended-worker-questions, platforms-processes-driving-a-tui-in-a-tmux-pane]
---

# Confirming a Keystroke Sent to a Terminal Pane Was Actually Consumed

## When this applies

An orchestrator drives another program through a terminal multiplexer — sending
a prompt to an agent CLI or a command to a shell with `tmux send-keys`, then
reading the pane back with `capture-pane` to decide whether to proceed, resend,
or escalate.

## Do this

1. **Read the target program's own busy/queued indicator first**, in the last
   few non-empty pane lines, and treat its presence as "not consumed yet". This
   fixed-window scan is scoped to an indicator the TUI paints at a fixed
   position near the bottom — it is **not** valid for a marker whose distance
   from the bottom grows with the payload; see the `[Pasted text` edge case
   below for that marker's own detection rule:

   ```sh
   tail_lines=$(tmux capture-pane -p -t "$s" | grep -v '^$' | tail -6)
   printf '%s' "$tail_lines" | grep -q "$BUSY_MARKER" && return 1   # still queued
   ```

2. **Accept a pane diff as delivery evidence only when that indicator is
   absent.** The terminal line discipline echoes typed characters as they
   arrive, independent of whether the foreground program has read them, so the
   pane changes for a queued keystroke exactly as it does for a consumed one.
3. **Prefer an effect the target produces to text the terminal echoed.** Order
   the checks by how much they prove:

| Evidence | Proves | Use as |
|----------|--------|--------|
| A file, status entry, or IPC message the target writes on receipt | The program ran the input | The confirmation |
| The target's own idle/ready prompt returning after the send | The program consumed and finished the input | A confirmation when no artifact exists |
| The target's busy/queued indicator present | The input is buffered, not consumed | A retry-later signal |
| Pane content differs from before the send | Bytes reached the tty | Nothing on its own |

4. **Bound the wait and escalate on the indicator, not on the diff.** When the
   busy marker is still present after the deadline, report "target busy" — a
   distinct outcome from "send failed", which the `send-keys` exit status owns
   ([platforms-shells-option-like-argument-values]).
5. **Capture the pane before and after with the same command and flags**, so a
   redraw, resize, or scroll-region change is not read as new content.

## Edge cases

| Case | Then |
|------|------|
| The target program disables echo (password prompt, raw-mode TUI) | The pane does **not** change on send; absence of a diff is not evidence of failure either — fall back to the artifact or ready-prompt check |
| The target repaints and the echoed text scrolls away | For the busy/queued **indicator**, search a fixed window of the last N non-empty lines, not the whole scrollback; a repaint drops the marker count to 0 while the input is still queued. That window is scoped to the indicator — it is not valid for a marker whose position depends on payload size (see the `[Pasted text` row below) |
| The send is a multi-line prompt | Send the body and the submit key as separate calls and check the indicator between them; a single blob can be consumed partially |
| Several sends are in flight to one pane | Serialize them — one outstanding send per pane, confirmed before the next; interleaved input is reordered by the tty buffer, not by your script |
| No busy indicator exists in the target | Require the artifact check from the table; without either, the harness cannot distinguish queued from consumed |
| You are binding a *new* unit of work to a pane the previous unit just reported finishing | Check for the idle prompt before binding, not after. A worker's "done" message is a report emitted from inside its turn, not the end of it — completion hooks keep the pane busy for minutes afterwards, and a dispatch bound to a busy pane is consumed as a failed unit rather than queued |
| The bind fails with a stage naming the runtime as unavailable | The pane is occupied by the tail of a turn — wait for the idle prompt and bind a fresh unit; the failed one is spent and is not retried in place |
| The bind fails with a stage naming the agent as unconfigured | The agent process behind the pane is dead even though the pane still renders and its worktree still resolves — no wait recovers it. Close the pane and create a new agent in worker mode, then bind |
| A bind is rejected for a pane/worktree mismatch | Pass the worktree alongside the pane on every bind; a pane identifier alone resolves against the coordinator's own checkout |
| The pane shows the prompt collapsed into a paste placeholder (`❯ [Pasted text #3]`) with no busy marker | Locate the **input box** — the region between the last two horizontal rules of the full `capture-pane -p` output — and look for the marker inside it, not in a fixed `tail -N` window: an unsubmitted paste renders its own remainder below the marker, so the marker's distance from the bottom grows with the payload and a fixed window is defeated by exactly the size it must detect; a whole-capture grep is also wrong, since it false-positives on a `[Pasted text` rendering still visible in the transcript above the input box. Once located: the body arrived as one bracketed-paste block and the submit key was consumed with it — send `Enter` as its own `send-keys` call and re-read. When the box's chrome cannot be located at all, that is *could not look*, not *nothing found*: report the check as unknown rather than a clean negative, or fall back to a deliberately oversized window only as a degraded check that announces itself as one. [platforms-processes-non-interactive-cli-invocation] owns the paste mechanism |
| A send helper reports a queued outcome and its own follow-up wait then reports pick-up | That pair is a confirmation: the wait observed the target take the input. A helper that reports delivery without a wait has observed only the write |

## Instead of

| If you are about to | Do this instead | Why |
|---------------------|-----------------|-----|
| Diff `capture-pane` before/after and call a difference "delivered" | Check the busy/queued indicator first and use the diff only when it is absent | The tty echoes typed characters while the program is busy, so the diff reports success for the queued case the check exists to catch |
| Sleep a fixed interval after `send-keys` and continue | Poll the indicator (or the artifact) until it clears, with a deadline | The right interval is the target's work time, which is what you are trying to measure |
| Read a send wrapper's success word or exit 0 as "the prompt is running" | Read it as "the keys reached the pane", then confirm submission from the pane: an empty input line plus the target's working indicator | The wrapper checks its own write, which succeeds whether the target submitted the input or parked it as an unsubmitted paste; the gap surfaces only as a phase timeout much later |
| Resend on the first unchanged capture | Distinguish "busy" from "not delivered" before resending | Resending into a busy pane queues a duplicate that runs when the pane drains |
| Treat every failed bind the same way and retry it | Branch on the stage the failure names: wait-and-rebind for an occupied runtime, replace the agent for a dead one | The two look identical from outside — the pane renders in both cases — and retrying a dead agent spends units without ever succeeding |
| Size the pasted-marker window by raising N | Anchor the scan on the input box region | N must exceed the payload's own rendered tail, which is unbounded; raising N moves the threshold instead of removing it |

## Sources

- https://man7.org/linux/man-pages/man3/termios.3.html — `ECHO` in `c_lflag`: "Echo input characters." The terminal driver echoes independently of when the program calls `read()`
- https://man7.org/linux/man-pages/man1/tmux.1.html — `send-keys` writes keys into a pane's input; `capture-pane` copies the pane's visible contents — neither reports whether the foreground process consumed the input
- Field observations 2026-08-06 (dev-loop 1.4.0 orchestrate, three dispatches): binding to a pane whose worker had just reported done produced a unit that went pending then failed and had to be recreated; a second pane rendered normally but its agent was dead, reported as an unconfigured-agent stage, and recovered only by closing the pane and creating a new worker-mode agent; a third bind was rejected for a pane/worktree mismatch and succeeded once the worktree was passed with the pane — the shipped script carries the same rule in `skills/orchestrate/scripts/orca-worker-start.sh` ("rejects the pair with `terminal_worktree_mismatch` (verified live)"), and `skills/orchestrate/SKILL.md` documents that a failed unit is replaced rather than retried in place
- Field observation 2026-08-12 (dev-loop orchestrate, 3 tmux worker sessions): `send-prompt.sh` returned 0/"delivered" for two workers whose panes both sat at `❯ [Pasted text #3]`/`#4` with the prompt unsubmitted, while the third returned "queued" and its follow-up `wait` reported pick-up — that one had actually submitted. Sending `Enter` as a separate key event to each stuck pane started both workers immediately
- Field reproduction 2026-08-05 (tmux 3.7b, macOS): a pane running `sleep 6` received `echo SECOND_PROMPT_MARKER`. Pane content changed (diff = YES) and the marker appeared once as echoed text, while the command's own output line count stayed 0; after the sleep drained, the command ran and the output line appeared
- Field observation 2026-08-25 (dev-loop 1.11.0 orchestrate, tmux, session `lo-1-dsr1`, task `t1-foundation` rework round r2): a 1713-byte single-line prompt — `send` returned `delivered` (exit 0) and a follow-up `state` returned `ready` while the pane sat at `❯ [Pasted text #10]…` with four further lines of the paste's remainder rendered below it, putting the marker **7th from the bottom** against the 6-line window; seven earlier sends of 1002–1520 bytes in the same run had succeeded; recovery was one `Enter` as its own `send-keys` call; the run only surfaced the stall ~10 minutes later via `watch-status.sh` exit 7 (`choiyounggi/dev-loop#145`)
- https://code.claude.com/docs/en/terminal-config — "Paste large content": the CLI collapses input over 800 characters or more than two lines to a `[Pasted text #N +M lines]` placeholder **in the input box**, which is what makes the input box the right anchor for the marker
