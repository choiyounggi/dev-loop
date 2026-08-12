---
id: infrastructure-agent-orchestration-pane-delivery-confirmation
domain: infrastructure
category: agent-orchestration
applies_to: [tmux, general]
confidence: verified
sources:
  - https://man7.org/linux/man-pages/man3/termios.3.html
  - https://man7.org/linux/man-pages/man1/tmux.1.html
last_verified: 2026-08-12
related: [platforms-shells-option-like-argument-values, infrastructure-agent-orchestration-session-completion-gates, platforms-processes-non-interactive-cli-invocation]
---

# Confirming a Keystroke Sent to a Terminal Pane Was Actually Consumed

## When this applies

An orchestrator drives another program through a terminal multiplexer — sending
a prompt to an agent CLI or a command to a shell with `tmux send-keys`, then
reading the pane back with `capture-pane` to decide whether to proceed, resend,
or escalate.

## Do this

1. **Read the target program's own busy/queued indicator first**, in the last
   few non-empty pane lines, and treat its presence as "not consumed yet":

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
| The target repaints and the echoed text scrolls away | Search a fixed window of the last N non-empty lines, not the whole scrollback; a repaint drops the marker count to 0 while the input is still queued |
| The send is a multi-line prompt | Send the body and the submit key as separate calls and check the indicator between them; a single blob can be consumed partially |
| Several sends are in flight to one pane | Serialize them — one outstanding send per pane, confirmed before the next; interleaved input is reordered by the tty buffer, not by your script |
| No busy indicator exists in the target | Require the artifact check from the table; without either, the harness cannot distinguish queued from consumed |
| The pane shows the prompt collapsed into a paste placeholder (`❯ [Pasted text #3]`) with no busy marker | The body arrived as one bracketed-paste block and the submit key was consumed with it — send `Enter` as its own `send-keys` call and re-read; [platforms-processes-non-interactive-cli-invocation] owns the paste mechanism |
| A send helper reports a queued outcome and its own follow-up wait then reports pick-up | That pair is a confirmation: the wait observed the target take the input. A helper that reports delivery without a wait has observed only the write |

## Instead of

| If you are about to | Do this instead | Why |
|---------------------|-----------------|-----|
| Diff `capture-pane` before/after and call a difference "delivered" | Check the busy/queued indicator first and use the diff only when it is absent | The tty echoes typed characters while the program is busy, so the diff reports success for the queued case the check exists to catch |
| Sleep a fixed interval after `send-keys` and continue | Poll the indicator (or the artifact) until it clears, with a deadline | The right interval is the target's work time, which is what you are trying to measure |
| Read a send wrapper's success word or exit 0 as "the prompt is running" | Read it as "the keys reached the pane", then confirm submission from the pane: an empty input line plus the target's working indicator | The wrapper checks its own write, which succeeds whether the target submitted the input or parked it as an unsubmitted paste; the gap surfaces only as a phase timeout much later |
| Resend on the first unchanged capture | Distinguish "busy" from "not delivered" before resending | Resending into a busy pane queues a duplicate that runs when the pane drains |

## Sources

- https://man7.org/linux/man-pages/man3/termios.3.html — `ECHO` in `c_lflag`: "Echo input characters." The terminal driver echoes independently of when the program calls `read()`
- https://man7.org/linux/man-pages/man1/tmux.1.html — `send-keys` writes keys into a pane's input; `capture-pane` copies the pane's visible contents — neither reports whether the foreground process consumed the input
- Field observation 2026-08-12 (dev-loop orchestrate, 3 tmux worker sessions): `send-prompt.sh` returned 0/"delivered" for two workers whose panes both sat at `❯ [Pasted text #3]`/`#4` with the prompt unsubmitted, while the third returned "queued" and its follow-up `wait` reported pick-up — that one had actually submitted. Sending `Enter` as a separate key event to each stuck pane started both workers immediately
- Field reproduction 2026-08-05 (tmux 3.7b, macOS): a pane running `sleep 6` received `echo SECOND_PROMPT_MARKER`. Pane content changed (diff = YES) and the marker appeared once as echoed text, while the command's own output line count stayed 0; after the sleep drained, the command ran and the output line appeared
